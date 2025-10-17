# Installing ProxBalance with AI Features

## Quick Install

To install ProxBalance with AI-powered migration recommendations:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/Pr0zak/ProxBalance/main/install.sh)"
```

### What the Installer Does:

1. Creates an LXC container with ProxBalance
2. Clones the main branch with all features including AI
3. Installs all dependencies including AI support (`requests` library)
4. Copies the AI-enabled index.html to /var/www/html/
5. Configures all services
6. Sets up Proxmox API authentication

## AI Features Included

ProxBalance includes:
- **OpenAI GPT-4 integration** - Cloud-based AI recommendations
- **Anthropic Claude 3.5 Sonnet** - Advanced AI analysis
- **Local LLM support** - Self-hosted models via Ollama
- **Enhanced web UI** - AI configuration in Settings menu
- **Comprehensive AI analysis** - Natural language explanations, risk scores, timing recommendations

## Post-Installation: Configure AI Provider

After installation, configure your AI provider:

### Option 1: Via Web Interface

1. Access ProxBalance at `http://<container-ip>`
2. Click the ⚙️ Settings icon (top right)
3. Scroll to "AI-Powered Recommendations"
4. Check "Enable AI-Enhanced Migration Recommendations"
5. Select your provider:
   - **OpenAI** - Requires API key from https://platform.openai.com/api-keys
   - **Anthropic** - Requires API key from https://console.anthropic.com/
   - **Local LLM** - Requires Ollama installation (see below)
6. Enter your API key or local URL
7. Select the model
8. Click "Save Settings"

### Option 2: Via Configuration File

SSH into the container and edit the config:

```bash
pct enter <ctid>
nano /opt/proxmox-balance-manager/config.json
```

Add AI configuration:

```json
{
  "collection_interval_minutes": 60,
  "ui_refresh_interval_minutes": 15,
  "proxmox_host": "10.0.0.1",
  "ai_provider": "anthropic",
  "ai_recommendations_enabled": true,
  "ai_config": {
    "openai": {
      "api_key": "",
      "model": "gpt-4"
    },
    "anthropic": {
      "api_key": "sk-ant-your-key-here",
      "model": "claude-3-5-sonnet-20241022"
    },
    "local": {
      "base_url": "http://localhost:11434",
      "model": "llama2"
    }
  }
}
```

Restart the service:
```bash
systemctl restart proxmox-balance
```

## Setting Up Local LLM (Ollama)

If you want to use a local LLM instead of cloud APIs:

### On ProxBalance Container

```bash
# Enter container
pct enter <ctid>

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a model (this will take a few minutes)
ollama pull llama2

# Start Ollama service (if not auto-started)
systemctl enable ollama
systemctl start ollama

# Verify it's running
curl http://localhost:11434/api/tags
```

### Configure ProxBalance to Use Local LLM

1. Go to Settings in web UI
2. Enable AI recommendations
3. Select "Local LLM (Ollama)"
4. Base URL: `http://localhost:11434`
5. Model: `llama2` (or `mistral`, `codellama`, etc.)
6. Save Settings

### Alternative: Run Ollama on Different Server

If you want to run Ollama on a different server:

```bash
# On the Ollama server
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve

# In ProxBalance config
# Base URL: http://<ollama-server-ip>:11434
```

## Using AI Recommendations

1. Access ProxBalance web interface
2. Wait for cluster data to be collected
3. Scroll to "🤖 AI-Enhanced Recommendations" section
4. Click "Get AI Analysis" button
5. Wait 10-30 seconds for AI analysis (longer for local LLMs)
6. Review recommendations with:
   - **Cluster Analysis** - Overall health summary
   - **Predicted Issues** - Future resource constraints
   - **Migration Recommendations** - AI-suggested moves with reasoning

Each recommendation shows:
- **Priority** (High/Medium/Low)
- **AI Reasoning** - Why this migration is recommended
- **Risk Score** - Migration risk percentage
- **Best Time** - Optimal execution timing
- **Expected Impact** - Predicted improvement

## ProxBalance Features

| Feature | Included |
|---------|----------|
| Basic recommendations | ✅ |
| Threshold-based alerts | ✅ |
| Anti-affinity rules | ✅ |
| **AI-powered analysis** | ✅ |
| **Natural language reasoning** | ✅ |
| **Risk assessment** | ✅ |
| **Predictive analytics** | ✅ |
| **Multi-dimensional optimization** | ✅ |
| **OpenAI integration** | ✅ |
| **Anthropic Claude integration** | ✅ |
| **Local LLM support** | ✅ |

## Cost Considerations

### OpenAI GPT-4
- **Cost**: ~$0.01-0.03 per AI analysis request
- **Speed**: 5-15 seconds
- **Quality**: Excellent reasoning and analysis

### Anthropic Claude 3.5 Sonnet
- **Cost**: ~$0.003-0.015 per AI analysis request
- **Speed**: 5-15 seconds
- **Quality**: Excellent reasoning, good cost/performance

### Local LLM (Ollama)
- **Cost**: Free (but requires compute resources)
- **Speed**: 10-60 seconds (depends on hardware)
- **Quality**: Good (model-dependent)
- **Resources**: ~4GB RAM, 2-4 CPU cores recommended

## Troubleshooting

### AI Analysis Button Not Showing

Check if AI is enabled:
```bash
pct exec <ctid> -- jq '.ai_recommendations_enabled' /opt/proxmox-balance-manager/config.json
```

Should return `true`. If not, enable it in Settings.

### "AI provider not configured" Error

Check provider and API key:
```bash
pct exec <ctid> -- jq '.ai_provider, .ai_config' /opt/proxmox-balance-manager/config.json
```

Ensure:
- `ai_provider` is set to `openai`, `anthropic`, or `local`
- API key is configured (for cloud providers)
- Local URL is reachable (for local provider)

### API Key Invalid

Test the API key manually:

**OpenAI:**
```bash
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer sk-your-key"
```

**Anthropic:**
```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: sk-ant-your-key" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":1024,"messages":[{"role":"user","content":"test"}]}'
```

**Ollama:**
```bash
curl http://localhost:11434/api/tags
```

### Slow AI Analysis

- **Cloud APIs**: Usually 5-15 seconds. If slower, check network latency.
- **Local LLM**: Can take 10-60 seconds depending on hardware. Consider:
  - Upgrading container resources (CPU/RAM)
  - Using a smaller model (e.g., `mistral` instead of `llama2`)
  - Running Ollama on dedicated hardware

### Check Logs

View API logs for AI errors:
```bash
pct exec <ctid> -- journalctl -u proxmox-balance -n 100 | grep -i ai
```

## Documentation

For more details, see:
- [AI Features Documentation](docs/AI_FEATURES.md)
- [Main Installation Guide](docs/INSTALL.md)
- [Troubleshooting Guide](docs/TROUBLESHOOTING.md)

---

**Questions or Issues?**
- GitHub Issues: https://github.com/Pr0zak/ProxBalance/issues
- Repository: https://github.com/Pr0zak/ProxBalance
