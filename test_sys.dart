import 'package:system_info_plus/system_info_plus.dart';
void main() async {
  print(await SystemInfoPlus.physicalMemory);
}
