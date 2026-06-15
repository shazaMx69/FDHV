import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/genealogy_tree_view.dart';
import 'package:flutter/material.dart';

/// Genealogy tree (top-down hierarchy, spouse pairs, connectors, zoom/pan).
class FamilyTreeDiagramView extends StatelessWidget {
  final FamilyTree tree;
  final void Function(FamilyTreeNode node)? onNodeTap;

  const FamilyTreeDiagramView({
    super.key,
    required this.tree,
    this.onNodeTap,
  });

  @override
  Widget build(BuildContext context) {
    return GenealogyTreeView(
      tree: tree,
      onNodeTap: onNodeTap,
    );
  }
}
