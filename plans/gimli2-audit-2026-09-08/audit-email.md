# Аудит паритета: EMAIL STEP + EXISTING-USER (Gimli 2.0 → funnel-engine)

Дата аудита: 2026-09-08.
Прод: `/Users/uvarovalexandr/myProject/promova.com_monorepo` (read-only).
Движок: `/Users/uvarovalexandr/myProject/funnel-engine`.

Проверено по коду, не по чек-листам. Важное расхождение с задачей: движок
отрефакторен — email-шаг больше **не** в `src/index.ts`, он в
`src/routes/quiz.ts` (`respondEmailStep`, строки 702–981). Все ссылки на
`src/index.ts:7xx/1xxx` из `gimli2-email-step-parity.md` и
`gimli2-existing-user-spec.md` **устарели**. `src/index.ts` теперь 9 КБ
бутстрапа.

Второе расхождение с документами: прод-хук `useCodeFunnelEmail.ts` **не** вынес
цепочку в `utils/email/setupCodeFunnelUser.ts` — такого файла в
`packages/features/FunnelBuilder/utils/email/` нет (`ls`: только
`checkUserActivePremiumSubscriptions.ts`, `cleanSelectedAnswers.ts`,
`getEmailDataByAdNameUTM.ts`, `getEmailRedirectUrl.ts`,
`getRetenoUserProperties.ts`, `sendEmailAnalytics.ts`,
`setupUserProfileData.ts`). Цепочка — inline в `setupNewUser`
(`useCodeFunnelEmail.ts:274-336`). Все ссылки вида `setupCodeFunnelUser.ts:160`
из `gimli2-existing-user-spec.md` не верифицируются.

---

## Таблица

### 1. Валидация email

| item | prod (file:line) | funnel-engine | статус | note |
|---|---|---|---|---|
| регулярка | `packages/config/constants/regex.ts:1` → `packages/utils/validateEmail.ts`, вызов `useCodeFunnelEmail.ts:359` | `src/email.ts:17-21` | **DONE** | `EMAIL_VALIDATE_REGEX_PATTERN` скопирована verbatim, комментарий объясняет почему нельзя «улучшать» |
| нормализация `trim().toLowerCase()` | `useCodeFunnelEmail.ts:354` | `src/routes/quiz.ts:718` | **DONE** | один раз, до всего |
| валидация ДО PENDING | `useCodeFunnelEmail.ts:359-377` (return без PENDING) | `quiz.ts:795-802` затем `827` | **DONE** | порядок соблюдён |
| `noValidate` на форме | `general-english/screens/EmailScreen.tsx:74` | `src/render/screens.ts:619` | **DONE** | комментарий в движке объясняет, что без этого сервер не увидит невалидный адрес и метрика ошибок обнулится |
| коды ошибок | `types/email_page.ts` `ERROR_TYPES`, копия `constants/email_page.ts:17-22` | `src/email.ts:24-29` + `schema/quiz.schema.ts:364-373` | **DONE** | 4 кода + 4 строки копии verbatim: `Oops! Please enter a valid email!`, `This email already exists` (×2 кода), `There is no account with this email :(` |
| маппинг REST-ошибок Firebase → `auth/*` | n/a (прод на JS SDK) | `src/email.ts:40-52` | **DONE** | `EMAIL_EXISTS`/`INVALID_EMAIL`/`EMAIL_NOT_FOUND`; неизвестное остаётся raw |
| `check_email_provider` как pre-check | `packages/api/auth/checkEmailProvider.ts` → `useCodeFunnelEmail.ts:420-427` | `src/platform.ts:77-91`, вызов `quiz.ts:872-877` | **DONE** | unauth POST `/v1/auth/check_email_provider` |
| **disposable / typo-домены** | **нет ни в проде, ни в схеме** (`grep disposable\|mailinator` по `FunnelBuilder` + `packages/api` — ноль). Описание эндпоинта в `schema.d.ts` упоминает «blocked providers», но контракт ответа этого не выражает | absent | **DONE (паритет)** | Проверять нечего: ни одна сторона не фильтрует. Пункт задачи «disposable/typo domain check (check_email_provider)» основан на неверной посылке — этот эндпоинт возвращает провайдеров аккаунта, а не блок-лист |
| **rate limiting** | FE не лимитирует; бэкенд отдаёт 429 `auth/too-many-requests` (`schema.d.ts` ответы `check_email_provider`) | absent (`grep rate.?limit\|throttle\|429` по `src/` — ноль) | **MISSING** | см. Gap 1 |
| ошибка `check_email_provider` фатальна? | `withOpenApiErrorHandler` **бросает** → submit прерывается | `quiz.ts:876` — только `console.error`, проваливается в link | **PARTIAL (осознанное расхождение)** | задокументировано в `gimli2-email-step-spec.md` §6.1 |

