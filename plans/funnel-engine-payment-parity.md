# funnel-engine: полный паритет по оплате с продом

Дата: 2026-09-10. Решение Алекса: «когда я говорил сделать всё как на проде —
платёжные системы тоже. Берём форму как на проде и вставляем сюда всю
стандартную форму, которую юзает Gimli».

Основание — ресёрч прода 2026-09-10 (агент по чекауту). Главное, что он снял:
**во фронте прода нет ни редиректов, ни поллинга, ни вебхуков.** Grep по
`poll|return_url|redirect_url|webhook` в `packages/features/Checkout` пустой.
Все способы оплаты — это кнопки внутри одного и того же смонтированного iframe
Solidgate, а завершение приходит теми же событиями `success` / `fail` / `error`,
которые движок уже обрабатывает. Поэтому объём переоценён с M на S+: это не
интеграция каждого способа, а флаги, гейты и параметры SDK.

---

## 1. Что есть у прода

| способ | как включается | что добавляет |
|---|---|---|
| карта | всегда (`isFormEnabled` по умолчанию `true`, `CheckoutForm.tsx:83`) | форма SDK |
| PayPal | флаг `show_paypal_button` (`useShowPaypalButton.ts:14-15`) + список из 23 валют (`paypalSupportedCurrencies.ts:1-25`) | отдельный эндпоинт `/v3/billing/paypal-orders/users/{id}` (`Checkout.ts:1535`), скрипт вендора инжектится тегом, флоу через DOM-события |
| Apple Pay | пропс по умолчанию `true` (`CheckoutForm.tsx:84`) | `applePayButtonParams` (`Checkout.ts:343-352`) |
| Google Pay | пропс по умолчанию `true` (`CheckoutForm.tsx:85`) | `googlePayButtonParams` (`Checkout.ts:354-357`) |
| **BLIK** | флаг `isShowBlikButton`, fail-closed `false` (`useShowBlikButton.ts:21-22`) + PL + PLN (`countries.ts:93-104`) | `blik: true` в теле заказа (`Checkout.ts:1195`) + `blikButtonParams.enabled` (`:371-374`) |
| **UPI Intent** | флаг `use_upi_payment` + Индия + INR (`useShowUpiButton.ts:22-30`) | только `upiButtonParams.enabled` (`Checkout.ts:376-379`), поля в теле нет |
| **Pix Automatico** | флаг `isShowPIXButton`, fail-closed (`useShowPixButton.ts:14-15`) + BRL (`CheckoutForm.tsx:139-140`) | `pix_automatico: true` (`Checkout.ts:1201`) + `pixAutomaticoButtonParams.enabled` (`:366-369`); легаси-кнопка Pix принудительно выключена (`:359-364`) |
| **MB Way** | флаг `isShowMBWayButton`, fail-closed (`useShowMbWayButton.ts:14-15`) + PT + EUR | `phone` в теле (`Checkout.ts:1202-1205`) + параметры кнопки |
| GCash | **в коде прода отсутствует полностью** — ни одной строки в `packages/`, включая сгенерированные схемы. Существует только как бэкенд-тикет PRMV-17114 | — |

Тело заказа прода (`OrderRequestV3`, `Checkout.ts:1184-1206`):
`billing_plan, currency, force_3ds, apple_pay, google_pay, blik, sandbox,
purchase_url, page_url, quiz_result_id?, channel?, pix_automatico?, phone?`

Форма монтируется так: скрипт `https://cdn.solidgate.com/js/solid-form.js`
(`CheckoutForm/constants.ts:3`) инжектится динамически
(`utils/loadSolidScript.ts:1-24`), затем `window.PaymentFormSdk.init(...)`
монтирует **iframe** в контейнер (`Checkout.ts:391-414`). Карта, Apple/Google
Pay, BLIK, UPI, Pix Automatico и MB Way — всё это подэлементы одного и того же
инстанса SDK, каждый со своим `*ButtonParams.enabled` + `containerId`
(`Checkout.ts:343-387`).

## 2. Что есть у движка сейчас

- `PAYMENT_TYPES` = `card`, `paypal`, `apple_pay`, `google_pay`
  (`src/checkout.ts:29`).
- В теле заказа `blik: false` **захардкожен**, `pix_automatico` и `phone`
  отсутствуют (`src/checkout.ts:88-100`).
- В инициализации SDK только два набора параметров — Google и Apple Pay
  (`src/render/checkout.ts:422-424`).
- PayPal есть, с гейтом флага и проверкой валют (сделано в P1-18).
- Заказ создаётся **серверно до рендера**, поэтому формa монтируется с готовыми
  credentials — у прода это браузерный вызов с 60-шаговым бэкоффом в ожидании
  SDK.

Одну прод-проблему движок при этом не наследует: прод откладывает первый монтаж
BLIK, пока не разрешится гео, чтобы не сделать второй POST на `solid-orders`
(`CheckoutForm.tsx:150-163`). У движка гео известно на сервере до рендера, и
заказ создаётся сразу с правильными флагами.

---

## 3. Работа, по этапам

### Этап 1 — четыре способа оплаты (S)

Для каждого: гейт (флаг GrowthBook + страна/валюта) → поле в теле заказа →
параметр SDK.

1. **BLIK** — флаг `isShowBlikButton` fail-closed, PL + PLN, `blik: true`,
   `blikButtonParams`.
2. **UPI** — флаг `use_upi_payment`, IN + INR, только `upiButtonParams`.
3. **Pix Automatico** — флаг `isShowPIXButton` fail-closed, BRL,
   `pix_automatico: true`, `pixAutomaticoButtonParams`, плюс принудительно
   выключить легаси-кнопку Pix, как делает прод.
