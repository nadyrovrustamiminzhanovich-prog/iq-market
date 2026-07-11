import 'package:flutter/material.dart';

class ChatInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isTyping;
  final bool isRecording;
  final int recordSeconds;
  final bool showEmoji;
  final VoidCallback onToggleEmoji;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final VoidCallback onRecordingCancelled;
  final Function(String) onEmojiSelected;
  final List<String> emojis;
  final String hintText;
  final String recordCancelText;

  const ChatInput({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isTyping,
    required this.isRecording,
    required this.recordSeconds,
    required this.showEmoji,
    required this.onToggleEmoji,
    required this.onTextChanged,
    required this.onAttach,
    required this.onSend,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.onRecordingCancelled,
    required this.onEmojiSelected,
    required this.emojis,
    this.hintText = 'Сообщение',
    this.recordCancelText = 'Проведите для отмены',
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  double _dragX = 0.0;
  bool _hasTriggeredCancel = false;
  static const double _cancelThreshold = -80.0;

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isRecording && oldWidget.isRecording) {
      _dragX = 0.0;
      _hasTriggeredCancel = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          color: const Color(0xFFF1F5F9), // Light background to blend with chat background
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: widget.isRecording 
                      ? _RecordingBar(
                          seconds: widget.recordSeconds, 
                          cancelText: widget.recordCancelText,
                          dragProgress: (_dragX / _cancelThreshold).clamp(0.0, 1.0),
                        )
                      : Row(
                          children: [
                            const SizedBox(width: 4),
                            // Plus button on the left of input (as in screenshot)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 26),
                              onPressed: widget.onAttach,
                            ),
                            Expanded(
                              child: TextField(
                                controller: widget.controller,
                                focusNode: widget.focusNode,
                                maxLines: 5,
                                minLines: 1,
                                onChanged: widget.onTextChanged,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: widget.hintText,
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                widget.showEmoji ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                                color: const Color(0xFF64748B),
                                size: 24,
                              ),
                              onPressed: widget.onToggleEmoji, 
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: widget.isTyping ? widget.onSend : null,
                onLongPressStart: (_) {
                  if (!widget.isTyping) {
                    setState(() {
                      _dragX = 0.0;
                      _hasTriggeredCancel = false;
                    });
                    widget.onLongPressStart();
                  }
                },
                onLongPressMoveUpdate: (details) {
                  if (widget.isRecording && !widget.isTyping) {
                    final dx = details.localOffsetFromOrigin.dx;
                    if (dx < 0) {
                      setState(() {
                        _dragX = dx.clamp(_cancelThreshold - 20.0, 0.0);
                      });
                      if (_dragX <= _cancelThreshold && !_hasTriggeredCancel) {
                        _hasTriggeredCancel = true;
                        widget.onRecordingCancelled();
                      }
                    } else {
                      setState(() {
                        _dragX = 0.0;
                      });
                    }
                  }
                },
                onLongPressEnd: (_) {
                  setState(() {
                    _dragX = 0.0;
                    _hasTriggeredCancel = false;
                  });
                  widget.onLongPressEnd();
                },
                onLongPressCancel: () {
                  setState(() {
                    _dragX = 0.0;
                    _hasTriggeredCancel = false;
                  });
                  widget.onLongPressEnd();
                },
                child: Transform.translate(
                  offset: Offset(_dragX, 0.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: widget.isRecording 
                        ? (_dragX <= _cancelThreshold ? Colors.black54 : Colors.redAccent) 
                        : const Color(0xFF3B82F6), 
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isRecording 
                            ? (_dragX <= _cancelThreshold ? Colors.black54 : Colors.redAccent) 
                            : const Color(0xFF3B82F6)).withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: Icon(
                      widget.isTyping 
                        ? Icons.send_rounded 
                        : (widget.isRecording 
                            ? (_dragX <= _cancelThreshold ? Icons.delete_outline_rounded : Icons.stop_rounded) 
                            : Icons.mic_rounded), 
                      color: Colors.white, 
                      size: 22
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.showEmoji) _EmojiPicker(onEmojiSelected: widget.onEmojiSelected, emojis: widget.emojis),
      ],
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final int seconds;
  final String cancelText;
  final double dragProgress;
  const _RecordingBar({
    required this.seconds, 
    this.cancelText = 'Проведите для отмены',
    this.dragProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - dragProgress).clamp(0.0, 1.0);
    final cancelColor = Color.lerp(
      const Color(0xFF64748B),
      Colors.redAccent,
      dragProgress,
    )!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Text(_formatTime(seconds), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Opacity(
              opacity: opacity,
              child: Text(
                cancelText, 
                style: TextStyle(
                  color: cancelColor, 
                  fontSize: 12,
                  fontWeight: dragProgress > 0.5 ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: opacity,
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: cancelColor),
          ),
        ],
      ),
    );
  }

  String _formatTime(int s) {
    final mins = s ~/ 60;
    final secs = s % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}

class _EmojiPicker extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final List<String> emojis;

  const _EmojiPicker({required this.onEmojiSelected, required this.emojis});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      color: const Color(0xFFF1F5F9), // Light background for emoji picker
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8, mainAxisSpacing: 8, crossAxisSpacing: 8),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () => onEmojiSelected(emojis[index]),
            child: Center(child: Text(emojis[index], style: const TextStyle(fontSize: 26))),
          );
        },
      ),
    );
  }
}
