-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION) - v5
-- Features: Ultra-Fast Aggressive Snap, Wide Active Zone, Wall Bypass,
--           Native AutoFire Boost, Player-Count FPS Fix, Reliable Button Toggles.
-- v5 Fix:
--   • Each button owns its own isActive boolean — toggle state NEVER depends
--     on whether the gc injection succeeded or not. UI always reflects reality.
--   • Removed save/restore originals system (was failing silently inside pcall,
--     locking buttons in a broken state). OFF state now writes safe neutral values.
--   • gc table refs are cached after first successful scan — no repeat scan cost.
--   • ProtectExecution only wraps the actual game-table writes, never the state logic.

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

local function FindAutoFireTable()
    if AutoFireRef then return AutoFireRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            local hasField =
                rawget(v, "Sensitivity")    ~= nil or
                rawget(v, "ReactionTime")   ~= nil or
                rawget(v, "FireDelay")      ~= nil or
                rawget(v, "TriggerDelay")   ~= nil or
                rawget(v, "AutoFireDelay")  ~= nil or
                rawget(v, "ShootDelay")     ~= nil or
                rawget(v, "TriggerEnabled") ~= nil

            local isAF =
                rawget(v, "TriggerEnabled")  ~= nil or
                rawget(v, "AutoFireEnabled") ~= nil or
                rawget(v, "FireMode")        ~= nil or
                rawget(v, "AutoFire")        ~= nil

            if hasField and isAF then
                AutoFireRef = v
                return v
            end
        end
    end
    return nil
end

-- Also hook the smoke raycast on first velocity scan.
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
    -- MAGNETISM — aggressive snap
    v.Magnetism.Enabled            = true
    v.Magnetism.MaxDistance        = 10000
    v.Magnetism.PullStrength       = 80.0   -- 3x harder snap than original 25
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28
    -- FRICTION — near-zero resistance for instant lock
    v.Friction.Enabled             = true
    v.Friction.BubbleRadius        = 250.0  -- wide sticky zone
    v.Friction.MinSensitivity      = 0.000001
    -- RECOIL — full suppression
    v.RecoilAssist.Enabled         = true
    v.RecoilAssist.ReductionAmount = 1.0
end

local function ApplyVelocityOFF(v)
    -- Write safe neutral values. Magnetism still enabled but weak,
    -- so the game doesn't error from a fully disabled state.
    v.Magnetism.PullStrength       = 1.0
    v.Magnetism.MaxDistance        = 300
    v.Magnetism.MaxAngleHorizontal = 0.5
    v.Magnetism.MaxAngleVertical   = 0.5
    v.Friction.BubbleRadius        = 5.0
    v.Friction.MinSensitivity      = 1.0
    v.RecoilAssist.ReductionAmount = 0.0
end

-- =========================================================================
-- 5. AUTOFIRE INJECTION — ON and OFF
-- =========================================================================
local function ApplyAutoFireON(v)
    if rawget(v, "TriggerEnabled")   ~= nil then v.TriggerEnabled   = true  end
    if rawget(v, "AutoFireEnabled")  ~= nil then v.AutoFireEnabled  = true  end
    if rawget(v, "Sensitivity")      ~= nil then v.Sensitivity      = 1.0   end
    if rawget(v, "ReactionTime")     ~= nil then v.ReactionTime     = 0.0   end
    if rawget(v, "FireDelay")        ~= nil then v.FireDelay        = 0.0   end
    if rawget(v, "TriggerDelay")     ~= nil then v.TriggerDelay     = 0.0   end
    if rawget(v, "AutoFireDelay")    ~= nil then v.AutoFireDelay    = 0.0   end
    if rawget(v, "ShootDelay")       ~= nil then v.ShootDelay       = 0.0   end
    if rawget(v, "TriggerAngle")     ~= nil then v.TriggerAngle     = 6.28  end
    if rawget(v, "TriggerDistance")  ~= nil then v.TriggerDistance  = 10000 end
    if rawget(v, "DetectionRadius")  ~= nil then v.DetectionRadius  = 10000 end
