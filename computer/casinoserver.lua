-- Casino Master Server with Monitor Stats Display

-- === Peripheral Setup ===
local modemFound = false
local monitor = peripheral.find("monitor")

for _, side in ipairs({ "left", "right", "top", "bottom", "front", "back" }) do
    if peripheral.getType(side) == "modem" then
        rednet.open(side)
        print("Opened modem on " .. side)
        modemFound = true
    end
end

if not modemFound then
    print("No modem found. Exiting.")
    return
end

-- === Balance Data ===
local balances = {}

-- === Load Balances ===
local function loadBalances()
    if fs.exists("balances.db") then
        local file = fs.open("balances.db", "r")
        local data = file.readAll()
        file.close()
        balances = textutils.unserialize(data) or {}
        print("Balances loaded.")
    else
        balances = {}
        print("No previous balances found. Starting fresh.")
    end
end

-- === Save Balances ===
local function saveBalances()
    local file = fs.open("balances.db", "w")
    file.write(textutils.serialize(balances))
    file.close()
    print("Balances saved.")
end

-- === Generate Unique Key ===
local function uuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function (c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

-- === Create Account ===
local function createAccount()
    local key = uuid()
    balances[key] = 0
    saveBalances()
    print("Created new account: " .. key)
    return key
end

-- === External Monitor Display ===
local function updateMonitor()
    if not monitor then return end

    monitor.setTextScale(1)
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
    monitor.clear()

    local totalPlayers = 0
    local totalCredits = 0
    for _, balance in pairs(balances) do
        totalPlayers = totalPlayers + 1
        totalCredits = totalCredits + balance
    end

    monitor.setCursorPos(1, 1)
    monitor.write("=== Casino Stats ===")

    monitor.setCursorPos(1, 3)
    monitor.write("Konten: " .. totalPlayers)

    monitor.setCursorPos(1, 4)
    monitor.write("Credits: " .. totalCredits)
end

-- === Handle Requests ===
local function handleRequest(sender, msg)
    if type(msg) ~= "table" or not msg.type then
        rednet.send(sender, { ok = false, error = "Invalid message format" })
        return
    end

    if msg.type == "register_request" then
        print("Received register_request from ID " .. sender)
        local key = createAccount()
        rednet.send(sender, { ok = true, key = key }, "casino")

    elseif msg.type == "get_balance" and msg.key then
        print("Received get_balance for key " .. msg.key)
        local bal = balances[msg.key]
        rednet.send(sender, { ok = true, balance = bal or 0 })

    elseif msg.type == "add_credits" and msg.key and msg.amount then
        print("Received add_credits for key " .. msg.key .. " amount: " .. msg.amount)
        balances[msg.key] = (balances[msg.key] or 0) + msg.amount
        saveBalances()
        rednet.send(sender, { ok = true, newBalance = balances[msg.key] })

    elseif msg.type == "remove_credits" and msg.key and msg.amount then
        print("Received remove_credits for key " .. msg.key .. " amount: " .. msg.amount)
        local current = balances[msg.key] or 0
        if current >= msg.amount then
            balances[msg.key] = current - msg.amount
            saveBalances()
            rednet.send(sender, { ok = true, newBalance = balances[msg.key] })
        else
            rednet.send(sender, { ok = false, error = "Insufficient funds" })
            print("Failed to remove credits: insufficient funds")
        end

    else
        print("Received unknown request type.")
        rednet.send(sender, { ok = false, error = "Unknown request type" })
    end

    updateMonitor()
end

-- === Main Loop ===
loadBalances()
updateMonitor()
print("Casino Master Server Ready.")

while true do
    local sender, msg, protocol = rednet.receive("casino")
    print("Received message from " .. sender)
    handleRequest(sender, msg)
end