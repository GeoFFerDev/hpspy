-- BLOXSTRIKE FLOATING SUITE
-- Features: Floating Icon UI, Highlight ESP, Wall-Check Aimbot
-- Fixes: Corrected Team Logic (Prevents Aimbot from breaking when Team Check is ON)

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
    Aimbot_FOV = 120,       -- Circle size
    Aimbot_Smoothness = 0.2,-- Lower = Snappier
    Team_Check = true,      -- Set to TRUE. The fix below handles it.
    Enemy_Color = Color3.fromRGB(255, 0, 0), -- Red
    Team_Color = Color3.fromRGB(0, 255, 0)   -- Green
}

-- MEMORY
local Highlights = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. FLOATING UI SYSTEM
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- The Main Menu
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 200)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- The Floating Icon (Hidden by default)
local OpenButton = Instance.new("TextButton")
OpenButton.Size = UDim2.new(0, 45, 0, 45)
OpenButton.Position = UDim2.new(0.1, 0, 0.2, 0) -- Starts near menu
OpenButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
OpenButton.Text = "B"
OpenButton.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenButton.Font = Enum.Font.SourceSansBold
OpenButton.TextSize = 24
OpenButton.Visible = false
OpenButton.Active = true
OpenButton.Draggable = true -- You can move the icon!
OpenButton.Parent = ScreenGui

-- Rounded corners for Icon
local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0) -- Circle
UICorner.Parent = OpenButton

-- UI ELEMENTS
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 30)
TitleBar.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0.8, 0, 1, 0)
Title.Position = UDim2.new(0.05, 0, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "BLOXSTRIKE"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 30, 0, 30)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 0)
MinimizeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
MinimizeBtn.Text = "_"
MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
MinimizeBtn.Font = Enum.Font.SourceSansBold
MinimizeBtn.TextSize = 20
MinimizeBtn.Parent = TitleBar

-- TOGGLE LOGIC (Minimize/Maximize)
MinimizeBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenButton.Visible = true
    -- Move button to where the menu was (optional QOL)
    OpenButton.Position = MainFrame.Position
end)

OpenButton.MouseButton1Click:Connect(function()
    OpenButton.Visible = false
    MainFrame.Visible = true
    MainFrame.Position = OpenButton.Position
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
-- 2. FIXED TEAM LOGIC
-- -------------------------------------------------------------------------
local function IsTeammate(player)
    -- If Team Check is OFF, nobody is a teammate (Free For All logic)
    if not Config.Team_Check then return false end
    if player == LocalPlayer then return true end
    
    -- 1. ATTRIBUTE CHECK (The reliable method for Bloxstrike)
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    
    -- If both have a team attribute, compare them directly
    if myTeam and theirTeam then
        return myTeam == theirTeam
    end
    
    -- 2. TEAM COLOR FALLBACK (Only if attributes fail)
    -- We ignore the "Team" object and check color, which is usually safer
    if player.TeamColor == LocalPlayer.TeamColor then
        return true
    end
    
    -- 3. FAIL-SAFE
    -- If we can't determine the team, assume they are an ENEMY to be safe.
    -- (This fixes the "Aimbot stops working" bug)
    return false 
end

-- -------------------------------------------------------------------------
-- 3. VISIBILITY (WALL) CHECK
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
            
            -- REMOVE if: Disabled, No Character, or Is Teammate
            if not Config.ESP_Enabled or not char or IsTeammate(player) then
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
                continue
            end
            
            -- ADD Highlight
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
        -- Use the fixed IsTeammate check here
        if player ~= LocalPlayer and not IsTeammate(player) then
            local char = player.Character
            if char and char:FindFirstChild("Head") then
                local head = char.Head
                local vector, onScreen = Camera:WorldToViewportPoint(head.Position)
                
                if onScreen then
                    -- FOV Check
                    local dist = (Vector2.new(vector.X, vector.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                    if dist < maxDist then
                        -- Wall Check
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
CreateButton("Aimbot (Wall Check)", 1, function() Config.Aimbot_Enabled = not Config.Aimbot_Enabled; return Config.Aimbot_Enabled end)
CreateButton("Team Check", 2, function() Config.Team_Check = not Config.Team_Check; return Config.Team_Check end)

-- CLEANUP
Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)

print("[Bloxstrike] Floating Suite Active")
