import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family/presentation/invite_accept_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/family_tree_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_gallery_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/presentation/memory_upload_screen.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:family_digital_heritage_vault/src/features/profile/presentation/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  void _switchTab(int index) => setState(() => _currentIndex = index);

  @override
  void initState() {
    super.initState();
    // Each time MainScreen mounts (fresh login or app reopen), load data.
    // No _initialized guard — the splash screen already prevents double-mounts
    // and providers are reset on sign-out, so loading is always fresh here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    final familyProvider = context.read<FamilyProvider>();
    await familyProvider.loadFamilies();

    if (!mounted) return;
    final selectedFamily = familyProvider.selectedFamily;
    if (selectedFamily != null) {
      await context.read<MemoryProvider>().loadMemories(selectedFamily.id);
    }

    if (mounted) _handleInviteDeepLink();
  }

  void _handleInviteDeepLink() {
    final token = Uri.base.queryParameters['invite'];
    if (token == null || token.isEmpty || !mounted) return;

    context.read<FamilyProvider>().setPendingInviteToken(token);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InviteAcceptScreen(token: token)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      DashboardScreen(
        onSwitchTab: _switchTab,
        onOpenUpload: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoryUploadScreen()),
        ),
      ),
      const FamilyTreeScreen(),
      const MemoryGalleryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        sizing: StackFit.expand,
        children: screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  static const _items = [
    (icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    (icon: Icons.account_tree_outlined, activeIcon: Icons.account_tree, label: 'Tree'),
    (icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library, label: 'Memories'),
    (icon: Icons.person_outline, activeIcon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.divider, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final active = currentIndex == i;
              return Expanded(
                child: _NavTile(
                  icon: item.icon,
                  activeIcon: item.activeIcon,
                  label: item.label,
                  isActive: active,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? AppColors.primary : AppColors.textSecondary,
                letterSpacing: isActive ? 0.2 : 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
