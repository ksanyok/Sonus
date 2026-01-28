# Инструкция по созданию релизов для автообновления

## Подготовка релиза

### 1. Обновите версию в Info.plist

```bash
# Откройте Info.plist и измените:
CFBundleShortVersionString: "1.2"  # Версия для пользователя
CFBundleVersion: "3"                # Внутренний номер сборки
```

### 2. Соберите приложение

```bash
cd /Users/oleksandr/Documents/GitHub/Sonus

# Сборка в release режиме
./build_app.sh release

# Проверьте что сборка успешна
ls -la dist/Sonus.app
```

### 3. Создайте ZIP архив

```bash
cd dist
zip -r Sonus-v1.2.zip Sonus.app
```

**ВАЖНО:** Название файла должно содержать .zip в конце!

### 4. Создайте GitHub Release

#### Через веб-интерфейс:

1. Перейдите на https://github.com/oleksandr/Sonus/releases
2. Нажмите "Create a new release"
3. Заполните:
   - **Tag version:** `v1.2` (обязательно с префиксом v)
   - **Release title:** `Sonus v1.2`
   - **Description:** Опишите изменения в релизе:
     ```
     ## Что нового
     - Добавлено автоматическое обновление
     - Исправлена проблема с сохранением настроек
     - Улучшена работа Interview Assistant
     
     ## Установка
     1. Скачайте Sonus-v1.2.zip
     2. Распакуйте архив
     3. Перетащите Sonus.app в папку Applications
     ```
4. **Прикрепите файл:** Перетащите `Sonus-v1.2.zip` в область "Attach binaries"
5. **Публикация:**
   - ✅ Отметьте "Set as the latest release"
   - ⚠️ НЕ отмечайте "This is a pre-release"
6. Нажмите "Publish release"

#### Через командную строку (GitHub CLI):

```bash
# Установите GitHub CLI если нужно
brew install gh

# Авторизуйтесь
gh auth login

# Создайте релиз
gh release create v1.2 \
  --title "Sonus v1.2" \
  --notes "Автообновление, исправления ошибок" \
  dist/Sonus-v1.2.zip
```

### 5. Настройка приватного репозитория

#### Вариант А: Публичные релизы (рекомендуется)

Даже в приватном репозитории можно сделать релизы публичными:

1. Создайте релиз как обычно
2. Assets (.zip файлы) будут доступны публично через прямую ссылку
3. Приложение сможет скачивать их без токена

#### Вариант Б: Использование токена (если нужен приватный доступ)

1. Создайте Personal Access Token:
   - GitHub → Settings → Developer settings → Personal access tokens
   - Создайте токен с правом `repo`
   
2. Обновите `UpdateService.swift`:
   ```swift
   private func fetchLatestRelease() async throws -> UpdateInfo {
       let urlString = "https://api.github.com/repos/\(githubRepo)/releases/latest"
       guard let url = URL(string: urlString) else {
           throw UpdateError.invalidURL
       }
       
       var request = URLRequest(url: url)
       request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
       
       // Добавьте ваш токен здесь
       request.setValue("Bearer ghp_ВАШТОКЕН", forHTTPHeaderField: "Authorization")
       
       // ... остальной код
   }
   ```

### 6. Обязательные обновления

Если обновление критично, добавьте в описание релиза слово `REQUIRED`:

```markdown
## REQUIRED Security Update

Важное обновление безопасности, обязательно к установке.
```

Приложение не позволит пропустить такое обновление.

## Проверка автообновления

### 1. Установите старую версию

```bash
# Установите текущую версию (1.1)
killall Sonus
cp -R dist/Sonus.app /Applications/
open /Applications/Sonus.app
```

### 2. Создайте тестовый релиз v1.2

```bash
# Измените версию в Info.plist на 1.2
# Пересоберите
./build_app.sh release
cd dist
zip -r Sonus-v1.2.zip Sonus.app

# Создайте релиз на GitHub
gh release create v1.2 \
  --title "Sonus v1.2 Test" \
  --notes "Тестовое обновление" \
  Sonus-v1.2.zip
```

### 3. Проверьте в приложении

1. Откройте Sonus v1.1
2. Подождите 3 секунды (автопроверка)
3. Или вручную: Settings → "Проверить обновления"
4. Должен появиться баннер с предложением обновиться

### 4. Установите обновление

1. Нажмите "Обновить"
2. Дождитесь скачивания
3. Приложение автоматически перезапустится
4. Проверьте что версия изменилась на 1.2

## Структура GitHub API ответа

```json
{
  "tag_name": "v1.2",
  "name": "Sonus v1.2",
  "body": "## Изменения\n- Новые функции",
  "published_at": "2026-01-28T12:00:00Z",
  "assets": [
    {
      "name": "Sonus-v1.2.zip",
      "browser_download_url": "https://github.com/oleksandr/Sonus/releases/download/v1.2/Sonus-v1.2.zip"
    }
  ]
}
```

## Чеклист релиза

- [ ] Обновлена версия в Info.plist
- [ ] Приложение собрано в release режиме
- [ ] Создан ZIP архив (.zip в конце имени!)
- [ ] Tag версии соответствует CFBundleShortVersionString
- [ ] Описание релиза содержит изменения
- [ ] ZIP файл прикреплен к релизу
- [ ] Релиз помечен как "latest"
- [ ] Протестировано автообновление со старой версии

## Откат обновления

Если обновление вызвало проблемы:

1. Удалите проблемный релиз с GitHub
2. Отметьте предыдущий релиз как "latest"
3. Или вручную установите предыдущую версию из бэкапа:
   ```bash
   cp -R /Applications/Sonus-Backup.app /Applications/Sonus.app
   ```

## Сохранение данных

Данные пользователя НЕ теряются при обновлении:

- ✅ Настройки в UserDefaults (API ключ, язык)
- ✅ Сессии в ~/Documents/sessions.json
- ✅ Аудио файлы в ~/Documents/Sonus/
- ✅ Словарь компании и playbooks

Обновляется только:
- `/Applications/Sonus.app` - сам исполняемый файл

## Частые проблемы

### "Network error" при проверке обновлений

**Причина:** Репозиторий приватный и релизы не публичны

**Решение:** Либо сделайте релизы публичными, либо добавьте токен в код

### "No .zip found"

**Причина:** Файл не называется .zip или не прикреплен к релизу

**Решение:** Переименуйте файл чтобы заканчивался на .zip

### Обновление не предлагается

**Причина:** Версия в релизе меньше или равна текущей

**Решение:** Проверьте что tag_name (v1.2) больше чем currentVersion (1.1)

### Приложение не запускается после обновления

**Причина:** Проблемы с подписью или карантином

**Решение:** Бэкап создается автоматически:
```bash
mv /Applications/Sonus.app /Applications/Sonus-broken.app
mv /Applications/Sonus-Backup.app /Applications/Sonus.app
```
