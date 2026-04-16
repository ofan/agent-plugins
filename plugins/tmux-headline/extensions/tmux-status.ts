/**
 * Pi + tmux headline integration
 *
 * Protocol (unified across Claude/Pi/Codex):
 *   Busy:  "⠋ headline" → "⠙ headline" → ... (braille cycle, ~200ms)
 *   Idle:  "⠿ headline" (static)
 *   End:   "" (cleared)
 *
 * Headlines extracted from transcript via script — no LLM instructions.
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync, unlinkSync } from "node:fs";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const HOME = process.env.HOME || "~";
const DATA_DIR = join(HOME, ".local", "share", "tmux-headline");
const HEADLINE_DIR = join(DATA_DIR, "headlines");
const BRAILLE = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];
const SPIN_MS = 100;
const IDLE_GLYPH = "⠿";

// ── helpers ───────────────────────────────────────────────────

function setTitle(title: string): void {
  process.stdout.write(`\x1b]2;${title}\x07`);
}

function tmuxSetAgent(on: boolean): void {
  const pane = process.env.TMUX_PANE;
  if (!pane) return;
  try {
    if (on) {
      execFileSync("tmux", ["set-option", "-p", "-t", pane, "@agent", "1"], { stdio: "ignore" });
    } else {
      execFileSync("tmux", ["set-option", "-p", "-t", pane, "-u", "@agent"], { stdio: "ignore" });
    }
  } catch {}
}

function ensureTmuxFormats(): void {
  try {
    const ready = execFileSync("tmux", ["show", "-gv", "@headline_ready"],
      { stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
    if (ready === "1") return;
  } catch {}
  try {
    execFileSync("tmux", ["set", "-g", "allow-rename", "on"], { stdio: "ignore" });
    execFileSync("tmux", ["set", "-g", "status-interval", "1"], { stdio: "ignore" });
    execFileSync("tmux", ["set", "-g", "@headline_ready", "1"], { stdio: "ignore" });
  } catch {}
}

/** Extract UUID from session file path like .../2026-04-05T..._<uuid>.jsonl */
function sessionIdFromPath(path?: string): string {
  if (!path) return "";
  const name = basename(path);
  // filename format: <timestamp>_<uuid>.jsonl
  const match = name.match(/^.*_([0-9a-f-]+)\.jsonl$/);
  return match?.[1] ?? "";
}

function readHeadline(sessionId: string): string {
  if (!sessionId || sessionId === ".") return "";
  try {
    const file = join(HEADLINE_DIR, `${sessionId}.headline`);
    if (existsSync(file)) {
      const h = readFileSync(file, "utf-8").trim().slice(0, 40);
      if (h) return h;
    }
  } catch {}
  return "";
}

function saveHeadline(sessionId: string, headline: string): void {
  if (!sessionId || sessionId === ".") return;
  try {
    mkdirSync(HEADLINE_DIR, { recursive: true });
    writeFileSync(join(HEADLINE_DIR, `${sessionId}.headline`), headline);
  } catch {}
}

function findPiTranscript(sessionId: string): string {
  if (!sessionId) return "";
  const sessionsDir = join(HOME, ".pi", "agent", "sessions");
  try {
    const dirs = readdirSync(sessionsDir);
    for (const dir of dirs) {
      try {
        const files = readdirSync(join(sessionsDir, dir));
        const match = files.find(f => f.includes(sessionId) && f.endsWith(".jsonl"));
        if (match) return join(sessionsDir, dir, match);
      } catch {}
    }
  } catch {}
  return "";
}

