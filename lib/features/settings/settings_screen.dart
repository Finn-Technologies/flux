import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/flux_drawer.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              child: Icon(Icons.settings_outlined,
                  size: 15, color: colorScheme.onPrimary),
            ),
            const SizedBox(width: 10),
            const Text('Settings',
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
      drawer: const FluxDrawer(currentItem: NavItem.settings),
      body: ListView(
        children: [
          _SectionHeader(title: 'Storage'),
          _SettingsTile(
            icon: Icons.storage_outlined,
            title: 'Storage used',
            subtitle: '2.3 GB by models',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear cache',
            subtitle: 'Remove temporary files',
            onTap: () => _confirm(context, 'Clear cache?',
                'This removes temporary files only.', 'Clear', false),
          ),
          _SettingsTile(
            icon: Icons.folder_delete_outlined,
            title: 'Delete all models',
            subtitle: 'Remove all downloaded models',
            isDestructive: true,
            onTap: () => _confirm(
              context,
              'Delete all models?',
              'This cannot be undone. You will need to re-download models to use them.',
              'Delete',
              true,
            ),
          ),
          _SectionHeader(title: 'Language'),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English',
            onTap: () => _showLanguageDialog(context, ref),
          ),
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About Flux',
            subtitle: 'Version 0.1.0',
            onTap: () => _showAboutSheet(context),
          ),
        ],
      ),
    );
  }

  void _confirm(
    BuildContext context,
    String title,
    String message,
    String action,
    bool destructive,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title),
        content: Text(message,
            style: TextStyle(color: colorScheme.onSurfaceVariant)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(action,
                style: TextStyle(
                    color:
                        destructive ? colorScheme.error : colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.smart_toy,
                    size: 32, color: colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              Text(
                'Flux',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 0.1.0',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your private AI assistant that runs locally on your device. '
                'Your data stays on your phone — no account needed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Language',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.language,
                      color: colorScheme.onPrimaryContainer),
                ),
                title: const Text('English'),
                trailing: Icon(Icons.check, color: colorScheme.primary),
                onTap: () {
                  ref.read(localeProvider.notifier).state = const Locale('en');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      Icon(Icons.language, color: colorScheme.onSurfaceVariant),
                ),
                title: const Text('Italiano'),
                onTap: () {
                  ref.read(localeProvider.notifier).state = const Locale('it');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDestructive
              ? colorScheme.error.withValues(alpha: 0.1)
              : colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isDestructive
              ? colorScheme.error
              : colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? colorScheme.error : null,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: colorScheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}
