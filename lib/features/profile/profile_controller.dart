import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';
import 'profile_repository.dart';
import 'user_profile.dart';

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile>(ProfileController.new);

class ProfileController extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    // Reloads on login, and clears on logout.
    final status = ref.watch(authProvider.select((s) => s.status));
    if (status != AuthStatus.signedIn) return UserProfile.empty;
    return ref.read(profileRepositoryProvider).fetch();
  }

  /// Each of these throws ApiError on failure and leaves the current profile as it was.
  Future<void> save(Map<String, dynamic> fields) async {
    state = AsyncData(await ref.read(profileRepositoryProvider).update(fields));
  }

  Future<void> uploadPhoto(Uint8List bytes, String filename) async {
    state = AsyncData(await ref.read(profileRepositoryProvider).uploadPhoto(bytes, filename));
  }

  Future<void> removePhoto() async {
    state = AsyncData(await ref.read(profileRepositoryProvider).deletePhoto());
  }
}