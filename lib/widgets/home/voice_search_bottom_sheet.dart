import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:iqmarket/widgets/voice_waveform.dart';
import 'package:iqmarket/services/translation_service.dart';

class VoiceSearchBottomSheet extends StatefulWidget {
  final stt.SpeechToText speech;
  final String lang;

  const VoiceSearchBottomSheet({
    super.key,
    required this.speech,
    required this.lang,
  });

  @override
  State<VoiceSearchBottomSheet> createState() => _VoiceSearchBottomSheetState();
}

class _VoiceSearchBottomSheetState extends State<VoiceSearchBottomSheet> {
  bool _isListening = false;
  String _recognizedText = '';
  double _soundLevel = 0.0;
  double _minLevel = 0.0;
  double _maxLevel = 10.0; // Typical Android speech_to_text max level is around 10

  /// FIX: Guard flag — ensures Navigator.pop is called AT MOST ONCE.
  /// Previously, onResult(finalResult) + onStatus('done') both scheduled a pop
  /// within ~600ms of each other → double/triple pop → black screen crash.
  bool _hasPopped = false;

  double getNormalizedLevel(double level) {
    if (level < _minLevel) _minLevel = level;
    if (level > _maxLevel) _maxLevel = level;
    final range = _maxLevel - _minLevel;
    if (range <= 0) return 0.0;
    return ((level - _minLevel) / range).clamp(0.0, 1.0);
  }

  /// Safe pop helper: atomically checks _hasPopped then pops exactly once.
  void _safePopWithResult([String? result]) {
    if (_hasPopped) {
      debugPrint('[VoiceSearch] _safePopWithResult blocked — already popped (result="$result")');
      return;
    }
    if (!mounted) {
      debugPrint('[VoiceSearch] _safePopWithResult blocked — widget not mounted (result="$result")');
      return;
    }
    _hasPopped = true;
    debugPrint('[VoiceSearch] Navigator.pop → result="$result"');
    Navigator.pop(context, result);
  }

  @override
  void initState() {
    super.initState();
    // Start listening as soon as the bottom sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    debugPrint('[VoiceSearch] _startListening called');
    try {
      bool available = await widget.speech.initialize(
        onStatus: (status) {
          debugPrint('[VoiceSearch] onStatus → "$status", _hasPopped=$_hasPopped, text="$_recognizedText"');
          if (status == 'done' || status == 'notListening') {
            if (mounted) {
              setState(() => _isListening = false);
              // FIX: Use _safePopWithResult — onResult(finalResult) may have
              // already scheduled a pop 600ms ago. Without the guard, this
              // second pop would crash with a black screen.
              if (_recognizedText.trim().isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 600), () {
                  debugPrint('[VoiceSearch] onStatus delayed pop firing');
                  _safePopWithResult(_recognizedText);
                });
              }
            }
          }
        },
        onError: (errorNotification) {
          debugPrint('[VoiceSearch] onError → $errorNotification');
          // FIX: Pop FIRST, then show snackbar via rootScaffold to avoid
          // using a context that belongs to the already-dismissed sheet.
          _safePopWithResult(null);
          // Show snackbar after pop using a short delay so root scaffold is active.
          Future.delayed(const Duration(milliseconds: 100), () {
            final rootContext = Navigator.of(context, rootNavigator: true).context;
            if (rootContext.mounted) {
              ScaffoldMessenger.of(rootContext).showSnackBar(
                SnackBar(content: Text(TranslationService.t('mic_unavailable', widget.lang)))
              );
            }
          });
          if (mounted) setState(() => _isListening = false);
        },
      );

      debugPrint('[VoiceSearch] speech.initialize → available=$available');

