import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:record/record.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/widgets/chat/chat_input.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

void setupTestMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock asset bundle to fake google_fonts asset presence and bypass HTTP calls & checksum checks.
  // Note: the variant part uses name descriptions (Regular, SemiBold, Bold, Black) instead of numeric weights.
  final fontManifest = {
    'google_fonts/Inter-Regular.ttf': ['google_fonts/Inter-Regular.ttf'],
    'google_fonts/Inter-SemiBold.ttf': ['google_fonts/Inter-SemiBold.ttf'],
    'google_fonts/Inter-Bold.ttf': ['google_fonts/Inter-Bold.ttf'],
    'google_fonts/Inter-Black.ttf': ['google_fonts/Inter-Black.ttf'],
  };
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
    if (message == null) return null;
    final String key = utf8.decode(message.buffer.asUint8List());
    if (key == 'AssetManifest.json') {
      final jsonStr = json.encode(fontManifest);
      final bytes = utf8.encode(jsonStr);
      return ByteData.view(Uint8List.fromList(bytes).buffer);
    }
    if (key == 'AssetManifest.bin') {
      return const StandardMessageCodec().encodeMessage(fontManifest);
    }
    if (key.startsWith('google_fonts/')) {
      return ByteData(20); // Dummy font bytes
    }
    return null;
  });

  setupFirebaseCoreMocks(); // Use official platform interface mocks for Firebase Core

  // Crashlytics Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_crashlytics'),
    (MethodCall methodCall) async {
      return <String, dynamic>{
        'isCrashlyticsCollectionEnabled': true,
      };
    },
  );

  // Auth Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_auth'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Auth#registerIdTokenListener') {
        return null;
      }
      if (methodCall.method == 'Auth#registerAuthStateListener') {
        return null;
      }
      if (methodCall.method == 'Auth#startListening') {
        return {
          'user': {
            'uid': 'current_user_123',
            'isAnonymous': false,
            'emailVerified': true,
          }
        };
      }
      return null;
    },
  );

  // Firestore Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/cloud_firestore'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'DocumentReference#get') {
        return {
          'data': {
            'users': ['current_user_123', 'other_user_456'],
          },
        };
      }
      if (methodCall.method == 'Query#snapshots') {
        return null;
      }
      return null;
    },
  );

  // Path Provider Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getTemporaryDirectory') {
        return '/tmp';
      }
      return null;
    },
  );

  // SharedPreferences Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'getAll') {
        return <String, dynamic>{};
      }
      return null;
    },
  );

  // Audioplayers Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'create') {
        final String? playerId = methodCall.arguments['playerId'] as String?;
        if (playerId != null) {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMessageHandler('xyz.luan/audioplayers/events/$playerId', (ByteData? message) async {
            return const StandardMethodCodec().encodeSuccessEnvelope(null);
          });
        }
      }
      return null;
    },
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async {
      return null;
    },
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('xyz.luan/audioplayers.global/events', (ByteData? message) async {
    return const StandardMethodCodec().encodeSuccessEnvelope(null);
  });
}

class FakeAudioRecorder extends Fake implements AudioRecorder {
  String? stoppedPath = '/tmp/fake_voice.m4a';
  bool stopCalled = false;
  bool hasPermissionValue = true;

  @override
  Future<bool> hasPermission({bool request = true}) async => hasPermissionValue;

  @override
  Future<void> start(RecordConfig config, {required String path}) async {
    stoppedPath = path;
  }

  @override
  Future<String?> stop() async {
    stopCalled = true;
    return stoppedPath;
  }

  @override
  Future<void> dispose() async {}
}

class FakeDocumentSnapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;
  final bool _exists;

  FakeDocumentSnapshot(this._data, this._exists);

  @override
  bool get exists => _exists;

  @override
  Map<String, dynamic>? data() => _data;
}

class FakeDocumentReference extends Fake implements DocumentReference<Map<String, dynamic>> {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> _snapshotsStream;

  FakeDocumentReference(this._snapshotsStream);

  @override
  String get id => 'msg_xyz';

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {}

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(collectionPath, _snapshotsStream);
  }

  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    return _snapshotsStream;
  }
}

class FakeCollectionReference extends Fake implements CollectionReference<Map<String, dynamic>> {
  final String _collectionName;
  final Stream<DocumentSnapshot<Map<String, dynamic>>> _snapshotsStream;

  FakeCollectionReference(this._collectionName, this._snapshotsStream);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return FakeDocumentReference(_snapshotsStream);
  }

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) async {
    return FakeDocumentReference(_snapshotsStream);
  }
}

class FakeFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> _snapshotsStream;

  FakeFirebaseFirestore(this._snapshotsStream);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return FakeCollectionReference(collectionPath, _snapshotsStream);
  }
}

void main() {
  setupTestMocks();

  setUpAll(() async {
    await Firebase.initializeApp();
    await StorageService.init();
  });

  group('ChatInput Widget Tests (Voice Recording)', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('Drag left past threshold triggers onRecordingCancelled', (WidgetTester tester) async {
      bool cancelTriggered = false;
      bool startTriggered = false;
      bool endTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              controller: controller,
              focusNode: focusNode,
              isTyping: false,
              isRecording: true, // Simulate recording state active
              recordSeconds: 5,
              showEmoji: false,
              onToggleEmoji: () {},
              onTextChanged: (_) {},
              onAttach: () {},
              onSend: () {},
              onLongPressStart: () {
                startTriggered = true;
              },
              onLongPressEnd: () {
                endTriggered = true;
              },
              onRecordingCancelled: () {
                cancelTriggered = true;
              },
              onEmojiSelected: (_) {},
              emojis: const ['😀'],
            ),
          ),
        ),
      );

      // Find the microphone button (which displays Icons.stop_rounded when recording)
      final micFinder = find.byIcon(Icons.stop_rounded);
      expect(micFinder, findsOneWidget);

      // Perform a drag gesture to the left
      final gesture = await tester.startGesture(tester.getCenter(micFinder));
      await tester.pump(const Duration(milliseconds: 600));

      // Drag left by 100 logical pixels (threshold is 80)
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();

      expect(cancelTriggered, isTrue);

      await gesture.up();
      await tester.pump();
    });

    testWidgets('Drag left less than threshold does not trigger onRecordingCancelled', (WidgetTester tester) async {
      bool cancelTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInput(
              controller: controller,
              focusNode: focusNode,
              isTyping: false,
              isRecording: true,
              recordSeconds: 5,
              showEmoji: false,
              onToggleEmoji: () {},
              onTextChanged: (_) {},
              onAttach: () {},
              onSend: () {},
              onLongPressStart: () {},
              onLongPressEnd: () {},
              onRecordingCancelled: () {
                cancelTriggered = true;
              },
              onEmojiSelected: (_) {},
              emojis: const ['😀'],
            ),
          ),
        ),
      );

      final micFinder = find.byIcon(Icons.stop_rounded);
      
      final gesture = await tester.startGesture(tester.getCenter(micFinder));
      await tester.pump(const Duration(milliseconds: 600));

      // Drag left by 40 logical pixels (less than 80 threshold)
      await gesture.moveBy(const Offset(-40, 0));
      await tester.pump();

      expect(cancelTriggered, isFalse);

      await gesture.up();
      await tester.pump();
    });
  });

  group('ChatScreen Widget Tests (Short Recording)', () {
    tearDown(() {
      ChatService.dbOverride = null;
    });

    testWidgets('Short recording less than 1s does not send message and triggers cleanup warning', (WidgetTester tester) async {
      final fakeRecorder = FakeAudioRecorder();
      final ad = AdModel(
        id: 'ad_123',
        userId: 'seller_123',
        userName: 'Seller Name',
        userEmail: 'seller@example.com',
        title: 'Test Ad',
        description: 'Test Ad description',
        price: 100,
        images: [],
        category: 'Electronics',
        status: 'approved',
        timestamp: DateTime.now(),
      );

      final firestoreController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      final fakeFirestore = FakeFirebaseFirestore(firestoreController.stream);

      firestoreController.add(FakeDocumentSnapshot({
        'lastActive': Timestamp.fromDate(DateTime.now()),
        'typing_seller_123': false,
      }, true));

      ChatService.dbOverride = fakeFirestore;

      try {
        await tester.pumpWidget(
          ChangeNotifierProvider<AppConfigProvider>(
            create: (_) => AppConfigProvider(),
            child: MaterialApp(
              home: Scaffold(
                body: ChatScreen(
                  ad: ad,
                  recorder: fakeRecorder,
                  firestore: fakeFirestore,
                ),
              ),
            ),
          ),
        );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find the mic icon to start recording
      final micBtn = find.byIcon(Icons.mic_rounded);
      expect(micBtn, findsOneWidget);

      // Start long press to begin recording
      final gesture = await tester.startGesture(tester.getCenter(micBtn));
      // Pump 600ms to trigger the long press threshold
      await tester.pump(const Duration(milliseconds: 600));

      // Now it should be recording (Icon changes to Icons.stop_rounded)
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      // Stop recording immediately (which means duration is < 1s)
      // runAsync delay must cover the 200ms Future.delayed inside _stopRecording()
      await tester.runAsync(() async {
        await gesture.up();
        await Future.delayed(const Duration(milliseconds: 600));
      });
      
      // Pump multiple frames to flush setState calls and render the SnackBar
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Verify that recording stopped (Icon changed back to Icons.mic_rounded)
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Verify that the stop method on recorder was called
      expect(fakeRecorder.stopCalled, isTrue);

      // Verify that the short recording SnackBar warning is displayed
      expect(find.text('Запись слишком короткая'), findsOneWidget);

      // Dismiss the SnackBar completely by pumping past its duration (3 seconds)
      await tester.pump(const Duration(seconds: 3));
      } finally {
        ChatService.dbOverride = null;
        await firestoreController.close();
      }
    });

    testWidgets('Error after successful upload shows warning and does not trigger retry', (WidgetTester tester) async {
      int uploadCalls = 0;
      
      // Override FileService to track calls and simulate success upload but failure on getDownloadURL
      FileService.uploadFileWithTaskOverride = (file, folder, {customFileName}) {
        uploadCalls++;
        final fakeRef = FakeReference('', throwOnGetUrl: true);
        final fakeSnapshot = FakeTaskSnapshot(fakeRef);
        return FakeUploadTask(Future.value(fakeSnapshot));
      };

      final fakeRecorder = FakeAudioRecorder();
      final ad = AdModel(
        id: 'ad_123',
        userId: 'seller_123',
        userName: 'Seller Name',
        userEmail: 'seller@example.com',
        title: 'Test Ad',
        description: 'Test Ad description',
        price: 100,
        images: [],
        category: 'Electronics',
        status: 'approved',
        timestamp: DateTime.now(),
      );

      final firestoreController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
      final fakeFirestore = FakeFirebaseFirestore(firestoreController.stream);

      firestoreController.add(FakeDocumentSnapshot({
        'lastActive': Timestamp.fromDate(DateTime.now()),
        'typing_seller_123': false,
      }, true));

      ChatService.dbOverride = fakeFirestore;

      try {
        UserService.mockUid = 'current_user_123';
        await tester.pumpWidget(
          ChangeNotifierProvider<AppConfigProvider>(
            create: (_) => AppConfigProvider(),
            child: MaterialApp(
              home: Scaffold(
                body: ChatScreen(
                  ad: ad,
                  recorder: fakeRecorder,
                  firestore: fakeFirestore,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        final micBtn = find.byIcon(Icons.mic_rounded);
        expect(micBtn, findsOneWidget);

        // Start long press to begin recording
        final gesture = await tester.startGesture(tester.getCenter(micBtn));
        // Pump 1500ms to exceed short recording threshold (1s)
        await tester.pump(const Duration(milliseconds: 1500));

        // Stop recording
        await tester.runAsync(() async {
          await gesture.up();
          await Future.delayed(const Duration(milliseconds: 500));
        });

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify that upload was called exactly once (no retries)
        expect(uploadCalls, equals(1));

        // Verify the warning SnackBar is shown
        expect(find.text('Файл загружен, но не удалось прикрепить сообщение.'), findsOneWidget);

        // Dismiss the SnackBar
        await tester.pump(const Duration(seconds: 4));
      } finally {
        UserService.mockUid = null;
        ChatService.dbOverride = null;
        FileService.uploadFileWithTaskOverride = null;
        await firestoreController.close();
      }
    });
  });
}

class FakeUploadTask extends Fake implements UploadTask {
  final Future<TaskSnapshot> _future;

  FakeUploadTask(this._future);

  @override
  Future<S> then<S>(FutureOr<S> Function(TaskSnapshot value) onValue, {Function? onError}) {
    return _future.then<S>(onValue, onError: onError);
  }

  @override
  Future<TaskSnapshot> catchError(Function onError, {bool Function(Object error)? test}) {
    return _future.catchError(onError, test: test);
  }
}

class FakeTaskSnapshot extends Fake implements TaskSnapshot {
  final Reference _ref;
  FakeTaskSnapshot(this._ref);

  @override
  Reference get ref => _ref;
}

class FakeReference extends Fake implements Reference {
  final String downloadUrl;
  final bool throwOnGetUrl;

  FakeReference(this.downloadUrl, {this.throwOnGetUrl = false});

  @override
  Future<String> getDownloadURL() async {
    if (throwOnGetUrl) {
      throw FirebaseException(
        plugin: 'storage',
        code: 'unauthorized',
        message: 'Mocked getDownloadURL permission denied error',
      );
    }
    return downloadUrl;
  }
}
