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

  Future<void> _loadUserInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('getFullUserInfo');
      final HttpsCallableResult result = await callable.call({'targetUid': widget.uid});
      
      setState(() {
        _data = Map<String, dynamic>.from(result.data);
        _isLoading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _error = e.message ?? 'Ошибка вызова Cloud Function';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return 'N/A';
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('dd.MM.yyyy, HH:mm').format(date);
    } catch (_) {
      return isoString;
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

    final auth = _data!['auth'] as Map<String, dynamic>?;
    final profile = _data!['profile'] as Map<String, dynamic>?;
    final ads = List<Map<String, dynamic>>.from(_data!['ads'] ?? []);
    final reportsAgainst = List<Map<String, dynamic>>.from(_data!['reportsAgainst'] ?? []);
    final reportsSubmitted = List<Map<String, dynamic>>.from(_data!['reportsSubmitted'] ?? []);
    final reviewsTo = List<Map<String, dynamic>>.from(_data!['reviewsTo'] ?? []);
    final reviewsFrom = List<Map<String, dynamic>>.from(_data!['reviewsFrom'] ?? []);
    final chats = _data!['chats'] as Map<String, dynamic>?;
    final taxiBidsSent = List<Map<String, dynamic>>.from(_data!['taxiBidsSent'] ?? []);
    final taxiBidsReceived = List<Map<String, dynamic>>.from(_data!['taxiBidsReceived'] ?? []);
    final taxiOrdersPassenger = List<Map<String, dynamic>>.from(_data!['taxiOrdersPassenger'] ?? []);
    final taxiOrdersDriver = List<Map<String, dynamic>>.from(_data!['taxiOrdersDriver'] ?? []);

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

  Widget _buildHeaderCard(
    BuildContext context,
    ColorScheme colorScheme,
    String name,
    String photo,
    bool isAdmin,
    Map<String, dynamic>? auth,
    Map<String, dynamic>? profile,
  ) {
    final email = profile?['email'] ?? auth?['email'] ?? 'N/A';
    final phone = profile?['phone'] ?? auth?['phoneNumber'] ?? 'N/A';
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
                backgroundImage: photo.isNotEmpty ? CachedNetworkImageProvider(photo) : null,
                child: photo.isEmpty ? Icon(PhosphorIcons.user(), color: Colors.grey, size: 28) : null,
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
          _buildInfoRow(PhosphorIcons.phone(), 'Телефон', phone, colorScheme),
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

    final providers = List<Map<String, dynamic>>.from(auth['providerData'] ?? []);

    return _buildSectionContainer(
      colorScheme,
      title: 'Учетная запись Firebase Auth',
      icon: PhosphorIcons.shieldCheck(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Регистрация', _formatDate(auth['creationTime'])),
          _buildDetailRow('Последний вход', _formatDate(auth['lastSignInTime'])),
          _buildDetailRow('Последнее обновление', _formatDate(auth['lastRefreshTime'])),
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
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(provIcon, size: 16, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(provName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('UID: ${prov['uid']}', style: GoogleFonts.firaCode(fontSize: 11, color: Colors.grey[600])),
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

              return Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Text(ad['title'] ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Создано: ${_formatDate(ad['createdAt'])}',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
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
                              Icon(PhosphorIcons.eye(), size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$viewsCount',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                              ),
                              const SizedBox(width: 12),
                              Icon(PhosphorIcons.phone(), size: 12, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                '$callsCount',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$price ₸', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          statusText,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      )
                    ],
                  ),
                  onTap: () async {
                    // Переход в детали объявления
                    try {
                      final docSnap = await FirebaseFirestore.instance.collection('ads').doc(ad['id']).get();
                      if (docSnap.exists && context.mounted) {
                        final adModel = AdModel.fromMap(docSnap.data()!, docSnap.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(ad: adModel, lang: 'ru', onReport: (_) {}),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Объявление удалено из базы данных.')),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error opening ad details: $e');
                    }
                  },
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
                return _buildReviewTile(
                  title: 'От ${rev['fromUserName'] ?? "Пользователь"} (${rev['rating']}★)',
                  comment: rev['comment'],
                  dateIso: rev['timestamp'],
                  rating: rev['rating'],
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
                return _buildReviewTile(
                  title: 'Кому (UID): ${rev['toUserId']} (${rev['rating']}★)',
                  comment: rev['comment'],
                  dateIso: rev['timestamp'],
                  rating: rev['rating'],
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
    required String? dateIso,
    required num rating,
    required ColorScheme colorScheme,
  }) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(_formatDate(dateIso), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(comment, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[800])),
          ]
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
                  title: rep['adId'] != null ? 'На объявление «${rep['adTitle']}»' : 'На профиль',
                  type: rep['type'],
                  comment: rep['comment'],
                  dateIso: rep['timestamp'],
                  subText: 'Отправил (UID): ${rep['reporterUserId']}',
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
                  type: rep['type'],
                  comment: rep['comment'],
                  dateIso: rep['timestamp'],
                  subText: 'Нарушитель (UID): ${rep['reportedUserId']}',
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReportTile({
    required String title,
    required String type,
    required String comment,
    required String? dateIso,
    required String subText,
  }) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13))),
              Text(_formatDate(dateIso), style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Тип: $type', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[800])),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Коммент: "$comment"', style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[800])),
          ],
          const SizedBox(height: 4),
          Text(subText, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
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
    final int chatsCount = chats?['count'] ?? 0;

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
                'Всего активных чатов: $chatsCount',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isSent ? 'Кому (UID): ${bid['receiverId']}' : 'От (UID): ${bid['senderId']}',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text('Заказ: ${bid['targetId']}', style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600])),
            ],
          ),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID Заказа: ${ord['id']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(
                role == 'Пассажир' ? 'Водитель (UID): ${ord['driverId']}' : 'Пассажир (UID): ${ord['passengerId']}',
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
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
              Text(
                title,
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16),
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
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
