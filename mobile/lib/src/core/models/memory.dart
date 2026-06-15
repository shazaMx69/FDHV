enum MediaType {
  image,
  video,
  audio,
  document;

  String get value {
    switch (this) {
      case MediaType.image:
        return 'IMAGE';
      case MediaType.video:
        return 'VIDEO';
      case MediaType.audio:
        return 'AUDIO';
      case MediaType.document:
        return 'DOCUMENT';
    }
  }

  static MediaType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'image':
      case 'photo':
        return MediaType.image;
      case 'video':
        return MediaType.video;
      case 'audio':
        return MediaType.audio;
      case 'document':
      case 'text':
        return MediaType.document;
      default:
        return MediaType.image;
    }
  }

  String get displayName {
    switch (this) {
      case MediaType.image:
        return 'Photo';
      case MediaType.video:
        return 'Video';
      case MediaType.audio:
        return 'Audio';
      case MediaType.document:
        return 'Document';
    }
  }
}

class Memory {
  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String? description;
  final MediaType mediaType;
  final String? storagePath;
  /// Time-limited URL for displaying media (from API `media_url`).
  final String? mediaUrl;
  final String? event;
  final DateTime? eventDate;
  final List<String>? tags;
  final DateTime createdAt;
  final bool isLocked;
  final String? inheritanceConditionType;

  Memory({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    this.description,
    required this.mediaType,
    this.storagePath,
    this.mediaUrl,
    this.event,
    this.eventDate,
    this.tags,
    required this.createdAt,
    this.isLocked = false,
    this.inheritanceConditionType,
  });

  factory Memory.fromJson(Map<String, dynamic> json) {
    return Memory(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      mediaType: MediaType.fromString(json['media_type'] as String),
      storagePath: json['storage_path'] as String?,
      mediaUrl: json['media_url'] as String?,
      event: json['event'] as String?,
      eventDate: json['event_date'] != null
          ? DateTime.parse(json['event_date'] as String)
          : null,
      tags: json['tags'] != null
          ? List<String>.from(json['tags'] as List)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isLocked: json['locked'] == true,
      inheritanceConditionType:
          (json['inheritance_info'] as Map<String, dynamic>?)?['condition_type'] as String?,
    );
  }

  String get inheritanceLockLabel {
    switch (inheritanceConditionType) {
      case 'UNLOCK_AT_DATE':
        return 'Unlocks on a set date';
      case 'UNLOCK_AT_AGE':
        return 'Unlocks at a set age';
      case 'UNLOCK_ON_BIRTHDAY':
        return 'Unlocks on birthday';
      default:
        return 'Inheritance locked';
    }
  }

  /// URL used to load memory media in the gallery and detail views.
  String? get displayUrl {
    if (mediaUrl != null && mediaUrl!.isNotEmpty) return mediaUrl;
    final path = storagePath;
    if (path == null || path.isEmpty) return null;
    return path;
  }

  Map<String, dynamic> toJson() => {
    'family_id': familyId,
    'title': title,
    if (description != null) 'description': description,
    'media_type': mediaType.value,
    if (storagePath != null) 'storage_path': storagePath,
    if (event != null) 'event': event,
    if (eventDate != null) 'event_date': eventDate!.toIso8601String().split('T').first,
    if (tags != null) 'tags': tags,
  };

  String? get publicUrl => displayUrl;
}

enum ConditionType {
  unlockAtDate,
  unlockAtAge,
  unlockOnBirthday;

  String get value {
    switch (this) {
      case ConditionType.unlockAtDate:
        return 'UNLOCK_AT_DATE';
      case ConditionType.unlockAtAge:
        return 'UNLOCK_AT_AGE';
      case ConditionType.unlockOnBirthday:
        return 'UNLOCK_ON_BIRTHDAY';
    }
  }

  static ConditionType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'UNLOCK_AT_DATE':
        return ConditionType.unlockAtDate;
      case 'UNLOCK_AT_AGE':
        return ConditionType.unlockAtAge;
      case 'UNLOCK_ON_BIRTHDAY':
        return ConditionType.unlockOnBirthday;
      default:
        return ConditionType.unlockAtDate;
    }
  }

  String get displayName {
    switch (this) {
      case ConditionType.unlockAtDate:
        return 'Unlock on specific date';
      case ConditionType.unlockAtAge:
        return 'Unlock when beneficiary reaches age';
      case ConditionType.unlockOnBirthday:
        return 'Unlock on beneficiary\'s birthday';
    }
  }
}

class InheritanceRule {
  final String id;
  final String memoryId;
  final String familyId;
  final String beneficiaryNodeId;
  final ConditionType conditionType;
  final DateTime? unlockDate;
  final int? unlockAge;
  final String createdBy;
  final DateTime createdAt;

  InheritanceRule({
    required this.id,
    required this.memoryId,
    required this.familyId,
    required this.beneficiaryNodeId,
    required this.conditionType,
    this.unlockDate,
    this.unlockAge,
    required this.createdBy,
    required this.createdAt,
  });

  factory InheritanceRule.fromJson(Map<String, dynamic> json) {
    return InheritanceRule(
      id: json['id'] as String,
      memoryId: json['memory_id'] as String,
      familyId: json['family_id'] as String,
      beneficiaryNodeId: json['beneficiary_node_id'] as String,
      conditionType: ConditionType.fromString(json['condition_type'] as String),
      unlockDate: json['unlock_date'] != null
          ? DateTime.parse(json['unlock_date'] as String)
          : null,
      unlockAge: json['unlock_age'] as int?,
      createdBy: json['created_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'memory_id': memoryId,
    'family_id': familyId,
    'beneficiary_node_id': beneficiaryNodeId,
    'condition_type': conditionType.value,
    if (unlockDate != null) 'unlock_date': unlockDate!.toIso8601String().split('T').first,
    if (unlockAge != null) 'unlock_age': unlockAge,
  };
}
