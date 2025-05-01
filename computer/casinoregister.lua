-- Casino Registration Kiosk

local monitor = peripheral.find("monitor")
local drive = peripheral.find("drive")
local wirelessModemSide = nil

-- === OPEN WIRELESS MODEM ===
for _, side in ipairs({ "top", "bottom", "left", "right", "front", "back" }) do
    if peripheral.getType(side) == "modem" and peripheral.call(side, "isWireless") then
        rednet.open(side)
        wirelessModemSide = side
        print("Wireless modem found and opened on side: " .. side)
        break
    end
end

-- === SAFETY CHECK ===
if not monitor or not drive or not rednet.isOpen() then
    print("Missing peripheral!")
    if not monitor then print("Monitor not found.") end
    if not drive then print("Disk drive not found.") end
    if not rednet.isOpen() then print("Wireless modem not open.") end
    return
end

print("All peripherals found. Starting interface...")

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

local function drawButton(text, y, color)
    local x = math.floor((w - #text - 4) / 2) + 1
    monitor.setCursorPos(x, y)
    monitor.setBackgroundColor(color)
    monitor.setTextColor(colors.black)
    monitor.write("  " .. text .. "  ")
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

local function waitForButtons(buttons)
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        print("Touch at x="..x..", y="..y)
        for _, button in ipairs(buttons) do
            local bx = math.floor((w - #button.label - 4) / 2) + 1
            local by = button.y
            if y == by and x >= bx and x <= (bx + #button.label + 3) then
                print("Button '" .. button.label .. "' clicked.")
                return button.label
            end
        end
    end
end

local function drawWelcomeScreen()
    print("Drawing welcome screen")
    monitor.clear()
    center("Willkommen", 2)
    center("im Casino!", 3)
    drawButton("Registrieren", 5, colors.green)
end

local function drawInsertDiskScreen()
    print("Prompting user to insert disk")
    monitor.clear()
    center("Bitte Diskette einlegen", 2)
    drawButton("Weiter", 4, colors.green)
    drawButton("Abbrechen", 6, colors.red)
end

local function drawRegistrationScreen()
    print("Registering user...")
    monitor.clear()
    center("Registriere...", 2)
    center("Bitte warten.", 3)
end

local function drawCompletionScreen()
    print("Registration complete.")
    monitor.clear()
    center("Fertig!", 2)
    center("Viel Glück!", 3)
    drawButton("OK", 5, colors.green)
end

local function drawErrorScreen(message)
    monitor.clear()
    center("[X] " .. message, 2)
    sleep(2)
end

local function doRegistration()
    drawRegistrationScreen()
    rednet.broadcast({ type = "register_request" }, "casino")
    print("Sent registration request to master.")
    local id, reply = rednet.receive("casino", 5)

    if reply and reply.ok and reply.key then
        print("Received key from master: " .. reply.key)

        -- Get correct mount path
        local mountPath = drive.getMountPath()
        if not mountPath then
            drawErrorScreen("Diskette nicht lesbar!")
            return
        end

        local f = fs.open(mountPath .. "/player.key", "w")
        if f then
            f.write(reply.key)
            f.close()
            disk.setLabel(peripheral.getName(drive), "Casino Karte")
            drawCompletionScreen()
            waitForButtons({ { label = "OK", y = 5 } })
        else
            print("Fehler beim Schreiben auf Diskette.")
            drawErrorScreen("Schreibfehler auf Diskette!")
        end
    else
        print("No response or invalid response from master.")
        drawErrorScreen("Kommunikation fehlgeschlagen")
    end
end

-- === Main Loop ===
while true do
    drawWelcomeScreen()
    local clicked = waitForButtons({
        { label = "Registrieren", y = 5 }
    })

    if disk.isPresent(peripheral.getName(drive)) and disk.hasData(peripheral.getName(drive)) then
        doRegistration()
    else
        local retryInsert = true
        while retryInsert do
            drawInsertDiskScreen()
            local insertClick = waitForButtons({
                { label = "Weiter", y = 4 },
                { label = "Abbrechen", y = 6 }
            })

            if insertClick == "Abbrechen" then
                retryInsert = false
            elseif insertClick == "Weiter" then
                if not disk.isPresent(peripheral.getName(drive)) then
                    print("No disk present.")
                    drawErrorScreen("Keine Diskette erkannt!")
                else
                    doRegistration()
                    retryInsert = false
                end
            end
        end
    end
end
