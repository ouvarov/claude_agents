# Аудит паритета POST-PURCHASE цепочки: prod (Gimli 2.0) → funnel-engine (HTMX)

Дата: 2026-09-08. Спека-база: `plans/gimli2-post-purchase-spec.md` (состояние прода на 2026-09-04).
Всё проверено по коду. Там, где номер строки взят из спеки и я не перепроверял его лично,
стоит **(по спеке)**.

## Вердикт в одну строку

Цепочка в движке **написана, но не включена**: `src/registry.ts:143` —
`const CHAINS: Record<string, unknown> = {}`, ни одного `import` файла
`post-purchase.json`, ни одного авторского чейна ни в одном фаннеле. `getPostPurchase()`
всегда возвращает `null` → `/sierra/:id/paid` терминален, а `/golf`, `/delta`, `/alpha`
недостижимы в рантайме. Из 25 пунктов чек-листа паритета **проходят 9**, частично — 7,
не проходят — 9. Три из непроходящих — это не «недоделка», а поведенческие дефекты
(форма-фолбэк уводит в цикл, двойной чардж, Meta-дубль Purchase).

---

## 1. Таблица паритета

Prod-пути: `promova.com_monorepo/packages/…`; движок: `funnel-engine/…`.

### 1.1 Роуты и состояние

| item | prod source (file:line) | funnel-engine (file:line) | status | note |
|---|---|---|---|---|
| Роуты `/golf`, `/delta`, `/alpha` | `apps/funnels/chameleon/app/[lang]/(funnel-builder)/{golf,delta,alpha}/[...slug]/page.tsx` **(по спеке)** | `src/post-purchase.ts:177-181` (`HOP_PREFIX`), `src/routes/post-purchase.ts:368-374` | DONE | имена роутов сохранены сознательно, обоснование в `src/post-purchase.ts:163-176` |
| Форма URL хопа | `/golf/{salesSlug}/{upsellSlug}/{uid}/{sid}`, `/alpha/{tySlug}/{sid}` **(по спеке `Sales.tsx:550-553`, `MoneyThankYouShell.tsx:53-58`)** | `/golf/:id/:slug` — `src/routes/post-purchase.ts:369` | DELIBERATE-DEVIATION | `uid`/`sid` из URL убраны, личность берётся из `fe_state` (`src/routes/post-purchase.ts:85-96`). Осознанно, но ломает совместимость ссылок и support-дебаг по URL |
| `funnel_slug` и весь searchParams протаскиваются на каждый хоп | `Sales.tsx:1422-1424`, `Upsell.tsx:368-392`, `UpsellDownsell.tsx:266-272` **(по спеке)** | absent | MISSING | движок не переносит query между хопами: в `renderOffer` action собирается из `pathPrefix + prefix + funnelId + slug` без query (`src/render/post-purchase.ts:116`). Для движка `funnel_slug` не нужен (id в пути), но `test_result_id`, `utm_*`, `from=sign-in` теряются |
| Вход в цепочку после оплаты | `Sales.tsx:1395-1474` `handleRedirect` (лестница из 6 шагов) **(по спеке)** | `src/routes/sales.ts:604-617` — `startChain` + 302/`HX-Redirect` на `firstHop` | PARTIAL | воспроизведён только «есть цепочка → первый хоп, нет → терминал». Нет `try_for_free`, нет `isUserFromSignIn → /my-plan`, нет `/xray`, нет `/confirmation-banner`, нет `pushToPlatform()` при `!IS_MAIN_DOMAIN` |
| Токен чарджа | `localStorage[checkout_order_id]` — `Sales.tsx:1319-1326`; конст. `FunnelBuilder/constants/common.ts:55` | `fe_pp`, HttpOnly, `sealIdentity`, Max-Age 7200 — `src/post-purchase.ts:13,26-40,139-157`; `src/routes/post-purchase.ts:120-135` | DELIBERATE-DEVIATION | движок строже прода: order_id зашифрован и не доходит до браузера. Обоснование в `src/post-purchase.ts:15-24` |
| `entity` исходного платежа (для `payment_type`) | `localStorage[checkout_payment_entity]` — `Sales.tsx:1321-1326`; `constants/common.ts:56` | absent | MISSING | `startChain` (`src/routes/post-purchase.ts:125-132`) не сохраняет `entity`, форма `/sierra/:id/paid` его читает (`src/routes/sales.ts:538`) и выбрасывает |
| Отказ хранить order_id для UPI | `Sales.tsx:1315-1320` — `isUpi → не писать` (PRMV-18065) | absent | MISSING | движок сохраняет order_id **всегда** (`src/routes/sales.ts:609`). UPI-покупатель попадёт в одноклик, который упадёт → форма. Результат совпадает, но не по замыслу |
| Отказ хранить order_id для кошельков без флага токенизации | `Sales.tsx:1321-1327` — ветка `isTokenizationForWalletsEnabled` / `!isRebillPayType`; `REBILL_PAY_TYPES` = `constants/common.ts:74` | absent | MISSING | флаг `TOKENIZATION_FOR_WALLETS_SPLIT` в движке не читается вообще |
| `state.done` (какие хопы уже решены) | `sessionStorage` счётчики / `useCallbackOnce` | `src/post-purchase.ts:32`; пишется `src/routes/post-purchase.ts:480,572` | PARTIAL | поле **записывается и нигде не читается** (`grep '\.done'` даёт только записи). Отсюда «revisit после решения» ниже |
| Ретеншн cookie / TTL | пин пакета `upkg_{slug}` 2 ч, не HttpOnly **(по спеке `upsellPackageCookie.ts:20-38`)** | 7200 с, HttpOnly, Secure — `src/post-purchase.ts:141-157` | DONE | тесты: `tests/chain.test.ts:141-151` |
| Deep-link на `/golf` без покупки | Next-страница рендерится, buy падает в модалку | 404 — `src/routes/post-purchase.ts:358-361` | DELIBERATE-DEVIATION | строже прода, обоснование в `src/routes/post-purchase.ts:10-12`; e2e: `tests/e2e.test.ts:332-338` |

