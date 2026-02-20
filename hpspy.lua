-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5.5
-- Features: Ultra-Fast Aggressive Snap, Wide Active Zone, Wall Bypass,
--           Native AutoFire Boost, Player-Count FPS Fix, Reliable Button Toggles,
--           Hitbox Expander (raycast hook, no size change = no kick),
--           Armor Penetration (client gc boost),
--           Zero Spread, Infinite Ammo.
-- v5.5 Changes:
--   • HITBOX FIX: Rewrote hitbox expander to use hookmetamethod(__namecall) to
--     intercept workspace:Raycast calls instead of changing BasePart.Size.
--     Changing Size on server-owned parts replicates back and gets you kicked.
--     The new approach adds a "near-miss radius" around enemy HumanoidRootParts —
--     if a ray misses but passes within that radius, a secondary real raycast fires
--     directly at the enemy and returns a valid RaycastResult. 100% client-side.
--   • NEW: Armor Penetration — scans gc for every loaded weapon Properties table
--     and sets ArmorPenetration = 1.0. This affects client-local calculations
--     (damage number indicators, etc.). Server manages its own copy, so raw
--     damage numbers on the server won't change, but paired with the hitbox
--     hook you register more hits per second which is effectively more DPS.
--   • v5.3 core (ESP, AutoFire, Velocity, Smoke bypass) preserved exactly.
--   • v5.4 Zero Spread and Infinite Ammo preserved exactly.
--   • UI window height increased to fit all 7 buttons.

local Players   = game:GetService("Players")
local CoreGui   = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

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
-- 3. GC SCANNER — finds and caches the aimbot config table
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
            if hasEnable then AutoFireRef = v; return v end
            local count = 0
            for _, f in ipairs(AF_DELAY_FIELDS) do
                if rawget(v, f) ~= nil then count = count + 1 end
                if count >= 2 then AutoFireRef = v; return v end
            end
        end
    end

    if VelocityRef then
        local hasAny = TableHasAny(VelocityRef, AF_ENABLE_FIELDS)
                    or TableHasAny(VelocityRef, AF_DELAY_FIELDS)
        if hasAny then AutoFireRef = VelocityRef; return VelocityRef end
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
-- 5. VELOCITY INJECTION
-- =========================================================================
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
    v.Magnetism.PullStrength       = 40.0
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
-- 8. UI  (window now taller to fit 7 buttons)
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

-- 7 buttons × 42px spacing + 10px top padding + 35px button height = ~325px content
-- + 30px title bar = 355px. Using 370px for breathing room.
local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 220, 0, 370)
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

-- Icon drag logic
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
Content.Size                = UDim2.new(1, 0, 1, -30)
Content.Position            = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent              = MainFrame

local COLOR_ON   = Color3.fromRGB(0, 150, 0)
local COLOR_OFF  = Color3.fromRGB(45, 45, 45)
local COLOR_IDLE = Color3.fromRGB(180, 60, 0)
local COLOR_BLUE = Color3.fromRGB(0, 80, 180)   -- used for armor pen (different visual)

local BTN_SPACING = 47   -- pixels between button tops; fits 7 buttons in 370px window

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
local FireBtn  = MakeButton("Boost AutoFire", 1, COLOR_IDLE)
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
-- BUTTON 2 — Max Velocity
-- =========================================================================
local VelBtn  = MakeButton("Max Velocity", 2, COLOR_IDLE)
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
-- BUTTON 3 — Hitbox Expander (v5.5 — NO SIZE CHANGES, uses namecall hook)
--
-- Root cause of the kick in v5.4:
--   Changing BasePart.Size on server-owned parts (enemy characters) causes
--   Roblox's physics replication to send the change to the server. BloxStrike's
--   anti-cheat detects the part-size mismatch and kicks the client.
--
-- Fix:
--   Instead we hook the game's __namecall metamethod to intercept every call to
--   workspace:Raycast. When a raycast MISSES but passes within HITBOX_RADIUS studs
--   of an enemy's HumanoidRootPart, we fire a SECOND real raycast aimed directly
--   at that enemy (using new params that only exclude our own character). That
--   second raycast returns a genuine RaycastResult pointing to a real enemy part —
--   so the game's bullet-hit array gets a valid hit that the server accepts.
--   Nothing is written to any replicated property. 100% local.
-- =========================================================================
local HITBOX_RADIUS  = 5.0   -- studs of near-miss forgiveness (raise to hit easier)
local hitboxActive   = false
local hitboxHooked   = false
local hookGuard      = false   -- re-entrancy guard: prevents the secondary raycast
                               -- from triggering the hook again infinitely

