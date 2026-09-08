# Аудит: онбординг-квиз прода (Gimli 2.0, `/kilo`) против `funnel-engine`

Сведено 2026-09-08. Прод — `/Users/uvarovalexandr/myProject/promova.com_monorepo`,
живой путь `/kilo/[funnel_id]/[[...screen_id]]`. Движок —
`/Users/uvarovalexandr/myProject/funnel-engine`.

Все `file:line` проверены по коду, а не по спекам. Где спека (`plans/gimli2-*.md`)
разошлась с кодом — это отмечено отдельно в §12.

---

## 0. Что вообще есть в проде

**Реестр — единственный источник истины:**
`packages/features/FunnelBuilder/code-funnels/funnelRegistry.ts:31-38`. Ровно
**6 живых воронок**, гейт роута — `isValidCodeFunnelId` (`:105`), больше нигде
ни флага, ни аллоулиста:

| id | экранов | типов экранов | локали квиза |
|---|---|---|---|
| `say-what-you-mean-2` | 20 (`say-what-you-mean-2/data.ts:462-483`) | 8 | **en only** (`locales/buildLocalizedData.ts:18` — `DICTIONARIES = {}`) |
| `say-what-you-mean-3` | 20 (`say-what-you-mean-3/data.ts:462-483`) | 8 | en, de, es, fr, it, pt |
| `general-english` | 32 (`general-english/data.ts:637-670`) | 10 | en, es, pt, de, fr, it (`general-english/locales/buildLocalizedData.ts:21-27`) |
| `general-english-b` | 32 | 10 | те же (общий `getGeneralEnglishSupportedLocales`) |
| `general-english-g` | 32 | 10 | те же |
| `english-hub` | **2** (`english-hub/data.ts:292` — `['landing','email']`) | 2 | en, de, es, **es-419**, fr, it, pt |

`general-english-b` и `-g` — побайтовые клоны `general-english`: `data.ts`
отличается одной строкой `salesPageSlug` (`general-english-b/data.ts:554`),
`index.ts` — слагом и `funnelId`, экраны — только строкой `InlineStyle id=`.

`_template/` — авторинг-скаффолд, **не зарегистрирован**, `/kilo/_template` 404-ит.
`test-funnel-money-04/` — мёртвый каталог с одним `.md`.
Общего enum типов экранов в прод-кодфаннелах **нет**: каждая воронка объявляет
свой discriminated union в своём `types.ts` и свою карту в `screenMapper.tsx`
(зафиксировано в `.claude/skills/quiz-funnel-factory/component-generation-code.md:10`).
Единственный общий контракт — `CodeFunnelEmailScreenData` (`code-funnels/types.ts:78-89`)
и `CodeFunnelScreenProps` (`:91+`).

**Движок:** `src/registry.ts:23-25` — `RAW = { 'general-english': generalEnglish }`.
**Одна воронка.** `SALES_RAW` (`:57-59`) одна, `THEMES` (`:95-97`) одна,
`CATALOGS` (`:86-88`) — `{ 'general-english': { uk } }`, `CHAINS` (`:126`) — `{}`.

---

## 1. Сводная таблица

### 1.1 Типы экранов онбординга

| item | прод (file:line) | funnel-engine (file:line / absent) | статус | note |
|---|---|---|---|---|
| `start-screen` (GE) | `general-english/types.ts:44-58` | `schema/quiz.schema.ts` `startScreen`; рендер `src/render/screens.ts:164-236` | **DONE** | trust-бар, тайлы-картинки, `otherLabel`, `disclosure`, `legal` — всё есть |
| `start-screen` (swym) | `say-what-you-mean-2/types.ts:50-64` | `startScreen` | **DONE** | `badges[]` (`RatingBadge`, `types.ts:43-48`) в схеме есть и рендерится (`screens.ts:189-201`); `prompt`→`question`, `personalizeNote`→`disclosure`, `options.male/female`→`tiles[]` (обобщение) |
| `goal-selector` | `general-english/types.ts:61-68` | `goalScreen`; `screens.ts:renderGoal` | **DONE** | |
| `choice` (GE) | `general-english/types.ts:71-88` | `choiceScreen` | **DONE** | `multiple`, `confirmWithCta`, `skip{label,answerKey}`, `skipText`, `layout: list\|grid`, `image`, `helperText`, per-answer `icon` — всё в схеме |
| `single-choice` (swym) | `say-what-you-mean-2/types.ts:66-86` | `choiceScreen` | **PARTIAL** | нет per-answer `reaction` (`types.ts:20-27` — присутствие `reaction` переключает экран с tap-to-advance на select-then-Continue); нет `stepNumber`/`stepTotal` |
| `multi-choice` (swym) | `say-what-you-mean-2/types.ts:88-98` | `choiceScreen{multiple:true}` | **PARTIAL** | нет `reassurance` (близко `helperText`); нет `stepNumber`/`stepTotal` |
| `agree-scale` | `general-english/types.ts:117-126` | `agreeScaleScreen`; `screens.ts:renderAgreeScale` | **DONE** | 7 экземпляров в GE |
| `value` | `general-english/types.ts:91-103` | `valueScreen` | **DONE** | `surface` больше не enum имён ассетов GE — `z.string().min(1).optional()` |
| `social-proof` | `general-english/types.ts:106-114` | `socialProofScreen` | **DONE** | |
| `info-screen` (swym) | `say-what-you-mean-2/types.ts:100-129` | `statementScreen` | **PARTIAL** | `stat.footnote` в проде вложен в `stat`, в движке — сосед `footnote`; `bars` в проде `{label}` (высота по индексу), в движке обязателен `pct: 0-100` — автору приходится выдумывать числа |
| `loader` (GE) | `general-english/types.ts:137-149`; рантайм `FunnelContext.tsx:1455-1481` | `loaderScreen`; `screens.ts:525-608` | **PARTIAL** | см. §5 — механика рампы расходится |
| `loader` (swym) | `say-what-you-mean-3/screens/LoaderScreen.tsx:20-40` | `loaderScreen` | **PARTIAL** | прод — чек-лист `steps[]` (спиннер→✓), движок только `stages[]` (одна ротирующаяся строка); у swym-гейта есть `body` |
| `email` | `code-funnels/types.ts:78-89` (4 поля) | `emailScreen` | **DONE+** | движок богаче: `privacyNote{lead,linkLabel,linkHref,tail}`, `errors{...}`, `consentNote` — в проде это захардкожено в компоненте |
| `name-input` | `general-english/types.ts:164-171` | `nameScreen` | **DONE** | |
| `results` (GE) | `general-english/types.ts:173-188`; `screens/ResultsScreen.tsx` | `resultsScreen` | **DONE** | `{name}`-приветствие (`screens.ts:420`), декоративный слайдер, `rows[].valueMap+fallback` |
| `results` (swym, **4 варианта**) | `say-what-you-mean-2/types.ts:198-223`; данные `data.ts:408-457`; селектор `screens/ResultsScreen.tsx:43-63` | **absent** | **MISSING** | 4 варианта `work/interviews/social/everyday`, каждый `{title,focus[],heroMoment,proof}`; + 3 карты `*Labels: Record<answerKey,string>` |
| `profile` (swym s15b) | `say-what-you-mean-2/types.ts:144-189`; `screens/ProfileScreen.tsx:86-103` | **absent** (частично ≈ `resultsScreen`) | **MISSING** | `track.nowByConfidence: Record<answerKey,{value,percent}>` (карта в **объект**, не в строку), `focus.byGoal`, `paceChipLabel`/`paceQuestionKey`, реестр inline-SVG глифов |
| `landing` (english-hub) | `english-hub/types.ts:18-83` | **absent** | **MISSING** | ~30 полей: `mediaGallery`, `stats`, `languages[{flag,name}]`, `forYouIf[]`, `confidenceStat`, `insideTheHub[]`, `featureTiles`, `guarantee`, `communityPosts[]`, `reviews`, `faq`, `badges`, `finePrint`, `progressPromise`, `bottomCta`. Фактически sales-page, а не экран |
| `target-language` / `native-language` | `_template/types.ts:143-159`; `_template/screens/TargetLanguageScreen.tsx`; каталог `code-funnels/languages/languageCatalog.ts`; фильтр `hooks/useLanguagePairs.ts` | **absent** | **MISSING (0 прод-потребителей)** | все 6 воронок — `courseSource: 'none'` (`general-english/index.ts:63`, `say-what-you-mean-2/index.ts:65`, `english-hub/index.ts:40`). `FunnelContext.test.tsx:1707`: «No shipped funnel currently declares courseSource: 'target-language'» |
| `profile-summary` | `_template/types.ts:166-171` | ≈ `resultsScreen` | **DONE-ish** | шаблонный, 0 потребителей |
| `statement` (тип движка) | нет прод-аналога под этим именем | `quiz.schema.ts` `statementScreen`; `screens.ts:622+` | n/a | ближайший прод-аналог — swym `info-screen`; в `funnels/general-english/config.json` — 0 экземпляров |
| числовые инпуты (age/height/weight) | **нет нигде.** Возраст — `choice` с диапазонами (`general-english/data.ts:650` `ft20_age`) | n/a | **DONE (нечего портировать)** | свободный ввод только `name-input` и `email` |
| мультиселект с картинками | **нет.** Опции несут только emoji-`icon` (`general-english/types.ts:27-31`) | n/a | **DONE (нечего портировать)** | реальные картинки только на `start-screen` тайлах (single-select) и опциональный верхний `image` у swym `single-choice` |
| интерактивный слайдер | **нет.** Только декоративный Now→goal трек на `results` (`general-english/screens/ResultsScreen.tsx:59-65`) | `resultsScreen.sliderStart/sliderEnd` | **DONE** | |
| отдельный экран-тестимониал | **нет.** Отзывы вкраплены в `social-proof`, `loader`, `landing` | n/a | **DONE** | |
| прогресс-бар | пер-воронка, **не рантайм**: `general-english/components/ProgressHeader.tsx` от `data.step` + `QUIZ_STEPS_TOTAL = 26` (`data.ts:29`); swym — инлайн `NN/15` от `stepNumber`/`stepTotal` | `engine.ts:progressPercent` = `index/flow.length` | **PARTIAL** | у движка знаменатель = длина `flow` (32), у прода — число экранов **с вопросом** (26 в GE, 15 в swym). Нет ни `progressTotal`, ни `stepNumber`. `_template/components/ProgressBar.tsx:26-32` прямо предупреждает про эту ошибку |

