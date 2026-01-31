-- BLOXSTRIKE POLISHED MOBILE SUITE
-- Features: Full Body Highlight Only, Wall-Check Aimbot, Minimized UI
-- Fixes: "Snapping" to walls prevents aiming at hidden enemies.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- SETTINGS
local Config = {
    ESP_Enabled = true,    -- Full Body Highlight
    Aimbot_Enabled = false,
    Aimbot_FOV = 120,      -- Smaller circle for better accuracy (aim closer to target to lock)
    Aimbot_Smoothness = 0.2, -- 0.1 = Snappy, 0.5 = Slow/Legit
    Team_Check = true,     -- Hides teammates
    Enemy_Color = Color3.fromRGB(255, 0, 0) -- Red
}

-- MEMORY
local Highlights = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. DRAGGABLE & MINIMIZABLE GUI
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

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
Title.Size = UDim2.new(0.8, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "BLOXSTRIKE SUITE"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

-- MINIMIZE BUTTON
local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 0)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinimizeBtn.Text = "-"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 20
MinimizeBtn.Parent = TitleBar

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, 0, 1, -30)
ContentFrame.Position = UDim2.new(0, 0, 0, 30)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

local IsMinimized = false
MinimizeBtn.MouseButton1Click:Connect(function()
    IsMinimized = not IsMinimized
    ContentFrame.Visible = not IsMinimized
    if IsMinimized then
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 30), "Out", "Quad", 0.3, true)
        MinimizeBtn.Text = "+"
        MinimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
    else
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 190), "Out", "Quad", 0.3, true)
        MinimizeBtn.Text = "-"
        MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end
end)

-- BUTTON CREATOR
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
    
    -- Rounded Corners
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 6)
    uiCorner.Parent = btn

    btn.MouseButton1Click:Connect(function()
        local newState = click_func()
        btn.Text = name .. ": " .. (newState and "ON" or "OFF")
        btn.BackgroundColor3 = newState and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(45, 45, 45)
    end)
    return btn
end

-- BUTTONS
CreateButton("Full Body ESP", 0, function() 
    Config.ESP_Enabled = not Config.ESP_Enabled 
    return Config.ESP_Enabled
end)

CreateButton("Aimbot (Visible Only)", 1, function() 
    Config.Aimbot_Enabled = not Config.Aimbot_Enabled 
    return Config.Aimbot_Enabled
end)

CreateButton("Team Check", 2, function() 
    Config.Team_Check = not Config.Team_Check 
    return Config.Team_Check
end)

-- -------------------------------------------------------------------------
-- 2. TEAM LOGIC (Attribute Check)
-- -------------------------------------------------------------------------
local function IsTeammate(player)
    if not Config.Team_Check then return false end
    if player == LocalPlayer then return true end
    
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    
    if myTeam and theirTeam then
        return myTeam == theirTeam
    end
    
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
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
    
    if Result then
        -- If we hit something, check if it is part of the enemy character
        if Result.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false -- We hit a wall
    end
    return true -- Nothing in the way
end

-- -------------------------------------------------------------------------
-- 4. ESP (Highlight Only)
-- -------------------------------------------------------------------------
local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            
            -- CLEANUP
            if not Config.ESP_Enabled or not char or not char:FindFirstChild("HumanoidRootPart") or IsTeammate(player) then
                if Highlights[player] then 
                    Highlights[player]:Destroy()
                    Highlights[player] = nil 
                end
                continue
            end
            
            -- APPLY HIGHLIGHT
            if not Highlights[player] or Highlights[player].Parent ~= char then
                local hl = Instance.new("Highlight")
                hl.Name = "ESPHighlight"
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
-- 5. AIMBOT (FOV + Visibility Check)
-- -------------------------------------------------------------------------
local function GetBestTarget()
    local closest = nil
    local maxDist = Config.Aimbot_FOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsTeammate(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") and char:FindFirstChild("HumanoidRootPart") then
                local head = char.Head
                
                -- 1. Screen Check
                local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                if onScreen then
                    -- 2. FOV Check (Distance from crosshair center)
                    local mouseDist = (Vector2.new(vector.X, vector.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    
                    if mouseDist < maxDist then
                        -- 3. Visibility Check (Raycast)
                        if IsVisible(head) then
                            maxDist = mouseDist
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
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(currentCF.Position, target.Position)
            -- Smooth Aim
            Camera.CFrame = currentCF:Lerp(targetCF, Config.Aimbot_Smoothness)
        end
    end
end)

Players.PlayerRemoving:Connect(function(p)
    if Highlights[p] then Highlights[p]:Destroy() end
end)

print("[Bloxstrike] Polished Suite Loaded")
