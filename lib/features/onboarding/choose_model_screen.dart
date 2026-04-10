import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/mock_models.dart';
import '../../core/widgets/model_card.dart';

class ChooseModelScreen extends StatelessWidget {
  const ChooseModelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final models = getMockModels();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a model'),
        automaticallyImplyLeading: true,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        color: colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Recommended',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Gemma 4 E2B',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fast, compact, and great for chat. Auto-quantized to ~2.2 GB.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarded', true);
                      if (context.mounted) context.go('/home');
                    },
                    child: const Text('Install & Continue'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All models',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: models.length,
              itemBuilder: (ctx, i) => ModelCard(
                model: models[i],
                onInstall: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarded', true);
                  if (ctx.mounted) context.go('/home');
                },
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('onboarded', true);
                    if (context.mounted) context.go('/home');
                  },
                  child: const Text('Continue without installing'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
