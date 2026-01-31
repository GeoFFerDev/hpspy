-- BLOXSTRIKE OMNI-SUITE
-- Features: Triggerbot (Auto Shoot), RCS (Recoil Control), ESP, Aimbot
-- UI: True Floating Icon (Draggable)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    Aimbot_Enabled = false,
    Triggerbot_Enabled = false, -- AUTO SHOOT
    RCS_Enabled = false,        -- RECOIL CONTROL
    Hide_Teammates = true,
    
    Aimbot_FOV = 120,
    Aimbot_Smooth = 0.2,
    RCS_Strength = 0.5,         -- How hard to pull down (0.1 - 1.0)
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM (Floating Icon)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.8, 0, 0.4, 0)
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
UserInputService.InputChanged:Connect(function(input) if input == dragInput and dragging then update(input) end end)

-- MAIN MENU
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 260) -- Taller for new buttons
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
Title.Text = "BLOXSTRIKE OMNI"
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

-- TOGGLE UI
local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 2. CORE LOGIC (Teams, Visibility)
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if not Config.Hide_Teammates then return true end
    if player == LocalPlayer then return false end
    
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    if myTeam and theirTeam then return myTeam ~= theirTeam end
    if player.TeamColor == LocalPlayer.TeamColor then return false end
    return true
end

local function IsVisible(targetPart)
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local Result = workspace:Raycast(Origin, Direction, RayParams)
    if Result and Result.Instance:IsDescendantOf(targetPart.Parent) then return true end
    return Result == nil
end

-- -------------------------------------------------------------------------
-- 3. FEATURES (Triggerbot, RCS, ESP, Aimbot)
-- -------------------------------------------------------------------------
local function GetBestTarget()
    local closest, maxDist = nil, Config.Aimbot_FOV
    for _, player in pairs(Players:GetPlayers()) do
        if IsEnemy(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") then
                local head = char.Head
                local vec, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    local dist = (Vector2.new(vec.X, vec.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
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

-- TRIGGERBOT LOGIC
local LastFire = 0
local function RunTriggerbot()
    local Center = Camera.ViewportSize / 2
    local Ray = Camera:ViewportPointToRay(Center.X, Center.Y)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local Result = workspace:Raycast(Ray.Origin, Ray.Direction * 1000, RayParams)
    
    if Result and Result.Instance and Result.Instance.Parent then
        local Model = Result.Instance.Parent
        local Player = Players:GetPlayerFromCharacter(Model)
        
        if Player and IsEnemy(Player) then
            -- Shoot!
            if tick() - LastFire > 0.1 then -- Fire rate limit
                VirtualUser:Button1Down(Vector2.new(0,0), Camera.CFrame)
                LastFire = tick()
                -- Release quickly
                task.delay(0.05, function() VirtualUser:Button1Up(Vector2.new(0,0), Camera.CFrame) end)
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    -- ESP UPDATE
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
    
    -- AIMBOT & RCS
    if Config.Aimbot_Enabled then
        local target = GetBestTarget()
        if target then
            local current = Camera.CFrame
            local goal = CFrame.new(current.Position, target.Position)
            Camera.CFrame = current:Lerp(goal, Config.Aimbot_Smooth)
            
            -- RCS (Drag Down Logic)
            if Config.RCS_Enabled then
                Camera.CFrame = Camera.CFrame * CFrame.Angles(-0.005 * Config.RCS_Strength, 0, 0)
            end
        end
    end
    
    -- TRIGGERBOT
    if Config.Triggerbot_Enabled then
        RunTriggerbot()
    end
end)

-- -------------------------------------------------------------------------
-- 4. MENU SETUP
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

Btn("Full Body ESP", 0, function() Config.ESP_Enabled = not Config.ESP_Enabled; return Config.ESP_Enabled end)
Btn("Aimbot (Safe)", 1, function() Config.Aimbot_Enabled = not Config.Aimbot_Enabled; return Config.Aimbot_Enabled end)
Btn("Triggerbot (Auto Fire)", 2, function() Config.Triggerbot_Enabled = not Config.Triggerbot_Enabled; return Config.Triggerbot_Enabled end)
Btn("RCS (Anti-Recoil)", 3, function() Config.RCS_Enabled = not Config.RCS_Enabled; return Config.RCS_Enabled end)
local tBtn = Btn("Hide Teammates", 4, function() Config.Hide_Teammates = not Config.Hide_Teammates; return Config.Hide_Teammates end)
tBtn.Text = "Hide Teammates: ON"; tBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Omni-Suite Loaded")
