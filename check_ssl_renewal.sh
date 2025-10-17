#!/bin/bash
# Check SSL Certificate and Auto-Renewal Status

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "======================================"
echo "SSL CERTIFICATE STATUS"
echo "======================================"
echo ""

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo -e "${RED}✗ Certbot not installed${NC}"
    echo "Run enable_https.sh or deploy_with_https.sh first"
    exit 1
fi

echo -e "${GREEN}✓ Certbot installed${NC}"
echo ""

# List certificates
echo "Installed Certificates:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
certbot certificates 2>/dev/null

echo ""
echo "======================================"
echo "AUTO-RENEWAL STATUS"
echo "======================================"
echo ""

# Check if renewal script exists
if [ -f /usr/local/bin/renew-ssl.sh ]; then
    echo -e "${GREEN}✓ Renewal script exists${NC}"
    echo "  Location: /usr/local/bin/renew-ssl.sh"
else
    echo -e "${RED}✗ Renewal script not found${NC}"
    echo "  Run enable_https.sh to set it up"
fi

echo ""

# Check cron job
if crontab -l 2>/dev/null | grep -q "renew-ssl.sh"; then
    echo -e "${GREEN}✓ Cron job configured${NC}"
    echo "  Schedule:"
    crontab -l 2>/dev/null | grep "renew-ssl.sh"
else
    echo -e "${RED}✗ Cron job not found${NC}"
    echo "  Run enable_https.sh to set it up"
fi

echo ""

# Check renewal log
if [ -f /var/log/ssl-renewal.log ]; then
    echo -e "${GREEN}✓ Renewal log exists${NC}"
    echo "  Location: /var/log/ssl-renewal.log"
    echo ""
    echo "  Last 5 entries:"
    echo "  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    tail -5 /var/log/ssl-renewal.log 2>/dev/null | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠ Renewal log not created yet${NC}"
    echo "  Will be created on first renewal attempt"
fi

echo ""
echo "======================================"
echo "RENEWAL TEST (DRY RUN)"
echo "======================================"
echo ""
echo "Testing renewal process..."
echo ""

certbot renew --dry-run 2>&1 | tail -10

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Renewal test PASSED${NC}"
    echo "  Your certificates will auto-renew successfully!"
else
    echo ""
    echo -e "${RED}✗ Renewal test FAILED${NC}"
    echo "  Check the output above for errors"
fi

echo ""
echo "======================================"
echo "CERTIFICATE EXPIRATION"
echo "======================================"
echo ""

# Check expiration dates
for cert in /etc/letsencrypt/live/*/cert.pem; do
    if [ -f "$cert" ]; then
        DOMAIN=$(basename $(dirname $cert))
        EXPIRY=$(openssl x509 -enddate -noout -in "$cert" | cut -d= -f2)
        DAYS_LEFT=$(( ($(date -d "$EXPIRY" +%s) - $(date +%s)) / 86400 ))
        
        echo "Domain: $DOMAIN"
        echo "Expires: $EXPIRY"
        
        if [ $DAYS_LEFT -gt 30 ]; then
            echo -e "Status: ${GREEN}✓ Valid for $DAYS_LEFT days${NC}"
        elif [ $DAYS_LEFT -gt 7 ]; then
            echo -e "Status: ${YELLOW}⚠ Expires in $DAYS_LEFT days${NC}"
        else
            echo -e "Status: ${RED}✗ Expires in $DAYS_LEFT days - URGENT${NC}"
        fi
        echo ""
    fi
done

echo "======================================"
echo "SUMMARY"
echo "======================================"
echo ""

# Overall status
if [ -f /usr/local/bin/renew-ssl.sh ] && crontab -l 2>/dev/null | grep -q "renew-ssl.sh"; then
    echo -e "${GREEN}✅ Auto-renewal is properly configured!${NC}"
    echo ""
    echo "What happens automatically:"
    echo "  1. Certbot checks for renewal twice daily (3 AM & 3 PM)"
    echo "  2. If certificate is within 30 days of expiry, it renews"
    echo "  3. Container automatically restarts after renewal"
    echo "  4. All activity is logged to /var/log/ssl-renewal.log"
    echo ""
    echo "You don't need to do anything - it's fully automatic! 🎉"
else
    echo -e "${YELLOW}⚠ Auto-renewal is not fully configured${NC}"
    echo ""
    echo "To set it up, run:"
    echo "  sudo bash enable_https.sh"
fi

echo ""
echo "======================================"
echo "USEFUL COMMANDS"
echo "======================================"
echo ""
echo "Manual renewal:"
echo "  sudo certbot renew"
echo ""
echo "Test renewal:"
echo "  sudo certbot renew --dry-run"
echo ""
echo "View renewal logs:"
echo "  tail -f /var/log/ssl-renewal.log"
echo ""
echo "View certificates:"
echo "  sudo certbot certificates"
echo ""
echo "Check cron jobs:"
echo "  crontab -l | grep renew"
echo ""