**Итог по типам:** прод — 14 различающихся литералов `type` в 6 живых воронках
(+3 только в `_template`). Движок — 11: `start-screen`, `goal-selector`,
`choice`, `agree-scale`, `value`, `social-proof`, `name-input`, `results`,
`statement`, `loader`, `email` (`schema/quiz.schema.ts` `screenSchema`).
Закрыто: 11 из 14. Не закрыто: swym `results` (варианты), swym `profile`,
english-hub `landing`. Плюс частичные дыры внутри закрытых типов (см. `reaction`,
`steps[]`, `stepNumber/stepTotal`, `bars.pct`).

### 1.2 Ветвление и условная логика

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| декларативный роутинг | контракт `code-funnels/types.ts:354-356` (`getNextScreenId`), рантайм `FunnelContext.tsx:808-846` | `schema/quiz.schema.ts` `transitionSchema` + `src/engine.ts:resolveNext` | **DONE+** | **все 6 прод-воронок строго линейны**, `getNextScreenId` не объявляет ни одна (`say-what-you-mean-2/index.ts:29-31` — прямая мотивировка отказа). У движка в `config.json` тоже 0 `next` |
| loop-back | запрещён структурно (`FunnelContext.tsx:841-843` — уже посещённый id отвергается) | `engine.ts:resolveNext` не запрещает, но `flow.includes` + линейный фолбэк | **DONE (не нужно)** | |
| лестница правил (AND/OR, first-match, default) | `say-what-you-mean-3/screens/ResultsScreen.tsx:45-64` `pickVariantKey` | `$rules` (`quiz.schema.ts` `rulesSchema`), исполнение `src/resolve.ts:98-112` | **DONE** | `all`/`any` из атомов, обязательный `default` (`superRefine`), first-match |
| атом по `questionKey` | `cf/utils/findAnswerByQuestionKey.ts:13-17` | `src/resolve.ts:answerIndex` (`:150-161`) — индекс по `questionKey` | **DONE** | |
| `map[answerKey] ?? fallback` | `say-what-you-mean-3/screens/ProfileScreen.tsx:86-103` | `$byAnswer` (`quiz.schema.ts` `byAnswerSchema`), `resolve.ts:71-84` | **DONE** | `fallback` обязателен |
| «выкинуть строку без ответа» | `ProfileScreen.tsx:88` (`.filter(r => Boolean(r.value))`) | `$byAnswer.dropIfMissing` + `DROP`-сентинел (`resolve.ts:66,113-133`) | **DONE** | |
| `count(answers)` | `general-english/screens/ResultsScreen.tsx:32-45` (`Object.keys(answers).length`) | **absent** | **MISSING** | |
| интерполяция `{n}` | `general-english/screens/ResultsScreen.tsx` | **absent** | **MISSING** | у движка только `{name}` (`screens.ts:420`) и `{time}` (`screens.ts:350-354`); общего механизма нет |
| карта в **объект**, а не в строку | `ProfileScreen.tsx` `track.nowByConfidence[key] → {value,percent}` | **absent** | **MISSING** | `$byAnswer.map` — `Record<string,string>`, `$rules[].value` — `string`. Объектные значения невыразимы (`quiz.schema.ts` `byAnswerSchema`/`rulesSchema`) |
| geo-гейт копии | `general-english/geoCompliance.ts:6-7` + `FTC_COUNTRIES` (`packages/config/types/countries.ts:42-55`, 11 кодов); 4 поля на 4 экранах (`data.ts:37-57`) | `variants["country:compliance"]` (`quiz.schema.ts` `COUNTRY_SETS.compliance` — те же 11 кодов); данные `funnels/general-english/config.json:915-940` | **DONE+** | движок патчит **любое** поле любого экрана, прод — 4 захардкоженных поля. Резолв server-side из `cf-ipcountry` → нет флэша неправильной легалки |
| geo-роутинг воронки | `geo/countryFunnelRules.ts:73` — `= {}`, «EMPTY ON PURPOSE»; резолвер `geo/resolveCodeCountryFunnelId.ts` | **absent** | **MISSING (0 прод-потребителей)** | ни одна воронка не имеет правил; роут это подтверждает (`page.tsx:123-124`) |
| `adTopic`-оверрайд + reorder опций | `general-english/types.ts:57,67` `adTopicVariants`; `screens/StartScreen.tsx:42-45`, `GoalScreen.tsx:25-39` | ось `adTopic:<topic>` в `variants` (`quiz.schema.ts` `AXIS_KEY`), `resolve.ts:activeVariantKeys` | **DONE** | reorder выражается заменой всего массива `answers` в варианте (shallow-merge поля, `resolve.ts:177-182`). В проде `adTopicVariants` заполнены у **нуля** воронок (`general-english/data.ts:81,96` — комментарии-плейсхолдеры) |
| ось флага | нет (см. §8) | ось `flag:<name>` + `quiz.flags` map (`quiz.schema.ts`), `growthbook.ts:activeFlags` | **DONE+** | у прода такого механизма нет вообще |
| `evalCondition` для `next[]` | n/a | `src/engine.ts:23-63` | **PARTIAL (латентно)** | `answer == 'key'` смотрит только на **текущий** экран, `has('s3','key')` ключуется по **screen id**, а прод-семантика — по `questionKey`. Сегодня безразлично: 0 ветвлений с обеих сторон |
| скоринг | нет ни в одной воронке | `answerSchema.score` + `engine.ts:applyAnswer` | n/a | функция движка без прод-потребителя |

