-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v4 STABILITY BUILD
-- Features: Ultra-Fast Aggressive Snap, Wide Active Zone, Wall Bypass,
--           Native AutoFire Boost, Player-Count FPS Fix, True Button Toggles.
-- v4 Changes:
--   • All buttons now properly toggle ON/OFF with correct UI feedback.
--   • Original game values are saved on first inject; restored on toggle-OFF.
--   • Re-enabling re-applies boosted values instantly (no second gc scan needed).
--   • Magnetism PullStrength: 25 → 80, BubbleRadius: 120 → 250 (more aggressive).
--   • MinSensitivity: 0.0001 → 0.000001 (near-zero friction, snappiest snap).

local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- SETTINGS
-- =========================================================================
local Config = {
    ESP_Enabled       = true,
    VelocityActive    = false,  -- tracks Inject Max Velocity ON/OFF
    AutoFireActive    = false,  -- tracks Boost AutoFire ON/OFF
    Enemy_Color       = Color3.fromRGB(255, 0, 0),
}

-- Cached gc table references — found once, reused forever for toggles.
-- This avoids re-scanning gc on every button press.
local VelocityTableRef  = nil   -- the aimbot/magnetism config table
local AutoFireTableRef  = nil   -- the autofire config table

-- Stored original values so we can restore them when toggling OFF.
local OrigVelocity = {}
local OrigAutoFire = {}

local MAX_HIGHLIGHTS = 10

-- =========================================================================
-- STATE
-- =========================================================================
local Highlights     = {}
local PlayerCache    = {}
local CharRemovedConns = {}

-- =========================================================================
-- 1. SAFE EXECUTION WRAPPER
-- =========================================================================
local function ProtectExecution(func)
    local ok, err = pcall(func)
    if not ok then warn("[Bloxstrike] Protected:", err) end
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
-- 3. DISTANCE HELPER
-- =========================================================================
local function GetDistanceTo(player)
    local myChar    = LocalPlayer.Character
    local theirChar = player.Character
    if not myChar or not theirChar then return math.huge end
    local myRoot    = myChar:FindFirstChild("HumanoidRootPart")
    local theirRoot = theirChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not theirRoot then return math.huge end
    return (myRoot.Position - theirRoot.Position).Magnitude
end

-- =========================================================================
-- 4. VELOCITY / AIMBOT — TRUE TOGGLE
--
--    First call:  Scans gc, saves originals, applies boosted values.
--    Toggle OFF:  Restores saved originals using the cached table ref.
--    Toggle ON:   Re-applies boosted values using the cached table ref.
--    No repeated gc scan after first successful find.
-- =========================================================================

-- Aggressive aim values — tuned for maximum snap speed and lock radius.
local VELOCITY_BOOST = {
    TargetSelection_MaxDistance  = 10000,
    TargetSelection_MaxAngle     = 6.28,
    TargetSelection_CheckWalls   = false,
    TargetSelection_VisibleOnly  = false,

    Magnetism_Enabled            = true,
    Magnetism_MaxDistance        = 10000,
    Magnetism_PullStrength       = 80.0,   -- was 25.0 — 3x harder snap
    Magnetism_StopThreshold      = 0,
    Magnetism_MaxAngleHorizontal = 6.28,
    Magnetism_MaxAngleVertical   = 6.28,

    Friction_Enabled             = true,
    Friction_BubbleRadius        = 250.0,  -- was 120.0 — much wider sticky zone
    Friction_MinSensitivity      = 0.000001, -- near-zero = snappiest possible

    RecoilAssist_Enabled         = true,
    RecoilAssist_ReductionAmount = 1.0,
}

local function SaveOriginalVelocity(v)
    -- TargetSelection
    OrigVelocity.TS_MaxDistance  = v.TargetSelection.MaxDistance
    OrigVelocity.TS_MaxAngle     = v.TargetSelection.MaxAngle
    if v.TargetSelection.CheckWalls  ~= nil then OrigVelocity.TS_CheckWalls  = v.TargetSelection.CheckWalls  end
    if v.TargetSelection.VisibleOnly ~= nil then OrigVelocity.TS_VisibleOnly = v.TargetSelection.VisibleOnly end
    -- Magnetism
    OrigVelocity.Mag_Enabled     = v.Magnetism.Enabled
    OrigVelocity.Mag_MaxDist     = v.Magnetism.MaxDistance
    OrigVelocity.Mag_Pull        = v.Magnetism.PullStrength
    OrigVelocity.Mag_Stop        = v.Magnetism.StopThreshold
    OrigVelocity.Mag_AngleH      = v.Magnetism.MaxAngleHorizontal
    OrigVelocity.Mag_AngleV      = v.Magnetism.MaxAngleVertical
    -- Friction
    OrigVelocity.Fri_Enabled     = v.Friction.Enabled
    OrigVelocity.Fri_Radius      = v.Friction.BubbleRadius
    OrigVelocity.Fri_MinSens     = v.Friction.MinSensitivity
    -- Recoil
    OrigVelocity.RC_Enabled      = v.RecoilAssist.Enabled
    OrigVelocity.RC_Amount       = v.RecoilAssist.ReductionAmount
