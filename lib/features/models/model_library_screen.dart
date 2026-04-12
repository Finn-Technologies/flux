import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/widgets/model_card.dart';
import '../../core/services/hf_api_service.dart';

class ModelLibraryScreen extends StatefulWidget {
  const ModelLibraryScreen({super.key});

  @override
  State<ModelLibraryScreen> createState() => _ModelLibraryScreenState();
}

class _ModelLibraryScreenState extends State<ModelLibraryScreen> {
  String? _capability;
  final _searchCtrl = TextEditingController();
  final _apiService = HfApiService();
  List<dynamic> _models = [];

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  int _searchId = 0;

  Future<void> _loadModels() async {
    final models = await _apiService.searchModels(
      query: _searchCtrl.text,
      capability: _capability,
    );
    setState(() {
      _models = models;
    });
  }

  void _filter() {
    final id = ++_searchId;
    Future.delayed(const Duration(milliseconds: 500), () {
      if (id == _searchId && mounted) {
        _loadModels();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _filter(),
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search models…',
                prefixIcon: Icon(
                  Icons.search,
                  size: 22,
                  color: colorScheme.secondary,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 20,
                          color: colorScheme.secondary,
                        ),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _capability == null,
                  onTap: () => _setCap(null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Chat',
                  selected: _capability == 'chat',
                  onTap: () => _setCap('chat'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _models.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No models found',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _models.length,
                    itemBuilder: (ctx, i) => ModelCard(model: _models[i])
                        .animate()
                        .fadeIn(delay: (i * 40).ms, duration: 300.ms)
                        .slideX(
                          begin: 0.03,
                          end: 0,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
          ),
        ],
      ),
    );
  }

  void _setCap(String? cap) {
    setState(() => _capability = cap);
    _filter();
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: selected ? colorScheme.onPrimary : colorScheme.secondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
