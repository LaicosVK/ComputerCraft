-- === CONFIGURATION ===
local fileName = "startup"
local folderName = ""

local remoteURL = "https://raw.githubusercontent.com/LaicosVK/ComputerCraft/refs/heads/main/" .. folderName .. fileName .. ".lua"
local localFile = fileName .. ".lua"

-- === FUNCTIONS ===
local function fileExists(path)
    return fs.exists(path)
end

local function readFile(path)
    local h = fs.open(path, "r")
    local data = h.readAll()
    h.close()
    return data
end

local function downloadFile(url, path)
    print("Downloading latest script from GitHub...")
    if fs.exists("temp_dl") then fs.delete("temp_dl") end
    local ok, err = pcall(function()
        shell.run("wget", url, "temp_dl")
    end)
    if not ok then
        print("Download failed: " .. tostring(err))
        return false
    end
    if fs.exists(path) then fs.delete(path) end
    fs.move("temp_dl", path)
    return true
end

-- === MAIN LOGIC ===
local updateNeeded = false

print("Checking for updates...")

if not http then
    print("HTTP API not enabled. Aborting.")
    return
end

-- Download remote script to temp file
if fs.exists("temp_dl") then fs.delete("temp_dl") end
local ok, err = pcall(function()
    shell.run("wget", remoteURL, "temp_dl")
end)

if not ok or not fs.exists("temp_dl") then
    print("Failed to fetch remote file: " .. tostring(err))
else
    local remoteContent = readFile("temp_dl")
    local localContent = fileExists(localFile) and readFile(localFile) or ""

    if remoteContent ~= localContent then
        print("Update found. Replacing old script...")
        if fileExists(localFile) then fs.delete(localFile) end
        fs.move("temp_dl", localFile)
    else
        print("Script is up to date.")
        fs.delete("temp_dl")
    end
end

-- === EXECUTE MAIN SCRIPT ===
print("Starting main script...")
sleep(1)
shell.run(localFile)
