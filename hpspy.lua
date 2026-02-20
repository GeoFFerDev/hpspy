-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5.2
-- v5.2 Fix:
--   • Forced Headshot Bone targeting.
--   • Snap speed increased (PullStrength 80 -> 150).
--   • Forced full-screen FOV for instant acquisition.

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- CONFIG & STATE
-- =========================================================================
local Config = {
    ESP_Enabled = true,
    Enemy_Color = Color3.fromRGB(255, 0, 0),
}
local MAX_HIGHLIGHTS = 10
local Highlights, PlayerCache, CharRemovedConns = {}, {}, {}
local VelocityRef, AutoFireRef = nil, nil

-- =========================================================================
-- 1. HELPERS
-- =========================================================================
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

local function GetDistanceTo(player)
    local myChar = LocalPlayer.Character
    local theirChar = player.Character
    if not myChar or not theirChar then return math.huge end
    local r1, r2 = myChar:FindFirstChild("HumanoidRootPart"), theirChar:FindFirstChild("HumanoidRootPart")
    if not r1 or not r2 then return math.huge end
    return (r1.Position - r2.Position).Magnitude
end

-- =========================================================================
-- 2. GC SCANNER
-- =========================================================================
local function FindVelocityTable()
    if VelocityRef then return VelocityRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and rawget(v, "TargetSelection") and rawget(v, "Magnetism") and rawget(v, "RecoilAssist") and rawget(v, "Friction") then
            VelocityRef = v
            return v
        end
    end
    return nil
end

local AF_ENABLE_FIELDS = {"TriggerEnabled", "AutoFireEnabled", "AutoFire", "FireMode", "Autofire", "Trigger", "AutoShoot", "EnableAutoFire", "Enable"}
local AF_DELAY_FIELDS = {"Sensitivity", "ReactionTime", "FireDelay", "TriggerDelay", "AutoFireDelay", "ShootDelay", "DelayBetweenShots", "ShotDelay", "Delay", "Rate", "Interval"}
local AF_RANGE_FIELDS = {"TriggerAngle", "TriggerDistance", "DetectionRadius", "AimAngle", "Range", "Radius", "Angle", "MaxAngle", "Distance"}

local function TableHasAny(t, fields)
    for _, f in ipairs(fields) do if rawget(t, f) ~= nil then return true, f end end
    return false
end

local function FindAutoFireTable()
    if AutoFireRef then return AutoFireRef end
    if VelocityRef then
        for key, val in pairs(VelocityRef) do
            if type(val) == "table" and (TableHasAny(val, AF_ENABLE_FIELDS) or TableHasAny(val, AF_DELAY_FIELDS)) then
                AutoFireRef = val; return val
            end
        end
    end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            if TableHasAny(v, AF_ENABLE_FIELDS) and TableHasAny(v, AF_DELAY_FIELDS) then AutoFireRef = v; return v end
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
            smokeHooked = true; break
        end
    end
end

-- =========================================================================
-- 3. INJECTION LOGIC (TUNED FOR ACCURACY & SPEED)
-- =========================================================================
local function ApplyVelocityON(v)
    -- [TARGET SELECTION] - Forced Head Targeting 
    v.TargetSelection.MaxDistance = 10000
    v.TargetSelection.MaxAngle = 6.28
    v.TargetSelection.TargetPart = "Head" -- Force aim at Head
    v.TargetSelection.PreferredPart = "Head"
    if v.TargetSelection.CheckWalls ~= nil then v.TargetSelection.CheckWalls = false end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end

    -- [MAGNETISM] - Forced Snap Speed 
    v.Magnetism.Enabled = true
    v.Magnetism.MaxDistance = 10000
    v.Magnetism.PullStrength = 150.0 -- Drastically increased for instant snap 
    v.Magnetism.StopThreshold = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical = 6.28

    -- [FRICTION] - Absolute Hard-Lock 
    v.Friction.Enabled = true
    v.Friction.BubbleRadius = 300.0 -- Wide acquisition zone
    v.Friction.MinSensitivity = 0.000000001 -- No slack 

    -- [RECOIL]
    v.RecoilAssist.Enabled = true
    v.RecoilAssist.ReductionAmount = 1.0
end

local function ApplyVelocityOFF(v)
    v.Magnetism.PullStrength = 1.0
    v.Magnetism.MaxDistance = 300
    v.Magnetism.MaxAngleHorizontal = 0.5
    v.Magnetism.MaxAngleVertical = 0.5
    v.Friction.BubbleRadius = 5.0
    v.Friction.MinSensitivity = 1.0
    v.RecoilAssist.ReductionAmount = 0.0
end

local function ApplyAutoFireON(v)
    for _, f in ipairs(AF_ENABLE_FIELDS) do if type(rawget(v, f)) == "boolean" then v[f] = true end end
    for _, f in ipairs(AF_DELAY_FIELDS) do if type(rawget(v, f)) == "number" then v[f] = (f:lower():find("sens")) and 1.0 or 0.0 end end
    for _, f in ipairs(AF_RANGE_FIELDS) do if type(rawget(v, f)) == "number" then v[f] = (f:lower():find("angle")) and 6.28 or 10000 end end
end

local function ApplyAutoFireOFF(v)
    for _, f in ipairs(AF_ENABLE_FIELDS) do if type(rawget(v, f)) == "boolean" then v[f] = false end end
    for _, f in ipairs(AF_DELAY_FIELDS) do if type(rawget(v, f)) == "number" then v[f] = 0.1 end end
