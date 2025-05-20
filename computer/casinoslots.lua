-- === Load Config ===
local config = dofile("config.lua")
local defaultCost = config.cost
local payout_small = config.payout_small
local payout_medium = config.payout_medium
local payout_big = config.payout_big
local version = "17"

-- === Setup ===
local modemSide = "bottom"
local diskDrive = peripheral.find("drive")
local diskDriveSide = diskDrive and peripheral.getName(diskDrive)
local monitor = peripheral.find("monitor")
local speaker = peripheral.wrap("right")
rednet.open(modemSide)

-- === Game State ===
local currentBet = defaultCost

-- === Constants ===
local minBet = 50
local maxBet = 100000

-- === Symbols & Weights ===
local symbolPool = {
    { char = "\x02", tier = "small", weight = 50 },
    { char = "\x0F", tier = "medium", weight = 30 },
    { char = "\x03", tier = "big", weight = 20 },
}

local lockSounds = {
    "block.chain.place",
    "block.chain.place",
    "block.chain.place"
}

-- === Utility ===
local function debugMessage(msg)
    print("[DEBUG] " .. msg)
end

local function centerText(line, text)
    local w = monitor.getSize()
    monitor.setCursorPos(math.floor((w - #text) / 2) + 1, line)
    monitor.write(text)
end

-- === Bet UI ===
local function drawScreen(state)
    local w, _ = monitor.getSize()
    monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    -- Title
    centerText(2, "Slot Machine v." .. version)

    if state == "idle" then
        centerText(5, "Einsatz: " .. currentBet .. " Credits")

        -- Bet adjustment buttons
        monitor.setCursorPos(8, 8)
        monitor.write("[ -50 ]")
        monitor.setCursorPos(18, 8)
        monitor.write("[ +50 ]")
        monitor.setCursorPos(8, 9)
        monitor.write("[ -500 ]")
        monitor.setCursorPos(18, 9)
        monitor.write("[ +500 ]")

        -- Green full-width play button
        monitor.setBackgroundColor(colors.green)
        monitor.setTextColor(colors.black)
        monitor.setCursorPos(1, 12)
        monitor.clearLine()
        centerText(12, "[   SPIELEN   ]")
        monitor.setBackgroundColor(colors.black)
        monitor.setTextColor(colors.white)

    elseif state == "spinning" then
        centerText(6, "Spinning...")
    elseif state == "error" then
        centerText(6, "Fehler!")
    end
end

-- === Key Functions ===
local function getKey()
    local drive = diskDrive
    if not drive or not drive.isDiskPresent() then return nil end

    local mountPath = drive.getMountPath()
    if not mountPath or not fs.exists(mountPath .. "/player.key") then return nil end

    local file = fs.open(mountPath .. "/player.key", "r")
    if file then
        local key = file.readAll()
        file.close()
        return key
    end
end

-- === Rednet Communication ===
local function requestBalance(key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok and msg.balance or nil
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

-- === Slot Logic ===
local function getRandomSymbol()
    local totalWeight = 0
    for _, s in ipairs(symbolPool) do totalWeight = totalWeight + s.weight end
    local pick = math.random(totalWeight)
    local cumulative = 0
    for _, s in ipairs(symbolPool) do
        cumulative = cumulative + s.weight
        if pick <= cumulative then return s end
    end
end

local function spinSlots()
    local result = { nil, nil, nil }
    local spinSymbols = {}
    local spinCounts = { 11, 22, 33 }
    local spinChars = { "|", "/", "-", "\\" }

    for i = 1, 3 do spinSymbols[i] = getRandomSymbol() end

    for frame = 1, spinCounts[3] do
        for i = 1, 3 do
            if frame <= spinCounts[i] then spinSymbols[i] = getRandomSymbol() end
        end

        local parts = {}
        local sep = spinChars[(frame - 1) % #spinChars + 1]
        for i = 1, 3 do
            local char = (frame > spinCounts[i]) and "." .. spinSymbols[i].char .. "." or " " .. spinSymbols[i].char .. " "
            parts[#parts + 1] = char
        end

        centerText(6, table.concat(parts, sep))
        speaker.playSound("block.bamboo.place")
        for i = 1, 3 do if frame == spinCounts[i] + 1 then speaker.playSound(lockSounds[i]) end end
        sleep(0.3)
    end

    for i = 1, 3 do result[i] = spinSymbols[i] end
    return result
end

local function evaluate(result)
    if result[1].char == result[2].char and result[2].char == result[3].char then
        local tier = result[1].tier
        return (tier == "small" and payout_small) or (tier == "medium" and payout_medium) or (tier == "big" and payout_big) or 0
    end
    return 0
end

local function showResult(result, mult, payout, balance)
    monitor.clear()
    centerText(2, "Ergebnis:")
    centerText(6, result[1].char .. " | " .. result[2].char .. " | " .. result[3].char)
    centerText(10, mult > 0 and ("Du gewinnst " .. payout .. " Credits!") or "Schade...")
    centerText(12, "Kontostand: " .. (balance - currentBet + payout) .. " Credits")
    speaker.playSound(mult > 0 and "minecraft:entity.villager.yes" or "minecraft:entity.villager.no")
    sleep(3)
end

-- === Main Loop ===
drawScreen("idle")

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    -- Increase/Decrease buttons
    if y == 8 and x >= 8 and x <= 14 then
        currentBet = math.max(minBet, currentBet - 50)
    elseif y == 8 and x >= 18 and x <= 24 then
        currentBet = math.min(maxBet, currentBet + 50)
    elseif y == 9 and x >= 8 and x <= 14 then
        currentBet = math.max(minBet, currentBet - 500)
    elseif y == 9 and x >= 18 and x <= 24 then
        currentBet = math.min(maxBet, currentBet + 500)
    elseif y == 12 then
        drawScreen("spinning")
        local key = getKey()
        if not key then
            centerText(6, "Keine Karte")
            sleep(2)
        else
            local balance = requestBalance(key)
            if balance and balance >= currentBet then
                if removeCredits(key, currentBet) then
                    local result = spinSlots()
                    local mult = evaluate(result)
                    local payout = mult * currentBet
                    if payout > 0 then addCredits(key, payout) end
                    showResult(result, mult, payout, balance)
                else
                    drawScreen("error")
                    sleep(2)
                end
            else
                centerText(6, "Zu wenig Credits.")
                sleep(2)
            end
        end
    end
    drawScreen("idle")
end
