//lib/features/home/application/profile_action_notifier.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trenda_frontend/features/home/application/user_profile_notifier.dart';
import 'package:trenda_frontend/features/home/models/user_address.dart';

/// -------------------- ACTION KEYS --------------------
enum ActionKey { photo, password, phone, google, addressAdd, addressEdit }

@immutable
class ProfileActionState {
  final bool isLoadingPhoto;
  final bool isLoadingPassword;
  final bool isLoadingPhone;
  final bool isLoadingGoogle;
  final Set<String> loadingAddresses;

  const ProfileActionState({
    this.isLoadingPhoto = false,
    this.isLoadingPassword = false,
    this.isLoadingPhone = false,
    this.isLoadingGoogle = false,
    this.loadingAddresses = const {},
  });

  ProfileActionState copyWith({
    bool? isLoadingPhoto,
    bool? isLoadingPassword,
    bool? isLoadingPhone,
    bool? isLoadingGoogle,
    Set<String>? loadingAddresses,
  }) {
    return ProfileActionState(
      isLoadingPhoto: isLoadingPhoto ?? this.isLoadingPhoto,
      isLoadingPassword: isLoadingPassword ?? this.isLoadingPassword,
      isLoadingPhone: isLoadingPhone ?? this.isLoadingPhone,
      isLoadingGoogle: isLoadingGoogle ?? this.isLoadingGoogle,
      loadingAddresses: loadingAddresses ?? this.loadingAddresses,
    );
  }
}

/// -------------------- NOTIFIER --------------------
class ProfileActionNotifier extends StateNotifier<ProfileActionState> {
  final Ref ref;

  ProfileActionNotifier(this.ref) : super(const ProfileActionState());

  /// -------------------- ADDRESS LOADING --------------------
  void setAddressLoading(String id, bool value) {
    final updated = Set<String>.from(state.loadingAddresses);
    value ? updated.add(id) : updated.remove(id);
    state = state.copyWith(loadingAddresses: updated);
  }

  bool isAddressLoading(String id) => state.loadingAddresses.contains(id);

  /// -------------------- SAFE ACTION WRAPPER --------------------
  Future<void> safeAction({
    required ActionKey key,
    required BuildContext context,
    required Future<void> Function() action,
  }) async {
    bool isLoading = _getLoading(key);
    if (isLoading) return;

    _setLoading(key, true);
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      _setLoading(key, false);
    }
  }

  bool _getLoading(ActionKey key) {
    switch (key) {
      case ActionKey.photo:
        return state.isLoadingPhoto;
      case ActionKey.password:
        return state.isLoadingPassword;
      case ActionKey.phone:
        return state.isLoadingPhone;
      case ActionKey.google:
        return state.isLoadingGoogle;
      case ActionKey.addressAdd:
      case ActionKey.addressEdit:
        return false; // per-address handled separately
    }
  }

  void _setLoading(ActionKey key, bool value) {
    switch (key) {
      case ActionKey.photo:
        state = state.copyWith(isLoadingPhoto: value);
        break;
      case ActionKey.password:
        state = state.copyWith(isLoadingPassword: value);
        break;
      case ActionKey.phone:
        state = state.copyWith(isLoadingPhone: value);
        break;
      case ActionKey.google:
        state = state.copyWith(isLoadingGoogle: value);
        break;
      case ActionKey.addressAdd:
      case ActionKey.addressEdit:
        // nothing, handled per address
        break;
    }
  }

  /// -------------------- ADDRESS CRUD --------------------
  Future<void> addOrUpdateAddress(
    UserAddress addr, {
    bool isUpdate = false,
    BuildContext? context,
  }) async {
    final userNotifier = ref.read(userProfileProvider.notifier);
    setAddressLoading(addr.id, true);

    try {
      await userNotifier.addOrUpdateAddress(addr, isUpdate: isUpdate);

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(isUpdate ? 'Address updated ✅' : 'Address added ✅')),
        );
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setAddressLoading(addr.id, false);
    }
  }

  Future<void> deleteAddress(UserAddress addr, {BuildContext? context}) async {
    final userNotifier = ref.read(userProfileProvider.notifier);
    setAddressLoading(addr.id, true);

    try {
      await userNotifier.deleteAddress(addr.id);

      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Address deleted ✅')));
      }
    } catch (e) {
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setAddressLoading(addr.id, false);
    }
  }

  /// -------------------- RESET --------------------
  void reset() => state = const ProfileActionState();
}

/// -------------------- PROVIDER --------------------
final profileActionProvider =
    StateNotifierProvider<ProfileActionNotifier, ProfileActionState>(
  (ref) => ProfileActionNotifier(ref),
);
