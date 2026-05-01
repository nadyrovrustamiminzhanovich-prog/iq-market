import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/screens/product_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  final String lang;
  const NotificationsScreen({super.key, required this.lang});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedChats = {};
  
  List<Map<String, dynamic>> _chats = [
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
  ];

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
        'notifications': 'Уведомления',
        'chats': 'Чаты',
        'mark_all': 'Прочитать всё',
        'today': 'СЕГОДНЯ',
        'yesterday': 'ВЧЕРА',
        'earlier': 'РАНЕЕ',
      },
      'Қазақша': {
        'center': 'Хабарландыру орталығы',
        'notifications': 'Хабарламалар',
        'chats': 'Чаттар',
        'mark_all': 'Барлығын оқу',
        'today': 'БҮГІН',
        'yesterday': 'КЕШЕ',
        'earlier': 'ЕРТЕРЕК',
      },
    };
    return (localizedValues[widget.lang]?[key] ?? localizedValues['Русский']?[key] ?? key).toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A1D1E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_t('center'), style: const TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF4A80F0),
          indicatorWeight: 3,
          labelColor: const Color(0xFF4A80F0),
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          tabs: [
            Tab(text: _t('notifications')),
            Tab(text: _t('chats')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationsTab(),
          _buildChatsTab(),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        _buildDayHeader(_t('today')),
        _buildNotificationItem(
          title: 'Срок объявления истекает',
          body: 'Осталось 3 дня до переноса "Toyota Camry 70" в архив. Продлите его сейчас!',
          time: 'Только что',
          icon: Icons.history_rounded,
          color: const Color(0xFFF43F5E),
          isUnread: true,
        ),
        _buildNotificationItem(
          title: 'Модерация пройдена',
          body: 'Ваше объявление "iPhone 13 Pro" успешно опубликовано и активно.',
          time: '12 минут назад',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF10B981),
          isUnread: true,
        ),
        const SizedBox(height: 25),
        _buildDayHeader(_t('yesterday')),
        _buildNotificationItem(
          title: 'Новое сообщение',
          body: 'Руслан интересуется состоянием товара в вашем объявлении.',
          time: 'Вчера, 21:40',
          icon: Icons.chat_bubble_rounded,
          color: const Color(0xFF4A80F0),
          isUnread: false,
        ),
      ],
    );
  }

  Widget _buildChatsTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _selectedChats.isNotEmpty ? AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => setState(() => _selectedChats.clear()),
        ),
        title: Text('${_selectedChats.length} выделено', style: const TextStyle(color: Colors.white, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _chats.removeWhere((chat) => _selectedChats.contains(chat['seller']));
                _selectedChats.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Чат удален'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
        ],
      ) : null,
      body: ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 10),
      itemCount: _chats.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, endIndent: 20, color: Colors.black12),
      itemBuilder: (context, index) {
        final chat = _chats[index];
        final isSelected = _selectedChats.contains(chat['seller']);
        return InkWell(
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() => _selectedChats.add(chat['seller']));
          },
          onTap: () {
            if (_selectedChats.isNotEmpty) {
              setState(() {
                if (isSelected) _selectedChats.remove(chat['seller']);
                else _selectedChats.add(chat['seller']);
              });
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(
              ad: {
                'title': chat['ad_title'],
                'price': chat['price'],
                'seller': chat['seller'],
                'images': [chat['image']]
              }
            )));
            }
          },
          child: Container(
            color: isSelected ? const Color(0xFF4A80F0).withValues(alpha: 0.1) : (chat['unread'] > 0 ? const Color(0xFF4A80F0).withValues(alpha: 0.05) : Colors.transparent),
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
                          Flexible(child: Text((chat['seller'] ?? 'Собеседник').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                          Text((chat['time'] ?? '').toString(), style: TextStyle(color: (chat['unread'] ?? 0) > 0 ? const Color(0xFF4A80F0) : Colors.grey[500], fontSize: 12, fontWeight: (chat['unread'] ?? 0) > 0 ? FontWeight.bold : FontWeight.normal)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text((chat['ad_title'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if ((chat['last_msg'] ?? '').toString().startsWith('Вы:'))
                            const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.done_all_rounded, size: 14, color: Color(0xFF00E5FF))),
                          Expanded(child: Text((chat['last_msg'] ?? '').toString().replaceAll('Вы: ', ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 14))),
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

  Widget _buildDayHeader(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 16),
    child: Text(
      title,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5),
    ),
  );

  Widget _buildNotificationItem({
    required String title,
    required String body,
    required String time,
    required IconData icon,
    required Color color,
    required bool isUnread,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 5)),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(
              lang: widget.lang,
              ad: {
                'id': 'notif_1',
                'title': title.contains('Camry') ? 'Toyota Camry 70' : 'iPhone 13 Pro',
                'price': title.contains('Camry') ? '15 500 000 ₸' : '450 000 ₸',
                'seller': 'Продавец',
                'images': [
                  'https://images.unsplash.com/photo-1621007947382-bb3c3994e3fb?auto=format&fit=crop&w=800&q=80'
                ],
                'description': body,
                'location': 'Алматы',
                'category': 'Авто'
              },
              onReport: (id) {},
            )));
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    if (isUnread)
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A80F0),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
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
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: isUnread ? FontWeight.w900 : FontWeight.w800,
                                fontSize: 15,
                                color: const Color(0xFF1A1D1E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            time,
                            style: TextStyle(
                              color: isUnread ? const Color(0xFF4A80F0) : Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.5),
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
}
