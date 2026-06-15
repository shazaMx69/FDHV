import 'package:flutter/material.dart';

/// Scrollable page body that avoids bottom overflow on small viewports.
class ResponsiveScrollScaffold extends StatelessWidget {
  final Color? backgroundColor;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ResponsiveScrollScaffold({
    super.key,
    this.backgroundColor,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: padding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}
