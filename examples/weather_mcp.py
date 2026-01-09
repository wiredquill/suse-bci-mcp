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
