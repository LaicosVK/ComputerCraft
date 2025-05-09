local bigfont = require "bigfont"
local mon = peripheral.wrap("back")

mon.setBackgroundColor(colors.black)
mon.clear()
mon.setTextScale(1)

-- Get monitor size
local w, _ = mon.getSize()

-- Text to display
local bigText = "CAUTION"
local smallText = "Enter at your own risk"

-- BigFont width per character (scale 0.5 = 4 pixels per char)
local charWidth = 4  -- for scale = 0.5
local scale = 0.5

-- Calculate width in pixels and center X
local textWidth = #bigText * charWidth
local x = math.floor((w * 6 - textWidth) / 2 / charWidth) + 1  -- 6 pixels per char cell

-- Draw big "CAUTION"
mon.setTextColor(colors.red)
bigfont.writeOn(mon, bigText, x, 2, scale)

-- Draw normal small text
mon.setTextColor(colors.white)
local x2 = math.floor((w - #smallText) / 2) + 1
mon.setCursorPos(x2, 8)
mon.write(smallText)
