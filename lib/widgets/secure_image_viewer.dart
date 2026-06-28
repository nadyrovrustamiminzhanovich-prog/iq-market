import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class SecureImageViewerScreen extends StatefulWidget {
  final ImageProvider imageProvider;
  final String heroTag;

  const SecureImageViewerScreen({
    super.key,
    required this.imageProvider,
    required this.heroTag,
  });

  @override
  State<SecureImageViewerScreen> createState() => _SecureImageViewerScreenState();
}

class _SecureImageViewerScreenState extends State<SecureImageViewerScreen> {
  @override
  void initState() {
    super.initState();
    _enableScreenshotProtection();
  }

  @override
  void dispose() {
    _disableScreenshotProtection();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Hero(
          tag: widget.heroTag,
          child: InteractiveViewer(
            clipBehavior: Clip.none,
            maxScale: 4.0,
            child: Image(
              image: widget.imageProvider,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_rounded, 
                size: 64, 
                color: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
