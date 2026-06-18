import 'dart:typed_data';

import 'package:family_digital_heritage_vault/src/core/models/memory.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family/state/family_provider.dart';
import 'package:family_digital_heritage_vault/src/features/memories/state/memory_provider.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class MemoryUploadScreen extends StatefulWidget {
  const MemoryUploadScreen({super.key});

  @override
  State<MemoryUploadScreen> createState() => _MemoryUploadScreenState();
}

class _MemoryUploadScreenState extends State<MemoryUploadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _eventController = TextEditingController();
  final _tagsController = TextEditingController();

  XFile? _selectedFile;
  MediaType _selectedMediaType = MediaType.image;
  DateTime? _eventDate;
  List<String> _selectedPeopleIds = [];
  bool _uploading = false;

  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _eventController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = picked;
        _selectedMediaType = MediaType.image;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (picked != null) {
      setState(() {
        _selectedFile = picked;
        _selectedMediaType = MediaType.video;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _selectedFile = picked;
        _selectedMediaType = MediaType.image;
      });
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _eventDate = date);
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() => _uploading = true);

    final familyProvider = context.read<FamilyProvider>();
    final memoryProvider = context.read<MemoryProvider>();

    if (familyProvider.selectedFamily == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No family selected')),
      );
      setState(() => _uploading = false);
      return;
    }

    final tags = _tagsController.text.isNotEmpty
        ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
        : null;

    final memory = await memoryProvider.uploadMemory(
      familyId: familyProvider.selectedFamily!.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      file: _selectedFile!,
      mediaType: _selectedMediaType,
      event: _eventController.text.trim().isNotEmpty
          ? _eventController.text.trim()
          : null,
      eventDate: _eventDate,
      tags: tags,
      peopleNodeIds: _selectedPeopleIds.isNotEmpty ? _selectedPeopleIds : null,
    );

    setState(() => _uploading = false);

    if (mounted) {
      if (memory != null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory uploaded successfully!')),
        );
      } else if (memoryProvider.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(memoryProvider.error!)),
        );
      }
    }
  }

  void _showPeopleSelector() {
    final familyProvider = context.read<FamilyProvider>();
    final nodes = familyProvider.familyTree?.nodes ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Tag Family Members',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        setState(() {});
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              if (nodes.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('No family members yet'),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: nodes.length,
                    itemBuilder: (context, index) {
                      final node = nodes[index];
                      final isSelected = _selectedPeopleIds.contains(node.id);
                      return CheckboxListTile(
                        value: isSelected,
                        onChanged: (checked) {
                          setModalState(() {
                            if (checked == true) {
                              _selectedPeopleIds.add(node.id);
                            } else {
                              _selectedPeopleIds.remove(node.id);
                            }
                          });
                        },
                        title: Text(node.fullName),
                        subtitle: node.birthDate != null
                            ? Text('Born: ${DateFormat.yMMM().format(node.birthDate!)}')
                            : null,
                        secondary: CircleAvatar(
                          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                          child: Text(
                            node.initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Add Memory',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media picker
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
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
                child: _selectedFile != null
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _selectedMediaType == MediaType.image
                                ? FutureBuilder<Uint8List>(
                                    future: _selectedFile!.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const Center(
                                          child: CircularProgressIndicator(),
                                        );
                                      }
                                      return Image.memory(
                                        snapshot.data!,
                                        width: double.infinity,
                                        height: 200,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  )
                                : Container(
                                    color: AppColors.primary.withValues(alpha: 0.1),
                                    child: const Center(
                                      child: Icon(
                                        Icons.videocam,
                                        size: 64,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              onPressed: () {
                                setState(() => _selectedFile = null);
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 48,
                            color: AppColors.textSecondary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Select media to upload',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _MediaButton(
                                icon: Icons.photo_library,
                                label: 'Gallery',
                                onTap: _pickImage,
                              ),
                              const SizedBox(width: 12),
                              _MediaButton(
                                icon: Icons.camera_alt,
                                label: 'Camera',
                                onTap: _takePhoto,
                              ),
                              const SizedBox(width: 12),
                              _MediaButton(
                                icon: Icons.videocam,
                                label: 'Video',
                                onTap: _pickVideo,
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 24),
              // Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Give this memory a title',
                  prefixIcon: const Icon(Icons.title),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Title is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Add a description (optional)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // Event name
              TextFormField(
                controller: _eventController,
                decoration: InputDecoration(
                  labelText: 'Event',
                  hintText: 'e.g., Birthday Party, Wedding',
                  prefixIcon: const Icon(Icons.event),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Event date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Event Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _eventDate != null
                        ? DateFormat.yMMMMd().format(_eventDate!)
                        : 'Select date',
                    style: TextStyle(
                      color: _eventDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tags
              TextFormField(
                controller: _tagsController,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Comma separated (e.g., family, vacation)',
                  prefixIcon: const Icon(Icons.tag),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tag people
              InkWell(
                onTap: _showPeopleSelector,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tag Family Members',
                    prefixIcon: const Icon(Icons.people_outline),
                    suffixIcon: const Icon(Icons.chevron_right),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _selectedPeopleIds.isEmpty
                        ? 'Select people in this memory'
                        : '${_selectedPeopleIds.length} people selected',
                    style: TextStyle(
                      color: _selectedPeopleIds.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Upload button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _uploading ? null : _upload,
                  icon: _uploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _uploading ? 'Uploading...' : 'Upload Memory',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
