# Аудит аналитики: funnel-engine против прода (2026-09-08)

Проверено по коду. Прод — `/Users/uvarovalexandr/myProject/promova.com_monorepo`
(живой путь `/kilo/[funnel_id]` в `apps/student`, зеркало `apps/funnels/chameleon`,
общая механика в `packages/features/FunnelBuilder`, `packages/utils/analytics.ts`,
`packages/ui/common/CommonScripts`). Движок — `/Users/uvarovalexandr/myProject/funnel-engine`.

Существующие документы (`plans/gimli2-analytics-inventory.md`,
`plans/gimli2-analytics-parity.md`) использованы как чек-лист. **Два их утверждения
опровергнуты кодом** — см. «Ошибки в предыдущих документах».

Не проверялось живьём: Loki/Grafana (MCP `grafana` в этой сессии не поднялся —
`CONNECTION_CLOSED`), Amplitude taxonomy, Meta Events Manager. Всё ниже — статический
разбор исходников.

---

## 1. Ошибки в предыдущих документах (проверено)

**1.1. `gen_joined_ab_test` «не эмитится ни там, ни там»** (`gimli2-analytics-parity.md:45-47`)
— неверно для прода. Прод фаерит его **двумя независимыми путями**:

- автоматически из `trackingCallback` GrowthBook на КАЖДЫЙ evaluate эксперимента
  (`packages/utils/growthbook/growthBook.ts:52-69` → `sendJoinABTestOncePerSession`),
  кроме ключей из `MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS`;
- вручную, 6 раз в квизе (`packages/features/FunnelBuilder/hooks/useOnboardingScreen.ts:331,354,374,387,408,426`),
  на sales (`pages/Sales/Sales.tsx:866,889,904,919,934,1227`), на апселе
  (`components/screens/upsell/Upsell.tsx:302,557`), на email
  (`pages/Email/Email.tsx:240`), в `ElysiumPlans.tsx:140`,
  `packages/utils/analytics.ts:1066,1102`, `SplitScreen/SplitScreen.tsx:34`.

Движок не эмитит его нигде: `gen_joined_ab_test` объявлен в
`src/analytics/envelope.ts:36` и не используется; `src/growthbook.ts` не имеет
никакого tracking-колбэка, а `activeFlags()` (`src/growthbook.ts:201-209`) решает
вариант контента и **молча** — экспозиция флага не репортится. То есть любой
A/B-тест, поданный движком через `flags`, будет невидим в Amplitude.

**1.2. «Движок при `hold` глушит и зеркало, и серверные отправки»**
(`gimli2-analytics-parity.md:106-109`) — верно **только для квиза**. На money-path
`hold` не доходит до эмиттера вообще: `MoneyContext`
(`src/analytics/money.ts:189-199`) не имеет поля `hold`, а `emitMoney`
(`src/analytics/money.ts:501-528`) гейтит отправку только по
`LIVE_MODE`/`SEND_EVENTS`. `consentFor(c).hold` в `routes/sales.ts:257` и
`routes/post-purchase.ts:185` уходит **только** в `holdForConsent` браузерных
бутстрапов. Следствие: для EEA-посетителя на пейволе движок шлёт серверный
Amplitude и TikTok Events API до ответа на баннер.

---

## 2. Таблица паритета

Легенда: DONE / PARTIAL / MISSING / DEVIATION (осознанное отклонение) / BUG.

### 2.1. Механика фан-аута и конверт

| item | прод (file:line) | funnel-engine (file:line) | статус | примечание |
|---|---|---|---|---|
| единый билдер конверта | 4 разных: `code-funnels/FunnelContext.tsx:916`, `hooks/useOnboardingScreen.ts:300`, `pages/Sales/Sales.tsx:588`, money `analyticsContext.tsx:67` | один: `src/analytics/envelope.ts:98-120` | DEVIATION | лучше прода, намеренно |
| `domain/funnel_name/screen_id/localization/source/user_type/screen_type/step_type/ad_topic/country/slug/page_path` | `FunnelContext.tsx:916-940` | `envelope.ts:103-118` | DONE | имена совпадают |
| `step_number` тип | СТРОКА: `String(progress.current)` (`FunnelContext.tsx:921,964`) | ЧИСЛО: `Envelope.step_number: number` (`envelope.ts:107`) | BUG | в одном Amplitude-проекте свойство станет mixed-type; группировки и фильтры «step_number = 3» перестанут покрывать оба источника |
| `country_funnel` | `FunnelContext.tsx:942`, чекаут `sendCheckoutEvents.ts:63`, purchase `sendPurchaseEvents.ts:36` | `envelope.ts:115` (только квиз); в `buildMoneyEnvelope` (`money.ts:201-215`) ОТСУТСТВУЕТ | PARTIAL | PRMV-17789: без него geo-routed сессии нечитаемы; на money-path пропало |
| `ab_arm` | `FunnelContext.tsx:922` (из `?ab_arm`, сплиттер припаркован) | `envelope.ts:74`, всегда undefined | DONE | паритет по факту (оба undefined) |
| дедуп-ключ квиза | нет (только React-рефы) | `insert_id = SHA-256(sid\|screen\|event\|occurrence)`, `envelope.ts:127-145`, `emit.ts:134,157` | DEVIATION | лучше прода |
| дедуп-ключ money | нет | **нет** — `emitMoney` не ставит `insert_id` (`money.ts:509-518`), `logEvent(null,…)` (`money.ts:506`) | BUG | см. gap G1 |
| транспорт зеркала | прямые вызовы в браузере | `#pixel-boot` (`render/layout.ts:482`) + `script.fe-mirror` в фрагменте (`http.ts:157-163`), реплей `analytics/pixels.ts:155-318` | DEVIATION | ограничение 16 КБ хедеров обойдено |
| `src/render/pixels-inline.ts` | — | 1 строка ре-экспорта `PIXEL_REPLAY_SCRIPT` | — | файл-заглушка, вся логика в `analytics/pixels.ts` |
| QA-гейты `?block_analytics`/`?preview` | `getAnalyticsSettings()` (`utils/analytics.ts:120-148`), 7 `BLOCK_*` флагов + `isPreviewMode` | нет эквивалента; только `LIVE_MODE`/`SEND_EVENTS`/`LOAD_PIXELS` (`emit.ts:105`, `http.ts:27`) | MISSING | пункт 17 инвентаря не портирован |
| `IS_PRODUCTION` гейт | `sendAnalytics` (`utils/analytics.ts:171`) | `sendsExternally` (`emit.ts:105`) | DONE | |

