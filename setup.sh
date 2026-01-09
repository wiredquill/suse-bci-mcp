#!/bin/bash

# Define root directory
ROOT_DIR="mcp-suse-repo"
mkdir -p "$ROOT_DIR"
mkdir -p "$ROOT_DIR/docker"
mkdir -p "$ROOT_DIR/examples"
mkdir -p "$ROOT_DIR/chart/mcp-server-suse/templates"

echo "📂 Creating directory structure in ./$ROOT_DIR..."

# --- 1. Dockerfile ---
cat > "$ROOT_DIR/docker/Dockerfile" <<EOF
# Base Image: SUSE Linux Enterprise Base Container Image for Python 3.11
FROM registry.suse.com/bci/python:3.11

# Metadata
LABEL maintainer="Expert Panel"
LABEL description="Universal MCP Server on SUSE BCI"

# Create a non-root user for security
RUN useradd -m -u 1000 mcpuser

# Set working directory
WORKDIR /app

# Install system dependencies
RUN zypper install -y git && zypper clean -a

# Install Python MCP dependencies (including httpx for the weather tool)
RUN pip install --no-cache-dir "mcp[cli,sse]" uvicorn starlette httpx

# Copy the generic wrapper
COPY server_wrapper.py /app/server_wrapper.py

# Create a directory for user code
RUN mkdir /app/user_code && chown -R mcpuser:mcpuser /app

# Switch to non-root user
USER 1000

# Expose the SSE port
EXPOSE 8080

# Environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONPATH=/app

# Run the wrapper
CMD ["python", "/app/server_wrapper.py"]
EOF
echo "✅ Created docker/Dockerfile"

# --- 2. Server Wrapper ---
cat > "$ROOT_DIR/docker/server_wrapper.py" <<EOF
import os
import sys
import uvicorn
from mcp.server.fastmcp import FastMCP

# Initialize FastMCP with SSE enabled
server_name = os.getenv("MCP_SERVER_NAME", "Generic-MCP-Server")
mcp = FastMCP(server_name)

# --- DYNAMIC LOADER ---
try:
    sys.path.append("/app/user_code")
    import user_mcp
    
    # Check if the user code has a 'register' function and call it
    if hasattr(user_mcp, 'register'):
        user_mcp.register(mcp)
        print(f"Registered tools from user_mcp")
    else:
        print("Module user_mcp loaded, but no 'register(mcp)' function found.")

except ImportError:
    print("No user_mcp module found. Running in default echo mode.")
    
    @mcp.tool()
    def echo_tool(text: str) -> str:
        """A default tool to prove the server is running."""
        return f"Echo from SUSE BCI: {text}"

if __name__ == "__main__":
    # Run the server on port 8080
    mcp.run(transport="sse", host="0.0.0.0", port=8080)
EOF
echo "✅ Created docker/server_wrapper.py"

# --- 3. Weather Example ---
cat > "$ROOT_DIR/examples/weather_mcp.py" <<EOF
import httpx
from mcp.server.fastmcp import FastMCP

def register(mcp: FastMCP):
    
    @mcp.tool()
    async def get_weather(city: str) -> str:
        """
        Get the current weather for a specific city using wttr.in.
        Returns a concise string like 'London: ⛅️ +13°C'.
        """
        url = f"https://wttr.in/{city}?format=3"
        headers = {"User-Agent": "MCP-Weather-Agent/1.0"}
        
        async with httpx.AsyncClient() as client:
            try:
                response = await client.get(url, headers=headers, timeout=10.0)
                response.raise_for_status()
                return response.text.strip()
            except httpx.HTTPStatusError as e:
                return f"Error fetching weather: {e.response.status_code}"
            except Exception as e:
                return f"Connection error: {str(e)}"
EOF
echo "✅ Created examples/weather_mcp.py"

# --- 4. Chart.yaml ---
cat > "$ROOT_DIR/chart/mcp-server-suse/Chart.yaml" <<EOF
apiVersion: v2
name: mcp-server-suse
description: A generic MCP Server deployment based on SUSE BCI
type: application
version: 0.1.0
appVersion: "1.0.0"
EOF
echo "✅ Created chart/Chart.yaml"

# --- 5. values.yaml ---
cat > "$ROOT_DIR/chart/mcp-server-suse/values.yaml" <<EOF
replicaCount: 1

image:
  repository: registry.example.com/mcp-suse # CHANGE THIS TO YOUR REPO
  pullPolicy: IfNotPresent
  tag: "v1"

service:
  type: ClusterIP
  port: 80

storage:
  enabled: false
  size: 1Gi
  storageClass: ""
  mountPath: "/app/data"

env:
  mcpServerName: "Rancher-MCP"
EOF
echo "✅ Created chart/values.yaml"

