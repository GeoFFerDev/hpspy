-- ═══════════════════════════════════════════════════════════════
--  KEY SYSTEM
-- ═══════════════════════════════════════════════════════════════
local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local HttpService      = game:GetService("HttpService")
local player           = Players.LocalPlayer

local API_URL = "https://script.google.com/macros/s/AKfycbxiWu05gsDeIBwe9qLvdb55Udxz3zn6oCA8sREjXgfwJmmw3UgNh1Ugl_vDm50ow0UhZw/exec"
local HWID    = tostring(player.UserId)

local function httpGet(url)
    local ok, res = pcall(function()
        return request({
            Url     = url,
            Method  = "GET",
            Headers = {
                ["User-Agent"] = "Mozilla/5.0",
                ["Accept"]     = "application/json"
            }
        })
    end)
    if ok and res and res.Body then return res.Body end
    return game:GetService("HttpService"):GetAsync(url)
end

local guiTarget = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and CoreGui)
    or player:WaitForChild("PlayerGui")

-- ── Key gate UI ───────────────────────────────────────────────
local keyGui = Instance.new("ScreenGui")
keyGui.Name           = "UI_KeyGate"
keyGui.IgnoreGuiInset = true
keyGui.ResetOnSpawn   = false
keyGui.Parent         = guiTarget

local bg2 = Instance.new("Frame", keyGui)
bg2.Size                   = UDim2.new(1,0,1,0)
bg2.BackgroundColor3       = Color3.fromRGB(4,5,9)
bg2.BackgroundTransparency = 0.45
bg2.BorderSizePixel        = 0

local panel = Instance.new("Frame", bg2)
panel.Size             = UDim2.new(0,360,0,250)
panel.Position         = UDim2.new(0.5,-180,0.5,-125)
panel.BackgroundColor3 = Color3.fromRGB(18,20,26)
panel.BorderSizePixel  = 0
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,10)
local ps = Instance.new("UIStroke", panel)
ps.Color = Color3.fromRGB(0,170,120) ; ps.Thickness = 1.5

local hdr = Instance.new("TextLabel", panel)
hdr.Size                  = UDim2.new(1,0,0,44)
hdr.BackgroundTransparency = 1
hdr.Text                  = "🔑  KEY REQUIRED"
hdr.TextColor3            = Color3.fromRGB(0,200,140)
hdr.Font                  = Enum.Font.GothamBlack
hdr.TextSize              = 18

local infoLbl = Instance.new("TextLabel", panel)
infoLbl.Size               = UDim2.new(1,-20,0,36)
infoLbl.Position           = UDim2.new(0,10,0,46)
infoLbl.BackgroundTransparency = 1
infoLbl.Text               = "Complete all steps on LootLabs, then\ncopy the key from the destination page."
infoLbl.TextColor3         = Color3.fromRGB(140,140,140)
infoLbl.Font               = Enum.Font.Gotham
infoLbl.TextSize           = 12
infoLbl.TextWrapped        = true

local linkBtn = Instance.new("TextButton", panel)
linkBtn.Size             = UDim2.new(1,-20,0,34)
linkBtn.Position         = UDim2.new(0,10,0,88)
linkBtn.BackgroundColor3 = Color3.fromRGB(0,100,72)
linkBtn.Text             = "🌐  Open LootLabs"
linkBtn.TextColor3       = Color3.fromRGB(220,255,240)
linkBtn.Font             = Enum.Font.GothamBold
linkBtn.TextSize         = 13
Instance.new("UICorner", linkBtn).CornerRadius = UDim.new(0,6)
linkBtn.MouseButton1Click:Connect(function()
    pcall(function() setclipboard("YOUR_LOOTLABS_LINK_HERE") end)
    infoLbl.Text = "✅ Link copied! Open in browser, finish steps, copy the key."
end)

local box = Instance.new("TextBox", panel)
box.Size               = UDim2.new(1,-20,0,34)
box.Position           = UDim2.new(0,10,0,132)
box.BackgroundColor3   = Color3.fromRGB(10,12,18)
box.TextColor3         = Color3.fromRGB(220,255,240)
box.PlaceholderText    = "Paste key here..."
box.PlaceholderColor3  = Color3.fromRGB(60,70,60)
box.Font               = Enum.Font.Code
box.TextSize           = 13
box.ClearTextOnFocus   = false
box.Text = ""
Instance.new("UICorner", box).CornerRadius = UDim.new(0,6)
local bs = Instance.new("UIStroke", box)
bs.Color = Color3.fromRGB(0,170,120) ; bs.Thickness = 1

local statusLbl = Instance.new("TextLabel", panel)
statusLbl.Size               = UDim2.new(1,-20,0,18)
statusLbl.Position           = UDim2.new(0,10,0,174)
statusLbl.BackgroundTransparency = 1
statusLbl.Text               = ""
statusLbl.TextColor3         = Color3.fromRGB(215,55,55)
statusLbl.Font               = Enum.Font.Code
statusLbl.TextSize           = 11

local submitBtn = Instance.new("TextButton", panel)
submitBtn.Size             = UDim2.new(1,-20,0,34)
submitBtn.Position         = UDim2.new(0,10,0,200)
submitBtn.BackgroundColor3 = Color3.fromRGB(0,170,120)
submitBtn.Text             = "Submit Key"
submitBtn.TextColor3       = Color3.fromRGB(255,255,255)
submitBtn.Font             = Enum.Font.GothamBold
submitBtn.TextSize         = 14
Instance.new("UICorner", submitBtn).CornerRadius = UDim.new(0,6)

local function ValidateKey(inputKey)
    inputKey = inputKey:gsub("%s+","")
    if inputKey == "" then
        statusLbl.Text      = "⚠ Please enter a key."
        statusLbl.TextColor3 = Color3.fromRGB(255,152,0)
        return false
    end
    statusLbl.Text       = "⏳ Verifying key..."
    statusLbl.TextColor3 = Color3.fromRGB(140,140,140)
    submitBtn.Active     = false

    local url = API_URL
        .. "?key="  .. HttpService:UrlEncode(inputKey)
        .. "&hwid=" .. HWID

    local ok, result = pcall(httpGet, url)
    submitBtn.Active = true

    if not ok then
        statusLbl.Text      = "⚠ Network error — try again."
        statusLbl.TextColor3 = Color3.fromRGB(255,152,0)
        return false
    end

    local parsed
    local pok = pcall(function()
        parsed = HttpService:JSONDecode(result)
    end)

    if not pok or type(parsed) ~= "table" then
        statusLbl.Text      = "⚠ Server error — try again."
        statusLbl.TextColor3 = Color3.fromRGB(255,152,0)
        return false
    end

    if parsed.status == "ok" then
        return true, parsed.msg
    else
        statusLbl.Text      = "✗ " .. (parsed.msg or "Invalid key.")
        statusLbl.TextColor3 = Color3.fromRGB(215,55,55)
        return false
    end
end

local keyEvent = Instance.new("BindableEvent")

submitBtn.MouseButton1Click:Connect(function()
    local success, msg = ValidateKey(box.Text)
    if success then
        statusLbl.Text       = "✓ " .. (msg or "Key accepted! Loading...")
        statusLbl.TextColor3 = Color3.fromRGB(0,210,100)
        task.wait(0.8)
        TweenService:Create(bg2, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
        task.wait(0.45)
        keyGui:Destroy()
        keyEvent:Fire()
    end
end)

keyEvent.Event:Wait()
keyEvent:Destroy()

-- ═══════════════════════════════════════════════════════════════
--  KEY VALIDATED — SCRIPT LOADING
-- ═══════════════════════════════════════════════════════════════

local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local StarterGui       = game:GetService("StarterGui")

pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() player.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

if guiTarget:FindFirstChild("UI_Load") then guiTarget.UI_Load:Destroy() end
if guiTarget:FindFirstChild("UI_Main") then guiTarget.UI_Main:Destroy() end

-- ═════════════════════════════════════════════════════════════
--  LOADING SCREEN
-- ═════════════════════════════════════════════════════════════
local loadGui = Instance.new("ScreenGui")
loadGui.Name           = "UI_Load"
loadGui.IgnoreGuiInset = true
loadGui.ResetOnSpawn   = false
loadGui.Parent         = guiTarget

local bg = Instance.new("Frame", loadGui)
bg.Size              = UDim2.new(1,0,1,0)
bg.BackgroundColor3  = Color3.fromRGB(4,5,9)
bg.BorderSizePixel   = 0

local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,0,0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6,8,14)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,0,0)),
}
vig.Rotation = 45
vig.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,   0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1,   0.6),
}

