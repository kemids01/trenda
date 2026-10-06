// The stock count wording shared by every product card and the product page.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trenda_frontend/features/products/widgets/product_card_parts.dart';
import 'package:trenda_shared/models/product_model.dart';

ProductModel _p({bool track = true, String mode = 'checkout'}) => ProductModel(
      id: 'p1',
      name: 'Pandesal',
      slug: 'p1',
      vendorId: 'v1',
      basePrice: 10,
      totalStock: 24,
      category: 'Bakery',
      trackInventory: track,
      transactionMode: mode,
    );

void main() {
  test('out, low and plenty read differently', () {
    expect(stockCountLabel(0).label, 'Out of stock');
    expect(stockCountLabel(0).level, StockLevel.out);
    expect(stockCountLabel(3).label, 'Only 3 left');
    expect(stockCountLabel(3).level, StockLevel.low);
    expect(stockCountLabel(24).label, '24 in stock');
    expect(stockCountLabel(24).level, StockLevel.plenty);
  });

  test("the product's own low-stock threshold decides 'Only N left'", () {
    expect(stockCountLabel(8, lowThreshold: 10).label, 'Only 8 left');
    expect(stockCountLabel(8, lowThreshold: 5).label, '8 in stock');
  });

  test('inquiry listings and untracked products show no count', () {
    expect(showsStockCount(_p()), isTrue);
    expect(showsStockCount(_p(track: false)), isFalse);
    expect(showsStockCount(_p(mode: 'inquiry')), isFalse);
  });

  testWidgets('StockCountLine prints the count', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: StockCountLine(stock: 12)),
    ));
    expect(find.text('12 in stock'), findsOneWidget);
  });
}
