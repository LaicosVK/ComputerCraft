local VERSION = "v6"

-- === Setup ===
local monitor, drive = nil, nil
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then monitor = peripheral.wrap(name) end
    if t == "drive" then drive = peripheral.wrap(name) end
end
if not monitor or not drive then error("Monitor oder Laufwerk nicht gefunden.") end

monitor.setTextScale(1)
local w, h = monitor.getSize()
local speaker = peripheral.find("speaker")

-- === Anzeige ===
local function clear()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
end

local function center(y, text, bg)
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    if bg then monitor.setBackgroundColor(bg) end
    monitor.write(text)
    if bg then monitor.setBackgroundColor(colors.black) end
end

local function drawButton(x, y, width, height, label)
    monitor.setBackgroundColor(colors.lightGray)
    for dy = 0, height - 1 do
        monitor.setCursorPos(x, y + dy)
        monitor.write(string.rep(" ", width))
    end
    monitor.setTextColor(colors.black)
    monitor.setCursorPos(x + math.floor((width - #label) / 2), y + math.floor(height / 2))
    monitor.write(label)
    monitor.setTextColor(colors.white)
    monitor.setBackgroundColor(colors.black)
end

-- === Master Server Kommunikation ===
local function getKey()
    if not drive.isDiskPresent() then return nil end
    local path = drive.getMountPath()
    if not path or not fs.exists(path .. "/player.key") then return nil end
    local f = fs.open(path .. "/player.key", "r")
    local key = f.readAll()
    f.close()
    return key
end

local function addCredits(key, amount)
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

local function removeCredits(key, amount)
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

-- === Optionen ===
local bets = {
    { label = "Rot", field = "red", color = colors.red },
    { label = "Schwarz", field = "black", color = colors.gray },
    { label = "Gerade", field = "even", color = colors.lightBlue },
    { label = "Ungerade", field = "odd", color = colors.orange },
    { label = "Zahl", field = "number", color = colors.green },
}

local function displayBetOptions(betAmounts, selectedNumber)
    clear()
    center(1, "ROULETTE " .. VERSION, colors.green)
    for i, b in ipairs(bets) do
        local label = b.label .. ": " .. (b.field == "number" and selectedNumber or betAmounts[b.field] or 0) .. (b.field ~= "number" and " Cr" or "")
        center(2 + i, label, b.color)
    end
    center(h - 3, "[ -50 ] [ +50 ]")
    center(h - 2, "[ ZAHL EINGEBEN ]")
    center(h - 1, "[ SPIELEN ]", colors.lime)
end

local function spinAnimation()
    local symbols = {}
    for i = 0, 36 do table.insert(symbols, tostring(i)) end
    for i = 1, 20 do
        clear()
        center(h / 2, "Kugel dreht: " .. symbols[math.random(1, #symbols)], colors.lightGray)
        sleep(0.1 + (i * 0.02))
    end
end

local function spinRoulette()
    local result = math.random(0, 36)
    local color = result == 0 and "grün" or (result % 2 == 0 and "rot" or "schwarz")
    return result, color
end

local function evaluateBet(betAmounts, result, color, selectedNumber)
    local payout = 0
    if color == "rot" then payout = payout + (betAmounts.red or 0) * 2 end
    if color == "schwarz" then payout = payout + (betAmounts.black or 0) * 2 end
    if result % 2 == 0 and result ~= 0 then payout = payout + (betAmounts.even or 0) * 2 end
    if result % 2 == 1 then payout = payout + (betAmounts.odd or 0) * 2 end
    if tonumber(selectedNumber) == result then payout = payout + (betAmounts.number or 0) * 36 end
    return payout
end

local function playGame(playerKey, betAmounts, selectedNumber)
    local totalBet = 0
    for _, b in pairs(betAmounts) do totalBet = totalBet + b end
    if totalBet == 0 then
        center(h / 2, "Kein Einsatz!", colors.red)
        sleep(2)
        return
    end
    if not removeCredits(playerKey, totalBet) then
        center(h / 2, "Nicht genug Credits!", colors.red)
        sleep(2)
        return
    end
    center(h / 2, "Kugel dreht...", colors.lightGray)
    spinAnimation()
    local result, color = spinRoulette()
    clear()
    center(h / 2, "Ergebnis: " .. result .. " (" .. color .. ")", colors.yellow)
    local win = evaluateBet(betAmounts, result, color, selectedNumber)
    if win > 0 then
        center(h / 2 + 1, "Gewinn: " .. win .. " Cr", colors.green)
        addCredits(playerKey, win)
        speaker.playSound("entity.player.levelup")
    else
        center(h / 2 + 1, "Leider verloren!", colors.red)
        speaker.playSound("entity.villager.no")
    end
    sleep(4)
end

local function handleNumberPad()
    local input = ""
    local keys = {
        { "1", "2", "3" },
        { "4", "5", "6" },
        { "7", "8", "9" },
        { "C", "0", "OK" }
    }
    while true do
        clear()
        center(1, "Zahl eingeben:", colors.green)
        center(2, input)

        for row = 1, 4 do
            for col = 1, 3 do
                local label = keys[row][col]
                local x = 4 + (col - 1) * 6
                local y = 3 + (row - 1) * 2  -- Adjusted the Y position to fit the height
                drawButton(x, y, 5, 1, label)  -- Reduced button height to 1
            end
        end

        local _, _, x, y = os.pullEvent("monitor_touch")

        for row = 1, 4 do
            for col = 1, 3 do
                local bx = 4 + (col - 1) * 6
                local by = 3 + (row - 1) * 2
                if x >= bx and x < bx + 5 and y >= by and y < by + 1 then
                    local label = keys[row][col]
                    if label == "C" then
                        input = ""
                    elseif label == "OK" then
                        return tonumber(input)
                    else
                        input = input .. label
                    end
                end
            end
        end
    end
end

local function main()
    rednet.open("top")
    local betAmounts = { red = 0, black = 0, even = 0, odd = 0, number = 0 }
    local selectedBet = "red"
    local selectedNumber = 0

    while true do
        displayBetOptions(betAmounts, selectedNumber)
        local _, _, x, y = os.pullEvent("monitor_touch")

        if y == h - 1 then
            local key = getKey()
            if not key then
                center(h / 2, "Keine Karte erkannt!", colors.red)
                speaker.playSound("entity.item.break")
                sleep(2)
            else
                playGame(key, betAmounts, selectedNumber)
                betAmounts = { red = 0, black = 0, even = 0, odd = 0, number = 0 }
                selectedNumber = 0
            end
        elseif y == h - 2 then
            selectedNumber = handleNumberPad() or 0
            speaker.playSound("block.note_block.pling")
        elseif y == h - 3 then
            if x < w / 2 then
                betAmounts[selectedBet] = math.max((betAmounts[selectedBet] or 0) - 50, 0)
                speaker.playSound("block.note_block.bass")
            else
                betAmounts[selectedBet] = (betAmounts[selectedBet] or 0) + 50
                speaker.playSound("block.note_block.hat")
            end
        elseif y >= 3 and y <= 7 then
            local idx = y - 2
            if bets[idx] then
                selectedBet = bets[idx].field
                speaker.playSound("block.lever.click")
            end
        end
    end
end

main()
