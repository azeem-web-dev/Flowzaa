import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles used across both apps.
class AppText {
  AppText._();

  static const _family = null; // uses default; swap for a bundled font later

  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 30,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );

  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.35,
    color: AppColors.ink,
  );

  static const bodySoft = TextStyle(
    fontSize: 14,
    height: 1.35,
    color: AppColors.inkSoft,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.inkSoft,
    letterSpacing: 0.2,
  );

  static const price = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
  );
}