### 2.2. Amplitude — события квиза

| событие | прод | движок | статус |
|---|---|---|---|
| `funnels_page_viewed` | `FunnelContext.tsx:912` | `routes/quiz.ts:570,595,997,1178` | DONE |
| `funnels_started_funnel` | `FunnelContext.tsx:970` (+ `getStartEventVisibilityProps()`: visibility_state/has_focus/time_to_event_ms) | `routes/quiz.ts:596` — **без visibility-пропсов** | PARTIAL |
| `funnels_started_funnel_confirmed` | `constants/analytics.ts:35`, `packages/utils/funnelStartConfirmation.ts` | `routes/quiz.ts:620` (клиент POST-ит на `/kilo/:id/event`) | DONE |
| `funnels_screen_answered` | `FunnelContext.tsx:1188` | `routes/quiz.ts:1098` | DONE |
| `funnels_button_clicked` | `constants/analytics.ts:63` | `routes/quiz.ts:621` | DONE |
| `funnels_loader_viewed` | `constants/analytics.ts:39` | `routes/quiz.ts:1178` | DONE |
| `funnels_test_completed` + `funnels_test_level_completed` (парой, идентичный payload) | `constants/analytics.ts:56-57` | `routes/quiz.ts:1098,1150` | DONE |
| `funnels_core_guarantee_violated` | `FunnelContext.tsx:135,1639` | `routes/quiz.ts:1166` | DONE |
| `funnels_screen_unresolved` | `components/FunnelScreenSwitcher.tsx:61` — **эмитится** | объявлено `envelope.ts:34`, не эмитится | MISSING (по смыслу N/A: у движка нет клиентского switcher'а, нерезолвленный экран невозможен) |
| `funnels_email_field_touched` / `_changed` | `constants/analytics.ts:60-61` | `routes/quiz.ts:622-623` | DONE |
| `funnels_email_submited_pending` (опечатка каноничная) | `constants/analytics.ts:62` | `routes/quiz.ts:827` | DONE |
| `funnels_email_entered_error` | `constants/analytics.ts:55` | `routes/quiz.ts:796,861,889` | DONE |
| `funnels_email_completed` | `sendEmailAnalytics.ts:94-97` | `routes/quiz.ts:852,973` | DONE |
| `gen_joined_ab_test` | см. §1.1 | нет | MISSING |
| generic `page_view` | `usePageView.ts:97-104` (на каждый pathname, `{domain, page_path, ...utm}`) → dataLayer + PostHog + Amplitude + ttq ViewContent + twq | нет | MISSING |
| `funnels_immediate_feedback_viewed` | `constants/analytics.ts:58` | нет | MISSING (фича не авторится в движке) |
| `funnels_time_to_study` | событие в проде; в движке только как Reteno-свойство (`src/engine.ts:310`) | — | PARTIAL |

**Свойства `funnels_email_completed`.** Прод (`sendEmailAnalytics.ts:57-71`):
`domain, funnel_name, country_funnel, screen_id, source, auth_type, user_email` (RAW),
`user_type, subscription_status, localization, screen_name, answer=sha256(email), ad_topic`,
опц. `cluster_number`. Движок (`routes/quiz.ts:973-978`): `auth_type, user_email` (RAW),
`answer` (hashed), `subscription_status` + конверт. **Отсутствуют `screen_name` и
`cluster_number`.**

### 2.3. Amplitude — user properties / identify

| item | прод | движок | статус |
|---|---|---|---|
| `screen_size`, `user_agent` | `useInitializeCommonPixels.ts:122-128` | `render/third-party.ts:113-118` | DONE |
| `device_os`, `device_type`, `device_size_width`, `device_size_height` | `useInitializeCommonPixels.ts:131-133` + `useDeviceData.ts:23-28` | нет | MISSING |
| `visitor_id` (антифрод Scotch) | `useInitializeCommonPixels.ts:96,129` | нет | MISSING |
| UTM-identify (`set` + `setOnce initial_*`, once/session) | `useSaveUTMsToAmplitude.ts:23-90` + `useInitializeCommonPixels.ts:142-146` | нет | MISSING |
| referrer-identify (once/session) | `buildReferrerIdentifyEvent`, `useInitializeCommonPixels.ts:148-152` | нет | MISSING |
| `user_email` / `user_type` на профиле | `sendEmailAnalytics.ts:77-78` | `routes/quiz.ts:845,971` через `sink:'amplitude-identify'` (`pixels.ts:59`) | DONE |
| `ab_test.<key>` user prop | `sendJoinABTestOncePerSession` (`utils/analytics.ts:1066,1102`) | нет | MISSING |
| порядок identify→track (FIFO) | да | да (`pixels.ts:219-225`, одна очередь `__ampQueue`) | DONE |
| `defaultTracking` всё off | `useInitializeCommonPixels.ts:110-116` | `render/third-party.ts:105-108` | DONE |
| Scotch-гейт на init Amplitude (пункт 11 инвентаря) | `useInitializeCommonPixels.ts:88` (`isScotchReady`) | нет | DEVIATION (осознанно: device_id минтится сервером) |

### 2.4. Amplitude — money-path

| событие | прод | движок | статус |
|---|---|---|---|
| `revenue_pricing_page_viewed` | `constants/analytics.ts:40` | `routes/sales.ts:320`, `routes/post-purchase.ts:310` | DONE |
| `revenue_pricing_block_viewed` | `constants/analytics.ts:41` (мёртв на code-воронках) | `routes/sales.ts:321` (шлётся всегда) | DEVIATION |
| `revenue_pricing_cta_clicked` | `constants/analytics.ts:45` | `routes/sales.ts:357` | DONE |
| `revenue_pricing_cta_ignored` | `constants/analytics.ts:42` | `routes/sales.ts:772`, `post-purchase.ts:563` | DONE |
| `revenue_started_checkout` | `sendCheckoutEvents.ts:91-94` | `routes/sales.ts:399-404`, `post-purchase.ts:393-399` | PARTIAL — см. свойства ниже |
| `revenue_checkout_form_mounted` | `packages/features/Checkout/Checkout.ts` | `routes/sales.ts:665` | DONE |
| `revenue_clicked_payment_type` | `analyticsEvents.ts:40` | `routes/sales.ts:666,698` | DONE |
| `revenue_initiated_transaction` | `analyticsEvents.ts:31` | `routes/sales.ts:667,711` | DONE |
| `revenue_checkout_closed` | `constants/analytics.ts:46` | `routes/sales.ts:765` | DONE |
| `revenue_closed_payment_form` (двойной фаер с closed) | `analyticsEvents.ts:32` | нет | DEVIATION (баг прода, не портировать — инвентарь :76) |
| `revenue_purchased` | `analyticsEvents.ts:41`, `utils/analytics.ts:736-738` | `routes/sales.ts:566`, `post-purchase.ts:468` | DONE (единицы исправлены: `money.ts:494-497`) |
| `sales_payment_success` | `sendPurchaseEvents.ts:44-47` (`{funnel_name, country_funnel, source, total}`) | `routes/sales.ts:584` (money-конверт + planProps + order_id) | PARTIAL — payload другой, `total` отсутствует |
| `upsell_purchased` | `Upsell.tsx:620`, `UpsellDownsell.tsx:316` (Reteno) | нет | MISSING |
| `upsell_offer_viewed/accepted/declined` | `constants/analytics.ts:51-53` | нет | MISSING |
| `revenue_upsell_viewed/added/removed/read_clicked/chosen/success` | `analyticsEvents.ts:34-39` | нет | MISSING |
| `funnels_overview_viewed_downsell` | `analyticsEvents.ts:43` | нет | MISSING |
| `revenue_post_purchase_flow_started/clicked/completed`, `revenue_after_purchase_flow` | `analyticsEvents.ts:121-124` | нет | MISSING |
| `revenue_started_free_plan` | `constants/analytics.ts:44`, `Sales.tsx:1583` | нет | MISSING (фича не авторится) |
| `revenue_spin_wheel_viewed/clicked/result_viewed` | `constants/analytics.ts:64-66` | нет | MISSING (фича не авторится) |
| `checkout_section_viewed`, `checkout_not_now_click` | `constants/analytics.ts:48-49` | нет | MISSING (inline-чекаут не авторится) |
| `resolved_paywall_goal_group` | `analyticsEvents.ts:6` | нет | MISSING |
| `sales_price_viewed` (Reteno-only) | `SalesUiProvider.tsx:75` | нет | MISSING |
| `revenue_seen_price_section`, `revenue_pricing_faq_clicked` | `analyticsEvents.ts:33` / литерал | нет | MISSING |
| `funnels_payment_declined` | нет | `money.ts:168`, `routes/sales.ts:512` | DEVIATION (новое, вне `revenue_`-семейства намеренно) |

**Свойства `revenue_started_checkout`.** Прод (`sendCheckoutEvents.ts:61-89`):
`funnel_name, country_funnel, slug, source, is_user_from_email, product_type,
product_id_funnel, subscription_status, localization, screen_name,
...subscriptionData` (весь спред подписки), `condition_id`, опц. `checkout_name`,
`cluster`, `weekPrice`. Движок (`money.ts:201-228`): `domain, funnel_name, slug,
screen_name, page_path, source, localization, country, product_type,
subscription_status, user_type` + `planProps` (6 полей). **Отсутствуют:
`is_user_from_email`, `condition_id`, `checkout_name`, `cluster`, `weekPrice`,
спред `subscriptionData`, `country_funnel`.** (Совпадает с §6
`gimli2-analytics-parity.md` — подтверждено.)

### 2.5. Браузерные пиксели

| пиксель | прод грузится? | движок | статус |
|---|---|---|---|
| Meta `fbq` | да, `CommonScripts.tsx:74` (`withFacebook=true`), init `:240-258` | `render/third-party.ts:141-152` | DONE |
| GTM / `dataLayer` | да, `packages/ui/common/Shared/HtmlShell.tsx:16`, `SharedDocument.tsx:41` | `render/third-party.ts:127-135` | DONE |
| TikTok `ttq` | да, `CommonScripts.tsx:77,190-212` (`withTiktok=true`) | `render/third-party.ts:154-167` | DONE |
| OpenAI `oaiq` | **да**, `CommonScripts.tsx:79,215-236` (`withOpenAi=true`), покупка `utils/analytics.ts:633-670` | нет | MISSING |
| Microsoft Clarity | **да, всегда** — `CommonScripts.tsx:260` → `Scripts/Clarity/ClarityAnalyticsScript.tsx:6-14` | нет | MISSING |
| Impact Radius (`ire`) | **да, всегда** — `CommonScripts.tsx:261` (`ImpactIdentify`), покупка при `utm_source=impact` | нет | MISSING |
| CookieYes | да, `CommonScripts.tsx:157` | `render/consent.ts:143` | DONE |
| Snapchat `snaptr` | нет (`withSnap=false`, `CommonScripts.tsx:76`) | sink объявлен (`pixels.ts:78`), вызовов нет | DEVIATION (корректно) |
| Twitter `twq` | нет (`withTwitter=false`, `:75`) | sink объявлен (`pixels.ts:80`), вызовов нет | DEVIATION (корректно) |
| Pinterest `pintrk` | нет (`withPinterest=false`, `:78`) | sink объявлен (`pixels.ts:79`), вызовов нет | DEVIATION (корректно) |
| Bing `uetq` / Reddit `rdt` | не найдены нигде в монорепе | нет | N/A |
| PostHog | `capturePostHog` вызывается (`utils/analytics.ts:181`), но `bootstrapPostHogClient` есть только в `chameleon` → на `apps/student` ноль событий | нет | DEVIATION (задокументировано) |
| двойной push GA4 (`{ecommerce:null}` затем событие) | `utils/analytics.ts:412-413` | `pixels.ts:213-218` | DONE |
| гвард «init один раз на документ» | React-монтирование | `third-party.ts:68-73` + `if(f.fbq)return` | DONE |

**Пиксельные вызовы по событиям:**

| вызов | прод | движок | статус |
|---|---|---|---|
| `fbq('track','PageView',{fbc})` | `CommonScripts.tsx:253-255` | `third-party.ts:151` | DONE |
| `fbq ViewContent` на каждый экран | `usePageView.ts:60-66` (deps `[isInitializeFacebook, pathname]`) | только на `funnels_started_funnel` (`pixels.ts:119-127`) | PARTIAL |
| `ttq ViewContent` на каждый экран | `trackPageView` (`utils/analytics.ts:311-317`) через generic `page_view` | нет | MISSING |
| подавление `ttq ViewContent` для `funnels_page_viewed` | `utils/analytics.ts:314` | `pixels.ts:114-117` | DONE |
| `fbq CompleteRegistration` | `sendEmailAnalytics.ts:104-113`, eventID = свежий uuid (`sendDefaultFacebookEvent`, `utils/analytics.ts:363`) | `pixels.ts:131-138`, eventID = `insert_id` | DEVIATION (лучше: общий id с серверной ногой) |
| `em` (advanced matching) в `fbq` | `sendEmailAnalytics.ts:112` + re-init `CommonScripts.tsx:117-133` для flowPixelId И domainPixels | **никогда**: `EmitContext.email` читается в `emit.ts:142`, но **не присваивается нигде**; `PixelConfig.email` не передаётся ни в `quiz.ts:370-380`, ни в `sales.ts:271-279`, ни в `post-purchase.ts:198-206` | MISSING |
| `ttq CompleteRegistration` | `sendEmailAnalytics.ts:87-93` | `pixels.ts:138` | DONE |
| `fbq InitiateCheckout` | `sendCheckoutEvents.ts:119-128` | `money.ts:285-296` | DONE |
| `ttq InitiateCheckout` | `sendCheckoutEvents.ts:96-101` | `money.ts:299-304` | DONE |
| `fbq AddPaymentInfo` | `Checkout.ts:660-679` + PayPal-ветка `:688-692` | `money.ts:307-318` | DONE |
| `fbq Purchase` (main) | `utils/analytics.ts:672-681`, eventID = `data.order_id`, payload `buildFacebookPurchaseData` | `money.ts:320-340`, eventID = orderId | PARTIAL — payload беднее (см. ниже) |
| `fbq trackCustom 'Upsell'` для апсела | `utils/analytics.ts:685-698` (ветка `isUpsell`) | нет — движок шлёт **`Purchase`** и на апселе (`money.ts:329`, вызов `post-purchase.ts:468`) | BUG |
| `content_ids` / `content_type` / `order_id` в Meta Purchase | `packages/utils/buildFacebookPurchaseData.ts:60-69` | нет: `money.ts:333-338` шлёт только `value, currency, predicted_ltv, funnel_name`; `ltv.ts:161-165` тоже их не собирает | MISSING |
| `ttq Purchase` | `utils/analytics.ts:701-716` | `money.ts:341-350` | DONE |
| `ttq AddPaymentInfo` на `sales_payment_success` | `sendPurchaseEvents.ts:49-54`, event_id = свежий uuid | `money.ts:353-362`, event_id = orderId | PARTIAL |
| GA4 `view_item_list` | `Sales.tsx:833` | `money.ts:83-92`, `sales.ts:331` | DONE |
| GA4 `view_item` | `Sales.tsx:850-853` | **нет** | MISSING |
| GA4 `add_to_cart` | `Sales.tsx:1009` | `money.ts:100-109`, `sales.ts:332,368` | DONE |
| GA4 `begin_checkout` | `Sales.tsx:1557` | `sales.ts:693` | DONE |
| GA4 `purchase_ecommerce` (`transaction_id` = subscription_id) | `Sales.tsx:1340-1345` | `money.ts:120-134`, `sales.ts:600` | DONE |
| `dataLayer.push({event:'purchase', … ecommerce, items, ltv, user_email})` — **живая Google Ads конверсия** | `utils/analytics.ts:578-611` | нет | MISSING |
| legacy `dataLayer.push({ecommerce:{purchase:{…}}})` | `utils/analytics.ts:613-631` | нет | MISSING |
| `oaiq('measure','order_created')` / `'custom'` c `custom_event_name:'upsell'` | `utils/analytics.ts:633-670`, event_id = order_id | нет | MISSING |
| GA4 на экранах апсела | нет (`sendECommerceAnalytics` только из `Sales.tsx`) | нет | DEVIATION (паритет) |

### 2.6. Серверные интеграции

| item | прод | движок | статус |
|---|---|---|---|
| Amplitude HTTP v2 с сервера | нет (только браузерный SDK) | `src/analytics/amplitude.ts:34-74`, парсинг `events_ingested` | DEVIATION (лучше прода) |
| TikTok Events API (прокси `/tiktok/event/track`) | `utils/analytics.ts:242-247`, `sendToServerTikTokEvent.ts` — **живой**, но внутри `if (tiktok)` | `analytics/tiktok.ts:75-92`, `emit.ts:73-96`; **независим от пикселя** | DEVIATION (лучше прода) |
| TikTok server: какие события | `CompleteRegistration` (email), `InitiateCheckout`, `AddPaymentInfo`, `Purchase` (только апселы) | `emit.ts:69-71` (только `funnels_email_completed`), `money.ts:376-408` (`InitiateCheckout`, `AddPaymentInfo`, `Purchase` при `tiktokToServer`) | DONE |
| TikTok server payload | только `user.email` = sha256, опц. `properties.{value,currency,contents}` (`utils/analytics.ts:222-241`) | `money.ts`-путь — так же (`tiktok.ts:44-66`); **квизовый путь (`emit.ts:89`) шлёт `properties: envelope`** — весь конверт воронки, включая `answer`/ответы | BUG (приватность + расхождение) |
| Meta CAPI напрямую | `sendToServerFacebookEvent.ts:114` — `FB_PROXY_DISABLED = true`, ранний return, МЁРТВ намеренно (PRMV-17926) | нет | DEVIATION (правильно, не реанимировать) |
| **живой backend-CAPI-feed**: `PATCH /v1/users/properties` с `{fbc,fbp}` | `packages/api/user.ts:61-85` (`getFacebookDataWhenReady` — 3s поллинг), вызов `Sales.tsx:1475` | нет | MISSING |
| **живой backend-CAPI-feed**: `POST /v1/billing/funnel/users/payload` с `facebook_pixel_id` + `page_view.url` | `packages/api/user.ts:43-51`, вызов `Sales.tsx:1276-1303` | нет | MISSING |
| `POST /v1/marketing/events` (`logFacebookEvent`) на каждый fbq-эвент | `packages/utils/facebookEventLogger.ts:44-72`; вызовы `utils/analytics.ts:365,677,690` | функция есть (`src/platform.ts:402-416`), **не вызывается ниоткуда** | MISSING (мёртвый код) |
| `POST /v1/users/utm` (`saveUserUtm`) | `packages/api/user.ts:105-115` | нет | MISSING |
| Reteno: `funnels_email_completed` + профильные свойства + slug | `sendEmailAnalytics.ts:122-132`, `useCodeFunnelEmail.ts:46` | `platform.ts:340-387`, `routes/quiz.ts:923,948,961` | DONE |
| Reteno на money-path (`revenue_started_checkout`, `revenue_started_free_plan`, `upsell_purchased`, `sales_price_viewed`) | `sendCheckoutEvents.ts:145`, `Sales.tsx:1583`, `Upsell.tsx:619`, `SalesUiProvider.tsx:75` | нет | MISSING |
| Snap/Pinterest/Twitter/OpenAI CPA-лукапы (5 параллельных `/v1/info/{dest}/values`) | `utils/analytics.ts:490-530` — 5 назначений (google, facebook, pinterest, snapchat, tiktok) | 2: `productLtv(tiktok)` + `facebookProductValues` (`money.ts:434-440`) | PARTIAL (соответствует набору живых пикселей, но Google LTV в dataLayer purchase потерян вместе с самим push'ем) |
| формула LTV (fee-модель + retention) | `packages/utils/getPriceValue.ts` | `src/analytics/ltv.ts:24-77` — портирована построчно | DONE |
| правило Meta value/currency/predicted_ltv одной валютой (PRMV-18362) | `buildFacebookPurchaseData.ts:56-69` | `ltv.ts:152-166` | DONE |
| USD-флип TikTok LTV | `utils/analytics.ts:709` | `money.ts:449-453` | DONE |

### 2.7. Идентичность и атрибуция

| item | прод | движок | статус |
|---|---|---|---|
| `_ppdi` (имя, 365d, path=/, Lax, Secure) | `packages/config/constants/storageKeys.ts:5`, `utils/deviceId/getOrCreateDeviceId.ts:32-37` | `analytics/attribution.ts:12,71-82` | DONE |
| `?ampDeviceId=` кросс-домен | `getOrCreateDeviceId.ts:16-22` | `attribution.ts:62-63` | DONE |
| `?ampSessionId=` кросс-домен | `packages/config/constants/amplitude.ts:2`, `useInitializeCommonPixels.ts:98-109` | нет | MISSING |
| session_id: катящаяся 30-минутная | SDK по умолчанию | `state.ts:264-276` (`sessionFor`/`touchSession`), `amplitude.ts:82`, передаётся в браузерный SDK (`quiz.ts:377`) | DONE (док-комментарий `amplitude.ts:76-81` устарел — говорит «pinned to run start») |
| session_id на money-страницах передаётся в браузерный SDK | — | **нет**: `sales.ts:271-279` и `post-purchase.ts:198-206` не передают `sessionId` | BUG (см. G1) |
| список 24 UTM-параметров | `packages/config/constants/common.ts:201-227` | `attribution.ts:15-40` — совпадает вербатим | DONE |
| sourcebuster `current` как fallback | `buildUtmParams.ts:31-38` | нет | MISSING |
| `traffic_type` (sourcebuster `typ`) | `common.ts:228-235` | нет | MISSING |
| `initial_*` семантика | first-touch из `sourcebuster.get.first`, **раз за сессию** (`buildUtmParams.ts:20-29`, `FIRST_SESSION_PAGE_VIEW_SEND`) | из URL/cookie текущего визита; замораживаются в `state.attr` (`http.ts:126`) и **едут на КАЖДОМ событии** (`envelope.ts:118`) | PARTIAL — другой источник и другая частота |
| `shared_utms` cookie | монорепа | `attribution.ts:85,151-164` | DONE |
| `fbclid` fallback-цепочка | URL → hash → localStorage → sessionStorage → cookie (пункт 1 инвентаря) | URL → cookie → фрагмент через beacon `/kilo/:id/fbclid` (`attribution.ts:184-190`, `parity.md:135`) | PARTIAL |
| `_fbc` формат `fb.1.<ms>.<fbclid>` | `getFacebookData.ts` | `attribution.ts:178-182` | DONE |
| кеш `promova_fbc` со стабильным timestamp 90d | монорепа | `fbclidCookie` 90d (`attribution.ts:103-107`), но `buildFbc` пересчитывает `Date.now()` при каждом вызове если нет `existing`, а `existing` не передаётся из `requestCtx` (`http.ts:200`) | BUG — timestamp в `_fbc` дрейфует между событиями одного визита; Meta матчит по (fbclid+ts), нестабильный ts снижает match quality |
| per-funnel Meta pixel id | `FLOW_FACEBOOK_PIXEL_ID`, пишется дважды (`useFacebookPixel` + `FunnelContext.tsx:625`) | `quiz.ts:370` (`quiz.tracking.facebookPixelId ?? FB_PIXEL_ID`); на money-страницах — только `FB_PIXEL_ID` (`sales.ts:272`, `post-purchase.ts:199`) | PARTIAL |
| `external_id` в Meta | только в CAPI (`utils/analytics.ts:679`), CAPI мёртв | нет | DEVIATION |
| `user_type` registered/unregistered | `selectIsUnregisteredUser` (клиентское `auth.currentUser.isAnonymous`) | `http.ts:195,233-237` — cookie `withAuth=true` | DONE |
| `user_id` в Amplitude | Firebase uid → потом платформенный | `emit.ts:154` (Firebase uid из sealed identity), биндится в браузер через `X-Amplitude-User-Id` (`pixels.ts:272-281`) | DONE |
| device-continuity после хэндоффа | тот же `_ppdi` | тот же `_ppdi`, same-origin за CF route split | DONE |

### 2.8. Consent (EEA)

| sink | прод | движок | статус |
|---|---|---|---|
| Google-теги (GA4/Ads) | Consent Mode v2 default denied + CookieYes (`ui/common/Scripts/GTMConsentMode/ConsentModeScript.tsx`) | `render/consent.ts:100-125`, эмитится ПЕРЕД GTM | DONE (порядок лучше прода) |
| `fbq` / `ttq` / Amplitude SDK | монтируются безусловно (`CommonScripts.tsx:190,240`), согласие не читают | held до grant (`third-party.ts:81,172-188`) | DEVIATION (строже) |
| Clarity | безусловно | не грузится вообще | N/A |
| список регионов | hardcoded в проде, `'EL'` вместо `GR`, без `CH` | `consent.ts:27-34` — `GR` + `CH` | DEVIATION (исправлено) |
| серверный Amplitude/TikTok, квиз | — | гейтится `ctx.hold` (`http.ts:205`, `emit.ts:166`) | DEVIATION (строже) |
| **серверный Amplitude/TikTok, money-path** | — | **не гейтится**: `MoneyContext` без `hold`, `emitMoney` смотрит только на `LIVE_MODE`/`SEND_EVENTS` (`money.ts:507`) | BUG (см. §1.2 / G2) |
| fail-open при отсутствии `cf-ipcountry` | — | `consentFor` → `needsConsent(null)` = false (`consent.ts:36`), предупреждение `http.ts:100-110` | DEVIATION (решение Алекса, риск принят) |
| бэкфилл событий после grant | — | нет (`emit.ts:162-165`) | DEVIATION (задокументировано) |

### 2.9. Own event log / мониторинг

| item | прод | движок | статус |
|---|---|---|---|
| first-party лог событий | нет | `src/analytics/log.ts:41-65`, одна JSON-строка в stdout, `kind:'funnel_event'` | DEVIATION (новое) |
| лог пишется до внешнего гейта | — | `emit.ts:169` — синхронно и первым | DONE |
| `event_id` в логе money-события | — | всегда `null` (`money.ts:506`) | PARTIAL |
| логи в Loki | прод пишет в Loki через Faro | **не подтверждено** — в этой сессии MCP `grafana` не поднялся; открытый пункт `parity.md:170` не закрыт | OPEN |
| Faro (RUM + ошибки) | живой на воронке: `pages/Sales/Sales.tsx:464,1489,1504,1543`, `components/screens/upsell/Upsell.tsx:417`, `features/Checkout/Checkout.ts`, `utils/faroReports.ts`, `utils/sendFaroError.ts`, `utils/faroBuffer.ts`, категории `ErrorCategory.FUNNEL_BUILDER`/`TRACKING` | **нет ничего**: только `console.error` (`emit.ts:174`, `money.ts:527`, `ltv.ts:106,111`, `growthbook.ts:118,133`) | MISSING |
| Sentry | не найден | нет | N/A |
| rate-limited error reporting | `sendFaroError` (per-message limiter) | нет | MISSING |
| Amplitude «200 + events_ingested:0» детект | — | `amplitude.ts:60-68` | DEVIATION (лучше) |

### 2.10. A/B тесты

| item | прод | движок | статус |
|---|---|---|---|
| GrowthBook remoteEval | `growthBook.ts:50` | `src/growthbook.ts:106-113` (`POST /api/eval/{key}`) | DONE |
| атрибуты (`custom_user_id`, `country`, `utm_source`, `device`, `platform`, `device_id`, `funnel_id`, `localization`) | `useAddGrowthBookAttributes` | `growthbook.ts:93-104` | DONE |
| `trackingCallback` → `gen_joined_ab_test` | `growthBook.ts:52-69` | **нет** | MISSING |
| ручные `gen_joined_ab_test` на сплитах воронки/sales/upsell/email | 15+ мест, см. §1.1 | нет | MISSING |
| `updateGrowthBookKeeper` (сохранение арма в keeper) | `useUpdateGrowthBookKeeper` | нет | MISSING |
| per-visitor evaluate | да (клиентский SDK на визитёра) | кеш по country/device/utm/funnel/locale, БЕЗ device_id (`growthbook.ts:81-88`) | DEVIATION — процентные роллауты резолвятся раз на когорту, а не на визитёра; реальный сплит-тест с движка невозможен |
| `MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS` | `packages/config/constants/remote_config.ts` | нет | MISSING |

### 2.11. Контрактные тесты

| item | прод | движок | статус |
|---|---|---|---|
| golden-file снапшот потока событий | — | **нет ни одного теста аналитики**: `grep -in "analytic\|pixel\|insert_id\|event_id\|emit" tests/` даёт 2 нерелевантных совпадения (`tests/e2e.test.ts:128`, `tests/session.test.ts:12`) | MISSING |
| Playwright request-interception | `apps/funnels/chameleon/tests/e2e/` | нет | MISSING |
| unit-тесты формул (`buildFacebookPurchaseData`, `getPriceValue`) | `packages/utils/buildFacebookPurchaseData.test.ts`, `getFacebookProductValues.test.ts`, `faroReports.test.ts` | нет | MISSING |
| пакет `@promova/funnel-events` как общий якорь | не создан | не создан | MISSING |

---

## 3. Gaps (по blast radius)

**G1. Money-события уходят в Amplitude ДВАЖДЫ, без ключа идемпотентности.**
`emitMoney` отправляет серверный `AmplitudeEvent` без `insert_id`
(`src/analytics/money.ts:509-518`), и одновременно `moneyMirror` кладёт
`{sink:'amplitude', event: name, params}` **без `eventId`**
(`src/analytics/money.ts:280-282`). Реплей вызывает
`window.amplitude.track(c.event, c.params, { insert_id: c.eventId })`
(`src/analytics/pixels.ts:199`) — то есть `insert_id: undefined`. Дедупа нет ни на
одной стороне. При `LIVE_MODE=true` (оба гейта открыты) каждое
`revenue_pricing_page_viewed`, `revenue_started_checkout`, `revenue_purchased`,
`sales_payment_success` попадёт в Amplitude в двух экземплярах → выручка и
конверсия пейвола завышаются вдвое. Усугубляется тем, что на money-страницах
браузерному SDK не передан `sessionId` (`routes/sales.ts:271-279`,
`routes/post-purchase.ts:198-206`), поэтому две копии ещё и в разных сессиях —
склеить их постфактум нельзя.

**G2. Серверная аналитика money-path не читает согласие.**
`MoneyContext` (`src/analytics/money.ts:189-199`) не имеет `hold`;
`consentFor(c).hold` в `routes/sales.ts:257` и `routes/post-purchase.ts:185`
попадает только в `holdForConsent` браузерных бутстрапов. Для EEA-посетителя
пейвола Amplitude и TikTok Events API получают данные до ответа на баннер.
Это одновременно опровергает §5.1 `gimli2-analytics-parity.md` и создаёт
compliance-экспозицию строго хуже прода на этом экране (у прода серверных ног на
этих событиях нет вообще).

**G3. Meta Purchase на апселе отправляется как `Purchase`, а не `Upsell`.**
Прод разделяет: `fbq('track','Purchase', …)` для основной покупки
(`packages/utils/analytics.ts:672-681`) и `fbq('trackCustom','Upsell', …)` для
апсела/даунсела (`:685-698`), плюс `oaiq` `'custom'` с
`custom_event_name:'upsell'` (`:653-669`). Движок в `moneyMirror` всегда шлёт
`Purchase` (`src/analytics/money.ts:329-340`), включая one-click апсел
(`routes/post-purchase.ts:462-468`). Meta получит N+1 Purchase на одну сессию;
ROAS-оптимизация и колонки конверсий поедут.

**G4. Живой backend-CAPI-feed не портирован.**
Прод кормит бек двумя вызовами, и именно бек шлёт Purchase в Meta CAPI
(дедуп против `eventID=order_id`): `PATCH /v1/users/properties` с `{fbc,fbp}`
(`packages/api/user.ts:61-85`, вызов `pages/Sales/Sales.tsx:1475`) и
`POST /v1/billing/funnel/users/payload` с `facebook_pixel_id` + `page_view.url`
(`packages/api/user.ts:43-51`, вызов `Sales.tsx:1276-1303`). В движке нет ни того,
ни другого — `src/platform.ts` содержит `/v1/profiles`, `/v1/billing/users/*`,
`/v1/users/funnel_register_flow`, `/v1/quiz-results`, Reteno, `/v1/courses/switcher`,
но не эти два. Плюс `sendMarketingEvents` (`src/platform.ts:402-416`) —
эквивалент `logFacebookEvent` — определён и **не вызывается ни разу**.

**G5. `em` (advanced matching) в Meta не отправляется никогда.**
`EmitContext.email` читается в `src/analytics/emit.ts:142` и передаётся в
`mirrorFor`, но **не присваивается ни в одном месте** — ни в `requestCtx`
(`src/http.ts:189-206`), ни в `withUserId` (`routes/quiz.ts:418-426`). Также
`PixelConfig.email` (`src/render/third-party.ts:52`) не передаётся ни на одной из
трёх поверхностей. Прод шлёт `em` и в init, и в событии, и делает re-init после
email-экрана для обоих источников pixel id (`CommonScripts.tsx:117-133` —
исправление, у которого в коде прода отдельный комментарий). Match quality Meta
для всей воронки движка будет ниже.

**G6. Meta Purchase payload беднее прода.**
`buildFacebookPurchaseData` (`packages/utils/buildFacebookPurchaseData.ts:60-69`)
кладёт `content_ids: [productId]`, `content_type` (= `paymentMode`), `order_id`.
Движок (`src/analytics/money.ts:333-338`) шлёт `value`, `currency`,
`predicted_ltv`, `funnel_name` — и `src/analytics/ltv.ts:161-165` этих полей тоже
не собирает. Без `content_ids`/`content_type` каталожный матчинг и DPA-ретаргетинг
на покупателей движка не соберутся.

**G7. Живая Google Ads конверсия на покупке не портирована.**
Прод делает два `dataLayer.push` (`packages/utils/analytics.ts:578-611` — `event:'purchase'`
с `ecommerce`, `items`, `ltv`, `currency`-флипом на USD и `user_email`; и
`:613-631` — legacy `ecommerce.purchase`). Именно тег на первом push'е — живая
конверсия Google Ads (комментарий в коде прода это фиксирует). Движок шлёт только
`purchase_ecommerce` (`money.ts:120-134`) — это ДРУГОЕ имя события, тег на него не
навешен. Покупки движка будут невидимы для Google Ads.

**G8. `gen_joined_ab_test` не эмитится вообще.**
См. §1.1 и §2.10. Ни автоматической экспозиции из GrowthBook, ни ручной на
`activeFlags`. Плюс кеш `evaluateFeatures` (`src/growthbook.ts:81-88`) намеренно
исключает `device_id`, так что процентный роллаут резолвится раз на когорту —
реальный сплит-тест с движка не только не измеряется, но и не рандомизируется.

**G9. Квизовый серверный TikTok шлёт весь конверт, включая ответы.**
`src/analytics/emit.ts:89`: `data: [{ event: mapped, event_id: id, properties: envelope }]`,
где `envelope = { ...buildEnvelope(...), ...props }` — то есть на
`funnels_email_completed` в TikTok уходят `user_email` (RAW, `routes/quiz.ts:975`),
`answer`, все UTM. Прод (`packages/utils/analytics.ts:214-241`) шлёт только
`user.email` = sha256 и опционально `value/currency/contents`. Money-путь движка
(`src/analytics/tiktok.ts:44-66`) устроен правильно — расхождение только в квизе.
Это и параритет-гэп, и утечка PII третьей стороне.

**G10. `_fbc` timestamp нестабилен внутри визита.**
`buildFbc(fbclid, existing)` (`src/analytics/attribution.ts:178-182`) берёт
`existing` первым, но `requestCtx` (`src/http.ts:200`) вызывает его без
`existing`: `buildFbc(readFbclid(url, cookie) ?? attr.utm.fbclid ?? null)`. Значит
`Date.now()` пересчитывается на каждом запросе, и `_fbc` в `fbq PageView` на экране 1
отличается от `_fbc` на экране 5. Прод кеширует `promova_fbc` со стабильным
timestamp на 90 дней (пункт 1 инвентаря). Ошибка тихая — деградирует только match rate.

**G11. Нет наблюдаемости серверной аналитики.**
Faro живой на воронке прода (`pages/Sales/Sales.tsx:464,1489,1504,1543`,
`components/screens/upsell/Upsell.tsx:417`, `utils/sendFaroError.ts`,
`utils/faroBuffer.ts`, `utils/faroReports.ts` с фиксированными сигнатурами
сообщений под агрегацию в Loki). У движка — только `console.error`. Вместе с
неподтверждённым попаданием stdout в Loki (`parity.md:170`) это значит: «Amplitude
ответил 200 / events_ingested:0» отличить от «не отправили» сейчас нельзя.
Гейт `LIVE_MODE`/`SEND_EVENTS` вообще нигде не логируется как причина пропуска.

**G12. Ноль тестов аналитики.**
`funnel-engine/tests/` — 9 файлов, ни один не проверяет ни имена событий, ни
конверт, ни зеркало, ни `insert_id`. Contract-test стратегия из инвентаря
(golden-file, Playwright interception, `@promova/funnel-events`) не реализована.
При этом G1/G3/G5 — ровно тот класс баг+ов, который golden-file поймал бы за один
прогон.

**G13. `step_number` — число против строки.**
`FunnelContext.tsx:921,964` шлёт `String(progress.current)`; `envelope.ts:107` —
`number`. В одном Amplitude-проекте свойство станет mixed-type.

**G14. Апсел/даунсел стадия не имеет своей таксономии.**
Прод: `upsell_offer_viewed/accepted/declined`
(`packages/features/FunnelBuilder/constants/analytics.ts:51-53`), `upsell_purchased`
(`Upsell.tsx:620`, `UpsellDownsell.tsx:316`), `revenue_upsell_*`
(`analyticsEvents.ts:34-39`), `funnels_overview_viewed_downsell`
(`analyticsEvents.ts:43`), `revenue_post_purchase_flow_*`
(`analyticsEvents.ts:121-124`). Движок на этих хопах шлёт те же generic
`revenue_pricing_page_viewed` / `revenue_started_checkout` / `revenue_purchased`
с добавленным `slug` (`routes/post-purchase.ts:304-310,393-399,462-468,557-563`).
Отличить апсел-воронку от основного пейвола в дашборде можно только по
`product_type`/`slug`, и любой существующий дашборд/CRM-сегмент на
`upsell_purchased` не увидит движок вовсе.

**G15. Amplitude user-properties сильно беднее.**
Движок ставит `screen_size` + `user_agent` (`render/third-party.ts:113-118`).
Прод дополнительно: `visitor_id`, `device_os`, `device_type`,
`device_size_width/height`, UTM-identify (`set` + `setOnce initial_*`),
referrer-identify (`useInitializeCommonPixels.ts:96-152`, `useDeviceData.ts:23-28`,
`useSaveUTMsToAmplitude.ts:23-90`). Любая сегментация профилей по устройству,
first-touch источнику или антифрод-скору не покроет трафик движка.

**G16. `oaiq`, Clarity, Impact Radius, generic `page_view`, GA4 `view_item` —
не портированы.** `CommonScripts.tsx:79,215-236` (oaiq, default ON), `:260`
(Clarity, всегда), `:261` (ImpactIdentify, всегда), `usePageView.ts:97-104`
(generic `page_view` на каждый экран + `ttq ViewContent` + `fbq ViewContent`),
`Sales.tsx:850-853` (GA4 `view_item`).

**G17. `initial_*` семантика подменена.** У прода это first-touch из sourcebuster,
раз за сессию (`buildUtmParams.ts:20-29`). У движка — UTM текущего визита,
префиксованные и вмороженные в `state.attr` (`http.ts:126`,
`attribution.ts:144-147`), а значит уезжающие на **каждом** событии
(`envelope.ts:118`). Плюс отсутствуют sourcebuster-fallback `current` и
`traffic_type`. Дашборд «initial_utm_source» на смешанном трафике будет считать
разные вещи.

---

## 4. Открытые вопросы

1. **Loki.** MCP `grafana` в этой сессии не поднялся, так что пункт
   `gimli2-analytics-parity.md:170` («логов движка нет ни в одном k3s-датасорсе»)
   ни подтвердить, ни опровергнуть не удалось. Пока не закрыт — G1/G2 нечем
   верифицировать на стейдже.
2. **Кому принадлежит `insert_id` на money-path.** Ставить его = менять
   `LoggedEvent.event_id` контракт (`src/analytics/log.ts:24-30` объясняет, почему
   там `null`). Или прекратить зеркалить Amplitude на money-path (тогда теряется
   device-контекст браузера), или ввести id и на money. Решение продуктовое.
3. **`revenue_pricing_block_viewed`.** Инвентарь говорит, что на code-воронках он
   мёртв; движок шлёт его всегда (`routes/sales.ts:321`). Это создаёт событие,
   которого у прода на этой поверхности нет — считать ли это регрессией или
   улучшением?
4. **`sales_payment_success` payload.** Прод шлёт `{funnel_name, country_funnel,
   source, total}` (`sendPurchaseEvents.ts:34-39`), где `total` — объект подписки.
   Движок шлёт money-конверт + `planProps` + `order_id`. Совпадает ли это с тем,
   на что смотрит дашборд?
5. **`?block_analytics` / `?preview`.** Как QA будет прогонять движок на проде без
   загрязнения метрик? `LIVE_MODE`/`SEND_EVENTS` — билд-тайм переменные, не
   per-request.
6. **`funnels_screen_unresolved`.** У прода это индикатор клиентского switcher'а
   (`FunnelScreenSwitcher.tsx:61`), у движка такого класса отказа не существует.
   Убрать из `EVENTS` или переиспользовать под серверный аналог (запрошен
   `?screen=N` вне диапазона)?
7. **`country_funnel` на money-path.** У прода он есть и на чекауте, и на покупке
   (`sendCheckoutEvents.ts:63`, `sendPurchaseEvents.ts:36`, PRMV-17789). В
   `buildMoneyEnvelope` его нет. Geo-роутинг у движка вообще существует?
8. **Per-funnel Meta pixel на money-страницах.** Квиз читает
   `quiz.tracking.facebookPixelId` (`routes/quiz.ts:370`), пейвол и апсел — только
   `c.env.FB_PIXEL_ID`. Если у воронки свой пиксель, покупка припишется
   домен-дефолтному.
9. **Карточный fallback в цепочке** (`parity.md:152-155`) — по-прежнему не
   проверено: POST на `/sierra/{funnelId}/paid` из цепочки резолвит план из куки
   пейвола, а не хопа.
