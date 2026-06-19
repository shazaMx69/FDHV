import 'package:family_digital_heritage_vault/src/core/models/memory.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/auth/state/auth_provider.dart';
import 'package:family_digital_heritage_vault/src/features/family/presentation/family_setup_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_detail_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_upload_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  final void Function(int tabIndex)? onSwitchTab;
  final VoidCallback? onOpenUpload;

  const DashboardScreen({super.key, this.onSwitchTab, this.onOpenUpload});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilyProvider>();
    final memories = context.watch<MemoryProvider>();

    final userName = _extractName(
      auth.user?.userMetadata?['full_name'] as String? ??
          auth.user?.email ??
          'User',
    );
    final hasFamily = family.hasFamily;
    final memberCount = family.familyTree?.nodes.length ?? 0;
    final memoryCount = memories.totalCount;
    final recentMemories = memories.getRecent(limit: 4);
    final isLoadingMemories = memories.loading && memories.memories.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _DashboardHeader(
              userName: userName,
              family: family,
              memories: memories,
              memberCount: memberCount,
              memoryCount: memoryCount,
              onFamilyChanged: (id) {
                final selected = family.families.firstWhere((f) => f.id == id);
                family.selectFamily(selected);
                context.read<MemoryProvider>().loadMemories(id);
              },
            ),
          ),

          // ── Get-started prompt ────────────────────────────────────────
          if (!hasFamily)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _GetStartedCard(
                  onCreateFamily: () => showCreateFamilyDialog(context),
                ),
              ),
            ),

          // ── Quick Actions ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _QuickActionsSection(
                hasFamily: hasFamily,
                onFamily: () => hasFamily
                    ? onSwitchTab?.call(1)
                    : showCreateFamilyDialog(context),
                onTree: () => onSwitchTab?.call(1),
                onAddMemory: onOpenUpload ??
                    () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const MemoryUploadScreen()),
                        ),
                onGallery: () => onSwitchTab?.call(2),
                onInvite: () {
                  if (!hasFamily) {
                    showCreateFamilyDialog(context);
                    return;
                  }
                  onSwitchTab?.call(3);
                },
              ),
            ),
          ),

          // ── Recent Memories header ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Memories',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onSwitchTab?.call(2),
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ),

          // ── Recent Memories list ──────────────────────────────────────
          if (isLoadingMemories)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => const _MemoryTileSkeleton(),
                  childCount: 3,
                ),
              ),
            )
          else if (memories.error != null && memories.memories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _ErrorCard(
                  message: memories.error!,
                  onRetry: () {
                    final id = family.selectedFamily?.id;
                    if (id != null) memories.loadMemories(id);
                  },
                ),
              ),
            )
          else if (recentMemories.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _EmptyMemoriesCard(
                  onAdd: onOpenUpload ??
                      () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const MemoryUploadScreen()),
                          ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final memory = recentMemories[i];
                    return _RecentMemoryTile(
                      memory: memory,
                      onTap: () {
                        if (memory.isLocked) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(memory.inheritanceLockLabel)),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemoryDetailScreen(memory: memory),
                          ),
                        );
                      },
                    );
                  },
                  childCount: recentMemories.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  String _extractName(String value) {
    if (value.contains('@')) {
      final local = value.split('@').first;
      if (local.isEmpty) return 'User';
      // Capitalise each word segment separated by dots/underscores/hyphens
      return local
          .split(RegExp(r'[._\-]'))
          .map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1))
          .join(' ');
    }
    return value.trim().isEmpty ? 'User' : value.trim();
  }
}

