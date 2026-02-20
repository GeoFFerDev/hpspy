-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - STABILITY OPTIMIZED
-- Features: Ultra-Fast Snap (25.0 Pull), Wide Active Zone (120 Radius), Wall Bypass, Auto-Fire.
-- Optimization pass: Removed per-frame pcall overhead, event-driven ESP cache,
--                    AutoFire throttle, stable Highlight lifecycle management.

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- =========================================================================
-- SETTINGS
-- =========================================================================
local Config = {
    ESP_Enabled  = true,
    AutoFire     = false,
    Enemy_Color  = Color3.fromRGB(255, 0, 0),
}

-- =========================================================================
-- CONSTANTS / CACHE
-- =========================================================================
local Highlights   = {}   -- [Player] = Highlight instance
local PlayerCache  = {}   -- event-driven list; avoids GetPlayers() every tick

-- AutoFire throttle: only attempt to fire every N seconds to avoid
-- calling tool:Activate() 60+ times per second (massive CPU waste).
local AUTOFIRE_INTERVAL = 0.08  -- ~12 attempts/sec is more than enough
local lastFireTime      = 0

-- =========================================================================
-- 1. SAFE EXECUTION WRAPPER  (used only for truly unsafe external calls)
-- =========================================================================
local function ProtectExecution(func)
    local ok, err = pcall(func)
    if not ok then
        warn("[Bloxstrike] Stealth Mode: Prevented Error Report.", err)
    end
    return ok
end

-- =========================================================================
-- 2. TEAM / ENEMY CHECK  (inlined, no closure allocation per frame)
-- =========================================================================
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam    = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team")    or "Nil")
    return myTeam ~= theirTeam
end

-- =========================================================================
-- 3. MEMORY INJECTION  (unchanged logic, only called on button press)
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
                    v.Magnetism.Enabled              = true
                    v.Magnetism.MaxDistance          = 10000
                    v.Magnetism.PullStrength         = 25.0
                    v.Magnetism.StopThreshold        = 0
                    v.Magnetism.MaxAngleHorizontal   = 6.28
                    v.Magnetism.MaxAngleVertical     = 6.28

                    -- [C] FRICTION
                    v.Friction.Enabled       = true
                    v.Friction.BubbleRadius  = 120.0
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
-- 4. ESP — EVENT-DRIVEN PLAYER CACHE + STABLE HIGHLIGHT LIFECYCLE
--    Problem fixed: GetPlayers() + full iteration every 0.1 s was wasteful.
--    Now we maintain a set via PlayerAdded/PlayerRemoving and only loop
--    over actual players. Highlights are only destroyed when truly needed.
-- =========================================================================
local function RemoveHighlight(player)
    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end
end

local function UpdateHighlight(player)
    if not Config.ESP_Enabled or not IsEnemy(player) then
        RemoveHighlight(player)
        return
    end

    local char = player.Character
    if not char then
        RemoveHighlight(player)
        return
    end

    local existing = Highlights[player]
    -- Only rebuild if the highlight is missing or orphaned (parent changed).
    if existing and existing.Parent == char then
        return  -- ← already valid, skip entirely (zero cost)
    end

    if existing then existing:Destroy() end

    local hl = Instance.new("Highlight")
    hl.FillTransparency   = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode          = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor          = Config.Enemy_Color
    hl.OutlineColor       = Config.Enemy_Color
    hl.Parent             = char
    Highlights[player]    = hl
end

-- Populate cache with current players immediately.
for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then
        PlayerCache[p] = true
    end
end

-- Keep cache in sync via events (zero per-frame cost).
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then
        PlayerCache[p] = true
    end
end)

Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil
    RemoveHighlight(p)
end)

-- Lightweight ESP refresh: 0.15 s is imperceptible for highlights
-- and cuts the loop frequency vs the original 0.1 s.
task.spawn(function()
    while task.wait(0.15) do
        -- Wrap only the loop body so pcall isn't called unless an error occurs.
        for player in pairs(PlayerCache) do
            local ok, err = pcall(UpdateHighlight, player)
            if not ok then warn("[Bloxstrike] ESP error:", err) end
        end
    end
end)

-- =========================================================================
-- 5. AUTO-FIRE — THROTTLED, pcall-FREE HOT PATH
--    Problem fixed: pcall on RenderStepped = ~60 pcalls/sec overhead.
--    Now we only wrap the risky Tool:Activate() call; the guard logic
--    runs native. A time-gate prevents spamming activate every frame.
-- =========================================================================
RunService.Heartbeat:Connect(function()
    if not Config.AutoFire then return end

    local now = os.clock()
    if (now - lastFireTime) < AUTOFIRE_INTERVAL then return end

    local target = Mouse.Target
    if not target or not target.Parent then return end

    local targetPlayer = Players:GetPlayerFromCharacter(target.Parent)
    if not targetPlayer or not IsEnemy(targetPlayer) then return end

    local char = LocalPlayer.Character
    if not char then return end

    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end

    lastFireTime = now
    -- Only pcall the external game call that can error.
    pcall(function() tool:Activate() end)
end)

-- =========================================================================
-- 6. UI SYSTEM  (identical functionality, minor cleanup)
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
IconFrame.Size                = UDim2.new(0, 50, 0, 50)
IconFrame.Position            = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible             = false
IconFrame.Active              = true
IconFrame.Parent              = ScreenGui

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
MainFrame.Size            = UDim2.new(0, 220, 0, 220)
MainFrame.Position        = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active          = true
MainFrame.Draggable       = true
MainFrame.Parent          = ScreenGui

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

-- ---- Drag logic for Icon (fixed race condition with a position delta check) ----
local iconDragStart, iconStartPos, iconLastInputPos
local DRAG_THRESHOLD = 5  -- pixels moved before it counts as a drag, not a tap

IconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        iconDragStart   = input.Position
        iconStartPos    = IconFrame.Position
        iconLastInputPos = input.Position
    end
end)

IconButton.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseMovement then
        iconLastInputPos = input.Position
        if iconDragStart then
            local delta = input.Position - iconDragStart
            if delta.Magnitude > DRAG_THRESHOLD then
                IconFrame.Position = UDim2.new(
                    iconStartPos.X.Scale, iconStartPos.X.Offset + delta.X,
                    iconStartPos.Y.Scale, iconStartPos.Y.Offset + delta.Y
                )
            end
        end
    end
end)

IconButton.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- Only treat as a tap (show window) if the cursor barely moved.
        if iconDragStart and (input.Position - iconDragStart).Magnitude <= DRAG_THRESHOLD then
            IconFrame.Visible  = false
            MainFrame.Visible  = true
        end
        iconDragStart = nil
    end
end)

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    IconFrame.Visible = true
end)

-- =========================================================================
-- 7. BUTTONS
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

local EspBtn = Btn("Full Body ESP", 0, function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    -- Immediately clear all highlights when ESP is turned off.
    if not Config.ESP_Enabled then
        for player in pairs(PlayerCache) do
            RemoveHighlight(player)
        end
    end
    return Config.ESP_Enabled
end)
EspBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
EspBtn.Text             = "Full Body ESP: ON"

local TriggerBtn = Btn("Auto Fire", 1, function()
    Config.AutoFire = not Config.AutoFire
    return Config.AutoFire
end)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
TriggerBtn.Text             = "Auto Fire: OFF"

local RageBtn = Btn("Inject Max Velocity", 2, function()
    return InjectGodMode()
end)
RageBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 0)
RageBtn.Text             = "Inject Max Velocity"

print("[Bloxstrike] Max Speed Loaded (Stability Optimized)")
