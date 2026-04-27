// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Flux';

  @override
  String get home => 'Inicio';

  @override
  String get creations => 'Creaciones';

  @override
  String get settings => 'Configuración';

  @override
  String get models => 'Modelos';

  @override
  String get downloadAndManageModels => 'Descargar y gestionar modelos de IA';

  @override
  String get clearCache => 'Limpiar caché';

  @override
  String get removeTemporaryFiles => 'Eliminar archivos temporales';

  @override
  String get aboutFlux => 'Acerca de Flux';

  @override
  String get version => 'Versión';

  @override
  String get yourPrivateAI =>
      'Tu asistente de IA privado que se ejecuta localmente en tu dispositivo. Tus datos permanecen en tu teléfono — no se necesita cuenta.';

  @override
  String get selectModel => 'Seleccionar Modelo';

  @override
  String get noModelsDownloaded =>
      'No hay modelos descargados. Ve a la Biblioteca para descargar.';

  @override
  String get poweredBy => 'Desarrollado por';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get clearCacheQuestion => '¿Limpiar caché?';

  @override
  String get clearCacheMessage =>
      'Esto solo elimina archivos temporales. Tus modelos descargados y chats no se verán afectados.';

  @override
  String get deleteModelQuestion => '¿Eliminar modelo?';

  @override
  String get cancelDownloadQuestion => '¿Cancelar descarga?';

  @override
  String get preview => 'Vista previa';

  @override
  String get download => 'Descargar';

  @override
  String get downloading => 'Descargando';

  @override
  String get chat => 'Chat';

  @override
  String get typeMessage => 'Escribe un mensaje...';

  @override
  String get noCreations => 'Aún no hay creaciones';

  @override
  String get createFirst => 'Crea tu primera aplicación con IA';

  @override
  String get noModelsYet => 'Aún no hay modelos';

  @override
  String get downloadModelToStart => 'Descarga un modelo para comenzar';

  @override
  String get cancelDownload => 'Cancelar descarga';

  @override
  String get continueDownload => 'Continuar descarga';

  @override
  String get buildFirstApp => 'Construye tu primera mini-app interactiva';

  @override
  String get welcomeToFlux => 'Bienvenido a Flux';

  @override
  String get start => 'Comenzar';

  @override
  String get skipSetup => 'Omitir configuración';

  @override
  String get downloadAndContinue => 'Descargar y continuar';

  @override
  String get highSpeedConnectionRecommended =>
      'Se recomienda conexión de alta velocidad.';

  @override
  String get noModelSelected => 'Ningún modelo seleccionado';

  @override
  String get noModelSelectedMessage =>
      'No hay ningún modelo seleccionado o descargado. Visita la Biblioteca para descargar uno primero.';

  @override
  String get messageFlux => 'Mensaje a Flux...';

  @override
  String get howCanIHelp => '¿Cómo puedo ayudarte hoy?';

  @override
  String get startConversation => 'Inicia una conversación con Flux';

  @override
  String get retry => 'Reintentar';

  @override
  String get copiedToClipboard => 'Copiado al portapapeles';

  @override
  String get chats => 'Chats';

  @override
  String get noChatsYet => 'Aún no hay chats';

  @override
  String get conversationsAppearHere => 'Tus conversaciones aparecerán aquí';

  @override
  String get rename => 'Renombrar';

  @override
  String get renameChat => 'Renombrar chat';

  @override
  String get chatName => 'Nombre del chat';

  @override
  String get save => 'Guardar';

  @override
  String get newChat => 'Nuevo chat';

  @override
  String get chatHistory => 'Historial de chats';

  @override
  String get weValuePrivacy => 'Valoramos tu privacidad';

  @override
  String get privacyDescription =>
      'Diseñamos Flux para usar modelos de IA locales, por lo que tus datos no van a corporaciones, ni siquiera a nosotros.';

  @override
  String get fullyOffline => 'Totalmente offline';

  @override
  String get offlineDescription =>
      'Como usamos modelos de IA locales, Flux funciona completamente offline, así que puedes hacer preguntas incluso sin cobertura.';

  @override
  String get chooseModel => 'Elige un modelo para descargar';

  @override
  String get chooseModelDescription =>
      'Flux recomienda modelos optimizados para tu dispositivo, asegurando que funcionen correctamente.';

  @override
  String get thatsIt => 'Eso es todo. ¡Flux está listo!';

  @override
  String get finish => 'Finalizar';

  @override
  String get next => 'Siguiente';

  @override
  String get back => 'Atrás';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get installed => 'Instalados';

  @override
  String get available => 'Disponibles';

  @override
  String get fluxCreativeRequired => 'Flux Creative requerido';

  @override
  String get installCreativeModel =>
      'Instala el modelo Creative para empezar a crear.';

  @override
  String get installFluxCreative => 'Instalar Flux Creative';

  @override
  String get creativeDownloadSize => '~890 MB de descarga';

  @override
  String get selectModelToChat => 'Selecciona un modelo para chatear';

  @override
  String get buildSomethingAmazing => 'Construye algo increíble';

  @override
  String get describeAppIdea => 'Describe tu idea de app...';

  @override
  String get previewCreation => 'Vista previa de la creación';

  @override
  String get tapToOpenApp => 'Toca para abrir la app interactiva';

  @override
  String get fluxCreativeNotInstalled => 'Flux Creative no está instalado.';

  @override
  String get installCreativeToUseCreations =>
      'Instálalo desde Modelos para usar Creaciones.';

  @override
  String get modelArchitectureUnsupported =>
      'Arquitectura de modelo no compatible. Por favor, prueba un modelo Llama 3.2 o Qwen estándar por ahora.';

  @override
  String get inferenceError => 'Error de inferencia';

  @override
  String get cacheCleared => 'Caché limpiada';

  @override
  String searchingFor(Object query) {
    return 'Buscando \"$query\"...';
  }

  @override
  String get sources => 'Fuentes';

  @override
  String get searched => 'Buscado';

  @override
  String get reasoned => 'Razonado';

  @override
  String get thinking => 'Pensando';

  @override
  String get closeMenu => 'Cerrar menú';

  @override
  String get untitledCreation => 'Creación sin título';

  @override
  String get newCreation => 'Nueva creación';

  @override
  String get modelPicker => 'Selector de modelo';

  @override
  String detectedRam(Object ram) {
    return '$ram GB de RAM detectados';
  }

  @override
  String get selectOptimizedModel =>
      'Selecciona el modelo más optimizado para tu dispositivo.';

  @override
  String get creationNotFound => 'Creación no encontrada';

  @override
  String get goBack => 'Volver';

  @override
  String get untitled => 'Sin título';

  @override
  String get justNow => 'Justo ahora';

  @override
  String minutesAgo(Object minutes) {
    return 'hace ${minutes}m';
  }

  @override
  String hoursAgo(Object hours) {
    return 'hace ${hours}h';
  }

  @override
  String daysAgo(Object days) {
    return 'hace ${days}d';
  }
}
