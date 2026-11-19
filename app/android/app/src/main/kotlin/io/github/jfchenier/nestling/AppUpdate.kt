package io.github.jfchenier.nestling

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * App updates (lib/update/): hands a release APK the app downloaded to Android's installer. The
 * APK is signed with the same key as this app, so Android installs it over it and keeps the data.
 */
class AppUpdate(private val activity: Activity) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "canInstall" -> result.success(canInstall())
            "allowInstall" -> {
                openInstallSetting()
                result.success(null)
            }
            "install" -> {
                val path = call.argument<String>("path")
                if (path == null) {
                    result.error("args", "path missing", null)
                    return
                }
                if (!canInstall()) {
                    openInstallSetting()
                    result.success(false)
                    return
                }
                try {
                    val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.updates", File(path))
                    val intent = Intent(Intent.ACTION_VIEW)
                        .setDataAndType(uri, "application/vnd.android.package-archive")
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                    activity.startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("install", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Android 8+ lets an app install others only once the user allows it ("Install unknown apps"). */
    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity.packageManager.canRequestPackageInstalls()

    private fun openInstallSetting() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        activity.startActivity(
            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:${activity.packageName}"))
        )
    }

    companion object {
        const val CHANNEL_NAME = "nestling/update"
    }
}
