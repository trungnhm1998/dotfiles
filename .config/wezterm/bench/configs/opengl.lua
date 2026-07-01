-- front_end=OpenGL in isolation (standalone). Compare cold startup vs empty (WebGpu default) and
-- webgpu-hp. NOTE: the `--config front_end="OpenGL"` CLI form is unusable from Start-Process here --
-- it strips the quotes in transport, so wezterm sees `front_end=OpenGL` (a bare word) -> Lua nil
-- error and the window never renders. A config file keeps the quotes intact.
return {
  front_end = "OpenGL",
}
