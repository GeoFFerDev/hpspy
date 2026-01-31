-- BLOXSTRIKE TRUE ICON SUITE
-- Features: Full Body Highlight, Wall-Check Aimbot
-- Fixes: Minimize button now hides the menu completely and shows a movable Icon.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    Aimbot_Enabled = false,
    Aimbot_FOV = 120,       
    Aimbot_Smoothness = 0.2,
    Team_Check = true,      
    Enemy_Color = Color3.fromRGB(255, 0, 0), -- Red
    Team_Color = Color3.fromRGB(0, 255, 0)   -- Green
}

-- MEMORY
local Highlights = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM (Menu + Floating Icon)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- == THE FLOATING ICON ==
local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 50, 0, 50)
IconFrame.Position = UDim2.new(0.9, 0, 0.4, 0) -- Right side of screen
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false -- Hidden by default (Menu starts open)
IconFrame.Active = true
IconFrame.Draggable = true -- The icon moves!
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
IconButton.Text = "B"
IconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
IconButton.Font = Enum.Font.SourceSansBold
IconButton.TextSize = 28
IconButton.Parent = IconFrame

-- Make Icon Circular
local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0)
IconCorner.Parent = IconButton

-- == THE MAIN MENU ==
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 190)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Visible = true -- Menu starts visible
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

-- Minimize Button (On Menu)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

-- TOGGLE LOGIC
MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false  -- Hide Menu
    IconFrame.Visible = true   -- Show Icon
end)

IconButton.MouseButton1Click:Connect(function()
    IconFrame.Visible = false  -- Hide Icon
    MainFrame.Visible = true   -- Show Menu
end)

-- BUTTON CREATOR
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -30)
ContentFrame.Position = UDim2.new(0, 0, 0, 30)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local function CreateButton(name, order, click_func)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 35)
    btn.Position = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 14
    btn.Parent = ContentFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local newState = click_func()
        btn.Text = name .. ": " .. (newState and "ON" or "OFF")
        btn.BackgroundColor3 = newState and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
    end)
end

-- -------------------------------------------------------------------------
-- 2. TEAM LOGIC (The Fix)
-- -------------------------------------------------------------------------
local function IsTeammate(player)
    if not Config.Team_Check then return false end
    if player == LocalPlayer then return true end
    
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    
    if myTeam and theirTeam then
        return myTeam == theirTeam
    end
    
    -- Fallback: Use color check if attributes fail
    if player.TeamColor == LocalPlayer.TeamColor then
        return true
    end
    
    return false 
end

-- -------------------------------------------------------------------------
-- 3. VISIBILITY CHECK (Wall Check)
-- -------------------------------------------------------------------------
local function IsVisible(targetPart)
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local Result = workspace:Raycast(Origin, Direction, RayParams)
    if Result and Result.Instance:IsDescendantOf(targetPart.Parent) then
        return true
    end
    return Result == nil
end

-- -------------------------------------------------------------------------
-- 4. ESP (Highlight)
-- -------------------------------------------------------------------------
local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            
            if not Config.ESP_Enabled or not char or IsTeammate(player) then
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
                continue
            end
            
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
        end
    end
end

-- -------------------------------------------------------------------------
-- 5. AIMBOT
-- -------------------------------------------------------------------------
local function GetBestTarget()
    local closest = nil
    local maxDist = Config.Aimbot_FOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsTeammate(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") then
                local head = char.Head
                local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    local dist = (Vector2.new(vector.X, vector.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if dist < maxDist then
                        if IsVisible(head) then
                            maxDist = dist
                            closest = head
                        end
                    end
                end
            end
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    UpdateESP()
    
    if Config.Aimbot_Enabled then
        local target = GetBestTarget()
        if target then
            local current = Camera.CFrame
            local goal = CFrame.new(current.Position, target.Position)
            Camera.CFrame = current:Lerp(goal, Config.Aimbot_Smoothness)
        end
    end
end)

-- SETUP BUTTONS
CreateButton("Full Body ESP", 0, function() Config.ESP_Enabled = not Config.ESP_Enabled; return Config.ESP_Enabled end)
CreateButton("Aimbot (Safe)", 1, function() Config.Aimbot_Enabled = not Config.Aimbot_Enabled; return Config.Aimbot_Enabled end)
CreateButton("Team Check", 2, function() Config.Team_Check = not Config.Team_Check; return Config.Team_Check end)

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)

print("[Bloxstrike] Icon Suite Loaded")