### 2. Firebase: anon → link, existing email, пароль, токены

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| анонимный вход | `signInAnonymously` (JS SDK) через `authService.ts` | `src/identity.ts:71-90` `accounts:signUp {returnSecureToken:true}` | **DONE** | REST-эквивалент, без клиентского SDK |
| link email | `EmailAuthProvider.credential` + `linkWithCredential`, `useCodeFunnelEmail.ts:429-437` | `src/identity.ts:98-129` `accounts:update {idToken,email,password,returnSecureToken}` | **DONE** | uid сохраняется, `platformUserId` не теряется (комментарий `identity.ts:115-117` — был баг) |
| случайный пароль | `crypto.randomUUID()` `useCodeFunnelEmail.ts:429` | `src/identity.ts:108` `crypto.randomUUID()` | **DONE** | |
| «email already in use» копия | `constants/email_page.ts:20-21` — `PROVIDER_LINKED` и `EMAIL_ALREADY_IN_USE` дают одну строку | `src/email.ts:54-55` `isAlreadyRegistered`, `quiz.ts:886` | **DONE** | |
| sign-in вместо линка | `useCodeFunnelEmail.ts:175-177` `signInUrl` = `/echo/default?form_type=sign-in&funnel_slug=…&to=/sierra/<sales>` | `src/email.ts:89-101` `buildSignInUrl` | **DONE** | relative + locale-prefix; `webOrigin` только для interim-хоста |
| password recover | **в проде на email-шаге НЕТ** (`EmailScreen.tsx:100-107` — только «Log in») | `src/email.ts:113-122` `buildPasswordRecoverUrl` → `/echo/password-recover?from=sign-in&slug=default` | **улучшение над прод** | Но: страница не читает `?email=` (`PasswordRecover.tsx:29`) и делает тихий no-op при неподнятом SDK (`:47-48`) |
| magic link | нет на email-шаге; `sid` только письмом (`/complete-sign-up/{sid}`) | absent | **DONE (паритет)** | |
| что получается на выходе | Firebase-сессия в IndexedDB + зеркало в **не-httpOnly** cookie `stsTokenManager` (`authService.ts:231-238`) + `withAuth=true` (`:127-132`) + `__session` httpOnly для не-анонима (`api/auth/sign-in/route.ts:60-67`) | sealed `idb` внутри HMAC-подписанной httpOnly cookie `fe_state`, `Path=/`, `SameSite=Lax`, `Max-Age=86400` (`src/state.ts:356-384`); внутри только `uid`, `platformUserId`, `refreshToken`, `email` (`identity.ts:172-184`) — idToken выброшен намеренно | **PARTIAL** | **Браузерной Firebase-сессии движок не создаёт вообще.** См. Gap 5 |
| refresh токена | SDK сам | `src/identity.ts:132-156` + `hydrate` `:191-208` | **DONE** | snake_case securetoken нормализован |
| E5: другой адрес после успешного линка | `linkWithCredential` на уже слинкованном → `auth/provider-already-linked` → тупик «This email already exists» (ложь) | `quiz.ts:823` fast-path только при `stored.email === email`; иначе `accounts:update` **сменит** адрес (это update, не link) и прогонит всю цепочку заново | **PARTIAL / расхождение** | см. Gap 6 |