### 1.2 Одноклик vs форма

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| `POST /v3/billing/upsales` без auth | `packages/api/billing.ts:41-78` | `src/checkout.ts:325-354` | DONE | |
| Тело запроса | `billing.ts:41-56`: `billing_plan, order_id, quiz_result_id, purchase_url, page_url, channel, payment_type?` | `src/checkout.ts:337-344`: `billing_plan, order_id, purchase_url, page_url, channel:'web'`, `quiz_result_id` только если передан | PARTIAL | **`quiz_result_id` — required в контракте** (`packages/api/schema/schema-payments.d.ts:1339`), а роут его не передаёт (`src/routes/post-purchase.ts:413-419`) → запрос может отбиваться 400. Прод всегда шлёт `'empty'`. `channel` захардкожен `'web'` вместо `currentPlan.channel` (в схеме движка поля `channel` у плана нет вообще) |
| `payment_type: 'rebill'` для кошельков | `Upsell.tsx:743-757` **(по спеке)**; deprecated с PRMV-16278 — `schema-payments.d.ts:1350-1366` | absent | MISSING / возможно OK | если флаг `upsale-server-derived-payment-type` раскатан, поле игнорируется. Открытый вопрос |
| `withRetries: false` | `Upsell.tsx:755` | нет ретраев по построению (`src/checkout.ts:334`) | DONE | |
| FTC-гейт: subscription → всегда форма | `Upsell.tsx:509-511` **(по спеке)** | `src/post-purchase.ts:109-116` `oneClickAllowed`; `src/routes/post-purchase.ts:404-407` | DONE | правило движка, а не конфига (`schema/post-purchase.schema.ts:112-121`); тесты `tests/chain.test.ts:110-120` |
| FTC one-time → одноклик сохраняется | `Upsell.tsx:509-511` | `src/post-purchase.ts:114` | DONE | тест `tests/chain.test.ts:117-118` |
| Не-`success` → тихо открыть форму, без сообщения об ошибке | `Upsell.tsx:776-783` **(по спеке)** | `src/routes/post-purchase.ts:485-491` + фолбэк ниже | DONE | плюс серверный `console.error`, которого у прода нет |
| Неуспешный buy НЕ считается отказом | неявно (прод не инкрементит счётчик) | `src/routes/post-purchase.ts:496-500` (комментарий), skips не растёт | DONE | |
| 3DS на однокликовом чардже | нигде не обрабатывается: `grep -i '3ds\|resign'` по `screens/upsell/` и `api/billing.ts` — пусто; `UpsaleResponse.state` — свободная строка (`schema-payments.d.ts:1089-1096`) | `src/checkout.ts:348` — любой `state !== 'success'` → фолбэк на форму | DONE (паритет) | 3DS-челлендж на одноклике в проде не поддержан вообще; движок ведёт себя так же |
| PayPal-оплаченный основной ордер → одноклик | `paypal` НЕ входит ни в `REBILL_PAY_TYPES` (`constants/common.ts:74`), ни в `PayTypes` (`Checkout/CheckoutForm/types.ts:72-82`) → `entity` пустой → order_id **сохраняется** → одноклик выполняется | `src/routes/sales.ts:609` — тоже сохраняет | DONE (паритет), поведение прода UNVERIFIED | умеет ли бэкенд ре-чарджить PayPal-ордер — открытый вопрос №1 спеки, остаётся открытым |
| Apple / Google Pay одноклик | зависит от `TOKENIZATION_FOR_WALLETS_SPLIT` (`Sales.tsx:1321-1326`) | флаг не читается → одноклик всегда пытается | MISSING | если флаг в проде off, движок будет пытаться чарджить wallet-ордер, чего прод не делает |
| Идемпотентность / защита от двойного чарджа | только `isProcessingRef.current` в браузере (`Upsell.tsx:204,665-669`) + `disabled={isProcessing}` на кнопках (`Upsell.tsx:896,915`); в API-контракте idempotency-ключа нет (`grep -i idempot` по `schema-payments.d.ts` — пусто) | **absent** | MISSING | у движка нет ни `hx-sync`, ни `hx-disabled-elt`, ни серверного дедупа: `src/render/post-purchase.ts:121-124` — обычная форма. Двойной тап = два `POST /golf/:id/:slug/buy` = два `chargeUpsale` с тем же `(order_id, billing_plan)`. Чек-лист №25 **не проходит** |
| Форма-фолбэк на хопе | `CheckoutModal` поверх апселла, `onSuccess → handleSuccess(e,false,true)` (`Upsell.tsx:808-828`) | `src/routes/post-purchase.ts:507-546` рендерит `renderCheckout` | **MISSING (дефект)** | `src/render/checkout.ts` захардкожен на sales-эндпоинты: success → `POST /sierra/${funnelId}/paid` (`:458`), fail → `/sierra/${funnelId}/declined` (`:472,479`), close → `/sierra/${funnelId}/close` (`:288`), target'ы `sales-body` / `checkout-slot`, которых на pp-странице нет (`bodyId: 'pp-body'` — `src/routes/post-purchase.ts:195`). См. Gap G1 |

