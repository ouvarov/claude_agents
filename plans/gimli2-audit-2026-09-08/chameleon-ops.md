# chameleon: как он задеплоен и чем живёт, и что из этого должен повторить funnel-engine

Только чтение. Каждое утверждение — с путём и номером строки либо выводом команды.
Пути монорепы указаны от `/Users/uvarovalexandr/myProject/promova.com_monorepo/`,
пути движка — от `/Users/uvarovalexandr/myProject/funnel-engine/`.

---

## 1. Что такое chameleon и что он обслуживает

### Одно приложение — пять-семь прод-деплоев

`apps/funnels/chameleon` — единственное приложение в `apps/funnels/`
(`ls apps/funnels` → `chameleon`). Next.js 16.2.7, App Router, React 19.2.7
(`apps/funnels/chameleon/package.json:39-45`). Пакет называется `chameleon`
(`package.json:2`), scripts: `build` = `NODE_OPTIONS='--max-old-space-size=8192' next build`
(`package.json:8`), `build:docker` — то же с `NODE_ENV=production` (`package.json:10`).

Ключевой факт: **из одного и того же билда собирается несколько прод-доменов,
разница только в наборе env из Vault.** В `.github/deployment-config-hetzner.yaml`
пять проектов указывают `env_path: apps/funnels/chameleon` и
`dockerfile: apps/funnels/chameleon/Dockerfile`: строки `37-38` (spanish-boost),
`60-61` (english-improve), `83-84` (ai-academy), `106-107` (english-academy),
`156-157` (learn-promova), `184-185` (skoool-promova). Это же сказано явно:

- `.github/workflows/bundle-gate-chameleon.yml:10-12` — «five of the seven prod
  deployments are the same apps/funnels/chameleon build (only the Vault env set
  differs)»;
- `docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md:26-27` — «Every funnel domain runs
  the same chameleon app, differing only by `NEXT_PUBLIC_CURRENT_DOMAIN`».

Домены прописаны в вызовах reusable-workflow:

| проект | домен | строка |
|---|---|---|
| student | `promova.com` | `.github/workflows/deploy-hetzner.yml:193` |
| spanish-boost | `spanish-boost.com` | `deploy-hetzner.yml:216` |
| english-improve | `english-improve.com` | `deploy-hetzner.yml:238` |
| ai-academy | `promova-ai-academy.com` | `deploy-hetzner.yml:260` |
| english-academy | `promova-english-academy.com` | `deploy-hetzner.yml:282` |
| mindpost (не chameleon) | `mindpost.news` | `deploy-hetzner.yml:304` |
| learn-promova | `''` — сабдомен promova.com | `deploy-hetzner.yml:326` |
| skoool-promova | `''` — сабдомен, ECS-сервиса ещё нет | `deploy-hetzner.yml:341-343`, `deployment-config-hetzner.yaml:177-181` |

### Роль рядом с `apps/student`

`apps/student` — это `promova.com` (`deploy-hetzner.yml:193`), полный сайт:
кабинет, блог, SEO-лендинги, ~3559 файлов против 200 у chameleon
(`bundle-gate-chameleon.yml:12-13`). chameleon — тонкий бандл только под воронки,
на отдельных рекламных доменах. Его корень редиректит сразу в воронку:
`apps/funnels/chameleon/next.config.ts:337-345` — `/` → `/o/app-bm-v3`, `permanent: true`.
У student такого редиректа нет.

### /kilo и /sierra: их отдаёт ТОТ, ЧЕЙ ДОМЕН

Роут-группы у обоих приложений совпадают буквально:

```
$ find apps/funnels/chameleon/app -maxdepth 3 -type d
… app/[lang]/(code-funnel)/kilo
… app/[lang]/(funnel-builder)/{alpha,delta,echo,foxtrot,golf,o,romeo,sierra,whiskey,xray}

$ find apps/student/app -maxdepth 3 -type d
… app/[lang]/(code-funnel)/kilo
… app/[lang]/(funnel-builder)/{alpha,confirmation-banner,delta,echo,foxtrot,golf,o,romeo,sierra,whiskey,xray}
```

Файлы страниц — почти байт в байт. `diff` двух `kilo/[funnel_id]/[[...screen_id]]/page.tsx`
даёт ровно два расхождения, оба комментарии; в student-версии на
`apps/student/app/[lang]/(code-funnel)/kilo/[funnel_id]/[[...screen_id]]/page.tsx:22-29`
написано прямым текстом:

> MIRROR of `apps/funnels/chameleon/app/[lang]/(code-funnel)/kilo/[funnel_id]/[[...screen_id]]/page.tsx`
> — the promova.com mount of the SAME shared code-funnel runtime
> (`packages/features/FunnelBuilder/code-funnels/**`), so every registered code
> funnel is reachable on both domains. All hrefs the runtime builds are relative
> (`/${locale}/kilo/...`, `/${locale}/sierra/...`), so quiz navigation and the
> money-path handoff stay on whichever domain the visitor entered.

То есть **`/kilo/<funnel_id>` и `/sierra/<slug>` отдаёт и student, и chameleon —
кто именно, решает только домен запроса**. `promova.com/en/kilo/general-english`
— это student (Vault-путь `student`, `deployment-config-hetzner.yaml:14-25`);
`english-improve.com/en/kilo/general-english` — это chameleon с env-набором
`english-improve`. Реестр воронок общий (`packages/features/FunnelBuilder/code-funnels/funnelRegistry.ts`
содержит `general-english`), поэтому привязки «воронка → домен» для code-funnels
не существует вовсе: `docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md:243-246` —
«after merge the funnel answers on every funnel domain and on promova.com —
there is no funnel-to-domain assignment to make».

Что домен всё-таки меняет — это три env:

- `DOMAIN_NAME = process.env.NEXT_PUBLIC_CURRENT_DOMAIN || 'promova.com'`
  (`packages/config/constants/common.ts:141-142`);
- `IS_MAIN_DOMAIN = process.env.NEXT_PUBLIC_IS_MAIN_DOMAIN === 'true'`
  (`common.ts:126`);
- `ONBOARDING_ENTRY_ROUTE = process.env.NEXT_PUBLIC_ONBOARDING_ENTRY_ROUTE ?? 'o'`
  (`common.ts:283-284`), `DEFAULT_FUNNEL_ID = 'app-bm-v3'` (`common.ts:287`).

И на них навешена доменная фильтрация воронок:
`packages/utils/middleware/localization/handleLocaleRedirect.ts:32-34` — если
`IS_MAIN_DOMAIN`, берём `funnelId` из URL как есть, иначе прогоняем через
`isFunnelBelongsToDomain`. Тот
(`packages/utils/middleware/isFunnelBelongsToDomain.ts:16-24`) тянет allow-list по
домену и, если запрошенной воронки в списке нет, редиректит на первую из списка.
Список приходит по HTTP:
`packages/utils/fetchChameleonFunnelsAllowList.ts:27` —
`${process.env.CF_FUNNELS_ALLOWLIST_API_BASE}/read?domain=${DOMAIN_NAME}`,
токен `CF_FUNNELS_ALLOWLIST_AUTH_TOKEN` (`:11`). Важно: `CF` здесь — Code
Funnels, не Cloudflare.

