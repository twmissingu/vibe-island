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
import { existsSync, unlinkSync, readFileSync } from "fs";
import { join } from "path";
import { homedir } from "os";

const sessionsDir = join(homedir(), ".vibe-island", "sessions");

const DEBUG = process.env.VIBE_ISLAND_DEBUG === "1";
const debugLog = (...args) => DEBUG && console.log("[VibeIsland Debug]", ...args);

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
// Read model context limit from OpenCode config file
// ---------------------------------------------------------------------------
function readModelContextLimit() {
  try {
    const configPath = join(homedir(), '.config', 'opencode', 'opencode.json');
    if (!existsSync(configPath)) {
      debugLog('Config file not found:', configPath);
      return null;
    }
    
    const configData = readFileSync(configPath, 'utf8');
    const config = JSON.parse(configData);
    
    // Try to find context limit in provider models
    // Config structure: provider.{providerName}.models.{modelId}.limit.context
    if (config.provider) {
      for (const providerName of Object.keys(config.provider)) {
        const provider = config.provider[providerName];
        if (provider.models) {
          for (const modelId of Object.keys(provider.models)) {
            const model = provider.models[modelId];
            if (model.limit?.context) {
              debugLog('Found context limit in config:', {
                provider: providerName,
                model: modelId,
                contextLimit: model.limit.context
              });
              return model.limit.context;
            }
          }
        }
      }
    }
    
    debugLog('No context limit found in config');
    return null;
  } catch (error) {
    debugLog('Error reading config:', error.message);
    return null;
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
  const defaultContextLimit = readModelContextLimit() || 200000;
  let modelContextLimit = defaultContextLimit; // default to config or 200K
  let toolCounts = {}; // Track tool usage counts for this session
  let skillCounts = {}; // Track skill usage counts for this session
  let cachedSortedTools = null;
  let cachedSortedSkills = null;
  let lastToolCountsHash = '';
  let lastSkillCountsHash = '';

  debugLog('Using context limit:', modelContextLimit);

  // ---------------------------------------------------------------------------
  // Shared: Calculate context usage and send hook
  // ---------------------------------------------------------------------------
  function sendContextUsageHook(eventName = 'UserPromptSubmit') {
    // Simple hash to detect if counts changed
    const toolCountsHash = JSON.stringify(toolCounts);
    const skillCountsHash = JSON.stringify(skillCounts);

    // Only re-sort if counts changed
    if (toolCountsHash !== lastToolCountsHash) {
      cachedSortedTools = Object.entries(toolCounts)
        .sort((a, b) => b[1] - a[1])
        .map(([name, count]) => ({ name, count }));
      lastToolCountsHash = toolCountsHash;
    }

    if (skillCountsHash !== lastSkillCountsHash) {
      cachedSortedSkills = Object.entries(skillCounts)
        .sort((a, b) => b[1] - a[1])
        .map(([name, count]) => ({ name, count }));
      lastSkillCountsHash = skillCountsHash;
    }

    return {
      tool_usage: cachedSortedTools || [],
      skill_usage: cachedSortedSkills || []
    };
  }

  // ---------------------------------------------------------------------------
  // Shared: Calculate and send context usage from token data
  // ---------------------------------------------------------------------------
  function handleTokenUpdate(tokens, source) {
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

    debugLog(`${source} context calculation:`, {
      totalTokens,
      modelContextLimit,
      usagePercent,
      tokensBreakdown: {
        input: inputTokens,
        output: outputTokens,
        reasoning: reasoningTokens,
        cacheRead,
        cacheWrite,
        total: tokens.total
      }
    });

    const { tool_usage, skill_usage } = sendContextUsageHook();

    // Send context usage info with the message
    const contextMsg = `Context usage: ${usagePercent}% (${totalTokens}/${modelContextLimit} tokens)`;
    debugLog(`Sending context usage hook (${source}):`, {
      context_usage: usagePercent / 100,
      context_tokens_used: totalTokens,
      context_tokens_total: modelContextLimit
    });

    callHook(hookBin, "UserPromptSubmit", {
      ...basePayload(),
      prompt: contextMsg,
      context_usage: usagePercent / 100,
      context_tokens_used: totalTokens,
      context_tokens_total: modelContextLimit,
      context_input_tokens: inputTokens,
      context_output_tokens: outputTokens,
      context_reasoning_tokens: reasoningTokens,
      tool_usage,
      skill_usage,
    });
  }
  
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
      debugLog('chat.params received:', JSON.stringify(params, null, 2));
      if (params?.model?.limit?.context) {
        modelContextLimit = params.model.limit.context;
        debugLog('modelContextLimit updated to:', modelContextLimit);
      } else {
        debugLog('No context limit found in params, using default:', modelContextLimit);
      }
    },

    // ---- Session lifecycle events ----
    event: async ({ event }) => {
      if (!event || !event.type) return;

      switch (event.type) {
        case "session.created":
          // Reset model context limit and tool counts for new session
          modelContextLimit = defaultContextLimit;
          toolCounts = {};
          skillCounts = {};
          cachedSortedTools = null;
          cachedSortedSkills = null;
          lastToolCountsHash = '';
          lastSkillCountsHash = '';
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

      // 检查刷新标记文件，触发上下文刷新
      const refreshFile = join(sessionsDir, `${sessionId}.refresh`);
      if (existsSync(refreshFile)) {
        try { unlinkSync(refreshFile); } catch {}
        // 请求 VibeIsland 刷新会话上下文
        callHook(hookBin, "RefreshContext", basePayload());
      }
    },

    // ---- Message part events: track token usage from step-finish ----
    "message.part.updated": async ({ part }) => {
      // Track context usage from step-finish token data
      if (!part || part.type !== "step-finish") return;
      handleTokenUpdate(part.tokens, 'message.part.updated');
    },

    // ---- Message events: track token usage ----
    "message.updated": async ({ message }) => {
      // Track context usage from message token data
      if (!message) return;
      handleTokenUpdate(message.tokens, 'message.updated');
    },

    // Keep chat.complete as fallback for compatibility
    "chat.complete": async (_input, output) => {
      // Track context usage after each assistant response
      const message = output?.message;
      if (!message) return;
      handleTokenUpdate(message.tokens, 'chat.complete');
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
      // Track tool usage
      if (tool) {
        toolCounts[tool] = (toolCounts[tool] || 0) + 1;
      }
    },

    "tool.execute.after": async () => {
      callHook(hookBin, "PostToolUse", basePayload());
    },

    // ---- Skill execution events ----
    "skill.execute.before": async (_input, output) => {
      const skill = output?.skill || _input?.skill;
      // Track skill usage
      if (skill) {
        skillCounts[skill] = (skillCounts[skill] || 0) + 1;
      }
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
