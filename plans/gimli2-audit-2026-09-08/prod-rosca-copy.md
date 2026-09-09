# Прод-копия ROSCA/FTC дисклеймеров: точный текст + точные условия показа

Репозиторий: `/Users/uvarovalexandr/myProject/promova.com_monorepo`. Только чтение.
Все пути ниже — абсолютные от корня репо (префикс `packages/…`).

---

## 0. Короткий вывод (для порта в Hono/HTMX)

На **живой code-funnel странице `/sierra/general-english` `SubscriptionInfo` вообще не
рендерится** — code-funnel layout полностью подменяет Strapi-секции
(`pages/Sales/Sales.tsx:220` `if (layout) return layout`). Значит все четыре
дисклеймера из `SubscriptionInfo/*` — это **Strapi-путь**, а не то, что видит
покупатель на `/sierra`.

На `/sierra` реально показываются ровно два юридических текста:

| Условие | Что видно | Где |
|---|---|---|
| FTC-флаг **OFF** | on-page строка `copy.billingTerms` | `code-funnels/money/general-english/layouts/SalesLayout.tsx:346-359` |
| FTC-флаг **ON** | на странице ROSCA-строки **нет**; вместо неё FTC-нота + per-card now/then, а полный дисклеймер — уже внутри чекаута (`UsPricingCheckoutDisclaimer`) | `SalesLayout.tsx:219-223`, `Checkout/CheckoutForm/CheckoutForm.tsx:327-332` |
| Down-sale (закрыл чекаут не купив) | своя строка из `copy.disclosure*`, **флаги FTC не проверяются вообще** | `layouts/SalesDownsaleLayout.tsx:129-148` |

`ActivationFeeNote` на code-funnel пути **не рендерится нигде** — он живёт только
внутри `SubscriptionInfo/*`.

---

## 1. Verbatim-текст компонентов `SubscriptionInfo/*`

Все четыре — Strapi-путь. Все внутри `<Trans>` из `@lingui/react/macro`, т.е.
**локализуются**, кроме отдельно отмеченного.

### 1.1 `NoIntroSubscriptionDisclaimer.tsx`

Файл: `packages/features/FunnelBuilder/components/common/sales-page/SubscriptionInfo/NoIntroSubscriptionDisclaimer.tsx`

Обёртка `<Trans>` — строки **38-54**. Verbatim (склеенный текст, `{' '}` = пробел):

> By continuing you agree you will automatically be charged **{formattedPrice} every {billingCyclePeriod}** until you cancel in settings. Learn more about cancellation and refund policy in [Subscription Terms](termsLink).

Разметка внутри:
- `<strong className={styles.strong}>{formattedPrice} every {billingCyclePeriod}</strong>` — строки 40-42
- `<a href={termsLink} target="_blank" rel="noopener noreferrer" className={styles.link}>Subscription Terms</a>` — строки 45-52
- финальная точка вне `<a>` — строка 53

Плейсхолдеры → поля плана:
| Плейсхолдер | Источник |
|---|---|
| `formattedPrice` | `handleLocalizeCurrency({ price: amount, currencyCode, currencySymbol })` — строки 30-34; `amount` = `Subscription.amount` (minor units) |
| `billingCyclePeriod` | `Subscription.billingCyclePeriod` (сырая строка биллинг-API, **без** `translate()`) |
| `termsLink` | из диспетчера: локале-префиксный `TermsRoutes.subscriptionTerms` |

Локализация: **внутри `<Trans>`** → локализуется. `oneDollarCharge` + `showActivationFee`
пробрасываются в `ActivationFeeNote` (строки 55-57).

### 1.2 `TwoForOneSubscriptionDisclaimer.tsx`

Файл: `…/SubscriptionInfo/TwoForOneSubscriptionDisclaimer.tsx`

**Ранний return:** `if (!rebillPayment || !extendedPeriod) return null` — строка **36**.
То есть на 2-for-1 правиле без `rebillPayment`/`extendedPeriod` дисклеймера НЕТ вообще.

Обёртка `<Trans>` — строки **46-68**. Verbatim:

> By continuing you agree that after the end of **{trialDuration} {trialPeriod}**, which includes a free **{extendedPeriod}** extension, you will automatically be charged **{formattedPrice} every {billingCyclePeriod}** until you cancel in settings. Learn more about cancellation and refund policy in [Subscription Terms](termsLink).

Разметка:
- `<strong>{trialDuration} {trialPeriod}</strong>` — строки 48-50
- `<strong>{extendedPeriod}</strong>` — строка 52
- `<strong>{formattedPrice} every {billingCyclePeriod}</strong>` — строки 54-56
- ссылка — строки 59-66, точка вне ссылки — строка 67

