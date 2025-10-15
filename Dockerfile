# Multi-stage Dockerfile for FastAPI + React Application
# Ubuntu 22.04 base image

FROM ubuntu:22.04

# Prevent interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV NODE_ENV=production

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    wget \
    git \
    software-properties-common \
    ca-certificates \
    gnupg \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Python 3.11
RUN add-apt-repository -y ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 && \
    rm -rf /var/lib/apt/lists/*

# Install Node.js 20.x
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists/*

# Install MongoDB
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | \
    gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor && \
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | \
    tee /etc/apt/sources.list.d/mongodb-org-7.0.list && \
    apt-get update && \
    apt-get install -y mongodb-org && \
    rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /data/db /var/log/supervisor /app/backend /app/frontend

# Copy application files
COPY backend/ /app/backend/
COPY frontend/ /app/frontend/

# Install Python dependencies
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r /app/backend/requirements.txt

# Install Node.js dependencies
WORKDIR /app/frontend
RUN yarn install --frozen-lockfile --production=false

# Build frontend (optional, uncomment for production builds)
# RUN yarn build

# Copy supervisor configuration
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy environment files (will be overridden by docker-compose)
COPY backend/.env.example /app/backend/.env 2>/dev/null || true
COPY frontend/.env.example /app/frontend/.env 2>/dev/null || true

# Expose ports
EXPOSE 3000 8001 27017

# Set working directory back to /app
WORKDIR /app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8001/api/ || exit 1

# Start supervisor
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