### 1.3 Прогресс, resume, back

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| где живёт позиция | сегмент URL: `/kilo/<id>/<screenId>` (`apps/student/app/[lang]/(code-funnel)/kilo/[funnel_id]/[[...screen_id]]/page.tsx`) | query `?screen=N` (индекс во `flow`), `routes/quiz.ts:screenUrl` (~:396-405) | **PARTIAL** | у движка нет deep-link по id экрана |
| где живут ответы | `localStorage['funnel_builder_user_answers']`, **один глобальный ключ**, без TTL (`utils/funnelsAPI.ts:147-181`) | подписанная HttpOnly кука `fe_state`, `Path=/`, `Max-Age=86400` (`src/state.ts:buildStateCookie`) | **PARTIAL** | разные носители → разные правила жизни (ниже) |
| сброс на входе | wipe `FUNNEL_BUILDER_USER_ANSWERS` на первом экране, раз за sessionStorage-сессию, с multi-tab гардом по `funnel_active_at` (`FunnelContext.tsx:705-770`, `MULTI_TAB_ACTIVE_THRESHOLD_MS`) | `canResume` (`state.ts:397-410`): новый click-fingerprint → fresh, `>4h` → fresh, нет `cur` → fresh | **PARTIAL** | правила пересекаются лишь частично |
| **новая вкладка** | **fresh run** — sessionStorage-флага нет → ответы вытираются на старт-экране | **resume** — кука общая на браузер, `state.cur` восстанавливается (`routes/quiz.ts` GET-хендлер) | **MISSING / противоположное** | прямое расхождение поведения |
| **через 24 ч** | resume, если URL несёт `screenId` (localStorage без TTL) | всегда fresh: `Max-Age=86400` + `MAX_RESUME_AGE_SECONDS = 4*3600` (`state.ts:392`) | **PARTIAL** | окно движка — 4 часа, прода — бесконечное |
| новый рекламный клик | правила нет | fresh run по `entryFingerprint` (`state.ts:ENTRY_PARAMS`, `:canResume`) | **DONE+** | движок корректнее для платного трафика |
| back-кнопка браузера | нативная навигация между URL экранов (`router.push`) | `history.replaceState`/`pushState` от `X-Screen-Url` + `popstate → location.reload()` (`render/layout.ts:613-621`, `routes/quiz.ts` заголовок `X-Screen-Url`) | **DONE** | работает; комментарий в `render/screens.ts:146-155` («browser back therefore leaves the funnel») **устарел** |
| явная кнопка Back | `FunnelContext.tsx:1375-1382` (`goBack`, walk по visited) | `POST /kilo/:id/back` + `engine.ts:previousScreen` | **DONE** | |
| forward-кнопка | нативно | high-water mark `state.far` (`state.ts`), клэмп в GET-хендлере | **DONE** | |
| deep-link на середину | `/kilo/<id>/s12` работает для любого; валидация только по членству во `flow` (`page.tsx:162-166`) | `?screen=12` разрешён только `<= far`, иначе клэмп к `resumeScreen` | **PARTIAL** | сознательное расхождение (защита данных воронки), но прод-ссылки не воспроизводятся |
| потолок носителя | нет | **3800 байт** (`state.ts:MAX_COOKIE_BYTES`); превышение → `console.error`, resume теряется, форма продолжает работать | **риск** | 32 экрана GE влезают; более длинная воронка — нет |

