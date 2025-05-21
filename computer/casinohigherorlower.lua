-- === Higher or Lower (Deutsch) ===
local monitor, drive, speaker
local version = "v7"
local MIN_BET = 500
local BET_STEP = 500
local BIG_BET_STEP = 5000
local MAX_BET = 1000000
local currentBet = MIN_BET

-- === Peripherie-Erkennung ===
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then monitor = peripheral.wrap(name)
    elseif t == "drive" then drive = peripheral.wrap(name)
    elseif t == "speaker" then speaker = peripheral.wrap(name)
    elseif t == "modem" then rednet.open(name) end
end

if not monitor or not drive then error("Monitor oder Laufwerk nicht gefunden.") end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

math.randomseed(os.time())

local screenWidth, screenHeight = monitor.getSize()

local function clear() monitor.clear() monitor.setCursorPos(1, 1) end

local function centerText(y, text, bgColor)
    local w = select(1, monitor.getSize())
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    if bgColor then monitor.setBackgroundColor(bgColor) monitor.clearLine() monitor.setCursorPos(x, y) end
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

local function getKey()
    local mountPath = drive.getMountPath()
    if not mountPath or not fs.exists(mountPath .. "/player.key") then return nil end
    local file = fs.open(mountPath .. "/player.key", "r")
    local key = file.readAll()
    file.close()
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

-- === Game Variables ===
local currentNumber = 12
local round = 1
local streak = 0
local maxWrongGuesses = 3
local wrongGuesses = 0
local winnings = 0
local key = nil

-- === Screens ===
local function drawTitleScreen()
    clear()
    centerText(3, "Higher or Lower " .. version)
    centerText(screenHeight - 6, "Einsatz: " .. currentBet .. " Credits")
    centerText(screenHeight - 4, "[-" .. BET_STEP .. "]           [+" .. BET_STEP .. "]", colors.gray)
    centerText(screenHeight - 3, "[-" .. BIG_BET_STEP .. "]         [+" .. BIG_BET_STEP .."]", colors.gray)
    centerText(screenHeight - 1, "   [ SPIELEN ]   ", colors.green)
end

local function drawGameScreen()
    clear()
    centerText(2, "Runde: " .. round .. " | Serie: " .. streak)
    centerText(3, "Leben: " .. string.rep("\3 ", maxWrongGuesses - wrongGuesses))
    centerText(5, "[ HÖHER ]", colors.orange)
    centerText(7, "Zahl: " .. currentNumber, colors.gray)
    centerText(9, "[ NIEDRIGER ]", colors.orange)
    centerText(screenHeight, "[ AUSZAHLUNG: " .. winnings .. " Cr ]", colors.green)
end

local function drawStatsScreen(wonAmount)
    clear()
    centerText(4, "Spiel beendet!")
    centerText(6, "Runden: " .. round )
    centerText(7, "Richtige Serie: " .. streak )
    centerText(8, "Verbleibende Leben: " .. string.rep("\3 ", maxWrongGuesses - wrongGuesses))
    centerText(10, wonAmount > 0 and ("Gewonnen: " .. wonAmount .. " Credits") or "Verloren!", wonAmount > 0 and colors.green or colors.red)
    if wonAmount > 0 then addCredits(key, wonAmount) end
    sleep(4)
    drawTitleScreen()
end

-- === Game Logic ===
local function calculateWinnings()
    return math.floor(currentBet * (1 + (streak * 0.2) + ((round-2) * 0.5)))
end

local function gameStep(choice)
    local newRoll
    repeat
        newRoll = math.random(1, 12)
    until newRoll ~= currentNumber

    local correct = (choice == "higher" and newRoll > currentNumber) or (choice == "lower" and newRoll < currentNumber)
    currentNumber = newRoll
    round = round + 1
    if correct then
        streak = streak + 1
        winnings = calculateWinnings()
        if speaker then speaker.playSound("entity.player.levelup") end
    else
        wrongGuesses = wrongGuesses + 1
        streak = 0
        if speaker then speaker.playSound("entity.villager.no") end
        if wrongGuesses >= maxWrongGuesses then drawStatsScreen(0) return false end
    end
    drawGameScreen()
    return true
end

-- === Main Handler ===
local function handleTouch(_, _, x, y)
    if y == screenHeight - 4 then
        if x <= screenWidth / 2 then
            currentBet = math.max(MIN_BET, currentBet - BET_STEP)
        else
            currentBet = math.min(MAX_BET, currentBet + BET_STEP)
        end
    elseif y == screenHeight - 3 then
        if x <= screenWidth / 2 then
            currentBet = math.max(MIN_BET, currentBet - BIG_BET_STEP)
        else
            currentBet = math.min(MAX_BET, currentBet + BIG_BET_STEP)
        end
    elseif y == screenHeight - 1 then
        key = getKey()
        if not key then centerText(2, "Karte fehlt!") sleep(2) drawTitleScreen() return end
        if not removeCredits(key, currentBet) then centerText(2, "Nicht genug Credits!") sleep(2) drawTitleScreen() return end
        round, streak, winnings, currentNumber, wrongGuesses = 1, 0, 0, 6, 0
        drawGameScreen()
        while true do
            local e = { os.pullEvent("monitor_touch") }
            if e[4] == 5 then
                if not gameStep("higher") then break end
            elseif e[4] == 9 then
                if not gameStep("lower") then break end
            elseif e[4] == screenHeight then
                drawStatsScreen(winnings)
                break
            end
        end
    end
    drawTitleScreen()
end

-- === Start ===
drawTitleScreen()
while true do handleTouch(os.pullEvent("monitor_touch")) end
