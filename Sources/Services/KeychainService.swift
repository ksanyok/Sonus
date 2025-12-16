import Foundation

class KeychainService {
    static let shared = KeychainService()
    private let storageKey = "com.sonus.app.openai_api_key"
    
    private init() {}
    
    func save(key: String) {
        UserDefaults.standard.set(key, forKey: storageKey)
    }
    
    func load() -> String? {
        return UserDefaults.standard.string(forKey: storageKey)
    }
    
    func delete() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
