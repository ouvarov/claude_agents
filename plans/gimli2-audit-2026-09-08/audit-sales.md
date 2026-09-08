# Аудит парити: SALES / DOWN-SALE / CHECKOUT / FTC — funnel-engine vs promova.com_monorepo

Дата: 2026-09-08. Прод-эталон — **code money funnel `general-english`** (`/sierra?funnel_slug=general-english`),
т.е. `renderCodeSalesHop` → живой `Sales.tsx` с `layout` + `suppressChrome` и layout-ом
`code-funnels/money/general-english/layouts/SalesLayout.tsx`. Strapi-ветка (19–21 dynamiczone-секций,
Elysium / WithTimer / DefaultSalesPage) для code-фаннелов **мертва**: `buildSyntheticSalesPage.ts:117`
ставит `data.sections = []`, а `Sales.tsx:1708` — `if (layout) return layout`.

Проверялось по коду, не по чеклистам. Расхождения с `plans/gimli2-sales-page-spec.md` отмечены отдельно.

---

## 1. Типы секций

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Набор секций code-фаннела | `packages/features/FunnelBuilder/code-funnels/money/general-english/layouts/SalesLayout.tsx:119-576` — 14 секций: hero, progress-chart, now→goal, ticker, ftc-note, plans, billing-terms, CTA, benefits, showcase-images, smallSteps, helpsWith, goals, rings, dayWorks, courses, withoutPromova, testimonial, chartFootnote, FAQ, stickyBar | `schema/sales.schema.ts:126-391` — 16 типов: hero, stats, bullets, chart, compare, rings, steps, testimonial, faq, secure-payment, rating-badges, guarantee, reviews, whats-inside, courses, plans; `funnels/general-english/sales.json:57-353` — 14 секций | **PARTIAL** | Тип-к-типу покрытие есть, но 3 прод-элемента не выражаются (ниже) |
| hero (goal-keyed headline + 3 чипа) | `SalesLayout.tsx:122-142`, `:45-55` | `src/render/sales.ts:84-104`; `sales.json:59-92` | **DONE** | Точный порт, включая fallback на каждый lookup |
| progress chart (SVG) | `SalesLayout.tsx:144-176` | `src/render/sales.ts:325-352` (`chart`) | **DONE** | Оба — статичная иллюстрация + footnote |
| now→goal comparison | `SalesLayout.tsx:178-210` — **2 колонки с ФОТО** (`now.jpg`/`goal.jpg`, `:186`) + dot-меры | `src/render/sales.ts:355-378` (`compare`) — только точки, без изображений | **PARTIAL** | Схема `compare` не имеет поля под картинку колонки |
| benefits list (заголовок по goal) | `SalesLayout.tsx:366-380`; `copy.ts:213-219` `benefitsHeadingByGoal` | `sales.json:130` — `stats.title` статичная строка; `schema/sales.schema.ts:147-153` — `title: z.string()` | **MISSING** | Персонализация заголовка benefits по `ft3_goal` не выражается в DSL |
| showcase-изображения (2 продуктовых скриншота без текста) | `SalesLayout.tsx:382-387` (`showcase-aitutor.png`, `showcase-inside.png`) | — | **MISSING** | Нет типа секции под standalone-картинку; `whats-inside` требует `units[].title` |
| smallSteps / helpsWith / goals / dayWorks | `SalesLayout.tsx:389-405`, `:407-419`, `:421-434`, `:476-498` | `sales.json:157`(stats), `:185`(bullets), `:199`(bullets), `:233`(steps) | **DONE** | |
| rings + обязательный footnote | `SalesLayout.tsx:436-474` | `src/render/sales.ts:388-400`; `schema/sales.schema.ts:198-205` (`footnote` **required**) | **DONE** | Схема жёстче прода — footnote нельзя не указать |
| courses (с focus-бейджем) | `SalesLayout.tsx:500-521` — `course.isFocus` → `courseRowFocus` + `copy.courses.focusLabel` | тип `courses` есть (`src/render/sales.ts:508-524`), но `sales.json:258` авторит эту секцию как `stats` с `"body": "Your focus"` (`sales.json:274`) | **PARTIAL** | Конфиг не использует готовый тип → бейджа нет, «Your focus» — просто текст в ячейке |
| withoutPromova (loss-aversion, скрыт под FTC) | `SalesLayout.tsx:523-537` (`{!isFtcPricing && …}`) | `sales.json:291-293` `"ftcHidden": true`; `src/render/sales.ts:526-528` | **DONE** | Обобщено во флаг `ftcHidden` — лучше, чем спец-кейс |
| testimonial (eyebrow по goal, 5 звёзд) | `SalesLayout.tsx:539-550` | `src/render/sales.ts:139-149`; `sales.json:308` | **DONE** | |
| FAQ | `SalesLayout.tsx:554-562` — `<p>`-пары | `src/render/sales.ts:152-161` — `<details>/<summary>` | **DONE** | Аккордеон вместо плоского списка — косметика |
| page-level `chartFootnote` | `SalesLayout.tsx:552` («Not a guarantee of result. Individual results may vary.») | нет отдельной строки; есть `compare.footnote` = `"* Individual results may vary."` (`sales.json:113`) | **PARTIAL** | Дисклеймер «не гарантия результата» на странице отсутствует |
| **sticky CTA bar** | `SalesLayout.tsx:564-573` — рендерится **БЕЗУСЛОВНО**, в т.ч. под FTC; меняется только копия (`isFtcPricing ? copy.ctaFtc : copy.cta`); `copy.ts:448` `stickyNote` | схема поддерживает (`schema/sales.schema.ts:387-389`), но (а) в `sales.json` **не заавторено вообще**, (б) рендер прячет под FTC: `src/render/sales.ts:297-309` `!ftcOn && s.stickyBar` | **MISSING + DEVIATION** | На проде sticky-бар есть у 100% посетителей; в движке его нет ни у кого, а если заавторить — исчезнет у FTC-гео |
| video / «твой план готов» с ИМЕНЕМ / app-store бейджи / countdown-бар / comparison-таблицы | отсутствуют в `SalesLayout.tsx` (комментарий `:23-31`: «No countdown timer (design/compliance)») | отсутствуют | **DONE (N/A)** | Спек прав: имени пользователя на sales нет. Хотя движок собирает имя (`config.json` s26b `name-input`) — на paywall его не показывает, как и прод |
| money-back блок со Strapi-текстом | у `general-english` **нет** такой секции (`copy.ts:175-448` — ключа money-back нет) | тип `guarantee` есть (`schema/sales.schema.ts:266-274`), не заавторен | **DONE (N/A)** | Прод-swap «Money-Back → Progress-Based Refund Guarantee» (`MoneyBack.tsx:18-22`) относится к Strapi-секции; для code-фаннела остаётся только swap ссылки в футере |
| reviews-стена / rating-badges / secure-payment / whats-inside | у `general-english` нет; есть у `say-what-you-mean-3` (`.../say-what-you-mean-3/layouts/SalesLayout.tsx:361` secure card, `:378-400` rating badges, `:402` guarantee, `layouts/TrustpilotReviews.tsx`, `layouts/WhatsInside.tsx`) | все 4 типа реализованы (`src/render/sales.ts:406-506`), покрыты `tests/sections.test.ts:56-68` | **DONE** | Движок готов к переносу swym-3 |
| Strapi-секции (19–21 dynamiczone) | `constants/sections.ts:50-190` | — | **DELIBERATE-DEVIATION** | Для code-фаннелов `data.sections=[]`; переносить нечего |
| Ось вариантов копии на sales | `renderCodeSalesHop.tsx` + отдельные funnelSlug (`general-english-b`, `-g` — layouts побайтово равны, различаются только 4 импорта ассетов) | `schema/quiz.schema.ts:486-510` — есть `country:*` / `adTopic:*` / `flag:*`; **в `sales.schema.ts` оси вариантов нет вообще** | **MISSING** | Sales-страница не умеет ни `country:compliance`, ни `flag:` — только `ftcHidden` |

