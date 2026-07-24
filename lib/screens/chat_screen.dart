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

import 'package:iqmarket/constants/voice_limits_config.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/file_service.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/notification_service.dart';
import 'package:iqmarket/services/storage_service.dart';
import 'package:iqmarket/screens/seller_profile_screen.dart';
import 'package:iqmarket/screens/profile_settings_screen.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:iqmarket/services/analytics_service.dart';

import 'package:iqmarket/widgets/secure_image_viewer.dart';

import '../widgets/chat/chat_background_painter.dart';
import '../widgets/chat/chat_bubbles.dart';
import '../widgets/chat/chat_headers.dart';
import '../widgets/chat/chat_input.dart';
import '../widgets/chat/chat_date_header.dart';
import '../widgets/chat/chat_context_menu.dart';
import '../widgets/chat/chat_empty_state.dart';

class ChatScreen extends StatefulWidget {
  final AdModel ad;
  final String? chatId;
  final AudioRecorder? recorder;
  final FirebaseFirestore? firestore;
  const ChatScreen({super.key, required this.ad, this.chatId, this.recorder, this.firestore});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
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

  String get _otherUserId {
    final uid = UserService.currentUid;
    if (uid == null) return widget.ad.userId;
    
    final explicitChatId = widget.chatId;
    if (explicitChatId != null && explicitChatId.isNotEmpty && explicitChatId.contains('_')) {
      final parts = explicitChatId.split('_');
      if (parts.length == 2) {
        return parts[0] == uid ? parts[1] : parts[0];
      }
    }
    return widget.ad.userId;
  }

  late Stream<List<MessageModel>> _messagesStream;
  final Map<String, UploadTask> _activeUploads = {};
  final Map<String, String> _localAudioPaths = {};
  final Map<String, String> _localImagePaths = {};
  bool _showEmoji = false;
  DateTime? _lastTypingSentTime;
  // 🔒 AudioPlayer stream subscriptions — хранятся явно для отмены в dispose()
  StreamSubscription? _audioPositionSub;
  StreamSubscription? _audioDurationSub;
  StreamSubscription? _audioCompleteSub;

  bool _isChatValidating = false;
  bool _isAccessDenied = false;
  // true  → чат СУЩЕСТВУЕТ, но uid не в participants (или permission-denied при чтении).
  // false → чат реально удалён / другая ошибка — показываем старый текст «Чат недоступен».
  bool _isWrongAccount = false;

