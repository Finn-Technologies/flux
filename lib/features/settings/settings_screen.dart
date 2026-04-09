import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/widgets/flux_drawer.dart';

final localeProvider = StateProvider<Locale>((ref) => const Locale('en'));

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
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
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.delete_outline,
            title: 'Clear cache',
            subtitle: 'Remove temporary files',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showConfirmDialog(
              context,
              title: 'Clear cache?',
              message: 'This will remove temporary files only.',
              confirmLabel: 'Clear',
              onConfirm: () {},
            ),
          ),
          _SettingsTile(
            icon: Icons.folder_delete_outlined,
            title: 'Delete all models',
            subtitle: 'Remove all downloaded models',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showConfirmDialog(
              context,
              title: 'Delete all models?',
              message:
                  'This cannot be undone. You will need to re-download models to use them.',
              confirmLabel: 'Delete',
              isDestructive: true,
              onConfirm: () {},
            ),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: 'Language'),
          _SettingsTile(
            icon: Icons.language_outlined,
            title: 'Language',
            subtitle: 'English',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, ref),
          ),
          const SizedBox(height: 8),
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline,
            title: 'About Flux',
            subtitle: 'Version 0.1.0',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Flux',
                applicationVersion: '0.1.0',
                applicationIcon:
                    Icon(Icons.smart_toy, size: 48, color: colorScheme.primary),
                children: [
                  const Text(
                    'Flux is your private AI assistant that runs locally on your device. '
                    'Your data stays on your phone — no account needed.',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(
              confirmLabel,
              style: TextStyle(color: isDestructive ? colorScheme.error : null),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: 'en',
              onChanged: (_) {
                ref.read(localeProvider.notifier).state = const Locale('en');
                Navigator.pop(ctx);
              },
            ),
            RadioListTile<String>(
              title: const Text('Italiano'),
              value: 'it',
              groupValue: 'en',
              onChanged: (_) {
                ref.read(localeProvider.notifier).state = const Locale('it');
                Navigator.pop(ctx);
              },
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
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
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: colorScheme.onPrimaryContainer),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
