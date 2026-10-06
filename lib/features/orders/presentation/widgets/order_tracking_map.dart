// trenda_frontend/lib/features/orders/presentation/widgets/order_tracking_map.dart
// Live order tracking map widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:trenda_shared/models/order_model.dart';
import 'package:trenda_shared/services/websocket_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class OrderTrackingMap extends ConsumerStatefulWidget {
  final OrderModel order;

  const OrderTrackingMap({super.key, required this.order});

  @override
  ConsumerState<OrderTrackingMap> createState() => _OrderTrackingMapState();
}

class _OrderTrackingMapState extends ConsumerState<OrderTrackingMap> {
  late MapController _mapController;
  LatLng? _currentRiderLocation;
  bool _isListening = false;
  // Callback reference for removal
  void Function(String, dynamic)? _wsCallback;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startListeningToUpdates();
  }

  @override
  void dispose() {
    if (_wsCallback != null) {
      ref.read(webSocketProvider.notifier).removeEventCallback(_wsCallback!);
    }
    super.dispose();
  }

  void _startListeningToUpdates() {
    if (_isListening) return;
    _isListening = true;

    final wsNotifier = ref.read(webSocketProvider.notifier);

    // Store callback to remove later
    _wsCallback = (event, data) {
      if (event == 'delivery:location_update') {
        final orderId = data['orderId']?.toString();
        if (orderId == widget.order.id) {
          final loc = data['location'];
          if (loc != null) {
            final lat = (loc['latitude'] as num?)?.toDouble();
            final lng = (loc['longitude'] as num?)?.toDouble();

            if (lat != null && lng != null) {
              if (mounted) {
                setState(() {
                  _currentRiderLocation = LatLng(lat, lng);
                });
              }
            }
          }
        }
      }
    };

    wsNotifier.addEventCallback(_wsCallback!);
  }

  // ✅ NEW: Fit camera bounds
  void _fitCameraBounds(LatLng p1, LatLng p2) {
    if (!mounted) return;

    final bounds = LatLngBounds(p1, p2);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  // ✅ NEW: Call rider
  Future<void> _callRider() async {
    final phone = widget.order.delivery?.riderPhone;
    if (phone != null && phone.isNotEmpty) {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        print('Could not launch $uri');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder for orders not in transit
    if (!_isInTransit(widget.order.status)) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Tracking Not Available Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Map will appear once the rider\nstarts the delivery.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    final customerLocation = _getCustomerLocation();
    final vendorLocation = _getVendorLocation();
    final riderLocation = _getRiderLocation();

    if (customerLocation == null) {
      return const Center(child: Text('Delivery location not available'));
    }

    // Determine initial center
    final initialCenter = riderLocation ?? vendorLocation ?? customerLocation;

    return Stack(
      children: [
        AllowRapidTaps(
            child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 14.0,
            onMapReady: () {
              // Auto-fit if we have both points
              if (riderLocation != null) {
                _fitCameraBounds(customerLocation, riderLocation);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.trenda.frontend',
            ),
            MarkerLayer(
              markers: [
                // Customer marker
                Marker(
                  point: customerLocation,
                  width: 40,
                  height: 40,
                  child: const _MapPin(
                    icon: Icons.home,
                    color: Colors.blue,
                    label: 'You',
                  ),
                ),
                // Vendor marker
                if (vendorLocation != null)
                  Marker(
                    point: vendorLocation,
                    width: 40,
                    height: 40,
                    child: const _MapPin(
                      icon: Icons.store,
                      color: Colors.green,
                      label: 'Vendor',
                    ),
                  ),
                // Rider marker
                if (riderLocation != null)
                  Marker(
                    point: riderLocation,
                    width: 50,
                    height: 50,
                    child: const _MapPin(
                      icon: Icons.delivery_dining,
                      color: Colors.orange,
                      label: 'Rider',
                      isPulsing: true,
                    ),
                  ),
              ],
            ),
          ],
        )),

        // Status overlay (Top)
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getStatusMessage(widget.order.status),
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Recenter Button (Right)
        if (riderLocation != null)
          Positioned(
            right: 16,
            bottom: 180, // Above the card
            child: FloatingActionButton.small(
              heroTag: 'recenter_map',
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Colors.black87),
              onPressed: () =>
                  _fitCameraBounds(customerLocation, riderLocation),
            ),
          ),

        // Rider Info Card (Bottom)
        if (riderLocation != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: const Icon(Icons.person, color: Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.order.delivery?.riderName ?? 'Rider',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.order.delivery?.vehiclePlate != null)
                          Text(
                            widget.order.delivery!.vehiclePlate!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green.shade50,
                      foregroundColor: Colors.green,
                    ),
                    icon: const Icon(Icons.phone),
                    onPressed: _callRider,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  bool _isInTransit(String status) {
    return [
      'shipped',
      'pickup_started',
      'out_for_delivery',
      'arriving_at_customer',
    ].contains(status.toLowerCase());
  }

  LatLng? _getCustomerLocation() {
    final address = widget.order.shippingAddress;
    if (address?.latitude != null && address?.longitude != null) {
      return LatLng(address!.latitude!, address.longitude!);
    }
    return null;
  }

  LatLng? _getVendorLocation() {
    final vendor = widget.order.vendor;
    if (vendor?.latitude != null && vendor?.longitude != null) {
      return LatLng(vendor!.latitude!, vendor.longitude!);
    }
    return null;
  }

  LatLng? _getRiderLocation() {
    // Return the real-time location from WebSocket
    return _currentRiderLocation;
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'shipped':
      case 'pickup_started':
        return 'Rider is picking up your order';
      case 'out_for_delivery':
        return 'Rider is on the way to you';
      case 'arriving_at_customer':
        return 'Rider is at your location';
      default:
        return 'Tracking your order';
    }
  }
}

class _MapPin extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isPulsing;

  const _MapPin({
    required this.icon,
    required this.color,
    required this.label,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: isPulsing ? 12 : 6,
                spreadRadius: isPulsing ? 2 : 0,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ],
    );
  }
}
