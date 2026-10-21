import 'package:flutter/material.dart';

class AppColors {
  // Voltagent / Frontend Brand Canvas & Surfaces (#101010 near-black, NO blue)
  static const Color background = Color(0xFF101010);        // --canvas: #101010
  static const Color surface = Color(0xFF161616);           // --canvas-soft: #161616
  static const Color surfaceBorder = Color(0xFF2E2E2E);     // --hairline: #2e2e2e
  static const Color cardBackground = Color(0xFF1A1A1A);    // #1a1a1a

  // Signature Voltagent Electric Green Brand Accent (#00d992, NO blue/indigo)
  static const Color primary = Color(0xFF00D992);           // --primary: #00d992
  static const Color primarySoft = Color(0xFF2FD6A1);       // --primary-soft: #2fd6a1
  static const Color primaryDeep = Color(0xFF10B981);       // --primary-deep: #10b981
  static const Color primaryPurple = Color(0xFF10B981);     // Mapped to brand green
  static const Color accentGreen = Color(0xFF00D992);       // #00d992
  static const Color onPrimary = Color(0xFF101010);         // --on-primary: #101010

  // Typography tokens
  static const Color textPrimary = Color(0xFFF2F2F2);       // --ink: #f2f2f2
  static const Color textSecondary = Color(0xFFBDBDBD);     // --body: #bdbdbd
  static const Color textMuted = Color(0xFF8B949E);         // --mute: #8b949e

  // Semantic tints (matching Frontend dashboard.css)
  static const Color toneMeeting = Color(0xFF4EA8FF);
  static const Color toneFocus = Color(0xFF00D992);
  static const Color toneReading = Color(0xFFC0A8FF);
  static const Color toneTask = Color(0xFF2FD6A1);

  // Voltagent / Frontend Brand Tokens (DESIGN.md)
  static const Color voltagentPrimary = Color(0xFF00D992);       // Electric Green CTA (#00d992)
  static const Color voltagentPrimarySoft = Color(0xFF2FD6A1);   // Light accent green
  static const Color voltagentPrimaryDeep = Color(0xFF10B981);   // Deep green (#10b981)
  static const Color voltagentOnPrimary = Color(0xFF101010);     // Dark text on primary button
  static const Color voltagentCanvas = Color(0xFF101010);        // Deep canvas background (#101010)
  static const Color voltagentCanvasSoft = Color(0xFF1A1A1A);    // Input / subtle card background (#1a1a1a)
  static const Color voltagentHairline = Color(0xFF2E2E2E);      // 1px subtle hairline border
  static const Color voltagentHairlineLight = Color(0xFF3D3A39); // Light hairline border
  static const Color voltagentInk = Color(0xFFF2F2F2);           // Main readable text (#f2f2f2)
  static const Color voltagentBody = Color(0xFFBDBDBD);          // Secondary body text (#bdbdbd)
  static const Color voltagentMute = Color(0xFF8B949E);          // Captions / fine print (#8b949e)
}