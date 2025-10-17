#!/bin/bash
# Quick container diagnostics script

echo "======================================"
echo "CONTAINER DIAGNOSTICS"
echo "======================================"
echo ""

# Check if container is running
echo "1. Container Status:"
docker ps --filter name=cloudvoro-adops

echo ""
echo "2. Services inside container:"
docker exec cloudvoro-adops supervisorctl status

echo ""
echo "3. Backend logs (last 20 lines):"
docker exec cloudvoro-adops tail -20 /var/log/supervisor/backend.out.log

echo ""
echo "4. Frontend logs (last 20 lines):"
docker exec cloudvoro-adops tail -20 /var/log/supervisor/frontend.out.log

echo ""
echo "5. Nginx logs (last 10 lines):"
docker exec cloudvoro-adops tail -10 /var/log/supervisor/nginx.out.log

echo ""
echo "6. Test backend from inside:"
docker exec cloudvoro-adops curl -s http://localhost:8001/api/ | head -5

echo ""
echo "7. Test frontend from inside:"
docker exec cloudvoro-adops curl -s http://localhost:3000 | head -10

echo ""
echo "8. Environment files:"
echo "Backend .env:"
docker exec cloudvoro-adops cat /app/backend/.env

echo ""
echo "Frontend .env:"
docker exec cloudvoro-adops cat /app/frontend/.env

echo ""
echo "======================================"
echo "If frontend shows errors, check:"
echo "  docker exec cloudvoro-adops tail -50 /var/log/supervisor/frontend.err.log"
echo ""
