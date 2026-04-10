import 'package:flutter/material.dart';
import '../../core/widgets/flux_drawer.dart';
import '../../core/widgets/model_card.dart';
import '../../constants/mock_models.dart';

class ModelLibraryScreen extends StatefulWidget {
  const ModelLibraryScreen({super.key});

  @override
  State<ModelLibraryScreen> createState() => _ModelLibraryScreenState();
}

class _ModelLibraryScreenState extends State<ModelLibraryScreen> {
  String? _capability;
  final _searchCtrl = TextEditingController();
  List<HFModel> _models = getMockModels();

  void _filter() {
    setState(() {
      _models = getMockModels().where((m) {
        final matchCap =
            _capability == null || m.capabilities.contains(_capability);
        final matchSearch = _searchCtrl.text.isEmpty ||
            m.name.toLowerCase().contains(_searchCtrl.text.toLowerCase());
        return matchCap && matchSearch;
      }).toList();
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
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.memory, size: 15, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 10),
            const Text('Model Library',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: colorScheme.onSurface),
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
              controller: _searchCtrl,
              onChanged: (_) => _filter(),
              decoration: InputDecoration(
                hintText: 'Search models…',
                prefixIcon: Icon(Icons.search,
                    size: 20, color: colorScheme.onSurfaceVariant),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 18, color: colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filter();
                        },
                      )
                    : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _FilterChip(
                    label: 'All',
                    selected: _capability == null,
                    onTap: () => _setCap(null)),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Chat',
                    selected: _capability == 'chat',
                    onTap: () => _setCap('chat')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Vision',
                    selected: _capability == 'vision',
                    onTap: () => _setCap('vision')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Audio',
                    selected: _capability == 'audio',
                    onTap: () => _setCap('audio')),
                const SizedBox(width: 6),
                _FilterChip(
                    label: 'Tools',
                    selected: _capability == 'tools',
                    onTap: () => _setCap('tools')),
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
                        Icon(Icons.search_off,
                            size: 40, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('No models found',
                            style:
                                TextStyle(color: colorScheme.onSurfaceVariant)),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color:
                selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
