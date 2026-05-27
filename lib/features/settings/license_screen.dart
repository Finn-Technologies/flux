import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../core/constants/responsive.dart';
import 'licenses.dart';

class LicenseScreen extends StatelessWidget {
  final String id;
  const LicenseScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final topPad = isDesktop ? 20.0 : 0.0;

    final entry = FluxLicenses.byId(id);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 48 + topPad,
                child: FluxBackButton(onTap: () => context.pop()),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 100 + topPad,
                child: BouncyFadeSlide(
                  delay: FluxDurations.staggerStep,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FluxTitle(title: entry?.name ?? 'License'),
                      ),
                      if (entry != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: flux.textPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            entry.type,
                            style: textTheme.labelLarge?.copyWith(
                              color: flux.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                top: 160 + topPad,
                bottom: 24,
                child: BouncyFadeSlide(
                  delay: FluxDurations.staggerStep * 2,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: flux.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: flux.border, width: 1),
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: SelectableText(
                        (entry?.text ?? 'Unknown license.').trim(),
                        style: GoogleFonts.firaCode(
                          fontSize: 12.5,
                          height: 1.55,
                          color: flux.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