      if (available) {
        if (mounted) {
          setState(() {
            _isListening = true;
            _recognizedText = '';
            _soundLevel = 0.0;
          });
        }

        await widget.speech.listen(
          onResult: (result) {
            debugPrint('[VoiceSearch] onResult → words="${result.recognizedWords}" final=${result.finalResult}');
            if (mounted) {
              setState(() {
                _recognizedText = result.recognizedWords;
              });
              // FIX: Use _safePopWithResult — onStatus('done') fires almost
              // simultaneously and would call a second pop without the guard.
              if (result.finalResult && _recognizedText.trim().isNotEmpty) {
                Future.delayed(const Duration(milliseconds: 600), () {
                  debugPrint('[VoiceSearch] onResult delayed pop firing');
                  _safePopWithResult(_recognizedText);
                });
              }
            }
          },
          onSoundLevelChange: (level) {
            if (mounted) {
              setState(() {
                _soundLevel = getNormalizedLevel(level);
              });
            }
          },
          localeId: widget.lang == 'Қазақша'
              ? 'kk_KZ'
              : widget.lang == 'Уйғурчә'
                  ? 'tr_TR'
                  : 'ru_RU',
        );
      } else {
        debugPrint('[VoiceSearch] speech not available — popping without result');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(TranslationService.t('mic_unavailable', widget.lang)))
          );
        }
        _safePopWithResult(null);
      }
    } catch (e, st) {
      debugPrint('[VoiceSearch] EXCEPTION in _startListening: $e\n$st');
      _safePopWithResult(null);
    }
  }

  void _stopListening() {
    debugPrint('[VoiceSearch] _stopListening called, isListening=${widget.speech.isListening}');
    if (widget.speech.isListening) {
      widget.speech.stop();
      // NOTE: speech.stop() triggers onStatus('done') asynchronously.
      // _safePopWithResult in _toggleListening will fire first (synchronously),
      // so the onStatus-triggered pop will be blocked by _hasPopped.
    }
  }

  void _toggleListening() {
    debugPrint('[VoiceSearch] _toggleListening, _isListening=$_isListening, text="$_recognizedText"');
    if (_isListening) {
      _stopListening();
      if (mounted) setState(() => _isListening = false);
      // FIX: Use _safePopWithResult — _stopListening() causes onStatus('done')
      // to fire, which would also try to pop. The guard ensures only one fires.
      if (_recognizedText.trim().isNotEmpty) {
        _safePopWithResult(_recognizedText);
      }
    } else {
      _startListening();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final backgroundColor = isDarkMode
        ? const Color(0xFF1E293B).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.9);
    final textColor = isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
    final subtextColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    // Title translations
    final String titleText = widget.lang == 'Қазақша' 
        ? 'Дауыспен іздеу' 
        : widget.lang == 'Уйғурчә' 
            ? 'Авазлиқ издәш' 
            : 'Голосовой поиск';

    final String statusText = _isListening
        ? (widget.lang == 'Қазақша' ? 'Тыңдап тұрмын...' : widget.lang == 'Уйғурчә' ? 'Аңлаватимән...' : 'Слушаю вас...')
        : (widget.lang == 'Қазақша' ? 'Тоқтатылды' : widget.lang == 'Уйғурчә' ? 'Тохтитилди' : 'Остановлено');

    final String actionText = _isListening
        ? (widget.lang == 'Қазақша' ? 'Тоқтату үшін басыңыз' : widget.lang == 'Уйғурчә' ? 'Тохтитиш үчүн басиң' : 'Нажмите, чтобы остановить')
        : (widget.lang == 'Қазақша' ? 'Жалғастыру үшін басыңыз' : widget.lang == 'Уйғурчә' ? 'Башлаш үшін басиң' : 'Нажмите, чтобы начать');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 30,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab Handle
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: subtextColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Spacer to center the title
                Text(
                  titleText,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: subtextColor,
                    letterSpacing: 0.5,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: subtextColor),
                  style: IconButton.styleFrom(
                    backgroundColor: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.05) 
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Animated Waveform
            SizedBox(
              height: 90,
              child: _isListening
                  ? VoiceWaveform(soundLevel: _soundLevel, color: theme.primaryColor)
                  : Center(
                      child: Container(
                        width: 120,
                        height: 3,
                        decoration: BoxDecoration(
                          color: subtextColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),

            // Live Recognized Text Container
            SizedBox(
              height: 70,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    _recognizedText.isEmpty ? statusText : _recognizedText,
                    key: ValueKey<String>(_recognizedText.isEmpty ? 'status' : 'text'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: _recognizedText.isEmpty ? 18 : 20,
                      fontWeight: _recognizedText.isEmpty ? FontWeight.w500 : FontWeight.w600,
                      color: _recognizedText.isEmpty ? subtextColor : textColor,
                      fontStyle: _recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Glowing Pulsating Mic Button
            GestureDetector(
              onTap: _toggleListening,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing rings (only when listening)
                  if (_isListening) ...[
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withValues(alpha: 0.1),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.4, 1.4),
                          duration: 1600.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeOut(duration: 1600.ms),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withValues(alpha: 0.15),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1.2, 1.2),
                          duration: 1200.ms,
                          curve: Curves.easeOut,
                        )
                        .fadeOut(duration: 1200.ms),
                  ],

                  // Core Mic Button
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? theme.primaryColor : subtextColor.withValues(alpha: 0.15),
                      boxShadow: _isListening
                          ? [
                              BoxShadow(
                                color: theme.primaryColor.withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ]
                          : null,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: _isListening ? Colors.white : subtextColor,
                      size: 32,
                    ),
                  )
                      .animate(
                        target: _isListening ? 1.0 : 0.0,
                        onPlay: (controller) => controller.repeat(reverse: true),
                      )
                      .scale(
                        begin: const Offset(1.0, 1.0),
                        end: const Offset(1.06, 1.06),
                        duration: 800.ms,
                        curve: Curves.easeInOut,
                      ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Hint Text
            Text(
              actionText,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: subtextColor.withValues(alpha: 0.7),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
