-- BLOXSTRIKE VELOCITY GOD v10 (HEAD PRIORITY)
-- Fixes: Aim locking to Torso during movement/swiping.
-- Logic: High Friction Sensitivity allows crosshair to slide past torso, forcing Magnet to snap only to Head.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local Config = {
    ESP = false,
    Aimbot = false,
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local OriginalSettings = {} 
local Hooks = { SmokeCheck = nil }

-- -------------------------------------------------------------------------
-- 1. FPS BOOSTER
-- -------------------------------------------------------------------------
local function BoostFPS()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9
    Lighting.Brightness = 2
    for _, v in pairs(game:GetDescendants()) do
        if v:IsA("Texture") or v:IsA("Decal") or v:IsA("ParticleEmitter") then
            v:Destroy()
        elseif v:IsA("BasePart") and not v:IsA("MeshPart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        end
    end
end

-- -------------------------------------------------------------------------
-- 2. ACTIVE AIMBOT ENFORCER
-- -------------------------------------------------------------------------
local function EnforceGodSettings()
    pcall(function()
        for i, v in pairs(getgc(true)) do
            if type(v) == "table" 
               and rawget(v, "Magnetism") 
               and rawget(v, "RecoilAssist") then
                
                -- Backup Default Settings (Once)
                if not OriginalSettings.Magnetism then
                    OriginalSettings = {
                        MagDist = v.Magnetism.MaxDistance,
                        Pull = v.Magnetism.PullStrength,
                        FricRad = v.Friction.BubbleRadius,
                        Recoil = v.RecoilAssist.ReductionAmount,
                        TargetDist = v.TargetSelection.MaxDistance,
                        VertAngle = v.Magnetism.MaxAngleVertical,
                        RecoilReq = v.RecoilAssist.RequiresTarget,
                        FricSens = v.Friction.MinSensitivity
                    }
                end

                if Config.Aimbot then
                    -- UPDATE LOOP
                    if v.Magnetism.PullStrength ~= 8.5 then 
                        
                        -- [A] TARGETING
                        v.TargetSelection.MaxDistance = 5000       
                        v.TargetSelection.MaxAngle = 3.14          

                        -- [B] MAGNETISM (HEAD SNAP)
                        v.Magnetism.Enabled = true
                        v.Magnetism.MaxDistance = 5000
                        v.Magnetism.PullStrength = 8.5             -- MAX STRENGTH
                        v.Magnetism.StopThreshold = 0              
                        v.Magnetism.MaxAngleHorizontal = 3.14      
                        v.Magnetism.MaxAngleVertical = 4.0         

                        -- [C] FRICTION (TORSO REJECTION)
                        v.Friction.Enabled = true
                        v.Friction.BubbleRadius = 9.5              -- PRECISE BUBBLE (9.5).
                        v.Friction.MinSensitivity = 0.8            -- HIGH SENSITIVITY (0.8). Makes aim SLIP off the torso so it can snap to the head.
                        
                        -- [D] NO RECOIL
                        v.RecoilAssist.Enabled = true
                        v.RecoilAssist.ReductionAmount = 1.0
                        v.RecoilAssist.RequiresTarget = false
                    end
                elseif OriginalSettings.Magnetism then
                    -- Restore defaults
                    if v.Magnetism.PullStrength ~= OriginalSettings.Pull then
                        v.Magnetism.MaxDistance = OriginalSettings.MagDist
                        v.Magnetism.PullStrength = OriginalSettings.Pull
                        v.Friction.BubbleRadius = OriginalSettings.FricRad
                        v.RecoilAssist.ReductionAmount = OriginalSettings.Recoil
                        v.TargetSelection.MaxDistance = OriginalSettings.TargetDist
                        v.Magnetism.MaxAngleVertical = OriginalSettings.VertAngle
                        v.RecoilAssist.RequiresTarget = OriginalSettings.RecoilReq
                        v.Friction.MinSensitivity = OriginalSettings.FricSens
                    end
                end
            end
        end
    end)
end

-- Hook Smoke Check Once
local function InjectSmokeBypass()
    if Hooks.SmokeCheck then return end
    for i, v in pairs(getgc()) do
        if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
            Hooks.SmokeCheck = hookfunction(v, function()
                if Config.Aimbot then return false end
                return true
            end)
        end
    end
end

-- -------------------------------------------------------------------------
-- 3. GUI SYSTEM
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
IconButton.Text = "V10"
IconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
IconButton.Font = Enum.Font.SourceSansBold
IconButton.TextSize = 24
IconButton.Parent = IconFrame
Instance.new("UICorner", IconButton).CornerRadius = UDim.new(1, 0)

-- Dragging
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
MainFrame.Size = UDim2.new(0, 220, 0, 190)
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
Title.Text = "VELOCITY V10 (HEAD ONLY)"
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

local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 4. BUTTONS
-- -------------------------------------------------------------------------
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function CreateSwitch(name, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 45) 
    b.Text = name .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    b.MouseButton1Click:Connect(function()
        local newState = callback()
        if newState then
            b.Text = name .. ": ON"
            b.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
        else
            b.Text = name .. ": OFF"
            b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        end
    end)
    return b
end

-- [1] ESP
CreateSwitch("Full Body ESP", 0, function() 
    Config.ESP = not Config.ESP
    return Config.ESP 
end)

-- [2] AIMBOT
CreateSwitch("Active Aimbot", 1, function()
    Config.Aimbot = not Config.Aimbot
    if Config.Aimbot then InjectSmokeBypass() end
    return Config.Aimbot
end)

-- [3] FPS BOOST
local FPSBtn = Instance.new("TextButton")
FPSBtn.Size = UDim2.new(0.9, 0, 0, 35)
FPSBtn.Position = UDim2.new(0.05, 0, 0, 10 + (2 * 40))
FPSBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
FPSBtn.Text = "Boost FPS"
FPSBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FPSBtn.Parent = Content
Instance.new("UICorner", FPSBtn).CornerRadius = UDim.new(0, 6)
FPSBtn.MouseButton1Click:Connect(function()
    BoostFPS()
    FPSBtn.Text = "FPS Boosted!"
    FPSBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 0)
end)

-- -------------------------------------------------------------------------
-- 5. LOOPS
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

RunService.RenderStepped:Connect(function()
    EnforceGodSettings()

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if Config.ESP and char and IsEnemy(player) then
                if not Highlights[player] or Highlights[player].Parent ~= char then
                    local hl = Instance.new("Highlight")
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.FillColor = Config.Enemy_Color
                    hl.OutlineColor = Config.Enemy_Color
                    hl.Parent = char
                    Highlights[player] = hl
                end
            else
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Velocity God v10 Loaded")