### 1.4 Funnel Core / формат ответов и эндпоинт

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| эндпоинт записи | `POST /v1/quiz-results/` (`packages/api/testResults` через `utils/saveTestResults.ts:53`), `not_update_profile` | `src/platform.ts:createTestResult` — `/v1/quiz-results/?not_update_profile=false` | **DONE** | |
| когда пишется | на экране лоадера (`useSaveTestResult`, монтируется только в `<LoaderSideEffects>`, `FunnelContext.tsx:1386-1391`) | `POST /kilo/:id/prepare?full=1` (`routes/quiz.ts` ~:437-500), гард по `state.qrid` | **DONE** | идемпотентность у движка строже |
| `question_id` = `questionKey` | `packages/utils/formatAnswersForBE.ts:24` (`if (item?.questionKey) answer.question_id = item.questionKey`) | `src/engine.ts:buildQuizResult` | **DONE** | |
| `id` = runtime screen id | `formatAnswersForBE.ts:13` | `buildQuizResult` — `id: screenId` | **DONE** | |
| **`selected_options`** | **тексты опций** (`formatAnswersForBE.ts:16` ← `selectedAnswers`; `general-english/screens/ChoiceScreen.tsx:46` — `selectedAnswers: titles`) | **answerKeys** (`engine.ts:buildQuizResult` — `selected_options: answerKeys`) | **MISSING** | **см. Разрыв G1** |
| **`selected_answer_id`** | answerKeys (`formatAnswersForBE.ts:20-23` ← `selectedAnswerIds`) | **absent** | **MISSING** | **см. Разрыв G1** |
| разделение `survey` / `language_test` | по `category === 'grammar'` (`formatAnswersForBE.ts:27-31`) | `buildQuizResult` — всегда пустой `language_test` | **DONE** | воронка не задаёт грамматику; пустой ≠ отсутствующий |
| `funnelCoreParams` gap-fill | `useSaveTestResult.ts:128-133` (lowest precedence) | `engine.ts:buildAnswerPayload` + `buildQuizResult` (константы не перебивают реальный ответ) | **DONE** | |
| **синтетический `user_language_level`** | всегда добавляется (`useSaveTestResult.ts:71-84`; ключ `user_language_level`, `packages/config/constants/common.ts:238`); fallback `A1` | **absent** в payload (только `actual_level` в аналитике, `engine.ts:resolveActualLevel`) | **MISSING** | **см. Разрыв G2** |
| фильтр пустых ответов | `utils/email/cleanSelectedAnswers.ts` — выкидывает записи с пустым `selectedAnswers` и стрипает HTML-теги | **absent** | **MISSING** | **см. Разрыв G3** |
| псевдо-ответы `ack`/`done` | **нет**: `value`/`social-proof`/`results` зовут только `onNext` (`general-english/screens/ValueScreen.tsx:91`, `SocialProofScreen.tsx:66`, `ResultsScreen.tsx:99`) | `render/screens.ts:366,387,452,508` (`answer=ack`), `:581` (`answer=done`) → `engine.ts:applyAnswer` пишет в `state.answers` | **MISSING** | **см. Разрыв G4** |
| ключи ответа гейта лоадера | `selectedAnswers: [option]` + `selectedAnswerKeys: [option.toLowerCase()]` (`general-english/screens/LoaderScreen.tsx:52-59`) | сырая строка опции как единственный ключ (`routes/quiz.ts`, цикл `gate_`) | **PARTIAL** | нет lowercase-ключа |
| `retenoUserProperty` | плюмбинг `FunnelContext.tsx`, enum одно значение `funnels_time_to_study` (`types/screens.ts:135-137`); **ни одна живая воронка не проставляет** | `baseScreen.retenoUserProperty` + `engine.ts:buildRetenoProperties` (спец-кейс `"HH:00"`) | **DONE** | |
| `quiz_result_id` дальше в чекаут | да | `state.qrid` → `routes/sales.ts` | **DONE** | |
| `time_location` | `Intl.DateTimeFormat().resolvedOptions().timeZone` в браузере (`saveTestResults.ts:57`) | скрытое поле `#tz-field` (`render/screens.ts:132-141`), shape-check `^[A-Za-z]+/...$` (`routes/quiz.ts`) | **DONE** | |
| `entry_url` | `localStorage['entry_url']` (`saveTestResults.ts:38-46`). На пути `/kilo` этот ключ, судя по грепу, **никем не пишется** (пишется только Sales v2 под другим литералом, `pages/Sales/v2/hooks/useLocalStorageSync.ts:22`) → в проде поле фактически отсутствует | синтетический `${origin}/kilo/${id}` **без query** (`routes/quiz.ts`) | **DONE+ / расхождение** | движок отдаёт больше, но теряет query первого касания |
| `collected_at_user_side` | `saveTestResults.ts:48-50` | **absent** | **MISSING (низкий приоритет)** | зависит от того же незаписываемого ключа |
| `quiz_id` / `flow_id` / `entry_point` | читаются из записи ответов (`saveTestResults.ts:22-25`) → на `/kilo` резолвятся в `undefined` | реальные значения (`quiz.id`, `state.attr.source`) | **DONE+** | движок богаче |
| формат для `/echo` hand-off (localStorage платформы) | `funnelsAPI.getLocalAnswers('funnel_builder_user_answers')` | `engine.ts:buildPlatformAnswers` | **PARTIAL** | наследует G1 и G4: пишет `selectedAnswers: answerKeys` вместо тайтлов, не пишет `selectedAnswerIds`, не пишет `tag` |
| `check_email_provider` | `mainHttpClientWithoutMiddleware` | `platform.ts:checkEmailProvider` | **DONE** | |
| marketing consent | `PUT /v1/profiles/notifications` (`hooks/useCodeFunnelEmail.ts:281-287`) | `platform.ts:setEmailNotifications`; `shown → выбор, hidden → implicit true` | **DONE** | |
| HRP | `PUT /v1/users/funnel_register_flow` | `platform.ts:setHrpFlag` | **DONE** | |
| Reteno slug / event / props | `setupUserProfileData.ts:19`, `retenoAnalytics.ts:19,41-49` | `platform.ts:setRetenoSlugProperty` / `sendRetenoEvent` / `sendRetenoUserProperties` | **DONE** | |

### 1.5 Лоадер

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| владелец рампы | **рантайм**, не экран (`FunnelContext.tsx:1455-1481`); экран рисует только `progress` (`general-english/screens/LoaderScreen.tsx:24-27` — «NO local timer, NO onNext, NO save/analytics here») | клиент, Alpine `x-data` в самом экране (`render/screens.ts:525-608`) | **PARTIAL** | архитектурное расхождение с последствиями ниже |
| тайминги | `LOADER_RAMP_MS=3000`, `LOADER_TICK_MS=100`, `LOADER_RAMP_CAP=90`, `LOADER_MAX_WAIT_MS=6000`, `LOADER_REDIRECT_DELAY_MS=600` (`FunnelContext.tsx:81-88`) | `minDurationMs` (default 3000), tick = `max(20, minDurationMs/50)` = 60 мс (`screens.ts:526`), рампа **0→100** | **PARTIAL** | нет `CAP=90`, нет force-таймаута, нет 600 мс задержки перед переходом |
| **ожидание записи** | рампа встаёт на 90 % и не завершается, пока `isTestResultSaved` (или 6 с форс) (`FunnelContext.tsx:1543`) | рампа доходит до 100 % и сабмитит **независимо** от `/prepare` | **MISSING** | **см. Разрыв G5** |
| `forced` | `isForced = !isTestResultSaved` (`FunnelContext.tsx:1668`), уходит в оба события | **захардкожен `false`** (`routes/quiz.ts` ~:1108-1113) | **MISSING** | сигнал неподтверждённой записи невозможен |
| гейты | `loaderGates?: readonly number[]` на модуле (`code-funnels/types.ts:262`), `awaitingGate` выставляется только когда рампа реально дошла до стопа (`FunnelContext.tsx:1495-1504`) | `loaderScreen.gates[{atProgress,questionId,question,options}]`, пауза в Alpine, ответ едет в том же сабмите | **DONE** | GE: 2 гейта 35 %/70 % (`general-english/data.ts:512-547` / `funnels/general-english/config.json:805-826`) |
| стадии | GE: 4 ротирующиеся `stages`; swym: 3 чек-лист `steps[]` (спиннер→✓) | только `stages[]` | **PARTIAL** | swym-стиль невыразим |
| geo-A/B карточки отзыва | `LoaderScreen.tsx:39-45,88-112` — `isComplianceGeo(country)` → атрибутированный App Store отзыв vs нейтральная строка | `review` в `variants["country:compliance"]` + базовый `reviewNeutral`; рендер `screens.ts:594-607` | **DONE** | |
| `funnels_loader_viewed` | `FunnelContext.tsx:1394-1404`, ref-гард | `EVENTS.LOADER_VIEWED` при переходе на лоадер (`routes/quiz.ts` ~:1175-1180) | **DONE** | |
| пара `test_level_completed` + `test_completed` | `FunnelContext.tsx:1693-1694`, идентичный payload (`:1682-1692`) | `routes/quiz.ts` ~:1140-1160 | **DONE** | |
| payload пары | `domain, funnel_name, screen_name, source, actual_level, localization, ab_arm, forced` | + **`answers: buildAnswerPayload(...)`** | **DONE+ / расхождение** | это и есть источник 17.9 KB миррора; в проде поля нет |
| `FUNNEL_CORE_GUARANTEE_VIOLATED` на лоадере | 3 бэкстопа: `levelSource`-роль (`:1580-1606`), `courseSource: 'target-language'` (`:1608-1630`), `funnel_core` с исключением `user_level` (`:1632-1660`) | только `funnel_core` (`engine.ts:missingCoreKeys` → `routes/quiz.ts` ~:1163-1173) | **PARTIAL** | роли `level`/`language` не объявляет ни одна живая воронка → сегодня не стреляет |
| один лоадер на воронку | `loaderScreenId` — одно значение | `quiz.schema.ts` `superRefine` — «exactly one loader screen is supported» | **DONE** | |

