package com.example.flux

import android.app.ActivityManager
import android.content.Context
import android.os.StatFs
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.flux/storage"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStorageSpace" -> {
                    try {
                        val stat = StatFs(Environment.getDataDirectory().path)
                        val totalBytes = stat.totalBytes
                        val freeBytes = stat.availableBytes
                        result.success(mapOf("total" to totalBytes, "free" to freeBytes))
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.message, null)
                    }
                }
                "getDeviceRAM" -> {
                    try {
                        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memoryInfo = ActivityManager.MemoryInfo()
                        activityManager.getMemoryInfo(memoryInfo)
                        result.success(memoryInfo.totalMem)
                    } catch (e: Exception) {
                        result.error("RAM_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