// ── Header ─────────────────────────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String userName;
  final FamilyProvider family;
  final MemoryProvider memories;
  final int memberCount;
  final int memoryCount;
  final ValueChanged<String> onFamilyChanged;

  const _DashboardHeader({
    required this.userName,
    required this.family,
    required this.memories,
    required this.memberCount,
    required this.memoryCount,
    required this.onFamilyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final familyName = family.selectedFamily?.name ?? 'No family yet';

    return Container(
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Notification icon — show badge when there's a pending invite
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Notifications coming soon.')),
                        ),
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Family pill
              if (family.families.length > 1)
                _FamilySelectorPill(
                  selectedId: family.selectedFamily?.id,
                  families: family.families,
                  onChanged: onFamilyChanged,
                )
              else
                _FamilyNamePill(name: familyName),

              const SizedBox(height: 20),

              // Stats
              Row(
                children: [
                  _StatCard(
                    value: memoryCount,
                    label: 'Memories',
                    icon: Icons.photo_library_outlined,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: memberCount,
                    label: 'Members',
                    icon: Icons.people_outline,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: memories.photoCount,
                    label: 'Photos',
                    icon: Icons.image_outlined,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilySelectorPill extends StatelessWidget {
  final String? selectedId;
  final List families;
  final ValueChanged<String> onChanged;

  const _FamilySelectorPill({
    required this.selectedId,
    required this.families,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedId,
          dropdownColor: AppColors.primaryDark,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
          items: families
              .map((f) => DropdownMenuItem<String>(
                    value: f.id as String,
                    child: Text(f.name as String,
                        style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (id) {
            if (id != null) onChanged(id);
          },
        ),
      ),
    );
  }
}

class _FamilyNamePill extends StatelessWidget {
  final String name;
  const _FamilyNamePill({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.home_outlined, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Get-started ─────────────────────────────────────────────────────────────

class _GetStartedCard extends StatelessWidget {
  final VoidCallback onCreateFamily;
  const _GetStartedCard({required this.onCreateFamily});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.07),
            AppColors.primaryLight.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.family_restroom,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your family vault',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Unlock the tree, memories, and invites.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ElevatedButton(
                    onPressed: onCreateFamily,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                    child: const Text('Get Started'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick Actions ────────────────────────────────────────────────────────────

class _QuickActionsSection extends StatelessWidget {
  final bool hasFamily;
  final VoidCallback onFamily;
  final VoidCallback onTree;
  final VoidCallback onAddMemory;
  final VoidCallback onGallery;
  final VoidCallback onInvite;

  const _QuickActionsSection({
    required this.hasFamily,
    required this.onFamily,
    required this.onTree,
    required this.onAddMemory,
    required this.onGallery,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        icon: hasFamily ? Icons.manage_accounts_outlined : Icons.add_home_outlined,
        label: hasFamily ? 'Manage\nFamily' : 'Create\nFamily',
        color: AppColors.primary,
        onTap: onFamily,
      ),
      (
        icon: Icons.account_tree_outlined,
        label: 'Family\nTree',
        color: AppColors.primaryLight,
        onTap: onTree,
      ),
      (
        icon: Icons.add_photo_alternate_outlined,
        label: 'Add\nMemory',
        color: AppColors.accent,
        onTap: onAddMemory,
      ),
      (
        icon: Icons.photo_library_outlined,
        label: 'Gallery',
        color: AppColors.primaryDark,
        onTap: onGallery,
      ),
      (
        icon: Icons.person_add_outlined,
        label: 'Invite\nMember',
        color: const Color(0xFF7C3AED),
        onTap: onInvite,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: actions.map((a) => _ActionTile(
            icon: a.icon,
            label: a.label,
            color: a.color,
            onTap: a.onTap,
          )).toList(),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Empty / Error / Skeleton states ─────────────────────────────────────────

class _EmptyMemoriesCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyMemoriesCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 52,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          const Text(
            'No memories yet',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'Start preserving your family moments',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Memory'),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline,
              color: AppColors.error.withValues(alpha: 0.7), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.error.withValues(alpha: 0.85)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MemoryTileSkeleton extends StatelessWidget {
  const _MemoryTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 11,
                  width: 120,
                  decoration: BoxDecoration(
                    color: AppColors.divider.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent Memory Tile ───────────────────────────────────────────────────────

class _RecentMemoryTile extends StatelessWidget {
  final Memory memory;
  final VoidCallback onTap;

  const _RecentMemoryTile({required this.memory, required this.onTap});

  static IconData _iconForType(MediaType type) {
    switch (type) {
      case MediaType.video:
        return Icons.videocam_outlined;
      case MediaType.audio:
        return Icons.mic_outlined;
      case MediaType.document:
        return Icons.description_outlined;
      default:
        return Icons.photo_outlined;
    }
  }

  static Color _colorForType(MediaType type) {
    switch (type) {
      case MediaType.video:
        return const Color(0xFF2563EB);
      case MediaType.audio:
        return const Color(0xFF059669);
      case MediaType.document:
        return const Color(0xFFD97706);
      default:
        return AppColors.primary;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _colorForType(memory.mediaType);
    final locked = memory.isLocked;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: locked
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: locked
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      locked ? Icons.lock_clock : _iconForType(memory.mediaType),
                      color: locked ? AppColors.primary : typeColor,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      memory.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: locked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (locked)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              memory.inheritanceLockLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          )
                        else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              memory.mediaType.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: typeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimeAgo(memory.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.chevron_right,
                color: locked ? AppColors.primary : AppColors.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
