import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Единый полноэкранный просмотрщик фото + видео объявления.
///
/// Раньше это были два разных места: `_openFullscreenGallery` (только фото,
/// открывался тапом по фото) и `FullscreenVideoPlayer` (только видео,
/// открывался отдельной кнопкой-разворотом на видео-слайде) — свайпнуть из
/// одного в другое было невозможно в принципе, они не знали друг о друге.
///
/// Плюс у фото-версии свайп между фото не работал вообще: страницы фото были
/// обёрнуты в `InteractiveViewer` (для pinch-zoom), а `InteractiveViewer`
/// всегда ставит свой `GestureDetector` на scale-жест (см. исходник Flutter
/// interactive_viewer.dart — `panEnabled`/`scaleEnabled` управляют только тем,
/// применяется ли результат внутри обработчика, а не тем, участвует ли
/// распознаватель в gesture arena). На практике это означает, что его
/// распознаватель забирал горизонтальный драг себе раньше родительского
/// PageView — и поскольку на масштабе 1.0 (не приближено) "пан" не двигает
/// ничего видимого, свайп внешне выглядел так, будто "ничего не происходит".
/// `panEnabled: false` эту гонку жестов НЕ решает (GestureDetector всё равно
/// не отдаёт жест наверх) — единственный надёжный способ гарантированно
/// вернуть свайп между фото — не ставить конкурирующий scale-распознаватель
/// на страницы фото вообще. Поэтому pinch-zoom в этом просмотрщике убран:
/// свайп между фото/видео гарантированно работает, ценой ручного масштабирования.
class FullscreenMediaGallery extends StatefulWidget {
  final List<String> images;
  final VideoPlayerController? videoController;
  final bool isVideoInitialized;
  final int initialIndex;
  final Widget Function(String url) imageBuilder;

  const FullscreenMediaGallery({
    super.key,
    required this.images,
    required this.videoController,
    required this.isVideoInitialized,
    required this.initialIndex,
    required this.imageBuilder,
  });

  @override
  State<FullscreenMediaGallery> createState() => _FullscreenMediaGalleryState();
}

class _FullscreenMediaGalleryState extends State<FullscreenMediaGallery> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isVideoPlaying = false;
  bool _showVideoControls = true;
  Timer? _controlsTimer;

  bool get _hasVideo => widget.videoController != null;
  int get _videoIndex => widget.images.length;
  int get _itemCount => widget.images.length + (_hasVideo ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    if (_hasVideo) {
      _isVideoPlaying = widget.videoController!.value.isPlaying;
      widget.videoController!.addListener(_videoListener);
      _startControlsTimer();
    }
  }

  void _videoListener() {
    if (!mounted) return;
    final playing = widget.videoController!.value.isPlaying;
    if (playing != _isVideoPlaying) {
      setState(() => _isVideoPlaying = playing);
      if (playing) {
        _startControlsTimer();
      } else {
        _controlsTimer?.cancel();
        setState(() => _showVideoControls = true);
      }
    }
  }

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isVideoPlaying) setState(() => _showVideoControls = false);
    });
  }

  void _toggleVideoControls() {
    setState(() => _showVideoControls = !_showVideoControls);
    if (_showVideoControls && _isVideoPlaying) {
      _startControlsTimer();
    } else {
      _controlsTimer?.cancel();
    }
  }

  void _toggleVideoPlayback() {
    final controller = widget.videoController;
    if (controller == null || !widget.isVideoInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  @override
  void dispose() {
    _controlsTimer?.cancel();
    widget.videoController?.removeListener(_videoListener);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _itemCount,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              // Свайпнули с видео на фото — не даём звуку играть фоном,
              // пока смотрят фотографии.
              if (_hasVideo && index != _videoIndex && widget.videoController!.value.isPlaying) {
                widget.videoController!.pause();
              }
            },
            itemBuilder: (context, index) {
              if (_hasVideo && index == _videoIndex) {
                return _buildVideoPage();
              }
              return Center(child: widget.imageBuilder(widget.images[index]));
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.5),
              radius: 22,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          if (_itemCount > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(12)),
                child: Text('${_currentIndex + 1}/$_itemCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPage() {
    final controller = widget.videoController!;
    return GestureDetector(
      onTap: _toggleVideoControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: widget.isVideoInitialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : const CircularProgressIndicator(color: Color(0xFF4A80F0)),
          ),
          IgnorePointer(
            ignoring: !_showVideoControls,
            child: AnimatedOpacity(
              opacity: _showVideoControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Center(
                child: GestureDetector(
                  onTap: _toggleVideoPlayback,
                  child: Container(
                    width: 75,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: Icon(
                      _isVideoPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 45,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.isVideoInitialized)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 20,
              left: 20,
              right: 20,
              child: IgnorePointer(
                ignoring: !_showVideoControls,
                child: AnimatedOpacity(
                  opacity: _showVideoControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Color(0xFF4A80F0),
                        bufferedColor: Colors.white30,
                        backgroundColor: Colors.white12,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
