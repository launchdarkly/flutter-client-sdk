package com.launchdarkly.launchdarkly_flutter_client_sdk_example

import android.os.Bundle

import io.flutter.embedding.android.FlutterActivity

import timber.log.Timber

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Timber.plant(Timber.DebugTree())
    }
}
