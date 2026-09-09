# Прод: что происходит на code-funnel sales (`/sierra`), когда `GET /v1/billing/products` падает

Репозиторий: `/Users/uvarovalexandr/myProject/promova.com_monorepo` (read-only).
Все ссылки — `абсолютный_путь:строка`.

## Короткий ответ

Алекс прав по сути, но формулировка «фолбэк на хардкод / стандартные цены» требует уточнения: **фолбэк есть, и он — не хардкод в коде, а «авторские» (CMS-овые) цены из Strapi pricing rule, в базовой валюте (обычно USD)**. Никакого захардкоженного в репозитории прайса для `general-english` нет.

Механика в три уровня:

1. `getBillingProducts` **никогда не бросает** — на любую transport-ошибку/таймаут (5 s) она резолвится в `[]`.
   `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/api/getMulticurrencyProducts.ts:70-75`
2. `mappingBillingPlans` при пустом/неполном ответе **возвращает авторские продукты как есть** — all-or-nothing на батч.
   `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/mappingBillingPlans.ts:19-22`
3. `Sales.tsx` дополнительно перестраховывается: `products = multiCurrencyProducts?.length ? multiCurrencyProducts : subscriptionsFromRule || page?.subscriptions?.data`.
   `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/pages/Sales/Sales.tsx:672-688`

Т.е. страница **всегда** рисует карточки — но в базовой валюте Strapi. Пустой пейволл в проде невозможен по клиентской ветке; он отсекается ещё на сервере 404-ем (`renderCodeSalesHop`).

---

## 1. Подтверждение / коррекция по анкорам

### `packages/utils/mappingBillingPlans.ts` — подтверждено дословно

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/mappingBillingPlans.ts:10-22`

```ts
  const externalMap = new Map(
    (externalProducts ?? []).map((ext) => [ext.product_id, ext])
  )

  // All-or-nothing per call: if the billing API returned multicurrency
  // pricing for only SOME products in this batch, applying it per-item would
  // mix currencies on one page (e.g. a downsell's 1-month tier remapped to
  // EUR while its 3-month tier silently stays in the Strapi base USD).
  // Safer to leave the whole batch in the base currency than show a mix.
  const hasFullCoverage = products.every((product) =>
    externalMap.has(product.attributes?.productId as string)
  )
  if (!hasFullCoverage) return products
```

`products` здесь — это **авторские** объекты `{ id, attributes: Subscription }`, пришедшие из Strapi. То есть да: `return products` = «оставить CMS-цены как есть». Регрессия, из-за которой это появилось (PGS downsell смешал USD и EUR на одной странице), зафиксирована в тесте:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/mappingBillingPlans.test.ts:40-53`

Важная деталь мержа (для порта): в happy-path мержатся **только** деньги и каталожные поля — `amount`, `firstPayment`, `secondPayment`, `currencyCode`, `currencySymbol`, `category`, `productType`, `term`, `oneDollarCharge`. Периоды/трайалы/лейблы (`billingCyclePeriod`, `billingPeriodInDays`, `trialPeriod`, `priceDivider`, `fullPeriodLabel`, `weekPrice`, `title`) **не** мержатся — остаются авторскими (`mappingBillingPlans.ts:29-52`).

### `packages/api/getMulticurrencyProducts.ts` — подтверждено

- Таймаут: `BILLING_PRODUCTS_TIMEOUT_MS = 5_000`, `AbortController` (`:21`, `:36-39`). Таймер стартует **после** `getCountry()`, т.е. бюджетирует только billing-запрос (`:18-20`).
- Транспортная ошибка / abort → `catch` → `reportBillingProductsException` + **`return [] as T`** (`:70-75`).
- HTTP 4xx/5xx: `openapi-fetch` не бросает; код только **репортит** (`reportBillingProductsHttpError`, `:58-64`) и делает `return data as T` (`:66`) — а `data` на не-2xx у openapi-fetch `undefined`.
- `enabled: params.query.product_id.length > 0` (`:88`) — без productId запрос вообще не идёт.
- Контракт «settle в ограниченное время» закреплён тестами:
  `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/pages/Sales/utils/billingProductsSettle.test.ts:72-102` (таймаут → `[]`), `:104-110` (transport → `[]`).