end

local function ApplyAutoFireOFF(v)
    if rawget(v, "TriggerEnabled")   ~= nil then v.TriggerEnabled   = false end
    if rawget(v, "AutoFireEnabled")  ~= nil then v.AutoFireEnabled  = false end
    if rawget(v, "ReactionTime")     ~= nil then v.ReactionTime     = 0.15  end
    if rawget(v, "FireDelay")        ~= nil then v.FireDelay        = 0.1   end
    if rawget(v, "TriggerDelay")     ~= nil then v.TriggerDelay     = 0.1   end
    if rawget(v, "AutoFireDelay")    ~= nil then v.AutoFireDelay    = 0.1   end
    if rawget(v, "ShootDelay")       ~= nil then v.ShootDelay       = 0.1   end
    if rawget(v, "TriggerAngle")     ~= nil then v.TriggerAngle     = 1.0   end
    if rawget(v, "TriggerDistance")  ~= nil then v.TriggerDistance  = 300   end
    if rawget(v, "DetectionRadius")  ~= nil then v.DetectionRadius  = 300   end
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
            -- Sort enemies by distance, cap at MAX_HIGHLIGHTS.
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
--    Each button owns a local isActive boolean.
--    The toggle logic runs OUTSIDE pcall so state is always flipped correctly.
--    Only the actual game-table write is wrapped in pcall.
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

-- ---- ESP Button ---- (simple toggle, no injection, starts ON)
local EspBtn = MakeButton("Full Body ESP", 0, COLOR_ON)
EspBtn.Text = "Full Body ESP: ON"
EspBtn.MouseButton1Click:Connect(function()
    Config.ESP_Enabled = not Config.ESP_Enabled
    EspBtn.Text             = "Full Body ESP: " .. (Config.ESP_Enabled and "ON" or "OFF")
    EspBtn.BackgroundColor3 = Config.ESP_Enabled and COLOR_ON or COLOR_OFF
end)

-- ---- Boost AutoFire Button ---- (injection toggle)
local FireBtn = MakeButton("Boost AutoFire", 1, COLOR_IDLE)
local fireActive = false

FireBtn.MouseButton1Click:Connect(function()
    -- 1. Flip the state FIRST — this always succeeds, UI is guaranteed to update.
    fireActive = not fireActive

    -- 2. Try to find the table and apply the corresponding values.
    local t = FindAutoFireTable()
    if t then
        if fireActive then
            pcall(ApplyAutoFireON, t)
        else
            pcall(ApplyAutoFireOFF, t)
        end
    else
        -- Table not found — revert state so button honestly shows it didn't work.
        fireActive = not fireActive
        warn("[Bloxstrike] AutoFire table not found in gc.")
    end

    -- 3. Update UI to match the final state.
    FireBtn.Text             = "Boost AutoFire: " .. (fireActive and "ON" or "OFF")
    FireBtn.BackgroundColor3 = fireActive and COLOR_ON or COLOR_IDLE
end)

-- ---- Max Velocity Button ---- (injection toggle)
local VelBtn = MakeButton("Max Velocity", 2, COLOR_IDLE)
local velActive = false

VelBtn.MouseButton1Click:Connect(function()
    -- 1. Flip state FIRST.
    velActive = not velActive

    -- 2. Find table and apply.
    local t = FindVelocityTable()
    if t then
        if velActive then
            pcall(ApplyVelocityON, t)
            -- Hook smoke bypass on first successful find.
            task.defer(HookSmoke)
        else
            pcall(ApplyVelocityOFF, t)
        end
    else
        -- Table not found — revert state.
        velActive = not velActive
        warn("[Bloxstrike] Velocity table not found in gc.")
    end

    -- 3. Update UI.
    VelBtn.Text             = "Max Velocity: " .. (velActive and "ON" or "OFF")
    VelBtn.BackgroundColor3 = velActive and COLOR_ON or COLOR_IDLE
end)

print("[Bloxstrike] v5 Loaded — Reliable Toggles + Aggressive Aim")
