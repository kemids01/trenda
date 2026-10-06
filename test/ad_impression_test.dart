import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/ad_model.dart';
import 'package:trenda_frontend/features/ads/utils/ad_click_handler.dart';

AdModel _ad(String id) => AdModel.fromJson({'_id': id, 'title': 'T', 'businessName': 'B'});

void main() {
  test('shouldTrackImpression tracks once per id and skips empty', () {
    final seen = <String>{};
    expect(shouldTrackImpression(seen, 'a'), true);
    expect(shouldTrackImpression(seen, 'a'), false);
    expect(shouldTrackImpression(seen, 'b'), true);
    expect(shouldTrackImpression(seen, ''), false);
  });

  test('recordAdImpression fires the tracker once per ad', () {
    final seen = <String>{};
    final fired = <String>[];
    recordAdImpression(_ad('507f1f77bcf86cd799439011'), seen, tracker: fired.add);
    recordAdImpression(_ad('507f1f77bcf86cd799439011'), seen, tracker: fired.add);
    expect(fired, ['507f1f77bcf86cd799439011']);
  });
}
