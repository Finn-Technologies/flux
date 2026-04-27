import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/flux_theme.dart';
import '../../l10n/app_localizations.dart';
import 'creations_screen.dart';

class CreationAppScreen extends ConsumerStatefulWidget {
  final String creationId;
  const CreationAppScreen({super.key, required this.creationId});

  @override
  ConsumerState<CreationAppScreen> createState() => _CreationAppScreenState();
}

class _CreationAppScreenState extends ConsumerState<CreationAppScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            if (mounted) setState(() => _error = error.description);
          },
        ),
      );
    _loadCreation();
  }

  void _loadCreation() {
    final creations = ref.read(creationsProvider);
    try {
      final creation = creations.firstWhere((c) => c.id == widget.creationId);
      _controller.loadHtmlString(creation.html);
    } catch (e) {
      setState(() {
        _error = AppLocalizations.of(context)!.creationNotFound;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final brightness = Theme.of(context).brightness;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white, // Most HTML apps expect a white background
        body: Stack(
          children: [
            if (_error != null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 48, color: flux.textSecondary),
                    const SizedBox(height: 16),
                    Text(_error!, style: TextStyle(color: flux.textPrimary)),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(AppLocalizations.of(context)!.goBack),
                    ),
                  ],
                ),
              )
            else
              SafeArea(
                bottom: false,
                child: WebViewWidget(controller: _controller),
              ),
            
            if (_isLoading && _error == null)
              Center(
                child: CircularProgressIndicator(color: flux.textPrimary),
              ),

            // Subtle close button for "App" feel but still allowing exit
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 20,
              child: AnimatedOpacity(
                opacity: _isLoading ? 0.0 : 0.3,
                duration: const Duration(milliseconds: 500),
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 16, color: Colors.black),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
