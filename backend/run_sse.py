
import os
import sys
import uvicorn
from starlette.applications import Starlette

# Ensure we can import from backend dir
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from mcp_server import mcp


def build_remote_app() -> Starlette:
    """
    Build a single ASGI app that serves both transports:
    - SSE endpoints: /sse and /messages
    - Streamable HTTP endpoint: /mcp
    """
    # IMPORTANT:
    # Streamable HTTP requires its own lifespan startup to initialize
    # the internal task group/session manager. Therefore we keep the
    # streamable app as the base app, then append SSE routes.
    app = mcp.streamable_http_app()
    sse_app = mcp.sse_app("/sse")
    app.router.routes.extend(sse_app.router.routes)
    return app


def main():
    """
    Run the Nocturne Memory MCP server in remote mode.
    It serves both SSE and Streamable HTTP on one port.
    """
    print("Initializing Nocturne Memory Remote MCP Server...")

    app = build_remote_app()

    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "0.0.0.0")

    print(f"Starting Remote MCP Server on http://{host}:{port}")
    print(f"SSE Endpoint: http://{host}:{port}/sse")
    print(f"MCP Endpoint: http://{host}:{port}/mcp")

    uvicorn.run(app, host=host, port=port)

if __name__ == "__main__":
    main()