### 1.3 Цепочка и переходы

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| Покупка апселла → следующий апселл, НЕ downsell | `Upsell.tsx:317-353` `shouldShowDownsell` **(по спеке)** | `src/post-purchase.ts:73-91` | DONE | тесты `tests/chain.test.ts:75-86` |
| Downsell только после отказа от ПОСЛЕДНЕГО апселла | `Upsell.tsx:347` (`isLastUpsell && isSkipped && !codeDownsellShown`) **(по спеке)** | `src/post-purchase.ts:84-89`, `downsellDue` `:95-99`, режим `lastUpsellSkipped` по умолчанию | DONE | |
| Strapi-семантика «3 скипа» как опция | `Upsell.tsx:350` **(по спеке)** | `schema/post-purchase.schema.ts:155-158` (`skipCount` + `skipThreshold`) | DONE | порог авторский, обоснование `:144-153` |
| Downsell один раз | `sessionStorage['upsell_downsell_bundle_shown']` на **view** (`UpsellDownsell.tsx:229`) **(по спеке)** | `state.ds` ставится на **skip** downsell-хопа: `src/routes/post-purchase.ts:573` | PARTIAL | если визитёр downsell **купил** или просто ушёл со экрана, `ds` остаётся `false` → повторный `POST .../skip` на последнем апселле снова выдаст downsell. Прод помечает на показе |
| Потолок хопов | `swym-2` был 5, стал 1 (`say-what-you-mean-2/index.ts:20-24`: «ONE upsell … public-speaking course upsell was removed 2026-08-06»); `general-english` = 2 | `schema/post-purchase.schema.ts:217-224` — валидатор режет >2 | DONE | тест `tests/chain.test.ts:64-67` |
| `/delta` терминален | `UpsellDownsell.tsx:251-281` `goToFinish` **(по спеке)** | `src/post-purchase.ts:79-82` (`index === -1 → thank-you`) | DONE | тест `tests/chain.test.ts:90-91` |
| Неизвестный слаг | `console.error + notFound()` (`renderCodeUpsellHop.tsx:71-78`) **(по спеке)** | 404 — `src/routes/post-purchase.ts:363-364`; в `nextHop` — конец цепочки (`src/post-purchase.ts:82`) | DONE | плюс проверка «слаг под своим префиксом» `:364` |
| Мёртвый pricing rule / хоп без продуктов | 404 (`renderCodeUpsellHop.tsx:92-99`) **(по спеке)** | **пропуск хопа**, не 404 — `src/routes/post-purchase.ts:283-292` | DELIBERATE-DEVIATION | обоснование `:221-229`: 404 посреди цепочки бросает уже заплатившего. Чек-лист №15 формально не проходит, но осознанно |
| Back / refresh посреди цепочки | `router.push` меняет URL на каждый хоп → back работает | нет `hx-push-url` в `src/render/post-purchase.ts:121-128`; swap в `#pp-body` | MISSING | URL остаётся на ПЕРВОМ хопе, пока тело показывает второй. Refresh → снова первый хоп, снова его `revenue_pricing_page_viewed` |
| Повторный визит на уже решённый хоп | `sessionStorage`-гейты + смена URL | `state.done` не читается (см. выше) | MISSING | GET `/golf/:id/{уже купленный slug}` рендерится заново, и его кнопка buy может списать второй раз |
| `revenue_pricing_page_viewed` один раз | `useCallbackOnce(..., !isPending)` (`Upsell.tsx:570-579`) **(по спеке)** | `src/routes/post-purchase.ts:304-315` — на каждый GET | MISSING | дубли на refresh/back |

### 1.4 Downsell-продукты и данные

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| Реальные продукты цепочки | `general-english/index.ts:15-17,55-75`: upsell-1 → rule `general-english-upsell` (4 Business English guides, one-time), upsell-2 → `general-english-upsell-vocab`, downsell-1 → `general-english-downsell` (Pronunciation intensive, one-time). `english-hub/index.ts:15-17`: `english-hub-upsell` (id 57, bundle), `english-hub-upsell-vocab` (id 58), `english-hub-downsell` (id 56). `say-what-you-mean-2/index.ts:82-90` → `say-what-you-mean-2-ai-speaking-assessment-rule`; `say-what-you-mean-3/index.ts:25-27,92-100` → `say-what-you-mean-3-upsell-test` (rule 54, subscription 2475), on-page downsell rule 53 (2472/2473/2474) | **absent** — ни одного `post-purchase.json`; `src/registry.ts:143` `CHAINS = {}` | MISSING | это данные, а не механизм, но без них цепочка мертва |
| Резолв продуктов из pricing rule | `resolveCommerce` → `GET /pricing-rule/{slug}/commerce` **(по спеке `resolveCommerce.ts:143-180`)** | absent — движок требует авторских `plans[]` с `productId` (`schema/post-purchase.schema.ts:106`) | DELIBERATE-DEVIATION | согласовано с sales-схемой движка, но требует ручной синхронизации с gringotts |
| Клиентский скоринг `usePricingRuleSubscription` (country вес 2 + `localStorage.utm_source` вес 1) | `packages/utils/customHooks/usePricingRuleSubscription.ts:20-101` **(по спеке)** | absent | MISSING | тот же пробел, что G2 в §4.2 спеки для sales-down-sale |
| `bestOfferProductId` в down-sale | `best_offer_subscription` **(по спеке `buildSyntheticSalesPage.ts:96-108`, `Sales.tsx:542`)**; `say-what-you-mean-3/index.ts:79` явно фиксирует «No `bestOfferSubscriptionId`» | absent в `schema/sales.schema.ts` | MISSING | пробел G3 спеки не закрыт |
| Мульти-продуктовый (bundle) хоп | `english-hub` upsell-bundle — один продукт из rule | `plans: z.array(planSchema).min(1)` (`schema/post-purchase.schema.ts:106`); цена — **сумма** (`src/render/post-purchase.ts:63,79`), чардж — **только `plans[0]`** (`src/routes/post-purchase.ts:396,418`) | **MISSING (дефект)** | хоп с 2+ планами покажет сумму, а спишет один продукт. См. Gap G3 |

