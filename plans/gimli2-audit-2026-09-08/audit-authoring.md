# Аудит: vibe-coder authoring + операционная готовность `funnel-engine`

**Дата:** 2026-09-08 · **Репо:** `/Users/uvarovalexandr/myProject/funnel-engine` (HEAD `486b290`, всё закоммичено и в `origin/main`)
**Сверка:** `plans/gimli2-authoring-inventory.md` (2026-09-03), `plans/gimli2-full-migration-plan.md` §4a/§5,
`plans/funnel-engine-docker-migration.md`, `plans/funnel-engine-vault-env.md`, монорепа `promova.com_monorepo`.
**Метод:** чтение кода + реальный прогон `pnpm validate` и `pnpm test` через `pnpm --dir`.
Пути абсолютные или от корня `funnel-engine`, если не указано иное.

---

## 0. Короткий вывод

Механика авторинга **есть и работает**: 934-строчный валидатор реально зелёный,
скаффолд собирает структурно целую воронку, реестр защищён от дрейфа, 186 юнит-кейсов
и 7 сьютов проходят, гейты вшиты в Dockerfile. Инвентаризация от 03.09 в части
«`pnpm validate` объявлен, а файла нет» **устарела** — файл есть с коммита `04197ca`.

Не готово ровно то, что стоит между «механизм собран» и «маркетолог сам сделал воронку»:

1. **Одна команда вместо пяти.** `/new-funnel` есть, `/funnel-copy`, `/funnel-theme`,
   `/funnel-images` из плана §8.5 — нет. Нет SKILL-файла, значит правила не подгружаются
   автоматически при правке `funnels/**` (в монорепе `quiz-funnel-factory/SKILL.md`
   именно так и работает).
2. **Нет `CLAUDE.md`** в корне репо (шаг 6 docker-плана не выполнен) — сессия Claude Code
   в этом репо не знает ни правил, ни пяти комплаенс-правил, пока автор вручную не
   наберёт `/new-funnel`.
3. **Пост-покупочная цепочка не покрыта авторингом вообще:** `CHAINS = {}`, скаффолд не
   пишет `post-purchase.json`, шаблона нет, а `/new-funnel` велит агенту сочинить его
   с нуля — при том что это единственный файл, который списывает деньги.
4. **Продуктовые id не проверяются против живого каталога** и нет ни строчки о том,
   где их брать (Walhalla MCP в репо не упомянут ни разу).
5. **Превью на ветку отсутствует** и признано осознанной потерей; черновик виден либо
   локально в докере, либо после мерджа в `main`.
6. **Ни одной воронки через vibe-coding не сделано.** `funnels/` содержит один
   `general-english`, портированный руками в трёх движковых коммитах.

---

## 1. Сводная таблица

