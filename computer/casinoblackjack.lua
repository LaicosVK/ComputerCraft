-- === Load Config ===
local config = dofile("config.lua")
local cost = config.cost
local payout_small = config.payout_small
local payout_medium = config.payout_medium
local payout_big = config.payout_big

-- === Setup ===
local modemSide = "top"
local diskDriveSide = "left"
local monitor = peripheral.find("monitor")
rednet.open(modemSide)

-- === Symbols ===
local symbols = {
    { char = "A", tier = "small" },
    { char = "B", tier = "medium" },
    { char = "C", tier = "big" }
}

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
    if disk.hasData(diskDriveSide) then
        return fs.open(disk.getMountPath(diskDriveSide) .. "/key", "r"):readAll()
    end
    return nil
end

-- === Talk to Master ===
local function requestBalance(key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then return msg.balance end
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

-- === Slot Logic ===
local function spinSlots()
    local result = {}
    for i = 1, 3 do
        result[i] = symbols[math.random(1, #symbols)]
    end
    return result
end

local function evaluate(result)
    if result[1].char == result[2].char and result[2].char == result[3].char then
        if result[1].tier == "small" then return payout_small
        elseif result[1].tier == "medium" then return payout_medium
        elseif result[1].tier == "big" then return payout_big
        end
    end
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
    sleep(3)
end

-- === Main ===
drawScreen("idle")

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    if y == 7 and x >= 10 and x <= 17 then
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
                sleep(2)
            end
        end
        drawScreen("idle")
    end
end
