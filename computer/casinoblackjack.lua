-- === Blackjack-Spiel (Deutsch) ===
local monitor, drive, speaker
local playerKey = nil
local currentBet = 50
local MIN_BET = 50
local BET_STEP = 50
local MAX_BET = 100000

local version = "v10"
local suits = { "\06", "\03", "\04", "\05" }
local values = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

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

-- === Hilfsfunktionen ===
local function clear()
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function centerText(y, text, bgColor)
    local w = select(1, monitor.getSize())
    local x = math.floor((w - #text) / 2) + 1
    if bgColor then
        monitor.setBackgroundColor(bgColor)
        monitor.setCursorPos(1, y)
        monitor.clearLine()
    end
    monitor.setCursorPos(x, y)
    monitor.setTextColor(colors.white)
    monitor.write(text)
    monitor.setBackgroundColor(colors.black)
end

local function drawCard()
    local value = values[math.random(#values)]
    local suit = suits[math.random(#suits)]
    return value .. suit
end

local function handValue(hand)
    local total, aces = 0, 0
    for _, card in ipairs(hand) do
        local v = card:sub(1, -2)
        if v == "A" then
            total = total + 11
            aces = aces + 1
        elseif v == "K" or v == "Q" or v == "J" then
            total = total + 10
        else
            total = total + tonumber(v)
        end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

-- === Benutzeroberfläche ===
local _, screenHeight = monitor.getSize()

local buttonY = {
    betLine1 = screenHeight - 3,
    betLine2 = screenHeight - 2,
    play = screenHeight
}

local function drawMainScreen()
    clear()
    centerText(2, "Blackjack 5:2 " .. version)
    centerText(4, "Casinokarte einlegen")
    centerText(screenHeight - 5, "Einsatz: " .. currentBet .. " Credits")
    centerText(buttonY.betLine1, "[ -500 ] [ -50 ] [ +50 ] [ +500 ]", colors.gray)
    centerText(buttonY.betLine2, "           [ SPIELEN ]           ", colors.lime)
end

-- === Serverkommunikation ===
local function getKey()
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

-- === Spiel-Logik ===
local function displayHands(player, dealer, hideDealer)
    clear()
    if speaker then speaker.playSound("block.piston.extend") end
    centerText(2, "Dealer:")
    centerText(3, hideDealer and (dealer[1] .. " ??") or table.concat(dealer, " ") .. " (" .. handValue(dealer) .. ")")
    centerText(screenHeight - 4, "Deine Hand:")
    centerText(screenHeight - 3, table.concat(player, " ") .. " (" .. handValue(player) .. ")")
end

local function playerTurn(player, dealer)
    while true do
        displayHands(player, dealer, true)
        centerText(screenHeight - 1, "   [ ZIEHEN ]   ", colors.orange)
        centerText(screenHeight,     "   [ HALTEN ]   ", colors.lime)
        local _, _, _, y = os.pullEvent("monitor_touch")
        if y == screenHeight - 1 then
            table.insert(player, drawCard())
            if speaker then speaker.playSound("entity.item.pickup") end
            if handValue(player) > 21 then return false, player end
        elseif y == screenHeight then
            if speaker then speaker.playSound("block.lever.click") end
            return true, player
        end
    end
end

local function dealerTurn(dealer)
    while handValue(dealer) < 17 do
        table.insert(dealer, drawCard())
        sleep(0.7)
    end
end

local function playGame()
    clear()
    centerText(2, "Spiel startet...")
    sleep(1)

    if not removeCredits(playerKey, currentBet) then
        centerText(4, "Nicht genug Credits!")
        sleep(2)
        return
    end

    local player = { drawCard(), drawCard() }
    local dealer = { drawCard(), drawCard() }

    local continued, finalPlayer = playerTurn(player, dealer)
    local playerVal = handValue(finalPlayer)

    dealerTurn(dealer)
    local dealerVal = handValue(dealer)

    displayHands(finalPlayer, dealer, false)

    if playerVal > 21 then
        centerText(screenHeight - 2, "Du hast verloren.", colors.red)
        if speaker then speaker.playSound("entity.zombie.infect") end
    elseif dealerVal > 21 then
        local win = currentBet / 2 * 5
        centerText(screenHeight - 2, "Dealer bust! Du gewinnst! +" .. win .. " Cr", colors.green)
        if speaker then speaker.playSound("entity.player.levelup") end
        addCredits(playerKey, win)
    elseif playerVal > dealerVal then
        centerText(screenHeight - 2, "Du gewinnst! +" .. (currentBet * 2) .. " Cr", colors.green)
        if speaker then speaker.playSound("entity.villager.yes") end
        addCredits(playerKey, currentBet * 2)
    elseif playerVal == dealerVal then
        centerText(screenHeight - 2, "Unentschieden.", colors.yellow)
        centerText(screenHeight - 1, "Einsatz zurück.", colors.yellow)
        if speaker then speaker.playSound("block.note_block.hat") end
        addCredits(playerKey, currentBet)
    else
        centerText(screenHeight - 2, "Dealer gewinnt.", colors.red)
        if speaker then speaker.playSound("entity.villager.no") end
    end

    sleep(4)
end

-- === Eingabe-Verarbeitung ===
local function handleTouch(_, _, x, y)
    if y == buttonY.betLine1 then
        if x <= 10 then
            currentBet = math.max(MIN_BET, currentBet - 500)
        elseif x <= 20 then
            currentBet = math.max(MIN_BET, currentBet - 50)
        elseif x <= 30 then
            currentBet = math.min(MAX_BET, currentBet + 50)
        else
            currentBet = math.min(MAX_BET, currentBet + 500)
        end
        if speaker then speaker.playSound("block.note_block.pling") end
    elseif y == buttonY.play then
        playerKey = getKey()
        if not playerKey then
            centerText(screenHeight - 4, "Karte fehlt!", colors.red)
            if speaker then speaker.playSound("block.anvil.land") end
            sleep(2)
        else
            playGame()
        end
    end
    drawMainScreen()
end

-- === Hauptprogramm ===
drawMainScreen()
while true do
    handleTouch(os.pullEvent("monitor_touch"))
end
