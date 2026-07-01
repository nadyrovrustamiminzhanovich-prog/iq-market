import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/services/translation_service.dart';

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
  const ChatScreen({super.key, required this.ad});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _msgFocusNode = FocusNode();
  
  bool _isTyping = false;
  bool _isRecording = false;
  bool _isCancelled = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  Timer? _typingTimer;
  
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
  final Map<String, String> _localAudioPaths = {};
  bool _showEmoji = false;
  bool _isOtherOnline = false;
  bool _isOtherTyping = false;
  StreamSubscription? _presenceSubscription;
  // 🔒 AudioPlayer stream subscriptions — хранятся явно для отмены в dispose()
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;
  StreamSubscription? _audioCompleteSub;

  final List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚','😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🤩','🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤗','🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴','🤤','😪','😵','🤐','🥴','🤢','🤮','🤧','😷','🤒','🤕','🤑','🤠','😈','👿','👹','👺','🤡','💩','👻','💀','☠️','👽','👾','🤖','🎃','😺','😸','😹','😻','😼','😽','🙀','😿','😾','🔥','✨','🌟','💯','👍','👎','❤️','💔','✔️','❌'
  ];

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _audioPlayer = AudioPlayer();
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _audioPlayer.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        // defaultToSpeaker разрешён только с playAndRecord — убираем его.
        // playback сам по себе воспроизводит через основной динамик.
        category: AVAudioSessionCategory.playback,
        options: {},
      ),
    ));
    
    final otherId = widget.ad.userId;
    _messagesStream = ChatService.getMessagesStream(otherId);

    _audioPositionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _currentPos = p);
    });
    _audioDurationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _currentDur = d);
    });
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _currentPlayingId = null);
    });
    
    ChatService.activeChatId = ChatService.getChatId(otherId);
    if (UserService.currentUid != null) {
      ChatService.markAsRead(otherId);
      ChatService.updateOnlineStatus(otherId, true);
    }
    _loadUserNames();

    // Listen for online/typing presence of the other user
    final chatId = ChatService.getChatId(otherId);
    _presenceSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _isOtherTyping = data['typing_${otherId}'] == true;
          _isOtherOnline = data['online_${otherId}'] == true;
        });
      }
    });
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
    _typingTimer?.cancel();
    _presenceSubscription?.cancel();
    // ✅ Явная отмена AudioPlayer-стримов — предотвращает утечку памяти
    _audioPositionSub?.cancel();
    _audioDurationSub?.cancel();
    _audioCompleteSub?.cancel();
    if (_isRecording) {
      _recorder.stop();
    }
    _recorder.dispose();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _msgFocusNode.dispose();
    ChatService.updateTypingStatus(widget.ad.userId, false);
    if (ChatService.activeChatId == ChatService.getChatId(widget.ad.userId)) {
      ChatService.activeChatId = null;
      ChatService.updateOnlineStatus(widget.ad.userId, false);
    }
    super.dispose();
  }

  void _updateMyTyping(bool isTyping) {
    _typingTimer?.cancel();
    if (isTyping) {
      if (!_isTyping) {
        ChatService.updateTypingStatus(widget.ad.userId, true);
        setState(() => _isTyping = true);
      }
      _typingTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _isTyping) {
          ChatService.updateTypingStatus(widget.ad.userId, false);
          setState(() => _isTyping = false);
        }
      });
    } else {
      if (_isTyping) {
        ChatService.updateTypingStatus(widget.ad.userId, false);
        setState(() => _isTyping = false);
      }
    }
  }

  Future<void> _sendMessage() async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (Provider.of<AppConfigProvider>(context, listen: false).isUserBlocked(widget.ad.userId)) return;
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final backupText = _msgController.text;
    _typingTimer?.cancel();
    _msgController.clear();
    ChatService.updateTypingStatus(widget.ad.userId, false);
    setState(() => _isTyping = false);
    _scrollToBottom();
    
    try {
      final msgId = await ChatService.sendMessage(ad: widget.ad, text: text, senderName: _currentUserName);
      if (msgId == null) {
        throw Exception('Сообщение не сохранено в БД');
      }
      _playSentSound();
    } catch (e) {
      if (mounted) {
        _msgController.text = backupText;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t('errSendMsgInternet', lang)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    if (mounted) {
      setState(() { _isRecording = true; _recordSeconds = 0; _isCancelled = false; });
    }
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording() async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (!_isRecording) return;
    _recordTimer?.cancel();
    await Future.delayed(const Duration(milliseconds: 200));
    final path = await _recorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (_isCancelled) return;
    if (path != null) {
      final msgId = await ChatService.sendMessage(ad: widget.ad, text: 'Голосовое сообщение', type: 'audio', duration: _recordSeconds, senderName: _currentUserName);
      if (msgId != null) {
        _playSentSound();
        _localAudioPaths[msgId] = path;
        final chatId = ChatService.getChatId(widget.ad.userId);
        final task = FileService.uploadFileWithTask(File(path), 'voice_messages/$chatId');
        if (mounted) setState(() { _activeUploads[msgId] = task; });
        task.then((snapshot) async {
          final url = await snapshot.ref.getDownloadURL();
          ChatService.updateMessage(widget.ad.userId, msgId, {'mediaUrl': url});
          if (mounted) setState(() { _activeUploads.remove(msgId); });
        }).catchError((e) {
          if (mounted) {
            setState(() { _activeUploads.remove(msgId); });
            // P8 FIX: inform user that voice upload failed so they can retry
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Не удалось загрузить голосовое. Попробуйте ещё раз.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                duration: const Duration(seconds: 4),
              ),
            );
          }
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(TranslationService.t('errSendVoiceMsg', lang)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _playTapSound() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tap.wav');
      if (!await file.exists()) {
        final sampleRate = 22050;
        final durationMs = 80;
        final totalSamples = (sampleRate * durationMs / 1000).toInt();
        final bytesPerSample = 2; 
        final subChunk2Size = totalSamples * bytesPerSample;
        final chunkSize = 36 + subChunk2Size;

        final header = ByteData(44);
        header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
        header.setUint32(4, chunkSize, Endian.little);
        header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
        header.setUint8(12, 0x66); header.setUint8(13, 0x6d); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, 1, Endian.little);
        header.setUint32(24, sampleRate, Endian.little);
        header.setUint32(28, sampleRate * bytesPerSample, Endian.little);
        header.setUint16(32, bytesPerSample, Endian.little);
        header.setUint16(34, 16, Endian.little);
        header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
        header.setUint32(40, subChunk2Size, Endian.little);

        final data = Int16List(totalSamples);
        final frequency = 880.0;
        for (int i = 0; i < totalSamples; i++) {
          final t = i / sampleRate;
          final envelope = (totalSamples - i) / totalSamples;
          data[i] = (math.sin(2 * math.pi * frequency * t) * 32767 * 0.3 * envelope).toInt();
        }

        final buffer = BytesBuilder();
        buffer.add(header.buffer.asUint8List());
        buffer.add(data.buffer.asUint8List());
        await file.writeAsBytes(buffer.toBytes());
      }
      
      final tapPlayer = AudioPlayer();
      await tapPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
      await tapPlayer.play(DeviceFileSource(file.path));
      Future.delayed(const Duration(milliseconds: 500), () => tapPlayer.dispose());
    } catch (e) {
      debugPrint('Error playing tap sound: $e');
    }
  }

  void _playSentSound() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sent.wav');
      if (!await file.exists()) {
        final sampleRate = 22050;
        final durationMs = 80;
        final totalSamples = (sampleRate * durationMs / 1000).toInt();
        final bytesPerSample = 2; 
        final subChunk2Size = totalSamples * bytesPerSample;
        final chunkSize = 36 + subChunk2Size;

        final header = ByteData(44);
        header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
        header.setUint32(4, chunkSize, Endian.little);
        header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
        header.setUint8(12, 0x66); header.setUint8(13, 0x6d); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
        header.setUint32(16, 16, Endian.little);
        header.setUint16(20, 1, Endian.little);
        header.setUint16(22, 1, Endian.little);
        header.setUint32(24, sampleRate, Endian.little);
        header.setUint32(28, sampleRate * bytesPerSample, Endian.little);
        header.setUint16(32, bytesPerSample, Endian.little);
        header.setUint16(34, 16, Endian.little);
        header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
        header.setUint32(40, subChunk2Size, Endian.little);

        final data = Int16List(totalSamples);
        final frequency = 1200.0;
        for (int i = 0; i < totalSamples; i++) {
          final t = i / sampleRate;
          final envelope = math.pow((totalSamples - i) / totalSamples, 2); 
          data[i] = (math.sin(2 * math.pi * frequency * t) * 32767 * 0.25 * envelope).toInt();
        }

        final buffer = BytesBuilder();
        buffer.add(header.buffer.asUint8List());
        buffer.add(data.buffer.asUint8List());
        await file.writeAsBytes(buffer.toBytes());
      }
      
      final sentPlayer = AudioPlayer();
      await sentPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: false,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
        ),
      ));
      await sentPlayer.play(DeviceFileSource(file.path));
      Future.delayed(const Duration(milliseconds: 500), () => sentPlayer.dispose());
    } catch (e) {
      debugPrint('Error playing sent sound: $e');
    }
  }

  void _playVoice(String id, String url) async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    try {
      debugPrint('Playing voice: id=$id, url=$url');
      if (_currentPlayingId == id) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _currentPlayingId = null);
      } else {
        _playTapSound();
        await _audioPlayer.stop();
        
        // 🔒 Reset audio context before playing to force speakerphone output and set max volume.
        // This is crucial because starting a recording session switches the global audio session
        // to a communication mode, making all playback route through the earpiece.
        await _audioPlayer.setAudioContext(AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.gain,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playAndRecord,
            options: {
              AVAudioSessionOptions.defaultToSpeaker,
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ));
        await _audioPlayer.setVolume(1.0);

        // 🔒 Optimization: Use local file if available to speed up playback and save bandwidth
        final localPath = _localAudioPaths[id];
        bool playLocal = false;
        if (localPath != null && await File(localPath).exists()) {
          playLocal = true;
        }

        if (playLocal) {
          debugPrint('Playing local voice file: $localPath');
          await _audioPlayer.play(DeviceFileSource(localPath!));
        } else if (url.startsWith('http')) {
          await _audioPlayer.play(UrlSource(url));
        } else {
          await _audioPlayer.play(DeviceFileSource(url));
        }
        
        if (mounted) {
          setState(() {
            _currentPlayingId = id;
            _currentPos = Duration.zero;
            _currentDur = Duration.zero;
          });
        }
      }
    } catch (e) {
      debugPrint('Error playing voice: $e');
      if (mounted) {
        setState(() {
          _currentPlayingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('errPlayback', lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _pickMedia(ImageSource source) async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (Provider.of<AppConfigProvider>(context, listen: false).isUserBlocked(widget.ad.userId)) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(source: source, imageQuality: 70);
    } catch (e) {
      debugPrint("Error picking chat image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(TranslationService.t('errOpenGalleryCamera', lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }
    
    if (file != null) {
      try {
        final chatId = ChatService.getChatId(widget.ad.userId);
        final url = await FileService.uploadFile(File(file.path), 'chat_media/$chatId');
        if (url != null) {
          final msgId = await ChatService.sendMessage(ad: widget.ad, text: 'Фото', type: 'image', mediaUrl: url, senderName: _currentUserName);
          if (msgId == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('errSendPhoto', lang)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
            );
          }
          _scrollToBottom();
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('errLoadPhoto', lang)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('errPrefix', lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<AppConfigProvider>(context);
    final lang = config.language;
    final isBlocked = config.isUserBlocked(widget.ad.userId);
    const chatBg = Color(0xFFF1F5F9); 
    const myBubbleColor = Color(0xFF3B82F6);
    const otherBubbleColor = Colors.white;

    return Scaffold(
      backgroundColor: chatBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: ChatBackgroundPainter())),
          Column(children: [
            SizedBox(height: MediaQuery.of(context).padding.top + 120),
            Expanded(
              child: StreamBuilder<List<MessageModel>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)));
                  final messages = snapshot.data ?? [];
                  if (messages.isEmpty) return _buildEmptyState();
                  return _buildMessageList(messages, myBubbleColor, otherBubbleColor);
                },
              ),
            ),
            if (isBlocked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                margin: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16, left: 16, right: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_flipped, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        TranslationService.t('blocked_user_banner', lang),
                        style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              ChatInput(
                controller: _msgController,
                focusNode: _msgFocusNode,
                isTyping: _isTyping,
                isRecording: _isRecording,
                recordSeconds: _recordSeconds,
                showEmoji: _showEmoji,
                hintText: TranslationService.t('chat_input_hint', lang),
                recordCancelText: TranslationService.t('record_cancel_hint', lang),
                onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
                onTextChanged: (v) => _updateMyTyping(v.isNotEmpty),
                onAttach: () => _pickMedia(ImageSource.gallery),
                onSend: _sendMessage,
                onLongPressStart: _startRecording,
                onLongPressEnd: _stopRecording,
                onEmojiSelected: (emoji) {
                  // P10 FIX: preserve cursor at end, don't reset it to start
                  final text = _msgController.text;
                  final newText = text + emoji;
                  _msgController.value = TextEditingValue(
                    text: newText,
                    selection: TextSelection.collapsed(offset: newText.length),
                  );
                  _updateMyTyping(true);
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
                  isOnline: _isOtherOnline,
                  isTyping: _isOtherTyping,
                  onBack: () => Navigator.of(context).maybePop(),
                  onProfileTap: _navigateToSellerProfile,
                  onCall: () async {
                    final phoneNum = _otherUserPhone ?? widget.ad.userPhone ?? '';
                    if (phoneNum.isNotEmpty) {
                      final url = Uri.parse('tel:$phoneNum');
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    } else {
                      NotificationService.notify(context, TranslationService.t('error_title', lang), TranslationService.t('no_phone_error', lang), isSuccess: false);
                    }
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
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
        const SizedBox(height: 16),
        Text(TranslationService.t('chat_start', lang), style: const TextStyle(color: Colors.white54)),
      ],
    ));
  }

  Widget _buildMessageList(List<MessageModel> messages, Color myColor, Color otherColor) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
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
          lang: lang,
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
            _msgController.text = TranslationService.t('chat_input_bargain_text', lang);
            _msgFocusNode.requestFocus();
            setState(() {
              _isTyping = true;
            });
          },
          onVoiceOffer: () {
            NotificationService.notify(context, TranslationService.t('voice_reply_title', lang), TranslationService.t('voice_reply_desc', lang), isSuccess: true);
          },
          onCallOffer: () async {
            final phoneNum = _otherUserPhone ?? widget.ad.userPhone ?? '';
            if (phoneNum.isNotEmpty) {
              final url = Uri.parse('tel:$phoneNum');
              try {
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.t('errNoPhoneCallApp', lang)), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(TranslationService.t('errCall', lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
                  );
                }
              }
            } else {
              NotificationService.notify(context, TranslationService.t('error_title', lang), TranslationService.t('no_phone_error', lang), isSuccess: false);
            }
          },
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final now = DateTime.now();
    String text;
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      text = TranslationService.t('today', lang);
    } else if (now.day - 1 == date.day && now.month == date.month && now.year == date.year) {
      text = TranslationService.t('yesterday', lang);
    } else {
      final locale = lang == 'Қазақша' ? 'kk' : (lang == 'Уйғурчә' ? 'ug' : 'ru');
      text = DateFormat('d MMMM', locale).format(date);
    }
    return Center(child: Container(margin: const EdgeInsets.symmetric(vertical: 12), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: const Color(0xFF17212D).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)), child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))));
  }

  void _showContextMenu(MessageModel msg) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    final bool isMyMessage = msg.senderId == UserService.currentUid;
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C2B3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              if (msg.type == 'text') ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white70), 
                title: Text(TranslationService.t('copy_text', lang), style: const TextStyle(color: Colors.white)), 
                onTap: () { 
                  Clipboard.setData(ClipboardData(text: msg.text)); 
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(TranslationService.t('copied', lang)),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              ),
              if (isMyMessage) ListTile(
                leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent), 
                title: Text(TranslationService.t('delete_for_all', lang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)), 
                onTap: () async { 
                  Navigator.pop(context);
                  final count = await ChatService.deleteMessages(widget.ad.userId, [msg.id]); 
                  if (count == 0 && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(TranslationService.t('errDeleteMsg', lang)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                    );
                  }
                }
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String url) {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    Navigator.push(context, MaterialPageRoute(builder: (innerCtx) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.download_rounded), onPressed: () async {
      try {
        final response = await http.get(Uri.parse(url));
        await Gal.putImageBytes(response.bodyBytes);
        if (innerCtx.mounted) {
          ScaffoldMessenger.of(innerCtx).showSnackBar(SnackBar(content: Text(TranslationService.t('saved_to_gallery', lang))));
        }
      } catch (e) {
        if (innerCtx.mounted) {
          ScaffoldMessenger.of(innerCtx).showSnackBar(
            SnackBar(content: Text(TranslationService.t('errSavePhoto', lang).replaceAll('{error}', e.toString())), backgroundColor: Colors.redAccent),
          );
        }
      }
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
        final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(seller: widget.ad, lang: lang, sellerAds: ads)));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
    }
  }
}
