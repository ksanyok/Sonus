import Foundation
import AppKit
import Security

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
    
    // Читаем версию напрямую из файла Info.plist установленного приложения
    // Это обходит кеширование Bundle и всегда возвращает актуальную версию
    private var currentVersion: String {
        // Сначала пробуем прочитать из установленного приложения
        if let installedVersion = readInstalledVersion() {
            print("📱 Версия из /Applications: \(installedVersion)")
            return installedVersion
        }
        // Fallback на Bundle (для разработки)
        let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        print("📱 Версия из Bundle (fallback): \(bundleVersion)")
        return bundleVersion
    }
    
    struct UpdateInfo: Codable {
        let version: String
        let releaseNotes: String
        let downloadURL: String
        let publishedAt: Date
        let isRequired: Bool // Обязательное обновление
    }
    
    private init() {
        print("🚀 UpdateService инициализирован")
        print("📱 Текущая версия: \(currentVersion)")
        print("📂 Bundle path: \(Bundle.main.bundlePath)")
    }
    
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
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        print("   Bundle Path: \(Bundle.main.bundlePath)")
        
        do {
            let latestRelease = try await fetchLatestRelease()
            
            print("   Последний релиз: v\(latestRelease.version)")
            print("   Сравнение: '\(latestRelease.version)' > '\(currentVersion)'?")
            print("   Результат сравнения: \(isNewerVersion(latestRelease.version, than: currentVersion))")
            
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
        errorMessage = nil
        
        print("═══════════════════════════════════════════")
        print("🚀 НАЧАЛО ОБНОВЛЕНИЯ")
        print("═══════════════════════════════════════════")
        print("   📋 Версия для установки: \(updateInfo.version)")
        print("   📋 Текущая версия: \(currentVersion)")
        print("   📋 URL загрузки: \(updateInfo.downloadURL)")
        
        do {
            // 1. Скачиваем .zip с новой версией
            print("\n[1/4] 📥 Скачивание обновления...")
            let zipURL = try await downloadUpdate(from: updateInfo.downloadURL)
            print("   ✅ Файл скачан: \(zipURL.path)")
            
            // 2. Распаковываем
            print("\n[2/4] 📦 Распаковка архива...")
            downloadProgress = 0.5
            let appURL = try await unzipUpdate(zipURL)
            print("   ✅ Распаковано: \(appURL.path)")
            
            let newAppVersion = readBundleVersion(at: appURL)
            print("   📦 Версия в распакованном архиве: \(newAppVersion ?? "НЕ НАЙДЕНА")")
            
            downloadProgress = 0.7
            
            if let newAppVersion = newAppVersion, !isNewerVersion(newAppVersion, than: currentVersion) {
                throw NSError(
                    domain: "UpdateService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "В архиве версия \(newAppVersion), она не новее текущей (\(currentVersion))."]
                )
            }
            
            // 3. Заменяем приложение
            print("\n[3/4] 🔄 Установка приложения...")
            downloadProgress = 0.9
            try await installUpdate(from: appURL)
            
            // Очищаем ошибки и флаг доступного обновления
            updateAvailable = nil
            errorMessage = nil
            
            // Проверяем что обновление применилось
            let installedVersion = readInstalledVersion()
            print("   ✅ Версия после установки: \(installedVersion ?? "НЕ ОПРЕДЕЛЕНА")")
            
            if let installedVersion = installedVersion,
               let expected = newAppVersion,
               installedVersion != expected {
                throw NSError(
                    domain: "UpdateService",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Обновление не применилось. Установлена версия: \(installedVersion), ожидалась: \(expected)"]
                )
            }
            
            downloadProgress = 1.0
            
            // 4. Перезапускаем приложение
            print("\n[4/4] 🔄 Перезапуск приложения...")
            print("═══════════════════════════════════════════")
            print("✅ ОБНОВЛЕНИЕ ЗАВЕРШЕНО УСПЕШНО")
            print("═══════════════════════════════════════════")
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
        
        // Декодер с поддержкой ISO8601 дат
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let release = try decoder.decode(GitHubRelease.self, from: data)
        
        print("   Tag: \(release.tag_name)")
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
        let backupPath = currentAppURL.deletingLastPathComponent().appendingPathComponent("Sonus-Backup.app")
        
        print("📦 Установка обновления:")
        print("   Источник: \(newAppURL.path)")
        print("   Назначение: \(currentAppURL.path)")
        print("   Бэкап: \(backupPath.path)")
        
        // Проверяем что новое приложение существует
        guard FileManager.default.fileExists(atPath: newAppURL.path) else {
            throw NSError(
                domain: "UpdateService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Загруженное приложение не найдено"]
            )
        }
        
        // Создаем скрипт установки
        // Используем ditto вместо cp -R для надежного копирования
        let scriptContent = """
#!/bin/bash
set -e

# Удаляем старый бэкап если есть
rm -rf '\(backupPath.path)' 2>/dev/null || true

# Создаём бэкап текущего приложения
if [ -d '\(currentAppURL.path)' ]; then
    ditto '\(currentAppURL.path)' '\(backupPath.path)'
fi

# Удаляем текущее приложение
rm -rf '\(currentAppURL.path)'

# Копируем новое приложение
ditto '\(newAppURL.path)' '\(currentAppURL.path)'

# Убираем карантин и подписываем
xattr -cr '\(currentAppURL.path)' 2>/dev/null || true
codesign --force --deep --sign - '\(currentAppURL.path)' 2>/dev/null || true

echo "SUCCESS"
"""
        
        let scriptPath = "/tmp/sonus_install_\(UUID().uuidString).sh"
        try scriptContent.write(toFile: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
        
        defer {
            try? FileManager.default.removeItem(atPath: scriptPath)
        }
        
        print("   🔐 Запрашиваем права администратора...")
        try await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-e",
            "do shell script \"bash '\(scriptPath)'\" with administrator privileges"
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        print("   📝 STDOUT: '\(output)'")
        print("   📝 STDERR: '\(errorOutput)'")
        print("   ⚙️ Код: \(process.terminationStatus)")

        if process.terminationStatus != 0 {
            let combined = output + errorOutput
            let errorMessage: String

            if combined.contains("(-128)") || combined.contains("User canceled") {
                errorMessage = "Установка отменена пользователем"
            } else if combined.contains("(-60005)") || combined.contains("not allowed") {
                errorMessage = "Требуются права администратора"
            } else if !errorOutput.isEmpty {
                errorMessage = "Ошибка установки: \(errorOutput)"
            } else {
                errorMessage = "Не удалось установить обновление (код \(process.terminationStatus))"
            }

            throw NSError(domain: "UpdateService", code: Int(process.terminationStatus),
                         userInfo: [NSLocalizedDescriptionKey: errorMessage])
        }

        if let installedBundle = Bundle(url: currentAppURL),
           let installedVersion = installedBundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            print("   ✅ Установленная версия: \(installedVersion)")
        }
        print("✅ Обновление успешно установлено")
    }
    
    private func restartApplication() {
        print("🔄 Перезапуск приложения...")
        
        // Путь к установленному приложению
        let installedAppPath = "/Applications/Sonus.app"
        let currentPID = ProcessInfo.processInfo.processIdentifier
        
        print("   📱 Текущий PID: \(currentPID)")
        print("   📂 Путь приложения: \(installedAppPath)")
        
        // Проверяем версию установленного приложения
        if let installedVersion = readInstalledVersion() {
            print("   ✅ Установленная версия: \(installedVersion)")
        }
        
        // Используем надежный метод перезапуска через отдельный bash-скрипт
        // Скрипт ждёт завершения текущего процесса и только потом запускает новый
        let script = """
        #!/bin/bash
        # Ждём завершения текущего процесса (максимум 10 секунд)
        for i in {1..100}; do
            if ! kill -0 \(currentPID) 2>/dev/null; then
                break
            fi
            sleep 0.1
        done
        sleep 0.3
        # Запускаем приложение
        open "\(installedAppPath)"
        # Удаляем этот скрипт
        rm -f "$0"
        """
        
        let scriptPath = "/tmp/sonus_restart_\(UUID().uuidString).sh"
        
        do {
            try script.write(toFile: scriptPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath)
            
            // Запускаем скрипт через nohup чтобы он продолжил работать после завершения родительского процесса
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
            process.arguments = ["/bin/bash", scriptPath]
            process.currentDirectoryURL = URL(fileURLWithPath: "/tmp")
            
            // Полностью отсоединяем от текущего процесса
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            
            try process.run()
            print("✅ Скрипт перезапуска запущен через nohup")
            
        } catch {
            print("❌ Ошибка запуска скрипта: \(error)")
            // Альтернативный метод - запуск через launchd
            let fallbackScript = "sleep 1 && open '\(installedAppPath)'"
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "nohup bash -c \"\(fallbackScript)\" &"]
            try? task.run()
        }
        
        print("   Завершаем текущий процесс через exit(0)...")
        
        // Даём немного времени скрипту запуститься, затем принудительно завершаем
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Используем exit(0) вместо NSApp.terminate для гарантированного завершения
            exit(0)
        }
    }
    
    private func isNewerVersion(_ version: String, than currentVersion: String) -> Bool {
        print("   🔢 Сравнение версий:")
        print("      Новая: '\(version)'")
        print("      Текущая: '\(currentVersion)'")
        
        let newComponents = version.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        
        print("      Компоненты новой: \(newComponents)")
        print("      Компоненты текущей: \(currentComponents)")
        
        for (index, newValue) in newComponents.enumerated() {
            let currentValue = index < currentComponents.count ? currentComponents[index] : 0
            print("      Сравнение [\(index)]: \(newValue) vs \(currentValue)")
            
            if newValue > currentValue {
                print("      ✅ Новая версия больше")
                return true
            } else if newValue < currentValue {
                print("      ❌ Новая версия меньше")
                return false
            }
        }
        
        print("      ⚖️ Версии равны")
        return false
    }
    
    private func showUpdateNotification(_ update: UpdateInfo) {
        let notification = NSUserNotification()
        notification.title = "Доступно обновление Sonus"
        notification.informativeText = "Версия \(update.version) готова к установке"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    private func readInstalledVersion() -> String? {
        let plistPath = "/Applications/Sonus.app/Contents/Info.plist"
        
        // Читаем файл напрямую без кеширования через Data
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plist["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }

    private func readBundleVersion(at appURL: URL) -> String? {
        let plistPath = appURL.appendingPathComponent("Contents/Info.plist").path
        
        // Читаем файл напрямую без кеширования
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let version = plist["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
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
