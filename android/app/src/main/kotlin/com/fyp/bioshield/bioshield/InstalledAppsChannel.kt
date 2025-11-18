package com.fyp.bioshield.bioshield

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class InstalledAppsChannel(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.fyp.bioshield/installed_apps"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledApps" -> {
                try {
                    val apps = getInstalledApps()
                    result.success(apps)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get installed apps: ${e.message}", null)
                }
            }
            "getAppLabel" -> {
                try {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val label = getAppLabel(packageName)
                        result.success(label)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get app label: ${e.message}", null)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun getInstalledApps(): List<Map<String, String>> {
        val pm = context.packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return packages
            .filter { app ->
                // Filter to only user-installed apps and system apps with biometric capability
                (app.flags and ApplicationInfo.FLAG_SYSTEM) == 0 ||
                hasLauncherIntent(pm, app.packageName)
            }
            .map { app ->
                mapOf(
                    "packageName" to app.packageName,
                    "appLabel" to app.loadLabel(pm).toString()
                )
            }
            .sortedBy { it["appLabel"] }
    }

    private fun getAppLabel(packageName: String): String? {
        return try {
            val pm = context.packageManager
            val appInfo = pm.getApplicationInfo(packageName, 0)
            appInfo.loadLabel(pm).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun hasLauncherIntent(pm: PackageManager, packageName: String): Boolean {
        return pm.getLaunchIntentForPackage(packageName) != null
    }
}
