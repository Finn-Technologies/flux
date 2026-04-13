import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/chat/chat_screen.dart';

enum NavItem { chat, models, downloads, settings }

class FluxDrawer extends ConsumerWidget {
  final NavItem currentItem;
  const FluxDrawer({super.key, required this.currentItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final size = MediaQuery.of(context).size;

    return Drawer(
      width: size.width * 0.82,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.smart_toy,
                        color: colorScheme.onPrimary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Flux',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Private & offline',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonal(
                onPressed: () {
                  ref.read(chatMessagesProvider.notifier).clear();
                  Navigator.pop(context);
                  context.go('/home');
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 6),
                    Text('New Chat'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Recent',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            _RecentChatItem(
                title: 'Explain quantum computing',
                time: '2m ago',
                onTap: () => _go(context, '/home')),
            _RecentChatItem(
                title: 'Write a Python script',
                time: '15m ago',
                onTap: () => _go(context, '/home')),
            _RecentChatItem(
                title: 'Summarize an article',
                time: '1h ago',
                onTap: () => _go(context, '/home')),
            const SizedBox(height: 12),
            Divider(
                indent: 20, endIndent: 20, color: colorScheme.outlineVariant),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Navigate',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            _DrawerItem(
              icon: Icons.widgets_outlined,
              label: 'Model Library',
              selected: currentItem == NavItem.models,
              onTap: () => _go(context, '/models'),
            ),
            _DrawerItem(
              icon: Icons.download_outlined,
              label: 'Downloads',
              selected: currentItem == NavItem.downloads,
              onTap: () => _go(context, '/downloads'),
            ),
            const Spacer(),
            Divider(
                indent: 20, endIndent: 20, color: colorScheme.outlineVariant),
            const SizedBox(height: 4),
            _DrawerItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: currentItem == NavItem.settings,
              onTap: () => _go(context, '/settings'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pop(context);
    context.go(route);
  }
}

class _RecentChatItem extends StatelessWidget {
  final String title;
  final String time;
  final VoidCallback onTap;

  const _RecentChatItem({
    required this.title,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: ListTile(
        dense: true,
        leading: Icon(
          Icons.chat_bubble_outline,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(time,
            style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: onTap,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 20,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? colorScheme.primary : colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: selected,
        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        onTap: onTap,
      ),
    );
  }
}
