-- === CONFIGURATION ===
local TRADE_VALUES = {
    ["minecraft:diamond"] = 100,
    ["minecraft:emerald"] = 80,
    ["minecraft:gold_ingot"] = 25,
    ["minecraft:iron_ingot"] = 10
}

-- === UTILITIES ===
local function debug(msg)
    print("[DEBUG] " .. msg)
end

local function findPeripheralByType(typeFilter)
    for _, name in ipairs(peripheral.getNames()) do
        if peripheral.getType(name) == typeFilter then
            debug("Found peripheral of type '" .. typeFilter .. "' at: " .. name)
            return peripheral.wrap(name), name
        end
    end
    return nil
end

-- === INITIALIZATION ===
local monitor = peripheral.find("monitor")
local modem = peripheral.find("modem", function(_, obj) return obj.isWireless and obj.isWireless() end)

if not monitor or not modem then
    error("Monitor or wireless modem not found")
end

rednet.open(peripheral.getName(modem))
debug("Wireless modem opened on " .. peripheral.getName(modem))

local barrel = nil
local secureChest = nil
local drive = nil
for _, name in ipairs(peripheral.getNames()) do
    local t = peripheral.getType(name)
    if t == "drive" then
        drive = peripheral.wrap(name)
    elseif t:find("barrel") then
        barrel = peripheral.wrap(name)
    elseif t:find("chest") or t:find("ender_storage") then
        secureChest = peripheral.wrap(name)
    end
end

if not (barrel and secureChest and drive) then
    error("One or more peripherals not found (barrel, chest, drive)")
end

-- === FUNCTIONS ===
local function getMountPath()
    if not drive.isDiskPresent() then
        return nil
    end
    return drive.getMountPath()
end

local function getKey()
    local mountPath = getMountPath()
    if not mountPath then
        debug("Keine Diskette erkannt")
        return nil
    end
    local path = mountPath .. "/player.key"
    if not fs.exists(path) then
        debug("player.key fehlt")
        return nil
    end
    local f = fs.open(path, "r")
    local key = f.readAll()
    f.close()
    debug("Key gelesen: " .. key)
    return key
end

local function calculateCredit()
    local items = barrel.list()
    local total = 0
    for slot, item in pairs(items) do
        local value = TRADE_VALUES[item.name] or 0
        total = total + (value * item.count)
    end
    return total, items
end

local function moveItemsToSecureStorage(items)
    for slot, item in pairs(items) do
        barrel.pushItems(peripheral.getName(secureChest), slot, item.count)
    end
end

local function sendCreditUpdate(key, amount)
    rednet.broadcast({ type = "add_credits", key = key, amount = amount }, "casino")
    local id, msg = rednet.receive("casino", 5)
    if msg and msg.ok then
        return true, msg.newBalance
    else
        return false, nil
    end
end

local function drawCentered(text, y)
    local w, _ = monitor.getSize()
    local x = math.floor((w - #text) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.write(text)
end

local function showMainScreen()
    monitor.clear()
    drawCentered("Willkommen im Credit Trade Terminal", 2)
    drawCentered("[Berechnen]", 5)
end

local function showCalculationScreen(amount)
    monitor.clear()
    drawCentered("Gefundene Credits: " .. amount, 2)
    drawCentered("[Bestätigen]", 4)
    drawCentered("[Abbrechen]", 6)
end

local function showThanks(balance)
    monitor.clear()
    drawCentered("Danke für deine Spende!", 2)
    drawCentered("Kontostand: " .. balance .. " Credits", 4)
    sleep(3)
end

-- === MAIN LOOP ===
while true do
    showMainScreen()
    local _, _, x, y = os.pullEvent("monitor_touch")
    if y == 5 then
        local key = getKey()
        if not key then
            drawCentered("Fehlender oder ungültiger Key!", 8)
            sleep(2)
        else
            local credits, items = calculateCredit()
            showCalculationScreen(credits)
            local _, _, x2, y2 = os.pullEvent("monitor_touch")
            if y2 == 4 then
                local recalc, currentItems = calculateCredit()
                if recalc ~= credits then
                    drawCentered("Inhalt geändert. Abbruch.", 8)
                    sleep(2)
                else
                    local ok, newBal = sendCreditUpdate(key, credits)
                    if ok then
                        moveItemsToSecureStorage(currentItems)
                        showThanks(newBal)
                    else
                        drawCentered("Fehler beim Senden", 8)
                        sleep(2)
                    end
                end
            end
        end
    end
end