Прочие роуты chameleon (`find … -maxdepth 3`):
`(funnel-builder)/o|foxtrot|alpha|delta|echo|golf|romeo|whiskey|xray`,
`(funnel-builder)/sierra/[...slug]` — sales-страница
(`apps/funnels/chameleon/app/[lang]/(funnel-builder)/sierra/[...slug]/page.tsx:7`
использует `SALES_PAGE_ENTRY_ROUTE`), `[lang]/terms/*` (шесть юридических
страниц, тянутся из Strapi: `apps/funnels/chameleon/app/[lang]/terms/privacy-policy/page.tsx:7,30`
через `FbMultiDomainTermsPages.PRIVACY_POLICY`), `[lang]/contact-us`,
`[lang]/config-modal`, `[lang]/error-sim`, и восемь route handlers:
`api/auth/sign-in`, `api/auth/sign-out`, `api/cms/webhooks/revalidate-app-structure`,
`api/cms/webhooks/revalidate-growthbook`, `api/domain-pixel`, `api/health`,
`api/legal/checkout-text`, `api/legal/footer-text`.

Middleware — переэкспорт общего: `apps/funnels/chameleon/proxy.ts:1-3`
(`export const proxy = baseMiddleware`), matcher на `:6-15` с исключением
`lp/.*` (статические web2app-преленды) и явными `/foxtrot/:path*`, `/o/:path*`.

README у chameleon — нетронутый шаблон `create-next-app`
(`apps/funnels/chameleon/README.md`, полезного нуля); реальная документация —
`apps/funnels/chameleon/CLAUDE.md` и `docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md`.

---

## 2. Как он деплоится

### Прод: Hetzner ECS Anywhere за Cloudflare Tunnel

Живой путь — `.github/workflows/deploy-hetzner.yml`, триггер `push` в `main`
(`:11-13`) плюс `workflow_dispatch`. Топология в шапке файла, `:5-6`:

> Infrastructure (Terraform): devops-control-hub/infra/terraform/envs/cfTunnelECSenywhere-frontend
> Architecture: Internet → Cloudflare Tunnel → Traefik → ECS Container (Hetzner)

То же продублировано в `.claude/docs/build-deployment.md:55` и
`docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md:27-29` («Production is Hetzner ECS
Anywhere … Vercel carries previews. A green Vercel check is not a shipped domain»).

Остальные workflow с именем «production» отключены: у
`deploy-production.yml:4-5` `push:` закомментирован, остаётся только
`workflow_dispatch` (`:9`); то же у `deploy-production-optimized.yml:9` и
`deploy-production-parallel.yml:9`. `.github/deployment-config.yaml` (ECS
multi-regional, `us-east-1` + `eu-central-1`, кластер `prod-promova-frontend-ecs`)
относится к этому выключенному пути.

Каждый проект вызывает `deploy-single-project-hetzner.yml`
(`deploy-hetzner.yml:186`, `:206`, `:228` …). Внутри:

- конфиг: `CONFIG_FILE: .github/deployment-config-hetzner.yaml`
  (`deploy-single-project-hetzner.yml:56`), парсится своим action
  (`:92`, `./.github/actions/parse-deployment-config`);
- **env: Vault → файл `.env` до docker build.**
  `deploy-single-project-hetzner.yml:98-106` вызывает
  `./.github/actions/vault-to-env` с `env-file: <env_path>/.env`,
  `vault-mount: monorepo-frontend-prod`, `secret-path: <проект>`. Action
  (`.github/actions/vault-to-env/action.yml:46-69`) читает
  `<mount>/data/<path>` и раскладывает `.data.data` в `KEY=VALUE`,
  отсортированный по ключу — сортировка нужна, чтобы не ломать turbo-кэш
  (`:64-68`). Vault-пути перечислены в `.github/DEPLOYMENT_README.md:104-109`;
- сборка: `docker build -f apps/funnels/chameleon/Dockerfile --build-arg GIT_HASH=<sha>`
  плюс `TURBO_TOKEN/TEAM/API` (`deploy-single-project-hetzner.yml:154-160`),
  до трёх попыток с релогином в ECR (`:144-175`);
  ECR-реестр `302263049735.dkr.ecr.us-east-1.amazonaws.com` (`:54`),
  тег `default-<commit_sha>` (`:137`);
- Dockerfile: `apps/funnels/chameleon/Dockerfile` —
  `node:22-alpine` (`:2`), pnpm 11.4.0 + turbo 2.9.14 (`:4`, `:7`),
  `turbo prune chameleon --docker` (`:13`), `NEXT_PRIVATE_STANDALONE=true` (`:18`),
  `COPY apps/funnels/chameleon/.env ./apps/funnels/chameleon/.env` (`:35` — вот
  куда попадает Vault-файл), `pnpm exec turbo run build --filter=chameleon...` (`:38`),
  runtime-стейдж non-root `nextjs:nodejs` (`:49-51`),
  `EXPOSE 3000` / `ENV PORT=3000` / `HOSTNAME=0.0.0.0` (`:56-58`),
  `CMD ["node", "apps/funnels/chameleon/server.js"]` (`:60`),
  `NODE_OPTIONS="--max-old-space-size=896 --max-semi-space-size=64"` (`:42`);
- статика: отдельно выкладывается в S3 + инвалидируется CloudFront
  (`deploy-single-project-hetzner.yml:211-289`): бакет
  `prod-promova-frontend-anywhere-<project>-static-cdn` (`:216`), из образа
  выковыриваются `.next/static` и `public` (`:254-258`),
  `aws s3 sync --cache-control "public, max-age=31536000, immutable"` (`:270-274`),
  затем `aws cloudfront create-invalidation --paths "/builds/<sha>/*"` (`:279-283`).
  Distribution ID захардкожены на `:220-228` (`spanish-boost` → `E2WB247HAZCOJW` и т.д.).
  R2-вариант того же шага закомментирован (`:175-209`, «migrated to S3 + CloudFront»);
- деплой: `./devops-actions/.github/actions/deploy-to-ecs-v2` из приватного
  `Promova/devops-reusable-actions` (`:324-327`, `:339-356`), с
  `wait-for-service-stability: 'true'` и — второй раз — Vault:
  `create-env-file: 'true'` + `vault-mount` / `secret-path` (`:352-356`). То есть
  env приезжает дважды: на билд (для инлайна `NEXT_PUBLIC_*`) и в task definition
  на рантайм;
- проверка откатов: сверяет image в PRIMARY-деплойменте с ожидаемым и падает,
  если ECS откатился (`:358-390`);
