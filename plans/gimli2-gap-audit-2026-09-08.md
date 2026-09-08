# Gimli 2.0 → funnel-engine: что не перенесено и план закрытия

Дата: 2026-09-08. Семь параллельных аудитов сверяли **код** `funnel-engine`
(HEAD `486b290`) с живым прод-путём монорепы (`/kilo`, `/sierra`, `/golf`,
`/delta`, `/alpha` для code-воронок), а не с планами. Сырые отчёты с `file:line`
по каждому пункту лежат в `plans/gimli2-audit-2026-09-08/`:

| отчёт | область | строк |
|---|---|---|
| `audit-legal.md` | легал-страницы, Strapi-текст, FTC/ROSCA копия, consent | 77 |
| `audit-analytics.md` | Amplitude, пиксели, серверные интеграции, атрибуция, A/B | 480 |
| `audit-onboarding.md` | типы экранов, ветвление, resume, Funnel Core контракт, лоадер, локали | 534 |
| `audit-email.md` | email-шаг, Firebase, existing user, hand-off, Reteno | 343 |
| `audit-sales.md` | sales page, цены, FTC, down-sale, checkout, способы оплаты | 381 |
| `audit-post-purchase.md` | upsell `/golf`, downsell `/delta`, thank-you `/alpha` | 365 |
| `audit-authoring.md` | скиллы для вайбкодеров, валидатор, скаффолд, CI, превью, публикация | 291 |

Этот документ: (1) вердикт по каждой заказанной области, (2) полный список
гэпов с приоритетом, (3) план выполнения на каждый пункт, (4) вопросы,
которые закрываются только людьми.

## Статус (обновляется по ходу)

| приоритет | всего | закрыто | осталось |
|---|---|---|---|
| P0 — блокируют пилот | 20 | **10** | 10 |
| P1 — паритет метрик и контрактов | 33 | 0 | 33 |
| P2 — полнота DSL, воронки, авторинг | 24 | 0 | 24 |
| P3 — тесты и гигиена | 10 | 0 | 10 |

Закрыто: P0-20 (legal на своём хосте), P0-5…P0-8 (аналитика денежного пути),
P0-14…P0-18 (email-шаг и лоадер). Все три блока с приёмкой — в §3.1.

Осталось в P0 десять. Четыре из них — цепочка post-purchase (P0-1…P0-4),
заблокирована реальным набором продуктов апселлов и даунсела (Q5). Остальные
шесть: P0-9, P0-10, P0-13 (down-sale и ROSCA), P0-11 (FTC-флаги, Q1), P0-12
(сессия после покупки, Q2), P0-19 (пустой paywall при сбое биллинга, Q4).

---

## 1. Вердикт по областям

| область (из ТЗ) | статус | одной строкой |
|---|---|---|
| Legal-страницы (Terms, Privacy и т.д.) с текстом из Strapi | **СДЕЛАНО 2026-09-08** (было MISSING/P0) | Решение Алекса: линковать на другой хост нельзя — документ должен жить на домене сделки. Движок теперь сам отдаёт `/terms/*` из тех же Strapi-рекордов, что читает платформа. Реализация и приёмка — §3.1 P0-20. |
| Legal-копия в воронке (ROSCA/FTC, ссылки, consent) | **PARTIAL** | FTC hard/soft в чекауте — пословный порт. Но non-FTC ROSCA под планами заменён своей формулировкой без ссылки на Subscription Terms; на старт-скрине ссылки не гео-зависимы; на paywall нет CMS-блока «Your payment is secured»; кэш legal-запросов мёртв после ухода с Workers. |
| Аналитика | **PARTIAL** (четыре дефекта закрыты 2026-09-08) | Квиз в паритете и лучше прода. Закрыто: двойной счёт money-событий, consent на серверных ногах, Meta `Upsell` вместо второго `Purchase`, сырой email в TikTok (§3.1 P0-5…P0-8). Осталось: Google Ads конверсия и backend-CAPI-feed не портированы, `gen_joined_ab_test` не эмитится вовсе, апселл-таксономия и часть свойств событий (P1-6…P1-14). |
| Онбординг-логика | **PARTIAL** | 11 из 14 типов экранов, ветвление богаче прода. Но контракт `POST /v1/quiz-results` расходится в 4 местах (ключи вместо текстов, нет `selected_answer_id`, нет `user_language_level`, мусорные `ack`-ответы), лоадер не ждёт записи и может потерять `quiz_result_id`, прод-локали не перенесены, 5 из 6 воронок не портированы. |
| Email-шаг + existing user | **DONE** (четыре дефекта закрыты 2026-09-08) | Валидация, Firebase, Reteno, consent — паритет. Закрыто: rate limit, смена адреса посреди прогона, сырой email в localStorage, мусорные `ack`-ответы, потеря `qrid` на лоадере (§3.1 P0-14…P0-18). Осталось: после покупки визитёр приходит на `/complete-sign-up` **без сессии** и уходит на sign-in (P0-12, ждёт security), плюс P1-1…P1-5 по контрактам. |
| Sales page + down-sale | **PARTIAL** | Цены, FTC-раскрытия, decline-таксономия — порт точный. Но down-sale продаёт **те же продукты по тем же ценам**, sticky CTA отсутствует, при сбое биллинга paywall пуст (прод продаёт на CMS-ценах), FTC-флаги false для всех стран (найдена вероятная причина). |
| Checkout | **PARTIAL** | Card/PayPal/Apple/Google работают. Нет BLIK/UPI/Pix, `channel` не уходит в заказ, sandbox не флагом, PayPal без GB-гейта, CheckoutDownsell (one-click на декляйне) отсутствует. |
| Upsell / downsell-for-upsell / thank-you | **написано, но выключено** | `CHAINS = {}` — ни одной авторской цепочки, `/golf` `/delta` `/alpha` недостижимы. При включении всплывут 3 дефекта: форма-фолбэк на хопе уводит в `/sierra/paid` и сбрасывает цепочку, двойной тап = двойной чардж, `quiz_result_id` не передаётся в `/v3/billing/upsales`. Thank-you без autologin и handoff-query. |
| Скиллы для вайбкодеров | **PARTIAL** | `/new-funnel`, `/translate-page`, `/translate-status` есть и хороши. Нет `CLAUDE.md` и SKILL с автоподгрузкой, нет шаблона post-purchase, нет проверки product id по живому каталогу, нет превью на ветку, нет `/funnel-copy`, `/funnel-theme`, `/funnel-images`. **Ни одной воронки через vibe-coding не сделано.** |
| FTC | **DONE в коде, BLOCKED в проде** | Логика и копия портированы. Оба флага резолвятся false везде. Вероятная причина найдена: клиентский прод-эвал шлёт в GrowthBook полное **название** страны (`useAddGrowthBookAttributes.ts:28,76`), серверный и движок — ISO. Правила почти наверняка написаны под «United States». |

Что важно понимать про масштаб: аудиты нашли **~120 расхождений**, но
основная масса — свойства событий и мелкие поля DSL. Реально блокируют
пилот на живом трафике **20 пунктов** (§2, приоритет P0).

---

## 2. Полный список гэпов с приоритетом

Приоритеты: **P0** — блокирует пилот на платном трафике (деньги, комплаенс,
PII, потеря данных). **P1** — паритет метрик и контрактов, без чего пилот
несравним с продом. **P2** — полнота DSL, остальные воронки, авторинг.
**P3** — гигиена, тесты, доки.

Размер: S — до полудня, M — 1–2 дня, L — 3+ дня или требует людей.

### P0 — блокеры пилота

