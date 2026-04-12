import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/hf_api_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/providers/download_provider.dart';
import '../../core/providers/model_provider.dart';

class ChooseModelScreen extends ConsumerStatefulWidget {
  const ChooseModelScreen({super.key});

  @override
  ConsumerState<ChooseModelScreen> createState() => _ChooseModelScreenState();
}

class _ChooseModelScreenState extends ConsumerState<ChooseModelScreen> {
  final _apiService = HfApiService();
  List<HFModel> _models = [];
  bool _isLoading = true;
  HFModel? _selectedModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await _apiService.searchModels(query: 'Llama 3');
    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
        if (models.isNotEmpty) _selectedModel = models.first;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
        title: const Text(
          'Recommended Models',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Select a model to get started. These are optimized for your device.',
              style: TextStyle(fontSize: 15, color: colorScheme.secondary),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _models.isEmpty
                    ? _buildErrorView(colorScheme)
                    : _buildModelList(colorScheme),
          ),
          _buildFooter(colorScheme),
        ],
      ),
    );
  }

  Widget _buildModelList(ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _models.length,
      itemBuilder: (context, index) {
        final model = _models[index];
        final isSelected = _selectedModel?.id == model.id;

        return GestureDetector(
          onTap: () => setState(() => _selectedModel = model),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withValues(alpha: 0.05)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      Text(
                        '${(model.sizeMB / 1024).toStringAsFixed(1)} GB · GGUF',
                        style: TextStyle(fontSize: 13, color: colorScheme.secondary),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ),
          ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05, end: 0),
        );
      },
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 48, color: colorScheme.secondary),
          const SizedBox(height: 16),
          const Text('No models found'),
          TextButton(onPressed: _loadModels, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildFooter(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _selectedModel == null ? null : _onContinue,
              child: const Text(
                'Download & Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Large models may take a few minutes to download.',
            style: TextStyle(fontSize: 12, color: colorScheme.secondary),
          ),
        ],
      ),
    );
  }

  Future<void> _onContinue() async {
    if (_selectedModel == null) return;
    
    // Start download
    ref.read(downloadProvider.notifier).startDownload(_selectedModel!);
    ref.read(selectedModelProvider.notifier).state = _selectedModel;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    
    if (mounted) context.go('/chat');
  }
}
