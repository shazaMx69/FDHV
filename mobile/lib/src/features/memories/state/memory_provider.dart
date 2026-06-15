import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/memory.dart';
import '../../../core/services/service_locator.dart';

class MemoryProvider extends ChangeNotifier {
  List<Memory> _memories = [];
  bool _loading = false;
  String? _error;

  List<Memory> get memories => _memories;
  bool get loading => _loading;
  String? get error => _error;

  int get totalCount => _memories.length;
  int get photoCount => _memories.where((m) => m.mediaType == MediaType.image).length;
  int get videoCount => _memories.where((m) => m.mediaType == MediaType.video).length;

  Future<void> loadMemories(String familyId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _memories = await services.memoryService.listMemories(familyId);
    } catch (e) {
      _error = 'Failed to load memories: ${e.toString()}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<Memory> filterByType(MediaType? type) {
    if (type == null) return _memories;
    return _memories.where((m) => m.mediaType == type).toList();
  }

  List<Memory> search(String query) {
    if (query.isEmpty) return _memories;
    final lowerQuery = query.toLowerCase();
    return _memories.where((m) {
      return m.title.toLowerCase().contains(lowerQuery) ||
          (m.description?.toLowerCase().contains(lowerQuery) ?? false) ||
          (m.event?.toLowerCase().contains(lowerQuery) ?? false) ||
          (m.tags?.any((t) => t.toLowerCase().contains(lowerQuery)) ?? false);
    }).toList();
  }

  List<Memory> getRecent({int limit = 5}) {
    final sorted = List<Memory>.from(_memories)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted.take(limit).toList();
  }

  Future<Memory?> uploadMemory({
    required String familyId,
    required String title,
    String? description,
    required XFile file,
    required MediaType mediaType,
    String? event,
    DateTime? eventDate,
    List<String>? tags,
    List<String>? peopleNodeIds,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Upload media file to Supabase Storage
      final storagePath = await services.memoryService.uploadMedia(
        familyId: familyId,
        file: file,
        mediaType: mediaType,
      );

      // Create memory record with the storage path
      final memory = await services.memoryService.createMemory(
        familyId: familyId,
        title: title,
        description: description,
        mediaType: mediaType,
        storagePath: storagePath,
        event: event,
        eventDate: eventDate,
        tags: tags,
        peopleNodeIds: peopleNodeIds,
      );

      _memories.insert(0, memory);
      // Refresh list so gallery gets signed media_url for thumbnails.
      await loadMemories(familyId);
      return memory;
    } catch (e) {
      _error = 'Failed to upload memory: ${e.toString()}';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> setInheritanceRule({
    required String memoryId,
    required String familyId,
    required String beneficiaryNodeId,
    required ConditionType conditionType,
    DateTime? unlockDate,
    int? unlockAge,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await services.memoryService.createInheritanceRule(
        memoryId: memoryId,
        familyId: familyId,
        beneficiaryNodeId: beneficiaryNodeId,
        conditionType: conditionType,
        unlockDate: unlockDate,
        unlockAge: unlockAge,
      );
      return true;
    } catch (e) {
      _error = 'Failed to set inheritance rule: ${e.toString()}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _memories = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
