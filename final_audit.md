# 🔍 Финальный Архитектурный Аудит — IQ Market Super App

> **Роль:** Senior Flutter Architect  
> **Дата:** 30.05.2026  
> **Охват:** ~99 файлов, lib/ + services + providers + screens  
> **Статус:** Pre-Release Code Review

---

## 1. Архитектура и бизнес-логика

### ✅ Что сделано правильно

- `TaxiProvider.dispose()` — все 8 StreamSubscription корректно отменены (строки 44–53 `taxi_provider.dart`)
- `TaxiServiceScreen.dispose()` — `_connectivitySubscription`, все 4 контроллера и FocusNode закрыты (строки 127–136)
- `ProfileScreen.dispose()` — `_timer`, `_tgSessionSub`, оба контроллера корректно закрыты (строки 126–131)
- `NotificationsScreen.dispose()` — `_tabController` закрыт
- Провайдеры (`TaxiProvider`, `AppConfigProvider`) содержат ТОЛЬКО бизнес-логику — молодцы

### 🟡 ПРЕДУПРЕЖДЕНИЯ

**[УТЕЧКА ПАМЯТИ — HIGH]** `taxi_service_screen.dart` строка **1134**:

```dart
// ❌ ПРОБЛЕМА: контроллер создаётся в _showFeedbackDialog, но НИКОГДА не dispose()-ится
void _showFeedbackDialog(...) {
  final TextEditingController commentController = TextEditingController();
  // ...нет commentController.dispose() после закрытия bottom sheet!
}
```

Этот диалог вызывается для каждой поездки. При 10 вызовах = 10 утечек контроллеров.

**Исправление:**
```dart
// ✅ ПРАВИЛЬНО: использовать dispose в builder
builder: (ctx) => StatefulBuilder(
  builder: (c, ss) {
    // ...
  },
),
// ПОСЛЕ закрытия:
).whenComplete(() => commentController.dispose());
```

**[СМЕШЕНИЕ ЛОГИКИ — MEDIUM]** `ad_service.dart` строки **216–225**:

```dart
// ⚠️ getActiveAdsStream() тянет 100 документов, затем фильтрует НА КЛИЕНТЕ:
static Stream<List<AdModel>> getActiveAdsStream() {
  return _adsCollection
      .orderBy('timestamp', descending: true)
      .limit(100)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(...)
          .where((ad) => ad.active && ad.status == 'active') // ← фильтр на клиенте
          .toList());
}
```

Поле `active` уже должно фильтроваться Firestore-запросом (`.where('active', isEqualTo: true)`), а не клиентом. Это лишние операции CPU при каждом снапшоте.

**[ЗАЩИТА ОТ ДУБЛЕЙ — MEDIUM]** `taxi_service_screen.dart` — нет флага `_isSubmitting` перед отправкой заявок:

```dart
// ❌ Нет защиты: быстрые двойные нажатия создадут 2 поездки
GestureDetector(
  onTap: () async {
    await provider.createPassengerOrder(...); // ← без isLoading-guard
  },
)
```

`TaxiProvider.createPassengerOrder()` и `createDriverRide()` используют `docId = 'order_${user.uid}_${DateTime.now().millisecondsSinceEpoch}'` — это хорошая защита от абсолютных дублей по времени, но **не защищает от нажатий с разницей >1мс** (что реально при быстром двойном тапе). Нужен UI-флаг.

---

## 2. UI/UX и Адаптивность

### ✅ Что сделано правильно

- Все bottom sheet используют `MediaQuery.of(ctx).viewInsets.bottom` — клавиатура не перекрывает поля ввода
- `SingleChildScrollView` внутри bottom sheet'ов предотвращает Bottom Overflow
- `NotificationsScreen` — `TabController` корректно создан и dispose()-ится

### 🟡 ПРЕДУПРЕЖДЕНИЯ

**[ЛОКАЛИЗАЦИЯ — MEDIUM]** Разрыв между языковыми системами:

В `TaxiProvider` язык хранится в `_curLang` (значения: `'ru'`, `'kz'`, `'uyg'`) через `taxiStrings`.  
В `AppConfigProvider` — `Locale('ru', 'RU')`, `Locale('kk', 'KZ')`.  
В `NotificationsScreen` — язык приходит как `'Русский'`, `'Қазақша'`, `'Уйғурчә'`.

Используются **3 разные системы хранения языка** в одном приложении. При смене языка в одном месте, статусы такси (`'Активен'`, `'Принят'` и т.д.) могут не обновиться в другом.