| # | гэп | область | размер |
|---|---|---|---|
| P0-1 | Post-purchase цепочка не включена: `CHAINS = {}`, нет `post-purchase.json` | PP | M |
| P0-2 | Форма-фолбэк на хопе постит в `/sierra/:id/paid` → чардж по плану пейволла, сброс цепочки | PP | M |
| P0-3 | Двойной тап на апселе = два чарджа (нет `hx-disabled-elt`, нет идемпотентности) | PP | S |
| P0-4 | `quiz_result_id` не передаётся в `/v3/billing/upsales`, поле required | PP | S |
| ~~P0-5~~ | ~~Money-события в Amplitude уходят дважды~~ — **СДЕЛАНО 2026-09-08** | A | M |
| ~~P0-6~~ | ~~Серверный Amplitude/TikTok на money-path игнорирует consent (EEA)~~ — **СДЕЛАНО 2026-09-08** | A | S |
| ~~P0-7~~ | ~~Meta получает `Purchase` на апселе вместо `trackCustom(Upsell)`~~ — **СДЕЛАНО 2026-09-08** | A | S |
| ~~P0-8~~ | ~~Квизовый серверный TikTok шлёт весь конверт с сырым email (PII)~~ — **СДЕЛАНО 2026-09-08** | A | S |
| P0-9 | Down-sale продаёт те же productId по тем же ценам под копией «a better price» | S | S + данные |
| P0-10 | Под FTC на down-sale нет ни одного раскрытия о продлении | S | S |
| P0-11 | FTC-флаги false для всех стран (гипотеза: правила GB под полное имя страны) | S | L (люди) |
| P0-12 | После покупки визитёр уходит на `/complete-sign-up` без сессии и `sid` → редирект на sign-in | E | L (security) |
| P0-13 | Non-FTC ROSCA под планами — своя формулировка без 24-часового окна и ссылки на Subscription Terms | L | S |
| ~~P0-14~~ | ~~Смена email посреди прогона переписывает адрес аккаунта и удваивает CompleteRegistration~~ — **СДЕЛАНО 2026-09-08** | E | S |
| ~~P0-15~~ | ~~Сырой email попадает в `localStorage` и в `selected_options`~~ — **СДЕЛАНО 2026-09-08** | E | S |
| ~~P0-16~~ | ~~Нет rate limit на `/kilo/:id/answer` → enumeration email~~ — **СДЕЛАНО 2026-09-08** | E | M |
| ~~P0-17~~ | ~~`ack`/`done` псевдо-ответы протекают в `/v1/quiz-results`~~ — **СДЕЛАНО 2026-09-08** | O | S |
| ~~P0-18~~ | ~~Лоадер не ждёт `/prepare`; `qrid` теряется; `forced` захардкожен~~ — **СДЕЛАНО 2026-09-08** | O | M |
| P0-19 | При сбое `/v1/billing/products` paywall пуст; прод продаёт на CMS-ценах | S | S + решение |
| ~~P0-20~~ | ~~Legal-страницы (`/terms/*`) не отдаются движком; все ссылки ведут на `promova.com`~~ — **СДЕЛАНО 2026-09-08** | L | M |

### P1 — паритет контрактов и метрик

| # | гэп | область | размер |
|---|---|---|---|
| P1-1 | `selected_options` = answerKeys вместо текстов; `selected_answer_id` отсутствует | O/E | S |
| P1-2 | Синтетический `user_language_level` не отправляется | O | S |
| P1-3 | Нет `cleanSelectedAnswers` (фильтр пустых, стрип HTML) | O | S |
| P1-4 | localStorage-хэндофф не несёт `quiz_id`/`flow_id`/`entry_point` | E | S |
| P1-5 | `withUserId` стирает `user_type: 'registered'` | E | S |
| P1-6 | Backend CAPI-feed: `PATCH /v1/users/properties {fbc,fbp}`, `POST /v1/billing/funnel/users/payload`, `sendMarketingEvents` не вызывается | A | M |
| P1-7 | Meta `em` advanced matching никогда не отправляется (`ctx.email` не заполняется) | A | S |
| P1-8 | Meta Purchase без `content_ids`/`content_type`/`order_id` | A | S |
| P1-9 | Google Ads конверсия: `dataLayer.push({event:'purchase', …})` + legacy push не портированы | A | S |
| P1-10 | `gen_joined_ab_test` не эмитится; GB-кэш без `device_id` → нет per-visitor рандомизации | A | M |
| P1-11 | Апселл-таксономия: `upsell_purchased`, `upsell_offer_*`, `product_type`/`screen_name`/`subscription_status` на pp неверны | A/PP | M |
| P1-12 | Пропущенные свойства: `country_funnel` на money, `revenue_started_checkout` (7 полей), `sales_payment_success.total`, `funnels_email_completed.screen_name`, visibility-пропсы старта | A | M |
| P1-13 | `step_number` число vs строка | A | S |
| P1-14 | `_fbc` timestamp пересчитывается на каждом запросе | A | S |
| P1-15 | Sticky CTA не заавторен и скрывается под FTC (прод показывает всегда) | S | S |
| P1-16 | `channel` не уходит в тело заказа и в upsales | S/PP | S |
| P1-17 | `sandbox` не управляется флагом `use_sand_box` | S | S |
| P1-18 | PayPal без гейта `show_paypal_button` и без проверки валют | S | S |
| P1-19 | BLIK / UPI / Pix Automatico не подключены; `tokenization_for_wallets_split` не читается | S/PP | M |
| P1-20 | Paywall: нет `secure-payment` с CMS `checkoutText`; поле `legal` статичное | L | S |
| P1-21 | Старт-скрин: legal-ссылки не гео-зависимы, Refund-лейбл зашит во FTC-вариант | L | S |
| P1-22 | Paywall-футер: лейблы не локализуются; нет «Legal Info» → `/contact-us` | L | S |
| P1-23 | Thank-you: нет handoff-query (utm_funnel, fbclid…), нет `funnels_completed_funnel_survey`, нет HRP-роутинга | PP | M |
| P1-24 | На offer/thank-you нет legal-футера и FTC-дисклеймера; FTC-вариант захардкожен `'hard'` | PP/L | S |
| P1-25 | Мульти-плановый хоп показывает сумму, списывает `plans[0]` | PP | S |
| P1-26 | `state.done` не читается; `ds` ставится на skip, не на view; нет `hx-push-url` | PP | S |
| P1-27 | Квиз-результат пишется один раз без retry | E | S |
| P1-28 | `CLAUDE.md` и SKILL с автоподгрузкой отсутствуют | AU | S |
| P1-29 | `pnpm validate` не входит в `pnpm build` | AU | S |
| P1-30 | Product id не проверяются по живому каталогу; путь через Walhalla MCP не задокументирован | AU | M |
| P1-31 | Таймер — только WARN в валидаторе | AU | S |
| P1-32 | Логи движка не подтверждены в Loki; нет Faro/error reporting | A/AU | M (DevOps) |
| P1-33 | Legal-кэш `cf.cacheTtl` мёртв на Node → каждый рендер ходит в `/api/legal/*` | L | S |

### P2 — полнота DSL, другие воронки, авторинг

| # | гэп | область | размер |
|---|---|---|---|
| P2-1 | Прод-локали квиза `es, pt, de, fr, it` не перенесены (есть только `uk`) | O | M |
| P2-2 | Типы экранов: swym `results` (4 варианта), swym `profile`, english-hub `landing` | O | L |
| P2-3 | Дыры внутри типов: `reaction`, `steps[]` лоадера, `reassurance`, `bars.pct`, `count(answers)`, `{n}`, lowercase гейта | O | M |
| P2-4 | Прогресс-бар: знаменатель = длина flow, а не число вопросов | O | S |
| P2-5 | `general-english-b` / `-g` не перенесены (тривиально); swym-2/3, english-hub — после P2-2 | O | S / L |
| P2-6 | Шаблон `post-purchase.json` в скаффолде + `/add-upsell-chain` | AU | S |
| P2-7 | Скиллы: `/funnel-copy`, `/funnel-theme`, `/funnel-images`, `/add-screen`, `/publish`, `/rollback`, `/post-launch-check` | AU | L |
| P2-8 | Превью на ветку (нет хоста под черновик до мерджа) | AU | L (DevOps) |
| P2-9 | Скриншот-гейт в CI (экраны × локали × гео) | AU | M |
| P2-10 | Реестр патчится строкой; локали/цепочки регистрируются руками → `registry.generated.ts` | AU | S |
| P2-11 | Публикация конфига без пересборки образа | AU | L (дизайн) |
| P2-12 | Sales-схема без оси вариантов (`country:`/`flag:`) | S | M |
| P2-13 | Sales-вёрстка: фото в `compare`, `courses` заавторен как `stats`, goal-keyed benefits, showcase-картинки, page-level `chartFootnote`, `page_url` без query | S | M |
| P2-14 | Timer: хром countdown не рендерится; swap продуктов не гейтится по FTC | S | S |
| P2-15 | CheckoutDownsell (one-click на декляйне), coupon, $1 activation-fee note, `fakeDiscount`/`discountLabel`, `bestOfferCardNumber`/`bestOfferSubscription` | S | L |
| P2-16 | Chain не локализован (`getPostPurchase` без locale) | PP | S |
| P2-17 | Amplitude user props: `device_*`, `visitor_id`, UTM-identify, referrer | A | S |
| P2-18 | `oaiq`, Clarity, Impact Radius, generic `page_view`, GA4 `view_item`, `fbq/ttq ViewContent` на экран | A | M |
| P2-19 | `initial_*` семантика (first-touch), `traffic_type`, sourcebuster fallback, `?ampSessionId` | A | M |
| P2-20 | QA-гейты `?block_analytics` / `?preview` | A | S |
| P2-21 | Reteno на money-path, `/v1/users/utm`, CPA-лукапы 2 из 5 | A | M |
| P2-22 | `?lang=` оверрайд; soft-404 на неизвестном `?screen`; семантика resume (новая вкладка, 4 ч) | O | S + решения |
| P2-23 | Brazil/EBANX дисклоуз | L | S |
| P2-24 | Email-ошибки не локализуются; name-input 40 vs 64, без серверной обрезки | E | S |

### P3 — гигиена

