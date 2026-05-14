import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:google_fonts/google_fonts.dart';

class VideoEditorScreen extends StatefulWidget {
  final File videoFile;
  final String lang;

  const VideoEditorScreen({super.key, required this.videoFile, required this.lang});

  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  VideoPlayerController? _controller;
  bool _isLoaded = false;
  bool _isSaving = false;
  
  Duration _totalDuration = Duration.zero;
  double _startFraction = 0.0;
  double _endFraction = 1.0;
  
  static const int _maxDurationSec = 20;
  
  List<Uint8List?> _thumbnails = [];
  static const int _thumbnailCount = 10;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    _controller = VideoPlayerController.file(widget.videoFile);
    await _controller!.initialize();
    if (!mounted) {
      _controller?.dispose();
      return;
    }
    setState(() {
      _isLoaded = true;
      _totalDuration = _controller!.value.duration;
      if (_totalDuration.inSeconds > _maxDurationSec) {
        _endFraction = _maxDurationSec / _totalDuration.inSeconds;
      }
    });
    _controller!.addListener(_playbackListener);
    _generateThumbnails();
  }

  Future<void> _generateThumbnails() async {
    final List<Uint8List?> thumbs = [];
    for (int i = 0; i < _thumbnailCount; i++) {
      try {
        final position = (_totalDuration.inMilliseconds * i / _thumbnailCount).toInt();
        final file = await VideoCompress.getFileThumbnail(
          widget.videoFile.path,
          quality: 30,
          position: position,
        );
        if (mounted && file.existsSync()) {
          thumbs.add(file.readAsBytesSync());
        } else {
          thumbs.add(null);
        }
      } catch (e) {
        thumbs.add(null);
      }
    }
    if (mounted) setState(() => _thumbnails = thumbs);
  }

  void _playbackListener() {
    if (!mounted || _controller == null) return;
    final endMs = (_totalDuration.inMilliseconds * _endFraction).toInt();
    if (_controller!.value.position.inMilliseconds >= endMs) {
      _controller!.pause();
      _controller!.seekTo(Duration(milliseconds: (_totalDuration.inMilliseconds * _startFraction).toInt()));
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_playbackListener);
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Duration get _startTime => Duration(milliseconds: (_totalDuration.inMilliseconds * _startFraction).toInt());
  Duration get _endTime => Duration(milliseconds: (_totalDuration.inMilliseconds * _endFraction).toInt());
  Duration get _selectedDuration => _endTime - _startTime;

  void _togglePlayback() async {
    if (_controller == null) return;
    if (_controller!.value.isPlaying) {
      await _controller!.pause();
    } else {
      await _controller!.seekTo(_startTime);
      await _controller!.play();
    }
    setState(() {});
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _saveVideo() async {
    setState(() => _isSaving = true);
    await _controller?.pause();
    
    try {
      final info = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.Res640x480Quality,
        startTime: _startTime.inSeconds,
        duration: _selectedDuration.inSeconds,
        deleteOrigin: false,
      );
      if (info?.file != null && mounted) {
        Navigator.pop(context, info!.file!);
      } else if (mounted) {
        Navigator.pop(context, widget.videoFile);
      }
    } catch (e) {
      debugPrint('Video editor save error: $e');
      if (mounted) Navigator.pop(context, widget.videoFile);
    }
  }

  String _t(String key) {
    final translations = {
      'title': { 'Русский': 'Обрезать видео ✂️', 'Қазақша': 'Видеон кесу ✂️', 'Уйғурчә': 'Видео кесиш ✂️' },
      'save': { 'Русский': 'Готово', 'Қазақша': 'Дайын', 'Уйғурчә': 'Тәййар' },
      'wait': { 'Русский': 'Оптимизируем видео... ✨', 'Қазақша': 'Видеоны өңдеуде... ✨', 'Уйғурчә': 'Видео ишлитиш... ✨' },
    };
    return translations[key]?[widget.lang] ?? translations[key]?['Русский'] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) {
          _controller?.pause();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                // AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: _isSaving ? null : () {
                          _controller?.pause();
                          Navigator.pop(context);
                        },
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
                        onPressed: _isSaving || !_isLoaded ? null : _saveVideo,
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
                
                if (_isSaving) ...[
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

                // Video preview
                Expanded(
                  child: !_isLoaded
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : GestureDetector(
                        onTap: _togglePlayback,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(30),
                                  child: AspectRatio(
                                    aspectRatio: _controller!.value.aspectRatio,
                                    child: VideoPlayer(_controller!),
                                  ),
                                ),
                              ),
                              if (!_controller!.value.isPlaying)
                                Container(
                                  width: 70, height: 70,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, size: 45, color: Colors.white),
                                ),
                            ],
                          ),
                        ),
                      ),
                ),

                // Controls
                if (_isLoaded)
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
                        // Time info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_startTime), style: GoogleFonts.firaCode(color: const Color(0xFF00FF85), fontSize: 13, fontWeight: FontWeight.w700)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedDuration.inSeconds} сек / $_maxDurationSec сек',
                                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text(_formatDuration(_endTime), style: GoogleFonts.firaCode(color: const Color(0xFFFF6B6B), fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Thumbnail timeline
                        _buildThumbnailTimeline(),
                        
                        const SizedBox(height: 10),
                        Text(
                          'Перетащите края рамки',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
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
  }

  Widget _buildThumbnailTimeline() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final leftPos = _startFraction * totalWidth;
        final rightPos = _endFraction * totalWidth;
        
        return SizedBox(
          height: 60,
          child: Stack(
            children: [
              // Thumbnails
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: List.generate(_thumbnailCount, (i) {
                    return Expanded(
                      child: Container(
                        height: 60,
                        color: const Color(0xFF334155),
                        child: _thumbnails.length > i && _thumbnails[i] != null
                            ? Image.memory(_thumbnails[i]!, fit: BoxFit.cover, gaplessPlayback: true)
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              
              // Dim left
              Positioned(
                left: 0, top: 0, bottom: 0, width: leftPos,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                ),
              ),
              // Dim right
              Positioned(
                right: 0, top: 0, bottom: 0, width: totalWidth - rightPos,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                ),
              ),
              
              // Frame top/bottom
              Positioned(left: leftPos, top: 0, width: rightPos - leftPos, height: 3, child: Container(color: Colors.white)),
              Positioned(left: leftPos, bottom: 0, width: rightPos - leftPos, height: 3, child: Container(color: Colors.white)),
              
              // CENTER DRAG — move entire selection
              Positioned(
                left: leftPos + 24,
                top: 0, bottom: 0,
                width: (rightPos - leftPos) - 48 > 0 ? (rightPos - leftPos) - 48 : 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final delta = details.delta.dx / totalWidth;
                    final selectionWidth = _endFraction - _startFraction;
                    final newStart = (_startFraction + delta).clamp(0.0, 1.0 - selectionWidth);
                    final newEnd = newStart + selectionWidth;
                    if (newEnd <= 1.0) {
                      setState(() {
                        _startFraction = newStart;
                        _endFraction = newEnd;
                      });
                      _controller?.seekTo(_startTime);
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              
              // Left handle
              Positioned(
                left: leftPos - 12, top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final newFrac = ((leftPos + details.delta.dx) / totalWidth).clamp(0.0, _endFraction - 0.05);
                    final newDurMs = (_endFraction - newFrac) * _totalDuration.inMilliseconds;
                    if (newDurMs <= _maxDurationSec * 1000) {
                      setState(() => _startFraction = newFrac);
                      _controller?.seekTo(_startTime);
                    }
                  },
                  child: Container(
                    width: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                    ),
                    child: const Center(child: Icon(Icons.drag_indicator_rounded, color: Color(0xFF1E3A8A), size: 16)),
                  ),
                ),
              ),
              
              // Right handle
              Positioned(
                left: rightPos - 12, top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final newFrac = ((rightPos + details.delta.dx) / totalWidth).clamp(_startFraction + 0.05, 1.0);
                    final newDurMs = (newFrac - _startFraction) * _totalDuration.inMilliseconds;
                    if (newDurMs <= _maxDurationSec * 1000) {
                      setState(() => _endFraction = newFrac);
                    }
                  },
                  child: Container(
                    width: 24,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                    child: const Center(child: Icon(Icons.drag_indicator_rounded, color: Color(0xFF1E3A8A), size: 16)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