Плейсхолдеры → поля плана:
| Плейсхолдер | Источник |
|---|---|
| `formattedPrice` | `handleLocalizeCurrency({ price: rebillPayment, … })` — строки 38-42. **Это `rebillPayment`, НЕ `amount`** |
| `trialDuration` | `Subscription.trialDuration` |
| `trialPeriod` | ⚠️ здесь передаётся **СЫРОЙ** `trialPeriod`, без `translate()` — см. `SubscriptionInfo.tsx:107` (`trialPeriod={trialPeriod}`), в отличие от Intro/NowThen, куда идёт `trialPeriodString` |
| `extendedPeriod` | `Subscription.extendedPeriod` |
| `billingCyclePeriod` | `Subscription.billingCyclePeriod` |

Локализация: внутри `<Trans>` → локализуется.

### 1.3 `UsNowThenDisclaimer.tsx`

Файл: `…/SubscriptionInfo/UsNowThenDisclaimer.tsx`

Doc-комментарий (строки 25-30) verbatim:
```
/**
 * "Now / then" subscription disclaimer shown when the US_PRICING_NOW_THEN
 * GrowthBook flag is on. `billingCyclePeriod` / `trialPeriod` are raw CMS
 * strings interpolated into the localized copy, mirroring
 * IntroSubscriptionDisclaimer. See PRMV-17769.
 */
```

**Ранний return:** `if (!introPrice || !fullPrice || !billingCyclePeriod) return null` — строка **55**.

**Вывод периода** (строки 57-66) — это критично для порта:
```ts
const period =
  billingPeriodInDays != null && billingPeriodInDays < 28
    ? `${billingPeriodInDays} days`
    : trialPeriod
      ? `${trialDuration} ${trialPeriod}`
      : billingCyclePeriod
```
Комментарий к нему (строки 57-60) verbatim:
```
// For short intro periods (<= 28 days) express the period as a day count
// ("7 days"); otherwise use the trial period (matching
// IntroSubscriptionDisclaimer's "{trialDuration} {trialPeriod}" format) or
// fall back to the subscription billing cycle. See PRMV-17769.
```
⚠️ Литерал `days` (строка 63) — **hardcoded English**, вне `<Trans>`; он попадает в
локализованный текст как есть.

Обёртка `<Trans>` — строки **70-93**. Verbatim (кавычки вокруг Continue — прямые `"`):

> By clicking "Continue" you agree to an introductory offer of **{introPrice}** for the **first {period}**. If you don't cancel prior to the end of the {period} introductory offer, you will automatically be charged the **full price of {fullPrice} every {billingCyclePeriod}** until you cancel in settings. Learn more about cancellation and refund policy in [Subscription Terms](termsLink).

Разметка:
- `<strong className={styles.strong}><span className={styles.price}>{introPrice}</span></strong>` — строки 72-74
- `<strong className={styles.strong}>first {period}</strong>` — строка 75
- `<strong className={styles.strong}>full price of <span className={styles.price}>{fullPrice}</span> every {billingCyclePeriod}</strong>` — строки 78-81
- ссылка — строки 84-91, точка — строка 92

Плейсхолдеры → поля плана:
| Плейсхолдер | Источник |
|---|---|
| `introPrice` | `handleLocalizeCurrency({ price: firstPayment, … })` — строки 44-48 → `Subscription.firstPayment` |
| `fullPrice` | `handleLocalizeCurrency({ price: secondPayment, … })` — строки 49-53 → `Subscription.secondPayment` (**не `amount`, не `rebillPayment`**) |
| `period` | производное из `billingPeriodInDays` / `trialDuration` + `trialPeriod` / `billingCyclePeriod` (см. выше) |
| `billingCyclePeriod` | `Subscription.billingCyclePeriod` |
| `trialPeriod` | из диспетчера — `translate(trialPeriod || '')` (`SubscriptionInfo.tsx:47,64`), дефолт `''` (строка 36) |

Локализация: внутри `<Trans>` → локализуется. `.price` (`subscription_info.module.scss:14-17`)
делает цифры чёрными и на 1px крупнее.

### 1.4 `ActivationFeeNote.tsx`

Файл: `…/SubscriptionInfo/ActivationFeeNote.tsx`

Гейт (строки 18-21):
```ts
const isDisclaimerEnabled = useFeatureIsOn(DISCLAIMER_FOR_US_1USD)

if (!isDisclaimerEnabled || !oneDollarCharge || !oneDollarCharge.amountMinor)
  return null
```
Плюс ещё один: `if (!formattedFee) return null` — строка **29**.

Обёртка: `<><br /><Trans>…</Trans></>` — строки **32-41**. Verbatim:

> A non-refundable **one-time {formattedFee} activation fee** will also be charged to your payment method upon checkout.

Разметка: `<strong className={styles.strong}>one-time {formattedFee} activation fee</strong>` — строки 36-38. Перед текстом обязательный `<br />` (строка 33).

Плейсхолдеры → поля плана:
| Плейсхолдер | Источник |
|---|---|
| `formattedFee` | `handleLocalizeCurrency({ price: oneDollarCharge.amountMinor, currencyCode: oneDollarCharge.currency, currencySymbol: oneDollarCharge.currencySymbol })` — строки 23-27 |

Локализация: внутри `<Trans>` → локализуется.

