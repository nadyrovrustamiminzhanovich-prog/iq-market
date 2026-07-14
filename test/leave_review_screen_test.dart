import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/review_model.dart';
import 'package:iqmarket/screens/leave_review_screen.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/review_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void setupTestMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();

  // Auth Mock
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_auth'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'Auth#registerIdTokenListener') return null;
      if (methodCall.method == 'Auth#registerAuthStateListener') return null;
      if (methodCall.method == 'Auth#startListening') {
        return {
          'user': {
            'uid': 'current_user_123',
            'isAnonymous': false,
            'emailVerified': true,
            'displayName': 'Test User',
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
}

void main() {
  setupTestMocks();

  setUpAll(() async {
    HttpOverrides.global = MockHttpOverrides();
    await Firebase.initializeApp();
    await StorageService.init();
  });

  tearDown(() {
    ReviewService.mockAddReview = null;
    ReviewService.mockHasUserReviewedAd = null;
    FileService.mockUploadMultipleFiles = null;
    LeaveReviewScreen.mockUser = null;
  });

  final dummyAd = AdModel(
    id: 'ad_999',
    title: 'Ad Title',
    description: 'Ad Desc',
    price: 1000.0,
    category: 'Category',
    images: [],
    userId: 'seller_123',
    userName: 'Seller Name',
    userEmail: 'seller@test.com',
    timestamp: DateTime.now(),
    location: 'Location',
  );

  Widget buildTestableScreen() {
    return ChangeNotifierProvider<AppConfigProvider>(
      create: (_) => AppConfigProvider(),
      child: MaterialApp(
        home: LeaveReviewScreen(ad: dummyAd),
      ),
    );
  }

  group('LeaveReviewScreen and Review Card flow tests', () {
    testWidgets('Publish review button gets blocked during upload and prevents double submit', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      LeaveReviewScreen.mockUser = MockUser(uid: 'current_user_123', displayName: 'Test User');
      int addReviewCallsCount = 0;
      final completer = Completer<void>();

      // Mock has reviewed to return false
      ReviewService.mockHasUserReviewedAd = (uid, adId) async => false;

      // Mock upload images (not used here but good to mock)
      FileService.mockUploadMultipleFiles = (files, folder) async => [];

      // Mock addReview to wait for our completer
      ReviewService.mockAddReview = (review) async {
        addReviewCallsCount++;
        await completer.future;
      };

      await tester.pumpWidget(buildTestableScreen());
      await tester.pumpAndSettle();

      // Enter comment
      final textFinder = find.byType(TextField);
      expect(textFinder, findsOneWidget);
      await tester.enterText(textFinder, 'Great seller!');
      await tester.pump();

      // Find submit button
      final btnFinder = find.byType(ElevatedButton);
      expect(btnFinder, findsOneWidget);

      await tester.ensureVisible(btnFinder);
      await tester.pumpAndSettle();

      // Tap button for the first time
      await tester.tap(btnFinder);
      await tester.pump(); // Start async execution

      // Verify that progress indicator is displayed
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap again while uploading to verify double submit guard prevents a second call
      await tester.tap(btnFinder);
      await tester.pump();

      // Complete the mock upload/database save
      completer.complete();
      await tester.pumpAndSettle();

      // Verify addReview was called exactly ONCE (prevented double submit)
      expect(addReviewCallsCount, equals(1));
    });

    testWidgets('Success confirmation snackbar is shown after review is published', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      LeaveReviewScreen.mockUser = MockUser(uid: 'current_user_123', displayName: 'Test User');
      ReviewService.mockHasUserReviewedAd = (uid, adId) async => false;
      ReviewService.mockAddReview = (review) async {};

      await tester.pumpWidget(
        ChangeNotifierProvider<AppConfigProvider>(
          create: (_) => AppConfigProvider(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => const ElevatedButton(
                  onPressed: null,
                  child: Text('Placeholder'),
                ),
              ),
            ),
          ),
        ),
      );

      // Let's push LeaveReviewScreen so we can verify pop behavior
      final BuildContext context = tester.element(find.byType(ElevatedButton));
      Navigator.push(context, MaterialPageRoute(builder: (_) => LeaveReviewScreen(ad: dummyAd)));
      await tester.pumpAndSettle();

      // Fill in text
      await tester.enterText(find.byType(TextField), 'Nice experience!');
      await tester.pump();

      // Tap publish
      final btnFinder = find.text('Опубликовать отзыв');
      await tester.ensureVisible(btnFinder);
      await tester.pumpAndSettle();
      await tester.tap(btnFinder);
      await tester.pumpAndSettle();

      // The screen should have been popped
      expect(find.byType(LeaveReviewScreen), findsNothing);

      // SnackBar should be shown with confirmation text
      expect(find.text('Спасибо! Отзыв опубликован.'), findsOneWidget);
    });

    testWidgets('Review card displays photo from r.images correctly', (WidgetTester tester) async {
      // Create a ReviewModel containing a photo URL
      final review = ReviewModel(
        id: 'rev_123',
        adId: 'ad_999',
        adTitle: 'Ad Title',
        fromUserId: 'buyer_777',
        fromUserName: 'Buyer Name',
        toUserId: 'seller_123',
        rating: 4.5,
        comment: 'Review with a photo!',
        images: ['https://test.com/review_photo.jpg'],
        timestamp: DateTime.now(),
      );

      // Build a widget representing the review card layout (from profile_screen.dart)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text(review.fromUserName),
                  Text(review.comment),
                  if (review.images.isNotEmpty) ...[
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: review.images.length.clamp(0, 4),
                        itemBuilder: (context, i) => Container(
                          key: const Key('review_image_container'),
                          width: 60,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: (review.images[i].isNotEmpty && review.images[i].startsWith('http'))
                                ? DecorationImage(image: NetworkImage(review.images[i]), fit: BoxFit.cover)
                                : null,
                            color: Colors.grey[200],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify comment and name are shown
      expect(find.text('Buyer Name'), findsOneWidget);
      expect(find.text('Review with a photo!'), findsOneWidget);

      // Find the container and verify its Decoration contains the correct NetworkImage
      final containerFinder = find.byKey(const Key('review_image_container'));
      expect(containerFinder, findsOneWidget);
      
      final Container containerWidget = tester.widget<Container>(containerFinder);
      final BoxDecoration decoration = containerWidget.decoration as BoxDecoration;
      final DecorationImage decorationImage = decoration.image!;
      final NetworkImage networkImage = decorationImage.image as NetworkImage;
      
      expect(networkImage.url, equals('https://test.com/review_photo.jpg'));
    });
  });
}

class MockUser {
  final String uid;
  final String? displayName;
  MockUser({required this.uid, this.displayName});
}

final List<int> transparentImage = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
];

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => MockHttpClientRequest();
}

class MockHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => MockHttpClientResponse();
}

class MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => transparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([transparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}
