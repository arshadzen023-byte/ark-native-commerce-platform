import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// One canonical set of layout values shared by ARK Designer Preview,
/// WordPress publish serialization, and the live Shopping Home renderer.
///
/// WordPress keeps legacy aliases for compatibility (height/height_px,
/// max_cross_axis_extent/max_width_px, etc.). This class resolves them in one
/// place so the editor and published renderer cannot interpret them differently.
class DesignerLayoutSpec {
  const DesignerLayoutSpec({
    required this.height,
    required this.widthFactor,
    required this.maxCrossAxisExtent,
    required this.mainAxisSpacing,
    required this.crossAxisSpacing,
    required this.borderRadius,
    required this.horizontal,
    required this.crossAxisCount,
    required this.crossAspectRatio,
    required this.elevation,
    required this.fixedGridViewCount,
    required this.margin,
    required this.padding,
  });

  final double height;
  final double widthFactor;
  final double? maxCrossAxisExtent;
  final double mainAxisSpacing;
  final double crossAxisSpacing;
  final double borderRadius;
  final bool horizontal;
  final int crossAxisCount;
  final double crossAspectRatio;
  final double elevation;
  final int fixedGridViewCount;
  final EdgeInsets margin;
  final EdgeInsets padding;

  static double? _firstNumber(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key];
      if (value is num) return value.toDouble();
    }
    return null;
  }

  static double _number(
    Map<String, dynamic> values,
    List<String> keys,
    double fallback,
  ) => _firstNumber(values, keys) ?? fallback;

  static int _integer(
    Map<String, dynamic> values,
    List<String> keys,
    int fallback,
  ) => (_firstNumber(values, keys) ?? fallback.toDouble()).round();

  factory DesignerLayoutSpec.fromMap(
    Map<String, dynamic> source, {
    double? defaultMaxCrossAxisExtent,
  }) {
    final nested = source['properties'] is Map
        ? Map<String, dynamic>.from(source['properties'] as Map)
        : <String, dynamic>{};
    final values = <String, dynamic>{...source, ...nested};

    final rawWidth = _firstNumber(values, const ['width']);
    final widthPct = _firstNumber(values, const ['width_pct']);
    final resolvedWidth = rawWidth ?? (widthPct == null ? 1.0 : widthPct / 100);
    final widthFactor = (resolvedWidth > 1 ? resolvedWidth / 100 : resolvedWidth)
        .clamp(.2, 1.0)
        .toDouble();

    final margin = EdgeInsets.fromLTRB(
      _number(values, const ['margin_left'], 0),
      _number(values, const ['margin_top'], 0),
      _number(values, const ['margin_right'], 0),
      _number(values, const ['margin_bottom'], 0),
    );
    final padding = EdgeInsets.fromLTRB(
      _number(values, const ['padding_left'], 12),
      _number(values, const ['padding_top'], 12),
      _number(values, const ['padding_right'], 12),
      _number(values, const ['padding_bottom'], 12),
    );

    final maxExtent = _firstNumber(
      values,
      const ['max_width_px', 'max_cross_axis_extent'],
    );

    return DesignerLayoutSpec(
      height: _number(values, const ['height_px', 'height'], 180),
      widthFactor: widthFactor,
      maxCrossAxisExtent: maxExtent ?? defaultMaxCrossAxisExtent,
      mainAxisSpacing: _number(
        values,
        const ['main_axis_spacing', 'item_gap'],
        10,
      ),
      crossAxisSpacing: _number(
        values,
        const ['cross_axis_spacing', 'item_gap'],
        10,
      ),
      borderRadius: _number(
        values,
        const ['corner_radius', 'border_radius'],
        16,
      ),
      horizontal: values['horizontal'] != false,
      crossAxisCount: _integer(
        values,
        const ['columns', 'cross_axis_count'],
        2,
      ).clamp(1, 6).toInt(),
      crossAspectRatio: _number(
        values,
        const ['card_aspect_ratio', 'cross_aspect_ratio'],
        1,
      ),
      elevation: _number(values, const ['card_depth', 'elevation'], 1),
      fixedGridViewCount: _integer(
        values,
        const ['limit', 'fixed_grid_view_count'],
        8,
      ).clamp(1, 40).toInt(),
      margin: margin,
      padding: padding,
    );
  }

  /// Width of one child inside its available cross-axis viewport.
  /// The same rule is used by the editor preview and the published renderer.
  double childWidthFor(
    double availableWidth, {
    double? fallbackMaxCrossAxisExtent,
  }) {
    final safeAvailable = availableWidth.isFinite
        ? math.max(0.0, availableWidth)
        : (maxCrossAxisExtent ?? fallbackMaxCrossAxisExtent ?? 0);
    final proposed = safeAvailable * widthFactor;
    final maximum = maxCrossAxisExtent ?? fallbackMaxCrossAxisExtent ?? safeAvailable;
    return math.min(math.min(proposed, maximum), safeAvailable).toDouble();
  }

  /// Emits paired legacy aliases with one exact effective value.
  /// The WordPress API can retain old keys without changing the layout result.
  Map<String, dynamic> canonicalAliases() {
    final heightPx = height.round();
    final widthPct = widthFactor * 100;
    final mainGap = mainAxisSpacing.round();
    final crossGap = crossAxisSpacing.round();
    final radius = borderRadius.round();
    final columns = crossAxisCount;
    final depth = elevation.round();
    final limit = fixedGridViewCount;

    return <String, dynamic>{
      'height': heightPx,
      'height_px': heightPx,
      'width': widthFactor,
      'width_pct': widthPct,
      if (maxCrossAxisExtent != null) ...{
        'max_cross_axis_extent': maxCrossAxisExtent!.round(),
        'max_width_px': maxCrossAxisExtent!.round(),
      },
      'main_axis_spacing': mainGap,
      'cross_axis_spacing': crossGap,
      'item_gap': crossGap,
      'border_radius': radius,
      'corner_radius': radius,
      'cross_axis_count': columns,
      'columns': columns,
      'cross_aspect_ratio': crossAspectRatio,
      'card_aspect_ratio': crossAspectRatio,
      'elevation': depth,
      'card_depth': depth,
      'fixed_grid_view_count': limit,
    };
  }
}
