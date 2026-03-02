import Foundation
import KeychainAccess

class KeychainHelper {
    static let shared = KeychainHelper()
    private let keychain = Keychain(service: "com.jeffybar.JeffyBar")

    private init() {}

    func save(_ value: String, for key: String) throws {
        try keychain.set(value, key: key)
    }

    func get(_ key: String) throws -> String? {
        try keychain.get(key)
    }

    func delete(_ key: String) throws {
        try keychain.remove(key)
    }

    func saveData(_ data: Data, for key: String) throws {
        try keychain.set(data, key: key)
    }

    func getData(_ key: String) throws -> Data? {
        try keychain.getData(key)
    }
}
