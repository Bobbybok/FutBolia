package com.futbolia.futbolia

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var githubProgressSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "matcharena/github_progress").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    githubProgressSink = events
                }

                override fun onCancel(arguments: Any?) {
                    githubProgressSink = null
                }
            },
        )

        MethodChannel(messenger, "matcharena/github").setMethodCallHandler { call, result ->
            when (call.method) {
                "status", "apply" -> {
                    val installed = try {
                        packageManager.getPackageInfo(packageName, 0).versionName.orEmpty()
                    } catch (_: Exception) {
                        ""
                    }
                    Thread {
                        val map = try {
                            if (call.method == "status") {
                                GithubUpdate.status(filesDir, installed)
                            } else {
                                GithubUpdate.apply(filesDir, installed) { pct, label ->
                                    mainHandler.post {
                                        githubProgressSink?.success(
                                            mapOf("pct" to pct, "label" to label),
                                        )
                                    }
                                }
                            }
                        } catch (e: Exception) {
                            mapOf(
                                "ok" to false,
                                "available" to false,
                                "install" to false,
                                "message" to (e.message ?: "Erreur GitHub"),
                            )
                        }
                        mainHandler.post {
                            @Suppress("UNCHECKED_CAST")
                            val typed = map as Map<String, Any?>
                            val path = typed["apkPath"] as? String
                            if (typed["install"] == true && !path.isNullOrBlank()) {
                                installApk(path)
                            }
                            result.success(typed)
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun canInstallPackages(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun requestInstallPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val intent = Intent(
            Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
            Uri.parse("package:$packageName"),
        )
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun installApk(path: String) {
        val file = File(path)
        if (!file.exists()) return
        if (!canInstallPackages()) {
            requestInstallPermission()
            return
        }
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
