import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/core/models/memory.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class InheritanceRuleScreen extends StatefulWidget {
  final Memory memory;

  const InheritanceRuleScreen({super.key, required this.memory});

  @override
  State<InheritanceRuleScreen> createState() => _InheritanceRuleScreenState();
}

class _InheritanceRuleScreenState extends State<InheritanceRuleScreen> {
  ConditionType _selectedCondition = ConditionType.unlockAtDate;
  FamilyTreeNode? _selectedBeneficiary;
  DateTime? _unlockDate;
  int? _unlockAge;
  bool _saving = false;

  final _ageController = TextEditingController();

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _unlockDate ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 100)),
    );
    if (date != null) {
      setState(() => _unlockDate = date);
    }
  }

  Future<void> _saveRule() async {
    if (_selectedBeneficiary == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a beneficiary')),
      );
      return;
    }

    if (_selectedCondition == ConditionType.unlockAtDate && _unlockDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an unlock date')),
      );
      return;
    }

    if (_selectedCondition == ConditionType.unlockAtAge && _unlockAge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an unlock age')),
      );
      return;
    }

    if (_selectedCondition == ConditionType.unlockOnBirthday &&
        _selectedBeneficiary?.birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beneficiary must have a birth date for birthday unlock'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final familyProvider = context.read<FamilyProvider>();
    final memoryProvider = context.read<MemoryProvider>();

    final success = await memoryProvider.setInheritanceRule(
      memoryId: widget.memory.id,
      familyId: familyProvider.selectedFamily!.id,
      beneficiaryNodeId: _selectedBeneficiary!.id,
      conditionType: _selectedCondition,
      unlockDate: _selectedCondition == ConditionType.unlockAtDate ? _unlockDate : null,
      unlockAge: _selectedCondition == ConditionType.unlockAtAge ? _unlockAge : null,
    );

    setState(() => _saving = false);

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inheritance rule created successfully!')),
        );
      } else if (memoryProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(memoryProvider.error!)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyProvider = context.watch<FamilyProvider>();
    final nodes = familyProvider.familyTree?.nodes ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Schedule memory for member',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Memory info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getMediaIcon(widget.memory.mediaType),
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.memory.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.memory.mediaType.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary.withOpacity(0.7),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Choose who receives this memory and when it unlocks — on a specific date, when they reach an age, or on their birthday each year.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Beneficiary selection
            const Text(
              'Send to family member',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Who should receive this memory when the rule is satisfied?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (nodes.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Center(
                  child: Text(
                    'No family members in tree yet.\nAdd members to your family tree first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: nodes.map((node) {
                    final isSelected = _selectedBeneficiary?.id == node.id;
                    return InkWell(
                      onTap: () => setState(() => _selectedBeneficiary = node),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary.withOpacity(0.05) : null,
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.divider.withOpacity(0.5),
                              width: nodes.last == node ? 0 : 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isSelected
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.1),
                              child: Text(
                                node.initials,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    node.fullName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (node.birthDate != null)
                                    Text(
                                      'Born ${DateFormat.yMMM().format(node.birthDate!)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),
            // Condition type selection
            const Text(
              'Unlock Condition',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'When should this memory become available?',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Condition type options
            _ConditionOption(
              icon: Icons.calendar_today,
              title: 'Unlock on specific date',
              subtitle: 'Memory becomes available on a chosen date',
              isSelected: _selectedCondition == ConditionType.unlockAtDate,
              onTap: () => setState(() => _selectedCondition = ConditionType.unlockAtDate),
            ),
            const SizedBox(height: 12),
            _ConditionOption(
              icon: Icons.cake,
              title: 'Unlock at age',
              subtitle: 'Memory unlocks when beneficiary reaches a certain age',
              isSelected: _selectedCondition == ConditionType.unlockAtAge,
              onTap: () => setState(() => _selectedCondition = ConditionType.unlockAtAge),
            ),
            const SizedBox(height: 12),
            _ConditionOption(
              icon: Icons.celebration,
              title: 'Unlock on birthday',
              subtitle: 'Visible only on the beneficiary\'s birthday each year',
              isSelected: _selectedCondition == ConditionType.unlockOnBirthday,
              onTap: () => setState(() => _selectedCondition = ConditionType.unlockOnBirthday),
            ),
            const SizedBox(height: 24),
            // Condition value input
            if (_selectedCondition == ConditionType.unlockOnBirthday) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedBeneficiary?.birthDate != null
                            ? 'Unlocks each year on ${DateFormat.MMMd().format(_selectedBeneficiary!.birthDate!)}'
                            : 'Select a beneficiary with a birth date in the family tree.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_selectedCondition == ConditionType.unlockAtDate) ...[
              const Text(
                'Select Unlock Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event,
                        color: _unlockDate != null ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _unlockDate != null
                            ? DateFormat.yMMMMd().format(_unlockDate!)
                            : 'Tap to select date',
                        style: TextStyle(
                          fontSize: 15,
                          color: _unlockDate != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Enter Unlock Age',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g., 18, 21, 25',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  suffixText: 'years old',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _unlockAge = int.tryParse(value);
                  });
                },
              ),
              const SizedBox(height: 8),
              if (_selectedBeneficiary?.birthDate != null && _unlockAge != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Memory will unlock on ${DateFormat.yMMMMd().format(DateTime(_selectedBeneficiary!.birthDate!.year + _unlockAge!, _selectedBeneficiary!.birthDate!.month, _selectedBeneficiary!.birthDate!.day))}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 32),
            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveRule,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_clock),
                label: Text(
                  _saving ? 'Creating Rule...' : 'Create Inheritance Rule',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  IconData _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.image:
        return Icons.photo;
      case MediaType.video:
        return Icons.videocam;
      case MediaType.audio:
        return Icons.audiotrack;
      case MediaType.document:
        return Icons.description;
    }
  }
}

class _ConditionOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConditionOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
              )
            else
              Icon(
                Icons.circle_outlined,
                color: AppColors.textSecondary.withOpacity(0.5),
              ),
          ],
        ),
      ),
    );
  }
}
