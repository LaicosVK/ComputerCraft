-- === Initialisierung ===
local monitor = peripheral.find("monitor")
local wirelessModem = nil
local driveName = nil

-- === Debug-Funktion ===
local function debug(msg)
    print("[DEBUG] " .. msg)
end

-- === Modem öffnen ===
for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
    if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
        rednet.open(side)
        wirelessModem = side
        debug("Wireless Modem geöffnet an Seite: " .. side)
        break
    end
end

if not rednet.isOpen() then
    print("Kein Wireless Modem gefunden!")
    return
end

-- === Disk Drive über Modem finden ===
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" then
        driveName = name
        debug("Disk Drive gefunden: " .. name)
        break
    end
end

if not driveName then
    print("Kein Diskettenlaufwerk gefunden!")
    return
end

-- === Monitor vorbereiten ===
if not monitor then
    print("Kein Monitor gefunden!")
    return
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local w, h = monitor.getSize()

local function center(text, y)
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function drawButton(label, y, color)
    local x = math.floor((w - #label - 4) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(color)
    monitor.setTextColor(colors.black)
    monitor.write("  " .. label .. "  ")
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

local function waitForButtons(buttons)
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        for _, button in ipairs(buttons) do
            local bx = math.floor((w - #button.label - 4) / 2) + 1
            local by = button.y
            if y == by and x >= bx and x <= (bx + #button.label + 3) then
                return button.label
            end
        end
    end
end

-- === Lies Key von Disk ===
local function readKey()
    local drive = peripheral.wrap(driveName)
    if not drive.isDiskPresent() then
        debug("Keine Diskette im Laufwerk.")
        return nil
    end

    local mountPath = drive.getMountPath()
    debug("Mount-Pfad: " .. (mountPath or "nil"))

    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        debug("Datei player.key nicht gefunden.")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if not file then
        debug("Fehler beim Öffnen der Datei.")
        return nil
    end

    local key = file.readAll()
    file.close()
    debug("Key gelesen: " .. key)
    return key
end

-- === Anfrage an Server senden ===
local function sendRequest(action)
    local key = readKey()
    if not key then
        center("Keine Karte!", 2)
        sleep(2)
        return
    end

    local msgType = (action == "add") and "add_credits" or "remove_credits"
	rednet.broadcast({ type = msgType, key = key, amount = 5 }, "casino")
    debug("Anfrage gesendet: " .. action)

    -- Warte auf Antwort
    local timer = os.startTimer(3)
    while true do
        local event, p1, p2, p3 = os.pullEvent()
        if event == "rednet_message" and type(p2) == "table" and p2.ok ~= nil and p3 == "casino" then
            if p2.ok then
                center("Neues Guthaben: " .. p2.newBalance, 2)
                debug("Antwort erhalten: Guthaben " .. p2.newBalance)
            else
                center("Fehler: Antwort negativ", 2)
                debug("Antwort mit ok = false")
            end
            sleep(2)
            return
        elseif event == "timer" and p1 == timer then
            center("Zeitüberschreitung!", 2)
            debug("Timeout beim Warten auf Antwort")
            sleep(2)
            return
        end
    end
end

-- === Hauptbildschirm ===
while true do
    monitor.clear()
    center("Casino Terminal", 1)
    drawButton("+5 Credits", 4, colors.green)
    drawButton("-5 Credits", 6, colors.red)

    local clicked = waitForButtons({
        { label = "+5 Credits", y = 4 },
        { label = "-5 Credits", y = 6 },
    })

    if clicked == "+5 Credits" then
        sendRequest("add")
    elseif clicked == "-5 Credits" then
        sendRequest("remove")
    end
end
