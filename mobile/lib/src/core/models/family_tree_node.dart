/// Gender stored in node metadata.
enum MemberGender {
  male,
  female,
  other,
  unspecified;

  String get value {
    switch (this) {
      case MemberGender.male:
        return 'male';
      case MemberGender.female:
        return 'female';
      case MemberGender.other:
        return 'other';
      case MemberGender.unspecified:
        return 'unspecified';
    }
  }

  static MemberGender fromString(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'male':
      case 'm':
        return MemberGender.male;
      case 'female':
      case 'f':
        return MemberGender.female;
      case 'other':
        return MemberGender.other;
      default:
        return MemberGender.unspecified;
    }
  }

  String get label {
    switch (this) {
      case MemberGender.male:
        return 'Male';
      case MemberGender.female:
        return 'Female';
      case MemberGender.other:
        return 'Other';
      case MemberGender.unspecified:
        return 'Not specified';
    }
  }
}

class FamilyTreeNode {
  final String id;
  final String familyId;
  final String fullName;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final String? userId;
  final Map<String, dynamic>? metadata;
  final String? photoUrl;
  final DateTime createdAt;

  FamilyTreeNode({
    required this.id,
    required this.familyId,
    required this.fullName,
    this.birthDate,
    this.deathDate,
    this.userId,
    this.metadata,
    this.photoUrl,
    required this.createdAt,
  });

  /// Generation level from metadata (defaults to 1).
  static int generationFromMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null) return 1;
    final value = metadata['generation'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 1;
  }

  int get generation => generationFromMetadata(metadata);

  MemberGender get gender => MemberGender.fromString(
        metadata?['gender'] as String?,
      );

  /// Signed URL for profile photo (from API `photo_url`).
  String? get displayPhotoUrl {
    if (photoUrl != null && photoUrl!.isNotEmpty) return photoUrl;
    final path = metadata?['photoPath'] as String?;
    if (path != null && path.startsWith('http')) return path;
    return null;
  }

  /// Chip label shown in the family tree generation filter row.
  static const List<String> generationFilterChips = [
    'All',
    'Root Gen',
    '1st Gen',
    '2nd Gen',
    '3rd Gen',
  ];

  /// Maps a filter chip label to a metadata generation level (`null` = show all).
  static int? filterLevelForChip(String chipLabel) {
    switch (chipLabel) {
      case 'All':
        return null;
      case 'Root Gen':
        return 0;
      case '1st Gen':
        return 1;
      case '2nd Gen':
        return 2;
      case '3rd Gen':
        return 3;
      default:
        return null;
    }
  }

  static String labelForGeneration(int level) {
    switch (level) {
      case 0:
        return 'Root Gen';
      case 1:
        return '1st Gen';
      case 2:
        return '2nd Gen';
      case 3:
        return '3rd Gen';
      default:
        return 'Gen $level';
    }
  }

  factory FamilyTreeNode.fromJson(Map<String, dynamic> json) {
    return FamilyTreeNode(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      fullName: json['full_name'] as String? ?? '',
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      deathDate: json['death_date'] != null
          ? DateTime.parse(json['death_date'] as String)
          : null,
      userId: json['user_id'] as String?,
      metadata: _parseMetadata(json['metadata']),
      photoUrl: json['photo_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  static Map<String, dynamic>? _parseMetadata(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'family_id': familyId,
    'full_name': fullName,
    if (birthDate != null) 'birth_date': birthDate!.toIso8601String().split('T').first,
    if (deathDate != null) 'death_date': deathDate!.toIso8601String().split('T').first,
    if (userId != null) 'user_id': userId,
    if (metadata != null) 'metadata': metadata,
  };

  String get initials {
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  int? get age {
    if (birthDate == null) return null;
    final endDate = deathDate ?? DateTime.now();
    return endDate.year - birthDate!.year;
  }

  bool get isDeceased => deathDate != null;
}

/// How a new member links to someone already in the tree.
enum MemberLinkType {
  none,
  /// Existing member is the parent of the new member.
  parentOfNew,
  /// Existing member is the child of the new member.
  childOfNew,
  /// Existing member is the spouse of the new member.
  spouseOfNew;

  String get label {
    switch (this) {
      case MemberLinkType.none:
        return 'No link';
      case MemberLinkType.parentOfNew:
        return 'Parent of this person';
      case MemberLinkType.childOfNew:
        return 'Child of this person';
      case MemberLinkType.spouseOfNew:
        return 'Spouse of this person';
    }
  }
}

enum RelationshipType {
  parent,
  child,
  spouse;

  String get value {
    switch (this) {
      case RelationshipType.parent:
        return 'PARENT';
      case RelationshipType.child:
        return 'CHILD';
      case RelationshipType.spouse:
        return 'SPOUSE';
    }
  }

  static RelationshipType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PARENT':
        return RelationshipType.parent;
      case 'CHILD':
        return RelationshipType.child;
      case 'SPOUSE':
        return RelationshipType.spouse;
      default:
        throw ArgumentError('Unknown relationship type: $value');
    }
  }
}

