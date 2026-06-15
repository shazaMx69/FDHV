import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:family_digital_heritage_vault/src/core/theme/app_theme.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/layout/genealogy_layout_engine.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/genealogy_tree_painter.dart';
import 'package:family_digital_heritage_vault/src/features/family_tree/presentation/member_form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Top-down genealogy tree with spouse pairing, parent-child connectors, zoom/pan.
class GenealogyTreeView extends StatefulWidget {
  final FamilyTree tree;
  final void Function(FamilyTreeNode node)? onNodeTap;

  const GenealogyTreeView({
    super.key,
    required this.tree,
    this.onNodeTap,
  });

  @override
  State<GenealogyTreeView> createState() => _GenealogyTreeViewState();
}

class _GenealogyTreeViewState extends State<GenealogyTreeView> {
  final Set<String> _collapsedUnits = {};
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _toggleCollapse(String unitKey) {
    setState(() {
      if (_collapsedUnits.contains(unitKey)) {
        _collapsedUnits.remove(unitKey);
      } else {
        _collapsedUnits.add(unitKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tree.nodes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Add family members and link relationships (parent, child, spouse) to build your genealogy tree.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
      );
    }

    final layout = GenealogyLayoutEngine(widget.tree).compute(
      collapsedUnitKeys: _collapsedUnits,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pinch or scroll to zoom • Drag to pan • Tap member for details • Use −/+ on a couple to collapse branch',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary.withOpacity(0.9)),
                ),
              ),
              IconButton(
                tooltip: 'Reset zoom',
                icon: const Icon(Icons.center_focus_strong, size: 20),
                onPressed: () => _transformController.value = Matrix4.identity(),
              ),
            ],
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 0.15,
            maxScale: 3,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox(
              width: layout.canvasSize.width,
              height: layout.canvasSize.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: layout.canvasSize,
                    painter: GenealogyTreePainter(lines: layout.lines),
                  ),
                  ..._buildUnitWidgets(layout.roots, widget.tree),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildUnitWidgets(List<GenealogyUnitLayout> units, FamilyTree tree) {
    final widgets = <Widget>[];
    for (final unit in units) {
      widgets.addAll(_unitLayer(unit, tree));
    }
    return widgets;
  }

  List<Widget> _unitLayer(GenealogyUnitLayout unit, FamilyTree tree) {
    final widgets = <Widget>[];

    final unitKey = unit.memberIds.join('|');
    final hasChildren = unit.children.isNotEmpty;
    final isCollapsed = _collapsedUnits.contains(unitKey);

    for (final person in unit.members) {
      widgets.add(
        Positioned(
          left: person.position.dx,
          top: person.position.dy,
          width: person.size.width,
          height: person.size.height,
          child: _GenealogyNodeCard(
            node: person.node,
            tree: tree,
            onTap: () => widget.onNodeTap?.call(person.node),
          ),
        ),
      );
    }

    if (hasChildren) {
      final first = unit.members.first;
      widgets.add(
        Positioned(
          left: first.position.dx + first.size.width - 8,
          top: first.position.dy - 8,
          child: _CollapseChip(
            collapsed: isCollapsed,
            childCount: _countDescendants(unit),
            onTap: () => _toggleCollapse(unitKey),
          ),
        ),
      );
    }

    if (!isCollapsed) {
      for (final child in unit.children) {
        widgets.addAll(_unitLayer(child, tree));
      }
    }

    return widgets;
  }

  int _countDescendants(GenealogyUnitLayout unit) {
    var count = 0;
    for (final child in unit.children) {
      count += child.members.length;
      count += _countDescendants(child);
    }
    return count;
  }
}

class _CollapseChip extends StatelessWidget {
  final bool collapsed;
  final int childCount;
  final VoidCallback onTap;

  const _CollapseChip({
    required this.collapsed,
    required this.childCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            collapsed ? Icons.add : Icons.remove,
            size: 14,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GenealogyNodeCard extends StatelessWidget {
  final FamilyTreeNode node;
  final FamilyTree tree;
  final VoidCallback? onTap;

  const _GenealogyNodeCard({
    required this.node,
    required this.tree,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = memberCardStyleForGender(node.gender);
    final titleColor = style.useLightText ? Colors.white : AppColors.textPrimary;
    final subtitleColor =
        style.useLightText ? Colors.white.withOpacity(0.88) : AppColors.textSecondary;

    final spouses = tree.getSpousesOf(node.id);

    String lifeLine = '';
    if (node.birthDate != null && node.deathDate != null) {
      lifeLine =
          '${DateFormat('y').format(node.birthDate!)} – ${DateFormat('y').format(node.deathDate!)}';
    } else if (node.birthDate != null) {
      lifeLine = 'b. ${DateFormat('y').format(node.birthDate!)}';
    } else if (node.deathDate != null) {
      lifeLine = 'd. ${DateFormat('y').format(node.deathDate!)}';
    }

    String status = 'Single';
    if (node.isDeceased) {
      status = 'Deceased';
    } else if (spouses.isNotEmpty) {
      status = spouses.length > 1 ? 'Married (${spouses.length})' : 'Married';
    }

    return Material(
      color: Colors.transparent,
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: style.gradient,
            borderRadius: BorderRadius.circular(12),
            border: style.border ?? Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: style.shadowColor,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberAvatar(
                  node: node,
                  size: 36,
                  textColor: titleColor,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 3),
                Text(
                  node.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: titleColor,
                    height: 1.1,
                  ),
                ),
                if (lifeLine.isNotEmpty)
                  Text(
                    lifeLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 9, color: subtitleColor),
                  ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (node.gender != MemberGender.unspecified)
                      Icon(genderIcon(node.gender), size: 10, color: subtitleColor),
                    if (node.gender != MemberGender.unspecified) const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: subtitleColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
