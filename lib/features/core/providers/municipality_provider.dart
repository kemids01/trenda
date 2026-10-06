import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trenda_shared/trenda_shared.dart';

/// Resolves the initial browsing municipality from persisted prefs.
/// Saved selection wins; else the registered home municipality; else null
/// (the UI prompts the user to pick). No hardcoded default (coding rule #3).
String? resolveInitialMunicipality(SharedPreferences prefs) {
  return prefs.getString('selected_municipality') ??
      prefs.getString('home_municipality');
}

/// Municipality preference provider
/// Stores user's selected municipality for filtering products/ads
class MunicipalityNotifier extends StateNotifier<String?> {
  static const String _key = 'selected_municipality';

  MunicipalityNotifier() : super(null) {
    _loadMunicipality();
  }

  Future<void> _loadMunicipality() async {
    final prefs = await SharedPreferences.getInstance();
    state = resolveInitialMunicipality(prefs);
  }

  Future<void> setMunicipality(String? municipality) async {
    final prefs = await SharedPreferences.getInstance();
    if (municipality == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, municipality);
    }
    state = municipality;
  }

  Future<void> clearMunicipality() async {
    await setMunicipality(null);
  }
}

final municipalityProvider =
    StateNotifierProvider<MunicipalityNotifier, String?>((ref) {
  return MunicipalityNotifier();
});

final municipalityRepositoryProvider = Provider<MunicipalityRepository>((ref) {
  return MunicipalityRepository(baseUrl: AppConfig.backendBaseUrl);
});

final availableMunicipalitiesProvider =
    FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(municipalityRepositoryProvider);
  final municipalities = await repo.getMunicipalities(); // fetch all active
  return municipalities.map((m) => m.name).toList()..sort();
});

/// Home municipality — the user's registered address municipality.
/// This is set once during registration/address setup and does not change
/// when the user switches browsing municipalities.
class HomeMunicipalityNotifier extends StateNotifier<String?> {
  static const String _key = 'home_municipality';

  HomeMunicipalityNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_key);
  }

  Future<void> setHomeMunicipality(String municipality) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, municipality);
    state = municipality;
  }
}

final homeMunicipalityProvider =
    StateNotifierProvider<HomeMunicipalityNotifier, String?>((ref) {
  return HomeMunicipalityNotifier();
});

/// Whether the user is browsing a municipality different from their home.
final isBrowsingOtherMunicipalityProvider = Provider<bool>((ref) {
  final home = ref.watch(homeMunicipalityProvider);
  final browsing = ref.watch(municipalityProvider);
  if (home == null || browsing == null) return false;
  return home.toLowerCase() != browsing.toLowerCase();
});

/// Whether the user can place orders (only allowed in home municipality).
final canOrderProvider = Provider<bool>((ref) {
  return !ref.watch(isBrowsingOtherMunicipalityProvider);
});

