-- Gift Shop Script
local version = "19"
local itemsPerPage = 5
local idleTimeout = 30

local lastInteraction = os.clock()
local selectedScreen = "main"
local scrollOffset = 0
local itemList = {}

-- Peripherals
local modem = peripheral.find("modem", function(_, obj)
    return peripheral.getType(obj) == "modem" and obj.isWireless()
end)
local drive = peripheral.find("drive")
local barrel = peripheral.find("barrel")

local monitor
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitor = peripheral.wrap(name)
        break
    end
end

if not monitor then error("Monitor not found") end

monitor.setTextScale(1)
local width, height = monitor.getSize()
rednet.open("top")

-- Utility Functions
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local function centerText(y, text, color)
    monitor.setCursorPos(math.floor((width - #text) / 2) + 1, y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function showMessage(message, color, duration)
    clearMonitor()
    centerText(math.floor(height / 2), message, color or colors.red)
    sleep(duration or 2)
end

local function displayLoadingAnimation()
    clearMonitor()
    centerText(math.floor(height / 2), "Lade Artikel...", colors.cyan)
    for i = 1, 3 do
        sleep(0.3)
        monitor.write(".")
    end
end

-- === Server-Kommunikation ===
local function getKey()
    if not drive.isDiskPresent() then return nil end
    local path = drive.getMountPath()
    if not path or not fs.exists(path .. "/player.key") then return nil end
    local f = fs.open(path .. "/player.key", "r")
    local key = f.readAll()
    f.close()
    return key
end

local function getCredits(key)
    rednet.broadcast({ type = "get_credits", key = key }, "casino")
    local _, msg = rednet.receive("casino", 2)
    if msg and type(msg) == "table" and msg.credits then
        return msg.credits
    end
    return nil
end

local function removeCredits(key, amount)
    rednet.broadcast({ type = "remove_credits", key = key, amount = amount }, "casino")
    local _, msg = rednet.receive("casino", 2)
    return msg and msg.ok
end

-- Display Functions
local function displayMain()
    clearMonitor()
    centerText(2, "Geschenkeshop v" .. version, colors.yellow)
    centerText(4, "[ Kaufen ]", colors.lime)
end

local function displayItems()
    clearMonitor()
    if #itemList == 0 then
        centerText(math.floor(height / 2), "Keine Artikel gefunden", colors.red)
        return
    end

    centerText(1, "[ Oben scrollen ]", colors.cyan)
    for i = 1, itemsPerPage do
        local idx = scrollOffset + i
        local y = i + 1
        if itemList[idx] then
            local item = itemList[idx]
            local bg = (i % 2 == 0) and colors.gray or colors.lightGray
            monitor.setBackgroundColor(bg)
            monitor.setCursorPos(1, y)
            monitor.clearLine()
            monitor.setTextColor(item.stock > 0 and colors.white or colors.red)
            local text = item.stock > 0 and (item.name .. " - " .. item.price .. "¢") or (item.name .. " - AUSVERKAUFT")
            monitor.write(text)
        end
    end
    monitor.setBackgroundColor(colors.black)
    centerText(height, "[ Unten scrollen ]", colors.cyan)
end

-- Inventory Scanner
local function scanChests()
    itemList = {}
    print("[DEBUG] Scanning peripherals...")
    displayLoadingAnimation()

    for _, side in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(side)

        if peripheral.hasType(side, "inventory") and pType ~= "barrel" then
            local chest = peripheral.wrap(side)
            local items = chest.list()
            local details = chest.getItemDetail(1)

            if details and details.displayName and details.displayName:find("cc:") then
                print("[DEBUG] Found labeled item in slot 1:", details.displayName)

                local parts = {}
                for part in details.displayName:gmatch("[^:]+") do table.insert(parts, part) end

                if #parts >= 3 then
                    local itemName = parts[2]
                    local itemPrice = tonumber(parts[3])
                    if itemName and itemPrice then
                        local count = 0
                        for slot, item in pairs(items) do
                            if slot ~= 1 and item.count then
                                count = count + item.count
                            end
                        end
                        table.insert(itemList, {
                            chest = side,
                            name = itemName,
                            price = itemPrice,
                            stock = count
                        })
                        print("[DEBUG] Added item:", itemName, "Price:", itemPrice, "Stock:", count)
                    else
                        print("[WARN] Invalid name/price:", itemName, itemPrice)
                    end
                else
                    print("[WARN] Invalid format:", details.displayName)
                end
            else
                print("[INFO] No valid label in slot 1 of", side)
            end
        end
    end

    print("[DEBUG] Total items loaded:", #itemList)
end

-- Purchase Logic
local function tryPurchase(item)
    print("[DEBUG] Attempting purchase:", item.name)
    if item.stock <= 0 then
        showMessage("Ausverkauft!", colors.red)
        return
    end

    local key = getKey()
    if not key then
        showMessage("Bitte Karte einlegen!", colors.orange)
        return
    end

    local credits = getCredits(key)
    if credits == nil then
        print("[DEBUG] Keine Antwort oder ungültig")
        showMessage("Fehler bei Guthabenprüfung", colors.red)
        return
    end

    if credits < item.price then
        showMessage("Nicht genug Guthaben!", colors.red)
        return
    end

    if removeCredits(key, item.price) then
        local chest = peripheral.wrap(item.chest)
        for slot, content in pairs(chest.list()) do
            if slot ~= 1 and content.name then
                chest.pushItems(peripheral.getName(barrel), slot, 1)
                if peripheral.find("speaker") then
                    peripheral.find("speaker").playNote("bell", 3, 5)
                end
                break
            end
        end
        showMessage("Kauf erfolgreich!", colors.lime)
    else
        showMessage("Kauf fehlgeschlagen!", colors.red)
    end
end

-- Main Loop
scanChests()
displayMain()

while true do
    if os.clock() - lastInteraction > idleTimeout then
        print("[DEBUG] Timeout - zurück zum Hauptmenü")
        selectedScreen = "main"
        scrollOffset = 0
        displayMain()
    end

    local e = os.pullEventRaw()
    if e == "terminate" then break end

    if e == "monitor_touch" then
        local _, side, x, y = os.pullEvent("monitor_touch")
        lastInteraction = os.clock()
        print("[DEBUG] Monitor touched at:", x, y)

        if selectedScreen == "main" and y == 4 then
            selectedScreen = "items"
            scrollOffset = 0
            scanChests()
            displayItems()
        elseif selectedScreen == "items" then
            if y == 1 and scrollOffset > 0 then
                scrollOffset = scrollOffset - 1
                displayItems()
            elseif y == height and (scrollOffset + itemsPerPage) < #itemList then
                scrollOffset = scrollOffset + 1
                displayItems()
            elseif y >= 2 and y <= itemsPerPage + 1 then
                local idx = scrollOffset + (y - 2) + 1
                if itemList[idx] then
                    tryPurchase(itemList[idx])
                    scanChests()
                    displayItems()
                end
            end
        end
    end
end
