// trenda_shared/lib/trenda_shared.dart - COMPLETE
library trenda_shared;

// Core
export 'core/config.dart';
export 'core/exceptions.dart';
export 'core/http_client.dart';
export 'core/logger.dart';
export 'core/error_boundary.dart';
export 'core/heartbeat_service.dart';
export 'core/trenda_qr.dart';

// Image pipeline (web-safe, bytes-based)
export 'core/images/picked_image.dart';
export 'core/images/image_picker_service.dart';

// Models
export 'models/ad_model.dart';
export 'models/user_model.dart' hide VendorVerification;
export 'models/product_model.dart';
export 'models/order_model.dart';
export 'models/dashboard_model.dart' hide PerformanceMetrics;
export 'models/store_model.dart';
export 'models/store_category.dart';
export 'models/promotion_model.dart';
export 'models/return_model.dart';
export 'models/review_model.dart';
export 'models/shipment_model.dart' hide ShippingAddress;
export 'models/financial_model.dart';
export 'models/performance_model.dart';
export 'models/chat_model.dart';
export 'chat/chat_timeline.dart';
export 'chat/chat_product_card.dart';
export 'chat/chat_alert.dart';
export 'models/inventory_model.dart';
export 'models/security_model.dart';
export 'models/verification_model.dart';
export 'models/bundle_model.dart';
export 'models/address_model.dart';
export 'models/installment_model.dart';
export 'models/report_model.dart';
export 'models/product_qna_model.dart';

// Repositories
export 'data/base_repository.dart';
export 'data/ads_repository.dart';
export 'data/products_repository.dart';
export 'data/user_repository.dart';
export 'data/municipality_repository.dart';
export 'data/orders_repository.dart';
export 'data/supplier_repository.dart';
export 'data/store_repository.dart';
export 'data/shipping_repository.dart';
export 'data/promotions_repository.dart';
export 'data/returns_repository.dart';
export 'data/reviews_repository.dart';
export 'data/financial_repository.dart';
export 'data/dashboard_repository.dart';
export 'data/performance_repository.dart';
export 'data/chat_repository.dart';
export 'data/inventory_repository.dart';
export 'data/security_repository.dart';
export 'data/verification_repository.dart';
export 'data/bundles_repository.dart' hide BundlesFetchResult;
export 'data/location_repository.dart';
export 'data/vendor_address_repository.dart';
export 'data/image_repository.dart';
export 'data/approval_repository.dart';
export 'data/report_repository.dart';
export 'data/app_config_repository.dart';
export 'data/product_qna_repository.dart';

// Models (continued)
export 'models/approval_model.dart';
export 'models/delivery_info.dart';
export 'models/app_runtime_config.dart';
export 'models/listing_template.dart';

// Services
export 'services/offline_queue.dart';

// Widgets
export 'widgets/municipality_dropdown.dart';
export 'widgets/barangay_dropdown.dart';
export 'widgets/cached_image.dart' hide ProductImage;
export 'widgets/connectivity_banner.dart';
export 'widgets/async_value_widget.dart';
export 'widgets/shimmer_loading.dart';
export 'widgets/refresh_list.dart';
export 'widgets/form_fields.dart';
export 'widgets/dialogs.dart';
export 'widgets/date_picker.dart';
export 'widgets/chips.dart';
export 'widgets/buttons.dart';
export 'widgets/cards.dart';

// Core utilities
export 'core/dio_interceptors.dart';
export 'core/api_result.dart';
export 'core/navigation_helpers.dart';
export 'core/debounce.dart';
export 'core/storage_helper.dart';
export 'core/extensions.dart';
export 'core/performance.dart';
export 'core/form_validation.dart';
export 'core/timezone.dart'; // GMT+8 timezone utilities

// Services
export 'services/geo_service.dart';

// Responsive widgets
export 'widgets/responsive.dart';

// Shared transaction widgets
export 'widgets/delivery_transaction_card.dart';
export 'widgets/ban_notification_overlay.dart';
export 'widgets/app_config_gate.dart';
export 'models/ad_placement.dart';
export 'widgets/official_ad_slot.dart';
export 'widgets/popup_ad.dart';
export 'widgets/price_comparison.dart';
