// lib/features/checkout/presentation/checkout_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:trenda_frontend/features/cart/models/cart_model.dart';
import 'package:trenda_shared/trenda_shared.dart'
    show PhoneValidator, AppConfigRepository, formatMoney, GeoService, MunicipalityDropdown;
import 'package:trenda_frontend/features/core/widgets/frontend_official_ad_slot.dart';
import '../../core/router/app_router.dart';
import '../../core/providers/location_providers.dart';
import '../../cart/providers/cart_provider.dart';
import '../../home/application/user_profile_notifier.dart';
import '../../home/models/user_address.dart';
import '../../home/models/profile_models.dart';
import '../../home/presentation/map_picker_page.dart';
import '../../home/presentation/addresses_page.dart';
import '../logic/payment_availability.dart';
import '../logic/pasabay_tiers.dart';
import '../providers/checkout_provider.dart';
import '../utils/farthest_vendor.dart';
import '../utils/visible_delivery_types.dart';
import '../utils/store_grouping.dart';
import '../utils/delivery_gating.dart';
import '../utils/gps_address.dart';
import '../utils/served_municipality_snap.dart';
import '../utils/location_capture.dart';
import '../utils/checkout_wizard.dart';
import '../utils/payment_summary.dart';
import '../providers/promo_provider.dart';
import '../models/checkout_model.dart';
import 'promo_code_widget.dart';
import '../../giftcards/widgets/gift_card_selector.dart';
import '../../giftcards/providers/gift_card_provider.dart';
import 'dynamic_fee_banner.dart';
import '../../stores/widgets/closed_store_dialog.dart';
import '../../stores/utils/advance_order_notice.dart';
import '../../stores/widgets/advance_order_notice.dart';
import '../widgets/pasabay_guide_modal.dart';
import '../providers/pasabay_provider.dart';
import '../models/checkout_quote.dart';
import '../data/pasabay_repository.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

