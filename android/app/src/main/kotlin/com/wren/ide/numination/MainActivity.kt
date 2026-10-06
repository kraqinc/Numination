package com.wren.ide.numination

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private companion object {
        const val GMAIL_CHANNEL = "numination/gmail"
        const val UPDATER_CHANNEL = "numination.updater"
        const val GMAIL_PACKAGE = "com.google.android.gm"
        const val APK_MIME = "application/vnd.android.package-archive"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GMAIL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openGmail" -> try {
                        val intent = packageManager.getLaunchIntentForPackage(GMAIL_PACKAGE)
                        if (intent == null) result.success(false)
                        else { intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK); startActivity(intent); result.success(true) }
                    } catch (_: Exception) { result.success(false) }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "canInstallPackages" -> result.success(
                        Build.VERSION.SDK_INT < Build.VERSION_CODES.O || packageManager.canRequestPackageInstalls()
                    )
                    "openUnknownSourcesSettings" -> try {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName"))
                        } else Intent(Settings.ACTION_SECURITY_SETTINGS)
                        startActivity(intent); result.success(true)
                    } catch (_: Exception) { result.success(false) }
                    "installApk" -> try {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) { result.error("INVALID_PATH", "Ruta APK vacía", null); return@setMethodCallHandler }
                        val apk = File(path)
                        if (!apk.exists()) { result.error("APK_NOT_FOUND", "No existe el APK", null); return@setMethodCallHandler }
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", apk)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, APK_MIME)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent); result.success(true)
                    } catch (e: Exception) { result.error("INSTALL_FAILED", e.message, null) }
                    else -> result.notImplemented()
                }
            }
    }
}
