# funnel-engine → Vault env fill sheet

Инфра поднята 2026-09-07 (DevOps, DM): `gimli.promova.com` — dev-хост,
`gimli_dev/kv/env` и `gimli_prod/kv/env` созданы пустыми.

Движок читает 25 переменных. Источник прод-значений — Vault монорепы,
mount `monorepo-frontend-prod`, path `student` (это тот деплой, что обслуживает
`/kilo/general-english` на promova.com; см. `.github/deployment-config.yaml:21`).

## Карта: ключ движка ← источник

| ключ движка | откуда берём | секрет |
|---|---|---|
| `STATE_HMAC_KEY` | **сгенерировать новый**, аналога в проде нет | да |
| `DIAG_TOKEN` | **сгенерировать новый**, аналога в проде нет | да |
| `FIREBASE_WEB_API_KEY` | `packages/utils/firebase.ts:7` (захардкожен в монорепе) | да |
| `MARKETING_SDK_TOKEN` | Vault `student` → `NEXT_PUBLIC_MARKETING_SDK_TOKEN` | да |
| `GROWTHBOOK_CLIENT_KEY` | Vault `student` → `NEXT_PUBLIC_GROWTH_SERVERSIDE_CLIENT_KEY` (движок резолвит на сервере) | да |
| `GROWTHBOOK_API_HOST` | Vault `student` → `NEXT_PUBLIC_GROWTH_BOOK_API_KEY` (имя врёт, внутри host) | нет |
| `API_HOST` | Vault `student` → `NEXT_PUBLIC_API_HOST` | нет |
| `API_PAYMENTS_HOST` | Vault `student` → `NEXT_PUBLIC_API_PAYMENTS_HOST` | нет |
| `API_MARKETING_HOST` | Vault `student` → `NEXT_PUBLIC_API_MARKETING` | нет |
| `MARKETING_STRAPI_URL` | Vault `student` → `NEXT_PUBLIC_MARKETING_STRAPI_URL` (прод-значение `https://gringotts.promova.work`) | нет |
| `FIREBASE_SERVICE_ACCOUNT` | **новый секрет.** JSON сервис-аккаунта Firebase проекта `ten-words` — того же, что за `FIREBASE_WEB_API_KEY` (`packages/utils/firebase.ts:10`); токен, подписанный ключом другого проекта, Firebase отклонит, и визитёр увидит форму логина без объяснений. Нужен, чтобы после покупки визитёр попадал на платформу уже залогиненным. Код с 2026-09-09 читает его в `src/custom-token.ts`; пусто = фолбэк на `link_for_auth` (ссылка живёт ~минуту, минтится по клику), сломанный JSON = одна строка в лог и тот же фолбэк. Принимаются оба вида PEM: с экранированными `\n` и с реальными переводами строк | да |
| `AMPLITUDE_API_KEY` | Vault `student` → `NEXT_PUBLIC_AMPLITUDE_API_KEY` | нет* |
| `COOKIEYES_ID` | Vault `student` → `NEXT_PUBLIC_COOKIEYES_ID` | нет |
| `FB_PIXEL_ID` | Vault `student` → `NEXT_PUBLIC_FB_PIXEL_ID` | нет |
| `TIKTOK_PIXEL_ID` | Vault `student` → `NEXT_PUBLIC_TIKTOK_PIXEL_ID` | нет |
| `GTM_ID` | `GTM-WKZFDV3` (`packages/config/constants/common.ts:44`) | нет |
| `WEB_ORIGIN` | `https://promova.com` | нет |
| `ENVIRONMENT` | `production` / `dev` | нет |
| `PORT` | `8080` | нет |
| `HOSTNAME` | ставит k8s (имя пода), руками не заполнять | нет |
| `GIT_HASH` | коммит образа; отдаётся в `/healthz` как `version`. Передавать **через чарт как обычную env**, не как build-arg: у движка нулевая build-time конфигурация, и один образ на все окружения — его осознанное свойство | нет |
| `LIVE_MODE` | см. ниже | нет |
| `SEND_EVENTS` | см. ниже | нет |
| `LOAD_PIXELS` | см. ниже | нет |
| `CONSENT_MODE` | не задавать (пусто = гейт включён) | нет |

\* ключ Amplitude уходит в браузер в любом случае, но лежит в том же Vault-пути.

## Генерация двух своих секретов

```
openssl rand -base64 32   # STATE_HMAC_KEY
openssl rand -hex 24      # DIAG_TOKEN
```

Вставлять прямо в Vault UI, в файлы не писать.

## gimli_prod/kv/env