### 1.6 Локали

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| локали `general-english` | en, es, pt, de, fr, it (`general-english/locales/buildLocalizedData.ts:21-27`) | **en + uk** (`src/registry.ts:88`) | **MISSING** | движок несёт локаль, которой у прода нет, и не несёт ни одной из пяти прод-локалей |
| механизм | deep-partial TS-оверлей, merge по позиции/id на сборке модуля (`localization/deepMergeOverlay.ts:57-107`) | каталог, ключуемый **исходной английской строкой** (`src/i18n.ts`), `translateTree` на локаль + кэш | **DONE+** | движок ловит устаревшую пару «правка EN → старый перевод» (`i18n.ts:catalogOrphans`); оверлей прода — нет |
| downgrade (локаль без каталога) | клиентский компонент `CodeFunnelRenderer.tsx:180-190` → `redirect` на дефолт с сохранением query | server-side `registry.ts:servedLocale` + `supportedLocales` — до первого байта | **DONE+** | у прода флэш английской страницы под локализованным URL |
| upgrade по `Accept-Language` | `localization/redirectCodeFunnelToBrowserLocale.ts:115-165`: **только с дефолтной локали**, **только на входном экране**, редирект 307 с переносом query | `src/locale.ts:negotiateLocale` — негоциация без редиректа, префикс проставляется во все ссылки, адресная строка правится boot-скриптом | **DONE+** | у движка нет round trip перед первым байтом |
| разбор `Accept-Language` | `getSupportedBrowserLanguage.ts` — берёт **первый** тег, первые 2 символа, **q-веса игнорирует** | `locale.ts:acceptedTags` — сортировка по `q`, отбрасывание `q=0` и `*`; `candidates` с таблицей `LATAM_SPANISH` под `es-419` | **DONE+ / расхождение** | `de;q=0.1,en;q=0.9`: прод выберет `de`, движок — `en` |
| `?lang=<locale>` оверрайд | `pages/Onboarding/utils/shouldConsiderBrowserLocaleRedirect.ts:6-33` — query-локаль бьёт `Accept-Language` | **absent** (грепом по `src/` — 0 совпадений) | **MISSING** | |
| набор распознаваемых префиксов | `LOCALES` из `@promova/config` | `locale.ts:LOCALES` — те же 14 кодов | **DONE** | |
| `/en/...` → 301 на бесprefix | `handleLocalizationMiddleware.ts` | `src/index.ts` + `locale.ts` (документировано в шапке `locale.ts`) | **DONE** | |
| пиннинг легалки к английскому | компоненты FTC/ROSCA не обёрнуты в `<Trans>`; `buildLocalizedMoneyCopy.ts:17-23` | `i18n.ts:PINNED_ENGLISH` | **DONE** | у english-hub прод сам себе противоречит (`money/english-hub/locales/de.ts:25-29` переводит `ftcNoPaymentNote`) — движок здесь строже |

### 1.7 Мульти-воронка

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| число воронок | 6 (`funnelRegistry.ts:31-38`) | **1** (`src/registry.ts:23-25`) | **PARTIAL** | не перенесены: `general-english-b`, `general-english-g` (тривиально — отличаются только слагом), `say-what-you-mean-2`, `say-what-you-mean-3`, `english-hub` |
| стоимость добавления | одна строка в **двух** картах (`codeFunnelModuleLoaders` + `codeFunnelEntries`), несоответствие ключей = ошибка компиляции | одна строка в `RAW` + `config.json` | **DONE+** | |
| code-splitting на воронку | `next/dynamic` per funnel (`funnelRegistry.ts:53-92`), мотивировка `:11-18` | не нужно — сервер-рендер | n/a | |
| темы на воронку | `funnelThemeBg.ts:85-125` (все 6) | `THEMES` (`registry.ts:95-97`), `schema/theme.schema.ts` 24 токена | **DONE** | |
| sales-страницы | `money/moneyRegistry.ts:19-26` — у всех 6 | `SALES_RAW` — одна | **PARTIAL** | |
| post-purchase цепочки | есть контракт | `CHAINS = {}` (`registry.ts:126`) — ни одной | **PARTIAL** | механизм собран, данных нет |
| публикация без деплоя | Strapi-режим — да; code-режим — нет (деплой) | нет: конфиги вбандлены в `dist/` | **DONE (паритет)** | сознательно, чтобы не обойти `pnpm validate` |

### 1.8 GrowthBook

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| флаги, которые читает quiz-сторона | **ровно два, и оба один**: `compliance_config_promova` + подключ `use_marketing_consent` (`hooks/useCodeFunnelEmail.ts:139-143`; литералы `packages/config/constants/remote_config.ts:3-4`) | `growthbook.ts:marketingConsentRequired` (тот же ключ и та же семантика `!!`) | **DONE** | |
| `code-funnel-<id>-arm` | `utils/resolveCodeFunnelArm.ts:38` — **PARKED, 0 call-site** | n/a | **DONE (не нужно)** | единственный call-site закомментирован в `apps/funnels/chameleon/.../foxtrot/[funnel_id]/page.tsx:47-63` |
| A/B-сплит на `/kilo` | **нет вообще**; `resolveSplitTestFunnelId` — только Strapi-режим | n/a | **DONE** | сплит делается клонированием воронки + рекламной ссылкой |
| per-screen / per-copy флаги | **нет ни одного** | ось `flag:<name>` + `quiz.flags` (`quiz.schema.ts`), `growthbook.ts:activeFlags` | **DONE+** | opt-in: воронка без `flags` не платит за eval (`routes/quiz.ts` ~:320-337) |
| атрибут `funnel_id` | `useSetFunnelIdGrowthBook(funnelId)` (`FunnelContext.tsx:338`) — раньше не ставился вовсе, из-за чего `funnel_id`-таргетинг молча не стрелял | `growthbook.ts` — `funnel_id` условно (только если задан) | **DONE** | |
| атрибуты | `useAddGrowthBookAttributes`: `custom_user_id`, `country`, `utm_source`, `device`, `platform`, `device_id`, `funnel_id`, `localization` | `growthbook.ts:evaluateFeatures` — тот же набор; `custom_user_id` = Firebase uid, пусто до email-экрана (как в проде) | **DONE** | |
| транспорт | браузерный SDK, `remoteEval: true` | server-side `POST /api/eval/{clientKey}` из воркера | **DONE+** | нет флэша неправильного плеча |
| кэш | n/a | per-isolate, TTL 5 мин, ключ **без** `device_id`/`custom_user_id` (`growthbook.ts:88-100`) | **риск** | процентный роллаут резолвится на когорту, а не на визитёра — задокументировано в самом файле |
| FTC-флаги | `us_pricing_now_then`, `ftc_soft_changes` (money-сторона) | `growthbook.ts:ftcPricing` — порт `useFtcPricing`, включая «при обоих true → soft» | **DONE** | по `plans/gimli2-full-migration-plan.md` §3.2 флаги **false для всех стран**, т.е. ось на живых флагах не проверена |

### 1.9 Авторизованный / уже подписанный визитёр

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| детекция | `selectIsUnregisteredUser` из auth-store (`FunnelContext.tsx:324`) — читает `auth.currentUser.isAnonymous` | кука `withAuth=true` (`src/http.ts:233-237`) | **DONE** | движок: `signedInOnPlatform`; кука не HttpOnly, ставится платформой на каждом non-anonymous auth-событии |
| где используется | **только** `user_type` на `funnels_page_viewed` и `funnels_started_funnel` (`FunnelContext.tsx:923,960`) | **только** `user_type` (`http.ts:195`) | **DONE** | тесты: `tests/session.test.ts:25-49` |
| редирект подписанного/вошедшего | **нет.** Единственный `redirect()` на пути `/kilo` — locale downgrade (`CodeFunnelRenderer.tsx:186`) | нет | **DONE (паритет)** | |
| существующий email на email-экране | `useCodeFunnelEmail` → предложить sign-in, hand-off на `/echo` | `routes/quiz.ts:respondEmailStep` → `alreadyRegistered` → `deny(screen.errors.exists, true)` + `buildSignInUrl`/`buildPasswordRecoverUrl`; `engine.ts:buildPlatformAnswers` кладёт ответы в формат платформы перед hand-off | **DONE** | закрыт реальный дефект прода (пустой результат под вошедшим юзером) |
| природа сигнала | серверная auth-state | **подделываемая кука**, и работает только когда движок за route split на том же домене | **риск** | в самом файле помечено «hint, never an authority» (`http.ts:218-224`) |

