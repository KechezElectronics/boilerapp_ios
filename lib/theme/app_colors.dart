import 'package:flutter/material.dart';

/// A full color palette for one selectable app theme. Parameter icon
/// colors (voltage=blue, temperature=red-orange, etc.) stay fixed
/// across themes since they carry sensor meaning — only chrome
/// (background, cards, text, accent) changes with the theme.
class AppColors {
  final String id;
  final String name;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color danger;
  final Color divider;

  const AppColors({
    required this.id,
    required this.name,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.danger,
    required this.divider,
  });

  /// Text/icon color that reads clearly on top of a solid [accent] fill
  /// (FAB icon, primary button label).
  Color get onAccent => brightness == Brightness.dark ? background : Colors.white;
}

const List<AppColors> appThemes = [
  AppColors(
    id: 'industrial',
    name: 'Industrial',
    brightness: Brightness.dark,
    background: Color(0xFF0D0D0F),
    surface: Color(0xFF1C1C1F),
    textPrimary: Color(0xFFF0F0F2),
    textSecondary: Color(0xFF8A8A90),
    textMuted: Color(0xFF5E6570),
    accent: Color(0xFF4FD1A5),
    danger: Color(0xFFE5484D),
    divider: Color(0xFF2C2C30),
  ),
  AppColors(
    id: 'ember',
    name: 'Ember',
    brightness: Brightness.dark,
    background: Color(0xFF14100D),
    surface: Color(0xFF241C16),
    textPrimary: Color(0xFFF5F0EA),
    textSecondary: Color(0xFF9C8F80),
    textMuted: Color(0xFF6E6255),
    accent: Color(0xFFD9822B),
    danger: Color(0xFFE5484D),
    divider: Color(0xFF362B21),
  ),
  AppColors(
    id: 'ocean',
    name: 'Ocean',
    brightness: Brightness.dark,
    background: Color(0xFF0A1116),
    surface: Color(0xFF16232B),
    textPrimary: Color(0xFFEAF2F5),
    textSecondary: Color(0xFF89A0AC),
    textMuted: Color(0xFF56707C),
    accent: Color(0xFF5AA9E0),
    danger: Color(0xFFE5484D),
    divider: Color(0xFF1F323C),
  ),
  AppColors(
    id: 'midnight',
    name: 'Midnight',
    brightness: Brightness.dark,
    background: Color(0xFF100D16),
    surface: Color(0xFF1E1826),
    textPrimary: Color(0xFFF1EDF7),
    textSecondary: Color(0xFF9A90AC),
    textMuted: Color(0xFF635A78),
    accent: Color(0xFF9B7FE0),
    danger: Color(0xFFE5484D),
    divider: Color(0xFF2C2438),
  ),
  AppColors(
    id: 'daylight',
    name: 'Daylight',
    brightness: Brightness.light,
    background: Color(0xFFF4F4F6),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1D),
    textSecondary: Color(0xFF6B6B70),
    textMuted: Color(0xFF9A9AA0),
    accent: Color(0xFF2F8F7A),
    danger: Color(0xFFC0392B),
    divider: Color(0xFFE2E2E6),
  ),
];

AppColors themeById(String id) =>
    appThemes.firstWhere((t) => t.id == id, orElse: () => appThemes.first);
