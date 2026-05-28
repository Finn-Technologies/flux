import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal() {
    _init();
  }

  final FlutterTts _tts = FlutterTts();
  final Queue<_TtsTask> _queue = Queue<_TtsTask>();
  bool _isSpeaking = false;
  bool _muted = false;
  Completer<void>? _currentCompleter;

  bool get isSpeaking => _isSpeaking;

  Future<void> _init() async {
    try {
      print("TTS: Initializing...");
      await _tts.setVolume(1.0);
      await _tts.setLanguage("en-US");

      // Pick the most natural-sounding voice the device offers, then tune the
      // prosody for a warm, conversational delivery rather than the flat,
      // robotic default.
      await _selectNaturalVoice();
      await _tts.setSpeechRate(_naturalRate());
      await _tts.setPitch(1.05);

      await _tts.awaitSpeakCompletion(true);
      
      _tts.setCompletionHandler(() {
        print("TTS: Speech completed");
        _isSpeaking = false;
        _currentCompleter?.complete();
        _currentCompleter = null;
        _remuteMusicIfNeeded();
        _processQueue();
      });

      _tts.setCancelHandler(() {
        print("TTS: Speech cancelled");
        _isSpeaking = false;
        _currentCompleter?.complete();
        _currentCompleter = null;
        _remuteMusicIfNeeded();
      });

      _tts.setErrorHandler((msg) {
        print("TTS: Speech error: $msg");
        _isSpeaking = false;
        _currentCompleter?.completeError(msg);
        _currentCompleter = null;
        _remuteMusicIfNeeded();
        _processQueue();
      });
      print("TTS: Initialization complete");
    } catch (e) {
      print("TTS Init Error: $e");
    }
  }

  /// flutter_tts maps speech rate to 0..1 but engines interpret it very
  /// differently. These values land on a relaxed, human cadence per platform.
  double _naturalRate() {
    if (Platform.isIOS || Platform.isMacOS) return 0.52;
    if (Platform.isAndroid) return 0.48;
    return 0.5;
  }

  /// Scans the installed voices and selects the warmest, most natural English
  /// voice available, preferring premium / enhanced (Apple) and neural /
  /// network (Google) voices over the low-quality compact defaults.
  Future<void> _selectNaturalVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List) return;

      final voices = raw
          .whereType<Object>()
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) =>
              (v['locale'] ?? '').toString().toLowerCase().startsWith('en'))
          .toList();
      if (voices.isEmpty) return;

      // A handful of voices widely regarded as warm and natural; used only as a
      // tie-breaker on top of the quality heuristics below.
      const preferredNames = [
        'samantha', 'ava', 'zoe', 'serena', 'aria', 'jenny', 'libby',
        'sonia', 'evie', 'tessa', 'moira', 'karen', 'nora',
      ];

      int scoreOf(Map<String, dynamic> v) {
        final name = (v['name'] ?? '').toString().toLowerCase();
        final locale = (v['locale'] ?? '').toString().toLowerCase();
        var score = 0;

        // Apple quality tiers.
        if (name.contains('premium')) score += 120;
        if (name.contains('enhanced')) score += 90;
        if (name.contains('siri')) score += 80;

        // Google / Android natural voices.
        if (name.contains('neural')) score += 110;
        if (name.contains('network')) score += 95;

        // Generic quality field, when present.
        final q = int.tryParse((v['quality'] ?? '').toString());
        if (q != null) score += (q ~/ 100);

        // Locale preference: US English first, then GB.
        if (locale == 'en-us') {
          score += 25;
        } else if (locale == 'en-gb') {
          score += 12;
        }

        // Warm, friendly tie-breaker.
        for (final p in preferredNames) {
          if (name.contains(p)) {
            score += 18;
            break;
          }
        }

        // Penalize known low-fidelity voices.
        if (name.contains('compact')) score -= 40;
        if (name.contains('eloquence')) score -= 70;

        return score;
      }

      voices.sort((a, b) => scoreOf(b).compareTo(scoreOf(a)));
      final best = voices.first;

      final voiceArg = <String, String>{
        'name': (best['name'] ?? '').toString(),
        'locale': (best['locale'] ?? 'en-US').toString(),
      };
      await _tts.setVoice(voiceArg);
      print("TTS: Selected voice: ${voiceArg['name']} (${voiceArg['locale']})");
    } catch (e) {
      print("TTS: voice selection failed: $e");
    }
  }

  void setMuted(bool muted) {
    _muted = muted;
    if (muted) {
      stop();
    }
  }

  Future<void> speak(String text) async {
    if (_muted || text.isEmpty) return;
    
    final completer = Completer<void>();
    _queue.add(_TtsTask(text, completer));
    
    if (!_isSpeaking) {
      _processQueue();
    }
    
    return completer.future;
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _isSpeaking || _muted) {
      if (_queue.isEmpty && !_isSpeaking) {
        _remuteMusicIfNeeded();
      }
      return;
    }

    _isSpeaking = true;
    final task = _queue.removeFirst();
    _currentCompleter = task.completer;
    
    try {
      // Ensure music is unmuted so user can hear TTS
      await _unmuteMusic();
      
      print("TTS: Speaking: ${task.text}");
      await _tts.speak(task.text);
    } catch (e) {
      _isSpeaking = false;
      task.completer.completeError(e);
      _processQueue();
    }
  }

  bool _enableAutoMute = false;
  bool _musicMuted = false;

  bool get enableAutoMute => _enableAutoMute;
  set enableAutoMute(bool value) {
    _enableAutoMute = value;
    // Entering live mode mutes music natively elsewhere; mirror that here so
    // the first utterance knows it needs to duck the music back in.
    _musicMuted = value;
  }

  Future<void> _unmuteMusic() async {
    // Only relevant on Android, and only when music is actually ducked. This
    // avoids a needless delay before every sentence (which made speech feel
    // laggy and choppy, especially on iOS/macOS where the channel is a no-op).
    if (!_musicMuted || !Platform.isAndroid) return;
    try {
      // Brief pause so any lingering STT start beep finishes first.
      await Future.delayed(const Duration(milliseconds: 250));
      const channel = MethodChannel('com.finn.flux/storage');
      await channel.invokeMethod('unmuteMusicStream');
    } catch (_) {}
    _musicMuted = false;
  }

  Future<void> _remuteMusicIfNeeded() async {
    if (!_enableAutoMute) return;
    // Keep music ducked continuously across a multi-sentence response; only
    // restore it once the whole utterance queue has drained.
    if (_queue.isNotEmpty) return;
    if (Platform.isAndroid) {
      try {
        const channel = MethodChannel('com.finn.flux/storage');
        await channel.invokeMethod('muteMusicStream');
      } catch (_) {}
    }
    _musicMuted = true;
  }

  Future<void> stop() async {
    _queue.clear();
    _isSpeaking = false;
    await _tts.stop();
    _currentCompleter?.complete();
    _currentCompleter = null;
  }
}

class _TtsTask {
  final String text;
  final Completer<void> completer;
  _TtsTask(this.text, this.completer);
}