### 1.5 Для сравнения — `IntroSubscriptionDisclaimer.tsx` (подтверждаю то, что уже установлено)

Файл: `…/SubscriptionInfo/IntroSubscriptionDisclaimer.tsx`, `<Trans>` — строки **42-60**.
Текст совпадает с тем, что дал вызывающий. `formattedPrice` = `amount` (строки 34-38),
`trialPeriod` приходит уже как `translate(trialPeriod || '')`.

---

## 2. Пункт 5 отдельно: `ActivationFeeNote` — флаг и поле

- **Флаг:** `DISCLAIMER_FOR_US_1USD` = строковый ключ **`'disclaimer_for_US_1usd'`**
  — `packages/config/constants/remote_config.ts:39`. Дефолт `false` —
  `remote_config.ts:134` (`[DISCLAIMER_FOR_US_1USD]: false`). Читается через
  `useFeatureIsOn` (GrowthBook) — `ActivationFeeNote.tsx:5,18`.
  Единственные потребители флага в репо — `remote_config.ts` и `ActivationFeeNote.tsx`
  (проверено grep'ом по `packages/` + `apps/`).
- **Поле плана:** `oneDollarCharge` — `types/sales_page.ts:96`, тип
  `OneDollarCharge` (`sales_page.ts:57-61`):
  `amountMinor` ← `OneDollarChargeResponse['amount_minor']`,
  `currency` ← `['currency']`, `currencySymbol` ← `['currency_symbol']`.
  Триггер — именно `oneDollarCharge.amountMinor` (truthy).
- **Ещё один гейт:** пропс `showActivationFee`, по умолчанию `false` в каждом
  дисклеймере. Все три sales-layout'а передают `showActivationFee` (без значения =
  `true`), а `PreCheckoutUpsellModal` — **нет** (`PreCheckoutUpsellModal.tsx:176`
  `<SubscriptionInfo {...subscription} />`), значит в pre-checkout upsell-модалке
  activation-fee строки не будет никогда.

---

## 3. Какие layout'ы монтируют `SubscriptionInfo` и под каким гейтом

Полный список JSX-монтирований в `packages/` + `apps/` (без тестов/сторей) — три
запрошенных плюс ещё пять.

### 3.1 Три запрошенных — **все три под одним и тем же гейтом `!isUsPricingNowThen`**

**a) `components/common/sales-page/Plans/Plans.tsx`** — флаг на строке 43
(`const { isOn: isUsPricingNowThen, variant } = useFtcPricing()`), гейт строки **79-81**:
```jsx
{!isUsPricingNowThen && (
  <SubscriptionInfo {...currentSubscription} showActivationFee />
)}
```

**b) `components/common/sales-page/sections/Plans/Plans.tsx`** — флаг на строке 59,
гейт строки **259-261**:
```jsx
{!isUsPricingNowThen && (
  <SubscriptionInfo {...currentSubscription} showActivationFee />
)}
```

**c) `components/common/sales-page/sections/PlansWithTimer/PlansWithTimer.tsx`** —
флаг на строке 68, гейт строки **249-253**:
```jsx
{!isUsPricingNowThen && (
  <div className={styles.description_wrap}>
    <SubscriptionInfo {...currentSubscription} showActivationFee />
  </div>
)}
```

### 3.2 Достижим ли `UsNowThenDisclaimer` из какого-либо монтирования? — ДА, но не с sales-page

Гейт `!isUsPricingNowThen` в трёх layout'ах выше делает FTC-ветку внутри диспетчера
(`SubscriptionInfo.tsx:57-73`) недостижимой **с sales-страницы**. То же и для
четвёртого sales-монтирования:

- `sections/QuantumStaticSection/sections/QuantumPlansSection/QuantumPlansSection.tsx`
  — флаг на строке 45, гейт строки **112-114**: `{!isUsPricingNowThen && (…)}`. Тоже
  недостижимо.

Но **пять монтирований БЕЗ гейта** — из них `UsNowThenDisclaimer` достижим:

