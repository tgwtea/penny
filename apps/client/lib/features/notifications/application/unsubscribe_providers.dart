import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/unsubscribe.dart';

/// The unsubscribe repository in use, set by the composition root.
final unsubscribeRepositoryProvider = Provider<UnsubscribeRepository>(
  (ref) => throw UnimplementedError(
    'unsubscribeRepositoryProvider is set by backendOverrides()',
  ),
);

/// What an unsubscribe link would stop.
final unsubscribeLinkProvider = FutureProvider.family<UnsubscribeLink, String>(
  (ref, token) => ref.watch(unsubscribeRepositoryProvider).describe(token),
  retry: (_, _) => null,
);
