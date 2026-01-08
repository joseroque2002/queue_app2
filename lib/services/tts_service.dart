import 'dart:io';
import 'package:flutter/foundation.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  // Speak text using platform-specific TTS
  Future<void> speak(String text) async {
    try {
      if (kIsWeb) {
        // Web TTS using JavaScript
        await _speakWeb(text);
      } else if (Platform.isWindows) {
        // Windows TTS using PowerShell
        await _speakWindows(text);
      } else if (Platform.isAndroid || Platform.isIOS) {
        // Mobile platforms - would use flutter_tts if available
        await _speakMobile(text);
      } else {
        // Linux/macOS fallback
        await _speakLinux(text);
      }
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  Future<void> _speakWeb(String text) async {
    // Web speech synthesis would be implemented here
    print('Web TTS: $text');
  }

  Future<void> _speakWindows(String text) async {
    try {
      // Use PowerShell SAPI for Windows TTS
      final result = await Process.run('powershell', [
        '-Command',
        'Add-Type -AssemblyName System.Speech; '
        '\$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer; '
        '\$speak.Speak("$text")'
      ]);
      
      if (result.exitCode != 0) {
        print('Windows TTS Error: ${result.stderr}');
      }
    } catch (e) {
      print('Windows TTS failed: $e');
    }
  }

  Future<void> _speakMobile(String text) async {
    // Placeholder for mobile TTS
    // Would use flutter_tts package when available
    print('Mobile TTS: $text');
  }

  Future<void> _speakLinux(String text) async {
    try {
      // Use espeak for Linux
      await Process.run('espeak', [text]);
    } catch (e) {
      // Fallback to festival
      try {
        await Process.run('echo', [text, '|', 'festival', '--tts']);
      } catch (e2) {
        print('Linux TTS failed: $e2');
      }
    }
  }

  // Announce queue completion
  Future<void> announceQueueCompletion(String userName, String department) async {
    final message = '$userName, your queue for $department department is now complete.';
    await speak(message);
  }

  // Announce queue position
  Future<void> announceQueuePosition(String userName, int position) async {
    final message = '$userName, you are now number $position in the queue.';
    await speak(message);
  }
}