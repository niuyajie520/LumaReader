import Foundation
import Security

@MainActor
enum AIKeychain {
    private static func identity(_ provider:AIProvider) -> [String:Any] { [
        kSecClass as String:kSecClassGenericPassword,
        kSecAttrService as String:"app.luma.personal-reader.ai",
        kSecAttrAccount as String:provider.rawValue+"-api-key",
        kSecAttrSynchronizable as String:false
    ] }
    static func read(provider:AIProvider = .deepseek) throws -> String? {
        var query = identity(provider)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary,&result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw failure(status) }
        return String(data:data,encoding:.utf8)
    }
    static func save(_ raw:String,provider:AIProvider = .deepseek) throws {
        let key = raw.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !key.isEmpty else { throw AIClientError.missingKey }
        let data = Data(key.utf8)
        let status = SecItemUpdate(identity(provider) as CFDictionary,[kSecValueData as String:data] as CFDictionary)
        if status == errSecItemNotFound {
            var query = identity(provider); query[kSecValueData as String] = data
            let added = SecItemAdd(query as CFDictionary,nil)
            guard added == errSecSuccess else { throw failure(added) }
        } else if status != errSecSuccess { throw failure(status) }
    }
    static func remove(provider:AIProvider = .deepseek) throws {
        let status = SecItemDelete(identity(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw failure(status) }
    }
    private static func failure(_ status:OSStatus) -> ReaderFailure {
        .message("无法访问 macOS 钥匙串（\(status)）。请解锁钥匙串并重试。")
    }
}
