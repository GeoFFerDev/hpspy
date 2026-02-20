-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5.3
-- Features: Ultra-Fast Aggressive Snap, Wide Active Zone, Wall Bypass,
--           Native AutoFire Boost, Player-Count FPS Fix, Reliable Button Toggles.
-- v5.3 Fix:
--   • Restored Minimize Button and complete UI from v5.1.
--   • FIXED AIM: Disabled "Friction" (which caused the camera to get stuck in the surroundings).
--   • SAFE HEAD AIM: Tries to safely force "Head" targeting without crashing the gun script.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- CONFIG
-- =========================================================================
local Config = {
    ESP_Enabled = true,
    Enemy_Color = Color3.fromRGB(255, 0, 0),
}

local MAX_HIGHLIGHTS = 10

-- =========================================================================
-- STATE
-- =========================================================================
local Highlights       = {}
local PlayerCache      = {}
local CharRemovedConns = {}

-- Cached gc table references (found once on first press, reused forever).
local VelocityRef  = nil
local AutoFireRef  = nil

-- =========================================================================
-- 1. TEAM CHECK
-- =========================================================================
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam    = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team")    or "Nil")
    return myTeam ~= theirTeam
end

-- =========================================================================
-- 2. DISTANCE HELPER
-- =========================================================================
local function GetDistanceTo(player)
    local myChar    = LocalPlayer.Character
    local theirChar = player.Character
    if not myChar or not theirChar then return math.huge end
    local r1 = myChar:FindFirstChild("HumanoidRootPart")
    local r2 = theirChar:FindFirstChild("HumanoidRootPart")
    if not r1 or not r2 then return math.huge end
    return (r1.Position - r2.Position).Magnitude
end

-- =========================================================================
-- 3. GC SCANNER — finds and caches the config table, returns it or nil
-- =========================================================================
local function FindVelocityTable()
    if VelocityRef then return VelocityRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table"
        and rawget(v, "TargetSelection")
        and rawget(v, "Magnetism")
        and rawget(v, "RecoilAssist")
        and rawget(v, "Friction") then
            VelocityRef = v
            return v
        end
    end
    return nil
end

-- All known field name variants across Bloxstrike versions
local AF_ENABLE_FIELDS = {
    "TriggerEnabled", "AutoFireEnabled", "AutoFire", "FireMode",
    "triggerEnabled", "autoFireEnabled", "autoFire", "fireMode",
    "Autofire", "Trigger", "AutoShoot", "autoShoot",
    "EnableAutoFire", "enableAutoFire", "Enable",
}
local AF_DELAY_FIELDS = {
    "Sensitivity", "ReactionTime", "FireDelay", "TriggerDelay",
    "AutoFireDelay", "ShootDelay", "DelayBetweenShots", "ShotDelay",
    "sensitivity", "reactionTime", "fireDelay", "triggerDelay",
    "autoFireDelay", "shootDelay", "delayBetweenShots", "shotDelay",
    "Delay", "delay", "Rate", "rate", "Interval", "interval",
}
local AF_RANGE_FIELDS = {
    "TriggerAngle", "TriggerDistance", "DetectionRadius", "AimAngle",
    "triggerAngle", "triggerDistance", "detectionRadius", "aimAngle",
    "Range", "range", "Radius", "radius", "Angle", "angle",
    "MaxAngle", "maxAngle", "Distance", "distance",
}

local function TableHasAny(t, fields)
    for _, f in ipairs(fields) do
        if rawget(t, f) ~= nil then return true, f end
    end
    return false
end

local function FindAutoFireTable()
    if AutoFireRef then return AutoFireRef end

    if VelocityRef then
        for key, val in pairs(VelocityRef) do
            if type(val) == "table" then
                local hasEnable = TableHasAny(val, AF_ENABLE_FIELDS)
                local hasDelay  = TableHasAny(val, AF_DELAY_FIELDS)
                if hasEnable or hasDelay then
                    AutoFireRef = val
                    return val
                end
            end
        end
    end

    local gc = getgc(true)

    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            local hasEnable = TableHasAny(v, AF_ENABLE_FIELDS)
            local hasDelay  = TableHasAny(v, AF_DELAY_FIELDS)
            if hasEnable and hasDelay then
                AutoFireRef = v
                return v
            end
        end
    end

    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            local hasEnable = TableHasAny(v, AF_ENABLE_FIELDS)
            if hasEnable then
                AutoFireRef = v
                return v
            end
            local count = 0
            for _, f in ipairs(AF_DELAY_FIELDS) do
                if rawget(v, f) ~= nil then count = count + 1 end
                if count >= 2 then
                    AutoFireRef = v
                    return v
                end
            end
        end
    end

    if VelocityRef then
        local hasAny = TableHasAny(VelocityRef, AF_ENABLE_FIELDS)
            or TableHasAny(VelocityRef, AF_DELAY_FIELDS)
        if hasAny then
            AutoFireRef = VelocityRef
            return VelocityRef
        end
    end

    return nil