| # | гэп | область | размер |
|---|---|---|---|
| P3-1 | Ноль тестов аналитики (golden-file потока) | A | M |
| P3-2 | Ноль юнит-тестов money-логики; e2e `/select` шлёт не то поле | S | M |
| P3-3 | Валидатор и скаффолд не покрыты тестами | AU | S |
| P3-4 | Legal почти без тестов | L | S |
| P3-5 | Атрибуция статистики ловится только цифрами | AU | S |
| P3-6 | `billingPeriodInDays` мёржится вопреки проду и собственному комментарию | S | S |
| P3-7 | Три копии списка EU-стран | L | S |
| P3-8 | Дрейф доков: README vs код (5 мест про Workers, 8 vs 11 групп валидатора, устаревшие роуты), устаревшие спеки в `plans/` (ссылки на `src/index.ts:7xx`) | AU | S |
| P3-9 | Мелочи PP: `skipTopLabel` не рендерится, `button_type` skip, `channel: 'web'`, `entity` не хранится | PP | S |
| P3-10 | Риски: кука 3800 байт, GB-кэш на когорту, подделываемая `withAuth` | O | — |

---

## 3. План выполнения по каждому пункту

Формат: **что** → **где** → **шаги** → **приёмка**. Зависимости и владелец
указаны, где не Alex.

### 3.1 P0

**P0-1. Включить post-purchase цепочку.**
Где: `src/registry.ts:143`, `funnels/general-english/post-purchase.json` (создать), `scripts/scaffold-funnel.ts`.
1. Снять живой набор продуктов: `GET gringotts…/api/pricing-rule/general-english-upsell/commerce`, `…-upsell-vocab`, `…-downsell` (по `.../code-funnels/money/general-english/index.ts:55-80`). Записать productId и paymentMode.
2. Написать `post-purchase.json` по `schema/post-purchase.schema.ts`: 2 хопа + `downsell` + `thankYou`. Копия — из `code-funnels/money/general-english/copy.ts` и `layouts/UpsellLayout.tsx`.
3. Зарегистрировать в `CHAINS`, добавить импорт; синхронизировать валидатор и рантайм (валидатор читает с диска, рантайм — из бандла; сделать один источник — см. P2-10).
4. Обновить `README.md:1061` и `:1129`.
Приёмка: `pnpm validate` зелёный; e2e: оплата → 302 на `/golf/general-english/<slug>`; skip×2 → `/delta`; skip → `/alpha`. `tests/e2e.test.ts:327-338` расширить.

**P0-2. Форма-фолбэк на хопе.**
Где: `src/render/checkout.ts:288,458,472,479,500`, `src/routes/post-purchase.ts:507-546`.
1. Параметризовать `renderCheckout` контекстом маршрута: `{paidUrl, declinedUrl, closeUrl, eventUrl, bodyId, slotId}`. Sales передаёт `/sierra/…`, pp — `/golf|/delta/:id/:slug/paid` и т.д.
2. Добавить в `src/routes/post-purchase.ts` роуты `/paid`, `/declined`, `/close` для хопа: план берётся из хопа, эмиссия `revenue_purchased` с `product_type: 'upsell'|'upsell_downsell'`, переход `nextHop`, без `startChain`.
3. То же для `renderCheckoutUnavailable`.
Приёмка: тест в `tests/chain.test.ts`: оплата формой на хопе 1 → `state.done` содержит slug хопа, `skips` не сброшен, редирект на хоп 2; сумма в `revenue_purchased` = цена хопа.

**P0-3. Защита от двойного чарджа.**
Где: `src/render/post-purchase.ts:121-124`, `src/routes/post-purchase.ts:/buy`, `src/checkout.ts:325-354`.
1. На форму buy: `hx-disabled-elt="this"` + `hx-sync="closest form:drop"`.
2. Серверно: в `fe_pp` хранить `charged: Record<slug, orderId>`; повторный `/buy` для уже `done` slug → 303 на `nextHop` без вызова `/v3/billing/upsales`.
3. Вопрос бэкенду про idempotency-key в контракте (§4) — параллельно, не блокирует.
Приёмка: два подряд POST `/buy` → один вызов `chargeUpsale` (мок), второй 303.

**P0-4. `quiz_result_id` в upsales.**
Где: `src/routes/post-purchase.ts:413-419`, `src/checkout.ts:337-344`.
1. Прокинуть `state.qrid` из `fe_state`; при отсутствии — `'empty'` (так делает прод).
2. Сделать поле обязательным в типе `UpsaleBody`.
Приёмка: юнит на тело запроса; e2e хоп one-click проходит на dev против живого бэкенда (после P0-1).

**P0-5 … P0-8. Блок аналитики денежного пути. — СДЕЛАНО 2026-09-08.**

Четыре дефекта закрыты одним изменением, потому что все четыре живут в
`src/analytics/`.

| дефект | что сделано |
|---|---|
| **P0-5** двойной счёт | `emitMoney` считает `insert_id` и ставит его на ОБЕ половины: серверный `AmplitudeEvent` и зеркальный вызов `{sink:'amplitude'}`. Ключ выводится из `ad.eventId` (order_id) там, где он есть, иначе случайный на emit: повтор `/paid` не забронирует выручку дважды, а второй просмотр пейволла остаётся настоящим вторым событием. Имя события всегда в хеше — Amplitude дедупит по одному `insert_id`, и `revenue_purchased` с `sales_payment_success` (общий order_id) иначе схлопнулись бы в одно. Плюс вторая половина проблемы: браузерному SDK на `/sierra` и `/golf` теперь передаётся тот же `sessionId`, что рапортует сервер — раньше SDK выдумывал свою сессию из 30-минутного таймера, и пара событий оказывалась в разных сессиях. |
| **P0-6** consent | `MoneyContext.hold` (обязательное поле, чтобы новый call-site не забыл), заполняется из `consentFor(c).hold` в обоих билдерах. `emitMoney` при `hold` пишет только в first-party лог и не трогает ни Amplitude, ни TikTok. |
| **P0-7** Meta на апселе | `MoneyContext.hop` (`'upsell'` / `'upsell_downsell'`), проставляется в `chainMoneyCtx` — он достижим только с `/golf`, `/delta`, `/alpha`. На хопе Meta получает `trackCustom('Upsell')`, на пейволле `track('Purchase')`. TikTok сознательно не разделён: прод его тоже не разделяет. Конверт (`product_type`, `screen_name`) НЕ тронут — это P1-11. |
| **P0-8** PII в TikTok | `sendTikTok` больше не шлёт конверт. Идёт через тот же `tiktokEvent`, что деньги: только `user.email` как SHA-256 и `event_id`. Собственный комментарий `tiktok.ts` это правило уже описывал — квиз его не соблюдал. |

Приёмка: новый сьют `tests/analytics.test.ts`, 26 кейсов, по одному на каждое
нарушенное свойство. Проверено живьём на пейволле: два money-события в зеркале
несут разные `insert_id`, `sessionId` SDK совпадает с серверным. Гейты:
typecheck, 9/9 сьютов (154 кейса), `pnpm build`, e2e (тот же единственный
локальный провал email-шага из-за наличия Firebase-ключа в локальном `.env`).

Побочно найдено: `pnpm test` не типизирует тестовые файлы — ошибка типов в
новом сьюте всплыла только на `pnpm build`. Это соседний пункт P1-29.

Исходный план (для истории). **Дедуп money-событий в Amplitude.**
Где: `src/analytics/money.ts:280-282,506,509-518`, `src/routes/sales.ts:271-279`, `src/routes/post-purchase.ts:198-206`.
1. Ввести `insert_id` для money-событий по той же формуле, что квиз (`envelope.ts:127-145`): `sha256(sid|surface|event|occurrence)`.
2. Класть его и в серверный `AmplitudeEvent`, и в зеркало (`eventId`), чтобы Amplitude склеил.
3. Передавать `sessionId` в браузерный SDK на sales/pp, как на квизе (`quiz.ts:377`).
4. `logEvent` — писать `event_id` вместо `null`; обновить комментарий `log.ts:24-30`.
Приёмка: golden-тест (см. P3-1): на один `revenue_purchased` два вызова с одинаковым `insert_id`; в Amplitude dev-проекте после прогона 1 событие.

**P0-6. Consent на серверном money-path.**
Где: `src/analytics/money.ts:189-199,501-528`, `src/routes/sales.ts:257`, `src/routes/post-purchase.ts:185`.
1. Добавить `hold: boolean` в `MoneyContext`; заполнять из `consentFor(c).hold`.
2. В `emitMoney`: при `hold` — писать в first-party лог, внешние sink'и пропускать (как `emit.ts:166`).
Приёмка: тест: `cf-ipcountry: DE` без consent-куки → `amplitude`/`tiktok` не вызваны, лог есть.

