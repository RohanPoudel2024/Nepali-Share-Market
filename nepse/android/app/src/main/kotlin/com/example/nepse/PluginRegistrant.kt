package com.example.nepse

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.shim.ShimPluginRegistry
import io.flutter.plugin.common.PluginRegistry
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin

object PluginRegistrant {
    fun registerPlugins(flutterEngine: FlutterEngine) {
        if (flutterEngine == null) {
            throw NullPointerException("FlutterEngine must not be null")
        }
        
        // Explicitly register common plugins that might need special handling
        try {
            flutterEngine.plugins.add(FlutterSecureStoragePlugin())
        } catch (e: Exception) {
            // Log but don't crash if a plugin isn't available
            println("Error registering FlutterSecureStoragePlugin: ${e.message}")
        }
        
        try {
            flutterEngine.plugins.add(SharedPreferencesPlugin())
            flutterEngine.plugins.add(PathProviderPlugin())
            flutterEngine.plugins.add(UrlLauncherPlugin())
            flutterEngine.plugins.add(WebViewFlutterPlugin())
            flutterEngine.plugins.add(FlutterAndroidLifecyclePlugin())
        } catch (e: Exception) {
            // Just log but continue execution
            println("Error registering plugins: ${e.message}")
        }
        
        // Let the GeneratedPluginRegistrant handle the rest
        io.flutter.plugins.GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
