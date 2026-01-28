import Foundation
import AppKit

/// Сервис для проверки и установки обновлений приложения
class UpdateService: ObservableObject {
    static let shared = UpdateService()
    
    @Published var updateAvailable: UpdateInfo?
    @Published var isCheckingForUpdates = false
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0
    @Published var errorMessage: String?
    
    // ВАЖНО: Замените на ваш GitHub репозиторий в формате "username/repo"
    private let githubRepo = "ksanyok/Sonus"
    private let currentVersion = "1.4.2" // Автоматически из Info.plist
    
    struct UpdateInfo: Codable {
        let version: String
        let releaseNotes: String
        let downloadURL: String
        let publishedAt: Date
        let isRequired: Bool // Обязательное обновление
    }
    
    private init() {}
    
    /// Проверить наличие обновлений
    @MainActor
    func checkForUpdates(silent: Bool = false) async {
        guard !isCheckingForUpdates else {
            print("⏸️ Проверка уже выполняется")
            return
        }
        
        if !silent {
            isCheckingForUpdates = true
        }
        
        print("🔍 Проверка обновлений...")
        print("   Текущая версия: \(currentVersion)")
        print("   GitHub репозиторий: \(githubRepo)")
        
        do {
            let latestRelease = try await fetchLatestRelease()
            
            print("   Последний релиз: v\(latestRelease.version)")
            print("   Сравнение: \(latestRelease.version) > \(currentVersion)?")
            
            if isNewerVersion(latestRelease.version, than: currentVersion) {
                print("✅ ОБНОВЛЕНИЕ ДОСТУПНО: v\(latestRelease.version)")
                updateAvailable = latestRelease
                
                if !silent {
                    print("   URL загрузки: \(latestRelease.downloadURL)")
                }
            } else {
                print("ℹ️ Обновлений нет - используется последняя версия")
                updateAvailable = nil
                if !silent {
                    // Показываем только при ручной проверке
                    showNoUpdatesAlert()
                }
            }
            
        } catch {
            print("❌ ОШИБКА проверки обновлений:")
            print("   Тип: \(type(of: error))")
            print("   Описание: \(error)")
            if !silent {
                errorMessage = "Ошибка проверки обновлений: \(error.localizedDescription)"
            }
        }
        
        isCheckingForUpdates = false
    }
    
    /// Скачать и установить обновление
    @MainActor
    func downloadAndInstallUpdate(_ updateInfo: UpdateInfo) async {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0
        
        do {
            // 1. Скачиваем .zip с новой версией
            print("📥 Скачивание обновления...")
            let zipURL = try await downloadUpdate(from: updateInfo.downloadURL)
            
            // 2. Распаковываем
            print("📦 Распаковка...")
            downloadProgress = 0.7
            let appURL = try await unzipUpdate(zipURL)
            
            // 3. Заменяем приложение
            print("🔄 Установка...")
            downloadProgress = 0.9
            try await installUpdate(from: appURL)
            
            downloadProgress = 1.0
            
            // 4. Перезапускаем приложение
            print("✅ Обновление установлено, перезапуск...")
            restartApplication()
            
        } catch {
            errorMessage = "Ошибка установки обновления: \(error.localizedDescription)"
            print("❌ Ошибка установки: \(error)")
        }
        
        isDownloading = false
    }
    
    // MARK: - Private Methods
    
