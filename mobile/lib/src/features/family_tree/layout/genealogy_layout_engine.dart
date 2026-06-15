import 'dart:math' as math;

import 'package:family_digital_heritage_vault/src/core/models/family_tree_node.dart';
import 'package:flutter/material.dart';

/// Layout constants for the genealogy tree.
class GenealogyLayoutMetrics {
  static const double nodeWidth = 132;
  static const double nodeHeight = 132;
  static const double spouseGap = 28;
  static const double siblingGap = 36;
  static const double rowGap = 100;
  static const double branchGap = 48;
  static const double margin = 40;
  static const double lineStub = 22;

  static double coupleWidth(int memberCount) {
    if (memberCount <= 1) return nodeWidth;
    return nodeWidth * memberCount + spouseGap * (memberCount - 1);
  }
}

/// One positioned person on the canvas.
class GenealogyPersonLayout {
  final FamilyTreeNode node;
  final Offset position;
  final Size size;

  const GenealogyPersonLayout({
    required this.node,
    required this.position,
    this.size = const Size(
      GenealogyLayoutMetrics.nodeWidth,
      GenealogyLayoutMetrics.nodeHeight,
    ),
  });

  Offset get center => Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

  Rect get rect => position & size;
}

/// Connector segment for [CustomPainter].
class GenealogyLine {
  final Offset from;
  final Offset to;
  final GenealogyLineKind kind;

  const GenealogyLine({
    required this.from,
    required this.to,
    this.kind = GenealogyLineKind.tree,
  });
}

enum GenealogyLineKind { spouse, tree }

/// A family unit: one or two spouses side-by-side with descendant subtree.
class GenealogyUnitLayout {
  final List<String> memberIds;
  final List<GenealogyPersonLayout> members;
  final List<GenealogyUnitLayout> children;
  final List<GenealogyLine> lines;
  final bool collapsed;
  final double width;
  final double height;
  final Offset origin;

  const GenealogyUnitLayout({
    required this.memberIds,
    required this.members,
    required this.children,
    required this.lines,
    required this.collapsed,
    required this.width,
    required this.height,
    required this.origin,
  });

  Offset get coupleCenter {
    if (members.isEmpty) return origin;
    if (members.length == 1) return members.first.center;
    return Offset(
      (members.first.center.dx + members.last.center.dx) / 2,
      members.first.center.dy,
    );
  }

  Iterable<GenealogyPersonLayout> get allPeople sync* {
    for (final m in members) {
      yield m;
    }
    if (!collapsed) {
      for (final child in children) {
        yield* child.allPeople;
      }
    }
  }

  Iterable<GenealogyLine> get allLines sync* {
    yield* lines;
    if (!collapsed) {
      for (final child in children) {
        yield* child.allLines;
      }
    }
  }
}

/// Full computed layout for one forest (may contain multiple root subtrees).
class GenealogyTreeLayout {
  final List<GenealogyUnitLayout> roots;
  final Size canvasSize;
  final List<GenealogyPersonLayout> people;
  final List<GenealogyLine> lines;

  const GenealogyTreeLayout({
    required this.roots,
    required this.canvasSize,
    required this.people,
    required this.lines,
  });
}

/// Builds top-down, generation-separated genealogy layouts from [FamilyTree] data.
class GenealogyLayoutEngine {
  GenealogyLayoutEngine(this.tree);

  final FamilyTree tree;
  final Map<String, FamilyTreeNode> _nodes = {};
  final Map<String, Set<String>> _parents = {};
  final Map<String, Set<String>> _children = {};
  final Map<String, Set<String>> _spouses = {};

  GenealogyTreeLayout compute({
    Set<String> collapsedUnitKeys = const {},
  }) {
    _indexTree();
    final rootIds = _findRoots();
    final assigned = <String>{};
    final rootUnits = <_UnitNode>[];

    for (final id in rootIds) {
      if (assigned.contains(id)) continue;
      final unit = _buildUnit(id, assigned);
      if (unit != null) rootUnits.add(unit);
    }

    for (final node in tree.nodes) {
      if (!assigned.contains(node.id)) {
        final unit = _buildUnit(node.id, assigned);
        if (unit != null) rootUnits.add(unit);
      }
    }

    double xCursor = GenealogyLayoutMetrics.margin;
    final laidOutRoots = <GenealogyUnitLayout>[];
    double maxHeight = 0;

    for (final root in rootUnits) {
      final collapsed = collapsedUnitKeys.contains(root.key);
      final layout = _layoutUnit(
        root,
        0,
        collapsed: collapsed,
        collapsedUnitKeys: collapsedUnitKeys,
      );
      final offset = Offset(xCursor - layout.origin.dx, GenealogyLayoutMetrics.margin - layout.origin.dy);
      laidOutRoots.add(_offsetUnit(layout, offset));
      xCursor += layout.width + GenealogyLayoutMetrics.branchGap;
      maxHeight = math.max(maxHeight, layout.height + GenealogyLayoutMetrics.margin * 2);
    }

    final allPeople = <GenealogyPersonLayout>[];
    final allLines = <GenealogyLine>[];
    for (final r in laidOutRoots) {
      allPeople.addAll(r.allPeople);
      allLines.addAll(r.allLines);
    }

    final canvasWidth = math.max(xCursor, GenealogyLayoutMetrics.margin * 2 + 200);
    return GenealogyTreeLayout(
      roots: laidOutRoots,
      canvasSize: Size(canvasWidth, maxHeight),
      people: allPeople,
      lines: allLines,
    );
  }

