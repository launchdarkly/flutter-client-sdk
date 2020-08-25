#import "LaunchdarklyFlutterClientSdkPlugin.h"
#if __has_include(<launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk-Swift.h>)
#import <launchdarkly_flutter_client_sdk/launchdarkly_flutter_client_sdk-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "launchdarkly_flutter_client_sdk-Swift.h"
#endif

@implementation LaunchdarklyFlutterClientSdkPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftLaunchdarklyFlutterClientSdkPlugin registerWithRegistrar:registrar];
}
@end
