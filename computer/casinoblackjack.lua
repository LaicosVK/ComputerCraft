-- === Blackjack-Spiel (Deutsch) ===
local monitor, drive, speaker
local version = "v11"
local MIN_BET = 50
local BET_STEP = 50
local BIG_BET_STEP = 500
local MAX_BET = 1000000
local currentBet = MIN_BET
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
    monitor.setCursorPos(x, y)
    if bgColor then
        monitor.setBackgroundColor(bgColor)
        monitor.clearLine()
        monitor.setCursorPos(x, y)
    end
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
        if v == "A" then total = total + 11 aces = aces + 1
        elseif v == "K" or v == "Q" or v == "J" then total = total + 10
        else total = total + tonumber(v) end
    end
    while total > 21 and aces > 0 do
        total = total - 10
        aces = aces - 1
    end
    return total
end

local screenWidth, screenHeight = monitor.getSize()

local buttonY = {
    bet50 = screenHeight - 4,
    bet500 = screenHeight - 3,
    play = screenHeight
}

local function drawMainScreen()
    clear()
    centerText(2, "Blackjack 5:2 " .. version)
    centerText(4, "Casinokarte einlegen")
    centerText(screenHeight - 6, "Einsatz: " .. currentBet .. " Credits")
    centerText(buttonY.bet50,  "[-50]           [+50]", colors.gray)
    centerText(buttonY.bet500, "[-500]         [+500]", colors.gray)
    centerText(buttonY.play,   "   [ SPIELEN ]   ", colors.green)
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

local function displayHands(player, dealer, hideDealer)
    clear()
    if speaker then speaker.playSound("block.piston.extend") end
    centerText(2, "Dealer:")
    centerText(3, hideDealer and (dealer[1] .. " ??") or (table.concat(dealer, " ") .. " (" .. handValue(dealer) .. ")"))
    centerText(screenHeight - 4, "Deine Hand:")
    centerText(screenHeight - 3, table.concat(player, " ") .. " (" .. handValue(player) .. ")")
end

local function playerTurn(player, dealer)
    while true do
        displayHands(player, dealer, true)
        centerText(screenHeight - 1, "   [ ZIEHEN ]   ", colors.orange)
        centerText(screenHeight,     "   [ HALTEN ]   ", colors.lime)
        local _, _, x, y = os.pullEvent("monitor_touch")
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
        sleep(0.5)
    end
end

local function playGame(key)
    clear()
    centerText(2, "Spiel startet...")
    sleep(1)
    if not removeCredits(key, currentBet) then
        centerText(4, "Nicht genug Credits!")
        if speaker then speaker.playSound("block.anvil.land") end
        sleep(2)
        return
    end

    centerText(4, "Einsatz akzeptiert!")
    sleep(0.5)

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
        addCredits(key, win)
    elseif playerVal > dealerVal then
        centerText(screenHeight - 2, "Du gewinnst! +" .. (currentBet * 2) .. " Cr", colors.green)
        if speaker then speaker.playSound("entity.villager.yes") end
        addCredits(key, currentBet * 2)
    elseif playerVal == dealerVal then
        centerText(screenHeight - 2, "Unentschieden.", colors.yellow)
        centerText(screenHeight - 1, "Einsatz zurück.", colors.yellow)
        if speaker then speaker.playSound("block.note_block.hat") end
        addCredits(key, currentBet)
    else
        centerText(screenHeight - 2, "Dealer gewinnt.", colors.red)
        if speaker then speaker.playSound("entity.villager.no") end
    end
    sleep(4)
end

local function handleTouch(_, _, x, y)
    if y == buttonY.bet50 then
        if x <= screenWidth / 2 then
            currentBet = math.max(MIN_BET, currentBet - BET_STEP)
            if speaker then speaker.playSound("block.note_block.bass") end
        else
            currentBet = math.min(MAX_BET, currentBet + BET_STEP)
            if speaker then speaker.playSound("block.note_block.pling") end
        end
    elseif y == buttonY.bet500 then
        if x <= screenWidth / 2 then
            currentBet = math.max(MIN_BET, currentBet - BIG_BET_STEP)
            if speaker then speaker.playSound("block.note_block.bass") end
        else
            currentBet = math.min(MAX_BET, currentBet + BIG_BET_STEP)
            if speaker then speaker.playSound("block.note_block.pling") end
        end
    elseif y == buttonY.play then
        local key = getKey()
        if not key then
            centerText(screenHeight - 5, "Karte fehlt!")
            if speaker then speaker.playSound("block.anvil.land") end
            sleep(2)
        else
            playGame(key)
        end
    end
    drawMainScreen()
end

-- === Start ===
drawMainScreen()
while true do handleTouch(os.pullEvent("monitor_touch")) end
