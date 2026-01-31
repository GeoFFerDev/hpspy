-- BLOXSTRIKE DIAGNOSTIC SUITE
-- Features: Triggerbot, RCS, ESP, Aimbot
-- Fixes: "Invert Team" button fixes the targeting logic instantly.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")

-- SETTINGS
local Config = {
    ESP_Enabled = false,
    Aimbot_Enabled = false,
    Triggerbot_Enabled = false,
    RCS_Enabled = false,
    Hide_Teammates = true,   -- Default ON (Logic can be flipped with button)
    Invert_Teams = false,    -- NEW: Flips the logic if it's broken
    
    Aimbot_FOV = 120,
    Aimbot_Smooth = 0.2,
    RCS_Strength = 0.6,
    Enemy_Color = Color3.fromRGB(255, 0, 0), -- Red
    Team_Color = Color3.fromRGB(0, 255, 0)   -- Green
}

-- MEMORY
local Highlights = {}
local EspText = {}
local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Exclude
RayParams.IgnoreWater = true

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM (True Icon Mode)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- [A] THE FLOATING ICON (Hidden by default, starts with Menu Open)
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

-- DRAG LOGIC (Mobile Friendly)
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

-- [B] THE MAIN MENU
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 240, 0, 300) -- Taller for extra button
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
Title.Text = "BLOXSTRIKE FIXED"
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

-- TOGGLE LOGIC
local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 2. CORE LOGIC (Safe Team Check)
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    -- If Hide Teammates is OFF, everyone is a target
    if not Config.Hide_Teammates then return true end
    if player == LocalPlayer then return false end
    
    -- Get Team Attributes (Safe String Conversion)
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    
    -- Debug Logic (Decides if they are same or different)
    local isSameTeam = (myTeam == theirTeam)
    
    -- If "Invert Teams" is ON, we flip the result
    if Config.Invert_Teams then
        return isSameTeam -- Treat Teammates as Enemies (Inverse)
    else
        return not isSameTeam -- Normal Mode: Different = Enemy
    end
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
-- 3. VISUALS (ESP Text + Highlight)
-- -------------------------------------------------------------------------
local function CreateESP(player, char)
    -- 1. Highlight
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
    
    -- 2. Text (For Debugging Teams)
    if not EspText[player] then
        local t = Drawing.new("Text")
        t.Size = 14
        t.Color = Color3.new(1,1,1)
        t.Center = true
        t.Outline = true
        EspText[player] = t
    end
    
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        local vec, onScreen = Camera:WorldToViewportPoint(root.Position)
        if onScreen then
            EspText[player].Position = Vector2.new(vec.X, vec.Y - 30)
            -- Show Team Name so you know why it's aiming/not aiming
            local teamName = tostring(player:GetAttribute("Team") or "NoTeam")
            EspText[player].Text = player.Name .. " [" .. teamName .. "]"
            EspText[player].Visible = true
        else
            EspText[player].Visible = false
        end
    end
end

local function ClearESP(player)
    if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
    if EspText[player] then EspText[player]:Remove(); EspText[player] = nil end
end

-- -------------------------------------------------------------------------
-- 4. AIMBOT & LOOP
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

-- TRIGGERBOT
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
            if tick() - LastFire > 0.1 then
                VirtualUser:Button1Down(Vector2.new(0,0), Camera.CFrame)
                LastFire = tick()
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
                CreateESP(player, char)
            else
                ClearESP(player)
            end
        end
    end
    
    -- AIMBOT
    if Config.Aimbot_Enabled then
        local target = GetBestTarget()
        if target then
            local current = Camera.CFrame
            local goal = CFrame.new(current.Position, target.Position)
            Camera.CFrame = current:Lerp(goal, Config.Aimbot_Smooth)
            if Config.RCS_Enabled then
                Camera.CFrame = Camera.CFrame * CFrame.Angles(-0.005 * Config.RCS_Strength, 0, 0)
            end
        end
    end
    
    -- TRIGGERBOT
    if Config.Triggerbot_Enabled then RunTriggerbot() end
end)

-- -------------------------------------------------------------------------
-- 5. MENU SETUP
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
Btn("Triggerbot", 2, function() Config.Triggerbot_Enabled = not Config.Triggerbot_Enabled; return Config.Triggerbot_Enabled end)
Btn("RCS (Recoil)", 3, function() Config.RCS_Enabled = not Config.RCS_Enabled; return Config.RCS_Enabled end)

-- THE FIX BUTTON
local InvBtn = Btn("Invert Team Check", 4, function() 
    Config.Invert_Teams = not Config.Invert_Teams
    return Config.Invert_Teams 
end)
InvBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0) -- Orange to stand out

-- Cleanup
Players.PlayerRemoving:Connect(function(p) ClearESP(p) end)
print("[Bloxstrike] Diagnostic Suite Loaded")
