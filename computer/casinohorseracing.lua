-- Horse Racing Game Script

local version = "1"

-- Configuration
local RACE_INTERVAL = 300 -- 5 minutes in seconds
local ENTRY_COST_MIN = 500
local ENTRY_COST_MAX = 1000

-- Horse definitions
local horses = {
    { color = "purple", colorCode = colors.purple },
    { color = "lightBlue", colorCode = colors.lightBlue },
    { color = "green", colorCode = colors.green },
    { color = "yellow", colorCode = colors.yellow },
    { color = "orange", colorCode = colors.orange },
    { color = "red", colorCode = colors.red }
}

-- Disk drive mapping: Adjust as per your setup
local diskDriveMapping = {
    ["drive_27"] = "purple",
    ["drive_32"] = "lightBlue",
    ["drive_31"] = "green",
    ["drive_30"] = "yellow",
    ["drive_29"] = "orange",
    ["drive_28"] = "red"
}

-- Initialize peripherals
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local modem = peripheral.find("modem", function(name, obj)
    return peripheral.getType(name) == "modem" and obj.isWireless()
end)

if not monitor or not modem then
    error("Monitor or wireless modem not found.")
end

-- Set monitor text scale
monitor.setTextScale(0.5)
local width, height = monitor.getSize()

-- Function to clear monitor
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

-- Function to center text
local function centerText(y, text, textColor, bgColor)
    local x = math.floor((width - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    if bgColor then
        monitor.setBackgroundColor(bgColor)
    else
        monitor.setBackgroundColor(colors.black)
    end
    if textColor then
        monitor.setTextColor(textColor)
    else
        monitor.setTextColor(colors.white)
    end
    monitor.write(text)
end

-- Function to display idle screen
local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Horse Racing Game " .. version, colors.white)
    centerText(2, string.format("Next race in: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Entry Cost: " .. entryCost .. " credits", colors.cyan)
    centerText(4, "Horse Stats:", colors.white)
    for i, horse in ipairs(horses) do
        local stat = horseStats[horse.color]
        local statText = string.format("%s: Speed %d", horse.color, stat)
        centerText(4 + i, statText, horse.colorCode)
    end
end

-- Function to get player keys from disk drives
local function getPlayerKeys()
    local playerKeys = {}
    for driveName, horseColor in pairs(diskDriveMapping) do
        if peripheral.isPresent(driveName) then
            local mountPath = peripheral.call(driveName, "getMountPath")
            if mountPath and fs.exists(mountPath .. "/player.key") then
                local file = fs.open(mountPath .. "/player.key", "r")
                local key = file.readAll()
                file.close()
                table.insert(playerKeys, { key = key, horse = horseColor })
                print("Player key detected for horse: " .. horseColor)
            end
        end
    end
    return playerKeys
end

-- Function to deduct credits from players
local function deductCredits(playerKeys, entryCost)
    for _, player in ipairs(playerKeys) do
        rednet.open("top")
        rednet.broadcast({ type = "remove_credits", key = player.key, amount = entryCost }, "casino")
        local id, response = rednet.receive("casino", 5)
        if response and response.ok then
            print("Credits deducted for player on horse: " .. player.horse)
        else
            print("Failed to deduct credits for player on horse: " .. player.horse)
        end
    end
end

-- Function to simulate race
local function simulateRace(horseStats)
    local positions = {}
    for _, horse in ipairs(horses) do
        positions[horse.color] = 0
    end

    local finishLine = width - 2
    local finished = {}
    local rankings = {}

    while #rankings < #horses do
        for _, horse in ipairs(horses) do
            if not finished[horse.color] then
                local move = math.random(1, horseStats[horse.color])
                positions[horse.color] = positions[horse.color] + move
                if positions[horse.color] >= finishLine then
                    positions[horse.color] = finishLine
                    finished[horse.color] = true
                    table.insert(rankings, horse.color)
                    print("Horse finished: " .. horse.color)
                end
            end
        end

        -- Display race
        clearMonitor()
        for i, horse in ipairs(horses) do
            local y = i
            local x = positions[horse.color]
            monitor.setCursorPos(x, y)
            monitor.setTextColor(horse.colorCode)
            monitor.write(">")
        end
        sleep(0.5)
    end

    return rankings
end

-- Function to display race results
local function displayResults(rankings)
    clearMonitor()
    centerText(1, "Race Results", colors.white)
    for i, horseColor in ipairs(rankings) do
        local text = string.format("%d. %s", i, horseColor)
        centerText(1 + i, text, colors.white)
    end
    sleep(5)
end

-- Main loop
while true do
    local entryCost = math.random(ENTRY_COST_MIN, ENTRY_COST_MAX)
    local horseStats = {}
    for _, horse in ipairs(horses) do
        horseStats[horse.color] = math.random(1, 3)
    end

    local timeLeft = RACE_INTERVAL
    while timeLeft > 0 do
        displayIdleScreen(timeLeft, entryCost, horseStats)
        sleep(1)
        timeLeft = timeLeft - 1
    end

    local playerKeys = getPlayerKeys()
    deductCredits(playerKeys, entryCost)
    local rankings = simulateRace(horseStats)
    displayResults(rankings)
end