class FamilyRelationship {
  final String id;
  final String familyId;
  final String fromNodeId;
  final String toNodeId;
  final RelationshipType type;
  final DateTime createdAt;

  FamilyRelationship({
    required this.id,
    required this.familyId,
    required this.fromNodeId,
    required this.toNodeId,
    required this.type,
    required this.createdAt,
  });

  factory FamilyRelationship.fromJson(Map<String, dynamic> json) {
    return FamilyRelationship(
      id: json['id']?.toString() ?? '',
      familyId: json['family_id']?.toString() ?? '',
      fromNodeId: json['from_node_id']?.toString() ?? '',
      toNodeId: json['to_node_id']?.toString() ?? '',
      type: RelationshipType.fromString(json['type'] as String),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'family_id': familyId,
    'from_node_id': fromNodeId,
    'to_node_id': toNodeId,
    'type': type.value,
  };
}

class FamilyTree {
  final List<FamilyTreeNode> nodes;
  final List<FamilyRelationship> relationships;

  FamilyTree({
    required this.nodes,
    required this.relationships,
  });

  factory FamilyTree.fromJson(Map<String, dynamic> json) {
    return FamilyTree(
      nodes: (json['nodes'] as List<dynamic>)
          .map((e) => FamilyTreeNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      relationships: (json['relationships'] as List<dynamic>)
          .map((e) => FamilyRelationship.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  FamilyTreeNode? getNodeById(String id) {
    try {
      return nodes.firstWhere((n) => n.id == id);
    } catch (_) {
      return null;
    }
  }

  List<FamilyTreeNode> getParentsOf(String nodeId) {
    final parentIds = <String>{};
    for (final r in relationships) {
      if (r.type == RelationshipType.parent && r.toNodeId == nodeId) {
        parentIds.add(r.fromNodeId);
      } else if (r.type == RelationshipType.child && r.fromNodeId == nodeId) {
        parentIds.add(r.toNodeId);
      }
    }
    return nodes.where((n) => parentIds.contains(n.id)).toList();
  }

  List<FamilyTreeNode> getChildrenOf(String nodeId) {
    final childIds = <String>{};
    for (final r in relationships) {
      if (r.type == RelationshipType.parent && r.fromNodeId == nodeId) {
        childIds.add(r.toNodeId);
      } else if (r.type == RelationshipType.child && r.toNodeId == nodeId) {
        childIds.add(r.fromNodeId);
      }
    }
    return nodes.where((n) => childIds.contains(n.id)).toList();
  }

  List<FamilyTreeNode> getSpousesOf(String nodeId) {
    final spouseIds = relationships
        .where((r) =>
            (r.fromNodeId == nodeId || r.toNodeId == nodeId) &&
            r.type == RelationshipType.spouse)
        .map((r) => r.fromNodeId == nodeId ? r.toNodeId : r.fromNodeId)
        .toList();
    return nodes.where((n) => spouseIds.contains(n.id)).toList();
  }

  /// Relationships involving [nodeId], with label from that member's perspective.
  List<MemberRelationshipDisplay> relationshipsInvolving(String nodeId) {
    final result = <MemberRelationshipDisplay>[];
    for (final rel in relationships) {
      if (rel.fromNodeId != nodeId && rel.toNodeId != nodeId) continue;

      final otherId = rel.fromNodeId == nodeId ? rel.toNodeId : rel.fromNodeId;
      final other = getNodeById(otherId);
      if (other == null) continue;

      String label;
      if (rel.type == RelationshipType.spouse) {
        label = 'Spouse';
      } else if (rel.type == RelationshipType.parent) {
        label = rel.fromNodeId == otherId ? 'Parent' : 'Child';
      } else if (rel.type == RelationshipType.child) {
        label = rel.fromNodeId == nodeId ? 'Child' : 'Parent';
      } else {
        label = rel.type.value;
      }

      result.add(MemberRelationshipDisplay(
        relationship: rel,
        otherMember: other,
        label: label,
      ));
    }
    return result;
  }

  FamilyTree subsetForNodes(List<FamilyTreeNode> nodeSubset) {
    final ids = nodeSubset.map((n) => n.id).toSet();
    final rels = relationships
        .where((r) => ids.contains(r.fromNodeId) && ids.contains(r.toNodeId))
        .toList();
    return FamilyTree(nodes: nodeSubset, relationships: rels);
  }
}

class MemberRelationshipDisplay {
  final FamilyRelationship relationship;
  final FamilyTreeNode otherMember;
  final String label;

  const MemberRelationshipDisplay({
    required this.relationship,
    required this.otherMember,
    required this.label,
  });

  String get subtitle {
    final year = otherMember.birthDate?.year;
    return year != null ? '${otherMember.fullName} (b. $year)' : otherMember.fullName;
  }
}