local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size                = UDim2.new(1,0,0,50)
titleLbl.Position            = UDim2.new(0,0,0.22,0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                = "HPSPY"
titleLbl.TextColor3          = Color3.fromRGB(0,170,120)
titleLbl.Font                = Enum.Font.GothamBlack
titleLbl.TextSize            = 38

local subLbl = Instance.new("TextLabel", bg)
subLbl.Size                = UDim2.new(1,0,0,24)
subLbl.Position            = UDim2.new(0,0,0.36,0)
subLbl.BackgroundTransparency = 1
subLbl.Text                = "Bloxstrike  ·  v8.0"
subLbl.TextColor3          = Color3.fromRGB(60,130,100)
subLbl.Font                = Enum.Font.GothamBold
subLbl.TextSize            = 14

local routeY      = 0.50
local ROUTE_LABELS = {"🚦 START", "◆ STEP 1", "◆ STEP 2", "◆ STEP 3", "🏁 DONE"}
local routeDots   = {}

for i, label in ipairs(ROUTE_LABELS) do
    local xpct = (i-1) / (#ROUTE_LABELS-1) * 0.7 + 0.15
    if i > 1 then
        local prevX = (i-2) / (#ROUTE_LABELS-1) * 0.7 + 0.15
        local lf = Instance.new("Frame", bg)
        lf.Size             = UDim2.new(xpct-prevX,-4,0,2)
        lf.Position         = UDim2.new(prevX,6,routeY,4)
        lf.BackgroundColor3 = Color3.fromRGB(20,40,30)
        lf.BorderSizePixel  = 0
        routeDots[i]       = routeDots[i] or {}
        routeDots[i].line  = lf
    end
    local dot = Instance.new("Frame", bg)
    dot.Size             = UDim2.new(0,10,0,10)
    dot.Position         = UDim2.new(xpct,-5,routeY,0)
    dot.BackgroundColor3 = Color3.fromRGB(20,40,30)
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0,5)
    local lbl2 = Instance.new("TextLabel", bg)
    lbl2.Size               = UDim2.new(0,80,0,16)
    lbl2.Position           = UDim2.new(xpct,-40,routeY,14)
    lbl2.BackgroundTransparency = 1
    lbl2.Text               = label
    lbl2.TextColor3         = Color3.fromRGB(30,55,40)
    lbl2.Font               = Enum.Font.Code
    lbl2.TextSize           = 10
    routeDots[i]     = routeDots[i] or {}
    routeDots[i].dot = dot
    routeDots[i].lbl = lbl2
end

local barTrack = Instance.new("Frame", bg)
barTrack.Size             = UDim2.new(0.5,0,0,5)
barTrack.Position         = UDim2.new(0.25,0,0.68,0)
barTrack.BackgroundColor3 = Color3.fromRGB(14,18,28)
barTrack.BorderSizePixel  = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0,3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size             = UDim2.new(0,0,1,0)
barFill.BackgroundColor3 = Color3.fromRGB(0,170,120)
barFill.BorderSizePixel  = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0,3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size               = UDim2.new(1,0,0,18)
barTxt.Position           = UDim2.new(0,0,0.72,0)
barTxt.BackgroundTransparency = 1
barTxt.TextColor3         = Color3.fromRGB(40,90,65)
barTxt.Font               = Enum.Font.Code
barTxt.TextSize           = 12

local speedLines = {}
math.randomseed(42)
for i = 1, 12 do
    local ln  = Instance.new("Frame", bg)
    local yp  = math.random(10,90)/100
    local w   = math.random(60,160)/1000
    local xp  = math.random(0,80)/100
    ln.Size              = UDim2.new(w,0,0,1)
    ln.Position          = UDim2.new(xp,0,yp,0)
    ln.BackgroundColor3  = Color3.fromRGB(0,170,120)
    ln.BorderSizePixel   = 0
    ln.BackgroundTransparency = 0.6 + math.random()*0.3
    speedLines[i] = { frame=ln, speed=math.random(40,120)/100, x=xp, w=w }
end

local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.frame.Position = UDim2.new(sl.x,0,sl.frame.Position.Y.Scale,0)
    end
end)

local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local CAM_ROUTE = {
    { CFrame.lookAt(Vector3.new(0,75,200),   Vector3.new(0,0,0)) },
    { CFrame.lookAt(Vector3.new(100,40,150), Vector3.new(0,0,0)) },
    { CFrame.lookAt(Vector3.new(-80,55,180), Vector3.new(0,0,0)) },
}
cam.CFrame = CAM_ROUTE[1][1]

local function SetProg(pct, msg, activeDot)
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(pct/100,0,1,0) }):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)
    local ci = math.max(1, math.min(#CAM_ROUTE, math.round(pct/100 * #CAM_ROUTE + 0.5)))
    TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { CFrame = CAM_ROUTE[ci][1] }):Play()
    for i, d in ipairs(routeDots) do
        local on  = activeDot and i <= activeDot
        local col = on and Color3.fromRGB(0,170,120) or Color3.fromRGB(20,40,30)
        local tc  = on and Color3.fromRGB(0,200,140) or Color3.fromRGB(30,55,40)
        if d.dot  then TweenService:Create(d.dot,  TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
        if d.lbl  then d.lbl.TextColor3 = tc end
        if d.line then TweenService:Create(d.line, TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
    end
end

SetProg(5,  "Initialising...", 1) ; task.wait(0.2)
SetProg(30, "Loading assets...", 2) ; task.wait(0.3)
SetProg(60, "Configuring...",   3) ; task.wait(0.3)
SetProg(80, "Building UI...",   4) ; task.wait(0.2)
SetProg(95, "Finalising...",    5) ; task.wait(0.2)
SetProg(100,"Ready!")
task.wait(0.5)

if loadAnimConn then loadAnimConn:Disconnect() end
pcall(function() TweenService:Create(cam, TweenInfo.new(0), { CFrame = cam.CFrame }):Play() end)
task.wait()
cam.CameraType    = Enum.CameraType.Custom
cam.CameraSubject = nil
task.wait()

TweenService:Create(bg, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
    { BackgroundTransparency = 1 }):Play()
for _, d in ipairs(loadGui:GetDescendants()) do
    if d:IsA("TextLabel") then
        pcall(function() TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play() end)
    end
    if d:IsA("Frame") then
        pcall(function() TweenService:Create(d, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play() end)
    end
end
task.wait(0.6)
if loadGui then loadGui:Destroy() end

-- ═════════════════════════════════════════════════════════════
--  MAIN PANEL
-- ═════════════════════════════════════════════════════════════
local Theme = {
    Background = Color3.fromRGB(24,24,28),
    Sidebar    = Color3.fromRGB(18,18,22),
    Accent     = Color3.fromRGB(0,170,120),
    AccentDim  = Color3.fromRGB(0,110,78),
    Text       = Color3.fromRGB(240,240,240),
    SubText    = Color3.fromRGB(150,150,150),
    Button     = Color3.fromRGB(35,35,40),
    Stroke     = Color3.fromRGB(60,60,65),
    Red        = Color3.fromRGB(215,55,55),
    Orange     = Color3.fromRGB(255,152,0),
    Green      = Color3.fromRGB(0,210,100),
}

local ScreenGui = Instance.new("ScreenGui", guiTarget)
ScreenGui.Name           = "UI_Main"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true

local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size                 = UDim2.new(0,45,0,45)
ToggleIcon.Position             = UDim2.new(0.5,-22,0.05,0)
ToggleIcon.BackgroundColor3     = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text                 = "🏁"
ToggleIcon.TextSize             = 22
ToggleIcon.Visible              = false
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1,0)
local IconStroke = Instance.new("UIStroke", ToggleIcon)
IconStroke.Color     = Theme.Accent
IconStroke.Thickness = 2

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size                  = UDim2.new(0,420,0,280)
MainFrame.Position              = UDim2.new(0.5,-210,0.5,-140)
MainFrame.BackgroundColor3      = Theme.Background
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active                = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0,10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color        = Theme.Stroke
MainStroke.Transparency = 0.4

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size                 = UDim2.new(1,0,0,32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size               = UDim2.new(0.6,0,1,0)
TitleLbl.Position           = UDim2.new(0,14,0,0)
TitleLbl.Text               = "🏁  HPSPY  ·  Bloxstrike"
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextColor3         = Theme.Accent
TitleLbl.TextSize           = 12
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local Sep = Instance.new("Frame", MainFrame)
Sep.Size             = UDim2.new(1,-20,0,1)
Sep.Position         = UDim2.new(0,10,0,32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel  = 0

local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size               = UDim2.new(0,28,0,22)
    b.Position           = pos
    b.BackgroundTransparency = 1
    b.Text               = text
    b.TextColor3         = color
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 12
    b.MouseButton1Click:Connect(cb)
    return b
end

AddCtrl("✕", UDim2.new(1,-32,0.5,-11), Color3.fromRGB(255,80,80), function()
    ScreenGui:Destroy()
end)
AddCtrl("—", UDim2.new(1,-62,0.5,-11), Theme.SubText, function()
    MainFrame.Visible  = false
    ToggleIcon.Visible = true
end)
ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible  = true
    ToggleIcon.Visible = false
end)

local function EnableDrag(obj, handle)
    local drag, start, startPos
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then
            drag     = true
            start    = i.Position
            startPos = obj.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then drag = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement
                  or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - start
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                     startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end
EnableDrag(MainFrame, TopBar)
EnableDrag(ToggleIcon, ToggleIcon)

local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size                  = UDim2.new(0,108,1,-33)
Sidebar.Position              = UDim2.new(0,0,0,33)
Sidebar.BackgroundColor3      = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel       = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0,10)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding             = UDim.new(0,5)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0,10)

local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size                  = UDim2.new(1,-118,1,-38)
ContentArea.Position              = UDim2.new(0,113,0,38)
ContentArea.BackgroundTransparency = 1

local AllTabs    = {}
local AllTabBtns = {}

local function CreateTab(name, icon)
    local tf = Instance.new("ScrollingFrame", ContentArea)
    tf.Size                  = UDim2.new(1,0,1,0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness    = 2
    tf.ScrollBarImageColor3  = Theme.AccentDim
    tf.Visible               = false
    tf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    tf.CanvasSize            = UDim2.new(0,0,0,0)
    tf.BorderSizePixel       = 0
    local lay = Instance.new("UIListLayout", tf)
    lay.Padding = UDim.new(0,7)
    local pad = Instance.new("UIPadding", tf)
    pad.PaddingTop = UDim.new(0,6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size                  = UDim2.new(0.92,0,0,30)
    tb.BackgroundColor3      = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text                  = "  " .. icon .. " " .. name
    tb.TextColor3            = Theme.SubText
    tb.Font                  = Enum.Font.GothamMedium
    tb.TextSize              = 12
    tb.TextXAlignment        = Enum.TextXAlignment.Left
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0,6)

    local ind = Instance.new("Frame", tb)
    ind.Size             = UDim2.new(0,3,0.6,0)
    ind.Position         = UDim2.new(0,2,0.2,0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible          = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1,0)

    tb.MouseButton1Click:Connect(function()
        for _, t in pairs(AllTabs)    do t.Frame.Visible = false end
        for _, b in pairs(AllTabBtns) do
            b.Btn.BackgroundTransparency = 1
            b.Btn.TextColor3             = Theme.SubText
            b.Ind.Visible                = false
        end
        tf.Visible               = true
        tb.BackgroundTransparency = 0.82
        tb.TextColor3            = Theme.Text
        ind.Visible              = true
    end)

    table.insert(AllTabs,    { Frame = tf })
    table.insert(AllTabBtns, { Btn = tb, Ind = ind })
    return tf
end

local function Section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                  = UDim2.new(0.98,0,0,18)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = text
    lbl.TextColor3            = Theme.AccentDim
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 10
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
end

local function AddButton(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98,0,0,35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = text
    btn.Font             = Enum.Font.GothamBold
    btn.TextColor3       = Theme.Text
    btn.TextSize         = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Theme.Stroke
    btn.MouseButton1Click:Connect(cb)
end

local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn   = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98,0,0,48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = ""
    btn.AutoButtonColor  = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,7)
    local btnStroke = Instance.new("UIStroke", btn) ; btnStroke.Color = Theme.Stroke

    local tx = Instance.new("TextLabel", btn)
    tx.Size               = UDim2.new(0.72,0,0.5,0)
    tx.Position           = UDim2.new(0,10,0,5)
    tx.Text               = title
    tx.Font               = Enum.Font.GothamMedium
    tx.TextColor3         = Theme.Text
    tx.TextSize           = 12
    tx.TextXAlignment     = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel", btn)
    sub.Size              = UDim2.new(0.72,0,0.5,0)
    sub.Position          = UDim2.new(0,10,0.5,0)
    sub.Text              = desc
    sub.Font              = Enum.Font.Gotham
    sub.TextColor3        = Theme.SubText
    sub.TextSize          = 10
    sub.TextXAlignment    = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame", btn)
    pill.Size             = UDim2.new(0,42,0,22)
    pill.Position         = UDim2.new(1,-52,0.5,-11)
    pill.BackgroundColor3 = Theme.Button
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1,0)
    local ps2 = Instance.new("UIStroke", pill) ; ps2.Color = Theme.Stroke ; ps2.Thickness = 1

    local pillTxt = Instance.new("TextLabel", pill)
    pillTxt.Size              = UDim2.new(1,0,1,0)
    pillTxt.Text              = "OFF"
    pillTxt.Font              = Enum.Font.GothamBold
    pillTxt.TextColor3        = Theme.SubText
    pillTxt.TextSize          = 9
    pillTxt.BackgroundTransparency = 1

    local function setV(on)
        state                 = on
        pill.BackgroundColor3 = on and Theme.Accent or Theme.Button
        ps2.Color             = on and Theme.Accent or Theme.Stroke
        pillTxt.Text          = on and "ON" or "OFF"
        pillTxt.TextColor3    = on and Color3.new(1,1,1) or Theme.SubText
        btn.BackgroundColor3  = on and Color3.fromRGB(30,42,36) or Theme.Button
    end
    setV(false)
    btn.MouseButton1Click:Connect(function()
        local res = callback(not state)
        setV(res ~= nil and res or not state)
    end)
    return setV
end

local function FluentSlider(parent, label, minV, maxV, defaultV, sweetspot, getV, setV)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(0.98,0,0,62)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0,7)
    local rowStroke = Instance.new("UIStroke", row) ; rowStroke.Color = Theme.Stroke

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size          = UDim2.new(0.55,0,0,20)
    nameLbl.Position      = UDim2.new(0,10,0,6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text          = label
    nameLbl.TextColor3    = Theme.Text
    nameLbl.Font          = Enum.Font.GothamMedium
    nameLbl.TextSize      = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size           = UDim2.new(0.40,0,0,20)
    valLbl.Position       = UDim2.new(0.58,0,0,6)
    valLbl.BackgroundTransparency = 1
    valLbl.Font           = Enum.Font.GothamBold
    valLbl.TextSize       = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", row)
    track.Size            = UDim2.new(1,-20,0,6)
    track.Position        = UDim2.new(0,10,0,36)
    track.BackgroundColor3 = Color3.fromRGB(14,18,28)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0,3)

    local fill = Instance.new("Frame", track)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0,0,1,0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0,3)

    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0,14,0,14)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0,7)

    local minTxt = Instance.new("TextLabel", row)
    minTxt.Size            = UDim2.new(0,30,0,10)
    minTxt.Position        = UDim2.new(0,10,0,48)
    minTxt.BackgroundTransparency = 1
    minTxt.Text            = tostring(minV)
    minTxt.TextColor3      = Theme.SubText
    minTxt.Font            = Enum.Font.Code
    minTxt.TextSize        = 8
    minTxt.TextXAlignment  = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel", row)
    maxTxt.Size            = UDim2.new(0,40,0,10)
    maxTxt.Position        = UDim2.new(1,-50,0,48)
    maxTxt.BackgroundTransparency = 1
    maxTxt.Text            = tostring(maxV) .. " MAX"
    maxTxt.TextColor3      = Theme.Red
    maxTxt.Font            = Enum.Font.Code
    maxTxt.TextSize        = 8
    maxTxt.TextXAlignment  = Enum.TextXAlignment.Right

    local function updateFromPct(pct)
        pct = math.clamp(pct,0,1)
        local raw = minV + pct * (maxV - minV)
        local rangeSize = maxV - minV
        local step = rangeSize <= 20 and 1 or (rangeSize <= 100 and 5 or 10)
        local val = math.clamp(math.round(raw/step)*step, minV, maxV)
        setV(val)
        local rp  = (val-minV)/(maxV-minV)
        fill.Size         = UDim2.new(rp,0,1,0)
        knob.Position     = UDim2.new(rp,-7,0.5,-7)
        local col         = (val >= maxV) and Theme.Red or Theme.Accent
        valLbl.Text       = val .. ""
        valLbl.TextColor3 = col
        fill.BackgroundColor3 = col
        knob.BackgroundColor3 = (val >= maxV) and Theme.Red or Color3.new(1,1,1)
    end
    updateFromPct((defaultV-minV)/(maxV-minV))

    local dragging = false
    local function applyInput(inp)
        local ax = track.AbsolutePosition.X
        local aw = track.AbsoluteSize.X
        updateFromPct((inp.Position.X-ax)/aw)
    end
    knob.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = true ; applyInput(i) end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
                      or i.UserInputType == Enum.UserInputType.Touch) then applyInput(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
        or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end

-- ═════════════════════════════════════════════════════════════
--  TABS
-- ═════════════════════════════════════════════════════════════
local Tab1 = CreateTab("Combat",   "🎯")
local Tab2 = CreateTab("Weapon",   "🔫")
local Tab3 = CreateTab("Visual",   "👁")
local Tab4 = CreateTab("Movement", "🦅")
local Tab5 = CreateTab("Info",     "⚙️")

if AllTabs[1] and AllTabBtns[1] then
    AllTabs[1].Frame.Visible              = true
    AllTabBtns[1].Btn.BackgroundTransparency = 0.82
    AllTabBtns[1].Btn.TextColor3          = Theme.Text
    AllTabBtns[1].Ind.Visible             = true
end

-- ═══════════════════════════════════════════════════════════════
--  FEATURE LOGIC
-- ═══════════════════════════════════════════════════════════════
local RS          = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local ESPConfig       = { Enabled = true, Color = Color3.fromRGB(255,0,0) }
local MAX_HIGHLIGHTS  = 10
local FPS_LOOP_RATE   = 2.0

local Highlights       = {}
local PlayerCache      = {}
local CharRemovedConns = {}
local VelocityRef      = nil

local function IsEnemy(p)
    if p == LocalPlayer then return false end
    local my    = tostring(LocalPlayer:GetAttribute("Team") or "Nil")
    local their = tostring(p:GetAttribute("Team") or "Nil")
    return my ~= their
end

local function DistanceTo(p)
    local mc = LocalPlayer.Character
    local tc = p.Character
    if not mc or not tc then return math.huge end
    local r1 = mc:FindFirstChild("HumanoidRootPart")
    local r2 = tc:FindFirstChild("HumanoidRootPart")
    if not r1 or not r2 then return math.huge end
    return (r1.Position - r2.Position).Magnitude
end

local function FindVelocityTable()
    if VelocityRef then return VelocityRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table"
        and rawget(v,"TargetSelection") and rawget(v,"Magnetism")
        and rawget(v,"RecoilAssist")   and rawget(v,"Friction") then
            VelocityRef = v ; return v
        end
    end
end

local smokeHooked = false
local function HookSmoke()
    if smokeHooked then return end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v,"n") == "doesRaycastIntersectSmoke" then
            hookfunction(v, function() return false end)
            smokeHooked = true ; break
        end
    end
