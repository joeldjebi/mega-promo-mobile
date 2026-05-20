import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Titres
  static TextStyle get displayLarge => GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );

  static TextStyle get titleLarge => GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );

  static TextStyle get titleMedium => GoogleFonts.montserrat(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0,
  );

  static TextStyle get h1 => displayLarge;

  static TextStyle get h2 => titleLarge;

  static TextStyle get h3 => titleMedium;

  // Corps
  static TextStyle get bodyLarge => GoogleFonts.montserrat(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static TextStyle get body => bodyLarge;

  static TextStyle get bodySecondary => GoogleFonts.montserrat(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static TextStyle get bodySmall => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // Boutons
  static TextStyle get button => GoogleFonts.montserrat(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0,
  );

  // Labels
  static TextStyle get label => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0,
  );

  // Prix / Points
  static TextStyle get price => GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.gold,
    letterSpacing: 0,
  );

  // Tag / Badge
  static TextStyle get tag => GoogleFonts.montserrat(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    letterSpacing: 0,
  );
}
