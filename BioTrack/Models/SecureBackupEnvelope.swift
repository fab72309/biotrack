import Foundation

public struct SecureBackupEnvelope: Codable, Equatable {
    public var version: Int
    public var algorithm: String
    public var salt: Data
    public var nonce: Data
    public var ciphertext: Data
    public var createdAt: Date

    public init(version: Int = 1,
                algorithm: String = "AES.GCM+PBKDF2-HMAC-SHA256",
                salt: Data,
                nonce: Data,
                ciphertext: Data,
                createdAt: Date = Date()) {
        self.version = version
        self.algorithm = algorithm
        self.salt = salt
        self.nonce = nonce
        self.ciphertext = ciphertext
        self.createdAt = createdAt
    }
}

