import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

/// Dropdown to pick which family vault to work with.
class FamilyPickerField extends StatelessWidget {
  final String? selectedFamilyId;
  final ValueChanged<String?> onChanged;

  const FamilyPickerField({
    super.key,
    required this.selectedFamilyId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final families = context.watch<FamilyProvider>().families;
    if (families.isEmpty) {
      return const ListTile(
        leading: Icon(Icons.family_restroom_outlined),
        title: Text('No family yet — add one from Home'),
      );
    }

    return DropdownButtonFormField<String>(
      value: selectedFamilyId ?? families.first.id,
      decoration: const InputDecoration(
        labelText: 'Family',
        prefixIcon: Icon(Icons.family_restroom_outlined),
      ),
      items: families
          .map(
            (f) => DropdownMenuItem(
              value: f.id,
              child: Text(f.name),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}

/// Link new member to an existing tree member.
class MemberRelationFields extends StatelessWidget {
  final List<FamilyTreeNode> existingMembers;
  final String? relatedMemberId;
  final MemberLinkType linkType;
  final ValueChanged<String?> onRelatedChanged;
  final ValueChanged<MemberLinkType> onLinkTypeChanged;

  const MemberRelationFields({
    super.key,
    required this.existingMembers,
    required this.relatedMemberId,
    required this.linkType,
    required this.onRelatedChanged,
    required this.onLinkTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (existingMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relationship (optional)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: relatedMemberId,
          decoration: const InputDecoration(
            labelText: 'Related to',
            prefixIcon: Icon(Icons.account_tree_outlined),
            hintText: 'Select existing member',
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('None — no link yet'),
            ),
            ...existingMembers.map(
              (n) {
                final year = n.birthDate?.year;
                final label = year != null
                    ? '${n.fullName} (b. $year)'
                    : n.fullName;
                return DropdownMenuItem<String?>(
                  value: n.id,
                  child: Text(label),
                );
              },
            ),
          ],
          onChanged: onRelatedChanged,
        ),
        if (relatedMemberId != null) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<MemberLinkType>(
            value: linkType == MemberLinkType.none
                ? MemberLinkType.parentOfNew
                : linkType,
            decoration: const InputDecoration(
              labelText: 'This person is their…',
              prefixIcon: Icon(Icons.link),
            ),
            items: const [
              DropdownMenuItem(
                value: MemberLinkType.parentOfNew,
                child: Text('Parent'),
              ),
              DropdownMenuItem(
                value: MemberLinkType.childOfNew,
                child: Text('Child'),
              ),
              DropdownMenuItem(
                value: MemberLinkType.spouseOfNew,
                child: Text('Spouse'),
              ),
            ],
            onChanged: (v) {
              if (v != null) onLinkTypeChanged(v);
            },
          ),
        ],
      ],
    );
  }
}

/// Profile photo picker for add/edit member forms.
class MemberPhotoPicker extends StatelessWidget {
  final XFile? pickedFile;
  final String? existingPhotoUrl;
  final VoidCallback onPickGallery;
  final VoidCallback? onClear;

  const MemberPhotoPicker({
    super.key,
    this.pickedFile,
    this.existingPhotoUrl,
    required this.onPickGallery,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onPickGallery,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.divider,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _buildPreview(),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onPickGallery,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(pickedFile != null || existingPhotoUrl != null
                ? 'Change photo'
                : 'Add photo'),
          ),
          if ((pickedFile != null || existingPhotoUrl != null) && onClear != null)
            TextButton(
              onPressed: onClear,
              child: const Text('Remove photo'),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (pickedFile != null) {
      return FutureBuilder<Uint8List>(
        future: pickedFile!.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        },
      );
    }
    if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: existingPhotoUrl!,
        fit: BoxFit.cover,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40),
      );
    }
    return const Icon(Icons.person_add_alt_1, size: 40, color: AppColors.textSecondary);
  }
}

/// Gender dropdown for member forms.
class MemberGenderField extends StatelessWidget {
  final MemberGender value;
  final ValueChanged<MemberGender> onChanged;