- **purge Cloudflare после успешного деплоя**: job `purge-cache`
  (`:417-441`), только если `inputs.domain != ''`; action
  `.github/actions/cloudflare-cache-purge/action.yml` находит zone по имени
  домена (`:40`) и делает `purge_everything` (`:72-75`), токен —
  `secrets.CLOUDFLARE_API_TOKEN_CACHE` (`deploy-hetzner.yml:203`).

`apps/funnels/chameleon/ignore-build.sh` — Vercel-only гейт (читает
`VERCEL_GIT_COMMIT_REF`/`VERCEL_GIT_COMMIT_MESSAGE`, `:32-39`): превью собирается
только по флагу `-deploy` в сообщении коммита или на защищённой ветке (`:49-79`).

### Stage: k3s + ArgoCD — тот самый стек, на котором стоит движок

`.github/deployment-config-stage-k3s.yaml:1-13` описывает именно то, что
funnel-engine уже использует:

> Pipeline: Vault → Docker build (amd64, self-hosted "frontend" runner) → ECR push →
> update-gitops (Promova/promova-gitops) → ArgoCD auto-sync
> values: apps/&lt;service&gt;/dev/server-values.yaml, chart: charts/internal-service,
> AppProject: frontend-stage, Cluster: temporal-dev-k3s (Hetzner Nuremberg),
> Namespace: frontend-stage, ECR: dev-promova-&lt;service&gt;-ecr,
> Vault: monorepo-frontend-dev/&lt;service&gt;

`deploy-single-project-stage-k3s.yml:45-47` — `GITOPS_REPO: Promova/promova-gitops`,
`GITOPS_ENV: dev`, `GITOPS_COMPONENT: server`; `:267-274` — `update-gitops` с
`service: <project>`, `environment`, `components`; ArgoCD-приложение в саммари —
`https://argocd-eu.promova.in/applications/<project>-dev-server` (`:309`).
Движок ходит той же дорогой: `.github/workflows/build-deploy-k3s.yml:245-265`
(`update-gitops`, `service: gimli`, `components: server`, `gitops_repo: Promova/promova-gitops`),
приложения `gimli-dev-server` / `gimli-prod-server` (`:274-278`),
`wait-argocd-sync` (`:286-293`).

Существенная разница по env: chameleon и на k3s печёт `.env` **на билде**
(`deploy-single-project-stage-k3s.yml:93-101`), потому что Next инлайнит
`NEXT_PUBLIC_*` в чанки — это прямо оговорено в
`bundle-gate-chameleon.yml:37-40`. Движок не печёт ничего:
`funnel-engine/.github/workflows/build-deploy-k3s.yml:3-7` — «gimli has ZERO
build-time configuration: no Dockerfile ARG, and every one of its ~20 env vars is
read at runtime via process.env … no Vault step, no .env generation and no --build-arg».
Это в пользу движка: один образ на все окружения.

`.env*` в репозитории chameleon нет — они в `.gitignore`
(`apps/funnels/chameleon/.gitignore:21-23`: `.env`, `.env*`).

---

## 3. Логи и error reporting

Короткий ответ: **у chameleon нет серверного error reporting вообще.**
Браузерный RUM и серверные логи — два не пересекающихся конвейера, и второй
заканчивается в stdout контейнера, дальше репозиторий молчит.

### (а) Где оказывается серверная ошибка

1. Программного канала нет. Хук Next.js `onRequestError` в монорепе не
   встречается ни разу (grep по `apps` + `packages` + `docs` — 0 вхождений).
   Sentry нет (`@sentry/` — 0 вхождений, включая `pnpm-lock.yaml`), pino нет,
   winston нет, Datadog/New Relic нет. Структурированного серверного логгера в
   репозитории не существует.
2. Faro на сервере — намеренный no-op. `packages/utils/faroBuffer.ts:59` —
   `if (!FARO_ENABLED || typeof window === 'undefined') return`; то же в
   `packages/observability/faro/bootstrap-faro-client.ts:20`; ещё один guard —
   `packages/utils/reportApiError.ts:187`. Это зафиксировано комментарием:
   `packages/features/FunnelBuilder/pages/Sales/v2/utils/fetchSalesPageCommerce.ts:71-76`
   — «runs in an RSC (server), where sendFaroError/withFaro is a deliberate no-op
   — a structured console.error is the reporting channel here».
3. Значит единственный носитель — голый `console.error` / необработанный throw в
   stdout PID 1 (`apps/funnels/chameleon/Dockerfile:60`). Реальные места:
   `app/api/legal/footer-text/route.ts:56`, `app/api/legal/checkout-text/route.ts:56`,
   `app/api/cms/webhooks/revalidate-app-structure/route.ts:87`,
   `app/api/cms/webhooks/revalidate-growthbook/route.ts:30`,
   `app/[lang]/(code-funnel)/kilo/[funnel_id]/[[...screen_id]]/page.tsx:51`.
   Политика описана там же, `:48-49`: «this is server-side, so it lands in the
   platform logs rather than a visitor's console».
4. Все три error boundary — клиентские и уходят в Faro, то есть в браузерный
   поток: `app/global-error.tsx:1,12-14` (`boundary: 'global'`),
   `app/[lang]/error.tsx:1,14-16` (`'top'`),
   `app/[lang]/(code-funnel)/error.tsx:1,24-26` (`'code-funnel'`), все через
   `packages/utils/reportBoundaryError.ts:66,78` → `withFaro`.
5. Единственный в монорепе роут, форвардящий логи по HTTP, — **у student, не у
   chameleon**: `apps/student/app/api/logs/route.ts:39-46` пушит в
   `${NEXT_PUBLIC_LOKI_URL}/loki/api/v1/push` с `X-Scope-OrgID: NEXT_PUBLIC_LOKI_ORG_ID`;
   вызывается только из браузера (`packages/api/sendLogMessage.ts:7`,
   относительный `fetch('/api/logs')`). У chameleon такого роута нет, вызов
   упал бы в 404.

### (б) Стрим / лейбл / дашборд

- Серверная телеметрия, которую приложение само маркирует, — только трейсы и
  профили, не логи: `packages/observability/otel/registerInstrumentation.ts:6-14`
  (`registerOTel({ serviceName: process.env.OTEL_SERVICE_NAME || 'unknown_service:node' })`),
  `packages/observability/pyroscope/initPyroscope.ts:2-3` (no-op без
  `PYROSCOPE_SERVER_ADDRESS`), `:11` (`appName` = `OTEL_SERVICE_NAME`), `:15`
  (тег `git_hash` из `GIT_HASH`). Подключено через
  `apps/funnels/chameleon/instrumentation.ts:1-5` (весь файл — 5 строк) и
  `next.config.ts:109` (`serverExternalPackages: ['@opentelemetry/instrumentation', '@pyroscope/nodejs']`).
  Имена env: `turbo.json:77` (`OTEL_SERVICE_NAME`), README `:235-238`
  (`OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_EXPORTER_OTLP_PROTOCOL`,
  `OTEL_RESOURCE_ATTRIBUTES`). OTLP-**логов** нет.