4. **MB Way** — флаг `isShowMBWayButton` fail-closed, PT + EUR, `phone` в теле,
   параметры кнопки.

Все флаги читаются **один раз на заказ** и передаются в рендер: прод специально
снимает снапшот гейта Pix, чтобы флаг не перевернулся между POST'ом заказа и
инициализацией SDK (`Checkout.ts:258-263`). У движка это естественно — оба шага
в одном запросе.

Fail-closed у трёх флагов из четырёх воспроизвести дословно: отсутствующий или
нечитаемый флаг = кнопки нет. Способ оплаты, включившийся по ошибке чтения,
хуже отсутствующего.

### Этап 2 — `entity` и путь rebill в апселле (S/M) — закрывает и P3-9

- Снять `entity` из payload успеха SDK (значения прода: `form`, `applebtn`,
  `googlebtn`, `blikbtn`, `upi`).
- Хранить рядом с `orderId` в запечатанном куке — у прода это отдельный ключ
  `CHECKOUT_PAYMENT_ENTITY` в localStorage.
- `REBILL_PAY_TYPES = [applebtn, googlebtn, blikbtn]`
  (`FunnelBuilder/constants/common.ts:58-60,74`). UPI исключён **намеренно**:
  мандаты UPI нельзя перезарядить сохранённым токеном (комментарий там же,
  PRMV-18065).
- Под флагом `tokenization_for_wallets_split`: `orderId` сохраняется для любой
  успешной оплаты, включая кошельки; в `/v3/billing/upsales` уходит
  `payment_type: 'rebill'`, когда entity из списка. Без флага — `orderId`
  сохраняется только для не-rebill entity, то есть фактически карта и PayPal
  (`CheckoutManager.tsx:263-274`, `Upsell.tsx:743-757`).
- Тот же флаг гейтит и токенизацию BLIK, несмотря на слово wallets в имени
  (`remote_config.ts:34-36`).

### Этап 3 — CheckoutDownsell: one-click после отказа (M)

- `POST /v3/billing/one-click-pay` (`packages/api/billing.ts:235`), проверка
  права — `GET /v3/billing/one-click-pay?type=credit` (`:208-217`).
- Показывается только при совпадении четырёх условий: entity — карта
  (`EntityTypes.FORM`), есть `declineSubscription`, есть
  `ERROR_CHECKOUT_ORDER_ID`, и код отказа входит в
  `[TRANSACTION_IS_DECLINED, INSUFFICIENT_FUNDS, SUSPECTED_FRAUD]`
  (`CheckoutErrorSection.tsx:305-322`).
- Успешные состояния — `success` и `created` (`CheckoutDownsell.tsx:205-234`).
- У downsell-пути **своя копия текстов** отказов, отличная от основной
  (`CheckoutDownsell.tsx:53-70` против `CheckoutErrorSection.tsx:47-246`).

### Этап 4 — купоны и activation fee (S)

- `form.applyCoupon` на SDK, затем серверное сохранение
  `POST /v1/billing/coupon/users/{userId}` (`Checkout.ts:612-645`,
  `billing.ts:180-200`).
- Activation fee у прода — **только отображение**, отдельной логики списания во
  фронте нет (`showActivationFee` в `SubscriptionInfo.tsx:17,33,69,81`).

### Не делаем

- **GCash** — в коде прода отсутствует. «Как на проде» здесь означает «нет».
- **Легаси-Pix** (не Automatico) — прод его принудительно выключает, повторяем.
- **Три чекаут-формы тьюторинга** (`TutoringBaseCheckoutForm`,
  `LessonPurchaseCheckoutForm`, `GroupLessonsCheckoutForm`) — другой продукт,
  не воронки.

---

## 4. Что нужно снять отдельным ресёрчем перед реализацией

Агент по чекауту дал карту, но для дословного порта не хватает деталей. Это и
есть тот «отдельный ресёрч»:

1. **Полный набор `*ButtonParams`** для BLIK, UPI, Pix Automatico и MB Way:
   точные имена ключей, `containerId`, цвета/локали, порядок в объекте
   `init(...)` (`Checkout.ts:343-387` целиком, построчно).
2. **Откуда берётся `phone`** для MB Way — поле формы, профиль пользователя,
   или опционально пропускается. Прод описан как «optionally forwarded», это
   надо разрешить точно.
3. **Как SDK отдаёт `entity`** в payload успеха и полный список значений —
   нужен точный разбор `PayTypes` (`CheckoutForm/types.ts:81`) и обработчиков
   `Checkout.ts:499-546`.
4. **Полная таблица кодов отказа** и обе копии текстов (основная и
   downsell-путь), чтобы перенести дословно, а не пересказом.
5. **Валютные таблицы движка**: чего в них не хватает против прода. Известно,
   что PHP есть в списке PayPal (`paypalSupportedCurrencies.ts:17`), но
   отмечался как отсутствующий в FE-таблицах; PLN, INR, BRL надо проверить
   отдельно, иначе гейты по валюте не сработают.
6. **Как прод рендерит контейнеры кнопок в разметке** — какие div'ы и в каком
   порядке, потому что «вставляем стандартную форму как на проде» означает и
   верстку тоже.

## 5. Порядок

Этап 1 → этап 2 (нужен для апселла) → этап 4 → этап 3. CheckoutDownsell
последним: он самый большой и единственный, который не влияет на способность
принять платёж, только на попытку спасти отказ.

Тесты на каждый этап, как договорено: гейты (флаг × страна × валюта — включая
fail-closed), тело заказа, выбор `payment_type` по entity, набор кодов отказа.
