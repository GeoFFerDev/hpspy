-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5.4
-- Features: Ultra-Fast Aggressive Snap, Wide Active Zone, Wall Bypass,
--           Native AutoFire Boost, Player-Count FPS Fix, Reliable Button Toggles.
--           + Hitbox Expander, Zero Spread, Infinite Ammo (all client-side only)
-- v5.4 New Features (client-side ONLY, no server-side effect):
--   • Hitbox Expander: Inflates enemy character parts locally for easier hits.
--   • Zero Spread: Hooks the local applySpread function to return perfect accuracy.
--   • Infinite Ammo: Keeps local ammo counter maxed so reload animation never triggers.

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
    v.Magnetism.PullStrength       = 40.0
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28
    
    -- FRICTION — Off to prevent camera sticking
    v.Friction.Enabled             = false  
    v.Friction.BubbleRadius        = 0      
    v.Friction.MinSensitivity      = 1.0

    -- RECOIL — Full suppression
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
-- 7. UI
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

-- Main window — taller to fit 6 buttons
local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 220, 0, 340)   -- increased from 220 → 340
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
    b.Position         = UDim2.new(0.05, 0, 0, 10 + order * 45)  -- 45px spacing for 6 buttons
    b.BackgroundColor3 = startColor or COLOR_OFF
    b.Text             = label .. ": OFF"
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.Font             = Enum.Font.SourceSansBold
    b.TextSize         = 13
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

-- =========================================================================
-- 9. NEW FEATURE: HITBOX EXPANDER (100% client-side)
--    Inflates every BasePart on enemy characters so your local raycast
--    has a much larger target to register. The server never sees any
--    size change — this only affects YOUR screen's raycasting.
--    Scale: 3 = 3× wider/taller boxes. Raise/lower as preferred.
-- =========================================================================
local HITBOX_SCALE   = 3       -- how many times bigger each part becomes
local hitboxActive   = false
local expandedParts  = {}      -- [BasePart] = originalSize
local hitboxThread   = nil

local function ExpandCharacterHitboxes()
    for player in pairs(PlayerCache) do
        if IsEnemy(player) and player.Character then
            for _, part in ipairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and not expandedParts[part] then
                    local ok, err = pcall(function()
                        expandedParts[part] = part.Size
                        part.Size = part.Size * HITBOX_SCALE
                    end)
                end
            end
        end
    end
end

local function RestoreAllHitboxes()
    for part, origSize in pairs(expandedParts) do
        pcall(function()
            if part and part.Parent then
                part.Size = origSize
            end
        end)
    end
    expandedParts = {}
end

-- Clean up if player respawns / leaves mid-session
Players.PlayerRemoving:Connect(function(p)
    if hitboxActive and p.Character then
        for _, part in ipairs(p.Character:GetDescendants()) do
            if part:IsA("BasePart") and expandedParts[part] then
                pcall(function() part.Size = expandedParts[part] end)
                expandedParts[part] = nil
            end
        end
    end
end)

local HitboxBtn = MakeButton("Hitbox Expand", 3, COLOR_IDLE)

