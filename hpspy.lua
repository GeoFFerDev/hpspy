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

---------------------------------------------------------------------
-- UI SYSTEM (UNCHANGED)
---------------------------------------------------------------------
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

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 220, 0, 260)
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
Title.Text = "VELOCITY MAX"
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

MinBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    IconFrame.Visible = true
end)

IconButton.MouseButton1Click:Connect(function()
    IconFrame.Visible = false
    MainFrame.Visible = true
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