⚠️ **НЕ подтверждено кодом/тестами**: что происходит на HTTP-ошибке. `return undefined` в TanStack Query v5 (`5.100.14`, `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/api/package.json:12`) — это ошибка запроса («Query data cannot be undefined»), значит включается дефолтный `retry: 3` с экспоненциальным бэкоффом (глобальных дефолтов `retry` нет: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/tanstack/getQueryClient.ts:8-24` задаёт только `refetchOnWindowFocus: false`). Итог тот же (`data` остаётся `undefined` → `= []` дефолт хука → фолбэк на Strapi-цены), но **гейт чекаута может держаться закрытым дольше 5 s**. Тестов на эту ветку нет; проверить в рантайме я не мог.

### `getIsPricingSettled` — файл лежит не там, где сказано

Фактический путь: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/pages/Sales/utils/getIsPricingSettled.ts` (не `packages/utils/`).

```ts
export const getIsPricingSettled = (
  isMulticurrencyLoaded: boolean | undefined
): boolean => isMulticurrencyLoaded !== false
```
`:25-27`

```ts
export const getShouldShowPricingSettleLoader = (
  isPricingSettled: boolean,
  isModalOpen: boolean
): boolean => !isPricingSettled && isModalOpen
```
`:37-39`

Т.е. гейт закрыт **ровно в одном состоянии** — запрос в полёте. Ошибка/таймаут/отключённый запрос → гейт открыт (`getIsPricingSettled.test.ts:15-28`).

### `useMultiCurrency.ts` — существует, но это МЁРТВАЯ ветка

Фактический путь: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/pages/Sales/v2/hooks/useMultiCurrency.ts`. Это Sales/v2, который в проде не используется. Логика идентична (`:32` `plans?.length ? mappingBillingPlans(...) : productsData`; `:51` `multiCurrencyProducts?.length ? multiCurrencyProducts : productsData`; `:91` `isMulticurrencyLoaded = !isMulticurrencyLoading`). **Живой путь — `Sales.tsx`**, который держит ту же логику инлайном; это прямо задокументировано в комментарии `Sales.tsx:653-664` («this (legacy, still the ONE production path — every Strapi funnel and every code money funnel render through this component)»).

### `Sales.tsx` — где планы попадают в layout

- Авторские планы: `productsData` = `usePricingRuleSubscription(pricingRule)` **или** `page?.subscriptions?.data` (`Sales.tsx:531-536`); `productIds` из них (`:539`).
- Запрос: `useGetBillingPlans` с `select: mappedProductsData` (`:636-650`), где `mappedProductsData = plans?.length ? mappingBillingPlans(productsData, plans) : productsData` (`:632-635`).
- `isMulticurrencyLoaded = !isMultiCurrencyProductsLoading` (`:664`), `isPricingSettled = getIsPricingSettled(isMulticurrencyLoaded)` (`:670`).
- Двойной фолбэк: `Sales.tsx:672-688`.
- Планы уходят в layout через `SalesPageContext` (`providerValue` → `subscriptions.products`, `:1653/:1665`), layout читает их хуком `useSalesPageContext()`.
- `isMulticurrencyLoaded` гейтит **только скелетон карточек в Strapi-секциях**: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/components/common/sales-page/sections/Plans/Plans.tsx:172` — `isMulticurrencyLoaded === false ? <CardSkeleton count={products?.length || 3} /> : …`. **Code-funnel layout `general-english/SalesLayout.tsx` этот флаг не читает вообще** (grep по файлу — ни одного упоминания), т.е. code-funnel сразу рисует авторские USD-цены и потом перерисовывает их в локальной валюте.
- Гейтится на `isPricingSettled` только чекаут: `renderCheckout()` (`Sales.tsx:1833-1837`) и `codeInlineCheckout` (`:1765-1769`).

### `code-funnels/money/general-english/*` — коммерс

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/general-english/index.ts:29`

```ts
commerce: { kind: 'pricing-rule', ruleSlug: 'general-english-sales' },
```

`resolveCommerce` (server-only) тянет `GET /pricing-rule/general-english-sales/commerce` из marketing-инстанса Strapi и нормализует форму:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/resolveCommerce.ts:151-183`. Сетевая ошибка → `{ pricingRule: null, subscriptions: [] }` (`:173-183`).

`buildSyntheticSalesPage` укладывает это в `SalesPageProps`, которые ждёт живой `Sales.tsx`:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/adapters/buildSyntheticSalesPage.ts:142` (`pricing_rule`), `:147` (`subscriptions: { data: commerce.subscriptions }`), `:151` (`downSubscriptions`), `:158-161` (`pricingRule` / `downSalePricingRule`).

Dead-paywall guard — на сервере, до рендера:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/renderCodeSalesHop.tsx:63-73` → `notFound()`, если ни `commerce.subscriptions.length > 0`, ни `pickFirstRuleSubscription(commerce.pricingRule)`.

---

## 2. Ответы на подвопросы

### 1) Fetch падает полностью — что видит посетитель?

**Видит авторские (Strapi) цены в базовой валюте продукта — на практике USD** (`DEFAULT_CURRENCY_CODE = 'USD'`, `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/config/constants/common.ts:308`; сама валюта берётся из поля `currencyCode` подписки в Strapi, а не из константы — константа используется только как дефолт в аналитике, напр. `Sales.tsx:1000`).

Цепочка: `getBillingProducts` → `[]` (`getMulticurrencyProducts.ts:74`) → `select` не вызывает маппер (`Sales.tsx:633`, `plans?.length` = 0) → `data` = `[]` → `products` берёт `subscriptionsFromRule || page?.subscriptions?.data` (`Sales.tsx:672-688`).

**Видимого уведомления нет.** Ни баннера, ни тоста, ни disabled-состояния. Единственный сигнал — Faro-ошибка с сообщением `'getBillingProducts API error — falling back to Strapi prices'`:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/reportBillingProductsError.ts:19-20`. Transport-ошибки схлопываются в **один** репорт за сессию (`:21`, `:136-147`), HTTP-ошибки репортятся полно со статусом и головой тела (`:102-122`).

Скелетон карточек посетитель тоже не увидит — в code-funnel layout его нет (см. выше). В Strapi-секциях (`Plans.tsx:172`) скелетон покажется на время загрузки и исчезнет при settle.

Отдельная, менее очевидная дыра: **если падает гео**, billing-запрос вообще не уходит. `getCountry()` вызывается внутри `try` (`getMulticurrencyProducts.ts:34`), его собственный axios-таймаут 5 s без ретраев (`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/customHooks/useQueryCountry.ts:39-48`), и его исключение ловится тем же `catch` → `[]`. То есть блокировка ip-api адблоком = гарантированные USD-цены. (Ретрай `retry: 1` живёт только в хуке `useQueryCountry`, `:65` — не в этом прямом вызове.)

### 2) Fetch успешен, но покрывает не все productIds — all-or-nothing по странице или по продукту?

**All-or-nothing на КАЖДЫЙ ЗАПРОС (батч productId), а не на страницу и не на продукт.** Один непокрытый productId → вся пачка остаётся в авторской валюте (`mappingBillingPlans.ts:19-22`).

Батчей на sales-странице несколько, и они независимы:

| Батч | productIds | Строки |
|---|---|---|
| основные планы (или downsale-планы, когда `isDownSale`) | `productsData` | `Sales.tsx:531-539`, `:636-650` |
| `subsTimerZero` (full-price после таймера) | `subsTimerZeroProductIds` | `Sales.tsx:702-731` |

`queryHash` включает список id (`Sales.tsx:647`, `:726`), поэтому переключение sales↔downsale создаёт **новый** запрос со своим all-or-nothing вердиктом. Т.е. теоретически возможна страница, где основной набор в EUR, а `subsTimerZero` — в USD; внутри одного набора смешения нет.

### 3) Где живут авторские / «стандартные» цены для CODE-фаннела?

**Не в репозитории.** Для code money funnel авторские планы — это записи Strapi (gringotts, marketing-инстанс), привязанные к pricing rule `general-english-sales` (`code-funnels/money/general-english/index.ts:29`), которые тянет `resolveCommerce` через `GET /pricing-rule/general-english-sales/commerce` (`resolveCommerce.ts:156-167`) и укладывает `buildSyntheticSalesPage` (`buildSyntheticSalesPage.ts:142-158`).

В `general-english/index.ts` захардкожен **только один** productId — и не как цена, а как preselect:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/general-english/index.ts:40`
```ts
preselectSubscriptionId: 'MC_promova_79.99_84days_intro_39.99',
```

Форма одного плана — тип `Subscription`, `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/types/sales_page.ts:63-97`:
`amount`, `firstPayment`, `secondPayment`, `billingPeriodInDays`, `billingCyclePeriod`, `currencyCode`, `currencySymbol`, `productId`, `paymentMode`, `priceDivider`, `trialPeriod/trialDuration/trialPeriodLabel`, `fullPeriodLabel`, `weekPrice`, `rebillPayment`, `title`, … Оборачивается в `ProductData = { id: number; attributes: Subscription }` (`:99-102`). Суммы — в **минорных единицах** (центах); это видно по `formatMoney` code-фаннела: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/code-funnels/money/general-english/formatMoney.ts:5` — `(cents / 100).toFixed(2)`.

Схема поля в CMS: `/Users/uvarovalexandr/myProject/gringotts-strapi-cms/src/api/subscription/content-types/subscription/schema.json` (`productId`, `pandaId`, `amount`, `firstPayment`, `secondPayment`, `currencyCode` как enum и т.д.).

⚠️ **Три полных plan-объекта для `general-english` из прода я привести не могу** — их значения лежат в базе Strapi, а не в коде, и я не запрашивал CMS/Walhalla. Ближайший к ним артефакт в коде — уже перенесённые авторские планы движка `funnel-engine`, где два из трёх productId совпадают с продовыми (`MC_promova_39.99_28days_intro_19.99`, `MC_promova_79.99_84days_intro_39.99`) — `/Users/uvarovalexandr/myProject/funnel-engine/funnels/general-english/sales.json:4-53`. Считать их точной копией прода нельзя: третий id там `promova_mc_39.99_28days_intro_6.99` (нижний регистр, другой порядок), это надо сверить с CMS.

Если нужны реальные значения — их даст либо `GET /pricing-rule/general-english-sales/commerce` на marketing-Strapi, либо Walhalla (`billing_plans` / `products`).

### 4) Может ли посетитель реально ЗАПЛАТИТЬ по фолбэк-ценам?

**Да, и это ключевой момент: цена в запросе на ордер вообще не передаётся.**

`OrderRequestV3` несёт только id плана и валюту:
`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/Checkout/Checkout.ts:1190-1191`
```ts
      billing_plan: productId,
      currency,
```
где `productId` = `this.config.productId` (из выбранной подписки), `currency = total?.currencyCode` (`:1049`). То же для PayPal (`:1518-1519`, `currency` на `:1504`), для апселлов — только `billing_plan` без валюты (`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/api/billing.ts:50`, `:228`).

Значит: **сумму определяет бэкенд по `billing_plan`**. Фолбэк-карточка с USD-цифрой — это только LABEL. Риск не в «неоплатимости», а в расхождении: карточка показала $39.99, а бэкенд по гео посчитает в локальной валюте — посетителя спишут по каталогу, а не по надписи. Именно это и есть смысл гейта PROMOVA-428: он не даёт смонтировать Solidgate-форму на неустоявшейся цене (`getIsPricingSettled.ts:1-24`).

Что **блокирует** чекаут:
- `!isPricingSettled` → `renderCheckout()` возвращает `<Loader/>` (если модалка открыта) или `null` (`Sales.tsx:1833-1837`); inline-чекаут не рендерится (`:1765-1769`). Но это состояние ограничено 5 s и **не** является ошибочным — после settle (в т.ч. по ошибке) гейт открыт.
- `!currentUserId || !currentSubscription || isLoading` → `<Loader isLoading />` (`Sales.tsx:1690-1692`).
- PayPal просто не рендерится при неподдерживаемой валюте (`Checkout.ts:1505-1512`), карта при этом работает.

Никакой проверки «цены не разрешились → не пускать в чекаут» в коде **нет**.

### 5) Есть ли путь, где НЕ рендерится ни одной карточки?

На клиенте — только через пустой `products`, и тогда это не «страница без карточек», а **вечный лоадер**: `currentSubscription` остаётся `null` (пресeлект ничего не находит: `Sales.tsx:785-806`), и срабатывает ранний return `<Loader isLoading />` (`Sales.tsx:1690-1692`).

В проде этот путь для code-фаннела отсекается на сервере — три dead-paywall guard-а в `renderCodeSalesHop.tsx`, каждый с `console.error` + `notFound()` (HTTP 404):
- основной набор пуст: `:63-73`;
- объявленный таймер, у которого `subsTimerZero` пуст (строже — без `pickFirstRuleSubscription`): `:136-145`;
- объявленный on-page downsale с пустым правилом: `:154-166`.

Т.е. **если Strapi не отдал подписки — посетитель получает 404, а не пустой пейволл**. Отказ billing-а сюда не приводит вообще никогда: он влияет только на валюту/суммы, но не на состав `products`.

Для Strapi-фаннелов (без `layout`) серверного guard-а нет — там пустые подписки действительно дают бесконечный лоадер; это прямо описано в комментарии `renderCodeSalesHop.tsx:53-62`.

### 6) Флаги и env, которые это меняют

Того, что переключало бы сам фолбэк, **нет**. Он безусловный. Что рядом:

- `BILLING_PRODUCTS_TIMEOUT_MS = 5_000` — константа в коде, **не** env (`getMulticurrencyProducts.ts:21`).
- `NEXT_PUBLIC_IP_API_KEY` — ключ ip-api (`useQueryCountry.ts:41`). Битый/заблокированный гео = гарантированный USD-фолбэк (см. п.1).
- `NEXT_PUBLIC_LIVE_MODE` → `FORCE_CACHE_ONLY_PROD` (`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/config/constants/common.ts:128-135`): `force-cache` vs `no-store` для Strapi-фетча `resolveCommerce`. Влияет на то, насколько свежи **авторские** цены, т.е. на качество фолбэка.
- FTC-флаги (`us_pricing_now_then` / `ftc_soft`, через `useFtcPricing()` в `general-english/layouts/SalesLayout.tsx:38`) — меняют только копи/раскладку дисклоузеров, не фолбэк.
- `?downsale=true` (`Sales.tsx:346-348`) — переключает набор продуктов, а значит и батч billing-запроса (свой independent all-or-nothing).
- `_timer` (`Sales.tsx:~740`) — дебаг-оверрайд длительности таймера.
- Никакого GrowthBook-флага вокруг multicurrency я не нашёл (grep по `packages/config` на `multicurrency|multi_currency` — пусто).

---

## How to port → `/Users/uvarovalexandr/myProject/funnel-engine`

### Что движок делает сейчас (прочитано)

1. `/Users/uvarovalexandr/myProject/funnel-engine/src/pricing.ts:45-51` — `mergeLivePrices` при неполном покрытии возвращает **`[]`**, а не `authored`. В комментарии `:28-35` это заявлено как сознательное расхождение с продом («Falling back to the AUTHORED prices was worse still, and was the behaviour here until now»).
2. `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/sales.ts:150` — `const plans = live.ok ? mergeLivePrices(activePlans, live.data) : []`, т.е. провал запроса → `[]`.
3. `/Users/uvarovalexandr/myProject/funnel-engine/src/render/sales.ts:185` — `if (ctx.plans.length === 0) return ''`: не рисуются ни карточки, ни `billingTerms`, ни **CTA** (CTA внутри той же функции, `:294-300`).
4. `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/post-purchase.ts:277-291` — `hopPlans` возвращает `null` при провале/неполноте → апселл-хоп скипается.

Итог: движок сегодня ведёт себя **строго иначе, чем прод** — прод показывает авторские цены, движок показывает пустоту.

### Что менять, чтобы совпасть с продом

**(A) `mergeLivePrices` — `/Users/uvarovalexandr/myProject/funnel-engine/src/pricing.ts:45`**

Заменить `return []` на `return authored`. Точная семантика прода:

```ts
export function mergeLivePrices(authored: Plan[], live: BillingPlan[]): Plan[] {
  const byId = new Map((live ?? []).map((p) => [p.product_id, p]))
  // all-or-nothing на БАТЧ: одна непокрытая позиция — вся пачка остаётся
  // авторской, чтобы не смешать валюты на одной странице
  if (authored.some((p) => !byId.has(p.productId))) {
    console.error('billing products incomplete, keeping authored prices', {
      missing: authored.filter((p) => !byId.has(p.productId)).map((p) => p.productId),
    })
    return authored
  }
  …
}
```

Дополнительно, чтобы совпасть с `mappingBillingPlans.ts:29-52` **точно**: движок сейчас мержит ещё и `billing_period_in_days` (`pricing.ts:62`), а прод — **нет**. Если цель — паритет, `billingPeriodInDays` из мержа убрать (прод считает cadence авторской); если сохранить — задокументировать как осознанное расхождение.

**(B) `salesContext` — `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/sales.ts:150`**

```ts
const plans = live.ok ? mergeLivePrices(activePlans, live.data) : activePlans
if (!live.ok) console.error('billing products failed, falling back to authored prices', live)
```

Прод так же не различает «упало» и «покрыло частично» — оба исхода дают авторские цены (`getMulticurrencyProducts.ts:74` + `mappingBillingPlans.ts:22`).

**(C) `renderPlans` — `/Users/uvarovalexandr/myProject/funnel-engine/src/render/sales.ts:185`**

После (A)+(B) `plans.length === 0` перестаёт означать «billing молчит» и начинает означать только «в конфиге нет планов». Guard можно оставить как страховку, но его смысл меняется — комментарий на `:176-184` надо переписать. Прод в этой точке не рендерит пустоту вообще: пустой набор планов у него — это **404 на сервере** (`renderCodeSalesHop.tsx:66-73`), а не тихая страница. Паритетный вариант: если `activePlans.length === 0` в конфиге — отдавать 404 из роута (а не пустую секцию из рендерера).

**(D) `hopPlans` — `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/post-purchase.ts:277-291`**

Прод для апселл/даунселл-хопов делает то же самое, что и для sales: `mappingBillingPlans` над авторскими продуктами хопа (те же вызовы через `useMultiCurrency`/`Sales`-подобную обвязку в `Upsell.tsx` / `UpsellDownsell.tsx`), т.е. **скип хопа из-за billing-а не происходит** — хоп показывается по авторской цене. Чтобы совпасть: `if (!live.ok) return plans` и `return merged` без обнуления. Скип оставить только для случая «у хопа нет авторских планов» (это и есть продовый dead-paywall guard на upsell/downsell-хопах, `renderCodeSalesHop.tsx:53-62` описывает их поведение).

**(E) Валюта при фолбэке — что делать движку**

Прод не делает никакой конвертации и никак не помечает страницу. Он показывает `currencyCode`/`currencySymbol` **авторской** записи как есть. Для `general-english` это `USD` / `$` (`/Users/uvarovalexandr/myProject/funnel-engine/funnels/general-english/sales.json:11-12` уже так и устроен). Соответственно движку:

1. **Оставить авторские `currencyCode` + `currencySymbol`**, ничего не пересчитывать. Никакого «взять локальную валюту и поделить по курсу» — курса ниоткуда нет, и прод этого не делает.
2. **Форматировать по авторской валюте**, а не по гео. `formatPrice` (`/Users/uvarovalexandr/myProject/funnel-engine/src/pricing.ts:118-125`) уже берёт формат из `currencyCode` плана — этого достаточно, менять не нужно. Важно только не подмешивать сюда country-based формат.
3. **Никакого видимого баннера/нотиса** — иначе движок разойдётся с продом (и, кстати, покажет посетителю то, чего прод не показывает).
4. **Оставить серверный лог** — это единственный сигнал, который есть в проде (там это Faro `'getBillingProducts API error — falling back to Strapi prices'`, `reportBillingProductsError.ts:19-20`). Если у движка есть Faro/Sentry-канал, стоит воспроизвести и схлопывание transport-ошибок в один репорт на сессию (`:136-147`) — но это уже nice-to-have.
5. **Чекаут не блокировать.** Ордер несёт только `billing_plan` + `currency` (`Checkout.ts:1190-1191`), суммы в нём нет — фолбэк-цена оплатима. Но `currency`, которую движок отправит в ордер, при фолбэке будет **авторской (USD)**, а не гео-валютой — ровно как в проде (`currency = total?.currencyCode`, `Checkout.ts:1049`). Это и есть источник расхождения «карточка vs списание»; воспроизводить надо именно так, а не «угадывать» локальную валюту.
6. Продовый эквивалент гейта PROMOVA-428 (`getIsPricingSettled`) движку **не нужен**: там гейт существует потому, что цены доезжают асинхронно на клиенте и Solidgate-форма может смонтироваться на USD-тотале. В движке цены разрешаются на сервере до первого байта — состояния «в полёте» нет. Единственное, что стоит перенести из этого файла, — правило «фолбэк открывает гейт, а не закрывает его»: провал billing-а не должен вести к отсутствию CTA.

### Минимальный чек-лист правок

| Файл:строка | Сейчас | Должно быть |
|---|---|---|
| `/Users/uvarovalexandr/myProject/funnel-engine/src/pricing.ts:47-51` | `return []` при неполном покрытии | `return authored` (all-or-nothing на батч сохраняется) |
| `/Users/uvarovalexandr/myProject/funnel-engine/src/pricing.ts:62` | мержит `billing_period_in_days` | убрать (прод cadence не мержит) — либо задокументировать расхождение |
| `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/sales.ts:150` | `: []` при `!live.ok` | `: activePlans` |
| `/Users/uvarovalexandr/myProject/funnel-engine/src/render/sales.ts:185` | `plans.length === 0 → ''` (нет карточек и нет CTA) | оставить только как страховку от пустого конфига; переписать комментарий; пустой конфиг → 404 в роуте |
| `/Users/uvarovalexandr/myProject/funnel-engine/src/routes/post-purchase.ts:283-291` | `null` → скип хопа | `return plans` / `return merged`; скип только при пустом авторском наборе |

### Чего я НЕ смог подтвердить

- Реальные значения `amount`/`firstPayment`/... продовых планов `general-english-sales` — они в базе Strapi, не в коде (см. п.3).
- Поведение TanStack Query на HTTP 4xx/5xx-ветке (`return undefined` → ошибка → дефолтные 3 ретрая): выведено из версии библиотеки и отсутствия override-а `retry`, кодом/тестами в репозитории не покрыто.
- Что именно отдаёт бэкенд `/v1/billing/products`, когда `country_code` не передан (гео упало) — в коде запрос просто уходит без параметра (`getMulticurrencyProducts.ts:47`).