### 1.5 Thank-you (`/alpha`)

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| Минимальный экран (бейдж + title + body + одна CTA) | `code-funnels/money/general-english/layouts/ThankYouLayout.tsx:15-32` | `src/render/post-purchase.ts:139-151` | DONE | паритет с code-layout прода |
| CTA ведёт в приложение | `goToApp = pushToPlatform` (`MoneyThankYouShell.tsx:61-69` **по спеке**; `ThankYouLayout.tsx:17,27`) | `<a href="${webOrigin}${localePath(page.href)}">` — `src/render/post-purchase.ts:144,149` | PARTIAL | обычная ссылка на `/complete-sign-up`, без query и без sid |
| Autologin (magic link) на платформу | `POST /v1/users/link_for_auth` через `getAuthLink` **(по спеке `usePlatformRedirect.ts:53-61`)** | **absent** на pp-пути (эндпоинт есть только в `src/routes/diag.ts:55-63`) | MISSING | кросс-хост сессии нет; визитёр приходит на платформу неаутентифицированным |
| HRP-маршрутизация (`/complete-sign-up` vs `/my-plan`) | `usePlatformRedirect.ts:39,53-58` **(по спеке)**; HRP пишется `setupCodeFunnelUser.ts:160-161` | `href` — статичное поле конфига, дефолт `/complete-sign-up` (`schema/post-purchase.schema.ts:178-180`) | MISSING | чек-лист №20 не проходит: `from=sign-in` и HRP=false не разводятся |
| Handoff-query (`utm_funnel` raw + fbclid/gclid/gbraid + все observeUtms) | `packages/utils/buildPlatformHandoffQuery.ts:22-77` **(по спеке)** | **absent** — `src/render/post-purchase.ts:144` собирает href без query; `grep utm_funnel` по движку даёт только `analytics/attribution.ts:22` | MISSING | чек-лист №21 не проходит; единственный канал атрибуции через bridge→promova.com (PRMV-18037) обрывается |
| `funnels_completed_funnel_survey` перед навигацией | `usePlatformRedirect.ts:76-84` **(по спеке)** | absent (`grep completed_funnel_survey` по `src/` — пусто) | MISSING | чек-лист №22 не проходит; спека просила отдельный `POST /…/ty/go` (§10.2), маршрута нет |
| Store-ссылки / QR / smart banner | Strapi `DownloadSection.tsx:27-80` + `packages/config/constants/downloadLinks.ts:10-15` (4 AppsFlyer OneLink); code-layout'ы прода **их не имеют** | absent; `storeLinks` из §10 спеки в схему **не попал** (`schema/post-purchase.schema.ts:171-181`) | PARTIAL / DELIBERATE-DEVIATION | паритет с code-фаннелами прода — да; но §10 спеки требовал поле в DSL, и его нет. Продуктовое решение (открытый вопрос №9 спеки) |
| Сводка заказа / referral | прод не показывает | absent; `showPurchaseSummary` из §10 в схему тоже не попал | DONE (паритет) | |
| Set-password форма | живёт в `apps/student/components/modules/CompleteSignUp/CompleteSignUp.tsx` **(по спеке)** | absent, сознательно — `schema/post-purchase.schema.ts:162-170` | DELIBERATE-DEVIATION | правильно: форма ключена на `sid` из письма |
| Reteno / CIO на thank-you | ничего **(по спеке §5.6)** | ничего | DONE | |
| Per-platform рендер (iOS/Android/desktop) | только через `DownloadSection` (Strapi) | absent | PARTIAL | нет ни в проде на code-пути |
| Копия подтверждения по email | не на thank-you (Reteno с email-шага) | absent | DONE (паритет) | |

### 1.6 Аналитика

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| `revenue_pricing_page_viewed` на хопе | `Upsell.tsx:570-579`, `UpsellDownsell.tsx:242-248` **(по спеке)** | `src/routes/post-purchase.ts:304-315` | PARTIAL | имя есть, но конверт неверный (ниже), и нет once-гейта |
| `revenue_started_checkout` на КАЖДЫЙ buy-клик, ДО выбора модалка/одноклик | `Upsell.tsx:717-730` **(по спеке)** | `src/routes/post-purchase.ts:389-402` | DONE | чек-лист №16 проходит, обоснование в комментарии `:389-392` |
| `revenue_purchased` на одноклике | `Upsell.tsx:762-770` **(по спеке)** | `src/routes/post-purchase.ts:462-478` | DONE | `amount = firstPayment`, `provider:'solid'` |
| `revenue_pricing_cta_ignored {button_type:'skip'}` | `Upsell.tsx:633-640` **(по спеке)** | `src/routes/post-purchase.ts:557-567` | PARTIAL | `button_type` не передаётся |
| `revenue_checkout_closed` на pp | `Upsell.tsx:645-662`, `UpsellDownsell.tsx:337-352` **(по спеке)** | absent — `/close` есть только для sales (`src/render/checkout.ts:288`) | MISSING | |
| `product_type: 'upsell'` / `'upsell_downsell'` | `Upsell.tsx:449-461` (`'upsell'`), `UpsellDownsell.tsx:215-225` (`'upsell_downsell'`) **(по спеке)** | `src/analytics/money.ts:183,211` — union только `'subscription' \| 'downsell'` | MISSING | апселл-хоп репортится как `product_type:'subscription'`, а `/delta` как `'downsell'` — то есть **сливается с on-page down-sale sales-страницы**. Апселл-воронка в Amplitude нечитаема |
| `screen_name` / `page_path` | `'upsell'` / `'upsell-downsell'`, `page_path = pathname` **(по спеке `Upsell.tsx:539-546`)** | `src/analytics/money.ts:206,207` — `'sales'\|'downsale'`, `page_path` захардкожен `/sierra/{funnelId}` | MISSING | |
| `subscription_status: premium\|free` из `/v1/billing/products/available` | `Upsell.tsx:217-220,548-579` **(по спеке)** | `src/analytics/money.ts:212` — захардкожен `'free'` | MISSING | на пост-оплатном пути визитёр только что купил → прод скажет `premium` |
| `slug` = слаг хопа | `params.slug[1]` / `'upsell-downsell'` **(по спеке)** | передаётся в props и перебивает конверт (`src/analytics/money.ts:498`), роуты передают `slug: hop.hop.slug` | DONE | |
| Meta: апселл → `trackCustom('Upsell')`, НИКОГДА `Purchase` | `packages/utils/analytics.ts:677-703` **(по спеке)** | `src/analytics/money.ts:320-341` — всегда `fbq('track','Purchase', std:true)` | **MISSING (дефект)** | чек-лист №18 не проходит: Meta получит второй Purchase на каждый купленный апселл → двойной учёт конверсий и порча оптимизации. См. Gap G2 |
| TikTok server-side дубль только на апселлах | `sendTikTokToServer` **(по спеке)** | `src/routes/post-purchase.ts:454-460` (`tiktokToServer: true`) vs `src/routes/sales.ts:552-559` (`false`) | DONE | чек-лист №17 (часть про TikTok) проходит |
| `eventID = order_id` для Meta | `analytics.ts:677-703` **(по спеке)** | `purchaseAdValues({orderId: charge.orderId})` → `ad.eventId` (`src/analytics/money.ts:340`) | DONE | |
| Reteno `upsell_purchased` ровно один раз | `Upsell.tsx:606-623`, `useCheckout.ts:100-114` **(по спеке)** | absent (`grep -i reteno` по `src/` — только квиз/email) | MISSING | чек-лист №19 не проходит |
| GA4 `purchase_ecommerce` на pp | прод фаерит только с Sales (`Sales.tsx:1332-1348` **по спеке**) | сознательно нет — `src/routes/post-purchase.ts:16-20` | DONE | |
| `revenue_closed_payment_form`, LTV-лукапы, Impact Radius | `useCheckout.ts:136-212` **(по спеке)** | LTV есть (`src/analytics/ltv.ts`), остальное absent | PARTIAL | |
| Amplitude-сессия одна на весь путь | — | `chainMoneyCtx` берёт `sessionFor(quizState)` — `src/routes/post-purchase.ts:157-182` | DONE | известный баг уже починен, см. комментарий `:137-156` |

