-- Coin Flip Double or Nothing
local version = "1.2"
local initialBet = 100
local currentBet = initialBet
local gameState = "title"
local animationSpeed = 0.005

-- Peripherals
local drive = peripheral.find("drive")
local speaker = peripheral.find("speaker")
local monitor
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitor = peripheral.wrap(name)
        break
    end
end
if not monitor then error("Monitor not found") end

monitor.setTextScale(1)
local width, height = monitor.getSize()
rednet.open("top")

-- Server Communication
local function getKey()
    if not drive.isDiskPresent() then return nil end
    local path = drive.getMountPath()
    if not path or not fs.exists(path .. "/player.key") then return nil end
    local f = fs.open(path .. "/player.key", "r")
    local key = f.readAll()
    f.close()
    return key
end

local function removeCredits(key, amount)
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

local function addCredits(key, amount)
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

-- Drawing Helpers
local function clear()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
end

local function fullLineText(y, text, textColor, bgColor)
    monitor.setCursorPos(1, y)
    monitor.setBackgroundColor(bgColor or colors.black)
    monitor.setTextColor(textColor or colors.white)
    monitor.clearLine()
    local x = math.floor((width - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function playSound(note, volume, pitch)
    if speaker then
        speaker.playNote(note, volume or 1, pitch or 1)
    end
end

-- Screens
local function drawTitle()
    clear()
    fullLineText(math.floor(height / 2) - 1, "Double or Nothing", colors.yellow)
    fullLineText(math.floor(height / 2), "v" .. version, colors.gray)
    fullLineText(math.floor(height / 2) + 2, "[ SPIELEN ]", colors.black, colors.lime)
    playSound("harp", 1, 2)
end

local function drawFlipScreen()
    clear()
    fullLineText(1, "Einsatz: " .. currentBet .. "¢", colors.yellow)

    fullLineText(math.floor(height / 2), "[Münze]", colors.white)

    -- FLIP Button
    fullLineText(height - 4, "  FLIP  ", colors.black, colors.lime)

    -- PAYOUT Button
    fullLineText(height - 2, "AUSZAHLEN", colors.white, colors.red)
end

local function drawLostScreen()
    clear()
    fullLineText(math.floor(height / 2), "Verloren!", colors.red)
    playSound("bass", 1, 0.5)
    sleep(2)
    gameState = "title"
    currentBet = initialBet
    drawTitle()
end

local function drawWinAnimation()
    local frames = {
        "     .     ",
        "    oOo    ",
        "   ( o )   ",
        "  <( o )>  ",
        "   ( o )   ",
        "    oOo    ",
        "     .     "
    }

    for _ = 1, 6 do
        for _, frame in ipairs(frames) do
            fullLineText(1, "Einsatz: " .. currentBet .. "¢", colors.yellow)
            fullLineText(math.floor(height / 2), frame, colors.cyan)
            sleep(animationSpeed)
        end
    end
end

-- Main Game Logic
local function tryStartGame()
    local key = getKey()
    if not key then
        clear()
        fullLineText(math.floor(height / 2), "Bitte Karte einlegen!", colors.orange)
        playSound("bass", 1, 0.5)
        sleep(2)
        drawTitle()
        return
    end
    if not removeCredits(key, initialBet) then
        clear()
        fullLineText(math.floor(height / 2), "Nicht genug Guthaben!", colors.red)
        playSound("bass", 1, 0.5)
        sleep(2)
        drawTitle()
        return
    end
    currentBet = initialBet
    gameState = "game"
    drawFlipScreen()
end

local function tryFlip()
    drawWinAnimation()
    if math.random() < 0.5 then
        drawLostScreen()
    else
        currentBet = currentBet * 2
        playSound("bell", 2, 1.2)
        drawFlipScreen()
    end
end

local function tryPayout()
    local key = getKey()
    if not key then
        clear()
        fullLineText(math.floor(height / 2), "Karte fehlt!", colors.orange)
        playSound("bass", 1, 0.5)
        sleep(2)
        drawFlipScreen()
        return
    end
    addCredits(key, currentBet)
    clear()
    fullLineText(math.floor(height / 2), "Auszahlung: " .. currentBet .. "¢", colors.lime)
    playSound("harp", 2, 1)
    sleep(2)
    gameState = "title"
    currentBet = initialBet
    drawTitle()
end

-- Init
math.randomseed(os.time())
drawTitle()

-- Event Loop
while true do
    local event, side, x, y = os.pullEvent("monitor_touch")

    if gameState == "title" and y == math.floor(height / 2) + 2 then
        tryStartGame()
    elseif gameState == "game" then
        if y == height - 4 then
            tryFlip()
        elseif y == height - 2 then
            tryPayout()
        end
    end
end
