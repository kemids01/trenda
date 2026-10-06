// trenda_shared/lib/models/chat_model.dart
// Chat/messaging models for vendor-customer communication

/// Chat conversation
class Conversation {
  final String id;
  final List<ConversationParticipant> participants;
  final String? productId;

  /// The product the thread is about, when the server populated it (name, first
  /// image, price). Null on older responses that only carried the id.
  final String? productName;
  final String? productImage;
  final double? productPrice;
  final String? orderId;
  final ChatMessage? lastMessage;
  final Map<String, int> unreadCount;
  final String status; // active, closed
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.participants,
    this.productId,
    this.productName,
    this.productImage,
    this.productPrice,
    this.orderId,
    this.lastMessage,
    this.unreadCount = const {},
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final product = json['product'];
    final order = json['order'];
    final productMap = product is Map<String, dynamic> ? product : null;
    final images = productMap?['images'];
    final price = productMap?['basePrice'] ?? productMap?['price'];
    return Conversation(
      id: json['_id'] ?? json['id'] ?? '',
      participants: (json['participants'] as List? ?? [])
          .map((p) => ConversationParticipant.fromJson(p))
          .toList(),
      productId: productMap != null
          ? productMap['_id']?.toString()
          : product?.toString(),
      productName: productMap?['name']?.toString(),
      productImage:
          images is List && images.isNotEmpty ? images.first?.toString() : null,
      productPrice: price is num ? price.toDouble() : null,
      orderId: order is Map ? order['_id']?.toString() : order?.toString(),
      lastMessage: json['lastMessage'] != null
          ? ChatMessage.fromJson(json['lastMessage'])
          : null,
      unreadCount: Map<String, int>.from(json['unreadCount'] ?? {}),
      status: json['status'] ?? 'active',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  /// Get the other participant (not the current user)
  ConversationParticipant? getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (p) => p.userId != currentUserId,
      orElse: () => participants.first,
    );
  }

  /// The participant with the given [role] ('customer' | 'vendor'), or null.
  ///
  /// Prefer this over [getOtherParticipant] in the apps: participant ids are
  /// Mongo `_id`s, but the apps only hold the Firebase `uid`, so id comparison
  /// never matches. Each app knows its own role, so the "other" party and
  /// "is this mine?" are derived from roles instead.
  ConversationParticipant? participantWithRole(String role) {
    for (final p in participants) {
      if (p.role == role) return p;
    }
    return null;
  }

  int getUnreadCount(String userId) => unreadCount[userId] ?? 0;

  /// Unread count for the participant with [role] ('customer' | 'vendor').
  /// Lets an app read its own unread badge without knowing its Mongo `_id`
  /// (the unreadCount map is keyed by participant `_id`).
  int unreadForRole(String role) {
    final me = participantWithRole(role);
    if (me == null) return 0;
    return unreadCount[me.userId] ?? 0;
  }
}

/// Conversation participant
class ConversationParticipant {
  final String userId;
  final String role; // customer, vendor
  final String? name;
  final String? photoUrl;

  /// Set on the VENDOR participant only: the shop the customer is talking to.
  /// `storeVendorId` is the id the store page is routed by (`/vendor/:id`).
  final String? storeVendorId;
  final String? storeName;
  final String? storeLogo;

  ConversationParticipant({
    required this.userId,
    required this.role,
    this.name,
    this.photoUrl,
    this.storeVendorId,
    this.storeName,
    this.storeLogo,
  });

  /// The shop name when there is one, else the person's name.
  String? get displayName =>
      (storeName != null && storeName!.isNotEmpty) ? storeName : name;

  /// The shop logo when there is one, else the person's photo.
  String? get displayPhoto =>
      (storeLogo != null && storeLogo!.isNotEmpty) ? storeLogo : photoUrl;

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final store = json['store'] is Map ? json['store'] as Map : null;
    if (user is Map<String, dynamic>) {
      return ConversationParticipant(
        userId: user['_id'] ?? user['id'] ?? '',
        role: json['role'] ?? 'customer',
        name: user['name'] ?? user['fullName'],
        photoUrl: user['photoUrl'] ?? user['profileImage'],
        storeVendorId: store?['vendorId']?.toString(),
        storeName: store?['name']?.toString(),
        storeLogo: store?['logo']?.toString(),
      );
    }
    return ConversationParticipant(
      userId: user?.toString() ?? '',
      role: json['role'] ?? 'customer',
    );
  }
}

/// Chat message
class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderRole;
  final String? senderName;
  final String? senderPhoto;
  final String message;
  final List<MessageAttachment> attachments;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderRole,
    this.senderName,
    this.senderPhoto,
    required this.message,
    this.attachments = const [],
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'];
    String senderId;
    String? senderName;
    String? senderPhoto;

    if (sender is Map<String, dynamic>) {
      senderId = sender['_id'] ?? sender['id'] ?? '';
      senderName = sender['name'] ?? sender['fullName'];
      senderPhoto = sender['photoUrl'] ?? sender['profileImage'];
    } else {
      senderId = sender?.toString() ?? '';
    }

    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      conversationId: json['conversation'] ?? '',
      senderId: senderId,
      senderRole: json['senderRole'] ?? 'customer',
      senderName: senderName,
      senderPhoto: senderPhoto,
      message: json['message'] ?? json['text'] ?? '',
      attachments: (json['attachments'] as List? ?? [])
          .map((a) => MessageAttachment.fromJson(a))
          .toList(),
      isRead: json['isRead'] ?? json['read'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['timestamp'] != null
              ? DateTime.parse(json['timestamp'])
              : DateTime.now()),
    );
  }

  /// The product card this message carries, if it is one (server-made, placed
  /// before a customer's question about a product).
  MessageAttachment? get productCard {
    for (final a in attachments) {
      if (a.isProduct) return a;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'message': message,
        if (attachments.isNotEmpty)
          'attachments': attachments.map((a) => a.toJson()).toList(),
      };
}

/// Message attachment
class MessageAttachment {
  final String type; // image, file, product
  final String url;
  final String? name;
  final String? mimeType;
  final int? size;

  /// Product cards only: the product the message is about, and its price when
  /// the card was made (a snapshot — the product may have changed since).
  final String? productId;
  final double? price;

  MessageAttachment({
    required this.type,
    required this.url,
    this.name,
    this.mimeType,
    this.size,
    this.productId,
    this.price,
  });

  bool get isProduct => type == 'product';

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      type: json['type'] ?? 'file',
      url: json['url'] ?? '',
      name: json['name'] ?? json['filename'],
      mimeType: json['mimeType'] ?? json['contentType'],
      size: json['size'] is num ? (json['size'] as num).toInt() : null,
      productId: json['productId']?.toString(),
      price: json['price'] is num ? (json['price'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        if (name != null) 'name': name,
        if (mimeType != null) 'mimeType': mimeType,
        if (size != null) 'size': size,
      };
}
