import 'package:flutter/material.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/chat_service.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = UserService.currentUid;
    if (uid == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Мои сообщения', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface),
            onSelected: (v) {
              if (v == 'read_all') {
                // Logic to mark all as read can be added
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'read_all', child: Text('Пометить все как прочитанные')),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ChatService.getChatListStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data ?? [];
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('У вас пока нет чатов', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final String lastMsg = chat['lastMessage'] ?? '';
              final Timestamp? ts = chat['lastTimestamp'] as Timestamp?;
              final String time = ts != null ? _formatTimestamp(ts) : '';
              final int unreadCount = chat['unreadCount_$uid'] ?? 0;
              final String adTitle = chat['adTitle'] ?? 'Объявление';
              final String adImage = chat['adImage'] ?? '';
              final String adId = chat['adId'] ?? '';
              
              final List users = chat['users'] ?? [];
              final String sellerId = users.firstWhere((id) => id != uid, orElse: () => '');
              final String sellerName = chat['name_$sellerId'] ?? 'Пользователь';
              
              final ad = AdModel(
                id: chat['adId'] ?? '', title: adTitle, description: '', price: 0.0, category: '',
                images: adImage.isNotEmpty ? [adImage] : [], userId: sellerId, userName: sellerName,
                userEmail: '', timestamp: DateTime.now(), location: '',
              );

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outline, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(ad: ad))),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.colorScheme.surfaceContainerHighest, width: 2),
                                ),
                                child: ClipOval(
                                  child: Hero(
                                    tag: 'chat_ad-image-$adId',
                                    child: adImage.isNotEmpty 
                                      ? Image.network(adImage, fit: BoxFit.cover)
                                      : const Icon(Icons.person_outline_rounded, color: Colors.grey),
                                  ),
                                ),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0, bottom: 0,
                                  child: Container(
                                    width: 14, height: 14,
                                    decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: theme.colorScheme.surface, width: 2.5)),
                                  ),
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
                                    Expanded(child: Text(sellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface))),
                                    Text(time, style: TextStyle(color: unreadCount > 0 ? const Color(0xFF4A80F0) : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(adTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(child: Text(lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14, fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal))),
                                    if (unreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 10),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(10)),
                                        child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(Timestamp ts) {
    final now = DateTime.now();
    final date = ts.toDate();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}.${date.month}';
  }
}
