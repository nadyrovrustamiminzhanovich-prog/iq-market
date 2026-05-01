import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/screens/seller_profile_screen.dart';


class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  final String? initialOffer;
  const ChatScreen({super.key, required this.ad, this.initialOffer});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  bool _isRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentPlayingId;
  late AnimationController _waveCtrl;
  double _recordDragX = 0;
  bool _isCancelled = false;
  final Set<String> _selectedMessages = {};

  final List<Map<String, dynamic>> _messages = [
    {'text': 'Здравствуйте. Актуально?', 'isMe': true, 'time': '14:23', 'status': 2, 'type': 'text', 'id': 'm0'},
  ];

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    final isTaxiAi = widget.ad['seller'] == 'IQ GPT AI';
    _messages.add({
      'text': isTaxiAi
          ? 'Привет! Я — IQ Помощник по межгороду 🤖 Чем могу помочь?'
          : 'Добрый день! Да, конечно. Какие вопросы у вас есть?',
      'isMe': false,
      'time': DateFormat('HH:mm').format(DateTime.now()),
      'status': 2,
      'type': 'text',
      'id': 'm1',
    });
    if (widget.initialOffer != null) {
      _messages.add({
        'text': 'Мое предложение: ${widget.initialOffer} ₸',
        'isMe': true,
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'status': 0,
        'type': 'offer',
        'id': 'm2',
      });
    }
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() => _currentPlayingId = null);
      }
    });
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _recordTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    setState(() {
      _messages.add({
        'text': text,
        'isMe': true,
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'status': 0,
        'type': 'text',
        'id': 'm${_messages.length}',
      });
      _msgController.clear();
      _isTyping = false;
    });
    _scrollToBottom();
    if (widget.ad['seller'] == 'IQ GPT AI') _handleTaxiAiResponse(text);
  }

  void _handleTaxiAiResponse(String userMsg) {
    String response;
    final q = userMsg.toLowerCase();
    if (q.contains('цена') || q.contains('стоимост')) {
      response = 'В IQ Market Taxi вы можете предлагать свою цену! Нажмите «Торговаться» в карточке водителя.';
    } else if (q.contains('время') || q.contains('выезд')) {
      response = 'Большинство машин выезжают утром (08:00–10:00) или после обеда (14:00–17:00).';
    } else if (q.contains('багаж') || q.contains('сумк')) {
      response = 'Одно место = одна стандартная сумка. Если багажа больше — договоритесь с водителем.';
    } else if (q.contains('привет') || q.contains('салам')) {
      response = 'Привет! Спросите меня о ценах, багаже или маршрутах.';
    } else {
      response = 'Я специализируюсь на вопросах межгородских поездок. Спросите о маршрутах Алматы–Жаркент, ценах или правилах.';
    }
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'text': response,
          'isMe': false,
          'time': DateFormat('HH:mm').format(DateTime.now()),
          'status': 2,
          'type': 'text',
          'id': 'm${_messages.length}',
        });
      });
      _scrollToBottom();
    });
  }

  // ── Voice recording ──────────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    setState(() { 
      _isRecording = true; 
      _recordSeconds = 0; 
      _recordDragX = 0;
      _isCancelled = false;
    });
    HapticFeedback.mediumImpact();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _recordSeconds++);
    });
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() { _isRecording = false; _recordSeconds = 0; });
    if (cancel || path == null) return;
    HapticFeedback.mediumImpact();
    final duration = _recordSeconds;
    setState(() {
      _messages.add({
        'type': 'voice',
        'isMe': true,
        'path': path,
        'duration': duration,
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'status': 0,
        'id': 'v${_messages.length}',
      });
    });
    _scrollToBottom();
  }

  Future<void> _togglePlayVoice(String id, String path) async {
    if (_currentPlayingId == id) {
      await _audioPlayer.pause();
      setState(() => _currentPlayingId = null);
    } else {
      setState(() => _currentPlayingId = id);
      await _audioPlayer.play(DeviceFileSource(path));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Очистить чат?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text('Все сообщения будут удалены. Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () { setState(() { _messages.clear(); _selectedMessages.clear(); }); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Очистить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _deleteSelectedMessages() {
    setState(() {
      _messages.removeWhere((msg) => _selectedMessages.contains(msg['id']));
      _selectedMessages.clear();
    });
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF8FAFC);
    const accent = Color(0xFF4A80F0);
    return Scaffold(
      backgroundColor: bg,
      body: Stack(children: [
        Positioned(top: -100, right: -100, child: _bgCircle(200, accent.withValues(alpha: 0.08))),
        Positioned(bottom: 100, left: -50, child: _bgCircle(150, Colors.purple.withValues(alpha: 0.05))),
        Column(children: [
          _buildHeader(accent),
          _buildAdCard(),
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text('Нет сообщений', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i], accent),
                  ),
          ),
          if (_isRecording) _buildRecordingBar(accent),
          _buildInput(accent),
        ]),
      ]),
    );
  }

  Widget _bgCircle(double s, Color c) => Container(
    width: s, height: s,
    decoration: BoxDecoration(shape: BoxShape.circle, color: c,
      boxShadow: [BoxShadow(color: c, blurRadius: 80, spreadRadius: 40)]),
  );

  Widget _buildHeader(Color accent) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 12),
          decoration: BoxDecoration(
            color: _selectedMessages.isNotEmpty ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 2))
            ],
            border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
          ),
          child: Row(children: [
            IconButton(
              icon: Icon(_selectedMessages.isNotEmpty ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded, 
                color: _selectedMessages.isNotEmpty ? Colors.white : const Color(0xFF1E293B), size: 20),
              onPressed: () {
                if (_selectedMessages.isNotEmpty) {
                  setState(() => _selectedMessages.clear());
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            if (_selectedMessages.isNotEmpty) ...[
              Expanded(
                child: Text('${_selectedMessages.length} выделено', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                onPressed: _deleteSelectedMessages,
              ),
              IconButton(
                icon: const Icon(Icons.content_copy_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  // Здесь логика копирования
                  setState(() => _selectedMessages.clear());
                },
              ),
            ] else ...[
              Stack(children: [
                CircleAvatar(radius: 20, backgroundColor: accent.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Colors.white, size: 20)),
                Positioned(right: 0, bottom: 0, child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0F172A), width: 2)),
                )),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SellerProfileScreen(
                      seller: widget.ad,
                      lang: 'Русский', // Default to Russian if lang not in widget.ad
                      sellerAds: [widget.ad], // Minimal list for now
                    )));
                  },
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.ad['seller'] ?? 'Собеседник',
                      style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold, fontSize: 16)),
                    const Text('онлайн', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.call_rounded, color: Color(0xFF10B981), size: 24),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  String phone = widget.ad['phone'] ?? '+7 708 900 70 30';
                  phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
                  final url = Uri.parse('tel:$phone');
                  if (await canLaunchUrl(url)) launchUrl(url);
                },
              ),
            ],
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF1E293B)),
              color: Colors.white,
              onSelected: (value) {
                if (value == 'clear') _clearChat();
                if (value == 'block') {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      title: const Text('Заблокировать?', style: TextStyle(fontWeight: FontWeight.w900)),
                      content: const Text('Вы больше не будете получать сообщения от этого пользователя.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Пользователь заблокирован')));
                          },
                          child: const Text('Заблокировать', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                        ),
                      ],
                    ),
                  );
                }
                if (value == 'report') {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Жалоба отправлена')));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'clear', child: Row(children: [Icon(Icons.delete_sweep_rounded, size: 20), SizedBox(width: 10), Text('Очистить чат')])),
                const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag_rounded, size: 20, color: Colors.orange), SizedBox(width: 10), Text('Пожаловаться')])),
                const PopupMenuItem(value: 'block', child: Row(children: [Icon(Icons.block_flipped, color: Colors.red, size: 20), SizedBox(width: 10), Text('Заблокировать', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))])),
              ],
            ),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }

  Widget _buildAdCard() {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(
          ad: widget.ad,
          onReport: (_) {},
          lang: 'Русский',
        )));
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF4A80F0).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1)),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFF4A80F0), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.ad['title'] ?? 'Объявление',
              style: const TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w800, fontSize: 14),
              overflow: TextOverflow.ellipsis),
            Text('${widget.ad['price'] ?? ''} ₸',
              style: const TextStyle(color: Color(0xFF4A80F0), fontSize: 12, fontWeight: FontWeight.w700)),
          ])),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF4A80F0), size: 20),
        ]),
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, Color accent) {
    final isMe = msg['isMe'] as bool;
    final type = msg['type'] as String;
    final id = msg['id'] as String;
    final isSelected = _selectedMessages.contains(id);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (type == 'voice') return _buildVoiceBubble(msg, accent, isMe, isSelected);
    if (type == 'image') return _buildImageBubble(msg, accent, isMe, isSelected);

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMessages.add(id));
      },
      onTap: () {
        if (_selectedMessages.isNotEmpty) {
          setState(() {
            if (isSelected) _selectedMessages.remove(id);
            else _selectedMessages.add(id);
          });
        }
      },
      child: Container(
        color: isSelected ? accent.withValues(alpha: 0.2) : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              gradient: isMe ? const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF6366F1)]) : null,
              color: isMe ? null : theme.colorScheme.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isMe ? 20 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 20),
              ),
              boxShadow: [
                BoxShadow(color: (isMe ? const Color(0xFF4A80F0) : Colors.black).withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4))
              ],
              border: isMe ? null : Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
            ),
            child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
              if (type == 'offer')
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_offer_rounded, color: const Color(0xFFF59E0B), size: 14),
                  const SizedBox(width: 6),
                  Flexible(child: Text(msg['text'], style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                ])
              else
              Text(msg['text'], style: GoogleFonts.inter(color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)), fontSize: 15, height: 1.4)),
              const SizedBox(height: 4),
              Text(msg['time'], style: TextStyle(color: isMe ? Colors.white.withValues(alpha: 0.6) : Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildImageBubble(Map<String, dynamic> msg, Color accent, bool isMe, bool isSelected) {
    final id = msg['id'] as String;
    final path = msg['path'] as String;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMessages.add(id));
      },
      onTap: () {
        if (_selectedMessages.isNotEmpty) {
          setState(() {
            if (isSelected) _selectedMessages.remove(id);
            else _selectedMessages.add(id);
          });
        } else {
          // Open full screen image
          Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
            body: Center(child: InteractiveViewer(child: Image.file(File(path)))),
          )));
        }
      },
      child: Container(
        color: isSelected ? accent.withValues(alpha: 0.2) : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  Image.file(File(path), width: 220, height: 280, fit: BoxFit.cover),
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(8)),
                      child: Text(msg['time'], style: const TextStyle(color: Colors.white, fontSize: 10)),
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

  Widget _buildVoiceBubble(Map<String, dynamic> msg, Color accent, bool isMe, bool isSelected) {
    final id = msg['id'] as String;
    final path = msg['path'] as String;
    final dur = msg['duration'] as int? ?? 0;
    final isPlaying = _currentPlayingId == id;

    return GestureDetector(
      onLongPress: () {
        HapticFeedback.lightImpact();
        setState(() => _selectedMessages.add(id));
      },
      onTap: () {
        if (_selectedMessages.isNotEmpty) {
          setState(() {
            if (isSelected) _selectedMessages.remove(id);
            else _selectedMessages.add(id);
          });
        }
      },
      child: Container(
        color: isSelected ? accent.withValues(alpha: 0.2) : Colors.transparent,
        child: Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: isMe ? LinearGradient(colors: [accent, const Color(0xFF6366F1)]) : null,
              color: isMe ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: () => _togglePlayVoice(id, path),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildWaveform(isPlaying, accent),
                const SizedBox(height: 4),
                Text('${dur ~/ 60}:${(dur % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(width: 8),
              Text(msg['time'], style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildWaveform(bool isPlaying, Color accent) {
    return AnimatedBuilder(
      animation: _waveCtrl,
      builder: (_, __) {
        final bars = [0.3, 0.7, 0.5, 1.0, 0.6, 0.8, 0.4, 0.9, 0.5, 0.7];
        return Row(
          children: bars.asMap().entries.map((e) {
            final h = isPlaying
                ? 8 + e.value * 16 * (0.5 + 0.5 * _waveCtrl.value * (e.key % 2 == 0 ? 1 : -1)).abs()
                : 8 + e.value * 10;
            return Container(
              width: 3, height: h,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: isPlaying ? accent : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRecordingBar(Color accent) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        AnimatedBuilder(
          animation: _waveCtrl,
          builder: (_, __) => Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.5 + 0.5 * _waveCtrl.value),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _isCancelled ? 'Удалено' : '● REC  ${_recordSeconds ~/ 60}:${(_recordSeconds % 60).toString().padLeft(2, '0')}',
          style: TextStyle(color: _isCancelled ? Colors.grey : Colors.red, fontWeight: FontWeight.w900, fontSize: 14),
        ),
        const Spacer(),
        if (!_isCancelled)
          AnimatedOpacity(
            opacity: (1.0 - (_recordDragX.abs() / 100)).clamp(0.0, 1.0),
            duration: Duration.zero,
            child: const Row(
              children: [
                Icon(Icons.arrow_back_ios_rounded, color: Colors.grey, size: 12),
                Text(' Смахните для отмены', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _buildInput(Color accent) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
        border: Border(top: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.05))),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF4A80F0), size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
            ),
            child: TextField(
              controller: _msgController,
              style: TextStyle(color: theme.colorScheme.onSurface),
              onChanged: (v) => setState(() => _isTyping = v.trim().isNotEmpty),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Сообщение...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send OR Voice button
        GestureDetector(
          onTap: _isTyping 
            ? _sendMessage 
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Удерживайте кнопку для записи голосового сообщения'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
          onLongPressStart: _isTyping ? null : (_) => _startRecording(),
          onLongPressMoveUpdate: _isTyping ? null : (details) {
            setState(() {
              _recordDragX = details.localOffsetFromOrigin.dx;
              if (_recordDragX < -80 && !_isCancelled) {
                _isCancelled = true;
                HapticFeedback.heavyImpact();
              }
            });
          },
          onLongPressEnd: _isTyping ? null : (_) => _stopRecording(cancel: _isCancelled),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: (_isTyping || _isRecording)
                  ? LinearGradient(colors: [
                      _isRecording ? Colors.red : accent,
                      _isRecording ? Colors.redAccent : const Color(0xFF6366F1),
                    ])
                  : null,
              color: (_isTyping || _isRecording) ? null : theme.colorScheme.onSurface.withValues(alpha: 0.06),
              shape: BoxShape.circle,
              boxShadow: (_isTyping || _isRecording)
                  ? [BoxShadow(color: (_isRecording ? Colors.red : accent).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]
                  : [],
            ),
            child: Icon(
              _isTyping
                  ? Icons.send_rounded
                  : (_isRecording ? Icons.stop_rounded : Icons.mic_rounded),
              color: (_isTyping || _isRecording) ? Colors.white : accent,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.camera_alt, color: Colors.white),
          title: const Text('Камера', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(context);
            final img = await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
            if (img != null) _addImageMessage(img.path);
          },
        ),
        ListTile(
          leading: const Icon(Icons.photo_library, color: Colors.white),
          title: const Text('Галерея', style: TextStyle(color: Colors.white)),
          onTap: () async {
            Navigator.pop(context);
            final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
            if (img != null) _addImageMessage(img.path);
          },
        ),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _addImageMessage(String path) {
    setState(() {
      _messages.add({
        'type': 'image',
        'isMe': true,
        'path': path,
        'time': DateFormat('HH:mm').format(DateTime.now()),
        'status': 0,
        'id': 'i${_messages.length}',
        'text': '',
      });
    });
    _scrollToBottom();
  }
}