/// All the fee/total figures the checkout UI displays. Computed once per build
/// (watches delivery-fee / checkout-fee / pasabay / promo providers) and shared
/// by the fee breakdown, the review step, and the bottom bar.
typedef CheckoutTotals = ({
  double subtotal,
  double discount,
  double shippingFee, // per-type display fee before free shipping
  double finalShippingFee,
  double total,
  double? distanceKm,
  bool isFreeShippingEligible,
  /// The server's cascade estimate behind [shippingFee], when one resolved. The breakdown itemises
  /// from THIS, never from the global DeliveryFees config — those are two different fee tables the
  /// moment a city sets an override, and the dialog used to show the global rates under a
  /// city-scoped total (Tuguegarao: itemised ₱60 base + ₱20/km against a ₱189.59 total).
  CalculatedDeliveryFee? serverFee,
  /// One delivery fee per store when the cart spans several stores (POST /api/checkout/quote).
  /// When [CheckoutQuote.showsPerStoreFees], [shippingFee] is the SUM of these and the summary
  /// lists each store — every store's order has its own rider and its own fee.
  CheckoutQuote? storeQuote,
});

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  UserAddress? _selectedAddress;

  /// The city (and barangay) the delivery fees must be quoted for.
  ///
  /// ⚠️ Every `deliveryFeesProvider` read goes through this. Reading the provider unscoped quotes
  /// the GLOBAL fee tier while checkout charges the per-city override — that is how Tuguegarao City
  /// displayed ₱60 and billed ₱80 (ORD-1789445886279-9FP4QN). Empty until an address is chosen, and
  /// the global tier is the right answer then.
  DeliveryFeeScope get _feeScope => (
        municipality: _selectedAddress?.city ?? '',
        barangay: _selectedAddress?.barangay ?? '',
      );
  UserAddress? _savedAddress; // last saved-mode selection, to restore when toggling back
  // GPS-only delivery (visitor without a saved address).
  bool _isGpsOnly = false;
  int _currentStep = 0; // 0 Address+Contact, 1 Items+Delivery+Payment, 2 Review
  bool _gpsLoading = false;
  double? _gpsLat, _gpsLng;
  String? _gpsMunicipality, _gpsBarangay;
  // GPS is the source of truth: municipality/barangay are reverse-geocoded from
  // the pin (no manual pickers). Manual barangay entry only surfaces when the
  // reverse-geocode can't detect one (rural pins) so checkout still has a barangay.
  String? _forceReasonShownFor; // guards the auto why-dialog per locked type
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cod;
  // What checkout currently offers. Resolved per shipping municipality once an address is chosen,
  // falling back to the global flags before then — see _refreshPaymentAvailability().
  bool _codEnabled = true;
  bool _onlineEnabled = true;
  // The global featureFlags, kept so a municipality lookup that fails can fall back to them.
  bool _globalCodEnabled = true;
  bool _globalOnlineEnabled = true;
  // The municipality whose payment flags are currently applied, so we only re-fetch on a change.
  String? _paymentFlagsCity;
  bool _isProcessing = false;
  bool _isDetectingLocation = false;
  // Express is the default; the build step below still switches to Heavy when
  // the cart weight forces it, or to the first offered type if Express is off.
  String _selectedDeliveryType = 'express';
  String? _selectedBatchTypeId;
  bool _showPasabayQuickGuide = false;

  // Contact info controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  bool _hasPrefilledContact = false;
  bool _hasPrefilledPhone = false;

  @override
  void initState() {
    super.initState();
    // ✅ FIX: Listen to text changes to re-evaluate _canPlaceOrder()
    _nameController.addListener(_onContactFieldChanged);
    _phoneController.addListener(_onContactFieldChanged);
    // Grey out COD / online per the admin payment flags. These are the GLOBAL ones — a starting
    // point only. Once the customer picks a delivery address, _refreshPaymentAvailability() asks
    // the backend for that municipality's resolved answer, which is what the server actually
    // enforces at submit; a COD-only city used to be shown both options and refused on placement.
    AppConfigRepository.fetch().then((cfg) {
      if (!mounted || cfg == null) return;
      _globalCodEnabled = cfg.flag('cashOnDelivery');
      _globalOnlineEnabled = cfg.flag('onlinePayment');
      _applyPaymentAvailability(resolvePaymentAvailability(
        globalCashOnDelivery: _globalCodEnabled,
        globalOnlinePayment: _globalOnlineEnabled,
      ));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = ref.read(userProfileProvider).valueOrNull;
      if (profile != null) {
        _tryPrefillFromProfile(profile);
      }
      // ✅ PASABAY: Show guide modal on first visit
      PasabayGuideModal.showIfNeeded(context);
    });
  }

  void _applyPaymentAvailability(PaymentAvailability a) {
    if (!mounted) return;
    if (_codEnabled == a.cashOnDelivery && _onlineEnabled == a.onlinePayment) return;
    setState(() {
      _codEnabled = a.cashOnDelivery;
      _onlineEnabled = a.onlinePayment;
      // If the method the customer had selected just became unavailable in this city, move them off
      // it rather than letting them submit an order the server will refuse.
      final onCod = _selectedPaymentMethod == PaymentMethod.cod;
      if (onCod && !_codEnabled && _onlineEnabled) {
        _selectedPaymentMethod = PaymentMethod.card;
      } else if (!onCod && !_onlineEnabled && _codEnabled) {
        _selectedPaymentMethod = PaymentMethod.cod;
      }
    });
  }

  /// Ask the backend which payment methods this municipality allows. The server enforces the same
  /// answer at submit, so this is what keeps the app from offering a choice that will fail.
  /// Falls back to the global flags when the city cannot be resolved.
  Future<void> _refreshPaymentAvailability(String? municipality) async {
    if (municipality == _paymentFlagsCity) return; // already applied
    _paymentFlagsCity = municipality;
    final resolved = await ref
        .read(paymentAvailabilityProvider(municipality).future)
        .catchError((_) => null);
    if (!mounted || _paymentFlagsCity != municipality) return; // address changed under us
    _applyPaymentAvailability(resolvePaymentAvailability(
      municipality: resolved,
      globalCashOnDelivery: _globalCodEnabled,
      globalOnlinePayment: _globalOnlineEnabled,
    ));
  }

  void _onContactFieldChanged() {
    // Trigger rebuild so Place Order button re-evaluates
    if (mounted) setState(() {});
  }

  void _tryPrefillFromProfile(UserProfileState profile) {
    // The phone is filled on its own: a prefilled name used to end prefilling,
    // so a profile phone arriving later never reached the field.
    if (!_hasPrefilledPhone && (profile.phone ?? '').isNotEmpty) {
      if (_phoneController.text.isEmpty) _phoneController.text = profile.phone!;
      _hasPrefilledPhone = true;
    }
    if (_hasPrefilledContact) return;

    if (_nameController.text.isEmpty) {
      final name = profile.fullName;
      if (name.isNotEmpty && name != 'New User') {
        _nameController.text = name;
      } else if (profile.displayName != null &&
          profile.displayName!.isNotEmpty) {
        _nameController.text = profile.displayName!;
      }
    }
    if (_nameController.text.isNotEmpty) _hasPrefilledContact = true;
  }

  /// Keep the number typed here on the profile, so the next checkout (and the
  /// Profile page) has it. It used to travel only on the order.
  void _rememberPhone(UserProfileState? profile) {
    final phone = _phoneController.text.trim();
    if (!PhoneValidator.validate(phone).isValid) return;
    if (phone == (profile?.phone ?? '').trim()) return;
    ref.read(userProfileProvider.notifier).updatePhone(phone);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onContactFieldChanged);
    _phoneController.removeListener(_onContactFieldChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep the payment options in step with the delivery city. _selectedAddress is assigned from
    // several places (saved address, GPS, picker), so this is hooked once here rather than at every
    // assignment; _refreshPaymentAvailability no-ops when the city has not changed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshPaymentAvailability(_selectedAddress?.city);
    });

    final cartAsync = ref.watch(checkoutCartProvider);
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0E1116)
          : const Color(0xFFF4F6F8),
      body: cartAsync.when(
        data: (cart) {
          if (cart.items.isEmpty) {
            return _buildEmptyCartState();
          }

          return profileAsync.when(
            data: (profile) {
              if (!_hasPrefilledContact) {
                _tryPrefillFromProfile(profile);
              }
              // Auto-select first address if needed
              if (!_isGpsOnly && _selectedAddress == null && profile.addresses.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_isGpsOnly && _selectedAddress == null) {
                    setState(() => _selectedAddress = profile.addresses.first);
                  }
                });
              }

              final totals = _computeCheckoutTotals(cart);
              return Column(
                children: [
                  const FrontendOfficialAdSlot(slotId: 'frontend.checkout.top'),
                  _buildStepHeader(),
                  // A closed store that still takes orders: said up front, on
                  // every step, not only in a dialog after Place Order.
                  if (advanceOrderMessage(advanceOrderStores(cart.items))
                      case final msg?)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: AdvanceOrderNotice(message: msg),
                    ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentStep,
                      children: [
                        _buildStep1(profile),
                        _buildStep2(cart, totals),
                        _buildStep3(cart, totals),
                      ],
                    ),
                  ),
                  _buildWizardBottomBar(cart, totals),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyCartState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: const Center(child: Text('Your cart is empty')),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(List<UserAddress> addresses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddressModeToggle(),
        const SizedBox(height: 12),
        if (_isGpsOnly) _buildGpsAddressBody() else _buildSavedAddressBody(addresses),
        _buildDeliveryAreaNotice(addresses),
      ],
    );
  }

  Widget _buildAddressModeToggle() {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Saved address'), icon: Icon(Icons.home_outlined)),
        ButtonSegment(value: true, label: Text('GPS location'), icon: Icon(Icons.my_location)),
      ],
      selected: {_isGpsOnly},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        final gps = s.first;
        setState(() {
          _isGpsOnly = gps;
          if (gps) {
            _savedAddress = _selectedAddress;
            _selectedAddress = null; // set once GPS + municipality + barangay chosen
          } else {
            _selectedAddress = _savedAddress;
          }
        });
        if (gps && _gpsLat == null) _captureGps();
      },
    );
  }

  Future<void> _captureGps() async {
    setState(() => _gpsLoading = true);
    final result = await captureCurrentPosition();
    if (!mounted) return;
    if (result.ok) {
      _gpsLat = result.position!.latitude;
      _gpsLng = result.position!.longitude;
      // GPS is enough: derive municipality + barangay from the pin itself.
      final geo = await GeoService.reverseGeocode(_gpsLat!, _gpsLng!);
      if (!mounted) return;
      final loc = deriveGpsLocality(geo?.components);
      // The geocoder's names only PRE-SELECT: the shopper confirms both in PSGC
      // dropdowns below, so the name always matches what the delivery-area rule
      // compares against ("Tuguegarao" → "Tuguegarao City"). The address city can be
      // any DELIVERABLE city (served ∪ neighbour towns), not just a served one.
      List<String> deliverable;
      try {
        final list = await ref.read(deliverableMunicipalitiesProvider.future);
        deliverable = list.map((m) => m.name).toList();
      } catch (_) {
        deliverable = const <String>[]; // nothing pre-selected; the shopper picks
      }
      if (!mounted) return;
      setState(() {
        _gpsMunicipality = snapToServedMunicipality(loc.municipality, deliverable);
        // Kept only if PSGC lists it for that municipality (checked by the dropdown).
        _gpsBarangay = loc.hasBarangay ? loc.barangay : null;
      });
      _composeGpsAddress();
    } else {
      // Stay in GPS mode so the user can fix settings/permission and tap Refresh
      // (a GPS-only visitor has no saved address to fall back to).
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
    if (mounted) setState(() => _gpsLoading = false);
  }

  void _composeGpsAddress() {
    if (_gpsLat != null &&
        _gpsLng != null &&
        (_gpsMunicipality ?? '').isNotEmpty &&
        (_gpsBarangay ?? '').isNotEmpty) {
      _selectedAddress = buildGpsAddress(
        lat: _gpsLat!,
        lng: _gpsLng!,
        municipality: _gpsMunicipality!,
        barangay: _gpsBarangay!,
      );
    } else {
      _selectedAddress = null; // block submit until complete
    }
  }

  Widget _buildGpsAddressBody() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, size: 18, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _gpsLoading
                      ? 'Getting your location…'
                      : (_gpsLat != null
                          ? 'Using your current location (${_gpsLat!.toStringAsFixed(4)}, ${_gpsLng!.toStringAsFixed(4)})'
                          : 'Location not captured yet'),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
              if (!_gpsLoading)
                TextButton(onPressed: _captureGps, child: const Text('Refresh')),
            ],
          ),
          if (_gpsLat != null) ...[
            const SizedBox(height: 12),
            // Both from PSGC — the same served list and barangay list the saved-address
            // form uses — so the delivery-area check compares real names, never typed text.
            MunicipalityDropdown(
              value: _gpsMunicipality,
              isRequired: true,
              labelText: 'Municipality/City *',
              items: ref.watch(deliverableMunicipalitiesProvider).valueOrNull,
              onChanged: (v) => setState(() {
                _gpsMunicipality = v;
                _gpsBarangay = null; // a barangay belongs to one municipality
                _composeGpsAddress();
              }),
            ),
            if ((_gpsMunicipality ?? '').isNotEmpty) ...[
              const SizedBox(height: 12),
              ref.watch(barangaysProvider(_gpsMunicipality)).when(
                    data: (barangays) {
                      final detected = _gpsBarangay;
                      if (detected != null && !barangays.contains(detected)) {
                        // The geocoder's barangay isn't a PSGC name here — drop it so the
                        // shopper picks one; never ship a name the rule can't match.
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted || _gpsBarangay != detected) return;
                          setState(() {
                            _gpsBarangay = null;
                            _composeGpsAddress();
                          });
                        });
                      }
                      return DropdownButtonFormField<String>(
                        value: barangays.contains(detected) ? detected : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Barangay *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.home_work_outlined),
                        ),
                        items: [
                          for (final b in barangays)
                            DropdownMenuItem(
                                value: b, child: Text(b, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() {
                          _gpsBarangay = v;
                          _composeGpsAddress();
                        }),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => Text(
                      'Could not load barangays — tap Refresh.',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade400),
                    ),
                  ),
            ],
          ],
          const SizedBox(height: 8),
          Text(
            'Delivering to your current GPS pin. Make sure your name and phone below are correct.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedAddressBody(List<UserAddress> addresses) {
    if (addresses.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(Icons.location_off_outlined,
                  size: 40, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No delivery address',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(Routes.addresses),
                icon: const Icon(Icons.add),
                label: const Text('Add Address'),
              ),
              const SizedBox(height: 16),
              _buildQuickLocationLink(),
            ],
          ),
        ),
      );
    }

    final selected = _selectedAddress;

    return Column(
      children: [
        if (selected != null)
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF1A237E).withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // Tapping the address opens its editor (the same form as
            // My Addresses ▸ edit); "Change" still picks another address.
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('checkout-selected-address'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _editAddress(selected),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        selected.label,
                        style: const TextStyle(
                          color: Color(0xFF1A237E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined,
                            size: 16, color: Colors.grey.shade500),
                        TextButton(
                          onPressed: () => _showAddressSelector(addresses),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (selected.houseNumber != null &&
                        selected.houseNumber!.isNotEmpty)
                      '#${selected.houseNumber}',
                    selected.street,
                  ].where((s) => s.isNotEmpty).join(', '),
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (selected.barangay != null && selected.barangay!.isNotEmpty)
                  Text(
                    'Brgy. ${selected.barangay}, ${selected.city}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  )
                else
                  Text(
                    selected.city,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                Text(
                  [
                    if (selected.province != null &&
                        selected.province!.isNotEmpty)
                      selected.province!,
                    selected.region,
                    if (selected.postalCode.isNotEmpty) selected.postalCode,
                  ].join(', '),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                if (selected.landmark != null && selected.landmark!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '📍 ${selected.landmark}',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                _buildLocationTypeBadge(selected.locationType),
              ],
                  ),
                ),
              ),
            ),
          )
        else
          ListTile(
            title: const Text('Select Address'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAddressSelector(addresses),
          ),

        const SizedBox(height: 12),
        // ⚠️ Warning if address is missing barangay
        if (selected != null &&
            (selected.barangay == null || selected.barangay!.isEmpty))
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Colors.orange.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Address is missing barangay/municipality. Please update to place order.',
                    style:
                        TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
                TextButton(
                  onPressed: () => _editAddress(selected),
                  child: const Text('Edit', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        // Quick add/detect button if needed
        if (selected == null) _buildQuickLocationLink(),
      ],
    );
  }

  /// The same editor as My Addresses ▸ edit, for this one address. The edited
  /// copy becomes the selection, so the fee and delivery-area checks re-run on it.
  void _editAddress(UserAddress address) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => AddressForm(
        existingAddress: address,
        onSave: (updated) async {
          await ref
              .read(userProfileProvider.notifier)
              .addOrUpdateAddress(updated, isUpdate: true);
          if (!mounted) return;
          setState(() => _selectedAddress = updated);
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
  }

  void _showAddressSelector(List<UserAddress> addresses) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                'Select Delivery Address',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: addresses.length + 1,
                itemBuilder: (context, index) {
                  if (index == addresses.length) {
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF5F5F5),
                        child: Icon(Icons.add, color: Colors.black),
                      ),
                      title: const Text('Add New Address'),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(Routes.addresses);
                      },
                    );
                  }
                  final address = addresses[index];
                  final isSelected = _selectedAddress?.id == address.id;
                  final isIncomplete =
                      address.barangay == null || address.barangay!.isEmpty;
                  final subtitleParts = <String>[
                    address.street,
                    if (address.barangay != null &&
                        address.barangay!.isNotEmpty)
                      'Brgy. ${address.barangay}',
                    address.city,
                  ].where((s) => s.isNotEmpty).toList();
                  return ListTile(
                    leading: Icon(
                      isSelected
                          ? Icons.check_circle
                          : isIncomplete
                              ? Icons.warning_amber_rounded
                              : Icons.location_on_outlined,
                      color: isSelected
                          ? const Color(0xFF1A237E)
                          : isIncomplete
                              ? Colors.orange
                              : Colors.grey,
                    ),
                    title: Text(address.label),
                    subtitle: Text(
                      subtitleParts.join(', '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isIncomplete
                        ? const Tooltip(
                            message: 'Missing barangay',
                            child: Icon(Icons.edit,
                                size: 16, color: Colors.orange),
                          )
                        : null,
                    onTap: () {
                      setState(() => _selectedAddress = address);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickLocationLink() {
    return GestureDetector(
      onTap: _isDetectingLocation ? null : () => TapGuard.run('checkout.detectMyLocation', _detectMyLocation),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.05),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isDetectingLocation)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              const Icon(Icons.my_location, size: 18, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              _isDetectingLocation ? 'Detecting...' : 'Use current location',
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildTextField(
              _nameController, 'Receiver Name', Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField(_phoneController, 'Phone Number',
              Icons.phone_outlined, TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(_notesController, 'Delivery Notes (Optional)',
              Icons.note_outlined),
        ],
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      [TextInputType? type]) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF1A237E)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildOrderSummary(CartModel cart) {
    return ExpansionTile(
      title: Text(
        '${cart.items.length} Items',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Total: ₱${cart.subtotal.toStringAsFixed(2)}',
        style: TextStyle(color: Colors.grey.shade600),
      ),
      childrenPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      backgroundColor: Colors.white,
      collapsedBackgroundColor: Colors.white,
      children: [
        // ✅ Grouped by store: store-name header, then that store's items.
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final group in groupItemsByStore(cart.items)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.storefront,
                          size: 16, color: Colors.grey.shade700),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          group.storeName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12, left: 4),
                    child: _itemRow(item),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showForceReasonDialog(String reason) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delivery option'),
        content: Text(reason),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _itemRow(CartItem item) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            image: item.image.isNotEmpty
                ? DecorationImage(image: NetworkImage(item.image), fit: BoxFit.cover)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('Qty: ${item.quantity}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
        Text('₱${item.subtotal.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      children: [
        _buildPaymentOption(
            PaymentMethod.cod,
            _codEnabled ? 'Cash on Delivery' : 'Cash on Delivery (unavailable)',
            Icons.money,
            _codEnabled),
        if (!_codEnabled)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Cash on Delivery is currently unavailable.',
              style: TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ),
        const SizedBox(height: 8),
        // Online methods have no live gateway yet, so they are ALWAYS non-selectable. Label them
        // "coming soon" (truthful) when the admin flag is on, or "unavailable" when it's off.
        _buildPaymentOption(
            PaymentMethod.card,
            _onlineEnabled ? 'Credit/Debit Card (coming soon)' : 'Credit/Debit Card (unavailable)',
            Icons.credit_card,
            false),
        const SizedBox(height: 8),
        _buildPaymentOption(
            PaymentMethod.ewallet,
            _onlineEnabled ? 'E-Wallet (coming soon)' : 'E-Wallet (unavailable)',
            Icons.account_balance_wallet,
            false),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _onlineEnabled
                ? 'Online payment is coming soon — please use Cash on Delivery.'
                : 'Online payment is currently unavailable.',
            style: const TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
      PaymentMethod method, String label, IconData icon, bool isEnabled) {
    final isSelected = _selectedPaymentMethod == method;
    return InkWell(
      onTap: isEnabled
          ? () => setState(() => _selectedPaymentMethod = method)
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1A237E).withValues(alpha: 0.05)
              : Colors.white,
          border: Border.all(
            color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? (isSelected
                      ? const Color(0xFF1A237E)
                      : Colors.grey.shade700)
                  : Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isEnabled
                      ? const Color(0xFF2C3E50)
                      : Colors.grey.shade400,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF1A237E), size: 20)
            else if (!isEnabled)
              Text('Soon',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryTypeSection(CartModel cart) {
    // ✅ Watch delivery fees from backend config
    final feesAsync = ref.watch(deliveryFeesProvider(_feeScope));
    final fees = feesAsync.valueOrNull ?? DeliveryFees.defaults();

    // ✅ Admin-enabled delivery options (hide disabled ones; server also enforces).
    const allDeliveryTypes = ['express', 'pasabay', 'heavy_express'];
    final visibleTypes = visibleDeliveryTypes(allDeliveryTypes, fees.enabledDeliveryTypes);

    // Calculate total weight
    double totalWeight = 0;
    for (final item in cart.items) {
      totalWeight += (item.weight ?? 0.5) * item.quantity;
    }

    // Auto-select heavy_express at the SAME weight the server forces it (heavyTypeThresholdKg =
    // DeliverySettings.loadCapacityKg, resolved per city/barangay) — not the surcharge threshold.
    final forceHeavy = totalWeight > fees.heavyTypeThresholdKg;
    if (forceHeavy && _selectedDeliveryType != 'heavy_express') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedDeliveryType = 'heavy_express');
      });
    }

    // ✅ Forced type (by weight) + GPS-only pasabay filter → the options actually offered.
    // Heavy Express is auto-selected and NOT manually changeable; Pasabay hidden for GPS-only.
    final force = deliverySelectionReason(
        totalWeight: totalWeight, heavyThreshold: fees.heavyTypeThresholdKg);
    final lockedType = force?.type; // 'heavy_express' | null
    final offered = availableDeliveryTypes(
      visibleTypes,
      gpsOnly: _isGpsOnly,
      lockedType: lockedType,
      totalWeight: totalWeight,
      pasabayMaxWeightKg: fees.pasabayMaxWeightKg,
    );
    if (offered.isNotEmpty && !offered.contains(_selectedDeliveryType)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !offered.contains(_selectedDeliveryType)) {
          setState(() => _selectedDeliveryType = offered.first);
        }
      });
    }
    if (lockedType != null && _forceReasonShownFor != lockedType) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _forceReasonShownFor = lockedType;
          _showForceReasonDialog(force!.reason);
        }
      });
    }

    // (Selection coercion is handled above via `offered` — covers admin-disabled, forced heavy,
    // and GPS-only pasabay exclusion in one place.)

    // Express is the BASE delivery tier (the ₱30 expressSurcharge was retired platform-wide on
    // 2026-08-20) — show the actual fee, never a phantom "+₱0" surcharge.
    final expressFeeLabel = '₱${fees.express.toStringAsFixed(0)}';

    return Column(
      children: [
        // Forced Heavy Express — auto-selected, locked; tap for the reason.
        if (lockedType != null && force != null)
          InkWell(
            onTap: () => _showForceReasonDialog(force.reason),
            child: Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Heavy Express auto-selected for this order. Tap to see why.',
                      style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
                    ),
                  ),
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                ],
              ),
            ),
          ),
        if (offered.contains('express')) ...[
          _buildDeliveryOption(
              'express',
              'Express Delivery',
              'Priority delivery — $expressFeeLabel',
              Icons.flash_on,
              !forceHeavy),
          const SizedBox(height: 8),
        ],
        if (offered.contains('pasabay')) ...[
          _buildDeliveryOption(
              'pasabay',
              'Pasabay (Recommended)',
              'Batch delivery with neighbors — save up to 70%!',
              Icons.groups,
              !forceHeavy,
              isPasabay: true,
              savingsLabel: 'SAVE UP TO 70%'),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: GestureDetector(
              onTap: () => PasabayGuideModal.show(context),
              child: const Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 14, color: Color(0xFF4CAF50)),
                  SizedBox(width: 4),
                  Text(
                    'How does Pasabay work?',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // Heavy is a CONSEQUENCE OF WEIGHT, not a menu item: selectable only once the cart is over
        // the load capacity, at which point it is also the only option left. It used to be enabled
        // unconditionally, so one tap bought the heavy surcharge on a cart that never needed it and
        // the server accepted it without complaint (a 6 kg order charged +₱60).
        if (offered.contains('heavy_express'))
          _buildDeliveryOption(
              'heavy_express',
              'Heavy Express',
              forceHeavy
                  ? 'For heavy items (from ₱${fees.heavyExpress.toStringAsFixed(0)})'
                  : 'Only for orders over ${fees.heavyTypeThresholdKg.toStringAsFixed(0)}kg — your cart is ${totalWeight.toStringAsFixed(1)}kg',
              Icons.fitness_center,
              forceHeavy),
        if (_selectedDeliveryType == 'pasabay')
          _buildPasabayBatchSelector(cart, fees.pasabay),
      ],
    );
  }

  Widget _buildPasabayBatchSelector(CartModel cart, double defaultPasabayFee) {
    if (_selectedAddress == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Please select a shipping address first to see available Pasabay batches.',
          style: TextStyle(color: Colors.orange, fontSize: 13),
        ),
      );
    }

    final municipality = _selectedAddress!.city;
    final barangay = _selectedAddress!.barangay ?? '';

    if (barangay.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Please select an address with a valid barangay.',
          style: TextStyle(color: Colors.orange, fontSize: 13),
        ),
      );
    }

    final deliveryFeesAsync = ref.watch(deliveryFeesProvider(_feeScope));
    final deliveryFees = deliveryFeesAsync.valueOrNull ?? DeliveryFees.defaults();
    
    // #1: normal (express) fee for the savings preview = authoritative server estimate (farthest
    // vendor) with the local formula as offline fallback.
    double normalFee = deliveryFees.express;
    final feeQuery = _expressFeeQuery(cart);
    if (feeQuery != null) {
      normalFee = ref.watch(checkoutFeeProvider(feeQuery.params)).maybeWhen(
            data: (f) => f.totalFee,
            orElse: () => feeQuery.localExpress,
          );
    }

    final previewsAsync = ref.watch(pasabayFeePreviewProvider((
      municipality: municipality,
      barangay: barangay,
      normalFee: normalFee,
    )));

    return previewsAsync.when(
      data: (previews) {
        if (previews.isEmpty) {
          return const Card(
            margin: EdgeInsets.only(top: 8),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No batch configurations found for this location.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          );
        }

        final selectedId = _selectedBatchTypeId ?? previews.first.batchType?.id;

        final activeBatchesAsync = ref.watch(activeBatchesProvider((
          municipality: municipality,
          barangay: barangay,
        )));

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(top: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.green.shade200, width: 1.5),
          ),
          color: Colors.green.shade50.withValues(alpha: 0.3),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pasabay Batch Option',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showPasabayQuickGuide = !_showPasabayQuickGuide;
                            });
                          },
                          child: Icon(
                            Icons.help_outline_rounded,
                            size: 16,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'SAVINGS INSIDE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showPasabayQuickGuide) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How Pasabay Batching Works:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          // From the tiers actually offered here (see pasabayGuideLines).
                          pasabayGuideLines([
                            for (final p in previews)
                              if (p.batchType != null) p.batchType!,
                          ]).map((l) => '• $l').join('\n'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade800,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: previews.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final preview = previews[index];
                    final bt = preview.batchType;
                    final fi = preview.feeInfo;
                    if (bt == null || fi == null) return const SizedBox.shrink();

                    final isSelected = selectedId == bt.id;
                    
                    final activeBatches = activeBatchesAsync.valueOrNull?.batches ?? [];
                    final matchingActiveBatch = activeBatches.firstWhere(
                      (b) => b.batchType?.id == bt.id && b.status == 'WAITING',
                      orElse: () => PasabayActiveBatch(
                        id: '',
                        batchCode: '',
                        barangay: '',
                        currentOrders: 0,
                        targetOrders: 0,
                        status: '',
                        progress: 0,
                        slotsRemaining: 0,
                        expiresInMinutes: 0,
                      ),
                    );
                    final hasActiveBatch = matchingActiveBatch.id.isNotEmpty;

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedBatchTypeId = bt.id;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? Colors.green.shade600 : Colors.grey.shade300,
                            width: isSelected ? 2.0 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Radio<String>(
                              value: bt.id,
                              groupValue: selectedId,
                              activeColor: Colors.green.shade600,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedBatchTypeId = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Text(
                                        bt.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected ? Colors.green.shade900 : Colors.black87,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          bt.code.toUpperCase().contains('SUPER_SAVER') ? '24h limit' : '3h limit',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isSelected ? Colors.green.shade800 : Colors.grey.shade600,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (hasActiveBatch)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${matchingActiveBatch.currentOrders}/${matchingActiveBatch.targetOrders} orders',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Colors.orange.shade900,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    bt.description ?? 'Wait for batch to fill up',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (hasActiveBatch) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Active batch exists! Join for instant matching.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.orange.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₱${fi.discountedFee.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  '₱${fi.originalFee.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Save ₱${fi.savings.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildDeliveryOption(String type, String label, String description,
      IconData icon, bool isEnabled, {bool isPasabay = false, String? savingsLabel}) {
    final isSelected = _selectedDeliveryType == type;
    return InkWell(
      onTap:
          isEnabled ? () => setState(() => _selectedDeliveryType = type) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.green.withValues(alpha: 0.05) : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.green : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isEnabled
                  ? (isSelected ? Colors.green : Colors.grey.shade700)
                  : Colors.grey.shade300,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? const Color(0xFF2C3E50)
                              : Colors.grey.shade400,
                        ),
                      ),
                      if (savingsLabel != null && isEnabled)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            savingsLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEnabled
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  CheckoutTotals _computeCheckoutTotals(CartModel cart) {
    final deliveryFeesAsync = ref.watch(deliveryFeesProvider(_feeScope));
    final deliveryFees = deliveryFeesAsync.valueOrNull ?? DeliveryFees.defaults();

    double shippingFee = deliveryFees.getFeeForType(_selectedDeliveryType);
    double? distanceKm;
    CalculatedDeliveryFee? serverFee;

    // Server estimate = the §8 cascade + distance createOrder charges. Before, it ran only when a
    // product carried coordinates — none does — so checkout showed the flat base fee (₱580) while
    // the order was charged ₱629.59. _serverFeeQuery now sends pin-less vendors as IDs.
    final feeQuery = _serverFeeQuery(cart, _selectedDeliveryType);
    if (feeQuery != null) {
      final fv = feeQuery.fv;
      if (fv != null) distanceKm = fv.distanceKm;
      final localFee = fv != null
          ? deliveryFees.calculateDistanceBasedFee(fv.distanceKm, _selectedDeliveryType)
          : shippingFee;
      final feeAsync = ref.watch(checkoutFeeProvider(feeQuery.params));
      serverFee = feeAsync.valueOrNull;
      if (serverFee != null && serverFee.distance > 0) distanceKm = serverFee.distance;
      shippingFee =
          feeAsync.maybeWhen(data: (f) => f.totalFee, orElse: () => localFee);
    }

    if (_selectedDeliveryType == 'pasabay' && _selectedAddress != null) {
      final municipality = _selectedAddress!.city;
      final barangay = _selectedAddress!.barangay ?? '';
      if (barangay.isNotEmpty && municipality.isNotEmpty) {
        double normalFee = deliveryFees.express;
        final localExpress = distanceKm != null
            ? deliveryFees.calculateDistanceBasedFee(distanceKm, 'express')
            : deliveryFees.express;
        final expressQuery = _serverFeeQuery(cart, 'express');
        if (expressQuery != null) {
          final exAsync = ref.watch(checkoutFeeProvider(expressQuery.params));
          normalFee =
              exAsync.maybeWhen(data: (f) => f.totalFee, orElse: () => localExpress);
        } else {
          normalFee = localExpress;
        }
        final previewsAsync = ref.watch(pasabayFeePreviewProvider((
          municipality: municipality,
          barangay: barangay,
          normalFee: normalFee,
        )));
        final previews = previewsAsync.valueOrNull ?? [];
        if (previews.isNotEmpty) {
          final selectedId = _selectedBatchTypeId ?? previews.first.batchType?.id;
          final selectedPreview = previews.firstWhere(
            (p) => p.batchType?.id == selectedId,
            orElse: () => previews.first,
          );
          shippingFee =
              selectedPreview.feeInfo?.discountedFee ?? deliveryFees.pasabay;
        }
      }
    }

    var isFreeShippingEligible = deliveryFees.freeDeliveryEnabled &&
        cart.subtotal >= deliveryFees.freeDeliveryThreshold;

    // Several stores → several orders, one rider and one delivery fee EACH, priced by the server
    // from each store (the same code createOrder charges with). Free delivery is then judged per
    // store too, so the per-store fees replace the cart-level estimate and threshold entirely.
    final storeQuote = _storeQuote(cart);
    if (storeQuote != null && storeQuote.showsPerStoreFees) {
      shippingFee = storeQuote.deliveryTotal!;
      isFreeShippingEligible = shippingFee == 0;
    }

    // Free shipping means free: the old expression left the cross-muni surcharge behind, so a
    // "free delivery" order still displayed a shipping charge.
    final finalShippingFee = isFreeShippingEligible ? 0.0 : shippingFee;
    final couponDiscount = ref.watch(promoProvider).discount;
    final rawTotal = cart.subtotal + finalShippingFee - couponDiscount;
    final total = rawTotal < 0 ? 0.0 : rawTotal;

    return (
      subtotal: cart.subtotal,
      discount: couponDiscount,
      shippingFee: shippingFee,
      finalShippingFee: finalShippingFee,
      total: total,
      distanceKm: distanceKm,
      isFreeShippingEligible: isFreeShippingEligible,
      serverFee: serverFee,
      storeQuote: storeQuote,
    );
  }

  /// The per-store quote for the ticked cart lines at the chosen address, or null (no address yet,
  /// or the quote failed — checkout then keeps its single estimate).
  CheckoutQuote? _storeQuote(CartModel cart) {
    final address = _selectedAddress;
    if (address == null || cart.items.isEmpty) return null;
    return ref.watch(checkoutQuoteProvider((
      cartKey: checkoutQuoteCartKey(cart.items.map((i) =>
          (productId: i.productId, variantId: i.variantId, quantity: i.quantity))),
      municipality: address.city,
      barangay: address.barangay ?? '',
      lat: address.latitude,
      lng: address.longitude,
      deliveryType: _selectedDeliveryType,
      batchTypeId: _selectedDeliveryType == 'pasabay' ? _selectedBatchTypeId : null,
    ))).valueOrNull;
  }

  /// One row per store under the delivery line: "Jollibee · ₱80". Each store's order is carried
  /// by its own rider, so each has its own delivery fee.
  List<Widget> _buildPerStoreDeliveryRows(CheckoutQuote quote) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurface.withValues(alpha: 0.6);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 4),
        child: Row(
          children: [
            Icon(Icons.two_wheeler, size: 14, color: scheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${quote.splitCaption} — each store is delivered separately',
                style: TextStyle(fontSize: 11.5, color: muted),
              ),
            ),
          ],
        ),
      ),
      for (final g in quote.groups)
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 2, bottom: 2),
          child: Row(
            children: [
              Icon(g.isOfficial ? Icons.verified : Icons.storefront, size: 13, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${g.label} · ${g.itemCount} item${g.itemCount == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
              Text(
                (g.fee ?? 0) == 0 ? 'FREE' : formatMoney(g.fee!),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: (g.fee ?? 0) == 0 ? Colors.green.shade700 : scheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _buildStepHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final idle = scheme.onSurface.withValues(alpha: 0.18);

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          for (final step in kCheckoutSteps) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: step.index <= _currentStep
                        ? scheme.primary
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          step.index <= _currentStep ? scheme.primary : idle,
                      width: 1.6,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: step.index < _currentStep
                      ? Icon(Icons.check_rounded,
                          size: 15, color: scheme.onPrimary)
                      : Text(
                          '${step.index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: step.index <= _currentStep
                                ? scheme.onPrimary
                                : scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                ),
                const SizedBox(height: 6),
                Text(
                  step.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.3,
                    fontWeight: step.index == _currentStep
                        ? FontWeight.w800
                        : FontWeight.w600,
                    color: step.index <= _currentStep
                        ? scheme.onSurface.withValues(alpha: 0.85)
                        : scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
            if (step.index != kCheckoutSteps.last.index)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
                  decoration: BoxDecoration(
                    color: step.index < _currentStep ? scheme.primary : idle,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep1(UserProfileState profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Delivery Address', Icons.place_outlined),
          _buildAddressSection(profile.addresses),
          const SizedBox(height: 24),
          _buildSectionTitle('Contact Info', Icons.person_outline),
          _buildContactInfoSection(),
        ],
      ),
    );
  }

  Widget _buildStep2(CartModel cart, CheckoutTotals totals) {
    final vendorMuni =
        cart.items.isNotEmpty ? (cart.items.first.location?.city ?? '') : '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Order Items', Icons.shopping_bag_outlined),
          _buildOrderSummary(cart),
          const SizedBox(height: 24),
          if (vendorMuni.isNotEmpty)
            DynamicFeeBanner(orderTotal: cart.subtotal, municipality: vendorMuni),
          _buildSectionTitle('Delivery Option', Icons.local_shipping_outlined),
          _buildDeliveryTypeSection(cart),
          const SizedBox(height: 24),
          PromoCodeWidget(orderTotal: cart.subtotal),
          // Gift card sits directly under the promo code — both reduce what the customer pays,
          // and the gift card's figure depends on the coupon discount above it.
          Builder(builder: (_) {
            final f = _computeCheckoutTotals(cart);
            return GiftCardSelector(
              subtotal: f.subtotal,
              discount: f.discount,
              total: f.total,
            );
          }),
          const SizedBox(height: 24),
          _buildSectionTitle('Payment', Icons.payment_outlined),
          _buildPaymentMethodSection(),
        ],
      ),
    );
  }

  Widget _buildStep3(CartModel cart, CheckoutTotals totals) {
    final deliveryLabel = switch (_selectedDeliveryType) {
      'express' => '🏍️ Express',
      'heavy_express' => '🚛 Heavy Express',
      'pasabay' => '🤝 Pasabay',
      _ => _selectedDeliveryType,
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReviewCard(
            title: 'Delivery address',
            icon: Icons.place_outlined,
            onEdit: () => setState(() => _currentStep = 0),
            child: Text(
              _selectedAddress == null
                  ? 'No delivery address selected yet — tap Edit.'
                  : '${_nameController.text.trim()} · ${_phoneController.text.trim()}\n'
                      // Blank parts are dropped; an address with no barangay
                      // used to render a dangling ", ,".
                      '${[
                      _selectedAddress!.street,
                      _selectedAddress!.barangay,
                      _selectedAddress!.city,
                    ].map((p) => p?.trim() ?? '').where((p) => p.isNotEmpty).join(', ')}',
              style: const TextStyle(fontSize: 13, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          _buildReviewCard(
            title: 'Delivery method',
            icon: Icons.local_shipping_outlined,
            onEdit: () => setState(() => _currentStep = 1),
            child: Text(deliveryLabel, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(height: 12),
          _buildSectionTitle('Order Items', Icons.shopping_bag_outlined),
          _buildOrderSummary(cart),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildFeeBreakdown(cart, totals),
          ),
          if (!_canPlaceOrder()) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      // Say WHY when it's the delivery area, not "complete your address".
                      _deliveryArea()?.ok == false
                          ? (_deliveryArea()!.message.isNotEmpty
                              ? _deliveryArea()!.message
                              : "Some items can't be delivered to this address.")
                          : 'Complete your delivery address and contact info (tap Edit above) '
                              'to place your order.',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String title,
    required Widget child,
    required VoidCallback onEdit,
    IconData? icon,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white12
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 15,
                    color: scheme.onSurface.withValues(alpha: 0.45)),
                const SizedBox(width: 7),
              ],
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 1.2,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 32),
                ),
                child: const Text(
                  'Edit',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildWizardBottomBar(CartModel cart, CheckoutTotals totals) {
    final isLast = _currentStep == kCheckoutSteps.last.index;
    final canAdvance = _currentStep == 0 ? _isStep1Valid() : true;
    final primaryEnabled =
        isLast ? (_canPlaceOrder() && !_isProcessing) : canAdvance;

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.4 : 0.08,
            ),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shows what the customer actually pays. With a gift card applied
            // the order total and the cash collected differ, and this bar used
            // to print only the former.
            Builder(builder: (context) {
              final scheme = Theme.of(context).colorScheme;
              // Address step: no delivery type chosen yet, so show the items alone.
              if (showsItemsSubtotalOnly(_currentStep)) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Items subtotal',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Text(
                          'Delivery fee added in the next step',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formatMoney(totals.subtotal),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: scheme.onSurface,
                      ),
                    ),
                  ],
                );
              }
              final applied = _giftCardApplied(totals);
              final due = paymentDueOnDelivery(
                total: totals.total,
                giftCardApplied: applied,
              );
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        payButtonAmountLabel(
                          total: totals.total,
                          giftCardApplied: applied,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      if (applied > 0)
                        Text(
                          '${formatMoney(totals.total)} less '
                          '${formatMoney(applied)} gift card',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    formatMoney(due),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 10),
            Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => setState(() => _currentStep -= 1),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: primaryEnabled
                        ? (isLast
                            ? () => TapGuard.run('checkout.placeOrder', _placeOrder)
                            : () {
                                if (_currentStep == 0) {
                                  _rememberPhone(
                                      ref.read(userProfileProvider).valueOrNull);
                                }
                                setState(() => _currentStep += 1);
                              })
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size.fromHeight(52),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.38),
                    ),
                    child: _isProcessing
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          )
                        : Text(isLast ? 'Place order' : 'Next',
                            style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.2)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// What the selected gift card pays toward this order, using the card's own
  /// capped arithmetic — never a second copy of it. Zero when nothing is
  /// selected or the cards have not loaded.
  double _giftCardApplied(CheckoutTotals t) {
    final code = ref.watch(selectedGiftCardCodeProvider);
    if (code == null) return 0;
    final cards = ref.watch(spendableGiftCardsProvider).valueOrNull;
    if (cards == null) return 0;
    final card = cards.where((c) => c.code == code).firstOrNull;
    if (card == null) return 0;
    return card.appliedTo(subtotal: t.subtotal, discount: t.discount);
  }

  bool _isStep1Valid() => checkoutStep1Valid(
        city: _selectedAddress?.city,
        street: _selectedAddress?.street,
        barangay: _selectedAddress?.barangay,
        name: _nameController.text,
        phone: _phoneController.text,
      );

  Widget _buildFeeBreakdown(CartModel cart, CheckoutTotals t) {
    final deliveryFees =
        ref.watch(deliveryFeesProvider(_feeScope)).valueOrNull ?? DeliveryFees.defaults();
    final giftCardApplied = _giftCardApplied(t);
    final shippingFee = t.shippingFee;
    final distanceKm = t.distanceKm;
    final isFreeShippingEligible = t.isFreeShippingEligible;
    final couponDiscount = t.discount;
    final total = t.total;
    final perStore = t.storeQuote?.showsPerStoreFees == true ? t.storeQuote : null;
    final remainingForFree = deliveryFees.freeDeliveryThreshold - cart.subtotal;
    final freeShippingProgress = deliveryFees.freeDeliveryEnabled
        ? (cart.subtotal / deliveryFees.freeDeliveryThreshold).clamp(0.0, 1.0)
        : 0.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Free Shipping Progress Banner
        // Free delivery is judged PER STORE when the cart is split, so a cart-level "₱X more"
        // would promise something no single store's order may reach.
        if (deliveryFees.freeDeliveryEnabled && !isFreeShippingEligible && perStore == null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.green.shade100],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping,
                        color: Colors.green.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '₱${remainingForFree.toStringAsFixed(0)} more for FREE delivery!',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: freeShippingProgress,
                    backgroundColor: Colors.green.shade100,
                    color: Colors.green.shade600,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

        // ✅ Free Shipping Achieved Banner
        if (isFreeShippingEligible)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle,
                    color: Colors.green.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  '🎉 FREE Delivery Applied!',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

        // (The orange "different municipality" notice lived here. It compared only the
        // FIRST store's city, with a " City" false positive; the server's delivery-area
        // check on the address step replaces it — see _buildDeliveryAreaNotice.)

        // ✅ Enhanced Fee Breakdown with transparency
        _buildSummaryRow('Subtotal', formatMoney(cart.subtotal)),
        if (couponDiscount > 0)
          _buildSummaryRow('Discount', '-${formatMoney(couponDiscount)}'),
        if (!isFreeShippingEligible && perStore != null) ...[
          _buildSummaryRow('Delivery (${perStore.groups.length} stores)', formatMoney(shippingFee)),
          ..._buildPerStoreDeliveryRows(perStore),
        ],
        if (!isFreeShippingEligible && perStore == null) ...[
          InkWell(
            onTap: () => _showFeeBreakdown(
              context,
              fees: deliveryFees,
              distanceKm: distanceKm,
              shippingFee: shippingFee,
              deliveryType: _selectedDeliveryType,
              serverFee: t.serverFee,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        distanceKm != null
                            ? 'Delivery (${distanceKm.toStringAsFixed(1)}km)'
                            : 'Delivery Fee',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Tap to see fee breakdown',
                        child: Icon(Icons.info_outline,
                            size: 14, color: Colors.blue.shade400),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        formatMoney(shippingFee),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.expand_more,
                          size: 16, color: Colors.grey.shade400),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        if (isFreeShippingEligible)
          _buildSummaryRow('Delivery', 'FREE', isFree: true),
        const Divider(height: 16),

        // A gift card does not lower the order total — it lowers the cash the
        // rider collects. Both figures are named so the confirm screen matches
        // what happens at the door.
        ..._buildReceiptTail(total, giftCardApplied),
      ],
    );
  }

  List<Widget> _buildReceiptTail(double total, double giftCardApplied) {
    final scheme = Theme.of(context).colorScheme;
    final lines = paymentSummaryLines(
      // The rows above already print subtotal/discount/delivery; only the
      // closing figures are taken from here.
      subtotal: 0,
      discount: 0,
      shippingFee: 0,
      total: total,
      giftCardApplied: giftCardApplied,
    ).where((l) =>
        l.kind == PaymentLineKind.orderTotal ||
        l.kind == PaymentLineKind.giftCard ||
        l.kind == PaymentLineKind.dueOnDelivery);

    return [
      for (final line in lines)
        Padding(
          padding: EdgeInsets.symmetric(vertical: line.isEmphasis ? 3 : 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                line.label,
                style: TextStyle(
                  fontSize: line.kind == PaymentLineKind.dueOnDelivery ? 14 : 13,
                  fontWeight: line.kind == PaymentLineKind.dueOnDelivery
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: scheme.onSurface.withValues(
                    alpha: line.kind == PaymentLineKind.dueOnDelivery ? 0.9 : 0.6,
                  ),
                ),
              ),
              Text(
                line.isCredit
                    ? '-${formatMoney(line.amount.abs())}'
                    : formatMoney(line.amount),
                style: TextStyle(
                  fontSize:
                      line.kind == PaymentLineKind.dueOnDelivery ? 20 : 14,
                  fontWeight: line.kind == PaymentLineKind.dueOnDelivery
                      ? FontWeight.w800
                      : FontWeight.w600,
                  letterSpacing:
                      line.kind == PaymentLineKind.dueOnDelivery ? -0.5 : 0,
                  color: line.isCredit
                      ? const Color(0xFF157347)
                      : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
    ];
  }

  // --- Summary Row Helper ---
  Widget _buildSummaryRow(String label, String value,
      {String? subtitle, bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isFree ? Colors.green.shade600 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // --- Delivery Fee Breakdown Dialog ---
  void _showFeeBreakdown(
    BuildContext context, {
    required DeliveryFees fees,
    required double? distanceKm,
    required double shippingFee,
    required String deliveryType,
    CalculatedDeliveryFee? serverFee,
  }) {
    // Itemise from the SERVER's cascade result whenever we have one — it is the same calculation
    // that charges the order, resolved for this city and barangay. `fees` is the GLOBAL config and
    // is only a fallback for the no-address case: using it under a city-scoped total printed rows
    // that did not add up to the figure beside them.
    final baseFee = serverFee?.baseFee ?? fees.base;
    final baseDistance = serverFee?.baseDistance ?? fees.baseDistance;
    final perKm = serverFee?.perKm ?? fees.perKm;
    final extraKm = serverFee != null
        ? serverFee.extraDistance
        : (distanceKm != null
            ? (distanceKm - baseDistance).clamp(0.0, double.infinity)
            : 0.0);
    final distanceFee = serverFee?.distanceFee ?? (extraKm * perKm);

    double typeSurcharge = 0;
    String typeLabel = 'Standard';
    switch (deliveryType) {
      case 'express':
        // Express is the base tier — no surcharge. (fees.expressSurcharge is a retired backend field
        // that the §8 cascade no longer applies; showing it here overstated the breakdown by ₱30.)
        typeSurcharge = 0;
        typeLabel = 'Express (base tier)';
        break;
      case 'heavy_express':
        typeSurcharge = serverFee?.heavySurcharge ?? fees.heavySurcharge;
        typeLabel = 'Heavy Express';
        break;
      case 'pasabay':
        typeLabel = 'Pasabay (flat)';
        break;
      default:
        typeLabel = 'Standard';
    }

    // Anything the cascade added that we did not name above (handling, peak, weather, barangay).
    final otherSurcharges =
        ((serverFee?.surcharge ?? 0) - typeSurcharge).clamp(0.0, double.infinity);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Row(
              children: [
                Icon(Icons.receipt_long, size: 20, color: Color(0xFF1A237E)),
                SizedBox(width: 8),
                Text(
                  'Delivery Fee Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Base fee
            _feeRow(
              'Base Fee',
              '₱${baseFee.toStringAsFixed(0)}',
              'Covers first ${baseDistance.toStringAsFixed(0)}km',
            ),

            // Distance fee
            if (distanceFee > 0)
              _feeRow(
                'Distance Surcharge',
                '₱${distanceFee.toStringAsFixed(0)}',
                '${extraKm.toStringAsFixed(1)}km × ₱${perKm.toStringAsFixed(0)}/km',
              ),

            // Delivery type surcharge
            if (typeSurcharge > 0)
              _feeRow(
                '$typeLabel Surcharge',
                '₱${typeSurcharge.toStringAsFixed(0)}',
                'Charged for orders over the ${fees.heavyTypeThresholdKg.toStringAsFixed(0)}kg load capacity',
              ),

            // Everything else the cascade added (handling, peak hour, weather, barangay), so the
            // rows always reconcile to the total below instead of quietly falling short.
            if (otherSurcharges > 0)
              _feeRow(
                'Other Surcharges',
                '₱${otherSurcharges.toStringAsFixed(0)}',
                'Peak hour, weather or barangay charges',
              ),

            // Pasabay flat
            if (deliveryType == 'pasabay')
              _feeRow(
                'Pasabay Rate',
                '₱${fees.pasabay.toStringAsFixed(0)}',
                'Flat rate batch delivery',
              ),

            const Divider(height: 24),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Delivery Fee',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                  '₱${shippingFee.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF1A237E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Info
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      distanceKm != null
                          ? 'Based on ${distanceKm.toStringAsFixed(1)}km distance from vendor to your address. '
                              'Fees are set by your municipality admin.'
                          : 'Select a delivery address to see distance-based pricing. '
                              'Current fee is the base rate for $typeLabel delivery.',
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String amount, String detail) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              Text(detail,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
          Text(amount,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- Helpers ---

  Widget _buildLocationTypeBadge(LocationType type) {
    if (type == LocationType.manual) return const SizedBox.shrink();

    final isGps = type == LocationType.gps;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isGps
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isGps ? Colors.green : Colors.blue,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGps ? Icons.gps_fixed : Icons.map,
            size: 12,
            color: isGps ? Colors.green : Colors.blue,
          ),
          const SizedBox(width: 3),
          Text(
            isGps ? 'GPS' : 'Map',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isGps ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _detectMyLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final capture = await captureCurrentPosition();
      if (!mounted) return;
      if (!capture.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(capture.error!)),
        );
        return;
      }
      final position = capture.position!;

      final result = await Navigator.push<MapPickerResult>(
        context,
        MaterialPageRoute(
          builder: (_) => MapPickerPage(
            initialLocation: LatLng(position.latitude, position.longitude),
          ),
        ),
      );

      if (result != null && mounted) {
        _showSaveLocationDialog(result, isGps: true);
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  void _showSaveLocationDialog(MapPickerResult result, {bool isGps = false}) {
    // Redirect to the full address page which has PSGC dropdowns
    // Pre-populate the GPS coordinates
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        // Pre-initialize the address form with GPS coordinates
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final notifier = ref.read(addressFormProvider.notifier);
          notifier.reset();
          notifier.updateCoordinates(
            result.location.latitude,
            result.location.longitude,
          );
          notifier.setLocationType(isGps ? LocationType.gps : LocationType.map);
          notifier.setLabel(isGps ? 'GPS Location' : 'Map Location');
          if (result.street != null && result.street!.isNotEmpty) {
            notifier.updateStreet(result.street!);
          }
        });

        return AddressForm(
          onSave: (address) async {
            final profileNotifier = ref.read(userProfileProvider.notifier);
            await profileNotifier.addOrUpdateAddress(address, isUpdate: false);
            setState(() => _selectedAddress = address);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        );
      },
    );
  }

  bool _canPlaceOrder() {
    if (_selectedAddress == null) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_phoneController.text.trim().isEmpty) return false;
    if (_selectedAddress!.barangay == null ||
        _selectedAddress!.barangay!.isEmpty) return false;
    if (_selectedAddress!.street.isEmpty) return false;
    if (_selectedAddress!.city.isEmpty) return false;
    // Every store must serve this address (the server rule createOrder enforces).
    if (_deliveryArea()?.ok == false) return false;
    return true;
  }

  /// The delivery-area pre-check for the current address + cart, or null when there
  /// is nothing to ask yet.
  DeliveryAreaQuery? _deliveryAreaQuery() {
    final addr = _selectedAddress;
    final cart = ref.watch(checkoutCartProvider).valueOrNull;
    if (addr == null || cart == null || cart.items.isEmpty || addr.city.isEmpty) {
      return null;
    }
    final ids = cart.items
        .map((i) => i.productId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return (
      municipality: addr.city,
      barangay: addr.barangay ?? '',
      lat: addr.latitude,
      lng: addr.longitude,
      productIds: ids.join(','),
    );
  }

  /// The server's answer, or null while loading / when there is nothing to ask.
  /// Build-time only (it watches providers).
  DeliveryAreaCheck? _deliveryArea() {
    final q = _deliveryAreaQuery();
    return q == null ? null : ref.watch(deliveryAreaCheckProvider(q)).valueOrNull;
  }

  /// Red card on the address step naming each store that can't deliver here.
  Widget _buildDeliveryAreaNotice(List<UserAddress> addresses) {
    final area = _deliveryArea();
    if (area == null || area.ok) return const SizedBox.shrink();
    final where = area.addressMunicipality.isNotEmpty
        ? area.addressMunicipality
        : 'this address';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.wrong_location_outlined, size: 20, color: Colors.red.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Can't deliver to $where",
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: Colors.red.shade800),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          for (final b in area.blocked)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(color: Colors.red.shade700)),
                  Expanded(
                    child: Text(
                      b.reason == 'store_location_missing'
                          ? "${b.storeName} hasn't set its location yet."
                          : "${b.storeName} (${b.storeMunicipality}) doesn't deliver there.",
                      style: TextStyle(fontSize: 12.5, color: Colors.red.shade800, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            OutlinedButton.icon(
              onPressed: _isGpsOnly ? _captureGps : () => _showAddressSelector(addresses),
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: Text(_isGpsOnly ? 'Refresh location' : 'Change address'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.push(Routes.cart),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('Remove items in cart'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            ),
          ]),
        ],
      ),
    );
  }

  /// Builds the express-fee query for the pasabay "normal fee" savings preview (farthest cart vendor),
  /// plus the local-formula fallback. Returns null when coordinates are unavailable. Uses ref.read so
  /// it is safe from both build and event-handler contexts (#1 pasabay preview follow-up).
  ({CheckoutFeeParams params, double localExpress})? _expressFeeQuery(CartModel cart) {
    final deliveryFees =
        ref.read(deliveryFeesProvider(_feeScope)).valueOrNull ?? DeliveryFees.defaults();
    final q = _serverFeeQuery(cart, 'express');
    if (q == null) return null;
    final localExpress = q.fv != null
        ? deliveryFees.calculateDistanceBasedFee(q.fv!.distanceKm, 'express')
        : deliveryFees.express;
    return (params: q.params, localExpress: localExpress);
  }

  /// The params for the server fee estimate — the SAME §8 cascade + farthest-leg distance createOrder
  /// charges. Products that carry coordinates are measured here ([fv]); products that do not (every
  /// product today) are sent as product IDs so the server resolves each one's origin exactly as
  /// createOrder does — the vendor's STORE pin, or an Official product's WAREHOUSE. Null only when
  /// there is no customer GPS or no line to measure from.
  ({CheckoutFeeParams params, VendorDistance? fv})? _serverFeeQuery(
      CartModel cart, String deliveryType) {
    final custLat = _selectedAddress?.latitude;
    final custLng = _selectedAddress?.longitude;
    if (custLat == null || custLng == null || cart.items.isEmpty) return null;

    final vendorCoords = <List<double>>[];
    for (final i in cart.items) {
      final loc = i.location;
      if (loc != null && loc.coordinates.length >= 2) {
        vendorCoords
            .add([loc.coordinates[0].toDouble(), loc.coordinates[1].toDouble()]);
      }
    }
    final fv = farthestVendor(vendorCoords, custLat, custLng);
    final pinless = pinlessLineIdsKey(cart.items
        .map((i) => (id: i.productId, coordinates: i.location?.coordinates)));
    if (fv == null && pinless.isEmpty) return null;

    final cartWeight =
        cart.items.fold<double>(0, (s, i) => s + (i.weight ?? 0.5) * i.quantity);
    return (
      params: (
        deliveryType: deliveryType,
        municipality: _selectedAddress!.city,
        barangay: _selectedAddress!.barangay ?? '',
        weight: cartWeight,
        itemCount: cart.items.length,
        orderTotal: cart.subtotal,
        vendorLat: fv?.lat ?? 0, // 0 = none; the server then measures from the resolved origins only
        vendorLng: fv?.lng ?? 0,
        customerLat: custLat,
        customerLng: custLng,
        productIds: pinless,
      ),
      fv: fv,
    );
  }

  Future<void> _placeOrder() async {
    // Basic validation
    if (_selectedAddress == null ||
        _nameController.text.isEmpty ||
        _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // ✅ Validate complete address with barangay
    if (_selectedAddress!.barangay == null ||
        _selectedAddress!.barangay!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add barangay to your delivery address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedAddress!.street.isEmpty || _selectedAddress!.city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your delivery address (street, city)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate phone number using PhoneValidator
    final phoneValidation =
        PhoneValidator.validate(_phoneController.text.trim());
    if (!phoneValidation.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(phoneValidation.errorMessage ?? 'Invalid phone number')),
      );
      return;
    }

    // ✅ Check for closed stores - block (not accepting orders) or warn (advance order).
    // Re-read the cart first: its storeStatus is the store's status NOW, not when the cart
    // loaded (a store can close while the shopper sits on this page).
    setState(() => _isProcessing = true);
    await ref.read(cartProvider.notifier).loadCart(silent: true);
    if (!mounted) return;
    setState(() => _isProcessing = false);
    final cart = ref.read(checkoutCartProvider).value;
    if (cart != null) {
      final closedStoreItems = cart.items
          .where((item) => item.storeStatus?.isOpen == false)
          .toList();

      if (closedStoreItems.isNotEmpty) {
        // If ANY closed store is not accepting orders, block checkout.
        final blockedItem = closedStoreItems.where((item) =>
            closedStoreAction(
              isOpen: item.storeStatus?.isOpen,
              canOrder: item.storeStatus?.canOrder,
            ) ==
            ClosedStoreAction.blocked);
        if (blockedItem.isNotEmpty) {
          await showStoreClosedBlockedDialog(
            context,
            storeName: blockedItem.first.storeName,
            nextOpenTime: blockedItem.first.storeStatus?.nextOpenTime,
            nextOpenDay: blockedItem.first.storeStatus?.nextOpenDay,
            nextOpenAt: blockedItem.first.storeStatus?.nextOpenAt,
          );
          return;
        }
        // Otherwise the remaining closed stores accept advance orders — warn once.
        final first = closedStoreItems.first;
        final proceed = await showClosedStoreDialog(
          context,
          storeName: first.storeName,
          reopening: reopeningLine(
            day: first.storeStatus?.nextOpenDay,
            time: first.storeStatus?.nextOpenAt,
            legacy: first.storeStatus?.nextOpenTime,
          ),
          question:
              'Do you still want to place your order and wait for the store to open?',
          confirmLabel: 'Place order & wait',
        );
        if (!proceed) return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final cart = ref.read(checkoutCartProvider).value!;
      if (cart.items.isEmpty) return;
      
      String? targetBatchTypeId;
      if (_selectedDeliveryType == 'pasabay') {
        targetBatchTypeId = _selectedBatchTypeId;
        if (targetBatchTypeId == null && _selectedAddress != null) {
          final deliveryFees = ref.read(deliveryFeesProvider(_feeScope)).valueOrNull ?? DeliveryFees.defaults();
          // #1: normal (express) fee = authoritative server estimate (farthest vendor); local fallback.
          double normalFee = deliveryFees.express;
          final feeQuery = _expressFeeQuery(cart);
          if (feeQuery != null) {
            try {
              normalFee =
                  (await ref.read(checkoutFeeProvider(feeQuery.params).future)).totalFee;
            } catch (_) {
              normalFee = feeQuery.localExpress;
            }
          }
          final previewsVal = ref.read(pasabayFeePreviewProvider((
            municipality: _selectedAddress!.city,
            barangay: _selectedAddress!.barangay ?? '',
            normalFee: normalFee,
          ))).valueOrNull;
          // The tier the picker shows as selected when the shopper chose none —
          // the first one offered. (A lookup for code 'saver' used to sit here;
          // codes are uppercase like 'SAVER_5', so it never matched.)
          if (previewsVal != null && previewsVal.isNotEmpty) {
            targetBatchTypeId = previewsVal.first.batchType?.id;
          }
        }
      }

      final checkoutData = CheckoutRequest(
        shippingAddress: {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'notes': _notesController.text.trim(),
          'street': _selectedAddress!.street,
          'city': _selectedAddress!.city,
          'municipality': _selectedAddress!.city, // ✅ PH: municipality = city
          'region': _selectedAddress!.region,
          'postalCode': _selectedAddress!.postalCode,
          'barangay': _selectedAddress!.barangay ?? '',
          'country': _selectedAddress!.country,
          if (_selectedAddress!.landmark != null &&
              _selectedAddress!.landmark!.isNotEmpty)
            'landmark': _selectedAddress!.landmark,
          // GPS coordinates for delivery navigation
          if (_selectedAddress!.latitude != null)
            'latitude': _selectedAddress!.latitude,
          if (_selectedAddress!.longitude != null)
            'longitude': _selectedAddress!.longitude,
          'locationType': _selectedAddress!.locationType.name,
        },
        paymentMethod: _selectedPaymentMethod,
        items: cart.items
            .map((item) => CheckoutItem(
                  productId: item.productId,
                  quantity: item.quantity,
                  variantId: item.variantId,
                ))
            .toList(),
        deliveryType: _selectedDeliveryType,
        batchTypeId: targetBatchTypeId,
        coupon: ref.read(promoProvider).appliedCode,
        // The server decides how much the card applies (goods only) — we send the code, never
        // an amount. See trenda_backend/docs/GIFT_CARDS.md §4.
        giftCardCode: ref.read(selectedGiftCardCodeProvider),
      );

      final orderId = await ref
          .read(checkoutProvider.notifier)
          .createCheckout(checkoutData);

      if (orderId != null && mounted) {
        // Only the ticked lines were ordered; the rest stay in the cart.
        final cartNotifier = ref.read(cartProvider.notifier);
        final fullCount = ref.read(cartProvider).value?.items.length ?? 0;
        if (cart.items.length >= fullCount) {
          await cartNotifier.clearCart();
        } else {
          await cartNotifier.removeItems(cart.items.map((i) => i.id));
        }
        ref.read(deselectedCartItemsProvider.notifier).state = const {};
        if (mounted) {
          // A cart from several stores is placed as one order per store, each with its own rider.
          final placedCount = ref.read(checkoutProvider).orderCount;
          context.goNamed('orderConfirmation',
              pathParameters: {'id': orderId},
              queryParameters: placedCount > 1 ? {'parts': '$placedCount'} : const {});
        }
      } else if (mounted) {
        // ✅ Show error message from provider when order creation fails
        final checkoutState = ref.read(checkoutProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(checkoutState.error ?? 'Order failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
