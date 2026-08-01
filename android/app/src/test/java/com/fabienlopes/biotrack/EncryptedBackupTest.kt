package com.fabienlopes.biotrack

import com.fabienlopes.biotrack.data.EncryptedBackup
import org.junit.Assert.assertEquals
import org.junit.Test

class EncryptedBackupTest {
    @Test
    fun encryptedPayloadRoundTrips() {
        val plaintext = "{\"schemaVersion\":3}"
        val passphrase = "correct horse battery staple".toCharArray()
        val encrypted = EncryptedBackup.encrypt(plaintext, passphrase)
        assertEquals(plaintext, EncryptedBackup.decrypt(encrypted, passphrase))
    }
}
