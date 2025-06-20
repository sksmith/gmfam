#!/bin/bash

# Setup script for local PostgreSQL databases

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up PostgreSQL databases for local development...${NC}"

# Database configuration
DB_USER="gmfam"
DB_PASS="gmfam123"
DB_HOST="localhost"
DB_PORT="5432"
DEV_DB="gmfam_dev"
TEST_DB="gmfam_test"

# Check if PostgreSQL is running
if ! pg_isready -h $DB_HOST -p $DB_PORT > /dev/null 2>&1; then
    echo -e "${YELLOW}PostgreSQL is not running on $DB_HOST:$DB_PORT${NC}"
    echo "Please ensure PostgreSQL is installed and running."
    echo ""
    echo "If using Docker Compose, run: docker-compose up -d postgres"
    exit 1
fi

echo -e "${GREEN}PostgreSQL is running${NC}"

# Create user if not exists
echo "Creating database user if not exists..."
PGPASSWORD=postgres psql -h $DB_HOST -p $DB_PORT -U postgres -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || \
PGPASSWORD=postgres psql -h $DB_HOST -p $DB_PORT -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS' CREATEDB;"

# Create development database
echo "Creating development database..."
PGPASSWORD=$DB_PASS createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $DEV_DB 2>/dev/null || \
echo -e "${YELLOW}Development database already exists${NC}"

# Create test database
echo "Creating test database..."
PGPASSWORD=$DB_PASS createdb -h $DB_HOST -p $DB_PORT -U $DB_USER $TEST_DB 2>/dev/null || \
echo -e "${YELLOW}Test database already exists${NC}"

# Grant all privileges
echo "Granting privileges..."
PGPASSWORD=postgres psql -h $DB_HOST -p $DB_PORT -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DEV_DB TO $DB_USER;" 2>/dev/null || true
PGPASSWORD=postgres psql -h $DB_HOST -p $DB_PORT -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $TEST_DB TO $DB_USER;" 2>/dev/null || true

echo -e "${GREEN}✅ Database setup complete!${NC}"
echo ""
echo "Development database: postgres://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DEV_DB?sslmode=disable"
echo "Test database: postgres://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$TEST_DB?sslmode=disable"
echo ""
echo "To start the application locally:"
echo "  1. With Docker Compose: docker-compose up"
echo "  2. Without Docker: make run"