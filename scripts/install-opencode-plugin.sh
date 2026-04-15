#!/usr/bin/env bash
# Install vibe-island plugin for OpenCode
# Usage: ./install-opencode-plugin.sh

set -e

PLUGIN_DIR="$HOME/.config/opencode/plugins"
PLUGIN_FILE="$PLUGIN_DIR/vibe-island.js"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_PLUGIN="$SCRIPT_DIR/../Sources/CLI/vibe-island-opencode-plugin.js"

echo "🔌 Vibe Island OpenCode Plugin Installer"
echo "========================================="

# 1. Check if opencode is installed
if ! command -v opencode &> /dev/null; then
    echo "❌ OpenCode is not installed."
    echo "   Install it first: https://github.com/anomalyco/opencode"
    exit 1
fi
echo "✅ OpenCode found: $(which opencode)"

# 2. Check if vibe-island CLI is available
VIBE_ISLAND_BIN=""
for candidate in \
    "$HOME/.vibe-island/bin/vibe-island" \
    "/Applications/VibeIsland.app/Contents/MacOS/vibe-island" \
    "$HOME/Applications/VibeIsland.app/Contents/MacOS/vibe-island" \
    "/usr/local/bin/vibe-island" \
    "/opt/homebrew/bin/vibe-island"; do
    if [ -f "$candidate" ]; then
        VIBE_ISLAND_BIN="$candidate"
        break
    fi
done

if [ -z "$VIBE_ISLAND_BIN" ]; then
    echo "⚠️  vibe-island CLI not found."
    echo "   The plugin will work once vibe-island is installed."
    echo "   Build CLI: cd Sources/CLI && swiftc ... -o vibe-island"
else
    echo "✅ vibe-island CLI found: $VIBE_ISLAND_BIN"
fi

# 3. Create plugin directory
mkdir -p "$PLUGIN_DIR"
echo "✅ Plugin directory: $PLUGIN_DIR"

# 4. Check if plugin already exists
if [ -f "$PLUGIN_FILE" ]; then
    # Check if it's our plugin
    if grep -q "vibe-island" "$PLUGIN_FILE" 2>/dev/null; then
        echo "⚠️  Plugin already installed."
        read -p "   Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "   Skipped."
            exit 0
        fi
        echo "   Backing up existing plugin..."
        cp "$PLUGIN_FILE" "$PLUGIN_FILE.bak.$(date +%Y%m%d%H%M%S)"
    else
        echo "⚠️  A different plugin exists at $PLUGIN_FILE"
        echo "   Please rename or remove it before installing vibe-island plugin."
        exit 1
    fi
fi

# 5. Copy plugin
if [ -f "$SOURCE_PLUGIN" ]; then
    cp "$SOURCE_PLUGIN" "$PLUGIN_FILE"
    echo "✅ Plugin copied from source"
else
    # Fallback: create a minimal plugin inline
    echo "⚠️  Source plugin not found, creating minimal version..."
    cat > "$PLUGIN_FILE" << 'INLINE_PLUGIN'
// vibe-island plugin for opencode (minimal version)
import { execFileSync } from "child_process";
import { existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const TOOL_NAME_MAP = {
  bash: "Bash", read: "Read", edit: "Edit", write: "Write",
  grep: "Grep", glob: "Glob", webfetch: "WebFetch", websearch: "WebSearch", task: "Task",
};
const KEY_MAP = { filePath: "file_path" };

function findHookBinary() {
  const candidates = [
    join(homedir(), ".vibe-island/bin/vibe-island"),
    "/Applications/VibeIsland.app/Contents/MacOS/vibe-island",
    join(homedir(), "Applications/VibeIsland.app/Contents/MacOS/vibe-island"),
    "/usr/local/bin/vibe-island", "/opt/homebrew/bin/vibe-island",
  ];
  for (const p of candidates) { if (existsSync(p)) return p; }
  return null;
}

function normalizeTool(name) {
  if (!name) return null;
  const lower = name.toLowerCase();
  if (TOOL_NAME_MAP[lower]) return TOOL_NAME_MAP[lower];
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function normalizeToolInput(args) {
  if (!args || typeof args !== "object") return args;
  const result = {};
  for (const [k, v] of Object.entries(args)) {
    const mapped = KEY_MAP[k] || k;
    if (typeof v === "string") result[mapped] = v;
  }
  return result;
}

function callHook(hookBin, eventName, payload) {
  try {
    const json = JSON.stringify({ ...payload, hook_event_name: eventName });
    execFileSync(hookBin, ["hook", eventName], { input: json, timeout: 5000, stdio: ["pipe", "pipe", "pipe"] });
  } catch { /* Best-effort — never crash opencode */ }
}

export const vibeIsland = async ({ directory }) => {
  const hookBin = findHookBinary();
  if (!hookBin) return {};
  const sessionId = `opencode-${process.pid}`;
  let sessionName = null;
  function basePayload() {
    return { session_id: sessionId, cwd: directory, source: "opencode", ...(sessionName && { session_name: sessionName }) };
  }
  callHook(hookBin, "SessionStart", basePayload());
  return {
    event: async ({ event }) => {
      if (!event || !event.type) return;
      switch (event.type) {
        case "session.created": callHook(hookBin, "SessionStart", basePayload()); break;
        case "session.idle": callHook(hookBin, "Stop", basePayload()); break;
        case "session.error": {
          const errMsg = event.error?.message || event.message || null;
          callHook(hookBin, "SessionError", { ...basePayload(), ...(errMsg && { error: errMsg }), ...(event.message && { message: event.message }) });
          break;
        }
        case "session.compacted": callHook(hookBin, "PostCompact", basePayload()); break;
        case "session.updated": { const t = event.properties?.info?.title; if (t) sessionName = t; break; }
      }
    },
    "chat.message": async (_input, output) => {
      const prompt = output?.message?.content || output?.content || (typeof output?.text === "string" ? output.text : null);
      callHook(hookBin, "UserPromptSubmit", { ...basePayload(), ...(prompt && { prompt }) });
    },
    "tool.execute.before": async (_input, output) => {
      const tool = normalizeTool(output?.tool || _input?.tool);
      const args = output?.args || _input?.args;
      callHook(hookBin, "PreToolUse", { ...basePayload(), ...(tool && { tool_name: tool }), ...(args && { tool_input: normalizeToolInput(args) }) });
    },
    "tool.execute.after": async () => { callHook(hookBin, "PostToolUse", basePayload()); },
    "permission.ask": async (input) => {
      const tool = normalizeTool(input?.tool);
      const args = input?.args;
      callHook(hookBin, "PermissionRequest", { ...basePayload(), ...(tool && { tool_name: tool }), ...(input?.title && { title: input.title }), ...(args && { tool_input: normalizeToolInput(args) }) });
    },
    "experimental.session.compacting": async () => { callHook(hookBin, "PreCompact", basePayload()); },
  };
};
INLINE_PLUGIN
    echo "✅ Minimal plugin created"
fi

# 6. Verify
if [ -f "$PLUGIN_FILE" ]; then
    echo ""
    echo "========================================="
    echo "🎉 Plugin installed successfully!"
    echo ""
    echo "   Location: $PLUGIN_FILE"
    echo ""
    echo "   Next steps:"
    echo "   1. Restart OpenCode (if running)"
    echo "   2. Start a new OpenCode session"
    echo "   3. The plugin will auto-connect to vibe-island"
    echo ""
    echo "   To uninstall:"
    echo "   rm $PLUGIN_FILE"
    echo "========================================="
else
    echo "❌ Installation failed."
    exit 1
fi
