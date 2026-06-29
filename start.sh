#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Starting Full-Stack Flutter App${NC}"

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker is not running. Please start Docker Desktop first.${NC}"
    exit 1
fi

# Check if containers are running
if ! docker ps | grep -q "backend-db-1"; then
    echo -e "${YELLOW}🐳 Starting Docker containers...${NC}"
    cd /Users/sam/Desktop/Flutter\ Trenzy/backend
    docker-compose up -d
    
    # Wait for database
    echo -e "${YELLOW}⏳ Waiting for database to be ready...${NC}"
    while ! docker exec backend-db-1 pg_isready -U postgres > /dev/null 2>&1; do
        sleep 1
    done
    echo -e "${GREEN}✅ Database is ready!${NC}"
else
    echo -e "${GREEN}✅ Docker containers are already running${NC}"
fi

# Show container status
echo -e "${YELLOW}📊 Container Status:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "backend|db"

# Run Flutter
echo -e "${YELLOW}📱 Starting Flutter app...${NC}"
cd /Users/sam/Desktop/Flutter\ Trenzy
flutter run