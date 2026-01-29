import Foundation

extension Notification.Name {
    static let sonusOpenSettings = Notification.Name("sonus.openSettings")
    static let sonusShowMiniWindow = Notification.Name("sonus.showMiniWindow")
    static let sonusTriggersDidChange = Notification.Name("sonus.triggersDidChange")
    static let sonusCloseHintsPanel = Notification.Name("sonus.closeHintsPanel")
    static let sonusSessionSaved = Notification.Name("sonus.sessionSaved")
}

/// Глобальная функция для получения версии приложения
/// Читает напрямую из файла Info.plist, обходя кеширование Bundle
func getAppVersion() -> String {
    let plistPath = "/Applications/Sonus.app/Contents/Info.plist"
    
    // Читаем файл напрямую без кеширования
    if let data = FileManager.default.contents(atPath: plistPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
       let version = plist["CFBundleShortVersionString"] as? String {
        return version
    }
    
    // Fallback на Bundle (для разработки)
    return (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "-"
}

/// Получает номер сборки приложения
func getAppBuild() -> String {
    let plistPath = "/Applications/Sonus.app/Contents/Info.plist"
    
    if let data = FileManager.default.contents(atPath: plistPath),
       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
       let build = plist["CFBundleVersion"] as? String {
        return build
    }
    
    return (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "-"
}
