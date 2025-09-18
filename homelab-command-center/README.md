# HomeLab Command Center

Modern FastAPI-based monitoring and management platform for your HomeLab Kubernetes cluster.

## Features

- Real-time cluster monitoring
- Node health tracking
- Service health checks
- Smart alerting system
- Web dashboard
- GitOps integration

## Development

First, install [uv](https://docs.astral.sh/uv/):

```bash
# Install uv (if not already installed)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Navigate to the source directory
cd src/

# Install dependencies and run the development server
uv sync
uv run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Development Commands

```bash
# Install dependencies
uv sync

# Run the application
uv run uvicorn app.main:app --reload

# Run with specific Python version
uv run --python 3.11 uvicorn app.main:app --reload

# Add new dependencies
uv add <package-name>

# Add development dependencies
uv add --dev <package-name>

# Run tests
uv run pytest

# Format code
uv run black .

# Lint code
uv run ruff check .
```

## Docker Build

```bash
cd src/
docker build -t homelab-command-center .
docker run -p 8000:8000 homelab-command-center
```

## Project Structure

```
src/
├── pyproject.toml          # Project dependencies and config
├── app/                    # FastAPI application
│   ├── main.py            # Application entry point
│   ├── config.py          # Configuration management
│   ├── database.py        # Database models and connection
│   ├── services/          # Business logic
│   ├── routers/           # API endpoints
│   ├── models/            # Data models
│   └── workers/           # Background tasks
└── Dockerfile             # Container definition
```
# Trigger build
