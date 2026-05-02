import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_version.dart';
import '../../core/theme/flux_theme.dart';
import '../../core/widgets/flux_widgets.dart';
import '../../core/widgets/flux_animations.dart';
import '../../core/constants/responsive.dart';
import '../../l10n/app_localizations.dart';

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
include a copy of the attribution notices contained within
such NOTICE file.

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

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _scrollController = ScrollController();
  double _topFadeOpacity = 0.0;
  double _bottomFadeOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
        setState(() => _bottomFadeOpacity = 1.0);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final top = offset > 0 ? 1.0 : 0.0;
    final bottom = maxExtent > 0 && offset < maxExtent ? 1.0 : 0.0;

    if (top != _topFadeOpacity || bottom != _bottomFadeOpacity) {
      setState(() {
        _topFadeOpacity = top;
        _bottomFadeOpacity = bottom;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flux = Theme.of(context).extension<FluxColorsExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final isDesktop = context.isDesktop;
    final topPad = isDesktop ? 20.0 : 0.0;
    final bottomPad = isDesktop ? 24.0 : 69.0;

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
                child: const FluxTitle(title: 'About'),
              ),

              Positioned(
                left: 20,
                right: 20,
                top: 143 + topPad,
                bottom: bottomPad,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 20),
                        cacheExtent: 500,
                        physics: const BouncingScrollPhysics(),
                        children: [
                          // App icon and info
                          BouncyFadeSlide(
                            delay: FluxDurations.staggerStep * 0,
                            child: Column(
                              children: [
                                Image.asset(
                                  'assets/icon/app_icon.png',
                                  width: 96,
                                  height: 96,
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  'Flux',
                                  style: textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${AppLocalizations.of(context)!.version} ${AppVersion.version}',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: flux.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  AppLocalizations.of(context)!.yourPrivateAI,
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyLarge?.copyWith(
                                    color: flux.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Description
                          BouncyFadeSlide(
                            delay: FluxDurations.staggerStep * 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      size: 20,
                                      color: flux.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'About Flux',
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Flux is your private AI assistant that runs entirely on your device. '
                                  'No data is sent to the cloud, ensuring complete privacy and security. '
                                  'Powered by state-of-the-art open-source models, Flux brings '
                                  'intelligent conversation to your fingertips while keeping '
                                  'your data local and secure.',
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: flux.textSecondary,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // Features
                          BouncyFadeSlide(
                            delay: FluxDurations.staggerStep * 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.star_outline,
                                      size: 20,
                                      color: flux.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Key Features',
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildFeatureItem(
                                  context,
                                  flux,
                                  textTheme,
                                  icon: Icons.security,
                                  title: '100% Private',
                                  description: 'All processing happens on your device',
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureItem(
                                  context,
                                  flux,
                                  textTheme,
                                  icon: Icons.offline_bolt,
                                  title: 'Works Offline',
                                  description: 'No internet connection required',
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureItem(
                                  context,
                                  flux,
                                  textTheme,
                                  icon: Icons.memory,
                                  title: 'Local Models',
                                  description: 'Powered by open-source AI models',
                                ),
                                const SizedBox(height: 12),
                                _buildFeatureItem(
                                  context,
                                  flux,
                                  textTheme,
                                  icon: Icons.devices,
                                  title: 'Cross-Platform',
                                  description: 'Available on mobile, tablet, and desktop',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 40),

                          // License info
                          BouncyFadeSlide(
                            delay: FluxDurations.staggerStep * 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.description_outlined,
                                      size: 20,
                                      color: flux.textSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Licenses',
                                      style: textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                BouncyTap(
                                  onTap: () => _showLicense(context, 'Flux', 'MIT License', _mitText, flux, textTheme),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: flux.textPrimary.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: flux.border.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Flux',
                                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'MIT License',
                                                style: textTheme.bodySmall?.copyWith(color: flux.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, size: 18, color: flux.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                BouncyTap(
                                  onTap: () => _showLicense(context, 'Qwen 3.5', 'Apache 2.0', _apacheText, flux, textTheme),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: flux.textPrimary.withValues(alpha: 0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: flux.border.withValues(alpha: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Qwen 3.5',
                                                style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Apache 2.0',
                                                style: textTheme.bodySmall?.copyWith(color: flux.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.chevron_right, size: 18, color: flux.textSecondary),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        ],
                      ),
                    ),
                    // Top fade overlay (appears on scroll)
                    if (_topFadeOpacity > 0)
                      Positioned(
                        top: -15,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  flux.background,
                                  flux.background,
                                  flux.background.withValues(alpha: 0),
                                ],
                                stops: const [0.0, 0.3, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Bottom fade overlay
                    if (_bottomFadeOpacity > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 50,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  flux.background,
                                  flux.background,
                                  flux.background.withValues(alpha: 0),
                                ],
                                stops: const [0.0, 0.3, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLicense(BuildContext context, String name, String type, String fullText, FluxColorsExtension flux, TextTheme textTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: flux.surface,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: flux.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Text(
                    name,
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: flux.textPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      type,
                      style: textTheme.labelLarge?.copyWith(
                        fontSize: 11,
                        color: flux.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    fullText.trim(),
                    style: GoogleFonts.firaCode(
                      fontSize: 13,
                      height: 1.5,
                      color: flux.textPrimary,
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

  Widget _buildFeatureItem(
    BuildContext context,
    FluxColorsExtension flux,
    TextTheme textTheme, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: flux.textPrimary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: flux.textPrimary.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: flux.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
