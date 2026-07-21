import 'dart:io';

import 'model_service.dart';

/// Detects the device's performance tier so the UI can scale expensive,
/// always-on visual effects down on low-end hardware.
///
/// Continuous full-screen animations (the aurora backdrop, the onboarding
/// aura, etc.) repaint every frame for the entire lifetime of the screen.
/// On low-tier devices that constant cost starves the frame pipeline, which is
/// exactly why interactive animations "sometimes don't play" and why scrolling
/// and streaming feel janky. By detecting low-end devices once at startup we
/// can keep those backdrops static there while leaving them fully animated on
/// capable hardware.
class PerformanceService {
  PerformanceService._();
  static final PerformanceService instance = PerformanceService._();

  bool _initialized = false;
  bool _isLowEnd = false;
  bool _isConstrained = false;
  int _deviceRamGb = 0;

  /// Whether this device should avoid continuous/expensive animations.
  /// Returns `false` until [init] has completed.
  bool get isLowEnd => _isLowEnd;

  /// Mobile hardware where continuous full-screen effects should be avoided,
  /// while short interaction and navigation animations remain enabled.
  bool get isConstrained => _isConstrained;

  int get deviceRamGb => _deviceRamGb;

  bool get initialized => _initialized;

  /// Resolve the device tier. Safe to call multiple times; only the first call
  /// does any work. Should be awaited once during app bootstrap.
  Future<void> init() async {
    if (_initialized) return;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final ram = await ModelService.getDeviceRAM();
        _deviceRamGb = ram;
        // 4 GB or less of RAM is our "low tier" threshold. These devices also
        // tend to ship weaker GPUs/CPUs, so we treat them conservatively.
        _isLowEnd = ram <= 4;
        _isConstrained = ram <= 8;
      } else {
        // Desktop platforms have ample resources.
        _isLowEnd = false;
        _isConstrained = false;
      }
    } catch (_) {
      // If detection fails, assume low-end so cheap hardware still benefits.
      _isLowEnd = true;
      _isConstrained = true;
    }
    _initialized = true;
  }
}
