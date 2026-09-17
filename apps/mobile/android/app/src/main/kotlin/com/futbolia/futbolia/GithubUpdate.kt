package com.futbolia.futbolia

import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

/**
 * Vérifie / installe la dernière **release** GitHub (APK),
 * sans jeton ni api.github.com — même principe que Gamelle.
 */
object GithubUpdate {
    const val OWNER = "Bobbybok"
    const val REPO = "FutBolia"

    fun apkFile(filesDir: File) = File(filesDir, "updates/MatchArena.apk")

    fun status(filesDir: File, installedVersion: String): Map<String, Any?> {
        val local = installedVersion
        return try {
            val remote = fetchLatestTag()
            val apk = fetchApkUrl(remote)
            val available = isNewer(remote, local) && apk != null
            mapOf(
                "ok" to true,
                "available" to available,
                "install" to false,
                "local" to display(local),
                "remote" to display(remote),
                "message" to when {
                    remote.isBlank() -> "Impossible de lire les releases GitHub."
                    apk == null ->
                        "Release ${display(remote)} sans APK. Joins un fichier .apk à la release."
                    available ->
                        "Une mise à jour est disponible (${display(local)} → ${display(remote)})."
                    else -> "Déjà à jour (${display(remote)})."
                },
            )
        } catch (e: Exception) {
            mapOf(
                "ok" to false,
                "available" to false,
                "install" to false,
                "local" to display(local),
                "message" to githubError(e),
            )
        }
    }

    fun apply(
        filesDir: File,
        installedVersion: String,
        onProgress: (Double, String) -> Unit = { _, _ -> },
    ): Map<String, Any?> {
        return try {
            onProgress(0.04, "Recherche de la release…")
            val remote = fetchLatestTag()
            if (remote.isBlank()) {
                return mapOf(
                    "ok" to false,
                    "install" to false,
                    "message" to "Release GitHub introuvable.",
                )
            }
            if (!isNewer(remote, installedVersion)) {
                onProgress(1.0, "Déjà à jour (${display(remote)}).")
                return mapOf(
                    "ok" to true,
                    "install" to false,
                    "available" to false,
                    "message" to "Déjà à jour (${display(remote)}).",
                )
            }
            val url = fetchApkUrl(remote)
                ?: throw RuntimeException("Release ${display(remote)} sans fichier APK.")
            val dest = apkFile(filesDir)
            dest.parentFile?.mkdirs()
            if (dest.exists()) dest.delete()
            onProgress(0.08, "Téléchargement de l’APK ${display(remote)}…")
            downloadToFile(url, dest, onProgress)
            onProgress(1.0, "Installation de ${display(remote)}…")
            mapOf(
                "ok" to true,
                "install" to true,
                "available" to true,
                "apkPath" to dest.absolutePath,
                "remote" to display(remote),
                "message" to "Installation de ${display(remote)}…",
            )
        } catch (e: Exception) {
            mapOf(
                "ok" to false,
                "install" to false,
                "available" to false,
                "message" to githubError(e),
            )
        }
    }

    private fun fetchLatestTag(): String {
        val loc = peekLocation("https://github.com/$OWNER/$REPO/releases/latest")
        val fromLoc = loc.substringAfter("/releases/tag/", "").substringBefore("/").substringBefore("?")
        if (fromLoc.isNotBlank()) return fromLoc.trim()
        val xml = String(
            httpGet("https://github.com/$OWNER/$REPO/releases.atom"),
            StandardCharsets.UTF_8,
        )
        val fromId = Regex("""/releases/tag/([^<"\s]+)""")
            .find(xml)
            ?.groupValues
            ?.get(1)
            .orEmpty()
        if (fromId.isNotBlank()) return fromId.trim()
        throw RuntimeException("Aucune release GitHub trouvée.")
    }

    private fun fetchApkUrl(tag: String): String? {
        val encoded = java.net.URLEncoder.encode(tag, "UTF-8").replace("+", "%20")
        val pages = listOf(
            "https://github.com/$OWNER/$REPO/releases/expanded_assets/$encoded",
            "https://github.com/$OWNER/$REPO/releases/tag/$encoded",
        )
        for (page in pages) {
            try {
                val html = String(httpGet(page), StandardCharsets.UTF_8)
                val rel = Regex("""(/[^"'\\s]+/releases/download/[^"'\\s]+\.apk)""")
                    .find(html)
                    ?.groupValues
                    ?.get(1)
                    .orEmpty()
                if (rel.isNotBlank()) {
                    return if (rel.startsWith("http")) rel else "https://github.com$rel"
                }
            } catch (_: Exception) {
            }
        }
        return null
    }

