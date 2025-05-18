-- Turtle Auto-Monitor & Replace Script
local CHECK_INTERVAL = 2  -- seconds between checks
local savedBlock = nil
local SLOT_BLOCK = 1  -- slot for the block to place

-- Helper: Get block data in front
local function inspectFront()
    local success, data = turtle.inspect()
    if success then
        return data.name
    else
        return nil
    end
end

-- Helper: Attempt to suck one block from chest above
local function fetchBlock()
    turtle.select(SLOT_BLOCK)
    if turtle.getItemCount(SLOT_BLOCK) == 0 then
        turtle.suckUp(1)
    end
    return turtle.getItemDetail(SLOT_BLOCK)
end

-- Helper: Place a block from SLOT_BLOCK
local function placeBlock()
    turtle.select(SLOT_BLOCK)
    if turtle.getItemCount(SLOT_BLOCK) > 0 then
        return turtle.place()
    end
    return false
end

-- Helper: Try to drop items to chest below
local function dropToBottom()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            turtle.dropDown()
        end
    end
end

-- Helper: Save block info
local function updateSavedBlock()
    local item = turtle.getItemDetail(SLOT_BLOCK)
    if item then
        savedBlock = item.name
        print("Saved block: " .. savedBlock)
    end
end

-- Startup: Place block if nothing in front
local function initialPlace()
    local frontBlock = inspectFront()
    if frontBlock == nil then
        local item = fetchBlock()
        if item then
            updateSavedBlock()
            if placeBlock() then
                print("Block placed.")
            else
                print("Failed to place block.")
            end
        else
            print("No block available to fetch.")
        end
    else
        savedBlock = frontBlock
        print("Existing block detected: " .. savedBlock)
    end
end

-- Main loop
initialPlace()

while true do
    sleep(CHECK_INTERVAL)
    local currentBlock = inspectFront()
    if currentBlock ~= savedBlock then
        print("Block changed or removed. Taking action...")
        if turtle.dig() then
            print("Block removed.")
        end

        dropToBottom()
        local item = fetchBlock()
        if item then
            updateSavedBlock()
            placeBlock()
        end
    end
end
