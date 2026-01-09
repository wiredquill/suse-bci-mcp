# SUSE MCP Server Repository

* `docker/`: Build context for the generic base image.
* `chart/`: Helm chart for Rancher.
* `examples/`: Sample Python MCP tools.

## Quick Start
1. `cd docker && docker build -t your-repo/mcp:v1 .`
2. `kubectl create configmap mcp-user-code --from-file=user_mcp.py=examples/weather_mcp.py`
3. Deploy the chart.
