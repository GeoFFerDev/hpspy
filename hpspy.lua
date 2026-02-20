-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v3 STABILITY BUILD
-- Features: Ultra-Fast Snap (25.0 Pull), Wide Active Zone (120 Radius),
--           Wall Bypass, Native AutoFire Boost, Player-Count FPS Fix.
-- Changes from v2:
--   • Removed custom AutoFire (conflicted with game's native autofire).
--   • Added InjectAutoFireBoost() — boosts the game's own autofire aggressiveness.
--   • ESP now caps at MAX_HIGHLIGHTS nearest enemies to prevent GPU overload in
--     large servers. CharacterRemoving used for instant highlight cleanup.
--   • ESP interval scales dynamically with player count (fewer players = faster refresh).

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local RunService       = game:GetService("RunService")  -- kept for future use / sanity
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- SETTINGS
-- =========================================================================
local Config = {
    ESP_Enabled  = true,
    Enemy_Color  = Color3.fromRGB(255, 0, 0),
}

-- Maximum simultaneous Highlight instances rendered at once.
-- AlwaysOnTop highlights are GPU-expensive; 10 is a safe ceiling
-- that still covers every realistic combat engagement range.
local MAX_HIGHLIGHTS = 10

-- =========================================================================
-- STATE
-- =========================================================================
local Highlights  = {}  -- [Player] = Highlight instance
local PlayerCache = {}  -- event-driven player set; never stale

-- =========================================================================
-- 1. SAFE EXECUTION WRAPPER
-- =========================================================================
local function ProtectExecution(func)
    local ok, err = pcall(func)
    if not ok then
        warn("[Bloxstrike] Protected:", err)
    end
    return ok
end

-- =========================================================================
-- 2. TEAM / ENEMY CHECK
-- =========================================================================
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam    = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team")    or "Nil")
    return myTeam ~= theirTeam
end

-- =========================================================================
-- 3. DISTANCE HELPER  (used for highlight priority sorting)
-- =========================================================================
local function GetDistanceTo(player)
    local myChar = LocalPlayer.Character
    local theirChar = player.Character
    if not myChar or not theirChar then return math.huge end

    local myRoot    = myChar:FindFirstChild("HumanoidRootPart")
    local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not theirRoot then return math.huge end

    return (myRoot.Position - theirRoot.Position).Magnitude
end

-- =========================================================================
-- 4. VELOCITY / AIMBOT INJECTION
-- =========================================================================
local function InjectGodMode()
    local foundTable  = false
    local hookedSmoke = false

    ProtectExecution(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]

            if type(v) == "table" and not foundTable then
                if rawget(v, "TargetSelection")
                and rawget(v, "Magnetism")
                and rawget(v, "RecoilAssist")
                and rawget(v, "Friction") then

                    -- [A] TARGETING
                    v.TargetSelection.MaxDistance = 10000
                    v.TargetSelection.MaxAngle    = 6.28
                    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = false end
                    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end

                    -- [B] MAGNETISM
                    v.Magnetism.Enabled            = true
                    v.Magnetism.MaxDistance        = 10000
                    v.Magnetism.PullStrength       = 25.0
                    v.Magnetism.StopThreshold      = 0
                    v.Magnetism.MaxAngleHorizontal = 6.28
                    v.Magnetism.MaxAngleVertical   = 6.28

                    -- [C] FRICTION
                    v.Friction.Enabled        = true
                    v.Friction.BubbleRadius   = 120.0
                    v.Friction.MinSensitivity = 0.0001

                    -- [D] NO RECOIL
                    v.RecoilAssist.Enabled         = true
                    v.RecoilAssist.ReductionAmount = 1.0

                    foundTable = true
                end

            elseif type(v) == "function" and not hookedSmoke then
                if debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                    hookfunction(v, function() return false end)
                    hookedSmoke = true
                end
            end

            if foundTable and hookedSmoke then break end
        end
    end)

    return foundTable
end

