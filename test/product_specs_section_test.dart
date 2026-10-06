import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_shared/models/product_model.dart';
import 'package:trenda_frontend/features/products/presentation/widgets/product_specs_section.dart';

ProductModel _product({required String category, Map<String, dynamic> attrs = const {}}) =>
    ProductModel.fromJson({
      'id': 'p1', 'name': 'X', 'basePrice': 1, 'category': category,
      'listingType': category == 'Vehicles' ? 'big_ticket' : 'standard_physical',
      'attributes': attrs,
    });

void main() {
  testWidgets('renders spec rows for a big-ticket product', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProductSpecsSection(
          product: _product(category: 'Vehicles', attrs: {'year': '2026'}),
        ),
      ),
    ));
    expect(find.text('Specifications'), findsOneWidget);
    expect(find.text('Year'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('renders nothing for a listing without specs', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProductSpecsSection(product: _product(category: 'Electronics')),
      ),
    ));
    expect(find.text('Specifications'), findsNothing);
  });
}
