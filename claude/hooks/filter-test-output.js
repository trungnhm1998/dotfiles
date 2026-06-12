#!/usr/bin/env node
// PreToolUse hook for the Bash tool: when the command is a recognized test/build
// runner, wrap it so the output returned to the model is failures-only (the full
// run still happens; the exit code is preserved; on success only a short tail
// comes back). Cuts 10k-token test logs down to the failing lines.
//
// Opt out for a session: export CC_NO_TEST_FILTER=1
// Skipped automatically when the command is multi-line, already piped, or
// already wrapped (re-entry guard).
'use strict';

const RUNNERS = [
  /\bdotnet\s+test\b/,
  /\b(npm|pnpm|yarn|bun)\s+(run\s+)?test\b/,
  /\bnpx\s+(jest|vitest|mocha)\b/,
  /\bpytest\b/,
  /\bgo\s+test\b/,
  /\bgradlew?(\.bat)?\b.*\btest\b/i,
  /-runTests\b/, // Unity batchmode test runs
];

const FAIL_PATTERN =
  'FAIL|Failed|FAILED|failures|error CS|error:|Error:|Exception|Traceback|Assert';

let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (input += c));
process.stdin.on('end', () => {
  if (process.env.CC_NO_TEST_FILTER === '1') return;

  let payload;
  try {
    payload = JSON.parse(input);
  } catch {
    return;
  }
  if (payload.tool_name !== 'Bash') return;

  const cmd = payload.tool_input && payload.tool_input.command;
  if (!cmd || typeof cmd !== 'string') return;
  if (cmd.includes('__ccf_out')) return; // already wrapped
  if (cmd.includes('\n')) return; // multi-line (heredocs etc.) — leave alone
  if (cmd.includes('|')) return; // caller is already filtering — don't double-pipe
  if (!RUNNERS.some((re) => re.test(cmd))) return;

  const wrapped =
    `__ccf_out=$(mktemp); { ${cmd} ; } >"$__ccf_out" 2>&1; __ccf_ec=$?; ` +
    `if [ $__ccf_ec -eq 0 ]; then tail -n 40 "$__ccf_out"; ` +
    `else grep -nE -B 2 -A 10 '${FAIL_PATTERN}' "$__ccf_out" | head -n 250; ` +
    `echo '--- last 25 lines of full output ---'; tail -n 25 "$__ccf_out"; fi; ` +
    `rm -f "$__ccf_out"; exit $__ccf_ec`;

  process.stdout.write(
    JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'PreToolUse',
        permissionDecision: 'allow',
        permissionDecisionReason:
          'test runner rewritten to failures-only output (filter-test-output hook)',
        updatedInput: { command: wrapped },
      },
    })
  );
});