-- =========================================================================
-- 5. NATIVE AUTOFIRE BOOST INJECTION
--    Scans gc for the game's own autofire/triggerbot settings table and
--    sets every known aggressiveness field to its most aggressive value.
--    This does NOT create a second autofire — it just makes the game's
--    existing one react as fast as physically possible.
-- =========================================================================
local function InjectAutoFireBoost()
    local found = false

    ProtectExecution(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]

            if type(v) == "table" then
                -- Broad scan: look for any table that owns one or more of the
                -- known autofire sensitivity/delay field names used by the game.
                local hasAutoFireField =
                    rawget(v, "Sensitivity")    ~= nil or
                    rawget(v, "ReactionTime")   ~= nil or
                    rawget(v, "FireDelay")      ~= nil or
                    rawget(v, "TriggerDelay")   ~= nil or
                    rawget(v, "AutoFireDelay")  ~= nil or
                    rawget(v, "ShootDelay")     ~= nil or
                    rawget(v, "TriggerEnabled") ~= nil

                -- Secondary guard: must also look like an autofire/trigger config
                -- by owning at least one of these confirming fields.
                local isAutoFireTable =
                    rawget(v, "TriggerEnabled") ~= nil or
                    rawget(v, "AutoFireEnabled") ~= nil or
                    rawget(v, "FireMode")        ~= nil or
                    rawget(v, "AutoFire")        ~= nil

                if hasAutoFireField and isAutoFireTable then

                    -- Enable the trigger/autofire system.
                    if rawget(v, "TriggerEnabled")   ~= nil then v.TriggerEnabled   = true  end
                    if rawget(v, "AutoFireEnabled")  ~= nil then v.AutoFireEnabled  = true  end
                    if rawget(v, "AutoFire")         ~= nil and type(v.AutoFire) == "boolean" then
                        v.AutoFire = true
                    end

                    -- Zero out all delay/reaction fields so it fires as fast as possible.
                    if rawget(v, "Sensitivity")   ~= nil then v.Sensitivity   = 1.0   end
                    if rawget(v, "ReactionTime")  ~= nil then v.ReactionTime  = 0.0   end
                    if rawget(v, "FireDelay")     ~= nil then v.FireDelay     = 0.0   end
                    if rawget(v, "TriggerDelay")  ~= nil then v.TriggerDelay  = 0.0   end
                    if rawget(v, "AutoFireDelay") ~= nil then v.AutoFireDelay = 0.0   end
                    if rawget(v, "ShootDelay")    ~= nil then v.ShootDelay    = 0.0   end

                    -- Maximise detection window / angular tolerance if present.
                    if rawget(v, "TriggerAngle")     ~= nil then v.TriggerAngle     = 6.28 end
                    if rawget(v, "TriggerDistance")  ~= nil then v.TriggerDistance  = 10000 end
                    if rawget(v, "DetectionRadius")  ~= nil then v.DetectionRadius  = 10000 end

                    found = true
                    break  -- Stop after the first matching table; only one config needed.
                end
            end
        end
    end)

    return found
end

-- =========================================================================
-- 6. ESP — PLAYER-COUNT AWARE, PROXIMITY-CAPPED HIGHLIGHTS
--
--    Core FPS fix: no more than MAX_HIGHLIGHTS Highlight instances exist at
--    once. On each tick we:
--      1. Collect all living enemies and sort them by distance.
--      2. Assign highlights only to the nearest MAX_HIGHLIGHTS players.
--      3. Remove highlights from anyone who fell outside the cap.
--
--    Interval scales with server size so a 60-player server doesn't spin
--    faster than a 2-player one.
-- =========================================================================
local function RemoveHighlight(player)
    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end
end

local function CreateHighlight(char)
    local hl = Instance.new("Highlight")
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor           = Config.Enemy_Color
    hl.OutlineColor        = Config.Enemy_Color
    hl.Parent              = char
    return hl
end

-- Instant cleanup when a character model is removed mid-match.
local CharRemovedConns = {}  -- [Player] = RBXScriptConnection

local function HookCharacterRemoving(player)
    if CharRemovedConns[player] then
        CharRemovedConns[player]:Disconnect()
    end
    CharRemovedConns[player] = player.CharacterRemoving:Connect(function()
        RemoveHighlight(player)
    end)
end

-- Populate cache with players already in the server.
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        PlayerCache[p] = true
        HookCharacterRemoving(p)
    end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        PlayerCache[p] = true
        HookCharacterRemoving(p)
    end
end)

Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil
    RemoveHighlight(p)
    if CharRemovedConns[p] then
        CharRemovedConns[p]:Disconnect()
        CharRemovedConns[p] = nil
    end
end)