### 3. Персист ответов под правильным uid до хэнд-оффа

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| куда пишутся ответы | `packages/utils/saveTestResults.ts:11-59` → `POST /v1/quiz-results`, из `useSaveTestResult` (смонтирован на loader'е) | `src/platform.ts:177-190` `createTestResult` → `POST /v1/quiz-results/?not_update_profile=false`, вызов `src/routes/quiz.ts:463-490` в `/kilo/:id/prepare?full=1` | **DONE** | loader `s25` — ровно там же, где прод; **до** email-шага `s26` |
| под каким id | `userId` из `useProfile()` = платформенный `user_id` | `identity.platformUserId` (`quiz.ts:466`) | **DONE** | link email не меняет uid → id остаётся верным после email-шага |
| шейп (Funnel Core keys) | `formatAnswersForBE.ts:12-32`: `question_id` перезаписывается `questionKey` (`:24`), `selected_options = selectedAnswers`, `selected_answer_id = selectedAnswerIds`, `category==='grammar'` → `language_test` | `src/engine.ts:245-292` `buildQuizResult`: `question_id: screen.questionKey ?? screenId`, `selected_options: answerKeys`, `language_test: {type:'common',payload:{answers:[]}}` всегда присутствует | **PARTIAL** | нет поля `selected_answer_id` — см. Gap 7 |
| идемпотентность | нет (React-эффект + инвалидация кэша профиля) | guard `!prepared.qrid` (`quiz.ts:463`), id пишется в state (`:487`) | **DONE** | |
| **retry при провале** | `useSaveTestResult` ждёт `userId`, инвалидирует кэш профиля (`useSaveTestResult.ts:140-152`) | однократно; при `!identity.platformUserId` или неуспехе — только `console.error` (`quiz.ts:489`), email-шаг **не** повторяет | **PARTIAL** | см. Gap 8 |
| localStorage-хэндофф для `/echo` | n/a (прод пишет `funnel_builder_user_answers` сам) | `src/render/screens.ts:623-645` inline `<script>` на ветке `emailError.exists`; шейп `src/engine.ts:366-387` `buildPlatformAnswers` | **DONE** (коммит `6bcf0c1`) | **ПОДТВЕРЖДЕНО**: пишется только на этой ветке (`handoff.test.ts:72-77`), только при непустых ответах (`:79-83`), payload — JSON-строковой литерал, экранирован `</` (`screens.ts:642`), round-trip проверен тестом (`:88-91`) |
| … но payload неполный | `saveTestResults.ts:22-24` читает `answers.entry_point`, `answers.quiz_id`, `answers.flow_id` из того же объекта | `buildPlatformAnswers` возвращает **только** словарь скринов, без `entry_point`/`quiz_id`/`flow_id` | **PARTIAL** | см. Gap 9 |

### 4. Хэнд-офф в платформу

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| `/echo/default?form_type=sign-in` | `useCodeFunnelEmail.ts:175-177` | `src/email.ts:89-101` + `screens.ts:637-640` | **DONE** | единственный реально используемый хэнд-офф на email-шаге |
| `/echo/password-recover` | не с email-шага | `src/email.ts:113-122` | **улучшение** | |
| `/sierra/{slug}/{userId}` | `Sales.tsx` `params.slug[1]` побеждает `useProfile()` | движок отдаёт визитёра на **свой** `/sierra/{funnelId}` (`quiz.ts:1252-1266`), т.к. `getSalesPage('general-english')` есть (`src/registry.ts:57-59`); платформенная форма с `{platformUserId}` — только фолбэк `quiz.ts:1277-1281` | **DONE (по-другому)** | пункт #17 паритет-листа для general-english неактуален: пейволл свой |
| `/complete-sign-up` | `usePlatformRedirect.ts:53-58`, маршрут решает `localStorage['hrp']` | `src/routes/sales.ts:635` и `:643` — статический `<a href="{WEB_ORIGIN}/complete-sign-up">` после покупки | **MISSING** | см. Gap 10 |
| `/sign-in?custom_token` / `/autologin` | `POST /v1/users/link_for_auth` → `{url}`; обработчик `AutoLoginPage.tsx:38` `signInWithCustomToken` | **absent**. Единственное упоминание — пробник `src/routes/diag.ts:57-66` | **MISSING** | см. Gap 5 и п.10 ниже |
| cross-host cookie | `stsTokenManager`/`withAuth` — host-only, `Path=/`, без `Domain`; `__session` — `SameSite=Strict` | `fe_state` — host-only, `Path=/`, `SameSite=Lax` (`state.ts:375-377`) | **PARTIAL — блокер** | см. Gap 5: пока движок не на `promova.com` за route split, обмен сессией невозможен ни в одну сторону |
| что передаётся | — | `quiz.ts:1269-1281`: `funnel_slug`, `ad_topic`, `funnel_source`, `country`, `sid`, + `{platformUserId}` в пути | **PARTIAL** | прод дополнительно несёт `fbclid`/`gclid`/`gbraid`/`course` (пункт #17 паритет-листа); не проверялось повторно, вне email-шага |

### 5. Marketing consent / GDPR

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| флаг видимости | `useCodeFunnelEmail.ts:157-161` GrowthBook `compliance_config_promova` → `use_marketing_consent`; дефолт `true` (`remote_config.ts`) | `src/growthbook.ts:211-216` `marketingConsentRequired`, дефолт `true` при отсутствии значения; remote-eval только на email-скрине (`quiz.ts:311-330`) | **DONE** | движок платит за GrowthBook ровно на одном скрине |
| семантика shown/hidden | `:163` `isConsentChecked = consentOverride ?? !isShowConsent` — показан ⇒ default unchecked; скрыт ⇒ implicit `true` | `screens.ts:672-681` скрытый маркер `consent_shown=1` рядом с чекбоксом; `quiz.ts:1068-1070` парсит оба; `quiz.ts:942` `marketing = consent.shown ? consent.checked : true` | **DONE** | маркер обязателен: unchecked box и отсутствующий box сабмитятся одинаково — движок это явно обрабатывает |
| запись значения | `setupUserProfileData.ts:24-27` → `setEmailNotifications` → `PUT /v1/profiles/notifications {marketing}` | `src/platform.ts:303`, вызов `quiz.ts:929` | **DONE** | пункт #6 паритет-листа закрыт |
| сохранение состояния при отказе | React state | `deny()` → `consentChecked: consent.checked` (`quiz.ts:791`), рендер `screens.ts:675-677` | **DONE** | |
| копия чекбокса | `EmailScreen.tsx:32-33` `CONSENT_NOTE` | `funnels/general-english/config.json` `s26.consentNote` — та же строка; переведена в `locales/uk.json` | **DONE** | |
| Privacy Policy как реальная ссылка | `EmailScreen.tsx:109-120`, геоделта копии `PRIVACY_NOTE_ROW` / `PRIVACY_NOTE_COMPLIANCE` | `s26.privacyNote` + `screens.ts:683-688` `platformHref` (locale-prefix) | **DONE** | uk-каталог содержит compliance-вариант строки |
| `POST /v1/dnt` (consent-of-record) | `useSaveUserConsent.ts` → `packages/api/user.ts:186` | absent (`grep dnt` — ноль) | **MISSING** | пункт #16, out of scope по указанию Alex |

### 6. Customer.io / email-сервис

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| Customer.io | **отсутствует во фронте вообще**: `grep -rln "customerio\|customer\.io"` по `packages/` + `apps/` — **ноль совпадений** | absent | **DONE (паритет)** | ESP на email-шаге — **Reteno**, не Customer.io. `customerio_track_event` существует только как бэкенд-инструмент (Walhalla), фронт его не вызывает |
| `lead` / identify в CRM | `sendRetenoAnalytics` event `funnels_email_completed {way, target_language}` + enrichment `country/platform/locale` (`retenoAnalytics.ts`, вызов `sendEmailAnalytics.ts:122-132`) | `src/platform.ts:356` `sendRetenoEvent`, вызов `quiz.ts:948-957` (+ `country`, `platform:'web'`, `locale`) | **DONE** | |
| Reteno slug-property (deep link на пейволл) | `setupUserProfileData.ts:19` → `setProfileRetenoProperties.ts:21-29` `POST /v1/property/receiver/reteno {params:{slug,language_code}}`, slug = `<sales>/<uid>?funnel_slug=<id>` (`useCodeFunnelEmail.ts:289`) | `src/platform.ts:340` `setRetenoSlugProperty`, вызов `quiz.ts:918-924`, тот же шейп slug | **DONE** | пункт #5 паритет-листа закрыт |
| Reteno user-properties из ответов | `getRetenoUserProperties` → `sendRetenoProfileProperty` (`useCodeFunnelEmail.ts:316-321`) | `src/platform.ts:375`, `buildRetenoProperties` (`src/engine.ts`), вызов `quiz.ts:959-963` | **DONE** | |
| гейт окружения | `sendRetenoAnalytics` и `sendRetenoProfileProperty` — `if (!IS_PRODUCTION) return` (`retenoAnalytics.ts:19` и `:89`). **slug-property НЕ гейтится** (`setProfileRetenoProperties.ts` — чистый axios) | `quiz.ts:944` `crmLive = LIVE_MODE\|\|SEND_EVENTS` гейтит event + user-properties; slug-property и `setEmailNotifications`/`setHrpFlag` — **без гейта** | **DONE** | Совпадает с реальным продом. Утверждение `gimli2-email-step-parity.md` «both Reteno calls are IS_PRODUCTION-gated» **неверно** для slug-property |
| `POST /v1/marketing/events` (зеркало Meta) | `facebookEventLogger.ts` → `packages/api/marketing.ts:12`, из `sendDefaultFacebookEvent` (`sendEmailAnalytics.ts:104-113`) | `src/platform.ts:402` `sendMarketingEvents` **написан, вызывающего нет** (`grep` — только определение) | **MISSING** | пункт #7 паритет-листа не закрыт |
| Meta CAPI | `sendToServerFacebookEvent.ts:110` `FB_PROXY_DISABLED = true` | absent | **DONE (паритет, не трогать)** | пункт #14 |
| Snap/Twitter/Pinterest | вызываются, но `CommonScripts.tsx:73-77` `withSnap/withTwitter/withPinterest = false` ⇒ no-op | `src/analytics/pixels.ts:112-115` — намеренно отсутствуют, с комментарием | **DONE (паритет)** | пункт #15 |

### 7. Name-input screen

| item | prod (`general-english/screens/NameScreen.tsx`) | funnel-engine | статус | note |
|---|---|---|---|---|
| позиция | `s26b`, после email, перед results | `funnels/general-english/config.json` `s26b`, `questionKey: "name"` | **DONE** | |
| PII в аналитике | `:34` `NAME_ANALYTICS_PLACEHOLDER = 'provided'` в `selectedAnswers`; настоящее имя в `selectedAnswerKeys` | `src/routes/quiz.ts:144` `if (screen.type === 'name-input' \|\| screen.type === 'email') return 'provided'` | **DONE** | движок распространил правило и на email-скрин — прод там `onAnswer` вообще не зовёт |
| длина | `:40` `MAX_NAME_LENGTH = 64`, срез по code point (`:58-61`) | `screens.ts:402` `maxlength="40"` | **PARTIAL** | 40 против 64; серверной обрезки нет вовсе — `applyAnswer` берёт значение как есть, `maxlength` в HTML обходится curl'ом |
| disabled при пустом | `:102` `disabled={!trimmed}` | нет (`screens.ts:403` — просто кнопка), поля `required` тоже нет | **PARTIAL** | пустое имя проходит; `renderResults` (`screens.ts:418-420`) тогда просто не покажет greeting |
| **куда сохраняется имя** | **никуда за пределы браузера.** `onAnswer` пишет в `UserAnswers` (localStorage). `useSaveTestResult` смонтирован на **loader'е** (`FunnelContext.tsx:243-247`), т.е. до name-скрина ⇒ `POST /v1/quiz-results` уже ушёл. Записи имени в профиль нет: `grep first_name\|firstName\|updateProfile` по `FunnelContext.tsx` — ноль | так же: `createTestResult` только в `/prepare` на loader'е; имя остаётся в `fe_state` и используется только для greeting | **DONE (паритет)** | **Пункт задачи «where the name is stored (platform profile field)» — ложная посылка: в проде имя в профиль платформы не попадает вообще.** Единственный путь, которым имя может доехать до бэкенда — повторный `saveTestResults` при sign-in на `/echo` (из localStorage), т.е. только в existing-email ветке |

### 8. Existing / авторизованный визитёр (сценарий B)

| item | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| детект `withAuth` | `authService.ts:127-132` пишет cookie | `src/http.ts:232-238` `signedInOnPlatform` + тесты `tests/session.test.ts:25-49` (границы имени cookie, `withAuth=false`, `notwithAuth=true`) | **PARTIAL** | реализовано, но использовано **только** для `user_type` |
| детект `stsTokenManager` / верификация JWT | `authService.ts:231-238` | **absent** (`grep stsTokenManager` по `src/` — ноль) | **MISSING** | ни JWKS, ни `accounts:lookup`, ни `sign_in_provider` |
| `user_type: 'registered'` в событиях воронки | `FunnelContext.tsx:324, 923-925, 960-962` | `http.ts:195` `userType: signedInOnPlatform(c) ? 'registered' : 'unregistered'` — **но** `quiz.ts:415-425` `withUserId` безусловно переписывает на `'unregistered'`, как только у прогона есть `idb` | **PARTIAL — баг** | см. Gap 2 |
| префилл email для залогиненного | code-funnel: **нет** (`EmailScreen.tsx:85-96` без `defaultValue`); Strapi `/echo`: есть (`Email.tsx:159,700,826`) | нет | **DONE (паритет с code-funnel)** | |
| скип email-шага для залогиненного | нет ни там, ни там | нет | **DONE (паритет)** | |
| запрет HRP для платформенной сессии (B-дефект 1) | прод **ставит** HRP на реальный аккаунт (`useCodeFunnelEmail.ts:293-294` после ветки `:401`) | `quiz.ts:934-937` `setHrpFlag` вызывается всегда после успешного линка; проверки `sign_in_provider !== 'anonymous'` нет | **MISSING** | движок не может воспроизвести дефект (он линкует только свою анонимную сессию), но и защиты, предписанной спецификацией §2.3, тоже нет |
| ветка копии по `providers` (соц vs пароль) | нет | нет: `quiz.ts:873-875` — `providers.length > 0` ⇒ одна и та же ветка `alreadyRegistered(PROVIDER_LINKED)`, содержимое массива не читается | **MISSING** | «not started» в плане подтверждается |
| redirect уже подписанного (premium) | `/echo` перехватывает и уводит на `/my-plan` (`Email.tsx:276-295`, `SignInForm.tsx:105-112`); прямой заход на `/sierra` — нет | нет | **PARTIAL (паритет с `/sierra`)** | |
| `subscription_status` | хардкод `'free'` (`useCodeFunnelEmail.ts:250`, `setupNewUser` → `sendEmailAnalytics` `subscriptionStatus:'free'` `:312`) | хардкод `'free'` (`quiz.ts:857`, `:978`) | **DONE (паритет с дефектом)** | `GET /v1/products/available` не вызывается ни там, ни здесь |
| E10 (платит под одним, залогинен под другим) | не обрабатывается | не обрабатывается | **MISSING** | |

### 9. Аналитика email-шага

| событие / свойство | prod | funnel-engine | статус | note |
|---|---|---|---|---|
| `funnels_email_submited_pending` | `useCodeFunnelEmail.ts:388-396`, 4 поля, `source` читается **напрямую** из `localStorage[FUNNEL_SOURCE]` (`:394`), до auth-цепочки | `quiz.ts:827` `report(EMAIL_SUBMITED_PENDING, {})` — полный envelope, **до** provider-check и link | **PARTIAL (осознанное)** | пункт #12: envelope шире, но порядок теперь правильный (в отличие от описанного в паритет-листе) |
| `funnels_email_completed` (успех) | `sendEmailAnalytics.ts:57-71`: `domain, funnel_name, country_funnel?, screen_id, source, auth_type, user_email` (RAW), `user_type:'unregistered'`, `subscription_status`, `localization`, `screen_name`, `answer: sha256(email)`, `ad_topic`, `cluster_number?` | `quiz.ts:973-979`: envelope (`domain, funnel_name, screen_id, step_number, localization, source, user_type, screen_type, step_type, ad_topic, country, country_funnel?, slug, page_path, utm*`) + `auth_type:'email'`, `user_email` (RAW), `answer: hashed`, `subscription_status:'free'` | **PARTIAL** | закрыто: `country_funnel` (envelope), RAW-email, `answer: sha256`. **Не закрыто: `screen_name`, `cluster_number`** (пункт #9) |
| `funnels_email_completed` (existing) | `reportAlreadyRegistered` `:238-253` через `sendAnalytics` ⇒ пиксели молчат | `quiz.ts:850-862` + `{ adConversion: false }`; фильтрация в `src/analytics/emit.ts:146-148` | **DONE** | явно, а не по случайности |
| `funnels_email_entered_error` | 3 значения `user_type`: `no_info` (`:370`), `registered` (`:266`), `unregistered` (`:466`); `user_email: sha256` всегда | `quiz.ts:796-800` `no_info`, `:864-868` `registered`, `:889-894` `unregistered` | **DONE** | пункт #11 закрыт |
| PII-асимметрия (error = sha256, completed = RAW) | закреплена тестом `useCodeFunnelEmail.test.ts` | `quiz.ts:719` `hashed` только в error-события; RAW в `completed` и `identify` | **DONE** | |
| Amplitude `setUserProperties` | `reportAlreadyRegistered:235-236` (2 вызова) и `sendEmailAnalytics.ts:77-78` | `quiz.ts:838-841` sink `amplitude-identify`; реплей `src/analytics/pixels.ts:191-197` (`new Identify()` + `.set` на ключ, как прод) | **DONE** | пункт #10 закрыт; эмитится **до** событий, очередь общая с `amplitude` (`pixels.ts:219-224`) — порядок не гонится |
| Amplitude `user_id` | `setAmplitudeUserId(user.uid)` — Firebase uid (`authService.ts:128`) | `quiz.ts:415-425` `withUserId` → `ctx.userId = stored.uid`; в браузер отдаётся заголовком `X-Amplitude-User-Id` (`quiz.ts:494`) | **DONE** | |
| `funnels_email_field_touched` | хук отдаёт `handleFocus`, но `general-english/EmailScreen.tsx` его **не подключает** | в allowlist (`quiz.ts:622`), но `renderEmail` (`screens.ts:605-687`) не имеет ни focus-, ни change-триггера ⇒ не летит | **DONE (паритет)** | пункт #8 разрешился в пользу паритета |
| `funnels_email_field_changed` | только legacy Strapi `DefaultForm.tsx:144` | то же — allowlist без вызывающего | **DONE (паритет)** | |
| TikTok CompleteRegistration (server) | `sendTiktokEvent` из браузера | `src/analytics/emit.ts:69-71` — единственное серверное событие TikTok | **DONE** | |
| Meta `em` advanced matching | 2 части: `setFacebookUserEmail(email)` (`sendEmailAnalytics.ts:54`) + **`fbq('init', pixelId, {em})` заново** (`CommonScripts.tsx:114-131`) | `src/analytics/pixels.ts:135` кладёт `em` в **параметры события**; `ctx.email` нигде не заполняется (`grep` — ноль присвоений `email:` в `requestCtx`, `src/http.ts:188-205`) ⇒ ветка мёртвая | **MISSING** | пункт #13 открыт целиком: и шейп неверный, и значения нет |
| локализация копии ошибок | lingui `msg` ⇒ переведено (`apps/funnels/chameleon/locales/uk/file.po:8397-8398` «Ця електронна пошта вже існує») | `errors.*` отсутствуют в `TRANSLATABLE_FIELDS` (`src/i18n.ts:65-137`) **и** в `funnels/general-english/locales/uk.json` | **MISSING** | см. Gap 3 |

### 10. Custom-token подпись в контейнере (ожидает security)

| item | статус | что известно из кода |
|---|---|---|
| подпись custom token в движке | **MISSING** | `grep SERVICE_ACCOUNT\|signCustomToken\|RSASSA` по `src/` — ноль. Секрета в окружении нет |
| что именно этим заблокировано | 1) браузерная Firebase-сессия на платформе после воронки (`/autologin?custom_token=…`); 2) обход 60-секундного TTL `link_for_auth` (`schema.d.ts` `token_ttl` default = max = 60) ⇒ линк можно минтить только «на клик»; 3) корректные user-properties на платформе после хэнд-оффа; 4) вход в `/complete-sign-up` и `/my-plan` без `sid` |
| fallback сегодня | `POST /v1/users/link_for_auth` — **не подключён к продуктовому пути**, есть только пробник `src/routes/diag.ts:57-66` (по нему и был получен вердикт `400 89012 "user email is empty"` для юзера без email). Реально работающий fallback: (а) существующий email → `/echo/default?form_type=sign-in` + запись ответов в localStorage (`screens.ts:642`) — платформа поднимает сессию сама; (б) после покупки → статическая ссылка `/complete-sign-up` **без сессии и без `sid`** (`src/routes/sales.ts:635,643`) ⇒ по `CompleteSignUp.tsx:163-166` это `replace('/sign-in')` |
| что НЕ заблокировано | Денежный путь: движок держит свой `/sierra/{funnelId}` (`registry.ts:57-59`, `quiz.ts:1252-1266`) и свой чекаут, identity берётся из `fe_state`. Custom token для оплаты не нужен |

