/// This is the API reference for the LaunchDarkly Client-Side SDK for Flutter.
///
/// In typical usage, you will create an [LDClient] instance once at startup,
/// which provides access to all of the SDK's functionality.
///
/// A complete [reference guide](https://docs.launchdarkly.com/sdk/client-side/flutter) is available on the LaunchDarkly
/// documentation site.
library launchdarkly_flutter_client_sdk;

// Re-export the client package, which includes the common dependencies as well.
// Only export types which are intended to be part of the public API.
export 'package:launchdarkly_dart_client/ld_client.dart'
    show
        LDContext,
        LDContextBuilder,
        HttpProperties,
        AttributeReference,
        LDValue,
        LDValueObjectBuilder,
        LDLogger,
        LDLogAdapter,
        LDLogRecord,
        LDLogLevel,
        LDBasicLogPrinter,
        LDEvaluationDetail,
        LDEvaluationReason,
        LDValueArrayBuilder,
        LDKind,
        LDErrorKind,
        LDValueType,
        FlagsChangedEvent,
        ServiceEndpoints,
        IdentifyResult,
        IdentifyComplete,
        IdentifyError,
        IdentifySuperseded,
        CredentialSource,
        DataSourceStatus,
        DataSourceStatusErrorInfo,
        DataSourceState,
        // TODO: Move LDConfigBuilder to flutter?
        LDConfigBuilder,
        AutoEnvAttributes;

// TODO: Will need to export more once the config is implemented.

export 'src/ld_client.dart'
    show LDClient;
