// TTS Wrapper that handles platform-specific TTS availability
// Uses flutter_tts when available, falls back to stub on Windows

import 'dart:io' show Platform, Process, File, Directory;
import 'package:flutter/foundation.dart';

// For Windows, we use WindowsTtsImpl (PowerShell-based)
// For other platforms, we try to use flutter_tts
// The import will be handled conditionally

/// TTS Interface
abstract class TtsInterface {
  Future<void> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> setVolume(double volume);
  Future<void> setPitch(double pitch);
  Future<void> speak(String text);
  Future<void> stop();
}

/// TTS Implementation using flutter_tts
class FlutterTtsImpl implements TtsInterface {
  final dynamic _tts; // FlutterTts from flutter_tts package

  FlutterTtsImpl(this._tts);

  bool get isAvailable => true; // FlutterTts is always available when this class is used

  @override
  Future<void> setLanguage(String language) async {
    try {
      await _tts.setLanguage(language);
    } catch (e) {
      debugPrint('Error setting TTS language: $e');
    }
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (e) {
      debugPrint('Error setting TTS speech rate: $e');
    }
  }

  @override
  Future<void> setVolume(double volume) async {
    try {
      await _tts.setVolume(volume);
    } catch (e) {
      debugPrint('Error setting TTS volume: $e');
    }
  }

  @override
  Future<void> setPitch(double pitch) async {
    try {
      await _tts.setPitch(pitch);
    } catch (e) {
      debugPrint('Error setting TTS pitch: $e');
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Error speaking with TTS: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }
}

/// Windows TTS implementation using PowerShell
class WindowsTtsImpl implements TtsInterface {
  Process? _currentProcess;

  @override
  Future<void> setLanguage(String language) async {
    // Windows SAPI uses system default language
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    // Rate is handled per-speech call
  }

  @override
  Future<void> setVolume(double volume) async {
    // Volume is handled per-speech call
  }

  @override
  Future<void> setPitch(double pitch) async {
    // Pitch adjustment not directly supported via PowerShell
  }

  @override
  Future<void> speak(String text) async {
    try {
      // Stop any current speech
      await stop();

      // Use temp file method - more reliable than inline command
      // Escape single quotes by doubling them
      final escapedText = text.replaceAll("'", "''");
      
      // Create PowerShell script content
      final psScript = 
        "Add-Type -AssemblyName System.Speech\n"
        "\$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer\n"
        "\$synthesizer.Rate = 0\n"
        "\$synthesizer.Volume = 100\n"
        "\$synthesizer.Speak('$escapedText')\n";
      
      // Write to temp file and execute
      final tempFile = await _writeTempScript(psScript);
      if (tempFile != null) {
        debugPrint('Windows TTS: Speaking "$text" via script: $tempFile');
        
        final command = 'powershell';
        final args = [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          tempFile
        ];
        
        _currentProcess = await Process.start(command, args);
        
        // Wait for speech to complete (with timeout)
        try {
          final exitCode = await _currentProcess!.exitCode.timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('Windows TTS: Speech timeout, killing process');
              _currentProcess?.kill();
              return -1;
            },
          );
          debugPrint('Windows TTS: PowerShell exited with code: $exitCode');
        } catch (e) {
          debugPrint('Windows TTS timeout error: $e');
        }
        
        // Clean up temp file
        try {
          await File(tempFile).delete();
          debugPrint('Windows TTS: Temp script deleted');
        } catch (e) {
          debugPrint('Failed to delete temp script: $e');
        }
      } else {
        debugPrint('Windows TTS: Failed to create temp script, trying inline command');
        // Fallback to inline command if temp file fails
        await _speakWithInlineCommand(text);
      }
    } catch (e) {
      debugPrint('Windows TTS error: $e');
      // Final fallback
      await _speakWithInlineCommand(text);
    }
  }

  /// Fallback method using inline PowerShell command
  Future<void> _speakWithInlineCommand(String text) async {
    try {
      // Escape text - replace single quotes
      final escapedText = text.replaceAll("'", "''");
      
      // Build PowerShell command with proper escaping
      final psCommand = 
        "Add-Type -AssemblyName System.Speech; "
        "`\$synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
        "`\$synthesizer.Rate = 0; "
        "`\$synthesizer.Volume = 100; "
        "`\$synthesizer.Speak('$escapedText');";
      
      final command = 'powershell';
      final args = [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        psCommand
      ];

      _currentProcess = await Process.start(command, args);
      
      // Don't wait - let it speak
      _currentProcess!.exitCode.then((code) {
        if (code != 0) {
          debugPrint('Windows TTS PowerShell exited with code: $code');
        }
      }).catchError((e) {
        debugPrint('Windows TTS error: $e');
      });
    } catch (e) {
      debugPrint('Inline Windows TTS also failed: $e');
      print('TTS: $text');
    }
  }

  Future<String?> _writeTempScript(String content) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}\\queue_tts_${DateTime.now().millisecondsSinceEpoch}.ps1');
      await tempFile.writeAsString(content);
      return tempFile.path;
    } catch (e) {
      debugPrint('Failed to create temp script: $e');
      return null;
    }
  }

  @override
  Future<void> stop() async {
    try {
      if (_currentProcess != null) {
        _currentProcess!.kill();
        _currentProcess = null;
      }
    } catch (e) {
      debugPrint('Error stopping Windows TTS: $e');
    }
  }
}

/// Stub implementation for platforms without TTS
class TtsStub implements TtsInterface {
  @override
  Future<void> setLanguage(String language) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> speak(String text) async {
    // Log the message - TTS not available on this platform
    debugPrint('TTS (not available): $text');
  }

  @override
  Future<void> stop() async {}
}

/// Factory to create appropriate TTS implementation
TtsInterface createTts() {
  // On Windows, use PowerShell-based TTS (Windows SAPI)
  if (Platform.isWindows) {
    debugPrint('Platform detected as Windows - creating WindowsTtsImpl');
    final tts = WindowsTtsImpl();
    debugPrint('WindowsTtsImpl created successfully');
    return tts;
  }
  
  // On other platforms (Android/iOS/macOS/Linux), use stub for now
  // flutter_tts is commented out to avoid Windows CMake errors
  // TODO: Re-enable flutter_tts for non-Windows platforms when needed
  debugPrint('Platform is not Windows - using TtsStub (flutter_tts not available)');
  return TtsStub();
}
