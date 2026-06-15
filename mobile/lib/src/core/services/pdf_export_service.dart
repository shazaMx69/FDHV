import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/core/models/memory.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:family_digital_heritage_vault/src/core/utils/file_download.dart';

class PdfExportService {
  Future<void> shareMemoryPdf({
    required Memory memory,
    required String familyName,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat.yMMMMd();
    pw.ImageProvider? imageProvider;

    final url = memory.displayUrl;
    if (memory.mediaType == MediaType.image && url != null && url.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          imageProvider = pw.MemoryImage(response.bodyBytes);
        }
      } catch (_) {
        // Continue without image.
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Text(
            familyName,
            style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            memory.title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            '${memory.mediaType.displayName} · ${dateFmt.format(memory.createdAt)}',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
          if (memory.event != null) ...[
            pw.SizedBox(height: 4),
            pw.Text('Event: ${memory.event}', style: const pw.TextStyle(fontSize: 11)),
          ],
          if (memory.eventDate != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Event date: ${dateFmt.format(memory.eventDate!)}',
              style: const pw.TextStyle(fontSize: 11),
            ),
          ],
          if (memory.description != null && memory.description!.trim().isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(memory.description!, style: const pw.TextStyle(fontSize: 12)),
          ],
          if (imageProvider != null) ...[
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Image(imageProvider, fit: pw.BoxFit.contain, height: 360),
            ),
          ],
          if (memory.isLocked) ...[
            pw.SizedBox(height: 16),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                border: pw.Border.all(color: PdfColors.amber800),
              ),
              child: pw.Text(
                'Scheduled release: ${memory.inheritanceLockLabel}',
                style: pw.TextStyle(fontSize: 11, color: PdfColors.amber900),
              ),
            ),
          ],
        ],
      ),
    );

    await downloadPdfBytes(
      await doc.save(),
      _safeFilename('${memory.title}_memory.pdf'),
    );
  }

  Future<void> shareFamilyTreePdf({
    required FamilyTree tree,
    required String familyName,
  }) async {
    final doc = pw.Document();
    final dateFmt = DateFormat.yMMMd();
    final hierarchyLines = _buildHierarchyLines(tree);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            familyName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Family tree · ${tree.nodes.length} members · ${dateFmt.format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Tree structure', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (hierarchyLines.isEmpty)
            pw.Text('No members in tree.', style: const pw.TextStyle(fontSize: 11))
          else
            ...hierarchyLines.map(
              (line) => pw.Padding(
                padding: pw.EdgeInsets.only(left: line.indent * 14.0, bottom: 4),
                child: pw.Text(line.text, style: const pw.TextStyle(fontSize: 10)),
              ),
            ),
          pw.SizedBox(height: 20),
          pw.Text('Member directory', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...tree.nodes.map((node) {
            final parents = tree.getParentsOf(node.id).map((p) => p.fullName).join(', ');
            final children = tree.getChildrenOf(node.id).map((c) => c.fullName).join(', ');
            final spouses = tree.getSpousesOf(node.id).map((s) => s.fullName).join(', ');
            final life = _lifeLine(node);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(node.fullName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  if (life.isNotEmpty)
                    pw.Text(life, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (parents.isNotEmpty)
                    pw.Text('Parents: $parents', style: const pw.TextStyle(fontSize: 9)),
                  if (spouses.isNotEmpty)
                    pw.Text('Spouse: $spouses', style: const pw.TextStyle(fontSize: 9)),
                  if (children.isNotEmpty)
                    pw.Text('Children: $children', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
            );
          }),
        ],
      ),
    );

    await downloadPdfBytes(
      await doc.save(),
      _safeFilename('${familyName}_family_tree.pdf'),
    );
  }

  List<_TreeLine> _buildHierarchyLines(FamilyTree tree) {
    final lines = <_TreeLine>[];
    final roots = tree.nodes.where((n) => tree.getParentsOf(n.id).isEmpty).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    final visited = <String>{};
    for (final root in roots) {
      _appendNode(tree, root.id, 0, lines, visited);
    }

    for (final node in tree.nodes) {
      if (!visited.contains(node.id)) {
        _appendNode(tree, node.id, 0, lines, visited);
      }
    }
    return lines;
  }

  void _appendNode(
    FamilyTree tree,
    String nodeId,
    int depth,
    List<_TreeLine> lines,
    Set<String> visited,
  ) {
    if (visited.contains(nodeId)) return;
    visited.add(nodeId);
    final node = tree.getNodeById(nodeId);
    if (node == null) return;

    final life = _lifeLine(node);
    final suffix = life.isNotEmpty ? ' ($life)' : '';
    lines.add(_TreeLine(depth, '• ${node.fullName}$suffix'));

    final children = tree.getChildrenOf(nodeId)
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    for (final child in children) {
      _appendNode(tree, child.id, depth + 1, lines, visited);
    }
  }

  String _lifeLine(FamilyTreeNode node) {
    if (node.birthDate != null && node.deathDate != null) {
      return '${node.birthDate!.year} – ${node.deathDate!.year}';
    }
    if (node.birthDate != null) return 'b. ${node.birthDate!.year}';
    if (node.deathDate != null) return 'd. ${node.deathDate!.year}';
    return '';
  }

  String _safeFilename(String name) {
    return name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').trim();
  }
}

class _TreeLine {
  final int indent;
  final String text;

  _TreeLine(this.indent, this.text);
}
