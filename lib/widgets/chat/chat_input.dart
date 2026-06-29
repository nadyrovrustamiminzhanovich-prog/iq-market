import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
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
    required this.onEmojiSelected,
    required this.emojis,
    this.hintText = 'Сообщение',
    this.recordCancelText = 'Проведите для отмены',
  });

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
                    child: isRecording 
                      ? _RecordingBar(seconds: recordSeconds, cancelText: recordCancelText)
                      : Row(
                          children: [
                            const SizedBox(width: 4),
                            // Plus button on the left of input (as in screenshot)
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF3B82F6), size: 26),
                              onPressed: onAttach,
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                focusNode: focusNode,
                                maxLines: 5,
                                minLines: 1,
                                onChanged: onTextChanged,
                                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16),
                                decoration: InputDecoration(
                                  hintText: hintText,
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                showEmoji ? Icons.keyboard_rounded : Icons.sentiment_satisfied_alt_rounded,
                                color: const Color(0xFF64748B),
                                size: 24,
                              ),
                              onPressed: onToggleEmoji, 
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: isTyping ? onSend : null,
                onLongPressStart: (_) => onLongPressStart(),
                onLongPressEnd: (_) => onLongPressEnd(),
                onLongPressCancel: () => onLongPressEnd(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.redAccent : const Color(0xFF3B82F6), 
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isRecording ? Colors.redAccent : const Color(0xFF3B82F6)).withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Icon(
                    isTyping ? Icons.send_rounded : (isRecording ? Icons.stop_rounded : Icons.mic_rounded), 
                    color: Colors.white, 
                    size: 22
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showEmoji) _EmojiPicker(onEmojiSelected: onEmojiSelected, emojis: emojis),
      ],
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final int seconds;
  final String cancelText;
  const _RecordingBar({required this.seconds, this.cancelText = 'Проведите для отмены'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Text(_formatTime(seconds), style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(cancelText, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: Color(0xFF94A3B8)),
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