### 1.1 Скиллы и команды для vibe-coder'а

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `/new-funnel` (бриф → воронка) | `.claude/commands/new-funnel.md` (150 стр.) | **DONE** | Покрывает: скаффолд, 5 комплаенс-правил (`:36-58`), no-prices (`:53-58`), Funnel Core (`:66-76`), таблицу «какой экран под какую задачу» (`:78-92`), закрытый список секций (`:94-102`), 3 примитива условности (`:104-124`) |
| `/translate-page` | `.claude/commands/translate-page.md` (88 стр.) | **DONE** | Образцовая форма: один артефакт, правила, команда проверки, «чего не делаем» (`PINNED_ENGLISH`) |
| `/translate-status` | `.claude/commands/translate-status.md` (56 стр.) | **DONE** | Читает `pnpm i18n status`, объясняет orphans |
| Команды подхватываются Claude Code как слэш-команды | `.claude/commands/` — единственный подкаталог `.claude/` | **DONE** | Проектные команды из `.claude/commands/*.md` подхватываются: `/new-funnel`, `/translate-page`, `/translate-status`. Frontmatter нет ни у одной (`new-funnel.md:1` — сразу `# /new-funnel`), значит нет `description`/`allowed-tools`, но вызов работает |
| `.claude/skills/` | — | **MISSING** | Каталога нет. Ничего не автоподгружается на `funnels/**`. Ср. монорепа: `.claude/skills/quiz-funnel-factory/SKILL.md:5-9` `autoLoad: packages/features/FunnelBuilder/code-funnels/**` |
| `CLAUDE.md` в корне репо | — | **MISSING** | `find -maxdepth 2 -name CLAUDE.md` пусто. Запланировано в `funnel-engine-docker-migration.md:160-168` (шаг 6), не сделано |
| add-a-screen | — | **MISSING** | В монорепе аналог — `/quiz-screen` (1569 строк). Здесь ничего; экран добавляется правкой `config.json` руками |
| edit-copy (`/funnel-copy`) | — | **MISSING** | План §8.5. В монорепе `/quiz-copy` 511 стр. + `/quiz-fix-copy` 306 стр. |
| add-upsell-chain | `.claude/commands/new-funnel.md:8` («и `post-purchase.json`, если бриф просит апселлы») | **MISSING** | Одна фраза. Ни шаблона, ни примера, ни живого конфига (`src/registry.ts:139` `const CHAINS = {}`). Схема на 230 строк есть, автор пишет JSON с нуля |
| theme-from-brand (`/funnel-theme`) | — | **MISSING** | План §8.5. Скаффолд кладёт 8 токенов (`scripts/scaffold-funnel.ts:216-226`), схема поддерживает ~40 + шрифты (`schema/theme.schema.ts:89-95`); из Figma/палитры ничего не собирает |
| image pipeline | `scripts/build-images.mjs` (115 стр.), `src/render/image-manifest.json` (10 ключей, все `general-english/*`) | **PARTIAL** | Механика хорошая: `assets/` → `public/img/` + манифест, webp q85, хеш в имени, PNG-фолбэк. Валидатор сверяет ключи (`scripts/validate-funnels.ts:546`). **Скилла нет**: в `new-funnel.md:138-142` три строки «положи в `assets/<id>/` и запусти `pnpm images`». Генерации картинок нет вообще (в монорепе `/quiz-images` 313 стр. + `cf/.tools/generate-image.mjs`) |
| product-id lookup (план: через Walhalla MCP) | `.claude/commands/new-funnel.md:132` «Ask for the product ids» | **MISSING** | В репо нет ни одного упоминания Walhalla / MCP / каталога продуктов (grep по `.claude/commands/` и `README.md`). Единственная защита — regex на `REPLACE_ME` |
| preview | `README.md:1338-1341` (`pnpm docker:run`) | **PARTIAL** | Только локально. В `/new-funnel` шага превью нет вообще (grep `pnpm dev|docker|preview` по файлу → 0 совпадений) |
| publish | — | **MISSING** | Публикация = коммит в `main`. В `/new-funnel` нет шага коммита/пуша/деплоя |
| A/B clone | `schema/quiz.schema.ts:494` (ось `flag:<name>`), `:510` (`declaredFlags`) | **PARTIAL** | Пер-полевые варианты по `country:`/`adTopic:`/`flag:` в схеме есть. Клона воронки / сплита на уровне воронки нет ни в коде, ни в командах. `gimli2-full-migration-plan.md` §6: «Не строить A/B внутрь движка сейчас» — осознанно |
| rollback | — | **MISSING** | Ни команды, ни раздела в README (grep `rollback` → 0 релевантных). Фактический откат = revert коммита → повторный прогон пайплайна, либо откат тега образа в `promova-gitops` руками |
| analytics check after launch | `README.md:855` (Loki-запрос `{service_name="funnel-engine-prod"} \|= "funnel_event" \| json`) | **PARTIAL** | Запрос документирован, но `gimli2-full-migration-plan.md` §5: «логов движка нет ни в одном k3s-датасорсе Loki». Скилла/чеклиста «проверь воронку через сутки» нет |
| legal review checklist | `.claude/commands/new-funnel.md:36-58` + валидатор `scripts/validate-funnels.ts:620-737` | **PARTIAL** | 5 правил формализованы и частично машинно проверяются. Отдельного чеклиста на legal sign-off (кто, когда, что подписывает) нет; каноничный ROSCA-текст не выбран (`gimli2-full-migration-plan.md` §5, «их в монорепе пять») |

### 1.2 Валидатор

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `pnpm validate` существует и зелёный | `package.json:9`, `scripts/validate-funnels.ts` (934 стр.) | **DONE** | Реальный прогон: `1 funnel validated — 0 failures, 2 warnings` |
| Группы проверок | баннеры `:74, :96, :125, :177, :356, :441, :532, :614, :740, :785, :808` = 11 групп + schema-parse в `validateFunnel:846-880` | **DONE** | Вызовы `:881-892`. README `:769-778` перечисляет только 8 — доки отстают от кода |
| Registry drift | `:82-95` | **DONE** | Ловит и «конфиг на диске, но не импортирован», и обратное |
| Funnel Core coverage | `:104-124` | **DONE** (WARN) | Считает `questionKey` экранов + `funnelCoreParams` |
| Плейсхолдеры | `:127-145` | **DONE** | `[REAL …]`, `TBD`, `LOREM`, `{{ }}` |
| **Цены и каденции в копии** | `:146-148` (`PRICE_IN_COPY`, `CADENCE_IN_COPY`), применение `:150-174`, для цепочки `:513-517` | **DONE** | Идентификаторные поля исключены (`:155`) |
| Директивы / варианты | `:205-355` | **DONE** | Главное: директива не может читать ответ на **более поздний** экран (`:250`); ключи оси валидируются схемой (`schema/quiz.schema.ts:494`) |
| Тема | `:369-440` | **DONE** | В т.ч. контраст legal-текста |
| Цепочка post-purchase | `:452-530` | **DONE** | `renewalLine` обязателен для подписки и запрещён для one-time; цифры без footnote — FAIL; цена в копии — FAIL |
| **Ключи картинок** | `:546-592` | **DONE** | Каждый `image`/`logo` сверяется с `image-manifest.json`, принимаются `key` и `<id>/key` |
| Scaffold-маркеры | `:594-613` | **DONE** | `REPLACE_ME|CHANGE_?ME` → FAIL |
| **Атрибуция статистики (footnote)** | `:640-698` | **PARTIAL** | Работает по regex `\d{1,3}\s?%` и `\d+ (million\|thousand\|k+)`. Статистика прописью («nine in ten», «двое из трёх») проходит молча |
| «results may vary» | `:658-698` | **DONE** | Экран `results` и секция `chart` |
| **FTC/ROSCA не переводить** | `:714-739` + `src/i18n.ts` `PINNED_ENGLISH` | **DONE** | Перевод авто-renewal фразы в каталоге — FAIL |
| **Таймер** | `:622-632` | **PARTIAL** | Только **WARN**. Схема таймер разрешает (`schema/sales.schema.ts:434`). Т.е. countdown технически может уехать в прод |
| **Cap на апселлы** | `schema/post-purchase.schema.ts:219-222` | **DONE** | Схема отказывает на третьем хопе — сильнее, чем WARN валидатора |
| Покрытие локалей | `:742-784` | **DONE** | FAIL <80%, WARN <100%, orphans, rejected-entries |
| Вес ассетов | `:787-806` | **DONE** | 96 КБ/картинка (WARN), 512 КБ/воронка (FAIL) |
| Down-sale honesty | `:816-833` | **DONE** (WARN) | Ловит «скидка арифметическая, а не другой продукт» |
| **Продуктовые id против живого каталога** | — | **MISSING** | В валидаторе нет ни `fetch(`, ни флага `--live` (grep). План §8.2 п.8 (commerce-fidelity) не реализован. Проверяется только строка `REPLACE_ME` |
| `pnpm validate` внутри `pnpm build` | `package.json:11` `build = images && typecheck && bundle` | **PARTIAL / дыра** | `validate` в `build` **не входит**. Гейт живёт только в `Dockerfile:36-41`. Локальный `pnpm build` собирает невалидированную воронку |

