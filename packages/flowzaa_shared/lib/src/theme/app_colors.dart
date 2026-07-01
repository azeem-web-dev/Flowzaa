import 'package:flutter/material.dart';

/// Flowzaa brand palette. A confident teal→green "flow" with warm accents.
class AppColors {
  AppColors._();

  // Brand
  static const primary = Color(0xFF00C2A8); // Flowzaa teal
  static const primaryDark = Color(0xFF009e8a);
  static const accent = Color(0xFFFFB020); // warm amber (fares, highlights)

  // Neutrals
  static const ink = Color(0xFF0E1726); // near-black text
  static const inkSoft = Color(0xFF5B6472);
  static const line = Color(0xFFE6E9EF);
  static const surface = Color(0xFFFFFFFF);
  static const scaffold = Color(0xFFF6F8FA);

  // Status
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info = Color(0xFF2563EB);

  // Vehicle accents
  static const bike = Color(0xFF00C2A8);
  static const auto = Color(0xFFFFB020);
  static const car = Color(0xFF2563EB);
  static const parcel = Color(0xFF8B5CF6);

  static const onlineGreen = Color(0xFF16A34A);
  static const offlineGrey = Color(0xFF94A3B8);
}
