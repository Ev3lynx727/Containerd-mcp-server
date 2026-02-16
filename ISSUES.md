Investigation Results: Containerd-mcp-server
Finding: Fabric MCP Server is MISSING
Status: ❌ Not actually implemented
What I Found
1. README mentions Fabric MCP:
   - Listed as "Included Server" with port 3004
   - Described as "Python-based MCP server for Microsoft Fabric operations"
2. But actual files DON'T EXIST:
      /home/ev3lynx/Project/Containerd-mcp-server/mcp-servers/
   ├── markdownlint-mcp-server.js
   ├── ruff/
   └── shellcheck/
   
   ❌ NO ms-fabric-mcp-server directory
   ❌ NO fabric-related files
   
3. Current MCP Servers in that repo:
   - ✅ shellcheck (shell script linting)
   - ✅ ruff (Python linting/formatting)
   - ✅ markdownlint (Markdown linting)
   - ❌ ms-fabric-mcp-server (NOT IMPLEMENTED)
Conclusion
The fabric-mcp server is documented in the README but not actually built yet. This explains why it's missing from your opencode.jsonc configuration - there's nothing to configure!
Options:
Option A: Create the fabric-mcp server implementation
- Build a Python-based MCP server for Microsoft Fabric integration
- Add it to the Containerd-mcp-server repository
- Then configure it in opencode.jsonc
Option B: Use the existing fabric-mcp PyPI package
- Install: pip install fabric-mcp
- Run: fabric-mcp --stdio
- Connect to running Fabric instance (fabric --serve)
- Add configuration to opencode.jsonc
Option C: Wait for the repository owner to implement it
Which option would you like to proceed with?