```
ENVIRONMENT=production
PORT=8080
WEB_ORIGIN=https://promova.com
GTM_ID=GTM-WKZFDV3
LIVE_MODE=true
SEND_EVENTS=true
LOAD_PIXELS=true
API_HOST=<student: NEXT_PUBLIC_API_HOST>
API_PAYMENTS_HOST=<student: NEXT_PUBLIC_API_PAYMENTS_HOST>
API_MARKETING_HOST=<student: NEXT_PUBLIC_API_MARKETING>
MARKETING_STRAPI_URL=https://gringotts.promova.work
GROWTHBOOK_API_HOST=<student: NEXT_PUBLIC_GROWTH_BOOK_API_KEY>
GROWTHBOOK_CLIENT_KEY=<student: NEXT_PUBLIC_GROWTH_SERVERSIDE_CLIENT_KEY>
AMPLITUDE_API_KEY=<student: NEXT_PUBLIC_AMPLITUDE_API_KEY>
COOKIEYES_ID=<student: NEXT_PUBLIC_COOKIEYES_ID>
FB_PIXEL_ID=<student: NEXT_PUBLIC_FB_PIXEL_ID>
TIKTOK_PIXEL_ID=<student: NEXT_PUBLIC_TIKTOK_PIXEL_ID>
MARKETING_SDK_TOKEN=<student: NEXT_PUBLIC_MARKETING_SDK_TOKEN>
FIREBASE_WEB_API_KEY=<packages/utils/firebase.ts:7>
FIREBASE_SERVICE_ACCOUNT=<JSON сервис-аккаунта проекта ten-words>
STATE_HMAC_KEY=<openssl rand -base64 32>
DIAG_TOKEN=<openssl rand -hex 24>
```

## gimli_dev/kv/env

Те же значения, кроме четырёх строк — иначе тестовый хост будет списывать
реальные карты и лить события в прод-дашборды:

```
ENVIRONMENT=dev
LIVE_MODE=false
SEND_EVENTS=false
LOAD_PIXELS=false
```

`STATE_HMAC_KEY` в dev тоже задать своим значением (отдельным от прода):
при `ENVIRONMENT=dev` без него подставляется известный dev-fallback.

## Что LIVE_MODE переключает в движке

| | `LIVE_MODE=true` | `false` |
|---|---|---|
| Solidgate | реальные списания | `sandbox: true` (`routes/sales.ts:371`, `post-purchase.ts:449`) |
| Amplitude / CRM | уходят наружу | только в лог (`analytics/emit.ts:105`) |
| пиксели | грузятся | не грузятся, если `LOAD_PIXELS` не `true` |

## Остаётся за DevOps (не в env)

1. Зона `gimli.promova.com` проксирована Cloudflare с IP Geolocation → иначе нет
   `cf-ipcountry`, EEA-гейт согласия выключен, гео-флаги в дефолт. Падает молча,
   единственный сигнал — `geo_missing` в логе.
2. CDN-правило на `/img/*` и `/vendor/*` — раньше отдавал edge, теперь процесс.
3. `X-Forwarded-Proto` / `X-Forwarded-Host` от ingress, и под недостижим иначе
   как через ingress.
4. `HOSTNAME` из downward API.
5. Пробы: `GET /healthz` (liveness), `GET /ready` (readiness, 503 до загрузки
   реестра воронок).
6. ~~**Email Address Obfuscation на зоне `gimli.promova.com`.**~~ **СНЯТО
   2026-09-09 — просить нечего.** Настройка зонная, а `gimli.promova.com` живёт
   в зоне `promova.com`, где она уже включена. Проверено на соседе по зоне:
   `learn.promova.com/terms/subscription-terms` (тот же chameleon, тот же
   Strapi-рекорд) отдаёт `data-cfemail` — значит субдомены наследуют. Сам
   `gimli.promova.com` уже за Cloudflare (`server: cloudflare`, `cf-ray`),
   сейчас отвечает 403.
   Попутно выяснилось, что защита **всюду половинчатая**, и это стоит знать,
   прежде чем ссылаться на неё как на меру: в том же ответе, где тело отдано
   как `[email protected]`, адрес лежит открытым текстом в RSC-payload
   (`self.__next_f`), потому что переписыватель Cloudflare трогает HTML и
   `mailto:`, но не содержимое скриптов. Проверено 2026-09-09 на пяти хостах:
   `promova.com`, `learn.promova.com`, `spanish-boost.com`,
   `english-improve.com`, `promova-ai-academy.com`,
   `promova-english-academy.com` — на каждом и `data-cfemail`, и сырой адрес.
   У движка RSC-payload нет вовсе, так что на его страницах обфускация
   сработает целиком: он окажется в этом месте чище прода, а не грязнее.
7. **`GIT_HASH` в чарт** — иначе `/healthz` отдаёт `version: null`, и «роллаут
   закончился» не отличить от «роллаут закончился, а старый образ ещё отвечает».
8. **`cf-region` (Managed Transform «Add visitor location headers»)** — опционально.
   Движок читает его для калифорнийского слага Terms. Сегодня он ничего не
   меняет: прод резолвит US-правило раньше калифорнийского, и движок повторяет
   этот порядок осознанно. Нужен, только если правило будут править на обеих
   сторонах.

---

Полная сверка с прод-воронками (что chameleon получает от платформы бесплатно,
что является настройкой зоны, что кодом) — в `funnel-engine-devops-parity.md`.
Там же три вопроса про логи, на которые репозиторий монорепы ответить не может.
