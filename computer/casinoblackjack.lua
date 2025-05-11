-- === CONFIGURATION ===
local fileName = "startup"
local folderName = ""
local remoteURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/" .. folderName .. fileName .. ".lua"
local localFile = fileName .. ".lua"
local monitor = peripheral.wrap("right")  -- assuming monitor is on top
local diskDrive = peripheral.wrap("right") -- assuming disk drive is connected to the right modem
local playerKey = nil
local playerBalance = 0
local betAmount = 0

-- === GET PLAYER KEY ===
local function getKey()
    -- Locate a connected disk drive peripheral
    local driveName
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "drive" then
            driveName = name
            break
        end
    end

    if not driveName then
        print("Kein Disklaufwerk gefunden.")
        return nil
    end

    local drive = peripheral.wrap(driveName)
    if not drive.isDiskPresent() then
        print("Keine Diskette im Laufwerk.")
        return nil
    end

    local mountPath = drive.getMountPath()
    print("Mount-Pfad: " .. (mountPath or "nil"))

    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        print("Datei player.key nicht gefunden bei: " .. (mountPath or "nil") .. "/player.key")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if file then
        playerKey = file:readAll()
        file:close()
        print("Key gelesen: " .. playerKey)
        return playerKey
    else
        print("Fehler beim Lesen von player.key.")
        return nil
    end
end

-- === TALK TO MASTER SERVER ===
local function requestBalance(key)
    print("Requesting balance for key: " .. key)
    rednet.broadcast({ type = "get_balance", key = key }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        print("Balance: " .. msg.balance)
        return msg.balance
    end
    print("Failed to get balance.")
    return nil
end

local function removeCredits(key, amount)
    print("Removing " .. amount .. " credits.")
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        print("Credits removed.")
        return true
    end
    print("Failed to remove credits.")
    return false
end

local function addCredits(key, amount)
    print("Adding " .. amount .. " credits.")
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 2)
    if msg and msg.ok then
        print("Credits added.")
        return true
    end
    print("Failed to add credits.")
    return false
end

-- === BLACKJACK GAME LOGIC ===
local function dealCard()
    local suits = {"♥", "♦", "♣", "♠"}
    local values = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
    local suit = suits[math.random(1, #suits)]
    local value = values[math.random(1, #values)]
    return value .. suit
end

local function calculateHandValue(hand)
    local value = 0
    local aces = 0
    for _, card in ipairs(hand) do
        local cardValue = card:sub(1, #card - 1)
        if cardValue == "J" or cardValue == "Q" or cardValue == "K" then
            value = value + 10
        elseif cardValue == "A" then
            value = value + 11
            aces = aces + 1
        else
            value = value + tonumber(cardValue)
        end
    end

    while value > 21 and aces > 0 do
        value = value - 10
        aces = aces - 1
    end

    return value
end

local function playBlackjack()
    local playerHand = {dealCard(), dealCard()}
    local dealerHand = {dealCard(), dealCard()}
    
    -- Show hands
    print("Player's Hand: " .. table.concat(playerHand, ", "))
    print("Dealer's Hand: " .. dealerHand[1] .. ", ?")
    
    -- Player's turn
    while true do
        print("Your hand value: " .. calculateHandValue(playerHand))
        print("Do you want to hit or stand? (h/s)")
        local choice = read()
        if choice == "h" then
            table.insert(playerHand, dealCard())
            print("You drew a card: " .. playerHand[#playerHand])
        elseif choice == "s" then
            break
        end
    end

    -- Dealer's turn
    while calculateHandValue(dealerHand) < 17 do
        table.insert(dealerHand, dealCard())
    end
    print("Dealer's Hand: " .. table.concat(dealerHand, ", "))
    
    -- Determine winner
    local playerValue = calculateHandValue(playerHand)
    local dealerValue = calculateHandValue(dealerHand)
    print("Player's value: " .. playerValue)
    print("Dealer's value: " .. dealerValue)

    if playerValue > 21 then
        print("You busted! Dealer wins.")
        return false
    elseif dealerValue > 21 then
        print("Dealer busted! You win!")
        return true
    elseif playerValue > dealerValue then
        print("You win!")
        return true
    elseif playerValue < dealerValue then
        print("Dealer wins.")
        return false
    else
        print("It's a tie!")
        return nil
    end
end

-- === MAIN ===
print("Welcome to Blackjack!")
getKey()
playerBalance = requestBalance(playerKey)

if playerBalance then
    print("Your balance: " .. playerBalance)
    print("Please enter your bet amount:")
    betAmount = tonumber(read())

    if betAmount <= playerBalance then
        print("Starting the game...")
        removeCredits(playerKey, betAmount)
        local win = playBlackjack()

        if win then
            print("You win, adding your winnings...")
            addCredits(playerKey, betAmount * 2)
        else
            print("You lose.")
        end
    else
        print("You don't have enough credits!")
    end
else
    print("Unable to fetch balance. Exiting.")
end
