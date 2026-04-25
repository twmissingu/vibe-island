// vibe-island plugin for opencode
// Translates opencode events to vibe-island-hook calls.
// Zero dependencies — only Node builtins.
//
// Installation:
//   Copy this file to ~/.config/opencode/plugins/vibe-island.js
//
// Uninstall:
//   rm ~/.config/opencode/plugins/vibe-island.js

import { execFileSync } from "child_process";
import { existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

// ---------------------------------------------------------------------------
// Tool name normalization: opencode lowercase → Claude Code PascalCase
// ---------------------------------------------------------------------------
const TOOL_NAME_MAP = {
  bash: "Bash",
  read: "Read",
  edit: "Edit",
  write: "Write",
  grep: "Grep",
  glob: "Glob",
  webfetch: "WebFetch",
  websearch: "WebSearch",
  task: "Task",
};

// opencode sends camelCase args, vibe-island expects snake_case
const KEY_MAP = { filePath: "file_path" };

// ---------------------------------------------------------------------------
// Locate the vibe-island CLI binary
// ---------------------------------------------------------------------------
function findHookBinary() {
  const candidates = [
    join(homedir(), ".vibe-island/bin/vibe-island"),
    "/Applications/VibeIsland.app/Contents/MacOS/vibe-island",
    join(homedir(), "Applications/VibeIsland.app/Contents/MacOS/vibe-island"),
    // Fallback: search PATH
    "/usr/local/bin/vibe-island",
    "/opt/homebrew/bin/vibe-island",
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Normalizers
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// Call vibe-island CLI
// ---------------------------------------------------------------------------
function callHook(hookBin, eventName, payload) {
  try {
    const json = JSON.stringify({ ...payload, hook_event_name: eventName });
    // Note: "hook" is a subcommand of vibe-island
    execFileSync(hookBin, ["hook", eventName], {
      input: json,
      timeout: 5000,
      stdio: ["pipe", "pipe", "pipe"],
    });
  } catch {
    // Best-effort — never crash opencode
  }
}

// ---------------------------------------------------------------------------
// Plugin entry point
// ---------------------------------------------------------------------------
export const vibeIsland = async ({ directory }) => {
  const hookBin = findHookBinary();
  if (!hookBin) return {};

  const sessionId = `opencode-${process.pid}`;
  let sessionName = null;
  let modelContextLimit = 200000; // default to 200K
  
  function basePayload() {
    return {
      session_id: sessionId,
      cwd: directory,
      source: "opencode",
      ...(sessionName && { session_name: sessionName }),
    };
  }

  // Fire SessionStart immediately on plugin load
  callHook(hookBin, "SessionStart", basePayload());

  return {
    // ---- Chat params: capture model context limit ----
    "chat.params": async ({ params }) => {
      if (params?.model?.limit?.context) {
        modelContextLimit = params.model.limit.context;
      }
    },

    // ---- Session lifecycle events ----
    event: async ({ event }) => {
      if (!event || !event.type) return;

      switch (event.type) {
        case "session.created":
          // Reset model context limit for new session
          modelContextLimit = 200000;
          callHook(hookBin, "SessionStart", basePayload());
          break;

        case "session.idle":
          callHook(hookBin, "Stop", basePayload());
          break;

        case "session.error": {
          const errMsg = event.error?.message || event.message || null;
          callHook(hookBin, "SessionError", {
            ...basePayload(),
            ...(errMsg && { error: errMsg }),
            ...(event.message && { message: event.message }),
          });
          break;
        }

        case "session.status": {
          const type =
            event.properties?.status?.type ||
            event.properties?.type ||
            event.status?.type;
          if (type === "retry") {
            callHook(hookBin, "SessionError", {
              ...basePayload(),
              error: "Retry",
            });
          }
          // busy → skip (already working)
          // idle → handled by session.idle
          break;
        }

        case "session.updated": {
          const title = event.properties?.info?.title;
          if (title) sessionName = title;
          break;
        }

        case "session.compacted":
          callHook(hookBin, "PostCompact", basePayload());
          break;

        case "session.deleted":
        case "permission.replied":
          // skip — liveness handles deletion, PreToolUse follows permission
          break;
      }
    },

    // ---- Message events: track token usage ----
    "chat.message": async (_input, output) => {
      const prompt =
        output?.message?.content ||
        output?.content ||
        (typeof output?.text === "string" ? output.text : null);
      callHook(hookBin, "UserPromptSubmit", {
        ...basePayload(),
        ...(prompt && { prompt }),
      });
    },

    "chat.complete": async (_input, output) => {
      // Track context usage after each assistant response
      const message = output?.message;
      if (!message) return;
      
      const tokens = message.tokens;
      if (!tokens) return;
      
      // Calculate total context usage
      const inputTokens = tokens.input || 0;
      const outputTokens = tokens.output || 0;
      const reasoningTokens = tokens.reasoning || 0;
      const cacheRead = tokens.cache?.read || 0;
      const cacheWrite = tokens.cache?.write || 0;
      
      const totalTokens = inputTokens + outputTokens + reasoningTokens + cacheRead + cacheWrite;
      const usagePercent = modelContextLimit > 0 
        ? Math.round((totalTokens / modelContextLimit) * 100)
        : 0;
      
      // Send context usage info with the message
      const contextMsg = `Context usage: ${usagePercent}% (${totalTokens}/${modelContextLimit} tokens)`;
      callHook(hookBin, "UserPromptSubmit", {
        ...basePayload(),
        prompt: contextMsg,
        context_usage: usagePercent / 100,
        context_tokens_used: totalTokens,
        context_tokens_total: modelContextLimit,
      });
    },

    // ---- Tool execution events ----
    "tool.execute.before": async (_input, output) => {
      const tool = normalizeTool(output?.tool || _input?.tool);
      const args = output?.args || _input?.args;
      callHook(hookBin, "PreToolUse", {
        ...basePayload(),
        ...(tool && { tool_name: tool }),
        ...(args && { tool_input: normalizeToolInput(args) }),
      });
    },

    "tool.execute.after": async () => {
      callHook(hookBin, "PostToolUse", basePayload());
    },

    // ---- Permission events ----
    "permission.ask": async (input) => {
      const tool = normalizeTool(input?.tool);
      const args = input?.args;
      callHook(hookBin, "PermissionRequest", {
        ...basePayload(),
        ...(tool && { tool_name: tool }),
        ...(input?.title && { title: input.title }),
        ...(args && { tool_input: normalizeToolInput(args) }),
      });
    },

    // ---- Context compaction events ----
    "experimental.session.compacting": async () => {
      callHook(hookBin, "PreCompact", basePayload());
    },
  };
};
