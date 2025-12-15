# 📦 Развёртывание Call Audit Proto на хостинге

## Быстрый старт

### 1. Загрузка файлов

Загрузите все файлы проекта на ваш хостинг через FTP/SFTP в корневую директорию сайта.

### 2. Установка зависимостей

Подключитесь к хостингу по SSH и выполните:

```bash
cd /path/to/your/domain
composer install --no-dev --optimize-autoloader
```

Если SSH недоступен, загрузите папку `vendor/` с локальной машины после выполнения `composer install`.

### 3. Настройка прав доступа

```bash
chmod -R 755 .
chmod -R 777 storage
```

### 4. Запуск установщика

Откройте в браузере:
```
https://yourdomain.com/install.php
```

Установщик автоматически:
- ✅ Проверит системные требования
- ✅ Запросит OpenAI API ключ
- ✅ Создаст конфигурацию (.env)
- ✅ Инициализирует базу данных
- ✅ Настроит структуру директорий

### 5. Безопасность

После успешной установки:
```bash
rm public/install.php
```

## Требования хостинга

### Обязательные
- ✅ PHP 8.1 или выше
- ✅ PDO + PDO SQLite
- ✅ cURL extension
- ✅ Mbstring extension
- ✅ JSON extension
- ✅ Composer
- ✅ FFmpeg (для аудио анализа)

### Рекомендуемые
- 📊 Минимум 512 MB RAM
- 💾 Минимум 1 GB дискового пространства
- ⏱️ PHP max_execution_time >= 300 секунд
- 📤 PHP upload_max_filesize >= 50 MB
- 🔒 HTTPS сертификат

## Структура проекта

```
yourdomain.com/
├── .htaccess              # Redirect to public/
├── .env                   # Конфигурация (создаётся установщиком)
├── composer.json
├── app/                   # Приложение (PHP код)
├── config/                # Конфигурационные файлы
├── storage/               # Загрузки, БД, отчёты
│   ├── app.sqlite        # База данных
│   ├── uploads/          # Аудио файлы
│   └── reports/          # Экспорты
├── public/               # Публичная директория (DocumentRoot)
│   ├── index.php         # Точка входа
│   └── install.php       # Установщик
└── vendor/               # Composer зависимости
```

## Настройка веб-сервера

### Apache

Убедитесь что `mod_rewrite` включен:
```apache
<VirtualHost *:80>
    ServerName yourdomain.com
    DocumentRoot /path/to/project/public
    
    <Directory /path/to/project/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

Файл `.htaccess` уже настроен в проекте.

### Nginx

```nginx
server {
    listen 80;
    server_name yourdomain.com;
    root /path/to/project/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

## Переменные окружения (.env)

Установщик создаёт `.env` автоматически. Для ручной настройки:

```env
# Application
APP_ENV=production
APP_URL=https://yourdomain.com
APP_DEBUG=false
TZ=Europe/Kyiv

# Database
DB_PATH=/absolute/path/to/storage/app.sqlite

# OpenAI (обязательно!)
OPENAI_API_KEY=sk-proj-...

# Uploads
MAX_UPLOAD_SIZE_MB=50

# FFmpeg
FFMPEG_PATH=/usr/bin/ffmpeg
```

## Проверка установки

После установки откройте:
```
https://yourdomain.com/healthz
```

Должен вернуть:
```json
{
  "status": "ok",
  "timestamp": "2025-10-24T12:00:00+03:00",
  "service": "call-audit-proto"
}
```

## Troubleshooting

### Ошибка 500

Проверьте логи PHP:
```bash
tail -f /var/log/apache2/error.log
# или
tail -f /var/log/nginx/error.log
```

### База данных не создаётся

Проверьте права:
```bash
ls -la storage/
chmod 777 storage
```

### OpenAI API не работает

1. Проверьте баланс на https://platform.openai.com/
2. Убедитесь что ключ правильный в `.env`
3. Проверьте что cURL работает: `php -m | grep curl`

### Timeout при анализе

Увеличьте лимиты в `php.ini`:
```ini
max_execution_time = 300
upload_max_filesize = 50M
post_max_size = 50M
```

## Обновление

1. Сделайте бэкап БД:
```bash
cp storage/app.sqlite storage/app.sqlite.backup
```

2. Загрузите новые файлы
3. Выполните миграции (если есть):
```bash
php bin/migrate.php
```

## Поддержка

- 📧 Email: support@example.com
- 📝 Документация: https://github.com/yourusername/call-audit-proto
- 🐛 Issues: https://github.com/yourusername/call-audit-proto/issues

## Лицензия

MIT License - используйте свободно!
