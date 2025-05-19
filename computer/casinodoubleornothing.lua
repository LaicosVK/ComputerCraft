-- Coin Flip Double or Nothing
local version = "1"
local initialBet = 100
local currentBet = initialBet
local gameState = "title"
local animationSpeed = 0.1

-- Peripherals
local drive = peripheral.find("drive")
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

local function centerText(y, text, color)
    monitor.setCursorPos(math.floor((width - #text) / 2) + 1, y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

-- Screens
local function drawTitle()
    clear()
    centerText(math.floor(height / 2) - 1, "Double or Nothing", colors.yellow)
    centerText(math.floor(height / 2), "v" .. version, colors.gray)
    centerText(math.floor(height / 2) + 2, "[ SPIELEN ]", colors.lime)
end

local function drawFlipScreen()
    clear()
    centerText(1, "Einsatz: " .. currentBet .. "¢", colors.yellow)
    centerText(math.floor(height / 2), "[Münze]", colors.white)
    monitor.setCursorPos(2, height - 2)
    monitor.setBackgroundColor(colors.lime)
    monitor.setTextColor(colors.black)
    monitor.clearLine()
    monitor.write("  FLIP  ")

    monitor.setCursorPos(width - 9, height - 2)
    monitor.setBackgroundColor(colors.red)
    monitor.setTextColor(colors.white)
    monitor.write("AUSZAHLEN")
end

local function drawLostScreen()
    clear()
    centerText(math.floor(height / 2), "Verloren!", colors.red)
    sleep(2)
    gameState = "title"
    currentBet = initialBet
    drawTitle()
end

local function drawWinAnimation()
    for i = 1, 6 do
        clear()
        local text = (i % 2 == 0) and "[Kopf]" or "[Zahl]"
        centerText(1, "Einsatz: " .. currentBet .. "¢", colors.yellow)
        centerText(math.floor(height / 2), text, colors.cyan)
        sleep(animationSpeed)
    end
end

-- Main Game Logic
local function tryStartGame()
    local key = getKey()
    if not key then
        clear()
        centerText(math.floor(height / 2), "Bitte Karte einlegen!", colors.orange)
        sleep(2)
        drawTitle()
        return
    end
    if not removeCredits(key, initialBet) then
        clear()
        centerText(math.floor(height / 2), "Nicht genug Guthaben!", colors.red)
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
        drawFlipScreen()
    end
end

local function tryPayout()
    local key = getKey()
    if not key then
        clear()
        centerText(math.floor(height / 2), "Karte fehlt!", colors.orange)
        sleep(2)
        drawFlipScreen()
        return
    end
    addCredits(key, currentBet)
    clear()
    centerText(math.floor(height / 2), "Auszahlung: " .. currentBet .. "¢", colors.lime)
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
        if y == height - 2 then
            if x <= 10 then
                tryFlip()
            elseif x >= width - 9 then
                tryPayout()
            end
        end
    end
end
