-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5.8
-- Features:
--   • Full Body ESP       — proximity-sorted highlights, 10 max, dynamic FPS scaling
--   • Boost AutoFire      — native gc injection, 4-pass broad field scan
--   • Max Velocity        — boosted aimbot (PullStrength 65, all-angle snap, head target,
--                           wall bypass, full recoil suppression)
--   • Zero Spread         — hooks applySpread or Bullet.Spread object via gc scan
--   • Infinite Ammo       — pins Rounds = Capacity on live weapon object at 20 Hz
--   • Speed Boost         — sets Humanoid.WalkSpeed = 32 with keepalive loop (default ~17-20)
--   • Rapid Fire          — lowers Properties.FireRate to 0.05s (~20 shots/sec), saves + restores
--
-- v5.8 Changes vs v5.7:
--   • ADDED: Speed Boost (Button 5)
--       Finds LocalPlayer.Character.Humanoid and sets WalkSpeed = 32.
--       A keepalive loop re-applies every 0.5s in case the game resets it on equip/respawn.
--       Client-side only — no packets sent, no server writes. Safe.
--
--   • ADDED: Rapid Fire (Button 6)
--       Scans gc for the live weapon Properties table (identified by FireRate + DamagePerPart).
--       Saves the original FireRate, then sets it to 0.05 (~20 shots/sec).
--       Restores on toggle OFF. Does NOT touch Penetration, WalkSpeed, or any other field.
--       The client shoot loop gates fire timing from this value. Kept at 0.05 (not 0.001)
--       to stay well under the server-side ByteNet rate limiter.
--
-- v5.7 Changes vs v5.6:
--   • REMOVED: Hitbox Expander.
--
--     WHY: Both approaches we tried caused bans for the same root reason:
--
--     v5.4 (Size change): Changing BasePart.Size on server-owned parts replicates
--     back to the server. Anti-cheat detects the size mismatch → kick.
--
--     v5.5/v5.6 (Namecall hook): The ShootWeapon packet sent to the server contains
--     BOTH a Direction vector (original miss direction) AND Hits[].Position (where
--     the bullet landed). Our secondary raycast returned a hit on an enemy, but the
--     Direction in the packet still pointed away from them. The server re-validates
--     hits by re-casting a ray from the same Origin in the same Direction — the hit
--     is geometrically impossible for that direction → ban.
--
--     To fix this we would also need to modify the outgoing Direction field in the
--     network packet itself, which requires hooking the ByteNet send call and
--     rewriting packet data — a far deeper injection that BloxStrike also monitors.
--     The risk-to-reward is zero: the aimbot already snaps to head before the shot
--     fires, so hitbox was redundant with Max Velocity enabled anyway.
--
--   • Max Velocity aimbot boosted to compensate:
--       PullStrength  40 → 65   (much snappier snap-to-target)
--       StopThreshold  0 →  0   (unchanged, already optimal)
--       MaxAngleH/V = 6.28      (unchanged, already full sphere)
--
--   • UI window reduced to 5 buttons (285px).
--   • All other features from v5.6 preserved exactly.

local Players     = game:GetService("Players")
local CoreGui     = game:GetService("CoreGui")
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
local VelocityRef = nil
local AutoFireRef = nil

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
-- 3. GC SCANNER
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

    -- Pass 1: sub-tables of VelocityRef
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

    -- Pass 2: strict — enable AND delay
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            if TableHasAny(v, AF_ENABLE_FIELDS) and TableHasAny(v, AF_DELAY_FIELDS) then
                AutoFireRef = v
                return v
            end
        end
    end

    -- Pass 3: relaxed — enable OR 2+ delay fields
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" and v ~= VelocityRef then
            if TableHasAny(v, AF_ENABLE_FIELDS) then
                AutoFireRef = v
                return v
            end
            local count = 0
            for _, f in ipairs(AF_DELAY_FIELDS) do
                if rawget(v, f) ~= nil then count = count + 1 end
                if count >= 2 then AutoFireRef = v; return v end
            end
        end
    end

    -- Pass 4: fallback to VelocityRef itself
    if VelocityRef then
        if TableHasAny(VelocityRef, AF_ENABLE_FIELDS)
        or TableHasAny(VelocityRef, AF_DELAY_FIELDS) then
            AutoFireRef = VelocityRef
            return VelocityRef
        end
    end

    return nil
end