local function InstallHitboxHook()
    if hitboxHooked then return true end

    -- hookmetamethod is provided by most executor environments.
    -- If it is not available, fall back gracefully and warn.
    if not hookmetamethod then
        warn("[Bloxstrike] hookmetamethod not available in this executor. Hitbox feature disabled.")
        return false
    end

    local origNamecall
    origNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()

        -- Only intercept workspace:Raycast when hitbox is active and not already in a hook call
        if hitboxActive and not hookGuard and self == workspace and method == "Raycast" then
            -- Step 1: Run the real raycast first — honour normal hits
            local realResult = origNamecall(self, ...)
            if realResult then return realResult end

            -- Step 2: Ray missed — check if it passed near any enemy HRP
            local args      = { ... }
            local origin    = args[1]
            local direction = args[2]
            if not (typeof(origin) == "Vector3" and typeof(direction) == "Vector3") then
                return realResult
            end

            local rayLen  = direction.Magnitude
            local rayUnit = direction.Unit

            local bestDist = HITBOX_RADIUS
            local bestHRP  = nil

            for player in pairs(PlayerCache) do
                if IsEnemy(player) and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        -- Project the HRP centre onto the ray line
                        local toHRP = hrp.Position - origin
                        local t     = toHRP:Dot(rayUnit)
                        -- Only consider the forward half of the ray (not behind us)
                        if t >= 0 then
                            local clampedT  = math.min(t, rayLen)
                            local closestPt = origin + rayUnit * clampedT
                            local dist      = (hrp.Position - closestPt).Magnitude
                            if dist < bestDist then
                                bestDist = dist
                                bestHRP  = hrp
                            end
                        end
                    end
                end
            end

            if bestHRP then
                -- Step 3: Fire a secondary raycast directly at the enemy.
                --   - We set hookGuard = true to prevent infinite recursion.
                --   - We exclude only OUR character so the ray can reach the enemy.
                --   - We do NOT exclude enemy characters so the ray returns their parts.
                hookGuard = true
                local toEnemy   = bestHRP.Position - origin
                local newParams = RaycastParams.new()
                newParams.FilterType = Enum.RaycastFilterType.Exclude
                local myChar = LocalPlayer.Character
                if myChar then
                    newParams.FilterDescendantsInstances = { myChar, workspace.CurrentCamera }
                end
                local hit = origNamecall(workspace, origin, toEnemy, newParams)
                hookGuard = false
                if hit then return hit end
            end

            return realResult   -- still nil, but we tried
        end

        return origNamecall(self, ...)
    end)

    hitboxHooked = true
    print("[Bloxstrike] Hitbox hook installed via __namecall (no size changes)")
    return true
end

local HitboxBtn = MakeButton("Hitbox Expand", 3, COLOR_IDLE)

