import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class InviteAcceptScreen extends StatefulWidget {
  final String token;

  const InviteAcceptScreen({super.key, required this.token});

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  bool _accepting = false;
  String? _previewFamily;
  String? _previewAccess;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    try {
      final preview =
          await context.read<FamilyProvider>().previewInvitation(widget.token);
      if (!mounted) return;
      setState(() {
        _previewFamily = preview['familyName'] as String?;
        _previewAccess = preview['accessLevel'] == 'view' ? 'View only' : 'Can edit';
      });
    } catch (_) {
      // Preview is optional; accept may still work.
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final message =
        await context.read<FamilyProvider>().acceptInvitation(widget.token);
    if (!mounted) return;
    setState(() => _accepting = false);

    if (message != null && !message.startsWith('Failed')) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<FamilyProvider>().error ?? 'Could not accept invitation',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family invitation'),
        backgroundColor: AppColors.background,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.mail_outline, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _previewFamily != null
                  ? 'Join $_previewFamily'
                  : 'Join a family vault',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (_previewAccess != null) ...[
              const SizedBox(height: 8),
              Text(
                'Access: $_previewAccess',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Accepting will add this family to your account. View-only members can browse but not edit the tree or upload memories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: _accepting ? null : _accept,
              child: _accepting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Accept invitation'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _accepting ? null : () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