### 1.3 Скаффолд

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `pnpm scaffold <id> ["Name"]` | `package.json:15`, `scripts/scaffold-funnel.ts` (309 стр.) | **DONE** | |
| `config.json` (6 экранов) | `:62-152` | **DONE** | start → choice → choice → value (`$byAnswer`) → email → results; footnote «Illustrative. Individual results may vary.» уже стоит (`:150`) |
| `sales.json` | `:161-207` | **DONE** | 2 плана + hero/bullets/plans/guarantee/secure-payment/faq |
| `theme.json` | `:216-226` | **PARTIAL** | 8 токенов, шрифтов/логотипа нет |
| `locales/` | `:231` (`mkdirSync`) | **PARTIAL** | Создаётся пустой каталог; файла локали нет, `--locales de,es,fr` из плана §8.3 не поддержан (аргументы только `<id> ["Name"]`, `:35`) |
| **`post-purchase.json`** | — | **MISSING** | Не создаётся. Значит «quiz → email → sales → upsell → downsell → thank-you» скаффолдом покрыт **только до sales** |
| `assets/<id>/` | — | **MISSING** | Не создаётся (план §8.3 требовал `.gitkeep`). Автор упирается в FAIL на `placeholder-a`/`placeholder-b` (`:75-76`, `:110`) без готового места под файлы |
| `funnels/<id>/README.md` с брифом | — | **MISSING** | План §8.1 требовал (аналог `design-analysis.md` прода). Ни скаффолд, ни `/new-funnel` его не пишут — бриф нигде не сохраняется |
| Регистрация в `src/registry.ts` | `:262-296` | **DONE, но хрупко** | Патч строковой заменой по 4 «иглам»; если строка сдвинется — abort с просьбой доделать руками (`:290-294`). План §8.1 требовал **генерируемый** `registry.generated.ts` — не сделано |
| Скаффолд намеренно не проходит `validate` | `:16-22`, вывод `:298-309` | **DONE (осознанно)** | Падает ровно на двух вещах: картинки и реальные product id |
| End-to-end работоспособность продукта скаффолда | — | **PARTIAL** | Квиз ходится, пейволл рендерится **без карточек** (нет цены — `README.md:1465`), апселла нет вовсе. До «полной воронки из брифа» не дотягивает |

