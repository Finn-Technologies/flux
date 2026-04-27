import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/animated_tap_card.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/constants/responsive.dart';

class _LicenseSummary {
  final String label;
  final IconData icon;
  final Color color;

  const _LicenseSummary({
    required this.label,
    required this.icon,
    required this.color,
  });
}

class _License {
  final String name;
  final String type;
  final String description;
  final IconData icon;
  final String fullText;
  final List<_LicenseSummary> permissions;
  final List<_LicenseSummary> limitations;
  final List<_LicenseSummary> conditions;

  const _License({
    required this.name,
    required this.type,
    required this.description,
    required this.icon,
    required this.fullText,
    required this.permissions,
    required this.limitations,
    this.conditions = const [],
  });
}

const _mitPermissions = [
  _LicenseSummary(label: 'Commercial use', icon: Icons.shopping_bag_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Modification', icon: Icons.edit_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Distribution', icon: Icons.share_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Private use', icon: Icons.lock_outlined, color: Color(0xFF2E7D32)),
];

const _mitLimitations = [
  _LicenseSummary(label: 'Liability', icon: Icons.gavel_outlined, color: Color(0xFFC62828)),
  _LicenseSummary(label: 'Warranty', icon: Icons.verified_outlined, color: Color(0xFFC62828)),
];

const _apachePermissions = [
  _LicenseSummary(label: 'Commercial use', icon: Icons.shopping_bag_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Modification', icon: Icons.edit_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Distribution', icon: Icons.share_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Patent use', icon: Icons.lightbulb_outlined, color: Color(0xFF2E7D32)),
  _LicenseSummary(label: 'Private use', icon: Icons.lock_outlined, color: Color(0xFF2E7D32)),
];

const _apacheLimitations = [
  _LicenseSummary(label: 'Liability', icon: Icons.gavel_outlined, color: Color(0xFFC62828)),
  _LicenseSummary(label: 'Warranty', icon: Icons.verified_outlined, color: Color(0xFFC62828)),
];

const _apacheConditions = [
  _LicenseSummary(label: 'License notice', icon: Icons.article_outlined, color: Color(0xFF1565C0)),
  _LicenseSummary(label: 'State changes', icon: Icons.difference_outlined, color: Color(0xFF1565C0)),
];

const _mitText = '''
MIT License

Copyright (c) 2024 Finn Technologies

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

const _apacheText = '''
Apache License
Version 2.0, January 2004
http://www.apache.org/licenses/

TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION

1. Definitions.

"License" shall mean the terms and conditions for use, reproduction,
and distribution as defined by Sections 1 through 9 of this document.

"Licensor" shall mean the copyright owner or entity authorized by
the copyright owner that is granting the License.

"Legal Entity" shall mean the union of the acting entity and all
other entities that control, are controlled by, or are under common
control with that entity.

"You" (or "Your") shall mean an individual or Legal Entity
exercising permissions granted by this License.

"Source" form shall mean the preferred form for making modifications,
including but not limited to software source code, documentation
source, and configuration files.

"Object" form shall mean any form resulting from mechanical
transformation or translation of a Source form.

"Work" shall mean the work of authorship, whether in Source or
Object form, made available under the License.

"Derivative Works" shall mean any work, whether in Source or Object
form, that is based on (or derived from) the Work.

"Contribution" shall mean any work of authorship that is intentionally
submitted to Licensor for inclusion in the Work.

"Contributor" shall mean Licensor and any individual or Legal Entity
on behalf of whom a Contribution has been received by Licensor.

2. Grant of Copyright License. Subject to the terms and conditions of
this License, each Contributor hereby grants to You a perpetual,
worldwide, non-exclusive, no-charge, royalty-free, irrevocable
copyright license to reproduce, prepare Derivative Works of,
publicly display, publicly perform, sublicense, and distribute the
Work and such Derivative Works in Source or Object form.

3. Grant of Patent License. Subject to the terms and conditions of
this License, each Contributor hereby grants to You a perpetual,
worldwide, non-exclusive, no-charge, royalty-free, irrevocable
(except as stated in this section) patent license to make, have made,
use, offer to sell, sell, import, and otherwise transfer the Work.

4. Redistribution. You may reproduce and distribute copies of the
Work or Derivative Works thereof in any medium, with or without
modifications, in Source or Object form, provided that You meet the
following conditions:

(a) You must give any other recipients of the Work or
Derivative Works a copy of this License; and

(b) You must cause any modified files to carry prominent notices
stating that You changed the files; and

(c) You must retain, in the Source form of any Derivative Works
that You distribute, all copyright, patent, trademark, and
attribution notices from the Source form of the Work; and

(d) If the Work includes a "NOTICE" text file as part of its
distribution, then any Derivative Works that You distribute must
include a readable copy of the attribution notices contained
within such NOTICE file.

5. Submission of Contributions. Unless You explicitly state otherwise,
any Contribution intentionally submitted for inclusion in the Work
by You to the Licensor shall be under the terms and conditions of
this License.

6. Trademarks. This License does not grant permission to use the trade
names, trademarks, service marks, or product names of the Licensor.

7. Disclaimer of Warranty. Unless required by applicable law or
agreed to in writing, Licensor provides the Work (and each
Contributor provides its Contributions) on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
implied.

8. Limitation of Liability. In no event and under no legal theory,
whether in tort (including negligence), contract, or otherwise,
unless required by applicable law or agreed to in writing, shall
any Contributor be liable to You for damages.

9. Accepting Warranty or Additional Liability. While redistributing
the Work or Derivative Works thereof, You may choose to offer,
and charge a fee for, acceptance of support, warranty, indemnity,
or other liability obligations and/or rights consistent with this
License.

END OF TERMS AND CONDITIONS
''';

const _licenses = [
  _License(
    name: 'Flux',
    type: 'MIT License',
    description: 'Flux itself is open source under the MIT license. '
        'You may freely use, modify, and distribute it.',
    icon: Icons.code_rounded,
    fullText: _mitText,
    permissions: _mitPermissions,
    limitations: _mitLimitations,
  ),
  _License(
    name: 'Qwen 3.5',
    type: 'Apache 2.0',
    description: 'The AI models powering Flux are GGUF-quantized versions of '
        'Qwen 3.5 by Alibaba Cloud, released under the Apache 2.0 license.',
    icon: Icons.smart_toy_outlined,
    fullText: _apacheText,
    permissions: _apachePermissions,
    limitations: _apacheLimitations,
    conditions: _apacheConditions,
  ),
];

class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final topPad = isDesktop ? 20.0 : 0.0;
    final bottomPad = isDesktop ? 24.0 : 108.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
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
                top: 100 + topPad,
                child: const FluxTitle(title: 'Licenses'),
              ),

              Positioned(
                left: 20,
                right: 20,
                top: 160 + topPad,
                bottom: bottomPad,
                child: ListView(
                  padding: EdgeInsets.zero,
                  cacheExtent: 500,
                  children: [
                    ..._licenses.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StaggeredEntrance(
                        index: entry.key,
                        child: _buildLicenseCard(context, entry.value, flux, textTheme),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLicenseCard(
    BuildContext context,
    _License license,
    FluxColorsExtension flux,
    TextTheme textTheme,
  ) {
    return AnimatedTapCard(
      onTap: () {
        HapticFeedback.lightImpact();
        _openLicense(context, license);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: flux.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: flux.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: flux.textPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(license.icon, color: flux.textPrimary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        license.name,
                        style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: flux.textPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          license.type,
                          style: textTheme.labelLarge?.copyWith(
                            fontSize: 11,
                            color: flux.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    license.description,
                    style: textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.chevron_right, size: 20, color: flux.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _openLicense(BuildContext context, _License license) {
    final page = _LicenseDetailScreen(license: license);
    final position = 0.24;

    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = Curves.easeInOutCubic;
          final size = MediaQuery.of(context).size;
          return AnimatedBuilder(
            animation: Listenable.merge([animation, secondaryAnimation]),
            builder: (context, child) {
              final thisProgress = curve.transform(animation.value);
              final secondaryProgress = curve.transform(secondaryAnimation.value);
              final thisOffset = position * (1.0 - thisProgress);
              final combinedOffset = thisOffset - (0.05 * secondaryProgress * (position > 0 ? -1 : 1));
              return Transform.translate(
                offset: Offset(combinedOffset * size.width, 0),
                child: Opacity(
                  opacity: 0.4 + (0.6 * thisProgress.clamp(0.0, 1.0)),
                  child: child,
                ),
              );
            },
            child: child,
          );
        },
      ),
    );
  }
}

class _LicenseDetailScreen extends StatelessWidget {
  final _License license;

  const _LicenseDetailScreen({required this.license});

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final topPad = isDesktop ? 20.0 : 0.0;
    final bottomPad = isDesktop ? 24.0 : 108.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: flux.background,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 20,
                top: 48 + topPad,
                child: FluxBackButton(onTap: () => Navigator.of(context).pop()),
              ),

              Positioned(
                left: 20,
                top: 100 + topPad,
                child: FluxTitle(title: license.name, subtitle: license.type),
              ),

              Positioned(
                left: 20,
                right: 20,
                top: 160 + topPad,
                bottom: bottomPad,
                child: ListView(
                  padding: EdgeInsets.zero,
                  cacheExtent: 500,
                  children: [
                    // Summary card
                    Container(
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
                          Text(
                            'Summary',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          _buildSummarySection(
                            context, flux, textTheme,
                            label: 'Permissions',
                            icon: Icons.check_circle_outlined,
                            items: license.permissions,
                          ),
                          if (license.conditions.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            _buildSummarySection(
                              context, flux, textTheme,
                              label: 'Conditions',
                              icon: Icons.info_outlined,
                              items: license.conditions,
                            ),
                          ],
                          const SizedBox(height: 14),
                          _buildSummarySection(
                            context, flux, textTheme,
                            label: 'Limitations',
                            icon: Icons.warning_amber_outlined,
                            items: license.limitations,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Full license text
                    SelectableText(
                      license.fullText,
                      style: GoogleFonts.firaCode(
                        fontSize: 13,
                        height: 1.5,
                        color: flux.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(
    BuildContext context,
    FluxColorsExtension flux,
    TextTheme textTheme, {
    required String label,
    required IconData icon,
    required List<_LicenseSummary> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: flux.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelLarge?.copyWith(
                color: flux.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: item.color.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 14, color: item.color),
                  const SizedBox(width: 5),
                  Text(
                    item.label,
                    style: textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: item.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
