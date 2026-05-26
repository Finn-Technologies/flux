import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hf_model.dart';
import '../services/model_service.dart';
import '../services/download_notification_service.dart';

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<HFModel>>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<List<HFModel>> {
  StreamSubscription? _downloadSubscription;

  DownloadNotifier() : super([]) {
    _loadInstalledModels();
    _setupDownloader();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _loadInstalledModels() {
    final box = Hive.box('models');
    final hived = box.values
        .map((v) => HFModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    final hivedIds = hived.map((m) => m.id).toSet();
    // Update existing state entries with Hive data, add any new ones
    state = [
      for (final m in state)
        if (hivedIds.contains(m.id))
          hived.firstWhere((h) => h.id == m.id)
        else
          m,
      ...hived.where((h) => !state.any((m) => m.id == h.id)),
    ];
  }



  Future<void> _setupDownloader() async {
    try {
      // Ensure the temporary cache directory exists on macOS
      // (background_downloader uses getTemporaryDirectory() which does not
      // auto-create the directory on macOS sandbox)
      try {
        final cacheDir = await getApplicationCacheDirectory();
        if (!await cacheDir.exists()) {
          await cacheDir.create(recursive: true);
        }
      } catch (_) {}
      
      final configured = await FileDownloader().configure(
        globalConfig: [('requestTimeout', const Duration(hours: 2))],
      );
      print('Downloader configured: $configured');
      _downloadSubscription = FileDownloader().updates.listen((update) {
        if (update is TaskProgressUpdate) {
          _updateProgress(
              update.task.taskId, update.progress, update.networkSpeed);
        } else if (update is TaskStatusUpdate) {
          print('Download status: ${update.status} for ${update.task.taskId}');
          if (update.status == TaskStatus.complete) {
            _markAsCompleted(update.task.taskId);
          } else if (update.status == TaskStatus.failed ||
              update.status == TaskStatus.canceled) {
            _markAsFailed(update.task.taskId, update.exception?.toString());
          }
        }
      });
    } catch (e, stack) {
      print('ERROR: Failed to configure downloader: $e\n$stack');
    }
  }



  Future<void> startDownloadWithUrl(HFModel model, String url) async {
    if (url.isEmpty) {
      print('Could not find download URL for ${model.id}');
      return;
    }

    print('Starting download for ${model.id}: $url');

    // Ensure models directory exists
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final filename = '${model.id.replaceAll('/', '_')}.gguf';
    final task = DownloadTask(
      url: url,
      filename: filename,
      directory: 'models',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      taskId: model.id,
      displayName: model.name,
      priority: 10, // High priority for faster downloading
    );

    // Preserve existing progress if resuming, otherwise start at 0
    final currentProgress = model.progress;
    final updatedModel = model.copyWith(
      downloadStatus: 'downloading',
      progress: currentProgress,
    );

    if (state.any((m) => m.id == model.id)) {
      state = state.map((m) => m.id == model.id ? updatedModel : m).toList();
    } else {
      state = [...state, updatedModel];
    }

    final enqueued = await FileDownloader().enqueue(task);
    print('Download task enqueued for ${model.id}: $enqueued (file: $filename)');
    if (enqueued) {
      DownloadNotificationService.onDownloadStart(
        model.id,
        model.name,
        model.totalBytes ?? (model.sizeMB * 1024 * 1024).toInt(),
      );
    }
    if (!enqueued) {
      state = state.map((m) {
        if (m.id == model.id) {
          return m.copyWith(
            downloadStatus: 'error',
            progress: 0,
            errorMessage: 'Failed to start download. Check network connection.',
          );
        }
        return m;
      }).toList();
    }
  }

  void _updateProgress(String id, double progress, double speed) {
    // Clamp progress between 0 and 1 to avoid negative or >100% values
    final clampedProgress = progress.clamp(0.0, 1.0);
    state = state.map((m) {
      if (m.id == id) {
        final totalBytes = m.totalBytes ?? (m.sizeMB * 1024 * 1024);
        final downloadedBytes = (totalBytes * clampedProgress).toInt();

        DownloadNotificationService.onProgressUpdate(
          id,
          clampedProgress,
          speed >= 0 ? speed : (m.downloadSpeed ?? 0),
          downloadedBytes,
          totalBytes.toInt(),
        );

        return m.copyWith(
          downloadStatus: 'downloading',
          progress: (clampedProgress * 100).toInt(),
          downloadSpeed: speed >= 0 ? speed : (m.downloadSpeed ?? 0),
          downloadedBytes: downloadedBytes,
          totalBytes: totalBytes.toInt(),
        );
      }
      return m;
    }).toList();
  }

  void _markAsCompleted(String id) async {
    final matches = state.where((m) => m.id == id);
    if (matches.isEmpty) return;
    final model = matches.first;
    final directory = await getApplicationDocumentsDirectory();
    final modelPath =
        '${directory.path}/models/${id.replaceAll('/', '_')}.gguf';

    // Verify file exists
    final file = File(modelPath);
    if (!await file.exists()) {
      print('ERROR: Download completed but file not found at $modelPath');
      _markAsFailed(id, 'Download file not found. Please try again.');
      return;
    }

    final fileSize = await file.length();
    print(
        'Download completed: $modelPath (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

    DownloadNotificationService.onDownloadComplete(id);

    final completedModel = model.copyWith(
      downloaded: true,
      progress: 100,
      downloadStatus: 'completed',
      localPath: modelPath,
    );

    state = state.map((m) => m.id == id ? completedModel : m).toList();

    final box = Hive.box('models');
    await box.put(id, completedModel.toJson());

    // Download multimodal projector (mmproj) for vision models
    final mmprojUrl = ModelService.getMmprojUrl(id);
    if (mmprojUrl != null) {
      final mmprojTask = DownloadTask(
        url: mmprojUrl,
        filename: '${id.replaceAll('/', '_')}.mmproj',
        directory: 'models',
        baseDirectory: BaseDirectory.applicationDocuments,
        retries: 3,
        allowPause: true,
        taskId: '${id}_mmproj',
      );
      try {
        await FileDownloader().enqueue(mmprojTask);
      } catch (e) {
        print('Mmproj download error for $id: $e');
      }
    }
  }

  void _markAsFailed(String id, [String? error]) {
    print('Download failed for $id: ${error ?? 'unknown error'}');
    DownloadNotificationService.onDownloadError(id);
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          downloadStatus: 'error',
          progress: 0,
          errorMessage: error ?? 'Download failed. Tap to retry.',
        );
      }
      return m;
    }).toList();
  }

  Future<void> deleteModel(String id) async {
    final modelIndex = state.indexWhere((m) => m.id == id);
    if (modelIndex == -1) return;

    final model = state[modelIndex];
    if (model.localPath != null) {
      final file = File(model.localPath!);
      if (await file.exists()) {
        await file.delete();
        print('Deleted model file: ${model.localPath}');
      }
      // Also delete the mmproj if it exists
      final mmprojFile = File(model.localPath!.replaceAll('.gguf', '.mmproj'));
      if (await mmprojFile.exists()) {
        await mmprojFile.delete();
        print('Deleted mmproj file: ${mmprojFile.path}');
      }
    }

    final box = Hive.box('models');
    await box.delete(id);

    // Update state by resetting download info instead of just removing (so it stays in library)
    state = state
        .map((m) => m.id == id
            ? m.copyWith(
                downloadStatus: 'none',
                downloaded: false,
                localPath: null,
                progress: 0,
              )
            : m)
        .toList();
  }

  /// Clear error state before retrying download
  void clearError(String id) {
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          downloadStatus: 'none',
          errorMessage: null,
          progress: 0,
          clearError: true,
        );
      }
      return m;
    }).toList();
  }

  /// Cancel a downloading model
  Future<void> cancelDownload(String id) async {
    DownloadNotificationService.onDownloadCancelled(id);
    // Cancel the download task
    await FileDownloader().cancelTaskWithId(id);
    
    // Reset state
    state = state.map((m) {
      if (m.id == id) {
        return m.copyWith(
          downloadStatus: 'none',
          progress: 0,
          downloadSpeed: 0,
        );
      }
      return m;
    }).toList();
    
    // Clean up any partial file
    final directory = await getApplicationDocumentsDirectory();
    final partialFile = File('${directory.path}/models/${id.replaceAll('/', '_')}.gguf');
    if (await partialFile.exists()) {
      await partialFile.delete();
    }
  }
}