| Файл:строка | Гейт |
|---|---|
| `components/common/sales-page/PreCheckoutUpsellModal/PreCheckoutUpsellModal.tsx:176` | нет FTC-гейта; в файле нет ни `useFtcPricing`, ни `isUsPricingNowThen` (проверено grep'ом). Монтируется из `pages/Sales/Sales.tsx:1951` под `{upsellSubscription && (…)}` |
| `features/CheckoutBuilder/components/common/PaymentStep/PaymentStep.tsx:516-519` | без гейта (внутри блока способа оплаты) |
| `features/CheckoutBuilder/components/common/PaymentStep/PaymentStep.tsx:582` | без гейта (внутри card-form wrapper) |
| `features/CheckoutBuilder/components/common/PaymentSection/PaymentSection.tsx:392` | без гейта; комментарий выше — `{/* Subscription disclaimer */}` |
| `features/Checkout/CheckoutDownsell/CheckoutDownsell.tsx:388-391` | без гейта; данные не из `currentSubscription`, а `{...multiCurrencyProducts?.[0]?.attributes}` |

**Итого по пункту 2:** ни один из четырёх *sales-page* layout'ов не достигает
`UsNowThenDisclaimer`; на sales-странице он — мёртвая ветка. Достижим он только с
checkout-поверхностей (CheckoutBuilder `PaymentStep`/`PaymentSection`,
`CheckoutDownsell`) и из `PreCheckoutUpsellModal`. **Не подтверждено кодом:** живут ли
`CheckoutBuilder`-поверхности в проде и попадает ли туда трафик — это вне того, что
можно доказать из этих файлов.

Прямое документальное подтверждение мёртвой sales-ветки — комментарий в шаблоне
code-funnel'а, `code-funnels/money/_template/layouts/SalesLayout.tsx:435-438` verbatim:
```
FTC: this page-level line is DROPPED when the flag is on — the live
page does the same (`{!isUsPricingNowThen && <SubscriptionInfo …/>}`
in sections/Plans/Plans.tsx + PlansWithTimer.tsx), because under FTC
the renewal terms are carried per-card by the now/then line plus the
checkout disclaimer.
```

---

## 4. Что реально рендерит живой code-funnel на `/sierra`

### 4.1 Трассировка

1. `code-funnels/money/moneyRegistry.ts:22` — `'general-english': () => import('./general-english')`.
   Модуль зарегистрирован, значит `/sierra` берёт code-путь. Doc там же
   (`moneyRegistry.ts:5-9`): «Each live money route (`/sierra`,`/golf`,`/delta`,`/alpha`)
   server-branches on `funnel_slug` and calls `getMoneyModule`».
2. `code-funnels/money/general-english/index.ts:27-35` — `funnelSlug: 'general-english'`,
   `salesSlug: 'general-english'`, `sales.layout: GeneralEnglishSalesLayout`,
   `commerce.ruleSlug: 'general-english-sales'`.
3. `pages/Sales/Sales.tsx:215-220` — **`renderSalesPage()` начинается с `if (layout) return layout`**:
```
const renderSalesPage = () => {
  // Code-funnel money path (Part 3): a code-authored layout replaces the
  // Strapi sections entirely. It is rendered inside SalesPageContext.Provider
  // (below), so it consumes useSalesPageContext() for cards/CTAs. This is a
  // no-op for every Strapi funnel (`layout` undefined).
  if (layout) return layout
```
   Значит `ConceptAdapter`/`WithTimerSalesPage`/`DefaultSalesPage` — и вместе с ними все
   четыре Strapi-монтирования `SubscriptionInfo` — **не выполняются**.
4. `Sales.tsx:1961-1965` — `suppressChrome` дополнительно снимает всю обвязку:
```
{suppressChrome ? (
  // Code-funnel money path (Part 3): the code layout owns the whole
  // page — no Header/Timer/EnglishTestResult/LegalInfo or wrappers.
  renderSalesPage()
```

**Ответ на пункт 3:** `/sierra/general-english` не рендерит ни один из трёх (четырёх)
layout'ов; он рендерит свой собственный `GeneralEnglishSalesLayout`, который сам
выводит billing-terms строку.

Единственный остаток Strapi-`SubscriptionInfo`, который технически ещё живёт на этой
странице — `PreCheckoutUpsellModal` (`Sales.tsx:1951-1957`), но он рендерится только
если `upsellSubscription` truthy (из `usePreCheckoutUpsell`, `Sales.tsx:1095`).
**Не подтверждено кодом:** сконфигурирован ли pre-checkout upsell для
`general-english` — это Strapi-конфиг, не код.

### 4.2 On-page ROSCA-строка code-funnel'а

Файл: `code-funnels/money/general-english/layouts/SalesLayout.tsx`, строки **346-359**:
```jsx
{!isFtcPricing &&
  !!(hasAnyIntro || currentSubscription) &&
  !!selectedPlan && (
    <p className={styles.billingTerms}>
      {copy.billingTerms
        .replace(
          '{price}',
          formatMoney(selectedPlan.amount, selectedPlan.currencySymbol)
        )
        .replace(
          '{period}',
          selectedPlan.fullPeriodLabel ?? selectedPlan.billingCyclePeriod
        )}
    </p>
  )}
```

Текст (`code-funnels/money/general-english/copy.ts:235-236`) verbatim:
```
billingTerms:
  'Renews at {price} {period} until you cancel. Cancel anytime in Settings.',
```

Условия показа целиком:
- `!isFtcPricing` — `isFtcPricing` = `useFtcPricing().isOn` (`SalesLayout.tsx:38`)
- `hasAnyIntro || currentSubscription` — `hasAnyIntro` (строки 103-107) = есть план с
  `firstPayment > 0 && firstPayment < amount`
- `selectedPlan` (строки 92-99) — план **из `products[]` по `productId` выбора**, с
  fallback на best-value, потом на `products[0]`. Комментарий (строки 90-91) verbatim:
  «Currency-safe page-level plan (ROSCA line): resolve from products[] via the
  selection's productId — never currentSubscription.amount (base currency).»

Подстановки:
| Токен | Источник |
|---|---|
| `{price}` | `formatMoney(selectedPlan.amount, selectedPlan.currencySymbol)` — `formatMoney.ts:5`: `` `${symbol}${(cents / 100).toFixed(2)}` `` (minor units) |
| `{period}` | `selectedPlan.fullPeriodLabel ?? selectedPlan.billingCyclePeriod` |

### 4.3 FTC-ветка на code-funnel странице

Когда `isFtcPricing === true`, on-page ROSCA-строка исчезает, а появляются:

**a) FTC-нота перед планами** — `SalesLayout.tsx:219-223`:
```jsx
{isFtcPricing && ftcVariant === 'hard' && (
  <p className={styles.ftcNote} data-cf-ftc-no-payment>
    {copy.ftcNoPaymentNote}
  </p>
)}
```
Текст (`copy.ts:238-239`) verbatim — обратите внимание на **en-dash `–`**, не hyphen:
```
ftcNoPaymentNote:
  "No payment on this step – you'll review your subscription and confirm next",
```
Показ только при `variant === 'hard'` (флаг `us_pricing_now_then`).

