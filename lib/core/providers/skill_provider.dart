import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:llamadart/llamadart.dart';
import '../services/search_service.dart';
import '../services/memory_service.dart';

class Skill {
  final String id;
  final String name;
  final String description;
  final bool isEnabled;
  final bool builtIn;
  final ToolDefinition? tool;

  Skill({
    required this.id,
    required this.name,
    required this.description,
    this.isEnabled = true,
    this.builtIn = false,
    this.tool,
  });

  Skill copyWith({bool? isEnabled}) {
    return Skill(
      id: id,
      name: name,
      description: description,
      isEnabled: isEnabled ?? this.isEnabled,
      builtIn: builtIn,
      tool: tool,
    );
  }
}

class SkillNotifier extends StateNotifier<List<Skill>> {
  SkillNotifier() : super([]) {
    _load();
  }

  /// Built-in skills that map directly to model tools. These always exist;
  /// only their enabled state is persisted.
  static final List<Skill> _builtIns = [
    Skill(
      id: 'web_search',
      name: 'Web Search',
      description: 'Lets Flux search the web for real-time information. '
          'Off keeps Flux fully offline; you can still enable search per message from the chat bar.',
      isEnabled: false,
      builtIn: true,
      tool: SearchService.webSearchTool,
    ),
    Skill(
      id: 'memory',
      name: 'Memory',
      description:
          'Lets Flux remember facts and preferences about you across chats.',
      builtIn: true,
      tool: MemoryService.saveMemoryTool,
    ),
  ];

  Box get _box => Hive.box('settings');

  void _load() {
    final enabledRaw = _box.get('skills_enabled');
    final enabled = enabledRaw is Map
        ? Map<String, dynamic>.from(enabledRaw)
        : <String, dynamic>{};
    final customRaw = _box.get('custom_skills');
    final customList = customRaw is List ? customRaw : const [];

    final builtIns = _builtIns
        .map((s) =>
            s.copyWith(isEnabled: enabled[s.id] as bool? ?? s.isEnabled))
        .toList();

    final custom = customList.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final id = m['id'] as String;
      return Skill(
        id: id,
        name: m['name'] as String? ?? id,
        description: m['description'] as String? ?? '',
        isEnabled: enabled[id] as bool? ?? (m['isEnabled'] as bool? ?? true),
      );
    }).toList();

    state = [...builtIns, ...custom];
  }

  Future<void> _persist() async {
    final enabled = {for (final s in state) s.id: s.isEnabled};
    await _box.put('skills_enabled', enabled);
    final custom = state
        .where((s) => !s.builtIn)
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'description': s.description,
              'isEnabled': s.isEnabled,
            })
        .toList();
    await _box.put('custom_skills', custom);
  }

  void toggleSkill(String id) {
    state = [
      for (final skill in state)
        if (skill.id == id) skill.copyWith(isEnabled: !skill.isEnabled) else skill,
    ];
    _persist();
  }

  void addSkill(Skill skill) {
    // Avoid duplicate ids.
    if (state.any((s) => s.id == skill.id)) return;
    state = [...state, skill];
    _persist();
  }

  void removeSkill(String id) {
    state = state.where((s) => s.id != id || s.builtIn).toList();
    _persist();
  }

  /// Tools the model can call, derived from currently enabled skills.
  List<ToolDefinition> getActiveTools() {
    return state
        .where((s) => s.isEnabled && s.tool != null)
        .map((s) => s.tool!)
        .toList();
  }

  /// System-prompt guidance describing enabled custom skills (which have no
  /// tool but extend what Flux should help with).
  String getActiveSkillInstructions() {
    final custom = state.where(
        (s) => s.isEnabled && s.tool == null && s.description.trim().isNotEmpty);
    if (custom.isEmpty) return '';
    final buffer = StringBuffer('\n\nEnabled skills you should use when relevant:\n');
    for (final s in custom) {
      buffer.writeln('- ${s.name}: ${s.description}');
    }
    return buffer.toString();
  }
}

final skillProvider = StateNotifierProvider<SkillNotifier, List<Skill>>((ref) {
  return SkillNotifier();
});
