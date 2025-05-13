-- === Konfiguration ===
local version = "v1"
local monitor, drive
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then monitor = peripheral.wrap(name) end
    if t == "drive" then drive = peripheral.wrap(name) end
end
if not monitor or not drive then error("Monitor oder Disklaufwerk nicht gefunden.") end

monitor.setTextScale(1)
local w, h = monitor.getSize()

-- === Sounds ===
local speaker = peripheral.find("speaker")

-- === Debug ===
local function debug(msg)
    print("[DEBUG] " .. msg)
end

-- === Master Server Verbindung ===
local function getKey()
    if not drive.isDiskPresent() then return nil end
    local path = drive.getMountPath()
    if not path or not fs.exists(path .. "/player.key") then return nil end
    local f = fs.open(path .. "/player.key", "r")
    local key = f.readAll()
    f.close()
    return key
end

local function requestBalance(key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok and msg.balance or nil
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

-- === UI Logik ===
local bets = {
    { label = "Rot", field = "red", color = colors.red },
    { label = "Schwarz", field = "black", color = colors.gray },
    { label = "Gerade", field = "even", color = colors.lightBlue },
    { label = "Ungerade", field = "odd", color = colors.orange },
}

local function displayBetOptions(betAmounts)
    clear()
    center(1, "ROULETTE " .. version, colors.green)
    for i, b in ipairs(bets) do
        local label = b.label .. ": " .. betAmounts[b.field] .. " Cr"
        center(2 + i, label, b.color)
    end
    center(h - 2, "[ +50 ] [ -50 ]")
    center(h - 1, "[ SPIELEN ]", colors.lime)
end

-- === Spielregeln & Berechnung ===
local function spinRoulette()
    local options = { "rot", "schwarz" }
    local result = math.random(0, 36)
    local color = result == 0 and "grün" or (result % 2 == 0 and "rot" or "schwarz")
    return result, color
end

local function evaluateBet(betAmounts, result, color)
    local payout = 0
    if color == "rot" then payout = payout + (betAmounts.red or 0) * 2 end
    if color == "schwarz" then payout = payout + (betAmounts.black or 0) * 2 end
    if result % 2 == 0 and result ~= 0 then payout = payout + (betAmounts.even or 0) * 2 end
    if result % 2 == 1 then payout = payout + (betAmounts.odd or 0) * 2 end
    return payout
end

-- === Spiel Start ===
local function playGame(playerKey, betAmounts)
    local totalBet = 0
    for _, b in pairs(betAmounts) do totalBet = totalBet + b end

    if not removeCredits(playerKey, totalBet) then
        center(h / 2, "Nicht genug Credits!", colors.red)
        sleep(2)
        return
    end

    center(h / 2, "Kugel dreht...", colors.lightGray)
    sleep(2)
    local result, color = spinRoulette()
    center(h / 2 + 1, "Ergebnis: " .. result .. " (" .. color .. ")", colors.yellow)
    speaker.playSound("block.note_block.pling")

    local win = evaluateBet(betAmounts, result, color)
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

-- === Hauptschleife ===
local function main()
    rednet.open("top")
    local betAmounts = { red = 0, black = 0, even = 0, odd = 0 }
    local selectedBet = "red"

    while true do
        displayBetOptions(betAmounts)
        local _, _, x, y = os.pullEvent("monitor_touch")

        if y == h - 1 then
            local key = getKey()
            if not key then
                center(h / 2, "Keine Karte erkannt!", colors.red)
                speaker.playSound("entity.item.break")
                sleep(2)
            else
                playGame(key, betAmounts)
                betAmounts = { red = 0, black = 0, even = 0, odd = 0 }
            end
        elseif y == h - 2 then
            if x < w / 2 then
                betAmounts[selectedBet] = math.max((betAmounts[selectedBet] or 0) - 50, 0)
                speaker.playSound("block.note_block.bass")
            else
                betAmounts[selectedBet] = (betAmounts[selectedBet] or 0) + 50
                speaker.playSound("block.note_block.hat")
            end
        else
            local optionIndex = y - 2
            if bets[optionIndex] then
                selectedBet = bets[optionIndex].field
                speaker.playSound("block.lever.click")
            end
        end
    end
end

main()
