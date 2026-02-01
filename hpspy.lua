-- BLOXSTRIKE VELOCITY SUITE (MAX SPEED EDITION)
-- Features: Ultra-Fast Snap (25.0 Pull), Wide Active Zone (120 Radius), Wall Bypass, Auto-Fire.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    AutoFire = false, -- Toggle this ON via the GUI button
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local OriginalSettings = {} 

-- -------------------------------------------------------------------------
-- 1. ANTI-BAN (Crash Blocker)
-- -------------------------------------------------------------------------
local function ProtectExecution(func)
    local success, result = pcall(func)
    if not success then
        warn("[Bloxstrike] Stealth Mode: Prevented Error Report.")
    end
    return success
end

-- -------------------------------------------------------------------------
-- 2. THE MEMORY HIJACK (TUNED FOR MAX SPEED)
-- -------------------------------------------------------------------------
local function InjectGodMode()
    local foundTable = false
    
    ProtectExecution(function()
        -- STEP 1: Find the Master Settings Table
        for i, v in pairs(getgc(true)) do
            if type(v) == "table" 
               and rawget(v, "TargetSelection") 
               and rawget(v, "Magnetism") 
               and rawget(v, "RecoilAssist") 
               and rawget(v, "Friction") then
                
                -- [A] TARGETING (Wide FOV)
                v.TargetSelection.MaxDistance = 10000        
                v.TargetSelection.MaxAngle = 6.28 
                
                -- WALL BYPASS
                if v.TargetSelection.CheckWalls ~= nil then v.TargetSelection.CheckWalls = false end
                if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end

                -- [B] MAGNETISM (SPEED & SNAP)
                v.Magnetism.Enabled = true
                v.Magnetism.MaxDistance = 10000
                v.Magnetism.PullStrength = 25.0             -- DRASTICALLY INCREASED (Was 8.0). Moves instantly.
                v.Magnetism.StopThreshold = 0              
                v.Magnetism.MaxAngleHorizontal = 6.28       
                v.Magnetism.MaxAngleVertical = 6.28

                -- [C] FRICTION (RESPONSIVENESS)
                v.Friction.Enabled = true
                v.Friction.BubbleRadius = 120.0             -- INCREASED (Was 50.0). Activates as soon as enemy is near crosshair.
                v.Friction.MinSensitivity = 0.0001          -- Hard Lock
                
                -- [D] NO RECOIL
                v.RecoilAssist.Enabled = true
                v.RecoilAssist.ReductionAmount = 1.0        

                foundTable = true
            end
        end

        -- STEP 2: Bypass Smoke Check
        for i, v in pairs(getgc()) do
            if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                hookfunction(v, function() return false end)
            end
        end
    end)
    
    return foundTable
end

-- -------------------------------------------------------------------------
-- 3. UI SYSTEM
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

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

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 220) 
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
Title.Text = "VELOCITY MAX"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- MINIMIZE BUTTON
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 4. VISUALS & AUTO FIRE
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

RunService.RenderStepped:Connect(function()
    ProtectExecution(function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                
                -- AUTO FIRE LOGIC
                if Config.AutoFire and char and Mouse.Target and Mouse.Target.Parent == char and IsEnemy(player) then
                     local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                     if tool then tool:Activate() end
                end

                -- ESP LOGIC
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
end)

-- -------------------------------------------------------------------------
-- 5. BUTTONS
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

local TriggerBtn = Btn("Auto Fire", 1, function() Config.AutoFire = not Config.AutoFire; return Config.AutoFire end)
TriggerBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45); TriggerBtn.Text = "Auto Fire: OFF"

local RageBtn = Btn("Inject Max Velocity", 2, function() 
    local success = InjectGodMode()
    if success then return true else return false end
end)
RageBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 0); RageBtn.Text = "Inject Max Velocity"

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Max Speed Loaded")
