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

local function doRegistration()
    drawRegistrationScreen()
    rednet.broadcast({ type = "register_request" }, "casino")
    print("Sent registration request to master.")
    local id, reply = rednet.receive("casino", 5)

    if reply and reply.ok and reply.key then
        print("Received key from master: " .. reply.key)

        -- Locate the disk drive peripheral
        local driveName
        for _, name in ipairs(peripheral.getNames()) do
            if peripheral.getType(name) == "drive" then
                driveName = name
                break
            end
        end

        if not driveName then
            print("Kein Disklaufwerk gefunden.")
            drawErrorScreen("Kein Laufwerk erkannt")
            return
        end

        local drive = peripheral.wrap(driveName)
        if not drive.isDiskPresent() then
            print("Keine Diskette eingelegt.")
            drawErrorScreen("Keine Diskette")
            return
        end

        local mountPath = drive.getMountPath()
        print("Mount-Pfad: " .. (mountPath or "nil"))

        if not mountPath then
            drawErrorScreen("Fehler beim Mounten")
            return
        end

        -- Write the player.key file to the disk
        local f = fs.open(mountPath .. "/player.key", "w")
        if not f then
            print("Konnte Datei nicht schreiben.")
            drawErrorScreen("Fehler beim Schreiben")
            return
        end
        f.write(reply.key)
        f.close()

        disk.setLabel(driveName, "Casino Karte")
        drawCompletionScreen()
        waitForButtons({ { label = "OK", y = 5 } })
    else
        print("No response or invalid response from master.")
        drawErrorScreen("Kommunikation fehlgeschlagen")
    end
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
key = getKey()
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