### 1.7 Цены, легалка, локализация

| item | prod source | funnel-engine | status | note |
|---|---|---|---|---|
| Живые цены хопа (`/v1/billing/products`, мердж all-or-nothing) | `Upsell.tsx:463-484`, `packages/api/getMulticurrencyProducts.ts:11-90` **(по спеке)** | `src/routes/post-purchase.ts:230-245` + `mergeLivePrices` | DONE | при пустом ответе — пропуск хопа, а не вечный лоадер |
| Валютная локализация | `formatMoney(price, currencySymbol)` — `general-english/layouts/UpsellLayout.tsx:81-85,97` | `money()` из `src/pricing.ts` — `src/render/post-purchase.ts:66,74,79` | DONE | |
| Intro / rebill: цена «сегодня» vs «потом» | `UpsellLayout.tsx:28-36` (`hasIntro → firstPayment`) | `src/render/post-purchase.ts:63` (`firstPayment`), `:79` (`amount` в renewalLine) | DONE | |
| Зачёркнутая цена | `UpsellLayout.tsx:37-44`: приоритет `currentPlan.fakeDiscount`, затем `amount` при intro | `src/post-purchase.ts:126-137` — только `intro` или синтетический процент | PARTIAL | **`fakeDiscount` (маркетинговая «regular») не поддержан** — реальный источник зачёркивания в проде выпал |
| Бейдж `{N}% OFF` | `UpsellLayout.tsx:45,75-77`; downsell — хардкод `70% OFF` **(по спеке `UpsellDownsell.tsx:467-469`)** | absent — `renderOffer` процент не считает и не рисует | MISSING | |
| Суффикс `/{period}` у цены | `UpsellLayout.tsx:87-89` | absent; период только внутри `renewalLine` | PARTIAL | |
| Синтетическая скидка 70 % на `/delta` | `UpsellDownsell.tsx:446-450` **(по спеке)** | `schema/post-purchase.schema.ts:129-140`, `src/post-purchase.ts:130-134` | DONE | вынесено в конфиг, а не константа; тесты `tests/chain.test.ts:128-131` |
| ROSCA / renewal-строка одним шаблоном | `copy.ts:492` + `UpsellLayout.tsx:94-100` | `schema/post-purchase.schema.ts:56-61`, `src/render/post-purchase.ts:72-83` | DONE | one-time не получает renewal-строку (тест `tests/chain.test.ts:180-181`) |
| FTC-дисклеймер на самом апселле (`OneTimeLegalShort`) | `Upsell.tsx:886-891` (в футере, при `isNowThenPricing`) + доп. padding `:789-797` | absent на offer-экране | MISSING | под FTC движок покажет апселл вообще без раскрытия — при этом одноклик для subscription он запрещает, так что риск смещён на one-time |
| FTC: skip визуально равен accept | `Upsell.tsx:913-940` (`OnboardingButton` вместо текстовой ссылки) | `src/render/post-purchase.ts:117,127` (`u-skip-equal`) | DONE | тест `tests/chain.test.ts:165-171` |
| FTC-вариант (hard / soft) в чекауте хопа | `useFtcPricing` возвращает вариант **(по спеке `hooks/useFtcPricing.ts:24-31`)** | `ftcFor()` возвращает **boolean** (`src/routes/post-purchase.ts:247-261`), в `renderCheckout` захардкожено `variant:'hard'` (`src/routes/post-purchase.ts:538`); sales-путь при этом вариант знает (`src/routes/sales.ts:122,194-197`) | MISSING | под soft-FTC покажется hard-копия (в проде hard — сырой JSX US-only, soft — локализованный `<Trans>`) |
| Legal-текст чекаута (`checkout-text`) | общий `Checkout` | `getLegalCheckoutText` — `src/routes/post-purchase.ts:521-525` | DONE | |
| Legal-футер (merchant name/address, refund) на pp-экранах | прод рендерит на каждой странице фаннела (`LegalFooterText`) | absent: `footerText` есть только в `src/render/sales.ts:57,624-625`, `shell()` в `src/routes/post-purchase.ts:184-209` его не передаёт | MISSING | offer и thank-you — единственные экраны без юрлица и refund-ссылок |
| Локализация цепочки | `buildLocalizedMoneyCopy(useMoneyLocale())` — `ThankYouLayout.tsx:16`, `UpsellLayout.tsx:23`; каталоги `code-funnels/money/general-english/locales/{de,es,fr,it,pt}.ts` | **absent** — `getPostPurchase(funnelId)` без locale и без `translateTree` (`src/registry.ts:147-168`); сравн. `getLocalizedSalesPage` (`src/registry.ts:226-239`) | MISSING | вся цепочка англоязычна; в movie-схеме `title/body/cta` — плоские строки конфига |

