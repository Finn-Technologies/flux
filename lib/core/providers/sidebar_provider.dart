import 'package:flutter_riverpod/flutter_riverpod.dart';

final sidebarOpenProvider = StateNotifierProvider<SidebarOpenNotifier, bool>((ref) {
  return SidebarOpenNotifier();
});

class SidebarOpenNotifier extends StateNotifier<bool> {
  SidebarOpenNotifier() : super(true);

  void toggle() {
    state = !state;
  }

  void setOpen(bool isOpen) {
    state = isOpen;
  }
}
