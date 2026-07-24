import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/services/translation_service.dart';

class SecureImageViewerScreen extends StatefulWidget {
  final ImageProvider? imageProvider;
  final String? imageUrl;
  final File? file;
  final String? heroTag;
  final bool enableDownload;
  final bool enableProtection;

  const SecureImageViewerScreen({
    super.key,
    this.imageProvider,
    this.imageUrl,
    this.file,
    this.heroTag,
    this.enableDownload = true,
    this.enableProtection = true,
  });

  @override
  State<SecureImageViewerScreen> createState() => _SecureImageViewerScreenState();
}

class _SecureImageViewerScreenState extends State<SecureImageViewerScreen> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
        }
      });

    if (widget.enableProtection) {
      _enableScreenshotProtection();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    if (widget.enableProtection) {
      _disableScreenshotProtection();
    }
    super.dispose();
  }

  void _enableScreenshotProtection() async {
    try {
      await ScreenProtector.preventScreenshotOn();
    } catch (e) {
      debugPrint("Error enabling screenshot protection: $e");
    }
  }

  void _disableScreenshotProtection() async {
    try {
      await ScreenProtector.preventScreenshotOff();
    } catch (e) {
      debugPrint("Error disabling screenshot protection: $e");
    }
  }

  String _getHighResUrl(String url) {
    if (url.isEmpty) return url;
    // Upgrade Google profile avatar quality from low-res thumbnail to high-res 1024px
    if (url.contains('googleusercontent.com')) {
      return url.replaceAll(RegExp(r'=s\d+(-c)?'), '=s1024');
    }
    return url;
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final double targetScale = currentScale > 1.2 ? 1.0 : 2.5;

    final Matrix4 endMatrix;
    if (targetScale == 1.0) {
      endMatrix = Matrix4.identity();
    } else {
      final position = details.localPosition;
      final x = -position.dx * (targetScale - 1);
      final y = -position.dy * (targetScale - 1);
      endMatrix = Matrix4.translationValues(x, y, 0)..scaleByDouble(targetScale, targetScale, 1.0, 1.0);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurveTween(curve: Curves.easeOutCubic).animate(_animationController));

    _animationController.forward(from: 0.0);
  }

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    final lang = Provider.of<AppConfigProvider>(context, listen: false).language;

    setState(() => _isSaving = true);
    try {
      if (widget.file != null) {
        final bytes = await widget.file!.readAsBytes();
        await Gal.putImageBytes(bytes);
      } else if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
        final url = _getHighResUrl(widget.imageUrl!);
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          await Gal.putImageBytes(response.bodyBytes);
        } else {
          throw Exception("HTTP ${response.statusCode}");
        }
      } else {
        throw Exception("No valid image source for saving");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(TranslationService.t('saved_to_gallery', lang))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(TranslationService.t('errSavePhoto', lang).replaceAll('{error}', e.toString())),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - (_dragOffset.abs() / 300.0)).clamp(0.0, 1.0);
    final String heroTag = widget.heroTag ?? 'fullscreen_img_${widget.imageUrl ?? widget.file?.path ?? widget.imageProvider.hashCode}';

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: opacity),
      body: Stack(
        children: [
          // Main Scaled & Zoomable Image Area
          GestureDetector(
            onDoubleTapDown: _handleDoubleTap,
            onVerticalDragUpdate: (details) {
              final scale = _transformationController.value.getMaxScaleOnAxis();
              if (scale <= 1.05) {
                setState(() {
                  _dragOffset += details.delta.dy;
                  _isDragging = true;
                });
              }
            },
            onVerticalDragEnd: (details) {
              if (_isDragging) {
                if (_dragOffset.abs() > 120 || details.primaryVelocity!.abs() > 600) {
                  Navigator.pop(context);
                } else {
                  setState(() {
                    _dragOffset = 0.0;
                    _isDragging = false;
                  });
                }
              }
            },
            child: Transform.translate(
              offset: Offset(0, _dragOffset),
              child: SizedBox.expand(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  clipBehavior: Clip.none,
                  minScale: 0.9,
                  maxScale: 5.0,
                  child: Center(
                    child: Hero(
                      tag: heroTag,
                      child: _buildMainImageWidget(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Glassmorphic Top Controls Bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                _glassButton(
                  icon: Icons.close_rounded,
                  onPressed: () => Navigator.pop(context),
                ),

                // Save button (if download enabled and valid image source)
                if (widget.enableDownload && (widget.file != null || (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)))
                  _glassButton(
                    icon: _isSaving ? Icons.hourglass_empty_rounded : Icons.download_rounded,
                    onPressed: _isSaving ? null : _saveToGallery,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainImageWidget() {
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      final highResUrl = _getHighResUrl(widget.imageUrl!);
      return CachedNetworkImage(
        imageUrl: highResUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_rounded, size: 54, color: Colors.white38),
              SizedBox(height: 8),
              Text(
                'Ошибка загрузки фото',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    } else if (widget.file != null) {
      return Image.file(
        widget.file!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (widget.imageProvider != null) {
      return Image(
        image: widget.imageProvider!,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 54, color: Colors.white38),
        ),
      );
    }

    return const Center(
      child: Icon(Icons.broken_image_rounded, size: 54, color: Colors.white38),
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onPressed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
