-- === Load Config ===
local config = dofile("config.lua")
local cost = config.cost
local payout_small = config.payout_small
local payout_medium = config.payout_medium
local payout_big = config.payout_big

-- === Setup ===
local modemSide = "top"
local diskDriveSide = "left"  -- Set disk drive on the left
local monitor = peripheral.find("monitor")
local diskDrive = peripheral.wrap(diskDriveSide)
rednet.open(modemSide)

-- === Symbols ===
local symbols = {
    { char = "A", tier = "small" },
    { char = "B", tier = "medium" },
    { char = "C", tier = "big" }
}

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
    centerText(1, "Slot Machine")
    centerText(3, "Insert Member Card")

    if state == "idle" then
        centerText(5, "Press to Play (" .. cost .. "C)")
        monitor.setBackgroundColor(colors.green)
        monitor.setTextColor(colors.white)
        monitor.setCursorPos(10, 7)
        monitor.write("[ PLAY ]")
    elseif state == "spinning" then
        centerText(5, "Spinning...")
    elseif state == "error" then
        centerText(5, "Error!")
    end
end

-- === Get Disk Key ===
local function getKey()
    -- Check if a disk is present by verifying mount path
    local mountPath = diskDrive.getMountPath()
    if not mountPath or not fs.exists(mountPath) then
        debugMessage("No disk in the drive.")
        return nil
    end

    -- Attempt to read the key from the disk
    debugMessage("Disk found, reading key...")
    local file = fs.open(mountPath .. "/key", "r")
    if file then
        local key = file:readAll()
        file:close()
        debugMessage("Key read: " .. key)
        return key
    else
        debugMessage("Failed to read key from disk.")
        return nil
    end
end

-- === Talk to Master ===
local function requestBalance(key)
    debugMessage("Requesting balance for key: " .. key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Balance received: " .. (msg.balance or 0))
        return msg.balance
    end
    debugMessage("Failed to receive balance.")
    return nil
end

local function removeCredits(key, amount)
    debugMessage("Attempting to remove " .. amount .. " credits from " .. key)
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Credits removed successfully. New balance: " .. (msg.newBalance or 0))
        return true
    end
    debugMessage("Failed to remove credits.")
    return false
end

local function addCredits(key, amount)
    debugMessage("Adding " .. amount .. " credits to " .. key)
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        debugMessage("Credits added successfully. New balance: " .. (msg.newBalance or 0))
        return true
    end
    debugMessage("Failed to add credits.")
    return false
end

-- === Slot Logic ===
local function spinSlots()
    debugMessage("Spinning the slots...")
    local result = {}
    for i = 1, 3 do
        result[i] = symbols[math.random(1, #symbols)]
        debugMessage("Slot " .. i .. " result: " .. result[i].char)
    end
    return result
end

local function evaluate(result)
    debugMessage("Evaluating result...")
    if result[1].char == result[2].char and result[2].char == result[3].char then
        debugMessage("Match found! Tier: " .. result[1].tier)
        if result[1].tier == "small" then return payout_small
        elseif result[1].tier == "medium" then return payout_medium
        elseif result[1].tier == "big" then return payout_big
        end
    end
    debugMessage("No match, no payout.")
    return 0
end

local function showResult(result, winMult)
    monitor.clear()
    centerText(2, "Result:")
    local line = 4
    local symbolsStr = result[1].char .. " | " .. result[2].char .. " | " .. result[3].char
    centerText(line, symbolsStr)
    line = line + 2
    if winMult > 0 then
        centerText(line, "You Win x" .. winMult .. "!")
    else
        centerText(line, "You Lose!")
    end
    debugMessage("Displayed result.")
    sleep(3)
end

-- === Main ===
drawScreen("idle")

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if y == 7 and x >= 10 and x <= 17 then
        debugMessage("Play button pressed.")
        drawScreen("spinning")

        local key = getKey()
        if not key then
            drawScreen("error")
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
                    showResult(result, mult)
                else
                    drawScreen("error")
                    sleep(2)
                end
            else
                monitor.clear()
                centerText(5, "Not enough credits")
                debugMessage("Insufficient balance.")
                sleep(2)
            end
        end
        drawScreen("idle")
    end
end
