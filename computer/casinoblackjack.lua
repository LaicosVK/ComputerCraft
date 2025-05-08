-- === Multiplayer Blackjack Table ===
-- Hardware:
-- - Monitors: 2x4 table layout (facing up)
-- - Top: Wireless modem
-- - Sides: Wired modem (disk drives for players)

-- === CONFIGURATION ===
local PLAYER_SLOTS = {"drive_1", "drive_2", "drive_3", "drive_4"}
local MONITOR = peripheral.find("monitor")
local SPEAKER = peripheral.find("speaker")
local modem = peripheral.find("modem", function(_, obj) return obj.isWireless() end)

-- === GAME STATE ===
local players = {}
local deck = {}
local dealer = { hand = {}, hiddenCard = nil }
local gameState = "waiting" -- or "playing" / "results"

-- === CARD UTILITIES ===
local suits = {"♠", "♥", "♦", "♣"} -- spade, heart, diamond, club
local values = {
  {val="A", pts=11}, {val="2", pts=2}, {val="3", pts=3}, {val="4", pts=4},
  {val="5", pts=5}, {val="6", pts=6}, {val="7", pts=7}, {val="8", pts=8},
  {val="9", pts=9}, {val="10", pts=10}, {val="J", pts=10}, {val="Q", pts=10}, {val="K", pts=10}
}

local function buildDeck()
  deck = {}
  for _, suit in ipairs(suits) do
    for _, v in ipairs(values) do
      table.insert(deck, {val = v.val, pts = v.pts, suit = suit})
    end
  end
  for i = #deck, 2, -1 do
    local j = math.random(i)
    deck[i], deck[j] = deck[j], deck[i]
  end
end

local function drawCard()
  return table.remove(deck)
end

local function handValue(hand)
  local total, aces = 0, 0
  for _, card in ipairs(hand) do
    total = total + card.pts
    if card.val == "A" then aces = aces + 1 end
  end
  while total > 21 and aces > 0 do
    total = total - 10
    aces = aces - 1
  end
  return total
end

-- === MONITOR DISPLAY ===
local function clearMonitor()
  MONITOR.setTextScale(0.5)
  MONITOR.setBackgroundColor(colors.black)
  MONITOR.setTextColor(colors.white)
  MONITOR.clear()
end

local function drawCentered(y, text)
  local w, _ = MONITOR.getSize()
  local x = math.floor((w - #text) / 2)
  MONITOR.setCursorPos(x, y)
  MONITOR.write(text)
end

local function drawLobby()
  clearMonitor()
  drawCentered(2, "== BLACKJACK TABLE ==")
  for i = 1, #PLAYER_SLOTS do
    local status = players[i] and "Joined" or "Insert card & press Join"
    drawCentered(3 + i, "Player " .. i .. ": " .. status)
  end
  if next(players) then
    drawCentered(9, "Press START on host PC to begin!")
  end
end

local function drawHand(x, y, hand, isDealer)
  MONITOR.setCursorPos(x, y)
  if isDealer then MONITOR.write("Dealer:") else MONITOR.write("Your Hand:") end
  MONITOR.setCursorPos(x, y + 1)
  local display = ""
  for _, card in ipairs(hand) do
    display = display .. card.val .. card.suit .. " "
  end
  MONITOR.write(display)
end

-- === PLAYER JOIN ===
local function tryJoin(slotId)
  local drive = peripheral.wrap(slotId)
  if not drive or not drive.isDiskPresent() then return false end
  local path = drive.getMountPath() .. "/player.key"
  if not fs.exists(path) then return false end
  local f = fs.open(path, "r")
  local key = f.readAll()
  f.close()
  for i, sid in ipairs(PLAYER_SLOTS) do
    if sid == slotId then
      players[i] = { key = key, hand = {}, stood = false }
      return true
    end
  end
  return false
end

-- === GAME LOGIC ===
local function startGame()
  buildDeck()
  dealer.hand = {}
  dealer.hiddenCard = drawCard()
  for i, p in pairs(players) do
    p.hand = { drawCard(), drawCard() }
    p.stood = false
  end
  dealer.hand = { drawCard() }
  gameState = "playing"
end

-- === MAIN LOOP ===
local function mainLoop()
  drawLobby()
  while true do
    for i, slotId in ipairs(PLAYER_SLOTS) do
      if not players[i] then
        tryJoin(slotId)
      end
    end
    drawLobby()
    sleep(1)
  end
end

-- === START ===
mainLoop()
