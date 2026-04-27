// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flux';

  @override
  String get home => '首页';

  @override
  String get creations => '创作';

  @override
  String get settings => '设置';

  @override
  String get models => '模型';

  @override
  String get downloadAndManageModels => '下载和管理AI模型';

  @override
  String get clearCache => '清除缓存';

  @override
  String get removeTemporaryFiles => '删除临时文件';

  @override
  String get aboutFlux => '关于Flux';

  @override
  String get version => '版本';

  @override
  String get yourPrivateAI => '您的私人AI助手，在您的设备上本地运行。您的数据保留在您的手机上 — 无需账户。';

  @override
  String get selectModel => '选择模型';

  @override
  String get noModelsDownloaded => '未下载模型。请前往库下载。';

  @override
  String get poweredBy => '由';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get clearCacheQuestion => '清除缓存？';

  @override
  String get clearCacheMessage => '这仅删除临时文件。您下载的模型和聊天记录不会受到影响。';

  @override
  String get deleteModelQuestion => '删除模型？';

  @override
  String get cancelDownloadQuestion => '取消下载？';

  @override
  String get preview => '预览';

  @override
  String get download => '下载';

  @override
  String get downloading => '下载中';

  @override
  String get chat => '聊天';

  @override
  String get typeMessage => '输入消息...';

  @override
  String get noCreations => '还没有创作';

  @override
  String get createFirst => '创建您的第一个AI应用';

  @override
  String get noModelsYet => '还没有模型';

  @override
  String get downloadModelToStart => '下载一个模型以开始';

  @override
  String get cancelDownload => '取消下载';

  @override
  String get continueDownload => '继续下载';

  @override
  String get buildFirstApp => '构建您的第一个交互式迷你应用';

  @override
  String get welcomeToFlux => '欢迎使用 Flux';

  @override
  String get start => '开始';

  @override
  String get skipSetup => '跳过设置';

  @override
  String get downloadAndContinue => '下载并继续';

  @override
  String get highSpeedConnectionRecommended => '建议使用高速连接。';

  @override
  String get noModelSelected => '未选择模型';

  @override
  String get noModelSelectedMessage => '当前未选择或下载任何模型。请访问库先下载一个模型。';

  @override
  String get messageFlux => '给 Flux 发消息...';

  @override
  String get howCanIHelp => '今天我能帮您什么？';

  @override
  String get startConversation => '开始与 Flux 对话';

  @override
  String get retry => '重试';

  @override
  String get copiedToClipboard => '已复制到剪贴板';

  @override
  String get chats => '聊天';

  @override
  String get noChatsYet => '还没有聊天';

  @override
  String get conversationsAppearHere => '您的对话将显示在这里';

  @override
  String get rename => '重命名';

  @override
  String get renameChat => '重命名聊天';

  @override
  String get chatName => '聊天名称';

  @override
  String get save => '保存';

  @override
  String get newChat => '新聊天';

  @override
  String get chatHistory => '聊天历史';

  @override
  String get weValuePrivacy => '我们重视您的隐私';

  @override
  String get privacyDescription =>
      '我们将 Flux 设计为使用本地 AI 模型，因此您的数据不会流向企业，甚至不会流向我们自己。';

  @override
  String get fullyOffline => '完全离线';

  @override
  String get offlineDescription =>
      '由于我们使用本地 AI 模型，Flux 完全离线工作，因此即使没有网络覆盖，您也可以提问。';

  @override
  String get chooseModel => '选择要下载的模型';

  @override
  String get chooseModelDescription => 'Flux 推荐针对您的设备优化的模型，确保它们正常工作。';

  @override
  String get thatsIt => '就这样。Flux 已准备就绪！';

  @override
  String get finish => '完成';

  @override
  String get next => '下一步';

  @override
  String get back => '返回';

  @override
  String get storage => '存储空间';

  @override
  String get installed => '已安装';

  @override
  String get available => '可用';

  @override
  String get fluxCreativeRequired => '需要 Flux Creative';

  @override
  String get installCreativeModel => '安装 Creative 模型以开始创作。';

  @override
  String get installFluxCreative => '安装 Flux Creative';

  @override
  String get creativeDownloadSize => '约 890 MB 下载';

  @override
  String get selectModelToChat => '选择模型开始聊天';

  @override
  String get buildSomethingAmazing => '构建令人惊叹的作品';

  @override
  String get describeAppIdea => '描述您的应用创意...';

  @override
  String get previewCreation => '预览创作';

  @override
  String get tapToOpenApp => '点击打开交互式应用';

  @override
  String get fluxCreativeNotInstalled => 'Flux Creative 未安装。';

  @override
  String get installCreativeToUseCreations => '请从模型中安装以使用创作功能。';

  @override
  String get modelArchitectureUnsupported =>
      '模型架构不受支持。目前请尝试标准的 Llama 3.2 或 Qwen 模型。';

  @override
  String get inferenceError => '推理错误';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String searchingFor(Object query) {
    return '正在搜索\"$query\"...';
  }

  @override
  String get sources => '来源';

  @override
  String get searched => '已搜索';

  @override
  String get reasoned => '已推理';

  @override
  String get thinking => '思考中';

  @override
  String get closeMenu => '关闭菜单';

  @override
  String get untitledCreation => '未命名的创作';

  @override
  String get newCreation => '新建创作';

  @override
  String get modelPicker => '模型选择器';

  @override
  String detectedRam(Object ram) {
    return '检测到 $ram GB 内存';
  }

  @override
  String get selectOptimizedModel => '选择最适合您设备的优化模型。';

  @override
  String get creationNotFound => '未找到创作';

  @override
  String get goBack => '返回';

  @override
  String get untitled => '无标题';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(Object minutes) {
    return '$minutes分钟前';
  }

  @override
  String hoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String daysAgo(Object days) {
    return '$days天前';
  }
}
