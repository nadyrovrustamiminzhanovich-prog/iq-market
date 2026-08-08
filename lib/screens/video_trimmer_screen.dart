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
  // Минимальная длина фрагмента задана в абсолютном времени, а не долей от
  // ролика. Раньше нижняя граница была «_endFraction - 0.05», т.е. 5% длины:
  // для 10-минутного видео это 30 сек — больше самого лимита в 20 сек, из-за
  // чего левый маркер у длинных роликов не двигался вообще.
  static const int _minDurationMs = 1000;

  // Ширина рамки выделения в долях от всей длины ролика.
  double get _maxFraction => _totalDuration.inMilliseconds > 0
      ? (_maxDurationSec * 1000 / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
      : 1.0;
  double get _minFraction => _totalDuration.inMilliseconds > 0
      ? (_minDurationMs / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  // Длина выбранного фрагмента в секундах, ОКРУГЛЁННАЯ, а не усечённая.
  // Duration.inSeconds отбрасывает дробную часть, и из-за погрешности
  // умножения долей на миллисекунды выбор ровно 20 сек почти всегда даёт
  // 19999 мс — то есть «19 сек» и в подписи, и в самой обрезке.
  int get _selectedSeconds => (_selectedDuration.inMilliseconds / 1000).round();

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
        // Стартовое окно — ровно лимит (или весь ролик, если он короче).
        // Раньше делили на _totalDuration.inSeconds — округлённое ВНИЗ число:
        // для ролика 60.8 сек рамка получалась 20/60 от длины, то есть 20.27
        // сек вместо 20, и подпись расходилась с тем, что реально сохранится.
        _endFraction = _maxFraction;
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

      // VideoCompress принимает startTime/duration только ЦЕЛЫМИ секундами
      // (int?, video_compress 3.1.4), поэтому доли секунды здесь теряются в
      // любом случае — важно округлять, а не усекать. Duration.inSeconds
      // усекает вниз: выбранные 19999 мс (это ровно то, что даёт рамка,
      // растянутая на все 20 сек) превращались в duration: 19, и пользователь
      // получал на секунду меньше, чем выделил. То же самое теряло секунду и
      // на startTime, сдвигая фрагмент назад.
      final int totalSec = _totalDuration.inMilliseconds ~/ 1000;
      int durationSec = _selectedSeconds.clamp(1, _maxDurationSec);
      if (totalSec > 0 && durationSec > totalSec) durationSec = totalSec;
      // После округления start + duration может выехать за конец исходника —
      // тогда кодек отдал бы фрагмент короче запрошенного. Сдвигаем начало
      // назад, сохраняя полную длину выбранного отрезка.
      final int maxStartSec = (totalSec - durationSec).clamp(0, totalSec);
      final int startSec =
          (_startTime.inMilliseconds / 1000).round().clamp(0, maxStartSec);

      final info = await VideoCompress.compressVideo(
        widget.videoFile.path,
        quality: VideoQuality.Res640x480Quality,
        startTime: needsTrim ? startSec : null,
        duration: needsTrim ? durationSec : null,
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
              ),
          ],
        ),
        body: !_isLoaded
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A80F0)))
          : Stack(
              children: [
              SafeArea(
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
                                color: _selectedSeconds <= _maxDurationSec
                                    ? const Color(0xFF4A80F0).withValues(alpha: 0.2)
                                    : Colors.red.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$_selectedSeconds сек',
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
              if (_isSaving) _buildSavingOverlay(),
              ],
            ),
      ),
    );
  }

  // Раньше на время сохранения был только крошечный 20x20 спиннер вместо
  // кнопки "Готово" в AppBar — легко не заметить, что реально идёт обрезка
  // и сжатие видео (реальная асинхронная работа, не мгновенная). Теперь —
  // на весь экран, как оверлей загрузки на экране публикации объявления.
  Widget _buildSavingOverlay() => Positioned.fill(
    child: AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black.withValues(alpha: 0.75),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 20),
              Text(
                TranslationService.t('savingVideo', Provider.of<AppConfigProvider>(context, listen: false).language),
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );

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
                    // Рамку УПИРАЕМ в границу лимита, а не отбрасываем жест.
                    // Раньше любое движение, которое вышло бы за 20 сек,
                    // игнорировалось целиком — палец за один event проходит
                    // несколько пикселей (на 60-секундном ролике это ~0.5 сек),
                    // поэтому выделение застревало заметно НЕ ДОТЯНУВ до 20 сек
                    // и дотянуть до ровных 20 было физически невозможно.
                    final newFraction = (leftPos + details.delta.dx) / totalWidth;
                    final upperBound = _endFraction - _minFraction;
                    final lowerBound = (_endFraction - _maxFraction).clamp(0.0, 1.0);
                    if (upperBound <= lowerBound) return;
                    setState(() => _startFraction = newFraction.clamp(lowerBound, upperBound));
                    _controller?.seekTo(_startTime);
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
                    // Симметрично левому маркеру: упираем в лимит, а не
                    // игнорируем жест (см. комментарий выше).
                    final newFraction = (rightPos + details.delta.dx) / totalWidth;
                    final lowerBound = _startFraction + _minFraction;
                    final upperBound = (_startFraction + _maxFraction).clamp(0.0, 1.0);
                    if (upperBound <= lowerBound) return;
                    setState(() => _endFraction = newFraction.clamp(lowerBound, upperBound));
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
