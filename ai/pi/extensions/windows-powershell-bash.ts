/**
 * Route pi LLM bash tool through PowerShell on Windows (pwsh first),
 * with Git Bash as fallback when PowerShell is unavailable.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  createBashTool,
  createLocalBashOperations,
} from "@earendil-works/pi-coding-agent";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";

const agentDir = join(dirname(fileURLToPath(import.meta.url)), "..");
const psPkg = join(agentDir, "npm/node_modules/pi-powershell/src");
const { createExecOps } = await import(pathToFileURL(join(psPkg, "ps-exec.js")).href);
const { resolveShell } = await import(pathToFileURL(join(psPkg, "shell-resolve.js")).href);

export default function windowsPowerShellBash(pi: ExtensionAPI): void {
  if (process.platform !== "win32") return;

  if (!process.env.PI_PS_TRANSLATE) {
    process.env.PI_PS_TRANSLATE = "auto";
  }

  const shell = resolveShell();
  const bashFallback = createLocalBashOperations();
  const translateMode =
    process.env.PI_PS_TRANSLATE === "off" ||
    process.env.PI_PS_TRANSLATE === "hint" ||
    process.env.PI_PS_TRANSLATE === "auto"
      ? process.env.PI_PS_TRANSLATE
      : "auto";

  const psOps = shell
    ? createExecOps(
        shell,
        translateMode,
        process.env.PI_PS_STRICT === "1",
        process.env.PI_PS_UTF8 !== "0",
        process.env.PI_PS_KILL_TREE !== "0",
      )
    : null;

  const operations = {
    exec(
      command: string,
      cwd: string,
      opts: {
        onData: (data: Buffer) => void;
        signal?: AbortSignal;
        timeout?: number;
        env?: NodeJS.ProcessEnv;
      },
    ): Promise<{ exitCode: number | null }> {
      if (psOps) {
        return psOps.exec(command, cwd, opts).catch((err: unknown) => {
          const message = err instanceof Error ? err.message : String(err);
          opts.onData(
            Buffer.from(
              `[windows-powershell-bash] PowerShell failed (${message}); retrying via bash...\n`,
            ),
          );
          return bashFallback.exec(command, cwd, opts);
        });
      }
      return bashFallback.exec(command, cwd, opts);
    },
  };

  const bashTool = createBashTool(process.cwd(), { operations });

  pi.registerTool({
    ...bashTool,
    label: "powershell",
    description:
      "Execute a shell command on Windows via PowerShell (pwsh). Common bash syntax is auto-translated; Git Bash is used only when PowerShell is unavailable.",
    promptSnippet: "Execute shell commands via PowerShell on Windows (bash syntax auto-translated)",
    promptGuidelines: [
      "Prefer PowerShell-native cmdlets when straightforward (Get-ChildItem, Select-String, etc.).",
      "Simple bash-style commands (ls, grep, cat, find) are translated automatically.",
      "You can inspect PI_* environment variables for current model and session details.",
    ],
  });

  pi.on("session_start", (_event, ctx) => {
    if (shell) {
      ctx.ui.notify(
        `[windows-powershell-bash] LLM shell -> ${shell.isPwsh7 ? "pwsh" : "Windows PowerShell"} ${shell.version} (translate: ${translateMode}); bash fallback ready`,
        "info",
      );
      return;
    }
    ctx.ui.notify(
      "[windows-powershell-bash] PowerShell not found; LLM shell -> Git Bash",
      "warning",
    );
  });
}