- Единственные названные Loki-лейблы и дашборд в репозитории — **фаровские,
  RUM-овские**: `docs/error-simulation-harness.md:104-106` — дашборд `CiroMopVz`
  («Frontend Observability»), переменная `$env`; `:112-118` — LogQL
  `sum by (kind) (count_over_time({app_environment="stage"}[15m]))` и
  `{app_environment="stage"} | logfmt | kind="event" |= "customError"`.
  Лейблы `app_environment` и `kind` относятся к браузерным сигналам, не к
  логам контейнера.
- **Куда уходит stdout из ECS — репозиторий ответить не может.** Деплой берёт
  существующий task definition, jq-ом подменяет только `.image` и регистрирует
  новую ревизию (`deploy-single-project.yml:221-234`), так что `logConfiguration`
  наследуется из объекта, которого в git нет. Grep по всему репо по
  `alloy|loki|firelens|awslogs|logConfiguration|fluentbit|log-driver|cloudwatch|log_group`
  не дал ни одного конфига агента или драйвера; про Grafana Alloy упоминаний нет
  вообще. Stage целиком управляется внешним `Promova/promova-gitops`
  (`deployment-config-stage-k3s.yaml:5-11`).

### (в) Браузерный RUM отдельно от серверных логов

Да, полностью. `packages/observability/faro/frontend-observability.ts:1`
(`'use client'`), `:39` — единственный `initializeFaro` в репозитории, `:40` —
коллектор `${process.env.NEXT_PUBLIC_FARO_URL}/collect`, `:42` —
`NEXT_PUBLIC_FARO_API_KEY`, `:44` — `app.name` из `NEXT_PUBLIC_FARO_APP_NAME`,
`:45` — `NEXT_PUBLIC_FARO_APP_NAMESPACE`, `:46` — `app.version` из
`VERCEL_DEPLOYMENT_ID`, `:50-53` — `environment` из
`NEXT_PUBLIC_FARO_ENVIRONMENT || NEXT_PUBLIC_VERCEL_ENV || NODE_ENV`, `:75` —
`beforeSend` с редакцией JWT (`faro/before-send.ts:21-27`). Гейт:
`packages/config/constants/common.ts:245-246` —
`FARO_ENABLED = NEXT_PUBLIC_FARO_ENABLED === 'true' || LIVE_MODE`.
Ленивая загрузка из `apps/funnels/chameleon/instrumentation-client.ts:13-24`
(там же PostHog session replay, `:29`, и auth-сервис, `:33`).
Amplitude — тоже только браузер (`packages/utils/amplitude/lazyClient.ts:4,23`,
серверного SDK нет).
`packages/utils/sendFaroError.ts:91` — `faro.api.pushEvent('customError', …)`;
`packages/features/FunnelBuilder/utils/faroReports.ts:3-7` требует статичных
строк сообщений, «чтобы идентичные падения агрегировались в одну Loki-подпись».

### Что из этого уже есть у движка

Движок пишет JSON-строки в stdout осознанно, а не по остаточному принципу:
`funnel-engine/src/analytics/log.ts:21,55` (`kind: 'funnel_event'`), `:68`
(`console.error('event log failed', …)`), `funnel-engine/src/http.ts:151-154`
(`kind: 'geo_missing'`), `funnel-engine/README.md:1562` — «logs | JSON lines on
stdout; events carry `"kind":"funnel_event"`». Лейбл для Loki уже согласован в
плане переезда: `plans/funnel-engine-docker-migration.md:178-179` —
`service_name=funnel-engine-{env}`. RUM у движка нет вовсе: grep по
`faro|sentry|window.onerror|unhandledrejection` в `funnel-engine/src` даёт одно
попадание, и то — комментарий про чужой шум (`src/checkout.ts:115`).

---

## 4. На какие настройки Cloudflare код опирается

### Опирается по-настоящему — три вещи

**1. Гео-заголовки `cf-ipcountry` / `cf-region` / `cf-connecting-ip`.**
`packages/utils/getRequestCountry.ts:27` читает `cf-ipcountry`, `:32` выбрасывает
`XX` (не определено) и `T1` (Tor), `:33` читает `cf-region`. Комментарий `:29-31`
прямо называет дашбордную настройку:

> Cloudflare always provides cf-ipcountry in production. 'XX' means country could
> not be determined, 'T1' means Tor. cf-region requires "Add visitor location
> headers" Managed Transform enabled in Cloudflare dashboard.

`:13` — `cf-connecting-ip` приоритетнее `x-forwarded-for` (`:19`).
Фолбэк при отсутствии заголовка — платный внешний lookup:
`getRequestCountry.ts:38-39` → `packages/utils/getCountryByIp.ts:7`
(`https://pro.ip-api.com/json/{ip}`, ключ `NEXT_PUBLIC_IP_API_KEY`).
`x-vercel-ip*` в chameleon и packages не встречается ни разу.

Второе, независимое чтение того же заголовка — в middleware:
`packages/utils/middleware/handleLandingBuilderRewrite.ts:126-128`
(`cf-ipcountry` → атрибут `country` для GrowthBook). Но в chameleon эта ветка не
активна: `baseMiddleware` (`packages/utils/middleware/middleware.ts:38`)
гео-заголовки сам не читает, а хук `afterLocalization` (`:82-95`) из
`apps/funnels/chameleon/proxy.ts` не передаётся.

Что молча ломается без гео:

- персонализация воронки: `packages/features/FunnelBuilder/code-funnels/personalization/resolveCountry.ts:41-49`,
  жёсткий `GEO_TIMEOUT_MS = 2000` (`:37`) заведён именно из-за незавершаемого
  IP-lookup (комментарий `:25-35`);
- сам `/kilo`: `apps/funnels/chameleon/app/[lang]/(code-funnel)/kilo/[funnel_id]/[[...screen_id]]/page.tsx:104-109`
  (`Promise.all([resolveAdTopic, resolveRequestCountry])`), комментарий `:83` —
  «(off Cloudflare) no geo lookup»;
- **FTC/ROSCA-раскрытия**: `packages/features/FunnelBuilder/code-funnels/general-english/geoCompliance.ts:6-7` —
  при `country === undefined` возвращается `false`, то есть US-посетитель
  получает вариант «Rest of World» без строгих раскрытий (то же в
  `general-english-b/geoCompliance.ts:6`);
- региональная редакция условий: `apps/funnels/chameleon/utils/dataFetching/termsPage/getChameleonTermsSlug.ts:139`
  (`await getRequestCountry()`), ветвления US `:146`, UAE `:159`, UAE/UK/EU `:171`;