### 1.10 SEO / meta / ошибки

| item | прод (file:line) | funnel-engine (file:line) | статус | note |
|---|---|---|---|---|
| robots | `metadata = { robots: { index: false, follow: false } }` (`apps/student/.../kilo/.../page.tsx:22-24` и зеркало в chameleon) | `<meta name="robots" content="noindex">` (`render/layout.ts:448`) | **PARTIAL** | нет `nofollow` |
| canonical / hreflang | **нет** | `canonical` + `alternate hreflang` + `x-default` (`render/layout.ts:358-384`) | **DONE+** | сознательно: мотивировка в `layout.ts:358-364` |
| OG / Twitter meta | нет | нет | **DONE (паритет)** | |
| `<title>` | из layout приложения | `quiz.tracking.funnelName` (`routes/quiz.ts:wrap`) | **DONE** | |
| 404 на неизвестный funnel id | реальный HTTP 404 через `notFound()` **до стриминга** (`page.tsx:79`; мотивировка `:68-77`); шелл `apps/student/app/[lang]/(code-funnel)/not-found.tsx` | `app.notFound` → `renderError('Funnel not found.', '/')`, 404 (`src/index.ts:38`) | **DONE** | |
| 404 на лишние сегменты пути | `page.tsx:88` (`screenIdSegments.length > 1`) | n/a (позиция в query) | n/a | |
| **404 на неизвестный screen id** | `page.tsx:162-166` — валидация против `flow` резолвнутой воронки | **нет**: `?screen=abc`/`?screen=99` молча отдают `flow[0]` или клэмпятся (`routes/quiz.ts` GET-хендлер) | **MISSING** | сознательный компромисс («не терять прогресс из-за опечатки»), но soft-404, который прод специально закрывал |
| error boundary | per-screen `CodegenErrorBoundary` (`CodeFunnelRenderer.tsx:113`); `resolveScreenComponent.tsx:25-43` — fallback-«continue» вместо краша; chameleon `error.tsx` | `app.onError` (`src/index.ts:40`); `renderScreen` → `<h1>Screen not found</h1>` (`screens.ts:721`); `renderError` с «Start over» | **DONE** | |
| locale-fallback на 404 | нет | `src/index.ts:100-153` — путь, который уже 404-нул, переспрашивается без locale-префикса | **DONE+** | |

---

## 2. Разрывы (Gaps) с доказательствами

### G1 — `selected_options` несёт не то, что в проде, и `selected_answer_id` не отправляется вовсе
**Severity: высокая. Это контракт с бэкендом/CRM/аналитикой.**

Прод, `packages/utils/formatAnswersForBE.ts:12-25`:
```ts
const answer = {
  id: item.questionId,
  question_id: item.questionId,
  question_text: item.questionText,
  selected_options: item.selectedAnswers,      // ← ТЕКСТЫ опций
}
if (item?.selectedAnswerIds) {
  answer.selected_answer_id = Array.isArray(item.selectedAnswerIds)
    ? item.selectedAnswerIds : [item.selectedAnswerIds]   // ← answerKeys
}
```
Что кладут экраны — `general-english/screens/ChoiceScreen.tsx:42-50`:
```ts
selectedAnswers: titles,
selectedAnswerKeys: titles.map(t => data.answers.find(a => a.title === t)?.answerKey)...
```
(персистится как `selectedAnswerIds` — прямо задокументировано в
`code-funnels/types.ts:26-36`).

Движок, `src/engine.ts:buildQuizResult`:
```ts
survey.push({
  id: screenId,
  question_id: screen.questionKey ?? screenId,
  question_text: questionText(screen, screenId, answerFor),
  selected_options: answerKeys,   // ← КЛЮЧИ, не тексты
})
```
`selected_answer_id` отсутствует. То же в `engine.ts:buildPlatformAnswers`
(`selectedAnswers: answerKeys`, нет `selectedAnswerIds`) — значит и hand-off на
`/echo` уезжает в чужом формате.

Последствие: любой потребитель, читающий `selected_options` как человекочитаемый
ответ, получит `goal_work` вместо «Work and career», а потребитель
`selected_answer_id` не получит ничего.

### G2 — синтетический `user_language_level` не отправляется
Прод добавляет его **всегда**, `packages/features/FunnelBuilder/hooks/useSaveTestResult.ts:71-84`:
```ts
[USER_LEVEL_QUESTION_ID]: {
  category: 'survey', questionId: USER_LEVEL_QUESTION_ID, questionText: '',
  selectedAnswers: [englishTestLevel || vocabularyResult?.level || DEFAULT_LEVEL],
}
```
`USER_LEVEL_QUESTION_ID = 'user_language_level'` (`packages/config/constants/common.ts:238`),
`DEFAULT_LEVEL = 'A1'`. Именно поэтому `FunnelContext.tsx:1641-1645` **исключает**
`user_level` из проверки Funnel Core: лоадер его всегда пишет.

В движке уровень вычисляется (`engine.ts:resolveActualLevel`, fallback `'A1'`) и
уходит только в `actual_level` аналитического события. В payload
`/v1/quiz-results/` записи `user_language_level` нет.

### G3 — нет фильтра пустых ответов и стрипа HTML
`packages/features/FunnelBuilder/utils/email/cleanSelectedAnswers.ts` перед
отправкой выкидывает каждую запись с пустым `selectedAnswers` и прогоняет
значения через `removeHtmlTags`. В движке эквивалента нет: `engine.ts:applyAnswer`
пишет `answerKeys` как есть, включая `[]`.

### G4 — псевдо-ответы `ack` / `done` протекают в payload бэкенда
Прод: `value`, `social-proof`, `results` зовут **только** `onNext` и не пишут
ничего (`general-english/screens/ValueScreen.tsx:91`, `SocialProofScreen.tsx:66`,
`ResultsScreen.tsx:99`).

Движок сабмитит скрытое поле:
`render/screens.ts:366` (value), `:387` (social-proof), `:452` (results),
`:508` (statement) — `<input type="hidden" name="answer" value="ack">`;
`:581` (loader) — `value="done"`.

`routes/quiz.ts` подавляет только **событие** (`isAcknowledgement`, ~:1104-1107),
но `applyAnswer` уже записал `state.answers[screenId] = ['ack']`. Дальше
`buildQuizResult`, `buildAnswerPayload` и `buildPlatformAnswers` итерируют
`state.answers` без фильтра.

Для `general-english` это **8 мусорных записей** в survey: 5 `value` (s1c, s4, s8,
s18, s21) + `social-proof` s13 + `results` s27 с `selected_options: ["ack"]` и
`question_id` = id экрана, плюс лоадер s25 с `["done"]`.

