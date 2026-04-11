class HFModel {
  final String id;
  final String name;
  final String description;
  final int sizeMB;
  final double speed;
  final double quality;
  final List<String> capabilities;
  bool downloaded;
  int progress;

  HFModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeMB,
    required this.speed,
    required this.quality,
    required this.capabilities,
    this.downloaded = false,
    this.progress = 0,
  });
}
