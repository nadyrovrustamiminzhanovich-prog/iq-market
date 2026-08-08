import 'dart:io';
import 'package:iqmarket/services/translation_service.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_compress/video_compress.dart';

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
  VideoPlayerController? _controller;
  bool _isLoaded = false;
  bool _isSaving = false;
  
  Duration _totalDuration = Duration.zero;
  double _startFraction = 0.0;  // 0.0 - 1.0
  double _endFraction = 1.0;    // 0.0 - 1.0
  
  static const int _maxDurationSec = 20;
  
  // Thumbnail frames
  List<Uint8List?> _thumbnails = [];
  static const int _thumbnailCount = 10;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.file(widget.videoFile);
      await _controller!.initialize();
      
      if (!mounted) {
        _controller?.dispose();
        return;
      }
      
      setState(() {
        _isLoaded = true;
        _totalDuration = _controller!.value.duration;
        // Set end to max 20 sec
        if (_totalDuration.inSeconds > _maxDurationSec) {
          _endFraction = _maxDurationSec / _totalDuration.inSeconds;
        }
      });
      
      _controller!.addListener(_playbackListener);
      _generateThumbnails();
    } catch (e) {
      debugPrint("VideoTrimmerScreen init error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t('errPlayVideo', Provider.of<AppConfigProvider>(context, listen: false).language)),
            backgroundColor: Colors.redAccent,
          ),
        );
        Navigator.pop(context);
      }
    }
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
          thumbs.add(await file.readAsBytes());
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
    VideoCompress.cancelCompression();
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

  Future<void> _saveVideo() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await _controller?.pause();
    
    try {
      // Раньше здесь было "isFullDuration = selectedSec >= totalSec - 1" —
      // сравнение ВЫБРАННОГО отрезка с ОБЩЕЙ длиной видео в округлённых
      // секундах. Для роликов длиной ровно 20-22 сек эта эвристика ошибочно
      // считала выбор "почти всем видео" и передавала duration: null —
      // VideoCompress тогда сжимал ролик ЦЕЛИКОМ, без обрезки до 20 сек,
      // то есть лимит по факту не соблюдался. Теперь сравниваем ИСХОДНУЮ
      // длину видео (в миллисекундах, без округления) с лимитом напрямую и
      // всегда явно ограничиваем duration, если исходник длиннее лимита.
      final bool needsTrim = _startTime.inMilliseconds > 0 ||
          _totalDuration.inMilliseconds > _maxDurationSec * 1000;
      final int cappedDurationSec = _selectedDuration.inSeconds.clamp(1, _maxDurationSec);

      final info = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.Res640x480Quality,
        startTime: needsTrim ? _startTime.inSeconds : null,
        duration: needsTrim ? cappedDurationSec : null,
        deleteOrigin: false,
      );

      if (info?.file != null && mounted) {
        widget.onSave(info!.file!.path);
        Navigator.pop(context);
      } else if (mounted) {
        widget.onSave(widget.videoFile.path);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Video trim error: $e');
      if (mounted) {
        widget.onSave(widget.videoFile.path);
        Navigator.pop(context);
      }
    }
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text(TranslationService.t('trimVideoTitle', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _isSaving ? null : () {
              _controller?.pause();
              Navigator.pop(context);
            },
          ),
          actions: [
            if (_isLoaded && !_isSaving)
              TextButton(
                onPressed: _saveVideo,
                child: Text(TranslationService.t('doneBtnCap', Provider.of<AppConfigProvider>(context, listen: false).language), style: GoogleFonts.inter(color: const Color(0xFF4A80F0), fontWeight: FontWeight.w900)),
              )
            else if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
              ),
          ],
        ),
        body: !_isLoaded 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)))
          : SafeArea(
              child: Column(
                children: [
                  // Video preview
                  Expanded(
                    child: GestureDetector(
                      onTap: _togglePlayback,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: AspectRatio(
                              aspectRatio: _controller!.value.aspectRatio,
                              child: VideoPlayer(_controller!),
                            ),
                          ),
                          // Play/pause overlay
                          if (!_controller!.value.isPlaying)
                            Container(
                              width: 70, height: 70,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  // WhatsApp-style timeline scrubber
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20)],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Duration info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_formatDuration(_startTime), style: GoogleFonts.firaCode(color: const Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.w700)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: _selectedDuration.inSeconds <= _maxDurationSec 
                                    ? const Color(0xFF4A80F0).withValues(alpha: 0.2) 
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedDuration.inSeconds} сек',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(_formatDuration(_endTime), style: GoogleFonts.firaCode(color: const Color(0xFFEF4444), fontSize: 13, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Thumbnail timeline with selection handles
                        _buildThumbnailTimeline(),
                        
                        const SizedBox(height: 12),
                        
                        Text(
                          'Перетащите края рамки для выбора фрагмента (макс $_maxDurationSec сек)',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ],
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
          height: 72,
          child: Stack(
            children: [
              // Thumbnail strip
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Row(
                  children: List.generate(_thumbnailCount, (i) {
                    return Expanded(
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          border: Border(
                            right: i < _thumbnailCount - 1 
                                ? BorderSide(color: Colors.black.withValues(alpha: 0.3), width: 0.5) 
                                : BorderSide.none,
                          ),
                        ),
                        child: _thumbnails.length > i && _thumbnails[i] != null
                            ? Image.memory(_thumbnails[i]!, fit: BoxFit.cover, gaplessPlayback: true)
                            : null,
                      ),
                    );
                  }),
                ),
              ),
              
              // Dimmed areas outside selection
              Positioned(
                left: 0, top: 0, bottom: 0,
                width: leftPos,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                  ),
                ),
              ),
              Positioned(
                right: 0, top: 0, bottom: 0,
                width: totalWidth - rightPos,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                  ),
                ),
              ),
              
              // Selection frame (top & bottom borders)
              Positioned(
                left: leftPos, top: 0,
                width: rightPos - leftPos,
                height: 3,
                child: Container(color: const Color(0xFF4A80F0)),
              ),
              Positioned(
                left: leftPos, bottom: 0,
                width: rightPos - leftPos,
                height: 3,
                child: Container(color: const Color(0xFF4A80F0)),
              ),
              
              // CENTER DRAG — move entire selection window
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
              
              // LEFT handle (drag to set start)
              Positioned(
                left: leftPos - 12,
                top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final newFraction = (leftPos + details.delta.dx) / totalWidth;
                    final clampedFraction = newFraction.clamp(0.0, _endFraction - 0.05);
                    // Check max duration
                    final newDurationMs = (_endFraction - clampedFraction) * _totalDuration.inMilliseconds;
                    if (newDurationMs <= _maxDurationSec * 1000) {
                      setState(() => _startFraction = clampedFraction);
                      _controller?.seekTo(_startTime);
                    }
                  },
                  child: Container(
                    width: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A80F0),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(6)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // RIGHT handle (drag to set end)
              Positioned(
                left: rightPos - 12,
                top: 0, bottom: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    final newFraction = (rightPos + details.delta.dx) / totalWidth;
                    final clampedFraction = newFraction.clamp(_startFraction + 0.05, 1.0);
                    final newDurationMs = (clampedFraction - _startFraction) * _totalDuration.inMilliseconds;
                    if (newDurationMs <= _maxDurationSec * 1000) {
                      setState(() => _endFraction = clampedFraction);
                    }
                  },
                  child: Container(
                    width: 24,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A80F0),
                      borderRadius: BorderRadius.horizontal(right: Radius.circular(6)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 16),
                        ],
                      ),
                    ),
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