### G5 — рампа лоадера не ждёт записи; `qrid` можно потерять
Прод останавливает рампу на 90 % и не завершает лоадер, пока запись не
подтверждена, либо пока не сработал 6-секундный форс:
`FunnelContext.tsx:81-88` (`LOADER_RAMP_CAP = 90`, `LOADER_MAX_WAIT_MS = 6000`),
`:1543` (`if (!isTestResultSaved && !loaderForceReady) return`),
`:1668` (`const isForced = !isTestResultSaved`).

Движок: `render/screens.ts:525-608` — рампа идёт 0→100 за `minDurationMs`
(в конфиге 3000 мс, `funnels/general-english/config.json:826`) и на 100 %
делает `requestSubmit()`. Медленная половина работы висит в `/kilo/:id/prepare?full=1`
(`routes/quiz.ts` ~:437-500), который в собственном комментарии оценивает
`GET /v1/profiles` в **~2.8 с** плюс ещё запись результата.

Возврат `/prepare` — OOB-свап скрытого `#state-field`. Если он не успел к 100 %,
сабмитится **старый** токен. `POST /kilo/:id/answer` восстанавливает из куки
**только `idb`** (~:1000-1010: `if (state && !state.idb) { ... state.idb = fromCookie.idb }`)
— `qrid` из куки **не** добирается. То есть `quiz_result_id` теряется, и в теле
заказа его не будет.

Дополнительно: `forced` в движке захардкожен `false` (`routes/quiz.ts` ~:1108-1113
с комментарием «the write is awaited server-side, so the race … cannot happen») —
но записи ждёт `/prepare`, а не рампа, так что гонка как раз возможна, а сигнала
о ней нет.

### G6 — прод-локали квиза не перенесены
`general-english` в проде: `es, pt, de, fr, it` + en
(`general-english/locales/buildLocalizedData.ts:21-27`).
`say-what-you-mean-3`: те же пять. `english-hub`: те же плюс `es-419`
(единственная воронка с ним, `english-hub/locales/buildLocalizedData.ts:22-29`).
`say-what-you-mean-2`: только en (`DICTIONARIES = {}`, `:18`).

Движок: `src/registry.ts:88` — `CATALOGS = { 'general-english': { uk } }`.
Ни одной прод-локали; вместо них `uk`, которого у прода нет.

### G7 — нет `?lang=` оверрайда локали
`pages/Onboarding/utils/shouldConsiderBrowserLocaleRedirect.ts:6-33`: query-параметр
`lang` бьёт `Accept-Language` и участвует в редиректе. Грепом по
`funnel-engine/src` — 0 совпадений на `'lang'`.

### G8 — soft-404 на неизвестном screen-параметре
Прод специально закрывал этот класс: `page.tsx:68-77` («an unknown id returns a
REAL HTTP 404 — not a 200 shell»), `:88` (лишние сегменты), `:162-166` (screen id
не во `flow`). Движок на `?screen=abc` / `?screen=99` отдаёт 200 и первый (или
клэмпнутый) экран.

### G9 — прогресс-бар считает по длине `flow`, а не по числу вопросов
`engine.ts:progressPercent` = `stepNumber / quiz.flow.length`.
Прод GE: `QUIZ_STEPS_TOTAL = 26` (`general-english/data.ts:29`, комментарий «Number
of quiz-body screens that show the progress counter (s1–s24)») и per-screen
`data.step`. swym: `stepNumber`/`stepTotal` = `NN/15` при 20 экранах во `flow`.
`_template/components/ProgressBar.tsx:26-32` прямо предупреждает про эту ошибку.
Ни в схеме движка, ни в `config.json` нет ни `progressTotal`, ни `step`.

### G10 — resume: новая вкладка ведёт себя противоположно проду
Прод: `FunnelContext.tsx:705-770` вытирает `funnel_builder_user_answers` на первом
экране, гейт — `getIsFirstAnalyticsSentForSession` в **sessionStorage** (per-tab).
Новая вкладка = флага нет = wipe = fresh run (кроме multi-tab-гарда по
`funnel_active_at` в пределах `MULTI_TAB_ACTIVE_THRESHOLD_MS`).
Движок: кука `fe_state` с `Path=/` и `Max-Age=86400` — общая на браузер, новая
вкладка **продолжает** прогон с `state.cur`.

Обратное расхождение по времени: прод (localStorage без TTL) восстановит прогон
и через сутки, если URL несёт screen id; движок — никогда
(`MAX_RESUME_AGE_SECONDS = 4*3600`, `state.ts:392`, плюс `Max-Age` куки).

### G11 — экраны прода, для которых в схеме нет типа
- swym `results`, 4 варианта: `say-what-you-mean-2/types.ts:198-223`, данные
  `data.ts:408-457`, селектор `screens/ResultsScreen.tsx:43-63`. Лестница
  `pickVariantKey` выражается через `$rules`, но **нет типа экрана**, который
  умеет `variants.<key> → {title, focus[], heroMoment, proof}`.
- swym `profile`: `types.ts:144-189`. Помимо типа экрана требует карт
  answerKey→**объект** (`nowByConfidence: {value,percent}`), которых
  `$byAnswer`/`$rules` не умеют (только строки).
- english-hub `landing`: `english-hub/types.ts:18-83`, ~30 полей.
- `target-language`/`native-language`: только `_template/types.ts:143-159`, нужен
  каталог курсов (`code-funnels/languages/languageCatalog.ts`) и живой фильтр
  (`hooks/useLanguagePairs.ts`). **0 прод-потребителей.**

### G12 — мелкие дыры внутри уже закрытых типов
- per-answer `reaction` у swym `single-choice` (`say-what-you-mean-2/types.ts:20-27`):
  его наличие переключает экран с tap-to-advance на select-then-Continue. В
  `answerSchema` движка такого поля нет.
- `steps[]`-чек-лист лоадера swym (`say-what-you-mean-3/screens/LoaderScreen.tsx:20-40`)
  против только `stages[]` у движка; у swym-гейта есть `body`.
- `reassurance` у swym `multi-choice` (`types.ts:96`).
- `bars` у swym `info-screen` — `{label}` (высота по индексу,
  `say-what-you-mean-2/types.ts:111-113`); в движке `pct: 0-100` обязателен, т.е.
  автор обязан выдумать числа для иллюстрации.
- `stat.footnote` вложен в `stat` у прода, у движка — сосед `footnote`.
- ключ ответа гейта лоадера: прод пишет и текст, и `option.toLowerCase()`
  (`general-english/screens/LoaderScreen.tsx:52-59`), движок — только сырую строку.
- `robots`: у прода `follow: false`, у движка только `noindex`.
- `count(answers)` и интерполяция `{n}` (`general-english/screens/ResultsScreen.tsx:32-45`).

### G13 — 5 из 6 воронок не перенесены
`src/registry.ts:23-25` — одна. Не перенесены `general-english-b`,
`general-english-g` (тривиально: отличаются `salesPageSlug` —
`general-english-b/data.ts:554`), `say-what-you-mean-2`, `say-what-you-mean-3`,
`english-hub`. Портирование двух клонов GE — это две строки в `RAW` плюс копия
конфига с другим `completion.salesSlug`; swym и english-hub блокированы G11.

### G14 — риски, не являющиеся разрывами, но фиксируем
- потолок куки 3800 байт (`state.ts:MAX_COOKIE_BYTES`): переполнение → resume
  молча деградирует до form-token, с `console.error`. 32 экрана GE проходят;
  более длинная воронка — нет.
- кэш GrowthBook не учитывает `device_id`/`custom_user_id` (`growthbook.ts:88-100`):
  процентный роллаут резолвится на когорту, а не на визитёра.
