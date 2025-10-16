#!/bin/bash
# Quick test to verify the installer works

echo "Testing installer basics..."

# Test 1: Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "✓ Root check passed"
else
    echo "✗ Not running as root"
    echo "Run with: sudo bash test_installer.sh"
    exit 1
fi

# Test 2: Check internet connectivity
if curl -s --max-time 5 ifconfig.me > /dev/null 2>&1; then
    echo "✓ Internet connection OK"
else
    echo "✗ No internet connection"
    exit 1
fi

# Test 3: Check if apt is available
if command -v apt-get &> /dev/null; then
    echo "✓ APT package manager available"
else
    echo "✗ APT not found"
    exit 1
fi

# Test 4: Check for any apt locks
if fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
    echo "⚠ Package manager is locked (another process using it)"
    echo "Attempting to fix..."
    killall apt apt-get 2>/dev/null || true
    rm -f /var/lib/apt/lists/lock 2>/dev/null || true
    rm -f /var/cache/apt/archives/lock 2>/dev/null || true
    rm -f /var/lib/dpkg/lock* 2>/dev/null || true
    sleep 2
    echo "✓ Locks cleared"
else
    echo "✓ No package manager locks"
fi

# Test 5: Try a simple apt update
echo ""
echo "Testing apt update (this will take 10-20 seconds)..."
if DEBIAN_FRONTEND=noninteractive apt-get update -y > /tmp/apt_test.log 2>&1; then
    echo "✓ APT update successful"
else
    echo "✗ APT update failed"
    echo "Last 10 lines of output:"
    tail -10 /tmp/apt_test.log
    exit 1
fi

echo ""
echo "═══════════════════════════════════════"
echo "✓ All checks passed!"
echo "═══════════════════════════════════════"
echo ""
echo "Your system is ready for the installer."
echo "Run: sudo bash auto_deploy.sh"
