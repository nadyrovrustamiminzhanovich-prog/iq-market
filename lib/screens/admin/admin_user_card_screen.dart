import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminUserCardScreen extends StatefulWidget {
  final String uid;
  const AdminUserCardScreen({super.key, required this.uid});

  @override
  State<AdminUserCardScreen> createState() => _AdminUserCardScreenState();
}

class _AdminUserCardScreenState extends State<AdminUserCardScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Map<String, dynamic>? _safeMap(dynamic input) {
    if (input is Map) {
      return input.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  List<Map<String, dynamic>> _safeList(dynamic input) {
    if (input is! Iterable) return [];
    return input.map((item) {
      if (item is Map) {
        return item.map((k, v) => MapEntry(k.toString(), v));
      }
      return <String, dynamic>{};
    }).toList();
  }

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getFullUserInfo');
      final HttpsCallableResult result = await callable.call({'targetUid': widget.uid});
      
      if (mounted) {
        setState(() {
          _data = _safeMap(result.data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[AdminUserCard] Cloud Function failed ($e), falling back to direct Firestore fetch...');
      await _loadUserInfoFromFirestore(widget.uid);
    }
  }

  Future<void> _loadUserInfoFromFirestore(String uid) async {
    try {
      final db = FirebaseFirestore.instance;
      
      // 1. Fetch main user document
      final userDoc = await db.collection('users').doc(uid).get();
      final profileData = userDoc.exists ? (userDoc.data() ?? {}) : <String, dynamic>{};
      
      // 2. Fetch contact info if available
      Map<String, dynamic> contactData = {};
      try {
        final contactDoc = await db.collection('users').doc(uid).collection('private').doc('contact').get();
        if (contactDoc.exists && contactDoc.data() != null) {
          contactData = contactDoc.data()!;
        }
      } catch (_) {}

      // 2b. Search tg_auth_sessions for Telegram phone & chat_id
      try {
        final rawTgId = uid.replaceAll('telegram_', '').replaceAll('tg_', '');
        if (RegExp(r'^\d+$').hasMatch(rawTgId)) {
          contactData['telegram_chat_id'] = rawTgId;
        }
        final tgSessions = await db.collection('tg_auth_sessions').where('initiatorUid', isEqualTo: uid).limit(5).get();
        for (final doc in tgSessions.docs) {
          final d = doc.data();
          if (d['phone'] != null && d['phone'].toString().isNotEmpty) {
            contactData['tg_session_phone'] = d['phone'].toString();
          }
          if (d['chat_id'] != null && d['chat_id'].toString().isNotEmpty) {
            contactData['telegram_chat_id'] = d['chat_id'].toString();
          }
        }
      } catch (_) {}

      // 3. Fetch user ads
      List<Map<String, dynamic>> adsList = [];
      try {
        final adsSnap = await db.collection('ads').where('userId', isEqualTo: uid).get();
        adsList = adsSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (_) {}

      // 4. Fetch reports against user
      List<Map<String, dynamic>> reportsAgainstList = [];
      try {
        final repAgainstSnap = await db.collection('reports').where('reportedUserId', isEqualTo: uid).get();
        reportsAgainstList = repAgainstSnap.docs.map((d) => d.data()).toList();
      } catch (_) {}

      // 5. Fetch reports submitted by user
      List<Map<String, dynamic>> reportsSubmittedList = [];
      try {
        final repSubSnap = await db.collection('reports').where('userId', isEqualTo: uid).get();
        reportsSubmittedList = repSubSnap.docs.map((d) => d.data()).toList();
      } catch (_) {}

      // 6. Fetch reviews received by user (toUserId == uid)
      List<Map<String, dynamic>> reviewsToList = [];
      try {
        final revToSnap = await db.collection('reviews').where('toUserId', isEqualTo: uid).limit(50).get();
        reviewsToList = revToSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (_) {}

      // 7. Fetch reviews submitted by user (fromUserId == uid)
      List<Map<String, dynamic>> reviewsFromList = [];
      try {
        final revFromSnap = await db.collection('reviews').where('fromUserId', isEqualTo: uid).limit(50).get();
        reviewsFromList = revFromSnap.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (_) {}

      final Map<String, dynamic> authMap = {
        'uid': uid,
        'email': profileData['email'] ?? contactData['email'] ?? 'Не указан',
        'phoneNumber': profileData['phone'] ?? contactData['phone'] ?? 'Не указан',
        'displayName': profileData['name'] ?? profileData['displayName'] ?? 'Пользователь',
        'photoURL': profileData['photoUrl'] ?? '',
        'disabled': profileData['isBanned'] == true || profileData['disabled'] == true,
        'creationTime': profileData['createdAt']?.toString(),
        'lastSignInTime': profileData['lastLoginAt']?.toString(),
        'metadata': {
          'creationTime': profileData['createdAt']?.toString(),
          'lastSignInTime': profileData['lastLoginAt']?.toString(),
        },
      };

      if (mounted) {
        setState(() {
          _data = {
            'auth': authMap,
            'profile': profileData,
            'contact': contactData,
            'ads': adsList,
            'reportsAgainst': reportsAgainstList,
            'reportsSubmitted': reportsSubmittedList,
            'reviewsTo': reviewsToList,
            'reviewsFrom': reviewsFromList,
            'chats': {},
            'taxiBidsSent': [],
            'taxiBidsReceived': [],
            'taxiOrdersPassenger': [],
            'taxiOrdersDriver': [],
            'avgRating': (profileData['rating'] as num?)?.toDouble() ?? 0.0,
            'reviewsCount': (profileData['reviewsCount'] as num?)?.toInt() ?? 0,
          };
          _isLoading = false;
          _error = null;
        });
      }
    } catch (fallbackErr) {
      if (mounted) {
        setState(() {
          _error = 'Ошибка при загрузке профиля: $fallbackErr';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(dynamic val) {
    if (val == null) return 'N/A';
    try {
      DateTime dt;
      if (val is Timestamp) {
        dt = val.toDate();
      } else if (val is DateTime) {
        dt = val;
      } else if (val is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(val);
      } else {
        final str = val.toString();
        if (str.isEmpty) return 'N/A';
        dt = DateTime.parse(str);
      }
      return DateFormat('dd.MM.yyyy, HH:mm').format(dt);
    } catch (_) {
      return val.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Карточка пользователя', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: true,
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: Icon(PhosphorIcons.arrowsClockwise()),
              onPressed: _loadUserInfo,
            )
        ],
      ),
      body: _buildBody(context, colorScheme),
    );
  }

  Widget _buildBody(BuildContext context, ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(PhosphorIcons.warningCircle(), size: 64, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки данных',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadUserInfo,
                child: const Text('Повторить'),
              )
            ],
          ),
        ),
      );
    }

    if (_data == null) {
      return const Center(child: Text('Нет данных'));
    }

    final auth = _safeMap(_data!['auth']);
    final profile = _safeMap(_data!['profile']);
    final ads = _safeList(_data!['ads']);
    final reportsAgainst = _safeList(_data!['reportsAgainst']);
    final reportsSubmitted = _safeList(_data!['reportsSubmitted']);
    final reviewsTo = _safeList(_data!['reviewsTo']);
    final reviewsFrom = _safeList(_data!['reviewsFrom']);
    final chats = _safeMap(_data!['chats']);
    final taxiBidsSent = _safeList(_data!['taxiBidsSent']);
    final taxiBidsReceived = _safeList(_data!['taxiBidsReceived']);
    final taxiOrdersPassenger = _safeList(_data!['taxiOrdersPassenger']);
    final taxiOrdersDriver = _safeList(_data!['taxiOrdersDriver']);

    final double avgRating = (_data!['avgRating'] as num?)?.toDouble() ?? 0.0;
    final int reviewsCount = (_data!['reviewsCount'] as num?)?.toInt() ?? 0;

    final displayName = profile?['name'] ?? auth?['displayName'] ?? 'Пользователь';
    final photoUrl = profile?['photoUrl'] ?? auth?['photoURL'] ?? '';
    final isAdmin = (profile?['accountType'] == 'admin') || (auth?['customClaims']?['admin'] == true);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Главный блок профиля
          _buildHeaderCard(context, colorScheme, displayName, photoUrl, isAdmin, auth, profile),
          const SizedBox(height: 24),

          // 2. Блок Firebase Auth
          _buildAuthSection(colorScheme, auth),
          const SizedBox(height: 24),

          // 3. Блок объявлений
          _buildAdsSection(context, colorScheme, ads),
          const SizedBox(height: 24),

          // 4. Отзывы и Рейтинг
          _buildReviewsSection(colorScheme, avgRating, reviewsCount, reviewsTo, reviewsFrom),
          const SizedBox(height: 24),

          // 5. Жалобы
          _buildReportsSection(colorScheme, reportsAgainst, reportsSubmitted),
          const SizedBox(height: 24),

          // 6. Чаты и Такси
          _buildTaxiAndChatsSection(colorScheme, chats, taxiBidsSent, taxiBidsReceived, taxiOrdersPassenger, taxiOrdersDriver),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _openAdDetails(String adId) async {
    try {
      final docSnap = await FirebaseFirestore.instance.collection('ads').doc(adId).get();
      if (docSnap.exists && mounted) {
        final adModel = AdModel.fromMap(docSnap.data()!, docSnap.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(ad: adModel, lang: 'ru', onReport: (_) {}, heroPrefix: 'card_ad_$adId'),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Объявление не найдено или удалено.')),
        );
      }
    } catch (e) {
      debugPrint('Error opening ad details: $e');
    }
  }

  // Открыть карточку другого пользователя (автор/получатель отзыва,
  // отправитель/нарушитель жалобы) — тем же экраном, обычный push,
  // рекурсия по клику вглубь предусмотрена намеренно (юзер попросил
  // прозрачность: от отзыва/жалобы дойти до любого причастного профиля).
  void _openUserCard(String uid) {
    final trimmed = uid.trim();
    if (trimmed.isEmpty || trimmed == 'anonymous' || trimmed == widget.uid) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminUserCardScreen(uid: trimmed)),
    );
  }

  Widget _linkChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editUserPhoneDialog(String currentPhone) {
    final cleanPhone = currentPhone.contains('(') ? currentPhone.split('(')[0].trim() : (currentPhone == 'Не указан' ? '' : currentPhone);
    final phoneController = TextEditingController(text: cleanPhone);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Указать / Редактировать номер', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сохраните номер телефона для связи с этим пользователем:', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Номер телефона (+7 777 ...)',
                prefixIcon: const Icon(Icons.phone),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              final newPhone = phoneController.text.trim();
              Navigator.pop(ctx);
              try {
                final db = FirebaseFirestore.instance;
                await db.collection('users').doc(widget.uid).set({'phone': newPhone}, SetOptions(merge: true));
                await db.collection('users').doc(widget.uid).collection('private').doc('contact').set({'phone': newPhone}, SetOptions(merge: true));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Номер телефона успешно сохранен!')));
                  _loadUserInfo();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
                }
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ColorScheme colorScheme,
    String name,
    String photo,
    bool isAdmin,
    Map<String, dynamic>? auth,
    Map<String, dynamic>? profile,
  ) {
    final ads = _safeList(_data?['ads']);
    final contact = _safeMap(_data?['contact']);
    final email = profile?['email'] ?? contact?['email'] ?? auth?['email'] ?? 'N/A';
    
    String phone = profile?['phone'] ?? profile?['phoneNumber'] ?? contact?['phone'] ?? contact?['tg_session_phone'] ?? contact?['driver_phone'] ?? auth?['phoneNumber'] ?? '';
    if (phone.isEmpty || phone == 'Не указан' || phone == 'N/A') {
      for (final ad in ads) {
        final p = (ad['phone'] ?? ad['contactPhone'] ?? ad['userPhone'] ?? ad['phoneNumber'] ?? '').toString().trim();
        if (p.isNotEmpty) {
          phone = '$p (из объявления)';
          break;
        }
      }
    }
    if (phone.isEmpty) phone = 'Не указан';

    final telegramUser = profile?['telegram_username'] ?? profile?['telegramUsername'] ?? profile?['username'] ?? '';
    final telegramChatId = contact?['telegram_chat_id'] ?? profile?['telegramChatId'] ?? profile?['chat_id'] ?? (widget.uid.startsWith('telegram_') ? widget.uid.replaceAll('telegram_', '') : null);

    final isVerified = profile?['isVerified'] == true;
    final isDisabled = auth?['disabled'] == true;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colorScheme.surfaceContainerHighest,
                backgroundImage: (photo.startsWith('http://') || photo.startsWith('https://')) ? CachedNetworkImageProvider(photo) : null,
                child: (!photo.startsWith('http://') && !photo.startsWith('https://')) ? Icon(PhosphorIcons.user(), color: Colors.grey, size: 28) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
                          ),
                        ),
                        if (isVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified_rounded, color: Colors.blue, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isAdmin)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(6)),
                        child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                    else
                      Text('Пользователь', style: GoogleFonts.inter(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          _buildInfoRow(PhosphorIcons.copy(), 'UID', widget.uid, colorScheme, isCopyable: true),
          const SizedBox(height: 12),
          _buildInfoRow(PhosphorIcons.envelope(), 'Email', email, colorScheme),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoRow(PhosphorIcons.phone(), 'Телефон', phone, colorScheme),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                tooltip: 'Указать / изменять телефон',
                onPressed: () => _editUserPhoneDialog(phone),
              ),
            ],
          ),
          if (telegramUser.toString().isNotEmpty || telegramChatId != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    PhosphorIcons.telegramLogo(),
                    'Telegram',
                    telegramUser.toString().isNotEmpty ? '@${telegramUser.toString().replaceAll('@', '')}' : 'ID: $telegramChatId',
                    colorScheme,
                  ),
                ),
                InkWell(
                  onTap: () async {
                    final tgLink = telegramUser.toString().isNotEmpty
                        ? 'https://t.me/${telegramUser.toString().replaceAll('@', '')}'
                        : 'https://t.me/c/$telegramChatId';
                    try {
                      final uri = Uri.parse(tgLink);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } else {
                        Clipboard.setData(ClipboardData(text: tgLink));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка на Telegram скопирована!')));
                        }
                      }
                    } catch (e) {
                      Clipboard.setData(ClipboardData(text: tgLink));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ссылка скопирована!')));
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF0088CC).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.telegram, size: 14, color: Color(0xFF0088CC)),
                        const SizedBox(width: 4),
                        Text('Написать', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0088CC))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            PhosphorIcons.lockKey(),
            'Статус аккаунта',
            isDisabled ? '❌ Блокирован' : '✅ Активен',
            colorScheme,
            valueColor: isDisabled ? Colors.redAccent : Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ColorScheme colorScheme, {bool isCopyable = false, Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text('$label: ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[600])),
        Expanded(
          child: GestureDetector(
            onTap: isCopyable
              ? () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Скопировано!'), duration: Duration(seconds: 1)));
                }
              : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isCopyable ? FontWeight.bold : FontWeight.normal,
                      color: valueColor ?? (isCopyable ? colorScheme.primary : Colors.black),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isCopyable) ...[
                  const SizedBox(width: 6),
                  Icon(PhosphorIcons.copy(), size: 12, color: colorScheme.primary),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthSection(ColorScheme colorScheme, Map<String, dynamic>? auth) {
    if (auth == null) {
      return _buildSectionContainer(
        colorScheme,
        title: 'Учетная запись Firebase Auth',
        icon: PhosphorIcons.shieldCheck(),
        child: const Text('Запись в Firebase Auth отсутствует для данного UID (пользователь может быть удален).'),
      );
    }

    final providers = _safeList(auth['providerData']);

    return _buildSectionContainer(
      colorScheme,
      title: 'Учетная запись Firebase Auth',
      icon: PhosphorIcons.shieldCheck(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Регистрация', _formatDate(auth['creationTime'] ?? (auth['metadata'] is Map ? auth['metadata']['creationTime'] : null))),
          _buildDetailRow('Последний вход', _formatDate(auth['lastSignInTime'] ?? (auth['metadata'] is Map ? auth['metadata']['lastSignInTime'] : null))),
          _buildDetailRow('Последнее обновление', _formatDate(auth['lastRefreshTime'] ?? (auth['metadata'] is Map ? auth['metadata']['lastRefreshTime'] : null))),
          _buildDetailRow('Email подтвержден', auth['emailVerified'] == true ? 'Да' : 'Нет'),
          const SizedBox(height: 16),
          Text('Способы авторизации:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (providers.isEmpty)
            Text('Нет провайдеров', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: providers.map((prov) {
                final String provId = prov['providerId'] ?? '';
                IconData provIcon = PhosphorIcons.envelope();
                String provName = provId;
                if (provId == 'google.com') {
                  provIcon = PhosphorIcons.googleLogo();
                  provName = 'Google';
                } else if (provId.contains('telegram')) {
                  provIcon = PhosphorIcons.telegramLogo();
                  provName = 'Telegram';
                } else if (provId == 'password') {
                  provIcon = PhosphorIcons.lock();
                  provName = 'Email/Пароль';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Icon(provIcon, size: 20, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              provName,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                            ),
                            if (prov['uid'] != null && prov['uid'].toString().isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'ID / Contact: ${prov['uid']}',
                                style: GoogleFonts.firaCode(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            )
        ],
      ),
    );
  }

  Widget _buildAdsSection(BuildContext context, ColorScheme colorScheme, List<Map<String, dynamic>> ads) {
    return _buildSectionContainer(
      colorScheme,
      title: 'Объявления пользователя (${ads.length})',
      icon: PhosphorIcons.megaphone(),
      child: ads.isEmpty
        ? Text('У пользователя нет объявлений.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
        : Column(
            children: ads.map((ad) {
              final price = ad['price'] ?? 0.0;
              final status = ad['status'] ?? 'pending';
              final phone = (ad['phone'] ?? ad['contactPhone'] ?? ad['userPhone'] ?? ad['phoneNumber'] ?? '').toString().trim();

              Color statusColor = Colors.orange;
              String statusText = 'На проверке';
              if (status == 'active') {
                statusColor = Colors.green;
                statusText = 'Активно';
              } else if (status == 'rejected') {
                statusColor = Colors.redAccent;
                statusText = 'Отклонено';
              } else if (status == 'archived' || status == 'sold') {
                statusColor = Colors.grey;
                statusText = 'В архиве';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      try {
                        final docSnap = await FirebaseFirestore.instance.collection('ads').doc(ad['id']).get();
                        if (docSnap.exists && context.mounted) {
                          final adModel = AdModel.fromMap(docSnap.data()!, docSnap.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailsScreen(ad: adModel, lang: 'ru', onReport: (_) {}, heroPrefix: 'user_card_${ad['id']}'),
                            ),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Объявление удалено из базы данных.')),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error opening ad details: $e');
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  ad['title'] ?? 'Объявление',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF0F172A)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                                child: Text(
                                  statusText,
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${price is num ? price.toInt() : price} ₸',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 15, color: const Color(0xFF10B981)),
                              ),
                              if (phone.isNotEmpty)
                                Row(
                                  children: [
                                    Icon(PhosphorIcons.phone(), size: 12, color: colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      phone,
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.primary),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                _formatDate(ad['createdAt']),
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                              ),
                              const Spacer(),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('ads')
                                    .doc(ad['id'])
                                    .collection('stats')
                                    .doc('counters')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  int viewsCount = 0;
                                  int callsCount = 0;
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                                    if (data != null) {
                                      viewsCount = data['viewsCount'] ?? 0;
                                      callsCount = data['callsCount'] ?? 0;
                                    }
                                  }
                                  return Row(
                                    children: [
                                      Icon(PhosphorIcons.eye(), size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text('$viewsCount', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                                      const SizedBox(width: 10),
                                      Icon(PhosphorIcons.phoneCall(), size: 12, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text('$callsCount', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
    );
  }

  Widget _buildReviewsSection(
    ColorScheme colorScheme,
    double avgRating,
    int reviewsCount,
    List<Map<String, dynamic>> reviewsTo,
    List<Map<String, dynamic>> reviewsFrom,
  ) {
    return _buildSectionContainer(
      colorScheme,
      title: 'Рейтинг и Отзывы',
      icon: PhosphorIcons.star(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 8),
              Text(
                avgRating.toStringAsFixed(1),
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 24),
              ),
              const SizedBox(width: 8),
              Text(
                '(всего отзывов: $reviewsCount)',
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
          const Divider(height: 24),
          Text('Полученные отзывы (до 50 последних):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (reviewsTo.isEmpty)
            Text('Отзывов еще нет.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: reviewsTo.map((rev) {
                final adTitle = rev['adTitle']?.toString() ?? '';
                final adTitleText = adTitle.isNotEmpty ? ' на «$adTitle»' : '';
                return _buildReviewTile(
                  title: 'От ${rev['fromUserName'] ?? "Пользователь"}$adTitleText (${rev['rating']}★)',
                  comment: rev['comment']?.toString() ?? '',
                  dateIso: rev['timestamp'],
                  rating: rev['rating'],
                  adId: rev['adId']?.toString(),
                  adTitle: adTitle,
                  otherUserId: rev['fromUserId']?.toString(),
                  otherUserLabel: 'Профиль автора отзыва',
                  colorScheme: colorScheme,
                );
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text('Оставленные отзывы (до 50 последних):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (reviewsFrom.isEmpty)
            Text('Пользователь еще не оставлял отзывы.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: reviewsFrom.map((rev) {
                final adTitle = rev['adTitle']?.toString() ?? '';
                final adTitleText = adTitle.isNotEmpty ? ' на «$adTitle»' : '';
                return _buildReviewTile(
                  title: 'Кому (UID): ${rev['toUserId']}$adTitleText (${rev['rating']}★)',
                  comment: rev['comment']?.toString() ?? '',
                  dateIso: rev['timestamp'],
                  rating: rev['rating'],
                  adId: rev['adId']?.toString(),
                  adTitle: adTitle,
                  otherUserId: rev['toUserId']?.toString(),
                  otherUserLabel: 'Профиль получателя отзыва',
                  colorScheme: colorScheme,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewTile({
    required String title,
    required String comment,
    required dynamic dateIso,
    required num rating,
    required ColorScheme colorScheme,
    String? adId,
    String? adTitle,
    String? otherUserId,
    String otherUserLabel = 'Профиль пользователя',
  }) {
    final validAdId = (adId != null && adId.trim().isNotEmpty) ? adId.trim() : null;
    final validOtherUserId = (otherUserId != null && otherUserId.trim().isNotEmpty && otherUserId != 'anonymous' && otherUserId != widget.uid)
        ? otherUserId.trim()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDate(dateIso), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[800], height: 1.3)),
          ],
          if (validAdId != null || validOtherUserId != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (validAdId != null)
                  _linkChip(
                    icon: PhosphorIcons.arrowSquareOut(),
                    label: 'Посмотреть объявление${adTitle != null && adTitle.isNotEmpty ? " «$adTitle»" : ""}',
                    color: colorScheme.primary,
                    onTap: () => _openAdDetails(validAdId),
                  ),
                if (validOtherUserId != null)
                  _linkChip(
                    icon: PhosphorIcons.userCircle(),
                    label: otherUserLabel,
                    color: colorScheme.primary,
                    onTap: () => _openUserCard(validOtherUserId),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportsSection(
    ColorScheme colorScheme,
    List<Map<String, dynamic>> reportsAgainst,
    List<Map<String, dynamic>> reportsSubmitted,
  ) {
    return _buildSectionContainer(
      colorScheme,
      title: 'Жалобы (Reports)',
      icon: PhosphorIcons.warningCircle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Жалобы НА этого пользователя (${reportsAgainst.length}):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.redAccent)),
          const SizedBox(height: 8),
          if (reportsAgainst.isEmpty)
            Text('Жалоб нет.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: reportsAgainst.map((rep) {
                return _buildReportTile(
                  title: rep['adId'] != null ? 'На объявление «${rep['adTitle'] ?? ""}»' : 'На профиль',
                  type: rep['type']?.toString(),
                  comment: rep['comment']?.toString(),
                  dateIso: rep['timestamp'],
                  adId: rep['adId']?.toString(),
                  subText: 'Отправил (UID): ${rep['reporterUserId']}',
                  otherUserId: rep['reporterUserId']?.toString(),
                  otherUserLabel: 'Профиль автора жалобы',
                  colorScheme: colorScheme,
                );
              }).toList(),
            ),
          const Divider(height: 24),
          Text('Жалобы, ПОДАННЫЕ этим пользователем (${reportsSubmitted.length}):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (reportsSubmitted.isEmpty)
            Text('Пользователь не отправлял жалобы.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: reportsSubmitted.map((rep) {
                return _buildReportTile(
                  title: rep['adId'] != null ? 'На объявление (ID: ${rep['adId']})' : 'На пользователя ${rep['reportedUserName'] ?? ""}',
                  type: rep['type']?.toString(),
                  comment: rep['comment']?.toString(),
                  dateIso: rep['timestamp'],
                  adId: rep['adId']?.toString(),
                  subText: 'Нарушитель (UID): ${rep['reportedUserId']}',
                  otherUserId: rep['reportedUserId']?.toString(),
                  otherUserLabel: 'Профиль нарушителя',
                  colorScheme: colorScheme,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTile({
    required String title,
    required String? type,
    required String? comment,
    required dynamic dateIso,
    required String subText,
    required ColorScheme colorScheme,
    String? adId,
    String? otherUserId,
    String otherUserLabel = 'Профиль пользователя',
  }) {
    final validAdId = (adId != null && adId.trim().isNotEmpty) ? adId.trim() : null;
    final validOtherUserId = (otherUserId != null && otherUserId.trim().isNotEmpty && otherUserId != 'anonymous' && otherUserId != widget.uid)
        ? otherUserId.trim()
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF0F172A)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(_formatDate(dateIso), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 4),
          Text('Тип: ${type ?? "Жалоба"}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[800])),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Коммент: "$comment"', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[800], height: 1.3)),
          ],
          const SizedBox(height: 6),
          Text(
            subText,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (validAdId != null || validOtherUserId != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (validAdId != null)
                  _linkChip(
                    icon: PhosphorIcons.arrowSquareOut(),
                    label: 'Посмотреть объявление',
                    color: Colors.red[700]!,
                    onTap: () => _openAdDetails(validAdId),
                  ),
                if (validOtherUserId != null)
                  _linkChip(
                    icon: PhosphorIcons.userCircle(),
                    label: otherUserLabel,
                    color: Colors.red[700]!,
                    onTap: () => _openUserCard(validOtherUserId),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaxiAndChatsSection(
    ColorScheme colorScheme,
    Map<String, dynamic>? chats,
    List<Map<String, dynamic>> bidsSent,
    List<Map<String, dynamic>> bidsReceived,
    List<Map<String, dynamic>> ordersPassenger,
    List<Map<String, dynamic>> ordersDriver,
  ) {
    return _buildSectionContainer(
      colorScheme,
      title: 'Чаты и Такси',
      icon: PhosphorIcons.car(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.chatCircleText(), size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Активные чаты пользователя:',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('users', arrayContains: widget.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Text('Нет активных переписок у пользователя.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey));
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final adTitle = data['adTitle'] ?? 'Объявление';
                  final adId = data['adId'];
                  final lastMessage = data['lastMessage'] ?? '...';
                  final buyerName = data['buyerName'] ?? 'Покупатель';
                  final sellerName = data['sellerName'] ?? 'Продавец';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.chatTeardropDots(), size: 16, color: const Color(0xFF4A80F0)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$adTitle ($buyerName ↔ $sellerName)',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12.5, color: const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (lastMessage.toString().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '"$lastMessage"',
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            if (adId != null && adId.toString().isNotEmpty) {
                              try {
                                final ad = await AdService.getAdById(adId.toString());
                                if (ad != null && context.mounted) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (c) => ChatScreen(ad: ad, chatId: doc.id)),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error opening chat: $e');
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4A80F0),
                            side: const BorderSide(color: Color(0xFF4A80F0)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          icon: const Icon(Icons.mark_chat_read_rounded, size: 14),
                          label: Text('ПРОЧИТАТЬ ЧАТ И ПЕРЕПИСКУ', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Divider(height: 24),
          Text('Ставки такси (Отправленные):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (bidsSent.isEmpty)
            Text('Нет ставок.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: bidsSent.map((bid) {
                return _buildTaxiBidTile(bid, isSent: true);
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text('Ставки такси (Полученные):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (bidsReceived.isEmpty)
            Text('Ставок от других нет.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: bidsReceived.map((bid) {
                return _buildTaxiBidTile(bid, isSent: false);
              }).toList(),
            ),
          const Divider(height: 24),
          Text('История поездок (Пассажир):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (ordersPassenger.isEmpty)
            Text('Поездок нет.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: ordersPassenger.map((ord) {
                return _buildTaxiOrderTile(ord, role: 'Пассажир');
              }).toList(),
            ),
          const SizedBox(height: 16),
          Text('История поездок (Водитель):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          if (ordersDriver.isEmpty)
            Text('Поездок нет.', style: GoogleFonts.inter(fontSize: 13, color: Colors.grey))
          else
            Column(
              children: ordersDriver.map((ord) {
                return _buildTaxiOrderTile(ord, role: 'Водитель');
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTaxiBidTile(Map<String, dynamic> bid, {required bool isSent}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSent ? 'Кому (UID): ${bid['receiverId']}' : 'От (UID): ${bid['senderId']}',
                  style: GoogleFonts.inter(fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text('Заказ: ${bid['targetId']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${bid['offeredPrice']} ₸', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                'Статус: ${bid['status']}',
                style: TextStyle(
                  fontSize: 10,
                  color: bid['status'] == 'accepted' ? Colors.green : (bid['status'] == 'rejected' ? Colors.red : Colors.orange),
                  fontWeight: FontWeight.bold,
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTaxiOrderTile(Map<String, dynamic> ord, {required String role}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID Заказа: ${ord['id']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  role == 'Пассажир' ? 'Водитель (UID): ${ord['driverId']}' : 'Пассажир (UID): ${ord['passengerId']}',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_formatDate(ord['createdAt']), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(
                'Статус: ${ord['status']}',
                style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionContainer(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
