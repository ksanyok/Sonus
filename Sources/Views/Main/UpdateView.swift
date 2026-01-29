import SwiftUI

struct UpdateView: View {
    @StateObject private var updateService = UpdateService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            if let update = updateService.updateAvailable {
                updateAvailableView(update)
            } else if updateService.isCheckingForUpdates {
                checkingView
            } else {
                noUpdatesView
            }
        }
        .frame(width: 500, height: 400)
        .padding(30)
    }
    
    // MARK: - Update Available
    
    @ViewBuilder
    private func updateAvailableView(_ update: UpdateService.UpdateInfo) -> some View {
        VStack(spacing: 24) {
            // Иконка
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            // Заголовок
            VStack(spacing: 8) {
                Text("Доступно обновление")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Версия \(update.version)")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Release Notes
            ScrollView {
                Text(update.releaseNotes)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 150)
            
            // Прогресс загрузки
            if updateService.isDownloading {
                VStack(spacing: 12) {
                    ProgressView(value: updateService.downloadProgress)
                        .progressViewStyle(.linear)
                    
                    Text("\(Int(updateService.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Ошибка
            if let error = updateService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Кнопки
            HStack(spacing: 16) {
                if !update.isRequired {
                    Button("Позже") {
                        dismiss()
                    }
                    .keyboardShortcut(.escape)
                }
                
                Button(updateService.isDownloading ? "Загрузка..." : "Обновить сейчас") {
                    Task {
                        await updateService.downloadAndInstallUpdate(update)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(updateService.isDownloading)
                .keyboardShortcut(.defaultAction)
            }
        }
    }
    
    // MARK: - Checking
    
    private var checkingView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Проверка обновлений...")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - No Updates

    private var noUpdatesView: some View {
        // Используем глобальную функцию getAppVersion() которая читает напрямую из файла
        let appVersion = getAppVersion()
        return VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                Text("У вас последняя версия")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Sonus v\(appVersion)")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Проверить снова") {
                Task {
                    await updateService.checkForUpdates(silent: false)
                }
            }
            .buttonStyle(.bordered)
            
            Button("Закрыть") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
    }
}

/// Компактное уведомление в Settings
struct UpdateBanner: View {
    let update: UpdateService.UpdateInfo
    @State private var showingUpdateSheet = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Доступна версия \(update.version)")
                    .font(.headline)
                
                Text("Нажмите для обновления")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Обновить") {
                showingUpdateSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
        .sheet(isPresented: $showingUpdateSheet) {
            UpdateView()
        }
    }
}

/// Компактный баннер для главного экрана (RecordView)
struct UpdateBannerCompact: View {
    let update: UpdateService.UpdateInfo
    @Binding var showingUpdateSheet: Bool
    
    var body: some View {
        Button(action: {
            showingUpdateSheet = true
        }) {
            HStack(spacing: 16) {
                // Анимированная иконка
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("🎉 Доступно обновление")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("v\(update.version)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.3))
                            .cornerRadius(6)
                            .foregroundColor(.green)
                    }
                    
                    Text("Новые функции и улучшения ждут вас")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Обновить")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.green.opacity(0.3),
                        Color.blue.opacity(0.2)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
            )
            .cornerRadius(16)
            .shadow(color: Color.green.opacity(0.3), radius: 15, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