**P0-7. Meta `Upsell` вместо `Purchase`.**
Где: `src/analytics/money.ts:190-199,320-341`.
1. В `MoneyContext` добавить `surface: 'sales'|'downsale'|'upsell'|'upsell_downsell'`.
2. Для `upsell*` — `{sink:'fbq', method:'trackCustom', event:'Upsell'}`; для sales — `Purchase`. Заодно `oaiq` (P2-18) пойдёт по тому же признаку.
Приёмка: тест зеркала на pp-покупке содержит `trackCustom('Upsell')` и не содержит `Purchase`.

**P0-8. TikTok квиза — только hashed email.**
Где: `src/analytics/emit.ts:73-96` (строка 89).
1. Собирать payload как на money-path (`tiktok.ts:44-66`): `user.email = sha256`, `properties` — только `value/currency/contents` при наличии.
Приёмка: тест: payload `funnels_email_completed` в TikTok не содержит `user_email`, `answer`, `utm_*`.

**P0-9. Реальные продукты down-sale.**
Где: `funnels/general-english/sales.json:354-460`, `schema/sales.schema.ts:404-415`.
1. Дёрнуть `general-english-downsell/commerce`, заавторить фактические productId (по комментарию прода — Pronunciation intensive, one-time).
2. Добавить в `downsaleSchema` опциональный `bestOfferProductId`.
3. В валидатор: FAIL, если `downsale.plans[].productId` ⊂ `plans[].productId` при равных `amount` (сейчас это WARN `:816-833`).
Приёмка: `pnpm validate` падает на текущем sales.json; проходит на новом.

**P0-10. Раскрытие на down-sale под FTC.**
Где: `src/render/sales.ts:266-282`.
1. Для `downsale` рендерить `billingTerms` (или FTC-вариант `nowThenLine`) независимо от `ftcOn`, как делает `SalesDownsaleLayout.tsx:129-148`.
Приёмка: тест: `?_ftc=hard` + `?downsale=true` → в HTML есть строка о продлении.

**P0-11. FTC-флаги.** Владелец: тот, у кого доступ к GrowthBook UI.
1. Открыть правила `us_pricing_now_then`, `ftc_soft_changes`: атрибут `country` — «United States» или `US`?
2. Если полное имя: либо править правила на ISO (затронет серверный эвал прода, который уже ISO — проверить, не сломан ли он сейчас), либо движок отправляет оба атрибута (`country` = имя, `country_code` = ISO) как временный мост.
3. После — снять `?_ftc=` с dev и проверить живой резолв из US-прокси.
Приёмка: `/_diag`-эндпоинт или лог показывает `ftc: hard` для `cf-ipcountry: US` без override.

**P0-12. Сессия после покупки.** Владелец решения: security.
Вариант A (без ключа сервис-аккаунта, делать сейчас): на `/sierra/:id/paid` и `/alpha` вызывать `POST /v1/users/link_for_auth` для `platformUserId` и подставлять полученный URL в CTA; TTL 60 с — минтить на клик через `POST /alpha/:id/go` → 302.
Вариант B (после sign-off): подпись custom token в контейнере ключом из Vault, `/sign-in?custom_token=`.
Шаги для A: `src/platform.ts` (обёртка уже в `diag.ts:57-66`), `src/routes/sales.ts:635,643`, `src/render/post-purchase.ts:144,149`, роут `/go`.
Приёмка: после оплаты на dev клик по CTA приводит на платформу залогиненным (`/complete-sign-up` не редиректит на sign-in).

**P0-13. ROSCA под планами.**
Где: `funnels/general-english/sales.json:125,437`, `src/render/sales.ts:266-278`, `schema/sales.schema.ts`.
1. Взять формулировку `IntroSubscriptionDisclaimer.tsx:43-60` с плейсхолдерами `{introDuration} {introPeriod} {price} {period}` и ссылкой на Subscription Terms.
2. `billingTerms` сделать объектом `{text, linkLabel, linkHref}` или разрешить `[Subscription Terms](…)`-разметку в pinned-English строках.
3. Добавить в валидатор: `billingTerms` для подписки обязан содержать «24 hours» и ссылку.
Приёмка: legal-ревью строки; тест на наличие `<a href=…subscription-terms>` внутри `.s-terms`.

**P0-14 … P0-18. Блок email-шага и лоадера. — СДЕЛАНО 2026-09-08.**

| дефект | что сделано |
|---|---|
| **P0-15 + P0-17** мусор и PII в наборе ответов | Одно решение в `applyAnswer`: новая функция `recordsAnswer` решает, попадает ли сабмит в `state.answers`. Не попадают: сентинелы `ack`/`done` со скринов без `questionKey` (value, social-proof, results, statement, лоадер) и набранный адрес с `email`-скрина. Позиция, `visited` и счётчик `seen` не тронуты — они верны независимо от того, сказал ли сабмит что-нибудь. Следствие сразу во всех потребителях: `buildQuizResult`, `buildAnswerPayload`, `buildPlatformAnswers` и подписанная кука. Восемь мусорных строк на GE и сырой адрес в localStorage платформы ушли одним изменением. |
| **P0-14** смена адреса | Решение вынесено в чистую `emailStepDecision(storedEmail, submitted)` → `advance` / `refuse-changed` / `link`, чтобы таблица истинности была тестируема. `refuse-changed` отказывает копией «this email already exists» — это то, что показывает прод в состоянии, до которого он доходит (`auth/provider-already-linked`), — и репортит ТОЛЬКО error-событие: completed на этом прогоне уже был. |
| **P0-16** rate limit | Новый `src/ratelimit.ts`: token bucket, непрерывный refill (фиксированное окно пропускает двойной лимит на границе). Два бакета: по `sid` 5/мин и по `cf-connecting-ip` 30/мин, IP-бакет пропускается, если edge адреса не дал. Проверка ПОСЛЕ валидации адреса — исправление опечатки не должно тратить токен. Отказ логируется как `email_step_rate_limited` и репортится как `error_description: 'rate_limited'` (свой код, не один из четырёх прод-исходов). |
| **P0-18** лоадер | Рампа держится на 90 % до ответа `/prepare` (тот дистпатчит `fe:prepared`, Alpine слушает на документе), форсит через 6 с, держит готовую полосу 600 мс — константы прода. `forced` теперь приходит из формы, а не захардкожен `false`. `/answer` восстанавливает из куки не только `idb`, но и `qrid`. Заодно `minDurationMs` стал означать время до потолка: делился на 50 при 100 шагах, то есть настроенный 3-секундный лоадер шёл 6. |

Приёмка: новый сьют `tests/email-step.test.ts`, 37 кейсов. Живьём: семь
сабмитов на email-шаг с одним токеном — лимитер отказал, в логе
`email_step_rate_limited`, в событиях `error_description: "rate_limited"`.
Гейты: typecheck, 10/10 сьютов (191 кейс), `pnpm validate` (0 failures),
`pnpm build`, e2e (тот же единственный локальный провал email-шага).

Замечание по проверке: живой прогон лимитера создал ~6 анонимных
пользователей в dev-проекте Firebase с адресами `probe*@example.com` — тем же,
куда пишет e2e (`e2e-probe@example.com`). Если dev-проект чистят, это они.

Исходный план (для истории). **Смена email посреди прогона.**
Где: `src/routes/quiz.ts:823,884`.
1. Ветка `stored.email && stored.email !== email` → ошибка `errors.alreadyLinked` («This run is already linked to <masked>») без вызова `accounts:update`, без повторной цепочки Reteno/HRP и без второго `funnels_email_completed`.
Приёмка: тест в `tests/handoff.test.ts`: второй сабмит с другим адресом → 0 вызовов identity, 0 событий с `adConversion: true`.

**P0-15. Сырой email в hand-off и quiz-results.**
Где: `src/engine.ts:263-270,373-386`, `src/routes/quiz.ts:761`.
1. Не вызывать `applyAnswer` для `email`-скрина (прод `EmailScreen` не зовёт `onAnswer`); адрес живёт только в `idb`.
2. `buildPlatformAnswers` и `buildQuizResult` — исключить экраны типа `email`.
Приёмка: тест: словарь hand-off и payload `/v1/quiz-results` не содержат `s26`.

**P0-16. Rate limit на email-шаге.**
Где: `src/routes/quiz.ts:1030` (`/answer`), новый `src/ratelimit.ts`.
1. In-process токен-бакет по `sid` (5/мин) и по IP визитёра (`cf-connecting-ip`, 30/мин) только для `email`-скрина.
2. Превышение → `errors.generic` + событие `funnels_email_entered_error{reason:'rate_limited'}`.
3. Вопрос бэкенду про лимит `check_email_provider` по IP пода (§4).
Приёмка: тест: 6-й сабмит за минуту → 429-путь, `checkEmailProvider` не вызван.

**P0-17. `ack`/`done` не попадают в payload.**
Где: `src/routes/quiz.ts` (`applyAnswer` после `isAcknowledgement`), `src/engine.ts`.
1. Для экранов без `questionKey` и типов `value|social-proof|results|statement|loader` — не записывать в `state.answers`; продвигать только `cur`/`far`.
2. Защитно: `buildQuizResult`/`buildAnswerPayload`/`buildPlatformAnswers` пропускают `['ack']`/`['done']`.
Приёмка: тест: payload GE содержит ровно экраны с `questionKey`; размер куки уменьшился.