function findScript(): string {
  const candidates = [
    join(dirname(fileURLToPath(import.meta.url)), "..", "scripts", "extract-headline.sh"),
    join(HOME, ".pi", "agent", "scripts", "extract-headline.sh"),
    join(HOME, ".claude", "plugins", "marketplaces", "ofan-plugins", "plugins", "tmux-headline", "scripts", "extract-headline.sh"),
    join(HOME, ".claude", "plugins", "local", "tmux-headline", "scripts", "extract-headline.sh"),
    join(HOME, "projects", "agent-plugins", "plugins", "tmux-headline", "scripts", "extract-headline.sh"),
  ];
  return candidates.find(p => existsSync(p)) || "";
}

function extractHeadline(transcript: string): string {
  if (!transcript) return "";
  try {
    const script = findScript();
    if (!script) return "";
    return execFileSync("bash", [script, transcript, ""],
      { timeout: 5000, stdio: ["ignore", "pipe", "ignore"] }).toString().trim();
  } catch { return ""; }
}

// ── extension ─────────────────────────────────────────────────

export default function (pi: ExtensionAPI) {
  let lastHeadline = "";
  let shuttingDown = false;
  let currentSessionId = "";
  let currentTranscript = "";
  let spinnerTimer: ReturnType<typeof setInterval> | null = null;
  let spinnerFrame = 0;

  mkdirSync(HEADLINE_DIR, { recursive: true });
  ensureTmuxFormats();

  /** Resolve session info from context */
  function resolveSession(ctx?: ExtensionContext): void {
    const file = ctx?.sessionManager?.getSessionFile?.();
    currentSessionId = sessionIdFromPath(file);
    currentTranscript = file || "";
  }

  /** Update the displayed title based on current state */
  function updateTitle(glyph: string): void {
    setTitle(lastHeadline ? `${glyph} ${lastHeadline}` : glyph);
  }

  function startSpinner(): void {
    stopSpinner();
    spinnerFrame = 0;
    updateTitle(BRAILLE[0]);
    spinnerTimer = setInterval(() => {
      if (shuttingDown) return stopSpinner();
      spinnerFrame++;
      updateTitle(BRAILLE[spinnerFrame % BRAILLE.length]);
    }, SPIN_MS);
  }

  function stopSpinner(): void {
    if (spinnerTimer) {
      clearInterval(spinnerTimer);
      spinnerTimer = null;
    }
  }

  /** Try to get a headline from transcript or cache */
  function refreshHeadline(): void {
    // Try cache first
    const cached = readHeadline(currentSessionId);
    if (cached) { lastHeadline = cached; return; }
    // Extract from transcript
    const transcript = currentTranscript || findPiTranscript(currentSessionId);
    if (transcript) {
      const extracted = extractHeadline(transcript);
      if (extracted) {
        lastHeadline = extracted;
        saveHeadline(currentSessionId, extracted);
      }
    }
  }

  // ── Session lifecycle ──

  pi.on("session_start", async (_event, ctx) => {
    resolveSession(ctx);
    lastHeadline = "";
    tmuxSetAgent(true);
  });

  pi.on("session_switch", async (_event, ctx) => {
    resolveSession(ctx);
    lastHeadline = "";
    stopSpinner();
    refreshHeadline();
    if (lastHeadline) {
      updateTitle(IDLE_GLYPH);
    }
  });

  // ── Busy: braille spinner ──

  pi.on("agent_start", async (_event, ctx) => {
    if (shuttingDown) return;
    resolveSession(ctx);
    refreshHeadline();
    startSpinner();
  });

  // ── Idle: static ⠿ + headline ──

  pi.on("agent_end", async (_event, ctx) => {
    if (shuttingDown) return;
    stopSpinner();
    resolveSession(ctx);
    refreshHeadline();
    if (lastHeadline) {
      updateTitle(IDLE_GLYPH);
    }
  });

  // ── Cleanup ──

  pi.on("session_shutdown", async () => {
    shuttingDown = true;
    stopSpinner();
    setTitle("");
    tmuxSetAgent(false);
    if (currentSessionId) {
      try { unlinkSync(join(HEADLINE_DIR, `${currentSessionId}.headline`)); } catch {}
    }
  });
}
