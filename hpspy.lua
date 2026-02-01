-- BLOXSTRIKE VELOCITY SUITE [MAX RAGE + TRIGGER]
-- Features: Instant Snap (12.0), 0% Recoil, Auto-Fire, Wall Bypass

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

-- SETTINGS
local Config = {
    ESP_Enabled = true,
    AutoFire = true,
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}

-- -------------------------------------------------------------------------
-- 1. UTILS & PROTECTION
-- -------------------------------------------------------------------------
local function ProtectExecution(func)
    local success, result = pcall(func)
    return success
end

local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

-- -------------------------------------------------------------------------
-- 2. TRIGGERBOT (Auto-Fire Logic)
-- -------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    if Config.AutoFire then
        local target = Mouse.Target
        if target and target.Parent then
            local character = target.Parent
            local player = Players:GetPlayerFromCharacter(character)
            
            -- If it's an enemy, simulate a click/firing
            if player and IsEnemy(player) then
                -- This triggers the game's internal tool activation
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                end
            end
        end
    end
end)

-- -------------------------------------------------------------------------
-- 3. THE RAGE INJECTION
-- -------------------------------------------------------------------------
local function InjectGodMode()
    local foundTable = false
    
    ProtectExecution(function()
        for i, v in pairs(getgc(true)) do
            if type(v) == "table" 
               and rawget(v, "TargetSelection") 
               and rawget(v, "Magnetism") 
               and rawget(v, "RecoilAssist") then
                
                -- [A] TARGET SELECTION
                v.TargetSelection.MaxDistance = 9999        
                v.TargetSelection.MaxAngle = 6.28 
                
                -- WALL BYPASS ATTEMPT
                if v.TargetSelection.CheckWalls ~= nil then v.TargetSelection.CheckWalls = false end
                if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end

                -- [B] MAGNETISM (Maximum Speed)
                v.Magnetism.Enabled = true
                v.Magnetism.MaxDistance = 9999
                v.Magnetism.PullStrength = 12.0 -- ULTRA SNAP
                v.Magnetism.StopThreshold = 0              
                v.Magnetism.MaxAngleHorizontal = 6.28      
                v.Magnetism.MaxAngleVertical = 6.28

                -- [C] FRICTION (Large Sticky Zone)
                v.Friction.Enabled = true
                v.Friction.BubbleRadius = 60.0 -- Aggressive sticky zone
                v.Friction.MinSensitivity = 0.0001 -- Lock mouse completely
                
                -- [D] NO RECOIL
                v.RecoilAssist.Enabled = true
                v.RecoilAssist.ReductionAmount = 1.0       

                foundTable = true
            end
        end

        -- Bypass Fog/Smoke
        for i, v in pairs(getgc()) do
            if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                hookfunction(v, function() return false end)
            end
        end
    end)
    
    return foundTable
end

-- -------------------------------------------------------------------------
-- 4. UI SYSTEM
-- -------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
if gethui then ScreenGui.Parent = gethui() else ScreenGui.Parent = CoreGui end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 220)
MainFrame.Position = UDim2.new(0.1, 0, 0.2, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
Title.Text = "VELOCITY RAGE"
Title.TextColor3 = Color3.fromRGB(255, 50, 50)
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 18
Title.Parent = MainFrame

local function Btn(name, order, func)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 40 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    b.Text = name; b.TextColor3 = Color3.fromRGB(255, 255, 255); b.Parent = MainFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
    b.MouseButton1Click:Connect(function()
        local s = func()
        b.BackgroundColor3 = s and Color3.fromRGB(200, 0, 0) or Color3.fromRGB(40, 40, 40)
    end)
    return b
end

Btn("Full ESP", 0, function() Config.ESP_Enabled = not Config.ESP_Enabled; return Config.ESP_Enabled end)
Btn("Auto-Fire", 1, function() Config.AutoFire = not Config.AutoFire; return Config.AutoFire end)
Btn("INJECT RAGE", 2, function() return InjectGodMode() end)

-- -------------------------------------------------------------------------
-- 5. ESP RENDER
-- -------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not Config.ESP_Enabled then 
        for _, h in pairs(Highlights) do h:Destroy() end
        table.clear(Highlights)
        return 
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and IsEnemy(player) then
            if not Highlights[player] then
                local hl = Instance.new("Highlight")
                hl.FillTransparency = 0.6; hl.OutlineTransparency = 0
                hl.FillColor = Config.Enemy_Color; hl.Parent = player.Character
                Highlights[player] = hl
            end
        end
    end
end)

print("[Bloxstrike] Rage Loaded. Auto-Fire Active.")
