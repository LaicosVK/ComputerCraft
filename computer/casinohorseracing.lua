-- Horse Racing Game Script
local version = "6"

-- Configuration
local RACE_INTERVAL = 10 -- seconds (for testing)
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

-- Disk drive mapping
local diskDriveMapping = {
    ["drive_27"] = "purple",
    ["drive_32"] = "lightBlue",
    ["drive_31"] = "green",
    ["drive_30"] = "yellow",
    ["drive_29"] = "orange",
    ["drive_28"] = "red"
}

-- Peripherals
local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local modem = peripheral.find("modem", function(_, obj)
    return peripheral.getType(obj) == "modem" and obj.isWireless()
end)

if not monitor or not modem then
    error("Monitor or wireless modem not found.")
end

monitor.setTextScale(2)
local width, height = monitor.getSize()

-- Utility functions
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    monitor.setCursorPos(1, 1)
end

local function centerText(y, text, textColor, bgColor)
    local x = math.floor((width - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.setTextColor(textColor or colors.white)
    monitor.setBackgroundColor(bgColor or colors.black)
    monitor.write(text)
end

local function fillLine(y, color)
    monitor.setCursorPos(1, y)
    monitor.setBackgroundColor(color)
    monitor.write(string.rep(" ", width))
end

local function getColorCodeByName(name)
    for _, h in ipairs(horses) do
        if h.color == name then
            return h.colorCode
        end
    end
    return colors.black
end

-- Idle screen
local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Horse Racing Game v" .. version, colors.white)
    centerText(2, string.format("Next race in: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Entry Cost: " .. math.floor(entryCost / 10 + 0.5) * 10 .. " credits", colors.cyan)
    centerText(4, "Horse Stats", colors.white)

    for i, horse in ipairs(horses) do
        local stat = horseStats[horse.color]
        local y = 4 + i
        fillLine(y, horse.colorCode)
        centerText(y, string.format("%s (Speed: %d)", horse.color, stat), colors.white, horse.colorCode)
    end
end

-- Get players
local function getPlayerKeys()
    local keys = {}
    for drive, color in pairs(diskDriveMapping) do
        if peripheral.isPresent(drive) then
            local path = peripheral.call(drive, "getMountPath")
            if path and fs.exists(path .. "/player.key") then
                local f = fs.open(path .. "/player.key", "r")
                local key = f.readAll()
                f.close()
                table.insert(keys, { key = key, horse = color })
                print("Detected player for horse:", color)
            end
        end
    end
    return keys
end

-- Deduct credits
local function deductCredits(players, cost)
    rednet.open("top")
    for _, p in ipairs(players) do
        rednet.broadcast({ type = "remove_credits", key = p.key, amount = cost }, "casino")
        local _, res = rednet.receive("casino", 5)
        if res and res.ok then
            print("Credits deducted for:", p.horse)
        else
            print("Failed to deduct for:", p.horse)
        end
    end
end

-- Countdown
local function showCountdown(seconds)
    for i = seconds, 1, -1 do
        clearMonitor()
        centerText(math.floor(height / 2), "Race starts in " .. i .. "...", colors.red)
        if speaker then speaker.playNote("bell", 3, 8) end
        sleep(1)
    end
end

-- Race simulation
local function simulateRace(stats)
    local positions, finished, ranks, rankMap = {}, {}, {}, {}
    for _, horse in ipairs(horses) do positions[horse.color] = 3 end
    local finish = width - 2

    if speaker then speaker.playNote("harp", 2, 8) end

    while #ranks < #horses do
        for _, horse in ipairs(horses) do
            if not finished[horse.color] then
                local move = math.random(1, stats[horse.color])
                positions[horse.color] = math.min(positions[horse.color] + move, finish + 1)
                if positions[horse.color] >= finish + 1 then
                    finished[horse.color] = true
                    table.insert(ranks, horse.color)
                    rankMap[horse.color] = #ranks
                end
            end
        end

        clearMonitor()
        for i, horse in ipairs(horses) do
            local y = 1 + (i - 1) * 2
            for j = 0, 1 do fillLine(y + j, horse.colorCode) end
            monitor.setTextColor(colors.white)
            monitor.setCursorPos(2, y)
            monitor.write("|")
            monitor.setCursorPos(finish, y)
            monitor.write("|")
            local x = math.min(positions[horse.color], finish + 1)
            monitor.setCursorPos(x, y)
            monitor.write(">")
            monitor.setCursorPos(x, y + 1)
            monitor.write(">")

            if rankMap[horse.color] then
                local place = tostring(rankMap[horse.color]) .. "."
                centerText(y, place, colors.white, horse.colorCode)
            end
        end
        sleep(0.4)
    end

    if speaker then speaker.playNote("pling", 3, 8) end
    return ranks
end

-- Results
local function displayResults(ranks)
    clearMonitor()
    centerText(1, "Race Results", colors.white)
    for i, color in ipairs(ranks) do
        local y = 1 + i
        local bg = getColorCodeByName(color)
        fillLine(y, bg)
        centerText(y, string.format("%d. %s", i, color), colors.white, bg)
    end
    if speaker then
        for i = 1, 3 do
            speaker.playNote("bell", 3 + i, 8)
            sleep(0.2)
        end
    end
    sleep(10)
end

-- Main loop
while true do
    local cost = math.floor(math.random(ENTRY_COST_MIN, ENTRY_COST_MAX) / 10 + 0.5) * 10
    local stats = {}
    for _, h in ipairs(horses) do stats[h.color] = math.random(1, 3) end

    local timer = RACE_INTERVAL
    while timer > 0 do
        displayIdleScreen(timer, cost, stats)
        sleep(1)
        timer = timer - 1
    end

    local players = getPlayerKeys()
    deductCredits(players, cost)
    showCountdown(5)
    local results = simulateRace(stats)
    displayResults(results)
end