end

-- =========================================================================
-- 4. ESP SYSTEM
-- =========================================================================
local function RemoveHighlight(player) if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end end
local function CreateHighlight(char)
    local hl = Instance.new("Highlight")
    hl.FillTransparency, hl.OutlineTransparency, hl.DepthMode = 0.5, 0, Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor, hl.OutlineColor, hl.Parent = Config.Enemy_Color, Config.Enemy_Color, char
    return hl
end

task.spawn(function()
    while true do
        local count = 0; for _ in pairs(PlayerCache) do count = count + 1 end
        task.wait(math.clamp(0.10 + count * 0.004, 0.10, 0.35))
        if not Config.ESP_Enabled then for p in pairs(Highlights) do RemoveHighlight(p) end else
            local candidates = {}
            for p in pairs(PlayerCache) do if IsEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then table.insert(candidates, {p=p, d=GetDistanceTo(p)}) end end
            table.sort(candidates, function(a,b) return a.d < b.d end)
            local active = {}; for i=1, math.min(#candidates, MAX_HIGHLIGHTS) do active[candidates[i].p] = true end
            for p in pairs(Highlights) do if not active[p] then RemoveHighlight(p) end end
            for p in pairs(active) do if not (Highlights[p] and Highlights[p].Parent == p.Character) then if Highlights[p] then Highlights[p]:Destroy() end Highlights[p] = CreateHighlight(p.Character) end end
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then PlayerCache[p] = true end end
Players.PlayerAdded:Connect(function(p) if p ~= LocalPlayer then PlayerCache[p] = true end end)
Players.PlayerRemoving:Connect(function(p) PlayerCache[p] = nil; RemoveHighlight(p) end)

-- =========================================================================
-- 5. UI SYSTEM
-- =========================================================================
local ScreenGui = Instance.new("ScreenGui"); ScreenGui.ResetOnSpawn, ScreenGui.Parent = false, (gethui and gethui()) or CoreGui
local MainFrame = Instance.new("Frame"); MainFrame.Size, MainFrame.Position, MainFrame.BackgroundColor3, MainFrame.Active, MainFrame.Draggable, MainFrame.Parent = UDim2.new(0, 220, 0, 220), UDim2.new(0.1, 0, 0.2, 0), Color3.fromRGB(25, 25, 25), true, true, ScreenGui
local TitleBar = Instance.new("Frame"); TitleBar.Size, TitleBar.BackgroundColor3, TitleBar.Parent = UDim2.new(1, 0, 0, 30), Color3.fromRGB(15, 15, 15), MainFrame
local Title = Instance.new("TextLabel"); Title.Size, Title.Position, Title.Text, Title.TextColor3, Title.Font, Title.TextSize, Title.Parent = UDim2.new(1, 0, 1, 0), UDim2.new(0, 10, 0, 0), "VELOCITY MAX v5.2", Color3.fromRGB(255, 255, 255), Enum.Font.SourceSansBold, 16, TitleBar

local Content = Instance.new("Frame"); Content.Size, Content.Position, Content.BackgroundTransparency, Content.Parent = UDim2.new(1, 0, 1, -30), UDim2.new(0, 0, 0, 30), 1, MainFrame
local function MakeButton(label, order)
    local b = Instance.new("TextButton"); b.Size, b.Position, b.BackgroundColor3, b.Text, b.TextColor3, b.Font, b.TextSize, b.Parent = UDim2.new(0.9, 0, 0, 35), UDim2.new(0.05, 0, 0, 10 + order * 40), Color3.fromRGB(45, 45, 45), label .. ": OFF", Color3.fromRGB(255, 255, 255), Enum.Font.SourceSansBold, 14, Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6); return b
end

local EspBtn = MakeButton("Full Body ESP", 0); EspBtn.Text, EspBtn.BackgroundColor3 = "Full Body ESP: ON", Color3.fromRGB(0, 150, 0)
EspBtn.MouseButton1Click:Connect(function() Config.ESP_Enabled = not Config.ESP_Enabled; EspBtn.Text = "Full Body ESP: " .. (Config.ESP_Enabled and "ON" or "OFF"); EspBtn.BackgroundColor3 = Config.ESP_Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45) end)

local fireActive = false
local FireBtn = MakeButton("Boost AutoFire", 1)
FireBtn.MouseButton1Click:Connect(function()
    fireActive = not fireActive; local t = FindAutoFireTable()
    if t then if fireActive then pcall(ApplyAutoFireON, t) else pcall(ApplyAutoFireOFF, t) end end
    FireBtn.Text, FireBtn.BackgroundColor3 = "Boost AutoFire: " .. (fireActive and "ON" or "OFF"), fireActive and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
end)

local velActive = false
local VelBtn = MakeButton("Max Velocity", 2)
VelBtn.MouseButton1Click:Connect(function()
    velActive = not velActive; local t = FindVelocityTable()
    if t then if velActive then pcall(ApplyVelocityON, t) pcall(HookSmoke) else pcall(ApplyVelocityOFF, t) end end
    VelBtn.Text, VelBtn.BackgroundColor3 = "Max Velocity: " .. (velActive and "ON" or "OFF"), velActive and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
end)

print("[Bloxstrike] v5.2 Loaded — Forced Headshot snap enabled")