- стабильность апселлов после оплаты: `packages/features/FunnelBuilder/code-funnels/money/resolveActiveUpsells.ts:33-36`
  описывает риск 404 после покупки, когда IP-lookup на следующем запросе
  отвечает иначе; отсюда пин `FALLBACK_PACKAGE_PIN` (`:44`);
- гео-роутинг воронок: `packages/features/FunnelBuilder/code-funnels/geo/resolveCodeCountryFunnelId.ts:33-35`
  («FAILURE POSTURE» — любая неизвестность резолвится в базовую воронку).

Заметный нюанс: **consent-гейт GDPR в chameleon от `cf-ipcountry` НЕ зависит** —
он на флаге GrowthBook `COMPLIANCE_CONFIG`
(`packages/features/FunnelBuilder/code-funnels/hooks/useCodeFunnelEmail.ts:90,149`).
У движка гейт согласия завязан на страну напрямую
(`funnel-engine/src/http.ts:291,302`), поэтому для движка отсутствие заголовка
дороже, чем для chameleon.

**2. Zone Purge API — из кода приложения, не только из CI.**
`apps/funnels/chameleon/app/api/cms/webhooks/revalidate-app-structure/route.ts:12,71`
→ `packages/utils/webhooks/revalidateCloudflareUrls.ts:39` →
`packages/utils/webhooks/purgeCloudflareTag.ts:7,41` — POST
`https://api.cloudflare.com/client/v4/zones/{zoneId}/purge_cache` с типами
`url`/`prefix`/`everything` (`:1-5`, `:24-38`); без валидных креденшлов бросает
(`:15-18`), то есть CMS-вебхук ревалидации падает. Имена env —
`CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_API_TOKEN` (`purgeCloudflareTag.ts:11-12`,
`turbo.json:63-64`).

**3. Edge-исполнение `s-maxage` / `stale-while-revalidate`.**
`apps/funnels/chameleon/app/api/legal/checkout-text/route.ts:51` и
`app/api/legal/footer-text/route.ts:51` — `public, s-maxage=3600, stale-while-revalidate=7200`.
Это директивы для shared-кэша; на проксируемых доменах их обслуживает CF.
Плюс `next.config.ts:325-333` — `/content/:match*` → `public, max-age=172800, immutable`
(сам `/content` при этом ревраитится на CloudFront, `:180-187`).

### Не опирается — и это важно знать до переноса

- **Email Address Obfuscation, Rocket Loader, `data-cfasync`, `__cf_email__`,
  `email-decode`** — в `apps/funnels/chameleon` и `packages` **0 вхождений**
  (grep). Код не расшифровывает обфусцированные адреса и никак не защищается от
  Rocket Loader. То есть обфускация на `promova.com` — это чисто зонная
  настройка, наблюдаемая в выдаче, а не контракт кода. Наблюдение из
  `plans/funnel-engine-vault-env.md:109-115` (единственное расхождение текста
  legal-страниц между хостами — ровно эта обфускация) этим не отменяется:
  движок отдаёт `support@promova.com` открытым текстом
  (`funnel-engine/src/render/cookie-policy.ts:42`,
  `funnel-engine/src/render/legal.ts:301`), и никакой код на стороне chameleon
  этого не делает — делает зона.
- **WAF, Bot Management, Turnstile, `__cf_bm`, `cf-ray`** — 0 вхождений.
  Анти-бот целиком инфраструктурный, приложение не отличает
  заблокированный/challenged трафик. Косвенно об этом
  `packages/utils/middleware/prefetchSignals.ts:5-11`: prefetch классифицируется в
  middleware именно потому, что CF-аналитика (`httpRequestsAdaptiveGroups`) не
  режется по заголовкам запроса.
- **`_headers` / `_redirects`** — таких файлов в репозитории нет вовсе
  (`find` — 0 результатов; в `apps/funnels/chameleon/public/` только
  `favicons/`, `images/`, `lp/`, `manifest.json`). Заголовки живут в
  `next.config.ts:299-335`: `securityHeaders`
  (`packages/config/security.headers.config.ts:3-32` — `X-Frame-Options: DENY` и
  `Content-Security-Policy: frame-ancestors …` на `/` и `/(.*?)`),
  `X-Robots-Tag` для сабдоменов (`next.config.ts:306-315`) и
  `Link: rel=preconnect` на `NEXT_PUBLIC_CDN_ASSETS_URL` (`:316-324`).
- **Cloudflare Workers / wrangler** — 0 вхождений во всём репозитории.
- Transform Rule для `X-Robots-Tag` рассмотрен и **сознательно отклонён**:
  `docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md:91-108` — все прод-домены воронок
  проксированы (Cloudflare Tunnel проксирован по определению), правило бы
  работало, но политику индексации оставили в коде, чтобы не заводить второй
  источник правды и чтобы DNS-only превью на Vercel тоже были покрыты. Плюс
  комментарий `packages/config/constants/common.ts:146-152`.

### Ассеты и version skew (не CF, но соседняя зависимость)

`next.config.ts:31-35` — `assetPrefix` собирается как
`${NEXT_PUBLIC_ASSET_HOST|ASSET_HOST}/builds/${GIT_HASH}` (`:347`), комментарий
`:33-34` даёт пример `https://cdn-static.spanish-boost.com/builds/abc1234`.
`deploymentId: gitHash` (`:58`) — version-skew protection, комментарий `:53-57`
связывает её с `faro/chunk-load-recovery.ts`. `images.loader: 'default'` (`:200`)
— встроенный оптимизатор Next, не CF Images; `minimumCacheTTL: 604800` (`:296`).

---

## 5. Третьи стороны и откуда берутся id (ТОЛЬКО имена переменных)

`.env*` в chameleon отсутствуют (`.gitignore:21-23`), канонический список имён —
`globalEnv` в `turbo.json`.

