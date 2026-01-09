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
