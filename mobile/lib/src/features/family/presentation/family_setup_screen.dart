import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens a dialog to create a family vault (used from the home dashboard).
Future<void> showCreateFamilyDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final formKey = GlobalKey<FormState>();
  var loading = false;
  String? dialogError;

  await showDialog<void>(
    context: context,
    barrierDismissible: !loading,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        Future<void> submit() async {
          if (!formKey.currentState!.validate()) return;

          setDialogState(() {
            loading = true;
            dialogError = null;
          });

          final familyProvider = dialogContext.read<FamilyProvider>();
          await familyProvider.createFamily(nameController.text.trim());

          if (!dialogContext.mounted) return;

          if (familyProvider.error != null) {
            setDialogState(() {
              loading = false;
              dialogError = familyProvider.error;
            });
            return;
          }

          final familyId = familyProvider.selectedFamily?.id;
          if (familyId != null) {
            try {
              await dialogContext.read<MemoryProvider>().loadMemories(familyId);
            } catch (_) {
              // Family was created; memories can load later.
            }
          }

          if (dialogContext.mounted) {
            Navigator.pop(dialogContext);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Family vault created!')),
              );
            }
          }
        }

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.family_restroom, color: AppColors.primary),
              SizedBox(width: 12),
              Expanded(child: Text('Create Family Vault')),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name your family to start adding members, memories, and your tree.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Family Name',
                    hintText: 'e.g., The Smith Family',
                    prefixIcon: const Icon(Icons.people_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  enabled: !loading,
                  autofocus: true,
                  onFieldSubmitted: loading ? null : (_) => submit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a family name';
                    }
                    if (value.trim().length < 2) {
                      return 'At least 2 characters';
                    }
                    return null;
                  },
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withOpacity(0.3)),
                    ),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: loading ? null : () => submit(),
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add, size: 20),
              label: Text(loading ? 'Creating...' : 'Create'),
            ),
          ],
        );
      },
    ),
  );

  nameController.dispose();
}
