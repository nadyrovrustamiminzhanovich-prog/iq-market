import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
            onPressed: () => NotificationService.markAllAsRead(),
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
      stream: NotificationService.getNotificationsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final notifications = snapshot.data ?? [];
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
              onDismissed: (direction) => NotificationService.deleteNotification(notif.id),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _handleNotificationTap(notif),
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
    await NotificationService.markAsRead(notif.id);
    
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
  }

  Widget _buildChatsTab() {
    final uid = UserService.currentUid;
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ChatService.getChatListStream(),
      builder: (context, snapshot) {
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
                      Text(ad.userName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1D1E))),
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
                child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
      default: return Icons.notifications_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'chat': return const Color(0xFF4A80F0);
      case 'driver_verified': return const Color(0xFF10B981);
      case 'system': return Colors.grey;
      case 'order': return Colors.orange;
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
