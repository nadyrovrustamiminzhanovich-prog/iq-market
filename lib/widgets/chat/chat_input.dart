import 'package:flutter/material.dart';

class ChatInput extends StatelessWidget {
  final TextEditingController controller;
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

  const ChatInput({
    super.key,
    required this.controller,
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
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black.withValues(alpha: 0.4)],
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C242F),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isRecording 
                      ? _RecordingBar(seconds: recordSeconds)
                      : Row(
                          children: [
                            IconButton(
                              icon: Icon(showEmoji ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined, color: showEmoji ? const Color(0xFF4A80F0) : Colors.white60, size: 24),
                              onPressed: onToggleEmoji, 
                            ),
                            Expanded(
                              child: TextField(
                                controller: controller,
                                maxLines: 5,
                                minLines: 1,
                                onChanged: onTextChanged,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                decoration: const InputDecoration(
                                  hintText: 'Сообщение',
                                  hintStyle: TextStyle(color: Colors.white38),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.attach_file_rounded, color: Colors.white60, size: 24),
                              onPressed: onAttach,
                            ),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: isTyping ? onSend : null,
                onLongPressStart: (_) => onLongPressStart(),
                onLongPressEnd: (_) => onLongPressEnd(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 50, height: 50,
                  decoration: BoxDecoration(
                    color: isRecording ? Colors.redAccent : const Color(0xFF4A80F0), 
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: (isRecording ? Colors.redAccent : const Color(0xFF4A80F0)).withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2)],
                  ),
                  child: Icon(
                    isTyping ? Icons.send_rounded : (isRecording ? Icons.stop_rounded : Icons.mic_rounded), 
                    color: Colors.white, 
                    size: 24
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
  const _RecordingBar({required this.seconds});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.mic, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Text(_formatTime(seconds), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text('Проведите для отмены', style: TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_back_ios_new_rounded, size: 12, color: Colors.white38),
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
      color: const Color(0xFF17212B),
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