**b) Per-card now/then строка** — `SalesLayout.tsx:296-311`, гейт `showNowThen`
(строки 240-244):
```ts
const showNowThen =
  isFtcPricing &&
  plan.paymentMode !== PaymentMode.noIntroSubscription &&
  !!plan.firstPayment &&
  !!rebillPrice &&
  !!plan.billingCyclePeriod
```
Текст (`copy.ts:237`) verbatim: `nowThenLine: '{now} now, then {then} every {period}'`.
Подстановки: `{now}` ← `formatMoney(plan.firstPayment, …)`,
`{then}` ← `formatMoney(rebillPrice, …)`, `{period}` ← `plan.billingCyclePeriod`.
`rebillPrice` = `ftcRebillPrice(plan)` (строки 65-70): `rebillPayment` на 2-for-1,
иначе `secondPayment` — «never `amount`» (комментарий строки 63-64).

**c) CTA переключается** — строки 362-364 и 569-572: `{isFtcPricing ? copy.ctaFtc : copy.cta}`.
`copy.ts:240` → `ctaFtc: 'Continue'`; `copy.ts:241` → `cta: 'Get my results & plan'`.

**d) Полный дисклеймер под FTC уезжает в чекаут** — `Checkout/CheckoutForm/CheckoutForm.tsx:327-332`:
```jsx
{isUsPricingNowThen && (
  <UsPricingCheckoutDisclaimer
    total={total}
    variant={ftcCheckoutVariant}
  />
)}
```
где (`CheckoutForm.tsx:191-200`):
```ts
const { isOn: isFunnelFtcOn, variant: funnelFtcVariant } = useFtcPricing()
const { isOn: isLandingsFtcOn, variant: landingsFtcVariant } = useLandingsFtcPricing()
const isUsPricingNowThen = isFunnelFtcOn || isLandingsFtcOn
// Soft wins if either layer reports soft — that copy is the looser legal one.
const ftcCheckoutVariant: 'hard' | 'soft' =
  (isFunnelFtcOn && funnelFtcVariant === 'soft') ||
  (isLandingsFtcOn && landingsFtcVariant === 'soft')
    ? 'soft'
    : 'hard'
```
Плюс кнопка: `if (isUsPricingNowThen) return _(msg`subscribe`)` — `CheckoutForm.tsx:211`.

