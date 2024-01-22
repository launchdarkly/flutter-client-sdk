/// The connection mode for the SDK to use.
///
/// Can be used to configure the initial connection mode used by the SDK.
enum ConnectionMode {
  /// The SDK will not receive updates from LaunchDarkly. To configure the SDK
  /// to not make network connections use [LDConfig.offline] instead.
  offline,

  /// The SDK will use a streaming connection to receive updates from
  /// LaunchDarkly.
  streaming,

  /// The SDK will make periodic requests to receive updates from LaunchDarkly.
  polling,
}
