-- Horse Racing Game Script
local version = "v3"

-- Configuration
local RACE_INTERVAL = 60 -- seconds
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

monitor.setTextScale(2)
local width, height = monitor.getSize()

-- Utility Functions
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function centerText(y, text, textColor, bgColor)
    local x = math.floor((width - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    if bgColor then monitor.setBackgroundColor(bgColor) end
    if textColor then monitor.setTextColor(textColor) end
    monitor.write(text)
end

local function fillLine(y, bgColor)
    monitor.setCursorPos(1, y)
    monitor.setBackgroundColor(bgColor)
    monitor.write(string.rep(" ", width))
end

-- Idle Screen
local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Horse Racing Game v" .. version, colors.white)
    centerText(2, string.format("Next race in: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Entry Cost: " .. entryCost .. " credits", colors.cyan)
    centerText(4, "Horse Stats", colors.white)

    for i, horse in ipairs(horses) do
        local stat = horseStats[horse.color]
        local lineY = 5 + i
        fillLine(lineY, horse.colorCode)
        centerText(lineY, string.format("%s (Speed: %d)", horse.color, stat), colors.black, horse.colorCode)
    end
end

-- Player Card Detection
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

-- Deduct Credits
local function deductCredits(playerKeys, entryCost)
    rednet.open("top")
    for _, player in ipairs(playerKeys) do
        rednet.broadcast({ type = "remove_credits", key = player.key, amount = entryCost }, "casino")
        local id, response = rednet.receive("casino", 5)
        if response and response.ok then
            print("Credits deducted for player on horse: " .. player.horse)
        else
            print("Failed to deduct credits for player on horse: " .. player.horse)
        end
    end
end

-- Countdown Before Race
local function showCountdown(seconds)
    for i = seconds, 1, -1 do
        clearMonitor()
        centerText(math.floor(height / 2), "Race starting in " .. i .. "...", colors.red)
        if speaker then
            speaker.playNote("bell", 3, 8)
        end
        sleep(1)
    end
end

-- Race Animation
local function simulateRace(horseStats)
    local positions, finished, rankings = {}, {}, {}
    for _, horse in ipairs(horses) do positions[horse.color] = 2 end
    local finishLine = width - 2

    if speaker then speaker.playNote("harp", 2, 8) end

    while #rankings < #horses do
        for _, horse in ipairs(horses) do
            if not finished[horse.color] then
                local move = math.random(1, horseStats[horse.color])
                positions[horse.color] = positions[horse.color] + move
                if positions[horse.color] >= finishLine then
                    positions[horse.color] = finishLine
                    finished[horse.color] = true
                    table.insert(rankings, horse.color)
                end
            end
        end

        -- Display horses
        clearMonitor()
        for i, horse in ipairs(horses) do
            local y = 6 + (i - 1) * 3
            for j = 0, 2 do
                fillLine(y + j, horse.colorCode)
            end
            monitor.setCursorPos(2, y + 1)
            monitor.setTextColor(colors.white)
            monitor.write("|") -- Start line
            monitor.setCursorPos(positions[horse.color], y + 1)
            monitor.write(">")
            monitor.setCursorPos(finishLine, y + 1)
            monitor.write("|") -- Finish line
        end
        sleep(0.4)
    end

    if speaker then speaker.playNote("pling", 3, 8) end
    return rankings
end

-- Results
local function displayResults(rankings)
    clearMonitor()
    centerText(1, "Race Results", colors.white)
    for i, horseColor in ipairs(rankings) do
        centerText(1 + i, string.format("%d. %s", i, horseColor), colors.white)
    end
    if speaker then
        for i = 1, 3 do
            speaker.playNote("bell", 3 + i, 8)
            sleep(0.2)
        end
    end
    sleep(6)
end

-- MAIN LOOP
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

    local players = getPlayerKeys()
    deductCredits(players, entryCost)
    showCountdown(5)
    local results = simulateRace(horseStats)
    displayResults(results)
end
