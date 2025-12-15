# 📋 Чек-лист для загрузки на хостинг

## Обязательные файлы и папки

### Корневая директория
- [ ] `.htaccess` - редирект на public/
- [ ] `composer.json` - зависимости
- [ ] `composer.lock` - версии пакетов
- [ ] `.env.example` - пример конфигурации
- [ ] `deploy.sh` - скрипт деплоя (опционально)

### Папка app/
- [ ] `app/Bootstrap.php`
- [ ] `app/Routes.php`
- [ ] `app/Controllers/` - все контроллеры
- [ ] `app/Domain/` - DTOs
- [ ] `app/Repositories/` - репозитории
- [ ] `app/Services/` - сервисы
- [ ] `app/Views/` - Twig шаблоны

### Папка bin/
- [ ] `bin/migrate.php` - скрипт миграций

### Папка config/
- [ ] `config/analysis.core.yml`
- [ ] `config/lexicon/` - все txt файлы

### Папка public/
- [ ] `public/index.php` - точка входа
- [ ] `public/.htaccess` - правила rewrite
- [ ] `public/install.php` - установщик ⭐

### Папка storage/
- [ ] `storage/uploads/audio/.gitkeep`
- [ ] `storage/uploads/rubrics/.gitkeep`
- [ ] `storage/reports/.gitkeep`
- [ ] `storage/embeddings/.gitkeep`

### Папка vendor/
- [ ] `vendor/` - ВСЯ папка после `composer install`
  (Или запустите `composer install` на хостинге)

---

## НЕ загружайте

- ❌ `.env` - создастся установщиком
- ❌ `storage/app.sqlite` - создастся установщиком
- ❌ `storage/uploads/*` - кроме .gitkeep
- ❌ `.git/` - если не используете git на хостинге
- ❌ `.idea/`, `.vscode/` - IDE файлы

---

## После загрузки

### 1. Установите зависимости (если не загрузили vendor/)
```bash
composer install --no-dev --optimize-autoloader
```

### 2. Установите права
```bash
chmod -R 755 .
chmod -R 777 storage
```

### 3. Проверьте Document Root
Убедитесь что веб-сервер указывает на папку `public/`:
```
DocumentRoot /path/to/your/domain/public
```

### 4. Откройте установщик
```
https://yourdomain.com/install.php
```

---

## Быстрая проверка

Создайте этот файл на хостинге: `public/phpinfo.php`
```php
<?php phpinfo();
```

Откройте: `https://yourdomain.com/phpinfo.php`

Проверьте:
- ✅ PHP версия >= 8.1
- ✅ PDO enabled
- ✅ PDO SQLite enabled
- ✅ cURL enabled
- ✅ mbstring enabled
- ✅ max_execution_time >= 300

**Удалите phpinfo.php после проверки!**

---

## Минимальный набор для первого запуска

Если хотите загрузить только самое необходимое:

```
.htaccess
composer.json
composer.lock
app/
bin/
config/
public/
storage/
vendor/          ← Только если composer install сделан локально
```

Всё остальное установщик создаст автоматически.