end

local smokeHooked = false
local function HookSmoke()
    if smokeHooked then return end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
            hookfunction(v, function() return false end)
            smokeHooked = true
            break
        end
    end
end

-- =========================================================================
-- 4. VELOCITY INJECTION — ON values (aggressive) and OFF values (neutral)
-- =========================================================================
local function ApplyVelocityON(v)
    -- TARGETING
    v.TargetSelection.MaxDistance = 10000
    v.TargetSelection.MaxAngle    = 6.28
    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = false end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end
    
    -- FORCE HEAD TARGETING (Safe Check)
    if rawget(v.TargetSelection, "TargetPart") ~= nil then v.TargetSelection.TargetPart = "Head" end
    if rawget(v.TargetSelection, "TargetBone") ~= nil then v.TargetSelection.TargetBone = "Head" end
    if rawget(v.TargetSelection, "Bone") ~= nil then v.TargetSelection.Bone = "Head" end

    -- MAGNETISM — The Pull
    v.Magnetism.Enabled            = true
    v.Magnetism.MaxDistance        = 10000
    v.Magnetism.PullStrength       = 40.0   -- Fast enough to snap instantly, safe enough to not break math
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28
    
    -- FRICTION — THE FIX
    -- Turning this OFF prevents the camera from getting "stuck" in the surroundings.
    v.Friction.Enabled             = false  
    v.Friction.BubbleRadius        = 0      
    v.Friction.MinSensitivity      = 1.0    -- 1.0 = No slowdown

    -- RECOIL — Full suppression
    v.RecoilAssist.Enabled         = true
    v.RecoilAssist.ReductionAmount = 1.0
end

local function ApplyVelocityOFF(v)
    v.Magnetism.PullStrength       = 1.0
    v.Magnetism.MaxDistance        = 300
    v.Magnetism.MaxAngleHorizontal = 0.5
    v.Magnetism.MaxAngleVertical   = 0.5
    
    -- Restore Friction to safe defaults
    v.Friction.Enabled             = true
    v.Friction.BubbleRadius        = 5.0
    v.Friction.MinSensitivity      = 1.0
    
    v.RecoilAssist.ReductionAmount = 0.0
end

