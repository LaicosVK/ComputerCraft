-- === Credit Trade Machine ===

-- === Peripheral Setup ===
local monitor = peripheral.wrap("back")
local barrel = peripheral.find("barrel")
local chest = peripheral.find("chest")
local diskDrive = peripheral.find("drive")

-- === Open Wireless Modem ===
for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
    if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
        rednet.open(side)
        print("Wireless modem opened on: " .. side)
        break
    end
end

-- === Helper Functions ===

local function debug(msg)
    print("[DEBUG] " .. msg)
end

local function centerText(line, text)
    local w, _ = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, line)
    monitor.write(text)
end

local function clearScreen()
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()
end

local function waitForButton(buttons)
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        for _, btn in ipairs(buttons) do
            local bx = math.floor((monitor.getSize() - #btn.label - 4) / 2) + 1
            if y == btn.y and x >= bx and x <= bx + #btn.label + 3 then
                return btn.label
            end
        end
    end
end

local function readPlayerKey()
    if not diskDrive or not diskDrive.isDiskPresent() then
        debug("No disk present.")
        return nil
    end

    local mountPath = diskDrive.getMountPath()
    if not mountPath or not fs.exists(mountPath .. "/player.key") then
        debug("player.key file not found.")
        return nil
    end

    local f = fs.open(mountPath .. "/player.key", "r")
    local key = f.readAll()
    f.close()
    return key
end

local values = {
    ["minecraft:diamond"] = 10,
    ["minecraft:emerald"] = 8,
    ["minecraft:gold_ingot"] = 5,
    ["minecraft:iron_ingot"] = 2
}

local function calculateValue()
    local total = 0
    for slot, item in pairs(barrel.list()) do
        if values[item.name] then
            total = total + values[item.name] * item.count
        end
    end
    return total
end

local function transferItems()
    for slot, item in pairs(barrel.list()) do
        barrel.pushItems(peripheral.getName(chest), slot)
    end
end

-- === UI Screens ===

local function drawMainScreen()
    clearScreen()
    centerText(2, "=== Credits kaufen ===")
    centerText(4, "Bitte Items in die Tonne legen")
    centerText(6, "[ Berechnen ]")
end

local function drawConfirmScreen(amount)
    clearScreen()
    centerText(2, "Gefundener Wert: " .. amount .. " Credits")
    centerText(4, "[ Bestätigen ]")
    centerText(6, "[ Abbrechen ]")
end

local function drawThanksScreen(balance)
    clearScreen()
    centerText(2, "Danke für deinen Einkauf!")
    centerText(4, "Neuer Kontostand: " .. balance .. " Credits")
    sleep(3)
end

local function drawError(message)
    clearScreen()
    centerText(3, "[Fehler] " .. message)
    sleep(2)
end

-- === Main Logic ===

while true do
    drawMainScreen()
    local button = waitForButton({ { label = "Berechnen", y = 6 } })

    if button == "Berechnen" then
        local initial = calculateValue()
        if initial == 0 then
            drawError("Keine gültigen Items.")
        else
            drawConfirmScreen(initial)
            local confirm = waitForButton({
                { label = "Bestätigen", y = 4 },
                { label = "Abbrechen", y = 6 }
            })

            if confirm == "Bestätigen" then
                local final = calculateValue()
                if final ~= initial then
                    drawError("Items wurden verändert!")
                else
                    local key = readPlayerKey()
                    if not key then
                        drawError("Keine Karte erkannt.")
                    else
                        rednet.broadcast({
                            type = "credit_action",
                            action = "add",
                            key = key,
                            amount = final
                        }, "casino")

                        local sender, response = rednet.receive("casino", 5)
                        if response and response.ok and response.newBalance then
                            transferItems()
                            drawThanksScreen(response.newBalance)
                        else
                            drawError("Serverfehler.")
                        end
                    end
                end
            end
        end
    end
end
