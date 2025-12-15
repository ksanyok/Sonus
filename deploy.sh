#!/bin/bash
#
# Call Audit Proto - Deployment Script
# Автоматический деплой на production хостинг
#

set -e  # Exit on error

echo "🚀 Call Audit Proto - Deployment"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if composer is installed
if ! command -v composer &> /dev/null; then
    echo -e "${RED}❌ Composer not found!${NC}"
    echo "Install composer from https://getcomposer.org/"
    exit 1
fi

# Install dependencies
echo -e "${YELLOW}📦 Installing dependencies...${NC}"
composer install --no-dev --optimize-autoloader

# Create necessary directories
echo -e "${YELLOW}📁 Creating directories...${NC}"
mkdir -p storage/{uploads/{audio,rubrics},reports,embeddings}

# Set permissions
echo -e "${YELLOW}🔐 Setting permissions...${NC}"
chmod -R 755 .
chmod -R 777 storage

# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚙️  No .env file found${NC}"
    echo -e "Please run the web installer at: ${GREEN}https://yourdomain.com/install.php${NC}"
else
    echo -e "${GREEN}✅ .env file exists${NC}"
    
    # Run migrations if database doesn't exist
    if [ ! -f storage/app.sqlite ]; then
        echo -e "${YELLOW}🗄️  Creating database...${NC}"
        php bin/migrate.php
    fi
fi

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Upload files to your hosting"
echo "2. Open https://yourdomain.com/install.php"
echo "3. Follow the installation wizard"
echo "4. Delete install.php after setup"
echo ""
echo "Documentation: DEPLOY.md"
