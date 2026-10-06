// lib/features/home/application/user_profile_notifier.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trenda_frontend/features/auth/application/state.dart';
import 'package:trenda_frontend/features/auth/data/providers.dart';
import 'package:trenda_shared/core/logger.dart';
import 'package:trenda_shared/core/config.dart';
import 'package:trenda_shared/core/images/picked_image.dart';
import '../models/profile_models.dart';
import '../../home/models/user_address.dart';
import '../../backend/api_service.dart';
import '../utils/profile_photo.dart';

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfileState>(
        () => UserProfileNotifier());

class UserProfileNotifier extends AsyncNotifier<UserProfileState> {
  late final ApiService api;

  @override
  Future<UserProfileState> build() async {
    api = ApiService('${AppConfig.backendBaseUrl}/api');

    // Listen to AuthNotifier changes - only react to actual user changes
    ref.listen<AuthState>(authNotifierProvider, (previous, next) async {
      final prevUid = previous?.user?.uid;
      final nextUid = next.user?.uid;

      // Only react if user actually changed (login/logout)
      if (prevUid != nextUid) {
        if (next.user != null) {
          await syncUser(next.user!);
          await reloadProfile(); // update profile when user logs in
        } else {
          reset(); // reset if logged out
        }
      }
    });

    // Wait for Firebase auth to restore after hot restart
    User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      debugPrint('📱 No immediate user, waiting for Firebase auth...');
      // Wait a bit for Firebase to restore auth state
      for (int i = 0; i < 10; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) break;
      }
    }

    if (currentUser != null) {
      debugPrint('📱 Found Firebase user: ${currentUser.uid}');
      await syncUser(currentUser);
      return await _loadUserProfile(currentUser);
    }

    // Fallback: check authNotifierProvider
    final authUser = ref.read(authNotifierProvider).user;
    if (authUser != null) {
      debugPrint('📱 Found auth user from provider: ${authUser.uid}');
      await syncUser(authUser);
      return await _loadUserProfile(authUser);
    }

    debugPrint('📱 No user found, returning initial state');
    return UserProfileState.initial();
  }

  /// ---------------- WAIT FOR FIREBASE USER ----------------
  Future<User?> _waitForFirebase() async {
    int attempts = 0;
    User? user = FirebaseAuth.instance.currentUser;
    while (user == null && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 200));
      user = FirebaseAuth.instance.currentUser;
      attempts++;
    }
    return user;
  }

  /// ---------------- RELOAD PROFILE ----------------
  bool _profileLoadInProgress = false;
  DateTime? _lastProfileLoadTime;

  Future<void> reloadProfile() async {
    // Debounce: skip if recently loaded (within 5 seconds)
    if (_lastProfileLoadTime != null) {
      final elapsed = DateTime.now().difference(_lastProfileLoadTime!);
      if (elapsed.inSeconds < 5) {
        if (kDebugMode)
          AppLogger.debug('Profile load skipped (debounced)', 'Profile');
        return;
      }
    }

    // Lock: skip if already loading
    if (_profileLoadInProgress) {
      if (kDebugMode)
        AppLogger.debug('Profile load skipped (in progress)', 'Profile');
      return;
    }

    final user = await _waitForFirebase();
    if (user == null) return;

    _profileLoadInProgress = true;
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _loadUserProfile(user));
      _lastProfileLoadTime = DateTime.now();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    } finally {
      _profileLoadInProgress = false;
    }
  }

  /// ---------------- LOAD USER PROFILE ----------------
  Future<UserProfileState> _loadUserProfile(User user) async {
    final data = await api.getUser(user.uid);
    if (data == null) return UserProfileState.initial();

    final addresses = (data['addresses'] as List? ?? [])
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();

    // Parse birthday if present
    DateTime? birthday;
    if (data['birthday'] != null) {
      try {
        birthday = DateTime.parse(data['birthday'] as String);
      } catch (_) {}
    }

    return UserProfileState(
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      photoURL: storedPhotoUrl(data),
      firstName: data['firstName'] as String?,
      middleName: data['middleName'] as String?,
      surname: data['surname'] as String?,
      birthday: birthday,
      gender: data['gender'] as String?,
      preferences: ProfilePreferences.fromJson(data['preferences'] ?? {}),
      addresses: addresses,
    );
  }

  /// ---------------- DISPLAY NAME ----------------
  Future<void> updateDisplayName(String newName) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldName = state.value!.displayName;
    state = AsyncValue.data(state.value!.copyWith(displayName: newName));

    final success = await api.updateUser(user.uid, {'displayName': newName});
    if (!success)
      state = AsyncValue.data(state.value!.copyWith(displayName: oldName));
  }

  /// ---------------- EMAIL ----------------
  Future<void> updateEmail(String newEmail) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldEmail = state.value!.email;
    state = AsyncValue.data(state.value!.copyWith(email: newEmail));

    try {
      // Update in Firebase Auth - requires verification first
      await user.verifyBeforeUpdateEmail(newEmail);

      // Update in backend
      final success = await api.updateUser(user.uid, {'email': newEmail});
      if (!success)
        state = AsyncValue.data(state.value!.copyWith(email: oldEmail));
    } on FirebaseAuthException catch (e) {
      if (kDebugMode)
        AppLogger.debug(
            'FirebaseAuth updateEmail error: ${e.message}', 'Profile');
      state = AsyncValue.data(state.value!.copyWith(email: oldEmail));
      rethrow; // allow UI to catch and show error
    } catch (e) {
      if (kDebugMode) AppLogger.debug('updateEmail error: $e', 'Profile');
      state = AsyncValue.data(state.value!.copyWith(email: oldEmail));
      rethrow;
    }
  }

  /// ---------------- PHONE ----------------
  /// True when the server saved it; on false the old number is restored, so a
  /// caller must not report success.
  Future<bool> updatePhone(String newPhone) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return false;

    final oldPhone = state.value!.phone;
    state = AsyncValue.data(state.value!.copyWith(phone: newPhone));

    final success = await api.updateUser(user.uid, {'phone': newPhone});
    if (!success) {
      state = AsyncValue.data(state.value!.copyWith(phone: oldPhone));
    }
    return success;
  }

  /// ---------------- PERSONAL INFO ----------------
  Future<void> updatePersonalInfo({
    String? firstName,
    String? middleName,
    String? surname,
    DateTime? birthday,
    String? gender,
  }) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldState = state.value!;
    state = AsyncValue.data(oldState.copyWith(
      firstName: firstName ?? oldState.firstName,
      middleName: middleName ?? oldState.middleName,
      surname: surname ?? oldState.surname,
      birthday: birthday ?? oldState.birthday,
      gender: gender ?? oldState.gender,
    ));

    final data = <String, dynamic>{};
    if (firstName != null) data['firstName'] = firstName;
    if (middleName != null) data['middleName'] = middleName;
    if (surname != null) data['surname'] = surname;
    if (birthday != null) data['birthday'] = birthday.toIso8601String();
    if (gender != null) data['gender'] = gender;

    final success = await api.updateUser(user.uid, data);
    if (!success) {
      state = AsyncValue.data(oldState);
    }
  }

  /// ---------------- PREFERENCES ----------------
  Future<void> updatePreferences(ProfilePreferences prefs) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldPrefs = state.value!.preferences;
    state = AsyncValue.data(state.value!.copyWith(preferences: prefs));

    final success = await api.updatePreferences(user.uid, prefs.toJson());
    if (!success)
      state = AsyncValue.data(state.value!.copyWith(preferences: oldPrefs));
  }

  /// ---------------- PHOTO ----------------
  /// ---------------- PHOTO ----------------
  Future<void> updatePhoto(PickedImage picked) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldPhoto = state.value!.photoURL;

    // Set loading state
    state = AsyncValue.data(
      state.value!.copyWith(isLoadingPhoto: true),
    );

    try {
      final url = await api.uploadPhotoAndGetUrl(user.uid, picked);

      if (url != null && url.isNotEmpty) {
        // Update state with new photo
        state = AsyncValue.data(
          state.value!.copyWith(photoURL: url, isLoadingPhoto: false),
        );

        // Sync with Firebase Auth
        try {
          await user.updatePhotoURL(url);
        } on FirebaseAuthException catch (e) {
          if (kDebugMode)
            AppLogger.debug(
                'FirebaseAuth updatePhotoURL failed: ${e.message}', 'Profile');
        }
      } else {
        // Restore old photo if upload failed
        state = AsyncValue.data(
          state.value!.copyWith(photoURL: oldPhoto, isLoadingPhoto: false),
        );
      }
    } catch (e) {
      // Restore old photo on exception
      state = AsyncValue.data(
        state.value!.copyWith(photoURL: oldPhoto, isLoadingPhoto: false),
      );
      if (kDebugMode) AppLogger.debug('updatePhoto error: $e', 'Profile');
    }
  }

  /// ---------------- ADDRESS CRUD ----------------
  Future<void> addOrUpdateAddress(UserAddress addr,
      {bool isUpdate = false}) async {
    debugPrint(
        '📍 addOrUpdateAddress called: isUpdate=$isUpdate, addr=${addr.toJson()}');

    final user = await _waitForFirebase();
    if (user == null || state.value == null) {
      debugPrint('❌ addOrUpdateAddress: user or state is null');
      return;
    }

    final oldList = state.value!.addresses;
    final newList = isUpdate
        ? oldList.map((a) => a.id == addr.id ? addr : a).toList()
        : [...oldList, addr];

    state = AsyncValue.data(state.value!.copyWith(addresses: newList));
    debugPrint('📍 Optimistic update: ${newList.length} addresses');

    final success = await api.addOrUpdateAddress(user.uid, addr.toJson(),
        isUpdate: isUpdate);
    debugPrint('📍 API save result: success=$success');

    if (!success) {
      debugPrint('❌ Reverting to old list');
      state = AsyncValue.data(state.value!.copyWith(addresses: oldList));
    }
  }

  Future<void> deleteAddress(String id) async {
    final user = await _waitForFirebase();
    if (user == null || state.value == null) return;

    final oldList = state.value!.addresses;
    state = AsyncValue.data(state.value!
        .copyWith(addresses: oldList.where((a) => a.id != id).toList()));

    final success = await api.deleteAddress(user.uid, id);
    if (!success)
      state = AsyncValue.data(state.value!.copyWith(addresses: oldList));
  }

  /// ---------------- AUTOMATIC USER SYNC ----------------
  /// Track if sync is in progress to prevent duplicate calls
  bool _syncInProgress = false;
  String? _lastSyncedUid;
  DateTime? _lastSyncTime;

  /// Public method to allow external notifiers (like AuthNotifier) to sync users
  /// Debounced to prevent rate limiting
  Future<void> syncUser(User user) async {
    // Debounce: skip if recently synced (within 5 seconds)
    if (_lastSyncedUid == user.uid && _lastSyncTime != null) {
      final elapsed = DateTime.now().difference(_lastSyncTime!);
      if (elapsed.inSeconds < 5) {
        if (kDebugMode)
          AppLogger.debug('Sync skipped (debounced): ${user.uid}', 'Profile');
        return;
      }
    }

    // Lock: skip if already syncing
    if (_syncInProgress) {
      if (kDebugMode)
        AppLogger.debug('Sync skipped (in progress): ${user.uid}', 'Profile');
      return;
    }

    _syncInProgress = true;

    try {
      final email = user.email ?? '';
      final displayName = user.displayName ?? 'New User';
      // No placeholder: a stock avatar saved here would count as a real photo.
      final photoURL = user.photoURL;

      await api.syncUser(
        uid: user.uid,
        email: email,
        displayName: displayName,
        photoURL: photoURL,
      );

      _lastSyncedUid = user.uid;
      _lastSyncTime = DateTime.now();

      if (kDebugMode) AppLogger.debug('User synced: ${user.uid}', 'Profile');
    } catch (e) {
      if (kDebugMode) AppLogger.debug('Failed to sync user: $e', 'Profile');
    } finally {
      _syncInProgress = false;
    }
  }

  /// ------------------- RESET STATE -------------------
  void reset() {
    _lastSyncedUid = null;
    _lastSyncTime = null;
    state = AsyncValue.data(UserProfileState.initial());
  }
}
