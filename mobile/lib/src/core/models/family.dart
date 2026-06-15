class Family {
  final String id;
  final String name;
  final DateTime createdAt;
  final String role;

  Family({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.role,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    DateTime createdAt = DateTime.now();
    if (createdRaw is String && createdRaw.isNotEmpty) {
      createdAt = DateTime.parse(createdRaw);
    } else if (createdRaw != null) {
      createdAt = DateTime.tryParse(createdRaw.toString()) ?? DateTime.now();
    }

    return Family(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      createdAt: createdAt,
      role: json['role'] as String? ?? 'ADMIN',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toIso8601String(),
    'role': role,
  };

  /// View-only invites receive JUNIOR role.
  bool get canEdit => role == 'ADMIN' || role == 'ADULT';
}

class FamilyMember {
  final String id;
  final String familyId;
  final String userId;
  final String role;
  final String? invitedEmail;
  final DateTime createdAt;

  FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    required this.role,
    this.invitedEmail,
    required this.createdAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: json['role'] as String,
      invitedEmail: json['invited_email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