**Важно:** при FTC OFF `CheckoutForm` **никакого** дисклеймера не рендерит — на
не-FTC пути весь ROSCA-текст живёт только на странице (`copy.billingTerms`).
Комментарий в `general-english/index.ts:22-23` («the verbatim ROSCA disclosure +
"Subscribe" button are the reused CheckoutForm's») **верен только для FTC-ветки** —
это расхождение комментария с кодом, стоит отметить при порте.

### 4.4 `UsPricingCheckoutDisclaimer` — verbatim, это то, что реально видит FTC-покупатель на `/sierra`

Файл: `packages/features/Checkout/CheckoutForm/components/UsPricingCheckoutDisclaimer/UsPricingCheckoutDisclaimer.tsx`

**Ранние return'ы:** строка **47** `if (!firstPayment || !secondPayment || !billingCyclePeriodText) return null`;
строка **60** `if (!formattedNow || !formattedThen) return null`.

**Период** (строки 66-71) — та же формула, что в `UsNowThenDisclaimer`:
```ts
const introPeriod =
  billingPeriodInDays != null && billingPeriodInDays < 28
    ? `${billingPeriodInDays} days`
    : trialPeriodText
      ? `${trialDuration} ${trialPeriodText}`
      : billingCyclePeriodText
```

#### variant `'soft'` (флаг `ftc_soft_changes`, G8) — строки 78-107, **RAW, вне `<Trans>`**

> By subscribing you agree that if you don't cancel at least 24 hours prior to the end of the {introPeriod} introductory offer, you will automatically be charged the full price of **{formattedThen}** every **{billingCyclePeriodText}** until you cancel in settings. Learn more in [Subscription Terms](subscriptionTerms).

(в JSX апостроф — `&apos;`, строка 90. `{formattedThen}` и `{billingCyclePeriodText}`
обёрнуты в `<strong className={styles.price}>` — строки 93-94.)

Комментарий-обоснование (строки 85-89) verbatim:
```
/*
 * Geo-gated G8 English copy (configured on the GrowthBook flag), so
 * the scaffold is intentionally not wrapped in <Trans>. Mirrors the
 * hard branch below.
 */
```

#### variant `'hard'` (флаг `us_pricing_now_then`, US/CY/UA) — строки 109-139, **RAW, вне `<Trans>`**

> By selecting a payment method and proceeding, you agree you will be charged an introductory offer of **{formattedNow}** for the {introPeriod}. If you don't cancel prior to the end of the {introPeriod} introductory offer, you will automatically be charged the full price of **{formattedThen}** every {billingCyclePeriodText} until you cancel in settings. See our [Subscription Terms](subscriptionTerms).

(`{formattedNow}`/`{formattedThen}` в `<span className={styles.price}>`, строки 124 и 127.
Точка после `{introPeriod}` стоит отдельной строкой 125 — в рендере это `…for the 7 days.`
без пробела.)

Комментарий-обоснование (строки 115-121) verbatim:
```
/*
 * US-only English copy (geo-gated on the GrowthBook flag), so the scaffold
 * is intentionally not wrapped in <Trans>. `introPeriod` /
 * `billingCyclePeriodText` are the English source of the period label
 * (resolved via getMessageSource), so the whole disclaimer stays English
 * even on non-English interface locales. See PRMV-17780 / PRMV-17775.
 */
```

Плейсхолдеры → `total` (`Total`, строки 33-42):
| Плейсхолдер | Источник |
|---|---|
| `formattedNow` | `handleLocalizeCurrency({ price: firstPayment, … })` (строки 49-53) |
| `formattedThen` | `handleLocalizeCurrency({ price: secondPayment, … })` (строки 54-58) |
| `billingCyclePeriodText` | `getMessageSource(billingCyclePeriod)` — строка 44 |
| `trialPeriodText` | `getMessageSource(trialPeriod)` — строка 45 |
| `subscriptionTerms` | локале-префиксный `TermsRoutes.subscriptionTerms` — строки 73-76 |

`getMessageSource` (`packages/utils/getMessageSource.ts:11-17`) возвращает `message ?? id`
Lingui-дескриптора, т.е. **английский source** — специально, чтобы период не был
переведён внутри английского скелета (doc-комментарий строки 3-10).

---

## 5. Down-sale: `SalesDownsaleLayout.tsx`

Файл: `code-funnels/money/general-english/layouts/SalesDownsaleLayout.tsx`

**Проверяет ли FTC-флаги? — НЕТ.** В файле нет ни `useFtcPricing`, ни `useLandingsFtcPricing`,
ни `isFtcPricing`/`isUsPricingNowThen` (файл целиком 152 строки, импорты — строки 3-10:
`useSalesPageContext`, `useMoneyLocale`, `fontVariables`, `formatMoney`,
`buildLocalizedMoneyCopy`, styles). FTC-гейта нет ни на одном элементе.

⚠️ При этом doc-комментарий модуля (`general-english/index.ts:43-44`) утверждает
обратное: «Countdown chrome is FTC-gated inside the layout.» — в коде layout'а этого
гейта нет. Расхождение комментария с кодом.

**Рендерит ли disclosure? — ДА, две штуки.**

### 5.1 Pre-plan disclosure — строка **49**, БЕЗ условия
```jsx
<p className={styles.plansDisclosure}>{copy.plansDisclosure}</p>
```
Текст (`copy.ts:531`) verbatim: `plansDisclosure: 'Review and confirm before any payment.'`

### 5.2 Основной disclosure — строки **129-148**, гейт `!!currentSubscription`
```jsx
{!!currentSubscription && (
  <p className={styles.disclosure}>
    {copy.disclosureLead}{' '}
    <b>
      {formatMoney(
        currentSubscription.firstPayment,
        currentSubscription.currencySymbol
      )}
    </b>{' '}
    {copy.disclosureThen}{' '}
    <b>
      {formatMoney(
        currentSubscription.amount,
        currentSubscription.currencySymbol
      )}
    </b>{' '}
    {copy.disclosureEvery} {currentSubscription.billingCyclePeriod}{' '}
    {copy.disclosureTail}
  </p>
)}
```

Куски текста (`copy.ts:536-539`) verbatim:
```
disclosureLead: "By continuing you agree you'll be charged",
disclosureThen: 'today, then',
disclosureEvery: 'every',
disclosureTail: 'until you cancel. Cancel anytime in Settings.',
```

Собранный текст:

> By continuing you agree you'll be charged **{firstPayment}** today, then **{amount}** every {billingCyclePeriod} until you cancel. Cancel anytime in Settings.

Подстановки:
| Слот | Источник |
|---|---|
| первый `<b>` | `formatMoney(currentSubscription.firstPayment, currencySymbol)` |
| второй `<b>` | `formatMoney(currentSubscription.amount, currencySymbol)` — **`amount`, не `secondPayment`/`rebillPayment`** |
| период | `currentSubscription.billingCyclePeriod` (raw) |

⚠️ Отличия от sales-страницы, важные для порта:
- Down-sale строка **всегда «now/then»**, даже когда `firstPayment === amount`
  (в отличие от карточек, где `hasIntro` = `firstPayment > 0 && firstPayment < amount`,
  строки 60-61). При плане без intro строка скажет «charged $X today, then $X every …».
- Она берёт `currentSubscription` напрямую, **не** `products[]`-resolved план (сравните
  с sales-страницей, где комментарий прямо предупреждает «never currentSubscription.amount
  (base currency)», `SalesLayout.tsx:90-91`). Потенциальная валютная нестабильность —
  но это наблюдение по коду, а не подтверждённый прод-баг.

Условие показа самого down-sale layout'а: `SalesDownsaleScope.tsx:34-37` —
`const { isDownSale } = useSalesPageContext(); if (isDownSale && DownsaleLayout) return <DownsaleLayout />`.
`isDownSale` флипается когда посетитель закрыл чекаут не купив; таймер практически
не срабатывает (`durationMinutes: 1440`, `index.ts:46`). QA-хук: `?downsale=true`
(`SalesDownsaleLayout.tsx:26-27`).

---

## 6. Что НЕЛЬЗЯ переводить — с кодом/комментарием

### 6.1 Явно задокументировано «оставлено на английском»

**a) `locales/buildLocalizedMoneyCopy.ts:17-23`** verbatim:
```
/**
 * Money-path localization scaffold. es/pt/de/fr/it overlays generated via
 * /quiz-translate (Version B "Rest of World" copy; machine-translated, pending
 * native review). The ROSCA/FTC legal disclosure strings (billingTerms,
 * ftcNoPaymentNote) and the attributed testimonial are intentionally left on
 * the EN base. Any locale with no entry falls through to the EN base.
 */
```

