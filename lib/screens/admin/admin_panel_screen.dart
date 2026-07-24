import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import 'package:iqmarket/screens/admin/admin_ads_screen.dart';
import 'package:iqmarket/screens/admin/admin_users_screen.dart';
import 'package:iqmarket/screens/admin/admin_notifications_screen.dart';
import 'package:iqmarket/screens/admin/admin_reports_screen.dart';
import 'package:iqmarket/screens/admin/admin_dashboard_screen.dart';
import 'package:iqmarket/screens/admin/admin_taxi_screen.dart';
import 'package:iqmarket/services/ad_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription? _reportsSub;
  StreamSubscription? _adsSub;
  StreamSubscription? _usersSub;

  int _pendingAdsCount = 0;
  int _reportsCount = 0;

  bool _isInitialReports = true;
  bool _isInitialAds = true;
  bool _isInitialUsers = true;

  // Banner notification state
  String? _bannerTitle;
  String? _bannerBody;
  VoidCallback? _bannerOnTap;
  bool _showBanner = false;
  Timer? _bannerTimer;

  void _initAudio() async {
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
    } catch (e) {
      debugPrint('Error setting audio context: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Глобальная чистка архива (раз в месяц), если зашел админ
    AdService.runGlobalCleanupIfNeeded();
    _initAudio();
    _setupRealtimeListeners();
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    _adsSub?.cancel();
    _usersSub?.cancel();
    _audioPlayer.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _showNotificationBanner({
    required String title,
    required String body,
    required VoidCallback onTap,
  }) async {
    // Play sweet bubble notification sound (offline generated WAV)
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/admin_alert.wav');
      if (!await file.exists()) {
        final sampleRate = 22050;
        final durationMs = 250;
        final totalSamples = (sampleRate * durationMs / 1000).toInt();
        final bytesPerSample = 2;
        final subChunk2Size = totalSamples * bytesPerSample;
        final chunkSize = 36 + subChunk2Size;

        final header = ByteData(44);
        header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); // "RIFF"
        header.setUint32(4, chunkSize, Endian.little);
        header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); // "WAVE"
        header.setUint8(12, 0x66); header.setUint8(13, 0x6d); header.setUint8(14, 0x74); header.setUint8(15, 0x20); // "fmt "
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, 1, Endian.little);
        header.setUint32(24, sampleRate, Endian.little);
        header.setUint32(28, sampleRate * bytesPerSample, Endian.little);
        header.setUint16(32, bytesPerSample, Endian.little);
        header.setUint16(34, 16, Endian.little);
        header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61); // "data"
        header.setUint32(40, subChunk2Size, Endian.little);

        final data = Int16List(totalSamples);
        final firstBeepEnd = (sampleRate * 80 / 1000).toInt();
        final pauseEnd = (sampleRate * 110 / 1000).toInt();

        for (int i = 0; i < totalSamples; i++) {
          if (i < firstBeepEnd) {
            final t = i / sampleRate;
            final envelope = math.pow((firstBeepEnd - i) / firstBeepEnd, 1.5);
            data[i] = (math.sin(2 * math.pi * 987.77 * t) * 32767 * 0.25 * envelope).toInt();
          } else if (i < pauseEnd) {
            data[i] = 0;
          } else {
            final t = (i - pauseEnd) / sampleRate;
            final secondBeepLen = totalSamples - pauseEnd;
            final envelope = math.pow((totalSamples - i) / secondBeepLen, 2.0);
            data[i] = (math.sin(2 * math.pi * 1318.51 * t) * 32767 * 0.25 * envelope).toInt();
          }
        }

        final buffer = BytesBuilder();
        buffer.add(header.buffer.asUint8List());
        buffer.add(data.buffer.asUint8List());
        await file.writeAsBytes(buffer.toBytes());
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint('Audio play error: $e');
    }

    _bannerTimer?.cancel();
    if (mounted) {
      setState(() {
        _bannerTitle = title;
        _bannerBody = body;
        _bannerOnTap = onTap;
        _showBanner = true;
      });
    }

    _bannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showBanner = false;
        });
      }
    });
  }

  void _setupRealtimeListeners() {
    // 1. Listen to Unread Reports
    _reportsSub = FirebaseFirestore.instance.collection('reports').snapshots().listen((snapshot) {
      if (!mounted) return;

      final unreadCount = snapshot.docs.where((doc) {
        final data = doc.data();
        final isRead = data['isRead'] == true;
        final isResolved = data['status'] == 'resolved' || data['resolved'] == true;
        return !isRead && !isResolved;
      }).length;

      if (_isInitialReports) {
        setState(() {
          _reportsCount = unreadCount;
          _isInitialReports = false;
        });
        return;
      }

      // Check for newly added unread reports
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data?['isRead'] != true) {
            final title = data?['adTitle'] ?? data?['reportedUserName'] ?? 'Жалоба';
            final type = data?['type'] ?? 'другое';

            _showNotificationBanner(
              title: '⚠️ Новая жалоба!',
              body: '$title ($type)',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen()));
              },
            );
          }
        }
      }

      setState(() {
        _reportsCount = unreadCount;
      });
    }, onError: (err) {
      debugPrint('Admin reports sub error: $err');
    });

    // 2. Listen to Pending Ads
    _adsSub = FirebaseFirestore.instance.collection('ads').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
      if (!mounted) return;

      final docChanges = snapshot.docChanges;
      final totalPending = snapshot.docs.length;

      if (_isInitialAds) {
        setState(() {
          _pendingAdsCount = totalPending;
          _isInitialAds = false;
        });
        return;
      }

      // Check for newly added pending ads
      for (final change in docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final title = data?['title'] ?? 'Объявление';

          _showNotificationBanner(
            title: '📢 Новое объявление!',
            body: title,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen()));
            },
          );
        }
      }

      setState(() {
        _pendingAdsCount = totalPending;
      });
    });

    // 3. Listen to New Users
    _usersSub = FirebaseFirestore.instance.collection('users').snapshots().listen((snapshot) {
      if (!mounted) return;

      final docChanges = snapshot.docChanges;

      if (_isInitialUsers) {
        _isInitialUsers = false;
        return;
      }

      // Check for newly added users
      for (final change in docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final email = data?['email'] ?? data?['name'] ?? 'Новый пользователь';

          _showNotificationBanner(
            title: '👤 Новый пользователь!',
            body: email,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen()));
            },
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Светлый фон (Slate 50)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('IQ УПРАВЛЕНИЕ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Stack(
        children: [
          // Main Panel Screen
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),

                // Сетка статистики (Light Glass)
                Row(
                  children: [
                    _buildQuickStat('АКТИВНЫЕ', FirebaseFirestore.instance.collection('ads').where('active', isEqualTo: true).count().get(), PhosphorIcons.chartLineUp(), const Color(0xFF4A80F0)),
                    const SizedBox(width: 16),
                    _buildQuickStat('ПОЛЬЗОВАТЕЛИ', FirebaseFirestore.instance.collection('users').count().get(), PhosphorIcons.usersThree(), const Color(0xFF8B5CF6)),
                  ],
                ),

                const SizedBox(height: 40),
                Text('ИНСТРУМЕНТЫ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5)),
                const SizedBox(height: 20),

                // Сетка инструментов
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.9,
                  children: [
                    _buildToolCard(context, 'Аналитика', 'Пульс рынка', PhosphorIcons.chartPieSlice(), Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminDashboardScreen()))),
                    _buildToolCard(context, 'Модерация', 'Контроль контента', PhosphorIcons.shieldCheck(), Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())), badgeCount: _pendingAdsCount),
                    _buildToolCard(context, 'Юзеры', 'Сообщество', PhosphorIcons.userList(), Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen()))),
                    _buildToolCard(context, 'Такси', 'Контроль поездок', PhosphorIcons.taxi(), Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminTaxiScreen()))),
                    _buildToolCard(context, 'Рассылка', 'Push-уведомления', PhosphorIcons.paperPlaneTilt(), Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminNotificationsScreen()))),
                    _buildToolCard(context, 'Жалобы', 'Конфликты', PhosphorIcons.warningCircle(), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen())), badgeCount: _reportsCount),
                  ],
                ),
              ],
            ),
          ),

          // Slide-down Top Alert Banner
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            top: _showBanner ? 16 : -120,
            left: 16,
            right: 16,
            child: _buildBannerWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerWidget() {
    if (_bannerTitle == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () {
        setState(() => _showBanner = false);
        if (_bannerOnTap != null) _bannerOnTap!();
      },
      child: Material(
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _bannerTitle!,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _bannerBody!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                onPressed: () => setState(() => _showBanner = false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Добро пожаловать', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Row(
          children: [
            const CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('СИСТЕМА ОНЛАЙН', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, Future<AggregateQuerySnapshot> future, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 20),
            FutureBuilder<AggregateQuerySnapshot>(
                future: future,
                builder: (context, snapshot) {
                  final val = snapshot.hasData ? snapshot.data!.count.toString() : '...';
                  return Text(val, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)));
                }
            ),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap, {int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
              border: Border.all(color: Colors.grey.withValues(alpha: 0.05)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 16),
                  Text(title, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 26,
                  minHeight: 26,
                ),
                child: Center(
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
