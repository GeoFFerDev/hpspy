-- BLOXSTRIKE STICKY SUITE
-- Features: Sticky Aim (Prevents Shaking), Hard Lock, True Icon UI
-- Fixes: Lock refuses to switch targets until the current one is dead.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    Aimbot_Enabled = true,
    
    Aimbot_FOV = 100,        -- Circle size
    Aimbot_Speed = 0.5,      -- 0.5 = VERY STRONG LOCK (Was 0.25)
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local LockedTarget = nil -- The "Sticky" Variable
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- VISUAL FOV CIRCLE
local FovCircle = Drawing.new("Circle")
FovCircle.Visible = true
FovCircle.Radius = Config.Aimbot_FOV
FovCircle.Color = Color3.fromRGB(255, 255, 255)
FovCircle.Thickness = 1.5
FovCircle.Transparency = 0.5
FovCircle.Filled = false
FovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM
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
Title.Text = "BLOXSTRIKE"
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
-- 2. CORE LOGIC
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    if myTeam == theirTeam then return false end
    return true
end

local function IsVisible(targetPart)
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local Result = workspace:Raycast(Origin, Direction, RayParams)
    
    if Result then
        if Result.Instance.Transparency > 0.5 or Result.Instance.CanCollide == false then return true end
        if Result.Instance:IsDescendantOf(targetPart.Parent) then return true end
        return false 
    end
    return true
end

-- -------------------------------------------------------------------------
-- 3. STICKY TARGET LOGIC
-- -------------------------------------------------------------------------
local function GetNewTarget()
    local closest, maxDist = nil, Config.Aimbot_FOV
    
    -- Update FOV Circle
    FovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FovCircle.Visible = Config.Aimbot_Enabled
    
    for _, player in pairs(Players:GetPlayers()) do
        if IsEnemy(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") then
                local head = char.Head
                local vec, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(vec.X, vec.Y) - FovCircle.Position).Magnitude
                    if dist < maxDist and IsVisible(head) then
                        maxDist = dist
                        closest = head
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    -- AIMBOT LOGIC
    if Config.Aimbot_Enabled then
        
        -- 1. Check if we still have a valid Locked Target
        if LockedTarget then
            local char = LockedTarget.Parent
            local hum = char and char:FindFirstChild("Humanoid")
            
            -- CONDITIONS TO LOSE TARGET:
            -- Dead, Null, or Behind Wall
            if not char or not LockedTarget.Parent or (hum and hum.Health <= 0) or not IsVisible(LockedTarget) then
                LockedTarget = nil -- Reset target
            else
                -- Target is valid! Check FOV
                local vec, onScreen = Camera:WorldToViewportPoint(LockedTarget.Position)
                local dist = (Vector2.new(vec.X, vec.Y) - FovCircle.Position).Magnitude
                if not onScreen or dist > Config.Aimbot_FOV then
                    LockedTarget = nil -- Target left the circle
                end
            end
        end
        
        -- 2. If no target, find a new one
        if not LockedTarget then
            LockedTarget = GetNewTarget()
        end
        
        -- 3. AIM AT TARGET
        if LockedTarget then
            local current = Camera.CFrame
            -- Direct Head Aim (No Offset = Harder Lock)
            local goal = CFrame.new(current.Position, LockedTarget.Position)
            Camera.CFrame = current:Lerp(goal, Config.Aimbot_Speed)
        end
    else
        FovCircle.Visible = false
        LockedTarget = nil
    end

    -- ESP LOGIC
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

local AimBtn = Btn("Sticky Aimbot", 1, function() Config.Aimbot_Enabled = not Config.Aimbot_Enabled; return Config.Aimbot_Enabled end)
AimBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0); AimBtn.Text = "Sticky Aimbot: ON"

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Sticky Suite Loaded")
