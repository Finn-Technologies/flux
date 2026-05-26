import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:background_downloader/background_downloader.dart';

class DownloadNotificationService {
  static const _liveActivityChannel = MethodChannel('com.finn.flux/live_activity');

  static bool _initialized = false;
  static String? _activeModelId;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (Platform.isAndroid) {
      _configureAndroid();
    }

    _initialized = true;
  }

  static void _configureAndroid() {
    try {
      FileDownloader().configureNotification(
        running: const TaskNotification(
          'Downloading {displayName}',
          '{progress} · {networkSpeed}',
        ),
        complete: const TaskNotification(
          'Download complete',
          '{displayName}',
        ),
        error: const TaskNotification(
          'Download failed',
          '{displayName}',
        ),
        progressBar: true,
        tapOpensFile: false,
      );
    } catch (e) {
      print('Failed to configure Android download notifications: $e');
    }
  }

  static void onDownloadStart(String modelId, String modelName, int totalBytes) {
    _activeModelId = modelId;

    if (Platform.isIOS) {
      _startLiveActivity(modelName, totalBytes);
    }
  }

  static void onProgressUpdate(
    String modelId,
    double progress,
    double speed,
    int downloadedBytes,
    int totalBytes,
  ) {
    if (modelId != _activeModelId) return;

    if (Platform.isIOS) {
      _updateLiveActivity(progress, downloadedBytes, totalBytes, speed);
    }
  }

  static void onDownloadComplete(String modelId) {
    if (modelId != _activeModelId) return;
    _endActivity();
  }

  static void onDownloadError(String modelId) {
    if (modelId != _activeModelId) return;
    _endActivity();
  }

  static void onDownloadCancelled(String modelId) {
    if (modelId != _activeModelId) return;
    _endActivity();
  }

  static void _startLiveActivity(String modelName, int totalBytes) {
    try {
      _liveActivityChannel.invokeMethod('start', {
        'modelName': modelName,
        'totalBytes': totalBytes,
      });
    } catch (e) {
      print('Failed to start Live Activity: $e');
    }
  }

  static void _updateLiveActivity(
    double progress,
    int downloadedBytes,
    int totalBytes,
    double speed,
  ) {
    try {
      _liveActivityChannel.invokeMethod('update', {
        'progress': progress,
        'downloadedBytes': downloadedBytes,
        'totalBytes': totalBytes,
        'speed': speed,
      });
    } catch (e) {
      print('Failed to update Live Activity: $e');
    }
  }

  static void _endActivity() {
    try {
      _liveActivityChannel.invokeMethod('end');
    } catch (e) {
      print('Failed to end Live Activity: $e');
    }
    _activeModelId = null;
  }
}