# --- 6. questions.yaml ---
cat > "$ROOT_DIR/chart/mcp-server-suse/questions.yaml" <<EOF
rancher_min_version: 2.6.0
questions:
- variable: service.type
  label: "Service Type"
  description: "How should this MCP server be exposed to the network?"
  type: enum
  options:
    - "ClusterIP"
    - "NodePort"
    - "LoadBalancer"
  default: "ClusterIP"
  group: "Networking"

- variable: storage.enabled
  label: "Enable Persistent Storage"
  type: boolean
  default: false
  group: "Storage"

- variable: storage.storageClass
  label: "Storage Class"
  type: storageclass
  default: ""
  group: "Storage"
  show_if: "storage.enabled=true"

- variable: storage.size
  label: "Volume Size"
  type: string
  default: "1Gi"
  group: "Storage"
  show_if: "storage.enabled=true"

- variable: env.mcpServerName
  label: "MCP Server Name"
  type: string
  default: "Suse-MCP-Agent"
  group: "Application Settings"
EOF
echo "✅ Created chart/questions.yaml"

# --- 7. App README ---
cat > "$ROOT_DIR/chart/mcp-server-suse/README.md" <<EOF
# SUSE MCP Server (Weather Agent)

![SUSE](https://www.suse.com/assets/img/suse-white-logo-green.svg)

## Overview
This chart deploys a **Model Context Protocol (MCP)** server built on **SUSE BCI Python 3.11**. It is designed to host Python-based MCP tools that Large Language Models (LLMs) can access remotely.

## ⚠️ Prerequisites (Critical)
Before installing this chart, you **must** create a ConfigMap containing your tool logic. 
\`kubectl create configmap mcp-user-code --from-file=user_mcp.py=weather_mcp.py\`

## How to Connect
* **SSE Endpoint:** \`http://<SERVICE-IP>:<PORT>/sse\`
EOF
echo "✅ Created chart/README.md"

# --- 8. .helmignore ---
cat > "$ROOT_DIR/chart/mcp-server-suse/.helmignore" <<EOF
.DS_Store
.git/
.gitignore
*.swp
weather_mcp.py
user_mcp.py
EOF
echo "✅ Created chart/.helmignore"

# --- 9. Deployment Template ---
cat > "$ROOT_DIR/chart/mcp-server-suse/templates/deployment.yaml" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "mcp-server.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ include "mcp-server.name" . }}
  template:
    metadata:
      labels:
        app: {{ include "mcp-server.name" . }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: sse
              containerPort: 8080
              protocol: TCP
          env:
            - name: MCP_SERVER_NAME
              value: {{ .Values.env.mcpServerName | quote }}
          volumeMounts:
            - name: code-volume
              mountPath: "/app/user_code"
              readOnly: true
            {{- if .Values.storage.enabled }}
            - name: data-volume
              mountPath: {{ .Values.storage.mountPath }}
            {{- end }}
      volumes:
        - name: code-volume
          configMap:
            name: mcp-user-code
            optional: true
        {{- if .Values.storage.enabled }}
        - name: data-volume
          persistentVolumeClaim:
            claimName: {{ include "mcp-server.fullname" . }}-pvc
        {{- end }}
EOF
echo "✅ Created templates/deployment.yaml"

# --- 10. Service Template ---
cat > "$ROOT_DIR/chart/mcp-server-suse/templates/service.yaml" <<EOF
apiVersion: v1
kind: Service
metadata:
  name: {{ include "mcp-server.fullname" . }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 8080
      protocol: TCP
      name: http
  selector:
    app: {{ include "mcp-server.name" . }}
EOF
echo "✅ Created templates/service.yaml"

# --- 11. PVC Template ---
cat > "$ROOT_DIR/chart/mcp-server-suse/templates/pvc.yaml" <<EOF
{{- if .Values.storage.enabled -}}
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {{ include "mcp-server.fullname" . }}-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: {{ .Values.storage.size }}
  {{- if .Values.storage.storageClass }}
  storageClassName: {{ .Values.storage.storageClass }}
  {{- end }}
{{- end -}}
EOF
echo "✅ Created templates/pvc.yaml"

# --- 12. Helpers Template ---
cat > "$ROOT_DIR/chart/mcp-server-suse/templates/_helpers.tpl" <<EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "mcp-server.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "mcp-server.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
EOF
echo "✅ Created templates/_helpers.tpl"

# --- 13. Root README ---
cat > "$ROOT_DIR/README.md" <<EOF
# SUSE MCP Server Repository

* \`docker/\`: Build context for the generic base image.
* \`chart/\`: Helm chart for Rancher.
* \`examples/\`: Sample Python MCP tools.

## Quick Start
1. \`cd docker && docker build -t your-repo/mcp:v1 .\`
2. \`kubectl create configmap mcp-user-code --from-file=user_mcp.py=examples/weather_mcp.py\`
3. Deploy the chart.
EOF
echo "✅ Created root README.md"

echo "🎉 All files created in directory: ./$ROOT_DIR"
