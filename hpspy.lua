-- BLOXSTRIKE FINAL MOBILE SUITE
-- Features: True Floating Icon, Enemy-Only Aimbot, Highlight ESP
-- Fixes: UI fully hides into an icon. Aimbot strictly ignores teammates.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- CONFIGURATION
local Config = {
    ESP_Enabled = true,      -- Shows red outline on enemies
    Aimbot_Enabled = false,  -- Locks camera on enemies
    Hide_Teammates = true,   -- CRITICAL: Keeps aimbot/ESP off your team
    Aimbot_FOV = 120,        -- Circle size (only aim near crosshair)
    Aimbot_Smooth = 0.2,     -- 0.1 = Fast, 0.5 = Smooth
    Enemy_Color = Color3.fromRGB(255, 0, 0) -- Red
}

-- MEMORY
local Highlights = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM (True Icon Mode)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- [A] THE FLOATING ICON (Hidden at start)
local IconFrame = Instance.new("Frame")
IconFrame.Size = UDim2.new(0, 45, 0, 45)
IconFrame.Position = UDim2.new(0.9, -50, 0.4, 0) -- Right side
IconFrame.BackgroundTransparency = 1
IconFrame.Visible = false 
IconFrame.Active = true
IconFrame.Draggable = true -- You can move this icon!
IconFrame.Parent = ScreenGui

local IconButton = Instance.new("TextButton")
IconButton.Size = UDim2.new(1, 0, 1, 0)
IconButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
IconButton.Text = "B"
IconButton.TextColor3 = Color3.fromRGB(255, 255, 255)
IconButton.Font = Enum.Font.SourceSansBold
IconButton.TextSize = 24
IconButton.Parent = IconFrame

local IconCorner = Instance.new("UICorner")
IconCorner.CornerRadius = UDim.new(1, 0) -- Circle shape
IconCorner.Parent = IconButton

-- [B] THE MAIN MENU (Visible at start)
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 200)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
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

-- Minimize Button (The "_" button)
local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 30, 0, 30)
MinBtn.Position = UDim2.new(1, -30, 0, 0)
MinBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinBtn.Text = "_"
MinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinBtn.Font = Enum.Font.SourceSansBold
MinBtn.TextSize = 20
MinBtn.Parent = TitleBar

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
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = ContentFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local newState = click_func()
        btn.Text = name .. ": " .. (newState and "ON" or "OFF")
        btn.BackgroundColor3 = newState and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
    end)
    return btn
end

-- -------------------------------------------------------------------------
-- 2. UI LOGIC (Switching between Icon and Menu)
-- -------------------------------------------------------------------------
MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false  -- Completely hide menu
    IconFrame.Visible = true   -- Show small icon
end)

IconButton.MouseButton1Click:Connect(function()
    IconFrame.Visible = false  -- Hide icon
    MainFrame.Visible = true   -- Show menu
end)

-- -------------------------------------------------------------------------
-- 3. TEAM CHECK (Aggressive)
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    -- 1. If Hide Teammates is OFF, everyone is an enemy (FFA Mode)
    if not Config.Hide_Teammates then return true end
    
    if player == LocalPlayer then return false end -- Never target self
    
    -- 2. Check Bloxstrike Attributes (Terrorists vs Counter-Terrorists)
    -- Source: CreateWeaponModel.lua 
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    
    if myTeam and theirTeam then
        -- If teams match, they are NOT an enemy.
        if myTeam == theirTeam then return false end
        -- If teams differ, they ARE an enemy.
        return true
    end
    
    -- 3. Fallback: Standard Roblox Teams
    if player.TeamColor == LocalPlayer.TeamColor then
        return false -- Same color = Teammate
    end
    
    return true -- If we can't tell, assume Enemy (Safety)
end

-- -------------------------------------------------------------------------
-- 4. VISIBILITY CHECK (Wall Check)
-- -------------------------------------------------------------------------
local function IsVisible(targetPart)
    local Origin = Camera.CFrame.Position
    local Direction = (targetPart.Position - Origin)
    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    
    local Result = workspace:Raycast(Origin, Direction, RayParams)
    
    -- If ray hits something, check if it's the enemy character
    if Result and Result.Instance:IsDescendantOf(targetPart.Parent) then
        return true
    end
    return Result == nil -- If ray hits nothing, path is clear
end

-- -------------------------------------------------------------------------
-- 5. AIMBOT & ESP LOOP
-- -------------------------------------------------------------------------
local function Update()
    local bestTarget = nil
    local maxDist = Config.Aimbot_FOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local isEnemy = IsEnemy(player)
            
            -- [ESP LOGIC]
            if Config.ESP_Enabled and char and isEnemy then
                if not Highlights[player] or Highlights[player].Parent ~= char then
                    local hl = Instance.new("Highlight")
                    hl.Name = "EnemyGlow"
                    hl.FillColor = Config.Enemy_Color
                    hl.OutlineColor = Config.Enemy_Color
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = char
                    Highlights[player] = hl
                end
            else
                -- Remove ESP if they are a teammate or ESP is off
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
            end
            
            -- [AIMBOT LOGIC]
            if Config.Aimbot_Enabled and isEnemy and char and char:FindFirstChild("Head") then
                local head = char.Head
                local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    -- Check distance from crosshair
                    local dist = (Vector2.new(vector.X, vector.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    
                    if dist < maxDist then
                        -- Check if behind wall
                        if IsVisible(head) then
                            maxDist = dist
                            bestTarget = head
                        end
                    end
                end
            end
        end
    end
    
    -- Apply Aim
    if bestTarget then
        local current = Camera.CFrame
        local goal = CFrame.new(current.Position, bestTarget.Position)
        Camera.CFrame = current:Lerp(goal, Config.Aimbot_Smooth)
    end
end

RunService.RenderStepped:Connect(Update)

-- -------------------------------------------------------------------------
-- 6. BUTTON SETUP
-- -------------------------------------------------------------------------
-- Button 1: ESP
CreateButton("Full Body ESP", 0, function() 
    Config.ESP_Enabled = not Config.ESP_Enabled 
    return Config.ESP_Enabled 
end)

-- Button 2: Aimbot
CreateButton("Aimbot (Safe)", 1, function() 
    Config.Aimbot_Enabled = not Config.Aimbot_Enabled 
    return Config.Aimbot_Enabled 
end)

-- Button 3: Hide Teammates (Defaults to ON)
local TeamBtn = CreateButton("Hide Teammates", 2, function() 
    Config.Hide_Teammates = not Config.Hide_Teammates 
    return Config.Hide_Teammates 
end)
-- Force update the button text to show it starts as ON
TeamBtn.Text = "Hide Teammates: ON"
TeamBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

-- Cleanup
Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)

print("[Bloxstrike] Final Suite Loaded")
