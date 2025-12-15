# 🚀 Быстрый старт Call Audit Proto

## Шаг 1: Установка зависимостей

```bash
# Установите Composer зависимости
composer install

# Скопируйте .env и настройте OpenAI API key
cp .env.example .env
# Отредактируйте .env и добавьте ваш OPENAI_API_KEY
```

## Шаг 2: Инициализация базы данных

```bash
# Создайте БД и таблицы
php bin/migrate.php

# Создайте директории
mkdir -p storage/uploads/{audio,rubrics}
mkdir -p storage/{reports,embeddings}
chmod -R 755 storage
```

## Шаг 3: Запуск

```bash
# Запустите встроенный сервер PHP
php -S localhost:8000 -t public
```

Откройте: http://localhost:8000

## Шаг 4: Первый анализ

1. Выберите MP3/WAV файл
2. Нажмите "Анализировать"
3. Дождитесь результатов
4. Экспортируйте отчёт

## Готово! 🎉

### API Example

```bash
curl -X POST http://localhost:8000/api/calls \
  -F "audio=@your-call.mp3" \
  -F "lang=auto"
```

### Troubleshooting

**Ошибка: "Class not found"**
→ Запустите `composer install`

**Ошибка: "OpenAI API key not set"**
→ Проверьте `.env` файл

**Ошибка: "Permission denied"**
→ Запустите `chmod -R 755 storage`

### Требования

- PHP 8.1+
- Composer
- ffmpeg
- OpenAI API key

Happy analyzing! 📞✨