end

local function ApplyVelocityBoost(v)
    v.TargetSelection.MaxDistance = VELOCITY_BOOST.TargetSelection_MaxDistance
    v.TargetSelection.MaxAngle    = VELOCITY_BOOST.TargetSelection_MaxAngle
    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = VELOCITY_BOOST.TargetSelection_CheckWalls  end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = VELOCITY_BOOST.TargetSelection_VisibleOnly end

    v.Magnetism.Enabled            = VELOCITY_BOOST.Magnetism_Enabled
    v.Magnetism.MaxDistance        = VELOCITY_BOOST.Magnetism_MaxDistance
    v.Magnetism.PullStrength       = VELOCITY_BOOST.Magnetism_PullStrength
    v.Magnetism.StopThreshold      = VELOCITY_BOOST.Magnetism_StopThreshold
    v.Magnetism.MaxAngleHorizontal = VELOCITY_BOOST.Magnetism_MaxAngleHorizontal
    v.Magnetism.MaxAngleVertical   = VELOCITY_BOOST.Magnetism_MaxAngleVertical

    v.Friction.Enabled             = VELOCITY_BOOST.Friction_Enabled
    v.Friction.BubbleRadius        = VELOCITY_BOOST.Friction_BubbleRadius
    v.Friction.MinSensitivity      = VELOCITY_BOOST.Friction_MinSensitivity

    v.RecoilAssist.Enabled         = VELOCITY_BOOST.RecoilAssist_Enabled
    v.RecoilAssist.ReductionAmount = VELOCITY_BOOST.RecoilAssist_ReductionAmount
end

local function RestoreVelocityOriginals(v)
    v.TargetSelection.MaxDistance = OrigVelocity.TS_MaxDistance
    v.TargetSelection.MaxAngle    = OrigVelocity.TS_MaxAngle
    if OrigVelocity.TS_CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = OrigVelocity.TS_CheckWalls  end
    if OrigVelocity.TS_VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = OrigVelocity.TS_VisibleOnly end

    v.Magnetism.Enabled            = OrigVelocity.Mag_Enabled
    v.Magnetism.MaxDistance        = OrigVelocity.Mag_MaxDist
    v.Magnetism.PullStrength       = OrigVelocity.Mag_Pull
    v.Magnetism.StopThreshold      = OrigVelocity.Mag_Stop
    v.Magnetism.MaxAngleHorizontal = OrigVelocity.Mag_AngleH
    v.Magnetism.MaxAngleVertical   = OrigVelocity.Mag_AngleV

    v.Friction.Enabled             = OrigVelocity.Fri_Enabled
    v.Friction.BubbleRadius        = OrigVelocity.Fri_Radius
    v.Friction.MinSensitivity      = OrigVelocity.Fri_MinSens

    v.RecoilAssist.Enabled         = OrigVelocity.RC_Enabled
    v.RecoilAssist.ReductionAmount = OrigVelocity.RC_Amount
end

-- Main toggle function called by the button.
local function ToggleVelocity()
    -- If we already have the table ref, just flip values — no gc scan.
    if VelocityTableRef then
        if Config.VelocityActive then
            ProtectExecution(function() RestoreVelocityOriginals(VelocityTableRef) end)
            Config.VelocityActive = false
        else
            ProtectExecution(function() ApplyVelocityBoost(VelocityTableRef) end)
            Config.VelocityActive = true
        end
        return Config.VelocityActive
    end

    -- First time: scan gc to find the table, save originals, then apply.
    local found        = false
    local hookedSmoke  = false

    ProtectExecution(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]

            if type(v) == "table" and not found then
                if rawget(v, "TargetSelection")
                and rawget(v, "Magnetism")
                and rawget(v, "RecoilAssist")
                and rawget(v, "Friction") then
                    SaveOriginalVelocity(v)
                    ApplyVelocityBoost(v)
                    VelocityTableRef      = v
                    Config.VelocityActive = true
                    found = true
                end

            elseif type(v) == "function" and not hookedSmoke then
                if debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                    hookfunction(v, function() return false end)
                    hookedSmoke = true
                end
            end

            if found and hookedSmoke then break end
        end
    end)

    return Config.VelocityActive
