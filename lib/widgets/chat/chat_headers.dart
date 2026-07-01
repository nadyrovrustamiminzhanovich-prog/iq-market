import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/widgets/report_user_sheet.dart';

class ChatGlassHeader extends StatelessWidget {
  final AdModel ad;
  final String? sellerAvatarUrl;
  final bool isOnline;
  final bool isTyping;
  final VoidCallback onBack;
  final VoidCallback onProfileTap;
  final VoidCallback onCall;

  const ChatGlassHeader({
    super.key,
    required this.ad,
    this.sellerAvatarUrl,
    this.isOnline = false,
    this.isTyping = false,
    required this.onBack,
    required this.onProfileTap,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)), onPressed: onBack),
            Expanded(
              child: GestureDetector(
                onTap: onProfileTap,
                child: Row(children: [
                  CircleAvatar(
                    radius: 18, 
                    backgroundColor: const Color(0xFFF1F5F9), 
                    backgroundImage: sellerAvatarUrl != null ? CachedNetworkImageProvider(sellerAvatarUrl!) : null,
                    child: sellerAvatarUrl == null ? const Icon(Icons.person, size: 20, color: Color(0xFF94A3B8)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(ad.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A))),
                      StreamBuilder<bool>(
                        stream: ChatService.getTypingStatusStream(ad.userId),
                        builder: (context, snapshot) {
                          final streamTyping = snapshot.data == true;
                          final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
                          if (streamTyping || isTyping) {
                            return Text(TranslationService.t('typing', lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold));
                          }
                          if (isOnline) {
                            return Text(TranslationService.t('online', lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold));
                          }
                          return StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance.collection('users').doc(ad.userId).snapshots(),
                            builder: (context, userSnap) {
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                                final lastActiveStamp = data['lastActive'] as Timestamp?;
                                if (lastActiveStamp != null) {
                                  final date = lastActiveStamp.toDate().toLocal();
                                  final now = DateTime.now();
                                  final today = DateTime(now.year, now.month, now.day);
                                  final yesterday = today.subtract(const Duration(days: 1));
                                  final activeDay = DateTime(date.year, date.month, date.day);

                                  String timeStr;
                                  if (activeDay == today) {
                                    timeStr = TranslationService.t('today_at', lang).replaceAll('{time}', DateFormat('HH:mm').format(date));
                                  } else if (activeDay == yesterday) {
                                    timeStr = TranslationService.t('yesterday_at', lang).replaceAll('{time}', DateFormat('HH:mm').format(date));
                                  } else {
                                    timeStr = '${DateFormat('dd.MM.yyyy').format(date)} ${TranslationService.t('at_time', lang)} ${DateFormat('HH:mm').format(date)}';
                                  }

                                  String finalStr;
                                  if (lang == 'Русский') {
                                    finalStr = '${TranslationService.t('was_online', lang)} $timeStr';
                                  } else {
                                    finalStr = '$timeStr ${TranslationService.t('was_online', lang)}';
                                  }
                                  return Text(finalStr, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11));
                                }
                              }
                              return Text(TranslationService.t('offline', lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11));
                            }
                          );
                        },
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            IconButton(icon: const Icon(Icons.call_rounded, color: Color(0xFF334155)), onPressed: onCall),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF334155)),
              onSelected: (val) {
                final config = Provider.of<AppConfigProvider>(context, listen: false);
                if (val == 'block') {
                  config.blockUser(ad.userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('block_success', config.language))),
                  );
                } else if (val == 'unblock') {
                  config.unblockUser(ad.userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('unblock_success', config.language))),
                  );
                } else if (val == 'report') {
                  ReportUserSheet.show(
                    context,
                    reportedUserId: ad.userId,
                    reportedUserName: ad.userName,
                    lang: config.language,
                  );
                }
              },
              itemBuilder: (context) {
                final config = Provider.of<AppConfigProvider>(context, listen: false);
                final isBlocked = config.isUserBlocked(ad.userId);
                return [
                  PopupMenuItem(
                    value: isBlocked ? 'unblock' : 'block',
                    child: Text(
                      TranslationService.t(isBlocked ? 'unblock_seller' : 'block_seller', config.language),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.report_gmailerrorred_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          TranslationService.t('report', config.language),
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }
}

class ChatAdInfoBar extends StatelessWidget {
  final AdModel ad;

  const ChatAdInfoBar({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context).language;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
          ),
          child: ClipOval(
            child: Hero(
              tag: 'chat_ad-image-${ad.id}',
              child: ad.images.isNotEmpty 
                ? CachedNetworkImage(imageUrl: ad.images.isNotEmpty ? ad.images.first : '', fit: BoxFit.cover, errorWidget: (context, url, error) => const Icon(Icons.image, color: Color(0xFF94A3B8)))
                : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          Text('${ad.price.toInt()} ₸', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 12)),
        ])),
        ElevatedButton(
          onPressed: () {
            if (ad.category == 'Taxi') {
              _showTaxiDetails(context);
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: lang, heroPrefix: 'chat_')));
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF2563EB),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            TranslationService.t('view_btn', lang),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ]),
    );
  }

  void _showTaxiDetails(BuildContext context) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 34),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.local_taxi_rounded, color: Color(0xFF4A80F0), size: 28),
                const SizedBox(width: 12),
                Expanded(child: Text(ad.title.replaceAll('Поездка: ', ''), style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 24),
            _infoRow(Icons.person_rounded, 'Собеседник', ad.userName),
            const SizedBox(height: 16),
            _infoRow(Icons.payments_rounded, 'Стоимость', '${ad.price.toInt()} ₸'),
            const SizedBox(height: 16),
            _infoRow(Icons.info_outline_rounded, 'Тип чата', 'Чат по поездке (IQ-Taxi)'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A80F0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text(TranslationService.t('closeBtnCap', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: const Color(0xFF4A80F0), size: 22),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
