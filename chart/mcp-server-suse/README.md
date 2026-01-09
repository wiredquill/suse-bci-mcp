# SUSE MCP Server (Weather Agent)

![SUSE](https://www.suse.com/assets/img/suse-white-logo-green.svg)

## Overview
This chart deploys a **Model Context Protocol (MCP)** server built on **SUSE BCI Python 3.11**. It is designed to host Python-based MCP tools that Large Language Models (LLMs) can access remotely.

## ⚠️ Prerequisites (Critical)
Before installing this chart, you **must** create a ConfigMap containing your tool logic. 
`kubectl create configmap mcp-user-code --from-file=user_mcp.py=weather_mcp.py`

## How to Connect
* **SSE Endpoint:** `http://<SERVICE-IP>:<PORT>/sse`