| сервис | имя переменной | где читается |
|---|---|---|
| CookieYes | `NEXT_PUBLIC_COOKIEYES_ID` | `packages/ui/common/Scripts/CookieYes/CookieYesScript.tsx:23`; объявлено в `turbo.json:47` |
| CookieYes для `english-improve.com` | константа `ENGLISH_IMPROVE_COOKIEYES_ID` | `packages/ui/common/Scripts/CookieYes/CookieYesScript.tsx:9` — id **зашит в исходник**, выбор по hostname `:17-22`, грузится только в проде `:11-13` |
| GTM | `NEXT_PUBLIC_GTM_ID` | `packages/ui/common/Shared/HtmlShell.tsx:16` (chameleon подключает через `app/[lang]/layout.tsx:39`), `packages/ui/common/SharedDocument/SharedDocument.tsx:17`; `turbo.json:42` |
| GTM (фолбэк) | константа `DEFAULT_GTM_ID` | `packages/config/constants/common.ts:44` — контейнер зашит в исходник; формат валидируется регэкспом `HtmlShell.tsx:20-22` |
| Meta / Facebook Pixel | `NEXT_PUBLIC_FB_PIXEL_ID` | `packages/features/FunnelBuilder/hooks/useFacebookPixel.ts:35`, `packages/ui/common/Shared/FacebookPixelProviderInitFlow.tsx:33`, `packages/utils/analytics.ts:770`, `packages/utils/sendToServerFacebookEvent.ts:80`; `turbo.json:15` |
| TikTok Pixel | `NEXT_PUBLIC_TIKTOK_PIXEL_ID` | `packages/ui/common/CommonScripts/CommonScripts.tsx:206`; `turbo.json:23` |
| Amplitude | `NEXT_PUBLIC_AMPLITUDE_API_KEY` | `packages/utils/customHooks/analytics/useInitializeCommonPixels.ts:103`; `turbo.json:9` |
| Firebase (серверный) | `FIREBASE_SERVICE_ACCOUNT_KEY`, `FIREBASE_DATABASE_URL` | `packages/utils/firebaseAdmin.ts:16-17,25`; `turbo.json:74-75,123-124,228-229`. Первый — секрет; `NEXT_PUBLIC_FIREBASE_*` в репозитории нет |
| Faro (RUM) | `NEXT_PUBLIC_FARO_URL`, `NEXT_PUBLIC_FARO_API_KEY`, `NEXT_PUBLIC_FARO_APP_NAME`, `NEXT_PUBLIC_FARO_APP_NAMESPACE`, `NEXT_PUBLIC_FARO_ENVIRONMENT`, `NEXT_PUBLIC_FARO_ENABLED`, `NEXT_PUBLIC_FARO_BLOCKED_VALUES` | `packages/observability/faro/frontend-observability.ts:36,40,42,44,45,50-53`; `turbo.json:30-36` |
| ip-api (гео-фолбэк) | `NEXT_PUBLIC_IP_API_KEY` | `packages/utils/getCountryByIp.ts:7` |
| Code-Funnels allow-list | `CF_FUNNELS_ALLOWLIST_API_BASE`, `CF_FUNNELS_ALLOWLIST_AUTH_TOKEN` | `packages/utils/fetchChameleonFunnelsAllowList.ts:11,27`; `turbo.json:82-83` |
| Cloudflare purge | `CLOUDFLARE_ZONE_ID`, `CLOUDFLARE_API_TOKEN` | `packages/utils/webhooks/purgeCloudflareTag.ts:11-12`; `turbo.json:63-64` |

Флаги-выключатели (не id): `BLOCK_AMPLITUDE_ANALYTICS`, `BLOCK_TIKTOK_ANALYTICS`
(`packages/config/constants/common.ts:104,106`, потребитель
`packages/utils/customHooks/useBlockAnalytics.ts:16,23`).

Два слоя FB-пикселя, которые нельзя путать
(`docs/funnel-builder/NEW_SUBDOMAIN_SETUP.md:127-152`): доменный дефолт —
Strapi-сущность *FB Multi Domain*, отдаётся через
`apps/funnels/chameleon/app/api/domain-pixel/route.ts:5-8`
(`getDomainFacebookPixel()`); пер-воронный — `facebookPixelId` в модуле code-funnel,
он переопределяет доменный на всех доменах сразу. Id обязан быть числовым
(`/^[1-9]\d*$/`), иначе `fbq('init', <value>)` даёт `ReferenceError` и убивает
инициализацию пикселя на весь домен — инцидент `say-what-you-mean-2`
(`NEW_SUBDOMAIN_SETUP.md:154-160`).

Consent Mode включается по домену:
`apps/funnels/chameleon/app/[lang]/layout.tsx:44-46` —
`withConsentMode: DOMAIN_NAME !== ENGLISH_IMPROVE_ORIGIN`.

---

## 6. Health / readiness

Один эндпойнт, и он ECS-ориентированный.
`apps/funnels/chameleon/app/api/health/route.ts` — 12 строк:
`dynamic = 'force-dynamic'` (`:6`), `createHealthState()` (`:8`),
`createHealthCheckHandler(state, { requiredSuccessfulProbes: 3 })` (`:10-12`).
Порог памяти не задан → RSS-проверка выключена.

Реализация — `packages/utils/healthCheck.ts`:

- `runWarmup` (`:15-34`) сам делает `fetch('http://localhost:${PORT}')` и считает
  прогрев успешным только если ответ ok **и** HTML содержит `</html>` (`:26`);
- три состояния 503: `warming_up` (`:57-69`), `memory_pressure`
  (`:74-88`, порог с per-instance джиттером 0-100 МБ, `:42-43`, `:51-54`),
  `stabilizing` пока `successfulProbes < requiredProbes` (`:92-103`);
- 200 `{status:'ok', version: GIT_HASH}` (`:105-109`); дефолт `requiredProbes = 4`
  (`:49`), chameleon переопределяет на 3;
- комментарий `:72-73` прямо про ECS: 503 → задача заменяется.

Отдельных `/healthz`, `/ready`, `/readiness` нет. `livenessProbe` /
`readinessProbe` / `startupProbe` в репозитории не встречаются ни разу (включая
`deploy-single-project-stage-k3s.yml`). `HEALTHCHECK` в
`apps/funnels/chameleon/Dockerfile` отсутствует.

В CI «health check» означает другое:
`.github/actions/ecs-health-check/action.yml:40-58` сверяет ECS
`running_count` vs `desired_count`, а не HTTP;
`.github/workflows/web_healthcheck.yml:47-56` и `post_deploy.yml` — это запуск
внешних e2e-автотестов из `Promova/Promova-QAAutoTests`, статус-контекст
`web-healthcheck` (`web_healthcheck.yml:67`).

Движок здесь уже впереди: `funnel-engine/src/index.ts:37` — `GET /healthz`
(`{ ok, funnels: listFunnelIds().length }`), `funnel-engine/src/server.node.ts:144`
— `GET /ready`, `:190-210` — SIGTERM с дренажем и логом
`{"kind":"shutdown","action":"drained"}`; README `:1560-1562` фиксирует контракт
(«503 until the registry holds at least one funnel», «SIGTERM drains in-flight,
exits 0, hard cap 10 s»).

---

## Чек-лист: что funnel-engine должен повторить

### A. То, что chameleon получает от платформы бесплатно, а движку придётся устроить себе самому

1. **Второй регион.** Выключенный ECS-путь описывает `us-east-1` + `eu-central-1`
   (`.github/deployment-config.yaml:54-68`); живой Hetzner-путь — один кластер
   (`deployment-config-hetzner.yaml:26-33`). У движка dev в `eu-central-1`, prod в
   `us-east-1` (`funnel-engine/.github/workflows/build-deploy-k3s.yml:74-79`), то
   есть одна прод-точка. Это влияет на замер шага 8, а не на функциональность.
