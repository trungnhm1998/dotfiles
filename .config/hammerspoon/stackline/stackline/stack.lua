local Stack = {}

function Stack:new(stackedWindows) -- {{{
    local stack = {
        windows = stackedWindows,
        background = nil  -- background canvas element
    }
    setmetatable(stack, self)
    self.__index = self
    return stack
end -- }}}

function Stack:get() -- {{{
    return self.windows
end -- }}}

function Stack:getHs() -- {{{
   return u.map(self.windows, function(w)
       return w._win
   end)
end -- }}}

function Stack:frame() -- {{{
   -- All stacked windows have the same dimensions,
   -- so the 1st Hs window's frame is ~= to the stack's frame
   -- TODO: Incorrect when the 1st window has min-size < stack width. See ./query.lua:105
   return self.windows[1]._win:frame()
end -- }}}

function Stack:eachWin(fn) -- {{{
   for _idx, win in pairs(self.windows) do
       fn(win)
   end
end -- }}}

function Stack:getOtherAppWindows(win) -- {{{
   -- NOTE: may not need when HS issue #2400 is closed
   return u.filter(self:get(), function(w)
       return w.app == win.app
   end)
end -- }}}

function Stack:anyFocused() -- {{{
   return u.any(self.windows, function(w)
       return w:isFocused()
   end)
end -- }}}

function Stack:drawBackground() -- {{{
   -- Draw a solid background rectangle behind all indicators
   if self.background then
       self.background:delete()
   end

   if #self.windows == 0 then return end

   -- Setup all indicators first to get their positions
   self:eachWin(function(w)
       w:setupIndicator()
   end)

   -- Find the window with the lowest stackIdx (topmost indicator)
   local topWin = self.windows[1]
   for _, win in pairs(self.windows) do
       if win.stackIdx and (not topWin.stackIdx or win.stackIdx < topWin.stackIdx) then
           topWin = win
       end
   end

   if not topWin or not topWin.indicator_rect then return end

   local c = stackline.config:get('appearance')
   local numWindows = #self.windows
   local padding = 3  -- symmetric padding around indicators

   -- Calculate background frame based on topmost window's indicator position
   local bgFrame = {
       x = topWin.indicator_rect.x - padding,
       y = topWin.indicator_rect.y - padding,
       w = topWin.indicator_rect.w + (padding * 2),
       h = (c.size * numWindows) + (c.size * (c.vertSpacing - 1) * (numWindows - 1)) + (padding * 2)
   }

   local screenFrame = topWin.screen:fullFrame()

   -- Extend background to screen edges when close to them
   -- This eliminates any gap between background and screen edge
   local edgeThreshold = 10  -- if within 10px of edge, extend to edge
   if bgFrame.x < edgeThreshold then
       -- Extend to left edge (and past it to ensure no gap)
       local rightEdge = bgFrame.x + bgFrame.w
       bgFrame.x = -2
       bgFrame.w = rightEdge - bgFrame.x
   end
   if bgFrame.x + bgFrame.w > screenFrame.w - edgeThreshold then
       -- Extend to right edge (and past it to ensure no gap)
       bgFrame.w = (screenFrame.w + 2) - bgFrame.x
   end

   self.background = hs.canvas.new(screenFrame)

   self.background:insertElement({
       type = "rectangle",
       action = "fill",
       fillColor = { white = 0.15, alpha = 0.85 },  -- dark semi-transparent background
       frame = bgFrame,
       roundedRectRadii = { xRadius = 6, yRadius = 6 },
   }, 1)

   self.background:level(hs.canvas.windowLevels.floating)
   self.background:clickActivating(false)
   self.background:show()
end -- }}}

function Stack:deleteBackground() -- {{{
   if self.background then
       self.background:delete()
       self.background = nil
   end
end -- }}}

function Stack:resetAllIndicators() -- {{{
   self:drawBackground()  -- draw background first (also sets up indicators)
   self:eachWin(function(w)
       w:drawIndicator()  -- indicators already setup in drawBackground
   end)
end -- }}}

function Stack:redrawAllIndicators(opts) -- {{{
   self:eachWin(function(win)
       if win.id ~= opts.except then
           win:redrawIndicator()
       end
   end)
end -- }}}

function Stack:deleteAllIndicators() -- {{{
   self:deleteBackground()  -- delete background too
   self:eachWin(function(win)
       win:deleteIndicator()
   end)
end -- }}}

function Stack:hideAllIndicators() -- {{{
   -- Hide indicators without deleting them (for caching)
   if self.background then
       self.background:hide()
   end
   self:eachWin(function(win)
       if win.indicator then
           win.indicator:hide()
       end
   end)
end -- }}}

function Stack:showAllIndicators() -- {{{
   -- Show previously hidden indicators
   if self.background then
       self.background:show()
   end
   self:eachWin(function(win)
       if win.indicator then
           win.indicator:show()
       end
   end)
end -- }}}

function Stack:getWindowByPoint(p)
   if p.x < 0 or p.y < 0 then
      -- FIX: https://github.com/AdamWagner/stackline/issues/62
      -- NOTE: Window indicator frame coordinates are relative to the window's screen.
      -- So, if click point has negative X or Y vals, then convert its coordinates
      -- to relative to the clicked screen before comparing to window indicator frames.
      -- TODO: Clean this up after fix is confirmed

      -- Get the screen with frame that contains point 'p'
      local function findClickedScreen(_p) -- {{{
         return table.unpack(
            u.filter(hs.screen.allScreens(), function(s)
               return _p:inside(s:frame())
            end)
         )
      end -- }}}

      local clickedScren = findClickedScreen(p)
      p = clickedScren
         and clickedScren:absoluteToLocal(p)
         or p
   end

   return table.unpack(
         u.filter(self.windows, function(w)
          local indicatorFrame = w.indicator and w.indicator:canvasElements()[1].frame
          if not indicatorFrame then return false end
          return p:inside(indicatorFrame) -- NOTE: frame *must* be a hs.geometry.rect instance
      end)
   )
end

return Stack