**P0-18. Лоадер ждёт записи; `qrid` не теряется.**
Где: `src/render/screens.ts:525-608`, `src/routes/quiz.ts` (`/prepare`, `/answer` ~:1000-1010, ~:1108-1113).
1. Рампа: cap 90 % до ответа `/prepare` (OOB-свап ставит флаг), форс через 6 с, 600 мс до сабмита — константы прода `FunnelContext.tsx:81-88`.
2. `/answer` восстанавливает из куки не только `idb`, но и `qrid`.
3. `forced = !prepared.qrid` вместо `false`.
Приёмка: тест с задержанным `/prepare` → сабмит содержит `qrid`; при таймауте `forced: true` в паре `test_completed`.

**P0-19. Поведение при сбое биллинга.** Решение продукта (§4).
Если «продавать на авторских ценах»: `src/pricing.ts:45-51` → возвращать авторские `plans` с флагом `livePrices: false`, рендерить баннер «Prices shown in USD»; e2e `tests/e2e.test.ts:310-312` обновить. Если «не продавать»: оставить, но добавить алерт на пустой paywall (P1-32).

**P0-20. Legal-страницы на хосте движка, текст из Strapi. — СДЕЛАНО 2026-09-08.**

Что сделано (все девять шагов ниже, кроме двух пунктов, ушедших к людям):

| | |
|---|---|
| новые файлы | `src/strapi.ts` (read-only CMS-клиент + кэш), `src/legal.ts` (каталог страниц, гео-слаги, общий набор ссылок), `src/render/legal.ts` (санитайзер + оболочка документа), `src/render/cookie-policy.ts` (единственный текст не из CMS), `src/routes/legal.ts` (роуты), `tests/legal.test.ts` |
| ссылки переключены | `src/render/sales.ts` (футер paywall), `src/render/screens.ts` (`platformHref`: `/terms/*` остаётся на своём хосте, `/echo` и прочее — платформе), `src/render/checkout.ts` (ссылка Subscription Terms в FTC-дисклеймере) |
| убрано как мёртвое | `webOrigin` из `SalesCtx` и `CheckoutCtx` — легалка была его единственным потребителем |
| env | `MARKETING_STRAPI_URL` (`src/http.ts`); прод-значение `https://gringotts.promova.work`; лист Vault обновлён |
| валидатор | новая группа `legal/*`: FAIL на абсолютный legal-href, на locale-префикс в авторском пути, на неизвестную `/terms/...` страницу |
| прочее | `<meta name="robots">` стал `noindex, nofollow` (прод отдаёт `index:false, follow:false`); `page()` получил `extraCss`; список EU-стран в `render/sales.ts` заменён на общий `COUNTRY_SETS.eu` |

Приёмка (прогнано):

- `pnpm typecheck`, `pnpm validate` (0 failures), `pnpm test` — 8/8 сьютов, `tests/legal.test.ts` 74 кейса зелёные.
- `pnpm test:e2e` против живого сервера: все legal-кейсы зелёные. Один провал не связан с задачей — «email step fails closed without an auth key» падает локально потому, что в локальном `.env` ключ Firebase есть, то есть предпосылка теста не выполняется (в CI ключа нет).
- Живые запросы: `/terms/cookie-policy` 200, `/terms/pricing` 404, `/terms/subscription-terms` 503 без env, `/terms` → 302, `/uk/terms/cookie-policy` 200.
- Все одиннадцать слагов, которые может выдать роутер, резолвятся против живого Strapi (`gringotts.promova.work`): `terms-of-use`, `-us`, `-ua`, `-ind`, `-1`, `privacy-policy`, `-us`, `subscription-terms`, `refund-policy`, `faq-resident-eu` + украинская локализация.
- **Текстовая сверка с платформой**: `/terms/refund` и `/terms/faq-resident` совпадают на 100 % чанков; `/terms/subscription-terms` — 44 из 49, и все пять расхождений содержат `support@promova.com`. Причина найдена: на `promova.com` включена Cloudflare Email Address Obfuscation (`[email protected]`). Содержимое документов идентично, потому что это один и тот же Strapi-рекорд. Отсюда пункт 6 для DevOps в `funnel-engine-vault-env.md`.
- `grep` по `src/` и `funnels/`: ни одного `promova.com/terms`. В HTML paywall'а, старт-скрина и чекаута legal-href'ы относительные, под `uk` — с префиксом.

**Переводы legal — проверено на живом Strapi 2026-09-08.** Локализации берутся
из тех же записей, что читает платформа, поэтому язык документа совпадает с
продом по построению. Что реально лежит в CMS:

| документ | языков | какие |
|---|---|---|
| `refund-policy` | 14 | de el en es es-419 fil fr hi it ja pl pt tr uk |
| `subscription-terms` | 13 | de el en es es-419 fr hi it ja pl pt tr uk |
| `terms-of-use`, `privacy-policy`, `faq-resident-eu` | 9 | de el en es fr it pl pt uk |
| `terms-of-use-us` | 3 | en es uk |
| `terms-of-use-ua` | 2 | en uk |

Живые ответы движка: `/uk/terms/privacy-policy` → «Політика
конфіденційності», `/de/…` → «DATENSCHUTZERKLÄRUNG», `/pl/terms/refund` →
«Polityka zwrotów», `/ja/terms/refund` → «返金ポリシー»,
`/it/terms/subscription-terms` → «Condizioni di abbonamento». Где перевода нет
(`/ja/terms/privacy-policy`) — отдаётся исходный английский И `<html lang="en">`,
то есть страница не врёт синтезатору речи о своём языке.

Ключевое: префикс на legal-ссылке — это ЗАПРОШЕННАЯ локаль, не отданная.
Проверено: `/de/kilo/general-english` отдаёт английский квиз (у воронки нет
немецкого каталога), но legal-ссылки на нём `/de/terms/*` и ведут на немецкие
документы — ровно как на проде. Перевод юридических текстов не ждёт перевода
воронки.

Таймаут CMS-фетча поднят 5 → 8 с: замер показал 3.0-3.4 с на двух больших
документах (Terms 45 КБ, Privacy 54 КБ, по девять локализаций), и пятисекундный
бюджет ставил холодный первый запрос в одну плохую секунду от 503.

Ушло к людям, не блокирует: Q16 (перенести Cookie Policy в Strapi — до тех пор в движке лежит копия с датой порта и пометкой о дрейфе), Q17 (canonical сейчас относительный, на другой хост не указывает; страница «Legal Info» не добавлена — прод-code-воронка её на paywall тоже не показывает).

Что осталось незакрытым по соседству, осознанно: набор legal-ссылок на старт-скрине по-прежнему авторский и не гео-зависимый (лейбл Refund зашит во FTC-вариант) — это P1-21, требует FTC-состояния на контексте квиза. Плюс `/terms/*` без locale-префикса всегда отдаётся по-английски, потому что `browserLocale` считает поддерживаемые локали по funnel id, которого у этого пути нет; платформа ведёт себя так же, но Strapi несёт 9-14 локализаций, так что негоциация по `doc.availableLocales` — дешёвое улучшение на потом.

Исходный план (для истории). Что было: каждый legal-href собирался как `${webOrigin}${localePath(href)}`
— `src/render/sales.ts:601-611`, `src/render/screens.ts:695-698`
(`platformHref`), `src/render/checkout.ts:116-117` (ссылка «Subscription
Terms» внутри FTC-дисклеймера). Ни одного роута `/terms/*` в `src/index.ts`
нет. У движка нет ни Strapi-клиента, ни env для marketing-Strapi (`src/http.ts:23-24`
знает только `API_MARKETING_HOST`/`MARKETING_SDK_TOKEN`).

Какие страницы нужны (то, на что ссылается воронка; `TermsRoutes` в
`packages/config/constants/routes.ts:2-12`):

| путь | источник на проде | как получать движку |
|---|---|---|
| `/terms/terms-and-conditions` | Strapi `api::page.page`, слаг по гео (`apps/student/utils/getTermsAndConditionsSlugByGeo.ts:24-50`: `terms-of-use`, `-us`, `-california`, `-1` UAE, `-ind`, `-ua`, …) | `GET {MARKETING_STRAPI_URL}/api/pages?filters[slug]=<slug>&populate[]=localizations&populate[]=seo`, публичный, без токена (`packages/utils/dataFetching/termsPage/fetchTermsData.ts`) |
| `/terms/privacy-policy` | то же, `getPrivacyPolicySlugByGeo.ts:27` (`privacy-policy`, `-us`, `-us-ea`, `-california`, `-1`, `-ua`, …) | то же |
| `/terms/subscription-terms` | слаг `subscription-terms`, один на все гео | то же |
| `/terms/refund` | слаг `refund-policy` | то же |
| `/terms/faq-resident` | слаг `faq-resident-eu` (`strapi_urls.ts:39`) | то же |
| `/terms/cookie-policy` | **не в Strapi**: `packages/ui/common/CookiePolicy/CookiePolicy.tsx` (417 строк JSX в `<Trans>`) | см. шаг 5 |
| «Legal Info» → `/contact-us` (только в футере прода, `LegalInfo.tsx:96-112`) | платформенная страница поддержки | не линковать на платформу; см. шаг 6 |

