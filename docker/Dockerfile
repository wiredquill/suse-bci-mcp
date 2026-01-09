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
