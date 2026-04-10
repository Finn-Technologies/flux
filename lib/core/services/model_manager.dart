import '../../constants/mock_models.dart';

class ModelManager {
  // TODO: Replace with real model management using llama.cpp / fllama.
  // Responsibilities:
  //   - Track installed models (persisted via Hive/Isar)
  //   - Filter models by device compatibility (RAM, free storage)
  //   - Trigger background downloads via background_downloader
  //   - Pause / resume / cancel downloads
  //   - Auto-select best quantization (Q4_K_M, Q5_K_S, etc.)

  Future<List<HFModel>> getCompatibleModels(
      {int? deviceRamGB, int? freeStorageMB}) async {
    // TODO: Wire to real device info via device_info_plus and path_provider
    // TODO: Replace with real HF API to fetch compatible models
    return [];
  }

  Future<void> downloadModel(HFModel model) async {
    // TODO: backgroundDownloader.enqueue(url: '...', savedName: '${model.id}.bin', directory: 'models/')
  }

  Future<void> pauseDownload(HFModel model) async {}
  Future<void> resumeDownload(HFModel model) async {}

  Future<void> deleteModel(HFModel model) async {
    // TODO: Cancel download, delete files, remove Hive/Isar entry
  }

  Future<int> getUsedStorageMB() async {
    // TODO: Calculate actual storage used by models directory
    return 0;
  }

  Future<int> getFreeStorageMB() async {
    // TODO: Get actual free storage from path_provider
    return 0;
  }
}
