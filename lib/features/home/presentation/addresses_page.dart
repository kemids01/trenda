// lib/features/home/presentation/addresses_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_shared/widgets/municipality_dropdown.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import '../models/user_address.dart';
import '../application/user_profile_notifier.dart';
import '../../../design_system/design_system.dart';
import 'map_picker_page.dart';
import '../../core/providers/location_providers.dart';
import 'package:trenda_shared/core/taps/taps.dart';

class AddressesPage extends ConsumerWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Addresses'),
      ),
      body: profileAsync.when(
        data: (profile) {
          final addresses = profile.addresses;

          if (addresses.isEmpty) {
            return _buildEmptyState(context, ref);
          }

          return ListView.separated(
            padding: AppSpacing.paddingMD,
            itemCount: addresses.length,
            separatorBuilder: (_, __) => AppSpacing.verticalSM,
            itemBuilder: (context, index) {
              return AddressCard(
                address: addresses[index],
                onEdit: () =>
                    _showAddressDialog(context, ref, addresses[index]),
                onDelete: () => _confirmDelete(context, ref, addresses[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 80,
            color: AppColors.textTertiary,
          ),
          AppSpacing.verticalMD,
          Text(
            'No addresses saved',
            style: AppTypography.titleLarge,
          ),
          AppSpacing.verticalXS,
          Text(
            'Add your delivery addresses for faster checkout',
            style: AppTypography.asSecondary(AppTypography.bodyMedium),
            textAlign: TextAlign.center,
          ),
          AppSpacing.verticalLG,
          ElevatedButton.icon(
            onPressed: () => _showAddressDialog(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
          ),
        ],
      ),
    );
  }

  void _showAddressDialog(
      BuildContext context, WidgetRef ref, UserAddress? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => AddressForm(
        existingAddress: existing,
        onSave: (address) async {
          final notifier = ref.read(userProfileProvider.notifier);
          await notifier.addOrUpdateAddress(address,
              isUpdate: existing != null);
          if (ctx.mounted) {
            Navigator.pop(ctx);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    existing != null ? 'Address updated' : 'Address added'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, UserAddress address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Remove "${address.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => TapGuard.run('addresses.delete@128', () async {
              Navigator.pop(ctx);
              await ref
                  .read(userProfileProvider.notifier)
                  .deleteAddress(address.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Address deleted')),
                );
              }
            }),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Address card widget
class AddressCard extends StatelessWidget {
  final UserAddress address;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const AddressCard({
    super.key,
    required this.address,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingCard,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: AppSpacing.paddingButtonSmall,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: AppSpacing.borderRadiusSM,
                  ),
                  child: Text(
                    address.label,
                    style: AppTypography.withColor(
                      AppTypography.labelMedium,
                      AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: onEdit,
                  iconSize: 20,
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: onDelete,
                  iconSize: 20,
                ),
              ],
            ),
            AppSpacing.verticalSM,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on,
                    size: 18, color: AppColors.textSecondary),
                AppSpacing.horizontalXS,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [
                          address.houseNumber != null
                              ? '#${address.houseNumber} '
                              : '',
                          address.street,
                          address.barangay != null
                              ? ', Brgy. ${address.barangay}'
                              : '',
                        ].join(''),
                        style: AppTypography.bodyMedium
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${address.city}, ${address.province ?? address.region}',
                        style: AppTypography.bodyMedium,
                      ),
                      Text(
                        '${address.country}, ${address.postalCode}',
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                      if (address.landmark != null &&
                          address.landmark!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Landmark: ${address.landmark}',
                            style: AppTypography.bodySmall
                                .copyWith(fontStyle: FontStyle.italic),
                          ),
                        ),
                      if (address.additionalInfo != null &&
                          address.additionalInfo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Note: ${address.additionalInfo}',
                            style: AppTypography.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      // ✅ GPS/Map Location Indicator
                      if (address.latitude != null && address.longitude != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: address.locationType == LocationType.gps
                                  ? Colors.green.shade50
                                  : address.locationType == LocationType.map
                                      ? Colors.blue.shade50
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: address.locationType == LocationType.gps
                                    ? Colors.green.shade300
                                    : address.locationType == LocationType.map
                                        ? Colors.blue.shade300
                                        : Colors.grey.shade300,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  address.locationType == LocationType.gps
                                      ? Icons.gps_fixed
                                      : address.locationType == LocationType.map
                                          ? Icons.pin_drop
                                          : Icons.edit_location_alt,
                                  size: 14,
                                  color: address.locationType ==
                                          LocationType.gps
                                      ? Colors.green.shade700
                                      : address.locationType == LocationType.map
                                          ? Colors.blue.shade700
                                          : Colors.grey.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  address.locationType == LocationType.gps
                                      ? 'GPS Location'
                                      : address.locationType == LocationType.map
                                          ? 'Map Pin'
                                          : 'Manual',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        address.locationType == LocationType.gps
                                            ? Colors.green.shade700
                                            : address.locationType ==
                                                    LocationType.map
                                                ? Colors.blue.shade700
                                                : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.check_circle,
                                    size: 12, color: Colors.green),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Address form bottom sheet
class AddressForm extends ConsumerStatefulWidget {
  final UserAddress? existingAddress;
  final Future<void> Function(UserAddress) onSave;

  const AddressForm({
    super.key,
    this.existingAddress,
    required this.onSave,
  });

  @override
  ConsumerState<AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<AddressForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Initialize form state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.existingAddress != null) {
        ref
            .read(addressFormProvider.notifier)
            .loadAddress(widget.existingAddress!);
      } else {
        // Try to load default from profile if needed, or just reset
        ref.read(addressFormProvider.notifier).reset();
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final formState = ref.read(addressFormProvider);
    if (!formState.isValid) {
      String errorMsg = 'Please fill all required fields';
      if (formState.latitude == null || formState.longitude == null) {
        errorMsg =
            'Please set your GPS location using "Detect GPS" or "Pick on Map"';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final address = formState.toUserAddress(
        widget.existingAddress?.id ?? const Uuid().v4(),
      );
      await widget.onSave(address);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  bool _isDetectingLocation = false;

  Future<void> _detectCurrentLocation(AddressFormNotifier notifier) async {
    setState(() => _isDetectingLocation = true);

    try {
      // Check and request location permission
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
        if (requested == LocationPermission.deniedForever) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission permanently denied. '
                    'Please enable in settings.'),
              ),
            );
          }
          return;
        }
      }

      // Get current GPS position directly
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );

      // ✅ FIXED: Directly set coordinates and locationType without opening map picker
      notifier.updateCoordinates(position.latitude, position.longitude);
      notifier.setLocationType(LocationType.gps);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.gps_fixed, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'GPS: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _openMapPicker() async {
    final formState = ref.read(addressFormProvider);
    final notifier = ref.read(addressFormProvider.notifier);

    // Construct search query based on current form values
    String query = '';
    if (formState.barangay != null && formState.cityMunicipality != null) {
      query = 'Brgy. ${formState.barangay}, ${formState.cityMunicipality}';
    } else if (formState.cityMunicipality != null) {
      query = '${formState.cityMunicipality}';
    }

    final result = await Navigator.push<MapPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerPage(
          initialQuery: query.isNotEmpty ? query : null,
        ),
      ),
    );

    if (result != null && mounted) {
      // ✅ Populate form fields from map picker result

      // Update street field with street from map or full address
      if (result.street != null && result.street!.isNotEmpty) {
        notifier.updateStreet(result.street!);
      }

      // Update coordinates
      notifier.updateCoordinates(
        result.location.latitude,
        result.location.longitude,
      );

      // ✅ Set location type to map (user pinned on map)
      notifier.setLocationType(LocationType.map);

      // Show confirmation with detected location details
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📍 Location selected!',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                result.address,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (result.region != null || result.city != null)
                Text(
                  '${result.city ?? ''}, ${result.region ?? ''}',
                  style: const TextStyle(fontSize: 11),
                ),
            ],
          ),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green.shade700,
        ),
      );

      // Show helper text if location dropdowns don't match
      if (result.city != null && result.city != formState.cityMunicipality) {
        // Suggest updating the city dropdown to match
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tip: Update Municipality to "${result.city}" for accuracy',
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildLocationActions(
      BuildContext context, AddressFormNotifier notifier) {
    final formState = ref.watch(addressFormProvider);
    final hasCoordinates =
        formState.latitude != null && formState.longitude != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppSpacing.borderRadiusMD,
        border:
            Border.all(color: hasCoordinates ? Colors.green : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on,
                  color: hasCoordinates ? Colors.green : AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCoordinates
                      ? 'GPS Location Set ✓'
                      : 'GPS Location Required *',
                  style: AppTypography.labelLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasCoordinates ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isDetectingLocation
                      ? null
                      : () => _detectCurrentLocation(notifier),
                  icon: _isDetectingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: Text(_isDetectingLocation
                      ? 'Detecting...'
                      : 'Use My Location'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openMapPicker,
                  icon: const Icon(Icons.map),
                  label: const Text('Pin on Map'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          // Show captured coordinates
          if (hasCoordinates) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: AppSpacing.borderRadiusSM,
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_fixed, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lat: ${formState.latitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Lng: ${formState.longitude!.toStringAsFixed(6)}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formState.locationType.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(addressFormProvider);
    final notifier = ref.read(addressFormProvider.notifier);

    final regionsAsync = ref.watch(regionsProvider);
    final provincesAsync = ref.watch(provincesProvider(formState.region));
    final barangaysAsync =
        ref.watch(barangaysProvider(formState.cityMunicipality));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: AppSpacing.paddingPage,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderDark,
                      borderRadius: AppSpacing.borderRadiusFull,
                    ),
                  ),
                ),
                AppSpacing.verticalMD,
                Text(
                  widget.existingAddress != null
                      ? 'Edit Address'
                      : 'Add Address',
                  style: AppTypography.headlineSmall,
                ),
                AppSpacing.verticalMD,

                // ✅ Location Quick Actions - Always visible at top
                _buildLocationActions(context, notifier),
                AppSpacing.verticalLG,

                // Label
                TextFormField(
                  initialValue: formState.label,
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    hintText: 'e.g., Home, Office',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  onChanged: notifier.setLabel,
                  validator: (v) => v?.isEmpty == true ? 'Required' : null,
                ),
                AppSpacing.verticalMD,

                // --- Location Dropdowns ---

                // Region
                regionsAsync.when(
                  data: (regions) {
                    if (regions.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber,
                                color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No regions available. Please seed the database with PSGC data.',
                                style: TextStyle(color: Colors.orange[800]),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return DropdownButtonFormField<String>(
                      value: formState.region,
                      decoration: const InputDecoration(
                        labelText: 'Region',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                      items: regions
                          .map((r) => DropdownMenuItem(
                                value: r.name,
                                child: Text(r.name,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          val != null ? notifier.setRegion(val) : null,
                      validator: (v) => v == null ? 'Required' : null,
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (err, _) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red),
                    ),
                    child: Text('Failed to load regions: $err',
                        style: const TextStyle(color: Colors.red)),
                  ),
                ),
                AppSpacing.verticalSM,

                // Province
                if (formState.region != null)
                  provincesAsync.when(
                    data: (provinces) => DropdownButtonFormField<String>(
                      value: formState.province,
                      decoration: const InputDecoration(
                        labelText: 'Province',
                        prefixIcon: Icon(Icons.landscape_outlined),
                      ),
                      items: provinces
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          val != null ? notifier.setProvince(val) : null,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Failed to load provinces'),
                  ),
                AppSpacing.verticalSM,

                // City/Municipality — deliverable list (served ∪ neighbour towns), so a
                // customer living just outside a served city can still pick their address.
                if (formState.province != null)
                  MunicipalityDropdown(
                    value: formState.cityMunicipality,
                    isRequired: true,
                    items: ref.watch(deliverableMunicipalitiesProvider).valueOrNull,
                    onChanged: (val) {
                      if (val != null) notifier.setCityMunicipality(val);
                    },
                  ),
                AppSpacing.verticalSM,

                // Barangay
                if (formState.cityMunicipality != null)
                  barangaysAsync.when(
                    data: (barangays) => DropdownButtonFormField<String>(
                      value: formState.barangay,
                      decoration: const InputDecoration(
                        labelText: 'Barangay',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      items: barangays
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                      onChanged: (val) =>
                          val != null ? notifier.setBarangay(val) : null,
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('Failed to load barangays'),
                  ),
                AppSpacing.verticalMD,

                // --- Detailed Fields ---
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        initialValue: formState.houseNumber,
                        decoration: const InputDecoration(
                          labelText: 'House No.',
                          hintText: '#123',
                        ),
                        onChanged: notifier.setHouseNumber,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    AppSpacing.horizontalMD,
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: formState.street,
                        decoration: const InputDecoration(
                          labelText: 'Street Name',
                          hintText: 'Main St.',
                        ),
                        onChanged: notifier.setStreet,
                        validator: (v) =>
                            v?.isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                AppSpacing.verticalSM,

                TextFormField(
                  initialValue: formState.landmark,
                  decoration: const InputDecoration(
                    labelText: 'Landmark (Optional)',
                    hintText: 'Near the blue gate',
                    prefixIcon: Icon(Icons.flag_outlined),
                  ),
                  onChanged: notifier.setLandmark,
                ),
                AppSpacing.verticalSM,

                TextFormField(
                  initialValue: formState.additionalInfo,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Instructions',
                    hintText: 'Leave at the front desk',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  maxLines: 2,
                  onChanged: notifier.setAdditionalInfo,
                ),
                AppSpacing.verticalSM,

                // Postal
                TextFormField(
                  initialValue: formState.postalCode,
                  decoration: const InputDecoration(
                    labelText: 'Postal Code',
                    prefixIcon: Icon(Icons.markunread_mailbox_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: notifier.setPostalCode,
                ),

                AppSpacing.verticalXL,

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      padding: AppSpacing.paddingButton,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            widget.existingAddress != null
                                ? 'Update Address'
                                : 'Save Address',
                            style: AppTypography.labelLarge,
                          ),
                  ),
                ),
                AppSpacing.verticalMD,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
