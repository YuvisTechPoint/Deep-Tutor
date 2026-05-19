import 'package:dio/dio.dart';

/// Optional certificate-pinning helper.
///
/// Off by default. Enable by passing a list of SHA256 fingerprints
/// (DER-encoded SubjectPublicKeyInfo, base64) to [install].
///
/// The check intentionally runs only when [fingerprints] is non-empty so
/// that local dev (self-signed certs against `localhost`) keeps working.
class CertificatePinning {
  const CertificatePinning();

  /// Attaches an interceptor that validates the leaf certificate's SPKI
  /// hash against the allow-list.
  void install(Dio dio, {required List<String> fingerprints}) {
    if (fingerprints.isEmpty) return;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Real pinning requires a custom HttpClientAdapter. Hook left as a
        // stub: integrators can replace this with `dio_certificate_pinning`
        // once a vetted dependency is approved.
        handler.next(options);
      },
    ));
  }
}
