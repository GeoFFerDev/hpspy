-- BLOXSTRIKE GHOST SUITE (100% VISUALS ONLY)
-- Removed: Aimbot, Triggerbot, RCS (These caused the ban)
-- Kept: Full Body Highlight, Safe Team Check, Floating Icon
-- Status: UNDETECTED (Read-Only)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    Hide_Teammates = true,   -- Default ON
    Invert_Teams = false,    -- Click if highlighting wrong people
    Enemy_Color = Color3.fromRGB(255, 0, 0), -- Red
    Team_Color = Color3.fromRGB(0, 255, 0)   -- Green
}

-- MEMORY
local Highlights = {}

-- -------------------------------------------------------------------------
-- 1. UI SYSTEM (Floating Icon)
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
-- Safe Parenting (Bypasses basic GUI detection)
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

-- [A] THE FLOATING ICON
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

-- SMOOTH DRAG LOGIC (Mobile Optimized)
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

-- [B] THE MAIN MENU
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 180) -- Smaller, cleaner
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
Title.Text = "BLOXSTRIKE GHOST"
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
    if not Config.Hide_Teammates then return true end
    if player == LocalPlayer then return false end
    
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    
    local isSameTeam = (myTeam == theirTeam)
    
    if Config.Invert_Teams then
        return isSameTeam 
    else
        return not isSameTeam
    end
end

-- -------------------------------------------------------------------------
-- 3. VISUALS (Highlight Only)
-- -------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            
            -- Only apply if ESP is ON, Character exists, and they are an ENEMY
            if Config.ESP_Enabled and char and IsEnemy(player) then
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
                -- Instantly remove if they become a teammate or ESP is off
                if Highlights[player] then Highlights[player]:Destroy(); Highlights[player] = nil end
            end
        end
    end
end)

-- -------------------------------------------------------------------------
-- 4. MENU BUTTONS
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

-- THE FIX BUTTONS
local InvBtn = Btn("Invert Team Check", 1, function() 
    Config.Invert_Teams = not Config.Invert_Teams
    return Config.Invert_Teams 
end)
InvBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)

local HideBtn = Btn("Hide Teammates", 2, function() 
    Config.Hide_Teammates = not Config.Hide_Teammates
    return Config.Hide_Teammates 
end)
HideBtn.Text = "Hide Teammates: ON"
HideBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

-- Cleanup
Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Ghost Suite Loaded")
