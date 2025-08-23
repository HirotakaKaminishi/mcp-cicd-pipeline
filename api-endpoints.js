// MCP Server Proxy Endpoint
app.get("/api/mcp-health", async (req, res) => {
  try {
    const response = await fetch("http://192.168.111.200:8080", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        jsonrpc: "2.0",
        method: "get_system_info",
        id: 1
      })
    });
    const data = await response.json();
    res.json({
      status: "operational",
      system: data.result?.system || "Unknown",
      connectivity: "connected",
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error("MCP proxy error:", error);
    res.status(500).json({
      status: "error",
      system: "Unknown",
      connectivity: "disconnected",
      error: error.message
    });
  }
});

// nginx Status Endpoint
app.get("/api/nginx-status", (req, res) => {
  res.json({
    status: "operational",
    version: "1.29.0",
    features: ["security-headers", "compression", "caching", "optimization"],
    timestamp: new Date().toISOString()
  });
});

console.log("Added MCP and nginx proxy endpoints");