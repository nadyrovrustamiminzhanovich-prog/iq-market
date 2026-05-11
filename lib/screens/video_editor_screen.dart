import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final String lang;

  const VideoEditorScreen({super.key, required this.videoFile, required this.lang});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0;
  double _endValue = 0.0;
  bool _isPlaying = false;
  bool _progressVisibility = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  void _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.videoFile);
  }

  void _saveVideo() async {
    setState(() => _progressVisibility = true);
    await _trimmer.saveTrimmedVideo(
      startValue: _startValue,
      endValue: _endValue,
      videoFolderName: "IQMarket_Videos",
      videoFileName: "trimmed_${DateTime.now().millisecondsSinceEpoch}",
      storageDir: StorageDir.temporaryDirectory,
      onSave: (String? outputPath) {
        setState(() => _progressVisibility = false);
        if (outputPath != null) {
          Navigator.pop(context, File(outputPath));
        } else {
          Navigator.pop(context, null);
        }
      },
    );
  }

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Обрезать видео ✂️', 'Қазақша': 'Видеон кесу ✂️', 'Уйғурчә': 'Видео кесиш ✂️' },
      'save': { 'Русский': 'Готово', 'Қазақша': 'Дайын', 'Уйғурчә': 'Тәййар' },
      'wait': { 'Русский': 'Оптимизируем видео... ✨', 'Қазақша': 'Видеоны өңдеуде... ✨', 'Уйғурчә': 'Видео ишлитиш... ✨' },
      'limit': { 'Русский': 'Лимит: 20 сек', 'Қазақша': 'Шектеу: 20 сек', 'Уйғурчә': 'Лимит: 20 сек' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E3A8A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom Glass AppBar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        _t('title'),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    TextButton(
                      onPressed: _progressVisibility ? null : _saveVideo,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: Text(
                        _t('save'),
                        style: const TextStyle(color: Color(0xFF00FF85), fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_progressVisibility) ...[
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        const LinearProgressIndicator(backgroundColor: Colors.white24, color: Color(0xFF00FF85), minHeight: 6),
                        const SizedBox(height: 12),
                        Text(_t('wait'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: VideoViewer(trimmer: _trimmer),
                    ),
                  ),
                ),
              ),

              // Controls Area
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: TrimViewer(
                        trimmer: _trimmer,
                        viewerHeight: 60.0,
                        viewerWidth: MediaQuery.of(context).size.width - 70,
                        maxVideoLength: const Duration(seconds: 20),
                        onChangeStart: (value) => _startValue = value,
                        onChangeEnd: (value) => _endValue = value,
                        onChangePlaybackState: (value) => setState(() => _isPlaying = value),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(_t('limit'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () async {
                        bool playbackState = await _trimmer.videoPlaybackControl(
                          startValue: _startValue,
                          endValue: _endValue,
                        );
                        setState(() => _isPlaying = playbackState);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 45.0,
                          color: const Color(0xFF1E3A8A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