HitboxBtn.MouseButton1Click:Connect(function()
    hitboxActive = not hitboxActive

    if hitboxActive then
        local ok = InstallHitboxHook()   -- install hook once, stays forever
        if not ok then
            hitboxActive = false          -- hook failed, revert state
            HitboxBtn.Text             = "Hitbox Expand: ERR"
            HitboxBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
            return
        end
        print("[Bloxstrike] Hitbox Expand ON — radius: " .. HITBOX_RADIUS .. " studs")
    else
        -- Hook stays installed but the guard check (hitboxActive = false) deactivates it
        print("[Bloxstrike] Hitbox Expand OFF")
    end

    HitboxBtn.Text             = "Hitbox Expand: " .. (hitboxActive and "ON" or "OFF")
    HitboxBtn.BackgroundColor3 = hitboxActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- BUTTON 4 — Armor Penetration (client-side gc boost)
--
-- Scans gc for every loaded weapon Properties table that contains an
-- ArmorPenetration (or variant) field and sets it to 1.0 (full bypass).
--
-- What this DOES affect:
--   • Client-local calculations — e.g. damage number indicators shown on screen.
--   • Any client-side logic that reads ArmorPenetration before firing.
--   • Potentially the Bullet module's hit-processing if it reads from the same
--     require'd table (depends on how the game shares the reference).
--
-- What this does NOT affect:
--   • The server's own copy of the weapon Properties table — Roblox runs server
--     and client in separate Lua VMs, so require() returns separate table instances.
--     Server-side damage is calculated with the server's own unmodified values.
--
-- Net result: your damage numbers on-screen look higher, and if any client-side
-- armor calculation feeds into the hit packet, you bypass it. Combined with the
-- hitbox hook, you simply land more shots — which IS more effective DPS.
-- =========================================================================
local ARMOR_PEN_FIELDS = {
    "ArmorPenetration", "armorPenetration",
    "PenetrationMultiplier", "penetrationMultiplier",
    "Penetration", "penetration",
    "ArmorPen", "armorPen",
}

local armorPenActive  = false
local armorPenSaved   = {}   -- { tbl, field, origVal } entries for restore

local function ApplyArmorPenON()
    armorPenSaved = {}
    local gc = getgc(true)
    local boosted = 0
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            for _, f in ipairs(ARMOR_PEN_FIELDS) do
                local cur = rawget(v, f)
                if type(cur) == "number" and cur >= 0 and cur <= 1.5 then
                    -- Validate this looks like a weapon Properties table
                    local isWeapon = rawget(v, "DamagePerPart") ~= nil
                                  or rawget(v, "WalkSpeed")     ~= nil
                                  or rawget(v, "FireRate")       ~= nil
                    if isWeapon then
                        table.insert(armorPenSaved, { tbl = v, field = f, orig = cur })
                        v[f] = 1.0
                        boosted = boosted + 1
                        break   -- only one ArmorPen field per table needed
                    end
                end
            end
        end
    end
    print("[Bloxstrike] Armor Pen ON — boosted " .. boosted .. " weapon tables to 1.0")
    if boosted == 0 then
        warn("[Bloxstrike] No weapon tables found yet. Equip a weapon then toggle again.")
    end
end

local function ApplyArmorPenOFF()
    for _, entry in ipairs(armorPenSaved) do
        pcall(function()
            entry.tbl[entry.field] = entry.orig
        end)
    end
    local count = #armorPenSaved
    armorPenSaved = {}
    print("[Bloxstrike] Armor Pen OFF — restored " .. count .. " tables")
end

local ArmorBtn = MakeButton("Armor Pen", 4, COLOR_BLUE)

ArmorBtn.MouseButton1Click:Connect(function()
    armorPenActive = not armorPenActive
    if armorPenActive then
        ApplyArmorPenON()
    else
        ApplyArmorPenOFF()
    end
    ArmorBtn.Text             = "Armor Pen: " .. (armorPenActive and "ON" or "OFF")
    ArmorBtn.BackgroundColor3 = armorPenActive and COLOR_ON or COLOR_BLUE
end)

-- =========================================================================
-- BUTTON 5 — Zero Spread (hooks applySpread in Bullet module via gc scan)
-- =========================================================================
local spreadHooked = false
local spreadActive = false

local function TryHookSpread()
    if spreadHooked then return true end

    local gc = getgc(true)

    -- Pass 1: look for the named "applySpread" helper function
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v, "n") == "applySpread" then
            hookfunction(v, function(direction, _spread, _seed)
                return direction   -- return direction unchanged — zero deviation
            end)
            spreadHooked = true
            print("[Bloxstrike] Zero Spread: hooked via applySpread function")
            return true
        end
    end

    -- Pass 2: find live Bullet instance and override its Spread state object
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

local SpreadBtn = MakeButton("Zero Spread", 5, COLOR_IDLE)

SpreadBtn.MouseButton1Click:Connect(function()
    spreadActive = not spreadActive

    if spreadActive then
        local ok = TryHookSpread()
        if not ok then
            warn("[Bloxstrike] Spread function not found yet. Fire your weapon once then toggle again.")
        else
            print("[Bloxstrike] Zero Spread: ON")
        end
    else
        -- hookfunction is permanent for the session; toggling OFF changes the
        -- UI label only. Re-inject the script to fully restore spread behaviour.
        if spreadHooked then
            print("[Bloxstrike] Zero Spread: UI set to OFF. Hook stays (hookfunction is permanent).")
            print("[Bloxstrike] Re-inject to restore spread.")
        end
    end

    SpreadBtn.Text             = "Zero Spread: " .. (spreadActive and "ON" or "OFF")
    SpreadBtn.BackgroundColor3 = spreadActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- BUTTON 6 — Infinite Ammo (pins Rounds = Capacity on live weapon object)
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
                local af, mf = pair[1], pair[2]
                local rounds   = rawget(v, af)
                local capacity = rawget(v, mf)
                if type(rounds) == "number" and type(capacity) == "number"
                and capacity > 0 and rounds >= 0
                and rawget(v, "DamagePerPart") == nil then
                    -- Confirm it is a live weapon state object, not a static config
                    if rawget(v, "IsEquipped") ~= nil or rawget(v, "IsShooting") ~= nil then
                        return v, af, mf
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

local AmmoBtn = MakeButton("Infinite Ammo", 6, COLOR_IDLE)

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
                        t[af] = cap   -- pin rounds at full capacity
                    end
                end
                task.wait(0.05)   -- 20 Hz — fast enough to stop reload trigger
            end
        end)
        print("[Bloxstrike] Infinite Ammo ON — equip a weapon if not detected immediately")
    else
        if ammoThread then task.cancel(ammoThread); ammoThread = nil end
        print("[Bloxstrike] Infinite Ammo OFF")
    end

    AmmoBtn.Text             = "Infinite Ammo: " .. (ammoActive and "ON" or "OFF")
    AmmoBtn.BackgroundColor3 = ammoActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
print("[Bloxstrike] v5.5 Loaded")
print("  Buttons: ESP | AutoFire | Velocity | Hitbox(namecall) | ArmorPen | ZeroSpread | InfiniteAmmo")
