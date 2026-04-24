import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/providers/download_provider.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../l10n/app_localizations.dart';

// ============================================================================
// MODEL
// ============================================================================
class Creation {
  final String id;
  final String title;
  final String html;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<Map<String, dynamic>> messages;
  final bool isPinned;
  final String? pinnedIconPath;
  final String? pinnedName;

  Creation({
    required this.id,
    required this.title,
    required this.html,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
    this.isPinned = false,
    this.pinnedIconPath,
    this.pinnedName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'html': html,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages,
    'isPinned': isPinned,
    'pinnedIconPath': pinnedIconPath,
    'pinnedName': pinnedName,
  };

  factory Creation.fromJson(Map<String, dynamic> json) => Creation(
    id: json['id'] as String,
    title: json['title'] as String,
    html: json['html'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List<dynamic>?)
            ?.map((m) => Map<String, dynamic>.from(m as Map))
            .toList() ??
        [],
    isPinned: json['isPinned'] as bool? ?? false,
    pinnedIconPath: json['pinnedIconPath'] as String?,
    pinnedName: json['pinnedName'] as String?,
  );

  Creation copyWith({
    String? id,
    String? title,
    String? html,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Map<String, dynamic>>? messages,
    bool? isPinned,
    String? pinnedIconPath,
    String? pinnedName,
  }) =>
      Creation(
        id: id ?? this.id,
        title: title ?? this.title,
        html: html ?? this.html,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        messages: messages ?? this.messages,
        isPinned: isPinned ?? this.isPinned,
        pinnedIconPath: pinnedIconPath ?? this.pinnedIconPath,
        pinnedName: pinnedName ?? this.pinnedName,
      );
}

// ============================================================================
// PROVIDER
// ============================================================================
final creationsProvider = StateNotifierProvider<CreationsNotifier, List<Creation>>((ref) => CreationsNotifier());

class CreationsNotifier extends StateNotifier<List<Creation>> {
  CreationsNotifier() : super([]) {
    _loadFromHive();
  }

  void _loadFromHive() {
    final box = Hive.box('creations');
    final items = box.values
        .map((v) => Creation.fromJson(Map<String, dynamic>.from(v)))
        .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = items;
  }

  Future<void> saveCreation(Creation creation) async {
    state = [
      creation,
      ...state.where((c) => c.id != creation.id),
    ];
    final box = Hive.box('creations');
    await box.put(creation.id, creation.toJson());
  }

  Future<void> deleteCreation(String id) async {
    state = state.where((c) => c.id != id).toList();
    final box = Hive.box('creations');
    await box.delete(id);
  }

  Future<void> togglePin(String id, {bool? isPinned, String? pinnedName, String? pinnedIconPath}) async {
    state = state.map((c) {
      if (c.id == id) {
        final updated = c.copyWith(
          isPinned: isPinned ?? !c.isPinned,
          pinnedName: pinnedName,
          pinnedIconPath: pinnedIconPath,
        );
        final box = Hive.box('creations');
        box.put(updated.id, updated.toJson());
        return updated;
      }
      return c;
    }).toList();
  }
}

// ============================================================================
// TYPOGRAPHY
// ============================================================================
class _TextStyles {
  static TextStyle title(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 25,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
        height: 1.22,
      );

  static TextStyle body(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textPrimary,
      );

  static TextStyle subtitle(BuildContext context) => GoogleFonts.instrumentSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: Theme.of(context).extension<FluxColorsExtension>()!.textSecondary,
      );
}

// ============================================================================
// MAIN COLLECTION SCREEN
// ============================================================================
class CreationsScreen extends ConsumerStatefulWidget {
  const CreationsScreen({super.key});

  @override
  ConsumerState<CreationsScreen> createState() => _CreationsScreenState();
}