-- =========================================================================
-- 4. SMOKE BYPASS
-- =========================================================================
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
-- 5. VELOCITY INJECTION  (PullStrength boosted 40 → 65)
-- =========================================================================
local function ApplyVelocityON(v)
    -- Targeting
    v.TargetSelection.MaxDistance = 10000
    v.TargetSelection.MaxAngle    = 6.28
    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = false end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end
    if rawget(v.TargetSelection, "TargetPart") ~= nil then v.TargetSelection.TargetPart = "Head" end
    if rawget(v.TargetSelection, "TargetBone") ~= nil then v.TargetSelection.TargetBone = "Head" end
    if rawget(v.TargetSelection, "Bone")       ~= nil then v.TargetSelection.Bone       = "Head" end

    -- Magnetism (boosted snap)
    v.Magnetism.Enabled            = true
    v.Magnetism.MaxDistance        = 10000
    v.Magnetism.PullStrength       = 65.0   -- was 40 — snappier, still stable
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28

    -- Friction off — prevents camera sticking
    v.Friction.Enabled             = false
    v.Friction.BubbleRadius        = 0
    v.Friction.MinSensitivity      = 1.0

    -- Recoil suppression
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

-- =========================================================================
-- 6. AUTOFIRE INJECTION
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
-- 7. ESP
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
-- 8. UI   (7 buttons × 47px spacing + 8px top = 337px content + 30px title = 367px → 379px)
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

local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 220, 0, 379)
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
-- 9. BUTTON BUILDER
-- =========================================================================
local Content = Instance.new("Frame")
Content.Size                   = UDim2.new(1, 0, 1, -30)
Content.Position               = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent                 = MainFrame

local COLOR_ON   = Color3.fromRGB(0, 150, 0)
local COLOR_OFF  = Color3.fromRGB(45, 45, 45)
local COLOR_IDLE = Color3.fromRGB(180, 60, 0)

local BTN_SPACING = 47

local function MakeButton(label, order, startColor)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 35)
    b.Position         = UDim2.new(0.05, 0, 0, 8 + order * BTN_SPACING)
    b.BackgroundColor3 = startColor or COLOR_OFF
    b.Text             = label .. ": OFF"
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.SourceSansBold
    b.TextSize         = 13
    b.Parent           = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

-- =========================================================================
-- BUTTON 0 — Full Body ESP
-- =========================================================================
local EspBtn = MakeButton("Full Body ESP", 0, COLOR_ON)
EspBtn.Text = "Full Body ESP: ON"

EspBtn.MouseButton1Click:Connect(function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    EspBtn.Text             = "Full Body ESP: " .. (Config.ESP_Enabled and "ON" or "OFF")
    EspBtn.BackgroundColor3 = Config.ESP_Enabled and COLOR_ON or COLOR_OFF
end)

-- =========================================================================
-- BUTTON 1 — Boost AutoFire
-- =========================================================================
local FireBtn    = MakeButton("Boost AutoFire", 1, COLOR_IDLE)
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

-- =========================================================================
-- BUTTON 2 — Max Velocity (aimbot, PullStrength boosted to 65)
-- =========================================================================
local VelBtn    = MakeButton("Max Velocity", 2, COLOR_IDLE)
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

-- =========================================================================
-- BUTTON 3 — Zero Spread
--
-- Pass 1: hooks the named "applySpread" function in the Bullet module.
-- Pass 2: falls back to overriding methods on the live Bullet.Spread object.
-- hookfunction is permanent for the session. Toggling OFF changes UI only.
-- Re-inject the script to fully restore spread behaviour.
-- =========================================================================
local spreadHooked = false
local spreadActive = false

local function TryHookSpread()
    if spreadHooked then return true end

    local gc = getgc(true)

    -- Pass 1: named function hook
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v, "n") == "applySpread" then
            hookfunction(v, function(direction, _spread, _seed)
                return direction
            end)
            spreadHooked = true
            print("[Bloxstrike] Zero Spread: hooked via applySpread")
            return true
        end
    end

    -- Pass 2: live Bullet.Spread object override
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

local SpreadBtn = MakeButton("Zero Spread", 3, COLOR_IDLE)