end

local function ApplyVelocityON(v)
    v.TargetSelection.MaxDistance = 10000
    v.TargetSelection.MaxAngle    = 6.28
    if v.TargetSelection.CheckWalls  ~= nil then v.TargetSelection.CheckWalls  = false end
    if v.TargetSelection.VisibleOnly ~= nil then v.TargetSelection.VisibleOnly = false end
    if rawget(v.TargetSelection,"TargetPart") ~= nil then v.TargetSelection.TargetPart = "Head" end
    if rawget(v.TargetSelection,"TargetBone") ~= nil then v.TargetSelection.TargetBone = "Head" end
    if rawget(v.TargetSelection,"Bone")       ~= nil then v.TargetSelection.Bone       = "Head" end
    v.Magnetism.Enabled            = true
    v.Magnetism.MaxDistance        = 10000
    v.Magnetism.PullStrength       = 65.0
    v.Magnetism.StopThreshold      = 0
    v.Magnetism.MaxAngleHorizontal = 6.28
    v.Magnetism.MaxAngleVertical   = 6.28
    v.Friction.Enabled             = false
    v.Friction.BubbleRadius        = 0
    v.Friction.MinSensitivity      = 1.0
    v.RecoilAssist.Enabled         = true
    v.RecoilAssist.ReductionAmount = 1.0
