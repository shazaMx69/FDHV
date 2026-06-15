import '../config/app_config.dart';
import 'api_client.dart';
import 'family_service.dart';
import 'family_tree_service.dart';
import 'memory_service.dart';
import 'pdf_export_service.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late final ApiClient _apiClient;
  late final FamilyService familyService;
  late final FamilyTreeService familyTreeService;
  late final MemoryService memoryService;
  late final PdfExportService pdfExportService;

  bool _initialized = false;

  void initialize() {
    if (_initialized) return;

    _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
    familyService = FamilyService(_apiClient);
    familyTreeService = FamilyTreeService(_apiClient);
    memoryService = MemoryService(_apiClient);
    pdfExportService = PdfExportService();

    _initialized = true;
  }
}

// Global accessor
final services = ServiceLocator();