    private func fetchLatestRelease() async throws -> UpdateInfo {
        // Используем GitHub API для получения последнего релиза
        // Для приватного репозитория релизы могут быть публичными
        let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
        
        print("   API URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("   ❌ Невалидный URL")
            throw UpdateError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        // Если нужен приватный доступ, добавьте токен:
        // request.setValue("Bearer YOUR_GITHUB_TOKEN", forHTTPHeaderField: "Authorization")
        
        print("   📡 Отправка запроса...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("   ❌ Не HTTPURLResponse")
            throw UpdateError.networkError
        }
        
        print("   📨 Статус код: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("   ❌ Ошибка HTTP: \(httpResponse.statusCode)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Ответ: \(responseString.prefix(200))")
            }
            throw UpdateError.networkError
        }
        
        print("   ✅ Получен ответ, размер: \(data.count) байт")
        
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        
        print("   Tag: \(release.tag_name)")
        print("   Имя: \(release.name ?? "без имени")")
        print("   Assets: \(release.assets.count)")
        
        // Ищем .zip файл в assets
        guard let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }) else {
            print("   ❌ ZIP файл не найден в assets")
            release.assets.forEach { asset in
                print("      - \(asset.name)")
            }
            throw UpdateError.noZipFound
        }
        
        print("   ✅ Найден ZIP: \(zipAsset.name)")
        
        return UpdateInfo(
            version: release.tag_name.replacingOccurrences(of: "v", with: ""),
            releaseNotes: release.body ?? "Новая версия доступна",
            downloadURL: zipAsset.browser_download_url,
            publishedAt: release.published_at,
            isRequired: release.body?.lowercased().contains("required") ?? false
        )
    }
    
    private func downloadUpdate(from urlString: String) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }
        
        let request = URLRequest(url: url)
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw UpdateError.downloadFailed
        }
        
        // Перемещаем во временную папку с правильным именем
        let destinationURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sonus-Update.zip")
        
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    private func unzipUpdate(_ zipURL: URL) async throws -> URL {
        let unzipDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sonus-Update")
        
        try? FileManager.default.removeItem(at: unzipDirectory)
        try FileManager.default.createDirectory(at: unzipDirectory, withIntermediateDirectories: true)
        
        // Используем встроенную команду unzip
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", zipURL.path, "-d", unzipDirectory.path]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw UpdateError.unzipFailed
        }
        
        // Ищем .app в распакованной папке
        let contents = try FileManager.default.contentsOfDirectory(
            at: unzipDirectory,
            includingPropertiesForKeys: nil
        )
        
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.noAppFound
        }
        
        return appURL
    }
    
    private func installUpdate(from newAppURL: URL) async throws {
        let currentAppURL = Bundle.main.bundleURL
        let backupURL = currentAppURL.deletingLastPathComponent()
            .appendingPathComponent("Sonus-Backup.app")
        
        let fm = FileManager.default
        
        // 1. Создаем бэкап текущей версии
        try? fm.removeItem(at: backupURL)
        try fm.copyItem(at: currentAppURL, to: backupURL)
        
        // 2. Удаляем текущую версию
        try fm.removeItem(at: currentAppURL)
        
        // 3. Копируем новую версию
        try fm.copyItem(at: newAppURL, to: currentAppURL)
        
        // 4. Очищаем расширенные атрибуты и подписываем
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        process.arguments = ["-cr", currentAppURL.path]
        try? process.run()
        process.waitUntilExit()
        
        // Подпись
        let codesignProcess = Process()
        codesignProcess.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        codesignProcess.arguments = ["--force", "--deep", "--sign", "-", currentAppURL.path]
        try? codesignProcess.run()
        codesignProcess.waitUntilExit()
        
        print("✅ Обновление установлено в \(currentAppURL.path)")
    }
    
    private func restartApplication() {
        let appURL = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        
        // Перезапускаем приложение
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            if let error = error {
                print("❌ Ошибка перезапуска: \(error)")
            }
        }
        
        // Завершаем текущий процесс
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            NSApp.terminate(nil)
        }
    }
    
    private func isNewerVersion(_ version: String, than currentVersion: String) -> Bool {
        let newComponents = version.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        for (index, newValue) in newComponents.enumerated() {
            let currentValue = index < currentComponents.count ? currentComponents[index] : 0
            if newValue > currentValue {
                return true
            } else if newValue < currentValue {
                return false
            }
        }
        
        return false
    }
    
    private func showUpdateNotification(_ update: UpdateInfo) {
        let notification = NSUserNotification()
        notification.title = "Доступно обновление Sonus"
        notification.informativeText = "Версия \(update.version) готова к установке"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func showNoUpdatesAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Обновлений нет"
            alert.informativeText = "У вас установлена последняя версия Sonus \(self.currentVersion)"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // MARK: - GitHub API Models
    
    struct GitHubRelease: Codable {
        let tag_name: String
        let body: String?
        let published_at: Date
        let assets: [GitHubAsset]
    }
    
    struct GitHubAsset: Codable {
        let name: String
        let browser_download_url: String
    }
}

enum UpdateError: Error, LocalizedError {
    case invalidURL
    case networkError
    case noZipFound
    case downloadFailed
    case unzipFailed
    case noAppFound
    case installFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Неверный URL обновления"
        case .networkError: return "Ошибка сети"
        case .noZipFound: return "Файл обновления не найден"
        case .downloadFailed: return "Ошибка скачивания"
        case .unzipFailed: return "Ошибка распаковки"
        case .noAppFound: return "Приложение не найдено в архиве"
        case .installFailed: return "Ошибка установки"
        }
    }
}
