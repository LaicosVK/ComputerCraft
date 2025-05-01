-- === Setup ===
local monitor = peripheral.find("monitor")
local modemSide = "top"
local driveName

-- === Open Wireless Modem ===
if peripheral.getType(modemSide) == "modem" and peripheral.call(modemSide, "isWireless") then
    rednet.open(modemSide)
    print("Wireless modem opened on " .. modemSide)
else
    print("No wireless modem on " .. modemSide)
    return
end

-- === Find Disk Drive ===
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "drive" then
        driveName = name
        print("Disk drive found: " .. driveName)
        break
    end
end

if not monitor or not driveName then
    print("Monitor or disk drive not found.")
    return
end

monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)
monitor.clear()

local w, h = monitor.getSize()

-- === Helper: Centered Text ===
local function center(text, y)
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

-- === Draw Buttons ===
local function drawButton(text, y, color)
    local x = math.floor((w - #text - 4) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(color)
    monitor.setTextColor(colors.black)
    monitor.write("  " .. text .. "  ")
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

-- === Get Key from Disk ===
local function getKey()
    local drive = peripheral.wrap(driveName)
    if not drive or not drive.isDiskPresent() then
        print("[DEBUG] Keine Diskette im Laufwerk.")
        return nil
    end

    local mountPath = drive.getMountPath()
    print("[DEBUG] Mount-Pfad: " .. tostring(mountPath))

    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        print("[DEBUG] player.key nicht gefunden unter: " .. tostring(mountPath) .. "/player.key")
        return nil
    end

    local file = fs.open(mountPath .. "/player.key", "r")
    if not file then
        print("[DEBUG] Fehler beim Öffnen von player.key")
        return nil
    end

    local key = file.readAll()
    file.close()
    print("[DEBUG] Gelesener Key: " .. key)
    return key
end

-- === Handle Credit Actions ===
local function sendRequest(type)
    local key = getKey()
    if not key then
        center("Keine gueltige Karte!", h)
        return
    end

    local amount = 5
    local message = {
        type = (type == "add") and "add_credits" or "remove_credits",
        key = key,
        amount = amount
    }

    rednet.broadcast(message, "casino")
    local timer = os.startTimer(3)
	local response = nil

	while true do
		local event, p1, p2, p3 = os.pullEvent()
		if event == "rednet_message" and p3 == "casino" and type(p2) == "table" and p2.ok ~= nil then
			response = p2
			break
		elseif event == "timer" and p1 == timer then
			print("[DEBUG] Timeout beim Warten auf Antwort.")
			break
		end
	end

    if response and response.ok then
        center("OK! Neuer Kontostand: " .. tostring(response.newBalance), h)
        print("[DEBUG] Erfolg! Neuer Kontostand: " .. tostring(response.newBalance))
    else
        center("Fehlgeschlagen!", h)
        print("[DEBUG] Antwort ungültig oder Zeitüberschreitung.")
    end
end

-- === Main Loop ===
while true do
    monitor.clear()
    center("Casino Terminal", 1)
    drawButton("5 Credits hinzufuegen", 3, colors.green)
    drawButton("5 Credits abziehen", 5, colors.red)

    local event, side, x, y = os.pullEvent("monitor_touch")
    if y == 3 then
        print("[DEBUG] Button Add 5 pressed.")
        sendRequest("add")
    elseif y == 5 then
        print("[DEBUG] Button Remove 5 pressed.")
        sendRequest("remove")
    end

    sleep(2)
end
