-- === Load Config ===
local config = dofile("config.lua")
local cost = config.cost
local payout_small = config.payout_small
local payout_medium = config.payout_medium
local payout_big = config.payout_big

-- === Setup ===
local modemSide = "top"
local diskDrive = peripheral.find("drive")
local diskDriveSide = diskDrive and peripheral.getName(diskDrive)
local monitor = peripheral.find("monitor")
rednet.open(modemSide)

-- === Symbols & Weights ===
local symbolPool = {
    { char = "\x02", tier = "small", weight = 50 },
    { char = "\x0F", tier = "medium", weight = 30 },
    { char = "\x03", tier = "big", weight = 20 },
}

-- === Weighted Random Symbol ===
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

-- === Debug Function ===
local function debugMessage(msg)
    print("[DEBUG] " .. msg)
end

-- === UI ===
local function centerText(line, text)
    local w, _ = monitor.getSize()
    monitor.setCursorPos(math.floor((w - #text) / 2) + 1, line)
    monitor.write(text)
end

local function drawScreen(state)
    monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
    centerText(2, "Slot Machine")
    centerText(4, "Insert Member Card")

    if state == "idle" then
        centerText(6, "Cost: " .. cost .. " credits")
        monitor.setBackgroundColor(colors.green)
        monitor.setTextColor(colors.black)
        centerText(8, "[   PLAY   ]")
        monitor.setBackgroundColor(colors.black)
    elseif state == "spinning" then
        centerText(6, "Spinning...")
    elseif state == "error" then
        centerText(6, "Error!")
    end
end

-- === Get Disk Key ===
local function getKey()
    -- Locate a connected disk drive peripheral
    local driveName
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            driveName = name
            break
        end
    end

    if not driveName then
        debugMessage("Kein Disklaufwerk gefunden.")
        return nil
    end

    local drive = peripheral.wrap(driveName)
    if not drive.isDiskPresent() then
        debugMessage("Keine Diskette im Laufwerk.")
        return nil
    end

    local mountPath = drive.getMountPath()
    debugMessage("Mount-Pfad: " .. (mountPath or "nil"))

    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        debugMessage("Datei player.key nicht gefunden bei: " .. (mountPath or "nil") .. "/player.key")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if file then
        local key = file:readAll()
        file:close()
        debugMessage("Key gelesen: " .. key)
        return key
    else
        debugMessage("Fehler beim Lesen von player.key.")
        return nil
    end
end


-- === Talk to Master ===
local function requestBalance(key)
    debugMessage("Requesting balance for key: " .. key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Balance: " .. msg.balance)
        return msg.balance
    end
    debugMessage("Failed to get balance.")
    return nil
end

local function removeCredits(key, amount)
    debugMessage("Removing " .. amount .. " credits.")
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Credits removed.")
        return true
    end
    debugMessage("Failed to remove credits.")
    return false
end

local function addCredits(key, amount)
    debugMessage("Adding " .. amount .. " credits.")
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Credits added.")
        return true
    end
    debugMessage("Failed to add credits.")
    return false
end

-- === Slot Logic mit Animation ===
local function spinSlots()
    debugMessage("Starte Slot-Animation...")

    local result = { nil, nil, nil }
    local spinSymbols = {}

    -- Initialisiere alle 3 Spalten mit Zufallswerten
    for i = 1, 3 do
        spinSymbols[i] = getRandomSymbol()
    end

    -- Anzahl an Wiederholungen für jeden Abschnitt
    local spinCounts = { 15, 10, 6 }

    for frame = 1, spinCounts[1] do
        -- Erzeuge neue Symbole für alle drei, solange sie nicht "stehen bleiben"
        for i = 1, 3 do
            if frame <= spinCounts[i] then
                spinSymbols[i] = getRandomSymbol()
            end
        end

        -- Darstellung auf Zeile 6
        local display = ""
        for i = 1, 3 do
            display = display .. spinSymbols[i].char
            if i < 3 then
                display = display .. " | "
            end
        end
        centerText(6, display)
        sleep(0.1)
    end

    -- Speichere das finale Ergebnis
    for i = 1, 3 do
        result[i] = spinSymbols[i]
        debugMessage("Slot " .. i .. ": " .. result[i].char)
    end

    return result
end

local function evaluate(result)
    debugMessage("Evaluating result...")
    if result[1].char == result[2].char and result[2].char == result[3].char then
        local tier = result[1].tier
        debugMessage("Match! Tier: " .. tier)
        if tier == "small" then return payout_small
        elseif tier == "medium" then return payout_medium
        elseif tier == "big" then return payout_big
        end
    end
    debugMessage("No win.")
    return 0
end

local function showResult(result, mult, payout)
    monitor.clear()
    centerText(2, "Result:")
    local line = 6
    centerText(line, result[1].char .. " | " .. result[2].char .. " | " .. result[3].char)
    line = line + 4
    if mult > 0 then
        centerText(line, "Du gewinnst " .. payout .. " credits!")
    else
        centerText(line, "Schade...")
    end
    sleep(3)
end

-- === Main Loop ===
drawScreen("idle")

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if y == 8 then
        debugMessage("Play button pressed.")
        drawScreen("spinning")

        local key = getKey()
        if not key then
            drawScreen("Keine valide Karte")
            sleep(2)
            drawScreen("idle")
        else
            local balance = requestBalance(key)
            if balance and balance >= cost then
                if removeCredits(key, cost) then
                    local result = spinSlots()
                    local mult = evaluate(result)
                    local payout = mult * cost
                    if payout > 0 then addCredits(key, payout) end
                    showResult(result, mult, payout)
                else
                    drawScreen("error")
                    sleep(2)
                end
            else
                monitor.clear()
                centerText(5, "Not enough credits")
                debugMessage("Balance too low.")
                sleep(2)
            end
            drawScreen("idle")
        end
    end
end
