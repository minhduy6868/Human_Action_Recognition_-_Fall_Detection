import 'package:flutter/material.dart';

class AuthStyles {
  static const double maxWidth = 460;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 24, 20, 24);
  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const double sectionSpacing = 14;

  static TextStyle? title(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.2,
    );
  }

  static TextStyle? subtitle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyMedium?.copyWith(height: 1.45);
  }

  static TextStyle? sectionTitle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w800,
      height: 1.15,
      letterSpacing: -0.15,
    );
  }
}
