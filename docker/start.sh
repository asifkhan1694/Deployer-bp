#!/bin/bash
# Startup script for the container

set -e

echo "=========================================="
echo "Starting FastAPI + React Application"
echo "=========================================="

# Create .env files from templates if they don't exist
if [ ! -f /app/backend/.env ]; then
    echo "Creating backend .env from template..."
    cp /app/backend/.env.template /app/backend/.env
    
    # Replace with environment variables if provided
    if [ -n "$MONGO_URL" ]; then
        sed -i "s|MONGO_URL=.*|MONGO_URL=$MONGO_URL|" /app/backend/.env
    fi
    if [ -n "$DB_NAME" ]; then
        sed -i "s|DB_NAME=.*|DB_NAME=$DB_NAME|" /app/backend/.env
    fi
fi

if [ ! -f /app/frontend/.env ]; then
    echo "Creating frontend .env from template..."
    cp /app/frontend/.env.template /app/frontend/.env
    
    # Replace with environment variables if provided
    if [ -n "$BACKEND_URL" ]; then
        sed -i "s|REACT_APP_BACKEND_URL=.*|REACT_APP_BACKEND_URL=$BACKEND_URL|" /app/frontend/.env
    fi
fi

echo "Backend .env:"
cat /app/backend/.env

echo ""
echo "Frontend .env:"
cat /app/frontend/.env

echo ""
echo "Starting services with Supervisor..."
echo ""

# Start supervisor
exec /usr/bin/supervisord -n -c /etc/supervisor/supervisord.conf
