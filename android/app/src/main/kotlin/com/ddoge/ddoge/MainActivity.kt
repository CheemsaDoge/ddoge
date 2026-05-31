package com.ddoge.ddoge

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ddoge.ddoge/app_update"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstallApks" -> result.success(canInstallApks())
                "openInstallPermissionSettings" -> {
                    openInstallPermissionSettings()
                    result.success(null)
                }
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path.isNullOrBlank()) {
                        result.error("INVALID_PATH", "APK path is empty", null)
                        return@setMethodCallHandler
                    }
                    installApk(path, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallApks(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallPermissionSettings() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName")
        )
        startActivity(intent)
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        val apkFile = File(path)
        if (!apkFile.exists()) {
            result.error("FILE_NOT_FOUND", "APK file does not exist", path)
            return
        }

        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        try {
            startActivity(intent)
            result.success(null)
        } catch (error: ActivityNotFoundException) {
            result.error(
                "INSTALLER_NOT_FOUND",
                "No Android package installer is available",
                error.message
            )
        }
    }
}
