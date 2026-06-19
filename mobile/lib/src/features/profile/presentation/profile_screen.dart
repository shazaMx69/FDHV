import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/auth/state/auth_provider.dart';
import 'package:family_digital_heritage_vault/src/features/family/presentation/family_setup_screen.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final family = context.watch<FamilyProvider>();
    final user = auth.user;
    final displayName = _displayName(user);
    final email = user?.email ?? 'Not signed in';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
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
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _initials(displayName, email),
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Member since ${_formatMemberSince(user?.createdAt)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      if (family.selectedFamily != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          family.selectedFamily!.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Settings'),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline,
                        title: 'Edit Profile',
                        onTap: () => _showEditProfileDialog(context, auth, displayName),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.notifications_outlined,
                        title: 'Notifications',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Notification settings coming soon.'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Family'),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.groups_outlined,
                        title: 'Manage Family',
                        onTap: () => _showManageFamilySheet(context, family),
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.person_add_outlined,
                        title: 'Invite Members',
                        onTap: () {
                          if (family.selectedFamily?.role != 'ADMIN') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only family Admins can send invitations.'),
                              ),
                            );
                            return;
                          }
                          _showInviteDialog(context, family);
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'Inheritance Rules',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Open a memory from the Memories tab, then set inheritance rules on its detail page.',
                              ),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('Support'),
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline,
                        title: 'Help & Support',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Contact your family vault admin for help.'),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: 'About',
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'Family Digital Heritage Vault',
                            applicationVersion: '1.0.0',
                            applicationLegalese: '© ${DateTime.now().year}',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loggingOut ? null : () => _confirmLogout(context),
                      icon: _loggingOut
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout, color: AppColors.error),
                      label: Text(
                        _loggingOut ? 'Signing out...' : 'Log Out',
                        style: const TextStyle(color: AppColors.error),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to access your family vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Log Out',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await context.read<AuthProvider>().signOut();
      context.read<FamilyProvider>().reset();
      context.read<MemoryProvider>().reset();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign out failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AuthProvider auth,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() => saving = true);
            try {
              await auth.updateDisplayName(controller.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated')),
                );
              }
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Update failed: $e')),
                );
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => saving = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('Edit Profile'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                enabled: !saving,
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Enter at least 2 characters';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: saving ? null : save,
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    controller.dispose();
  }

  void _showManageFamilySheet(BuildContext context, FamilyProvider family) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Your families',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                if (family.families.isEmpty)
                  const Text(
                    'No family vault yet. Create one to get started.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...family.families.map((f) {
                    final selected = family.selectedFamily?.id == f.id;
                    return ListTile(
                      title: Text(
                        f.name,
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        f.role,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppColors.primary)
                          : null,
                      onTap: () async {
                        await family.selectFamily(f);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Switched to ${f.name}')),
                          );
                        }
                      },
                    );
                  }),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    showCreateFamilyDialog(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create new family vault'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInviteDialog(BuildContext context, FamilyProvider family) async {
    if (!family.hasFamily) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a family vault first.')),
      );
      return;
    }

    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String selectedRole = 'ADULT';
    bool sending = false;
    String? resultMessage;
    bool success = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> send() async {
            if (!formKey.currentState!.validate()) return;
            setDialogState(() {
              sending = true;
              resultMessage = null;
            });

            final message = await family.inviteMember(
              email: emailController.text.trim(),
              role: selectedRole,
            );

            if (!dialogContext.mounted) return;
            setDialogState(() {
              sending = false;
              resultMessage = message;
              success = family.error == null;
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Invite Family Member',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: success
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF059669), size: 48),
                      const SizedBox(height: 12),
                      Text(
                        resultMessage ?? 'Invitation sent!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
                      ),
                    ],
                  )
                : Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'They will receive a branded email with a link to join your vault.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          enabled: !sending,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Enter an email address';
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Family Role',
                            prefixIcon: Icon(Icons.shield_outlined),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'ADMIN', child: Text('Admin — full access')),
                            DropdownMenuItem(value: 'ADULT', child: Text('Editor — upload & manage tree')),
                            DropdownMenuItem(value: 'JUNIOR', child: Text('Viewer — read only')),
                          ],
                          onChanged: sending ? null : (v) {
                            if (v != null) setDialogState(() => selectedRole = v);
                          },
                        ),
                        if (resultMessage != null && !success) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              resultMessage!,
                              style: const TextStyle(color: AppColors.error, fontSize: 13),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
            actions: success
                ? [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Done'),
                    ),
                  ]
                : [
                    TextButton(
                      onPressed: sending ? null : () => Navigator.pop(dialogContext),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      onPressed: sending ? null : send,
                      icon: sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_outlined, size: 18),
                      label: Text(sending ? 'Sending...' : 'Send Invite'),
                    ),
                  ],
          );
        },
      ),
    );

    emailController.dispose();
  }

  String _displayName(User? user) {
    if (user == null) return 'User';
    final fullName = user.userMetadata?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      return fullName.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first;
      if (local.isNotEmpty) {
        return local[0].toUpperCase() + local.substring(1);
      }
    }
    return 'User';
  }

  String _initials(String displayName, String email) {
    final source = displayName.isNotEmpty ? displayName : email;
    if (source.isEmpty) return 'U';
    return source.trim()[0].toUpperCase();
  }

  String _formatMemberSince(dynamic createdAt) {
    if (createdAt == null) return 'N/A';
    DateTime? date;
    if (createdAt is DateTime) {
      date = createdAt;
    } else if (createdAt is String) {
      date = DateTime.tryParse(createdAt);
    }
    if (date == null) return 'N/A';
    return '${date.month}/${date.year}';
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
