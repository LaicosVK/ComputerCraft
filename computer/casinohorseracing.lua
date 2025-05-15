-- Pferderennen

local version = "21"

local RENN_INTERVAL = 300
local EINSATZ_MIN = 1000
local EINSATZ_MAX = 10000

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
local modem = peripheral.find("modem", function(_, obj)
    return peripheral.getType(obj) == "modem" and obj.isWireless()
end)

if not monitor or not modem then
    error("Monitor oder drahtloses Modem nicht gefunden.")
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

local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Pferderennen v" .. version, colors.white)
    centerText(2, string.format("Nächstes Rennen in: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Einsatz: " .. math.floor(entryCost / 100 + 0.5) * 100 .. " Credits", colors.cyan)
    centerText(4, "Pferde-Statistiken", colors.white)
    centerText(5, "GES  AUS  BES  STA  GESCH  KONZ", colors.lightGray)

    for i, horse in ipairs(horses) do
        local s = horseStats[horse.color]
        local y = 5 + i
        fillLine(y, horse.colorCode)
        local statLine = string.format(" %2d   %2d   %2d   %2d    %2d     %2d", s.spd, s.endu, s.acc, s.sta, s.agi, s.foc)
        centerText(y, statLine, colors.white, horse.colorCode)
    end
end

local function getPlayerStates(cost)
    local playerStates = {}
    rednet.open("top")
    for drive, color in pairs(diskDriveMapping) do
        if peripheral.isPresent(drive) then
            local path = peripheral.call(drive, "getMountPath")
            if path and fs.exists(path .. "/player.key") then
                local f = fs.open(path .. "/player.key", "r")
                local key = f.readAll()
                f.close()

                rednet.broadcast({ type = "remove_credits", key = key, amount = cost }, "casino")
                local _, res = rednet.receive("casino", 3)
                if res and res.ok then
                    playerStates[color] = key
                else
                    playerStates[color] = "1"
                end
            else
                playerStates[color] = "0"
            end
        else
            playerStates[color] = "0"
        end
    end
    return playerStates
end

local function showCountdown(seconds)
    for i = seconds, 1, -1 do
        clearMonitor()
        centerText(math.floor(height / 2), "Rennen startet in " .. i .. "...", colors.red)
        if speaker then speaker.playNote("bell", 3, 8) end
        sleep(1)
    end
end

local function simulateRace(stats, playerStates)
    local positions, speeds, timers = {}, {}, {}
    local finished, ranks, rankMap = {}, {}, {}
    for _, horse in ipairs(horses) do
        positions[horse.color] = 3
        speeds[horse.color] = 0
        timers[horse.color] = { tick = 0, fatigue = false }
    end
    local finish = width - 2

    if speaker then speaker.playNote("harp", 2, 8) end

    while #ranks < #horses do
        local remaining = #horses - #ranks

        for _, horse in ipairs(horses) do
            local s = stats[horse.color]
            local timer = timers[horse.color]
            if not finished[horse.color] then
                timer.tick = timer.tick + 1
                if timer.tick > s.endu then timer.fatigue = true end

                local maxSpeed = timer.fatigue and math.max(1, s.spd - 1) or s.spd
                if remaining <= 2 then maxSpeed = maxSpeed + 2 end

                local currentSpeed = math.min(maxSpeed, math.floor(speeds[horse.color] + 1))
                if speeds[horse.color] < maxSpeed then
                    speeds[horse.color] = speeds[horse.color] + s.acc / 10
                end

                local move = math.random(0, currentSpeed)
                if math.random(1, 10) <= s.agi then move = move + 1 end
                if math.random(1, 10) > s.foc then move = math.max(0, move - 1) end

                local swing = math.random(-1, 1) * (5 - s.sta)
                move = math.max(0, move + swing)

                if math.random(1, 100) <= s.luk then
                    move = move + math.random(-2, 2)
                end

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
            fillLine(y, horse.colorCode)
            fillLine(y + 1, horse.colorCode)
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

            if playerStates[horse.color] == "1" then
                monitor.setCursorPos(4, y + 1)
                monitor.write("X Guthaben fehlt")
            end
        end
        sleep(0.4)
    end

    if speaker then speaker.playNote("pling", 3, 8) end
    return ranks
end

local function displayResults(ranks, einsatz, playerStates)
    clearMonitor()
    centerText(1, "Ergebnisse", colors.white)

    local multipliers = {
        [1] = 3.0,
        [2] = 2,
        [3] = 1.5
    }

    rednet.open("top")
    for i, color in ipairs(ranks) do
        local y = 1 + i
        local bg = getColorCodeByName(color)
        fillLine(y, bg)

        local key = playerStates[color]
        local payout = 0
        local theoretical = 0

        if multipliers[i] then
            theoretical = math.floor(einsatz * multipliers[i])
            if key ~= "0" and key ~= "1" then
                payout = theoretical
                rednet.broadcast({ type = "add_credits", key = key, amount = payout }, "casino")
            end
        end

        local text
        if key == "1" or key == "0" then
            text = string.format("%d. %s  (+%d)", i, color, theoretical)
        else
            text = string.format("%d. %s  +%d", i, color, payout)
        end

        centerText(y, text, colors.white, bg)
    end

    if speaker then
        for i = 1, 3 do
            speaker.playNote("bell", 3 + i, 8)
            sleep(0.2)
        end
    end
    sleep(10)
end

while true do
    local einsatz = math.floor(math.random(EINSATZ_MIN, EINSATZ_MAX) / 10 + 0.5) * 10
    local stats = {}
    for _, h in ipairs(horses) do
        stats[h.color] = {
            spd = math.random(2, 5),
            endu = math.random(5, 20),
            acc = math.random(1, 5),
            sta = math.random(1, 5),
            agi = math.random(1, 5),
            foc = math.random(1, 5),
            luk = math.random(1, 10)
        }
    end

    local timer = RENN_INTERVAL
    while timer > 0 do
        displayIdleScreen(timer, einsatz, stats)
        sleep(1)
        timer = timer - 1
    end

    local playerStates = getPlayerStates(einsatz)
    showCountdown(5)
    local results = simulateRace(stats, playerStates)
    displayResults(results, einsatz, playerStates)
end
