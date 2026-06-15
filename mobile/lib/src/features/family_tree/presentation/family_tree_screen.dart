import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/core/services/service_locator.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/family/presentation/family_setup_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/family_tree_diagram_view.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/member_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class FamilyTreeScreen extends StatefulWidget {
  const FamilyTreeScreen({super.key});

  @override
  State<FamilyTreeScreen> createState() => _FamilyTreeScreenState();
}

class _FamilyTreeScreenState extends State<FamilyTreeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedGeneration = 'All';
  final List<String> _generations = FamilyTreeNode.generationFilterChips;
  final Set<String> _favoriteIds = {};
  bool _showTreeDiagram = true;

  List<FamilyTreeNode> _getFilteredMembers(FamilyProvider provider) {
    var nodes = provider.familyTree?.nodes ?? [];

    // Filter by search
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      nodes = nodes.where((n) {
        return n.fullName.toLowerCase().contains(query);
      }).toList();
    }

    final filterLevel = FamilyTreeNode.filterLevelForChip(_selectedGeneration);
    if (filterLevel != null) {
      nodes = nodes.where((n) {
        return FamilyTreeNode.generationFromMetadata(n.metadata) == filterLevel;
      }).toList();
    }

    nodes.sort((a, b) {
      final g = a.generation.compareTo(b.generation);
      if (g != 0) return g;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return nodes;
  }

  bool get _showGenerationSections =>
      _selectedGeneration == 'All' && _searchController.text.trim().isEmpty;

  Future<void> _downloadTreePdf(BuildContext context, FamilyProvider provider) async {
    final tree = provider.familyTree;
    if (tree == null || tree.nodes.isEmpty) return;
    final familyName = provider.selectedFamily?.name ?? 'Family Tree';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Preparing family tree PDF…')),
    );
    try {
      await services.pdfExportService.shareFamilyTreePdf(
        tree: tree,
        familyName: familyName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = context.watch<FamilyProvider>();
    final filteredMembers = _getFilteredMembers(familyProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with gradient
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Family Tree',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.people, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${familyProvider.familyTree?.nodes.length ?? 0}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        familyProvider.selectedFamily?.name ?? 'Your Family Heritage',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      if (familyProvider.families.length > 1) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: familyProvider.selectedFamily?.id,
                              items: familyProvider.families
                                  .map(
                                    (f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) {
                                if (id == null) return;
                                final f = familyProvider.families
                                    .firstWhere((fam) => fam.id == id);
                                familyProvider.selectFamily(f);
                              },
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(
                                  value: true,
                                  label: Text('Tree'),
                                  icon: Icon(Icons.account_tree, size: 18),
                                ),
                                ButtonSegment(
                                  value: false,
                                  label: Text('Cards'),
                                  icon: Icon(Icons.grid_view, size: 18),
                                ),
                              ],
                              selected: {_showTreeDiagram},
                              onSelectionChanged: (s) {
                                setState(() => _showTreeDiagram = s.first);
                              },
                              style: ButtonStyle(
                                backgroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return Colors.white.withOpacity(0.2);
                                }),
                                foregroundColor: WidgetStateProperty.resolveWith((states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primary;
                                  }
                                  return Colors.white;
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: familyProvider.familyTree == null ||
                                    familyProvider.familyTree!.nodes.isEmpty
                                ? null
                                : () => _downloadTreePdf(context, familyProvider),
                            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                            tooltip: 'Download tree as PDF',
                          ),
                          IconButton(
                            onPressed: () => showCreateFamilyDialog(context),
                            icon: const Icon(Icons.add_home_work, color: Colors.white),
                            tooltip: 'Add family',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search family member...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 15,
                            ),
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary.withOpacity(0.7),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() {});
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Generation filter chips
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _generations.map((gen) {
                    final isSelected = _selectedGeneration == gen;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(gen),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedGeneration = gen;
                          });
                        },
                        backgroundColor: Colors.white,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color:
                                isSelected ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                        showCheckmark: false,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          // Content
          if (familyProvider.selectedFamily == null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.family_restroom, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'No family selected',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => showCreateFamilyDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Family'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (familyProvider.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredMembers.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else if (_showTreeDiagram)
            SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(
                color: AppColors.background,
                child: FamilyTreeDiagramView(
                  tree: (familyProvider.familyTree ??
                          FamilyTree(nodes: const [], relationships: const []))
                      .subsetForNodes(filteredMembers),
                  onNodeTap: (node) => _showMemberDetail(context, node),
                ),
              ),
            )
          else if (_showGenerationSections)
            ..._buildGenerationSectionSlivers(context, filteredMembers)
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final node = filteredMembers[index];
                    return _MemberCard(
                      node: node,
                      isFavorite: _favoriteIds.contains(node.id),
                      onTap: () => _showMemberDetail(context, node),
                      onFavoriteToggle: () {
                        setState(() {
                          if (_favoriteIds.contains(node.id)) {
                            _favoriteIds.remove(node.id);
                          } else {
                            _favoriteIds.add(node.id);
                          }
                        });
                      },
                    );
                  },
                  childCount: filteredMembers.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddMemberDialog(context);
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  List<Widget> _buildGenerationSectionSlivers(
    BuildContext context,
    List<FamilyTreeNode> members,
  ) {
    final byGeneration = <int, List<FamilyTreeNode>>{};
    for (final node in members) {
      byGeneration.putIfAbsent(node.generation, () => []).add(node);
    }
    final levels = byGeneration.keys.toList()..sort();

    final slivers = <Widget>[];
    for (final level in levels) {
      final group = byGeneration[level]!
        ..sort((a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      slivers.add(
        SliverToBoxAdapter(
          child: _GenerationSectionHeader(
            level: level,
            count: group.length,
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final node = group[index];
                return _MemberCard(
                  node: node,
                  isFavorite: _favoriteIds.contains(node.id),
                  onTap: () => _showMemberDetail(context, node),
                  onFavoriteToggle: () {
                    setState(() {
                      if (_favoriteIds.contains(node.id)) {
                        _favoriteIds.remove(node.id);
                      } else {
                        _favoriteIds.add(node.id);
                      }
                    });
                  },
                );
              },
              childCount: group.length,
            ),
          ),
        ),
      );
    }
    return slivers;
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty || _selectedGeneration != 'All';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.family_restroom,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No members found' : 'No family members yet',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try adjusting your search or filters'
                  : 'Start building your family tree',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _showAddMemberDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Family Member'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedGeneration = 'All');
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMemberDetail(BuildContext context, FamilyTreeNode node) {
    final familyProvider = context.read<FamilyProvider>();
    final tree = familyProvider.familyTree;
    final genLabel = FamilyTreeNode.labelForGeneration(
      FamilyTreeNode.generationFromMetadata(node.metadata),
    );
    final rels = tree?.relationshipsInvolving(node.id) ?? [];
    final children = tree?.getChildrenOf(node.id) ?? [];
    final spouses = tree?.getSpousesOf(node.id) ?? [];
    final parents = tree?.getParentsOf(node.id) ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                  children: [
                    MemberAvatar(
                      node: node,
                      size: 88,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      node.fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _MetaChip(
                          icon: Icons.layers_outlined,
                          label: genLabel,
                        ),
                        if (node.gender != MemberGender.unspecified)
                          _MetaChip(
                            icon: genderIcon(node.gender),
                            label: node.gender.label,
                          ),
                        _MetaChip(
                          icon: node.isDeceased ? Icons.spa : Icons.favorite_border,
                          label: node.isDeceased
                              ? 'Deceased'
                              : (spouses.isNotEmpty ? 'Married' : 'Single'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Birth/Death info
                    if (node.birthDate != null || node.deathDate != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (node.birthDate != null) ...[
                              const Icon(Icons.cake, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.yMMMd().format(node.birthDate!),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                            if (node.birthDate != null && node.deathDate != null)
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(' - ', style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            if (node.deathDate != null) ...[
                              const Icon(Icons.spa, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat.yMMMd().format(node.deathDate!),
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (parents.isNotEmpty || spouses.isNotEmpty || children.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Relationships',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (parents.isNotEmpty)
                        _RelationListTile(
                          title: 'Parents',
                          names: parents.map((n) => n.fullName).join(', '),
                        ),
                      if (spouses.isNotEmpty)
                        _RelationListTile(
                          title: 'Spouse${spouses.length > 1 ? 's' : ''}',
                          names: spouses.map((n) => n.fullName).join(', '),
                        ),
                      if (children.isNotEmpty)
                        _RelationListTile(
                          title: 'Children',
                          names: children.map((n) => n.fullName).join(', '),
                        ),
                      for (final r in rels)
                        if (!['Parent', 'Child', 'Spouse'].contains(r.label))
                          _RelationListTile(title: r.label, names: r.otherMember.fullName),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.photo_library,
                          label: 'Memories',
                          onTap: () {
                            Navigator.pop(ctx);
                            // TODO: Navigate to member's memories with filter
                          },
                        ),
                        _ActionButton(
                          icon: Icons.edit,
                          label: 'Edit',
                          onTap: () {
                            Navigator.pop(ctx);
                            _showEditMemberDialog(context, node);
                          },
                        ),
                        _ActionButton(
                          icon: Icons.delete_outline,
                          label: 'Delete',
                          onTap: () {
                            Navigator.pop(ctx);
                            _confirmDelete(context, node);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, FamilyTreeNode node) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Family Member'),
        content: Text('Are you sure you want to remove ${node.fullName} from the family tree?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final familyProvider = context.read<FamilyProvider>();
              final success = await familyProvider.deleteFamilyMember(node.id);
              if (mounted && !success && familyProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(familyProvider.error!)),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context, FamilyTreeNode node) {
    final nameController = TextEditingController(text: node.fullName);
    final picker = ImagePicker();
    DateTime? birthDate = node.birthDate;
    DateTime? deathDate = node.deathDate;
    int generation = node.generation;
    MemberGender gender = node.gender;
    XFile? pickedPhoto;
    final removedRelationshipIds = <String>{};
    String? newRelatedMemberId;
    MemberLinkType newLinkType = MemberLinkType.parentOfNew;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Edit Family Member',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                MemberPhotoPicker(
                  pickedFile: pickedPhoto,
                  existingPhotoUrl: node.displayPhotoUrl,
                  onPickGallery: () async {
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1200,
                      maxHeight: 1200,
                      imageQuality: 85,
                    );
                    if (file != null) setSheetState(() => pickedPhoto = file);
                  },
                  onClear: pickedPhoto != null
                      ? () => setSheetState(() => pickedPhoto = null)
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 16),
                MemberGenderField(
                  value: gender,
                  onChanged: (g) => setSheetState(() => gender = g),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(
                    birthDate != null
                        ? 'Born: ${DateFormat.yMMMd().format(birthDate!)}'
                        : 'Set Birth Date',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: birthDate ?? DateTime(1980),
                      firstDate: DateTime(1800),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setSheetState(() => birthDate = date);
                    }
                  },
                ),
                // Generation selector
                DropdownButtonFormField<int>(
                  value: generation,
                  decoration: const InputDecoration(
                    labelText: 'Generation',
                    prefixIcon: Icon(Icons.layers_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Root')),
                    DropdownMenuItem(value: 1, child: Text('1st Generation')),
                    DropdownMenuItem(value: 2, child: Text('2nd Generation')),
                    DropdownMenuItem(value: 3, child: Text('3rd Generation')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => generation = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final fp = context.watch<FamilyProvider>();
                    final tree = fp.familyTree;
                    final existing = tree?.relationshipsInvolving(node.id) ?? [];
                    final allMembers = tree?.nodes ?? [];
                    return MemberEditRelationshipsSection(
                      member: node,
                      existing: existing,
                      removedRelationshipIds: removedRelationshipIds,
                      linkableMembers: allMembers,
                      newRelatedMemberId: newRelatedMemberId,
                      newLinkType: newLinkType,
                      onRemoveRelationship: (id) {
                        setSheetState(() => removedRelationshipIds.add(id));
                      },
                      onNewRelatedChanged: (id) {
                        setSheetState(() => newRelatedMemberId = id);
                      },
                      onNewLinkTypeChanged: (t) {
                        setSheetState(() => newLinkType = t);
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.isEmpty) return;
                      Navigator.pop(ctx);
                      final familyProvider = context.read<FamilyProvider>();
                      var success = await familyProvider.updateFamilyMember(
                        nodeId: node.id,
                        fullName: nameController.text.trim(),
                        birthDate: birthDate,
                        deathDate: deathDate,
                        generation: generation,
                        gender: gender,
                        photo: pickedPhoto,
                      );
                      if (success) {
                        for (final relId in removedRelationshipIds) {
                          final ok =
                              await familyProvider.deleteRelationship(relId);
                          if (!ok) success = false;
                        }
                      }
                      if (success &&
                          newRelatedMemberId != null &&
                          newRelatedMemberId!.isNotEmpty) {
                        final linked = await familyProvider.linkMembers(
                          nodeId: node.id,
                          relatedMemberId: newRelatedMemberId!,
                          linkType: newLinkType,
                        );
                        if (!linked) success = false;
                      }
                      if (mounted) {
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Member and relationships saved'),
                            ),
                          );
                        } else if (familyProvider.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(familyProvider.error!)),
                          );
                        }
                      }
                    },
                    child: const Text('Save Changes'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context) {
    final familyProvider = context.read<FamilyProvider>();
    if (familyProvider.families.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a family from Home first')),
      );
      showCreateFamilyDialog(context);
      return;
    }

    final nameController = TextEditingController();
    final picker = ImagePicker();
    DateTime? birthDate;
    int generation = 1;
    MemberGender gender = MemberGender.unspecified;
    XFile? pickedPhoto;
    bool saving = false;
    String? selectedFamilyId = familyProvider.selectedFamily?.id ?? familyProvider.families.first.id;
    String? relatedMemberId;
    MemberLinkType linkType = MemberLinkType.parentOfNew;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Add Family Member',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                FamilyPickerField(
                  selectedFamilyId: selectedFamilyId,
                  onChanged: (id) async {
                    if (id == null) return;
                    setSheetState(() {
                      selectedFamilyId = id;
                      relatedMemberId = null;
                    });
                    final fp = ctx.read<FamilyProvider>();
                    if (fp.selectedFamily?.id != id) {
                      final fam = fp.families.firstWhere((f) => f.id == id);
                      await fp.selectFamily(fam);
                      if (ctx.mounted) setSheetState(() {});
                    }
                  },
                ),
                const SizedBox(height: 16),
                MemberPhotoPicker(
                  pickedFile: pickedPhoto,
                  onPickGallery: () async {
                    final file = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1200,
                      maxHeight: 1200,
                      imageQuality: 85,
                    );
                    if (file != null) setSheetState(() => pickedPhoto = file);
                  },
                  onClear: pickedPhoto != null
                      ? () => setSheetState(() => pickedPhoto = null)
                      : null,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                MemberGenderField(
                  value: gender,
                  onChanged: (g) => setSheetState(() => gender = g),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(
                    birthDate != null
                        ? 'Birth Date: ${DateFormat.yMMMd().format(birthDate!)}'
                        : 'Set Birth Date (optional)',
                    style: TextStyle(
                      color: birthDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: birthDate ?? DateTime(1980),
                      firstDate: DateTime(1800),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setSheetState(() => birthDate = date);
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: generation,
                  decoration: const InputDecoration(
                    labelText: 'Generation',
                    prefixIcon: Icon(Icons.layers_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Root (Grandparents)')),
                    DropdownMenuItem(value: 1, child: Text('1st Generation (Parents)')),
                    DropdownMenuItem(value: 2, child: Text('2nd Generation (Self/Siblings)')),
                    DropdownMenuItem(value: 3, child: Text('3rd Generation (Children)')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setSheetState(() => generation = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final fp = context.watch<FamilyProvider>();
                    final members = fp.familyTree?.nodes ?? [];
                    final sameFamily = selectedFamilyId == fp.selectedFamily?.id;
                    final existing = sameFamily
                        ? members
                        : <FamilyTreeNode>[];
                    return MemberRelationFields(
                      existingMembers: existing,
                      relatedMemberId: relatedMemberId,
                      linkType: linkType,
                      onRelatedChanged: (id) => setSheetState(() => relatedMemberId = id),
                      onLinkTypeChanged: (t) => setSheetState(() => linkType = t),
                    );
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Please enter a name')),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            final familyProvider = context.read<FamilyProvider>();
                            if (selectedFamilyId != null &&
                                selectedFamilyId != familyProvider.selectedFamily?.id) {
                              final fam = familyProvider.families
                                  .firstWhere((f) => f.id == selectedFamilyId);
                              await familyProvider.selectFamily(fam);
                            }
                            final node = await familyProvider.addFamilyMember(
                              fullName: nameController.text.trim(),
                              birthDate: birthDate,
                              generation: generation,
                              gender: gender,
                              photo: pickedPhoto,
                              familyId: selectedFamilyId,
                              relatedMemberId: relatedMemberId,
                              linkType: relatedMemberId != null
                                  ? linkType
                                  : MemberLinkType.none,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              if (node != null) {
                                final warning = familyProvider.error;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      warning != null
                                          ? warning
                                          : '${node.fullName} added to family tree',
                                    ),
                                  ),
                                );
                                if (warning != null) {
                                  familyProvider.clearError();
                                }
                              } else if (familyProvider.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(familyProvider.error!),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Member'),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GenerationSectionHeader extends StatelessWidget {
  final int level;
  final int count;

  const _GenerationSectionHeader({
    required this.level,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              FamilyTreeNode.labelForGeneration(level),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count member${count == 1 ? '' : 's'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RelationListTile extends StatelessWidget {
  final String title;
  final String names;

  const _RelationListTile({required this.title, required this.names});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              names,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final FamilyTreeNode node;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteToggle;

  const _MemberCard({
    required this.node,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    final genLabel = FamilyTreeNode.labelForGeneration(node.generation);
    final gender = node.gender;
    final cardStyle = memberCardStyleForGender(gender);
    final titleColor = cardStyle.useLightText
        ? Colors.white
        : AppColors.textPrimary;
    final subtitleColor = cardStyle.useLightText
        ? Colors.white.withOpacity(0.85)
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: cardStyle.gradient,
            color: cardStyle.solidColor,
            borderRadius: BorderRadius.circular(16),
            border: cardStyle.border,
            boxShadow: [
              BoxShadow(
                color: cardStyle.shadowColor,
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MemberAvatar(node: node, size: 56),
                    const SizedBox(height: 10),
                    Text(
                      node.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      node.birthDate != null
                          ? '$genLabel • ${node.birthDate!.year}'
                          : genLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              if (gender != MemberGender.unspecified)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: cardStyle.useLightText
                          ? Colors.black.withOpacity(0.35)
                          : AppColors.divider,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      genderIcon(gender),
                      size: 16,
                      color: cardStyle.useLightText
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onFavoriteToggle,
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? (cardStyle.useLightText
                            ? AppColors.textOnPrimary
                            : AppColors.primary)
                        : (cardStyle.useLightText
                            ? Colors.white.withOpacity(0.7)
                            : AppColors.textSecondary),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
