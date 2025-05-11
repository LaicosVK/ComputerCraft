-- casinoblackjack.lua
-- One player vs dealer blackjack game

-- === Constants ===
local MIN_BET = 50
local BET_STEP = 50
local BLACKJACK_PAYOUT = 2.5
local WIN_PAYOUT = 2.0
local TIE_PAYOUT = 1.0

-- === Setup ===
local monitor, drive
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "monitor" then
        monitor = peripheral.wrap(name)
    elseif t == "drive" then
        drive = peripheral.wrap(name)
    end
end

assert(monitor, "Monitor not found")
assert(drive, "Disk drive not found")

monitor.setTextScale(0.5)

-- === Utility ===
local function debugMessage(msg)
    print("[DEBUG] " .. msg)
end

local function centerText(line, text)
    local w, _ = monitor.getSize()
    monitor.setCursorPos(math.floor((w - #text) / 2) + 1, line)
    monitor.write(text)
end

local function drawBetScreen(bet)
    monitor.clear()
    centerText(2, "Set your bet amount")
    centerText(4, "Current Bet: " .. bet .. " C")
    centerText(6, "[ -50 ]    [ Play ]    [ +50 ]")
end

local function waitForTouch()
    while true do
        local e, side, x, y = os.pullEvent("monitor_touch")
        return x, y
    end
end

-- === Disk Key ===
local function getKey()
    if not drive.isDiskPresent() then return nil end
    local mountPath = drive.getMountPath()
    if not mountPath then return nil end
    if not fs.exists(mountPath .. "/player.key") then return nil end
    local file = fs.open(mountPath .. "/player.key", "r")
    if not file then return nil end
    local key = file.readAll()
    file.close()
    return key
end

-- === Master Communication ===
local function requestBalance(key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    return msg and msg.balance or nil
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

-- === Blackjack Game Logic ===
local cards = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

local function drawCard()
    return cards[math.random(#cards)]
end

local function calculateScore(hand)
    local score = 0
    local aces = 0
    for _, card in ipairs(hand) do
        if card == "A" then
            score = score + 11
            aces = aces + 1
        elseif card == "K" or card == "Q" or card == "J" or card == "10" then
            score = score + 10
        else
            score = score + tonumber(card)
        end
    end
    while score > 21 and aces > 0 do
        score = score - 10
        aces = aces - 1
    end
    return score
end

local function showHand(y, label, hand)
    local handStr = table.concat(hand, " ")
    centerText(y, label .. ": " .. handStr)
end

local function playBlackjack(key, bet)
    local player = {drawCard(), drawCard()}
    local dealer = {drawCard(), drawCard()}

    monitor.clear()
    showHand(2, "Dealer", {dealer[1], "?"})
    showHand(4, "You", player)
    centerText(6, "[ Hit ]   [ Stand ]")

    while true do
        local x, y = waitForTouch()
        if y == 6 and x >= 2 and x <= 8 then
            table.insert(player, drawCard())
        elseif y == 6 and x >= 15 and x <= 21 then
            break
        end
        monitor.clear()
        showHand(2, "Dealer", {dealer[1], "?"})
        showHand(4, "You", player)
        centerText(6, "[ Hit ]   [ Stand ]")
        if calculateScore(player) > 21 then break end
    end

    local playerScore = calculateScore(player)
    local dealerScore = calculateScore(dealer)
    while dealerScore < 17 do
        table.insert(dealer, drawCard())
        dealerScore = calculateScore(dealer)
    end

    monitor.clear()
    showHand(2, "Dealer", dealer)
    showHand(4, "You", player)

    local result = "Push"
    local payout = 0

    if playerScore > 21 then
        result = "You Lose"
        payout = 0
    elseif dealerScore > 21 or playerScore > dealerScore then
        if #player == 2 and playerScore == 21 then
            result = "Blackjack!"
            payout = bet * BLACKJACK_PAYOUT
        else
            result = "You Win"
            payout = bet * WIN_PAYOUT
        end
    elseif playerScore == dealerScore then
        result = "Push"
        payout = bet * TIE_PAYOUT
    else
        result = "You Lose"
        payout = 0
    end

    if payout > 0 then
        addCredits(key, payout)
    end

    centerText(6, result .. " - " .. payout .. "C")
    sleep(4)
end

-- === Main Loop ===
math.randomseed(os.time())
rednet.open("top")

while true do
    local bet = MIN_BET
    drawBetScreen(bet)

    while true do
        local x, y = waitForTouch()
        if y == 6 then
            if x >= 2 and x <= 7 then
                bet = math.max(MIN_BET, bet - BET_STEP)
            elseif x >= 21 and x <= 27 then
                bet = bet + BET_STEP
            elseif x >= 12 and x <= 17 then
                local key = getKey()
                if not key then
                    monitor.clear()
                    centerText(3, "Insert valid player card")
                    sleep(2)
                    break
                end
                local balance = requestBalance(key)
                if balance and balance >= bet then
                    if removeCredits(key, bet) then
                        playBlackjack(key, bet)
                    end
                else
                    monitor.clear()
                    centerText(3, "Not enough credits")
                    sleep(2)
                end
                break
            end
            drawBetScreen(bet)
        end
    end
end
