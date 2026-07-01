BeforeAll {
  . "$PSScriptRoot/bench.lib.ps1"
  # Pester 5: $PSScriptRoot is reliable here but can be empty inside It blocks — capture it now.
  $script:SamplePath = "$PSScriptRoot/samples/paint-sample.txt"
}

Describe 'ConvertFrom-WezDuration' {
  It 'parses <label> to about <ms> ms' -TestCases @(
    @{ label = '1.234ms';       t = '1.234ms';                     ms = 1.234 }
    @{ label = '567us(U+00B5)'; t = ('567' + [char]0x00B5 + 's');  ms = 0.567 }
    @{ label = '567us(U+03BC)'; t = ('567' + [char]0x03BC + 's');  ms = 0.567 }
    @{ label = '567us(ascii)';  t = '567us';                       ms = 0.567 }
    @{ label = '2.5s';          t = '2.5s';                        ms = 2500 }
    @{ label = '123ns';         t = '123ns';                       ms = 0.000123 }
  ) {
    $got = ConvertFrom-WezDuration $t
    $got | Should -BeGreaterOrEqual ($ms - 1e-9)
    $got | Should -BeLessOrEqual ($ms + 1e-9 + [math]::Abs($ms) * 1e-6)
  }
  It 'throws on garbage' { { ConvertFrom-WezDuration 'abc' } | Should -Throw }
}

Describe 'Get-Percentile' {
  It 'median of 1..10 is 5'  { Get-Percentile -Values (1..10)  -P 50  | Should -Be 5 }
  It 'p95 of 1..100 is 95'   { Get-Percentile -Values (1..100) -P 95  | Should -Be 95 }
  It 'p100 is the max'       { Get-Percentile -Values @(3,1,2) -P 100 | Should -Be 3 }
  It 'throws on empty'       { { Get-Percentile -Values @() -P 50 }   | Should -Throw }
}

Describe 'Get-PaintSamplesMs' {
  It 'extracts only paint_impl elapsed values' {
    $log = @(
      '10:00:00.100 DEBUG wezterm_gui::termwindow::render::paint > paint_impl elapsed=1.5ms, fps=60'
      '10:00:00.200 INFO  mux > unrelated line'
      ('10:00:00.300 DEBUG wezterm_gui::termwindow::render::paint > paint_impl elapsed=800' + [char]0x00B5 + 's, fps=59')
    )
    $s = Get-PaintSamplesMs -LogLines $log
    $s.Count | Should -Be 2
    $s[0]    | Should -Be 1.5
    $s[1]    | Should -Be 0.8
  }
  It 'parses the real captured samples without error' {
    $script:SamplePath | Should -Exist
    $real = Get-Content $script:SamplePath
    $s = Get-PaintSamplesMs -LogLines $real
    $s.Count | Should -BeGreaterThan 0
    # @() guard: Where-Object returns $null for zero matches, and $null.Count throws under StrictMode.
    @($s | Where-Object { $_ -le 0 }).Count | Should -Be 0
  }
}
