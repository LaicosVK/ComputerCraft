-- === STARTUP CONFIG ===
local configFile = "startup.cfg"
local fileName = "main"
local folderName = ""

-- === UTILITY FUNCTIONS ===
local function log(msg)
    print("[Startup] " .. msg)
end

local function fileExists(path)
    return fs.exists(path)
end

local function readFile(path)
    if not fs.exists(path) then return nil end
    local h = fs.open(path, "r")
    local data = h.readAll()
    h.close()
    return data
end

local function writeFile(path, content)
    local h = fs.open(path, "w")
    h.write(content)
    h.close()
end

local function downloadFile(url, destination)
    if fs.exists(destination) then fs.delete(destination) end
    local ok, err = pcall(function()
        shell.run("wget", url, destination)
    end)
    return ok and fs.exists(destination)
end

-- === CONFIG LOGIC ===
local function loadOrCreateConfig()
    if fs.exists(configFile) then
        local content = readFile(configFile)
        local config = textutils.unserialize(content or "")
        if type(config) == "table" then
            fileName = config.fileName or fileName
            folderName = config.folderName or folderName
        else
            log("Ungültige Konfigurationsdatei.")
        end
        return true
    else
        --log("Keine Konfig gefunden. Erstelle Standarddatei.")
        writeFile(configFile, textutils.serialize({
            fileName = "main",
            folderName = ""
        }))
        log("Bitte 'startup.cfg' bearbeiten und den Computer neu starten.")
        return false
    end
end

-- === UPDATE CHECK ===
local function checkAndQueueStartupUpdate()
    local url = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/startup.lua"
    local temp = "startup_new.lua"
    if not downloadFile(url, temp) then
        log("Konnte Startup-Update nicht herunterladen.")
        return
    end

    local remote = readFile(temp)
    local current = readFile("startup.lua") or ""
    if remote ~= current then
        log("!!\n!!\nNeues Startup-Update gefunden. Update wird beim nächsten Neustart angewendet.\n!!\n!!")
        fs.delete("startup_update.lua")
        fs.move(temp, "startup_update.lua")
    else
        fs.delete(temp)
        --log("Startup ist aktuell.")
    end
end

local function applyStartupUpdateIfAvailable()
    if fs.exists("startup_update.lua") then
        fs.delete("startup.lua")
        fs.move("startup_update.lua", "startup.lua")
        log("Startup-Update angewendet. Bitte neu starten.")
        return true
    end
    return false
end

-- === MAIN LOGIC ===
local function main()
    if not http then
        --log("HTTP ist nicht aktiviert.")
        return
    end

    if applyStartupUpdateIfAvailable() then
        return -- exit early, update will apply on next boot
    end

    if not loadOrCreateConfig() then return end

    checkAndQueueStartupUpdate()

    -- Check for main program update
    local mainPath = fileName .. ".lua"
    local url = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/" .. folderName .. mainPath
    local temp = "temp_dl"
    if downloadFile(url, temp) then
        local remote = readFile(temp)
        local localContent = readFile(mainPath) or ""
        if remote ~= localContent then
            log("!!\n!!\nUpdate für " .. mainPath .. " gefunden.\n!!\n!!")
            if fs.exists(mainPath) then fs.delete(mainPath) end
            fs.move(temp, mainPath)
        else
            fs.delete(temp)
            --log("Programm ist aktuell.")
        end
    else
        log("Konnte Hauptprogramm nicht aktualisieren.")
    end

    -- Run the main script
    log("Starte " .. mainPath)
    sleep(1)
    shell.run(mainPath)
end

main()