---

## 2. Планы / цены / мультивалюта

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Фетч `/v1/billing/products` | `packages/api/getMulticurrencyProducts.ts:11,21,34-51` — 5s abort, `country_code` из **ip-api.com**, Bearer необязателен, при ошибке `return []` | `src/platform.ts:217-227` — `product_id[]` + `country_code` из `cf-ipcountry`; `src/routes/sales.ts:126-136` | **DONE (улучшение)** | Убран клиентский round-trip к `pro.ip-api.com` (`useQueryCountry.ts:40-47`, timeout 5s + `retry: 1` ⇒ до ~11s) |
| all-or-nothing merge | `packages/utils/mappingBillingPlans.ts:19-22` — `if (!hasFullCoverage) **return products**` (CMS-цены в базовой валюте) | `src/pricing.ts:45-51` — `return []` (НЕТ карточек) | **DEVIATION (важно)** | Одинаковое условие, противоположный исход. См. Gap G1 |
| Список мёржимых полей | `mappingBillingPlans.ts:33-51`: `amount, firstPayment, secondPayment, currencyCode, currencySymbol, category, productType, term, oneDollarCharge` | `src/pricing.ts:53-66`: `amount, firstPayment, secondPayment, currencyCode, currencySymbol, **billingPeriodInDays**, type, category` | **DEVIATION** | Движок мёржит `billingPeriodInDays`, чего прод НЕ делает (остаётся CMS). Противоречит собственному комментарию `src/pricing.ts:41-43` («period fields deliberately NOT merged»). Влияет на `orderPlans` и на ветку `<28 days` в `introPeriodLabel` |
| `term` / `oneDollarCharge` | `mappingBillingPlans.ts:43`, `:45-51`; рендер `SubscriptionInfo/ActivationFeeNote.tsx:20-27` за флагом `DISCLAIMER_FOR_US_1USD` | нет ни поля, ни секции | **MISSING** | Дисклеймер об активационном сборе $1 (собственная валюта!) не переносим |
| Fallback-семантика (`??` vs `||`) | `mappingBillingPlans.ts:34-39` — `||` ⇒ живой `first_payment: 0` откатывается на CMS | `src/pricing.ts:58` — `??` ⇒ 0 сохраняется | **DEVIATION (в лучшую сторону)** | Настоящий free-trial (0) прод показывает неверно, движок верно |
| Форматирование валют | `packages/utils/handleLocalizeCurrency.ts:7-77` — 7 шаблонов, 17 кодов (вкл. **PHP**), `decimalPlaces: 2`, Proxy-fallback → USD-шаблон | `src/pricing.ts:91-125` — те же 7 шаблонов, 16 кодов (PHP нет), fallback `BEFORE_COMMA_DOT` | **DONE** | PHP в проде = `symbolBeforeCommaDot`, т.е. ровно fallback движка ⇒ вывод идентичен |
| Какой форматтер видит юзер на проде | code-фаннел использует НАИВНЫЙ `code-funnels/money/general-english/formatMoney.ts:5-6` = `` `${symbol}${(cents/100).toFixed(2)}` `` | движок использует таблицу `handleLocalizeCurrency` | **DELIBERATE-DEVIATION** | Реальное визуальное расхождение: UAH прод `₴1476.99` / движок `1 476,99 ₴`; EUR/PLN/CZK/BRL/CHF тоже. Задокументировано в `src/pricing.ts:70-82` |
| Ещё 2+ прод-форматтера | `FunnelBuilder/utils/priceFormatting.ts:5-28` (жёстко `'en-US'` + ICU-символ), `Elysium/PlanCard/PlanCard.tsx:15-24` (локальная копия без `min/maxFractionDigits`), `apps/student/utils/helpers.ts:16-28` | один (`formatPrice`) + `@deprecated formatMoney` (`src/pricing.ts:133-134`) | **DONE** | Порт одного, как и требовал спек |
| headline / intro / rebill | `SalesLayout.tsx:63-71` (`ftcRebillPrice`: 2-for-1 → `rebillPayment`, иначе `secondPayment`), `:233-237` (`hasIntroPrice` через `<`, не `!==`) | `src/pricing.ts:143-161` | **DONE** | Дословный порт, включая комментарий про surcharge |
| per-day математика | `SalesLayout.tsx:72-78` — `priceDivider ? firstPayment / priceDivider : null`, **без floor**; сплит `(perPeriod/100).toFixed(2).split('.')` (`:259-263`); `weekPrice`-фоллбэка НЕТ (`_template/…/SalesLayout.tsx:188-192`, PR #5231) | `src/pricing.ts:169-170`, `:263-266` | **DONE** | Канонический `getPricePerPeriod` (floor, `priceFormatting.ts:13-14`) — Strapi-путь, code-фаннел его не использует; движок повторил code-путь верно |
| Сортировка карточек | `SalesLayout.tsx:110-118` — `billingPeriodInDays ?? amount`, по возрастанию | `src/pricing.ts:177-180` | **DONE** | Оба наследуют прод-баг: смешивание дней и центов в одном компараторе |
| «Best value» | `SalesLayout.tsx:80-95` — минимальный per-day, `?? Infinity` | `src/pricing.ts:183-191` | **DONE** | |
| Preselect-лестница | `Sales.tsx:784-808`: 4 ступени — `preselectedSubscription` → `products[bestOfferCardNumber-1]` → `bestOfferSubscription` → `products[0]`; + отдельная ветка timer-zero `:740-776`; `hasUserSelectedRef` `:349,809-811` | `src/pricing.ts:202-208`: 3 ступени — `selectedId` → `bestValueProductId` (вычисленный) → `plans[0]`; жёсткая валидация конфига `schema/sales.schema.ts:471-479` | **PARTIAL** | Нет `bestOfferCardNumber` / `bestOfferSubscription`; вторая ступень заменена на вычисленный best-value. Для `general-english` не видно (preselect всегда попадает), но у down-sale прод именно `bestOfferSubscriptionId` даёт бейдж |
| Strike-through | sales-карточки `general-english`: **нет** `<s>`, есть «then $X» (`SalesLayout.tsx:313-318`); `<s>` есть в down-sale (`SalesDownsaleLayout.tsx:110-114`) | `src/render/sales.ts:207-224` — «then …», `<s>` нет нигде | **PARTIAL** | На главной парити есть, в down-sale — нет (см. §4) |
| «Save X%» | sales `general-english` — нет; чекаут `CheckoutBuilder/.../SummarySection.tsx:83-86` — база `secondPayment`, `Math.round`; Elysium — база `amount` (`priceFormatting.ts:16-17`) | `src/render/checkout.ts:196-236` — база `secondPayment`, `Math.round` | **DONE** | Выбрана правильная (чекаутная) база, комментарий `:198-203` |
| `fakeDiscount` / `discountLabel` | `utils/getFakeDiscountOldPrice.ts:21-31` — `oneTime` only, `round(firstPayment/(1−fake/100))`; подавляется под FTC-hard (`Plans/Card/Card.tsx:114`); `discountLabel`-бейдж у `english-hub/…/SalesLayout.tsx:152` | нет ни `fakeDiscount`, ни `discountLabel` в `planSchema` | **MISSING** | Для `general-english` не нужно (нет `oneTime`), для `english-hub`/upsell-ов нужно |
| VAT / налоги | нигде (только статичный «VAT number» в `ui/modules/LegalDisclaimer/LegalDisclaimer.tsx:24`); в `BillingPlanResponse` (`api/schema/schema.d.ts:4471-4522`) полей налога нет | нигде | **DONE (N/A)** | Цены брутто без tax-disclosure в обоих |
| Поддерживаемые валюты | union 20 кодов `packages/config/types/index.ts:97-116`; символы `config/constants/prices.ts:153-245`; таблица форматов 17 | таблица форматов 16 + USD-fallback; выбор валюты целиком на бэкенде (`country_code`) | **DONE** | `CAD, AUD, MXN, ILS, IDR` падают в USD-шаблон и в проде, и в движке — парити «по совпадению». `DKK, SEK` есть в таблице у обоих, но их нет в прод-union |
| `channel` продукта | gringotts отдаёт `"channel": "promova"` (см. `plans/gimli2-commerce-binding-probe.md` §3); прод шлёт его в order (`Checkout.ts:1201`) | в `planSchema` поля `channel` нет; в order-body не шлётся | **MISSING** | См. §5 |
| `isMulticurrencyLoaded` / pricing-settled | `useMultiCurrency.ts:91`; gate чекаута `utils/getIsPricingSettled.ts:25-27`; `Sales.tsx:670,1832-1836` | исчезает (server-render) | **DELIBERATE-DEVIATION** | Гонка `hasUserSelectedRef` (behavior #2 в money-path-anatomy) устранена конструктивно |

---

## 3. FTC (`us_pricing_now_then` / `ftc_soft_changes`)

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Резолв состояния | `FunnelBuilder/hooks/useFtcPricing.ts:24-31` — `isOn = hard \|\| soft`, `variant = isSoft ? 'soft' : 'hard'` | `src/growthbook.ts:182-186` | **DONE** | Включая приоритет soft при обоих true |
| Гео-таргетинг | в правилах GrowthBook, не в коде | там же (движок шлёт `country`) | **DONE** | |
| Скрытие ribbons | `SalesLayout.tsx:273` `{!isFtcPricing && …}` | `src/render/sales.ts:236` | **DONE** | |
| Скрытие social ticker | `SalesLayout.tsx:212` | `src/render/sales.ts:283-287` | **DONE** | |
| Скрытие billing-terms (ROSCA) | `SalesLayout.tsx:346-348` — `!isFtcPricing && !!(hasAnyIntro \|\| currentSubscription) && !!selectedPlan` | `src/render/sales.ts:268-282` | **DONE** | Условие эквивалентно |
| now/then строка | `SalesLayout.tsx:239-245` (`showNowThen`), `:295-311` (одна и та же строка для hard и soft, различие только `data-variant`) | `src/pricing.ts:248-256`, `src/render/sales.ts:207-213` | **DONE** | ⚠️ Поправка к спеку: боксированная зачёркнутая полная цена под hard (`HardRow`/`HardPricesBlock`, `Plans/Card/Card.tsx:134-166`) — это **Strapi-путь**; code-фаннел её не рисует, движок правильно её не рисует |
| per-day только под soft | `SalesLayout.tsx:39` `showPerPeriodUnderFtc = !isFtcPricing \|\| ftcVariant === 'soft'` | `src/render/sales.ts:180` | **DONE** | |
| `ftcNoPaymentNote` (hard only) | `SalesLayout.tsx:219-223` | `src/render/sales.ts:288-292`; копия в `sales.json:124` побайтово равна `copy.ts:238-239` | **DONE** | |
| CTA swap | `SalesLayout.tsx:363` `isFtcPricing ? copy.ctaFtc : copy.cta` | `src/render/sales.ts:265` — плюс приоритет над per-card CTA | **DONE** | Копии совпадают: `cta: 'Get my results & plan'`, `ctaFtc: 'Continue'` |
| Sticky CTA под FTC | `SalesLayout.tsx:564-573` — **остаётся**, копия swap-ится | `src/render/sales.ts:297-309` — **скрывается целиком** | **DEVIATION** | См. §1 / Gap G3 |
| Чекаут: CTA «Subscribe» | `Checkout/CheckoutForm/CheckoutForm.tsx:211` | `src/render/checkout.ts:281` | **DONE** | |
| Чекаут: FTC-дисклеймер вместо social-proof | `CheckoutForm.tsx:323` (`SocialProofBanner` только `&& !isUsPricingNowThen`), `:327-332`; копии `UsPricingCheckoutDisclaimer.tsx:78-107` (soft) / `:109-139` (hard) | `src/render/checkout.ts:88-136`; non-FTC слот = `''` (`src/render/checkout.ts:151`, с объяснением) | **DONE** | Raw English для обоих вариантов, `secondPayment` (не `rebillPrice`) — как в проде |
| `introPeriodLabel` | `SubscriptionInfo/UsNowThenDisclaimer.tsx:61-66` — `billingPeriodInDays < 28 ? "{n} days" : trial ? "{dur} {period}" : billingCyclePeriod` | `src/pricing.ts:229-239` | **DONE** | |
| Чекаут-сводка под FTC | `Checkout/RedesignCheckoutInfo/RedesignCheckoutInfo.tsx:192-196` («Total today»), `:207` (убрать «then …»), `:250-259` («After {period} auto-renews») | `src/render/checkout.ts:238-261` | **DONE** | Все три дельты в том же порядке |
| Money-Back → Progress-Based Refund | `common/sales-page/MoneyBack/MoneyBack.tsx:18-22` (заголовок), badge скрыт `:35`, `MoneyBackPolicyLink.tsx:24`; футер `common/onboarding/LegalInfo/LegalInfo.tsx:79-90` | только футер: `src/render/sales.ts:592` | **DONE (N/A) / MISSING для общности** | У code-фаннела money-back-секции нет; в схеме `guarantee` нет FTC-aware swap-а заголовка и авто-ссылки |
| Форс legacy CheckoutModal под FTC | `Sales.tsx:1848-1852`, `:1879`; `CheckoutManager.tsx:365,397` | у движка один чекаут | **DELIBERATE-DEVIATION** | Переносить нечего |
| Подавление timer / Elysium под FTC | `Sales.tsx:600-605`, `:1975`; `code-funnels/money/SalesTimerScope.tsx:45` (`if (!timer \|\| isFtcPricing) return children`) | у `general-english` таймера нет ни там, ни там; при заавторенном `timer` движок его **не гейтит по FTC** (`src/routes/sales.ts:121-124` — `timerExpired` считается всегда) | **PARTIAL** | Продовый swap `products → subsTimerZero` под FTC не происходит; у движка произойдёт. Скрытого хрома нет, но набор продуктов подменится |
| Down-sale НЕ гейтится по FTC | `SalesDownsaleScope.tsx:26-31` (осознанно) | `src/sales.ts:53-70` + `src/routes/sales.ts:96-99` | **DONE** | behavior #7 воспроизведён |
| **Оба флага резолвятся в false** | — | **ПОДТВЕРЖДЕНО**: `src/routes/sales.ts:182-190` (`ftcOverride`, комментарий «Both FTC flags currently resolve false for every country»); `README.md:1596-1610` | **BLOCKER** | Локализовано. Причина — см. Gap G2 |
| QA-override | прод: `?_timer=` (`TimerSalesProvider.tsx:24`) | `?_ftc=hard\|soft\|off` (`src/routes/sales.ts:184-190`) | **DONE (улучшение)** | Единственный способ увидеть FTC-вёрстку сейчас |

---

## 4. Down-sale (on-page)

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Триггер | закрытие чекаута без оплаты (`Sales.tsx` `handleClose` → `useCanChowDownSale`) + `?downsale=true` (`Sales.tsx:346`). **Ни exit-intent, ни beforeunload, ни таймера, ни decline** | `src/routes/sales.ts:734-788` (`POST /sierra/:id/close`); `?downsale=true` `src/routes/sales.ts:90-92` | **DONE** | Waterfall (AI-Tutor / spin wheel) обоснованно свёрнут — `src/sales.ts:12-22` |
| 24h cooldown + авто-выход | `utils/customHooks/useFunnelBuilderTimer.tsx` (`has24HoursPassed`, `:99-105`), глобальный LS-ключ `downSaleTimer` на браузер | `src/sales.ts:85-94`, `:60-70`; подписанная per-funnel кука `fe_sale` (`src/sales.ts:98-102`) | **DONE (улучшение)** | Прод-семантика воспроизведена, ключ стал per-funnel и не редактируемым |
| **Продукты down-sale** | **отдельное pricing-rule** `general-english-downsell` (`code-funnels/money/general-english/index.ts:45-52`), тот же набор, что у `/delta`-хопа (`:72-76`); по комментарию `:17` — «Pronunciation intensive, one-time» | `funnels/general-english/sales.json:354-460` — **ТЕ ЖЕ 3 productId и ТЕ ЖЕ цены**, что на главной (`:5,22,39` vs `:358,376,394`), различие только `"note": "DOWNSELL"` | **MISSING (критично)** | Копия обещает «Wait — a better price / Start for less today», а цена не меняется. См. Gap G4 |
| Копия down-sale | `copy.ts:527-540` | `sales.json:411-438` — побайтово те же строки | **DONE** | |
| Вёрстка down-sale | выделенный `layouts/SalesDownsaleLayout.tsx:29-152`: eyebrow, title, offer, `plansDisclosure`, строки планов с **`<s>` старой ценой справа** (`:110-114`) + inline «X today, then Y every Z» (`:86-105`), бейдж `mostRecommended` из `bestOfferSubscription` (`:56,72-76`), CTA, дисклоужер | переиспользуются `hero` + `plans` (`sales.json:412-439`) | **PARTIAL** | Нет `<s>`-колонки, нет отдельного `bestOffer`-бейджа |
| `bestOfferSubscriptionId` | `code-funnels/money/types.ts:147-150` | в `downsaleSchema` (`schema/sales.schema.ts:404-415`) поля нет | **MISSING** | |
| Дисклоужер down-sale под FTC | `SalesDownsaleLayout.tsx:129-148` — гейт только `!!currentSubscription`, **FTC не проверяется** (в файле нет ни `useFtcPricing`, ни `isFtcPricing` — проверено grep-ом) | `src/render/sales.ts:268-270` — `!ftcOn && s.billingTerms` ⇒ под FTC дисклоужера нет | **DEVIATION (compliance)** | См. Gap G5 |
| Countdown на down-sale | у `general-english` **нет** (проверено grep-ом по `SalesDownsaleLayout.tsx`); есть у `english-hub/…/SalesLayout.tsx:55,108` и `_template/…/SalesLayout.tsx:273-296` | нет; `remainingSeconds` пробрасывается в `SalesCtx` (`src/render/sales.ts:44`) и **не используется** | **DONE для general-english / MISSING для общности** | ⚠️ Поправка: отчёт вспомогательного агента приписал countdown `general-english/SalesDownsaleLayout.tsx` — это неверно, там его нет |
| `revenue_checkout_closed` / `revenue_pricing_cta_ignored` | безусловно, против покидаемой поверхности | `src/routes/sales.ts:766-781` — тот же порядок и контексты | **DONE** | behavior #10/#30 учтены |
| Chain down-sell `/delta` (3 skip) | `code-funnels/money/general-english/index.ts:72-76`; `renderCodeDownsellHop.tsx` | механика есть (`schema/post-purchase.schema.ts:129-190`, `tests/chain.test.ts:63-104`), но **`funnels/general-english/` содержит только `config.json`, `sales.json`, `theme.json`, `locales/`** — `post-purchase.json` отсутствует | **MISSING** | Прод: 2 upsell-а + downsell + thank-you. Движок после оплаты отдаёт терминальный экран `src/routes/sales.ts:630-643` |

---

## 5. Checkout

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Скрипт SDK + preconnect | `Checkout/CheckoutForm/utils/loadSolidScript.ts:1-24` | `src/render/layout.ts:460-463` | **DONE** | |
| `PaymentFormSdk.init` опции | `Checkout.ts:393-414`: `merchantData, formParams, pixButtonParams, pixAutomaticoButtonParams, blikButtonParams, upiButtonParams, mbwayButtonParams, applePayButtonParams, googlePayButtonParams, iframeParams{containerId,width:'100%'}, styles` | `src/render/checkout.ts:390-415`: `merchantData, iframeParams{containerId,width:'100%'}, formParams{submitButtonText,autoFocus:false,allowSubmit:true}, googlePayButtonParams, applePayButtonParams, styles` | **PARTIAL** | Нет `blikButtonParams`, `upiButtonParams`, `pixAutomaticoButtonParams`, `mbwayButtonParams`, `pixButtonParams{enabled:false}`; нет `applePayButtonParams.enabled` и `type:'pay'` (`Checkout.ts:343-352`), нет `formParams.enabled` |
| `formTypeClass` / `allowSubmitOnEnter` | закомментировано (`Checkout.ts:336`) / не используется нигде | нет | **DONE (N/A)** | |
| Стили формы | `whiteFormStyles.ts` — но на фаннельном пути всегда перекрыт `customStyles` (`CheckoutForm.tsx:287`) | `src/render/checkout.ts:32-77` — своя палитра | **DELIBERATE-DEVIATION** | Задокументировано |
| Где создаётся order | в браузере, после загрузки SDK; backoff до 60 попыток (`Checkout.ts:44,547-576`) | на сервере, до рендера (`src/routes/sales.ts:381-476`, `src/checkout.ts:36-106`) | **DONE (улучшение)** | Убирает класс гонок «waiting for BillingUserID» |
| Order body | `Checkout.ts:1184-1210`: `billing_plan, currency, force_3ds, apple_pay, google_pay, blik, sandbox, purchase_url, page_url, [quiz_result_id], [channel], [pix_automatico], [phone], [name]` | `src/checkout.ts:51-62`: `billing_plan, currency, force_3ds:false, apple_pay:true, google_pay:true, blik:false, sandbox, page_url, purchase_url, [quiz_result_id]` | **PARTIAL** | Нет **`channel`** (значимо: приходит из gringotts как `"promova"`, влияет на биллинг-роутинг), нет `pix_automatico`/`phone`/`name` |
| `ip` в body | не шлётся (в `OrderRequestV3` поля нет) | не шлётся | **DONE** | |
| `page_url` | `window.location.href` (с UTM) | `${origin}/sierra/${page.id}` (`src/routes/sales.ts:471`) — **без query** | **PARTIAL** | Атрибуция в `page_url` теряется |
| `force_3ds` | `!!config.force3Ds`; **ни один вызывающий его не задаёт** (`CheckoutForm/types.ts:21`, `Checkout.ts:1036,1491`) ⇒ всегда `false` | `src/checkout.ts:54` — `?? false` | **DONE** | 3DS полностью внутри SDK/бэкенда |
| Card | `#solid_container` (`CheckoutForm.tsx:368-375`) | `#solid-form` (`src/render/checkout.ts:311`) | **DONE** | |
| PayPal | `POST /v3/billing/paypal-orders/users/{uid}`, body `Checkout.ts:1517-1527` (без `google_pay`/`blik`); гейты: GB-флаг `show_paypal_button` (`Checkout.ts:1418-1423`, `useShowPaypalButton.ts:15`) + `paypalSupportedCurrencies` (`Checkout.ts:1505-1511`); ошибка **невидима** (`onError` не подключён) | `src/checkout.ts:119-154`; `src/routes/sales.ts:479-483`; ошибка **показывается** (`src/render/checkout.ts:298-305`) | **PARTIAL** | Улучшение по видимости ошибки, но **нет гейтов**: движок создаст PayPal-order и покажет слот в неподдерживаемой валюте, и флагом его не выключить |
| Apple Pay / Google Pay | флаги в order + собственные контейнеры (`CheckoutForm.tsx:345-356`) | `src/checkout.ts:56-57`, контейнеры `src/render/checkout.ts:293-294` | **DONE** | |
| BLIK | `CheckoutForm.tsx:141-149,358`; `getIsBlikEligible` (`config/types/countries.ts:93-104`) = флаг `isShowBlikButton` + PL + PLN; `blik:true` в order И `blikButtonParams` — «must never diverge» (`remote_config.ts:55-58`) | `blik: false` жёстко (`src/checkout.ts:57`) | **MISSING** | |
| UPI | `CheckoutForm.tsx:360`; `Sales.tsx:627-629` (IN + INR) + GB `use_upi_payment` | нет | **MISSING** | |
| Pix Automatico | `CheckoutForm.tsx:139-140,357`; BRL + GB `isShowPIXButton` | нет | **MISSING** | |
| MB Way | поддержан в `CheckoutForm`, но `CheckoutModal` не передаёт `isMbWayFlow`/`phone` ⇒ **на sales-чекауте не подключён** | нет | **DONE (N/A)** | |
| GCash | **не существует** в монорепе (0 вхождений `gcash`) | нет | **DONE (N/A)** | PRMV-17114 ещё не в коде |
| SDK-события | `Checkout.ts:498-546` — ровно 7: `success, error, fail, submit, mounted, resize, interaction`. `orderStatus`/`verify`/`customTerms` — не подписаны нигде | `src/render/checkout.ts:417-480` — те же 7 | **DONE** | Дедуп `mounted` (`:417-419`) воспроизведён |
| `interaction` → GA4 `begin_checkout` | `CheckoutManager.tsx:242-247` (one-shot) | `src/render/checkout.ts:455-461` (one-shot) | **DONE** | |
| `submit` → `revenue_initiated_transaction` + FB AddPaymentInfo | `Checkout.ts:647-680` | `src/routes/sales.ts:704-711` (`is_trial` из наличия `trialPeriod`, `price` в мажорных) | **DONE** | |
| Пересоздание order на `fail` | `Checkout.handlePaymentFail` (`Checkout.ts:932-971`) — чистит контейнер и **сам** вызывает `setupForm()` (новый POST + новый `init`) | экран decline с кнопкой «Try again» → `POST /sierra/:id/checkout` (`src/render/checkout.ts:582-586`) | **PARTIAL** | На проде свежая форма готова за спиной экрана ошибки; в движке нужен клик. Функционально эквивалентно, но на один тап дороже |
| Таксономия declines (15 кодов) | `config/constants/paymentError.ts:1-19`; копии `CheckoutErrorSection.tsx:47-246` | `src/checkout.ts:163-179`, `:209-291` | **DONE** | Все 15 кодов, копии совпадают, включая общий текст для `0.01/2.03/6.01/6.02` |
| `support`-ссылка | `isShowLink: true` только у `3.10` (`:61-73`) и `3.08` (`:74-89`) | `src/checkout.ts:222`, `:229` | **DONE** | |
| downsell-eligible коды | `CheckoutErrorSection.tsx:248-252` — `3.04, 3.02, 3.10` | `src/checkout.ts:215,222,236` (`downsell: true`) | **DONE (флаг)** | |
| **CheckoutDownsell (one-click на упавший order)** | `CheckoutDownsell.tsx:189-234` → `POST /v3/billing/one-click-pay` (`api/billing.ts:219-240`, Bearer); 4 условия (`CheckoutErrorSection.tsx:305-322`): entity=`form`, `declineSubscription` из CMS, `sessionStorage[error_checkout_order_id]`, код из 3; страйк-цена = `firstPayment * 6.99` (`:87,371`) | флаг `downsell` считается, но **UI и вызова нет** | **MISSING** | |
| Retry разрешён, ничего не блокирует | `CheckoutErrorSection.tsx:280-297` | `src/render/checkout.ts:582-592` | **DONE** | |
| Success → хранение order_id | LS `checkout_order_id` / `checkout_payment_entity` (`constants/common.ts:55-57`); гейт GB `tokenization_for_wallets_split` + `REBILL_PAY_TYPES=[apple_pay,google_pay,blik]` (`Sales.tsx:1306-1326`); v1 дополнительно пропускает UPI (`:1315`), v2 — **нет** | подписанная chain-кука (`src/routes/sales.ts:605-609`, `startChain`), гейта токенизации нет | **PARTIAL (улучшение по безопасности)** | order_id не покидает воркер (лучше прода), но wallet/BLIK-order_id будет использован для one-click там, где прод бы отказался |
| Polling статуса order | нет нигде (только SDK `success` + PayPal DOM `order-processed`, `Checkout.ts:1473`) | нет | **DONE** | |
| `sandbox` | GB-флаг `use_sand_box` (`utils/customHooks/useSandBox.ts:9-38`), default `!LIVE_MODE` (`remote_config.ts:105`) | `src/routes/sales.ts:466` — `c.env.LIVE_MODE !== 'true'`, GrowthBook не читается | **DEVIATION** | Оператор не может перевести движок в sandbox флагом (и наоборот) |
| Anti-fraud | клиентской логики нет; `USE_CAPTCHA` в чекауте не читается | нет | **DONE** | Про `anti-fraud-protection` (README:1609) в монорепе следов нет — это бэкенд |
| Coupon / `applyCoupon` | `Checkout.ts:612-645` (`form.applyCoupon` + `POST /v1/billing/coupon/users/{uid}`); UI `CheckoutPromoCode.tsx:42-70`; гейт `useCheckoutInfo.ts:50-51` (нет промо на trial-планах); применение промо **выключает PayPal** (`CheckoutForm.tsx:341`) | нет | **MISSING** | |
| Легальная строка процессора | `/api/legal/checkout-text` | `src/platform.ts:274-278`, `src/render/checkout.ts:318` | **DONE** | |
| Pre-auth $1 при `firstPayment === 0` | предполагается `CheckoutFooter` `freeTrial` | `src/render/checkout.ts:314-317` | **НЕ ПРОВЕРЕНО** | Точный прод-источник этой строки не подтверждён |
| Варианты чекаута (Builder / Configurable / inline) | `Sales.tsx:1822-1937`, `CheckoutManager.tsx:363-451`; `withChangingTotal` — вопрос корректности списания (`CheckoutModal.tsx:284-291`) | один модальный чекаут | **DELIBERATE-DEVIATION** | Под FTC прод и так форсит legacy modal |

---

## 6. Таймеры

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Главный countdown | `general-english` **не объявляет** (`index.ts:21`, `SalesLayout.tsx:23-31`) | `sales.json` не объявляет `timer` | **DONE** | |
| Механика `timer` в DSL | `usePersistentCountdown.ts:9` (`elysium_discount_timer`, elapsed-seconds, 24h TTL, общий на браузер), пауза при открытом модале (`TimerSalesProvider.tsx:32-36`) | `schema/sales.schema.ts:434-441`; дедлайн в подписанной куке (`src/sales.ts:42-43`), не перезапускается (`src/routes/sales.ts:305-307`) | **DONE (улучшение)** | behavior #4/#6 (два источника правды) устранены |
| Swap `products → subsTimerZero` на истечении | `PlansWithTimer.tsx:114-147`, `_template/…/SalesLayout.tsx:129` | `src/routes/sales.ts:121-124` — серверный swap | **DONE** | |
| **Хром countdown-а** | `_template/…/SalesLayout.tsx:252-271` / `:273-296`; `english-hub/…/SalesLayout.tsx:108` | **нет вообще**: `remainingSeconds` в `SalesCtx` (`src/render/sales.ts:44`) не рендерится нигде; комментарий `src/render/sales.ts:614-624` | **MISSING** | Если фаннел объявит `timer`, набор продуктов сменится молча, без UI |
| Down-sale countdown | у `general-english` нет | нет | **DONE** | |
| `TimeOffer` (декоративный) / upsell-downsell 10-мин | Strapi / `UpsellDownsell` | нет | **DELIBERATE-DEVIATION** | Оба декоративные |

---

## 7. Trust-блоки

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Отзыв + 5 звёзд | `SalesLayout.tsx:539-550` | `src/render/sales.ts:139-149` | **DONE** | |
| Rings с атрибуцией опроса | `SalesLayout.tsx:436-474` + `copy.rings.footnote` | `src/render/sales.ts:388-400`, footnote обязателен | **DONE** | |
| «As seen in» / app-store бейджи / secure-payment бейджи | у `general-english` **нет** | не заавторены | **DONE (N/A)** | |
| rating-badges / reviews-стена / secure-payment | есть у `say-what-you-mean-3` (`:361,378-400`, `TrustpilotReviews.tsx`) | типы реализованы, покрыты `tests/sections.test.ts:56-63` | **DONE** | Готовность к swym-3 |
| Карточные марки | чекаут: 5 марок | sales: 4 (`src/render/sales.ts:466-471`, без Maestro), чекаут: 5 (`src/render/checkout.ts:266-272`) | **PARTIAL** | Косметика; марки нарисованы CSS-ом, не файлами |

---

## 8. Legal (кратко — детально другой агент)

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Футер `LegalInfo` на sales code-фаннела | **НЕ рендерится**: `Sales.tsx:1962-1965` — `suppressChrome ? renderSalesPage() : (… <LegalInfo/>)`; сам `SalesLayout.tsx` юридических ссылок не содержит | `src/render/sales.ts:566-604` — рендерится всегда, на главной и на down-sale | **DEVIATION (в лучшую сторону)** | Движок добавляет то, чего у прод-code-фаннела на paywall нет вообще. Передать legal-агенту |
| Swap 4-й ссылки под FTC | `LegalInfo.tsx:79-90` | `src/render/sales.ts:592` | **DONE** | |
| Cookie Policy (EU+GB+US, US-суффикс) / FAQ for EU Residents (EU+GB) | `LegalInfo.tsx` | `src/render/sales.ts:583-589` | **DONE** | Гео из `cf-ipcountry`, т.е. в первом байте |
| Merchant-строка | `/api/legal/footer-text` | `src/platform.ts:283-287`, `src/render/sales.ts:598-600` | **DONE** | |
| Дисклоужер под CTA (ROSCA) | `SalesLayout.tsx:346-360` | `src/render/sales.ts:268-282` | **DONE** | Но см. §4 (down-sale под FTC) |

---

## 9. Аналитика sales-страницы (только перечень — детально другой агент)

Движок (`src/analytics/money.ts:136-168`, `src/routes/sales.ts`):
`revenue_pricing_page_viewed`, `revenue_pricing_block_viewed`, `revenue_pricing_cta_clicked`,
`revenue_pricing_cta_ignored`, `revenue_started_checkout`, `revenue_checkout_form_mounted`,
`revenue_clicked_payment_type`, `revenue_initiated_transaction`, `revenue_checkout_closed`,
`revenue_purchased`, `sales_payment_success`, `funnels_payment_declined`;
GA4: `view_item_list`, `add_to_cart`, `begin_checkout`, `purchase_ecommerce`.

Заметки: `revenue_pricing_block_viewed` на проде у code-фаннелов **не фаерится вообще**
(behavior #30) — движок его отправляет (`src/routes/sales.ts:320-321`), т.е. форма
funnel-view метрики изменится. `gen_joined_ab_test` не отправляется ни разу
(0 вхождений в движке) — 6 прод-сайтов сплит-эвентов не покрыты.

---

## 10. Auth guard / форма URL

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| URL | `/sierra/{salesSlug}/{uid}/{sid?}` + `?funnel_slug=`; `pages/Sales/SalesPage.tsx:24-25` — `slug[0]`=salesSlug, `slug[1]`=userId, **пустая строка допустима** | `/sierra/{funnelId}` (`src/routes/sales.ts:295`), uid/sid нет в URL | **DELIBERATE-DEVIATION** | Идентичность — в подписанной куке (`src/routes/sales.ts:475-481`) |
| Guard «юзер обязан существовать» | **нет**. `renderCodeSalesHop.tsx:64-73,137-146,157-167` — `notFound()` только на dead-paywall (нет подписок / пустой subsTimerZero / пустой down-sale) | страница рендерится без идентичности; чекаут отдаёт `renderCheckoutUnavailable`, если нет `platformUserId` (`src/routes/sales.ts:433-446`) | **PARTIAL** | Продовые dead-paywall-гварды (в т.ч. строгий для `subsTimerZero`, ленивый для down-sale) у движока не воспроизведены как 404 — вместо этого страница без карточек |
| `sid` (email-link id) | едет конкатенацией, не валидируется | `SaleState.sid` привязан к квиз-сессии и подписан (`src/sales.ts:33-35`) | **DONE (улучшение)** | |

---

## 11. GrowthBook-флаги, влияющие на sales/checkout

| флаг | prod source (file:line) | funnel-engine | status |
|---|---|---|---|
| `us_pricing_now_then` | `remote_config.ts:42`; `useFtcPricing.ts:24-31` | `src/growthbook.ts:30,183` | **DONE (но резолвится false)** |
| `ftc_soft_changes` | `remote_config.ts:43` | `src/growthbook.ts:31,184` | **DONE (но резолвится false)** |
| `compliance_config_promova.use_marketing_consent` | `remote_config.ts:3-4` | `src/growthbook.ts:211-216` | **DONE** |
| `use_sand_box` | `remote_config.ts:7,105`; `useSandBox.ts:9-38` | не читается | **MISSING** |
| `show_paypal_button` | `remote_config.ts:47`; `Checkout.ts:1418-1423` | не читается | **MISSING** |
| `isShowBlikButton` | `remote_config.ts:58` | не читается | **MISSING** |
| `isShowPIXButton` | `remote_config.ts:51` | не читается | **MISSING** |
| `isShowMBWayButton` | `remote_config.ts:61` | не читается | **DONE (N/A)** (на sales-чекауте не подключён) |
| `use_upi_payment` | `remote_config.ts:25` | не читается | **MISSING** |
| `tokenization_for_wallets_split` | `remote_config.ts:37`; `Sales.tsx:1306-1326` | не читается | **MISSING** |
| `disclaimer_for_US_1usd` | `remote_config.ts:39`; `ActivationFeeNote.tsx:18` | не читается | **MISSING** |
| `use_funnel_animations` | `remote_config.ts:30`; `SalesPage.tsx:60` | не читается | **DELIBERATE-DEVIATION** |
| `eu_withdrawal_from_contract` | `remote_config.ts:64` — рендерится на `/withdraw-from-contract`, **не на sales** | — | **DONE (N/A)** |
| Ось `flag:` на sales-копии | — | `schema/quiz.schema.ts:486-510` есть, **в `sales.schema.ts` нет** | **MISSING** |
| A/B самой sales-страницы | отдельные funnelSlug: `general-english`, `-b`, `-g` (`moneyRegistry.ts:19-26`); layouts побайтово равны, различаются только 4 импорта ассетов | одна папка `funnels/general-english/` | **PARTIAL** | Механически выразимо (отдельная папка фаннела), но не заавторено |

---

## Gaps (с доказательствами)

**G1. Отказ биллинга обнуляет paywall целиком, а прод продолжает продавать.**
Прод: `packages/utils/mappingBillingPlans.ts:19-22` — `if (!hasFullCoverage) return products`, т.е. страница
остаётся на CMS-ценах в базовой валюте. Движок: `src/pricing.ts:45-51` — `return []`, и
`src/render/sales.ts:174` — `if (ctx.plans.length === 0) return ''` (нет карточек, нет CTA, нет
billing-terms). Собственный e2e это фиксирует как контракт: `tests/e2e.test.ts:310-312`
(«unresolved prices render no cards and no CTA», «the down-sale is equally empty»).
Решение задокументировано (`src/pricing.ts:29-35`) и защитимо по смыслу «не показывать цену,
которую бэкенд не подтвердит», но последствие — 100% потеря конверсии при любом сбое
`/v1/billing/products`, там где прод теряет только локальную валюту. Это продуктовое решение,
которое стоит проговорить с владельцем метрики, а не техническая деталь.

**G2. Найдена вероятная причина «оба FTC-флага = false везде».**
Клиентский prod-эвал шлёт в GrowthBook **полное НАЗВАНИЕ страны**:
`packages/utils/customHooks/useAddGrowthBookAttributes.ts:28` — `const { country } = useQueryCountry()`,
и именно `country` (не `countryCode`) уходит в атрибуты (`:76`, `:122`); в
`packages/utils/customHooks/useQueryCountry.ts:8-9` это два разных поля (`country: string`,
`countryCode: string`) из ответа ip-api. Серверный prod-эвал шлёт ISO:
`packages/utils/growthbook/initializeGrowthBookServerSide.ts:98` — `const country = data.countryCode`.
Движок шлёт ISO из `cf-ipcountry` (`src/growthbook.ts:95`). `useFtcPricing` — клиентский хук, т.е.
правила таргетинга FTC почти наверняка авторены под формат «United States», а не «US».
Гипотеза README (`README.md:1602-1606`) подтверждается на стороне кода; окончательно её закрывает
только чтение правил в GrowthBook UI.
Второе, независимое: `useAddGrowthBookAttributes.ts:65` — `if (!userId || !growthBook || !country …) return`,
т.е. на проде анонимный посетитель **вообще не имеет атрибутов** и все флаги у него дефолтные.
Движок атрибуты отправляет всегда (`src/growthbook.ts:93-100`) — это расхождение в другую сторону.

**G3. Sticky CTA: отсутствует на всех гео и запрещён на FTC-гео.**
Прод рендерит sticky-бар безусловно (`.../general-english/layouts/SalesLayout.tsx:564-573`), меняя
только копию кнопки. В движке (а) `funnels/general-english/sales.json` секцию `plans` объявляет
без `stickyBar` (`:116-128` — поля нет), (б) рендер прячет её под FTC
(`src/render/sales.ts:297-299` — `!ftcOn && s.stickyBar`), что зафиксировано тестом
`tests/sections.test.ts:76`. Итог: элемент, который на проде видят все, в движке не видит никто, и
даже после заавторивания его не увидят FTC-гео.

**G4. Down-sale продаёт тот же товар по той же цене под копией «а better price».**
Прод биндит отдельное правило: `.../general-english/index.ts:45-52` —
`downsale.commerce = { kind: 'pricing-rule', ruleSlug: 'general-english-downsell' }`, то же, что у
`/delta`-хопа (`:72-76`). Движок: `funnels/general-english/sales.json:356-410` перечисляет
**те же три `productId`** с **теми же `amount`/`firstPayment`**, что и главная (`:5-51`), добавляя лишь
`"note": "DOWNSELL"`. Копия при этом — прод-вербатим: «Wait — a better price», «Start for less
today», «A one-time lower price to begin» (`:414-420`, совпадает с `copy.ts:528-530`). То есть
страница обещает скидку, которой нет. Плюс `renderCodeSalesHop.tsx:157-167` на проде 404-ит
фаннел, у которого down-sale-правило пусто, — у движка такого гварда нет.

**G5. Под FTC на down-sale не остаётся ни одного дисклоужера о продлении.**
Прод-`SalesDownsaleLayout.tsx:129-148` рендерит дисклоужер по условию `!!currentSubscription`;
в файле нет ни `useFtcPricing`, ни `isFtcPricing` (проверено grep-ом) — значит FTC-посетитель его
видит. У движка `src/render/sales.ts:268-270` гейтит `billingTerms` через `!ftcOn`, а
`plainTerms()` в чекауте пуст (`src/render/checkout.ts:151`). Под FTC на down-sale-странице
остаются только per-card now/then строки и `ftcNoPaymentNote`; сводная фраза про списание
исчезает. Направление ошибки — «меньше раскрытия под compliance-флагом», т.е. худшее из двух.

**G6. Post-purchase цепочка у `general-english` не заавторена.**
`ls funnels/general-english/` → `config.json`, `locales`, `sales.json`, `theme.json`. Файла
`post-purchase.json` нет, при том что механика и тесты есть
(`schema/post-purchase.schema.ts:185-190`, `tests/chain.test.ts:70-108`). Прод имеет 2 upsell-а
(`general-english-upsell`, `general-english-upsell-vocab`), downsell (`general-english-downsell`) и
thank-you (`.../general-english/index.ts:55-80`). Движок после оплаты отдаёт терминальный
самописный экран (`src/routes/sales.ts:630-643`), т.е. вся пост-покупочная выручка отсутствует.

**G7. `channel` не уходит в order.**
Прод: `Checkout.ts:1201` — `...(total?.channel && { channel: total.channel })`; источник — Strapi-поле
`Subscription.channel` (`FunnelBuilder/types/sales_page.ts:95`), и в живом ответе gringotts оно
заполнено (`plans/gimli2-commerce-binding-probe.md` §3: `"channel": "promova"`). В движке поля
`channel` нет ни в `planSchema` (`schema/sales.schema.ts:44-89`), ни в теле заказа
(`src/checkout.ts:51-62`).

**G8. Способы оплаты сокращены до card/PayPal/Apple/Google без возможности включить остальные.**
`blik: false` жёстко (`src/checkout.ts:57`); `blikButtonParams`/`upiButtonParams`/
`pixAutomaticoButtonParams`/`mbwayButtonParams` в `PaymentFormSdk.init` не передаются
(`src/render/checkout.ts:390-415`). Прод-предупреждение `remote_config.ts:55-58` прямо говорит, что
`blik` в теле заказа и `blikButtonParams` «must never diverge», — у движка они «сходятся» на
выключенном состоянии, так что это безопасно, но PL/PLN, IN/INR и BR/BRL-трафик теряет свои методы.
Плюс PayPal у движка **без** гейта `show_paypal_button` и без проверки
`paypalSupportedCurrencies` (`Checkout.ts:1418-1423,1505-1511`).

**G9. `sandbox` больше не управляется флагом.**
Прод: `useSandBox()` читает GB `use_sand_box` (`utils/customHooks/useSandBox.ts:9-38`, default
`!LIVE_MODE`), и это первая зависимость эффекта монтирования формы
(`useCheckoutEngine.ts:88,119`) — т.е. переключение живое. Движок: `src/routes/sales.ts:466` —
`const sandbox = c.env.LIVE_MODE !== 'true'`. Дежурный не может ни включить sandbox на проде, ни
выключить его на стейдже без редеплоя.

**G10. `billingPeriodInDays` мёржится из биллинга, чего прод не делает.**
`src/pricing.ts:62` мёржит `live.billing_period_in_days`, тогда как
`mappingBillingPlans.ts:33-51` этого поля вообще не касается. При этом собственный комментарий
движка (`src/pricing.ts:41-43`) утверждает обратное. Поле участвует в сортировке карточек
(`src/pricing.ts:179`) и в ветке `<28 days` FTC-дисклоужера (`src/pricing.ts:230-232`) — т.е.
расхождение форматов между CMS и биллингом может переставить карточки и изменить
юридически проверенную фразу.

**G11. Нулевое юнит-покрытие money-логики.**
`grep -rn "render/checkout\|declineView\|mergeLivePrices\|formatPrice\|introPeriodLabel\|showNowThen\|ftcPricing" tests/`
→ пусто. `tests/e2e.test.ts:346-350` проверяет только `status === 200` для трёх FTC-арм, не
проверяя ни одной из FTC-дельт. `tests/sections.test.ts:75-78` покрывает лишь sticky-бар и
`ctaFtc`. Не покрыты: таблица 15 declines, `mergeLivePrices` (в т.ч. all-or-nothing),
`formatPrice` по каждой валюте, `introPeriodLabel`, `showNowThen`, обе FTC-копии чекаута,
FTC-строки сводки. Плюс `tests/e2e.test.ts:290-295` отправляет в `/select` поле `productId`, а
роут читает `form.get('plan')` (`src/routes/sales.ts:345`) — тест «выбора плана» ничего не выбирает.

**G12. Мелкие расхождения вёрстки.**
`compare` без фотографий колонок (прод `SalesLayout.tsx:186`); `courses` заавторено как `stats`
(`sales.json:258`) вместо готового типа; goal-keyed заголовок benefits не выражается; два
showcase-изображения (`SalesLayout.tsx:382-387`) не переносимы; page-level
`chartFootnote` («Not a guarantee of result…») отсутствует; `page_url` в заказе без query-строки
(`src/routes/sales.ts:471`).

---

## Open questions

1. **G1 — продуктовое решение, а не техническое.** «Пустой paywall вместо USD-цен при сбое
   биллинга» надо подтвердить у владельца money-метрики. Нужен ли третий режим (показать
   базовую валюту + баннер «prices shown in USD»)?
2. **G2 — нужен доступ к GrowthBook UI.** Правила `us_pricing_now_then` / `ftc_soft_changes`
   таргетируют `country` как полное название («United States») или как ISO («US»)? Код монорепы
   допускает оба формата на разных путях. Пока это не прочитано, движок для FTC-гео рендерит
   не-compliance вёрстку — это юридический риск, а не косметика.
3. **Down-sale (G4): какой набор продуктов правильный?** `general-english-downsell` в комментарии
   прод-модуля описан как «Pronunciation intensive, one-time», что не похоже на «та же подписка
   дешевле». Нужно дёрнуть
   `GET https://gringotts.promova.work/api/pricing-rule/general-english-downsell/commerce?locale=en`
   и заавторить фактические продукты — до этого копия down-sale вводит в заблуждение.
4. **`channel` (G7): что именно шлёт прод для `general-english`?** В gringotts у подписок
   `"channel": "promova"`. Влияет ли отсутствие поля на биллинг-роутинг/репортинг, или бэкенд
   подставляет дефолт? Вопрос к владельцу биллинга.
5. **Sticky-бар (G3): убрать под FTC — это решение или недосмотр?** Прод его оставляет. Если
   решение осознанное, его надо зафиксировать в `sales.schema.ts` рядом с полем; если нет —
   поправить рендер и заавторить `stickyBar` в `sales.json`.
6. **Pre-auth $1 (`src/render/checkout.ts:314-317`)** — прод-источник этой копии не подтверждён.
   Найти компонент/строку в `CheckoutFooter`, иначе это наша собственная юридическая формулировка
   на платёжном экране.
7. **`anti-fraud-protection` (README:1609)** — в монорепе следов нет (0 вхождений). Это бэкендный
   механизм? Если он может молча выставить `sandbox: true` и вернуть 200 без списания, нужен
   способ это увидеть со стороны движка.
8. **Dead-paywall гварды:** прод 404-ит хоп при пустом commerce, причём асимметрично (строгий для
   `subsTimerZero`, ленивый для sales/down-sale — `renderCodeSalesHop.tsx:130-167`). Движок вместо
   404 рендерит страницу без карточек. Что предпочтительнее для SEO/алертинга?
9. **Legal-футер (§8):** движок рендерит юридические ссылки на paywall, прод-code-фаннел — нет
   (`Sales.tsx:1962-1965`). Это исправление прод-пробела или расхождение, которое надо согласовать
   с legal? Передать агенту по legal.
10. **`revenue_pricing_block_viewed`:** движок его отправляет, прод у code-фаннелов — никогда
    (behavior #30). Начать отправлять = изменить форму funnel-view метрики. Согласовать с
    аналитикой до пилота.
