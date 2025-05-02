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
    local h = fs.open(path, "r")
    local data = h.readAll()
    h.close()
    return data
end

local function downloadFile(url, destination)
    if fs.exists("temp_dl") then fs.delete("temp_dl") end
    local ok, err = pcall(function()
        shell.run("wget", url, "temp_dl")
    end)
    if not ok or not fs.exists("temp_dl") then
        log("Fehler beim Herunterladen von: " .. url)
        return false
    end
    if fs.exists(destination) then fs.delete(destination) end
    fs.move("temp_dl", destination)
    return true
end

-- === CONFIG LOGIC ===
local function loadOrCreateConfig()
    if fs.exists(configFile) then
        local ok, err = pcall(function()
            local f = fs.open(configFile, "r")
            local config = textutils.unserialize(f.readAll())
            f.close()
            if type(config) == "table" then
                if config.fileName then fileName = config.fileName end
                if config.folderName then folderName = config.folderName end
            end
        end)
        if not ok then
            log("Fehler beim Laden der Konfiguration: " .. tostring(err))
        end
    else
        log("Keine Konfiguration gefunden. Erstelle Standarddatei.")
        local f = fs.open(configFile, "w")
        f.write(textutils.serialize({
            fileName = "main",
            folderName = ""
        }))
        f.close()
        log("Bitte 'startup.cfg' bearbeiten und danach neu starten.")
        return false
    end
    return true
end

-- === UPDATE CHECKER ===
local function checkForUpdate(scriptPath, remoteURL)
    log("Überprüfe Updates für '" .. scriptPath .. "' ...")
    local remoteOK = downloadFile(remoteURL, "temp_dl")
    if not remoteOK then
        log("Updateprüfung fehlgeschlagen.")
        return false
    end

    local remoteContent = readFile("temp_dl")
    local localContent = fileExists(scriptPath) and readFile(scriptPath) or ""

    if remoteContent ~= localContent then
        log("⚠️ Update verfügbar! Ersetze '" .. scriptPath .. "' ...")
        if fileExists(scriptPath) then fs.delete(scriptPath) end
        fs.move("temp_dl", scriptPath)
        return true
    else
        log("Keine Aktualisierung notwendig für '" .. scriptPath .. "'.")
        fs.delete("temp_dl")
        return false
    end
end

-- === MAIN EXECUTION ===
local function main()
    if not http then
        log("HTTP API ist nicht aktiviert. Beende ...")
        return
    end

    if not loadOrCreateConfig() then return end

    -- Update self
    local startupURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/startup.lua"
    checkForUpdate("startup.lua", startupURL)

    -- Update target program
    local programPath = fileName .. ".lua"
    local programURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/" .. folderName .. fileName .. ".lua"
    checkForUpdate(programPath, programURL)

    -- Run main program
    log("Starte '" .. programPath .. "' ...")
    sleep(1)
    shell.run(programPath)
end

main()