**b) В каждом из пяти overlay'ев (`es.ts` / `pt.ts` / `de.ts` / `fr.ts` / `it.ts`),
строки 8-11** — идентичный текст, verbatim (пример `it.ts:8-11`):
```
 * Left in English on purpose: the ROSCA auto-renewal disclosure (billingTerms)
 * and the FTC pre-payment note (ftcNoPaymentNote) are kept verbatim as legal
 * compliance text; the attributed App Store testimonial is never fabricated
 * into a translated quote. Brand names ("AI Tutor") are preserved.
```
Механически подтверждено: ключей `billingTerms` и `ftcNoPaymentNote` в overlay'ях нет
(есть только упоминания в этих комментариях), значит `deepMergeOverlay` оставляет
EN-базу.

**c) Весь блок `downsale` отсутствует в overlay'ях полностью.** Grep по `downsale`
во всех пяти файлах — ноль совпадений. То есть `plansDisclosure` и
`disclosureLead/Then/Every/Tail` остаются английскими на **любой** локали — но **по
умолчанию/по пропуску, а не по задокументированному решению**. Это разница между
sales-строкой (осознанно pinned) и down-sale строкой (просто не переведена).
Пометьте как решение, которое надо принять при порте, а не как установленное требование.

**d) `UsPricingCheckoutDisclaimer.tsx`** — два in-JSX комментария (строки 85-89 и
115-121, приведены выше) прямо говорят «intentionally not wrapped in `<Trans>`».
Обе ветки — **raw English JSX**, локализация невозможна by design; период тоже
принудительно английский через `getMessageSource`.

**e) `packages/utils/getMessageSource.ts:3-10`** verbatim — механизм пиннинга:
```
/**
 * Returns the English source text of a Lingui MessageDescriptor (its `message`,
 * falling back to `id`), or the string as-is. Use for US-only copy that must
 * stay English regardless of the active interface locale — e.g. the
 * `us_pricing_now_then` FTS price line / checkout disclaimer, where the
 * surrounding scaffold is hardcoded English and a localized period would
 * produce mixed-language output. See PRMV-17775.
 */
```

**f) `copy.ts:9-14`** — коммерческая инвариантность копирайта, verbatim:
```
 * COMMERCE-FIDELITY (Money-QA A2/A4): this object carries NO price/currency
 * literal, NO cadence word ("weekly/monthly/…"), and NO subscription-nature
 * claim ("one-time / not a subscription / auto-renews"). Price, period,
 * renewal and nature are read LIVE from the bound pricing rule in the layout
 * (`currentSubscription`/`currentPlan`) and interpolated into the tokenized
 * `billingTerms` / `nowThenLine`.
```
То есть: в HTMX-движке цена/период/каденция обязаны приходить из плана, а не из копий.

### 6.2 Скрытые непереводимые фрагменты внутри локализованных строк