### 1.4 Превью / CI / публикация

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| CI на PR | `.github/workflows/ci.yml` | **DONE** | Один джоб: docker build (внутри — `images/typecheck/validate/test/bundle`), запуск контейнера, `/ready`, `pnpm test:e2e` против контейнера, проверка graceful SIGTERM (`"action":"drained"` + exit 0) |
| Preview URL на PR | — | **MISSING** | `ci.yml` образ не пушит (`load: true`, локальный тег `funnel-engine:ci`) и никуда не деплоит |
| Скриншот-гейт на PR (экраны × локали × гео) | — | **MISSING** | План §8.4 п.3. В проде это Category I (`gimli2-authoring-inventory.md:1045`) — единственный гейт, реально ловивший дизайн-регрессии |
| Dev-хост | `build-deploy-k3s.yml` (push в `main`, path-filtered) → `deploy_dev=true` | **DONE** | `gimli.promova.com`, поднят 07.09 (`funnel-engine-vault-env.md:3`) |
| Prod-хост | `build-deploy-k3s.yml` `workflow_dispatch` `environment: prod|both` | **DONE** | Прод только вручную; push в `main` прод не трогает |
| `ci-test/**` escape hatch | `build-deploy-k3s.yml` (setup → `build_only=true`) | **DONE** | Собирает и пушит образ, но в `promova-gitops` не пишет — то есть **тоже не даёт хоста** |
| Роут `?_preview=<funnelId>` | — | **MISSING** | grep по `src/`: есть только `_ftc` (`src/routes/sales.ts:194`, `src/routes/post-purchase.ts:249`) |
| Как маркетолог видит черновик | `README.md:1330-1341` | **PARTIAL** | Только `pnpm docker:build && pnpm docker:run` локально, либо мердж в `main` → dev-хост. Признано «the sharpest single regression from the runtime move and it has no cheap fix» (`README.md:1567-1571`) |
| Публикация конфига без деплоя | `src/registry.ts:1-4` (статические импорты), `README.md:1558-1566` | **MISSING (осознанно)** | Конфиги инлайнятся esbuild'ом в `dist/` (`scripts/bundle.mjs`), парсятся раз за процесс. Любая правка копирайта = новый образ. Причина названа честно: внешний источник конфига обойдёт `pnpm validate` |
| Фактические шаги/время на одну правку копирайта | `ci.yml` + `build-deploy-k3s.yml` | — | 1) правка JSON → 2) коммит/пуш в `main` → 3) `ci.yml` (docker build с гейтами + e2e против контейнера) → 4) `build-deploy-k3s.yml`: `setup` (timeout 2 мин) → `build` на `hetzner-amd64` (timeout **30 мин**) → ECR push → 5) `deploy` (timeout **20 мин**): `update-gitops` → `wait-argocd-sync` (timeout **480 с**). Прод — отдельный ручной `workflow_dispatch`. Т.е. на dev это минуты-десятки минут и **два независимых пайплайна на один правленый заголовок** |
| Устаревшая ссылка в README | `README.md:1368` «`pnpm deploy` runs it automatically» | **дрейф** | Скрипта `deploy` в `package.json` нет; `README.md:125` сам же пишет «There is no deploy command» |

### 1.5 Мультифаннельность

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `RAW` (квизы) | `src/registry.ts:22-24` | **PARTIAL** | Хардкод-объект + статический импорт |
| `SALES_RAW` | `src/registry.ts:56-58` | **PARTIAL** | То же |
| `CATALOGS` (локали) | `src/registry.ts:97-99` | **PARTIAL** | Добавление локали = правка кода руками (`translate-page.md:44-56`), скаффолдом не автоматизировано |
| `THEMES` | `src/registry.ts:110-112` | **PARTIAL** | |
| `CHAINS` | `src/registry.ts:139` `const CHAINS = {}` | **MISSING** | **Ни одной** зарегистрированной цепочки. Апселл-путь целиком без живого конфига |
| Добавление воронки = code change? | `scripts/scaffold-funnel.ts:262-296` | **PARTIAL** | Да, code change (4 правки в `registry.ts`), но скаффолд их делает сам; дрейф ловит `validate-funnels.ts:82` |
| Генерируемый реестр (план §8.1) | — | **MISSING** | `registry.generated.ts` не сделан |

### 1.6 Наблюдаемость

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `/healthz` (liveness) | `src/index.ts:36` | **DONE** | Отдаёт `{ok, funnels: <count>}` |
| `/ready` (readiness) | `src/server.node.ts:144` | **DONE** | |
| `/_diag/identity` | `src/routes/diag.ts:14-18` | **DONE** | За `DIAG_TOKEN`, 403 без ключа |
| Страницы ошибок | `src/index.ts:38` (`notFound` → `renderError`), `:40` (`onError`) | **DONE** | |
| Событийный лог в stdout | `src/analytics/log.ts:58` | **DONE** | Одна JSON-строка, `kind:"funnel_event"` первым полем под дешёвый Loki-селектор |
| Логи реально в Loki | `README.md:855` (запрос), `gimli2-full-migration-plan.md` §5 | **MISSING** | «логов движка нет ни в одном k3s-датасорсе Loki» — открытый пункт к DevOps. Без них не отличить «не отправили» от «отправили, Amplitude отверг» (`events_ingested: 0` на 200) |
| Диагностика криво настроенного хоста | `src/http.ts:100` `warnOnMissingGeo`, вызов `src/routes/quiz.ts:523` | **DONE** | Единственный self-check: пишет в лог при отсутствии `cf-ipcountry` |
| Алерты / дашборд | — | **MISSING** | В README нет раздела про алерты (grep `alert|Grafana` → только про «dashboard row» в смысле Amplitude) |
| Обзор для автора (не инженера) | — | **MISSING** | Нет ни `/funnel-health`, ни чеклиста «что смотреть после запуска» |