---

## 2. Gaps (с доказательствами)

### G0. Цепочки нет в рантайме — она недостижима
`src/registry.ts:143`:
```ts
const CHAINS: Record<string, unknown> = {}
```
Ни одного `import … from '../funnels/*/post-purchase.json'` (в `src/registry.ts:1-4` импортируются
только `config.json`, `sales.json`, `locales/uk.json`, `theme.json`). Файла
`funnels/general-english/post-purchase.json` нет (`ls funnels/general-english/` → `config.json`,
`sales.json`, `theme.json`, `locales/`). Следствие: `getPostPurchase()` → `null` для любого
фаннела → `src/routes/sales.ts:607` (`if (chain)`) никогда не срабатывает, `/sierra/:id/paid`
терминален. `scripts/validate-funnels.ts:453-467` **читает** `post-purchase.json` с диска, то есть
валидатор и рантайм расходятся: авторский чейн пройдёт `pnpm validate` и не заработает.
README сам себе противоречит: `README.md:1061` «No upsell chain after payment. `/s/:id/paid`
is terminal», `README.md:1129` — описание чейна на устаревшем `/p/:id/:slug`.
`tests/e2e.test.ts:327-338` проверяет только 404 без cookie — позитивного e2e нет, потому что
нечего проходить.

### G1. Форма-фолбэк на хопе уводит в цикл и переписывает состояние цепочки
`src/routes/post-purchase.ts:532-546` рендерит тот же `renderCheckout`, что и sales, а тот
захардкожен на sales-эндпоинты:
- `src/render/checkout.ts:458` — `post('/sierra/${ctx.funnelId}/paid', …, 'sales-body')`
- `src/render/checkout.ts:472,479` — `post('/sierra/${ctx.funnelId}/declined', …, 'checkout-slot')`
- `src/render/checkout.ts:288` — close → `/sierra/${funnelId}/close`
- `src/render/checkout.ts:500` — `track()` → `/sierra/${funnelId}/event`

Что произойдёт после успешной оплаты апселла через форму:
1. запрос уйдёт в `/sierra/:id/paid` (`src/routes/sales.ts:532`), который посчитает план по
   `data.sale?.sel` — то есть **план sales-страницы, а не апселла** (`src/routes/sales.ts:541`);
2. эмитит `revenue_purchased` + `sales_payment_success` с ценой основной подписки и
   `ga4Purchase` (`:562-598`);
3. вызовет `startChain(c, page.id, orderId)` (`:609`) → **сбросит `skips`, `done`, `ds`** и
   отправит визитёра на **первый хоп** (`:610-612`);
4. swap-таргеты `sales-body` / `checkout-slot` на pp-странице отсутствуют (`bodyId: 'pp-body'`,
   `src/routes/post-purchase.ts:195`) → htmx не найдёт цель.

Итого: покупка апселла формой = повторный учёт основной покупки + возврат в начало цепочки.
Это блокер, а не косметика. `renderCheckoutUnavailable(funnelId, pathPrefix)`
(`src/render/checkout.ts:595-607`) — та же проблема: кнопка «повторить» ведёт на
`/sierra/:id/checkout`.

### G2. Meta получит `Purchase` на апселле вместо `trackCustom('Upsell')`
`src/analytics/money.ts:320-341` — на `MONEY_EVENTS.PURCHASED` всегда
`{ sink: 'fbq', event: 'Purchase', std: true }`. Условия «это апселл» в `moneyMirror` нет,
потому что `MoneyContext` (`src/analytics/money.ts:190-199`) знает только `isDownsale`.
Прод для апселлов посылает `fbq('trackCustom','Upsell')` и **никогда** `Purchase`
(`packages/utils/analytics.ts:677-703`, **по спеке**). Чек-лист №18 не проходит.

### G3. Хоп с несколькими планами показывает сумму, а списывает один продукт
Показ: `src/render/post-purchase.ts:63` — `total(ctx.plans,'firstPayment')`, `:79` —
`total(ctx.plans,'amount')`. Чардж: `src/routes/post-purchase.ts:396` — `const first = plans[0]!`,
`:418` — `productId: first.productId`. Схема разрешает `plans` длиной >1
(`schema/post-purchase.schema.ts:106`) и объясняет это существующим bundle-хопом в проде.
То есть авторский bundle-хоп продаст один продукт по цене двух.

### G4. `quiz_result_id` не передаётся, хотя он required
`packages/api/schema/schema-payments.d.ts:1339` — `quiz_result_id: string` (без `?`).
`src/checkout.ts:343` — `...(opts.quizResultId ? { quiz_result_id: opts.quizResultId } : {})`,
а вызов в `src/routes/post-purchase.ts:413-419` поля не передаёт вовсе. Прод всегда шлёт
значение (`'empty'` при отсутствии, **по спеке** `Upsell.tsx:753`). Одноклик может
отбиваться 400 → тихий фолбэк на форму (G1) на каждом хопе.

### G5. Двойного чарджа ничто не держит
`src/render/post-purchase.ts:121-124` — обычная форма без `hx-sync`, `hx-disabled-elt`,
`hx-indicator`. `grep -rn 'hx-disabled-elt\|hx-sync' src/render src/routes` → единственное
попадание `src/render/screens.ts:156` (`hx-indicator`, квиз). Серверного дедупа нет:
`chargeUpsale` (`src/checkout.ts:325-354`) не несёт идемпотентного ключа, и в API-контракте
его тоже нет (`grep -i idempot schema-payments.d.ts` → пусто). Прод держится на
`isProcessingRef` + `disabled` (`Upsell.tsx:204,665-669,896,915`) — слабо, но хоть что-то.
Чек-лист №25 не проходит.

