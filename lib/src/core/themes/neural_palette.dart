import 'package:flutter/material.dart';

/// Neural Interface color tokens registered as a [ThemeExtension].
///
/// Dark variant carries the exact values from the Stitch "Neural Interface"
/// design system (obsidian surfaces with emerald / cyan / violet / amber
/// accents). The light variant provides adapted equivalents so widgets
/// remain readable under the light theme. Access through the theme with
/// `context.neural` — never reference raw literals from widgets.
@immutable
class NeuralPalette extends ThemeExtension<NeuralPalette> {
  /// Creates a palette with explicit token values.
  const NeuralPalette({
    required this.obsidian950,
    required this.obsidian900,
    required this.obsidian850,
    required this.obsidian800,
    required this.obsidian700,
    required this.obsidian600,
    required this.emerald,
    required this.emerald400,
    required this.emerald300,
    required this.cyan,
    required this.cyan400,
    required this.cyan300,
    required this.violet,
    required this.purple500,
    required this.indigo500,
    required this.fuchsia500,
    required this.amber,
    required this.amber400,
    required this.amber300,
    required this.amber200,
    required this.pink400,
    required this.slate100,
    required this.slate200,
    required this.slate300,
    required this.slate400,
    required this.glassPanel,
    required this.glassPanelSubtle,
    required this.hairline,
    required this.hairlineSoft,
    required this.hairlineStrong,
    required this.glowEmerald,
    required this.glowCyan,
    required this.glowAmber,
    required this.glowMatrixActive,
  });

  /// Exact Stitch "Neural Interface" dark palette.
  static const NeuralPalette dark = NeuralPalette(
    obsidian950: Color(0xFF07080A),
    obsidian900: Color(0xFF0C0E12),
    obsidian850: Color(0xFF11141A),
    obsidian800: Color(0xFF161922),
    obsidian700: Color(0xFF202533),
    obsidian600: Color(0xFF2D3345),
    emerald: Color(0xFF10B981), // emerald-500
    emerald400: Color(0xFF34D399),
    emerald300: Color(0xFF6EE7B7),
    cyan: Color(0xFF06B6D4), // cyan-500
    cyan400: Color(0xFF22D3EE),
    cyan300: Color(0xFF67E8F9),
    violet: Color(0xFF8B5CF6), // violet-500
    purple500: Color(0xFFA855F7),
    indigo500: Color(0xFF6366F1),
    fuchsia500: Color(0xFFD946EF),
    amber: Color(0xFFF59E0B), // amber-500
    amber400: Color(0xFFFBBF24),
    amber300: Color(0xFFFCD34D),
    amber200: Color(0xFFFEF3C7),
    pink400: Color(0xFFF472B6),
    slate100: Color(0xFFF1F5F9),
    slate200: Color(0xFFE2E8F0),
    slate300: Color(0xFFCBD5E1),
    slate400: Color(0xFF94A3B8),
    // rgba(17, 20, 26, 0.72)
    glassPanel: Color(0xB811141A),
    // rgba(22, 25, 34, 0.6)
    glassPanelSubtle: Color(0x99161922),
    // rgba(255, 255, 255, 0.07)
    hairline: Color(0x12FFFFFF),
    // rgba(255, 255, 255, 0.05)
    hairlineSoft: Color(0x0DFFFFFF),
    // rgba(255, 255, 255, 0.10)
    hairlineStrong: Color(0x1AFFFFFF),
    // 0 0 20px -5px rgba(16, 185, 129, 0.3)
    glowEmerald: Color(0x4D10B981),
    // 0 0 20px -5px rgba(6, 182, 212, 0.35)
    glowCyan: Color(0x5906B6D4),
    // 0 0 20px -5px rgba(245, 158, 11, 0.3)
    glowAmber: Color(0x4DF59E0B),
    // 0 0 10px rgba(16, 185, 129, 0.6)
    glowMatrixActive: Color(0x9910B981),
  );

