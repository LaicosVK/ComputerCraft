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
    if fs.exists("temp_dl") then fs.delete("temp_dl") end
    local ok, err = pcall(function()
        shell.run("wget", url, "temp_dl")
    end)
    if not ok or not fs.exists("temp_dl") then
        log("Download failed from: " .. url)
        return false
    end
    if fs.exists(destination) then fs.delete(destination) end
    fs.move("temp_dl", destination)
    return true
end

-- === CONFIG LOGIC ===
local function loadOrCreateConfig()
    if fs.exists(configFile) then
        local content = readFile(configFile)
        if content then
            local config = textutils.unserialize(content)
            if type(config) == "table" then
                fileName = config.fileName or fileName
                folderName = config.folderName or folderName
            else
                log("Config konnte nicht gelesen werden.")
            end
        else
            log("Config-Datei ist leer oder unlesbar.")
        end
        return true
    else
        log("Keine Konfiguration gefunden. Erstelle Standarddatei...")
        writeFile(configFile, textutils.serialize({
            fileName = "main",
            folderName = ""
        }))
        log("Bitte 'startup.cfg' bearbeiten und danach neu starten.")
        return false
    end
end

-- === UPDATE CHECKER ===
local function checkForUpdate(scriptPath, remoteURL)
    log("Prüfe Update für '" .. scriptPath .. "' ...")
    if not downloadFile(remoteURL, "temp_dl") then
        log("Updateprüfung fehlgeschlagen.")
        return false
    end

    local remoteContent = readFile("temp_dl")
    local localContent = readFile(scriptPath) or ""

    if remoteContent ~= localContent then
        log("⚠️ Update gefunden! Ersetze '" .. scriptPath .. "' ...")
        if fs.exists(scriptPath) then fs.delete(scriptPath) end
        fs.move("temp_dl", scriptPath)
        return true
    else
        log("'" .. scriptPath .. "' ist aktuell.")
        fs.delete("temp_dl")
        return false
    end
end

-- === MAIN ===
local function main()
    if not http then
        log("HTTP API ist deaktiviert. Beende ...")
        return
    end

    if not loadOrCreateConfig() then return end

    -- Update this startup script
    local startupURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/startup.lua"
    checkForUpdate("startup.lua", startupURL)

    -- Update main program
    local scriptPath = fileName .. ".lua"
    local programURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/" .. folderName .. fileName .. ".lua"
    checkForUpdate(scriptPath, programURL)

    -- Run main program
    log("Starte '" .. scriptPath .. "' ...")
    sleep(1)
    shell.run(scriptPath)
end

main()
