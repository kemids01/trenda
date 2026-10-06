import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/utils/profile_photo.dart';

void main() {
  test('reads the backend photoUrl field (the one it actually stores)', () {
    expect(storedPhotoUrl({'photoUrl': 'https://lh3.googleusercontent.com/a'}),
        'https://lh3.googleusercontent.com/a');
  });

  test('still accepts the legacy photoURL spelling', () {
    expect(storedPhotoUrl({'photoURL': 'https://x/p.jpg'}), 'https://x/p.jpg');
  });

  test('empty or missing is no photo', () {
    expect(storedPhotoUrl({'photoUrl': ''}), isNull);
    expect(storedPhotoUrl({}), isNull);
  });

  test('saves under the field the server allows', () {
    expect(kProfilePhotoField, 'photoUrl');
  });
}