SpreadBtn.MouseButton1Click:Connect(function()
    spreadActive = not spreadActive

    if spreadActive then
        local ok = TryHookSpread()
        if not ok then
            warn("[Bloxstrike] Spread function not found. Fire weapon once then toggle again.")
        else
            print("[Bloxstrike] Zero Spread: ON")
        end
    else
        if spreadHooked then
            print("[Bloxstrike] Zero Spread: OFF (hook stays — re-inject to fully restore).")
        end
    end

    SpreadBtn.Text             = "Zero Spread: " .. (spreadActive and "ON" or "OFF")
    SpreadBtn.BackgroundColor3 = spreadActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- BUTTON 4 — Infinite Ammo
--
-- Scans gc for the live weapon state table — distinguished from static
-- Properties tables by the presence of IsEquipped or IsShooting — and
-- pins Rounds = Capacity at 20 Hz so the reload animation never triggers.
-- =========================================================================
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

local AmmoBtn = MakeButton("Infinite Ammo", 4, COLOR_IDLE)

AmmoBtn.MouseButton1Click:Connect(function()
    ammoActive = not ammoActive

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
        print("[Bloxstrike] Infinite Ammo ON")
    else
        if ammoThread then task.cancel(ammoThread); ammoThread = nil end
        print("[Bloxstrike] Infinite Ammo OFF")
    end

    AmmoBtn.Text             = "Infinite Ammo: " .. (ammoActive and "ON" or "OFF")
    AmmoBtn.BackgroundColor3 = ammoActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- BUTTON 5 — Speed Boost
--
-- Sets Humanoid.WalkSpeed = SPEED_TARGET on the local character.
-- BloxStrike default is weapon-dependent (AWP = 16.16, MAC-10 = 19.39 etc.).
-- A keepalive loop re-applies every 0.5s so weapon equip/respawn
-- doesn't silently reset it back to normal.
-- 100% client-side, zero packets sent.
-- =========================================================================
local SPEED_TARGET = 32      -- studs/second.  Default range: 16-20.
local speedActive  = false
local speedThread  = nil

local function ApplySpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = SPEED_TARGET end
end

local function RestoreSpeed()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 end  -- Roblox default fallback
end

local SpeedBtn = MakeButton("Speed Boost", 5, COLOR_IDLE)

SpeedBtn.MouseButton1Click:Connect(function()
    speedActive = not speedActive

    if speedActive then
        if speedThread then task.cancel(speedThread) end
        speedThread = task.spawn(function()
            while speedActive do
                pcall(ApplySpeed)
                task.wait(0.5)
            end
        end)
        print("[Bloxstrike] Speed Boost ON — WalkSpeed: " .. SPEED_TARGET)
    else
        if speedThread then task.cancel(speedThread); speedThread = nil end
        pcall(RestoreSpeed)
        print("[Bloxstrike] Speed Boost OFF")
    end

    SpeedBtn.Text             = "Speed Boost: " .. (speedActive and "ON" or "OFF")
    SpeedBtn.BackgroundColor3 = speedActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- BUTTON 6 — Rapid Fire
--
-- Finds the live weapon Properties table in gc by requiring BOTH:
--   (a) a numeric FireRate field in the realistic range 0.01–5.0 seconds
--   (b) a DamagePerPart sub-table (confirms it's a weapon, not something else)
-- Saves the original FireRate, sets it to RAPID_RATE, restores on toggle OFF.
-- Only touches FireRate — no other fields modified.
-- Kept at 0.05 (20 shots/sec) to stay under the ByteNet server rate limiter.
-- =========================================================================
local RAPID_RATE   = 0.05    -- seconds between shots.  Do not go below 0.03.
local rapidActive  = false
local rapidRef     = nil     -- { tbl, field, orig }

local FIRERATE_NAMES = {
    "FireRate", "fireRate", "ShootDelay", "shootDelay",
    "AttackSpeed", "attackSpeed", "ShotDelay", "shotDelay",
}

local function FindFireRateEntry()
    if rapidRef then return rapidRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table"
        and rawget(v, "DamagePerPart") ~= nil then   -- must be a weapon Properties table
            for _, fname in ipairs(FIRERATE_NAMES) do
                local cur = rawget(v, fname)
                if type(cur) == "number" and cur > 0.01 and cur < 5.0 then
                    rapidRef = { tbl = v, field = fname, orig = cur }
                    return rapidRef
                end
            end
        end
    end
    return nil
end

local RapidBtn = MakeButton("Rapid Fire", 6, COLOR_IDLE)

RapidBtn.MouseButton1Click:Connect(function()
    rapidActive = not rapidActive

    local entry = FindFireRateEntry()
    if entry then
        if rapidActive then
            entry.tbl[entry.field] = RAPID_RATE
            print("[Bloxstrike] Rapid Fire ON — FireRate: " .. RAPID_RATE
                  .. " (was " .. entry.orig .. ")")
        else
            entry.tbl[entry.field] = entry.orig
            rapidRef = nil   -- force re-scan next time (catches weapon swaps)
            print("[Bloxstrike] Rapid Fire OFF — FireRate restored to " .. entry.orig)
        end
    else
        warn("[Bloxstrike] FireRate table not found. Equip a weapon and try again.")
        rapidActive = not rapidActive   -- revert toggle
    end

    RapidBtn.Text             = "Rapid Fire: " .. (rapidActive and "ON" or "OFF")
    RapidBtn.BackgroundColor3 = rapidActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
print("[Bloxstrike] v5.8 Loaded")
print("  Buttons: ESP | AutoFire | Velocity(x65) | ZeroSpread | InfiniteAmmo | SpeedBoost | RapidFire")
print("  Hitbox removed — server validates Direction vs Hit geometry (unbeatable)")
