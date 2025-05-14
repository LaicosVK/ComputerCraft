-- Horse Racing Game Script
local version = "9"

-- Konfiguration
local RENN_INTERVAL = 10 -- Sekunden (für Test)
local EINSATZ_MIN = 500
local EINSATZ_MAX = 1000

-- Pferdedaten
local horses = {
    { color = "purple", colorCode = colors.purple },
    { color = "lightBlue", colorCode = colors.lightBlue },
    { color = "green", colorCode = colors.green },
    { color = "yellow", colorCode = colors.yellow },
    { color = "orange", colorCode = colors.orange },
    { color = "red", colorCode = colors.red }
}

-- Laufwerk-Zuordnung
local diskDriveMapping = {
    ["drive_27"] = "purple",
    ["drive_32"] = "lightBlue",
    ["drive_31"] = "green",
    ["drive_30"] = "yellow",
    ["drive_29"] = "orange",
    ["drive_28"] = "red"
}

-- Peripherie
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

-- Hilfsfunktionen
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

-- Startbildschirm
local function displayIdleScreen(timeLeft, entryCost, horseStats)
    clearMonitor()
    centerText(1, "Pferderennen v" .. version, colors.white)
    centerText(2, string.format("Nächstes Rennen in: %02d:%02d", math.floor(timeLeft / 60), timeLeft % 60), colors.yellow)
    centerText(3, "Einsatz: " .. math.floor(entryCost / 10 + 0.5) * 10 .. " Credits", colors.cyan)
    centerText(4, "Pferde-Statistiken", colors.white)
    centerText(5, "         GES  AUS  BES  STA  GESCH  KONZ", colors.lightGray)

    for i, horse in ipairs(horses) do
        local s = horseStats[horse.color]
        local y = 5 + i
        fillLine(y, horse.colorCode)
        local statLine = string.format("%-9s  %d    %d    %d    %d     %d      %d", horse.color, s.spd, s.endu, s.acc, s.sta, s.agi, s.foc)
        centerText(y, statLine, colors.white, horse.colorCode)
    end
end

-- Spielererkennung
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
                print("Spieler erkannt für Pferd:", color)
            end
        end
    end
    return keys
end

-- Guthaben abziehen
local function deductCredits(players, cost)
    rednet.open("top")
    for _, p in ipairs(players) do
        rednet.broadcast({ type = "remove_credits", key = p.key, amount = cost }, "casino")
        local _, res = rednet.receive("casino", 5)
        if res and res.ok then
            print("Guthaben abgezogen für:", p.horse)
        else
            print("Fehler beim Abzug für:", p.horse)
        end
    end
end

-- Countdown
local function showCountdown(seconds)
    for i = seconds, 1, -1 do
        clearMonitor()
        centerText(math.floor(height / 2), "Rennen startet in " .. i .. "...", colors.red)
        if speaker then speaker.playNote("bell", 3, 8) end
        sleep(1)
    end
end

-- Rennsimulation
local function simulateRace(stats)
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
        for _, horse in ipairs(horses) do
            local s = stats[horse.color]
            local timer = timers[horse.color]
            if not finished[horse.color] then
                timer.tick = timer.tick + 1
                if timer.tick > s.endu then timer.fatigue = true end

                local maxSpeed = timer.fatigue and math.max(1, s.spd - 1) or s.spd
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

-- Ergebnisanzeige
local function displayResults(ranks)
    clearMonitor()
    centerText(1, "Ergebnisse", colors.white)
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

-- Hauptschleife
while true do
    local einsatz = math.floor(math.random(EINSATZ_MIN, EINSATZ_MAX) / 10 + 0.5) * 10
    local stats = {}
    for _, h in ipairs(horses) do
        stats[h.color] = {
            spd = math.random(2, 5),   -- Geschwindigkeit
            endu = math.random(5, 20), -- Ausdauer
            acc = math.random(1, 5),   -- Beschleunigung
            sta = math.random(1, 5),   -- Stabilität
            agi = math.random(1, 5),   -- Geschick
            foc = math.random(1, 5),   -- Konzentration
            luk = math.random(1, 10)   -- Glück (versteckt)
        }
    end

    local timer = RENN_INTERVAL
    while timer > 0 do
        displayIdleScreen(timer, einsatz, stats)
        sleep(1)
        timer = timer - 1
    end

    local players = getPlayerKeys()
    deductCredits(players, einsatz)
    showCountdown(5)
    local results = simulateRace(stats)
    displayResults(results)
end
