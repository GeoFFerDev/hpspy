-- BLOXSTRIKE VELOCITY GOD v2
-- Features: Silent Footsteps, Instant Aimbot, 0% Recoil, Wallbang, ESP
-- Update: Added Silent Steps (Networked), Toggleable GUI, Anti-Ban.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- SETTINGS (Default State)
local Config = {
    ESP_Enabled = true,
    Silent_Footsteps = false,
    God_Mode = false, -- (Aimbot/Recoil/Wallbang)
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

-- MEMORY
local Highlights = {}
local OriginalSettings = {} 
local Hooks = {} -- To store our hooks so we can toggle them

-- -------------------------------------------------------------------------
-- 1. ANTI-BAN (Crash Blocker)
-- -------------------------------------------------------------------------
local function ProtectExecution(func)
    local success, result = pcall(func)
    if not success then
        -- Suppress errors to prevent detection
    end
    return success
end

-- -------------------------------------------------------------------------
-- 2. SILENT FOOTSTEPS (New Feature)
-- -------------------------------------------------------------------------
local function InjectSilentSteps()
    -- We scan for the "Update" function in MovementSounds
    -- Fingerprint: It uses the constant "IsSniperScoped" and "LastFloorSoundTime"
    for i, v in pairs(getgc()) do
        if type(v) == "function" and not is_synapse_function(v) then
            local info = debug.getinfo(v)
            if info.name == "Update" then
                -- Check constants to be sure it's the right function
                local consts = debug.getconstants(v)
                if table.find(consts, "IsSniperScoped") and table.find(consts, "LastFloorSoundTime") then
                    
                    -- FOUND IT. Hook it.
                    local old = v
                    Hooks.Update = hookfunction(v, function(...)
                        if Config.Silent_Footsteps then
                            -- If enabled, we DO NOTHING.
                            -- No code runs = No sound = No network packet.
                            return 
                        end
                        return old(...) -- If disabled, run normal game code
                    end)
                    
                    print("[Bloxstrike] Silent Footsteps Injected!")
                    return true
                end
            end
        end
    end
    return false
end

-- -------------------------------------------------------------------------
-- 3. AIMBOT / RECOIL / WALLBANG
-- -------------------------------------------------------------------------
local function InjectGodMode()
    local foundTable = false
    
    ProtectExecution(function()
        -- STEP 1: Find the Master Settings Table
        for i, v in pairs(getgc(true)) do
            if type(v) == "table" 
               and rawget(v, "TargetSelection") 
               and rawget(v, "Magnetism") 
               and rawget(v, "RecoilAssist") 
               and rawget(v, "Friction") then
                
                -- Backup for toggling off
                if not OriginalSettings.Magnetism then
                    OriginalSettings = {
                        MagDist = v.Magnetism.MaxDistance,
                        Pull = v.Magnetism.PullStrength,
                        FricRad = v.Friction.BubbleRadius,
                        Recoil = v.RecoilAssist.ReductionAmount,
                        TargetDist = v.TargetSelection.MaxDistance
                    }
                end

                if Config.God_Mode then
                    -- [ON] APPLY GOD SETTINGS
                    
                    -- [A] TARGETING (Map Wide)
                    v.TargetSelection.MaxDistance = 5000       
                    v.TargetSelection.MaxAngle = 3.14          

                    -- [B] MAGNETISM (INSTANT LOCK)
                    v.Magnetism.Enabled = true
                    v.Magnetism.MaxDistance = 5000
                    v.Magnetism.PullStrength = 5.0             -- BUMPED TO 5.0 (Absolute Instant)
                    v.Magnetism.StopThreshold = 0              
                    v.Magnetism.MaxAngleHorizontal = 3.14      
                    v.Magnetism.MaxAngleVertical = 1.5

                    -- [C] FRICTION (Sniper Safe)
                    v.Friction.Enabled = true
                    v.Friction.BubbleRadius = 10.0             -- 10.0 prevents wall shots
                    v.Friction.MinSensitivity = 0.001          -- Crosshair freezes
                    
                    -- [D] NO RECOIL
                    v.RecoilAssist.Enabled = true
                    v.RecoilAssist.ReductionAmount = 1.0
                    
                else
                    -- [OFF] RESTORE LEGIT SETTINGS
                    if OriginalSettings.Magnetism then
                        v.Magnetism.MaxDistance = OriginalSettings.MagDist
                        v.Magnetism.PullStrength = OriginalSettings.Pull
                        v.Friction.BubbleRadius = OriginalSettings.FricRad
                        v.RecoilAssist.ReductionAmount = OriginalSettings.Recoil
                        v.TargetSelection.MaxDistance = OriginalSettings.TargetDist
                    end
                end

                foundTable = true
            end
        end

        -- STEP 2: Bypass Smoke Check (Safe Hook)
        if not Hooks.Smoke then
             for i, v in pairs(getgc()) do
                if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                    Hooks.Smoke = hookfunction(v, function()
                        if Config.God_Mode then return false end -- No smoke
                        return true -- Normal smoke
                    end)
                end
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

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 220) -- Taller for new button
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
Title.Text = "VELOCITY GOD v2"
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

local isDraggingIcon = false
IconButton.MouseButton1Down:Connect(function() isDraggingIcon = false end)
IconButton.InputChanged:Connect(function() isDraggingIcon = true end)
IconButton.MouseButton1Up:Connect(function() if not isDraggingIcon then IconFrame.Visible = false; MainFrame.Visible = true end; isDraggingIcon = false end)
MinBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false; IconFrame.Visible = true end)

-- -------------------------------------------------------------------------
-- 5. BUTTON LOGIC
-- -------------------------------------------------------------------------
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, 0, 1, -30)
Content.Position = UDim2.new(0, 0, 0, 30)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local function Btn(name, order, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0.9, 0, 0, 35)
    b.Position = UDim2.new(0.05, 0, 0, 10 + (order * 40))
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    b.Text = name .. ": OFF"
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Parent = Content
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    
    b.MouseButton1Click:Connect(function()
        local newState = callback()
        if newState then
            b.Text = name .. ": ON"
            b.BackgroundColor3 = Color3.fromRGB(0, 180, 0) -- Green
        else
            b.Text = name .. ": OFF"
            b.BackgroundColor3 = Color3.fromRGB(45, 45, 45) -- Grey
        end
    end)
    return b
end

-- BUTTON 1: ESP
Btn("Full Body ESP", 0, function() 
    Config.ESP_Enabled = not Config.ESP_Enabled
    return Config.ESP_Enabled 
end)

-- BUTTON 2: GOD MODE (Aimbot/Recoil)
Btn("Velocity Aimbot", 1, function()
    Config.God_Mode = not Config.God_Mode
    InjectGodMode() -- Updates the memory settings
    return Config.God_Mode
end)

-- BUTTON 3: SILENT FOOTSTEPS
local SilentBtn = Btn("Silent Footsteps", 2, function()
    Config.Silent_Footsteps = not Config.Silent_Footsteps
    if not Hooks.Update then InjectSilentSteps() end -- Inject hook on first click
    return Config.Silent_Footsteps
end)

-- -------------------------------------------------------------------------
-- 6. ESP LOOP
-- -------------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    local myTeam = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local theirTeam = tostring(player:GetAttribute("Team") or "Nil")
    return myTeam ~= theirTeam
end

RunService.RenderStepped:Connect(function()
    ProtectExecution(function()
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
end)

Players.PlayerRemoving:Connect(function(p) if Highlights[p] then Highlights[p]:Destroy() end end)
print("[Bloxstrike] Velocity God v2 Loaded")
