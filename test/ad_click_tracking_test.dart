import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_frontend/features/ads/utils/ad_click_handler.dart';

AdModel _ad(String id) => AdModel.fromJson({'_id': id, 'title': 'T', 'businessName': 'B'});

void main() {
  test('recordAdClick forwards the ad id to the tracker', () {
    final seen = <String>[];
    recordAdClick(_ad('507f1f77bcf86cd799439011'), tracker: seen.add);
    expect(seen, ['507f1f77bcf86cd799439011']);
  });

  test('recordAdClick skips an empty id', () {
    final seen = <String>[];
    recordAdClick(_ad(''), tracker: seen.add);
    expect(seen, isEmpty);
  });
}
