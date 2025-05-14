-- Horse Racing Game Script with Stats and Original Layout

local version = "4"

-- Configuration
local RACE_INTERVAL = 10 -- seconds
local ENTRY_COST_MIN = 500
local ENTRY_COST_MAX = 1000

local horses = {
    { color = "purple", colorCode = colors.purple },
    { color = "lightBlue", colorCode = colors.lightBlue },
    { color = "green", colorCode = colors.green },
    { color = "yellow", colorCode = colors.yellow },
    { color = "orange", colorCode = colors.orange },
    { color = "red", colorCode = colors.red }
}

local diskDriveMapping = {
    ["drive_27"] = "purple",
    ["drive_32"] = "lightBlue",
    ["drive_31"] = "green",
    ["drive_30"] = "yellow",
    ["drive_29"] = "orange",
    ["drive_28"] = "red"
}

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

local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Horse Racing " .. version, colors.white)
    centerText(2, string.format("Next: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Entry: " .. math.floor(entryCost / 10 + 0.5) * 10 .. " cr", colors.cyan)
    centerText(4, "Col  Spd End Acc Sta", colors.white)

    for i, horse in ipairs(horses) do
        local stat = horseStats[horse.color]
        local text = string.format("%-6s %3d %3d %3d %3d", horse.color:sub(1, 6), stat.spd, stat.endu, stat.acc, stat.sta)
        monitor.setCursorPos(1, 4 + i)
        monitor.setBackgroundColor(horse.colorCode)
        monitor.setTextColor(colors.white)
        monitor.write(text .. string.rep(" ", width - #text))
    end
end

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
            end
        end
    end
    return playerKeys
end

local function deductCredits(playerKeys, entryCost)
    for _, player in ipairs(playerKeys) do
        rednet.open("top")
        rednet.broadcast({ type = "remove_credits", key = player.key, amount = entryCost }, "casino")
        rednet.receive("casino", 5)
    end
end

local function calculateMove(stats, tick)
    local base = math.random(1, stats.spd)
    local enduranceFactor = (tick <= stats.endu) and 1 or 0.5
    local accelFactor = math.min(tick / 5, 1) * (stats.acc / 5)
    local staminaRoll = math.random(1, stats.sta)
    local luckBoost = (math.random() < stats.luck / 10) and 2 or 0
    return math.floor((base + accelFactor + luckBoost) * enduranceFactor * (staminaRoll / stats.sta))
end

local function simulateRace(horseStats)
    local positions, finished, rankings, ticks = {}, {}, {}, 0
    local finishLine = width - 2

    for _, horse in ipairs(horses) do
        positions[horse.color] = 1
    end

    while #rankings < #horses do
        ticks = ticks + 1
        for _, horse in ipairs(horses) do
            if not finished[horse.color] then
                local move = calculateMove(horseStats[horse.color], ticks)
                positions[horse.color] = math.min(positions[horse.color] + move, finishLine)
                if positions[horse.color] >= finishLine then
                    table.insert(rankings, horse.color)
                    finished[horse.color] = true
                end
            end
        end

        clearMonitor()
        for i, horse in ipairs(horses) do
            local y = 2 + (i - 1) * 2
            for j = 0, 1 do
                monitor.setCursorPos(1, y + j)
                monitor.setBackgroundColor(colors.black)
                monitor.write("|" .. string.rep(" ", width - 2) .. "|")
            end

            monitor.setCursorPos(positions[horse.color], y)
            monitor.setBackgroundColor(horse.colorCode)
            monitor.setTextColor(colors.white)
            monitor.write(">")
            monitor.setCursorPos(positions[horse.color], y + 1)
            monitor.write(">")

            if finished[horse.color] then
                local place = nil
                for p, c in ipairs(rankings) do if c == horse.color then place = p end end
                local placeText = tostring(place) .. "."
                centerText(y, placeText, colors.white, horse.colorCode)
            end
        end
        sleep(0.3)
    end

    return rankings
end

local function displayResults(rankings)
    clearMonitor()
    centerText(1, "Race Results", colors.white)
    for i, horseColor in ipairs(rankings) do
        local horseColorCode = nil
        for _, h in ipairs(horses) do
            if h.color == horseColor then
                horseColorCode = h.colorCode
                break
            end
        end
        local text = string.format("%d. %s", i, horseColor)
        centerText(1 + i, text, colors.white, horseColorCode)
    end
    sleep(6)
end

while true do
    local entryCost = math.random(ENTRY_COST_MIN, ENTRY_COST_MAX)
    local horseStats = {}

    for _, horse in ipairs(horses) do
        horseStats[horse.color] = {
            spd = math.random(3, 6),
            endu = math.random(4, 7),
            acc = math.random(1, 5),
            sta = math.random(3, 6),
            luck = math.random(1, 3)
        }
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