---

## Gaps (с доказательствами)

**Gap 1 — на `/kilo/:id/answer` нет никакого rate limit, а email-шаг с него дергает Firebase и бэкенд.**
`app.post('/kilo/:id/answer', …)` (`src/routes/quiz.ts:1030`) не аутентифицирован
(достаточно валидного подписанного `fe_state`, который выдаётся любому GET'у) и
на email-скрине выполняет `POST /v1/auth/check_email_provider`
(`quiz.ts:872`) + Firebase `accounts:update` (`quiz.ts:884`). Ни лимита по IP,
ни по сессии, ни по адресу (`grep -rin "rate.?limit\|throttle\|too-many"` по
`src/` — ноль совпадений). Два следствия:
(а) enumeration существующих адресов через `check_email_provider` от лица
датацентрового IP;
(б) E11 из `gimli2-existing-user-spec.md` — 429 от бэкенда придёт на **общий**
IP пода, а не на IP визитёра, и `quiz.ts:876` мягко деградирует в link, т.е.
проблема будет невидимой в метриках.
Ключ лимита на бэкенде — по-прежнему открытый вопрос №5.

**Gap 2 — `withUserId` стирает `user_type: 'registered'`.**
`src/http.ts:195` корректно выставляет `userType` по cookie `withAuth`, но
`src/routes/quiz.ts:415-425`:
```ts
return stored?.uid ? { ...ctx, userId: stored.uid, userType: 'unregistered' } : ctx
```
— безусловно. Так как `withUserId` применяется на `/answer` (`quiz.ts:668`,
`:762`) и на `/event` (`:669`), у залогиненного визитёра `user_type` честен
только на первых двух событиях (до появления `idb`), а дальше становится
`unregistered`. Это ломает ровно ту единственную адаптацию, которую делает прод
(`FunnelContext.tsx:324, 923-925, 960-962`), и делает поле `user_type` в
`funnels_email_completed` бессмысленным для сценария B.

**Gap 3 — копия ошибок email-шага не локализуется вообще.**
Дефолты `errors.invalid / exists / generic / signInLead / signInLabel /
recoverLabel` заданы в `schema/quiz.schema.ts:364-373`. Ни одно из этих имён
полей нет в `TRANSLATABLE_FIELDS` (`src/i18n.ts:65-137`), и ни одной из строк
нет в `funnels/general-english/locales/uk.json` (проверено: все шесть ключей →
`None`). Значит украинский визитёр на отказе видит
`This email already exists`, `Log in`, `Forgot password?` по-английски. Прод это
переводит (`apps/funnels/chameleon/locales/uk/file.po:8396-8398`). Фикс —
двухчастный: добавить имена в `TRANSLATABLE_FIELDS` **и** ключи в каталог;
одного каталога недостаточно.

**Gap 4 — сырой email уезжает в localStorage и в `/v1/quiz-results` там, где прод его туда не кладёт.**
Прод `EmailScreen.tsx` **не вызывает `onAnswer`** (в списке пропсов `:42-45`
только `data` и `onNext`) ⇒ адрес никогда не попадает в `UserAnswers` и, значит,
ни в localStorage, ни в `selected_options` квиз-результата.
Движок: `quiz.ts:761` `applyAnswer(quiz, working, node, [email])` кладёт адрес в
`state.answers['s26']`; на ветке `alreadyRegistered` → `deny()` →
`respondWithScreen(…, attempt, …)` (`quiz.ts:785-793`) → `renderEmail` пишет
`buildPlatformAnswers` в `localStorage['funnel_builder_user_answers']`
(`screens.ts:642`), а `buildPlatformAnswers` (`src/engine.ts:373-386`) кладёт
`selectedAnswers: answerKeys` без исключений. Итог: сырой адрес оказывается в
**не-httpOnly** localStorage на `promova.com` (читается любым скриптом), а затем
уезжает в `selected_options` при повторном `saveTestResults` на `/echo`.
Плюс он же лежит base64 в `fe_state` (подписана, но не шифрована — шифруется
только `idb`, `state.ts:356-384`) — это известный пункт #18, но Gap 4 хуже:
это не наша cookie, а общее хранилище платформы.

**Gap 5 — браузерная сессия не передаётся ни в одну сторону, и это упирается в route split, а не только в security sign-off.**
Движок не создаёт Firebase-сессию в браузере вообще (`src/identity.ts` — только
REST), не читает `stsTokenManager` и не подписывает custom token. Единственный
рабочий переход — отдать визитёра платформенной странице, которая поднимет
сессию сама (`/echo`). Оба cookie платформы (`withAuth`, `stsTokenManager`) —
host-only, так что `signedInOnPlatform` (`http.ts:232-238`) вернёт `false`,
пока движок живёт не на `promova.com`. То есть сегодня работает не только
custom-token путь, но и **детект** сценария B — тесты
`tests/session.test.ts:25-49` проверяют парсер, а не доступность cookie.

**Gap 6 — смена адреса посреди прогона тихо переписывает email аккаунта.**
`quiz.ts:823` даёт fast-path только при точном совпадении. Иначе выполняется
`accounts:update {idToken, email, password}` (`identity.ts:103-112`) — а это
**update**, не link: Firebase сменит адрес уже слинкованного пользователя и
вернёт 200. Дальше `quiz.ts:905-969` заново прогонит slug-property,
`setEmailNotifications`, `setHrpFlag`, Reteno-event и Reteno-properties, и
`quiz.ts:973` выстрелит вторым `funnels_email_completed` (с
`adConversion: true`, т.е. вторая CompleteRegistration в Meta/TikTok на того же
человека). Прод в этом месте падает в `auth/provider-already-linked`
(тупик, но без двойной конверсии). Нужна явная ветка
`stored.email && stored.email !== email`.

**Gap 7 — `selected_answer_id` не отправляется, поэтому имя приходит не в то поле.**
`formatAnswersForBE.ts:19-23` кладёт `selectedAnswerIds` в
`answer.selected_answer_id`, а `NameScreen.tsx:65-70` передаёт настоящее имя
именно через `selectedAnswerKeys` (→ `selectedAnswerIds`), оставляя в
`selectedAnswers` константу `'provided'`. У движка `buildQuizResult`
(`src/engine.ts:263-270`) и `buildPlatformAnswers` (`:373-386`) поля
`selected_answer_id` / `selectedAnswerIds` **нет вообще** — есть только
`selected_options`, куда попадает сырое значение. То есть шейп расходится в двух
направлениях сразу: у прода в `selected_options` константа, а настоящее значение
в отдельном поле; у движка сырое значение в `selected_options` и второго поля
нет. Для name-скрина это неважно (он идёт после квиз-результата), а для
существующего email — важно, потому что `/echo` пересохранит наш словарь через
`formatAnswersForBE`.

**Gap 8 — квиз-результат пишется один раз и не переспрашивается.**
`quiz.ts:463` `if (withProfile && identity?.platformUserId && !prepared.qrid)`.
Если `getOrCreateProfile` не вернул `user_id` (по `diag.ts` этот вызов —
~2.8 с синхронного провижининга на бэкенде) или `createTestResult` упал, в логах
будет `quiz result save failed` (`quiz.ts:489`) и **всё**: email-шаг повтора не
делает, `qrid` остаётся пустым, `quizResultId` не доедет до чекаута
(`src/routes/sales.ts:439`). Прод здесь настойчивее: `useSaveTestResult` ждёт
`userId` и инвалидирует кэш профиля (`useSaveTestResult.ts:140-152`).

**Gap 9 — localStorage-хэндофф не несёт `quiz_id` / `flow_id` / `entry_point`.**
`saveTestResults.ts:22-24` читает эти три поля **из того же объекта**
`answers`, а `buildPlatformAnswers` (`src/engine.ts:366-387`) возвращает только
словарь `screenId → entry`. Значит на `/echo` платформа пересохранит результат
с `quiz_id: undefined`, `flow_id: undefined`, `entry_point: undefined`.
Коммит `6bcf0c1` спас **ответы**; принадлежность результата воронке — нет.
Тест `tests/handoff.test.ts:39` фиксирует «одна запись на отвеченный экран», то
есть он закрепляет текущее (неполное) поведение.

**Gap 10 — после покупки визитёр уходит на `/complete-sign-up` без сессии и без `sid`.**
`src/routes/sales.ts:635` и `:643` — статический
`<a href="{WEB_ORIGIN}{/locale}/complete-sign-up">`. По
`CompleteSignUp.tsx:163-166` (`!user && !sid → replace('/sign-in')`) это
означает, что заплативший визитёр попадёт на форму входа с HRP-паролем, которого
он никогда не видел. Прод приходит туда с уже поднятой браузерной сессией
(`usePlatformRedirect.ts:53-58`). Это тот же корень, что Gap 5, но это
**денежный** путь, а не email-шаг.

**Gap 11 — `sendMarketingEvents` и Meta `em` остаются написанным-но-невключённым кодом.**
`src/platform.ts:402` — функция есть, вызывающего нет (пункт #7).
`src/analytics/pixels.ts:135` — ветка `em` есть, но (а) кладёт `em` в параметры
события, а Meta ingest'ит advanced matching только через `fbq('init', id, {em})`
(`CommonScripts.tsx:114-131`), и (б) `ctx.email` не заполняется никогда
(`requestCtx`, `src/http.ts:188-205`, не содержит `email`). Пункт #13 открыт
целиком.

**Gap 12 — name-input мягче прода и без серверной границы.**
`screens.ts:401-403`: `maxlength="40"` (прод — 64, `NameScreen.tsx:40`), нет
`required`, нет `disabled` на пустом значении (прод — `:102`), и `applyAnswer`
не обрезает значение на сервере. Значение уходит в `fe_state` и в greeting
(`screens.ts:418-420`), т.е. риск — не безопасность, а мусор в подписанной
cookie и в пересохранённом квиз-результате.

---

## Открытые вопросы

**Бэкенд**
1. `check_email_provider`: ключ и величина rate limit (IP / email / глобально)?
   Из Worker'а/пода вызовы идут с одного адреса — Gap 1 без этого не
   спроектировать. (Открытый вопрос №5 спеки, всё ещё открыт.)
2. `POST /v1/users/link_for_auth` для пользователя **с** email и HRP-паролем —
   проходит? Пробник `diag.ts:57-66` дал только отказ для юзера без email
   (`400 89012`). Нужен прогон на свежем реальном адресе.
3. Какой путь реально отдаёт `link_for_auth` — `/sign-in` (пример в схеме) или
   `/autologin` (где живёт `signInWithCustomToken` и где подавляется
   анонимный вход)? Один curl.
4. `POST /v1/quiz-results` — обязательны ли `quiz_id` / `flow_id` /
   `entry_point`, и что делает бэкенд, когда платформа пересохраняет результат
   без них (Gap 9)?
5. Читается ли `selected_answer_id` кем-нибудь downstream, или `selected_options`
   достаточно (Gap 7)?
6. `GET /api/auth/whoami` (читает `__session` через firebase-admin, отдаёт
   `{uid, email, hrp, hasPremium}`) — можно? Это снимает и Gap 5, и зависимость
   от внутреннего поля SDK `stsTokenManager`.

**Security**
7. `FIREBASE_SERVICE_ACCOUNT_KEY` в секреты контейнера движка — да/нет. От
   этого зависят Gap 5 и Gap 10. Альтернатива — жить с 60-секундным TTL
   `link_for_auth` и минтить линк на клик.
8. Gap 4: согласны ли на сырой email в `localStorage` платформы как цену
   existing-email хэндоффа, или писать туда словарь **без** записи `s26`?
   Второе дешевле и ближе к проду (прод адрес в `UserAnswers` не кладёт).

**Продукт / аналитика**
9. Gap 2: `user_type` для сценария B — правим `withUserId` (тогда наши цифры
   сойдутся с продом) или фиксируем `unregistered` как инвариант движка?
10. Gap 6: при смене адреса посреди прогона — показывать «этот прогон уже
    привязан к `<адрес>`» (без попытки записи) или разрешать смену? Второе
    удваивает конверсию в Meta/TikTok.
11. Ветка копии по `providers` (A3/A5 — только соц-логин): делаем «Войдите через
    Google/Apple» и скрываем recover, или держим паритет с продом и оставляем
    одну строку на все состояния?
12. Gap 3: перевести копию ошибок — до или после ad spend на uk?
13. `subscription_status: 'free'` хардкодом на обеих сторонах — известный дефект
    или новость для аналитики? (Открытый вопрос №15 спеки.)
14. Gap 12: `maxlength` 40 против 64 — выравнивать по проду?

**Гигиена документов**
15. `gimli2-email-step-parity.md` и `gimli2-existing-user-spec.md` ссылаются на
    `src/index.ts:7xx–1xxx` и на `utils/email/setupCodeFunnelUser.ts`. Ни того,
    ни другого больше нет. Обновить ссылки, иначе следующий аудит начнётся с
    того же часа на переоткрытие файлов.
