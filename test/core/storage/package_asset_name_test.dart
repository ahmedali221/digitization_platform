import 'package:digitization_platform/core/storage/package_asset_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('proxy background URLs produce unique names with real extensions', () {
    const siteUrl =
        'https://example.test/api/files?path=canvas-backgrounds%2Fsite%2F1%2Fplan.jpg';
    const floorUrl =
        'https://example.test/api/files?path=canvas-backgrounds%2Ffloor%2F7%2Fplan.jpg';

    final siteName = packageImageFileName(siteUrl);
    final floorName = packageImageFileName(floorUrl);

    expect(siteName, endsWith('_plan.jpg'));
    expect(floorName, endsWith('_plan.jpg'));
    expect(siteName, isNot(floorName));
    expect(siteName, isNot('files'));
  });

  test('direct image URLs retain their basename and remain deterministic', () {
    const url = 'https://cdn.example.test/maps/background.png';

    expect(packageImageFileName(url), packageImageFileName(url));
    expect(packageImageFileName(url), endsWith('_background.png'));
  });
}