### 1.7 Доки

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `README.md` | 1646 строк | **PARTIAL** | Очень подробный, раздел «Authoring a funnel» `:1400-1430`, «Deliberately not here» `:1553-1581`, «What MVP-1 needs» `:1591-1646` — честные |
| «Пять правил не из схемы» | `.claude/commands/new-funnel.md:36-58`, сводка `README.md:774-782` | **PARTIAL** | Сформулированы. Но живут в команде, которую надо вызвать по имени; без SKILL/CLAUDE.md сессия их не увидит |
| `CLAUDE.md` | — | **MISSING** | См. 1.1 |
| Дрейф README ↔ код | `README.md:1368` vs `package.json` (нет `deploy`); `README.md:125` противоречит `:1368` | **дрейф** | |
| Workers-остатки в комментариях | `scripts/test.ts:4` («needs a running Worker»), `scripts/i18n.ts:20-24` («types is `@cloudflare/workers-types` alone» — неправда с `235c6bf`), `src/registry.ts:17` («MVP-1 adds a KV read-through cache» — KV больше нет), `scripts/validate-funnels.ts:20-21` и `scripts/scaffold-funnel.ts:26` ссылаются на удалённый `scripts/node-shims.d.ts` | **дрейф** | Пять мест, где комментарий описывает мёртвый рантайм |
| Замеры производительности | `README.md:1330-1336` | **PARTIAL, но помечено** | Цифры сняты на Workers, в файле стоит явная плашка «не перемерялось на k3s» |
| README отстаёт от валидатора | `README.md:769-778` (8 групп) vs 11 групп в коде | **дрейф** | |

### 1.8 Приёмка

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| Воронок в репо | `funnels/general-english/{config.json 25 573 B, sales.json 15 019 B, theme.json, locales/uk.json}` | — | **Одна.** 32 экрана: 13 `choice`, 7 `agree-scale`, 5 `value`, по 1 `start-screen`/`goal-selector`/`social-proof`/`name-input`/`loader`/`email`/`results` |
| Сделана ли она vibe-coding-потоком | `git log -- funnels/` → `3fc6e39` (initial import), `0938978` (conditional layer), `776ba91` (theme) | **MISSING** | Все три — движковые коммиты автора движка. Ни одного коммита «воронка из брифа» |
| Официальный статус | `gimli2-full-migration-plan.md` §4a: «Механизм собран, но ни одной воронки через него не сделано. Нужен бриф» | **MISSING** | Совпадает с фактом |
| `assets/general-english/` | 10 файлов, 2.8 МБ исходников → `image-manifest.json` 10 ключей | **DONE** | |

### 1.9 Тесты

| item | где (file:line) | статус | заметка |
|---|---|---|---|
| `pnpm test` | `scripts/test.ts` (54 стр.), запускает каждый сьют отдельным процессом | **DONE** | Реальный прогон: **7/7 сьютов, 186 кейсов** — chain 48, handoff 16, locale 38, resolve 19, screens 27, sections 28, session 10 |
| `pnpm test:e2e` | `tests/e2e.test.ts:24` `BASE = E2E_BASE ?? 'http://localhost:8799'` | **DONE** | README `:1433` заявляет 66 кейсов (не проверял — нужен слушатель) |
| Против чего гоняется e2e в CI | `ci.yml` → `docker run -d --name fe -p 8799:8080 -e ENVIRONMENT=dev funnel-engine:ci`, затем `E2E_BASE=http://localhost:8799 pnpm test:e2e` | **DONE** | Именно против собранного образа, не против `tsx` |
| CI гоняет e2e | `ci.yml` шаг `e2e` | **DONE** | + `validate`/`typecheck`/`test`/`bundle` внутри `Dockerfile:36-41` |
| Тест-раннер | `tests/harness.ts` (79 стр.) | **DONE (осознанно)** | Без фреймворка, `README.md:1576-1581` объясняет почему |
| Тесты авторинга (скаффолд, валидатор) | — | **MISSING** | Ни `scripts/scaffold-funnel.ts`, ни `scripts/validate-funnels.ts` не покрыты сьютом. Валидатор — единственное, что стоит между генерацией и живым трафиком, и он сам не тестируется |
| Визуальный/скриншотный тест | — | **MISSING** | См. 1.4 |

### 1.10 Сравнение с authoring-тулингом монорепы