  /// Light-theme adaptation of the Neural Interface tokens.
  static const NeuralPalette light = NeuralPalette(
    obsidian950: Color(0xFFF6F6F8),
    obsidian900: Color(0xFFFFFFFF),
    obsidian850: Color(0xFFEEF0F4),
    obsidian800: Color(0xFFE4E7EC),
    obsidian700: Color(0xFFD5DAE2),
    obsidian600: Color(0xFFC3CAD6),
    emerald: Color(0xFF059669), // emerald-600 for light contrast
    emerald400: Color(0xFF10B981),
    emerald300: Color(0xFF34D399),
    cyan: Color(0xFF0891B2), // cyan-600
    cyan400: Color(0xFF06B6D4),
    cyan300: Color(0xFF22D3EE),
    violet: Color(0xFF7C3AED), // violet-600
    purple500: Color(0xFF9333EA),
    indigo500: Color(0xFF4F46E5),
    fuchsia500: Color(0xFFC026D3),
    amber: Color(0xFFD97706), // amber-600
    amber400: Color(0xFFF59E0B),
    amber300: Color(0xFFFBBF24),
    amber200: Color(0xFFFEF3C7),
    pink400: Color(0xFFEC4899),
    slate100: Color(0xFF0B1220),
    slate200: Color(0xFF1E293B),
    slate300: Color(0xFF334155),
    slate400: Color(0xFF64748B),
    // rgba(255, 255, 255, 0.72)
    glassPanel: Color(0xB8FFFFFF),
    // rgba(242, 244, 248, 0.6)
    glassPanelSubtle: Color(0x99F2F4F8),
    // rgba(0, 0, 0, 0.08)
    hairline: Color(0x14000000),
    // rgba(0, 0, 0, 0.06)
    hairlineSoft: Color(0x0F000000),
    // rgba(0, 0, 0, 0.12)
    hairlineStrong: Color(0x1F000000),
    glowEmerald: Color(0x33059669),
    glowCyan: Color(0x3D0891B2),
    glowAmber: Color(0x33D97706),
    glowMatrixActive: Color(0x99059669),
  );

  // ---------------------------------------------------------------------------
  // Obsidian surfaces (neutral ramp)
  // ---------------------------------------------------------------------------
  final Color obsidian950;
  final Color obsidian900;
  final Color obsidian850;
  final Color obsidian800;
  final Color obsidian700;
  final Color obsidian600;

  // ---------------------------------------------------------------------------
  // Neural accents
  // ---------------------------------------------------------------------------
  final Color emerald;
  final Color emerald400;
  final Color emerald300;
  final Color cyan;
  final Color cyan400;
  final Color cyan300;
  final Color violet;
  final Color purple500;
  final Color indigo500;
  final Color fuchsia500;
  final Color amber;
  final Color amber400;
  final Color amber300;
  final Color amber200;
  final Color pink400;

  // ---------------------------------------------------------------------------
  // Text ramp
  // ---------------------------------------------------------------------------
  final Color slate100;
  final Color slate200;
  final Color slate300;
  final Color slate400;

  // ---------------------------------------------------------------------------
  // Glass panel fills and hairline borders
  // ---------------------------------------------------------------------------
  final Color glassPanel;
  final Color glassPanelSubtle;
  final Color hairline;
  final Color hairlineSoft;
  final Color hairlineStrong;

  // ---------------------------------------------------------------------------
  // Glow shadow colors
  // ---------------------------------------------------------------------------
  final Color glowEmerald;
  final Color glowCyan;
  final Color glowAmber;
  final Color glowMatrixActive;

