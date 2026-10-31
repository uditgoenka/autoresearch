// stop-notify — ported from claude-plugin/hooks/stop-notify.cjs, with the
// multi-protocol terminal notification from pi's notify.ts example (OSC 777,
// Kitty OSC 99, Windows toast). Fires on session_shutdown: sends a terminal
// notification + optional webhook, then cleans up the session state file.

import http from "node:http";
import https from "node:https";
import { basename } from "node:path";
import {
  cleanupSessionFile,
  isHookEnabled,
  loadSessionState,
  log,
} from "../lib/session-state.js";
import { findRecentTsv, readTsvTail } from "../lib/tsv.js";

const HOOK_NAME = "stop-notify";

function formatDuration(startedAt?: string): string {
  if (!startedAt) return "unknown";
  const ms = Date.now() - new Date(startedAt).getTime();
  if (ms < 0) return "unknown";
  const totalSeconds = Math.floor(ms / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  if (hours > 0) return `${hours}h ${minutes}m`;
  return `${minutes}m ${seconds}s`;
}

function buildTsvSummary(projectRoot: string): { text: string; iterations: number } {
  const tsvPath = findRecentTsv(projectRoot, 120); // look back 2 hours on session end
  if (!tsvPath) return { text: "no iterations recorded", iterations: 0 };

  const tsv = readTsvTail(tsvPath, 1);
  if (!tsv) return { text: "no iterations recorded", iterations: 0 };

  const lastRow = tsv.rows[0] || "";
  const metricMatch = lastRow.match(/[\t|]([0-9.-]+)(?:[\t|]|$)/);
  const metric = metricMatch ? metricMatch[1] : "n/a";

  return { text: `${tsv.total} iterations, metric: ${metric}`, iterations: tsv.total };
}

function windowsToastScript(title: string, body: string): string {
  // PowerShell single-quoted strings escape a quote by doubling it.
  const quote = (text: string) => text.replace(/'/g, "''");
  const type = "Windows.UI.Notifications";
  const mgr = `[${type}.ToastNotificationManager, ${type}, ContentType = WindowsRuntime]`;
  const template = `[${type}.ToastTemplateType]::ToastText01`;
  const toast = `[${type}.ToastNotification]::new($xml)`;
  return [
    `${mgr} > $null`,
    `$xml = [${type}.ToastNotificationManager]::GetTemplateContent(${template})`,
    `$xml.GetElementsByTagName('text')[0].AppendChild($xml.CreateTextNode('${quote(body)}')) > $null`,
    `[${type}.ToastNotificationManager]::CreateToastNotifier('${quote(title)}').Show(${toast})`,
  ].join("; ");
}

function notifyOSC777(title: string, body: string): void {
  process.stdout.write(`\x1b]777;notify;${title};${body}\x07`);
}

function notifyOSC99(title: string, body: string): void {
  process.stdout.write(`\x1b]99;i=1:d=0;${title}\x1b\\`);
  process.stdout.write(`\x1b]99;i=1:p=body;${body}\x1b\\`);
}

function notifyWindows(title: string, body: string): void {
  const { execFile } = require("node:child_process");
  execFile("powershell.exe", ["-NoProfile", "-Command", windowsToastScript(title, body)]);
}

function notify(title: string, body: string): void {
  if (process.env.WT_SESSION) {
    notifyWindows(title, body);
  } else if (process.env.KITTY_WINDOW_ID) {
    notifyOSC99(title, body);
  } else {
    notifyOSC777(title, body);
  }
}

function postWebhook(webhookUrl: string, payload: Record<string, unknown>): Promise<void> {
  return new Promise((resolve) => {
    try {
      const parsed = new URL(webhookUrl);
      const client = parsed.protocol === "http:" ? http : https;
      const body = JSON.stringify(payload);
      const req = client.request(
        {
          hostname: parsed.hostname,
          port: parsed.port || (parsed.protocol === "https:" ? 443 : 80),
          path: parsed.pathname + parsed.search,
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Content-Length": Buffer.byteLength(body),
          },
        },
        (response) => {
          response.resume();
          response.on("end", resolve);
        },
      );
      req.setTimeout(2000, () => req.destroy());
      req.on("error", resolve);
      req.write(body);
      req.end();
    } catch {
      resolve();
    }
  });
}

export async function runStopNotify(cwd: string, sessionId: string): Promise<void> {
  if (!isHookEnabled(HOOK_NAME)) return;
  try {
    const state = loadSessionState(cwd, sessionId);
    const duration = formatDuration(state.startedAt);
    const tsvSummary = buildTsvSummary(state.projectRoot || cwd);
    const projectName = basename(state.projectRoot || cwd);

    notify("autoresearch", `Session completed — ${projectName} (${duration})`);

    const webhookUrl = process.env.AR_NOTIFY_WEBHOOK;
    if (webhookUrl) {
      await postWebhook(webhookUrl, {
        text: "autoresearch session completed",
        project: projectName,
        branch: state.gitBranch || "",
        duration,
        tsv_summary: tsvSummary.text,
      });
    }

    log(HOOK_NAME, {
      projectName,
      duration,
      iterations: tsvSummary.iterations,
    });

    cleanupSessionFile(cwd, sessionId);
  } catch {
    // fail-open
  }
}
