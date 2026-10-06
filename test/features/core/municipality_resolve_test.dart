import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_frontend/features/core/providers/municipality_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  group('resolveInitialMunicipality', () {
    test('prefers saved selected_municipality', () async {
      final p = await prefsWith({
        'selected_municipality': 'Aparri',
        'home_municipality': 'Solana',
      });
      expect(resolveInitialMunicipality(p), 'Aparri');
    });

    test('falls back to home_municipality when no selection', () async {
      final p = await prefsWith({'home_municipality': 'Solana'});
      expect(resolveInitialMunicipality(p), 'Solana');
    });

    test('returns null when neither is set', () async {
      final p = await prefsWith({});
      expect(resolveInitialMunicipality(p), isNull);
    });
  });
}