  @override
  NeuralPalette copyWith({
    Color? obsidian950,
    Color? obsidian900,
    Color? obsidian850,
    Color? obsidian800,
    Color? obsidian700,
    Color? obsidian600,
    Color? emerald,
    Color? emerald400,
    Color? emerald300,
    Color? cyan,
    Color? cyan400,
    Color? cyan300,
    Color? violet,
    Color? purple500,
    Color? indigo500,
    Color? fuchsia500,
    Color? amber,
    Color? amber400,
    Color? amber300,
    Color? amber200,
    Color? pink400,
    Color? slate100,
    Color? slate200,
    Color? slate300,
    Color? slate400,
    Color? glassPanel,
    Color? glassPanelSubtle,
    Color? hairline,
    Color? hairlineSoft,
    Color? hairlineStrong,
    Color? glowEmerald,
    Color? glowCyan,
    Color? glowAmber,
    Color? glowMatrixActive,
  }) {
    return NeuralPalette(
      obsidian950: obsidian950 ?? this.obsidian950,
      obsidian900: obsidian900 ?? this.obsidian900,
      obsidian850: obsidian850 ?? this.obsidian850,
      obsidian800: obsidian800 ?? this.obsidian800,
      obsidian700: obsidian700 ?? this.obsidian700,
      obsidian600: obsidian600 ?? this.obsidian600,
      emerald: emerald ?? this.emerald,
      emerald400: emerald400 ?? this.emerald400,
      emerald300: emerald300 ?? this.emerald300,
      cyan: cyan ?? this.cyan,
      cyan400: cyan400 ?? this.cyan400,
      cyan300: cyan300 ?? this.cyan300,
      violet: violet ?? this.violet,
      purple500: purple500 ?? this.purple500,
      indigo500: indigo500 ?? this.indigo500,
      fuchsia500: fuchsia500 ?? this.fuchsia500,
      amber: amber ?? this.amber,
      amber400: amber400 ?? this.amber400,
      amber300: amber300 ?? this.amber300,
      amber200: amber200 ?? this.amber200,
      pink400: pink400 ?? this.pink400,
      slate100: slate100 ?? this.slate100,
      slate200: slate200 ?? this.slate200,
      slate300: slate300 ?? this.slate300,
      slate400: slate400 ?? this.slate400,
      glassPanel: glassPanel ?? this.glassPanel,
      glassPanelSubtle: glassPanelSubtle ?? this.glassPanelSubtle,
      hairline: hairline ?? this.hairline,
      hairlineSoft: hairlineSoft ?? this.hairlineSoft,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      glowEmerald: glowEmerald ?? this.glowEmerald,
      glowCyan: glowCyan ?? this.glowCyan,
      glowAmber: glowAmber ?? this.glowAmber,
      glowMatrixActive: glowMatrixActive ?? this.glowMatrixActive,
    );
  }

  @override
  NeuralPalette lerp(ThemeExtension<NeuralPalette>? other, double t) {
    if (other is! NeuralPalette) return this;
    return NeuralPalette(
      obsidian950: Color.lerp(obsidian950, other.obsidian950, t)!,
      obsidian900: Color.lerp(obsidian900, other.obsidian900, t)!,
      obsidian850: Color.lerp(obsidian850, other.obsidian850, t)!,
      obsidian800: Color.lerp(obsidian800, other.obsidian800, t)!,
      obsidian700: Color.lerp(obsidian700, other.obsidian700, t)!,
      obsidian600: Color.lerp(obsidian600, other.obsidian600, t)!,
      emerald: Color.lerp(emerald, other.emerald, t)!,
      emerald400: Color.lerp(emerald400, other.emerald400, t)!,
      emerald300: Color.lerp(emerald300, other.emerald300, t)!,
      cyan: Color.lerp(cyan, other.cyan, t)!,
      cyan400: Color.lerp(cyan400, other.cyan400, t)!,
      cyan300: Color.lerp(cyan300, other.cyan300, t)!,
      violet: Color.lerp(violet, other.violet, t)!,
      purple500: Color.lerp(purple500, other.purple500, t)!,
      indigo500: Color.lerp(indigo500, other.indigo500, t)!,
      fuchsia500: Color.lerp(fuchsia500, other.fuchsia500, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amber400: Color.lerp(amber400, other.amber400, t)!,
      amber300: Color.lerp(amber300, other.amber300, t)!,
      amber200: Color.lerp(amber200, other.amber200, t)!,
      pink400: Color.lerp(pink400, other.pink400, t)!,
      slate100: Color.lerp(slate100, other.slate100, t)!,
      slate200: Color.lerp(slate200, other.slate200, t)!,
      slate300: Color.lerp(slate300, other.slate300, t)!,
      slate400: Color.lerp(slate400, other.slate400, t)!,
      glassPanel: Color.lerp(glassPanel, other.glassPanel, t)!,
      glassPanelSubtle: Color.lerp(
        glassPanelSubtle,
        other.glassPanelSubtle,
        t,
      )!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineSoft: Color.lerp(hairlineSoft, other.hairlineSoft, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      glowEmerald: Color.lerp(glowEmerald, other.glowEmerald, t)!,
      glowCyan: Color.lerp(glowCyan, other.glowCyan, t)!,
      glowAmber: Color.lerp(glowAmber, other.glowAmber, t)!,
      glowMatrixActive: Color.lerp(
        glowMatrixActive,
        other.glowMatrixActive,
        t,
      )!,
    );
  }
}
