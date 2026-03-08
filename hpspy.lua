-- BLOXSTRIKE VELOCITY SUITE — v5.8  (Fluent UI)
-- Features:
--   • Full Body ESP       — proximity-sorted highlights, 10 max, dynamic FPS scaling
--   • Boost AutoFire      — native gc injection, 4-pass broad field scan
--   • Max Velocity        — boosted aimbot (PullStrength 65, all-angle snap, head target,
--                           wall bypass, full recoil suppression)
--   • Zero Spread         — hooks applySpread or Bullet.Spread object via gc scan
--   • Infinite Ammo       — pins Rounds = Capacity on live weapon object at 20 Hz
--
-- UI renovated to Fluent UI template.
-- Speed Boost and Rapid Fire removed (bannable).

-- ─────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local StarterGui       = game:GetService("StarterGui")
local LocalPlayer      = Players.LocalPlayer
local player           = LocalPlayer

-- Force landscape on mobile
pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() player.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

-- GUI mount target
local guiTarget = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and CoreGui)
    or player:WaitForChild("PlayerGui")

-- Anti-overlap: destroy any previous instances
if guiTarget:FindFirstChild("UI_Load") then guiTarget.UI_Load:Destroy() end
if guiTarget:FindFirstChild("UI_Main")  then guiTarget.UI_Main:Destroy()  end

-- ═════════════════════════════════════════════════════════════
--  LOADING SCREEN
-- ═════════════════════════════════════════════════════════════
local loadGui = Instance.new("ScreenGui")
loadGui.Name           = "UI_Load"
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn   = false
loadGui.Parent         = guiTarget

local bg = Instance.new("Frame", loadGui)
bg.Size             = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(4, 5, 9)
bg.BorderSizePixel  = 0

local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 8, 14)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 0, 0)),
}
vig.Rotation = 45
vig.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,   0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1,   0.6),
}

