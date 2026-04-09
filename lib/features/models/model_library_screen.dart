import 'package:flutter/material.dart';
import '../../core/widgets/flux_drawer.dart';
import '../../core/widgets/model_card.dart';
import '../../constants/mock_models.dart';

class ModelLibraryScreen extends StatefulWidget {
  const ModelLibraryScreen({Key? key}) : super(key: key);

  @override
  State<ModelLibraryScreen> createState() => _ModelLibraryScreenState();
}

class _ModelLibraryScreenState extends State<ModelLibraryScreen> {
  String? _selectedCapability;
  final _searchController = TextEditingController();
  List<HFModel> _models = getMockModels();

  void _filter() {
    setState(() {
      _models = getMockModels().where((m) {
        final matchCap = _selectedCapability == null ||
            m.capabilities.contains(_selectedCapability);
        final matchSearch = _searchController.text.isEmpty ||
            m.name.toLowerCase().contains(_searchController.text.toLowerCase());
        return matchCap && matchSearch;
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Model Library'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const FluxDrawer(currentItem: NavItem.models),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search models...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => _filter(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _selectedCapability == null,
                  onSelected: () {
                    setState(() => _selectedCapability = null);
                    _filter();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Chat',
                  selected: _selectedCapability == 'chat',
                  onSelected: () {
                    setState(() => _selectedCapability = 'chat');
                    _filter();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Vision',
                  selected: _selectedCapability == 'vision',
                  onSelected: () {
                    setState(() => _selectedCapability = 'vision');
                    _filter();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Audio',
                  selected: _selectedCapability == 'audio',
                  onSelected: () {
                    setState(() => _selectedCapability = 'audio');
                    _filter();
                  },
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Tools',
                  selected: _selectedCapability == 'tools',
                  onSelected: () {
                    setState(() => _selectedCapability = 'tools');
                    _filter();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _models.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No models found',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _models.length,
                    itemBuilder: (ctx, i) => ModelCard(model: _models[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 13)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
