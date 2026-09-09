# Что прод реально отправляет в GrowthBook как targeting-атрибуты

Репозиторий: `/Users/uvarovalexandr/myProject/promova.com_monorepo` (read-only).
Все пути абсолютные, идентификаторы дословные.

---

## TL;DR

1. **Расхождение по `country` подтверждено, и оно жёсткое.** Клиент отправляет **полное название страны** (`"Ukraine"`, `"United States"`), сервер и middleware отправляют **ISO alpha-2** (`"UA"`, `"US"`). Один и тот же ключ атрибута `country`, два несовместимых словаря.
2. **FTC-флаги (`us_pricing_now_then`, `ftc_soft_changes`) читаются ТОЛЬКО на клиенте**, через `useFeatureIsOn`. То есть на прод-пути они видят именно **полное название страны**. Ни один серверный вызов их не читает.
3. Значит гипотеза из `funnel-engine/README.md:1656-1664` — верная по механике: engine посылает ISO (`cf-ipcountry`), а правило FTC-флага в GrowthBook почти наверняка написано под полное имя, потому что его единственный потребитель — клиентский хук.
4. **Словаря «имя ↔ ISO» в репозитории нет.** Оба формата приходят одним ответом от `pro.ip-api.com` (поля `country` и `countryCode`), репозиторий просто берёт то или другое поле и никогда не конвертирует.
5. Зато есть **готовый ISO-список ровно тех гео**, что таргетят FTC-флаги: `FTC_COUNTRIES` в `packages/config/types/countries.ts:42-54`. Это и есть тот словарь, который надо использовать в engine — но как локальную проверку, а не как атрибут.

---

## 1. Полная карта атрибутов на КЛИЕНТЕ

Единственная точка монтирования: `packages/ui/common/CommonScripts/CommonScripts.tsx:101` → `useAddGrowthBookAttributes()`.

