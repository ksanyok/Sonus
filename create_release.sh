#!/bin/bash

# Скрипт для создания релиза на GitHub

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "❌ Укажите версию релиза"
    echo "Использование: ./create_release.sh 1.2"
    exit 1
fi

TAG="v${VERSION}"
RELEASE_NOTES="release_notes_v${VERSION}.md"
ZIP_FILE="dist/Sonus-v${VERSION}.zip"

echo "📦 Создание релиза ${TAG}"
echo ""

# Проверка что ZIP существует
if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Файл $ZIP_FILE не найден"
    echo "Сначала соберите приложение:"
    echo "  ./build_app.sh release"
    echo "  cd dist && zip -r Sonus-v${VERSION}.zip Sonus.app"
    exit 1
fi

# Проверка что release notes существуют
if [ ! -f "$RELEASE_NOTES" ]; then
    echo "⚠️  Файл $RELEASE_NOTES не найден"
    echo "Создаю стандартные release notes..."
    cat > "$RELEASE_NOTES" << EOF
## Что нового в версии ${VERSION}

### Новые функции
- Описание новых функций

### Улучшения
- Описание улучшений

### Исправления
- Исправленные ошибки

## Установка
1. Скачайте Sonus-v${VERSION}.zip
2. Распакуйте архив
3. Перетащите Sonus.app в папку Applications

## Обновление
Если у вас уже установлен Sonus - откройте приложение, оно предложит обновиться автоматически!
EOF
fi

echo "📄 Release notes:"
cat "$RELEASE_NOTES"
echo ""
echo "---"
echo ""

# Создание релиза
echo "🚀 Создание релиза на GitHub..."
gh release create "$TAG" \
  --title "Sonus v${VERSION}" \
  --notes-file "$RELEASE_NOTES" \
  "$ZIP_FILE"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Релиз ${TAG} успешно создан!"
    echo "🔗 https://github.com/ksanyok/Sonus/releases/tag/${TAG}"
    echo ""
    echo "📝 Не забудьте:"
    echo "  1. Проверить что релиз опубликован (не draft)"
    echo "  2. Протестировать автообновление"
    echo "  3. Обновить версию в Info.plist для следующего релиза"
else
    echo ""
    echo "❌ Ошибка при создании релиза"
    echo "Попробуйте создать релиз вручную:"
    echo "  https://github.com/ksanyok/Sonus/releases/new"
fi