| item | монорепа (file, строк) | funnel-engine | вывод |
|---|---|---|---|
| Скилл | `.claude/skills/quiz-funnel-factory/` — **26 `.md`, 7 896 строк** | нет `.claude/skills/` | Движок не имеет автоподгружаемого «мозга» |
| Автоподгрузка | `quiz-funnel-factory/SKILL.md:5-9` `autoLoad: [codegen-screens/flow-*/**, code-funnels/**, **/workflow-state.json]` (единственный `autoLoad` из 128 скиллов) | — | В движке правила подгружаются только через явный `/new-funnel` |
| Слэш-команды | `.claude/commands/` — **20 файлов, 8 218 строк**; 16 `quiz-*` = 7 072 (в т.ч. `quiz-screen.md` 1 569) | 3 файла, **294 строки** | Прозы в ~55 раз меньше — ровно тот ROI, который обещал план §8.5 («на data-DSL остаются 3 содержательных шага»). Но часть шагов пропала не потому, что стала ненужной, а потому что не написана (copy, theme, images, screen) |
| Lock-файл скиллов | `skills-lock.json` (11 строк) фиксирует **только** `next-browser` (`vercel-labs/next-browser`, по хешу). `quiz-funnel-factory` не залочен; grep `skills-lock|skillsLock` по репо → **0 попаданий**, нигде не enforce-ится | нет | Версионирования authoring-прозы нет ни там, ни здесь |
| Реальный CI-гейт авторинга | `.github/workflows/code-funnels-validate.yml` (132 стр.): scoped tsc + jest + lint; триггер включает `.claude/skills/quiz-funnel-factory/**` (`:45`); два списка `paths` и аргументы шагов синхронизируются **вручную** (комментарий `:22-28`) | `ci.yml` + `Dockerfile:36-41` | У движка гейт строже и без ручной синхронизации: `validate` схемный, а не grep по TSX |
| Единый «как добавить воронку» | **нет**; процедура растащена по `QUIZ_FACTORY_SETUP.md` (90 стр., marketer-facing, есть живой `<!-- TODO -->` на `:34`), `QUIZ_FACTORY_FLOW.md` (609 стр.), `SKILL.md`, `workflow.md`, `quiz-start-code.md` + 16 команд. `docs/funnel-builder/` — 66 записей, 33 из них `CODE_FUNNELS_*.md`, `KNOWN_ISSUES.md` ~51 КБ. Слово `kilo` встречается в 41 файле | `README.md:1400-1430` + `new-funnel.md` | **У движка с этим лучше**: одна точка входа в README + одна команда |
| Шаблон | `code-funnels/_template/` — 12 записей TS/TSX/SCSS (плюс `money/_template*`), ~60-81 новый файл на воронку (`gimli2-authoring-inventory.md:6.2`) | 3 JSON-файла | Главный выигрыш подтверждается |
| Скиллы/агенты по воронкам в `claude-agents` | — | `.claude/skills/` (56 записей) и `.claude/agents/` (10) — **ни одного funnel-related** | Проверено `ls`. Оркестрации авторинга снаружи движка нет |

---

## 2. Gaps (с доказательствами)

**G1. Пост-покупочная цепочка — единственная часть воронки, у которой нет ни шаблона, ни живого примера, ни авторингового шага, при том что именно она списывает деньги.**
`src/registry.ts:139` `const CHAINS: Record<string, unknown> = {}`; `scripts/scaffold-funnel.ts` не пишет `post-purchase.json` (grep → 0);
`.claude/commands/new-funnel.md:8` — единственное упоминание, в форме «если бриф просит».
При этом схема на 230 строк (`schema/post-purchase.schema.ts`) и валидатор на ~90 строк (`scripts/validate-funnels.ts:452-530`) готовы и ждут конфиг.
**Следствие:** цель «quiz → email → sales → upsell → downsell → thank-you из брифа» сегодня недостижима: скаффолд доводит до sales, дальше агент пишет с нуля файл, который проходит только те проверки, которые не может увидеть схема.

**G2. Нет `CLAUDE.md` и нет SKILL — правила существуют, но не подгружаются.**
`.claude/` содержит только `commands/` (`ls`); `find -maxdepth 2 -name CLAUDE.md` → пусто.
Шаг 6 `funnel-engine-docker-migration.md:160-168` явно требовал «`README.md`, `CLAUDE.md` в funnel-engine» — README сделан, `CLAUDE.md` нет.
Монорепа решает это `autoLoad`-глобами (`quiz-funnel-factory/SKILL.md:5-9`).
**Следствие:** сессия, которая правит `funnels/general-english/sales.json` не через `/new-funnel`, не знает ни про «никаких цен в копии», ни про пять комплаенс-правил, ни про pinned-English. Валидатор поймает часть — но только на `pnpm validate`, который в `pnpm build` **не входит** (`package.json:11`).

**G3. `pnpm validate` не входит в `pnpm build`.**
`package.json:11` `"build": "pnpm images && pnpm typecheck && pnpm bundle"`. Валидатор вызывается только в `Dockerfile:36-41`.
**Следствие:** локальный `pnpm build` собирает `dist/` из невалидированных конфигов. Гейт есть, но не на каждом пути к артефакту.

**G4. Продуктовые id не верифицируются, и нигде не написано, где их брать.**
В `scripts/validate-funnels.ts` нет ни `fetch(`, ни флага `--live` (grep `live|fetch(|pricing-rule|walhalla`). Единственная защита — regex `REPLACE_ME|CHANGE_?ME` (`:595`).
В репо нет ни одного упоминания Walhalla/MCP (grep по `.claude/commands/` и `README.md` → только «Ask for the product ids», `new-funnel.md:132`).
План §8.2 п.8 требовал commerce-fidelity: сверку `paymentMode`/периода/`firstPayment` с живым каталогом — ровно того гейта, отсутствие которого в проде дало «Not a subscription» на 28-дневной подписке.
**Следствие:** валидный id неправильного продукта проходит все проверки. Плюс `plans[].amount/firstPayment/secondPayment` в скаффолде (`:167-181`) — авторские числа, которые схема принимает, а живой каталог может опровергнуть.