Шаги:
1. **Env + клиент.** Добавить `MARKETING_STRAPI_URL` (Vault `student` →
   `NEXT_PUBLIC_MARKETING_STRAPI_URL`, дополнить `funnel-engine-vault-env.md`).
   `src/strapi.ts`: `fetchPage(slug, locale)` с той же query, что
   `fetchTermsData`; извлечение локали как `packages/utils/strapi/getLocalizedContent.ts`
   (ищет в `localizations.data`, фолбэк на дефолтную запись); `availableLocales`.
   Это осознанное исключение из правила «не ходить в Strapi напрямую» старого
   плана §6: у платформы нет прокси для `/api/pages`, а заводить его в монорепе
   ради движка — лишняя зависимость. Snippet-эндпоинты остаются через прокси.
2. **Гео-слаг.** `src/legal.ts`: порт `getTermsAndConditionsSlugByGeo` и
   `getPrivacyPolicySlugByGeo` (страна из `cf-ipcountry`, регион — если
   Cloudflare отдаёт `cf-region-code`, иначе California не отличить от US:
   зафиксировать как известное ограничение, платформа тоже берёт регион из
   гео-провайдера). Списки стран — из `packages/config/types/countries`.
3. **Роуты.** `src/routes/legal.ts`: `GET /:locale?/terms/:page` для шести
   путей. Рендер в общем `layout.ts` с темой, `<h1>` из `title`, `content`
   как HTML. Прод вставляет `content` через `dangerouslySetInnerHTML` без
   санитизации; движок — прогонять через allowlist-санитайзер (теги
   заголовков, списки, ссылки, таблицы, `<strong>/<em>`), потому что теперь
   это наш origin. Приёмка санитайзера — визуальный диф с прод-страницей.
4. **Кэш.** In-process TTL 3600 с по ключу `(slug, locale)` +
   stale-while-revalidate; при недоступности Strapi отдавать последнюю
   удачную копию, при холодном старте без копии — 503 с `Retry-After`, не
   пустую страницу. Вебхук инвалидации (`TERMS_PAGES_TAG`) — позже, TTL
   достаточно для пилота.
5. **Cookie Policy.** Текст не в Strapi. Правильное решение — завести в
   Strapi `page` со слагом `cookie-policy` (и переводы из Lingui `.po`),
   тогда платформа и движок читают одно. Владелец — контент/legal (Q16).
   До этого — временный статический партиал `src/legal/cookie-policy.en.html`,
   портированный из `CookiePolicy.tsx` verbatim, с пометкой источника и
   датой; переводы — из `.po` в каталог движка.
6. **«Legal Info».** Вместо ссылки на `/contact-us` — своя страница
   `/terms/legal-info` на движке: merchant-текст из `/api/legal/footer-text`
   (уже есть в `src/platform.ts:287`) + support-email из env. Либо не
   показывать ссылку вовсе (прод-code-воронка её на paywall не показывает,
   `Sales.tsx:1962-1965`). Решение — legal.
7. **Переключить hrefs.** `platformHref` → same-host `localePath(href)`;
   убрать `webOrigin` из `sales.ts:601-611`, `screens.ts:695-698`,
   `checkout.ts:116-117`. Валидатор: FAIL на любой абсолютный `href` с
   `promova.com` в legal-полях конфига (`quiz.schema.ts:419-424`,
   `sales.schema.ts` legal-поля), чтобы вайбкодер не вернул ссылку на
   платформу.
8. **SEO.** `noindex, nofollow` на копиях, `<link rel="canonical">` на
   платформенный URL (это meta, не пользовательская ссылка — Q17 к legal,
   если и это нежелательно, оставить только noindex).
9. **Локали.** Отдавать под `/:locale/terms/*` те локали, что есть в
   `localizations`; остальное — фолбэк на `en` без редиректа, как на
   платформе.

Приёмка: (а) для `cf-ipcountry` ∈ {US, DE, UA, AE, IN} страница
`/terms/terms-and-conditions` на движке отдаёт тот же `content`, что
`promova.com/terms/terms-and-conditions` при том же гео (побайтовое
сравнение после нормализации whitespace); (б) `grep -r "promova.com/terms"`
по `src/` и `funnels/` пуст; (в) тест: HTML paywall/старт-скрина/чекаута не
содержит `href="https://promova.com`; (г) legal-ревью списка страниц и
факта, что домен документа совпадает с доменом сделки.

Зависимости: P1-33 (тот же кэш), P1-21/P1-22 (гео-ссылки и лейблы) —
делать одним изменением. Q16, Q17.

### 3.2 P1

**P1-1. Контракт ответов.** `src/engine.ts:245-292,366-387`: `selected_options` = тексты опций (title), `selected_answer_id` = answerKeys (как `formatAnswersForBE.ts:12-25`); `name-input`: `selected_options: ['provided']`, `selected_answer_id: [name]`. Приёмка: фикстура payload ↔ прод-фикстура из `packages/utils/formatAnswersForBE`.

**P1-2. `user_language_level`.** `src/engine.ts:buildQuizResult`: добавить запись `{question_id:'user_language_level', selected_options:[resolveActualLevel() ?? 'A1']}`. Исключить из `missingCoreKeys`.

**P1-3. `cleanSelectedAnswers`.** Порт `utils/email/cleanSelectedAnswers.ts` в `src/engine.ts` перед сборкой обоих payload.

**P1-4. Hand-off с `quiz_id`/`flow_id`/`entry_point`.** `src/engine.ts:366-387`: вернуть объект `{...answers, quiz_id, flow_id, entry_point}`; обновить `tests/handoff.test.ts:39`.

**P1-5. `user_type` для залогиненного.** `src/routes/quiz.ts:415-425`: `userType: ctx.userType` вместо литерала.

**P1-6. Backend CAPI-feed.** `src/routes/sales.ts` на GET paywall: `PATCH /v1/users/properties {fbc, fbp}` и `POST /v1/billing/funnel/users/payload {facebook_pixel_id, page_view:{url}}` (обёртки в `src/platform.ts`); `sendMarketingEvents` вызывать там же, где прод зовёт `logFacebookEvent` (email completed, purchase, upsell). Приёмка: моки вызваны с полями прода.

**P1-7. Meta `em`.** `src/http.ts:188-205` / `withUserId`: заполнять `ctx.email` из `idb`; `PixelConfig.email` на всех трёх поверхностях; в `third-party.ts` — `fbq('init', id, {em})` + re-init после email-экрана как `CommonScripts.tsx:117-133`.

**P1-8. Meta Purchase payload.** `src/analytics/ltv.ts:161-165` + `money.ts:333-338`: добавить `content_ids:[productId]`, `content_type: paymentMode`, `order_id`.

**P1-9. Google Ads конверсия.** `src/analytics/money.ts` на `PURCHASED`: два `dataLayer.push` по `utils/analytics.ts:578-631` (с USD-флипом и `user_email`).

**P1-10. `gen_joined_ab_test`.** `src/growthbook.ts`: из ответа remote-eval брать `experiments`/`inExperiment` и эмитить событие (once per sid, хранить в `state`); кэш ключевать с `device_id` для фич с процентным роллаутом (или отключить кэш для них). Приёмка: флаг с 50/50 на dev даёт разные варианты разным device_id и событие в логе.

**P1-11. Апселл-таксономия.** `src/analytics/money.ts:183,206-212`: `product_type: 'upsell'|'upsell_downsell'`, `screen_name: 'upsell'|'upsell-downsell'`, `page_path` реальный, `subscription_status` из `/v1/billing/products/available` после покупки; добавить `upsell_purchased`, `upsell_offer_viewed/accepted/declined`, `revenue_checkout_closed` на pp; once-гейт на `revenue_pricing_page_viewed` по `state`.

**P1-12. Свойства событий.** По таблицам `audit-analytics.md` §2.2, §2.4: `country_funnel` в `buildMoneyEnvelope`; `revenue_started_checkout` + `is_user_from_email, condition_id, checkout_name, cluster, weekPrice, …subscriptionData`; `sales_payment_success.total`; `funnels_email_completed.screen_name/cluster_number`; `funnels_started_funnel` + visibility-пропсы.

**P1-13.** `envelope.ts:107`: `step_number: String(n)`.

**P1-14.** `src/http.ts:200`: передавать существующий `_fbc` из куки в `buildFbc`.

**P1-15. Sticky CTA.** `funnels/general-english/sales.json:116-128`: добавить `stickyBar` с копией `copy.ts:448`; `src/render/sales.ts:297-309`: под FTC не прятать, а менять копию на `ctaFtc`; поправить `tests/sections.test.ts:76`.