- `signedInOnPlatform` (`http.ts:233`) читает подделываемую куку и работает только
  за route split на том же домене.
- FTC-флаги, по `plans/gimli2-full-migration-plan.md` §3.2, `false` для всех стран
  → ось `flag:` не проверена на живых флагах.
- комментарий `render/screens.ts:146-155` («browser back therefore leaves the
  funnel») **устарел**: `layout.ts:613-621` + `X-Screen-Url` делают back рабочим.

---

## 3. Проверка утверждения `gimli2-full-migration-plan.md` §2

> «Осталось из карты: экраны swym `results` (4 варианта) и `profile`,
> `english-hub landing`, `language-picker`, реальный набор дешёвых продуктов для
> даунсела, `bestOfferProductId`.»

**Верно, но неполно.** Все четыре экранных пункта подтверждены (G11). Однако
в списке отсутствует:

1. **G1/G2/G3/G4** — четыре расхождения формата ответов, уезжающих на
   `POST /v1/quiz-results/` и в hand-off платформы. Это не «экран», это контракт.
2. **G5** — рампа лоадера не ждёт записи, `qrid` теряется, `forced` захардкожен.
3. **G6** — пять прод-локалей квиза (`es, pt, de, fr, it`) не перенесены; вместо
   них `uk`, которого у прода нет.
4. **G7** — `?lang=` оверрайд.
5. **G8** — soft-404 на неизвестном screen-параметре (прод этот класс специально
   закрывал).
6. **G9** — знаменатель прогресс-бара.
7. **G10** — resume в новой вкладке и через сутки.
8. **G12** — `reaction`, `steps[]`, `reassurance`, `bars.pct`, lowercase ключа
   гейта, `nofollow`, `count(answers)`, `{n}`.
9. **G13** — `general-english-b` и `-g` не перенесены, хотя это тривиально.

Уточнение по формулировке плана: «`language-picker` (нужен каталог курсов)» —
у этого типа **ноль прод-потребителей** (все 6 воронок `courseSource: 'none'`,
`FunnelContext.test.tsx:1707`). Приоритет должен быть ниже, чем у G1–G5.

### Проверка `gimli2-authoring-inventory.md` §1.1 и §4.8
Документ описывает движок **до** коммита условного слоя/экранов и в ряде мест
устарел. Проверено по текущему коду — **закрыто** то, что там помечено PART/MISS:

| в инвентаре | сейчас |
|---|---|
| «нет `badges[]`» у swym `start-screen` | есть, `quiz.schema.ts` `startScreen.badges`, рендер `screens.ts:189-201` |
| «нет `layout`» у `choice` | есть, `layout: z.enum(['list','grid'])` |
| «`surface` — enum имён ассетов GE» | `z.string().min(1).optional()` |
| «в движке только `skipText`» | есть `skip{label,answerKey}` **и** `skipText` |
| «`statement` беднее `info-screen`» | добавлены `stat`, `bullets`, `bars`, `caption`, `image`, `eyebrow` |
| «AND/OR — MISS» | `$rules.when.all` / `.any` |
| «упорядоченный список правил для контента — PART» | `$rules` с обязательным `default` |
| «`map[answerKey] ?? fallback` не общий примитив» | `$byAnswer` на любом copy-поле |
| «выкинуть строку без ответа — MISS» | `dropIfMissing` + `DROP` |
| «`adTopic` — MISS» | ось `adTopic:<topic>` в `variants` |
| «атом по `questionKey` — PART» | `$rules`-атомы ключуются по `questionKey` (`resolve.ts:answerIndex`) |

**Остаётся верным из §4.8:** `count(answers)` — MISSING; общая интерполяция —
MISSING; `evalCondition`'s `answer ==` смотрит только текущий экран, а `has()`
ключуется по screen id, не по `questionKey` (латентно, 0 потребителей).

---

## 4. Открытые вопросы

1. **G1 — какой формат правильный?** Бэкенд `/v1/quiz-results/` индексирует
   `question_id` (это проверено), но что делают потребители с `selected_options` и
   `selected_answer_id`? Если `selected_options` где-то показывается человеку —
   движок сейчас отдаёт ключи, и это регресс. Нужен ответ от бэкенда/CRM, а не
   догадка.
2. **G2 — нужен ли `user_language_level` от движка?** Прод пишет его всегда с
   fallback `A1`; движок в `general-english` спрашивает уровень напрямую
   (`ft8_lvl`). Дублировать его как отдельную запись, или `ft8_lvl` достаточно?
   От этого зависит, ломается ли сегментация по уровню.
3. **G5 — как правильно ждать?** Скопировать прод (cap 90 % + форс 6 с + `forced`)
   или переставить архитектуру: держать сабмит до ответа `/prepare` и добирать
   `qrid` из куки в `/answer`. Второе дешевле и надёжнее, но расходится с прод-UX
   (у прода посетитель видит 90 % и ждёт).
4. **G6 — какие локали нужны пилоту?** `uk` в движке — под какую задачу? Прод
   `general-english` живёт на `es/pt/de/fr/it`. Если пилот идёт на тех же
   кампаниях, `uk` бесполезен, а пяти нужных нет.
5. **G8 — какой ответ на неизвестный `?screen=`?** 404 (паритет с продом,
   SEO-корректно) или текущий клэмп (не теряет прогон)? Прод специально выбрал
   404; движок специально выбрал клэмп. Одно из решений надо отменить осознанно.
6. **G10 — какая семантика resume целевая?** 4 часа + fresh-на-новый-клик
   (движок) выглядит правильнее для платного трафика, но это **изменение
   продуктового поведения**, а не порт. Нужно решение продукта, иначе метрики
   пилота и прода несравнимы.
7. **G9 — откуда брать знаменатель прогресса?** Ввести `progressTotal` в схему
   (как у прода на модуле) или считать по числу экранов с `questionKey`? Второе
   выводится автоматически и совпадает с прод-интентом («count QUESTIONS, not
   `flow[]`»).
8. **G11 — `profile` требует расширения DSL, а не только типа экрана.**
   `nowByConfidence: Record<answerKey, {value, percent}>` — карта в объект.
   Расширять `$byAnswer.map` до `Record<string, unknown>` (и терять гарантию, что
   директива всегда коллапсирует в строку) или ввести отдельный примитив на этот
   экран?
9. **english-hub `landing` — экран или sales-page?** 30 полей, композиция
   секций, `loaderScreenId: null`, flow из двух шагов. `schema/sales.schema.ts`
   уже умеет 16 типов секций. Не дешевле ли выразить его как sales-страницу
   с email-шагом, чем как тип экрана квиза?
10. **G13 — переносить ли `-b` и `-g`?** Они отличаются одним слагом. Если
    A/B-сплит делается рекламной ссылкой (как в проде), движку нужны три
    идентичных конфига — или одна воронка с осью `variants` и разными
    `completion.salesSlug`? Второе схема сейчас не умеет (`salesSlug` не поле
    экрана).
11. **`funnel_name` пилота.** По `gimli2-full-migration-plan.md` §4a решено
    писать под тем же именем. Тогда любое расхождение из §2 (`ack`-записи,
    отсутствие `user_language_level`) смешается с прод-данными в Amplitude и
    в квиз-результатах бэкенда. Это точно приемлемо?
12. **Кто чинит `render/screens.ts:146-155`?** Комментарий утверждает
    противоположное тому, что делает код (`layout.ts:613-621`). Мелочь, но именно
    такие комментарии потом читают как спеку.