    private fun downloadToFile(
        url: String,
        dest: File,
        onProgress: (Double, String) -> Unit,
    ) {
        val conn = open(url, readTimeoutMs = 600_000)
        try {
            val code = conn.responseCode
            if (code !in 200..299) {
                val err = conn.errorStream?.readBytes() ?: ByteArray(0)
                throw RuntimeException("HTTP $code ${String(err, StandardCharsets.UTF_8).take(240)}")
            }
            val length = conn.contentLengthLong
            val buf = ByteArray(64 * 1024)
            var got = 0L
            conn.inputStream.use { input ->
                dest.outputStream().use { out ->
                    while (true) {
                        val n = input.read(buf)
                        if (n < 0) break
                        out.write(buf, 0, n)
                        got += n
                        val frac = if (length > 0L) (got.toDouble() / length).coerceIn(0.0, 1.0) else 0.45
                        onProgress(0.08 + 0.90 * frac, "Téléchargement de l’APK…")
                    }
                }
            }
        } finally {
            conn.disconnect()
        }
    }

    private fun peekLocation(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 20000
        conn.readTimeout = 20000
        conn.instanceFollowRedirects = false
        conn.setRequestProperty("User-Agent", "MatchArena")
        conn.setRequestProperty("Accept", "*/*")
        try {
            conn.responseCode
            return conn.getHeaderField("Location").orEmpty()
        } finally {
            conn.disconnect()
        }
    }

    private fun httpGet(url: String): ByteArray {
        val conn = open(url)
        try {
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val bytes = stream?.readBytes() ?: ByteArray(0)
            if (code !in 200..299) {
                throw RuntimeException("HTTP $code ${String(bytes, StandardCharsets.UTF_8).take(240)}")
            }
            return bytes
        } finally {
            conn.disconnect()
        }
    }

    private fun open(startUrl: String, readTimeoutMs: Int = 120000): HttpURLConnection {
        var current = startUrl
        repeat(8) {
            val conn = URL(current).openConnection() as HttpURLConnection
            conn.connectTimeout = 20000
            conn.readTimeout = readTimeoutMs
            conn.instanceFollowRedirects = false
            conn.setRequestProperty("User-Agent", "MatchArena")
            conn.setRequestProperty("Accept", "*/*")
            val code = conn.responseCode
            if (code in 300..399) {
                val loc = conn.getHeaderField("Location")
                conn.disconnect()
                if (loc.isNullOrBlank()) throw RuntimeException("Redirect sans Location ($code)")
                current = if (loc.startsWith("http")) loc else URL(URL(current), loc).toString()
                return@repeat
            }
            return conn
        }
        throw RuntimeException("Trop de redirections GitHub")
    }

    private fun key(tag: String) = tag.trim().removePrefix("v").removePrefix("V")

    private fun display(tag: String): String {
        val t = tag.trim()
        if (t.isEmpty()) return t
        return if (t.startsWith("v", ignoreCase = true)) t else "v$t"
    }

    private fun isNewer(remote: String, local: String): Boolean {
        if (remote.isBlank()) return false
        if (local.isBlank()) return true
        val r = semver(key(remote))
        val l = semver(key(local))
        if (r == null || l == null) return key(remote) != key(local)
        for (i in 0..2) {
            if (r[i] != l[i]) return r[i] > l[i]
        }
        return false
    }

    private fun semver(version: String): IntArray? {
        val parts = version.split(Regex("[.+\\-]"))
        if (parts.isEmpty() || parts[0].toIntOrNull() == null) return null
        return intArrayOf(
            parts.getOrNull(0)?.toIntOrNull() ?: 0,
            parts.getOrNull(1)?.toIntOrNull() ?: 0,
            parts.getOrNull(2)?.toIntOrNull() ?: 0,
        )
    }

    private fun githubError(e: Exception): String {
        val raw = (e.message ?: e.toString()).take(280)
        return when {
            raw.contains("HTTP 403") && raw.contains("rate limit", ignoreCase = true) ->
                "Limite GitHub atteinte. Réessaie dans une heure."
            raw.contains("HTTP 401") || raw.contains("HTTP 403") ->
                "GitHub a refusé la requête. $raw"
            raw.contains("HTTP 404") ->
                "Release introuvable. Publie une release avec un APK sur Bobbybok/FutBolia."
            else -> "Impossible de joindre GitHub. $raw"
        }
    }
}
