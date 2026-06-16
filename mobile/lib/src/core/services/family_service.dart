import '../models/family.dart';
import 'api_client.dart';

class FamilyService {
  final ApiClient _client;

  FamilyService(this._client);

  Future<List<Family>> listFamilies() async {
    final response = await _client.get('/api/families');
    final list = response as List<dynamic>;
    return list.map((json) => Family.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Family> createFamily(String name) async {
    final response = await _client.post('/api/families', body: {'name': name});
    return Family.fromJson({
      ...response as Map<String, dynamic>,
      'role': 'ADMIN',
    });
  }

  Future<Map<String, dynamic>> inviteMember({
    required String familyId,
    required String email,
    String? role,
    String accessLevel = 'edit',
  }) async {
    final response = await _client.post(
      '/api/families/$familyId/invite',
      body: {
        'email': email,
        'accessLevel': accessLevel,
        if (role != null) 'role': role,
      },
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptInvitation(String token) async {
    final response = await _client.post(
      '/api/invitations/accept',
      body: {'token': token},
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewInvitation(String token) async {
    final response = await _client.get('/api/invitations/$token');
    return response as Map<String, dynamic>;
  }
}
