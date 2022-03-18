# coding: utf-8
#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint launchdarkly_flutter_client_sdk.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'launchdarkly_flutter_client_sdk'
  s.version          = '0.0.1'
  s.summary          = 'Flutter client SDK for LaunchDarkly.'
  s.description      = <<-DESC
                   LaunchDarkly is the feature management platform that software teams use to build better software, faster. Development teams use feature management as a best practice to separate code deployments from feature releases. With LaunchDarkly teams control their entire feature lifecycles from concept to launch to value.
                   With LaunchDarkly, you can:
                   * Release a new feature to a subset of your users, like a group of users who opt-in to a beta tester group.
                   * Slowly roll out a feature to an increasing percentage of users and track the effect that feature has on key metrics.
                   * Instantly turn off a feature that is causing problems, without re-deploying code or restarting the application with a changed config file.
                   * Maintain granular control over your users’ experience by granting access to certain features based on any attribute you choose. For example, provide different users with different functionality based on their payment plan.
                   * Disable parts of your application to facilitate maintenance, without taking everything offline.
                       DESC
  s.homepage         = 'https://github.com/launchdarkly/flutter-client-sdk'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'LaunchDarkly' => 'sdks@launchdarkly.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'LaunchDarkly', '5.4.5'
  s.platform = :ios, '10.0'

  # Flutter.framework does not contain a i386 slice. Only x86_64 simulators are supported.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'VALID_ARCHS[sdk=iphonesimulator*]' => 'x86_64' }
  s.swift_version = '5.0'
end
