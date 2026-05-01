import 'package:flutter/material.dart';
import 'package:iqmarket/screens/chat_screen.dart';

class ChatsListScreen extends StatelessWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Моковые данные для чатов
    final List<Map<String, dynamic>> chats = [
      {
        'seller': 'Ерлан',
        'ad_title': 'iPhone 13 Pro Max',
        'last_msg': 'Добрый день! Да, еще продаю. Обращайтесь...',
        'time': '14:30',
        'unread': 1,
        'image': 'https://images.unsplash.com/photo-1632661674596-df8be070a5c5?auto=format&fit=crop&w=150&q=80',
        'price': '350 000',
      },
      {
        'seller': 'Айдос',
        'ad_title': 'Мебель для гостиной',
        'last_msg': 'Вы: Торг уместен?',
        'time': 'Вчера',
        'unread': 0,
        'image': 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?auto=format&fit=crop&w=150&q=80',
        'price': '120 000',
      },
      {
        'seller': 'Service Center',
        'ad_title': 'Ремонт ноутбуков Almaty',
        'last_msg': 'Спасибо, ждем вас завтра.',
        'time': 'Пн',
        'unread': 0,
        'image': 'https://images.unsplash.com/photo-1496181133206-80ce9b88a853?auto=format&fit=crop&w=150&q=80',
        'price': 'От 5 000',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEEF2F6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Мои сообщения', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.black87),
            onSelected: (v) {
              if (v == 'clear') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Все чаты помечены как прочитанные ✅'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('Пометить все как прочитанные')),
            ],
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: chats.length,
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, endIndent: 20, color: Colors.black12),
        itemBuilder: (context, index) {
          final chat = chats[index];
          return InkWell(
            onTap: () {
              // Мокаем переход в чат
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
                ad: {
                  'title': chat['ad_title'],
                  'price': chat['price'],
                  'seller': chat['seller'],
                  'images': [chat['image']]
                }
              )));
            },
            child: Container(
              color: chat['unread'] > 0 ? const Color(0xFF4A80F0).withValues(alpha: 0.05) : Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 55, height: 55,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                        ),
                        child: ClipOval(
                          child: Icon(Icons.person_outline_rounded, size: 28, color: Colors.grey[400]),
                        ),
                      ),
                      if (chat['unread'] > 0)
                        Positioned(
                          right: 0, bottom: 0,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: Text(chat['seller'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                            Text(chat['time'], style: TextStyle(color: chat['unread'] > 0 ? const Color(0xFF4A80F0) : Colors.grey[500], fontSize: 12, fontWeight: chat['unread'] > 0 ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(chat['ad_title'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (chat['last_msg'].startsWith('Вы:'))
                              const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF00E5FF))),
                            Expanded(child: Text(chat['last_msg'].replaceAll('Вы: ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
                            if (chat['unread'] > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(10)),
                                child: Text(chat['unread'].toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