- `UsNowThenDisclaimer.tsx:63` — литерал `` `${billingPeriodInDays} days` `` захардкожен
  по-английски и вставляется в `<Trans>`-текст. То же в
  `UsPricingCheckoutDisclaimer.tsx:68`.
- `SubscriptionInfo.tsx:47` — `translate(trialPeriod || '')` пропускает CMS-строку
  через Lingui; но в `TwoForOneSubscriptionDisclaimer` (`SubscriptionInfo.tsx:107`)
  передаётся **сырой** `trialPeriod`. Асимметрия в коде, без комментария-обоснования.
- `billingCyclePeriod` **нигде** не проходит через `translate()` в `SubscriptionInfo/*` —
  всегда сырая CMS/billing-API строка.
- `QuantumPlansSection.tsx:109` — `Get my plan` в кнопке написан без `<Trans>` (raw),
  в отличие от других layout'ов. Побочное наблюдение, не юридический текст.

---

## 7. Значения флагов (для конфигурации HTMX-движка)

| Константа | Строковый ключ | Дефолт | Файл:строка |
|---|---|---|---|
| `US_PRICING_NOW_THEN` | `us_pricing_now_then` | `false` | `packages/config/constants/remote_config.ts:42`, дефолт `:137` |
| `FTC_SOFT_CHANGES` | `ftc_soft_changes` | `false` | `remote_config.ts:43`, дефолт `:138` |
| `LANDINGS_FTC_SOFT_CHANGES` | `landings_ftc_soft_changes` | `false` | `remote_config.ts:45`, дефолт `:140` |
| `DISCLAIMER_FOR_US_1USD` | `disclaimer_for_US_1usd` | `false` | `remote_config.ts:39`, дефолт `:134` |

`useFtcPricing` (`packages/features/FunnelBuilder/hooks/useFtcPricing.ts:24-31`):
```ts
export const useFtcPricing = (): FtcPricingState => {
  const isHard = useUsPricingNowThen()
  const isSoft = useFtcSoftChanges()
  return {
    isOn: isHard || isSoft,
    variant: isSoft ? 'soft' : 'hard',
  }
}
```
Doc там же (строки 13-23) verbatim:
```
 * - `us_pricing_now_then` -> hard (US, CY, UA)
 * - `ftc_soft_changes`   -> soft (G8: UK, AU, CA, FR, LU, NL, CH, BE)
 *
 * Both flags are mutually exclusive at the GrowthBook targeting layer (geo
 * partitions Hard vs G8), but if both ever come back true at once, soft wins
 * because it carries the looser legal copy. See PRMV-17964.
```
Гео-таргетинг сконфигурирован **на самом GrowthBook-флаге** через атрибут `country`
(`useUsPricingNowThen.ts:10-12`, `useFtcSoftChanges.ts:11-14`) — в коде гео нет,
значит в HTMX-движке гео надо решать на своей стороне.

---

## 8. Форматирование денег — две разные функции

| Путь | Функция | Поведение |
|---|---|---|
| Strapi `SubscriptionInfo/*`, `UsPricingCheckoutDisclaimer` | `packages/utils/handleLocalizeCurrency.ts` | таблица per-currency форматов: позиция символа, разделители тысяч/дроби, 2 знака, пробел перед символом. `USD → symbolBeforeCommaDot` (`handleLocalizeCurrency.ts:60`) |
| code-funnel `general-english` | `code-funnels/money/general-english/formatMoney.ts:5` | `` `${symbol}${(cents / 100).toFixed(2)}` `` — всегда символ впереди, точка-десятичный, без разделителя тысяч |

Doc `formatMoney.ts:1-4` verbatim:
```
/**
 * The ONE money price formatter for general-english — amounts arrive in MINOR
 * units (cents); this only FORMATS the live value, never computes a price.
 */
```
Обе принимают **minor units**. Для порта: если движок должен совпасть с прод-code-funnel'ом
байт-в-байт — брать `formatMoney`; если с Strapi-путём — `handleLocalizeCurrency`.

---

## 9. Не подтверждено кодом (явно помечаю)

1. Живут ли `CheckoutBuilder` `PaymentStep`/`PaymentSection` и `CheckoutDownsell` в
   проде и есть ли на них трафик — из файлов не выводится. Утверждение
   «`UsNowThenDisclaimer` достижим» доказано только структурно (нет FTC-гейта на
   монтировании).
2. Сконфигурирован ли pre-checkout upsell (`upsellSubscription`) для
   `general-english` — это Strapi-конфиг (`UpsellModalConfig`), не код.
3. Какое реальное значение флагов у конкретного посетителя `/sierra` — GrowthBook,
   не репозиторий.
4. Что именно рендерит `general-english-b` / `general-english-g` / `english-hub` —
   не проверял, задание было про `general-english`. Их layout'ы упоминают ROSCA
   (grep), т.е. вероятно структура та же, но verbatim-текст не сверял.
5. `general-english/index.ts:22-23` и `:43-44` — два комментария, расходящихся с
   кодом (см. 4.3 и 5). Что именно верно — комментарий или код — из репо не
   определить; код есть код.