HitboxBtn.MouseButton1Click:Connect(function()
    hitboxActive = not hitboxActive

    if hitboxActive then
        -- Expand immediately, then keep expanding newly spawned enemies every 0.5s
        ExpandCharacterHitboxes()
        if hitboxThread then task.cancel(hitboxThread) end
        hitboxThread = task.spawn(function()
            while hitboxActive do
                task.wait(0.5)
                if hitboxActive then ExpandCharacterHitboxes() end
            end
        end)
        print("[Bloxstrike] Hitbox Expand ON — scale x" .. HITBOX_SCALE)
    else
        RestoreAllHitboxes()
        if hitboxThread then task.cancel(hitboxThread); hitboxThread = nil end
        print("[Bloxstrike] Hitbox Expand OFF — sizes restored")
    end

    HitboxBtn.Text             = "Hitbox Expand: " .. (hitboxActive and "ON" or "OFF")
    HitboxBtn.BackgroundColor3 = hitboxActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- 10. NEW FEATURE: ZERO SPREAD (100% client-side)
--     Hooks the "applySpread" function inside the Bullet module via gc scan.
--     When active, every shot fires dead-straight regardless of movement,
--     spray-and-pray, or crouch state. Server sees the direction you send —
--     so with aimbot ON you'll get perfectly on-target rays every shot.
-- =========================================================================
local spreadHooked  = false
local spreadActive  = false
local origSpreadFn  = nil

local function TryHookSpread()
    if spreadHooked then return true end

    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" then
            -- The Bullet module has an internal "applySpread" helper
            -- signature: applySpread(direction: Vector3, spread: number, seed: number) → Vector3
            local name = debug.info(v, "n")
            if name == "applySpread" then
                origSpreadFn = clonefunction(v)
                hookfunction(v, function(direction, _spread, _seed)
                    -- Return the original direction untouched — zero deviation
                    return direction
                end)
                spreadHooked = true
                print("[Bloxstrike] Zero Spread hooked via applySpread")
                return true
            end
        end
    end

    -- Fallback: scan for live Bullet instance and zero its Spread position
    -- The Bullet object has .Spread (a StateMachine/spring object with :getPosition())
    if not spreadHooked then
        for i = 1, #gc do
            local v = gc[i]
            if type(v) == "table" then
                local sp = rawget(v, "Spread")
                local cs = rawget(v, "CharacterSpeed")
                local pr = rawget(v, "Properties")
                if sp ~= nil and cs ~= nil and type(pr) == "table" then
                    -- Override the spread object's update so it always stays at 0
                    pcall(function()
                        sp.update = function() end          -- stop it climbing
                        sp.setPosition = function(_, val)   -- clamp any writes to 0
                            rawset(sp, "_pos", 0)
                        end
                        sp.getPosition = function()
                            return 0
                        end
                    end)
                    spreadHooked = true
                    print("[Bloxstrike] Zero Spread hooked via Bullet.Spread object")
                    return true
                end
            end
        end
    end

    return false
end

local SpreadBtn = MakeButton("Zero Spread", 4, COLOR_IDLE)

SpreadBtn.MouseButton1Click:Connect(function()
    spreadActive = not spreadActive

    if spreadActive then
        local ok = TryHookSpread()
        if not ok then
            -- Not found yet — keep button ON and remind them to fire once
            warn("[Bloxstrike] Spread function not found. Fire your weapon once, then toggle again.")
            -- Don't revert state — leave ON so retry is easy
        else
            print("[Bloxstrike] Zero Spread: ON")
        end
    else
        -- hookfunction is permanent once applied; toggling OFF is informational
        -- The hook stays, but we log the state for the user
        if spreadHooked then
            print("[Bloxstrike] Zero Spread: hook stays active (hookfunction is permanent).")
            print("[Bloxstrike] Re-inject the script to fully restore spread.")
        end
    end

    SpreadBtn.Text             = "Zero Spread: " .. (spreadActive and "ON" or "OFF")
    SpreadBtn.BackgroundColor3 = spreadActive and COLOR_ON or COLOR_IDLE
end)

-- =========================================================================
-- 11. NEW FEATURE: INFINITE AMMO (100% client-side)
--     Scans gc for the live weapon object (the table that has both .Rounds
--     and .Capacity as number fields) and continuously sets Rounds = Capacity.
--     This prevents the reload animation from triggering because the client
--     never sees an empty mag. The server tracks ammo independently — this
--     is a pure visual/local state trick so there's zero server interaction.
-- =========================================================================
local ammoActive  = false
local ammoThread  = nil

-- Field name pairs: { ammoField, maxField }
-- The script tries each pair until it finds a match on the live weapon object.
local AMMO_PAIRS = {
    { "Rounds",        "Capacity"    },
    { "rounds",        "capacity"    },
    { "CurrentAmmo",   "MaxAmmo"     },
    { "currentAmmo",   "maxAmmo"     },
    { "Ammo",          "MaxAmmo"     },
    { "ammo",          "maxAmmo"     },
    { "CurrentRounds", "TotalRounds" },
}

-- Looks for a live weapon state table in gc — distinct from Properties tables
-- (those have DamagePerPart; live weapon objects have Rounds AND IsEquipped)
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
                -- Exclude pure Properties tables (they also have DamagePerPart)
                and not rawget(v, "DamagePerPart") then
                    -- Extra confidence check: live weapons also carry IsEquipped or IsShooting
                    if rawget(v, "IsEquipped") ~= nil or rawget(v, "IsShooting") ~= nil then
                        return v, af, mf
                    end
                end
            end
        end
    end
    return nil, nil, nil
end

local AmmoBtn = MakeButton("Infinite Ammo", 5, COLOR_IDLE)

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
                        t[af] = cap    -- keep rounds pinned at full capacity
                    end
                end
                task.wait(0.05)        -- 20 Hz — fast enough to prevent reload trigger
            end
        end)
        print("[Bloxstrike] Infinite Ammo ON — equip a weapon if not found immediately")
    else
        if ammoThread then task.cancel(ammoThread); ammoThread = nil end
        print("[Bloxstrike] Infinite Ammo OFF")
    end

    AmmoBtn.Text             = "Infinite Ammo: " .. (ammoActive and "ON" or "OFF")
    AmmoBtn.BackgroundColor3 = ammoActive and COLOR_ON or COLOR_IDLE
end)

print("[Bloxstrike] v5.4 Loaded — Hitbox Expand / Zero Spread / Infinite Ammo added")