local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size               = UDim2.new(1, 0, 0, 50)
titleLbl.Position           = UDim2.new(0, 0, 0.22, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text               = "VELOCITY MAX"
titleLbl.TextColor3         = Color3.fromRGB(0, 170, 120)
titleLbl.Font               = Enum.Font.GothamBlack
titleLbl.TextSize           = 38

local subLbl = Instance.new("TextLabel", bg)
subLbl.Size               = UDim2.new(1, 0, 0, 24)
subLbl.Position           = UDim2.new(0, 0, 0.36, 0)
subLbl.BackgroundTransparency = 1
subLbl.Text               = "BloxStrike Suite  ·  v5.8"
subLbl.TextColor3         = Color3.fromRGB(60, 130, 100)
subLbl.Font               = Enum.Font.GothamBold
subLbl.TextSize           = 14

-- Route dots
local routeY      = 0.50
local ROUTE_LABELS = {"🚦 START", "◆ GC SCAN", "◆ ESP INIT", "◆ BUILD UI", "🏁 READY"}
local routeDots   = {}

for i, label in ipairs(ROUTE_LABELS) do
    local xpct = (i - 1) / (#ROUTE_LABELS - 1) * 0.7 + 0.15
    if i > 1 then
        local prevX = (i - 2) / (#ROUTE_LABELS - 1) * 0.7 + 0.15
        local lf = Instance.new("Frame", bg)
        lf.Size             = UDim2.new(xpct - prevX, -4, 0, 2)
        lf.Position         = UDim2.new(prevX, 6, routeY, 4)
        lf.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
        lf.BorderSizePixel  = 0
        routeDots[i]      = routeDots[i] or {}
        routeDots[i].line = lf
    end
    local dot = Instance.new("Frame", bg)
    dot.Size             = UDim2.new(0, 10, 0, 10)
    dot.Position         = UDim2.new(xpct, -5, routeY, 0)
    dot.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 5)
    local lbl2 = Instance.new("TextLabel", bg)
    lbl2.Size               = UDim2.new(0, 80, 0, 16)
    lbl2.Position           = UDim2.new(xpct, -40, routeY, 14)
    lbl2.BackgroundTransparency = 1
    lbl2.Text               = label
    lbl2.TextColor3         = Color3.fromRGB(30, 55, 40)
    lbl2.Font               = Enum.Font.Code
    lbl2.TextSize           = 10
    routeDots[i]     = routeDots[i] or {}
    routeDots[i].dot = dot
    routeDots[i].lbl = lbl2
end

-- Progress bar
local barTrack = Instance.new("Frame", bg)
barTrack.Size             = UDim2.new(0.5, 0, 0, 5)
barTrack.Position         = UDim2.new(0.25, 0, 0.68, 0)
barTrack.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
barTrack.BorderSizePixel  = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
barFill.BorderSizePixel  = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size               = UDim2.new(1, 0, 0, 18)
barTxt.Position           = UDim2.new(0, 0, 0.72, 0)
barTxt.BackgroundTransparency = 1
barTxt.TextColor3         = Color3.fromRGB(40, 90, 65)
barTxt.Font               = Enum.Font.Code
barTxt.TextSize           = 12

-- Animated speed lines
local speedLines = {}
math.randomseed(42)
for i = 1, 12 do
    local ln = Instance.new("Frame", bg)
    local yp = math.random(10, 90) / 100
    local w  = math.random(60, 160) / 1000
    local xp = math.random(0, 80) / 100
    ln.Size             = UDim2.new(w, 0, 0, 1)
    ln.Position         = UDim2.new(xp, 0, yp, 0)
    ln.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
    ln.BorderSizePixel  = 0
    ln.BackgroundTransparency = 0.6 + math.random() * 0.3
    speedLines[i] = { frame = ln, speed = math.random(40, 120) / 100, x = xp, w = w }
end

local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.frame.Position = UDim2.new(sl.x, 0, sl.frame.Position.Y.Scale, 0)
    end
end)

-- Camera cinematic during load
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local CAM_ROUTE = {
    { CFrame.lookAt(Vector3.new(0, 75, 200),   Vector3.new(0, 0, 0)) },
    { CFrame.lookAt(Vector3.new(100, 40, 150), Vector3.new(0, 0, 0)) },
    { CFrame.lookAt(Vector3.new(-80, 55, 180), Vector3.new(0, 0, 0)) },
}
cam.CFrame = CAM_ROUTE[1][1]

local function SetProg(pct, msg, activeDot)
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(pct / 100, 0, 1, 0) }):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)
    local ci = math.max(1, math.min(#CAM_ROUTE, math.round(pct / 100 * #CAM_ROUTE + 0.5)))
    TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { CFrame = CAM_ROUTE[ci][1] }):Play()
    for i, d in ipairs(routeDots) do
        local on  = activeDot and i <= activeDot
        local col = on and Color3.fromRGB(0, 170, 120) or Color3.fromRGB(20, 40, 30)
        local tc  = on and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(30, 55, 40)
        if d.dot  then TweenService:Create(d.dot,  TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
        if d.lbl  then d.lbl.TextColor3 = tc end
        if d.line then TweenService:Create(d.line, TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
    end
end

-- ═════════════════════════════════════════════════════════════
--  HPSPY FEATURE LOGIC  (unchanged from v5.8)
-- ═════════════════════════════════════════════════════════════

-- ── CONFIG ───────────────────────────────────────────────────
local Config = {
    ESP_Enabled = true,
    Enemy_Color = Color3.fromRGB(255, 0, 0),
}
local MAX_HIGHLIGHTS = 10

-- ── STATE ────────────────────────────────────────────────────
local Highlights       = {}
local PlayerCache      = {}
local CharRemovedConns = {}
local VelocityRef      = nil
local AutoFireRef      = nil

SetProg(5, "Initialising...", 1) ; task.wait(0.2)

-- ── 1. TEAM CHECK ────────────────────────────────────────────
local function IsEnemy(p)
    if p == LocalPlayer then return false end
    local myTeam    = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(p:GetAttribute("Team")          or "Nil")
    return myTeam ~= theirTeam
end

-- ── 2. DISTANCE HELPER ───────────────────────────────────────
local function GetDistanceTo(p)
    local myChar    = LocalPlayer.Character
    local theirChar = p.Character
    if not myChar or not theirChar then return math.huge end
    local r1 = myChar:FindFirstChild("HumanoidRootPart")
    local r2 = theirChar:FindFirstChild("HumanoidRootPart")
    if not r1 or not r2 then return math.huge end
    return (r1.Position - r2.Position).Magnitude
end

-- ── 3. GC SCANNER ────────────────────────────────────────────
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
        for _, val in pairs(VelocityRef) do
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
            if TableHasAny(v, AF_ENABLE_FIELDS) and TableHasAny(v, AF_DELAY_FIELDS) then
                AutoFireRef = v ; return v
            end
        end
    end
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            if TableHasAny(v, AF_ENABLE_FIELDS) then AutoFireRef = v ; return v end
            local count = 0
            for _, f in ipairs(AF_DELAY_FIELDS) do
                if rawget(v, f) ~= nil then count = count + 1 end
                if count >= 2 then AutoFireRef = v ; return v end
            end
        end
    end
    if VelocityRef then
        if TableHasAny(VelocityRef, AF_ENABLE_FIELDS)
        or TableHasAny(VelocityRef, AF_DELAY_FIELDS) then
            AutoFireRef = VelocityRef ; return VelocityRef
        end
    end
    return nil
end

SetProg(30, "Scanning GC...", 2) ; task.wait(0.3)

-- ── 4. SMOKE BYPASS ──────────────────────────────────────────
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

-- ── 5. VELOCITY INJECTION ────────────────────────────────────
local function ApplyVelocityON(v)
    v.TargetSelection.MaxDistance = 10000
    v.TargetSelection.MaxAngle    = 6.28
    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = false end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end
    if rawget(v.TargetSelection, "TargetPart") ~= nil then v.TargetSelection.TargetPart = "Head" end
    if rawget(v.TargetSelection, "TargetBone") ~= nil then v.TargetSelection.TargetBone = "Head" end
    if rawget(v.TargetSelection, "Bone")       ~= nil then v.TargetSelection.Bone       = "Head" end
    v.Magnetism.Enabled            = true
    v.Magnetism.MaxDistance        = 10000
    v.Magnetism.PullStrength       = 65.0
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28
    v.Friction.Enabled             = false
    v.Friction.BubbleRadius        = 0
    v.Friction.MinSensitivity      = 1.0
    v.RecoilAssist.Enabled         = true
    v.RecoilAssist.ReductionAmount = 1.0
end

local function ApplyVelocityOFF(v)
    v.Magnetism.PullStrength       = 1.0
    v.Magnetism.MaxDistance        = 300
    v.Magnetism.MaxAngleHorizontal = 0.5
    v.Magnetism.MaxAngleVertical   = 0.5
    v.Friction.Enabled             = true
    v.Friction.BubbleRadius        = 5.0
    v.Friction.MinSensitivity      = 1.0
    v.RecoilAssist.ReductionAmount = 0.0
end

-- ── 6. AUTOFIRE INJECTION ────────────────────────────────────
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

-- ── 7. ESP ───────────────────────────────────────────────────
local function RemoveHighlight(p)
    if Highlights[p] then
        Highlights[p]:Destroy()
        Highlights[p] = nil
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

local function HookCharRemoving(p)
    if CharRemovedConns[p] then CharRemovedConns[p]:Disconnect() end
    CharRemovedConns[p] = p.CharacterRemoving:Connect(function()
        RemoveHighlight(p)
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then PlayerCache[p] = true ; HookCharRemoving(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then PlayerCache[p] = true ; HookCharRemoving(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil
    RemoveHighlight(p)
    if CharRemovedConns[p] then CharRemovedConns[p]:Disconnect() ; CharRemovedConns[p] = nil end
end)

task.spawn(function()
    while true do
        local count = 0
        for _ in pairs(PlayerCache) do count = count + 1 end
        task.wait(math.clamp(0.10 + count * 0.004, 0.10, 0.35))
        if not Config.ESP_Enabled then
            for p in pairs(Highlights) do RemoveHighlight(p) end
        else
            local candidates = {}
            for p in pairs(PlayerCache) do
                if IsEnemy(p) and p.Character
                and p.Character:FindFirstChild("HumanoidRootPart") then
                    candidates[#candidates + 1] = { p = p, d = GetDistanceTo(p) }
                end
            end
            table.sort(candidates, function(a, b) return a.d < b.d end)
            local active = {}
            for i = 1, math.min(#candidates, MAX_HIGHLIGHTS) do
                active[candidates[i].p] = true
            end
            for p in pairs(Highlights) do
                if not active[p] then RemoveHighlight(p) end
            end
            for p in pairs(active) do
                local char = p.Character
                local hl   = Highlights[p]
                if not (hl and hl.Parent == char) then
                    if hl then hl:Destroy() end
                    Highlights[p] = CreateHighlight(char)
                end
            end
        end
    end
end)

SetProg(60, "ESP initialised...", 3) ; task.wait(0.3)

-- ── 8. INFINITE AMMO (state) ─────────────────────────────────
local AMMO_PAIRS = {
    { "Rounds",        "Capacity"    },
    { "rounds",        "capacity"    },
    { "CurrentAmmo",   "MaxAmmo"     },
    { "currentAmmo",   "maxAmmo"     },
    { "Ammo",          "MaxAmmo"     },
    { "ammo",          "maxAmmo"     },
    { "CurrentRounds", "TotalRounds" },
}

local ammoActive = false
local ammoThread = nil

local function FindLiveWeaponTable()
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            for _, pair in ipairs(AMMO_PAIRS) do
                local af, mf   = pair[1], pair[2]
                local rounds   = rawget(v, af)
                local capacity = rawget(v, mf)
                if type(rounds) == "number" and type(capacity) == "number"
                and capacity > 0 and rounds >= 0
                and rawget(v, "DamagePerPart") == nil then
                    if rawget(v, "IsEquipped") ~= nil
                    or rawget(v, "IsShooting") ~= nil then
                        return v, af, mf
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

-- ── 9. ZERO SPREAD (state) ───────────────────────────────────
local spreadHooked = false
local spreadActive = false

local function TryHookSpread()
    if spreadHooked then return true end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v, "n") == "applySpread" then
            hookfunction(v, function(direction, _spread, _seed) return direction end)
            spreadHooked = true
            print("[Bloxstrike] Zero Spread: hooked via applySpread")
            return true
        end
    end
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            local sp = rawget(v, "Spread")
            local cs = rawget(v, "CharacterSpeed")
            local pr = rawget(v, "Properties")
            if sp ~= nil and cs ~= nil and type(pr) == "table" then
                pcall(function()
                    sp.update      = function() end
                    sp.setPosition = function() rawset(sp, "_pos", 0) end
                    sp.getPosition = function() return 0 end
                end)
                spreadHooked = true
                print("[Bloxstrike] Zero Spread: hooked via Bullet.Spread object")
                return true
            end
        end
    end
    return false
end

SetProg(80, "Building UI...", 4) ; task.wait(0.2)

-- ═════════════════════════════════════════════════════════════
--  LOADING — DISMISS
-- ═════════════════════════════════════════════════════════════
SetProg(95, "Finalising...", 5) ; task.wait(0.2)
SetProg(100, "Ready!")
task.wait(0.5)

if loadAnimConn then loadAnimConn:Disconnect() end
pcall(function()
    TweenService:Create(cam, TweenInfo.new(0), { CFrame = cam.CFrame }):Play()
end)
task.wait()
cam.CameraType    = Enum.CameraType.Custom
cam.CameraSubject = nil
task.wait()

TweenService:Create(bg, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    { BackgroundTransparency = 1 }):Play()
for _, d in ipairs(loadGui:GetDescendants()) do
    if d:IsA("TextLabel") then
        pcall(function() TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end)
    end
    if d:IsA("Frame") then
        pcall(function() TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play() end)
    end
end
task.wait(0.6)
if loadGui then loadGui:Destroy() end

-- ═════════════════════════════════════════════════════════════
--  MAIN PANEL — FLUENT UI
-- ═════════════════════════════════════════════════════════════

local Theme = {
    Background = Color3.fromRGB(24, 24, 28),
    Sidebar    = Color3.fromRGB(18, 18, 22),
    Accent     = Color3.fromRGB(0, 170, 120),
    AccentDim  = Color3.fromRGB(0, 110, 78),
    Text       = Color3.fromRGB(240, 240, 240),
    SubText    = Color3.fromRGB(150, 150, 150),
    Button     = Color3.fromRGB(35, 35, 40),
    Stroke     = Color3.fromRGB(60, 60, 65),
    Red        = Color3.fromRGB(215, 55, 55),
    Orange     = Color3.fromRGB(255, 152, 0),
    Green      = Color3.fromRGB(0, 210, 100),
}

local ScreenGui = Instance.new("ScreenGui", guiTarget)
ScreenGui.Name           = "UI_Main"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true

-- Minimised toggle icon
local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size                   = UDim2.new(0, 45, 0, 45)
ToggleIcon.Position               = UDim2.new(0.5, -22, 0.05, 0)
ToggleIcon.BackgroundColor3       = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text                   = "🎯"
ToggleIcon.TextSize               = 22
ToggleIcon.Visible                = false
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1, 0)
local IconStroke = Instance.new("UIStroke", ToggleIcon)
IconStroke.Color     = Theme.Accent
IconStroke.Thickness = 2

-- Main window frame
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size                   = UDim2.new(0, 420, 0, 280)
MainFrame.Position               = UDim2.new(0.5, -210, 0.5, -140)
MainFrame.BackgroundColor3       = Theme.Background
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active                 = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color        = Theme.Stroke
MainStroke.Transparency = 0.4

-- Top bar
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size                 = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size               = UDim2.new(0.6, 0, 1, 0)
TitleLbl.Position           = UDim2.new(0, 14, 0, 0)
TitleLbl.Text               = "🎯  VELOCITY MAX  ·  v5.8"
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextColor3         = Theme.Accent
TitleLbl.TextSize           = 12
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local Sep = Instance.new("Frame", MainFrame)
Sep.Size             = UDim2.new(1, -20, 0, 1)
Sep.Position         = UDim2.new(0, 10, 0, 32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel  = 0

-- Top bar control buttons
local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size               = UDim2.new(0, 28, 0, 22)
    b.Position           = pos
    b.BackgroundTransparency = 1
    b.Text               = text
    b.TextColor3         = color
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 12
    b.MouseButton1Click:Connect(cb)
    return b
end

AddCtrl("✕", UDim2.new(1, -32, 0.5, -11), Color3.fromRGB(255, 80, 80), function()
    ScreenGui:Destroy()
end)
AddCtrl("—", UDim2.new(1, -62, 0.5, -11), Theme.SubText, function()
    MainFrame.Visible  = false
    ToggleIcon.Visible = true
end)
ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible  = true
    ToggleIcon.Visible = false
end)

-- Drag support
local function EnableDrag(obj, handle)
    local drag, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag     = true
            start    = i.Position
            startPos = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
                  or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

-- Sidebar
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size                   = UDim2.new(0, 108, 1, -33)
Sidebar.Position               = UDim2.new(0, 0, 0, 33)
Sidebar.BackgroundColor3       = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel        = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding             = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0, 10)

-- Content area
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size                   = UDim2.new(1, -118, 1, -38)
ContentArea.Position               = UDim2.new(0, 113, 0, 38)
ContentArea.BackgroundTransparency = 1

local AllTabs    = {}
local AllTabBtns = {}

-- CreateTab helper
local function CreateTab(name, icon)
    local tf = Instance.new("ScrollingFrame", ContentArea)
    tf.Size                  = UDim2.new(1, 0, 1, 0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness    = 2
    tf.ScrollBarImageColor3  = Theme.AccentDim
    tf.Visible               = false
    tf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    tf.CanvasSize            = UDim2.new(0, 0, 0, 0)
    tf.BorderSizePixel       = 0
    local lay = Instance.new("UIListLayout", tf)
    lay.Padding = UDim.new(0, 7)
    local pad = Instance.new("UIPadding", tf)
    pad.PaddingTop = UDim.new(0, 6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size                   = UDim2.new(0.92, 0, 0, 30)
    tb.BackgroundColor3       = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text                   = "  " .. icon .. " " .. name
    tb.TextColor3             = Theme.SubText
    tb.Font                   = Enum.Font.GothamMedium
    tb.TextSize               = 12
    tb.TextXAlignment         = Enum.TextXAlignment.Left
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)

    local ind = Instance.new("Frame", tb)
    ind.Size             = UDim2.new(0, 3, 0.6, 0)
    ind.Position         = UDim2.new(0, 2, 0.2, 0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible          = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

    tb.MouseButton1Click:Connect(function()
        for _, t in pairs(AllTabs)    do t.Frame.Visible = false end
        for _, b in pairs(AllTabBtns) do
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3             = Theme.SubText
            b.Ind.Visible                = false
        end
        tf.Visible               = true
        tb.BackgroundTransparency = 0.82
        tb.TextColor3            = Theme.Text
        ind.Visible              = true
    end)

    table.insert(AllTabs,    { Frame = tf })
    table.insert(AllTabBtns, { Btn = tb, Ind = ind })
    return tf
end

-- UI Component helpers
local function Section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                   = UDim2.new(0.98, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = text
    lbl.TextColor3             = Theme.AccentDim
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 10
    lbl.TextXAlignment         = Enum.TextXAlignment.Left
end

local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn   = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98, 0, 0, 48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = ""
    btn.AutoButtonColor  = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local btnStroke = Instance.new("UIStroke", btn) ; btnStroke.Color = Theme.Stroke

    local tx = Instance.new("TextLabel", btn)
    tx.Size               = UDim2.new(0.72, 0, 0.5, 0)
    tx.Position           = UDim2.new(0, 10, 0, 5)
    tx.Text               = title
    tx.Font               = Enum.Font.GothamMedium
    tx.TextColor3         = Theme.Text
    tx.TextSize           = 12
    tx.TextXAlignment     = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel", btn)
    sub.Size              = UDim2.new(0.72, 0, 0.5, 0)
    sub.Position          = UDim2.new(0, 10, 0.5, 0)
    sub.Text              = desc
    sub.Font              = Enum.Font.Gotham
    sub.TextColor3        = Theme.SubText
    sub.TextSize          = 10
    sub.TextXAlignment    = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame", btn)
    pill.Size             = UDim2.new(0, 42, 0, 22)
    pill.Position         = UDim2.new(1, -52, 0.5, -11)
    pill.BackgroundColor3 = Theme.Button
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local ps = Instance.new("UIStroke", pill) ; ps.Color = Theme.Stroke ; ps.Thickness = 1

    local pillTxt = Instance.new("TextLabel", pill)
    pillTxt.Size              = UDim2.new(1, 0, 1, 0)
    pillTxt.Text              = "OFF"
    pillTxt.Font              = Enum.Font.GothamBold
    pillTxt.TextColor3        = Theme.SubText
    pillTxt.TextSize          = 9
    pillTxt.BackgroundTransparency = 1

    local function setV(on)
        state                 = on
        pill.BackgroundColor3 = on and Theme.Accent or Theme.Button
        ps.Color              = on and Theme.Accent or Theme.Stroke
        pillTxt.Text          = on and "ON"  or "OFF"
        pillTxt.TextColor3    = on and Color3.new(1, 1, 1) or Theme.SubText
        btn.BackgroundColor3  = on and Color3.fromRGB(30, 42, 36) or Theme.Button
    end
    setV(false)
    btn.MouseButton1Click:Connect(function()
        local res = callback(not state)
        setV(res ~= nil and res or not state)
    end)
    return setV
end

-- ═════════════════════════════════════════════════════════════
--  TABS
-- ═════════════════════════════════════════════════════════════
local TabCombat  = CreateTab("Combat",  "🎯")
local TabUtility = CreateTab("Utility", "🔧")

-- ─────────────────────────────────────────────────────────────
--  TAB 1 — COMBAT
-- ─────────────────────────────────────────────────────────────
Section(TabCombat, "  AIMBOT")

FluentToggle(TabCombat, "Max Velocity", "PullStrength ×65, head snap, wall bypass", function(v)
    local t = FindVelocityTable()
    if t then
        if v then
            pcall(ApplyVelocityON, t)
            task.defer(HookSmoke)
            print("[Bloxstrike] Max Velocity: ON")
        else
            pcall(ApplyVelocityOFF, t)
            print("[Bloxstrike] Max Velocity: OFF")
        end
        return v
    else
        warn("[Bloxstrike] Velocity table not found in gc.")
        return false
    end
end)

FluentToggle(TabCombat, "Zero Spread", "Hooks applySpread or Bullet.Spread object", function(v)
    spreadActive = v
    if spreadActive then
        local ok = TryHookSpread()
        if not ok then
            warn("[Bloxstrike] Spread function not found. Fire weapon once then toggle again.")
            spreadActive = false
            return false
        end
        print("[Bloxstrike] Zero Spread: ON")
    else
        if spreadHooked then
            print("[Bloxstrike] Zero Spread: OFF (hook stays — re-inject to fully restore).")
        end
    end
    return spreadActive
end)

Section(TabCombat, "  TRIGGER")

FluentToggle(TabCombat, "Boost AutoFire", "Native gc injection, 4-pass field scan", function(v)
    local t = FindAutoFireTable()
    if t then
        if v then
            pcall(ApplyAutoFireON, t)
            print("[Bloxstrike] AutoFire Boost: ON")
        else
            pcall(ApplyAutoFireOFF, t)
            print("[Bloxstrike] AutoFire Boost: OFF")
        end
        return v
    else
        warn("[Bloxstrike] AutoFire table not found in gc.")
        return false
    end
end)

-- ─────────────────────────────────────────────────────────────
--  TAB 2 — UTILITY
-- ─────────────────────────────────────────────────────────────
Section(TabUtility, "  VISUALS")

local setESP = FluentToggle(TabUtility, "Full Body ESP", "Proximity-sorted highlights, 10 max", function(v)
    Config.ESP_Enabled = v
    print("[Bloxstrike] Full Body ESP: " .. (v and "ON" or "OFF"))
    return v
end)
setESP(true)   -- ESP starts enabled on load

Section(TabUtility, "  WEAPON")

FluentToggle(TabUtility, "Infinite Ammo", "Pins Rounds = Capacity on live weapon at 20 Hz", function(v)
    ammoActive = v
    if ammoActive then
        if ammoThread then task.cancel(ammoThread) end
        ammoThread = task.spawn(function()
            while ammoActive do
                local t, af, mf = FindLiveWeaponTable()
                if t then
                    local cap = rawget(t, mf)
                    if type(cap) == "number" and cap > 0 then
                        t[af] = cap
                    end
                end
                task.wait(0.05)
            end
        end)
        print("[Bloxstrike] Infinite Ammo: ON")
    else
        if ammoThread then task.cancel(ammoThread) ; ammoThread = nil end
        print("[Bloxstrike] Infinite Ammo: OFF")
    end
    return ammoActive
end)

-- ── Activate first tab by default ────────────────────────────
if AllTabs[1] and AllTabBtns[1] then
    AllTabs[1].Frame.Visible               = true
    AllTabBtns[1].Btn.BackgroundTransparency = 0.82
    AllTabBtns[1].Btn.TextColor3           = Theme.Text
    AllTabBtns[1].Ind.Visible              = true
end

print("[Bloxstrike] v5.8 Fluent UI — Loaded")
print("  Tabs: Combat (Max Velocity | Zero Spread | AutoFire) | Utility (ESP | Infinite Ammo)")