-- Dynamic ESP loop.
task.spawn(function()
    while true do
        -- Scale interval: faster refresh when few players, slower when many.
        -- 2 players  → 0.10 s   (snappy)
        -- 20 players → 0.20 s   (balanced)
        -- 60 players → 0.35 s   (safe)
        local playerCount = 0
        for _ in pairs(PlayerCache) do playerCount = playerCount + 1 end
        local interval = math.clamp(0.10 + (playerCount * 0.004), 0.10, 0.35)
        task.wait(interval)

        if not Config.ESP_Enabled then
            -- ESP was toggled off — clear everything and idle.
            for player in pairs(Highlights) do
                RemoveHighlight(player)
            end
        else
            -- Build a sorted list of [player, distance] for living enemies only.
            local candidates = {}
            for player in pairs(PlayerCache) do
                if IsEnemy(player) and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart") then
                    candidates[#candidates + 1] = { player = player, dist = GetDistanceTo(player) }
                end
            end

            table.sort(candidates, function(a, b) return a.dist < b.dist end)

            -- Build a set of who *should* have a highlight this tick.
            local shouldHighlight = {}
            local cap = math.min(#candidates, MAX_HIGHLIGHTS)
            for i = 1, cap do
                shouldHighlight[candidates[i].player] = true
            end

            -- Remove highlights from players no longer in the cap.
            for player in pairs(Highlights) do
                if not shouldHighlight[player] then
                    RemoveHighlight(player)
                end
            end

            -- Add or validate highlights for players in the cap.
            for player in pairs(shouldHighlight) do
                local char     = player.Character
                local existing = Highlights[player]

                if existing and existing.Parent == char then
                    -- Already valid — zero cost, skip.
                else
                    if existing then existing:Destroy() end
                    Highlights[player] = CreateHighlight(char)
                end
            end
        end
    end
end)

-- =========================================================================
-- 7. UI
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
if gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = CoreGui
end

-- ---- Minimized Icon ----
local IconFrame = Instance.new("Frame")
IconFrame.Size                   = UDim2.new(0, 50, 0, 50)
IconFrame.Position               = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible                = false
IconFrame.Active                 = true
IconFrame.Parent                 = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size             = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
IconButton.Text             = "B"
IconButton.TextColor3       = Color3.fromRGB(255, 255, 255)
IconButton.Font             = Enum.Font.SourceSansBold
IconButton.TextSize         = 24
IconButton.Parent           = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(1, 0)

-- ---- Main Window ----
local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 220, 0, 220)
MainFrame.Position         = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel  = 0
MainFrame.Active           = true
MainFrame.Draggable        = true
MainFrame.Parent           = ScreenGui

local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TitleBar.Parent           = MainFrame

local Title = Instance.new("TextLabel")
Title.Size              = UDim2.new(0.7, 0, 1, 0)
Title.Position          = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text              = "VELOCITY MAX"
Title.TextColor3        = Color3.fromRGB(255, 255, 255)
Title.Font              = Enum.Font.SourceSansBold
Title.TextSize          = 16
Title.TextXAlignment    = Enum.TextXAlignment.Left
Title.Parent            = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text             = "_"
MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
MinBtn.Font             = Enum.Font.SourceSansBold
MinBtn.TextSize         = 20
MinBtn.Parent           = TitleBar

-- ---- Icon drag (tap vs drag via pixel-delta threshold) ----
local iconDragStart, iconStartPos
local DRAG_THRESHOLD = 5

IconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        iconDragStart = input.Position
        iconStartPos  = IconFrame.Position
    end
end)

IconButton.InputChanged:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.Touch
    or  input.UserInputType == Enum.UserInputType.MouseMovement)
    and iconDragStart then
        local delta = input.Position - iconDragStart
        if delta.Magnitude > DRAG_THRESHOLD then
            IconFrame.Position = UDim2.new(
                iconStartPos.X.Scale, iconStartPos.X.Offset + delta.X,
                iconStartPos.Y.Scale, iconStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

IconButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        if iconDragStart and (input.Position - iconDragStart).Magnitude <= DRAG_THRESHOLD then
            IconFrame.Visible = false
            MainFrame.Visible = true
        end
        iconDragStart = nil
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    IconFrame.Visible = true
end)

-- =========================================================================
-- 8. BUTTONS
-- =========================================================================
local Content = Instance.new("Frame")
Content.Size                = UDim2.new(1, 0, 1, -30)
Content.Position            = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent              = MainFrame

local function Btn(name, order, func)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.Position         = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    b.Text             = name
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        local state = func()
        b.Text             = name .. ": " .. (state and "ON" or "OFF")
        b.BackgroundColor3 = state and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
    end)
    return b
end

-- Button 1: Full Body ESP
local EspBtn = Btn("Full Body ESP", 0, function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    return Config.ESP_Enabled
end)
EspBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
EspBtn.Text             = "Full Body ESP: ON"

-- Button 2: Boost AutoFire Sensitivity
local FireBoostBtn = Btn("Boost AutoFire", 1, function()
    local ok = InjectAutoFireBoost()
    return ok
end)
FireBoostBtn.BackgroundColor3 = Color3.fromRGB(150, 80, 0)
FireBoostBtn.Text             = "Boost AutoFire"

-- Button 3: Inject Max Velocity
local RageBtn = Btn("Inject Max Velocity", 2, function()
    return InjectGodMode()
end)
RageBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 0)
RageBtn.Text             = "Inject Max Velocity"

print("[Bloxstrike] v3 Loaded — AutoFire Boost + Player-Count FPS Fix Active")