**G5. Атрибуция статистики ловится только цифрами.**
`scripts/validate-funnels.ts:645` — `hasStat` = regex `\b\d{1,3}\s?%|\b\d+\s?(million|thousand|k\+)\b`.
**Следствие:** «nine in ten learners», «двое из трёх» и любая статистика прописью проходит без footnote — а это ровно тот бакет, который в проде оказался самым дорогим (`gimli2-authoring-inventory.md` §6.6: комплаенс — 5 коммитов, все после запуска, все на живом трафике).

**G6. Countdown-таймер — только WARN.**
`scripts/validate-funnels.ts:622-632` (`'WARN', 'compliance/countdown'`), при том что схема поле разрешает (`schema/sales.schema.ts:434`).
`new-funnel.md:41-45` говорит «не авторить», но это проза.
**Следствие:** правило №1 из пяти — единственное из пяти, которое не блокирует. Ср. cap апселлов, который вынесен в схему и **отказывает** (`schema/post-purchase.schema.ts:219-222`).

**G7. Превью на ветку отсутствует, и ни один CI-путь не даёт хоста под черновик.**
`ci.yml` собирает образ в локальный тег (`load: true`, `tags: funnel-engine:ci`) и никуда не деплоит; `build-deploy-k3s.yml` даёт dev только на push в `main`, а `ci-test/**` принудительно `build_only=true`.
Роут `?_preview` не существует (grep по `src/` → только `_ftc`).
Признано осознанной потерей: `README.md:1567-1571`, `funnel-engine-docker-migration.md` «Что теряем и принимаем».
**Следствие:** «маркетолог смотрит черновик» = либо `pnpm docker:run` на своей машине (то есть Docker, `.env`, терминал), либо мердж в `main`. Второе означает, что ревью воронки происходит **после** публикации на dev.

**G8. Скриншотного гейта нет — а в проде это был единственный работающий гейт против дизайн-регрессий.**
План §8.4 п.3 требовал headless-рендер каждого экрана и секции × (локаль × гео) в артефакты PR. В `ci.yml` такого шага нет.
`gimli2-authoring-inventory.md:1045` (Category I) — в проде именно он ловил регрессии, и на data-DSL он **дешевле**, а не дороже (экраны перечислены в `flow`, рендер серверный).

**G9. Реестр патчится строковой заменой, а не генерируется.**
`scripts/scaffold-funnel.ts:268-296` — 4 «иглы»; при несовпадении `process.exit(1)` с просьбой дописать руками.
Локали и цепочки не автоматизированы вовсе (`translate-page.md:44-56` — правка `CATALOGS` руками).
План §8.1 требовал `src/registry.generated.ts`.
**Следствие:** «добавить воронку = code change» сохранилось; спасает только `checkRegistryDrift` (`scripts/validate-funnels.ts:82`).

**G10. Публикация копирайта = два пайплайна и новый образ.**
`src/registry.ts:1-4` статические импорты → `scripts/bundle.mjs` инлайнит JSON в `dist/`.
Правка одного заголовка: коммит в `main` → `ci.yml` (docker build с полным набором гейтов + контейнер + e2e) → `build-deploy-k3s.yml`: `setup` (2 мин) → `build` на `hetzner-amd64` (до 30 мин) → ECR → `deploy` (до 20 мин, `wait-argocd-sync` 480 с). Прод — отдельный ручной `workflow_dispatch`.
Причина не сделано названа прямо и она правильная (`README.md:1558-1566`): внешний источник конфига обойдёт `pnpm validate`.
**Следствие:** для контентного цикла (в проде — 65 пост-лончевых коммитов, 14 из них копия/локали) это дорого, и это упирается в дизайн «валидация при публикации + отказ при чтении», который ещё не спроектирован.

**G11. Логов движка нет в Loki — то есть проверить воронку после запуска сейчас нечем.**
`src/analytics/log.ts:58` пишет корректно, `README.md:855` даёт готовый запрос, но `gimli2-full-migration-plan.md` §5: «логов движка нет ни в одном k3s-датасорсе Loki». Лейбл `service_name=funnel-engine-{env}` был передан в handoff (`funnel-engine-docker-migration.md:176-179`), но не подтверждён.
Алертов нет. `warnOnMissingGeo` (`src/http.ts:100`) — единственный self-check, и его тоже видно только в логе.
**Следствие:** «Amplitude отвечает 200 с `events_ingested: 0`» неразличимо от «не отправили».

