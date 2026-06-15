import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/family.dart';
import '../../../core/models/family_tree_node.dart';
import '../../../core/services/api_client.dart';
import '../../../core/services/service_locator.dart';

class FamilyProvider extends ChangeNotifier {
  List<Family> _families = [];
  Family? _selectedFamily;
  FamilyTree? _familyTree;
  bool _loading = false;
  String? _error;
  String? _pendingInviteToken;

  List<Family> get families => _families;
  String? get pendingInviteToken => _pendingInviteToken;
  Family? get selectedFamily => _selectedFamily;
  FamilyTree? get familyTree => _familyTree;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasFamily => _families.isNotEmpty;

  Future<void> loadFamilies() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _families = await services.familyService.listFamilies();
      if (_families.isNotEmpty && _selectedFamily == null) {
        _selectedFamily = _families.first;
        await loadFamilyTree();
      }
    } catch (e) {
      _error = 'Failed to load families: ${e.toString()}';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> selectFamily(Family family) async {
    _selectedFamily = family;
    notifyListeners();
    await loadFamilyTree();
  }

  Future<void> createFamily(String name) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final family = await services.familyService.createFamily(name);
      _families.add(family);
      _selectedFamily = family;
      _familyTree = FamilyTree(nodes: [], relationships: []);
    } catch (e) {
      _error = _formatError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void setPendingInviteToken(String? token) {
    _pendingInviteToken = token;
    notifyListeners();
  }

  void reset() {
    _families = [];
    _selectedFamily = null;
    _familyTree = null;
    _loading = false;
    _error = null;
    _pendingInviteToken = null;
    notifyListeners();
  }

  Future<String?> inviteMember({
    required String email,
    String accessLevel = 'edit',
  }) async {
    if (_selectedFamily == null) return 'No family selected';

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await services.familyService.inviteMember(
        familyId: _selectedFamily!.id,
        email: email,
        accessLevel: accessLevel,
      );
      return result['message'] as String? ??
          (result['emailSent'] == true
              ? 'Invitation email sent'
              : 'Invitation created — share the link from the server log if email is not configured');
    } catch (e) {
      _error = 'Failed to invite member: ${e.toString()}';
      return _error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> previewInvitation(String token) async {
    return services.familyService.previewInvitation(token);
  }

  Future<String?> acceptInvitation(String token) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await services.familyService.acceptInvitation(token);
      _pendingInviteToken = null;
      await loadFamilies();
      final familyId = result['familyId'] as String?;
      if (familyId != null) {
        for (final family in _families) {
          if (family.id == familyId) {
            await selectFamily(family);
            break;
          }
        }
      }
      return result['message'] as String? ?? 'Joined family successfully';
    } catch (e) {
      _error = 'Failed to accept invitation: ${e.toString()}';
      return _error;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadFamilyTree() async {
    if (_selectedFamily == null) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _familyTree = await services.familyTreeService.getFamilyTree(_selectedFamily!.id);
    } catch (e) {
      _error = 'Failed to load family tree: ${e.toString()}';
      _familyTree = FamilyTree(nodes: [], relationships: []);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<FamilyTreeNode?> addFamilyMember({
    required String fullName,
    DateTime? birthDate,
    DateTime? deathDate,
    int generation = 1,
    MemberGender gender = MemberGender.unspecified,
    XFile? photo,
    Map<String, dynamic>? metadata,
    String? familyId,
    String? relatedMemberId,
    MemberLinkType linkType = MemberLinkType.none,
  }) async {
    if (familyId != null) {
      final match = _families.where((f) => f.id == familyId);
      if (match.isEmpty) {
        _error = 'Selected family not found';
        notifyListeners();
        return null;
      }
      if (_selectedFamily?.id != familyId) {
        await selectFamily(match.first);
      }
    }

    if (_selectedFamily == null) {
      _error = 'Create or select a family vault first';
      notifyListeners();
      return null;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final mergedMetadata = <String, dynamic>{
        'generation': generation,
        'gender': gender.value,
        ...?metadata,
      };

      var node = await services.familyTreeService.createOrUpdateNode(
        familyId: _selectedFamily!.id,
        fullName: fullName,
        birthDate: birthDate,
        deathDate: deathDate,
        metadata: mergedMetadata,
      );

      if (photo != null) {
        try {
          node = await services.familyTreeService.uploadMemberPhoto(
            familyId: _selectedFamily!.id,
            nodeId: node.id,
            file: photo,
          );
        } catch (photoError) {
          _mergeNodeIntoTree(node);
          _error =
              'Member saved, but photo upload failed: ${_formatError(photoError)}';
          notifyListeners();
          return node;
        }
      }

      if (relatedMemberId != null &&
          linkType != MemberLinkType.none &&
          relatedMemberId.isNotEmpty) {
        try {
          await _createLinkBetween(
            newNodeId: node.id,
            existingNodeId: relatedMemberId,
            linkType: linkType,
          );
        } catch (linkError) {
          _mergeNodeIntoTree(node);
          _error =
              'Member saved, but relationship failed: ${_formatError(linkError)}';
          notifyListeners();
          return node;
        }
      }

      try {
        await loadFamilyTree();
        _error = null;
      } catch (reloadError) {
        _mergeNodeIntoTree(node);
        _error =
            'Member added, but tree refresh failed: ${_formatError(reloadError)}';
      }
      return node;
    } catch (e) {
      _error = 'Failed to add family member: ${_formatError(e)}';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateFamilyMember({
    required String nodeId,
    required String fullName,
    DateTime? birthDate,
    DateTime? deathDate,
    int? generation,
    MemberGender? gender,
    XFile? photo,
    Map<String, dynamic>? metadata,
  }) async {
    if (_selectedFamily == null) return false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final existing = _familyTree?.getNodeById(nodeId);
      final mergedMetadata = <String, dynamic>{
        ...?existing?.metadata,
        ...?metadata,
        if (generation != null) 'generation': generation,
        if (gender != null) 'gender': gender.value,
      };

      await services.familyTreeService.createOrUpdateNode(
        familyId: _selectedFamily!.id,
        id: nodeId,
        fullName: fullName,
        birthDate: birthDate,
        deathDate: deathDate,
        metadata: mergedMetadata,
      );

      if (photo != null) {
        await services.familyTreeService.uploadMemberPhoto(
          familyId: _selectedFamily!.id,
          nodeId: nodeId,
          file: photo,
        );
      }

      await loadFamilyTree();
      return true;
    } catch (e) {
      _error = 'Failed to update family member: ${e.toString()}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteRelationship(String relationshipId) async {
    if (_selectedFamily == null) return false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await services.familyTreeService.deleteRelationship(
        familyId: _selectedFamily!.id,
        relationshipId: relationshipId,
      );
      await loadFamilyTree();
      return true;
    } catch (e) {
      _error = 'Failed to remove relationship: ${_formatError(e)}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> linkMembers({
    required String nodeId,
    required String relatedMemberId,
    required MemberLinkType linkType,
  }) async {
    if (_selectedFamily == null) return false;
    if (linkType == MemberLinkType.none) return true;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _createLinkBetween(
        newNodeId: nodeId,
        existingNodeId: relatedMemberId,
        linkType: linkType,
      );
      await loadFamilyTree();
      return true;
    } catch (e) {
      _error = 'Failed to save relationship: ${_formatError(e)}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> addRelationship({
    required String fromNodeId,
    required String toNodeId,
    required RelationshipType type,
  }) async {
    if (_selectedFamily == null) return false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await services.familyTreeService.createRelationship(
        familyId: _selectedFamily!.id,
        fromNodeId: fromNodeId,
        toNodeId: toNodeId,
        type: type,
      );
      await loadFamilyTree();
      return true;
    } catch (e) {
      _error = 'Failed to add relationship: ${e.toString()}';
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteFamilyMember(String nodeId) async {
    if (_selectedFamily == null) return false;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await services.familyTreeService.deleteNode(
        familyId: _selectedFamily!.id,
        nodeId: nodeId,
      );
      await loadFamilyTree();
      return true;
    } catch (e) {
      _error = 'Failed to delete family member: ${e.toString()}';
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

  Future<void> _createLinkBetween({
    required String newNodeId,
    required String existingNodeId,
    required MemberLinkType linkType,
  }) async {
    final familyId = _selectedFamily!.id;
    switch (linkType) {
      case MemberLinkType.parentOfNew:
        await services.familyTreeService.createRelationship(
          familyId: familyId,
          fromNodeId: existingNodeId,
          toNodeId: newNodeId,
          type: RelationshipType.parent,
        );
        break;
      case MemberLinkType.childOfNew:
        // Existing member is parent; new member is child.
        await services.familyTreeService.createRelationship(
          familyId: familyId,
          fromNodeId: existingNodeId,
          toNodeId: newNodeId,
          type: RelationshipType.parent,
        );
        break;
      case MemberLinkType.spouseOfNew:
        await services.familyTreeService.createRelationship(
          familyId: familyId,
          fromNodeId: newNodeId,
          toNodeId: existingNodeId,
          type: RelationshipType.spouse,
        );
        break;
      case MemberLinkType.none:
        break;
    }
  }

  void _mergeNodeIntoTree(FamilyTreeNode node) {
    final tree = _familyTree;
    if (tree != null && !tree.nodes.any((n) => n.id == node.id)) {
      _familyTree = FamilyTree(
        nodes: [...tree.nodes, node],
        relationships: tree.relationships,
      );
    } else if (tree == null) {
      _familyTree = FamilyTree(nodes: [node], relationships: []);
    }
  }

  String _formatError(Object e) {
    if (e is ApiException) {
      return e.message;
    }
    final text = e.toString();
    if (text.contains('Connection refused') ||
        text.contains('Failed host lookup') ||
        text.contains('SocketException') ||
        text.contains('ClientException')) {
      return 'Cannot reach the server. Open a terminal in the backend folder and run: npm run dev';
    }
    if (text.startsWith('ApiException: ')) {
      return text.replaceFirst('ApiException: ', '').split(' (status:').first;
    }
    return text;
  }
}
