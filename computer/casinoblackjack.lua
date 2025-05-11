-- === Blackjack Game ===
local monitor, drive
local playerKey = nil
local currentBet = 50
local MIN_BET = 50
local BET_STEP = 50
local MAX_BET = 1000

local suits = { "♠", "♥", "♦", "♣" }
local values = { "A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K" }

-- === Debug Helper ===
local function debugMessage(msg)
    print("[DEBUG] " .. msg)
end

-- === Peripheral Setup ===
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then
        monitor = peripheral.wrap(name)
    elseif t == "drive" then
        drive = peripheral.wrap(name)
    end
end

if not monitor or not drive then
    error("Monitor or drive not found")
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

-- === Helper Functions ===
local function clear()
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function centerText(y, text, bgColor)
    local w, _ = monitor.getSize()
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

-- === Card Handling ===
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

-- === UI ===
local buttonY = {
    minus = 8,
    plus = 9,
    play = 11
}

local function drawMainScreen()
    clear()
    centerText(2, "Blackjack Casino")
    centerText(4, "Insert card and press Play")
    centerText(6, "Current Bet: " .. currentBet .. " Cr")
    centerText(buttonY.minus, "   [ -50 ]   ", colors.gray)
    centerText(buttonY.plus,  "   [ +50 ]   ", colors.gray)
    centerText(buttonY.play,  "   [ PLAY ]  ", colors.green)
end

-- === Disk Key ===
local function getKey()
    local mountPath = drive.getMountPath()
    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        debugMessage("Key file not found.")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if file then
        local key = file.readAll()
        file.close()
        debugMessage("Read key: " .. key)
        return key
    else
        debugMessage("Failed to read player.key")
        return nil
    end
end

-- === Rednet API ===
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

-- === Game Logic ===
local function displayHands(player, dealer, hideDealer)
    clear()
    centerText(2, "Your Hand: " .. table.concat(player, " ") .. " (" .. handValue(player) .. ")")
    local dealerDisplay = hideDealer and (dealer[1] .. " ??") or (table.concat(dealer, " ") .. " (" .. handValue(dealer) .. ")")
    centerText(4, "Dealer: " .. dealerDisplay)
end

local function playerTurn(player, dealer)
    while true do
        displayHands(player, dealer, true)
        centerText(6, "   [ HIT ]   ", colors.orange)
        centerText(7, "   [ STAND ] ", colors.lime)

        local _, _, x, y = os.pullEvent("monitor_touch")
        if y == 6 then
            table.insert(player, drawCard())
            if handValue(player) > 21 then return false end
        elseif y == 7 then
            return true
        end
    end
end

local function dealerTurn(dealer)
    while handValue(dealer) < 17 do
        table.insert(dealer, drawCard())
    end
end

local function playGame()
    clear()
    centerText(2, "Game starting...")
    sleep(1)

    if not removeCredits(playerKey, currentBet) then
        centerText(4, "Not enough credits!")
        sleep(2)
        return
    end

    centerText(4, "Bet accepted!")
    sleep(1)

    local player = { drawCard(), drawCard() }
    local dealer = { drawCard(), drawCard() }

    local continued = playerTurn(player, dealer)

    if not continued then
        displayHands(player, dealer, false)
        centerText(6, "You busted! You lose.")
        sleep(3)
        return
    end

    dealerTurn(dealer)
    displayHands(player, dealer, false)
    local playerVal = handValue(player)
    local dealerVal = handValue(dealer)

    if dealerVal > 21 or playerVal > dealerVal then
        centerText(6, "You win! +" .. (currentBet * 2) .. " Cr")
        addCredits(playerKey, currentBet * 2)
    elseif playerVal == dealerVal then
        centerText(6, "Push. Bet refunded.")
        addCredits(playerKey, currentBet)
    else
        centerText(6, "Dealer wins. You lose.")
    end
    sleep(4)
end

-- === Input Handling ===
local function handleTouch(_, _, x, y)
    if y == buttonY.minus then
        currentBet = math.max(MIN_BET, currentBet - BET_STEP)
    elseif y == buttonY.plus then
        currentBet = math.min(MAX_BET, currentBet + BET_STEP)
    elseif y == buttonY.play then
        playerKey = getKey()
        if not playerKey then
            centerText(13, "Insert card first!")
            sleep(2)
        else
            playGame()
        end
    end
    drawMainScreen()
end

-- === Main ===
rednet.open("top")
drawMainScreen()

while true do
    handleTouch(os.pullEvent("monitor_touch"))
end
