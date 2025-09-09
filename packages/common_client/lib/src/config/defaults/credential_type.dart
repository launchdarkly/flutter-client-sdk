/// Represents the credential type used by the SDK. The credential type is
/// determined by the platform the SDK is running on.
enum CredentialType {
  /// The SDK is using a mobile key credential.
  mobileKey,

  /// The SDK is using a client-side ID.
  clientSideId,
}
