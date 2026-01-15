import 'package:flutter/material.dart';

class BaseScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? drawer;

  const BaseScreen({
    super.key,
    required this.title,
    required this.child,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      drawer: drawer,
      body: SafeArea(
        child: child,
      ),
    );
  }
}
