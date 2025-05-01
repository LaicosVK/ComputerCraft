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

-- Debugging function to output messages to the terminal
local function debug(msg)
    print("[DEBUG] " .. msg)
end

-- Function to read the player key from the disk
local function readKey()
    debug("Suche nach eingelegter Diskette...")

    -- Check if the disk drive is connected via the modem on the left side
    local driveSide = "left"
    if not disk.isPresent(driveSide) then
        debug("Keine Diskette in Laufwerk an Seite: " .. driveSide)
        return nil
    end

    debug("Diskette an Seite " .. driveSide .. " erkannt.")

    -- Check if the disk has data
    if not disk.hasData(driveSide) then
        debug("Diskette hat keine Daten.")
        return nil
    end

    -- Get the mount path of the disk
    local mountPath = disk.getMountPath(driveSide)
    if not mountPath then
        debug("Mount-Pfad konnte nicht ermittelt werden.")
        return nil
    end

    debug("Mount-Pfad: " .. mountPath)

    -- Now check if the player.key file exists on the disk
    local keyPath = mountPath .. "/player.key"
    if fs.exists(keyPath) then
        debug("player.key gefunden!")
        local f = fs.open(keyPath, "r")
        local key = f.readAll()
        f.close()
        return key
    else
        debug("player.key NICHT gefunden auf der Diskette.")
        return nil
    end
end

-- Main loop to attempt to read the key
local key = readKey()
if key then
    print("Schlüssel erfolgreich gefunden: " .. key)
else
    print("Kein Schlüssel gefunden.")
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