end

-- =========================================================================
-- 5. AUTOFIRE BOOST — TRUE TOGGLE
--    Same pattern: first press scans gc and saves originals.
--    Subsequent presses use the cached ref to flip instantly.
-- =========================================================================
local AUTOFIRE_BOOST = {
    TriggerEnabled  = true,
    AutoFireEnabled = true,
    Sensitivity     = 1.0,
    ReactionTime    = 0.0,
    FireDelay       = 0.0,
    TriggerDelay    = 0.0,
    AutoFireDelay   = 0.0,
    ShootDelay      = 0.0,
    TriggerAngle    = 6.28,
    TriggerDistance = 10000,
    DetectionRadius = 10000,
}

local AUTOFIRE_ORIGINAL_DEFAULTS = {
    Sensitivity     = 0.5,
    ReactionTime    = 0.15,
    FireDelay       = 0.1,
    TriggerDelay    = 0.1,
    AutoFireDelay   = 0.1,
    ShootDelay      = 0.1,
    TriggerAngle    = 1.0,
    TriggerDistance = 300,
    DetectionRadius = 300,
    TriggerEnabled  = false,
    AutoFireEnabled = false,
}

local function SaveOriginalAutoFire(v)
    for field, default in pairs(AUTOFIRE_ORIGINAL_DEFAULTS) do
        if rawget(v, field) ~= nil then
            OrigAutoFire[field] = v[field]
        end
    end
end

local function ApplyAutoFireBoost(v)
    for field, val in pairs(AUTOFIRE_BOOST) do
        if rawget(v, field) ~= nil then
            -- Handle the AutoFire boolean field separately.
            if field == "AutoFire" and type(v[field]) ~= "boolean" then continue end
            v[field] = val
        end
    end
end

local function RestoreAutoFireOriginals(v)
    for field, val in pairs(OrigAutoFire) do
        if rawget(v, field) ~= nil then
            v[field] = val
        end
    end
    -- Explicitly disable the trigger system on restore.
    if rawget(v, "TriggerEnabled")  ~= nil then v.TriggerEnabled  = false end
    if rawget(v, "AutoFireEnabled") ~= nil then v.AutoFireEnabled = false end
end

local function ToggleAutoFireBoost()
    -- Fast path: table already found.
    if AutoFireTableRef then
        if Config.AutoFireActive then
            ProtectExecution(function() RestoreAutoFireOriginals(AutoFireTableRef) end)
            Config.AutoFireActive = false
        else
            ProtectExecution(function() ApplyAutoFireBoost(AutoFireTableRef) end)
            Config.AutoFireActive = true
        end
        return Config.AutoFireActive
    end

    -- First time: scan gc.
    local found = false
    ProtectExecution(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]
            if type(v) == "table" then
                local hasAutoFireField =
                    rawget(v, "Sensitivity")    ~= nil or
                    rawget(v, "ReactionTime")   ~= nil or
                    rawget(v, "FireDelay")      ~= nil or
                    rawget(v, "TriggerDelay")   ~= nil or
                    rawget(v, "AutoFireDelay")  ~= nil or
                    rawget(v, "ShootDelay")     ~= nil or
                    rawget(v, "TriggerEnabled") ~= nil

                local isAutoFireTable =
                    rawget(v, "TriggerEnabled")  ~= nil or
                    rawget(v, "AutoFireEnabled") ~= nil or
                    rawget(v, "FireMode")        ~= nil or
                    rawget(v, "AutoFire")        ~= nil

                if hasAutoFireField and isAutoFireTable then
                    SaveOriginalAutoFire(v)
                    ApplyAutoFireBoost(v)
                    AutoFireTableRef      = v
                    Config.AutoFireActive = true
                    found = true
                    break
                end
            end
        end
    end)

    return Config.AutoFireActive
end

-- =========================================================================
-- 6. ESP — PROXIMITY-CAPPED, PLAYER-COUNT-AWARE HIGHLIGHTS
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

