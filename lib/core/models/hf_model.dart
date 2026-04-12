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
  String? localPath;
  String? downloadStatus; // 'none', 'downloading', 'paused', 'completed'
  double? downloadSpeed; // in MB/s
  int? downloadedBytes;
  int? totalBytes;

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
    this.localPath,
    this.downloadStatus = 'none',
    this.downloadSpeed,
    this.downloadedBytes,
    this.totalBytes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sizeMB': sizeMB,
    'speed': speed,
    'quality': quality,
    'capabilities': capabilities,
    'downloaded': downloaded,
    'progress': progress,
    'localPath': localPath,
    'downloadStatus': downloadStatus,
    'downloadSpeed': downloadSpeed,
    'downloadedBytes': downloadedBytes,
    'totalBytes': totalBytes,
  };

  factory HFModel.fromJson(Map<String, dynamic> json) => HFModel(
    id: json['id'],
    name: json['name'],
    description: json['description'],
    sizeMB: json['sizeMB'],
    speed: json['speed'],
    quality: json['quality'],
    capabilities: List<String>.from(json['capabilities']),
    downloaded: json['downloaded'] ?? false,
    progress: json['progress'] ?? 0,
    localPath: json['localPath'],
    downloadStatus: json['downloadStatus'] ?? 'none',
    downloadSpeed: (json['downloadSpeed'] as num?)?.toDouble(),
    downloadedBytes: json['downloadedBytes'],
    totalBytes: json['totalBytes'],
  );
}
