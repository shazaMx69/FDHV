import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/memory.dart';
import 'api_client.dart';

class MemoryService {
  final ApiClient _client;
  final _supabase = Supabase.instance.client;

  MemoryService(this._client);

  Future<List<Memory>> listMemories(String familyId) async {
    final response = await _client.get('/api/memories', queryParams: {'familyId': familyId});
    final list = response as List<dynamic>;
    return list.map((json) => Memory.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Memory> getMemory(String memoryId, {String? familyId}) async {
    final response = await _client.get(
      '/api/memories/$memoryId',
      queryParams: familyId != null ? {'familyId': familyId} : null,
    );
    return Memory.fromJson(response as Map<String, dynamic>);
  }

  Future<Memory> createMemory({
    required String familyId,
    required String title,
    String? description,
    required MediaType mediaType,
    String? storagePath,
    String? event,
    DateTime? eventDate,
    List<String>? tags,
    List<String>? peopleNodeIds,
  }) async {
    final body = <String, dynamic>{
      'familyId': familyId,
      'title': title,
      'mediaType': mediaType.value,
      if (description != null) 'description': description,
      if (storagePath != null) 'storagePath': storagePath,
      if (event != null) 'event': event,
      if (eventDate != null) 'eventDate': eventDate.toIso8601String().split('T').first,
      if (tags != null) 'tags': tags,
      if (peopleNodeIds != null) 'peopleNodeIds': peopleNodeIds,
    };

    final response = await _client.post('/api/memories', body: body);
    return Memory.fromJson(response as Map<String, dynamic>);
  }

  Future<InheritanceRule> createInheritanceRule({
    required String memoryId,
    required String familyId,
    required String beneficiaryNodeId,
    required ConditionType conditionType,
    DateTime? unlockDate,
    int? unlockAge,
  }) async {
    final body = <String, dynamic>{
      'familyId': familyId,
      'beneficiaryNodeId': beneficiaryNodeId,
      'conditionType': conditionType.value,
      if (unlockDate != null) 'unlockDate': unlockDate.toIso8601String().split('T').first,
      if (unlockAge != null) 'unlockAge': unlockAge,
    };

    final response = await _client.post('/api/memories/$memoryId/inheritance-rules', body: body);
    return InheritanceRule.fromJson(response as Map<String, dynamic>);
  }

  /// Uploads via backend (Supabase service role). Works on web, mobile, and desktop.
  Future<String> uploadMedia({
    required String familyId,
    required XFile file,
    required MediaType mediaType,
  }) async {
    final token = _supabase.auth.currentSession?.accessToken;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final bytes = await file.readAsBytes();
    final fileName = _resolveFileName(file, mediaType);

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/api/memories/upload-media'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['familyId'] = familyId;
    request.fields['mediaType'] = mediaType.value;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Upload failed';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    // Store object path in DB; API resolves signed URLs when listing/viewing.
    return data['storagePath'] as String;
  }

  String _resolveFileName(XFile file, MediaType mediaType) {
    if (file.name.isNotEmpty) return file.name;
    switch (mediaType) {
      case MediaType.video:
        return 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      case MediaType.audio:
        return 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      case MediaType.document:
        return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      case MediaType.image:
        return 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
  }

}
