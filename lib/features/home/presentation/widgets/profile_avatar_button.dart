// lib/features/home/presentation/widgets/profile_avatar_button.dart
// The way into Profile since it left the bottom bar (2026-09-30): the signed-in
// shopper's photo (or initial) in a ring at the top right, beside the
// municipality pill. Signed out it is a plain person glyph — tapping it still
// opens /profile, which shows the sign-in prompt.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/providers.dart';
import '../../../chat/providers/chat_provider.dart';

/// What the avatar needs about the signed-in shopper: (signedIn, photoUrl, name).
/// Its own provider so a widget test can override it without Firebase.
final profileAvatarInfoProvider = Provider<(bool, String, String)>((ref) {
  final user = ref.watch(authNotifierProvider).user;
  return (
    user != null,
    user?.photoURL ?? '',
    (user?.displayName ?? user?.email ?? '').trim(),
  );
});

class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  static const double _size = 36;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final (signedIn, photo, name) = ref.watch(profileAvatarInfoProvider);
    final initial = name.isEmpty ? '' : name.characters.first.toUpperCase();
    // Unread chat messages. Messages lives inside Profile, so the way in carries
    // the count. Not fetched signed out (the endpoint needs a session).
    final unread =
        signedIn ? ref.watch(unreadMessagesCountProvider).valueOrNull ?? 0 : 0;

    final Widget face;
    if (photo.isNotEmpty) {
      face = CachedNetworkImage(
        imageUrl: photo,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _Fallback(initial: initial),
      );
    } else {
      face = _Fallback(initial: initial);
    }

    final avatar = Semantics(
      button: true,
      label: unread > 0 ? 'Profile, $unread unread messages' : 'Profile',
      child: Tooltip(
        message: unread > 0 ? '$unread unread messages' : 'Profile',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push('/profile'),
          child: Container(
            width: _size + 4,
            height: _size + 4,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Signed in: a ring in the brand colour; signed out: a quiet one.
              gradient: signedIn
                  ? LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              border: !signedIn
                  ? Border.all(color: scheme.outlineVariant, width: 1.5)
                  : null,
            ),
            child: ClipOval(
              child: ColoredBox(
                color: scheme.surface,
                child: Padding(
                  padding: EdgeInsets.all(signedIn ? 1.5 : 0),
                  child: ClipOval(child: SizedBox.expand(child: face)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (unread == 0) return avatar;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -4,
          top: -4,
          child: IgnorePointer(child: _UnreadBadge(count: unread)),
        ),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;
  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('profile-unread-badge'),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.error,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: scheme.surface, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: scheme.onError,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String initial;
  const _Fallback({required this.initial});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.primaryContainer,
      child: Center(
        child: initial.isEmpty
            ? Icon(Icons.person_rounded,
                size: 20, color: scheme.onPrimaryContainer)
            : Text(
                initial,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
      ),
    );
  }
}
