package com.fabienlopes.biotrack.data

import android.content.Context
import kotlinx.serialization.json.Json
import java.io.File
import java.security.SecureRandom
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

class LocalStore(context: Context) {
    private val file = File(context.filesDir, "biotrack-snapshot.json")
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        prettyPrint = true
    }

    fun load(): AppSnapshot {
        if (!file.exists()) return AppSnapshot()
        return runCatching { json.decodeFromString<AppSnapshot>(file.readText()) }
            .getOrElse {
                preserveCorruptedFile()
                AppSnapshot()
            }
    }

    fun save(snapshot: AppSnapshot) {
        val temporary = File(file.parentFile, "${file.name}.tmp")
        temporary.writeText(json.encodeToString(snapshot))
        if (!temporary.renameTo(file)) {
            file.writeText(json.encodeToString(snapshot))
            temporary.delete()
        }
    }

    fun encode(snapshot: AppSnapshot): String = json.encodeToString(snapshot)

    fun decode(raw: String): AppSnapshot = json.decodeFromString(raw)

    private fun preserveCorruptedFile() {
        val backup = File(file.parentFile, "${file.name}.corrupt-${System.currentTimeMillis()}")
        runCatching { file.copyTo(backup, overwrite = false) }
    }
}

object EncryptedBackup {
    private const val prefix = "BTSEC1"
    private const val iterations = 150_000

    fun encrypt(payload: String, passphrase: CharArray): String {
        require(passphrase.isNotEmpty()) { "Le mot de passe ne peut pas être vide." }
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val iv = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val key = deriveKey(passphrase, salt)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(128, iv))
        val encrypted = cipher.doFinal(payload.toByteArray(Charsets.UTF_8))
        return listOf(prefix, salt.encode(), iv.encode(), encrypted.encode()).joinToString(":")
    }

    fun decrypt(serialized: String, passphrase: CharArray): String {
        require(passphrase.isNotEmpty()) { "Le mot de passe ne peut pas être vide." }
        val parts = serialized.split(":")
        require(parts.size == 4 && parts[0] == prefix) { "Sauvegarde chiffrée invalide." }
        val salt = parts[1].decode()
        val iv = parts[2].decode()
        val ciphertext = parts[3].decode()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, deriveKey(passphrase, salt), GCMParameterSpec(128, iv))
        return cipher.doFinal(ciphertext).toString(Charsets.UTF_8)
    }

    private fun deriveKey(passphrase: CharArray, salt: ByteArray): SecretKeySpec {
        val spec = PBEKeySpec(passphrase, salt, iterations, 256)
        return try {
            val bytes = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
            SecretKeySpec(bytes, "AES")
        } finally {
            spec.clearPassword()
        }
    }

    private fun ByteArray.encode(): String = Base64.getEncoder().withoutPadding().encodeToString(this)
    private fun String.decode(): ByteArray = Base64.getDecoder().decode(this)
}
