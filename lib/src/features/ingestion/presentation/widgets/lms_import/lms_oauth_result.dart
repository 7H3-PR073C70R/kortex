/// Result model representing verified OAuth credentials for an LMS platform.
class LmsOAuthResult {
  const LmsOAuthResult({
    required this.platform,
    required this.accessToken,
    required this.accountEmail,
    this.canvasDomain,
  });

  final String platform;
  final String accessToken;
  final String accountEmail;
  final String? canvasDomain;
}
