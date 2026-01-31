-- BLOXSTRIKE ULTIMATE MOBILE SUITE
-- Features: Full Body ESP (Highlight), Box ESP, Aimbot, Draggable Menu
-- Fixes: Uses accurate Attribute-based Team Check found in game files.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")

-- SETTINGS (Toggleable via Menu)
local Config = {
    ESP_Enabled = true,
    ESP_Highlight = true,  -- Full Body visible through walls
    ESP_Boxes = true,      -- 2D Boxes for info
    Aimbot_Enabled = false,
    Aimbot_FOV = 150,      -- Field of View circle size
    Team_Check = true,     -- Hides teammates (CRITICAL)
    Enemy_Color = Color3.fromRGB(255, 0, 0), -- Red
    Team_Color = Color3.fromRGB(0, 255, 0)   -- Green
}

-- MEMORY
local Highlights = {}
local Drawings = {}

-- -------------------------------------------------------------------------
-- 1. DRAGGABLE GUI SETUP (Mobile Friendly)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 220, 0, 180)
Frame.Position = UDim2.new(0.1, 0, 0.2, 0)
Frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Frame.BorderSizePixel = 0
Frame.Active = true
Frame.Draggable = true -- Allows moving it around
Frame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Title.Text = "BLOXSTRIKE MENU"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = Frame

-- Helper to make buttons
local function CreateButton(name, y_pos, click_func)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, y_pos)
    btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = Frame
    btn.MouseButton1Click:Connect(function()
        local newState = click_func()
        btn.Text = name .. ": " .. (newState and "ON" or "OFF")
        btn.BackgroundColor3 = newState and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(50, 50, 50)
    end)
    return btn
end

-- Create the Toggle Buttons
CreateButton("ESP (Wallhack)", 40, function() 
    Config.ESP_Enabled = not Config.ESP_Enabled 
    return Config.ESP_Enabled
end)

CreateButton("Aimbot (Safe)", 80, function() 
    Config.Aimbot_Enabled = not Config.Aimbot_Enabled 
    return Config.Aimbot_Enabled
end)

CreateButton("Team Check", 120, function() 
    Config.Team_Check = not Config.Team_Check 
    return Config.Team_Check
end)

-- -------------------------------------------------------------------------
-- 2. TEAM LOGIC (The "Fix" based on your logs)
-- -------------------------------------------------------------------------
local function IsTeammate(player)
    if not Config.Team_Check then return false end
    if player == LocalPlayer then return true end
    
    -- 1. Check Custom Attributes (Found in CreateWeaponModel.lua)
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    
    if myTeam and theirTeam then
        if myTeam == theirTeam then return true end
        return false
    end
    
    -- 2. Fallback to Standard Teams if Attributes fail
    if player.Team and LocalPlayer.Team then
        return player.Team == LocalPlayer.Team
    end
    
    return false -- Assume enemy if unsure (Safety)
end

-- -------------------------------------------------------------------------
-- 3. VISUALS (ESP + Highlight)
-- -------------------------------------------------------------------------
local function CreateHighlight(player)
    if Highlights[player] then return end
    
    local char = player.Character
    if not char then return end
    
    local hl = Instance.new("Highlight")
    hl.Name = "ESPHighlight"
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- See through walls
    hl.Parent = char
    
    Highlights[player] = hl
end

local function UpdateESP()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            
            -- CLEANUP: Remove ESP if disabled or invalid
            if not Config.ESP_Enabled or not char or not char:FindFirstChild("HumanoidRootPart") or IsTeammate(player) then
                if Highlights[player] then 
                    Highlights[player]:Destroy()
                    Highlights[player] = nil 
                end
                if Drawings[player] then
                    Drawings[player].Visible = false
                end
                continue
            end
            
            -- APPLY HIGHLIGHT (Full Body)
            if Config.ESP_Highlight then
                if not Highlights[player] or Highlights[player].Parent ~= char then
                    CreateHighlight(player)
                end
                if Highlights[player] then
                    Highlights[player].FillColor = Config.Enemy_Color
                    Highlights[player].OutlineColor = Config.Enemy_Color
                end
            end
            
            -- APPLY BOX (2D Info)
            if Config.ESP_Boxes then
                if not Drawings[player] then
                    local box = Drawing.new("Square")
                    box.Thickness = 1.5
                    box.Filled = false
                    Drawings[player] = box
                end
                
                local root = char.HumanoidRootPart
                local vector, onScreen = Camera:WorldToViewportPoint(root.Position)
                
                if onScreen then
                    local box = Drawings[player]
                    local dist = (Camera.CFrame.Position - root.Position).Magnitude
                    local size = 1500 / dist
                    
                    box.Size = Vector2.new(size, size * 1.5)
                    box.Position = Vector2.new(vector.X - size/2, vector.Y - size/2)
                    box.Color = Config.Enemy_Color
                    box.Visible = true
                else
                    Drawings[player].Visible = false
                end
            end
        end
    end
end

-- -------------------------------------------------------------------------
-- 4. AIMBOT LOGIC (Safe & Simple)
-- -------------------------------------------------------------------------
local function GetClosestTarget()
    local closest = nil
    local maxDist = Config.Aimbot_FOV
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and not IsTeammate(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") then
                local head = char.Head
                local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    local mouseDist = (Vector2.new(vector.X, vector.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if mouseDist < maxDist then
                        maxDist = mouseDist
                        closest = head
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
        local target = GetClosestTarget()
        if target then
            -- Smoothly aim at the head
            local currentCF = Camera.CFrame
            local targetCF = CFrame.new(currentCF.Position, target.Position)
            Camera.CFrame = currentCF:Lerp(targetCF, 0.2) -- 0.2 is smoothness (lower = smoother)
        end
    end
end)

-- CLEANUP ON LEAVE
Players.PlayerRemoving:Connect(function(p)
    if Highlights[p] then Highlights[p]:Destroy() end
    if Drawings[p] then Drawings[p]:Remove() end
end)

print("[Bloxstrike] Ultimate Suite Loaded!")
