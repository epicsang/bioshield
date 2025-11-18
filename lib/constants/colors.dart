// lib/constants/colors.dart
import 'package:flutter/material.dart';

// Primary Brand Color — Soft Sky Blue (HEX#E6F9FF)
const Color kSkyBlue = Color(0xFFE6F9FF);

// Overlay / Accent / Toolbar Color — Deep Navy Blue (HEX#164273)
const Color kAuthNavy = Color(0xFF164273);

// Active Tab Icon Color — Deep Navy Blue (HEX#002E95)
const Color kActiveNavy = Color(0xFF002E95);

// Inactive Icon Color (HEX#828282)
const Color kInactiveIcon = Color(0xFF828282);

// Backgrounds
const Color kCardBackground = Colors.white;
const Color kOverlayBackground = kSkyBlue;

// Text & Icons
const Color kTextPrimary = Color(0xFF263238);
const Color kTextSecondary = Color(0xFF546E7A);
const Color kTextHint = Color(0xFF90A4AE);
const Color kDivider = Color(0xFFB0BEC5);
const Color kBorderLight = Color(0xFFE0E0E0);

// Buttons
const Color kButtonPrimary = kSkyBlue;
const Color kButtonSecondary = Colors.white;

// Status Colors
const Color kSuccess = Color(0xFF43A047);
const Color kSuccessLight = Color(0xFFE8F5E9);
const Color kWarning = Color(0xFFFB8C00);
const Color kWarningLight = Color(0xFFFFF3E0);
const Color kError = Color(0xFFE53935);
const Color kErrorLight = Color(0xFFFFEBEE);

// Gradients
const List<Color> kLandingGradient = [
  kSkyBlue,
  Colors.white,
];

// Shadows
const List<BoxShadow> kCardShadow = [
  BoxShadow(
    color: Color(0x0D000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
];

const List<BoxShadow> kElevatedShadow = [
  BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
];

const List<BoxShadow> kButtonShadow = [
  BoxShadow(
    color: Color(0x14000000),
    blurRadius: 12,
    offset: Offset(0, 3),
  ),
];