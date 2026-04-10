class HFModel {
  final String id;
  final String name;
  final String description;
  final int sizeMB; // approximate download size
  final double speed; // 0-1, higher is faster
  final double quality; // 0-1, higher is better
  final List<String> capabilities; // e.g. chat, vision, audio
  bool downloaded;
  int progress; // 0-100

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

List<HFModel> getMockModels() {
  return [
    HFModel(
      id: 'gemma4e2b',
      name: 'Gemma 4 E2B',
      description: 'Optimized for chat with great throughput on mobile.',
      sizeMB: 2300,
      speed: 0.9,
      quality: 0.9,
      capabilities: ['chat'],
    ),
    HFModel(
      id: 'phi3mini',
      name: 'Phi-3-mini',
      description: 'Compact, good balance for quick tasks.',
      sizeMB: 1100,
      speed: 0.8,
      quality: 0.75,
      capabilities: ['chat'],
    ),
    HFModel(
      id: 'llama3_2_3b',
      name: 'Llama 3.2 3B',
      description: 'General purpose model with decent memory footprint.',
      sizeMB: 3200,
      speed: 0.75,
      quality: 0.8,
      capabilities: ['chat', 'tools'],
    ),
    HFModel(
      id: 'nebula6b',
      name: 'Nebula-6B',
      description: 'Solid for offline Q&A and reasoning tasks.',
      sizeMB: 5200,
      speed: 0.72,
      quality: 0.85,
      capabilities: ['chat'],
    ),
    HFModel(
      id: 'finch1_5b',
      name: 'Finch-1.5B',
      description: 'Lightweight; good for on-device conversation.',
      sizeMB: 1500,
      speed: 0.85,
      quality: 0.7,
      capabilities: ['chat', 'tools'],
    ),
    HFModel(
      id: 'orion4b',
      name: 'Orion-4B',
      description: 'Vision + text capabilities for mixed media.',
      sizeMB: 4500,
      speed: 0.8,
      quality: 0.8,
      capabilities: ['chat', 'vision'],
    ),
    HFModel(
      id: 'atlas9_4b',
      name: 'Atlas-9 4B',
      description: 'Reliable general-purpose model.',
      sizeMB: 5200,
      speed: 0.8,
      quality: 0.82,
      capabilities: ['chat', 'tools'],
    ),
    HFModel(
      id: 'cosmos8b',
      name: 'Cosmos-8B',
      description:
          'Large model; not recommended for low RAM (mocked as heavy).',
      sizeMB: 7000,
      speed: 0.7,
      quality: 0.9,
      capabilities: ['chat'],
    ),
  ];
}
