import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AzureTtsService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> speak(String text, String lang) async {
    if (text.isEmpty) {
      return;
    }

    try {
      String locale = "";
      if (lang == 'KZ') {
        locale = "kk";
      } else if (lang == 'UG') {
        locale = "ug";
      } else {
        locale = "ru";
      }

      // Разбиваем на предложения для красоты и стабильности
      List<String> chunks = _splitText(text, 180);
      
      for (var chunk in chunks) {
        String url = "https://translate.google.com/translate_tts?ie=UTF-8&q=${Uri.encodeComponent(chunk)}&tl=$locale&client=tw-ob";
        await _audioPlayer.play(UrlSource(url));
        
        // Ждем пока дочитает кусок или пока не прервали
        await _audioPlayer.onPlayerComplete.first;
      }
      
    } catch (e) {
      debugPrint("Google TTS Error: $e");
    }
  }

  List<String> _splitText(String text, int size) {
    List<String> result = [];
    String current = text;
    while (current.length > size) {
      int splitAt = current.lastIndexOf(' ', size);
      if (splitAt == -1) splitAt = size;
      result.add(current.substring(0, splitAt));
      current = current.substring(splitAt).trim();
    }
    result.add(current);
    return result;
  }

  void stop() {
    _audioPlayer.stop();
  }
}
