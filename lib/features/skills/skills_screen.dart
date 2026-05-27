import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/skill_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skills = ref.watch(skillProvider);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: flux.background,
      body: Stack(
        children: [
          Positioned(
            left: 20,
            top: topPadding + 48,
            child: FluxBackButton(onTap: () => context.pop()),
          ),
          Positioned(
            left: 20,
            top: topPadding + 100,
            child: const FluxTitle(
              title: "Skills",
              subtitle: "Capabilities Flux can use during chat",
            ),
          ),
          Positioned.fill(
            top: topPadding + 150,
            left: 20,
            right: 20,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: skills.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) return const _SectionLabel(label: 'Your Skills');
                if (index == 1) return const SizedBox(height: 12);
                final skillIndex = index - 2;
                final skill = skills[skillIndex];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: BouncyFadeSlide(
                    delay: Duration(milliseconds: skillIndex * 50),
                    child: _SkillTile(skill: skill),
                  ),
                );
              },
            ),
          ),

          // Create Skill FAB
          Positioned(
            right: 24,
            bottom: 40 + MediaQuery.of(context).padding.bottom,
            child: BouncyTap(
              onTap: () => _showCreateSkillDialog(context, ref),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: flux.surface,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: flux.textPrimary, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateSkillDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: flux.surface,
        shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(999)),
        title: const Text("Create New Skill"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Skill Name (e.g. Weather)"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(hintText: "Description (How to use it)"),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(skillProvider.notifier).addSkill(
                  Skill(
                    id: nameController.text.toLowerCase().replaceAll(' ', '_'),
                    name: nameController.text,
                    description: descController.text,
                  ),
                );
                Navigator.pop(context);
              }
            },
            child: const Text("Create"),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        label.toUpperCase(),
        style: textTheme.labelLarge?.copyWith(
          color: flux.textSecondary,
          letterSpacing: 1.4,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SkillTile extends ConsumerWidget {
  final Skill skill;
  const _SkillTile({required this.skill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        ref.read(skillProvider.notifier).toggleSkill(skill.id);
      },
      scaleDown: 0.97,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: flux.surface,
            borderRadius: BorderRadius.circular(999),
          ),
        child: Row(
          children: [
            _StickerChip(
              icon: _getIconForSkill(skill.id),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.name,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skill.description,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: skill.isEnabled,
              activeTrackColor: flux.textPrimary,
              onChanged: (_) {
                HapticFeedback.lightImpact();
                ref.read(skillProvider.notifier).toggleSkill(skill.id);
              },
            ),
          ],
        ),
      ),
    );
  }


  IconData _getIconForSkill(String id) {
    switch (id) {
      case 'web_search': return Icons.search_rounded;
      case 'creations': return Icons.auto_awesome_mosaic_rounded;
      default: return Icons.extension_rounded;
    }
  }
}

class _StickerChip extends StatelessWidget {
  final IconData icon;

  const _StickerChip({required this.icon});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: flux.textPrimary.withValues(alpha: 0.05),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: flux.textPrimary),
    );
  }
}
