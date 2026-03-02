import Foundation
import CryptoKit

struct DeviceIdentity {
    let deviceId: String
    let publicKeyBase64URL: String
    let privateKey: Curve25519.Signing.PrivateKey

    static func loadOrCreate() -> DeviceIdentity {
        let keychainKey = "deviceIdentityPrivateKey"

        if let rawKeyData = try? KeychainHelper.shared.getData(keychainKey),
           let privateKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: rawKeyData) {
            return DeviceIdentity(privateKey: privateKey)
        }

        let privateKey = Curve25519.Signing.PrivateKey()
        let rawPrivKey = Data(privateKey.rawRepresentation)
        try? KeychainHelper.shared.saveData(rawPrivKey, for: keychainKey)
        return DeviceIdentity(privateKey: privateKey)
    }

    init(privateKey: Curve25519.Signing.PrivateKey) {
        self.privateKey = privateKey
        let rawPubKey = Data(privateKey.publicKey.rawRepresentation)

        let hash = SHA256.hash(data: rawPubKey)
        self.deviceId = hash.map { String(format: "%02x", $0) }.joined()

        self.publicKeyBase64URL = rawPubKey.base64URLEncodedString()
    }

    func signPayload(
        nonce: String,
        token: String,
        signedAtMs: Int64
    ) -> String {
        let scopes = "operator.read,operator.write"
        let payload = [
            "v3",
            deviceId,
            "jeffybar",
            "ui",
            "operator",
            scopes,
            String(signedAtMs),
            token,
            nonce,
            "macos",
            ""
        ].joined(separator: "|")

        let payloadData = payload.data(using: .utf8)!
        guard let signature = try? privateKey.signature(for: payloadData) else { return "" }
        return Data(signature).base64URLEncodedString()
    }
}

extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
