-- === Blackjack Game ===
local monitor, drive
local playerKey = nil
local currentBet = 50
local MIN_BET = 50
local BET_STEP = 50
local MAX_BET = 1000

-- === Debug Helper ===
local function debugMessage(msg)
    print("[DEBUG] " .. msg)
end

-- === Peripheral Setup ===
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then
        monitor = peripheral.wrap(name)
    elseif t == "drive" then
        drive = peripheral.wrap(name)
    end
end

if not monitor or not drive then
    error("Monitor or drive not found")
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

-- === Helper Functions ===
local function clear()
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function centerText(y, text)
    local w, _ = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function drawMainScreen()
    clear()
    centerText(2, "🎲 Blackjack Casino 🎲")
    centerText(4, "Insert card and press Play")
    centerText(6, "Current Bet: " .. currentBet .. " Cr")
    centerText(8, "[ -50 ]")
    centerText(9, "[ +50 ]")
    centerText(11, "[ PLAY ]")
end

-- === Get Disk Key ===
local function getKey()
    local mountPath = drive.getMountPath()
    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        debugMessage("Key file not found.")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if file then
        local key = file.readAll()
        file.close()
        debugMessage("Read key: " .. key)
        return key
    else
        debugMessage("Failed to read player.key")
        return nil
    end
end

-- === Communication with Master Server ===
local function requestBalance(key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        return msg.balance
    end
    return nil
end

local function removeCredits(key, amount)
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

local function addCredits(key, amount)
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

-- === Event Handling ===
local function waitForTouch()
    while true do
        local e, side, x, y = os.pullEvent("monitor_touch")
        return x, y
    end
end

local function handleTouch(x, y)
    if y == 8 then
        currentBet = math.max(MIN_BET, currentBet - BET_STEP)
    elseif y == 9 then
        currentBet = math.min(MAX_BET, currentBet + BET_STEP)
    elseif y == 11 then
        playerKey = getKey()
        if not playerKey then
            centerText(13, "Insert card first!")
            sleep(2)
        else
            centerText(13, "Starting game...")
            sleep(1)
            -- Game logic would go here
        end
    end
    drawMainScreen()
end

-- === Main Loop ===
rednet.open("top")
drawMainScreen()

while true do
    local x, y = waitForTouch()
    handleTouch(x, y)
end
