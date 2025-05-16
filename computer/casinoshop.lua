-- Gift Shop Script
local version = "13"
local itemsPerPage = 5
local idleTimeout = 300

local lastInteraction = os.clock()
local selectedScreen = "main"
local scrollOffset = 0

-- Peripherals
local modem = peripheral.find("modem", function(_, obj)
    return peripheral.getType(obj) == "modem" and obj.isWireless()
end)
local diskDrive = peripheral.find("drive")
local barrel = peripheral.find("barrel")

local monitor
for _, name in ipairs(peripheral.getNames()) do
    if peripheral.getType(name) == "monitor" then
        monitor = peripheral.wrap(name)
        break
    end
end

if not monitor then
    error("Monitor not found")
end

monitor.setTextScale(1)
local width, height = monitor.getSize()
rednet.open("top")

-- Functions
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local function centerText(y, text, color)
    monitor.setCursorPos(math.floor((width - #text) / 2) + 1, y)
    monitor.setTextColor(color or colors.white)
    monitor.write(text)
end

local function displayMain()
    clearMonitor()
    centerText(2, "Geschenkeshop v" .. version, colors.yellow)
    centerText(4, "[ Kaufen ]", colors.lime)
end

local function scanChests()
    itemList = {}
    print("[DEBUG] Scanning peripherals...")
    for _, side in ipairs(peripheral.getNames()) do
        local pType = peripheral.getType(side)
        print("[DEBUG] Found peripheral:", side, "Type:", pType)

        if peripheral.hasType(side, "inventory") and pType ~= "barrel" then
            local chest = peripheral.wrap(side)
            local items = chest.list()
            local firstSlot = items[1]
            if firstSlot and firstSlot.displayName then
                local label = firstSlot.displayName
                print("[DEBUG] Item in first slot:", label)
                if label:find("cc:") then
                    local parts = {}
                    for part in label:gmatch("[^:]+") do table.insert(parts, part) end
                    if #parts >= 3 then
                        local itemName = parts[2]
                        local itemPrice = tonumber(parts[3])
                        if itemName and itemPrice then
                            local count = 0
                            for slot, item in pairs(items) do
                                if slot ~= 1 then
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
                            print("[WARN] Invalid name or price in:", label)
                        end
                    else
                        print("[WARN] Label format invalid:", label)
                    end
                end
            end
        end
    end
    print("[DEBUG] Total items loaded:", #itemList)
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
        if itemList[idx] then
            local item = itemList[idx]
            local stockText = item.stock > 0 and (item.name .. " - " .. item.price .. "¢") or (item.name .. " - AUSVERKAUFT")
            monitor.setCursorPos(2, i + 1)
            monitor.setTextColor(item.stock > 0 and colors.white or colors.gray)
            monitor.write(stockText)
        end
    end
    centerText(height, "[ Unten scrollen ]", colors.cyan)
end

local function inBounds(x, y, bx, by, bw, bh)
    return x >= bx and x <= bx + bw - 1 and y >= by and y <= by + bh - 1
end

local function getPlayerKey()
    if diskDrive.isDiskPresent() then
        local mount = diskDrive.getMountPath()
        if mount and fs.exists(mount .. "/player.key") then
            local file = fs.open(mount .. "/player.key", "r")
            local key = file.readAll()
            file.close()
            return key
        end
    end
    return nil
end

local function tryPurchase(item)
    if item.stock <= 0 then return end
    local key = getPlayerKey()
    if not key then return end
    rednet.broadcast({ type = "get_credits", key = key }, "casino")
    local _, response = rednet.receive("casino", 3)
    if response and response.credits and response.credits >= item.price then
        rednet.broadcast({ type = "remove_credits", key = key, amount = item.price }, "casino")
        local _, confirm = rednet.receive("casino", 3)
        if confirm and confirm.ok then
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
        end
    end
end

-- Main Loop
scanChests()
displayMain()

while true do
    if os.clock() - lastInteraction > idleTimeout and selectedScreen ~= "main" then
        selectedScreen = "main"
        scrollOffset = 0
        displayMain()
    end

    local e, side, x, y = os.pullEventRaw()
    if e == "monitor_touch" then
        lastInteraction = os.clock()

        if selectedScreen == "main" and inBounds(x, y, 1, 4, width, 1) then
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
            elseif y >= 2 and y <= 1 + itemsPerPage then
                local idx = scrollOffset + y - 1
                if itemList[idx] then
                    tryPurchase(itemList[idx])
                    displayItems()
                end
            end
        end
    end
end
