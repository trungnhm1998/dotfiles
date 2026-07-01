-- Isolates the startup cost of WebGpu + HighPerformance (forces the discrete GPU) vs the default.
-- Compare cold startup of this vs empty.lua (WebGpu default / LowPower) to attribute the GPU-init cost.
return {
  front_end = "WebGpu",
  webgpu_power_preference = "HighPerformance",
}