  void _indexTree() {
    _nodes
      ..clear()
      ..addEntries(tree.nodes.map((n) => MapEntry(n.id, n)));
    _parents.clear();
    _children.clear();
    _spouses.clear();

    for (final id in _nodes.keys) {
      _parents[id] = {};
      _children[id] = {};
      _spouses[id] = {};
    }

    for (final rel in tree.relationships) {
      if (rel.type == RelationshipType.parent) {
        _parents[rel.toNodeId]!.add(rel.fromNodeId);
        _children[rel.fromNodeId]!.add(rel.toNodeId);
      } else if (rel.type == RelationshipType.spouse) {
        _spouses[rel.fromNodeId]!.add(rel.toNodeId);
        _spouses[rel.toNodeId]!.add(rel.fromNodeId);
      }
    }
  }

  List<String> _findRoots() {
    final roots = _nodes.keys.where((id) => _parents[id]!.isEmpty).toList();
    roots.sort(_compareIds);
    return roots;
  }

  int _compareIds(String a, String b) {
    final na = _nodes[a]!;
    final nb = _nodes[b]!;
    final g = na.generation.compareTo(nb.generation);
    if (g != 0) return g;
    final ay = na.birthDate?.year ?? 9999;
    final by = nb.birthDate?.year ?? 9999;
    if (ay != by) return ay.compareTo(by);
    return na.fullName.compareTo(nb.fullName);
  }

  _UnitNode? _buildUnit(String startId, Set<String> assigned) {
    if (!_nodes.containsKey(startId) || assigned.contains(startId)) return null;

    final members = <String>[startId];
    assigned.add(startId);

    final spouses = _spouses[startId]!
        .where((s) => _nodes.containsKey(s) && !assigned.contains(s))
        .toList()
      ..sort(_compareIds);

    for (final spouseId in spouses) {
      members.add(spouseId);
      assigned.add(spouseId);
    }

    members.sort(_compareIds);
    final memberSet = members.toSet();

    final childIds = <String>{};
    for (final mid in members) {
      for (final cid in _children[mid]!) {
        final parents = _parents[cid]!;
        final knownParentsInTree = parents.where(_nodes.containsKey).toSet();
        if (knownParentsInTree.isEmpty) continue;
        if (knownParentsInTree.every((p) => memberSet.contains(p))) {
          childIds.add(cid);
        } else if (knownParentsInTree.length == 1 && memberSet.contains(knownParentsInTree.first)) {
          childIds.add(cid);
        }
      }
    }

    final childUnits = <_UnitNode>[];
    final sortedChildren = childIds.toList()..sort(_compareIds);
    for (final cid in sortedChildren) {
      if (assigned.contains(cid)) continue;
      final childUnit = _buildUnit(cid, assigned);
      if (childUnit != null) childUnits.add(childUnit);
    }

    return _UnitNode(
      key: members.join('|'),
      memberIds: members,
      children: childUnits,
    );
  }