-- =========================================================================
-- 5. AUTOFIRE INJECTION — ON and OFF
-- =========================================================================
local function ApplyAutoFireON(v)
    for _, f in ipairs(AF_ENABLE_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "boolean" then v[f] = true end
    end
    for _, f in ipairs(AF_DELAY_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "number" then
            v[f] = (f == "Sensitivity" or f == "sensitivity") and 1.0 or 0.0
        end
    end
    for _, f in ipairs(AF_RANGE_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "number" then
            v[f] = (string.find(string.lower(f), "angle") and 6.28) or 10000
        end
    end
end

local function ApplyAutoFireOFF(v)
    for _, f in ipairs(AF_ENABLE_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "boolean" then v[f] = false end
    end
    for _, f in ipairs(AF_DELAY_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "number" then
            v[f] = (f == "Sensitivity" or f == "sensitivity") and 0.5 or 0.1
        end
    end
    for _, f in ipairs(AF_RANGE_FIELDS) do
        local cur = rawget(v, f)
        if type(cur) == "number" then
            v[f] = (string.find(string.lower(f), "angle") and 1.0) or 300
        end
    end
end

-- =========================================================================
-- 6. ESP
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

local function HookCharRemoving(player)
    if CharRemovedConns[player] then CharRemovedConns[player]:Disconnect() end
    CharRemovedConns[player] = player.CharacterRemoving:Connect(function()
        RemoveHighlight(player)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then PlayerCache[p] = true; HookCharRemoving(p) end
end

Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then PlayerCache[p] = true; HookCharRemoving(p) end
end)

Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil
    RemoveHighlight(p)
    if CharRemovedConns[p] then CharRemovedConns[p]:Disconnect(); CharRemovedConns[p] = nil end
end)

task.spawn(function()
    while true do
        local count = 0
        for _ in pairs(PlayerCache) do count = count + 1 end
        task.wait(math.clamp(0.10 + count * 0.004, 0.10, 0.35))

        if not Config.ESP_Enabled then
            for player in pairs(Highlights) do RemoveHighlight(player) end
        else
            local candidates = {}
            for player in pairs(PlayerCache) do
                if IsEnemy(player) and player.Character
                and player.Character:FindFirstChild("HumanoidRootPart") then
                    candidates[#candidates + 1] = { p = player, d = GetDistanceTo(player) }
                end
            end
            table.sort(candidates, function(a, b) return a.d < b.d end)

            local active = {}
            for i = 1, math.min(#candidates, MAX_HIGHLIGHTS) do
                active[candidates[i].p] = true
            end

            for player in pairs(Highlights) do
                if not active[player] then RemoveHighlight(player) end
            end

            for player in pairs(active) do
                local char = player.Character
                local hl   = Highlights[player]
                if not (hl and hl.Parent == char) then
                    if hl then hl:Destroy() end
                    Highlights[player] = CreateHighlight(char)
                end
            end
        end
    end
end)

-- =========================================================================
-- 7. UI (RESTORED EXACTLY FROM v5.1)
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = (gethui and gethui()) or CoreGui

-- Minimized icon
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

-- Main window
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

-- Icon drag
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
-- 8. BUTTON BUILDER
-- =========================================================================
local Content = Instance.new("Frame")
Content.Size                = UDim2.new(1, 0, 1, -30)
Content.Position            = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent              = MainFrame

local COLOR_ON   = Color3.fromRGB(0, 150, 0)
local COLOR_OFF  = Color3.fromRGB(45, 45, 45)
local COLOR_IDLE = Color3.fromRGB(180, 60, 0)

local function MakeButton(label, order, startColor)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.Position         = UDim2.new(0.05, 0, 0, 10 + order * 40)
    b.BackgroundColor3 = startColor or COLOR_OFF
    b.Text             = label .. ": OFF"
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.SourceSansBold
    b.TextSize         = 14
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- ---- ESP Button ---- 
local EspBtn = MakeButton("Full Body ESP", 0, COLOR_ON)
EspBtn.Text = "Full Body ESP: ON"
EspBtn.MouseButton1Click:Connect(function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    EspBtn.Text             = "Full Body ESP: " .. (Config.ESP_Enabled and "ON" or "OFF")
    EspBtn.BackgroundColor3 = Config.ESP_Enabled and COLOR_ON or COLOR_OFF
end)

-- ---- Boost AutoFire Button ---- 
local FireBtn = MakeButton("Boost AutoFire", 1, COLOR_IDLE)
local fireActive = false

FireBtn.MouseButton1Click:Connect(function()
    fireActive = not fireActive
    local t = FindAutoFireTable()

    if t then
        if fireActive then
            pcall(ApplyAutoFireON, t)
            print("[Bloxstrike] AutoFire BOOST ON")
        else
            pcall(ApplyAutoFireOFF, t)
            print("[Bloxstrike] AutoFire BOOST OFF")
        end
    else
        warn("[Bloxstrike] AutoFire table not found in gc.")
    end

    FireBtn.Text             = "Boost AutoFire: " .. (fireActive and "ON" or "OFF")
    FireBtn.BackgroundColor3 = fireActive and COLOR_ON or COLOR_IDLE
end)

-- ---- Max Velocity Button ---- 
local VelBtn = MakeButton("Max Velocity", 2, COLOR_IDLE)
local velActive = false

VelBtn.MouseButton1Click:Connect(function()
    velActive = not velActive
    local t = FindVelocityTable()
    if t then
        if velActive then
            pcall(ApplyVelocityON, t)
            task.defer(HookSmoke)
        else
            pcall(ApplyVelocityOFF, t)
        end
    else
        velActive = not velActive
        warn("[Bloxstrike] Velocity table not found in gc.")
    end

    VelBtn.Text             = "Max Velocity: " .. (velActive and "ON" or "OFF")
    VelBtn.BackgroundColor3 = velActive and COLOR_ON or COLOR_IDLE
end)

print("[Bloxstrike] v5.3 Loaded — Restored UI & Fixed Surrounding Stickiness")
