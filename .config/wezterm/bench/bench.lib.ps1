# Pure helpers for the WezTerm perf harness. Dot-source only; no side effects on load.
Set-StrictMode -Version Latest

function ConvertFrom-WezDuration {
  # Parses Rust Duration Debug format ("123ns" "45.6us"/micro-sign "1.234ms" "2.5s") to milliseconds.
  # WezTerm's log emits the micro sign as U+00B5; U+03BC (Greek mu) is accepted defensively.
  # Regex uses \uXXXX escapes (pure-ASCII source, encoding-proof); the unit is normalized to ASCII.
  param([Parameter(Mandatory)][string]$Text)
  if ($Text -notmatch '^\s*([0-9]*\.?[0-9]+)\s*(ns|us|ms|s|[µμ]s)\s*$') {
    throw "Unrecognized duration: '$Text'"
  }
  $v = [double]$Matches[1]
  $u = $Matches[2] -replace '[µμ]', 'u'   # micro sign -> ASCII 'u'
  switch ($u) {
    'ns' { $v / 1e6 }
    'us' { $v / 1e3 }
    'ms' { $v }
    's'  { $v * 1e3 }
  }
}

function Get-Percentile {
  # Nearest-rank percentile. $P in 0..100.
  param([Parameter(Mandatory)][double[]]$Values, [Parameter(Mandatory)][double]$P)
  if ($Values.Count -eq 0) { throw 'Get-Percentile: no values' }
  $sorted = @($Values | Sort-Object)
  if ($P -le 0)   { return $sorted[0] }
  if ($P -ge 100) { return $sorted[-1] }
  $rank = [math]::Ceiling(($P / 100.0) * $sorted.Count) - 1
  if ($rank -lt 0) { $rank = 0 }
  $sorted[$rank]
}

function Get-PaintSamplesMs {
  # Extracts paint_impl elapsed=<dur> values (ms) from WezTerm log lines.
  param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$LogLines)
  $out = [System.Collections.Generic.List[double]]::new()
  foreach ($line in $LogLines) {
    if ($line -match 'paint_impl elapsed=([0-9.]+(?:ns|us|ms|s|[µμ]s))') {
      $out.Add((ConvertFrom-WezDuration $Matches[1]))
    }
  }
  ,$out.ToArray()
}

function Format-BenchTable {
  # Rows: [pscustomobject]@{ Variant; Mode; N; MedianMs; P95Ms; MaxMs } -> markdown table string.
  param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Rows)
  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine('| Variant | Mode | N | median (ms) | p95 (ms) | max (ms) |')
  [void]$sb.AppendLine('|---|---|---:|---:|---:|---:|')
  foreach ($r in $Rows) {
    [void]$sb.AppendLine(('| {0} | {1} | {2} | {3:N1} | {4:N1} | {5:N1} |' -f `
      $r.Variant, $r.Mode, $r.N, $r.MedianMs, $r.P95Ms, $r.MaxMs))
  }
  $sb.ToString()
}
