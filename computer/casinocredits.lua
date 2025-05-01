-- === Setup ===
local monitor = peripheral.find("monitor")
local wirelessModemSide = "top"
local drive = peripheral.find("drive")

rednet.open(wirelessModemSide)
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
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == "disk" and disk.isPresent(name) and disk.hasData(name) then
            local mountPath = disk.getMountPath(name)
            if mountPath and fs.exists(mountPath .. "/player.key") then
                local f = fs.open(mountPath .. "/player.key", "r")
                local read = f.readAll()
                f.close()
                return read
            end
        end
    end
    return nil
end

local function sendCredits(action)
    if not key then return "Keine Karte gefunden." end

    local typeMsg = action == "add" and "add_credits" or "remove_credits"
    rednet.broadcast({ type = typeMsg, key = key, amount = 5 }, "casino")
    local id, msg = rednet.receive("casino", 2)

    if msg and msg.ok then
        return "Erfolg: Neuer Kontostand: " .. (msg.newBalance or "?")
    else
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

    if y == 4 then
        local result = sendCredits("add")
        drawScreen(result)
    elseif y == 6 then
        local result = sendCredits("remove")
        drawScreen(result)
    end
end
