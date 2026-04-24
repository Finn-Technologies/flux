import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/hf_model.dart';
import 'download_provider.dart';

final selectedModelIdProvider = StateNotifierProvider<SelectedModelIdNotifier, String?>((ref) {
  return SelectedModelIdNotifier();
});

class SelectedModelIdNotifier extends StateNotifier<String?> {
  SelectedModelIdNotifier() : super(null) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('selectedModelId');
    if (savedId != null && mounted) {
      state = savedId;
    }
  }

  Future<void> select(String? modelId) async {
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    if (modelId != null) {
      await prefs.setString('selectedModelId', modelId);
    } else {
      await prefs.remove('selectedModelId');
    }
  }
}

final selectedModelProvider = Provider<HFModel?>((ref) {
  final selectedId = ref.watch(selectedModelIdProvider);
  if (selectedId == null) return null;

  final downloadedModels = ref.watch(downloadProvider);
  for (final model in downloadedModels) {
    if (model.id == selectedId) return model;
  }
  return null;
});