**G12. Ни одной воронки через vibe-coding.**
`funnels/` = один `general-english`; `git log -- funnels/` — 3 коммита, все движковые (`3fc6e39`, `0938978`, `776ba91`).
Блокеры первого реального брифа, по фактам:
(а) самого брифа нет (`gimli2-full-migration-plan.md` §4a, §5 «Продукт и контент»);
(б) реальные product id — нет документированного пути получения (G4);
(в) картинки — нет ни генерации, ни скилла, ни каталога `assets/<id>/` от скаффолда;
(г) `post-purchase.json` — нет шаблона (G1);
(д) нет хоста под черновик до мерджа (G7);
(е) GrowthBook `us_pricing_now_then` и `ftc_soft_changes` резолвятся false для всех стран → US-раскрытия достижимы только через `?_ftc=hard|soft|off` (`README.md:1596-1612`) — это регуляторный риск, а не косметика.

**G13. Валидатор и скаффолд не покрыты тестами.**
`tests/` — 8 сьютов про рантайм (chain, handoff, locale, resolve, screens, sections, session, e2e). Ни одного кейса на `scripts/validate-funnels.ts` или `scripts/scaffold-funnel.ts`.
**Следствие:** единственный гейт между генерацией и живым трафиком не защищён от регрессии в себе самом. У этого есть прецедент: `gimli2-full-migration-plan.md:150-152` фиксирует, что уже пришлось править сам валидатор дважды (корень считался от cwd; проверка полей варианта сравнивалась с инстансом вместо схемы).

**G14. Дрейф комментариев и README по следам ухода с Workers (5 мест).**
`README.md:1368` «`pnpm deploy` runs it automatically» против `README.md:125` «There is no deploy command»;
`scripts/test.ts:4` «needs a running Worker»;
`scripts/i18n.ts:20-24` «types is `@cloudflare/workers-types` alone» (неправда с `235c6bf`);
`src/registry.ts:17` «MVP-1 adds a KV read-through cache» (KV удалён вместе с Workers);
`scripts/validate-funnels.ts:20-21` и `scripts/scaffold-funnel.ts:26` ссылаются на удалённый `scripts/node-shims.d.ts`.
Плюс `README.md:769-778` перечисляет 8 групп валидатора против 11 в коде.

---

## 3. Открытые вопросы

1. **Кто пишет `post-purchase.json` для первой воронки и откуда берёт продукты?** Схема и валидатор готовы, `CHAINS` пуст. Нужно решение: делаем ли шаблон в скаффолде (с `REPLACE_ME`-продуктами, как в sales), или апселлы вне MVP-1 (в проде у 3 из 5 живых money-модулей `/delta` нет — `gimli2-full-migration-plan.md` §5).
2. **Product-id lookup: MCP или человек?** План говорил «через Walhalla MCP», в репо об этом ноль. Если MCP — это надо (а) записать в `CLAUDE.md`/SKILL, (б) добавить `pnpm validate --live` с проверкой `paymentMode`/периода. Если человек — нужен формат заявки и SLA, иначе `/new-funnel` всегда будет заканчиваться «спроси у людей».
3. **Таймер: WARN или FAIL?** Открытый вопрос №7 инвентаризации до сих пор открыт. Если политика «таймера на sales-page не будет» — правило надо унести в схему, как унесли cap апселлов, и тогда четыре из пяти правил станут машинными.
4. **Куда девать превью?** Три варианта: (а) ветка-неймспейс в k3s с хостом (вопрос к Богдану, `gimli2-full-migration-plan.md` §4a), (б) короткоживущий деплой на тот же dev-хост под своим `funnelId`, (в) считать нормой `docker run` у автора и вложиться в скриншотный артефакт PR (G8). (в) — самый дешёвый и закрывает не превью, а ревью, что для маркетолога не одно и то же.
5. **Публикация без деплоя: config map, Strapi или ничего?** Требование «валидация при публикации + отказ при чтении» сформулировано (`README.md:1558-1566`), дизайна нет. Пока его нет, контентный цикл стоит один образ на правку — и это надо либо принять как MVP-1, либо заводить как отдельную задачу с оценкой.
6. **`CLAUDE.md`: что в него положить, чтобы не расползлось в 7 896 строк, как `quiz-funnel-factory`?** Минимум: пять правил, no-prices-in-copy, Funnel Core allow-list, «не писать код — сообщать о нехватке DSL», bash/pnpm-инварианты. Всё остальное — ссылками на README и `new-funnel.md`.
7. **Кто владелец валидатора и какой SLA на «нужна новая секция»?** Вопрос №14 инвентаризации. Сейчас закрытый набор секций (`new-funnel.md:94-102`) — фича; он же станет узким местом на первом же брифе, который просит что-то своё.
8. **Логи в Loki: подтвердить лейбл и датасорс до первого брифа.** Иначе первая воронка запустится без возможности проверить, доехали ли события — при том что Amplitude на неверный ключ отвечает 200.
9. **Нужен ли `funnels/<id>/README.md` с брифом?** План §8.1 требовал; сейчас бриф не сохраняется нигде. Для ревью и для повторного `/funnel-copy` это единственный источник «что вообще заказывали».
10. **GrowthBook FTC-флаги** — не authoring-вопрос, но он блокирует приёмку: пока `us_pricing_now_then`/`ftc_soft_changes` false для всех стран, любая воронка, сделанная из брифа, поедет без US-раскрытий, и валидатор этого не увидит (он проверяет наличие текста в конфиге, а не то, отрендерится ли он).
