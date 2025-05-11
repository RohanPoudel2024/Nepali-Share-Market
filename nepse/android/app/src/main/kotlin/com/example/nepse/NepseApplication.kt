package com.example.nepse

import io.flutter.app.FlutterApplication
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugins.GeneratedPluginRegistrant

// Update: Using FlutterApplication properly with V2 embedding
class NepseApplication : FlutterApplication() {
    override fun onCreate() {
        super.onCreate()
        
        // Pre-warm the Flutter engine
        val flutterEngine = FlutterEngine(this)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        
        // Cache the Flutter engine
        FlutterEngineCache.getInstance().put("my_engine_id", flutterEngine)
        
        // Register plugins using V2 embedding
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
