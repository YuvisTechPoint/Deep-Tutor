import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] and forwards incoming app/uni links to [router].
///
/// Supported URLs:
///   - `deeptutor://eip/<slug>` → `/eip/<slug>`
///   - `deeptutor://books/<bookId>` → `/books/<bookId>`
///   - `deeptutor://tutorbot/<botId>` → `/tutorbot/<botId>`
///   - HTTPS variants on `deeptutor.app` paths.
class DeepLinkListener extends StatefulWidget {
  const DeepLinkListener({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<DeepLinkListener> createState() => _DeepLinkListenerState();
}

class _DeepLinkListenerState extends State<DeepLinkListener> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  @override
  void initState() {
    super.initState();
    _initial();
    _sub = _appLinks.uriLinkStream.listen(_handle);
  }

  Future<void> _initial() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (_) {}
  }

  void _handle(Uri uri) {
    if (uri.pathSegments.isEmpty) return;
    final segs = uri.pathSegments;
    final first = segs.first;
    if (first == 'eip' && segs.length >= 2) {
      widget.router.go('/eip/${segs[1]}');
    } else if (first == 'books' && segs.length >= 2) {
      widget.router.go('/books/${segs[1]}');
    } else if (first == 'tutorbot' && segs.length >= 2) {
      widget.router.go('/tutorbot/${segs[1]}');
    } else if (first == 'chat' && segs.length >= 2) {
      widget.router.go('/chat/${segs[1]}');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
