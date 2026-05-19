import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_errors.dart';
import 'dt_skeleton.dart';

/// User-friendly message for common API / parsing failures.
String friendlyErrorMessage(Object error) {
  if (error is DioException) {
    final code = error.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Please sign in again to load this data.';
    }
    if (code == 404) {
      return 'This content is not available right now.';
    }
    if (isConnectionDioError(error)) {
      return "Can't reach the server. Start the API with "
          '`deeptutor serve --port 8001`, then tap Retry.';
    }
    final detail = error.message;
    if (detail != null && detail.trim().isNotEmpty) {
      return detail;
    }
  }

  final s = error.toString();
  if (s.contains('DioException') && s.contains('401')) {
    return 'Please sign in again to load this data.';
  }
  if (error is TypeError ||
      s.contains('TypeError') ||
      s.contains("type 'Null'")) {
    return "We couldn't load this data. Pull to refresh or tap Retry.";
  }
  if (s.contains('SocketException') ||
      s.contains('Connection refused') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable')) {
    return "Can't reach the server. Check that the API is running, then try again.";
  }
  if (s.contains('401') || s.contains('403')) {
    return 'Your session may have expired. Please sign in again.';
  }
  if (s.contains('404')) {
    return 'This content is not available right now.';
  }
  return 'Something went wrong. Please try again.';
}

/// Icon + short message + optional Retry button.
class FriendlyErrorView extends StatelessWidget {
  const FriendlyErrorView({
    super.key,
    this.error,
    this.message,
    this.onRetry,
  });

  final Object? error;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = message ??
        (error != null ? friendlyErrorMessage(error!) : 'Something went wrong.');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: cs.onSurface.withOpacity(0.45),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.75),
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Generic [AsyncValue] renderer that handles loading, error, and data states.
class AsyncValueWidget<T> extends StatelessWidget {
  const AsyncValueWidget({
    super.key,
    required this.value,
    required this.builder,
    this.loadingWidget,
    this.errorBuilder,
    this.onRetry,
    this.skipLoadingOnRefresh = true,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loadingWidget;
  final Widget Function(Object error, StackTrace? stackTrace)? errorBuilder;
  final VoidCallback? onRetry;
  final bool skipLoadingOnRefresh;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      loading: () =>
          loadingWidget ??
          const DtSkeletonList(),
      error: (e, st) =>
          errorBuilder?.call(e, st) ??
          FriendlyErrorView(error: e, onRetry: onRetry),
      data: builder,
    );
  }
}