end

local function ApplyVelocityOFF(v)
    v.Magnetism.PullStrength       = 1.0
    v.Magnetism.MaxDistance        = 300
    v.Magnetism.MaxAngleHorizontal = 0.5
    v.Magnetism.MaxAngleVertical   = 0.5
    v.Friction.Enabled             = true
    v.Friction.BubbleRadius        = 5.0
    v.Friction.MinSensitivity      = 1.0
    v.RecoilAssist.ReductionAmount = 0.0
end

local function RemoveHL(p)
    if Highlights[p] then Highlights[p]:Destroy(); Highlights[p] = nil end
end
local function MakeHL(char)
    local hl = Instance.new("Highlight")
    hl.FillTransparency    = 0.5
    hl.OutlineTransparency = 0
    hl.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor           = ESPConfig.Color
    hl.OutlineColor        = ESPConfig.Color
    hl.Parent              = char
    return hl
end
local function HookCharRem(p)
    if CharRemovedConns[p] then CharRemovedConns[p]:Disconnect() end
    CharRemovedConns[p] = p.CharacterRemoving:Connect(function() RemoveHL(p) end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then PlayerCache[p] = true; HookCharRem(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then PlayerCache[p] = true; HookCharRem(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    PlayerCache[p] = nil ; RemoveHL(p)
    if CharRemovedConns[p] then CharRemovedConns[p]:Disconnect(); CharRemovedConns[p] = nil end
end)

task.spawn(function()
    while true do
        local cnt = 0; for _ in pairs(PlayerCache) do cnt = cnt + 1 end
        task.wait(math.clamp(0.10 + cnt*0.004, 0.10, 0.35))
        if not ESPConfig.Enabled then
            for p in pairs(Highlights) do RemoveHL(p) end
        else
            local cands = {}
            for p in pairs(PlayerCache) do
                if IsEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    cands[#cands+1] = { p=p, d=DistanceTo(p) }
                end
            end
            table.sort(cands, function(a,b) return a.d < b.d end)
            local active = {}
            for i = 1, math.min(#cands, MAX_HIGHLIGHTS) do active[cands[i].p] = true end
            for p in pairs(Highlights) do if not active[p] then RemoveHL(p) end end
            for p in pairs(active) do
                local char = p.Character
                local hl = Highlights[p]
                if not (hl and hl.Parent == char) then
                    if hl then hl:Destroy() end
                    Highlights[p] = MakeHL(char)
                end
            end
        end
    end
end)

-- ── Infinite Ammo ─────────────────────────────────────────────
local AMMO_PAIRS = {
    {"Rounds","Capacity"}, {"rounds","capacity"}, {"CurrentAmmo","MaxAmmo"},
    {"currentAmmo","maxAmmo"}, {"Ammo","MaxAmmo"}, {"ammo","maxAmmo"},
    {"CurrentRounds","TotalRounds"},
}
local _IC = nil
local function GetIC()
    if _IC then return _IC end
    local ok, ic = pcall(function()
        return require(RS:WaitForChild("Controllers",2):WaitForChild("InventoryController",2))
    end)
    if ok and ic and type(ic.getCurrentEquipped) == "function" then _IC = ic end
    return _IC
end
local function FindLiveWeaponGC()
    local gc = getgc(true)
    local fb = nil
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table" then
            for _, pr in ipairs(AMMO_PAIRS) do
                local af, mf = pr[1], pr[2]
                local rounds = rawget(v,af)
                local cap    = rawget(v,mf)
                if type(rounds)=="number" and type(cap)=="number"
                and cap > 0 and rounds >= 0 and rawget(v,"DamagePerPart")==nil then
                    if type(rawget(v,"Identifier")) == "string" then return v, af, mf end
                    if not fb then
                        local ok2 = type(rawget(v,"CharacterSpeed"))=="number"
                               or  type(rawget(v,"LastShotTick"))=="number"
                               or  rawget(v,"IsEquipped") ~= nil
                               or  rawget(v,"IsShooting") ~= nil
                        if ok2 then fb = {v=v, af=af, mf=mf} end
                    end
                end
            end
        end
    end
    if fb then return fb.v, fb.af, fb.mf end
    return nil, nil, nil
end

local ammoActive = false
local ammoConn   = nil
local function RunAmmoHook()
    local ic = GetIC()
    ammoConn = RunService.Heartbeat:Connect(function()
        if not ammoActive then return end
        local handled = false
        if ic then
            local ok, eq = pcall(ic.getCurrentEquipped)
            if ok and eq then
                for _, pr in ipairs(AMMO_PAIRS) do
                    local a, m = pr[1], pr[2]
                    local cap = rawget(eq,m)
                    if type(cap) == "number" and cap > 0 then
                        local magSize = (rawget(eq,"Properties") and rawget(eq.Properties,"Rounds")) or cap
                        pcall(function()
                            eq[a] = magSize
                            eq[m] = 9999
                            eq.IsReloading     = false
                            eq.IsBurstShooting = false
                        end)
                        handled = true ; break
                    end
                end
            end
        end
        if not handled then
            local t, a, m = FindLiveWeaponGC()
            if t then
                local magSize = (rawget(t,"Properties") and rawget(t.Properties,"Rounds"))
                                or rawget(t,m) or 30
                pcall(function()
                    t[a] = magSize
                    t[m] = 9999
                    t.IsReloading     = false
                    t.IsBurstShooting = false
                end)
            end
        end
    end)
end

-- ── Zero Spread ───────────────────────────────────────────────
local spreadHooked = false
local function TryHookSpread()
    if spreadHooked then return true end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v)=="function" and debug.info(v,"n")=="applySpread" then
            hookfunction(v, function(dir) return dir end)
            spreadHooked = true ; return true
        end
    end
    for i = 1, #gc do
        local v = gc[i]
        if type(v)=="table" then
            local sp=rawget(v,"Spread"); local cs=rawget(v,"CharacterSpeed"); local pr=rawget(v,"Properties")
            if sp ~= nil and cs ~= nil and type(pr)=="table" then
                pcall(function()
                    sp.update      = function() end
                    sp.setPosition = function() rawset(sp,"_pos",0) end
                    sp.getPosition = function() return 0 end
                end)
                spreadHooked = true ; return true
            end
        end
    end
    return false
end

-- ── FPS Boost ─────────────────────────────────────────────────
local fpsActive    = false
local fpsThread    = nil
local _origQuality = nil

local function KillParticles(parent)
    pcall(function()
        for _, v in ipairs(parent:GetDescendants()) do
            if v:IsA("ParticleEmitter") or v:IsA("Smoke")
            or v:IsA("Fire")            or v:IsA("Sparkles") then
                pcall(function() v.Enabled = false end)
            end
        end
    end)
end
local function ApplyFPS()
    local L = game:GetService("Lighting")
    pcall(function() L.GlobalShadows = false end)
    pcall(function()
        for _, o in ipairs(L:GetChildren()) do
            if o:IsA("Atmosphere") or o:IsA("Sky") then o.Parent = nil end
        end
    end)
    pcall(function()
        if not _origQuality then _origQuality = settings().Rendering.QualityLevel end
        settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
    end)
    KillParticles(workspace)
    KillParticles(L)
end
local function RestoreFPS()
    pcall(function() game:GetService("Lighting").GlobalShadows = true end)
    pcall(function() settings().Rendering.QualityLevel = _origQuality or Enum.QualityLevel.Automatic end)
end

-- ── Noclip ────────────────────────────────────────────────────
local noclipActive = false
local noclipConn   = nil
local function StartNoclip()
    if noclipConn then return end
    noclipActive = true
    noclipConn = RunService.Heartbeat:Connect(function()
        if not noclipActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end)
end
local function StopNoclip(keepFlag)
    if not keepFlag then noclipActive = false end
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    local char = LocalPlayer.Character
    if char then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = true end
        end
    end
end

-- ── Magic Jump (Fall Cushion) ─────────────────────────────────
local magicJumpActive = false
local magicJumpConn   = nil
local mj_lastY        = math.huge
local MJ_TRIGGER_VY   = -18
local MJ_MIN_GAP      = 4

local function SpawnCushion(hrp)
    local catchY = hrp.Position.Y - 2
    local box    = Instance.new("Part")
    box.Size             = Vector3.new(9,1.2,9)
    box.CFrame           = CFrame.new(hrp.Position.X, catchY, hrp.Position.Z)
    box.Anchored         = true
    box.CanCollide       = true
    box.CastShadow       = false
    box.Material         = Enum.Material.SmoothPlastic
    box.Color            = Color3.fromRGB(255,160,30)
    box.Transparency     = 0.45
    box.TopSurface       = Enum.SurfaceType.Smooth
    box.BottomSurface    = Enum.SurfaceType.Smooth
    box.Parent           = workspace
    task.delay(2.5, function()
        if box and box.Parent then box:Destroy() end
    end)
    mj_lastY = hrp.Position.Y
end

local function StartMagicJump()
    if magicJumpConn then return end
    mj_lastY = math.huge
    magicJumpConn = RunService.Heartbeat:Connect(function()
        if not magicJumpActive then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hrp  = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local vy   = hrp.AssemblyLinearVelocity.Y
        local curY = hrp.Position.Y
        if vy <= MJ_TRIGGER_VY and (mj_lastY - curY) >= MJ_MIN_GAP then
            SpawnCushion(hrp)
        end
        if vy > -5 then mj_lastY = math.huge end
    end)
end

local function StopMagicJump(keepFlag)
    if not keepFlag then magicJumpActive = false end
    if magicJumpConn then magicJumpConn:Disconnect(); magicJumpConn = nil end
end

-- ── Platform Spawner ──────────────────────────────────────────
local spawnedBoxes = {}
local BOX_SIZE     = 4
local BOX_ENABLED  = false
local BOX_COLOR    = Color3.fromRGB(80,80,90)
local BOX_MATERIAL = Enum.Material.SmoothPlastic
local BOX_TRANS    = 0.35

local function GetPlacePosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local ahead   = hrp.CFrame.LookVector * (BOX_SIZE * 1.2)
    local origin  = hrp.Position + ahead
    local feetY   = hrp.Position.Y - 3
    local boxTopY = feetY + BOX_SIZE / 2
    if #spawnedBoxes > 0 then
        local last = spawnedBoxes[#spawnedBoxes]
        if last and last.Parent then
            local dist = (Vector3.new(origin.X,0,origin.Z)
                        - Vector3.new(last.Position.X,0,last.Position.Z)).Magnitude
            if dist < BOX_SIZE * 2.5 then
                boxTopY = last.Position.Y + last.Size.Y/2 + BOX_SIZE/2
            end
        end
    end
    return Vector3.new(origin.X, boxTopY, origin.Z)
end

local function SpawnBox()
    local pos = GetPlacePosition()
    if not pos then return end
    local box                  = Instance.new("Part")
    box.Name                   = "StepBox_" .. #spawnedBoxes
    box.Size                   = Vector3.new(BOX_SIZE, BOX_SIZE*0.45, BOX_SIZE)
    box.Position               = pos
    box.Anchored               = true
    box.CanCollide             = true
    box.CastShadow             = false
    box.Material               = BOX_MATERIAL
    box.Color                  = BOX_COLOR
    box.Transparency           = BOX_TRANS
    box.TopSurface             = Enum.SurfaceType.Smooth
    box.BottomSurface          = Enum.SurfaceType.Smooth
    local bb                   = Instance.new("BillboardGui", box)
    bb.Size                    = UDim2.new(0,40,0,20)
    bb.StudsOffset             = Vector3.new(0, box.Size.Y, 0)
    bb.AlwaysOnTop             = true
    local lbl                  = Instance.new("TextLabel", bb)
    lbl.Size                   = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.Text                   = "#" .. (#spawnedBoxes+1)
    lbl.TextColor3             = Color3.fromRGB(0,200,140)
    lbl.Font                   = Enum.Font.GothamBold
    lbl.TextSize               = 10
    box.Parent = workspace
    table.insert(spawnedBoxes, box)
end

local function RemoveLastBox()
    if #spawnedBoxes == 0 then return end
    local last = table.remove(spawnedBoxes)
    if last and last.Parent then last:Destroy() end
end

local function RemoveAllBoxes()
    for _, box in ipairs(spawnedBoxes) do
        if box and box.Parent then box:Destroy() end
    end
    spawnedBoxes = {}
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if not BOX_ENABLED then return end
    if input.KeyCode == Enum.KeyCode.E then
        SpawnBox()
    elseif input.KeyCode == Enum.KeyCode.Q then
        RemoveLastBox()
    end
end)

local mobileHUD = Instance.new("ScreenGui", guiTarget)
mobileHUD.Name           = "PlatformSpawnerHUD"
mobileHUD.ResetOnSpawn   = false
mobileHUD.IgnoreGuiInset = true
mobileHUD.Enabled        = false

local HUD_BTN_SIZE = 68

local btnPlace = Instance.new("TextButton", mobileHUD)
btnPlace.Size                   = UDim2.new(0, HUD_BTN_SIZE, 0, HUD_BTN_SIZE)
btnPlace.Position               = UDim2.new(1, -(HUD_BTN_SIZE+12), 1, -(HUD_BTN_SIZE+12))
btnPlace.BackgroundColor3       = Color3.fromRGB(0,170,120)
btnPlace.BackgroundTransparency = 0.15
btnPlace.Text                   = "📦"
btnPlace.TextSize               = 28
btnPlace.Font                   = Enum.Font.GothamBold
btnPlace.TextColor3             = Color3.new(1,1,1)
btnPlace.AutoButtonColor        = false
Instance.new("UICorner", btnPlace).CornerRadius = UDim.new(1,0)
local placeStroke = Instance.new("UIStroke", btnPlace)
placeStroke.Color     = Color3.fromRGB(0,200,140)
placeStroke.Thickness = 2

local placeCount = Instance.new("TextLabel", btnPlace)
placeCount.Size                  = UDim2.new(1,0,0,18)
placeCount.Position              = UDim2.new(0,0,0,-20)
placeCount.BackgroundTransparency = 1
placeCount.Text                  = "0 boxes"
placeCount.TextColor3            = Color3.fromRGB(0,200,140)
placeCount.Font                  = Enum.Font.GothamBold
placeCount.TextSize              = 10

local btnUndo = Instance.new("TextButton", mobileHUD)
btnUndo.Size                    = UDim2.new(0, HUD_BTN_SIZE, 0, HUD_BTN_SIZE)
btnUndo.Position                = UDim2.new(1, -(HUD_BTN_SIZE*2+20), 1, -(HUD_BTN_SIZE+12))
btnUndo.BackgroundColor3        = Color3.fromRGB(50,50,58)
btnUndo.BackgroundTransparency  = 0.15
btnUndo.Text                    = "↩️"
btnUndo.TextSize                = 26
btnUndo.Font                    = Enum.Font.GothamBold
btnUndo.TextColor3              = Color3.new(1,1,1)
btnUndo.AutoButtonColor         = false
Instance.new("UICorner", btnUndo).CornerRadius = UDim.new(1,0)
local undoStroke = Instance.new("UIStroke", btnUndo)
undoStroke.Color     = Color3.fromRGB(100,100,110)
undoStroke.Thickness = 2

local function FlashBtn(btn, col)
    local orig = btn.BackgroundColor3
    btn.BackgroundColor3 = col
    task.delay(0.12, function() btn.BackgroundColor3 = orig end)
end

btnPlace.MouseButton1Click:Connect(function()
    if not BOX_ENABLED then return end
    SpawnBox()
    placeCount.Text = #spawnedBoxes .. " box" .. (#spawnedBoxes == 1 and "" or "es")
    FlashBtn(btnPlace, Color3.fromRGB(0,230,160))
end)
btnUndo.MouseButton1Click:Connect(function()
    if not BOX_ENABLED then return end
    RemoveLastBox()
    placeCount.Text = #spawnedBoxes .. " box" .. (#spawnedBoxes == 1 and "" or "es")
    FlashBtn(btnUndo, Color3.fromRGB(90,90,100))
end)

-- ── Respawn handlers ──────────────────────────────────────────
LocalPlayer.CharacterRemoving:Connect(function()
    StopNoclip(true)
    StopMagicJump(true)
    RemoveAllBoxes()
    mj_lastY = math.huge
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.1)
    if noclipActive    then StartNoclip()    end
    if magicJumpActive then StartMagicJump() end
    if BOX_ENABLED     then placeCount.Text = "0 boxes" end
end)

-- ═════════════════════════════════════════════════════════════
--  TAB 1 — COMBAT
-- ═════════════════════════════════════════════════════════════
Section(Tab1, "  ◆ ESP")
FluentToggle(Tab1, "Full Body ESP", "", function(v)
    ESPConfig.Enabled = v
    return v
end)(true)

Section(Tab1, "  ◆ AIMBOT")
FluentToggle(Tab1, "Aimbot", "", function(v)
    local t = FindVelocityTable()
    if t then
        if v then pcall(ApplyVelocityON, t); task.defer(HookSmoke)
        else       pcall(ApplyVelocityOFF, t) end
        return v
    end
    warn("[HPSPY] Velocity table not found — fire a weapon first.")
    return false
end)

Section(Tab1, "  ◆ BULLET")
FluentToggle(Tab1, "Zero Spread", "", function(v)
    if v then
        local ok = TryHookSpread()
        if not ok then warn("[HPSPY] Spread hook not found — fire a weapon first, then retry.") end
        return ok and v or false
    end
    return false
end)

Section(Tab1, "  ◆ AUDIO")
-- Audio ESP state
local AUDIO_DURATION  = 1.8
local audioESPActive  = false
local audioEvents     = {}
local audioBillboards = {}
local audioConns      = {}

local audioHUD = Instance.new("ScreenGui", guiTarget)
audioHUD.Name            = "AudioESP_HUD"
audioHUD.ResetOnSpawn    = false
audioHUD.IgnoreGuiInset  = true
audioHUD.Enabled         = false

local ARROW_POOL = 8
local arrowPool  = {}
for i = 1, ARROW_POOL do
    local fr = Instance.new("Frame", audioHUD)
    fr.Size                   = UDim2.new(0,32,0,32)
    fr.BackgroundColor3       = Color3.fromRGB(220,60,60)
    fr.BackgroundTransparency = 0.2
    fr.BorderSizePixel        = 0
    fr.Visible                = false
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0,6)
    local stroke = Instance.new("UIStroke", fr)
    stroke.Color     = Color3.fromRGB(255,120,120)
    stroke.Thickness = 1.5
    local lbl = Instance.new("TextLabel", fr)
    lbl.Size               = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextSize           = 18
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextColor3         = Color3.new(1,1,1)
    lbl.Text               = "🔊"
    arrowPool[i] = { fr=fr, lbl=lbl }
end

local function MakeAudioBB(player)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if audioBillboards[player] and audioBillboards[player].bb.Parent then
        audioBillboards[player].bb:Destroy()
    end
    local bb = Instance.new("BillboardGui")
    bb.Name          = "AudioESP"
    bb.Size          = UDim2.new(0,110,0,26)
    bb.StudsOffset   = Vector3.new(0,4.2,0)
    bb.AlwaysOnTop   = true
    bb.ResetOnSpawn  = false
    bb.Enabled       = false
    bb.Parent        = hrp
    local bgf = Instance.new("Frame", bb)
    bgf.Size                   = UDim2.new(1,0,1,0)
    bgf.BackgroundColor3       = Color3.fromRGB(14,8,8)
    bgf.BackgroundTransparency = 0.2
    bgf.BorderSizePixel        = 0
    Instance.new("UICorner", bgf).CornerRadius = UDim.new(0,5)
    local lbl = Instance.new("TextLabel", bgf)
    lbl.Size               = UDim2.new(1,-4,1,0)
    lbl.Position           = UDim2.new(0,4,0,0)
    lbl.BackgroundTransparency = 1
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextSize           = 11
    lbl.TextColor3         = Color3.fromRGB(255,90,90)
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.Text               = "🔊"
    audioBillboards[player] = { bb=bb, lbl=lbl }
end

local function LogAudio(player, icon, label)
    if not audioESPActive then return end
    if not IsEnemy(player) then return end
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local dist  = myHRP and math.floor((hrp.Position - myHRP.Position).Magnitude) or 0
    audioEvents[player] = { time=tick(), label=label, icon=icon, pos=hrp.Position }
    local entry = audioBillboards[player]
    if not entry or not entry.bb.Parent then
        MakeAudioBB(player)
        entry = audioBillboards[player]
    end
    if entry then
        entry.lbl.Text   = icon .. " " .. label .. "  " .. dist .. "m"
        entry.bb.Enabled = true
    end
end

local function ClassifySound(name)
    local n = name:lower()
    if string.find(n,"shoot") or string.find(n,"fire")   then return "🔫","Shot"     end
    if string.find(n,"reload")                            then return "🔄","Reload"   end
    if string.find(n,"landing") or string.find(n,"land") then return "💥","Landing"  end
    if string.find(n,"jump")                              then return "↑","Jump"      end
    if string.find(n,"footstep") or string.find(n,"step") or string.find(n,"walk")
    or string.find(n,"floor") or string.find(n,"concrete") or string.find(n,"metal")
    or string.find(n,"grass") or string.find(n,"gravel")  or string.find(n,"sand")
    or string.find(n,"wood")  or string.find(n,"glass")   or string.find(n,"rubber") then
        return "👣","Footstep"
    end
    return nil, nil
end

local function ConnectChar(player, char)
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return end
    MakeAudioBB(player)
    local function hookSound(s)
        if not s:IsA("Sound") then return end
        local icon, label = ClassifySound(s.Name)
        if not icon then return end
        s.Played:Connect(function() LogAudio(player, icon, label) end)
    end
    for _, s in ipairs(hrp:GetDescendants())  do hookSound(s) end
    for _, s in ipairs(head:GetDescendants()) do hookSound(s) end
    local c1 = hrp.DescendantAdded:Connect(function(s)  task.defer(function() hookSound(s) end) end)
    local c2 = head.DescendantAdded:Connect(function(s) task.defer(function() hookSound(s) end) end)
    if not audioConns[player] then audioConns[player] = {} end
    table.insert(audioConns[player], c1)
    table.insert(audioConns[player], c2)
end

local function ConnectPlayer(player)
    if not audioConns[player] then audioConns[player] = {} end
    if player.Character then ConnectChar(player, player.Character) end
    local c = player.CharacterAdded:Connect(function(char)
        char:WaitForChild("HumanoidRootPart", 10)
        task.wait(0.05)
        ConnectChar(player, char)
    end)
    table.insert(audioConns[player], c)
end

local function DisconnectPlayer(player)
    if audioConns[player] then
        for _, c in ipairs(audioConns[player]) do pcall(function() c:Disconnect() end) end
        audioConns[player] = nil
    end
    if audioBillboards[player] then
        pcall(function() audioBillboards[player].bb:Destroy() end)
        audioBillboards[player] = nil
    end
    audioEvents[player] = nil
end

RunService.Heartbeat:Connect(function()
    if not audioESPActive then return end
    local cam   = workspace.CurrentCamera
    local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not cam or not myHRP then return end
    local vp     = cam.ViewportSize
    local cx, cy = vp.X/2, vp.Y/2
    local now    = tick()
    local arrowN = 0
    for p, ev in pairs(audioEvents) do
        local age = now - ev.time
        if age >= AUDIO_DURATION then
            local entry = audioBillboards[p]
            if entry and entry.bb then entry.bb.Enabled = false end
            audioEvents[p] = nil
        else
            local sp, inView = cam:WorldToViewportPoint(ev.pos)
            local onScreen = inView and sp.X >= 0 and sp.X <= vp.X and sp.Y >= 0 and sp.Y <= vp.Y
            if not onScreen and arrowN < ARROW_POOL then
                arrowN = arrowN + 1
                local a    = arrowPool[arrowN]
                local fade = age / AUDIO_DURATION
                local dx   = sp.X - cx
                local dy   = sp.Y - cy
                local ang  = math.atan2(dy, dx)
                local ex   = math.clamp(cx + math.cos(ang)*(cx-22), 16, vp.X-48)
                local ey   = math.clamp(cy + math.sin(ang)*(cy-22), 16, vp.Y-48)
                a.fr.Position           = UDim2.new(0, ex, 0, ey)
                a.fr.BackgroundTransparency = 0.15 + 0.55*fade
                a.lbl.Text              = ev.icon
                a.lbl.TextTransparency  = fade * 0.6
                a.fr.Visible            = true
            end
        end
    end
    for i = arrowN+1, ARROW_POOL do arrowPool[i].fr.Visible = false end
end)

FluentToggle(Tab1, "Audio ESP", "", function(v)
    audioESPActive   = v
    audioHUD.Enabled = v
    if v then
        for p in pairs(PlayerCache) do
            if IsEnemy(p) then ConnectPlayer(p) end
        end
        Players.PlayerAdded:Connect(function(p)
            if audioESPActive and IsEnemy(p) then ConnectPlayer(p) end
        end)
        Players.PlayerRemoving:Connect(function(p)
            DisconnectPlayer(p)
        end)
    else
        for p in pairs(audioConns) do DisconnectPlayer(p) end
        for _, entry in pairs(audioBillboards) do
            if entry and entry.bb then entry.bb.Enabled = false end
        end
        for i = 1, ARROW_POOL do arrowPool[i].fr.Visible = false end
    end
    return v
end)

-- ═════════════════════════════════════════════════════════════
--  TAB 2 — WEAPON
-- ═════════════════════════════════════════════════════════════
Section(Tab2, "  ◆ AMMO")
FluentToggle(Tab2, "Infinite Ammo", "", function(v)
    ammoActive = v
    if v then
        if ammoConn then ammoConn:Disconnect(); ammoConn = nil end
        RunAmmoHook()
    else
        if ammoConn then ammoConn:Disconnect(); ammoConn = nil end
    end
    return v
end)

-- ═════════════════════════════════════════════════════════════
--  TAB 3 — VISUAL
-- ═════════════════════════════════════════════════════════════
Section(Tab3, "  ◆ PERFORMANCE")
FluentToggle(Tab3, "FPS Boost", "", function(v)
    fpsActive = v
    if v then
        ApplyFPS()
        if fpsThread then task.cancel(fpsThread) end
        fpsThread = task.spawn(function()
            while fpsActive do task.wait(FPS_LOOP_RATE); KillParticles(workspace) end
        end)
    else
        if fpsThread then task.cancel(fpsThread); fpsThread = nil end
        RestoreFPS()
    end
    return v
end)

Section(Tab3, "  ◆ CAMERA")
local FOV_ACTIVE = false
local TARGET_FOV = 90
local FOV_STEP   = "FOV_Override"

local function StartFOV()
    pcall(function() RunService:UnbindFromRenderStep(FOV_STEP) end)
    RunService:BindToRenderStep(FOV_STEP, Enum.RenderPriority.Camera.Value + 2, function()
        if not FOV_ACTIVE then return end
        local c = workspace.CurrentCamera
        if c.FieldOfView >= 65 then c.FieldOfView = TARGET_FOV end
    end)
end
local function StopFOV()
    pcall(function() RunService:UnbindFromRenderStep(FOV_STEP) end)
    workspace.CurrentCamera.FieldOfView = 70
end

FluentToggle(Tab3, "FOV Unlocker", "", function(v)
    FOV_ACTIVE = v
    if v then StartFOV() else StopFOV() end
    return v
end)
FluentSlider(Tab3, "FOV Value", 70, 120, 90, 100,
    function() return TARGET_FOV end,
    function(val)
        TARGET_FOV = val
        if FOV_ACTIVE then
            local c = workspace.CurrentCamera
            if c.FieldOfView >= 65 then c.FieldOfView = val end
        end
    end
)

-- ═════════════════════════════════════════════════════════════
--  TAB 4 — MOVEMENT
-- ═════════════════════════════════════════════════════════════
Section(Tab4, "  ◆ NOCLIP")
FluentToggle(Tab4, "Noclip", "", function(v)
    if v then StartNoclip() else StopNoclip() end
    return v
end)

Section(Tab4, "  ◆ MAGIC JUMP")
FluentToggle(Tab4, "Magic Jump", "", function(v)
    magicJumpActive = v
    if v then StartMagicJump() else StopMagicJump() end
    return v
end)

Section(Tab4, "  ◆ PLATFORM SPAWNER")
FluentToggle(Tab4, "Platform Spawner", "", function(v)
    BOX_ENABLED       = v
    mobileHUD.Enabled = v
    if not v then placeCount.Text = "0 boxes" end
    return v
end)
FluentSlider(Tab4, "Box Size", 2, 16, 4, 6,
    function() return BOX_SIZE end,
    function(v) BOX_SIZE = v end
)
AddButton(Tab4, "🗑️  Remove All Platforms", function()
    RemoveAllBoxes()
    placeCount.Text = "0 boxes"
end)

-- ═════════════════════════════════════════════════════════════
--  TAB 5 — INFO (Ban Logger)
-- ═════════════════════════════════════════════════════════════
local LOG_MAX    = 80
local logEntries = {}
local logFrozen  = false
local logLabels  = {}

Section(Tab5, "  ◆ BAN LOGGER")
AddButton(Tab5, "Clear Log", function()
    logFrozen  = false
    logEntries = {}
    for _, lbl in ipairs(logLabels) do lbl:Destroy() end
    logLabels = {}
end)

local logFrame = Instance.new("ScrollingFrame", Tab5)
logFrame.Size                  = UDim2.new(0.98,0,0,180)
logFrame.BackgroundColor3      = Color3.fromRGB(10,12,16)
logFrame.BackgroundTransparency = 0.2
logFrame.BorderSizePixel       = 0
logFrame.ScrollBarThickness    = 3
logFrame.ScrollBarImageColor3  = Theme.AccentDim
logFrame.AutomaticCanvasSize   = Enum.AutomaticSize.Y
logFrame.CanvasSize            = UDim2.new(0,0,0,0)
Instance.new("UICorner", logFrame).CornerRadius = UDim.new(0,5)
local logLayout = Instance.new("UIListLayout", logFrame)
logLayout.Padding = UDim.new(0,1)
local logPad = Instance.new("UIPadding", logFrame)
logPad.PaddingLeft = UDim.new(0,5)
logPad.PaddingTop  = UDim.new(0,3)

local TAG_COLORS = {
    BAN    = Color3.fromRGB(255,60,60),
    REMOTE = Color3.fromRGB(80,180,255),
    VEL    = Color3.fromRGB(255,165,0),
    FEAT   = Color3.fromRGB(0,210,100),
    SYS    = Color3.fromRGB(150,150,150),
}

local function PushLog(tag, msg)
    if logFrozen and tag ~= "BAN" then return end
    local entry = { t=tick(), tag=tag, msg=msg }
    table.insert(logEntries, entry)
    if #logEntries > LOG_MAX then table.remove(logEntries, 1) end
    local lbl = Instance.new("TextLabel", logFrame)
    lbl.Size               = UDim2.new(1,-8,0,13)
    lbl.BackgroundTransparency = 1
    lbl.Font               = Enum.Font.Code
    lbl.TextSize           = 10
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.TextColor3         = TAG_COLORS[tag] or Theme.SubText
    lbl.TextTruncate       = Enum.TextTruncate.AtEnd
    local ts = string.format("[%.1f]", entry.t % 1000)
    lbl.Text = ts .. " [" .. tag .. "] " .. msg
    table.insert(logLabels, lbl)
    while #logLabels > LOG_MAX do
        logLabels[1]:Destroy()
        table.remove(logLabels, 1)
    end
    task.defer(function()
        logFrame.CanvasPosition = Vector2.new(0, logLayout.AbsoluteContentSize.Y)
    end)
    print(string.format("[HPSPYLog][%s] %s", tag, msg))
end

task.spawn(function()
    local NR = game:GetService("ReplicatedStorage"):WaitForChild("NetworkRemotes", 10)
    if not NR then PushLog("SYS", "NetworkRemotes not found"); return end
    local function WatchRemote(path, tag)
        local ok, remote = pcall(function()
            local obj = NR
            for _, part in ipairs(string.split(path,"/")) do
                obj = obj:WaitForChild(part, 5)
            end
            return obj
        end)
        if ok and remote and remote:IsA("RemoteEvent") then
            remote.OnClientEvent:Connect(function(data)
                local info = ""
                if data ~= nil then
                    local ok2, enc = pcall(
                        game:GetService("HttpService").JSONEncode,
                        game:GetService("HttpService"), data)
                    info = ok2 and (" -> " .. tostring(enc):sub(1,50)) or " -> [data]"
                end
                PushLog("REMOTE", tag .. info)
            end)
            PushLog("SYS", "Watching: " .. tag)
        end
    end
    WatchRemote("Character/CharacterDamaged", "Char.Damaged")
    WatchRemote("Character/CharacterDied",    "Char.Died")
    WatchRemote("Character/FallDamage",       "Char.FallDmg")
    WatchRemote("Character/ShotSlow",         "Char.ShotSlow")
    WatchRemote("UI/ShowNotification",        "UI.Notification")
    WatchRemote("Chat/ChatSystemMessage",     "Chat.SysMsg")
    WatchRemote("Chat/ChatTeamDamage",        "Chat.TeamDmg")
end)

task.spawn(function()
    local ok, banRemote = pcall(function()
        return game:GetService("ReplicatedStorage")
            :WaitForChild("NetworkRemotes",10)
            :WaitForChild("Chat",10)
            :WaitForChild("ChatPlayerBanned",10)
    end)
    if ok and banRemote then
        banRemote.OnClientEvent:Connect(function(data)
            local name = (type(data)=="table" and data.name) or tostring(data)
            logFrozen = true
            local feats = {}
            if ESPConfig.Enabled then feats[#feats+1] = "ESP"          end
            if ammoActive         then feats[#feats+1] = "InfAmmo"      end
            if fpsActive          then feats[#feats+1] = "FPSBoost"     end
            if noclipActive       then feats[#feats+1] = "Noclip"       end
            if magicJumpActive    then feats[#feats+1] = "MagicJump"    end
            PushLog("BAN", "!! BANNED: " .. name
                .. " | Active: " .. (#feats > 0 and table.concat(feats,",") or "none"))
            PushLog("BAN", "Log frozen — scroll up to review pre-ban activity.")
        end)
        PushLog("SYS", "Ban detection active.")
    else
        PushLog("SYS", "WARN: Could not hook ban remote.")
    end
end)

local VEL_WARN_Y  = 60
local VEL_WARN_XZ = 30
task.spawn(function()
    while true do
        task.wait(0.1)
        if logFrozen then break end
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local vel = hrp.AssemblyLinearVelocity
                local xz  = Vector3.new(vel.X,0,vel.Z).Magnitude
                if math.abs(vel.Y) > VEL_WARN_Y then
                    PushLog("VEL", string.format("Y=%.1f (limit %d)", vel.Y, VEL_WARN_Y))
                end
                if xz > VEL_WARN_XZ then
                    PushLog("VEL", string.format("XZ=%.1f (limit %d)", xz, VEL_WARN_XZ))
                end
            end
        end
    end
end)

PushLog("SYS", "HPSPY v8.0 loaded.")

Section(Tab5, "  ◆ BUILD")
AddButton(Tab5, "HPSPY  ·  Bloxstrike  ·  v8.0", function() end)
Section(Tab5, "  ◆ NOTES")
AddButton(Tab5, "Aimbot — fire weapon first before enabling", function() end)
AddButton(Tab5, "Zero Spread — fire weapon first before enabling", function() end)
AddButton(Tab5, "Ban Logger — pre-ban events logged above", function() end)

print("[HPSPY] v8.0 loaded.")
print("  Tab 1 Combat  : ESP | Aimbot | Zero Spread | Audio ESP")
print("  Tab 2 Weapon  : Infinite Ammo")
print("  Tab 3 Visual  : FPS Boost | FOV Unlocker")
print("  Tab 4 Movement: Noclip | Magic Jump | Platform Spawner")
print("  Tab 5 Info    : Ban Logger")
