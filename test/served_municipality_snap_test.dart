import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/checkout/utils/served_municipality_snap.dart';

void main() {
  const served = ['Cauayan City', 'Tuguegarao City'];

  test('geocoded base name snaps to the served spelling', () {
    expect(snapToServedMunicipality('Tuguegarao', served), 'Tuguegarao City');
    expect(snapToServedMunicipality(' tuguegarao city ', served), 'Tuguegarao City');
  });

  test('an unserved or empty name selects nothing', () {
    expect(snapToServedMunicipality('Solana', served), isNull);
    expect(snapToServedMunicipality('', served), isNull);
    expect(snapToServedMunicipality(null, served), isNull);
  });
}