```dart
// taxi_provider.dart строка 154–157:
String translate(String? key) {
  return (taxiStrings[_curLang]?[key] ?? key).toString(); // 'ru'/'kz'/'uyg'
}
// Но main.dart строка 67–73 использует 'Русский'/'Қазақша' → несоответствие ключей
```

**[NAVIGATION — LOW]** `taxi_service_screen.dart` строка **153–158**:

```dart
PopScope(
  canPop: true,
  onPopInvokedWithResult: (didPop, result) {
    if (didPop) return;
    Navigator.of(context).pop(); // ← dead code: если didPop=true, этот блок недостижим
  },
)
```

Логика `onPopInvokedWithResult` с `canPop: true` + ручным `Navigator.pop()` избыточна — это двойной pop.

---

## 3. Экономия Firebase

### ✅ Что сделано правильно

- `persistenceEnabled: true` + 100MB кэш настроен в `main.dart` (строки 33–36) ✅
- `getAdsByIds` правильно разбивает на чанки по 10 (ограничение `whereIn`) ✅
- `getActiveAdsPaginated` использует пагинацию с `startAfterDocument` и `limit(20)` ✅
- `checkVerificationStatus` использует `.limit(1)` ✅
- `AdService.getAdById` использует `Source.cache` в offline-режиме ✅

### 🔴 КРИТИЧЕСКИЕ ПРОБЛЕМЫ

**[FIRESTORE — CRITICAL]** `taxi_provider.dart` строки **384–401**:

```dart
// ❌ НЕТ ЛИМИТА на taxi_rides и taxi_orders!
_ridesSub = FirebaseFirestore.instance
    .collection('taxi_rides')
    .where('status', isEqualTo: 'active')
    .snapshots() // ← При 1000+ активных поездок скачает ВСЁ!
    .listen(...);
```

Аналогично для `_ordersSub`. **При росте базы это убьёт приложение** — каждое изменение любой поездки будет пересылать весь список на все подключённые устройства.

**Исправление:**
```dart
.collection('taxi_rides')
.where('status', isEqualTo: 'active')
.limit(50)  // ← Обязательно добавить!
.snapshots()
```

**[FIRESTORE — HIGH]** `ad_service.dart` строка **317–325** — `getPendingAdsStream()` БЕЗ фильтра и лимита:

```dart
static Stream<List<AdModel>> getPendingAdsStream() {
  return _adsCollection
      .orderBy('timestamp', descending: true)
      // ❌ НЕТ .where('status', isEqualTo: 'pending')  ← фильтр только на клиенте!
      // ❌ НЕТ .limit(...)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map(...)
          .where((ad) => ad.status == 'pending')  // ← Фильтр ПОСЛЕ скачки всей коллекции!
          .toList());
}
```

Это означает, что при каждом снапшоте скачивается **вся коллекция `ads`** (включая активные, архивные, отклонённые), а фильтрация идёт на клиенте.

**[RATING READS — HIGH]** `taxi_provider.dart` строки **564–591** — `fetchUserRating()`:

```dart
// Эта функция вызывается при каждом элементе в списке поездок:
for (var doc in snapshot.docs) {
  if (data['driverId'] != null) {
    fetchUserRating(data['driverId']); // ← 1 read на юзера при каждом обновлении
  }
}
```

Есть кэш `_userRatings` — это хорошо. Но если водитель получит новый отзыв, **его рейтинг в кэше останется устаревшим** до перезапуска приложения. Кэш инвалидируется только в `submitReview()`, но не по таймауту.

---

## 4. Безопасность и стабильность

### ✅ Что сделано правильно

- `api_keys.dart` — **нет хардкода** ключей, все перенесены в Cloud Functions ✅
- `ErrorWidget.builder` переопределён в `main.dart` (строки 103–139) — глобальный ErrorWidget настроен ✅
- `Crashlytics` подключён для fatal и async ошибок ✅
- `FirebaseAppCheck` активирован с разными провайдерами для debug/release ✅
- `pauseFirebaseSync()` / `resumeFirebaseSync()` — потоки останавливаются при уходе с экрана ✅

### 🟡 ПРЕДУПРЕЖДЕНИЯ

**[БЕЗОПАСНОСТЬ — MEDIUM]** `taxi_provider.dart` строка **252**:

```dart
void setLoginStatus(bool status) {
  // ...
  startFirebaseSync(); // ← Запускает синк даже когда status=false (logout)!
}
```

При `status = false` всё равно вызывается `startFirebaseSync()`. Внутри функции есть проверка `if (user != null)` для личных подписок, но глобальные `_ridesSub` и `_ordersSub` запустятся даже для анонимного пользователя.

**[СТАБИЛЬНОСТЬ — MEDIUM]** `taxi_service_screen.dart` строки **831–854** — кнопки "Принять" / "Отклонить" bid без защиты от повторного нажатия:

```dart
GestureDetector(
  onTap: () async {
    HapticFeedback.mediumImpact();
    await provider.acceptBid(bidId); // ← Нет isLoading-флага!
    // Юзер может тапнуть дважды → 2 вызова acceptBid
  },
)
```

`acceptBid()` не идемпотентен полностью: он читает документ, обновляет его, и запускает цепочку обновлений. Двойной вызов может создать гонку.

**[БЕЗОПАСНОСТЬ — LOW]** `firestore.rules` не проверялся в этом аудите — рекомендую отдельно убедиться, что пользователь не может напрямую обновить `status: 'approved'` в `driver_verifications`.

---

## 5. ТОП-3 Критических места для нагрузки

### 🔴 #1 — Неограниченные стримы taxi_rides/taxi_orders
**Файл:** `taxi_provider.dart` строки **384–421**  
**Риск:** При 500+ активных поездок каждый новый заказ вызовет скачку **всего** снапшота на все устройства. O(N) reads × M пользователей = экспоненциальный рост стоимости Firebase и RAM.  
**Исправление:** Добавить `.limit(50)` + пагинацию или cursor-based подход.

---

### 🔴 #2 — `getPendingAdsStream()` без Firestore-фильтра
**Файл:** `ad_service.dart` строки **317–325**  
**Риск:** Скачивает **всю коллекцию `ads`** при каждом изменении любого объявления. При 10,000 объявлений — это 10,000 reads при каждом открытии Админ-панели.  
**Исправление:**
```dart
static Stream<List<AdModel>> getPendingAdsStream() {
  return _adsCollection
      .where('status', isEqualTo: 'pending')
      .orderBy('timestamp', descending: true)
      .limit(50)
      .snapshots()
      .map(...);
}
```

---

### 🔴 #3 — taxi_service_screen.dart (316KB, 6904 строки)
**Файл:** `taxi_service_screen.dart`  
**Риск:** Один `StatefulWidget` с ~30 методами-виджетами. Каждый вызов `setState()` или `notifyListeners()` из `TaxiProvider` перестраивает **весь** дерево виджетов экрана. При активном пользователе (2 stream события/сек) это означает 2 полных rebuild'а в секунду всего огромного дерева.  
**Решение:** Декомпозиция на изолированные `Consumer<TaxiProvider>` виджеты.

---

## Вердикт Senior-разработчика

| Область | Оценка | Комментарий |
|---------|--------|-------------|
| Безопасность ключей | ✅ 10/10 | Cloud Functions, AppCheck — отлично |
| Обработка ошибок | ✅ 9/10 | ErrorWidget + Crashlytics настроены |
| Управление стримами | 🟡 7/10 | Dispose() есть, но нет лимитов |
| Firebase экономия | 🔴 5/10 | 2 критических unbounded stream |
| Архитектура | 🟡 6/10 | God-file на 6904 строки |
| Локализация | 🟡 6/10 | 3 параллельных системы языка |
| Защита от дублей | 🟡 7/10 | docId с timestamp — хорошо, но нет UI-флага |

**Общая оценка: 7/10** — Проект стабилен для MVP/soft launch с небольшой нагрузкой.

---

## ✅ Готовность к декомпозиции taxi_service_screen.dart

**ПОДТВЕРЖДАЮ — ГОТОВ.**

Файл [taxi_service_screen.dart](file:///d:/iqmarket/lib/screens/taxi/taxi_service_screen.dart) (316KB, 6904 строк) является единственным самым большим узким местом. Инфраструктура готова:

- `TaxiProvider` правильно изолирует бизнес-логику
- `dispose()`/`resume` паузы уже реализованы корректно
- Вспомогательные виджеты (`taxi_order_card.dart`, `taxi_driver_card.dart`, `taxi_ui_components.dart`) уже выделены

### Предлагаемый план декомпозиции:

```
screens/taxi/
├── taxi_service_screen.dart          ← Оболочка (Scaffold + Provider)
├── tabs/
│   ├── passenger_tab.dart           ← Весь _passengerView()
│   └── driver_tab.dart              ← Весь _driverView()
├── dialogs/
│   ├── bid_details_bottom_sheet.dart
│   ├── feedback_dialog.dart         ← + dispose commentController!
│   ├── cancel_survey_dialog.dart
│   └── sos_dialog.dart
└── components/
    ├── taxi_top_bar.dart
    ├── taxi_header.dart
    ├── taxi_role_selector.dart
    └── active_bids_widget.dart
```

**Первый шаг к декомпозиции: `_showFeedbackDialog` → `feedback_dialog.dart`** (попутно исправит утечку `commentController`).