### G6. `state.done` пишется и не читается → повтор решённого хопа
`grep -rn '\.done\b' src/post-purchase.ts src/routes/post-purchase.ts` → только объявление
(`src/post-purchase.ts:32`) и три записи (`src/routes/post-purchase.ts:128,480,572`).
Ни `resolveRequest` (`:344-366`), ни `showHop` (`:264-333`), ни `nextHop`
(`src/post-purchase.ts:73-91`) его не смотрят. Плюс нет `hx-push-url` → URL не двигается
за хопом. Следствия: refresh возвращает на первый хоп и дублирует его
`revenue_pricing_page_viewed`; GET на слаг уже купленного апселла отдаёт рабочую кнопку buy.

### G7. Флаг `ds` ставится на выходе, а не на показе
`src/routes/post-purchase.ts:573` — `ds: state.ds || hop.kind === 'downsell'` только в
обработчике `/skip`. Купил downsell или закрыл вкладку — `ds` остался `false`
(`/buy` на строке 480 обновляет только `done`). Прод помечает на **view**
(`UpsellDownsell.tsx:229`, **по спеке**). Downsell может показаться повторно.

### G8. Ни handoff-query, ни magic link, ни `funnels_completed_funnel_survey` на thank-you
`src/render/post-purchase.ts:144` — `const href = ${opts.webOrigin}${opts.localePath(opts.page.href)}`.
Никакого query, никакого `sid`, никакого `link_for_auth`
(`grep -rn 'link_for_auth' src/` → только `src/routes/diag.ts:57`),
никакого `funnels_completed_funnel_survey` (`grep` по `src/` — пусто).
Спека §10.2 требовала `POST /s/:id/ty/go` — маршрута нет. Чек-листы №20, №21, №22 не проходят.

### G9. Конверт аналитики на pp-пути врёт по четырём полям
`src/analytics/money.ts:200-215`: `screen_name` = `'sales'|'downsale'`,
`page_path` = `/sierra/{funnelId}`, `product_type` = `'subscription'|'downsell'`,
`subscription_status` = `'free'`, `user_type` = `'unregistered'`.
Роуты pp переопределяют только `slug` и `planProps`
(`src/routes/post-purchase.ts:311-314,400,469-475,564-566`); остальное едет как есть,
потому что `payload = { ...envelope, ...scaled }` (`src/analytics/money.ts:498`).
Отдельно: апселл-хоп получает `product_type:'subscription'` (то есть неотличим от
основной покупки), а `/delta` — `'downsell'`, то есть неотличим от on-page down-sale
sales-страницы.

### G10. Цепочка не локализована
`src/registry.ts:147` — `getPostPurchase(funnelId: string)`, без locale, без `getCatalog`,
без `translateTree` — в отличие от `getLocalizedSalesPage` (`src/registry.ts:226-239`).
Прод code-фаннелы локализуют money-копию (`ThankYouLayout.tsx:16`, `UpsellLayout.tsx:23`,
каталоги `code-funnels/money/general-english/locales/{de,es,fr,it,pt}.ts`).

### G11. Legal-футер и FTC-дисклеймер отсутствуют на offer/thank-you
`shell()` (`src/routes/post-purchase.ts:184-209`) не запрашивает `getLegalFooterText`
(`src/platform.ts:287-291`) и не передаёт `footerText` — поле существует только в
`src/render/sales.ts:57,624-625`. `renderOffer` не рисует аналог `OneTimeLegalShort`
(`Upsell.tsx:886-891`). Вариант FTC в чекауте хопа захардкожен `'hard'`
(`src/routes/post-purchase.ts:538`), хотя `ftcPricing` умеет вариант и sales-путь его
использует (`src/routes/sales.ts:122,194-197`).

### G12. Данных нет: ни одного авторского хопа, ни `bestOfferProductId`, ни скоринга по гео/трафику
Живые продукты прода перечислены в §1.4. В движке — ничего.
`bestOfferProductId` в `schema/sales.schema.ts` отсутствует (пробел G3 спеки §4.2 открыт).
`usePricingRuleSubscription`-эквивалента нет нигде (пробел G2 спеки открыт).

### Мелкое
- `skipTopLabel` объявлен в схеме (`schema/post-purchase.schema.ts:30-32`) и **не рендерится**
  `renderSection` (`src/render/post-purchase.ts:44-51`) — а в проде это отдельная кнопка
  top-right (`UpsellLayout.tsx:52-59`).
- `button_type: 'skip'` не идёт в `PRICING_CTA_IGNORED` (`src/routes/post-purchase.ts:563-566`).
- `channel` захардкожен `'web'` (`src/checkout.ts:342`), у плана в схеме движка поля нет;
  прод шлёт `currentPlan.channel`, пример в контракте — `'promova'`
  (`schema-payments.d.ts:1346-1349`).
- Декоративный 10-минутный таймер `/delta` (прод: `CountdownTimer.tsx:9-68`, **по спеке**)
  в движке отсутствует — вероятно правильно (открытый вопрос №8 спеки).
- `grantCourses` реализован по DSL, а не через `/v1/courses/short`
  (`src/routes/post-purchase.ts:426-448`, схема `:124-126`) и не роняет визитёра при провале
  (`:441`) — это лучше прода.

---

## 3. Чек-лист паритета спеки: результат

