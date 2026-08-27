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

import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
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

  Future<void> _refreshAdminData() async {
    AdService.runGlobalCleanupIfNeeded();
    try {
      final reportsSnap = await FirebaseFirestore.instance.collection('reports').get();
      final unreadCount = reportsSnap.docs.where((doc) {
        final data = doc.data();
        final isRead = data['isRead'] == true || data['read'] == true;
        final isResolved = data['status'] == 'resolved' || data['status'] == 'dismissed' || data['resolved'] == true;
        return !isRead && !isResolved;
      }).length;

      final pendingAdsSnap = await FirebaseFirestore.instance
          .collection('ads')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _reportsCount = unreadCount;
          _pendingAdsCount = pendingAdsSnap.count ?? 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Данные админ-панели успешно обновлены! 🔄'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error refreshing admin data: $e');
    }
  }

  void _setupRealtimeListeners() {
    // 1. Listen to Unread Reports
    _reportsSub = FirebaseFirestore.instance.collection('reports').snapshots().listen((snapshot) {
      if (!mounted) return;

      final unreadCount = snapshot.docs.where((doc) {
        final data = doc.data();
        final isRead = data['isRead'] == true || data['read'] == true;
        final isResolved = data['status'] == 'resolved' || data['status'] == 'dismissed' || data['resolved'] == true;
        return !isRead && !isResolved;
      }).length;

      if (_isInitialReports) {
        setState(() {
          _reportsCount = unreadCount;
          _isInitialReports = false;
        });
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data?['isRead'] != true && data?['read'] != true) {
            final title = data?['adTitle'] ?? data?['reportedUserName'] ?? 'Жалоба';
            final type = data?['type'] ?? 'другое';

            _showNotificationBanner(
              title: '⚠️ Новая жалоба!',
              body: '$title ($type)',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen())).then((_) => _refreshAdminData());
              },
            );
          }
        }
      }

      setState(() {
        _reportsCount = unreadCount;
      });
    });

    // 2. Listen to Pending Ads
    _adsSub = FirebaseFirestore.instance.collection('ads').where('status', isEqualTo: 'pending').snapshots().listen((snapshot) {
      if (!mounted) return;

      final count = snapshot.docs.length;

      if (_isInitialAds) {
        setState(() {
          _pendingAdsCount = count;
          _isInitialAds = false;
        });
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final title = data?['title'] ?? 'Новое объявление';

          _showNotificationBanner(
            title: '📦 Новое объявление на модерации!',
            body: title,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())).then((_) => _refreshAdminData());
            },
          );
        }
      }

      setState(() {
        _pendingAdsCount = count;
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

      for (final change in docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final email = data?['email'] ?? data?['name'] ?? 'Новый пользователь';

          _showNotificationBanner(
            title: '👤 Новый пользователь!',
            body: email,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen())).then((_) => _refreshAdminData());
            },
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
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
        actions: [
          IconButton(
            icon: Icon(PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold), color: const Color(0xFF0F172A), size: 22),
            onPressed: _refreshAdminData,
            tooltip: 'Обновить данные',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold), color: const Color(0xFF0F172A), size: 22),
            onPressed: _showGlobalSearchDialog,
            tooltip: 'Глобальный поиск',
          ),
          IconButton(
            icon: Icon(PhosphorIcons.broom(PhosphorIconsStyle.bold), color: const Color(0xFF0F172A), size: 22),
            onPressed: () {
              AdService.runGlobalCleanupIfNeeded();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проверка и чистка архива выполнена! 🧹'), behavior: SnackBarBehavior.floating),
              );
            },
            tooltip: 'Очистка архива',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshAdminData,
            color: const Color(0xFF2563EB),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // 📊 4 Real-Time Metrics Cards
                  Row(
                    children: [
                      _buildQuickStat('ВСЕ ОБЪЯВЛЕНИЯ', FirebaseFirestore.instance.collection('ads').count().get(), PhosphorIcons.package(), const Color(0xFF4A80F0), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())).then((_) => _refreshAdminData());
                      }),
                      const SizedBox(width: 12),
                      _buildQuickStat('ПОЛЬЗОВАТЕЛИ', FirebaseFirestore.instance.collection('users').count().get(), PhosphorIcons.usersThree(), const Color(0xFF8B5CF6), () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen())).then((_) => _refreshAdminData());
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickStat('НА ПРОВЕРКЕ', null, PhosphorIcons.shieldCheck(), Colors.orange, () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())).then((_) => _refreshAdminData());
                      }, value: '$_pendingAdsCount'),
                      const SizedBox(width: 12),
                      _buildQuickStat('ЖАЛОБЫ', null, PhosphorIcons.warningCircle(), Colors.redAccent, () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen())).then((_) => _refreshAdminData());
                      }, value: '$_reportsCount'),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader('ИНСТРУМЕНТЫ АДМИНИСТРИРОВАНИЯ'),
                  const SizedBox(height: 16),

                  // Сетка инструментов 2x3
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.95,
                    children: [
                      _buildToolCard(context, 'Аналитика', 'Обзор и графики', PhosphorIcons.chartPieSlice(), Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminDashboardScreen()))),
                      _buildToolCard(context, 'Все объявления', 'Модерация и архив', PhosphorIcons.shieldCheck(), Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())).then((_) => _refreshAdminData()), badgeCount: _pendingAdsCount),
                      _buildToolCard(context, 'Пользователи', 'База и блокировки', PhosphorIcons.userList(), Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen())).then((_) => _refreshAdminData())),
                      _buildToolCard(context, 'Такси', 'Заказы и поездки', PhosphorIcons.taxi(), Colors.blue, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminTaxiScreen()))),
                      _buildToolCard(context, 'Рассылка', 'Push-уведомления', PhosphorIcons.paperPlaneTilt(), Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminNotificationsScreen()))),
                      _buildToolCard(context, 'Жалобы', 'Разрешение споров', PhosphorIcons.warningCircle(), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen())).then((_) => _refreshAdminData()), badgeCount: _reportsCount),
                    ],
                  ),

                  const SizedBox(height: 32),
                  _buildSectionHeader('ЖИВАЯ ЛЕНТА СОБЫТИЙ'),
                  const SizedBox(height: 14),
                  _buildLiveActivityStream(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Top Alert Banner
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title, 
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1.2),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.25), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Панель управления', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'СИСТЕМА ОНЛАЙН • СЕРВЕРЫ АКТИВНЫ',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF10B981), letterSpacing: 0.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(PhosphorIcons.shieldCheckered(PhosphorIconsStyle.bold), color: Colors.amber, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, Future<AggregateQuerySnapshot>? future, IconData icon, Color color, VoidCallback onTap, {String? value}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 6))],
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 14),
              if (value != null)
                Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)))
              else
                FutureBuilder<AggregateQuerySnapshot>(
                  future: future,
                  builder: (context, snapshot) {
                    final val = snapshot.hasData ? snapshot.data!.count.toString() : '...';
                    return Text(val, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)));
                  },
                ),
              const SizedBox(height: 2),
              Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500], letterSpacing: 0.5)),
            ],
          ),
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
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 12, offset: const Offset(0, 4))],
              border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)), textAlign: TextAlign.center),
                  const SizedBox(height: 3),
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
                  color: Colors.redAccent,
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

  Widget _buildLiveActivityStream() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ads').orderBy('timestamp', descending: true).limit(5).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(12), child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))));

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Padding(padding: const EdgeInsets.all(12), child: Text('Нет последних событий', style: GoogleFonts.inter(color: Colors.grey)));

          final lang = Provider.of<AppConfigProvider>(context, listen: false).language;

          return Column(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['id'] = doc.id;
              final ad = AdModel.fromMap(data, doc.id);
              final title = data['title'] ?? 'Объявление';
              final author = data['userName'] ?? 'Пользователь';
              final status = data['status'] ?? 'active';

              Color badgeColor = const Color(0xFF10B981);
              String statusLabel = 'АКТИВНО';
              if (status == 'pending') {
                badgeColor = Colors.orange;
                statusLabel = 'НА ПРОВЕРКЕ';
              } else if (status == 'rejected') {
                badgeColor = Colors.redAccent;
                statusLabel = 'ОТКЛОНЕНО';
              } else if (!ad.active) {
                badgeColor = Colors.grey;
                statusLabel = 'АРХИВ';
              }

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context, 
                      MaterialPageRoute(
                        builder: (c) => ProductDetailsScreen(ad: ad, lang: lang, onReport: (_) {}, heroPrefix: 'stream_')
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                          child: Icon(
                            status == 'pending' ? Icons.access_time_filled_rounded : Icons.shopping_bag_outlined,
                            color: badgeColor,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$author ➔ "$title"',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${ad.location} • ${ad.price.toInt()} ₸',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            statusLabel,
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: badgeColor),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
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
                    Text(_bannerTitle!, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
                    const SizedBox(height: 2),
                    Text(_bannerBody!, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey), onPressed: () => setState(() => _showBanner = false)),
            ],
          ),
        ),
      ),
    );
  }

  void _showGlobalSearchDialog() {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 24, right: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ГЛОБАЛЬНЫЙ ПОИСК ПО БАЗЕ', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            TextField(
              controller: searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Введите имя, телефон, email или заголовок товара...',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
              onSubmitted: (query) {
                Navigator.pop(context);
                if (query.trim().isNotEmpty) {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen()));
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
