import 'package:flutter_test/flutter_test.dart';
import 'package:glowhit_shopping/designer_layout_contract.dart';

void main() {
  test('Designer and published layout keep margin, padding and dimensions exact', () {
    final spec = DesignerLayoutSpec.fromMap({
      'margin_top': 3,
      'margin_right': 7,
      'margin_bottom': 11,
      'margin_left': 13,
      'padding_top': 17,
      'padding_right': 19,
      'padding_bottom': 23,
      'padding_left': 29,
      'height': 211,
      'width': 0.82,
      'max_cross_axis_extent': 287,
      'main_axis_spacing': 9,
      'cross_axis_spacing': 15,
      'border_radius': 21,
      'cross_axis_count': 3,
      'cross_aspect_ratio': 1.35,
      'elevation': 4,
      'fixed_grid_view_count': 7,
    });

    expect(spec.margin.top, 3);
    expect(spec.margin.right, 7);
    expect(spec.margin.bottom, 11);
    expect(spec.margin.left, 13);
    expect(spec.padding.top, 17);
    expect(spec.padding.right, 19);
    expect(spec.padding.bottom, 23);
    expect(spec.padding.left, 29);
    expect(spec.height, 211);
    expect(spec.widthFactor, 0.82);
    expect(spec.maxCrossAxisExtent, 287);
    expect(spec.mainAxisSpacing, 9);
    expect(spec.crossAxisSpacing, 15);
    expect(spec.borderRadius, 21);
    expect(spec.crossAxisCount, 3);
    expect(spec.crossAspectRatio, 1.35);
    expect(spec.elevation, 4);
    expect(spec.fixedGridViewCount, 7);

    final aliases = spec.canonicalAliases();
    expect(aliases['height'], aliases['height_px']);
    expect(aliases['width'], 0.82);
    expect(aliases['width_pct'], 82.0);
    expect(aliases['main_axis_spacing'], 9);
    expect(aliases['cross_axis_spacing'], 15);
    expect(aliases['item_gap'], 15);
    expect(aliases['border_radius'], aliases['corner_radius']);
    expect(aliases['cross_axis_count'], aliases['columns']);
  });
}