### 1a. Конструктор инстанса (модульный top-level, до всякой авторизации)

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/growthbook/growthBook.ts:35-49`:

```ts
export const growthBookInstance = new GrowthBook({
  attributes: {
    device_id: readDeviceIdSafely(),
  },
  apiHost: process.env.NEXT_PUBLIC_GROWTH_BOOK_API_KEY,
  clientKey: process.env.NEXT_PUBLIC_GROWTH_CLIENT_KEY,
  enableDevMode: process.env.NEXT_PUBLIC_LIVE_MODE !== 'true',
  remoteEval: true,
```

И сразу же, `growthBook.ts:73-84`:

```ts
const langQueryAttribute =
  typeof window !== 'undefined'
    ? new URLSearchParams(window.location.search)
        .get('lang')
        ?.trim()
        .toLowerCase() ?? ''
    : ''

growthBookInstance.updateAttributes({
  platform: 'web',
  ...(langQueryAttribute && { lang_query: langQueryAttribute }),
})
```

То есть **первый** remote-eval POST уходит с набором `{ device_id, platform, lang_query? }` — без `country`, без `custom_user_id`. `remoteEval: true` означает, что определения фич клиенту не отдаются вообще: каждый `updateAttributes` — это новый POST на прокси и новая порция уже посчитанных значений.

`device_id` берётся из куки `_ppdi` (`CookieKeys.DEVICE_ID_COOKIE = '_ppdi'`, `packages/config/constants/storageKeys.ts:5`), и намеренно пустая строка, если кука не записалась (`growthBook.ts:17-33`) — стабильный no-match вместо случайного ре-бакетинга.

### 1b. Основная пачка — `useAddGrowthBookAttributes`

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/customHooks/useAddGrowthBookAttributes.ts:64-109` — дословно объектный литерал:

```ts
  useEffect(() => {
    if (!userId || !growthBook || !country || (user && isExperimentsLoading)) {
      return
    }

    const deviceId = Cookies.get(CookieKeys.DEVICE_ID_COOKIE) || ''
    const funnelId = Cookies.get(CookieKeys.FUNNEL_ID) || ''

    const isMobile = navigator.maxTouchPoints > 0 && 'orientation' in window

    const attributes: Record<string, any> = {
      custom_user_id: userId,
      country,
      utm_source: utmSource,
      device: isMobile ? 'mobile' : 'desktop',
      platform: 'web',
      device_id: deviceId,
    }

    if (funnelId) {
      attributes.funnel_id = funnelId
    }

    if (locale) {
      attributes.localization = locale
    }

    if (activeCourse?.target) {
      attributes.target_language = activeCourse?.target
    }

    if (user && isSubscriptionFetched && isProfileFetched) {
      attributes.email = user.email
      attributes.self_learning_premium_access = hasCoursesPremium
        ? SubscriptionStatus.PREMIUM
        : SubscriptionStatus.FREE
      attributes.user_created_date = formatISO(
        new Date(user.metadata.creationTime || '')
      )
      attributes.completed_first_lesson = isFirstLessonCompleted

      if (experimentsData) {
        const experimentsInvolved = experimentsData?.value?.split(',') || []
        attributes.ff_experiments_involved = experimentsInvolved
      }
    }

    growthBook.updateAttributes(attributes).then(() => { … })
```

Таблица (ключ → источник → формат):

| ключ | источник (file:line) | формат / пример |
|---|---|---|
| `custom_user_id` | `useAddGrowthBookAttributes.ts:35` — `globalUser?.uid`, Firebase uid из `useAuthStore` | строка Firebase uid, 28 симв.: `"Be8QX7sY3pXiomqdYgmTnlNwaeh2"`. **Включает анонимные сессии** (`packages/store/stores/auth.ts:9-10`) |
| `country` | `useAddGrowthBookAttributes.ts:28` — `const { country } = useQueryCountry()` | **ПОЛНОЕ НАЗВАНИЕ СТРАНЫ**: `"Ukraine"`, `"United States"`. См. §4 |
| `utm_source` | `useAddGrowthBookAttributes.ts:32` — `params?.get('utm_source') \|\| 'organic'` | строка; **дефолт `'organic'`**, не пусто |
| `device` | `useAddGrowthBookAttributes.ts:72,78` — `navigator.maxTouchPoints > 0 && 'orientation' in window` | `'mobile'` \| `'desktop'` |
| `platform` | `useAddGrowthBookAttributes.ts:79` (и `growthBook.ts:82`) | константа `'web'` |
| `device_id` | `useAddGrowthBookAttributes.ts:69` — кука `_ppdi` | uuid v4: `"ebf6afe9-df91-4b02-bdd3-6324befe645d"`, либо `''` |
| `funnel_id` | `useAddGrowthBookAttributes.ts:70,83-85` — кука `funnel_id`; **условный** | слаг воронки. Пишется отдельно в `useSetFunnelIdGrowthBook.ts:20-26` |
| `localization` | `useAddGrowthBookAttributes.ts:33,87-89` — `usePathnameLocale()` → `getLocaleFromPathname` | локаль из ПЕРВОГО сегмента пути, валидируется против `LOCALES`, иначе `DEFAULT_LOCALE = 'en'` (`packages/config/constants/common.ts:1-18`). Формат `'en' \| 'uk' \| 'es' \| 'es-419' \| 'pt' \| 'fr' \| 'tr' \| 'it' \| 'de' \| 'pl' \| 'hi' \| 'el' \| 'ja' \| 'fil'` |
| `lang_query` | `growthBook.ts:73-84` — `?lang=` из URL; **условный**, ставится ДО всего остального | lowercase+trim строка |
| `target_language` | `useAddGrowthBookAttributes.ts:91-93` — `activeCourse?.target`; **условный**, только у залогиненных (`useActiveCourse` под `enabled: Boolean(user)`) | код языка курса |
| `email` | `useAddGrowthBookAttributes.ts:96`; только зарегистрированный + `isSubscriptionFetched && isProfileFetched` | email |
| `self_learning_premium_access` | `:97-99` | `SubscriptionStatus.PREMIUM` \| `SubscriptionStatus.FREE` (`'premium'` / `'free'`) |
| `user_created_date` | `:100-102` — `formatISO(new Date(user.metadata.creationTime))` | ISO с оффсетом: `"2026-07-15T17:35:37+03:00"` |
| `completed_first_lesson` | `:103` — `userProfile?.keeper?.[COMPLETED_FIRST_LESSON]?.value \|\| false` | boolean |
| `ff_experiments_involved` | `:105-108` — `experimentsData?.value?.split(',')` | массив строк, может быть `[]` |

### 1c. Живой дамп из прода/стейджа — прямое доказательство формата `country`

`/Users/uvarovalexandr/myProject/promova.com_monorepo/docs/funnel-builder/CODE_FUNNELS_MONEY_QA_FIX_PLAN_RESULT_01.md:143-159`, вывод `window._growthbook.getAttributes()`:

```json
{
  "platform": "web",
  "custom_user_id": "Be8QX7sY3pXiomqdYgmTnlNwaeh2",
  "country": "Ukraine",
  "utm_source": "organic",
  "device": "desktop",
  "device_id": "ebf6afe9-df91-4b02-bdd3-6324befe645d",
  "localization": "en",
  "email": "testfunnel20260715174636@gmail.com",
  "self_learning_premium_access": "premium",
  "user_created_date": "2026-07-15T17:35:37+03:00",
  "completed_first_lesson": false,
  "ff_experiments_involved": []
}
```

`"country": "Ukraine"` — не `"UA"`. Это уже не чтение кода, а зафиксированный runtime-снимок. Плюс он подтверждает: `funnel_id` в дампе **отсутствует** (задокументированный дефект B1b, `:162-165`), `lang_query` и `target_language` тоже.

---

## 2. Полная карта атрибутов на СЕРВЕРЕ

Их **две разных**, и обе отличаются от клиентской.

### 2a. Server Components / server actions — `initializeGrowthBookServerSide`

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/growthbook/initializeGrowthBookServerSide.ts:85-143`:

```ts
const buildUserContext = async () => {
  const cookieStore = await cookies()
  const deviceId = cookieStore.get(CookieKeys.DEVICE_ID_COOKIE)?.value
  const funnelId = cookieStore.get(CookieKeys.FUNNEL_ID)?.value
  const sharedUtms = cookieStore.get(CookieKeys.SHARED_UTMS)?.value
  const locale = cookieStore.get(CookieKeys.NEXT_LOCALE)?.value
  const gbOverridesCookie = cookieStore.get(CookieKeys.GB_OVERRIDES)?.value

  const data = await getRequestCountry().catch(() => ({
    countryCode: null,
    regionName: null,
  }))

  const country = data.countryCode          // <<< ISO alpha-2

  const attributes: Record<string, string> = { platform: 'web' }

  if (deviceId) {
    attributes.device_id = deviceId
  }

  if (funnelId) {
    attributes.funnel_id = funnelId
  }

  if (country) {
    attributes.country = country
  }

  if (locale) {
    attributes.localization = locale
  }

  const langQuery = await getLangQueryFromUrl()
  if (langQuery) {
    attributes.lang_query = langQuery
  }
  …
  Object.entries(utmsToApply).forEach(([key, value]) => {
    if (value) {
      attributes[key] = value
    }
  })
```

| ключ | источник | формат |
|---|---|---|
| `platform` | `:100` | `'web'`, всегда |
| `device_id` | `:87,102-104` — кука `_ppdi`; условный | uuid |
| `funnel_id` | `:88,106-108` — кука `funnel_id`; условный | слаг |
| `country` | `:93-112` — `getRequestCountry().countryCode` | **ISO alpha-2**: `"UA"`. Условный |
| `localization` | `:90,114-116` — кука **`nextLocale`** (не путь!) | локаль |
| `lang_query` | `:16-30,118-121` — `?lang=` из `x-request-url` / `x-url` / `referer` | lowercase |
| `utm_*` + `fbclid`/`gclid`/`gbraid`/`hook_id`/`ad_topic` | `:123-143` — сначала из URL, иначе из куки `shared_utms`; список `observeUtms` (`packages/config/constants/common.ts:201-226`) | каждый UTM кладётся **своим отдельным ключом** |

Отсутствуют полностью: `custom_user_id`, `device`, `email`, `target_language`, `self_learning_premium_access`, `user_created_date`, `completed_first_lesson`, `ff_experiments_involved`.

`getRequestCountry` (`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/getRequestCountry.ts:25-40`):

```ts
export const getRequestCountry = async () => {
  const hdrs = await nextHeaders()
  const cfCountry = hdrs.get('cf-ipcountry')

  if (cfCountry && cfCountry !== 'XX' && cfCountry !== 'T1') {
    const cfRegion = hdrs.get('cf-region')
    return { countryCode: cfCountry, regionName: cfRegion }
  }

  const ip = await getClientIp()
  return getCountryByIp(ip)
}
```

Фолбэк `getCountryByIp` (`packages/utils/getCountryByIp.ts:16-22`) тоже берёт из ответа ip-api **только** `countryCode` и `regionName` — полное имя выбрасывается.

### 2b. Edge middleware — `handleLandingBuilderRewrite`

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/middleware/handleLandingBuilderRewrite.ts:109-153` (нумерация файла: функция `buildGrowthBookAttributes`):

```ts
function buildGrowthBookAttributes(
  req: NextRequest,
  deviceId: string,
  locale: string
): Record<string, string> {
  const attributes: Record<string, string> = {
    device_id: deviceId,
    platform: 'web',
  }

  const funnelId = req.cookies.get(CookieKeys.FUNNEL_ID)?.value
  if (funnelId) attributes.funnel_id = funnelId

  if (locale) attributes.localization = locale

  const cfCountry = req.headers.get('cf-ipcountry')
  if (cfCountry && cfCountry !== 'XX' && cfCountry !== 'T1') {
    attributes.country = cfCountry
  }

  for (const key of observeUtms) {
    const value = req.nextUrl.searchParams.get(key)
    if (value) attributes[key] = value
  }
  …
```

Тоже **ISO** (`cf-ipcountry` напрямую, даже без нормализации к upper-case), тоже без `custom_user_id` / `device`.

### 2c. Отдельный факт: сервер и клиент — это ДВА разных SDK-подключения

- клиент: `clientKey: process.env.NEXT_PUBLIC_GROWTH_CLIENT_KEY`, `remoteEval: true` (`growthBook.ts:48-50`);
- сервер: `clientKey: process.env.NEXT_PUBLIC_GROWTH_SERVERSIDE_CLIENT_KEY` + `decryptionKey` из `GROWTH_BOOK_DECRYPTION_KEY` / `NEXT_PUBLIC_GROWTH_DECRYPTION_KEY`, **локальная** оценка на `GrowthBookMultiUser` (`packages/utils/growthbook/growthbookServer.ts:43-62`).

Это значит, что «серверные» и «клиентские» фичи в GrowthBook могут быть в разных SDK-connection-ах с разными наборами включённых фич. Для engine это существенно: `POST /api/eval/{clientKey}` работает только на remote-eval-подключении, то есть engine сидит на **клиентском** ключе — и это как раз то подключение, откуда FTC-флаги читаются в проде. Хорошая новость.

---

## 3. Где клиент и сервер расходятся — построчно

| ключ | клиент | сервер / middleware | вердикт |
|---|---|---|---|
| **`country`** | `"Ukraine"` — полное имя.<br>`useAddGrowthBookAttributes.ts:28` `const { country } = useQueryCountry()`<br>`:76` `country,`<br>подтверждено дампом `CODE_FUNNELS_MONEY_QA_FIX_PLAN_RESULT_01.md:147` | `"UA"` — ISO alpha-2.<br>`initializeGrowthBookServerSide.ts:98` `const country = data.countryCode`<br>`:110-112` `if (country) { attributes.country = country }`<br>`handleLandingBuilderRewrite.ts` `attributes.country = cfCountry` | **НЕСОВМЕСТИМО.** Правило `country in ["US","CY","UA"]` матчится только серверу; правило `country in ["United States","Cyprus","Ukraine"]` — только клиенту |
| `custom_user_id` | Firebase uid, есть всегда (в т.ч. анонимный) | **отсутствует** | сервер не участвует в percentage rollout по юзеру |
| `device` | `'mobile'` / `'desktop'` | **отсутствует** | правило по девайсу на сервере не матчится |
| `localization` | из **пути** (`usePathnameLocale`) | из **куки `nextLocale`** (server) / из пути (middleware) | могут разойтись значением |
| `utm_source` | всегда есть, дефолт `'organic'` | есть **только если реально пришёл** в URL или в куке `shared_utms` | правило `utm_source = "organic"` матчится клиенту и НЕ матчится серверу |
| остальные `utm_*`, `fbclid`, `gclid`, `gbraid`, `hook_id`, `ad_topic` | **не отправляются вообще** (клиент читает только `utm_source`) | отправляются каждый своим ключом | зеркальная асимметрия |
| `email`, `target_language`, `self_learning_premium_access`, `user_created_date`, `completed_first_lesson`, `ff_experiments_involved` | есть (у зарегистрированных) | **отсутствуют** | — |
| `lang_query` | есть (`growthBook.ts:73-84`) | есть (`initializeGrowthBookServerSide.ts:16-30`) | совпадает |
| `platform`, `device_id`, `funnel_id` | есть | есть | совпадает |

---

## 4. `useQueryCountry` — что именно возвращает

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/customHooks/useQueryCountry.ts:39-49`:

```ts
export const getCountry = async (): Promise<ResultCountry> => {
  const data = await axios.get(
    `https://pro.ip-api.com/json?key=${process.env.NEXT_PUBLIC_IP_API_KEY}`,
    { timeout: 5_000 }
  )
  return data?.data
}
```

Эндпоинт: **`https://pro.ip-api.com/json`** (ip-api.com, платный тариф, ключ в `NEXT_PUBLIC_IP_API_KEY`). Запрос идёт **из браузера**, без IP в пути — то есть ip-api определяет гео по IP самого запроса.

Тип ответа, `useQueryCountry.ts:5-20`:

```ts
type ResultCountry = {
  as: string
  city: string
  country: string
  countryCode: string
  isp: string
  lat: number
  lon: number
  org: string
  query: string
  region: string
  regionName: string
  status: string
  timezone: string
  zip: string
}
```

Разница между полями — это разница **полей самого ответа ip-api**, репозиторий их не вычисляет:

- **`country`** — поле `country` ответа ip-api: **полное английское название страны**, `"Ukraine"`, `"United States"`, `"United Kingdom"`.
- **`countryCode`** — поле `countryCode` ответа ip-api: **ISO 3166-1 alpha-2**, `"UA"`, `"US"`, `"GB"`.
- `query` — IP визитёра; `regionName` — имя региона (`"California"`), `region` — код региона.

Хук возвращает `{ ...(data || placeholder), isGeoResolved: isFetched }` (`:70`), где `placeholder` (`:22-37`) — все поля пустыми строками. То есть до ответа ip-api `country === ''` — а это ровно то условие, которое блокирует `useAddGrowthBookAttributes` (`:65`, `!country`).

Кто какое поле берёт (доказательство, что `country` — именно имя):

- `apps/student/utils/customHooks/useDetectUkrainianUser.ts:13` — `country === 'Ukraine'`
- `packages/utils/customHooks/useMarkUkraineUser.ts:25` — `if (country === 'Ukraine' || browserLang === 'uk')`
- `apps/student/features/Lessons/group/GroupLessons/useGroupLessonsPlans.ts:22` — `return country === 'Ukraine' ? UKR_GROUP_LESSONS_PLANS : GROUP_LESSONS_PLANS`
- `apps/student/components/templates/OverviewSalesPage/SubscriptionsScreen/SubscriptionsScreen.tsx:78` — то же сравнение с полным именем

Против ~40 мест, которые берут `countryCode` и сравнивают с ISO — в частности весь легальный слой `packages/utils/checkLegalAccess.ts:10-27` (`countryCode: string | null` + `.includes()` по alpha-2 массивам).

Итого `useAddGrowthBookAttributes.ts:28` — это единственная в репозитории точка, где полное имя страны уезжает в GrowthBook, и она в подавляющем меньшинстве по стилю. Похоже на исторический выбор, который потом закрепился в правилах дашборда.

---

## 5. `useFtcPricing` — ключи, комбинация, смысл варианта

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/hooks/useFtcPricing.ts:13-31`:

```ts
/**
 * Resolves the FTC pricing variant for funnel surfaces (sales-page, downsale,
 * upsell, checkout under a funnel).
 *
 * - `us_pricing_now_then` -> hard (US, CY, UA)
 * - `ftc_soft_changes`   -> soft (G8: UK, AU, CA, FR, LU, NL, CH, BE)
 *
 * Both flags are mutually exclusive at the GrowthBook targeting layer (geo
 * partitions Hard vs G8), but if both ever come back true at once, soft wins
 * because it carries the looser legal copy. See PRMV-17964.
 */
export const useFtcPricing = (): FtcPricingState => {
  const isHard = useUsPricingNowThen()
  const isSoft = useFtcSoftChanges()
  return {
    isOn: isHard || isSoft,
    variant: isSoft ? 'soft' : 'hard',
  }
}
```

Составляющие:

- `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/hooks/useUsPricingNowThen.ts:14-15` — `useFeatureIsOn(US_PRICING_NOW_THEN)`, комментарий `:11-12`: «Geo targeting (US IP only) is configured on the GrowthBook flag itself via the `country` attribute». PRMV-17727.
- `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/hooks/useFtcSoftChanges.ts:16-17` — `useFeatureIsOn(FTC_SOFT_CHANGES)`, комментарий `:12-14`: «Geo targeting (G8: UK, AU, CA, FR, LU, NL, CH, BE) is configured on the GrowthBook flag itself via the `country` attribute». PRMV-17964.

Семантика варианта:

- `hard` (`us_pricing_now_then`, US/CY/UA) — «{price} now, then {price} every {period}», per-period цифра **скрыта**, зачёркнутые/фейковые скидки скрыты, таймеры/urgency скрыты, чекаутный disclaimer в жёсткой формулировке. См. `packages/features/FunnelBuilder/code-funnels/money/_template/layouts/SalesLayout.tsx:56-73` и `packages/features/Checkout/CheckoutForm/components/UsPricingCheckoutDisclaimer/UsPricingCheckoutDisclaimer.tsx:18-21`.
- `soft` (`ftc_soft_changes`, G8) — now/then строка **плюс** per-period цифра остаётся видимой.
- при обоих `true` побеждает **soft** — более мягкая юридическая копия (`useFtcPricing.ts:29`). Порт в engine (`funnel-engine/src/growthbook.ts`, `ftcPricing`) это уже воспроизводит верно.

Аналогичная пара для лендингов (не воронок): `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/FunnelBuilder/hooks/useLandingsFtcPricing.ts:16-23` — `landings_ftc_hard_changes` / `landings_ftc_soft_changes`, та же формула.

### Записи в `packages/config/constants/remote_config.ts`

Ключи (`:42-45`):

```ts
export const US_PRICING_NOW_THEN = 'us_pricing_now_then'
export const FTC_SOFT_CHANGES = 'ftc_soft_changes'
export const LANDINGS_FTC_HARD_CHANGES = 'landings_ftc_hard_changes'
export const LANDINGS_FTC_SOFT_CHANGES = 'landings_ftc_soft_changes'
```

Дефолты в `DEFAULT_REMOTE_CONFIG` (`:137-140`):

```ts
  [US_PRICING_NOW_THEN]: false,
  [FTC_SOFT_CHANGES]: false,
  [LANDINGS_FTC_HARD_CHANGES]: false,
  [LANDINGS_FTC_SOFT_CHANGES]: false,
```

Важная деталь: эти четыре дефолта **никуда не передаются**. `useFeatureIsOn(key)` не принимает fallback, а `DEFAULT_REMOTE_CONFIG[...]` для FTC-ключей нигде не читается (проверено грепом: читаются только `USE_SAND_BOX`, `USE_CAPTCHA`, `COMPLIANCE_CONFIG`, `TOKENIZATION_FOR_WALLETS_SPLIT`, `USE_CONFIRMATION_BANNER`, `USE_AMETHYST_SALES_IOS_USERS`, `UPSELL_TRANSITION_SCREEN_V3`, `WEB_V3_DOWNSELL_AI_TUTOR`). То есть «выключено» для FTC — это дефолт самого GrowthBook, а не константа из репозитория. Это ровно то поведение, которое engine уже имитирует через `flagOn(...)` → `false`.

Тип флага: булев (не JSON с `split_analytics`), поэтому `useFeatureIsOn` возвращает труthiness значения фичи напрямую.

---

## 6. Есть ли в репозитории таблица «имя страны ↔ ISO»?

**Нет.** Проверено сплошным поиском (идентификаторы `countryName`, `COUNTRY_NAMES`, `countryCodeToName`, `nameToCode`, `isoToCountry`, `COUNTRY_MAP`, `COUNTRY_LIST`, `alpha2`, `iso3166`; `Intl.DisplayNames`; зависимости `i18n-iso-countries`, `country-list`, `countries-list`, `world-countries`, `iso-3166`, `react-phone-number-input` — ни одной).

Что есть вместо словаря:

1. **Единственный «мост» между форматами — сторонний ответ ip-api.** `packages/utils/customHooks/useQueryCountry.ts:5-20` отдаёт `country` (имя) и `countryCode` (ISO) рядом, из одного HTTP-ответа. Репозиторий берёт то или другое поле и **никогда не конвертирует**. То есть если targeting в GrowthBook написан по полным именам, вокабуляр этих имён — это вокабуляр **ip-api**, а не наш.
2. **`/Users/uvarovalexandr/myProject/promova.com_monorepo/apps/student/public/json/countries.json`** — 250 записей вида `{"name":{"common":"Kuwait","official":"State of Kuwait","nativeName":{…}}}` (сырой дамп restcountries.com). Кодов **нет вообще** (`grep -c cca2` → `0`). Плюс на файл нет ни одной ссылки из `.ts`/`.tsx` — мёртвый статик.
3. **`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/config/types/countries.ts`** — списки **только ISO-кодов**, с полным именем лишь в inline-комментарии (`'CY', // Cyprus`). Это не programmatic map, но именно здесь лежит нужный набор гео, `:39-54`:

```ts
// Single source of truth for the geos subject to FTC-style compliance treatment.
// US is the origin; CY/UA and the G8 set below were stretched on top. Kept as one
// list so individual geos can be dropped in a single place after the legal review.
export const FTC_COUNTRIES: string[] = [
  'US',
  'CY', // Cyprus
  'UA', // Ukraine
  'GB', // United Kingdom
  'AU', // Australia
  'CA', // Canada
  'FR', // France
  'LU', // Luxembourg
  'NL', // Netherlands
  'CH', // Switzerland
  'BE', // Belgium
]
```

и `:68-72`:

```ts
export const FTC_START_DISCLAIMER_COUNTRIES: string[] = [
  'US', // United States
  'CY', // Cyprus
  'UA', // Ukraine
]
```

`FTC_START_DISCLAIMER_COUNTRIES` = **ровно hard-набор** (`us_pricing_now_then`), а `FTC_COUNTRIES \ FTC_START_DISCLAIMER_COUNTRIES` = **ровно soft-набор G8** (`ftc_soft_changes`: GB, AU, CA, FR, LU, NL, CH, BE). Это тот словарь, который надо назвать: **hard и soft гео-наборы FTC уже есть в коде как ISO-списки**, независимо от GrowthBook. Используются, например, в `packages/features/FunnelBuilder/code-funnels/general-english/geoCompliance.ts:7` — `!!country && FTC_COUNTRIES.includes(country.toUpperCase())` (`usePersonalization().country` там — server-resolved ISO) и в `packages/utils/checkLegalAccess.ts:15-19`.

4. `country-flag-emoji-polyfill` (в `packages/ui/common/Shared/ClientLayout.tsx:5`) — только рендер флагов-эмодзи. `libphonenumber-js` — телефоны. Ни то, ни другое не используется как name↔code таблица.

**Вывод по п.6:** если прод действительно таргетит по полным именам, то этот вокабуляр существует **только внутри GrowthBook-дашборда и в ответах ip-api** — в репозитории его нет. Значит без доступа к UI восстановить точный список строк (`"United States"` vs `"United States of America"`, `"United Kingdom"` vs `"UK"`) нельзя. Это ровно то, что делает «слепое» исправление `country` рискованным.

---

## 7. `trackingCallback` / `gen_joined_ab_test`

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/growthbook/growthBook.ts:51-70`:

```ts
  /**
   * trackingCallback only required for A/B testing;
   * Called every time a user is put into an experiment (A/B test);
   * triggers when we use useFeatureValue or useFeatureIsOn hooks
   */
  trackingCallback: (experiment, result) => {
    /**
     * If the experiment.key is in the list of MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS,
     * we do not send automatically gen_joined_ab_test analytics for this key
     */
    if (MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS.includes(experiment.key)) {
      return
    }

    sendJoinABTestOncePerSession({
      key: experiment.key,
      value: result?.value?.value,
      split_analytics: result?.value?.split_analytics,
    })
  },
```

**Когда стреляет:** только на клиенте, только когда GrowthBook помещает визитёра в эксперимент — то есть на первом `useFeatureValue` / `useFeatureIsOn` для фичи, у которой есть experiment-правило. Серверная сторона (`GrowthBookMultiUser` / `UserScopedGrowthBook`) `trackingCallback` не имеет вовсе — событий с сервера нет.

**Payload** (`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/analytics.ts:1056-1092`):

```ts
export const sendJoinABTestOncePerSession = ({
  key,
  value,
  split_analytics,
}: SendAnalyticsOncePerSessionProps): void => {
  const isSendABTest = split_analytics?.send_event

  if (isAmplitudeInitialized()) {
    if (isSendABTest) {
      sendAnalyticsOncePerSession({
        eventName: AnalyticsEvent.GEN_JOINED_AB_TEST,
        data: {
          param_name: key,
          param_value: value,
        },
        key,
      })
    }

    const isSetUserProp = split_analytics?.send_user_prop

    if (isSetUserProp) {
      setUserProperties({
        [`ab_test.${key}`]: value,
      })
    }
  } else {
    waitForAmplitudeInit(() => { … })
  }
}
```

- имя события: `gen_joined_ab_test` (`packages/config/constants/analyticsEvents.ts:5`);
- поля: `param_name` = ключ фичи, `param_value` = `result.value.value` (то есть **вложенное** `value` из JSON-значения фичи, не сама фича);
- отправка гейтится **самим значением фичи**: `split_analytics.send_event` → событие, `split_analytics.send_user_prop` → user property `ab_test.<key>`. Тип — `DefaultJsonValueType` (`packages/config/constants/remote_config.ts:66-85`);
- дедуп — раз на сессию, по `key`;
- если Amplitude ещё не инициализирован — колбэк ждёт (`waitForAmplitudeInit`).

**Исключённые из автоматического пути** — `MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS`, `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/config/constants/remote_config.ts:157-178`, дословно:

```ts
export const MANUALLY_TRIGGERED_SEND_JOINED_AB_TEST_KEYS: string[] = [
  USE_FAKE_PROGRESS,
  USE_WEB_2_APP_PATH,
  USE_SOURCE_LANGUAGE_RECOMMENDATION,
  USE_POST_PURCHASE_FLOW,
  USE_NEW_AUTH_FORM,
  USE_AI_AND_HUMAN_TUTOR_ACCESS,
  USE_AMETHYST_SALES_IOS_USERS,
  USE_CONFIRMATION_BANNER,
  UPSELL_TRANSITION_SCREEN_V3,
  USE_FUNNEL_PROGRESS_BAR_MILESTONES,
  APP_BM_V3_CHECKOUT_REDIRECT_FLOW,
  USE_LANG_QUERY_PARAM,
  DISCLAIMER_FOR_US_1USD,
  PAUSE_BEFORE_CANCEL,
  US_PRICING_NOW_THEN,
  FTC_SOFT_CHANGES,
  LANDINGS_FTC_HARD_CHANGES,
  LANDINGS_FTC_SOFT_CHANGES,
  WEB_V3_DOWNSELL_AI_TUTOR,
  TOKENIZATION_FOR_WALLETS_SPLIT,
]
```

**Все четыре FTC-ключа в списке.** Значит для FTC-флагов `gen_joined_ab_test` из `trackingCallback` **никогда** не уходит; экспозиция шлётся вручную с экранов (`Sales.tsx:866,889,904,919,934,1227`, `Upsell.tsx:302,557`, `ElysiumPlans.tsx:140`, `Email.tsx:240`, `SplitScreen.tsx:34`, `useOnboardingScreen.ts:331…426`). Для engine это удобно: копируя FTC-флаг, никакого автоматического события воспроизводить не надо — только ручное, если понадобится парити по аналитике.

---

## 8. Что меняет резолв флага для анонимного визитёра

### 8a. Ранний return без `userId` — главный гейт

`/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/utils/customHooks/useAddGrowthBookAttributes.ts:64-67`:

```ts
  useEffect(() => {
    if (!userId || !growthBook || !country || (user && isExperimentsLoading)) {
      return
    }
```

где `userId = globalUser?.uid` (`:35`).

Ключевой нюанс, который легко прочитать неверно: **`globalUser` включает анонимные Firebase-сессии.** `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/store/stores/auth.ts:9-10`:

```ts
  // Raw Firebase user including anonymous sessions (legacy context.globalUser).
  globalUser: User | null
```

а «зарегистрированный» — это отдельный селектор, `auth.ts:42-45`:

```ts
// Registered user only — anonymous sessions read as null (legacy context.user).
export const selectAuthUser = (
  state: Pick<AuthState, 'globalUser'>
): User | null => (state.globalUser?.isAnonymous ? null : state.globalUser)
```

Анонимный вход делается сам: `/Users/uvarovalexandr/myProject/promova.com_monorepo/packages/features/Auth/authService.ts:198-205`:

```ts
  authSdk
    .signInAnonymously(authInstance)
    .then((userData) => {
      machineState = userData.user.isAnonymous ? 'anonymous' : 'registered'
      useAuthStore.getState().setGlobalUser(userData.user)
      runUserSideEffects(userData.user)
    })
```

**Следствие:** анонимный визитёр в проде в итоге **получает полный набор атрибутов**, включая `country` и `custom_user_id` (анонимный Firebase uid). Ранний return — это не «анонимных не таргетим», а **задержка**: атрибуты не уедут, пока не выполнятся ОБА условия — (а) Firebase SDK лениво загрузился и анонимный sign-in завершился, (б) ip-api ответил (`!country` — до ответа `country === ''`, `useQueryCountry.ts:22-37,70`).

Это правка к комментарию в `/Users/uvarovalexandr/myProject/funnel-engine/src/growthbook.ts:50-55`, где написано «Production's effect returns early without it, so an anonymous visitor there is evaluated with NO attributes at all». Точнее: без атрибутов оценивается **только начальное окно**, а не вся анонимная сессия.

### 8b. Окно, в котором FTC-флаг заведомо `false`

До того момента инстанс имеет только `{ device_id, platform, lang_query? }` (`growthBook.ts:42-44,81-84`), и `remoteEval` уже сходил на прокси с этим набором. FTC-хуки (`useFeatureIsOn`) **ничем не гейтятся** — ни `isGeoResolved`, ни `growthBookStatus`. Гейт по `growthBookStatus !== GrowthBookStatus.NOT_ATTRIBUTES_UPDATED` существует, но применяется только к отправке аналитики (`packages/features/FunnelBuilder/pages/Sales/Sales.tsx:944`, `pages/Sales/v2/components/SalesContextProvider.tsx:252`, `components/screens/onboarding/SplitScreen/SplitScreen.tsx:43`), не к рендеру FTC-варианта.

То есть на проде sales-страница сначала рендерится **не-FTC**, а потом перерисовывается в FTC, когда `updateAttributes` → новый remote-eval вернёт `true`. Engine, отдающий готовый HTML с первого байта, ведёт себя тут *лучше*, но и *иначе* — это не баг парити, но это причина, по которой сравнение «вживую в браузере» может обманывать.

### 8c. Прочее, что двигает резолв

- **`device_id` может быть пустым.** `growthBook.ts:17-33`: если кука `_ppdi` не записалась (Safari «block all cookies», sandboxed iframe), в атрибут уходит `''`. Percentage-rollout тогда стабильно не матчится. Тот же `device_id` читается заново в большой пачке (`useAddGrowthBookAttributes.ts:69`), так что оба чтения согласованы.
- **`funnel_id` в проде часто отсутствует.** Дамп `CODE_FUNNELS_MONEY_QA_FIX_PLAN_RESULT_01.md:162-165`: «No `funnel_id` key; `document.cookie` also has no `funnel_id`». Он ставится только через `useSetFunnelIdGrowthBook` (`packages/features/FunnelBuilder/hooks/useSetFunnelIdGrowthBook.ts:17-27`), которое вызывается из `code-funnels/FunnelContext.tsx:338`. Правило по `funnel_id` в проде для части воронок просто не матчится.
- **QA-оверрайды.** Клиент: `sessionStorage[GROWTH_BOOK_PAYLOAD]` → `setForcedFeatures` (`growthBook.ts:93-110`). Сервер/middleware: кука `gb_overrides` → `forcedFeatureValues` (`initializeGrowthBookServerSide.ts:145-166`, `handleLandingBuilderRewrite.ts:193`), UI — `packages/ui/common/ConfigWidgetGrowthBook/ConfigWidgetGrowthBook.tsx:101,191`. Если проверяешь флаг в браузере — убедись, что оверрайд не активен.
- `enableDevMode: process.env.NEXT_PUBLIC_LIVE_MODE !== 'true'` (`growthBook.ts:49`) — dev-режим сам по себе значения не меняет, но включает devtools-глобал; `usePageCoreLogic.tsx:41` ставит `window.growthBook = growthBookInstance`.

---

## Как сделать, чтобы второй сервис сходился с продом

### Что engine отправляет сейчас — подтверждено

`/Users/uvarovalexandr/myProject/funnel-engine/src/growthbook.ts:96-108`:

```ts
    const attributes: Record<string, unknown> = {
      custom_user_id: attrs.userId ?? '',
      country: attrs.country ?? '',
      utm_source: attrs.utmSource || 'organic',
      device: attrs.device ?? 'desktop',
      platform: 'web',
      device_id: attrs.deviceId,
    }
    if (attrs.funnelId) attributes['funnel_id'] = attrs.funnelId
    if (attrs.locale) attributes['localization'] = attrs.locale
```

Источники: `country` = `requestCountry(c)` → `c.req.header('cf-ipcountry')?.trim().toUpperCase()` (`funnel-engine/src/http.ts:117-118`) — **ISO alpha-2**; `device` = `isMobileRequest` по `sec-ch-ua-mobile` / UA (`http.ts:387-392`); `locale` = `requestLocale` из внутреннего заголовка `x-fe-locale`, дефолт `en` (`http.ts:414-415`); `userId` = Firebase uid из HMAC-запечатанной identity (`routes/sales.ts:122`); `funnelId` = `page.id` / `quiz.id`.

Набор ключей и их имена — **уже точная копия** клиентской пачки. Отличается только формат `country` и подмножество (нет `email`, `target_language`, `lang_query`, прочих `utm_*`).

### Конкретные изменения, не трогая правила GrowthBook

**A. Отправлять `country` в ДВУХ форматах одновременно — единственная правка, которая реально закрывает расхождение.**

GrowthBook игнорирует незнакомые атрибуты, поэтому лишний ключ безопасен, а вот **под каким именем** прод ждёт полное имя — неизвестно (в проде это тот же ключ `country`). Значит вариант «добавить второй ключ» не решает задачу, если правило написано на `country`. Реальные варианты:

- **A1 (рекомендуемый, слепо безопасный): послать ДВА запроса на `/api/eval` и объединить по OR.** Один с `country: "US"`, второй с `country: "United States"`; FTC-флаг считать включённым, если он `true` хотя бы в одном ответе. Правила GrowthBook при этом не меняются, а мы перестаём зависеть от того, в каком словаре они написаны. Цена — второй POST (кэш в `growthbook.ts` уже есть, ключ надо расширить форматом). Для hard/soft различения важно: OR применять **до** `ftcPricing()`, то есть слить `features` двух ответов флаг-за-флагом.
- **A2: заменить `country` на полное имя.** Соответствует клиентскому проду один-в-один — но ломает совпадение с серверным продом и с middleware, и требует словаря ISO→имя, которого в репозитории нет (§6). Слепо делать нельзя.
- **A3: оставить ISO.** Соответствует серверному проду и middleware, но именно клиент читает FTC-флаги — то есть это как раз текущее (неработающее) состояние.

**B. Источник полного имени, если идти в A1/A2.** Только `pro.ip-api.com` — поле `country` того же ответа, из которого прод берёт значение (`packages/utils/customHooks/useQueryCountry.ts:39-49`). Engine может дёрнуть `https://pro.ip-api.com/json/{ip}?key=…` с `cf-connecting-ip` (в `routes/quiz.ts:723` этот заголовок уже читается) и взять `country`. Это гарантирует **тот же словарь строк**, что у прода, вместо собственной таблицы. Минус — сетевой вызов на горячем пути, поэтому кэшировать по ISO-коду (`US` → `"United States"`) — маппинг стабилен, TTL можно взять большим.

**C. `utm_source`.** Engine уже делает `attrs.utmSource || 'organic'` — совпадает с `useAddGrowthBookAttributes.ts:32`. Оставить как есть. **Не** переходить на «не отправлять, если нет» (это серверное поведение прода, и оно ломает правило `utm_source = "organic"`).

**D. `custom_user_id`.** Прод отправляет анонимный Firebase uid **всегда** (после sign-in), а engine — пустую строку до email-экрана. Для percentage-rollout это значит, что все анонимные визитёры engine сидят в одном бакете. Для FTC-флагов (гео, 100%) это неважно; для любого реального split-теста — важно. Правка: если Firebase uid недоступен, класть в `custom_user_id` **стабильный per-visitor идентификатор** (тот же `deviceId`), а не `''`. Осторожно: это меняет бакетинг, поэтому делать только вместе с решением по A, не «до».

**E. `localization`.** Формат совпадает (`en`, `uk`, `es-419`, …). Стоит только сверить, что `requestLocale` не отдаёт локаль, которой нет в `LOCALES` (`packages/config/constants/common.ts:3-18`) — прод валидирует и падает в `'en'`.

**F. `lang_query`.** Прод посылает его и на клиенте, и на сервере; engine — нет. Дешёвая правка: если в URL есть `?lang=`, положить `lang_query` в lowercase+trim. Безопасно (флаг `use_lang_query_param` в проде отдельный, к FTC не относится).

**G. `funnel_id`.** Engine отправляет всегда, прод — часто **нет** (дамп B1b). Если правило FTC-флага случайно содержит условие по `funnel_id`, поведение разойдётся. Диагностика без доступа к UI: сделать `POST /api/eval` дважды — с `funnel_id` и без — и сравнить. Если ответы совпали, `funnel_id` в правилах FTC не участвует, и можно спокойно оставить.

**H. Что НЕ надо копировать:** `email`, `user_created_date`, `self_learning_premium_access`, `completed_first_lesson`, `ff_experiments_involved`, `target_language`. Это атрибуты зарегистрированного пользователя; на воронке до покупки прод их тоже не отправляет.

**I. Ключ подключения.** `POST /api/eval/{clientKey}` работает только на remote-eval SDK-connection, то есть engine обязан держать **клиентский** ключ (аналог `NEXT_PUBLIC_GROWTH_CLIENT_KEY`), а не серверный (`NEXT_PUBLIC_GROWTH_SERVERSIDE_CLIENT_KEY`). Это стоит проверить явно: если `GROWTHBOOK_CLIENT_KEY` в engine — серверный ключ, то FTC-флаги могут просто отсутствовать в его payload, и никакой формат `country` не поможет. Дешёвая проверка: сравнить список ключей в ответе `/api/eval` с ожидаемым (`Object.keys(data.features)` уже логируется в `growthbook.ts:118-124`) — если `us_pricing_now_then` в нём **есть**, но `false`, дело в атрибутах; если ключа **нет вообще** — дело в подключении.

### Что можно делать слепо, а что нет

**Безопасно слепо:**
- A1 (двойная оценка + OR по флагам) — правила не трогаются, худший случай = текущее поведение плюс один лишний POST;
- F (`lang_query`);
- E (валидация локали);
- I (диагностика подключения — чистое чтение);
- G (диагностический дифф с/без `funnel_id`);
- оставить `utm_source` с дефолтом `'organic'` (C).

**Слепо НЕЛЬЗЯ:**
- A2 (замена `country` на полное имя без подтверждённого словаря) — если промахнуться со строкой, US-визитёр молча не получит FTC-раскрытий; это юридический риск, а не косметика. Ровно та оговорка, что уже стоит в `funnel-engine/README.md:1666-1669`;
- D (заполнение `custom_user_id` device-id-ом) — меняет бакетинг всех процентных роллаутов;
- любую попытку «вывести» hard/soft локально из `FTC_COUNTRIES` вместо чтения флага. Списки в `packages/config/types/countries.ts:42-72` действительно совпадают с задокументированными гео-наборами (hard = `FTC_START_DISCLAIMER_COUNTRIES` = US/CY/UA; soft = остаток = G8), но это **параллельный** источник истины: если в GrowthBook кто-то выключит флаг или изменит гео, engine об этом не узнает и продолжит показывать FTC-копию. Как **временный** аварийный фолбэк, когда `/api/eval` вернул ошибку, — разумно; как основной путь — нет.

**Что всё равно требует человека с доступом к GrowthBook:** один вопрос — в каком словаре написано условие `country` у `us_pricing_now_then` и `ftc_soft_changes`. A1 позволяет не ждать ответа, но не отменяет необходимости его получить: пока он не получен, мы не знаем, работает ли флаг вообще (альтернативное объяснение «флаги просто выключены» из README всё ещё живо и снаружи выглядит идентично).
