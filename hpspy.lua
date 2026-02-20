-- BLOXSTRIKE TARGET ASSIST SUITE (STABILITY-REFINED)
-- NOTE:
-- pcall is used ONLY for crash prevention, not stealth or anti-detection.

---------------------------------------------------------------------
-- SERVICES
---------------------------------------------------------------------
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local Config = {
    ESP_Enabled = true,
    AutoFire = false,
    Enemy_Color = Color3.fromRGB(255, 0, 0)
}

---------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------
local Highlights = {}
local SmokeHooked = false
local AimConfigInjected = false

---------------------------------------------------------------------
-- SAFE CALL (CRASH GUARD ONLY)
---------------------------------------------------------------------
local function SafeCall(fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[Velocity Suite] Runtime error suppressed:", err)
    end
end

---------------------------------------------------------------------
-- AIM CONFIG OVERRIDE (GUARDED)
---------------------------------------------------------------------
local function InjectAimOverride()
    if AimConfigInjected then
        return true
    end

    local foundTable = false

    SafeCall(function()
        local gc = getgc(true)
        if type(gc) ~= "table" then return end

        for _, v in ipairs(gc) do
            if type(v) == "table" then
                local ts = rawget(v, "TargetSelection")
                local mag = rawget(v, "Magnetism")
                local fric = rawget(v, "Friction")
                local recoil = rawget(v, "RecoilAssist")

                if ts and mag and fric and recoil then
                    -- Targeting
                    ts.MaxDistance = 10000
                    ts.MaxAngle = 6.28
                    if ts.CheckWalls ~= nil then ts.CheckWalls = false end
                    if ts.VisibleOnly ~= nil then ts.VisibleOnly = false end

                    -- Magnetism
                    mag.Enabled = true
                    mag.MaxDistance = 10000
                    mag.PullStrength = 25.0
                    mag.StopThreshold = 0
                    mag.MaxAngleHorizontal = 6.28
                    mag.MaxAngleVertical = 6.28

                    -- Friction
                    fric.Enabled = true
                    fric.BubbleRadius = 120.0
                    fric.MinSensitivity = 0.0001

                    -- Recoil
                    recoil.Enabled = true
                    recoil.ReductionAmount = 1.0

                    foundTable = true
                    AimConfigInjected = true
                    break
                end
            end
        end
    end)

    -- Smoke hook done separately to avoid partial state
    if not SmokeHooked then
        SafeCall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
                    hookfunction(v, function()
                        return false
                    end)
                    SmokeHooked = true
                    break
                end
            end
        end)
    end

    return foundTable
end

---------------------------------------------------------------------
-- TEAM CHECK (SAFE)
---------------------------------------------------------------------
local function IsEnemy(player)
    if not player or player == LocalPlayer then return false end
    local myTeam = LocalPlayer:GetAttribute("Team")
    local theirTeam = player:GetAttribute("Team")
    if myTeam == nil or theirTeam == nil then
        return false
    end
    return tostring(myTeam) ~= tostring(theirTeam)
end

---------------------------------------------------------------------
-- AUTO FIRE (DEFENSIVE)
---------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
    if not Config.AutoFire then return end

    local target = Mouse.Target
    if not target then return end

    local char = target.Parent
    if not char then return end

    local targetPlayer = Players:GetPlayerFromCharacter(char)
    if not targetPlayer or not IsEnemy(targetPlayer) then return end

    local character = LocalPlayer.Character
    if not character then return end

    local tool = character:FindFirstChildOfClass("Tool")
    if tool then
        tool:Activate()
    end
end)

---------------------------------------------------------------------
-- ESP LOOP (SAFE + THROTTLED)
---------------------------------------------------------------------
task.spawn(function()
    while task.wait(0.1) do
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
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if Highlights[player] then
        Highlights[player]:Destroy()
        Highlights[player] = nil
    end
end)

print("[Velocity Suite] Loaded (Stability Refined)")