2. **Версионированный CDN-префикс для статики.** chameleon выкладывает
   `.next/static` + `public` в S3 c `max-age=31536000, immutable` и инвалидирует
   CloudFront (`deploy-single-project-hetzner.yml:270-283`), а бандл ссылается на
   `<host>/builds/<sha>` (`next.config.ts:31-35,347`). Движок отдаёт статику из
   пода (`funnel-engine/src/server.node.ts:46,53` — `immutable`), поэтому CDN-правило
   перед подом становится обязательным, а не приятным.
3. **Purge кэша по домену после деплоя.** У chameleon это job в пайплайне
   (`deploy-single-project-hetzner.yml:417-441` + `.github/actions/cloudflare-cache-purge/action.yml:72-75`).
   В `funnel-engine/.github/workflows/build-deploy-k3s.yml` такого шага нет
   вообще — после релиза edge продолжит отдавать старую статику до истечения TTL.
4. **Прогрев перед принятием трафика.** `packages/utils/healthCheck.ts:15-34`
   держит 503, пока сам не получит полный HTML с локального порта, и добавляет
   `stabilizing`-порог из 3 проб (`app/api/health/route.ts:11`). У движка `/ready`
   проверяет только «реестр непустой» (`server.node.ts:144`, README `:1560`) — под
   принимает трафик до первого прогретого рендера.
5. **Самоубийство по памяти.** `healthCheck.ts:74-88` отдаёт 503 при превышении
   RSS c per-instance джиттером, чтобы оркестратор заменил задачу
   (комментарий `:72-73`). У движка такого предохранителя нет; в chameleon он, впрочем,
   тоже выключен (порог не передан).
6. **Куда уходит stdout.** Для chameleon это конфиг вне репозитория
   (`logConfiguration` наследуется из task definition, `deploy-single-project.yml:221-234`;
   stage — из `Promova/promova-gitops`). Для движка это надо получить письменно:
   `plans/funnel-engine-docker-migration.md:178-179` уже просит
   `service_name=funnel-engine-{env}` и поиск по `kind="funnel_event"` — пока это
   заявка, не факт.
7. **Дашборд под серверные логи.** Единственный названный в монорепе дашборд —
   `CiroMopVz` («Frontend Observability», `docs/error-simulation-harness.md:104`) —
   это RUM, и туда движок не попадёт, потому что RUM у него нет. Своя панель или
   алерт по `kind="geo_missing"` / `console.error` — отдельная работа.
8. **Второй набор Vault-путей на домен.** chameleon получает пять env-наборов из
   `monorepo-frontend-prod/<slug>` (`DEPLOYMENT_README.md:104-109`), и это то, что
   делает один образ пятью доменами. У движка `gimli_dev/kv/env` и
   `gimli_prod/kv/env` (`plans/funnel-engine-vault-env.md:3-4`) — по одному на
   окружение. Если движку когда-нибудь понадобится второй домен с собственным
   пикселем, множественность придётся заводить.
9. **Профилирование и трейсы.** `packages/observability/otel/registerInstrumentation.ts:6-14`
   + `pyroscope/initPyroscope.ts:2-20` дают chameleon OTLP-трейсы и CPU-профили
   по `OTEL_SERVICE_NAME`. В `funnel-engine/src` нет ни OTel, ни Pyroscope.

### B. Зонные настройки Cloudflare, которые надо применить и к `gimli.promova.com`

1. **Проксирование зоны + IP Geolocation → `cf-ipcountry`.** Единственный
   источник гео у обоих: `packages/utils/getRequestCountry.ts:27` у chameleon,
   `funnel-engine/src/http.ts:117-118` у движка. Без него у движка выключается
   EEA-гейт согласия (`funnel-engine/src/http.ts:291,302`) и гео-флаги падают в
   дефолт; единственный сигнал — `kind: "geo_missing"` (`http.ts:151-154`).
2. **Managed Transform «Add visitor location headers» → `cf-region`.**
   Дашбордная настройка, названная в самом коде:
   `packages/utils/getRequestCountry.ts:31`. Движок читает `cf-region` для
   калифорнийского слага Terms; сегодня это ничего не меняет
   (`plans/funnel-engine-vault-env.md:116-120`), поэтому — опционально, но
   применять надо парой с (1), а не отдельно.
3. **Cache Rule на `/img/*` и `/vendor/*`.** У chameleon эти байты вообще не
   доходят до пода — они на S3/CloudFront. У движка их отдаёт процесс, отвечая
   `immutable` (`funnel-engine/src/server.node.ts:46,53`), так что без правила
   каждая картинка — запрос в конкурентность пода
   (`funnel-engine/README.md:1573-1577`).
4. **Email Address Obfuscation.** На `promova.com` включена, и это чисто зонная
   настройка: в коде chameleon нет ни `__cf_email__`, ни `email-decode`, ни
   `data-cfasync` (grep — 0 вхождений по `apps/funnels/chameleon` и `packages`).
   Движок отдаёт те же документы со своего хоста открытым адресом
   (`funnel-engine/src/render/cookie-policy.ts:42`,
   `funnel-engine/src/render/legal.ts:301`), значит без настройки на зоне
   `support@promova.com` уедет харвестерам в открытом виде — ровно вывод
   `plans/funnel-engine-vault-env.md:109-115`.
5. **Rocket Loader — проверить, что выключен (или что движок его переживёт).**
   Ни chameleon, ни движок не защищаются `data-cfasync="false"` (0 вхождений в
   обоих). У chameleon скрипты монтирует Next/React; движок отдаёт инлайновые
   теги пикселей в HTML (`funnel-engine/src/routes/sales.ts:308-312`), так что
   перестановка порядка загрузки бьёт по нему сильнее. Настройку надо явно
   сверить с зоной `promova.com`, а не предполагать.
6. **`X-Forwarded-Proto` / `X-Forwarded-Host` от ingress и недостижимость пода
   иначе как через ingress.** У chameleon это Cloudflare Tunnel → Traefik
   (`deploy-hetzner.yml:6`), у движка — требование, из которого он собирает
   внешний URL (`funnel-engine/README.md:1578-1582`,
   `plans/funnel-engine-docker-migration.md:186`).
7. **Zone Purge API-доступ.** chameleon дёргает `purge_cache` из кода вебхука
   ревалидации (`packages/utils/webhooks/purgeCloudflareTag.ts:41`) и из CI
   (`.github/actions/cloudflare-cache-purge/action.yml:72-75`). Если движок будет
   отдавать что-то кэшируемое из Strapi, ему понадобится тот же доступ на свою
   зону; сейчас в `funnel-engine/src` вызовов CF API нет.
8. **WAF / Bot Management — на паритет, вслепую.** Ни chameleon, ни движок не
   видят этот слой из кода (0 вхождений `turnstile|__cf_bm|cf-ray`). Значит его
   конфигурация на `promova.com` неизвестна из репозитория и должна быть
   скопирована на `gimli.promova.com` силами DevOps, иначе поведение под
   рекламным пиком будет разным.

### C. Чисто кодовое — и что у движка уже есть