  final List<String> _emojis = [
    '😀','😃','😄','😁','😆','😅','😂','🤣','😊','😇','🙂','🙃','😉','😌','😍','🥰','😘','😗','😙','😚','😋','😛','😝','😜','🤪','🤨','🧐','🤓','😎','🤩','🥳','😏','😒','😞','😔','😟','😕','🙁','☹️','😣','😖','😫','😩','🥺','😢','😭','😤','😠','😡','🤬','🤯','😳','🥵','🥶','😱','😨','😰','😥','😓','🤗','🤔','🤭','🤫','🤥','😶','😐','😑','😬','🙄','😯','😦','😧','😮','😲','🥱','😴','🤤','😪','😵','🤐','🥴','🤢','🤮','🤧','😷','🤒','🤕','🤑','🤠','😈','👿','👹','👺','🤡','💩','👻','💀','☠️','👽','👾','🤖','🎃','😺','😸','😹','😻','😼','😽','🙀','😿','😾','🔥','✨','🌟','💯','👍','👎','❤️','💔','✔️','❌'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorder = widget.recorder ?? AudioRecorder();
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
        category: AVAudioSessionCategory.playback,
        options: {},
      ),
    ));
    
    final otherId = _otherUserId;
    final explicitChatId = widget.chatId;

    _audioPositionSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _currentPos = p);
    });
    _audioDurationSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _currentDur = d);
    });
    _audioCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _currentPlayingId = null);
    });
    
    if (widget.recorder == null) {
      _isChatValidating = true;
      _validateChatId(explicitChatId != null && explicitChatId.isNotEmpty
          ? explicitChatId
          : ChatService.getChatId(otherId));
      _loadUserNames();
    } else {
      _isChatValidating = false;
      _isAccessDenied = false;
      _messagesStream = const Stream.empty();
    }
  }

  void _loadUserNames() async {
    final me = await UserService.getUserById(UserService.currentUid ?? '');
    if (me != null && mounted) setState(() => _currentUserName = me.name);

    final seller = await UserService.getUserById(_otherUserId);
    if (seller != null && mounted) {
      setState(() {
        _sellerAvatarUrl = seller.photoUrl;
        _otherUserPhone = seller.phone;
      });
    }
  }

  void _validateChatId(String chatId) async {
    final uid = UserService.currentUid;
    if (uid == null) {
      if (mounted) setState(() { _isChatValidating = false; _isAccessDenied = true; });
      return;
    }

    try {
      final docSnap = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!docSnap.exists) {
        debugPrint('[CHAT_SECURITY] Chat $chatId not found. Falling back to default chatId.');
        if (mounted) {
          setState(() {
            _isChatValidating = false;
            _messagesStream = ChatService.getMessagesStream(_otherUserId);
            ChatService.activeChatId = ChatService.getChatId(_otherUserId);
          });
          
          AnalyticsService.logPushNavigation('chat_fallback_triggered', extra: {
            'attempted_chat_id': chatId,
            'fallback_chat_id': ChatService.activeChatId ?? '',
            'is_from_push': widget.chatId != null ? 'true' : 'false'
          });
          AnalyticsService.logPushNavigation('chat_opened', extra: {
            'chat_id': ChatService.activeChatId ?? '',
            'mode': 'fallback',
            'is_from_push': widget.chatId != null ? 'true' : 'false'
          });

          // ✅ Fallback на стандартный chatId (собственный детерминированный ID).
          // markAsRead вызывается ТОЛЬКО здесь — после безопасного fallback.
          // Fallback не может привести в чужой чат: getChatId(otherId) детерминирован
          // через sorted([currentUid, otherId]).join('_'), клиент не контролирует результат.
          if (UserService.currentUid != null) {
            ChatService.markAsRead(_otherUserId);
          }
        }
        return;
      }

      final List<dynamic> users = docSnap.data()?['users'] ?? [];
      if (!users.contains(uid)) {
        debugPrint('[CHAT_SECURITY] SECURITY WARNING: User $uid tried to access chat $chatId but is not a participant!');
        
        AnalyticsService.logPushNavigation('chat_access_denied', extra: {
          'chat_id': chatId,
          'uid': uid,
          'is_from_push': widget.chatId != null ? 'true' : 'false'
        });

        if (mounted) {
          setState(() {
            _isChatValidating = false;
            _isAccessDenied = true;
            // Чат существует, но uid не в списке участников — вероятнее всего смена аккаунта.
            _isWrongAccount = true;
          });
          // ✅ НЕ вызываем markAsRead — пользователь не является участником
        }
        return;
      }

      // Valid participant! Load stream and presence sync
      if (mounted) {
        setState(() {
          _isChatValidating = false;
          _messagesStream = ChatService.getMessagesStreamWithChatId(chatId);
          ChatService.activeChatId = chatId;
        });

        AnalyticsService.logPushNavigation('chat_validated_success', extra: {'chat_id': chatId});
        AnalyticsService.logPushNavigation('chat_opened', extra: {
          'chat_id': chatId,
          'mode': 'validated',
          'is_from_push': widget.chatId != null ? 'true' : 'false'
        });

        // ✅ markAsRead — только после подтверждения участия
        if (UserService.currentUid != null) {
          ChatService.markAsRead(_otherUserId);
        }
      }
    } catch (e, stack) {
      debugPrint('[CHAT_SECURITY] Error validating chatId: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        AnalyticsService.logPermissionDenied(
          chatId: chatId,
          operation: 'read',
          type: 'chat_doc',
        );
        // permission-denied при чтении чата = uid скорее всего не в participants.
        if (mounted) setState(() => _isWrongAccount = true);
      }
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'Error validating chatId',
        information: [
          'chatId: $chatId',
          'otherId: $_otherUserId',
          'isFromPush: ${widget.chatId != null ? "true" : "false"}',
        ],
      );
      if (mounted) {
        setState(() {
          _isChatValidating = false;
          _isAccessDenied = true;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (_isRecording) {
        _handleRecordingCancelled();
      }
      _updateMyTyping(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordTimer?.cancel();
    _typingTimer?.cancel();
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
    ChatService.updateTypingStatus(_otherUserId, false);
    final expectedChatId = widget.chatId ?? ChatService.getChatId(_otherUserId);
    if (ChatService.activeChatId == expectedChatId) {
      ChatService.activeChatId = null;
    }
    super.dispose();
  }

  void _updateMyTyping(bool isTyping) {
    _typingTimer?.cancel();
    if (isTyping) {
      final now = DateTime.now();
      if (!_isTyping || _lastTypingSentTime == null || now.difference(_lastTypingSentTime!).inSeconds >= 5) {
        ChatService.updateTypingStatus(_otherUserId, true);
        _lastTypingSentTime = now;
      }
      if (!_isTyping) {
        setState(() => _isTyping = true);
      }
      _typingTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _isTyping) {
          ChatService.updateTypingStatus(_otherUserId, false);
          setState(() {
            _isTyping = false;
            _lastTypingSentTime = null;
          });
        }
      });
    } else {
      if (_isTyping) {
        ChatService.updateTypingStatus(_otherUserId, false);
        setState(() {
          _isTyping = false;
          _lastTypingSentTime = null;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (Provider.of<AppConfigProvider>(context, listen: false).isUserBlocked(_otherUserId)) return;
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    
    final backupText = _msgController.text;
    _typingTimer?.cancel();
    _msgController.clear();
    ChatService.updateTypingStatus(_otherUserId, false);
    setState(() {
      _isTyping = false;
      _lastTypingSentTime = null;
    });
    _scrollToBottom();
    
    try {
      final msgId = await ChatService.sendMessage(ad: widget.ad, text: text, senderName: _currentUserName, recipientId: _otherUserId);
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
    _isCancelled = false;
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TranslationService.t('mic_permission_denied', lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
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
      return;
    }
    HapticFeedback.mediumImpact();
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
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
        if (mounted) {
          setState(() {
            _recordSeconds++;
            if (_recordSeconds >= VoiceLimitsConfig.maxDurationSeconds) {
              _recordTimer?.cancel();
              _stopRecording();
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error starting voice recorder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось запустить диктофон: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleRecordingCancelled() async {
    if (!_isRecording) return;
    _isCancelled = true;
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    await _cancelRecording(path);
  }

  Future<void> _cancelRecording(String? path) async {
    _recordTimer?.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordSeconds = 0;
      });
    }
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          debugPrint('Temporary voice recording file deleted: $path');
        }
      } catch (e) {
        debugPrint('Error deleting temporary voice recording: $e');
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
    if (!_isRecording) return;
    
    String? path;
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      path = await _recorder.stop();
    } catch (e) {
      debugPrint('Error stopping voice recorder: $e');
    }
    if (mounted) setState(() => _isRecording = false);
    
    if (_isCancelled) {
      await _cancelRecording(path);
      return;
    }
    
    if (path == null || _recordSeconds < 1) {
      await _cancelRecording(path);
      if (mounted && _recordSeconds < 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    TranslationService.t('record_too_short', lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    if (path != null) {
      _updateMyTyping(false);
      final msgId = await ChatService.sendMessage(ad: widget.ad, text: 'Голосовое сообщение', type: 'audio', duration: _recordSeconds, senderName: _currentUserName, recipientId: _otherUserId);
      if (msgId != null) {
        _playSentSound();
        _localAudioPaths[msgId] = path;
        final chatId = ChatService.getChatId(_otherUserId);
        _uploadVoiceMessageWithRetry(msgId, path, chatId);
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

  void _uploadVoiceMessageWithRetry(String msgId, String path, String chatId, {int attempt = 1}) {
    final task = FileService.uploadFileWithTask(
      File(path),
      'voice_messages/$chatId',
      customFileName: '$msgId.m4a',
    );
    if (mounted) {
      setState(() {
        _activeUploads[msgId] = task;
      });
    }

    task.then((snapshot) async {
      try {
        final url = await snapshot.ref.getDownloadURL();
        await ChatService.updateMessage(_otherUserId, msgId, {'mediaUrl': url});
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
        }
      } catch (e, stack) {
        debugPrint('[CHAT_SCREEN] Error updating message reference after successful upload: $e');
        AnalyticsService.logStoragePermissionError(e, stack, 'voice_messages/$chatId');
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Файл загружен, но не удалось прикрепить сообщение.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orangeAccent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }).catchError((e, stack) async {
      final code = e is FirebaseException ? e.code : '';
      final isPermissionError = code == 'permission-denied' || code == 'unauthorized';
      
      const delays = [500, 1500, 3000];
      
      if (isPermissionError && attempt <= delays.length) {
        final delayMs = delays[attempt - 1];
        debugPrint('[CHAT_SCREEN] Upload permission denied (replication lag). Retrying attempt $attempt in ${delayMs}ms. Error: $e');
        await Future.delayed(Duration(milliseconds: delayMs));
        if (mounted) {
          _uploadVoiceMessageWithRetry(msgId, path, chatId, attempt: attempt + 1);
        }
      } else {
        final String cid = ChatService.getChatId(_otherUserId);
        AnalyticsService.logStoragePermissionError(e, stack, 'voice_messages/$cid');
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
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
      }
    });
  }

  void _uploadImageWithRetry(String msgId, String path, String chatId, {int attempt = 1}) {
    final task = FileService.uploadFileWithTask(
      File(path),
      'chat_media/$chatId',
      customFileName: '$msgId.jpg',
    );
    if (mounted) {
      setState(() {
        _activeUploads[msgId] = task;
      });
    }

    task.then((snapshot) async {
      try {
        final url = await snapshot.ref.getDownloadURL();
        await ChatService.updateMessage(_otherUserId, msgId, {'mediaUrl': url});
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
        }
      } catch (e, stack) {
        debugPrint('[CHAT_SCREEN] Error updating message reference after successful photo upload: $e');
        AnalyticsService.logStoragePermissionError(e, stack, 'chat_media/$chatId');
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Файл загружен, но не удалось обновить ссылку на фото.'),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    }).catchError((e, stack) async {
      final code = e is FirebaseException ? e.code : '';
      final isPermissionError = code == 'permission-denied' || code == 'unauthorized';
      
      const delays = [500, 1500, 3000];
      
      if (isPermissionError && attempt <= delays.length) {
        final delayMs = delays[attempt - 1];
        debugPrint('[CHAT_SCREEN] Photo upload permission denied. Retrying attempt $attempt in ${delayMs}ms. Error: $e');
        await Future.delayed(Duration(milliseconds: delayMs));
        if (mounted) {
          _uploadImageWithRetry(msgId, path, chatId, attempt: attempt + 1);
        }
      } else {
        final String cid = ChatService.getChatId(_otherUserId);
        AnalyticsService.logStoragePermissionError(e, stack, 'chat_media/$cid');
        if (mounted) {
          setState(() {
            _activeUploads.remove(msgId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось отправить фото. Попробуйте еще раз.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
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
            category: AVAudioSessionCategory.playback,
            options: {
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
    if (Provider.of<AppConfigProvider>(context, listen: false).isUserBlocked(_otherUserId)) return;
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
        final chatId = ChatService.getChatId(_otherUserId);
        await ChatService.createChatIfNeeded(widget.ad, recipientId: _otherUserId);
        
        _updateMyTyping(false);
        final msgId = await ChatService.sendMessage(
          ad: widget.ad,
          text: 'Фото',
          type: 'image',
          mediaUrl: '', // empty means uploading!
          senderName: _currentUserName,
          recipientId: _otherUserId,
        );

        if (msgId != null) {
          if (mounted) {
            setState(() {
              _localImagePaths[msgId] = file!.path;
            });
          }
          _playSentSound();
          _scrollToBottom();
          _uploadImageWithRetry(msgId, file!.path, chatId);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(TranslationService.t('errSendPhoto', lang)), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
            );
          }
        }
      } catch (e, stack) {
        final String cid = ChatService.getChatId(_otherUserId);
        AnalyticsService.logStoragePermissionError(e, stack, 'chat_media/$cid');
        FirebaseCrashlytics.instance.recordError(
          e,
          stack,
          reason: 'Error sending photo in chat',
          information: ['chatId: $cid'],
        );
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

    if (_isChatValidating) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F9),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4A80F0)),
        ),
      );
    }

    if (_isAccessDenied) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(TranslationService.t('chat', lang)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isWrongAccount
                      ? Icons.manage_accounts_outlined
                      : Icons.lock_outline_rounded,
                  size: 64,
                  color: _isWrongAccount ? const Color(0xFF4A80F0) : Colors.redAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _isWrongAccount ? 'Другой аккаунт' : 'Чат недоступен',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isWrongAccount ? const Color(0xFF4A80F0) : Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isWrongAccount
                      ? 'Похоже, вы входили другим способом. Привяжите аккаунты в настройках, чтобы получить доступ к своим чатам.'
                      : 'У вас нет доступа к этому чату или он был удален.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
                ),
                if (_isWrongAccount) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileSettingsScreen(
                          // Читаем актуальные данные из SharedPreferences (уже инициализирован в main).
                          currentName: StorageService.getString('user_name') ?? '',
                          profileImagePath: StorageService.getString('user_image'),
                          isBioEnabled: StorageService.getBool('is_bio_enabled'),
                          accType: StorageService.getString('account_type') ?? 'user',
                          lang: lang,
                          // themes: const {} безопасно — ProfileSettingsScreen использует
                          // fallback-цвета через ??, краша нет (строки 76–80 profile_settings_screen.dart).
                          currentTheme: 'light',
                          themes: const {},
                          // onThemeChanged: no-op безопасен — тема применяется через
                          // AppConfigProvider (строка 204 profile_settings_screen.dart),
                          // колбэк нужен только для обновления локального state ProfileScreen.
                          onThemeChanged: (_) {},
                          // onSave: no-op безопасен — Firestore/Auth реально обновляются
                          // внутри _saveProfile() (строки 208–229 profile_settings_screen.dart).
                          // ProfileScreen подтянет новое имя из SharedPreferences при
                          // следующем открытии через widget.currentName.
                          onSave: (_, __, ___, ____, _____) {},
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Привязать аккаунты'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A80F0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final isBlocked = config.isUserBlocked(_otherUserId);
    const chatBg = Color(0xFFF1F5F9); 
    const myBubbleColor = Color(0xFF3B82F6);
    const otherBubbleColor = Colors.white;

    final secondsRemaining = VoiceLimitsConfig.maxDurationSeconds - _recordSeconds;
    final isWarning = secondsRemaining <= VoiceLimitsConfig.warningThresholdSeconds;
    final String cancelText = isWarning
        ? TranslationService.t('voice_limit_warning', lang).replaceAll('{sec}', '$secondsRemaining')
        : TranslationService.t('record_cancel_hint', lang);

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
                recordCancelText: cancelText,
                onToggleEmoji: () => setState(() => _showEmoji = !_showEmoji),
                onTextChanged: (v) => _updateMyTyping(v.isNotEmpty),
                onAttach: () => _pickMedia(ImageSource.gallery),
                onSend: _sendMessage,
                onLongPressStart: _startRecording,
                onLongPressEnd: _stopRecording,
                onRecordingCancelled: _handleRecordingCancelled,
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
                  onBack: () => Navigator.of(context).maybePop(),
                  onProfileTap: _navigateToSellerProfile,
                  firestore: widget.firestore,
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
    return const ChatEmptyState();
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
        if (item is DateTime) return ChatDateHeader(date: item);
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
          localImagePath: _localImagePaths[msg.id],
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

  void _showContextMenu(MessageModel msg) {
    ChatContextMenu.show(
      context: context,
      msg: msg,
      otherUserId: _otherUserId,
    );
  }

  void _showFullScreenImage(String url) {
    if (url.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SecureImageViewerScreen(
          imageUrl: url,
          heroTag: 'chat_msg_img_$url',
        ),
      ),
    );
  }

  void _navigateToSellerProfile() async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)));
    try {
      final adsStream = AdService.getAdsByUserStream(_otherUserId);
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
