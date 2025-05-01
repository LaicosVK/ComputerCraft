-- === Setup ===
local monitor = peripheral.find("monitor")
local drive = peripheral.find("drive")
local wirelessModemSide = "top"

-- Debug utility
local function debug(msg)
    print("[DEBUG] " .. msg)
end

-- Open wireless modem
if peripheral.getType(wirelessModemSide) == "modem" then
    rednet.open(wirelessModemSide)
    debug("Wireless modem opened on side: " .. wirelessModemSide)
else
    print("Kein drahtloses Modem oben gefunden!")
    return
end

if not monitor then
    print("Monitor nicht gefunden!")
    return
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

local w, h = monitor.getSize()
local key = nil

-- === Functions ===
local function centerText(text, y)
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function drawScreen(status)
    monitor.clear()
    centerText("Kredit Terminal", 1)
    centerText(status or "", 2)

    -- Add Button
    local addText = "Addiere 5 Credits"
    monitor.setCursorPos(math.floor((w - #addText - 4) / 2) + 1, 4)
    monitor.setBackgroundColor(colors.green)
    monitor.setTextColor(colors.black)
    monitor.write("  " .. addText .. "  ")

    -- Remove Button
    local remText = "Entferne 5 Credits"
    monitor.setCursorPos(math.floor((w - #remText - 4) / 2) + 1, 6)
    monitor.setBackgroundColor(colors.red)
    monitor.setTextColor(colors.black)
    monitor.write("  " .. remText .. "  ")

    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

local function readKey()
    debug("Suche nach eingelegter Diskette...")

    for _, side in ipairs({ "top", "bottom", "left", "right", "back", "front" }) do
        if disk.isPresent(side) and disk.hasData(side) then
            debug("Diskette erkannt an Seite: " .. side)
            local mountPath = disk.getMountPath(side)

            if mountPath then
                local keyPath = mountPath .. "/player.key"
                debug("Prüfe auf Datei: " .. keyPath)

                if fs.exists(keyPath) then
                    debug("player.key gefunden!")
                    local f = fs.open(keyPath, "r")
                    local key = f.readAll()
                    f.close()
                    return key
                else
                    debug("player.key NICHT gefunden in: " .. keyPath)
                end
            else
                debug("Mount-Pfad konnte nicht ermittelt werden.")
            end
        else
            debug("Keine Diskette an Seite: " .. side)
        end
    end

    debug("Keine gültige Diskette mit player.key gefunden.")
    return nil
end


local function sendCredits(action)
    if not key then return "Keine Karte gefunden." end

    local typeMsg = action == "add" and "add_credits" or "remove_credits"
    debug("Sende Rednet-Nachricht: " .. typeMsg)
    rednet.broadcast({ type = typeMsg, key = key, amount = 5 }, "casino")
    local id, msg = rednet.receive("casino", 2)

    if msg and msg.ok then
        debug("Antwort vom Server erhalten. Neuer Kontostand: " .. tostring(msg.newBalance))
        return "Erfolg! Kontostand: " .. (msg.newBalance or "?")
    else
        debug("Keine oder ungültige Antwort vom Server.")
        return "Fehlgeschlagen."
    end
end

-- === Main ===
key = readKey()
if not key then
    drawScreen("Keine Karte erkannt!")
else
    drawScreen("Karte geladen.")
end

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    debug("Monitor Touch bei x=" .. x .. ", y=" .. y)

    if y == 4 then
        local result = sendCredits("add")
        drawScreen(result)
    elseif y == 6 then
        local result = sendCredits("remove")
        drawScreen(result)
    end
end
