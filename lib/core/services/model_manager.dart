import '../../constants/mock_models.dart';

class ModelManager {
  // TODO: Replace with real model management using llama.cpp / fllama.
  // Responsibilities:
  //   - Track installed models (persisted via Hive/Isar)
  //   - Filter models by device compatibility (RAM, free storage)
  //   - Trigger background downloads via background_downloader
  //   - Pause / resume / cancel downloads
  //   - Auto-select best quantization (Q4_K_M, Q5_K_S, etc.)

  static const int defaultRamGB = 6;

  Future<List<HFModel>> getCompatibleModels({
    int? deviceRamGB,
    int? freeStorageMB,
  }) async {
    // TODO: Wire to real device info via:
    //   - device_info_plus: for device RAM
    //   - path_provider + Stat: for free storage
    final ram = deviceRamGB ?? defaultRamGB;
    final free = freeStorageMB ?? 8000;

    // Mock: filter out models that need > 1.5x available RAM or > available storage
    final all = getMockModels();
    return all.where((m) {
      final ramNeededMB = (ram * 1024 * 0.6).round();
      return m.sizeMB <= free && m.sizeMB <= ramNeededMB;
    }).toList();
  }

  Future<void> downloadModel(HFModel model) async {
    // TODO: Use background_downloader to download model files.
    //   1. Enqueue task: backgroundDownloader.enqueue(
    //        url: 'https://huggingface.co/${model.id}/resolve/main/...',
    //        savedName: '${model.id}.bin',
    //        directory: 'models/',
    //      );
    //   2. Track progress via backgroundDownloaderupdates stream.
    //   3. On complete, persist model metadata to Hive/Isar.
    await Future.delayed(const Duration(seconds: 1));
  }

  Future<void> pauseDownload(HFModel model) async {
    // TODO: backgroundDownloader.pause(model.downloadTaskId);
  }

  Future<void> resumeDownload(HFModel model) async {
    // TODO: backgroundDownloader.resume(model.downloadTaskId);
  }

  Future<void> deleteModel(HFModel model) async {
    // TODO: backgroundDownloader.cancel(model.downloadTaskId);
    // TODO: Delete local files + Hive/Isar entry.
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<int> getUsedStorageMB() async {
    // TODO: Sum sizes of all installed model files on disk.
    await Future.delayed(const Duration(milliseconds: 100));
    return 2300;
  }

  Future<int> getFreeStorageMB() async {
    // TODO: Use path_provider + Platform info to query free space.
    await Future.delayed(const Duration(milliseconds: 100));
    return 8000;
  }
}
