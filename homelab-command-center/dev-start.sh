#!/bin/bash

# HomeLab Command Center - Development Startup Script

set -e

echo "🚀 Starting HomeLab Command Center Development Environment"

# Check if we're in the right directory
if [ ! -f "src/pyproject.toml" ]; then
    echo "❌ Error: Please run this script from the homelab-command-center directory"
    exit 1
fi

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo "📦 Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.cargo/env
fi

# Navigate to src directory
cd src

echo "📦 Installing dependencies..."
uv sync

echo "🗄️ Setting up database..."
# Check if PostgreSQL is running
if ! pg_isready -h localhost -p 5432 &> /dev/null; then
    echo "⚠️  PostgreSQL is not running. Please start PostgreSQL first:"
    echo "   brew services start postgresql  # macOS"
    echo "   sudo systemctl start postgresql  # Linux"
    echo "   Or use: docker-compose up -d postgres"
    exit 1
fi

# Check if Redis is running
if ! redis-cli ping &> /dev/null; then
    echo "⚠️  Redis is not running. Please start Redis first:"
    echo "   brew services start redis  # macOS"
    echo "   sudo systemctl start redis  # Linux"
    echo "   Or use: docker-compose up -d redis"
    exit 1
fi

# Initialize database if needed
echo "🔧 Initializing database..."
if [ ! -d "migrations" ]; then
    echo "📝 Creating initial migration..."
    python ../init_migrations.py
fi

# Apply migrations
echo "🔄 Applying database migrations..."
uv run alembic upgrade head

echo "✅ Setup complete!"
echo ""
echo "🎯 Available commands:"
echo "   Start API server:     uv run uvicorn app.main:app --reload"
echo "   Start Celery worker:  uv run celery -A app.workers.celery_app worker --loglevel=info"
echo "   Start Celery beat:    uv run celery -A app.workers.celery_app beat --loglevel=info"
echo "   Run tests:            uv run pytest"
echo "   Format code:          uv run black ."
echo "   Lint code:            uv run ruff check ."
echo ""
echo "🌐 Web dashboard will be available at: http://localhost:8000"
echo "📚 API documentation at: http://localhost:8000/docs"
echo ""
echo "🚀 Starting development server..."

# Start the development server
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
