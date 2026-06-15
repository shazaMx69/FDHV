import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/family_tree_node.dart';
import 'api_client.dart';

class FamilyTreeService {
  final ApiClient _client;

  FamilyTreeService(this._client);

  Future<FamilyTree> getFamilyTree(String familyId) async {
    final response = await _client.get('/api/family-tree/$familyId');
    return FamilyTree.fromJson(response as Map<String, dynamic>);
  }

  Future<FamilyTreeNode> createOrUpdateNode({
    required String familyId,
    String? id,
    required String fullName,
    DateTime? birthDate,
    DateTime? deathDate,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'fullName': fullName,
      if (id != null) 'id': id,
      if (birthDate != null) 'birthDate': birthDate.toIso8601String().split('T').first,
      if (deathDate != null) 'deathDate': deathDate.toIso8601String().split('T').first,
      if (userId != null) 'userId': userId,
      if (metadata != null) 'metadata': metadata,
    };

    final response = await _client.post('/api/family-tree/$familyId/nodes', body: body);
    return FamilyTreeNode.fromJson(response as Map<String, dynamic>);
  }

  Future<FamilyRelationship> createRelationship({
    required String familyId,
    required String fromNodeId,
    required String toNodeId,
    required RelationshipType type,
  }) async {
    final body = {
      'fromNodeId': fromNodeId,
      'toNodeId': toNodeId,
      'type': type.value,
    };

    final response = await _client.post('/api/family-tree/$familyId/relationships', body: body);
    return FamilyRelationship.fromJson(response as Map<String, dynamic>);
  }

  Future<void> deleteNode({
    required String familyId,
    required String nodeId,
  }) async {
    await _client.delete('/api/family-tree/$familyId/nodes/$nodeId');
  }

  Future<void> deleteRelationship({
    required String familyId,
    required String relationshipId,
  }) async {
    await _client.delete(
      '/api/family-tree/$familyId/relationships/$relationshipId',
    );
  }

  Future<FamilyTreeNode> uploadMemberPhoto({
    required String familyId,
    required String nodeId,
    required XFile file,
  }) async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) {
      throw ApiException('Not authenticated', 401);
    }

    final bytes = await file.readAsBytes();
    final fileName = file.name.isNotEmpty ? file.name : 'member_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiBaseUrl}/api/family-tree/$familyId/nodes/$nodeId/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes('file', bytes, filename: fileName),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String message = 'Photo upload failed';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = body['message'] as String? ?? message;
      } catch (_) {}
      throw ApiException(message, response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return FamilyTreeNode.fromJson(data);
  }
}
