import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/hf_model.dart';

final downloadProvider =
    StateNotifierProvider<DownloadNotifier, List<HFModel>>((ref) {
  return DownloadNotifier();
});

class DownloadNotifier extends StateNotifier<List<HFModel>> {
  DownloadNotifier() : super([]) {
    _loadInstalledModels();
    _setupDownloader();
  }

  void _loadInstalledModels() {
    final box = Hive.box('models');
    final installed = box.values
        .map((v) => HFModel.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    state = [...state, ...installed];
  }

  void _setupDownloader() {
    FileDownloader().configure(
      globalConfig: [('requestTimeout', '2h')],
    ).then((_) {
      FileDownloader().updates.listen((update) {
        if (update is TaskProgressUpdate) {
          _updateProgress(
              update.task.taskId, update.progress, update.networkSpeed);
        } else if (update is TaskStatusUpdate) {
          if (update.status == TaskStatus.complete) {
            _markAsCompleted(update.task.taskId);
          } else if (update.status == TaskStatus.failed ||
              update.status == TaskStatus.canceled) {
            _markAsFailed(update.task.taskId);
          }
        }
      });
    });
  }

  Future<void> startDownload(HFModel model) async {
    // Legacy support or fallback
    print('Direct startDownload called, but cloud integration is disabled.');
    return;
  }

  Future<void> startDownloadWithUrl(HFModel model, String url) async {
    if (url.isEmpty) {
      print('Could not find download URL for ${model.id}');
      return;
    }

    // Ensure models directory exists
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final task = DownloadTask(
      url: url,
      filename: '${model.id.replaceAll('/', '_')}.gguf',
      directory: 'models',
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      retries: 3,
      allowPause: true,
      taskId: model.id,
      priority: 10, // High priority for faster downloading
    );

    final updatedModel = HFModel(
      id: model.id,
      name: model.name,
      description: model.description,
      sizeMB: model.sizeMB,
      speed: model.speed,
      quality: model.quality,
      capabilities: model.capabilities,
      downloadStatus: 'downloading',
      progress: 0,
    );

    if (state.any((m) => m.id == model.id)) {
      state = state.map((m) => m.id == model.id ? updatedModel : m).toList();
    } else {
      state = [...state, updatedModel];
    }

    await FileDownloader().enqueue(task);
  }

  void _updateProgress(String id, double progress, double speed) {
    state = state.map((m) {
      if (m.id == id) {
        return HFModel(
          id: m.id,
          name: m.name,
          description: m.description,
          sizeMB: m.sizeMB,
          speed: m.speed,
          quality: m.quality,
          capabilities: m.capabilities,
          downloadStatus: 'downloading',
          progress: (progress * 100).toInt(),
          downloadSpeed: speed >= 0 ? speed : (m.downloadSpeed ?? 0),
          downloadedBytes:
              ((m.totalBytes ?? (m.sizeMB * 1024 * 1024)) * progress).toInt(),
          totalBytes: m.totalBytes ?? (m.sizeMB * 1024 * 1024),
        );
      }
      return m;
    }).toList();
  }

  void _markAsCompleted(String id) async {
    final model = state.firstWhere((m) => m.id == id);
    final directory = await getApplicationDocumentsDirectory();
    final modelPath =
        '${directory.path}/models/${id.replaceAll('/', '_')}.gguf';

    // Verify file exists
    final file = File(modelPath);
    if (!await file.exists()) {
      print('ERROR: Download completed but file not found at $modelPath');
      _markAsFailed(id);
      return;
    }

    final fileSize = await file.length();
    print(
        'Download completed: $modelPath (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

    final completedModel = HFModel(
      id: model.id,
      name: model.name,
      description: model.description,
      sizeMB: model.sizeMB,
      speed: model.speed,
      quality: model.quality,
      capabilities: model.capabilities,
      downloaded: true,
      progress: 100,
      downloadStatus: 'completed',
      localPath: modelPath,
    );

    state = state.map((m) => m.id == id ? completedModel : m).toList();

    final box = Hive.box('models');
    await box.put(id, completedModel.toJson());
  }

  void _markAsFailed(String id) {
    state = state.map((m) {
      if (m.id == id) {
        return HFModel(
          id: m.id,
          name: m.name,
          description: m.description,
          sizeMB: m.sizeMB,
          speed: m.speed,
          quality: m.quality,
          capabilities: m.capabilities,
          downloadStatus: 'none',
          progress: 0,
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
    }

    final box = Hive.box('models');
    await box.delete(id);

    // Update state by resetting download info instead of just removing (so it stays in library)
    state = state
        .map((m) => m.id == id
            ? HFModel(
                id: m.id,
                name: m.name,
                description: m.description,
                sizeMB: m.sizeMB,
                speed: m.speed,
                quality: m.quality,
                capabilities: m.capabilities,
                downloadStatus: 'none',
                downloaded: false,
              )
            : m)
        .toList();
  }
}
