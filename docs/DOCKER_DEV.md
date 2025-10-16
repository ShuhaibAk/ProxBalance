# Local Docker Development Setup

This guide helps you run ProxBalance locally using Docker for testing changes before pushing to GitHub.

## Prerequisites

- Docker Desktop installed (Windows/Mac) or Docker + Docker Compose (Linux)
- Git

## Quick Start

1. **Start the development environment:**
   ```bash
   docker-compose -f docker-compose.dev.yml up --build
   ```

2. **Access the application:**
   - Web UI: http://localhost:5000
   - API: http://localhost:5000/api/health

3. **Stop the environment:**
   ```bash
   docker-compose -f docker-compose.dev.yml down
   ```

## Development Workflow

### Making Changes

The Docker setup uses volume mounts, so changes to these files are reflected immediately:
- `app.py` - Flask API (may need restart)
- `index.html` - Web UI (just refresh browser)
- `ai_provider.py` - AI provider logic
- `config.json` - Configuration

### Restarting After Python Changes

```bash
# Restart the container to reload Python code
docker-compose -f docker-compose.dev.yml restart
```

### Viewing Logs

```bash
# Follow logs in real-time
docker-compose -f docker-compose.dev.yml logs -f

# View specific service logs
docker-compose -f docker-compose.dev.yml logs -f proxbalance
```

### Testing API Endpoints

```bash
# Health check
curl http://localhost:5000/api/health

# Get configuration
curl http://localhost:5000/api/config

# Test AI models endpoint
curl -X POST http://localhost:5000/api/ai-models \
  -H "Content-Type: application/json" \
  -d '{"provider": "anthropic"}'
```

## Creating Test Data

Create a mock cache file for testing:

```bash
mkdir -p dev-cache
cat > dev-cache/cluster_cache.json << 'EOF'
{
  "collected_at": "2025-01-16T12:00:00",
  "nodes": [
    {
      "name": "pve1",
      "cpu_percent": 45.5,
      "mem_percent": 62.3,
      "load_1": 2.5,
      "status": "online"
    },
    {
      "name": "pve2",
      "cpu_percent": 35.2,
      "mem_percent": 55.1,
      "load_1": 1.8,
      "status": "online"
    }
  ],
  "guests": []
}
EOF
```

## Configuration for Testing

Create a test config file:

```bash
cat > config.json << 'EOF'
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "localhost",
  "ai_provider": "none",
  "ai_recommendations_enabled": false,
  "ai_config": {
    "openai": {
      "api_key": "",
      "model": "gpt-4"
    },
    "anthropic": {
      "api_key": "",
      "model": "claude-3-5-sonnet-20241022"
    },
    "local": {
      "base_url": "http://localhost:11434",
      "model": "llama2"
    }
  }
}
EOF
```

## Troubleshooting

### Container won't start
```bash
# Check logs for errors
docker-compose -f docker-compose.dev.yml logs

# Rebuild from scratch
docker-compose -f docker-compose.dev.yml down -v
docker-compose -f docker-compose.dev.yml up --build
```

### Port already in use
```bash
# Change port in docker-compose.dev.yml
ports:
  - "5001:5000"  # Use port 5001 instead
```

### Permission issues (Linux)
```bash
# Fix permissions on mounted directories
sudo chown -R $USER:$USER dev-cache/
```

## Testing the AI Model Selection Feature

1. **Start the container:**
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

2. **Open the web UI:** http://localhost:5000

3. **Test model fetching:**
   ```bash
   # Test OpenAI models endpoint (requires API key)
   curl -X POST http://localhost:5000/api/ai-models \
     -H "Content-Type: application/json" \
     -d '{"provider": "openai", "api_key": "sk-..."}'

   # Test Anthropic models (no API key needed, returns static list)
   curl -X POST http://localhost:5000/api/ai-models \
     -H "Content-Type: application/json" \
     -d '{"provider": "anthropic"}'

   # Test Local/Ollama models (requires Ollama running)
   curl -X POST http://localhost:5000/api/ai-models \
     -H "Content-Type: application/json" \
     -d '{"provider": "local", "base_url": "http://host.docker.internal:11434"}'
   ```

4. **Test in the UI:**
   - Click Settings icon
   - Enable AI recommendations
   - Select a provider
   - Click "Refresh Models" button
   - Try entering a custom model name

## Clean Up

```bash
# Stop and remove containers, networks
docker-compose -f docker-compose.dev.yml down

# Remove volumes too
docker-compose -f docker-compose.dev.yml down -v

# Remove test data
rm -rf dev-cache/
```

## Tips

- Use `docker-compose -f docker-compose.dev.yml up -d` to run in detached mode
- Use `docker-compose -f docker-compose.dev.yml exec proxbalance bash` to get a shell inside the container
- Check `docker ps` to see running containers
- Use `docker-compose -f docker-compose.dev.yml restart` after Python code changes