| пункт | у chameleon | у движка |
|---|---|---|
| Гео через `cf-ipcountry` + отбраковка `XX`/`T1` | `getRequestCountry.ts:27,32` | **частично**: `funnel-engine/src/http.ts:117-118` читает заголовок, но `XX`/`T1` не отбраковывает — Tor-выход даст «страну» `T1`; chameleon этого не допускает |
| Предупреждение при отсутствии гео | нет — молча уходит в платный IP-lookup (`getRequestCountry.ts:38-39`) | **есть и лучше**: `http.ts:150-155`, `kind: "geo_missing"` на entry-hit |
| IP-фолбэк гео | есть (`getCountryByIp.ts:7`, ip-api, платный) | **нет** — сознательно: без CF страна `null` |
| `/healthz` + `/ready` раздельно | нет, один `/api/health` c внутренними состояниями (`healthCheck.ts:57-109`) | **есть**: `src/index.ts:37`, `src/server.node.ts:144` |
| Грациозный SIGTERM | не в коде (ECS + `wait-for-service-stability`, `deploy-single-project-hetzner.yml:349`) | **есть**: `src/server.node.ts:190-210`, дренаж, cap 10 с |
| Структурированные логи | **нет** — голый `console.error` (`route.ts:56` ×2, `page.tsx:51`) | **есть**: `src/analytics/log.ts:21,55`, JSON-строки, `kind` |
| Серверный error reporting (`onRequestError`/Sentry) | **нет вообще** (0 вхождений в монорепе) | нет — паритет; но у движка нет и клиентского Faro, так что суммарно наблюдаемость ниже |
| Браузерный RUM | есть (`frontend-observability.ts:39`, лейблы `app_environment`/`kind`, дашборд `CiroMopVz`) | **нет** — единственное упоминание Faro в `src` это комментарий (`src/checkout.ts:115`) |
| Version-skew protection | есть: `deploymentId: gitHash` (`next.config.ts:58`) + `faro/chunk-load-recovery.ts` | **нет** — движку она почти не нужна (HTML отдаётся сервером, чанков нет), но `?dpl=`-эквивалента для версии страницы тоже нет |
| Версия сборки в health-ответе | есть: `GIT_HASH` (`healthCheck.ts:108`) | **нет**: `/healthz` отдаёт `{ok, funnels}` (`src/index.ts:37`); имя пода вместо colo только в диагностике (`plans/funnel-engine-docker-migration.md:28`) |
| `X-Frame-Options: DENY` + CSP `frame-ancestors` | есть на всех путях (`packages/config/security.headers.config.ts:3-32`, подключено `next.config.ts:301`) | **нет** — grep по `X-Frame-Options|Content-Security-Policy` в `funnel-engine/src` пуст |
| `noindex` для не-основного домена | есть двумя способами: `app/robots.ts` + `X-Robots-Tag` (`next.config.ts:306-315`, обоснование `NEW_SUBDOMAIN_SETUP.md:85-89`) | **частично**: только мета-тег (`funnel-engine/src/render/layout.ts:456`), заголовка `X-Robots-Tag` нет, а он единственный доходит по прямой ссылке из объявления |
| `immutable` на статику | делает CDN (`deploy-single-project-hetzner.yml:271`) | **есть в коде**: `src/server.node.ts:46,53` |
| Отказ старта без секрета | нет | **есть**: `ENVIRONMENT=production` без `STATE_HMAC_KEY` роняет процесс (`funnel-engine/README.md:1590-1595`) |
| Env-набор третьих сторон | `NEXT_PUBLIC_*` (см. §5), инлайнятся на билде | **есть, но рантаймовые**: `COOKIEYES_ID`, `GTM_ID`, `FB_PIXEL_ID`, `TIKTOK_PIXEL_ID`, `AMPLITUDE_API_KEY` (`funnel-engine/src/http.ts:21-43`, потребители `src/routes/sales.ts:308-312`, `src/http.ts:305`) — карта соответствия уже составлена (`plans/funnel-engine-vault-env.md:12-37`) |
| Доменный пиксель из CMS | есть (`app/api/domain-pixel/route.ts:5-8`) | нет — у движка один `FB_PIXEL_ID` из env; для одного домена этого достаточно |
| Consent Mode / CookieYes по домену | `app/[lang]/layout.tsx:44-46` | есть свой гейт: `CONSENT_MODE` пусто = гейт включён (`plans/funnel-engine-vault-env.md:36`) |
| Allow-list «воронка ↔ домен» | есть (`isFunnelBelongsToDomain.ts:16-24` + внешний сервис) | нет и не нужен, пока хост один |

### Что репозиторий ответить не может — и кого спрашивать

1. **Куда физически уходит stdout контейнера chameleon и под каким лейблом его
   искать.** `logConfiguration` наследуется из task definition, которого в git нет
   (`deploy-single-project.yml:221-234`); grep по
   `alloy|loki|firelens|awslogs|logConfiguration|fluentbit|cloudwatch` по всему
   репо — 0 конфигов. Вопрос DevOps (`#devops-hub`): какой log driver у
   `prod-promova-frontend-anywhere-*`, какой Loki-стрим/лейблы, и подтвердить,
   что `service_name=funnel-engine-{env}` действительно заведён для gimli.
2. **Включены ли на зоне `promova.com` Email Address Obfuscation, Rocket Loader,
   Bot Management/WAF, и с какими правилами** — в коде этих настроек нет вовсе,
   только наблюдаемое поведение выдачи. Вопрос DevOps: снять текущий набор
   зонных настроек `promova.com` и применить эквивалент к `gimli.promova.com`.
3. **Есть ли Cache Rule на `/img/*` и `/vendor/*`, и на какой зоне.**
   Для chameleon вопрос не стоит (статика на CloudFront), для движка это
   обязательный пункт. Вопрос DevOps.
4. **Правила таргетинга GrowthBook для `us_pricing_now_then` и
   `ftc_soft_changes`** — из репозитория неотличимо «флаг выключен» от «атрибут
   `country` в неверном формате» (`funnel-engine/README.md:1656-1670`).
   Вопрос — к владельцу GrowthBook (аналитика/продукт), не к DevOps.
5. **Значения `OTEL_SERVICE_NAME` / `PYROSCOPE_SERVER_ADDRESS` для chameleon** —
   только имена в `turbo.json:77` и README; значения в Vault. Вопрос DevOps, если
   движок захочет попасть в те же трейсы.
6. **Task definition / helm values c probes и лимитами.** `livenessProbe` /
   `readinessProbe` в репозитории нет ни для chameleon, ни для его stage-k3s
   (0 вхождений). Значит контракт проб для gimli (`/healthz` liveness,
   `/ready` readiness, 2 реплики + HPA — `plans/funnel-engine-docker-migration.md:174,187`)
   нигде в коде не закреплён и живёт только в `Promova/promova-gitops`.
   Вопрос DevOps: подтвердить, что values для `gimli-prod-server` их содержат.
