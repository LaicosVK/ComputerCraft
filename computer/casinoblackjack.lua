-- === Multiplayer Blackjack Table ===
-- Supports 1–4 players with disk drive card join and shared monitor interface

print("v1")

-- === CONFIGURATION ===
local MONITOR_SIDE = "back"
local MODEM_SIDE = "top"
local PLAYER_SIDES = {"left", "right", "front", "bottom"} -- Each disk drive for players 1–4
local CHANNEL = "blackjack"
local JOIN_BUTTON_COLOR = colors.lime

-- === GLOBALS ===
local monitor = peripheral.wrap(MONITOR_SIDE)
local players = {}

-- === UTILITY FUNCTIONS ===
local function clearMonitor()
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
end

local function centerText(y, text)
    local w, _ = monitor.getSize()
    local x = math.floor((w - #text) / 2)
    monitor.setCursorPos(x + 1, y)
    monitor.write(text)
end

local function drawJoinButtons()
    local width, height = monitor.getSize()
    local sectionWidth = math.floor(width / 4)

    for i = 1, 4 do
        local x = (i - 1) * sectionWidth + math.floor((sectionWidth - 6) / 2)
        local y = math.floor(height / 2)

        monitor.setCursorPos(x, y)
        monitor.setBackgroundColor(JOIN_BUTTON_COLOR)
        monitor.setTextColor(colors.black)
        monitor.write(" JOIN ")
        monitor.setBackgroundColor(colors.black)
    end
end

local function getPlayerFromClick(x)
    local width = monitor.getSize()
    local sectionWidth = math.floor(width / 4)
    return math.ceil(x / sectionWidth)
end

local function readKeyFromDrive(side)
    if not peripheral.isPresent(side) then return nil end
    local drive = peripheral.wrap(side)
    if not drive.isDiskPresent() then return nil end

    local mountPath = drive.getMountPath()
    if not mountPath then return nil end

    local path = mountPath .. "/player.key"
    if not fs.exists(path) then return nil end

    local f = fs.open(path, "r")
    local key = f.readAll()
    f.close()
    return key
end

local function showWaiting()
    clearMonitor()
    centerText(1, "Insert card & press JOIN")
    drawJoinButtons()
end

local function addPlayer(index)
    local side = PLAYER_SIDES[index]
    local key = readKeyFromDrive(side)
    if not key then
        print("[!] No key found for Player " .. index)
        return
    end
    players[index] = { key = key, hand = {}, total = 0 }
    print("[+] Player " .. index .. " joined with key: " .. key)
end

-- === MAIN ===
rednet.open(MODEM_SIDE)
monitor.setTextScale(1)
monitor.setBackgroundColor(colors.black)
monitor.setTextColor(colors.white)

showWaiting()

while true do
    local event, side, x, y = os.pullEvent("monitor_touch")
    local playerIndex = getPlayerFromClick(x)

    if players[playerIndex] then
        print("Player " .. playerIndex .. " already joined.")
    else
        addPlayer(playerIndex)
        showWaiting()
        -- Optional: show confirmation in monitor area
        local w = monitor.getSize()
        local sectionWidth = math.floor(w / 4)
        local px = (playerIndex - 1) * sectionWidth + 2
        monitor.setCursorPos(px, y + 1)
        monitor.setTextColor(colors.white)
        monitor.write("JOINED")
    end
end