#!/bin/bash
# Create a deployment package tarball

PACKAGE_NAME="fastapi-react-deployment-package"
PACKAGE_DIR="/tmp/$PACKAGE_NAME"
OUTPUT_FILE="$PACKAGE_NAME.tar.gz"

echo "================================================"
echo "Creating Deployment Package"
echo "================================================"

# Create package directory
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy deployment scripts
echo "Copying deployment scripts..."
cp install.sh "$PACKAGE_DIR/"
cp deploy.sh "$PACKAGE_DIR/"
cp setup_supervisor.sh "$PACKAGE_DIR/"
cp quick_start.sh "$PACKAGE_DIR/"
cp health_check.sh "$PACKAGE_DIR/"
cp logs.sh "$PACKAGE_DIR/"
cp .env.example "$PACKAGE_DIR/"

# Copy Docker files
echo "Copying Docker configuration..."
mkdir -p "$PACKAGE_DIR/docker"
cp Dockerfile "$PACKAGE_DIR/"
cp docker-compose.yml "$PACKAGE_DIR/"
cp docker/supervisord.conf "$PACKAGE_DIR/docker/"
cp docker/nginx.conf "$PACKAGE_DIR/docker/"

# Copy documentation
echo "Copying documentation..."
cp README_DEPLOYMENT.md "$PACKAGE_DIR/"
cp DEPLOYMENT_PACKAGE_README.md "$PACKAGE_DIR/README.md"

# Make scripts executable
chmod +x "$PACKAGE_DIR"/*.sh

# Create tarball
echo "Creating tarball..."
cd /tmp
tar -czf "$OUTPUT_FILE" "$PACKAGE_NAME"

# Move to current directory
mv "$OUTPUT_FILE" /app/

# Cleanup
rm -rf "$PACKAGE_DIR"

echo ""
echo "================================================"
echo "✅ Package created successfully!"
echo "================================================"
echo ""
echo "Package location: /app/$OUTPUT_FILE"
echo "Package size: $(du -h /app/$OUTPUT_FILE | cut -f1)"
echo ""
echo "To extract on target server:"
echo "  tar -xzf $OUTPUT_FILE"
echo "  cd $PACKAGE_NAME"
echo "  sudo ./quick_start.sh"
echo ""
