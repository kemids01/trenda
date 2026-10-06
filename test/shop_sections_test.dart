// Pins the Shop-tab band parsing: colours are optional, blank strings must not
// become colours, and the admin's product order has to survive the wire.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/home/providers/official_collections_provider.dart'
    show colorFromHex;
import 'package:trenda_frontend/features/home/providers/shop_sections_provider.dart';

Map<String, dynamic> _product(String id, String name) => {
      '_id': id,
      'name': name,
      'basePrice': 100,
      'images': <String>[],
    };

void main() {
  group('ShopSection.fromJson', () {
    test('reads the admin-configured heading, colours and products', () {
      final section = ShopSection.fromJson({
        '_id': 'sec1',
        'title': 'Daily Basics',
        'subtitle': 'Everyday essentials',
        'backgroundColor': '#EEF2FF',
        'accentColor': '#2563EB',
        'products': [_product('a', 'Rice'), _product('b', 'Eggs')],
      });

      expect(section.id, 'sec1');
      expect(section.title, 'Daily Basics');
      expect(section.subtitle, 'Everyday essentials');
      expect(section.backgroundColor, '#EEF2FF');
      expect(section.accentColor, '#2563EB');
      expect(section.products.map((p) => p.name), ['Rice', 'Eggs']);
    });

    test('keeps the server order — it is the admin\'s shelf order', () {
      final section = ShopSection.fromJson({
        'title': 'Daily Basics',
        'products': [_product('b', 'Eggs'), _product('a', 'Rice')],
      });
      expect(section.products.map((p) => p.name), ['Eggs', 'Rice']);
    });

    test('absent and blank colours both parse as null, never as a colour', () {
      // A blank string reaching colorFromHex would render the band black.
      final absent = ShopSection.fromJson({'title': 'X', 'products': []});
      expect(absent.backgroundColor, isNull);
      expect(absent.accentColor, isNull);
      expect(absent.subtitle, isNull);

      final blank = ShopSection.fromJson({
        'title': 'X',
        'subtitle': '   ',
        'backgroundColor': '',
        'accentColor': '  ',
        'products': [],
      });
      expect(blank.backgroundColor, isNull);
      expect(blank.accentColor, isNull);
      expect(blank.subtitle, isNull);
    });


    test('reads the carousel card and subtitle colours', () {
      final section = ShopSection.fromJson({
        'title': 'Daily Basics',
        'carouselColor': '#FFFFFF',
        'subtitleColor': '#6B7280',
        'products': [],
      });
      expect(section.carouselColor, '#FFFFFF');
      expect(section.subtitleColor, '#6B7280');
    });

    test('absent carousel/subtitle colours fall back to null, not a colour', () {
      // Null is what makes the app use white for the card and the band's own
      // ink for the subtitle; a blank string would parse as black.
      final section = ShopSection.fromJson({
        'title': 'X',
        'carouselColor': '',
        'subtitleColor': '   ',
        'products': [],
      });
      expect(section.carouselColor, isNull);
      expect(section.subtitleColor, isNull);
    });

    test('a malformed payload yields an empty, renderable section', () {
      final section = ShopSection.fromJson({'title': 'X', 'products': 'nope'});
      expect(section.products, isEmpty);
    });
  });


  group('store bands', () {
    Map<String, dynamic> storeJson(String id, String name,
            {bool open = true}) =>
        {
          'id': id,
          'name': name,
          'category': 'Grocery',
          'municipality': 'Tuguegarao City',
          'rating': 4.5,
          'reviewCount': 3,
          'productCount': 12,
          'isFeatured': false,
          'storeStatus': {'isOpen': open},
        };

    test('a store band parses its stores and knows which shelf it uses', () {
      final section = ShopSection.fromJson({
        'title': 'Top Shops',
        'contentType': 'stores',
        'products': [],
        'stores': [storeJson('uid-a', 'Dubets Store'), storeJson('uid-b', 'Trenda Test Store')],
      });

      expect(section.shelvesStores, isTrue);
      expect(section.itemCount, 2);
      expect(section.stores.map((s) => s.name), ['Dubets Store', 'Trenda Test Store']);
      // The pick order is the admin's shelf order and must survive the wire.
      expect(section.stores.first.id, 'uid-a');
    });

    test('a band with no contentType is a PRODUCT band', () {
      // Every band created before store bands existed carries no contentType.
      final section = ShopSection.fromJson({
        'title': 'Daily Basics',
        'products': [_product('a', 'Rice')],
      });
      expect(section.shelvesStores, isFalse);
      expect(section.contentType, 'products');
      expect(section.itemCount, 1);
    });

    test('an unrecognised contentType falls back to products, not to nothing', () {
      final section = ShopSection.fromJson({
        'title': 'X',
        'contentType': 'bundles',
        'products': [_product('a', 'Rice')],
      });
      expect(section.contentType, 'products');
      expect(section.itemCount, 1);
    });

    test('a store with no id is dropped — it cannot be tapped through', () {
      // /store/:id needs the vendor UID; a card that links nowhere is worse
      // than an absent one.
      final section = ShopSection.fromJson({
        'title': 'Top Shops',
        'contentType': 'stores',
        'products': [],
        'stores': [storeJson('', 'Broken'), storeJson('uid-a', 'Dubets Store')],
      });
      expect(section.stores.map((s) => s.name), ['Dubets Store']);
    });

    test('itemCount ignores the shelf the band does not use', () {
      // Both lists are stored so switching type in admin loses nothing, but a
      // store band must not be counted by its leftover products.
      final section = ShopSection.fromJson({
        'title': 'Top Shops',
        'contentType': 'stores',
        'products': [_product('a', 'Rice'), _product('b', 'Eggs')],
        'stores': [storeJson('uid-a', 'Dubets Store')],
      });
      expect(section.itemCount, 1);
    });

    test('a closed store still parses and keeps its status', () {
      final section = ShopSection.fromJson({
        'title': 'Top Shops',
        'contentType': 'stores',
        'products': [],
        'stores': [storeJson('uid-a', 'Dubets Store', open: false)],
      });
      expect(section.stores.single.storeStatus.isOpen, isFalse);
    });
  });

  group('colorFromHex (band colours)', () {
    test('parses 6- and 8-digit hex with or without the hash', () {
      expect(colorFromHex('#EEF2FF', Colors.black), const Color(0xFFEEF2FF));
      expect(colorFromHex('EEF2FF', Colors.black), const Color(0xFFEEF2FF));
      expect(colorFromHex('#80EEF2FF', Colors.black), const Color(0x80EEF2FF));
    });

    test('falls back rather than rendering a wrong colour', () {
      expect(colorFromHex(null, Colors.red), Colors.red);
      expect(colorFromHex('nope', Colors.red), Colors.red);
      expect(colorFromHex('#ABC', Colors.red), Colors.red);
    });
  });
}