| # | пункт | verdict |
|---|---|---|
| 1 | оплата → первый хоп с сохранённым `funnel_slug` | PARTIAL — хоп есть (`src/routes/sales.ts:604-617`), query не переносится |
| 2 | покупка апселла → следующий апселл | PASS |
| 3 | скип промежуточного → следующий апселл, счётчик +1 | PASS |
| 4 | скип последнего → `/delta` один раз | PARTIAL — «один раз» держится только через skip-путь (G7) |
| 5 | скип на `/delta` → `/alpha` с searchParams | PARTIAL — переход есть, query нет |
| 6 | покупка на `/delta` → `/alpha` | PASS (`nextHop`, `src/post-purchase.ts:79-82`) |
| 7 | нет order_id → форма | PASS (`src/routes/post-purchase.ts:420`) |
| 8 | UPI → апселл через форму | PARTIAL — по факту, не по замыслу (entity не хранится) |
| 9 | кошелёк без флага → order_id не сохранён | FAIL |
| 10 | кошелёк с флагом → `payment_type:'rebill'` | FAIL |
| 11 | FTC + subscription → форма | PASS |
| 12 | FTC + one-time → одноклик | PASS |
| 13 | не-success → форма без сообщения | PASS |
| 14 | неизвестный слаг → 404, не подмена | PASS |
| 15 | мёртвый rule → 404, не лоадер | DELIBERATE-DEVIATION (пропуск хопа) |
| 16 | `revenue_started_checkout` на каждый buy | PASS |
| 17 | `revenue_purchased` c TikTok-server + `eventID = order_id` | PASS |
| 18 | Meta на апселлах — `Upsell`, никогда `Purchase` | FAIL (G2) |
| 19 | Reteno `upsell_purchased` один раз | FAIL (Reteno на pp нет) |
| 20 | thank-you CTA: HRP / sid маршрутизация | FAIL (G8) |
| 21 | `utm_funnel` raw в handoff-query | FAIL (G8) |
| 22 | `funnels_completed_funnel_survey` до навигации | FAIL (G8) |
| 23 | пин пакета не меняется между хопами | N/A — `upsellPackages` в схеме движка нет вообще |
| 24 | `__fallback__` тоже пинится | N/A |
| 25 | двойной тап не создаёт двух чарджей | FAIL (G5) |

**PASS 11 · PARTIAL 4 · FAIL 7 · DELIBERATE-DEVIATION 1 · N/A 2.**

---

## 4. Открытые вопросы

**Требуют человека / бэкенд**
1. **Идемпотентность `/v3/billing/upsales`.** В контракте ключа нет
   (`schema-payments.d.ts:1322-1367`), `UpsaleResponse.state` — свободная строка
   (`:1089-1096`). Прод защищается только браузерным `isProcessingRef`. Нужен либо
   серверный ключ на бэке, либо серверный дедуп в движке по `(oid, productId)` в `fe_pp`.
   Пока этого нет, любой ретрай/двойной тап — потенциальный второй чардж.
2. **PayPal-ордер и одноклик.** Прод его не исключает (`paypal` нет ни в `REBILL_PAY_TYPES`
   — `constants/common.ts:74`, ни в `PayTypes` — `Checkout/CheckoutForm/types.ts:72-82`),
   значит одноклик по PayPal-ордеру формально выполняется. Умеет ли бэкенд его ре-чарджить —
   по-прежнему **UNVERIFIED**.
3. **`quiz_result_id` реально required?** Если да — G4 блокирует одноклик целиком.
4. **`payment_type` после PRMV-16278.** Состояние флага
   `upsale-server-derived-payment-type`? Если раскатан — движку поле не нужно, и G-пробел
   про кошельки сужается до «не хранить order_id для UPI».
5. **`channel`.** `'web'` — валидное значение? Прод шлёт `currentPlan.channel` (пример в
   контракте — `'promova'`). Нужно ли поле `channel` в `planSchema` движка.
6. **Сколько живёт order_id как чардж-токен?** От этого зависит, 7200 с — это много или мало
   (`src/post-purchase.ts:157`).

**Продукт**
7. **Нужен ли `/delta` в MVP?** 3 из 5 живых модулей его не объявляют, а
   `english-hub/index.ts:20-25` фиксирует прямое требование маркетолога делать down-sale
   ДО покупки. Механизм в движке уже есть и стоит дешево; вопрос в данных.
8. **Что показывает thank-you движка?** Store-ссылки (`storeLinks`) из §10 спеки в схему не
   попали. Паритет с code-layout'ами прода — да; но тогда фиксируем, что OneLink-блока не
   будет, и вычёркиваем его из §10.
9. **Autologin.** Нужен ли magic link с хоста движка, или thank-you просто ведёт на
   `/complete-sign-up` и пароль ставится там? Без magic link визитёр приходит на платформу
   неаутентифицированным — на code-пути прода он приходит аутентифицированным.
10. **Отдельный `funnel_name` для пилота** — тот же вопрос, что в README; на pp-пути он
    острее, потому что все `revenue_*` группируются по нему.

**Флаги / доступы**
11. **FTC-флаги** резолвятся в false для всех стран (пробел из README) — на pp-пути это
    значит, что subscription-апселл спишется молча одним кликом. Плюс вариант hard/soft
    в чекауте хопа захардкожен (`src/routes/post-purchase.ts:538`).
12. **`TOKENIZATION_FOR_WALLETS_SPLIT`** — текущее состояние? От него зависит, будет ли у
    wallet-покупателей одноклик и надо ли движку хранить `entity`.
13. **`anti-fraud-protection`** может вернуть 200 с `sandbox: true` — на апселле визитёр даже
    формы не видит, так что «успех без денег» здесь незаметнее, чем на sales.

**Расхождения, которые стоит показать команде (из спеки — подтверждаю, живые)**
14. `Upsell.handleSuccess` игнорирует флаг токенизации, в отличие от `Sales.tsx:1321-1327`
    и `UpsellDownsell` (**по спеке** `Upsell.tsx:599-604`). Порту решить: воспроизводить
    асимметрию или нет. Сейчас движок не воспроизводит ни ту, ни другую ветку.
15. Валидатор движка (`scripts/validate-funnels.ts:453`) читает `post-purchase.json` с диска,
    а рантайм (`src/registry.ts:143`) — нет. Это ловушка: чейн пройдёт проверку и не заработает.
16. README `funnel-engine/README.md:1061` vs `:1129` — противоречие плюс устаревший роут
    `/p/:id/:slug`.
