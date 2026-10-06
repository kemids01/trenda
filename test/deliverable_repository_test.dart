import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/core/data/deliverable_repository.dart';

void main() {
  test('parses deliverable cities into MunicipalityModel, server order kept', () {
    final list = parseDeliverable({
      'success': true,
      'data': [
        {'name': 'Tuguegarao City', 'psgcCode': '021529', 'served': true},
        {'name': 'Solana', 'psgcCode': '021527', 'served': false},
      ],
    });
    expect(list.map((m) => m.name), ['Tuguegarao City', 'Solana']);
    expect(list.first.order < list.last.order, isTrue);
  });

  test('bad bodies → empty, never throw', () {
    expect(parseDeliverable(const {}), isEmpty);
    expect(parseDeliverable(const {'data': 'x'}), isEmpty);
  });

  test('barangay names from the /deliverable/barangays body', () {
    expect(parseBarangayNames({'data': [{'name': 'Centro 01'}, {'name': ''}, 'x']}), ['Centro 01']);
  });
}
