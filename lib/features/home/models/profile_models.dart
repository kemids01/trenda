// lib/features/home/models/profile_models.dart
import '../../home/models/user_address.dart';

class ProfilePreferences {
  final bool darkTheme;
  final bool pushNotifications;

  const ProfilePreferences({
    this.darkTheme = false,
    this.pushNotifications = true,
  });

  factory ProfilePreferences.fromJson(Map<String, dynamic> json) {
    return ProfilePreferences(
      darkTheme: json['darkTheme'] as bool? ?? false,
      pushNotifications: json['pushNotifications'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'darkTheme': darkTheme,
        'pushNotifications': pushNotifications,
      };

  ProfilePreferences copyWith({
    bool? darkTheme,
    bool? pushNotifications,
  }) {
    return ProfilePreferences(
      darkTheme: darkTheme ?? this.darkTheme,
      pushNotifications: pushNotifications ?? this.pushNotifications,
    );
  }
}

class UserProfileState {
  final String? displayName;
  final String? photoURL;
  final String? email;
  final String? phone;

  // ✅ Personal Information
  final String? firstName;
  final String? middleName;
  final String? surname;
  final DateTime? birthday;
  final String? gender; // 'male', 'female', 'other', 'prefer_not_to_say'

  final ProfilePreferences preferences;
  final List<UserAddress> addresses;
  final String? errorMsg;
  final bool isLoadingPhoto;

  const UserProfileState({
    this.displayName,
    this.photoURL,
    this.email,
    this.phone,
    this.firstName,
    this.middleName,
    this.surname,
    this.birthday,
    this.gender,
    this.preferences = const ProfilePreferences(),
    this.addresses = const [],
    this.errorMsg,
    this.isLoadingPhoto = false,
  });

  /// Full name composed from first, middle, surname
  String get fullName {
    final parts = [firstName, middleName, surname]
        .where((p) => p != null && p.isNotEmpty)
        .toList();
    return parts.isEmpty ? displayName ?? 'New User' : parts.join(' ');
  }

  /// Age calculated from birthday
  int? get age {
    if (birthday == null) return null;
    final now = DateTime.now();
    int years = now.year - birthday!.year;
    if (now.month < birthday!.month ||
        (now.month == birthday!.month && now.day < birthday!.day)) {
      years--;
    }
    return years;
  }

  factory UserProfileState.initial() => const UserProfileState();

  UserProfileState copyWith({
    String? displayName,
    String? photoURL,
    String? email,
    String? phone,
    String? firstName,
    String? middleName,
    String? surname,
    DateTime? birthday,
    String? gender,
    ProfilePreferences? preferences,
    List<UserAddress>? addresses,
    String? errorMsg,
    bool? isLoadingPhoto,
  }) {
    return UserProfileState(
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      surname: surname ?? this.surname,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      preferences: preferences ?? this.preferences,
      addresses: addresses ?? this.addresses,
      errorMsg: errorMsg ?? this.errorMsg,
      isLoadingPhoto: isLoadingPhoto ?? this.isLoadingPhoto,
    );
  }
}
