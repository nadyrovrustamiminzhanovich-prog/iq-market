# 🕵️‍♂️ Жёсткий аудит мобильного приложения «IQ Market» перед публикацией в Google Play

Этот технический аудит составлен Senior Staff Engineer и QA Lead. Отчёт содержит детальный разбор уязвимостей безопасности, архитектурных недостатков, потенциальных утечек ресурсов, рисков отказа в прохождении модерации Google Play, ошибок локализации и стабильности.

В отчёте указаны конкретные файлы и строки кода. Проект оценен беспристрастно и честно.

---

## 1. 🛡️ Безопасность (Security)

### [Critical] Секретные ключи API и токены в открытом виде в репозитории
* **Файл:** [functions/.env](file:///d:/iqmarket/functions/.env#L6-L10)
* **Проблема:** Файл содержит реальные секреты: `TG_TOKEN` (токен Telegram-бота), `GEMINI_MODERATION_KEY` и `GEMINI_ASSISTANT_KEY` (ключи API Gemini), а также `WEBHOOK_SECRET` и `ADMIN_CHAT`. Все они закоммичены в открытом виде.
* **Что сломается:** Злоумышленники могут перехватить контроль над Telegram-ботом, исчерпать квоты/баланс Google Cloud Gemini API или слать спам от имени администрации.
* **Решение:** Полностью удалить файл `.env` из коммитов Git. Использовать Firebase Secret Manager: `firebase functions:secrets:set TG_TOKEN="value"`. В коде функций считывать их через `process.env.TG_TOKEN` или использовать декларативное связывание секретов для Firebase Functions v2 / v1.

### [Critical] Публичный доступ к конфиденциальным данным пользователей (Утечка персональных данных)
* **Файл:** [firestore.rules](file:///d:/iqmarket/firestore.rules#L37)
* **Проблема:** Правило для чтения профилей пользователей разрешает доступ всем без авторизации:
  ```javascript
  match /users/{userId} {
    allow read: if true;
  }
  ```
* **Что сломается:** Любой неавторизованный пользователь (или спам-скрейпер) может выгрузить всю базу данных пользователей из Firestore, включая персональные номера телефонов (`phone`) и адреса электронной почты (`email`). Это прямое нарушение GDPR и Закона РК «О персональных данных и их защите», что повлечет юридические риски и блокировку в Google Play.
* **Решение:** Запретить публичное чтение приватных полей. Разрешить полный `read` только владельцу и админу, а для публичных нужд (просмотр профиля продавца) ограничить список полей (например, отдавать только `name`, `photoUrl`, `rating`) или проверять `request.auth != null`:
  ```javascript
  match /users/{userId} {
    allow read: if isSignedIn();
  }
  ```

### [High] Подмена автора сообщения (Sender Spoofing) в чате
* **Файл:** [firestore.rules](file:///d:/iqmarket/firestore.rules#L84-L89)
* **Проблема:** Правило обновления сообщений:
  ```javascript
  allow update: if isSignedIn() && (request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users) && (
    (request.auth.uid == resource.data.senderId) || 
    (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']))
  );
  ```
  Если `request.auth.uid == resource.data.senderId`, отправитель сообщения может обновить документ сообщения без ограничений по изменяемым полям.
* **Что сломается:** Отправитель сообщения может сделать `update` и изменить поле `senderId` на `uid` получателя. Это позволит подделать переписку (сделать так, будто получатель сам написал оскорбительное сообщение), что нарушает целостность данных системы.
* **Решение:** Ограничить список полей, которые отправитель может редактировать (например, разрешить изменять только `text` или `mediaUrl`, запретив менять `senderId` и `timestamp`):
  ```javascript
  allow update: if isSignedIn() && (request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.users) && (
    (request.auth.uid == resource.data.senderId && !request.resource.data.diff(resource.data).affectedKeys().hasAny(['senderId', 'timestamp'])) || 
    (request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']))
  );
  ```

---

## 2. 💣 Стабильность и крэши (Stability & Crashes)

### [High] Зависание удаления файлов / Отказ в доступе (Permission Denied) в Storage Rules
* **Файл:** [storage.rules](file:///d:/iqmarket/storage.rules#L26-L41)
* **Проблема:** Правила записи для папок `voice_messages` и `chat_media` содержат условие проверки размера файла:
  ```javascript
  allow write: if isSignedIn() 
               && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.users
               && request.resource.size < 15 * 1024 * 1024;
  ```
  При удалении файла (метод `delete`) объект `request.resource` равен `null`. Попытка прочесть `request.resource.size` во время операции `delete` вызывает ошибку выполнения правил безопасности Firebase Storage.
* **Что сломается:** При очистке чата или удалении сообщения методы [ChatService.deleteMessages](file:///d:/iqmarket/lib/services/chat_service.dart#L271) и [clearChat](file:///d:/iqmarket/lib/services/chat_service.dart#L299) завершатся ошибкой прав доступа `[storage/unauthorized] User does not have permission to access this object.` Файлы в облаке останутся навсегда, накапливая дисковый кэш и расходы на хостинг.
* **Решение:** Проверять наличие `request.resource` перед оценкой его параметров, либо разделить правила на `create` и `delete`:
  ```javascript
  allow create: if isSignedIn() 
                && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.users
                && request.resource.size < 15 * 1024 * 1024;
  allow delete: if isSignedIn() 
                && request.auth.uid in firestore.get(/databases/(default)/documents/chats/$(chatId)).data.users;
  ```

### [High] Unhandled Exception при попытке воспроизведения или редактирования поврежденного видео
* **Файлы:** [lib/screens/video_trimmer_screen.dart](file:///d:/iqmarket/lib/screens/video_trimmer_screen.dart#L45) и [lib/screens/video_editor_screen.dart](file:///d:/iqmarket/lib/screens/video_editor_screen.dart#L40)
* **Проблема:** Метод `_controller!.initialize()` вызывается асинхронно без обертывания в `try/catch`.
* **Что сломается:** Если пользователь выберет поврежденный видеофайл или файл с неподдерживаемым кодеком, инициализация плеера выбросит необработанное исключение. Экран навсегда зависнет на состоянии загрузки (потому что `_isLoaded` останется `false`), а приложение может упасть.
* **Решение:** Обернуть вызовы инициализации в `try/catch`, выводить ошибку пользователю и закрывать экран:
  ```dart
  try {
    await _controller!.initialize();
  } catch (e) {
    debugPrint("Video init error: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ошибка воспроизведения видео")));
      Navigator.pop(context);
    }
    return;
  }
  ```

### [High] Крэш «setState() called after dispose()» при проверке водителя
* **Файл:** [lib/screens/taxi/driver_verification_screen.dart](file:///d:/iqmarket/lib/screens/taxi/driver_verification_screen.dart#L323) и [L326](file:///d:/iqmarket/lib/screens/taxi/driver_verification_screen.dart#L326)
* **Проблема:** В методе `_runAnalysis` происходят долгие асинхронные вызовы: сжатие картинок, загрузка в Storage, анализ ИИ Gemini и задержка `_delay(600)`. После их завершения вызывается `setState()`, но проверка `mounted` отсутствует.
* **Что сломается:** Если пользователь запустит проверку документов и закроет экран (или свернет/перейдет назад), до того как завершится долгий запрос к Gemini, вызов `setState()` на уничтоженном виджете вызовет фатальное исключение Flutter.
* **Решение:** Добавить проверку `if (mounted)` перед каждым вызовом `setState` после операций с `await`:
  ```dart
  if (mounted) {
    setState(() { _analyzing = false; _done = true; });
  }
  ```

### [Medium] Небезопасный парсинг JSON в отчете ИИ
* **Файл:** [lib/services/gemini_service.dart](file:///d:/iqmarket/lib/services/gemini_service.dart#L207)
* **Проблема:** `jsonDecode(cleanJson) as Map<String, dynamic>` вызывается напрямую для ответа ИИ-модели.
* **Что сломается:** Если Gemini вернет невалидный JSON, или добавит лишний текст вне блоков разметки, `jsonDecode` выбросит `FormatException`. Метод вернет ошибку, хотя сама сессия могла быть успешной.
* **Решение:** Обернуть вызов `jsonDecode` в `try/catch` внутри `analyzeDriverDocuments` и корректно перехватывать ошибку парсинга:
  ```dart
  try {
    return jsonDecode(cleanJson) as Map<String, dynamic>;
  } catch (e) {
    return {
      'error': 'JSON_PARSE_ERROR',
      'confidence': 'low',
      'reason': 'Ошибка распознавания документов системой ИИ'
    };
  }
  ```

---

## 3. ⚡ Производительность и утечки памяти (Performance & Leaks)

### [High] Тяжелая утечка ресурсов при сжатии видео (Background Processing Leak)
* **Файлы:** [lib/screens/video_trimmer_screen.dart](file:///d:/iqmarket/lib/screens/video_trimmer_screen.dart#L98) и [lib/screens/video_editor_screen.dart](file:///d:/iqmarket/lib/screens/video_editor_screen.dart#L89)
* **Проблема:** Во время компрессии видео (`VideoCompress.compressVideo`) пользователь может нажать кнопку «Назад», чтобы прервать операцию. Метод `dispose()` уничтожает плеер, но никак не останавливает процесс сжатия.
* **Что сломается:** Видеоконвертер продолжит сжимать видео в фоновом режиме на процессоре устройства. Это приведет к сильному нагреву телефона, ускоренному разряду батареи и возможному завершению приложения ОС по причине нехватки памяти (OOM / Out-of-Memory).
* **Решение:** В методе `dispose()` вызывать отмену компрессии:
  ```dart
  @override
  void dispose() {
    VideoCompress.cancelCompress();
    // ... остальной dispose
  }
  ```

### [High] Отсутствие остановки аудиозаписи при закрытии чата
* **Файл:** [lib/screens/chat_screen.dart](file:///d:/iqmarket/lib/screens/chat_screen.dart#L153)
* **Проблема:** В методе `dispose()` уничтожается `_recorder`, но не вызывается метод `stop()`, если в этот момент шла активная запись голоса.
* **Что сломается:** В зависимости от реализации плагина `record`, вызов `dispose()` на пишущем рекордере может вызвать аппаратную ошибку аудиокодека Android (MediaRecorder error) или оставить фоновую запись висеть, что приведет к утечке памяти и блокировке микрофона для других приложений.
* **Решение:** Принудительно останавливать запись в `dispose()`:
  ```dart
  @override
  void dispose() {
    if (_isRecording) {
      _recorder.stop();
    }
    _recorder.dispose();
    // ...
  }
  ```

---

## 4. 🤖 Соответствие политикам Google Play (Google Play Policies)

### [High] Спам-уведомления от заблокированных пользователей (Нарушение UGC Policy)
* **Файл:** [functions/index.js](file:///d:/iqmarket/functions/index.js#L22) (триггер `onNewMessage`)
* **Проблема:** Когда пользователь отправляет сообщение, триггер `onNewMessage` отправляет Push-уведомление через Firebase Cloud Messaging получателю. При этом база данных `blockedUserIds` получателя никак не проверяется.
* **Что сломается:** Если пользователь А заблокировал пользователя Б, пользователь Б всё еще может слать сообщения в общий чат через API. При этом получателю А на экран телефона будут приходить Push-уведомления со спамом от Б. Это прямое нарушение правил Google Play UGC (User Generated Content), требующих полного исключения контактов и уведомлений от заблокированных субъектов.
* **Решение:** Внутри облачной функции `onNewMessage` прочесть массив `blockedUserIds` получателя из `/users/{receiverId}` и прекратить отправку уведомления, если ID отправителя находится в этом списке:
  ```javascript
  const receiverDoc = await db.collection('users').doc(receiverId).get();
  if (receiverDoc.exists) {
    const blocked = receiverDoc.data().blockedUserIds || [];
    if (blocked.includes(senderId)) {
      console.log(`[onNewMessage] Skip FCM: sender ${senderId} is blocked by receiver ${receiverId}`);
      return;
    }
  }
  ```

### [Medium] Неиспользуемые чувствительные разрешения в манифесте
* **Файл:** [android/app/src/main/AndroidManifest.xml](file:///d:/iqmarket/android/app/src/main/AndroidManifest.xml#L12)
* **Проблема:** Запрошено разрешение:
  ```xml
  <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
  ```
* **Что сломается:** Приложение использует микрофон для записи голосовых сообщений и воспроизводит их. Однако функция выбора готовых музыкальных или аудиофайлов из локальной памяти устройства отсутствует. Google Play Console выдаст предупреждение или отклонит публикацию из-за запроса избыточных медиа-разрешений (Policy: Data Minimization).
* **Решение:** Удалить строку с `<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />` из `AndroidManifest.xml`.

---

## 5. 🗣️ Локализация (Localization)

### [High] Захардкоженный русский текст на экранах авторизации и чата
* **Файл:** [lib/screens/login_screen.dart](file:///d:/iqmarket/lib/screens/login_screen.dart#L399-L420)
* **Проблема:** Инструкции по Telegram-верификации полностью жестко прописаны на русском языке:
  - `label: 'Продолжить с Mail.ru'` (L886)
  - `label: 'Продолжить с Google'` (L899)
  - `'Открыть Telegram'` (L467)
  - `'Открытие Telegram через $remaining сек...'` (L444)
  - `'Код действителен в течение 5 минут'` (L609)
  - `'❌ Неверный код. Попробуйте еще раз'` (L684)
  Также в [lib/widgets/common/offline_wrapper.dart](file:///d:/iqmarket/lib/widgets/common/offline_wrapper.dart#L61) текст `'Нет подключения к интернету'` захардкожен.
* **Что сломается:** Пользователь, выбравший казахский или уйгурский язык, столкнется со смесью языков (экран входа будет на русском, а внутренности на выбранном языке). Это ухудшает UX и локализационную оценку.
* **Решение:** Перенести все строки в `TranslationService` / `loginStrings` и использовать вызов `TranslationService.t(...)`.

### [Medium] Fallback Уйгурского языка на английский (English Locale mapping)
* **Файл:** [lib/main.dart](file:///d:/iqmarket/lib/main.dart#L74)
* **Проблема:** В словаре соответствий `Уйғурчә` привязана к системной локали `en_US`:
  ```dart
  'Уйғурчә': const Locale('en', 'US'),
  ```
* **Что сломается:** Если пользователь выбирает уйгурский язык, то системные диалоги (копирование/вставка, календари, выбор времени, системные предупреждения) отобразятся на английском языке, а не на русском или казахском, что было бы более логично и понятно жителям Казахстана.
* **Решение:** Использовать официальный код уйгурского языка `ug` (`Locale('ug')`) или настроить fallback на `ru_RU` / `kk_KZ` для системных компонентов, если уйгурский язык не поддерживается ОС.

---

## 6. 🔄 Граничные случаи и UX (Edge Cases)

### [Medium] Зависший/замороженный таймер отсчета в Telegram Login
* **Файл:** [lib/screens/login_screen.dart](file:///d:/iqmarket/lib/screens/login_screen.dart#L357-L365)
* **Проблема:** Таймер обратного отсчета работает через `Timer.periodic`, который вызывает `setState` родительского виджета `_LoginScreenState`. Сам текст таймера находится внутри диалоговой шторки `StatefulBuilder` (L368), чье состояние (`ss`) при этом не обновляется.
* **Что сломается:** Текст «Открытие Telegram через 4 сек...» зависнет на цифре 4 и не сдвинется до тех пор, пока бот не откроется автоматически. Это создает ощущение зависшего приложения.
* **Решение:** Вызывать обновление состояния шторки (`ss(() {})`) внутри таймера, либо перенести логику таймера в контроллер/ValueNotifier.

### [Low] Неактивная кнопка входа через Mail.ru
* **Файл:** [lib/screens/login_screen.dart](file:///d:/iqmarket/lib/screens/login_screen.dart#L892-L895)
* **Проблема:** Кнопка «Продолжить с Mail.ru» имеет пустой обработчик `onTap: () {}`.
* **Что сломается:** Элемент выглядит интерактивным, но при клике ничего не происходит.
* **Решение:** Реализовать вход либо временно скрыть кнопку до реализации фичи.

---

## 🔍 Не проверено (Требует ручного тестирования на реальных устройствах)
* **Push-уведомления в фоне (FCM):** Доставка push-уведомлений при закрытом приложении на китайских устройствах (Xiaomi, Meizu) требует ручной проверки из-за агрессивного энергосбережения MIUI/HyperOS.
* **Аппаратный GPS-трекинг:** Работа GPS-модуля при блокировке экрана в режиме такси (не засыпает ли сервис геолокации).
* **Сжатие видео на старых Android-устройствах:** На чипах MediaTek младших серий сжатие видео через `video_compress` может приводить к падению нативного кодека (нужен прогон на тестовых стендах Firebase Test Lab).

---

## 📋 Итоговая таблица проблем

| № | Файл | Уровень | Проблема | Блокирует релиз? | Решение |
|---|------|---------|----------|------------------|---------|
| 1 | `functions/.env` | 🔴 **Critical** | Ключи API и токены TG в открытом репозитории | **ДА** (Блокатор) | Перенести секреты в Cloud Secrets |
| 2 | `firestore.rules` | 🔴 **Critical** | Открытый доступ на чтение `/users` (слив телефонов/email) | **ДА** (Блокатор) | Разрешить чтение только для `isSignedIn()` |
| 3 | `storage.rules` | 🟠 **High** | Сбой `request.resource.size` при `delete` (нельзя очистить чат) | **ДА** (Блокатор) | Добавить проверку `request.resource != null` |
| 4 | `firestore.rules` | 🟠 **High** | Подмена `senderId` отправителем при обновлении сообщения | **ДА** (Блокатор) | Запретить изменение `senderId` в `affectedKeys` |
| 5 | `functions/index.js` | 🟠 **High** | Push-уведомления приходят от заблокированных пользователей | **ДА** (Блокатор) | Проверять `blockedUserIds` в триггере FCM |
| 6 | `video_trimmer_screen.dart` | 🟠 **High** | Нет отмены `VideoCompress` при закрытии экрана (утечка CPU/ОЗУ) | **ДА** (Блокатор) | Вызывать `cancelCompress()` в `dispose` |
| 7 | `video_trimmer/editor` | 🟠 **High** | Крэш при инициализации битого видео-файла | **ДА** (Блокатор) | Добавить `try/catch` на `.initialize()` |
| 8 | `driver_verification_screen.dart` | 🟡 **Medium** | setState после dispose без mounted проверки | Нет (Исправить после запуска) | Добавить `if (mounted)` |
| 9 | `login_screen.dart` | 🟡 **Medium** | Часть текстов авторизации захардкожена на русском | Нет (Исправить после запуска) | Перевести через `TranslationService` |
| 10 | `login_screen.dart` | 🟡 **Medium** | Замороженный таймер обратного отсчета в UI | Нет (Исправить после запуска) | Обновлять состояние StatefulBuilder шторки |
| 11 | `main.dart` | 🟡 **Medium** | Fallback уйгурского языка настроен на `en_US` | Нет (Исправить после запуска) | Сделать fallback на `ru_RU` или `Locale('ug')` |
| 12 | `login_screen.dart` | 🟢 **Low** | Пустая кнопка Mail.ru | Нет (Исправить после запуска) | Убрать или реализовать метод |
| 13 | `offline_wrapper.dart` | 🟢 **Low** | Захардкоженный русский текст баннера офлайна | Нет (Исправить после запуска) | Перевести через t() |
| 14 | `AndroidManifest.xml` | 🟢 **Low** | Лишнее разрешение `READ_MEDIA_AUDIO` | Нет (Исправить после запуска) | Удалить разрешение из манифеста |

---
**Итог по блокирующим факторам:** Из 14 найденных проблем **7 являются критическими и блокируют публикацию в Google Play** (из-за несоответствия правилам безопасности персональных данных, UGC-политике и рискам утечки коммерческих API-ключей). Остальные 7 проблем можно исправить сразу после релиза в плановых обновлениях.
