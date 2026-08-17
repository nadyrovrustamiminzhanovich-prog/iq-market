import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/screens/chat_screen.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/screens/login_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  int _retryCounter = 0;

  // Мемоизировано на весь жизненный цикл экрана. ChatService.getChatListStream()
  // не кэширует сама себя — раньше вызов стоял прямо в stream: внутри build(),
  // а build() этого экрана перестраивается на любой Provider.notifyListeners()
  // (смена языка/города/избранного), не только на новое сообщение. Каждый такой
  // rebuild гасил и открывал заново listener на ВСЮ коллекцию chats разом.
  late final Stream<List<Map<String, dynamic>>> _chatListStream = ChatService.getChatListStream();

  /// Превью последнего сообщения на языке ЧИТАЮЩЕГО, а не на языке, на
  /// котором его отправили. Раньше 'Фото'/'Голосовое сообщение' писались в
  /// lastMessage как есть на русском и показывались так же всем — теперь
  /// переводим по lastMessageType, а сырой текст оставляем только для
  /// реальных текстовых сообщений (их переводить нельзя, это чужие слова).
  /// Старые чаты без lastMessageType (созданные до этого фикса) просто
  /// показывают сырой текст как раньше — обратная совместимость.
  String _formatLastMessagePreview(Map<String, dynamic> chat, String rawLastMsg, String lang) {
    final String? type = chat['lastMessageType'];
    switch (type) {
      case 'image':
        return TranslationService.t('chatPreviewPhoto', lang);
      case 'audio':
        return TranslationService.t('chatPreviewVoice', lang);
      case 'offer':
        final price = (chat['lastOfferPrice'] as num?)?.toInt();
        final label = TranslationService.t('chatPreviewOffer', lang);
        return price != null ? '$label: $price ₸' : label;
      case 'cleared':
        return TranslationService.t('chatPreviewCleared', lang);
      case 'empty':
        // Все сообщения переписки удалены «у всех» — превью обязано опустеть
        // вместе с ними, иначе в списке чатов остаётся висеть текст, который
        // пользователь только что удалил.
        return TranslationService.t('chatPreviewEmpty', lang);
      case 'system':
        // Исход оффера. Без этой ветки превью показывало бы русский текст
        // сообщения всем читателям независимо от их языка.
        final key = chat['lastSystemKey'] as String?;
        if (key == null || key.isEmpty) return rawLastMsg;
        final translated = TranslationService.t('${key}_msg', lang);
        return translated == '${key}_msg' ? rawLastMsg : translated;
      default:
        return rawLastMsg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = UserService.currentUid;
    final lang = Provider.of<AppConfigProvider>(context).language;
    final canPop = Navigator.canPop(context);
    if (uid == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            TranslationService.t('chats', lang),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          leading: canPop
              ? IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                )
              : null,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 80,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 24),
                Text(
                  TranslationService.t('auth_required_title', lang),
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  TranslationService.t('auth_required_chats_desc', lang),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A80F0), Color(0xFF3B82F6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(lang: lang, returnToCallerOnSuccess: true),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        TranslationService.t('login_btn', lang),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        // Кнопку «назад» показываем только если экран открыт как отдельный route
        leading: canPop
            ? IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
        title: Text(TranslationService.t('my_messages', lang), style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: false,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurface),
            onSelected: (v) {
              if (v == 'read_all') {
                ChatService.markAllChatsAsRead();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'read_all', child: Text(TranslationService.t('mark_all_read', lang))),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        key: ValueKey(_retryCounter),
        stream: _chatListStream,
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
                      TranslationService.t('errLoadingData', lang),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                        TranslationService.t('retryBtn', lang),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final config = Provider.of<AppConfigProvider>(context);
          final chats = (snapshot.data ?? []).where((chat) {
            final List users = chat['users'] ?? [];
            final String otherUserId = users.firstWhere((id) => id != uid, orElse: () => '');
            return !config.blockedUserIds.contains(otherUserId);
          }).toList();
          if (chats.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(TranslationService.t('no_chats_yet', lang), style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final String rawLastMsg = chat['lastMessage'] ?? '';
              final String lastMsg = _formatLastMessagePreview(chat, rawLastMsg, lang);
              final Timestamp? ts = chat['lastTimestamp'] as Timestamp?;
              final String time = ts != null ? _formatTimestamp(ts) : '';
              final int unreadCount = chat['unreadCount_$uid'] ?? 0;
              final String adTitle = chat['adTitle'] ?? 'Объявление';
              final String adImage = chat['adImage'] ?? '';
              final String adId = chat['adId'] ?? '';
              
              final List users = chat['users'] ?? [];
              final String sellerId = users.firstWhere((id) => id != uid, orElse: () => '');
              final String fallbackName = chat['name_$sellerId'] ?? 'Пользователь';

              return _ChatListTile(
                key: ValueKey(chat['id']),
                chatId: chat['id'] ?? '',
                sellerId: sellerId,
                fallbackName: fallbackName,
                adTitle: adTitle,
                adImage: adImage,
                adId: adId,
                lastMsg: lastMsg,
                time: time,
                unreadCount: unreadCount,
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

class _ChatListTile extends StatefulWidget {
  final String chatId;
  final String sellerId;
  final String fallbackName;
  final String adTitle;
  final String adImage;
  final String adId;
  final String lastMsg;
  final String time;
  final int unreadCount;

  const _ChatListTile({
    super.key,
    required this.chatId,
    required this.sellerId,
    required this.fallbackName,
    required this.adTitle,
    required this.adImage,
    required this.adId,
    required this.lastMsg,
    required this.time,
    required this.unreadCount,
  });

  @override
  State<_ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<_ChatListTile> {
  // Мемоизировано на весь жизненный цикл СТРОКИ (не всего списка) — раньше
  // этот стрим пересоздавался для каждой строки на каждый rebuild списка
  // (новое сообщение в любом из чатов, смена языка и т.д.), т.е. один пришедший
  // месседж гасил и открывал заново listener'ы ВСЕХ строк одновременно.
  // key: ValueKey(chat['id']) на месте создания гарантирует, что при
  // изменении порядка чатов Flutter не перепутает этот стрим с чужим сюда.
  late final Stream<DocumentSnapshot>? _sellerStream =
      widget.sellerId.isNotEmpty ? UserService.users.doc(widget.sellerId).snapshots() : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _sellerStream,
      builder: (context, userSnap) {
        String displaySellerName = widget.fallbackName;
        if (userSnap.hasData && userSnap.data!.exists) {
          final uData = userSnap.data!.data() as Map<String, dynamic>?;
          if (uData != null && uData['name'] != null && uData['name'].toString().trim().isNotEmpty) {
            displaySellerName = uData['name'];
          }
        }

        final ad = AdModel(
          id: widget.adId, title: widget.adTitle, description: '', price: 0.0, category: '',
          images: widget.adImage.isNotEmpty ? [widget.adImage] : [], userId: widget.sellerId, userName: displaySellerName,
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
                              // Тег завязан на id чата, а не объявления: если по одному
                              // объявлению открыто несколько чатов, одинаковый adId-тег
                              // давал коллизию нескольких Hero в одном списке одновременно.
                              tag: 'chat_ad-image-${widget.chatId}',
                              child: widget.adImage.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.adImage,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 150,
                                    placeholder: (context, url) => Container(color: theme.colorScheme.surface),
                                    errorWidget: (context, url, error) => const Icon(Icons.error_outline_rounded),
                                  )
                                : const Icon(Icons.person_outline_rounded, color: Colors.grey),
                            ),
                          ),
                        ),
                        if (widget.unreadCount > 0)
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
                              Expanded(child: Text(displaySellerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface))),
                              Text(widget.time, style: TextStyle(color: widget.unreadCount > 0 ? const Color(0xFF4A80F0) : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(widget.adTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 12, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: Text(widget.lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14, fontWeight: widget.unreadCount > 0 ? FontWeight.w700 : FontWeight.normal))),
                              if (widget.unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 10),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(10)),
                                  child: Text(widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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
  }
}
