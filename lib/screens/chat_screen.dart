import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/message_model.dart';

import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/screens/seller_profile_screen.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:gal/gal.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../widgets/chat/chat_background_painter.dart';
import '../widgets/chat/chat_bubbles.dart';
import '../widgets/chat/chat_headers.dart';
import '../widgets/chat/chat_input.dart';

class ChatScreen extends StatefulWidget {
  final AdModel ad;
  final String? initialOffer;
  const ChatScreen({super.key, required this.ad, this.initialOffer});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _msgFocusNode = FocusNode();
  
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isCancelled = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  
  late final AudioRecorder _recorder;
  late final AudioPlayer _audioPlayer;
  
  String? _currentPlayingId;
  Duration _currentPos = Duration.zero;
  Duration _currentDur = Duration.zero;
  String _currentUserName = 'Пользователь';
  String? _sellerAvatarUrl;
  String? _otherUserPhone;
  late Stream<List<MessageModel>> _messagesStream;
  final Map<String, UploadTask> _activeUploads = {};
  bool _showEmoji = false;

  final List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚','😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🤩','🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤗','🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴','🤤','😪','😵','🤐','🥴','🤢','🤮','🤧','😷','🤒','🤕','🤑','🤠','😈','👿','👹','👺','🤡','💩','👻','💀','☠️','👽','👾','🤖','🎃','😺','😸','😹','😻','😼','😽','🙀','😿','😾','🔥','✨','🌟','💯','👍','👎','❤️','💔','✔️','❌'
  ];

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    
    final otherId = widget.ad.userId;
    _messagesStream = ChatService.getMessagesStream(otherId);

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _currentPos = p);
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _currentDur = d);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _currentPlayingId = null);
    });
    
    ChatService.activeChatId = ChatService.getChatId(otherId);
    if (UserService.currentUid != null) {
      ChatService.markAsRead(otherId);
    }
    _loadUserNames();
  }

  void _loadUserNames() async {
    final me = await UserService.getUserById(UserService.currentUid ?? '');
    if (me != null && mounted) setState(() => _currentUserName = me.name);

    final seller = await UserService.getUserById(widget.ad.userId);
    if (seller != null && mounted) {
      setState(() {
        _sellerAvatarUrl = seller.photoUrl;
        _otherUserPhone = seller.phone;
      });
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _msgFocusNode.dispose();
    if (ChatService.activeChatId == ChatService.getChatId(widget.ad.userId)) {
      ChatService.activeChatId = null;
    }
    super.dispose();
  }

  void _sendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    ChatService.sendMessage(ad: widget.ad, text: text, senderName: _currentUserName);
    _msgController.clear();
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    HapticFeedback.mediumImpact();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { _isRecording = true; _recordSeconds = 0; _isCancelled = false; });
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _recordSeconds++));
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _recordTimer?.cancel();
    await Future.delayed(const Duration(milliseconds: 200));
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (_isCancelled) return;
    if (path != null) {
      final msgId = await ChatService.sendMessage(ad: widget.ad, text: 'Голосовое сообщение', type: 'audio', duration: _recordSeconds, senderName: _currentUserName);
      if (msgId != null) {
        final task = FileService.uploadFileWithTask(File(path), 'voice_messages');
        setState(() => _activeUploads[msgId] = task);
        task.then((snapshot) async {
          final url = await snapshot.ref.getDownloadURL();
          ChatService.updateMessage(widget.ad.userId, msgId, {'mediaUrl': url});
          if (mounted) setState(() => _activeUploads.remove(msgId));
        }).catchError((e) {
          if (mounted) setState(() => _activeUploads.remove(msgId));
        });
      }
    }
  }

  void _playVoice(String id, String url) async {
    try {
      if (_currentPlayingId == id) {
        await _audioPlayer.pause();
        setState(() => _currentPlayingId = null);
      } else {
        await _audioPlayer.stop(); // Stop any currently playing audio first!
        await _audioPlayer.play(UrlSource(url));
        setState(() {
          _currentPlayingId = id;
          _currentPos = Duration.zero;
          _currentDur = Duration.zero;
        });
      }
    } catch (e) {
      debugPrint('Error playing voice: $e');
    }
  }

  void _pickMedia(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 70);
    if (file != null) {
      final url = await FileService.uploadFile(File(file.path), 'chat_media');
      if (url != null) {
        ChatService.sendMessage(ad: widget.ad, text: 'Фото', type: 'image', mediaUrl: url, senderName: _currentUserName);
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const chatBg = Color(0xFF0E1621); 
    const myBubbleColor = Color(0xFF2B5278);
    const otherBubbleColor = Color(0xFF182533);

    return Scaffold(
      backgroundColor: chatBg,
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.2, child: CustomPaint(painter: ChatBackgroundPainter()))),
          Column(children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 120),
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)));
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) return _buildEmptyState();
                  return _buildMessageList(messages.reversed.toList(), myBubbleColor, otherBubbleColor);
                },
              ),
            ),
            ChatInput(
              controller: _msgController,
              focusNode: _msgFocusNode,
              isTyping: _isTyping,
              isRecording: _isRecording,
              recordSeconds: _recordSeconds,
              showEmoji: _showEmoji,
              onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
              onTextChanged: (v) {
                final isNowTyping = v.isNotEmpty;
                if (_isTyping != isNowTyping) {
                  ChatService.updateTypingStatus(widget.ad.userId, isNowTyping);
                  setState(() => _isTyping = isNowTyping);
                }
              },
              onAttach: () => _pickMedia(ImageSource.gallery),
              onSend: _sendMessage,
              onLongPressStart: _startRecording,
              onLongPressEnd: _stopRecording,
              onEmojiSelected: (emoji) {
                _msgController.text += emoji;
                setState(() => _isTyping = true);
              },
              emojis: _emojis,
            ),
          ]),
          Positioned(
            top: 0, left: 0, right: 0,
            child: Column(
              children: [
                ChatGlassHeader(
                  ad: widget.ad, sellerAvatarUrl: _sellerAvatarUrl,
                  onBack: () => Navigator.of(context).maybePop(),
                  onProfileTap: _navigateToSellerProfile,
                  onCall: () async {
                    final url = Uri.parse('tel:${widget.ad.userPhone ?? '+77000000000'}');
                    if (await canLaunchUrl(url)) await launchUrl(url);
                  },
                ),
                ChatAdInfoBar(ad: widget.ad),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        const Text('Начните общение', style: TextStyle(color: Colors.white54)),
      ],
    ));
  }

  Widget _buildMessageList(List<MessageModel> messages, Color myColor, Color otherColor) {
    final groupedItems = <dynamic>[];
    
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      groupedItems.add(msg);
      
      final date = DateTime(msg.timestamp.year, msg.timestamp.month, msg.timestamp.day);
      final nextMsg = (i + 1 < messages.length) ? messages[i + 1] : null;
      final nextDate = nextMsg != null 
          ? DateTime(nextMsg.timestamp.year, nextMsg.timestamp.month, nextMsg.timestamp.day) 
          : null;
      
      if (nextDate == null || date != nextDate) {
        groupedItems.add(date);
      }
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 110), 
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final item = groupedItems[index];
        if (item is DateTime) return _buildDateHeader(item);
        final msg = item as MessageModel;
        return ChatBubble(
          msg: msg,
          sellerAvatarUrl: _sellerAvatarUrl,
          myBubbleColor: myColor,
          otherBubbleColor: otherColor,
          textColor: Colors.white,
          subTextColor: Colors.white70,
          onPlayVoice: _playVoice,
          isPlaying: _currentPlayingId == msg.id,
          currentPos: _currentPos,
          currentDur: _currentDur,
          onLongPress: _showContextMenu,
          onImageTap: _showFullScreenImage,
          onAcceptOffer: () => ChatService.updateOfferStatus(msg.senderId, msg.id, 'accepted'),
          onDeclineOffer: () => ChatService.updateOfferStatus(msg.senderId, msg.id, 'rejected'),
          onWriteOffer: () {
            _msgController.text = 'Привет! Насчет вашего предложения цены... ';
            _msgFocusNode.requestFocus();
            setState(() {
              _isTyping = true;
            });
          },
          onVoiceOffer: () {
            NotificationService.notify(context, 'Голосовой ответ', 'Зажмите синюю круглую кнопку микрофона справа внизу, чтобы записать голосовое сообщение.', isSuccess: true);
          },
          onCallOffer: () async {
            final phoneNum = _otherUserPhone ?? widget.ad.userPhone ?? '';
            if (phoneNum.isNotEmpty) {
              final url = Uri.parse('tel:$phoneNum');
              if (await canLaunchUrl(url)) await launchUrl(url);
            } else {
              NotificationService.notify(context, 'Ошибка', 'Номер телефона этого пользователя не указан.', isSuccess: false);
            }
          },
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final now = DateTime.now();
    String text = (now.day == date.day && now.month == date.month && now.year == date.year) ? 'Сегодня' : (now.day - 1 == date.day && now.month == date.month && now.year == date.year) ? 'Вчера' : DateFormat('d MMMM', 'ru').format(date);
    return Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF17212D).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))));
  }

  void _showContextMenu(MessageModel msg) {
    final bool isMyMessage = msg.senderId == UserService.currentUid;
    showModalBottomSheet(
      context: context, 
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            if (msg.type == 'text') ListTile(
              leading: const Icon(Icons.copy_rounded), 
              title: const Text('Копировать текст'), 
              onTap: () { 
                Clipboard.setData(ClipboardData(text: msg.text)); 
                Navigator.pop(context); 
              }
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.grey), 
              title: const Text('Удалить у меня'), 
              onTap: () { 
                ChatService.deleteMessages(widget.ad.userId, [msg.id]); 
                Navigator.pop(context); 
              }
            ),
            if (isMyMessage) ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red), 
              title: const Text('Удалить у всех', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)), 
              onTap: () { 
                ChatService.deleteMessages(widget.ad.userId, [msg.id]); 
                Navigator.pop(context); 
              }
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.download_rounded), onPressed: () async {
      final response = await http.get(Uri.parse(url));
      await Gal.putImageBytes(response.bodyBytes);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено в галерею')));
    })]), body: Center(child: InteractiveViewer(child: (url.isNotEmpty && url.startsWith('http')) 
      ? CachedNetworkImage(
          imageUrl: url,
          placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white),
          errorWidget: (context, url, error) => const Icon(Icons.error_outline_rounded, color: Colors.white, size: 40),
        )
      : const Icon(Icons.broken_image_rounded, color: Colors.white, size: 40)
    )))));

  }

  void _navigateToSellerProfile() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final adsStream = AdService.getAdsByUserStream(widget.ad.userId);
      final adsList = await adsStream.first;
      final ads = adsList;
      
      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: widget.ad, lang: 'Русский', sellerAds: ads)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }
}