**P1-16. `channel`.** `schema/sales.schema.ts:44-89` + `post-purchase.schema.ts`: поле `channel` (мёржить из `/v1/billing/products` если приходит); `src/checkout.ts:51-62,342`: слать при наличии.

**P1-17. `use_sand_box`.** `src/growthbook.ts`: читать флаг; `src/routes/sales.ts:466`: `sandbox = flag ?? !LIVE_MODE`.

**P1-18. PayPal-гейты.** `src/routes/sales.ts:479-483`: показывать PayPal только при GB `show_paypal_button` и валюте из `paypalSupportedCurrencies` (список из `Checkout.ts:1505-1511`).

**P1-19. BLIK / UPI / Pix + tokenization.** `src/checkout.ts:51-62` и `src/render/checkout.ts:390-415`: параметры кнопок из флагов `isShowBlikButton` (PL+PLN), `use_upi_payment` (IN+INR), `isShowPIXButton` (BRL); `blik` в заказе и `blikButtonParams` из одного источника. `tokenization_for_wallets_split` + `REBILL_PAY_TYPES`: не сохранять order_id для UPI и для кошельков без флага (`Sales.tsx:1306-1327`), хранить `entity`.

**P1-20. `secure-payment` с CMS-текстом.** `sales.json`: добавить секцию; `src/render/sales.ts:413-424`: поле `legal` заменить на `getLegalCheckoutText()` (уже есть в `platform.ts:274`).

**P1-21. Гео-ссылки на старт-скрине.** `funnels/general-english/config.json:86-106`: `legal` через `variants["country:eu"|"country:gb"|"country:us"]` (добавить наборы в `COUNTRY_SETS`), Refund-лейбл через `variants["flag:us_pricing_now_then"]`. Либо вынести генерацию legal-списка в рендер (`screens.ts:198-206`) с той же логикой, что `renderLegal` — предпочтительно, один источник.

**P1-22. Футер paywall.** `src/render/sales.ts:601-611`: лейблы через `t()`; добавить лид «By continuing you agree with:». «Legal Info» — не на `/contact-us` платформы, а на свою страницу из P0-20 шаг 6 (или не показывать).

**P1-23. Thank-you handoff.** Порт `packages/utils/buildPlatformHandoffQuery.ts:22-77` в `src/platform.ts`; CTA `/alpha` → `POST /alpha/:id/go`: эмитит `funnels_completed_funnel_survey`, минтит `link_for_auth` (P0-12), редиректит с query. HRP-роутинг — `hrp` из state.

**P1-24. Legal на offer/ty + FTC-вариант.** `src/routes/post-purchase.ts:184-209`: `getLegalFooterText`, рендер футера как на sales; `:538`: `variant` из `ftcPricing()`, не `'hard'`; на offer — аналог `OneTimeLegalShort` для one-time и `renewalLine` для подписки.

**P1-25. Мульти-плановый хоп.** `schema/post-purchase.schema.ts:106`: либо `plans.length === 1`, либо режим `bundle` с одним `productId` бандла и `includes[]` для показа. Не списывать `plans[0]` при `length > 1`.

**P1-26. State цепочки.** `src/routes/post-purchase.ts`: `showHop` пропускает `done`-хопы; `ds = true` на GET `/delta`; `hx-push-url` на переходах.

**P1-27. Retry записи результата.** `src/routes/quiz.ts:463`: на email-шаге, если `!qrid` — повторить `createTestResult` перед hand-off.

**P1-28. `CLAUDE.md` + SKILL.** Корень `funnel-engine/CLAUDE.md` (≤80 строк): 5 правил, no-prices, Funnel Core, «не писать код — сообщать о нехватке DSL», bash-инварианты, ссылки на команды. `.claude/skills/funnel-authoring/SKILL.md` с `autoLoad: funnels/**`.

**P1-29.** `package.json:11`: `build = images && typecheck && validate && bundle`.

**P1-30. Product id по каталогу.** `scripts/validate-funnels.ts`: флаг `--live` → `GET /v1/billing/products?ids=` (dev), FAIL на неизвестный id, WARN на расхождение `paymentMode`/периода. В `new-funnel.md` и CLAUDE.md: раздел «где взять productId» (Walhalla MCP `billing_plans`/`products`, или заявка).

**P1-31.** `schema/sales.schema.ts:434`: `timer` убрать из схемы или `validate` → FAIL. Решение продукта (§4).

**P1-32. Наблюдаемость.** DevOps: подтвердить `service_name=funnel-engine-{env}` в Loki; движок: структурные `console.error` заменить на `logEvent({kind:'error'})`; алерт на `events_ingested: 0` и на пустой paywall.

**P1-33. Кэш legal.** `src/platform.ts:262`: убрать `cf:`; in-process Map с TTL 3600 с по ключу `(type, country, locale)`, stale-while-revalidate.

### 3.3 P2

**P2-1. Прод-локали.** `/translate-page general-english es|pt|de|fr|it` — но не машинный перевод, а перенос из `code-funnels/general-english/locales/*.ts` и `money/general-english/locales/*.ts` (ключевать по EN-строке скриптом). Зарегистрировать в `CATALOGS`. Решить судьбу `uk` (§4).

**P2-2. Новые типы экранов.** По приоритету: (а) swym `results` — тип `resultsVariants` с `variants: Record<key,{title,focus[],heroMoment,proof}>` + селектор `$rules`; (б) `profile` — требует `$byAnswer.map` в объект: ввести `$byAnswerObject` с схемой значения; (в) english-hub `landing` — выразить как sales-страницу с email-шагом (см. вопрос §4), не как экран.

**P2-3.** Добавить в `quiz.schema.ts`: `answers[].reaction`, `loader.steps[]` (чек-лист), `choice.reassurance`, `bars[].pct` опционально (высота по индексу), `stat.footnote` вложенный, `{n}`/`count(answers)` в `resolve.ts`, lowercase-ключ гейта в `routes/quiz.ts`.

**P2-4.** `engine.ts:progressPercent`: знаменатель = число экранов с `questionKey`; опционально `quiz.progressTotal`.

**P2-5.** `-b`/`-g`: либо два конфига через `pnpm scaffold` + копия, либо (лучше) `completion.salesSlug` как поле с осью вариантов. swym-2/3, english-hub — после P2-2.

**P2-6.** `scripts/scaffold-funnel.ts`: писать `post-purchase.json` с одним хопом и `REPLACE_ME`; `assets/<id>/.gitkeep`; `funnels/<id>/README.md` с брифом; `.claude/commands/add-upsell-chain.md`.

**P2-7. Скиллы.** По одному файлу в `.claude/commands/` на шаг: `funnel-copy` (правка копии с прогоном `validate` и `i18n status`), `funnel-theme` (из палитры/Figma → `theme.json`), `funnel-images` (генерация → `assets/` → `pnpm images`), `add-screen`, `publish` (коммит + пуш + ссылка на dev-хост), `rollback` (revert + пайплайн), `post-launch-check` (Loki-запрос + Amplitude-чарт за сутки). Образец формы — `translate-page.md`.

**P2-8. Превью.** DevOps: короткоживущий деплой на dev-хост под путём `/preview/<branch>/` или неймспейс на ветку. Дешёвый промежуточный шаг — P2-9.

**P2-9. Скриншот-гейт.** В `ci.yml`: после `docker run` — Playwright-скрипт рендерит каждый экран × локали × `cf-ipcountry ∈ {US, DE, UA}` в PNG, кладёт артефактом PR.

**P2-10.** `scripts/gen-registry.ts` → `src/registry.generated.ts` из содержимого `funnels/`; `registry.ts` импортирует его; `validate` и рантайм читают один список.

**P2-11. Публикация без образа.** Дизайн-документ: configmap/объектное хранилище + подпись валидатора (`validate` пишет hash в манифест, рантайм отказывается читать конфиг без валидного hash). Только после дизайна.

**P2-12.** `schema/sales.schema.ts`: перенести `variants`-механику из `quiz.schema.ts:486-510`; `resolve.ts` применять к sales-дереву.

**P2-13.** `compare.columns[].image`; `sales.json:258` → тип `courses`; `stats.titleByGoal` через `$byAnswer`; тип `image` (standalone showcase); `page.footnote`; `page_url` с query из `state.attr`.

**P2-14.** `src/render/sales.ts:614-624`: рендер countdown из `remainingSeconds`; `src/routes/sales.ts:121-124`: swap продуктов только при `!ftcOn`.

**P2-15.** CheckoutDownsell: на decline-кодах `3.04/3.02/3.10` — блок с `POST /v3/billing/one-click-pay` (`api/billing.ts:219-240`). Coupon, `$1` note (`disclaimer_for_US_1usd`), `fakeDiscount`/`discountLabel`, `bestOfferCardNumber` — по потребности первого брифа.

**P2-16.** `src/registry.ts:147`: `getLocalizedPostPurchase(funnelId, locale)` через `translateTree`, как sales.

