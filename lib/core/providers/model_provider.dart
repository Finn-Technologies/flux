import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hf_model.dart';
import 'download_provider.dart';

final selectedModelIdProvider = StateProvider<String?>((ref) => null);

final selectedModelProvider = Provider<HFModel?>((ref) {
  final selectedId = ref.watch(selectedModelIdProvider);
  if (selectedId == null) return null;

  final downloadedModels = ref.watch(downloadProvider);
  for (final model in downloadedModels) {
    if (model.id == selectedId) return model;
  }
  return null;
});
