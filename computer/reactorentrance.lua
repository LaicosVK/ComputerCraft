local bigfont = require "bigfont"
local monitor = peripheral.wrap("back")
print("v5")


local warningScreen = {
	"",
    " ###  ###  ## ## ###### ##  ###  ##   ##", -- Line 1
    "#### ## ## ## ## ###### ## ##### ###  ##", -- Line 2
    "##   ##### ## ##   ##   ## ## ## #### ##", -- Line 3
    "##   ##### ## ##   ##   ## ## ## ## ####", -- Line 4
    "#### ## ## #####   ##   ## ##### ##  ###", -- Line 5
    " ### ## ##  ###    ##   ##  ###  ##   ##", -- Line 6
    "",                                               -- Spacer
	"",
    "   ! Nuklearanlage !   ",
    "!!!  Betreten verboten  !!!"
}


-- Draw a line of text with full background width and alignment
local function drawLine(line, text, colorText, colorBackground, alignment)
    alignment = alignment or "left"
    colorText = colorText or colors.white
    colorBackground = colorBackground or colors.black

    monitor.setCursorPos(1, line)
    monitor.setBackgroundColor(colorBackground)
    monitor.clearLine()

    local x = 1
    if alignment == "center" then
        x = math.floor((monitor.getSize()) - #text) / 2 + 2
    elseif alignment == "right" then
        local w = select(1, monitor.getSize())
        x = w - #text + 1
    end

    monitor.setCursorPos(x, line)
    monitor.setTextColor(colorText)
    monitor.write(text)
end


for i, line in ipairs(warningScreen) do
    drawLine(i, line, colors.yellow, colors.black, "center")
end
