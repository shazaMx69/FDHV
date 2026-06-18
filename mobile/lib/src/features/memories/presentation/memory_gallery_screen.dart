import 'package:cached_network_image/cached_network_image.dart';
import 'package:family_digital_heritage_vault/src/core/models/memory.dart';
import 'package:family_digital_heritage_vault/src/core/services/api_client.dart';
import 'package:family_digital_heritage_vault/src/core/services/service_locator.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_detail_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_upload_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MemoryGalleryScreen extends StatefulWidget {
  const MemoryGalleryScreen({super.key});

  @override
  State<MemoryGalleryScreen> createState() => _MemoryGalleryScreenState();
}

class _MemoryGalleryScreenState extends State<MemoryGalleryScreen> {
  final TextEditingController _searchController = TextEditingController();
  MediaType? _selectedFilter;
  bool _showInheritanceOnly = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Memory> _getFilteredMemories(MemoryProvider provider) {
    var memories = provider.memories;

    // Apply media type filter
    if (_selectedFilter != null) {
      memories = provider.filterByType(_selectedFilter);
    }

    if (_showInheritanceOnly) {
      memories = memories.where((m) => m.isLocked).toList();
    }

    // Apply search filter
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      memories = memories.where((m) {
        return m.title.toLowerCase().contains(query.toLowerCase()) ||
            (m.description?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (m.event?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (m.tags?.any((t) => t.toLowerCase().contains(query.toLowerCase())) ?? false);
      }).toList();
    }

    return memories;
  }

  @override
  Widget build(BuildContext context) {
    final memoryProvider = context.watch<MemoryProvider>();
    final filteredMemories = _getFilteredMemories(memoryProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Header with gradient
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.headerGradient,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
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
                            'Memories',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_library, color: Colors.white, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  '${memoryProvider.totalCount}',
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
                        'Your Family Memories',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Search bar
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search memories...',
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
                              color: AppColors.textSecondary.withValues(alpha: 0.7),
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
          // Filter chips
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      count: memoryProvider.totalCount,
                      isSelected: _selectedFilter == null,
                      onSelected: () => setState(() => _selectedFilter = null),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Photos',
                      count: memoryProvider.photoCount,
                      isSelected: _selectedFilter == MediaType.image,
                      onSelected: () => setState(() => _selectedFilter = MediaType.image),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Videos',
                      count: memoryProvider.videoCount,
                      isSelected: _selectedFilter == MediaType.video,
                      onSelected: () => setState(() => _selectedFilter = MediaType.video),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Audio',
                      count: memoryProvider.filterByType(MediaType.audio).length,
                      isSelected: _selectedFilter == MediaType.audio,
                      onSelected: () => setState(() => _selectedFilter = MediaType.audio),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Docs',
                      count: memoryProvider.filterByType(MediaType.document).length,
                      isSelected: _selectedFilter == MediaType.document,
                      onSelected: () => setState(() => _selectedFilter = MediaType.document),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Locked',
                      count: memoryProvider.memories.where((m) => m.isLocked).length,
                      isSelected: _showInheritanceOnly,
                      onSelected: () => setState(() {
                        _showInheritanceOnly = !_showInheritanceOnly;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Content
          if (memoryProvider.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredMemories.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(),
            )
          else
            // Memory grid
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
                    final memory = filteredMemories[index];
                    return _MemoryCard(
                      memory: memory,
                      onTap: () => _openMemory(context, memory),
                    );
                  },
                  childCount: filteredMemories.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: context.watch<FamilyProvider>().selectedFamily?.canEdit ?? false
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MemoryUploadScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _openMemory(BuildContext context, Memory memory) async {
    if (memory.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(memory.inheritanceLockLabel)),
      );
      return;
    }
    try {
      final fresh = await services.memoryService.getMemory(
        memory.id,
        familyId: memory.familyId,
      );
      if (!context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemoryDetailScreen(memory: fresh),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final message = e is ApiException
          ? e.message
          : e.toString().replaceFirst('ApiException: ', '').split(' (status:').first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open memory: $message')),
      );
    }
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty || _selectedFilter != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.photo_library_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isSearching ? 'No memories found' : 'No memories yet',
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
                  : 'Start preserving your family moments',
              style: const TextStyle(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MemoryUploadScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Memory'),
              ),
            ] else ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _selectedFilter = null);
                },
                child: const Text('Clear filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const _MemoryCard({
    required this.memory,
    required this.onTap,
  });

  IconData get _typeIcon {
    switch (memory.mediaType) {
      case MediaType.video:
        return Icons.play_circle_outline;
      case MediaType.audio:
        return Icons.music_note;
      case MediaType.document:
        return Icons.article_outlined;
      case MediaType.image:
        return Icons.image_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background - image or gradient placeholder
              _buildBackground(),
              // Title overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        memory.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat.yMMMd().format(memory.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (memory.isLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_clock, color: Colors.white, size: 36),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            memory.inheritanceLockLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Type badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _typeIcon,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBackground() {
    final imageUrl = memory.displayUrl;
    if (imageUrl != null && memory.mediaType == MediaType.image) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.gradientStart.withValues(alpha: 0.7),
                AppColors.gradientEnd.withValues(alpha: 0.9),
              ],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gradientStart.withValues(alpha: 0.7),
            AppColors.gradientEnd.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          _typeIcon,
          size: 48,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
