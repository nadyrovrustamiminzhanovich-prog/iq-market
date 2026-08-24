import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/widgets/report_user_sheet.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/features/taxi/presentation/widgets/ui/call_agreement_dialog.dart';

class ChatGlassHeader extends StatefulWidget {
  final AdModel ad;
  final String? sellerAvatarUrl;
  final bool isTyping;
  final VoidCallback onBack;
  final VoidCallback onProfileTap;
  final VoidCallback onCall;
  final FirebaseFirestore? firestore;

  const ChatGlassHeader({
    super.key,
    required this.ad,
    this.sellerAvatarUrl,
    this.isTyping = false,
    required this.onBack,
    required this.onProfileTap,
    required this.onCall,
    this.firestore,
  });

  @override
  State<ChatGlassHeader> createState() => _ChatGlassHeaderState();
}

class _ChatGlassHeaderState extends State<ChatGlassHeader> {
  // Мемоизировано на весь жизненный цикл виджета. ChatService.
  // getTypingStatusStream() создаёт НОВЫЙ Firestore-listener + Timer.periodic
  // при каждом вызове (см. chat_service.dart, там своего кэша нет) — раньше
  // вызов стоял прямо в stream: StreamBuilder внутри build(), а build() этого
  // заголовка перестраивался на каждый setState родителя ChatScreen (тик
  // таймера записи голосового, позиция аудио, обновление _activeUploads и
  // т.д. — за время активного чата таких setState множество). Каждый такой
  // rebuild гасил и открывал заново listener+таймер — лишняя нагрузка,
  // особенно заметная на слабых устройствах.
  late final Stream<bool> _typingStream = ChatService.getTypingStatusStream(widget.ad.userId);

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
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF0F172A)), onPressed: widget.onBack),
            Expanded(
              child: GestureDetector(
                onTap: widget.onProfileTap,
                child: Row(children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFFF1F5F9),
                    backgroundImage: widget.sellerAvatarUrl != null ? CachedNetworkImageProvider(widget.sellerAvatarUrl!) : null,
                    child: widget.sellerAvatarUrl == null ? const Icon(Icons.person, size: 20, color: Color(0xFF94A3B8)) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(widget.ad.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF0F172A))),
                      StreamBuilder<bool>(
                        stream: _typingStream,
                        builder: (context, snapshot) {
                          final streamTyping = snapshot.data == true;
                          final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
                          if (streamTyping || widget.isTyping) {
                            return Text(TranslationService.t('typing', lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: const Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold));
                          }
                          return StreamBuilder<DocumentSnapshot>(
                            stream: (widget.firestore ?? FirebaseFirestore.instance).collection('users').doc(widget.ad.userId).snapshots(),
                            builder: (context, userSnap) {
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                                final lastActiveStamp = data['lastActive'] as Timestamp?;
                                if (lastActiveStamp != null) {
                                  final date = lastActiveStamp.toDate().toLocal();
                                  final now = DateTime.now();
                                  
                                  // Онлайн, если lastActive обновлялся в течение последних 60 секунд
                                  final difference = now.difference(date).inSeconds;
                                  if (difference <= 60) {
                                    return Text(TranslationService.t('online', lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold));
                                  }

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
            IconButton(icon: const Icon(Icons.call_rounded, color: Color(0xFF334155)), onPressed: widget.onCall),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF334155)),
              onSelected: (val) async {
                final config = Provider.of<AppConfigProvider>(context, listen: false);
                final lang = config.language;
                final chatId = ChatService.activeChatId ?? ChatService.getChatId(widget.ad.userId);

                if (val == 'block') {
                  config.blockUser(widget.ad.userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('block_success', lang))),
                  );
                } else if (val == 'unblock') {
                  config.unblockUser(widget.ad.userId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('unblock_success', lang))),
                  );
                } else if (val == 'report') {
                  ReportUserSheet.show(
                    context,
                    reportedUserId: widget.ad.userId,
                    reportedUserName: widget.ad.userName,
                    lang: lang,
                  );
                } else if (val == 'clear_chat') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text(TranslationService.t('clear_chat', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                      content: Text(TranslationService.t('clear_chat_confirm', lang)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(TranslationService.t('cancel', lang), style: const TextStyle(color: Colors.grey))),
                        TextButton(onPressed: () => Navigator.pop(dCtx, true), child: Text(TranslationService.t('delete_confirm_action', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    final success = await ChatService.clearChatHistory(chatId: chatId, otherUserId: widget.ad.userId);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(TranslationService.t('chat_cleared_success', lang)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating),
                      );
                    }
                  }
                } else if (val == 'delete_chat') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: Text(TranslationService.t('delete_chat_title', lang), style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
                      content: Text(TranslationService.t('delete_chat_confirm_desc', lang)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(TranslationService.t('cancel', lang), style: const TextStyle(color: Colors.grey))),
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: Text(TranslationService.t('delete_confirm_action', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    final success = await ChatService.deleteChatForUser(chatId: chatId, otherUserId: widget.ad.userId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(TranslationService.t('chat_deleted_success', lang)), backgroundColor: const Color(0xFF10B981), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  }
                }
              },
              itemBuilder: (context) {
                final config = Provider.of<AppConfigProvider>(context, listen: false);
                final isBlocked = config.isUserBlocked(widget.ad.userId);
                return [
                  PopupMenuItem(
                    value: 'clear_chat',
                    child: Row(
                      children: [
                        const Icon(Icons.cleaning_services_rounded, color: Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        Text(TranslationService.t('clear_chat', config.language)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_chat',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(TranslationService.t('delete_chat', config.language), style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
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
                ? CachedNetworkImage(imageUrl: ad.images.isNotEmpty ? ad.images.first : '', fit: BoxFit.cover, memCacheWidth: 100, errorWidget: (context, url, error) => const Icon(Icons.image, color: Color(0xFF94A3B8)))
                : const Icon(Icons.shopping_bag_outlined, color: Color(0xFF94A3B8), size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
          Text('${ad.price.toInt()} ₸', style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900, fontSize: 12)),
        ])),
        if (ad.category == 'Taxi') ...[
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('taxi_history')
                .where('driverId', whereIn: [FirebaseAuth.instance.currentUser?.uid ?? '', ad.userId])
                .snapshots(),
            builder: (context, snapshot) {
              bool isAgreed = false;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                isAgreed = snapshot.data!.docs.any((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return (data['driverId'] == myUid && data['passengerId'] == ad.userId) ||
                         (data['passengerId'] == myUid && data['driverId'] == ad.userId);
                });
              }

              if (isAgreed) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF84CC16).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF84CC16)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF4D7C0F), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        TranslationService.t('chatTaxiAgreed', lang),
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4D7C0F)),
                      ),
                    ],
                  ),
                );
              }

              return ElevatedButton.icon(
                onPressed: () {
                  final provider = Provider.of<TaxiProvider>(context, listen: false);
                  showCallAgreementDialog(
                    context: context,
                    provider: provider,
                    t: provider.theme,
                    targetId: ad.id,
                    targetType: 'drive',
                    counterpartName: ad.userName,
                    counterpartPhone: '',
                    counterpartImg: ad.images.isNotEmpty ? ad.images.first : '',
                    suggestedPrice: ad.price.toInt(),
                  );
                },
                icon: const Icon(Icons.handshake_rounded, size: 16),
                label: Text(TranslationService.t('chatTaxiAgreeBtn', lang), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF84CC16),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
        ElevatedButton(
          onPressed: () async {
            // ad здесь — облегчённая заглушка из списка чатов (только id/title/image,
            // price всегда 0.0), иначе экран объявления показывал "Бесплатно" вместо
            // реальной цены. Подгружаем настоящее объявление по id перед показом.
            try {
              final freshAd = await AdService.getAdById(ad.id);
              if (!context.mounted) return;
              if (freshAd == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang == 'Қазақша'
                      ? 'Хабарландыру табылмады немесе өшірілген'
                      : lang == 'Уйғурчә'
                          ? 'Елан тепильмиди йаки өчүрүлгән'
                          : 'Объявление не найдено или удалено')),
                );
                return;
              }
              if (freshAd.category == 'Taxi') {
                _showTaxiDetails(context);
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(ad: freshAd, onReport: (_) {}, lang: lang, heroPrefix: 'chat_')));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(lang == 'Қазақша'
                      ? 'Қате шықты'
                      : lang == 'Уйғурчә'
                          ? 'Хата йүз бәрди'
                          : 'Произошла ошибка')),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEFF6FF),
            foregroundColor: const Color(0xFF2563EB),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
            _infoRow(Icons.person_rounded, TranslationService.t('chatTaxiCounterpart', lang), ad.userName),
            const SizedBox(height: 16),
            _infoRow(Icons.payments_rounded, TranslationService.t('chatTaxiCost', lang), '${ad.price.toInt()} ₸'),
            const SizedBox(height: 16),
            _infoRow(Icons.info_outline_rounded, TranslationService.t('chatTaxiChatType', lang), TranslationService.t('chatTaxiRideChatDesc', lang)),
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