  const MemberGenderField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<MemberGender>(
      value: value,
      decoration: const InputDecoration(
        labelText: 'Gender',
        prefixIcon: Icon(Icons.wc_outlined),
      ),
      items: MemberGender.values
          .map(
            (g) => DropdownMenuItem(
              value: g,
              child: Text(g.label),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Circular avatar for cards and detail (photo or initials).
class MemberAvatar extends StatelessWidget {
  final FamilyTreeNode node;
  final double size;
  final Color? textColor;
  final Color? backgroundColor;

  const MemberAvatar({
    super.key,
    required this.node,
    this.size = 60,
    this.textColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final url = node.displayPhotoUrl;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _initialsFallback(),
              errorWidget: (_, __, ___) => _initialsFallback(),
            )
          : _initialsFallback(),
    );
  }

  Widget _initialsFallback() {
    return Center(
      child: Text(
        node.initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.bold,
          color: textColor ?? AppColors.primary,
        ),
      ),
    );
  }
}

/// Visual styling for family tree member cards by gender.
class MemberCardStyle {
  final LinearGradient? gradient;
  final Color? solidColor;
  final Border? border;
  final Color shadowColor;
  final bool useLightText;

  const MemberCardStyle({
    this.gradient,
    this.solidColor,
    this.border,
    required this.shadowColor,
    required this.useLightText,
  });
}

MemberCardStyle memberCardStyleForGender(MemberGender gender) {
  switch (gender) {
    case MemberGender.male:
      return MemberCardStyle(
        gradient: AppColors.maleMemberGradient,
        shadowColor: AppColors.maleCardEnd.withOpacity(0.35),
        useLightText: true,
      );
    case MemberGender.female:
      return MemberCardStyle(
        gradient: AppColors.femaleMemberGradient,
        shadowColor: AppColors.femaleCardEnd.withOpacity(0.35),
        useLightText: true,
      );
    case MemberGender.other:
    case MemberGender.unspecified:
      return MemberCardStyle(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.neutralCardStart,
            AppColors.neutralCardEnd,
          ],
        ),
        border: Border.all(color: AppColors.neutralCardBorder),
        shadowColor: Colors.black.withOpacity(0.08),
        useLightText: false,
      );
  }
}

/// Edit existing relationships and add new links (saved to database on save).
class MemberEditRelationshipsSection extends StatelessWidget {
  final FamilyTreeNode member;
  final List<MemberRelationshipDisplay> existing;
  final Set<String> removedRelationshipIds;
  final List<FamilyTreeNode> linkableMembers;
  final String? newRelatedMemberId;
  final MemberLinkType newLinkType;
  final ValueChanged<String> onRemoveRelationship;
  final ValueChanged<String?> onNewRelatedChanged;
  final ValueChanged<MemberLinkType> onNewLinkTypeChanged;

  const MemberEditRelationshipsSection({
    super.key,
    required this.member,
    required this.existing,
    required this.removedRelationshipIds,
    required this.linkableMembers,
    required this.newRelatedMemberId,
    required this.newLinkType,
    required this.onRemoveRelationship,
    required this.onNewRelatedChanged,
    required this.onNewLinkTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final visible = existing
        .where((e) => !removedRelationshipIds.contains(e.relationship.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Relationships',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          const Text(
            'No relationships yet.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...visible.map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(genderIcon(item.otherMember.gender)),
                title: Text(item.subtitle),
                subtitle: Text(item.label),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: AppColors.error),
                  onPressed: () => onRemoveRelationship(item.relationship.id),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        MemberRelationFields(
          existingMembers: linkableMembers
              .where((n) => n.id != member.id)
              .toList(),
          relatedMemberId: newRelatedMemberId,
          linkType: newLinkType,
          onRelatedChanged: onNewRelatedChanged,
          onLinkTypeChanged: onNewLinkTypeChanged,
        ),
      ],
    );
  }
}

IconData genderIcon(MemberGender gender) {
  switch (gender) {
    case MemberGender.male:
      return Icons.male;
    case MemberGender.female:
      return Icons.female;
    case MemberGender.other:
      return Icons.transgender;
    case MemberGender.unspecified:
      return Icons.person_outline;
  }
}
