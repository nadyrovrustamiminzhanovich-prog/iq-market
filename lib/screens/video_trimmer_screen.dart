import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_trimmer/video_trimmer.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoTrimmerScreen extends StatefulWidget {
  final File videoFile;
  final Function(String) onSave;
  
  const VideoTrimmerScreen({
    super.key, 
    required this.videoFile, 
    required this.onSave
  });

  @override
  State<VideoTrimmerScreen> createState() => _VideoTrimmerScreenState();
}

class _VideoTrimmerScreenState extends State<VideoTrimmerScreen> {
  final Trimmer _trimmer = Trimmer();
  double _startValue = 0.0, _endValue = 0.0;
  bool _isPlaying = false;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  @override
  void dispose() {
    _trimmer.dispose();
    super.dispose();
  }

  Future<void> _loadVideo() async {
    await _trimmer.loadVideo(videoFile: widget.videoFile);
    if (mounted) setState(() => _isLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Обрезать видео', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)), 
        backgroundColor: Colors.black, 
        foregroundColor: Colors.white, 
        elevation: 0,
        actions: [
          if (_isLoaded && !_isSaving)
            TextButton(
              onPressed: _saveVideo,
              child: Text('ГОТОВО', style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900)),
            )
          else if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))),
        ]
      ),
      body: !_isLoaded 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)))
        : SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: Center(
                      child: VideoViewer(trimmer: _trimmer),
                    ),
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  color: const Color(0xFF1E293B),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ТАЙМЛАЙН (Ползунок)
                      Container(
                        height: 80,
                        width: double.infinity,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: TrimViewer(
                          trimmer: _trimmer,
                          viewerHeight: 60.0,
                          viewerWidth: MediaQuery.of(context).size.width - 40,
                          maxVideoLength: const Duration(seconds: 20),
                          onChangeStart: (value) => _startValue = value,
                          onChangeEnd: (value) => _endValue = value,
                          onChangePlaybackState: (value) => setState(() => _isPlaying = value),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Перетащите края, чтобы выбрать до 20 сек',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () async {
                          bool playbackState = await _trimmer.videoPlaybackControl(
                            startValue: _startValue, 
                            endValue: _endValue
                          );
                          setState(() => _isPlaying = playbackState);
                        },
                        child: Container(
                          width: 60, height: 60,
                          decoration: const BoxDecoration(color: Color(0xFF4A80F0), shape: BoxShape.circle),
                          child: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _saveVideo() {
    setState(() => _isSaving = true);
    _trimmer.saveTrimmedVideo(
      startValue: _startValue, 
      endValue: _endValue,
      onSave: (path) {
        setState(() => _isSaving = false);
        if (path != null) widget.onSave(path);
        Navigator.pop(context);
      }
    );
  }
}
