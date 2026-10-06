// trenda_shared/lib/models/product_qna_model.dart
// Product Q&A model — customer questions + vendor/admin answers

class ProductQnaAnswer {
  final String id;
  final String text;
  final String responderName;
  final bool isVendor;
  final bool isOfficial;
  final int helpfulCount;
  final DateTime? answeredAt;

  const ProductQnaAnswer({
    required this.id,
    required this.text,
    this.responderName = '',
    this.isVendor = false,
    this.isOfficial = false,
    this.helpfulCount = 0,
    this.answeredAt,
  });

  factory ProductQnaAnswer.fromJson(Map<String, dynamic> json) {
    // responderName: explicit field, else populated respondedBy.name, else ''
    String responderName = (json['responderName'] ?? '').toString();
    if (responderName.isEmpty && json['respondedBy'] is Map<String, dynamic>) {
      final respondedBy = json['respondedBy'] as Map<String, dynamic>;
      responderName = (respondedBy['name'] ?? '').toString();
    }

    return ProductQnaAnswer(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      responderName: responderName,
      isVendor: json['isVendor'] == true,
      isOfficial: json['isOfficial'] == true,
      helpfulCount: _toInt(json['helpfulCount']),
      answeredAt: _toDate(json['answeredAt']),
    );
  }
}

class ProductQna {
  final String id;
  final String productId;
  final String question;
  final String askerName;
  final String status;
  final DateTime? createdAt;
  final List<ProductQnaAnswer> answers;

  const ProductQna({
    required this.id,
    required this.productId,
    required this.question,
    this.askerName = 'Customer',
    this.status = 'visible',
    this.createdAt,
    this.answers = const [],
  });

  bool get hasAnswer => answers.isNotEmpty;

  factory ProductQna.fromJson(Map<String, dynamic> json) {
    // productId: `product` may be a bare id string OR a populated object
    String productId = '';
    final product = json['product'];
    if (product is String) {
      productId = product;
    } else if (product is Map<String, dynamic>) {
      productId = (product['_id'] ?? product['id'] ?? '').toString();
    }
    if (productId.isEmpty) {
      productId = (json['productId'] ?? '').toString();
    }

    // askerName: explicit field, else populated user.name, else 'Customer'
    String askerName = (json['askerName'] ?? '').toString();
    if (askerName.isEmpty && json['user'] is Map<String, dynamic>) {
      final user = json['user'] as Map<String, dynamic>;
      askerName = (user['name'] ?? '').toString();
    }
    if (askerName.isEmpty) {
      askerName = 'Customer';
    }

    final answersRaw = json['answers'];
    final answers = answersRaw is List
        ? answersRaw
              .whereType<Map<String, dynamic>>()
              .map(ProductQnaAnswer.fromJson)
              .toList()
        : <ProductQnaAnswer>[];

    return ProductQna(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      productId: productId,
      question: (json['question'] ?? '').toString(),
      askerName: askerName,
      status: (json['status'] ?? 'visible').toString(),
      createdAt: _toDate(json['createdAt']),
      answers: answers,
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