class _CreationsScreenState extends ConsumerState<CreationsScreen> {
  void _showOptionsSheet(BuildContext context, Creation creation) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    showModalBottomSheet(
      context: context,
      backgroundColor: flux.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      useRootNavigator: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Text(
                  creation.title.isNotEmpty ? creation.title : 'Untitled Creation',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: flux.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const Divider(height: 25),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Delete',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showDeleteConfirmDialog(context, creation);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, Creation creation) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: flux.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Creation?',
          style: _TextStyles.body(context).copyWith(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '"${creation.title}" will be permanently removed.',
          style: _TextStyles.subtitle(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: _TextStyles.subtitle(context),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(creationsProvider.notifier).deleteCreation(creation.id);
              Navigator.pop(ctx);
              HapticFeedback.lightImpact();
            },
            child: Text(
              'Delete',
              style: GoogleFonts.instrumentSans(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(BuildContext context, Creation creation) {
    if (creation.html.isEmpty) return;
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    
    final webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(flux.background)
      ..loadHtmlString(creation.html);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (ctx) => _CreationPreviewScreen(
          webViewController: webViewController,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final creations = ref.watch(creationsProvider);
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final brightness = Theme.of(context).brightness;

    final downloaded = ref.watch(downloadProvider);
    final creativeModels = downloaded.where(
      (m) => m.id == 'flux-creative-qwen-2.5-coder-0.5b' && m.downloaded,
    );
    final creativeModel = creativeModels.isNotEmpty ? creativeModels.first : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: Stack(
          children: [
            // Title
            Positioned(
              left: 20,
              top: topPadding + 58,
              child: Text(
                AppLocalizations.of(context)!.creations,
                style: _TextStyles.title(context),
              ),
            ),

            // Content area
            Positioned(
              left: 20,
              right: 20,
              top: topPadding + 110,
              bottom: 108,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Creative install prompt (only shown when Creative is not installed)
                    if (creativeModel == null)
                      _buildCreativePrompt(context, flux),

                    if (creativeModel == null)
                      const SizedBox(height: 20),

                    // Collection grid or empty state
                    Expanded(
                      child: creations.isEmpty
                          ? _buildEmptyState(context, flux)
                          : _buildGrid(context, creations, flux),
                    ),
                  ],
                ),
              ),

            // FAB - New Creation
            if (creativeModel != null)
              Positioned(
                right: 20,
                bottom: 130,
                child: Semantics(
                  label: 'New Creation',
                  button: true,
                  child: Tooltip(
                    message: 'New Creation',
                    child: AnimatedTapCard(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/creations/editor');
                      },
                      scaleDown: 0.85,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: flux.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, color: flux.background, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildCreativePrompt(BuildContext context, FluxColorsExtension flux) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: flux.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: flux.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: flux.textPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.memory,
                  color: flux.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flux Creative Required',
                      style: GoogleFonts.instrumentSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: flux.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Install the Creative model to start creating.',
                      style: _TextStyles.subtitle(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedTapCard(
            onTap: () => context.push('/settings/models'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: flux.textPrimary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Center(
                child: Text(
                  'Install Flux Lite',
                  style: GoogleFonts.instrumentSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: flux.background,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '500 MB download',
              style: GoogleFonts.instrumentSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: flux.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, FluxColorsExtension flux) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_outlined,
            size: 48,
            color: flux.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.noCreations,
            style: GoogleFonts.instrumentSans(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: flux.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppLocalizations.of(context)!.buildFirstApp,
            style: GoogleFonts.instrumentSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: flux.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<Creation> creations, FluxColorsExtension flux) {
    final isWide = MediaQuery.of(context).size.width > 400;

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 2 : 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isWide ? 3.2 : 4.0,
      ),
      itemCount: creations.length,
      cacheExtent: 200,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, index) {
        final creation = creations[index];
        return _CreationCard(
          index: index,
          creation: creation,
          flux: flux,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/creations/editor', extra: creation.id);
          },
          onLongPress: () => _showOptionsSheet(context, creation),
          onPlayPreview: () => _showPreview(context, creation),
        );
      },
    );
  }
}

// ============================================================================
// CREATION CARD
// ============================================================================
class _CreationCard extends StatelessWidget {
  final int index;
  final Creation creation;
  final FluxColorsExtension flux;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onPlayPreview;

  const _CreationCard({
    required this.index,
    required this.creation,
    required this.flux,
    required this.onTap,
    required this.onLongPress,
    required this.onPlayPreview,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeInOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 18 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: AnimatedTapCard(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            color: flux.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: flux.border, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Visual preview area (Compact Square)
              Container(
                width: 60,
                height: double.infinity,
                color: flux.textPrimary.withValues(alpha: 0.03),
                child: Center(
                  child: Icon(
                    Icons.code_rounded,
                    size: 20,
                    color: flux.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
              ),

              // Text info (Compact)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        creation.title.isNotEmpty ? creation.title : 'Untitled',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: flux.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(creation.updatedAt),
                        style: GoogleFonts.instrumentSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: flux.textSecondary.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Play button or pin icon
              if (creation.html.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AnimatedTapCard(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onPlayPreview();
                    },
                    scaleDown: 0.85,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: flux.textPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: flux.background, size: 18),
                    ),
                  ),
                )
              else if (creation.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 14,
                    color: flux.textSecondary.withValues(alpha: 0.3),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CREATION PREVIEW SCREEN
// ============================================================================
class _CreationPreviewScreen extends StatelessWidget {
  final WebViewController webViewController;
  final VoidCallback onClose;
  const _CreationPreviewScreen({required this.webViewController, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    return Scaffold(
      backgroundColor: flux.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  AnimatedTapCard(
                    onTap: onClose,
                    scaleDown: 0.85,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: flux.border),
                      ),
                      child: Icon(Icons.close, size: 18, color: flux.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Preview',
                        style: GoogleFonts.instrumentSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: flux.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 36), // Spacer to balance the X button
                ],
              ),
            ),
            Divider(color: flux.border, height: 1, thickness: 0.5),
            // WebView
            Expanded(
              child: RepaintBoundary(
                child: WebViewWidget(controller: webViewController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
