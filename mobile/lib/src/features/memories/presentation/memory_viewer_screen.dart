import 'package:flutter/material.dart';

class MemoryViewerScreen extends StatelessWidget {
  const MemoryViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // This would call the backend /api/memories and /api/memories/{id}
    // and rely on the inheritance engine middleware for access control.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.photo),
            title: Text('Sample memory #$index'),
            subtitle: const Text('This is placeholder content.'),
            onTap: () {
              // In a full implementation, navigate to a detail screen that
              // streams the media from Firebase Storage.
            },
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemCount: 10,
      ),
    );
  }
}
