import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/model_service.dart';
import '../../core/models/hf_model.dart';
import '../../core/widgets/model_card.dart';

class ModelLibraryScreen extends StatefulWidget {
  const ModelLibraryScreen({super.key});

  @override
  State<ModelLibraryScreen> createState() => _ModelLibraryScreenState();
}

class _ModelLibraryScreenState extends State<ModelLibraryScreen> {
  List<HFModel> _models = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    final models = await ModelService.getRecommendedModels();
    if (mounted) {
      setState(() {
        _models = models;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Model Library',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Optimized models available for your device.',
              style: TextStyle(fontSize: 14, color: colorScheme.secondary),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _models.length,
                    itemBuilder: (ctx, i) => ModelCard(model: _models[i])
                        .animate()
                        .fadeIn(delay: (i * 100).ms, duration: 350.ms)
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                  ),
          ),
        ],
      ),
    );
  }
}