local function HookCharacterRemoving(player)
    if CharRemovedConns[player] then CharRemovedConns[player]:Disconnect() end
    CharRemovedConns[player] = player.CharacterRemoving:Connect(function()
        RemoveHighlight(player)
    end)
end

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

task.spawn(function()
    while true do
        local playerCount = 0
        for _ in pairs(PlayerCache) do playerCount = playerCount + 1 end
        local interval = math.clamp(0.10 + (playerCount * 0.004), 0.10, 0.35)
        task.wait(interval)

        if not Config.ESP_Enabled then
            for player in pairs(Highlights) do RemoveHighlight(player) end
        else
            local candidates = {}
            for player in pairs(PlayerCache) do
                if IsEnemy(player) and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart") then
                    candidates[#candidates + 1] = { player = player, dist = GetDistanceTo(player) }
                end
            end
            table.sort(candidates, function(a, b) return a.dist < b.dist end)

            local shouldHighlight = {}
            local cap = math.min(#candidates, MAX_HIGHLIGHTS)
            for i = 1, cap do shouldHighlight[candidates[i].player] = true end

            for player in pairs(Highlights) do
                if not shouldHighlight[player] then RemoveHighlight(player) end
            end

            for player in pairs(shouldHighlight) do
                local char     = player.Character
                local existing = Highlights[player]
                if existing and existing.Parent == char then
                    -- Valid, skip.
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
ScreenGui.Parent = gethui and gethui() or CoreGui

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
Title.Size                   = UDim2.new(0.7, 0, 1, 0)
Title.Position               = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text                   = "VELOCITY MAX"
Title.TextColor3             = Color3.fromRGB(255, 255, 255)
Title.Font                   = Enum.Font.SourceSansBold
Title.TextSize               = 16
Title.TextXAlignment         = Enum.TextXAlignment.Left
Title.Parent                 = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size             = UDim2.new(0, 30, 0, 30)
MinBtn.Position         = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text             = "_"
MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
MinBtn.Font             = Enum.Font.SourceSansBold
MinBtn.TextSize         = 20
MinBtn.Parent           = TitleBar

-- ---- Icon drag ----
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
--    Two button types:
--      Btn()        — simple toggle: func() returns the new boolean state.
--      ActionBtn()  — injection toggle: tracks its own ON/OFF state correctly
--                     and updates label/color based on Config flag, not raw return.
-- =========================================================================
local Content = Instance.new("Frame")
Content.Size                = UDim2.new(1, 0, 1, -30)
Content.Position            = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent              = MainFrame

local COLOR_ON  = Color3.fromRGB(0, 150, 0)
local COLOR_OFF = Color3.fromRGB(45, 45, 45)
local COLOR_ACT = Color3.fromRGB(200, 50, 0)  -- "injector" idle color

-- Simple toggle button (ESP) — func() returns new boolean state.
local function Btn(name, order, startState, func)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.Position         = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = startState and COLOR_ON or COLOR_OFF
    b.Text             = name .. ": " .. (startState and "ON" or "OFF")
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.SourceSansBold
    b.TextSize         = 14
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        local state = func()
        b.Text             = name .. ": " .. (state and "ON" or "OFF")
        b.BackgroundColor3 = state and COLOR_ON or COLOR_OFF
    end)
    return b
end

-- Injection toggle button (Velocity, AutoFire).
-- Reads Config flag AFTER func() so the display is always accurate.
local function InjectionBtn(name, order, configKey, func)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.Position         = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = COLOR_ACT
    b.Text             = name .. ": OFF"
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.SourceSansBold
    b.TextSize         = 14
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        func()  -- run the toggle (modifies Config[configKey] internally)
        local state = Config[configKey]
        b.Text             = name .. ": " .. (state and "ON" or "OFF")
        b.BackgroundColor3 = state and COLOR_ON or COLOR_ACT
    end)
    return b
end

-- Button 1: Full Body ESP (simple toggle, starts ON)
local EspBtn = Btn("Full Body ESP", 0, true, function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    return Config.ESP_Enabled
end)

-- Button 2: Boost AutoFire (injection toggle, starts OFF)
local _FireBtn = InjectionBtn("Boost AutoFire", 1, "AutoFireActive", ToggleAutoFireBoost)

-- Button 3: Inject Max Velocity (injection toggle, starts OFF)
local _VelBtn  = InjectionBtn("Max Velocity", 2, "VelocityActive", ToggleVelocity)

print("[Bloxstrike] v4 Loaded — True Toggles + Aggressive Aim Active")
