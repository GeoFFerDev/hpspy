-- BLOXSTRIKE INTERNAL GOD SUITE
-- Features: Map-Wide Magnetism, 0% Recoil, Smoke Bypass, Sticky Aim, ESP
-- Method: Memory Hijack (Modifies AimAssistController Upvalues)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local OriginalSettings = {} 

-- -------------------------------------------------------------------------
-- 1. THE MEMORY HIJACK (The Core Logic)
-- -------------------------------------------------------------------------
local function InjectGodMode()
    local foundTable = false
    local foundSmoke = false
    
    -- STEP 1: Find the Master Settings Table in Garbage Collection
    -- We look for the exact structure found in 'Initialize.md' and 'findBestTarget.md'
    for i, v in pairs(getgc(true)) do
        if type(v) == "table" 
           and rawget(v, "TargetSelection") 
           and rawget(v, "Magnetism") 
           and rawget(v, "RecoilAssist") 
           and rawget(v, "Friction") then
            
            -- Backup Original Settings (Safety)
            if not OriginalSettings.Magnetism then
                OriginalSettings = {
                    MagDist = v.Magnetism.MaxDistance,
                    Pull = v.Magnetism.PullStrength,
                    FricRad = v.Friction.BubbleRadius,
                    Recoil = v.RecoilAssist.ReductionAmount
                }
            end

            -- [A] TARGETING (See Everyone)
            -- Source: findBestTarget.md (Line 200)
            v.TargetSelection.MaxDistance = 5000       -- Was 125. Now covers entire map.
            v.TargetSelection.MaxAngle = 3.14          -- Was ~0.5. Now 180 degrees (Look behind you).

            -- [B] MAGNETISM (Strong Lock)
            -- Source: GetMagnetismRotation.md (Line 543)
            v.Magnetism.Enabled = true
            v.Magnetism.MaxDistance = 5000
            v.Magnetism.PullStrength = 1.0             -- Was 0.11. Now Maximum Strength.
            v.Magnetism.StopThreshold = 0              -- Never stops pulling.
            v.Magnetism.MaxAngleHorizontal = 3.14      -- 360 lock.
            v.Magnetism.MaxAngleVertical = 1.5

            -- [C] FRICTION (Sticky Aim)
            -- Source: GetFrictionMultiplier.md (Line 363)
            v.Friction.Enabled = true
            v.Friction.BubbleRadius = 25.0             -- Huge sticky hitbox (Was 2.4).
            v.Friction.MinSensitivity = 0.05           -- Crosshair "freezes" on enemy.
            
            -- [D] NO RECOIL (Native)
            -- Source: GetRecoilAssistMultiplier.md (Line 581)
            v.RecoilAssist.Enabled = true
            v.RecoilAssist.ReductionAmount = 1.0       -- Was 0.5 (50%). Now 1.0 (100% Reduction).

            foundTable = true
        end
    end

    -- STEP 2: Bypass Smoke Check
    -- Source: doesRaycastIntersectSmoke.md (Line 44)
    -- We find the function and force it to return FALSE
    for i, v in pairs(getgc()) do
        if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
            hookfunction(v, function()
                return false -- "No smoke detected, boss!"
            end)
            foundSmoke = true
        end
    end
    
    return foundTable
end

-- -------------------------------------------------------------------------
-- 2. UI SYSTEM (Floating Icon)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- [A] FLOATING ICON
local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.9, -60, 0.4, 0)
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false 
IconFrame.Active = true
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
IconButton.Text = "B"
IconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
IconButton.Font = Enum.Font.SourceSansBold
IconButton.TextSize = 24
IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(1, 0)

-- DRAG LOGIC
local dragging, dragInput, dragStart, startPos
local function update(input)
    local delta = input.Position - dragStart
    IconFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
IconButton.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = IconFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
IconButton.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
game:GetService("UserInputService").InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)

-- [B] MAIN MENU
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 180)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.7, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "INTERNAL GOD"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

-- UI TOGGLE
local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 3. VISUALS (Full Body ESP)
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    -- Native Attribute Team Check
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

RunService.RenderStepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if Config.ESP_Enabled and char and IsEnemy(player) then
                if not Highlights[player] or Highlights[player].Parent ~= char then
                    local hl = Instance.new("Highlight")
                    hl.FillTransparency = 0.5; hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillColor = Config.Enemy_Color; hl.OutlineColor = Config.Enemy_Color; hl.Parent = char
                    Highlights[player] = hl
                end
            else
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
            end
        end
    end
end)

-- -------------------------------------------------------------------------
-- 4. BUTTONS
-- -------------------------------------------------------------------------
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function Btn(name, order, func)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    b.Text = name; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseButton1Click:Connect(function()
        local s = func()
        b.Text = name .. ": " .. (s and "ON" or "OFF")
        b.BackgroundColor3 = s and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
    end)
    return b
end

local EspBtn = Btn("Full Body ESP", 0, function() Config.ESP_Enabled = not Config.ESP_Enabled; return Config.ESP_Enabled end)
EspBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0); EspBtn.Text = "Full Body ESP: ON"

local RageBtn = Btn("Inject God Settings", 1, function() 
    local success = InjectGodMode()
    if success then
        return true -- Button turns green
    else
        return false -- Button stays grey (Retry)
    end
end)
RageBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 0); RageBtn.Text = "Inject God Settings"

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Internal God Loaded")
