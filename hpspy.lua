-- BLOXSTRIKE VELOCITY SUITE (WORKING + STUTTER PROFILING)
-- Based on LAST CONFIRMED WORKING BUILD
-- Profiling is READ-ONLY (no behavior change)

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local Config = {
    ESP_Enabled = true,
    AutoFire = false,
    FPS_Boosted = false,
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local Highlights = {}
local OriginalTech = Lighting.Technology
local FPSConnection = nil

---------------------------------------------------------------------
-- CRASH GUARD (NOT ANTI-BAN)
---------------------------------------------------------------------
local function ProtectExecution(func)
    local ok, err = pcall(func)
    if not ok then
        warn("[Velocity] Runtime error suppressed:", err)
    end
end

---------------------------------------------------------------------
-- FRAME-TIME STUTTER MONITOR (SAFE)
---------------------------------------------------------------------
local lastFrame = os.clock()
RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local delta = now - lastFrame
    lastFrame = now

    if delta > 0.05 then
        warn(string.format("[STUTTER] Frame spike: %.2f ms", delta * 1000))
    end
end)

---------------------------------------------------------------------
-- AIM CONFIG OVERRIDE (UNCHANGED)
---------------------------------------------------------------------
local function InjectGodMode()
    local foundTable = false
    local hookedSmoke = false

    ProtectExecution(function()
        local gc = getgc(true)
        for i = 1, #gc do
            local v = gc[i]

            if type(v) == "table" and not foundTable then
                if rawget(v, "TargetSelection")
                and rawget(v, "Magnetism")
                and rawget(v, "RecoilAssist")
                and rawget(v, "Friction") then

                    v.TargetSelection.MaxDistance = 10000
                    v.TargetSelection.MaxAngle = 6.28
                    if v.TargetSelection.CheckWalls ~= nil then v.TargetSelection.CheckWalls = false end
                    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end

                    v.Magnetism.Enabled = true
                    v.Magnetism.MaxDistance = 10000
                    v.Magnetism.PullStrength = 25.0
                    v.Magnetism.StopThreshold = 0
                    v.Magnetism.MaxAngleHorizontal = 6.28
                    v.Magnetism.MaxAngleVertical = 6.28

                    v.Friction.Enabled = true
                    v.Friction.BubbleRadius = 120.0
                    v.Friction.MinSensitivity = 0.0001

                    v.RecoilAssist.Enabled = true
                    v.RecoilAssist.ReductionAmount = 1.0

                    foundTable = true
                end
            elseif type(v) == "function" and not hookedSmoke then
                if debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                    hookfunction(v, function() return false end)
                    hookedSmoke = true
                end
            end

            if foundTable and hookedSmoke then
                break
            end
        end
    end)

    return foundTable
end

-- =========================
-- VELOCITY MAX UI CORE
-- =========================

local CoreGui = game:GetService("CoreGui")
local UIS = game:GetService("UserInputService")

pcall(function()
    CoreGui:FindFirstChild("VelocityMaxUI"):Destroy()
end)

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "VelocityMaxUI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 320)
MainFrame.Position = UDim2.new(0.1, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20,20,20)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1,0,0,36)
TitleBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1,-40,1,0)
TitleText.Position = UDim2.new(0,10,0,0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "VELOCITY MAX"
TitleText.TextColor3 = Color3.new(1,1,1)
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 18
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = TitleBar

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0,36,0,36)
MinBtn.Position = UDim2.new(1,-36,0,0)
MinBtn.Text = "-"
MinBtn.TextSize = 22
MinBtn.BackgroundColor3 = Color3.fromRGB(170,40,40)
MinBtn.TextColor3 = Color3.new(1,1,1)
MinBtn.Parent = TitleBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1,0,1,-36)
Content.Position = UDim2.new(0,0,0,36)
Content.BackgroundTransparency = 1
Content.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.Padding = UDim.new(0,8)
UIList.Parent = Content

local Padding = Instance.new("UIPadding")
Padding.PaddingTop = UDim.new(0,10)
Padding.PaddingLeft = UDim.new(0,10)
Padding.PaddingRight = UDim.new(0,10)
Padding.Parent = Content

-- BUTTON FACTORY
local function Button(text, callback)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,0,0,40)
    b.BackgroundColor3 = Color3.fromRGB(45,45,45)
    b.Text = text
    b.TextColor3 = Color3.new(1,1,1)
    b.Font = Enum.Font.SourceSans
    b.TextSize = 16
    b.Parent = Content

    b.MouseButton1Click:Connect(function()
        if callback then callback() end
    end)
end

-- 🔗 CONNECT THESE TO YOUR EXISTING LOGIC
Button("ESP", function()
    Config.ESP_Enabled = not Config.ESP_Enabled
end)

Button("Auto Fire", function()
    Config.AutoFire = not Config.AutoFire
end)

Button("Close", function()
    ScreenGui:Destroy()
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    Content.Visible = not minimized
    MinBtn.Text = minimized and "+" or "-"
end)

-- DRAG (MOBILE SAFE)
local dragging, dragStart, startPos

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement
    ) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch
    or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

---------------------------------------------------------------------
-- TEAM CHECK
---------------------------------------------------------------------
local function IsEnemy(player)
    if player == LocalPlayer then return false end
    return tostring(LocalPlayer:GetAttribute("Team"))
        ~= tostring(player:GetAttribute("Team"))
end

---------------------------------------------------------------------
-- AUTO FIRE
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not Config.AutoFire then return end
    ProtectExecution(function()
        local target = Mouse.Target
        if target then
            local player = Players:GetPlayerFromCharacter(target.Parent)
            if player and IsEnemy(player) then
                local tool = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then tool:Activate() end
            end
        end
    end)
end)

---------------------------------------------------------------------
-- ESP LOOP + COST LOG
---------------------------------------------------------------------
task.spawn(function()
    while task.wait(0.1) do
        local start = os.clock()
        ProtectExecution(function()
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    local char = player.Character
                    if Config.ESP_Enabled and char and IsEnemy(player) then
                        if not Highlights[player] then
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
                        if Highlights[player] then
                            Highlights[player]:Destroy()
                            Highlights[player] = nil
                        end
                    end
                end
            end
        end)

        local cost = os.clock() - start
        if cost > 0.02 then
            warn(string.format("[ESP] Loop cost: %.2f ms", cost * 1000))
        end
    end
end)

print("[Velocity] Loaded (Working + Profiling)")
