local bigfont = require "bigfont"
local mon = peripheral.wrap("back")

mon.setBackgroundColor(colors.black)
mon.clear()
mon.setTextScale(1)

-- Draw big "CAUTION" in red, centered
mon.setTextColor(colors.red)
bigfont.writeCentered(mon, "CAUTION", 2, 0.5)

-- Draw small "Enter at your own risk" in white, centered
mon.setTextColor(colors.white)
local w, _ = mon.getSize()
local text = "Enter at your own risk"
local x = math.floor((w - #text) / 2) + 1
mon.setCursorPos(x, 8)
mon.write(text)
