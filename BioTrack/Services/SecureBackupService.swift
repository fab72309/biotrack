import CryptoKit
import Foundation
import Security

enum SecureBackupError: LocalizedError {
    case invalidPassphrase
    case malformedPayload
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .invalidPassphrase:
            return "Passphrase invalide."
        case .malformedPayload:
            return "Sauvegarde chiffrée invalide."
        case .encryptionFailed:
            return "Impossible de chiffrer la sauvegarde."
        case .decryptionFailed:
            return "Impossible de déchiffrer la sauvegarde."
        }
    }
}

enum SecureBackupService {
    private static let iterations = 120_000
    private static let keyLength = 32

    static func encrypt(snapshot: BioTrackSnapshot, passphrase: String) throws -> SecureBackupEnvelope {
        guard !passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SecureBackupError.invalidPassphrase
        }
        do {
            let plain = try JSONEncoder().encode(snapshot)
            let salt = try randomData(count: 16)
            let keyData = pbkdf2SHA256(password: Data(passphrase.utf8), salt: salt, iterations: iterations, keyLength: keyLength)
            let key = SymmetricKey(data: keyData)
            let nonceData = try randomData(count: 12)
            let nonce = try AES.GCM.Nonce(data: nonceData)
            let sealed = try AES.GCM.seal(plain, using: key, nonce: nonce)
            return SecureBackupEnvelope(
                salt: salt,
                nonce: nonceData,
                ciphertext: sealed.ciphertext + sealed.tag
            )
        } catch {
            throw SecureBackupError.encryptionFailed
        }
    }

    static func decrypt(envelope: SecureBackupEnvelope, passphrase: String) throws -> BioTrackSnapshot {
        guard !passphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SecureBackupError.invalidPassphrase
        }
        guard envelope.ciphertext.count > 16 else {
            throw SecureBackupError.malformedPayload
        }
        do {
            let keyData = pbkdf2SHA256(password: Data(passphrase.utf8), salt: envelope.salt, iterations: iterations, keyLength: keyLength)
            let key = SymmetricKey(data: keyData)
            let nonce = try AES.GCM.Nonce(data: envelope.nonce)
            let ciphertext = envelope.ciphertext.dropLast(16)
            let tag = envelope.ciphertext.suffix(16)
            let box = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            let plain = try AES.GCM.open(box, using: key)
            var snapshot = try JSONDecoder().decode(BioTrackSnapshot.self, from: plain)
            MigrationService.migrate(&snapshot)
            return snapshot
        } catch {
            throw SecureBackupError.decryptionFailed
        }
    }

    private static func randomData(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else { throw SecureBackupError.encryptionFailed }
        return Data(bytes)
    }

    // PBKDF2-HMAC-SHA256 implementation (RFC 8018)
    private static func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyLength: Int) -> Data {
        let hLen = 32
        let blocks = Int(ceil(Double(keyLength) / Double(hLen)))
        var derived = Data()

        for blockIndex in 1...blocks {
            var blockSalt = Data(salt)
            var beIndex = UInt32(blockIndex).bigEndian
            withUnsafeBytes(of: &beIndex) { bytes in
                blockSalt.append(contentsOf: bytes)
            }
            var u = hmacSHA256(key: password, data: blockSalt)
            var t = u

            if iterations > 1 {
                for _ in 2...iterations {
                    u = hmacSHA256(key: password, data: u)
                    t = xorData(t, u)
                }
            }
            derived.append(t)
        }
        return derived.prefix(keyLength)
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        let signature = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(signature)
    }

    private static func xorData(_ lhs: Data, _ rhs: Data) -> Data {
        Data(zip(lhs, rhs).map { $0 ^ $1 })
    }
}