**P2-17.** `src/render/third-party.ts:113-118`: `device_os/type/size`, UTM `set`+`setOnce initial_*` once/session, referrer.

**P2-18.** `oaiq` (init + `order_created`/`custom upsell`), Clarity, Impact Radius в `third-party.ts`; generic `page_view` + `fbq/ttq ViewContent` на каждый экран; GA4 `view_item` на select.

**P2-19.** `attribution.ts`: first-touch `initial_*` в отдельной 365-дневной куке; `traffic_type`; `?ampSessionId`.

**P2-20.** `http.ts`: `?block_analytics` / `?preview` → `ctx.blocked`, все sink'и молчат, лог помечен.

**P2-21.** Reteno `sales_price_viewed`, `upsell_purchased`; `POST /v1/users/utm`; остальные 3 CPA-лукапа.

**P2-22.** `?lang=` в `locale.ts`; неизвестный `?screen` → 404 или клэмп (решение §4); resume — зафиксировать целевую семантику в README.

**P2-23.** `src/render/checkout.ts`: блок EBANX для `cf-ipcountry: BR` по `CheckoutFooter.tsx:65-79`.

**P2-24.** `i18n.ts:65-137`: добавить `errors.*` в `TRANSLATABLE_FIELDS` + ключи в `uk.json`; `screens.ts:401-403`: `maxlength=64`, `required`, серверный trim/срез по code point.

### 3.4 P3

**P3-1.** `tests/analytics.test.ts`: прогон полного пути через `tests/harness.ts`, снапшот всех `logEvent`/зеркал в golden-файл; диф — падение.
**P3-2.** `tests/money.test.ts`: 15 declines, `mergeLivePrices`, `formatPrice` × 16 валют, `introPeriodLabel`, `showNowThen`, обе FTC-копии; починить `tests/e2e.test.ts:290-295` (`plan`, не `productId`).
**P3-3.** `tests/validate.test.ts` на фикстурах-нарушителях; `tests/scaffold.test.ts` — скаффолд → validate падает ровно на картинках и id.
**P3-4.** `tests/legal.test.ts`: Cookie при `DE`, FAQ EU при `GB`, Refund-свитч под `?_ftc`, точный FTC-текст, ссылка на Subscription Terms.
**P3-5.** `validate-funnels.ts:645`: добавить словарь числительных прописью (en) и «N in M».
**P3-6.** `src/pricing.ts:62`: убрать мёрж `billingPeriodInDays` или обосновать и обновить комментарий `:41-43`.
**P3-7.** Один `COUNTRY_SETS` в `schema/quiz.schema.ts`, импорт в `render/sales.ts:570-573` и `render/consent.ts:28-36`.
**P3-8.** README: `:125` vs `:1368`, `:769-778` → 11 групп, `:1061`/`:1129`; комментарии `scripts/test.ts:4`, `scripts/i18n.ts:20-24`, `src/registry.ts:17`, `validate-funnels.ts:20-21`, `scaffold-funnel.ts:26`, `render/screens.ts:146-155`; в `plans/gimli2-email-step-parity.md` и `gimli2-existing-user-spec.md` заменить ссылки `src/index.ts:7xx` на `src/routes/quiz.ts`.
**P3-9.** `render/post-purchase.ts:44-51`: `skipTopLabel`; `button_type:'skip'` в `PRICING_CTA_IGNORED`; `channel` из плана; `entity` в `fe_pp`.
**P3-10.** Задокументировать в README как известные ограничения; алерт на `console.error` переполнения куки.

---

## 4. Вопросы к людям (блокируют конкретные пункты)

| # | вопрос | кому | блокирует |
|---|---|---|---|
| Q1 | Правила `us_pricing_now_then` / `ftc_soft_changes` в GrowthBook: `country` = «United States» или `US`? | владелец GB | P0-11 |
| Q2 | Ключ сервис-аккаунта Firebase в Vault движка — да/нет? Если нет — живём с `link_for_auth` (60 с TTL, минт на клик) | security | P0-12 (вариант B) |
| Q3 | Идемпотентность `POST /v3/billing/upsales`: есть ли серверная защита от повторного чарджа? `quiz_result_id` реально required? Валиден ли `channel: 'web'`? | бэкенд биллинга | P0-3, P0-4, P1-16 |
| Q4 | При сбое `/v1/billing/products`: пустой paywall (текущее) или авторские цены в USD с баннером (прод)? | продукт / money-метрика | P0-19 |
| Q5 | Реальный набор продуктов `general-english-downsell` и `-upsell*` (или дать доступ к gringotts commerce-эндпоинту) | продукт / CRM | P0-1, P0-9 |
| Q6 | Своя формулировка ROSCA под планами допустима, или только ревьюленная (24 ч + ссылка)? | legal | P0-13 |
| Q7 | Лимит `check_email_provider` по IP: весь трафик движка идёт с адресов пода | бэкенд auth | P0-16 |
| Q8 | `selected_options`: кто читает downstream — тексты или ключи? `selected_answer_id` нужен? | бэкенд / CRM / аналитика | P1-1 |
| Q9 | Таймер: WARN или FAIL (политика «таймеров не будет»)? | продукт | P1-31 |
| Q10 | Локали пилота: `uk` под что? Нужны ли прод `es/pt/de/fr/it` в MVP? | маркетинг | P2-1 |
| Q11 | english-hub `landing` — переносить как экран (30 полей) или как sales-страницу с email-шагом? | продукт | P2-2 |
| Q12 | Превью: неймспейс на ветку, путь на dev-хосте или только скриншоты в PR? | DevOps | P2-8 |
| Q13 | Логи `funnel-engine-{dev,prod}` в Loki: подтвердить датасорс и лейбл | DevOps | P1-32 |
| Q14 | `funnel_name` пилота — тот же, что прод (решено 8.09), при том что до P0-17/P1-1 данные квиза будут отличаться по форме? | аналитика | все P0 онбординга |
| Q15 | Бриф на первую воронку | продукт / маркетинг | P2-7, приёмка |
| Q16 | Перенести Cookie Policy из `CookiePolicy.tsx` в Strapi `page` (слаг `cookie-policy`), чтобы платформа и движок читали один текст | контент / legal / Strapi | P0-20 шаг 5 |
| Q17 | На копиях legal-страниц движка: допустим ли `rel=canonical` на `promova.com`, или только `noindex`? Нужна ли страница «Legal Info» на движке? | legal | P0-20 шаги 6, 8 |

---

## 5. Порядок исполнения

**Спринт A — «деньги и комплаенс» (P0, ~2 недели).**
Параллельно: (1) цепочка P0-1…P0-4; (2) аналитика P0-5…P0-8; (3) sales/legal
P0-9, P0-10, P0-13, P0-19, **P0-20** (legal-страницы на своём хосте — без
этого пилот на платном трафике не запускать вовсе); (4) email/квиз
P0-14…P0-18. P0-11 и P0-12 —
запросы к людям в первый день, вариант A для P0-12 делать не дожидаясь.
Выход: пилот можно ставить на 1 % US-трафика без риска двойного чарджа,
задвоенной выручки в Amplitude и нарушений FTC.

**Спринт B — «сравнимость с продом» (P1, ~2 недели).**
Контракты (P1-1…P1-5), Meta/Google (P1-6…P1-9), A/B (P1-10), апселл-события
(P1-11), способы оплаты (P1-16…P1-19), legal-мелочи (P1-20…P1-24), авторинг
(P1-28…P1-31), наблюдаемость (P1-32). Выход: дашборды прода читают движок
без оговорок; sanity-чек метрик пилота против прода.

**Спринт C — «первая воронка из брифа» (P2-6, P2-7, P2-10, P2-9 + бриф).**
Это цель проекта. До получения брифа — скаффолд post-purchase, CLAUDE.md,
скиллы, скриншот-гейт. С брифом — воронка через `/new-funnel` и запись
всего, что пришлось делать руками, как список следующих скиллов.

**Спринт D — «остальные воронки» (P2-1…P2-5, P2-12…P2-15).**
Локали → `-b`/`-g` → swym-3 (нужны `results`-варианты и `profile`) →
english-hub (после решения Q11). Каждая воронка — через авторинг, не порт
руками, иначе спринт C не проверен.

**Фоново — P3.** Golden-тест аналитики (P3-1) стоит сделать уже в спринте A:
он ловит P0-5…P0-8 и защищает их от регрессии.

**Не делать** (подтверждено аудитами, §6 старого плана остаётся в силе с
одной поправкой: пункт «не ходить в Strapi напрямую» снимается для
`/api/pages` — см. P0-20 шаг 1):
`language-picker` (0 прод-потребителей), geo-роутинг воронок (`= {}` в
проде), Strapi dynamiczone-секции, waterfall down-sale (AI-Tutor, spin
wheel), `/xray`, `/confirmation-banner`, `revenue_closed_payment_form`
двойной фаер, MB Way на sales, GCash (нет в монорепе).
