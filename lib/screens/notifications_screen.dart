import 'package:flutter/material.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';

import 'package:iqmarket/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/models/notification_model.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends StatefulWidget {
  final String lang;
  const NotificationsScreen({super.key, required this.lang});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isProcessing = false;
  int _retryCounter = 0;
  // Список приходит из живого Firestore-стрима (getNotificationsStream). Свайп
  // (Dismissible) сам убирает виджет из дерева СРАЗУ по завершении анимации —
  // до того, как асинхронный deleteNotification() успеет дойти до сервера и
  // стрим переизлучит список без этого элемента. Если за это окно (сетевая
  // задержка) стрим переизлучится по ДРУГОЙ причине (пришло новое уведомление,
  // isRead поменялся у соседнего), ListView перестроится со старым списком, где
  // этот же ключ всё ещё есть — Dismissible кинет
  // "A dismissed Dismissible widget is still part of the tree". Локально
  // скрываем id сразу при свайпе (не дожидаясь стрима) и возвращаем обратно,
  // если удаление на сервере реально не прошло — тогда пользователь видит
  // объективную картину, а не молча пропавшее (по факту неудалённое) уведомление.
  final Set<String> _locallyDeletedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Уведомления НЕ помечаются прочитанными от одного факта открытия экрана.
    // Раньше здесь стоял markAllAsRead() на старте и на переключении вкладки:
    // красный счётчик обнулялся до того, как пользователь успевал прочитать
    // список, и понять, какое уведомление новое, было невозможно — все они
    // мгновенно теряли подсветку и синюю точку.
    //
    // Прочитанным становится КОНКРЕТНОЕ уведомление, которое открыли
    // (_handleNotificationTap → NotificationService.markAsRead), чат — когда
    // его открыли (ChatService.markAsRead гасит и своё уведомление в
    // колокольчике). Массово — только по явной кнопке «Прочитать всё».
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _t(String key) {
    final Map<String, Map<String, String>> localizedValues = {
      'Русский': {
        'center': 'Центр уведомлений',
        'title': 'Мои сообщения',
        'notifications': 'Уведомления',
        'chats': 'Чаты',
        'mark_all': 'Прочитать всё',
        'today': 'СЕГОДНЯ',
        'yesterday': 'ВЧЕРА',
        'earlier': 'РАНЕЕ',
        'no_notifications': 'Уведомлений пока нет',
        'no_chats': 'Чатов пока нет',
        'ad_rejected_title': 'Объявление отклонено',
        'ad_rejected_desc1': 'Ваше объявление ',
        'ad_rejected_desc2': ' не прошло модерацию и было удалено.',
        'rejection_reason_label': 'ПРИЧИНА ОТКЛОНЕНИЯ:',
        'ad_rejected_info': 'Пожалуйста, исправьте указанные нарушения и опубликуйте объявление заново.',
        'got_it': 'ПОНЯТНО',
      },
      'Қазақша': {
        'center': 'Хабарландыру орталығы',
        'title': 'Менің хабарларым',
        'notifications': 'Хабарламалар',
        'chats': 'Чаттар',
        'mark_all': 'Барлығын оқу',
        'today': 'БҮГІН',
        'yesterday': 'КЕШЕ',
        'earlier': 'ЕРТЕРЕК',
        'no_notifications': 'Хабарламалар әлі жоқ',
        'no_chats': 'Чаттар әлі жоқ',
        'ad_rejected_title': 'Хабарландыру қабылданбады',
        'ad_rejected_desc1': 'Сіздің хабарландыруыңыз ',
        'ad_rejected_desc2': ' модерациядан өтпей, жойылды.',
        'rejection_reason_label': 'ҚАБЫЛДАМАУ СЕБЕБІ:',
        'ad_rejected_info': 'Көрсетілген бұзушылықтарды түзетіп, хабарландыруды қайта жариялаңыз.',
        'got_it': 'ТҮСІНІКТІ',
      },
      // ✅ Уйгурский язык — полный набор переводов (кириллица)
      'Уйғурчә': {
        'center': 'Уқтуруш мәркизи',
        'title': 'Мениң учурлирим',
        'notifications': 'Уқтурушлар',
        'chats': 'Чатлар',
        'mark_all': 'Һәммисини оқуш',
        'today': 'БҮГҮН',
        'yesterday': 'ТҮНҮГҮН',
        'earlier': 'ИЛГИРИ',
        'no_notifications': 'Уқтурушлар техи йоқ',
        'no_chats': 'Чатлар техи йоқ',
        'ad_rejected_title': 'Уқтуруш рәт қилинди',
        'ad_rejected_desc1': 'Сизниң уқтурушиңиз ',
        'ad_rejected_desc2': ' модерациядин өтмәй, өчүрүлди.',
        'rejection_reason_label': 'РӘТ ҚИЛИШ СӘВӘВИ:',
        'ad_rejected_info': 'Көрситилгән бузушларни түзәтип, уқтурушни қайта елан қилиң.',
        'got_it': 'ЧҮШИНИШЛИК',
      },
    };
    return (localizedValues[widget.lang]?[key] ?? localizedValues['Русский']?[key] ?? key).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1D1E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _t('title'), // ✅ Переводится на все 3 языка (было захардкожено 'Мои сообщения')
          style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await NotificationService.markAllAsRead();
              await ChatService.markAllChatsAsRead();
            },
            child: Text(_t('mark_all'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A80F0))),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A80F0),
          indicatorWeight: 3,
          labelColor: const Color(0xFF4A80F0),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          tabs: [
            Tab(text: _t('chats')),
            Tab(text: _t('notifications')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatsTab(),
          _buildNotificationsTab(),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return StreamBuilder<List<NotificationModel>>(
      key: ValueKey('notif_$_retryCounter'),
      stream: NotificationService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    TranslationService.t('errLoadingData', widget.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _retryCounter++;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(
                      TranslationService.t('retryBtn', widget.lang),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final notifications = (snapshot.data ?? [])
            .where((n) => !_locallyDeletedIds.contains(n.id))
            .toList();
        if (notifications.isEmpty) return _buildEmptyState(Icons.notifications_none_rounded, _t('no_notifications'));

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final notif = notifications[index];
            return Dismissible(
              key: Key(notif.id),
              direction: DismissDirection.endToStart,
              onDismissed: (direction) async {
                // Скрываем немедленно и локально — не дожидаясь, пока стрим
                // подтвердит удаление с сервера (см. комментарий у поля выше).
                setState(() => _locallyDeletedIds.add(notif.id));
                try {
                  await NotificationService.deleteNotification(notif.id);
                } catch (e) {
                  if (mounted) {
                    // Удаление реально не прошло — возвращаем уведомление в
                    // список, а не оставляем пользователя думать, что оно
                    // удалено, пока на сервере оно всё ещё есть.
                    setState(() => _locallyDeletedIds.remove(notif.id));
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.t('errDeleteNotif', widget.lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
              ),
              child: _buildNotificationItem(notif),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationItem(NotificationModel notif) {
    final icon = _getIconForType(notif.type);
    final color = _getColorForType(notif.type);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: notif.isRead ? Colors.white : const Color(0xFF4A80F0).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notif.isRead ? Colors.transparent : const Color(0xFF4A80F0).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isProcessing ? null : () => _handleNotificationTap(notif),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    if (!notif.isRead)
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(color: const Color(0xFF4A80F0), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(notif.title, style: TextStyle(fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900, fontSize: 15, color: const Color(0xFF1A1D1E))),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatTimestamp(notif.timestamp), style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(notif.body, style: TextStyle(color: const Color(0xFF64748B), fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel notif) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await NotificationService.markAsRead(notif.id);
      
      if (notif.type == 'ad_rejected') {
        final String reason = notif.data?['reason'] ?? 'Нарушение правил размещения';
        String adTitle = 'Ваше объявление';
        if (notif.body.contains('"')) {
          final parts = notif.body.split('"');
          if (parts.length > 1) {
            adTitle = '"${parts[1]}"';
          }
        }
        _showRejectionDetailsDialog(adTitle, reason);
        return;
      }
      
      if (notif.type == 'chat' && notif.data != null) {
        final String adId = notif.data!['adId'] ?? '';
        final String adTitle = notif.data!['adTitle'] ?? 'Объявление';
        final String adImage = notif.data!['adImage'] ?? '';
        final String senderId = notif.data!['senderId'] ?? '';
        final String senderName = notif.data!['senderName'] ?? 'Пользователь';

        if (senderId.isNotEmpty && mounted) {
          final ad = AdModel(
            id: adId, title: adTitle, description: '', price: 0.0, category: '',
            images: adImage.isNotEmpty ? [adImage] : [], userId: senderId, userName: senderName,
            userEmail: '', timestamp: DateTime.now(), location: '',
          );
          Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: ad)));
        }
      } else if (notif.data != null && notif.data!['adId'] != null && mounted) {
        // Поддержка других типов (review, price_drop и т.д.)
        final adId = notif.data!['adId'];
        try {
          final adDoc = await FirebaseFirestore.instance.collection('ads').doc(adId).get();
          if (adDoc.exists && mounted) {
            final ad = AdModel.fromMap(adDoc.data() as Map<String, dynamic>, adDoc.id);
            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(ad: ad, onReport: (_){}, lang: widget.lang)));
          }
        } catch (e) {
          debugPrint('Error loading ad from notification: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showRejectionDetailsDialog(String adTitle, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _t('ad_rejected_title'),
                style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_t('ad_rejected_desc1')}$adTitle${_t('ad_rejected_desc2')}',
              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _t('rejection_reason_label'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.redAccent, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    reason,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: const Color(0xFF1E293B), height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _t('ad_rejected_info'),
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), height: 1.45),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A80F0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size(100, 40),
              elevation: 0,
            ),
            child: Text(_t('got_it'), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    final uid = UserService.currentUid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('chats_$_retryCounter'),
      stream: ChatService.getChatListStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text(
                    TranslationService.t('errLoadingData', widget.lang),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _retryCounter++;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: Text(
                      TranslationService.t('retryBtn', widget.lang),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final chats = snapshot.data ?? [];
        if (chats.isEmpty) return _buildEmptyState(Icons.chat_bubble_outline_rounded, _t('no_chats'));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 10),
          itemCount: chats.length,
          itemBuilder: (context, index) {
            final chat = chats[index];
            final String lastMsg = chat['lastMessage'] ?? '';
            final Timestamp? ts = chat['lastTimestamp'] as Timestamp?;
            final String time = ts != null ? _formatTimestamp(ts.toDate()) : '';
            final int unreadCount = chat['unreadCount_$uid'] ?? 0;
            final String adTitle = chat['adTitle'] ?? 'Объявление';
            final String adImage = chat['adImage'] ?? '';
            final List users = chat['users'] ?? [];
            final String otherId = users.firstWhere((id) => id != uid, orElse: () => '');
            final String otherName = chat['name_$otherId'] ?? 'Пользователь';

            final ad = AdModel(
              id: chat['adId'] ?? '', title: adTitle, description: '', price: 0.0, category: '',
              images: adImage.isNotEmpty ? [adImage] : [], userId: otherId, userName: otherName,
              userEmail: '', timestamp: DateTime.now(), location: '',
            );

            return _buildChatItem(ad, lastMsg, time, unreadCount, chat, uid ?? '');


          },
        );
      },
    );
  }

  Widget _buildChatItem(AdModel ad, String lastMsg, String time, int unreadCount, Map<String, dynamic> chat, String uid) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(ad: ad))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: unreadCount > 0 ? const Color(0xFF4A80F0).withValues(alpha: 0.03) : Colors.transparent,
          border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 58, height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFF1F5F9), width: 2),
                image: (ad.images.isNotEmpty && ad.images.first.startsWith('http')) 
                  ? DecorationImage(image: NetworkImage(ad.images.first), fit: BoxFit.cover)
                  : null,
              ),
              child: (ad.images.isEmpty || !ad.images.first.startsWith('http')) 
                  ? const Icon(Icons.person, color: Colors.grey) 
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          ad.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1D1E)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(time, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF4A80F0) : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(ad.title, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMsg, 
                          maxLines: 1, 
                          overflow: TextOverflow.ellipsis, 
                          style: TextStyle(
                            color: const Color(0xFF64748B), 
                            fontSize: 14, 
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ),
                      if (chat['lastSenderId'] == uid) ...[
                        const SizedBox(width: 4),
                        Icon(
                          chat['isRead'] == true ? Icons.done_all_rounded : Icons.done_rounded, 
                          size: 16, 
                          color: chat['isRead'] == true ? const Color(0xFF4A80F0) : Colors.grey[400]
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(10)),
                child: Text(unreadCount > 99 ? '99+' : '$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }


  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(text, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'chat': return Icons.chat_bubble_rounded;
      case 'driver_verified': return Icons.verified_user_rounded;
      case 'system': return Icons.info_rounded;
      case 'order': return Icons.shopping_bag_rounded;
      case 'ad_expiring': return Icons.hourglass_bottom_rounded;
      case 'review_deleted': return Icons.delete_outline_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'chat': return const Color(0xFF4A80F0);
      case 'driver_verified': return const Color(0xFF10B981);
      case 'system': return Colors.grey;
      case 'order': return Colors.orange;
      case 'ad_expiring': return Colors.orange;
      case 'review_deleted': return Colors.redAccent;
      default: return const Color(0xFF4A80F0);
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    if (now.day == dt.day && now.month == dt.month && now.year == dt.year) return DateFormat('HH:mm').format(dt);
    if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd.MM.yyyy').format(dt);
  }
}