  GenealogyUnitLayout _layoutUnit(
    _UnitNode unit,
    double y, {
    required bool collapsed,
    Set<String> collapsedUnitKeys = const {},
  }) {
    final memberLayouts = <GenealogyPersonLayout>[];
    double x = 0;
    for (var i = 0; i < unit.memberIds.length; i++) {
      final node = _nodes[unit.memberIds[i]]!;
      memberLayouts.add(
        GenealogyPersonLayout(
          node: node,
          position: Offset(x, y),
        ),
      );
      x += GenealogyLayoutMetrics.nodeWidth;
      if (i < unit.memberIds.length - 1) {
        x += GenealogyLayoutMetrics.spouseGap;
      }
    }

    final coupleWidth = GenealogyLayoutMetrics.coupleWidth(unit.memberIds.length);
    final lines = <GenealogyLine>[];

    if (unit.memberIds.length == 2) {
      final a = memberLayouts[0].center;
      final b = memberLayouts[1].center;
      lines.add(GenealogyLine(from: a, to: b, kind: GenealogyLineKind.spouse));
    }

    if (collapsed || unit.children.isEmpty) {
      return GenealogyUnitLayout(
        memberIds: unit.memberIds,
        members: memberLayouts,
        children: const [],
        lines: lines,
        collapsed: collapsed,
        width: coupleWidth,
        height: GenealogyLayoutMetrics.nodeHeight,
        origin: Offset(0, y),
      );
    }

    double childX = 0;
    final childLayouts = <GenealogyUnitLayout>[];
    final childY = y + GenealogyLayoutMetrics.nodeHeight + GenealogyLayoutMetrics.rowGap;

    for (var i = 0; i < unit.children.length; i++) {
      final child = unit.children[i];
      final childCollapsed = collapsedUnitKeys.contains(child.key);
      final laidChild = _layoutUnit(
        child,
        childY,
        collapsed: childCollapsed,
        collapsedUnitKeys: collapsedUnitKeys,
      );
      final offsetChild = _offsetUnit(laidChild, Offset(childX - laidChild.origin.dx, 0));
      childLayouts.add(offsetChild);
      childX += offsetChild.width;
      if (i < unit.children.length - 1) {
        childX += GenealogyLayoutMetrics.siblingGap;
      }
    }

    final childrenTotalWidth = childX > 0 ? childX - GenealogyLayoutMetrics.siblingGap : 0;
    final unitWidth = math.max(coupleWidth, childrenTotalWidth).toDouble();
    final coupleCenterX = unitWidth / 2;
    final coupleOffsetX = coupleCenterX - coupleWidth / 2;

    final adjustedMembers = memberLayouts
        .map(
          (m) => GenealogyPersonLayout(
            node: m.node,
            position: Offset(m.position.dx + coupleOffsetX, m.position.dy),
            size: m.size,
          ),
        )
        .toList();

    final adjustedChildren = childLayouts
        .map((c) => _offsetUnit(c, Offset((unitWidth - childrenTotalWidth) / 2 - c.origin.dx, 0)))
        .toList();

    final coupleCenter = Offset(
      coupleOffsetX + coupleWidth / 2,
      y + GenealogyLayoutMetrics.nodeHeight / 2,
    );

    if (adjustedChildren.isNotEmpty) {
      final busY = y + GenealogyLayoutMetrics.nodeHeight + GenealogyLayoutMetrics.lineStub;
      lines.add(GenealogyLine(from: Offset(coupleCenter.dx, y + GenealogyLayoutMetrics.nodeHeight), to: Offset(coupleCenter.dx, busY)));

      final childCenters = adjustedChildren.map((c) => c.coupleCenter).toList();
      final minX = childCenters.map((c) => c.dx).reduce(math.min);
      final maxX = childCenters.map((c) => c.dx).reduce(math.max);
      lines.add(GenealogyLine(from: Offset(minX, busY), to: Offset(maxX, busY)));

      for (final cc in childCenters) {
        lines.add(GenealogyLine(from: Offset(cc.dx, busY), to: Offset(cc.dx, cc.dy - GenealogyLayoutMetrics.lineStub)));
      }
    }

    final subtreeHeight = adjustedChildren.isEmpty
        ? GenealogyLayoutMetrics.nodeHeight
        : adjustedChildren.map((c) => c.height + childY - y).reduce(math.max).toDouble();

    return GenealogyUnitLayout(
      memberIds: unit.memberIds,
      members: adjustedMembers,
      children: adjustedChildren,
      lines: lines,
      collapsed: false,
      width: unitWidth,
      height: subtreeHeight,
      origin: Offset(0, y),
    );
  }

  GenealogyUnitLayout _offsetUnit(GenealogyUnitLayout unit, Offset delta) {
    return GenealogyUnitLayout(
      memberIds: unit.memberIds,
      members: unit.members
          .map(
            (m) => GenealogyPersonLayout(
              node: m.node,
              position: m.position + delta,
              size: m.size,
            ),
          )
          .toList(),
      children: unit.children.map((c) => _offsetUnit(c, delta)).toList(),
      lines: unit.lines
          .map(
            (l) => GenealogyLine(
              from: l.from + delta,
              to: l.to + delta,
              kind: l.kind,
            ),
          )
          .toList(),
      collapsed: unit.collapsed,
      width: unit.width,
      height: unit.height,
      origin: unit.origin + delta,
    );
  }
}

class _UnitNode {
  final String key;
  final List<String> memberIds;
  final List<_UnitNode> children;

  _UnitNode({
    required this.key,
    required this.memberIds,
    required this.children,
  });
}
