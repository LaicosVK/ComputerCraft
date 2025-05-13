local VERSION = "v15"

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

local function center(y, text, bg, fg)
    local x = math.floor((w - #text) / 2) + 1
    if bg then monitor.setBackgroundColor(bg) end
    if fg then monitor.setTextColor(fg) else monitor.setTextColor(colors.white) end
    monitor.setCursorPos(x, y)
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
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
        local valueText = ""
        if b.field == "number" then
            valueText = (selectedNumber or "-") .. " (" .. (betAmounts.number or 0) .. " Cr)"
        else
            valueText = tostring(betAmounts[b.field] or 0) .. " Cr"
        end
        center(2 + i, b.label .. ": " .. valueText, b.color)
    end
    center(h - 4, "[ -50 ] [ +50 ]    [ -500 ] [ +500 ]")
    center(h - 2, "[ ZAHL EINGEBEN ]")
    center(h - 1, "[ SPIELEN ]", colors.lime)
end

local function spinAnimation()
    local symbols = {}
    for i = 0, 36 do table.insert(symbols, tostring(i)) end
    for i = 1, 20 do
        clear()
        center(h / 2, symbols[math.random(1, #symbols)], colors.lightGray)
        sleep(0.1 + (i * 0.02))
    end
end

local function spinRoulette()
    local result = math.random(0, 36)
    local color = result == 0 and "grün" or (result % 2 == 0 and "rot" or "schwarz")
    local parity = result == 0 and "-" or (result % 2 == 0 and "GERADE" or "UNGERADE")
    return result, color, parity
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
    local result, color, parity = spinRoulette()
    clear()
    center(h / 2 - 1, tostring(result), colors.yellow)
    local colorBg = color == "rot" and colors.red or color == "schwarz" and colors.gray or colors.green
    center(h / 2, color:upper(), colorBg, colors.white)
    local parityBg = parity == "GERADE" and colors.lightBlue or parity == "UNGERADE" and colors.orange or colors.green
    center(h / 2 + 1, parity, parityBg, colors.black)
    local win = evaluateBet(betAmounts, result, color, selectedNumber)
    if win > 0 then
        center(h / 2 + 2, "Gewinn: " .. win .. " Cr", colors.green)
        addCredits(playerKey, win)
        speaker.playSound("entity.player.levelup")
    else
        center(h / 2 + 2, "Leider verloren!", colors.red)
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
                local y = 3 + (row - 1) * 2
                drawButton(x, y, 5, 1, label)
            end
        end

        local _, _, x, y = os.pullEvent("monitor_touch")

        for row = 1, 4 do
            for col = 1, 3 do
                local bx = 4 + (col - 1) * 6
                local by = 3 + (row - 1) * 2
                if x >= bx and x < bx + 5 and y == by then
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

-- === Main Loop ===
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
            selectedBet = "number"
            speaker.playSound("block.note_block.pling")
        elseif y == h - 4 then
            if x < 10 then
                betAmounts[selectedBet] = math.max((betAmounts[selectedBet] or 0) - 50, 0)
                speaker.playSound("block.note_block.bass")
            elseif x < 20 then
                betAmounts[selectedBet] = (betAmounts[selectedBet] or 0) + 50
                speaker.playSound("block.note_block.hat")
            elseif x < 30 then
                betAmounts[selectedBet] = math.max((betAmounts[selectedBet] or 0) - 500, 0)
                speaker.playSound("block.note_block.bass")
            else
                betAmounts[selectedBet] = (betAmounts[selectedBet] or 0) + 500
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
