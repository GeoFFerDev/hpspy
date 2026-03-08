--[[
  ══════════════════════════════════════════════════════════════
  FLUENT UI TEMPLATE  —  Extracted from JOSEPEDOV V51
  ══════════════════════════════════════════════════════════════
  LAYOUT OVERVIEW:
    • Loading Screen  — fullscreen bg + gradient vignette,
                        title/sub labels, checkpoint route dots,
                        progress bar, animated speed lines
    • Main Panel      — 420×280 draggable window
        ├─ TopBar     — title, minimize (—), close (✕)
        ├─ Sidebar    — tab buttons with active indicator
        └─ ContentArea— scrolling tab frames
            ├─ Tab 1  (empty — add content here)
            ├─ Tab 2  (empty — add content here)
            ├─ Tab 3  (empty — add content here)
            ├─ Tab 4  (empty — add content here)
            └─ Tab 5  (empty — add content here)

  UI HELPERS (ready to use):
    Section(parent, "  HEADER TEXT")
    AddButton(parent, "Button Label", callback)
    FluentToggle(parent, "Title", "Description", callback)  → returns setV(bool)
    FluentSlider(parent, "Label", min, max, default, sweetspot, getV, setV)
    FluentStepper(parent, "Label", "fmt", getV, decV, incV)
  ══════════════════════════════════════════════════════════════
]]

-- ─────────────────────────────────────────────────────────────
--  SERVICES
-- ─────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local Workspace        = game:GetService("Workspace")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local StarterGui       = game:GetService("StarterGui")
local player           = Players.LocalPlayer

-- Force landscape on mobile
pcall(function() StarterGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)
pcall(function() player.PlayerGui.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight end)

-- GUI mount target
local guiTarget = (type(gethui) == "function" and gethui())
    or (pcall(function() return game:GetService("CoreGui") end) and CoreGui)
    or player:WaitForChild("PlayerGui")

-- Anti-overlap: destroy any previous instances
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
bg.Size              = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3  = Color3.fromRGB(4, 5, 9)
bg.BorderSizePixel   = 0

-- Vignette gradient
local vig = Instance.new("UIGradient", bg)
vig.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0, 0, 0)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 8, 14)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0, 0, 0)),
}
vig.Rotation = 45
vig.Transparency = NumberSequence.new{
    NumberSequenceKeypoint.new(0,   0.6),
    NumberSequenceKeypoint.new(0.5, 0),
    NumberSequenceKeypoint.new(1,   0.6),
}

-- Title
local titleLbl = Instance.new("TextLabel", bg)
titleLbl.Size                = UDim2.new(1, 0, 0, 50)
titleLbl.Position            = UDim2.new(0, 0, 0.22, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text                = "YOUR SCRIPT TITLE"     -- ← change me
titleLbl.TextColor3          = Color3.fromRGB(0, 170, 120)
titleLbl.Font                = Enum.Font.GothamBlack
titleLbl.TextSize            = 38

-- Subtitle
local subLbl = Instance.new("TextLabel", bg)
subLbl.Size                = UDim2.new(1, 0, 0, 24)
subLbl.Position            = UDim2.new(0, 0, 0.36, 0)
subLbl.BackgroundTransparency = 1
subLbl.Text                = "Author  ·  Version"      -- ← change me
subLbl.TextColor3          = Color3.fromRGB(60, 130, 100)
subLbl.Font                = Enum.Font.GothamBold
subLbl.TextSize            = 14

-- ── Checkpoint / Route dots ────────────────────────────────────
local routeY      = 0.50
local ROUTE_LABELS = {"🚦 START", "◆ STEP 1", "◆ STEP 2", "◆ STEP 3", "🏁 DONE"} -- ← change me
local routeDots   = {}

for i, label in ipairs(ROUTE_LABELS) do
    local xpct = (i - 1) / (#ROUTE_LABELS - 1) * 0.7 + 0.15
    if i > 1 then
        local prevX = (i - 2) / (#ROUTE_LABELS - 1) * 0.7 + 0.15
        local lf = Instance.new("Frame", bg)
        lf.Size             = UDim2.new(xpct - prevX, -4, 0, 2)
        lf.Position         = UDim2.new(prevX, 6, routeY, 4)
        lf.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
        lf.BorderSizePixel  = 0
        routeDots[i]       = routeDots[i] or {}
        routeDots[i].line  = lf
    end

    local dot = Instance.new("Frame", bg)
    dot.Size             = UDim2.new(0, 10, 0, 10)
    dot.Position         = UDim2.new(xpct, -5, routeY, 0)
    dot.BackgroundColor3 = Color3.fromRGB(20, 40, 30)
    dot.BorderSizePixel  = 0
    Instance.new("UICorner", dot).CornerRadius = UDim.new(0, 5)

    local lbl2 = Instance.new("TextLabel", bg)
    lbl2.Size               = UDim2.new(0, 80, 0, 16)
    lbl2.Position           = UDim2.new(xpct, -40, routeY, 14)
    lbl2.BackgroundTransparency = 1
    lbl2.Text               = label
    lbl2.TextColor3         = Color3.fromRGB(30, 55, 40)
    lbl2.Font               = Enum.Font.Code
    lbl2.TextSize           = 10

    routeDots[i]     = routeDots[i] or {}
    routeDots[i].dot = dot
    routeDots[i].lbl = lbl2
end

-- ── Progress bar ───────────────────────────────────────────────
local barTrack = Instance.new("Frame", bg)
barTrack.Size             = UDim2.new(0.5, 0, 0, 5)
barTrack.Position         = UDim2.new(0.25, 0, 0.68, 0)
barTrack.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
barTrack.BorderSizePixel  = 0
Instance.new("UICorner", barTrack).CornerRadius = UDim.new(0, 3)

local barFill = Instance.new("Frame", barTrack)
barFill.Size             = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(0, 170, 120)
barFill.BorderSizePixel  = 0
Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 3)

local barTxt = Instance.new("TextLabel", bg)
barTxt.Size               = UDim2.new(1, 0, 0, 18)
barTxt.Position           = UDim2.new(0, 0, 0.72, 0)
barTxt.BackgroundTransparency = 1
barTxt.TextColor3         = Color3.fromRGB(40, 90, 65)
barTxt.Font               = Enum.Font.Code
barTxt.TextSize           = 12

-- ── Animated speed lines ──────────────────────────────────────
local speedLines = {}
math.randomseed(42)
for i = 1, 12 do
    local ln  = Instance.new("Frame", bg)
    local yp  = math.random(10, 90) / 100
    local w   = math.random(60, 160) / 1000
    local xp  = math.random(0, 80) / 100
    ln.Size              = UDim2.new(w, 0, 0, 1)
    ln.Position          = UDim2.new(xp, 0, yp, 0)
    ln.BackgroundColor3  = Color3.fromRGB(0, 170, 120)
    ln.BorderSizePixel   = 0
    ln.BackgroundTransparency = 0.6 + math.random() * 0.3
    speedLines[i] = { frame = ln, speed = math.random(40, 120) / 100, x = xp, w = w }
end

local loadAnimConn = RunService.Heartbeat:Connect(function(dt)
    for _, sl in ipairs(speedLines) do
        sl.x = sl.x + sl.speed * dt * 0.15
        if sl.x > 1 then sl.x = -sl.w end
        sl.frame.Position = UDim2.new(sl.x, 0, sl.frame.Position.Y.Scale, 0)
    end
end)

-- ── Camera cinematic during load ──────────────────────────────
local cam = Workspace.CurrentCamera
cam.CameraType = Enum.CameraType.Scriptable
local CAM_ROUTE = {
    { CFrame.lookAt(Vector3.new(0, 75, 200),  Vector3.new(0, 0, 0)) },  -- ← change me
    { CFrame.lookAt(Vector3.new(100, 40, 150), Vector3.new(0, 0, 0)) },
    { CFrame.lookAt(Vector3.new(-80, 55, 180), Vector3.new(0, 0, 0)) },
}
cam.CFrame = CAM_ROUTE[1][1]

-- ── SetProg helper ────────────────────────────────────────────
local function SetProg(pct, msg, activeDot)
    TweenService:Create(barFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = UDim2.new(pct / 100, 0, 1, 0) }):Play()
    barTxt.Text = string.format("  %d%%  —  %s", math.floor(pct), msg)

    local ci = math.max(1, math.min(#CAM_ROUTE, math.round(pct / 100 * #CAM_ROUTE + 0.5)))
    TweenService:Create(cam, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        { CFrame = CAM_ROUTE[ci][1] }):Play()

    for i, d in ipairs(routeDots) do
        local on  = activeDot and i <= activeDot
        local col = on and Color3.fromRGB(0, 170, 120) or Color3.fromRGB(20, 40, 30)
        local tc  = on and Color3.fromRGB(0, 200, 140) or Color3.fromRGB(30, 55, 40)
        if d.dot  then TweenService:Create(d.dot,  TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
        if d.lbl  then d.lbl.TextColor3 = tc end
        if d.line then TweenService:Create(d.line, TweenInfo.new(0.25), { BackgroundColor3 = col }):Play() end
    end
end

-- ─────────────────────────────────────────────────────────────
--  LOADING SEQUENCE  ← replace task.wait() calls with real work
-- ─────────────────────────────────────────────────────────────
SetProg(5,  "Initialising...", 1) ; task.wait(0.2)
-- TODO: add your preload / setup work here between SetProg calls
SetProg(30, "Loading assets...", 2) ; task.wait(0.3)
SetProg(60, "Configuring...",    3) ; task.wait(0.3)
SetProg(80, "Building UI...",    4) ; task.wait(0.2)
SetProg(95, "Finalising...",     5) ; task.wait(0.2)
SetProg(100,"Ready!")

task.wait(0.5)

-- Dismiss loading screen
if loadAnimConn then loadAnimConn:Disconnect() end

pcall(function()
    TweenService:Create(cam, TweenInfo.new(0), { CFrame = cam.CFrame }):Play()
end)
task.wait()
cam.CameraType   = Enum.CameraType.Custom
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

-- ── Theme ────────────────────────────────────────────────────
local Theme = {
    Background = Color3.fromRGB(24, 24, 28),
    Sidebar    = Color3.fromRGB(18, 18, 22),
    Accent     = Color3.fromRGB(0, 170, 120),
    AccentDim  = Color3.fromRGB(0, 110, 78),
    Text       = Color3.fromRGB(240, 240, 240),
    SubText    = Color3.fromRGB(150, 150, 150),
    Button     = Color3.fromRGB(35, 35, 40),
    Stroke     = Color3.fromRGB(60, 60, 65),
    Red        = Color3.fromRGB(215, 55, 55),
    Orange     = Color3.fromRGB(255, 152, 0),
    Green      = Color3.fromRGB(0, 210, 100),
}

-- ── ScreenGui ────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui", guiTarget)
ScreenGui.Name           = "UI_Main"
ScreenGui.ResetOnSpawn   = false
ScreenGui.IgnoreGuiInset = true

-- ── Minimised toggle icon ─────────────────────────────────────
local ToggleIcon = Instance.new("TextButton", ScreenGui)
ToggleIcon.Size                 = UDim2.new(0, 45, 0, 45)
ToggleIcon.Position             = UDim2.new(0.5, -22, 0.05, 0)
ToggleIcon.BackgroundColor3     = Theme.Background
ToggleIcon.BackgroundTransparency = 0.1
ToggleIcon.Text                 = "🏁"                -- ← change icon
ToggleIcon.TextSize             = 22
ToggleIcon.Visible              = false
Instance.new("UICorner", ToggleIcon).CornerRadius = UDim.new(1, 0)
local IconStroke = Instance.new("UIStroke", ToggleIcon)
IconStroke.Color     = Theme.Accent
IconStroke.Thickness = 2

-- ── Main window frame ─────────────────────────────────────────
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size                  = UDim2.new(0, 420, 0, 280)
MainFrame.Position              = UDim2.new(0.5, -210, 0.5, -140)
MainFrame.BackgroundColor3      = Theme.Background
MainFrame.BackgroundTransparency = 0.08
MainFrame.Active                = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color        = Theme.Stroke
MainStroke.Transparency = 0.4

-- ── Top bar ───────────────────────────────────────────────────
local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size                 = UDim2.new(1, 0, 0, 32)
TopBar.BackgroundTransparency = 1

local TitleLbl = Instance.new("TextLabel", TopBar)
TitleLbl.Size               = UDim2.new(0.6, 0, 1, 0)
TitleLbl.Position           = UDim2.new(0, 14, 0, 0)
TitleLbl.Text               = "🏁  YOUR SCRIPT TITLE"  -- ← change me
TitleLbl.Font               = Enum.Font.GothamBold
TitleLbl.TextColor3         = Theme.Accent
TitleLbl.TextSize           = 12
TitleLbl.TextXAlignment     = Enum.TextXAlignment.Left
TitleLbl.BackgroundTransparency = 1

local Sep = Instance.new("Frame", MainFrame)
Sep.Size             = UDim2.new(1, -20, 0, 1)
Sep.Position         = UDim2.new(0, 10, 0, 32)
Sep.BackgroundColor3 = Theme.Stroke
Sep.BorderSizePixel  = 0

-- ── Top bar control buttons ───────────────────────────────────
local function AddCtrl(text, pos, color, cb)
    local b = Instance.new("TextButton", TopBar)
    b.Size               = UDim2.new(0, 28, 0, 22)
    b.Position           = pos
    b.BackgroundTransparency = 1
    b.Text               = text
    b.TextColor3         = color
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 12
    b.MouseButton1Click:Connect(cb)
    return b
end

AddCtrl("✕", UDim2.new(1, -32, 0.5, -11), Color3.fromRGB(255, 80, 80), function()
    ScreenGui:Destroy()
end)

AddCtrl("—", UDim2.new(1, -62, 0.5, -11), Theme.SubText, function()
    MainFrame.Visible    = false
    ToggleIcon.Visible   = true
end)

ToggleIcon.MouseButton1Click:Connect(function()
    MainFrame.Visible  = true
    ToggleIcon.Visible = false
end)

-- ── Drag support (window + icon) ─────────────────────────────
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

-- ── Sidebar ───────────────────────────────────────────────────
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size                  = UDim2.new(0, 108, 1, -33)
Sidebar.Position              = UDim2.new(0, 0, 0, 33)
Sidebar.BackgroundColor3      = Theme.Sidebar
Sidebar.BackgroundTransparency = 0.4
Sidebar.BorderSizePixel       = 0
Instance.new("UICorner", Sidebar).CornerRadius = UDim.new(0, 10)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding              = UDim.new(0, 5)
SidebarLayout.HorizontalAlignment  = Enum.HorizontalAlignment.Center

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0, 10)

-- ── Content area ─────────────────────────────────────────────
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Size                  = UDim2.new(1, -118, 1, -38)
ContentArea.Position              = UDim2.new(0, 113, 0, 38)
ContentArea.BackgroundTransparency = 1

local AllTabs    = {}
local AllTabBtns = {}

-- ── CreateTab helper ──────────────────────────────────────────
local function CreateTab(name, icon)
    local tf = Instance.new("ScrollingFrame", ContentArea)
    tf.Size                  = UDim2.new(1, 0, 1, 0)
    tf.BackgroundTransparency = 1
    tf.ScrollBarThickness    = 2
    tf.ScrollBarImageColor3  = Theme.AccentDim
    tf.Visible               = false
    tf.AutomaticCanvasSize   = Enum.AutomaticSize.Y
    tf.CanvasSize            = UDim2.new(0, 0, 0, 0)
    tf.BorderSizePixel       = 0

    local lay = Instance.new("UIListLayout", tf)
    lay.Padding = UDim.new(0, 7)

    local pad = Instance.new("UIPadding", tf)
    pad.PaddingTop = UDim.new(0, 6)

    local tb = Instance.new("TextButton", Sidebar)
    tb.Size                  = UDim2.new(0.92, 0, 0, 30)
    tb.BackgroundColor3      = Theme.Accent
    tb.BackgroundTransparency = 1
    tb.Text                  = "  " .. icon .. " " .. name
    tb.TextColor3            = Theme.SubText
    tb.Font                  = Enum.Font.GothamMedium
    tb.TextSize              = 12
    tb.TextXAlignment        = Enum.TextXAlignment.Left
    Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 6)

    local ind = Instance.new("Frame", tb)
    ind.Size             = UDim2.new(0, 3, 0.6, 0)
    ind.Position         = UDim2.new(0, 2, 0.2, 0)
    ind.BackgroundColor3 = Theme.Accent
    ind.Visible          = false
    Instance.new("UICorner", ind).CornerRadius = UDim.new(1, 0)

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

-- ── UI Component helpers ──────────────────────────────────────

--- Adds a small section header label.
local function Section(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size                  = UDim2.new(0.98, 0, 0, 18)
    lbl.BackgroundTransparency = 1
    lbl.Text                  = text
    lbl.TextColor3            = Theme.AccentDim
    lbl.Font                  = Enum.Font.GothamBold
    lbl.TextSize              = 10
    lbl.TextXAlignment        = Enum.TextXAlignment.Left
end

--- Adds a simple action button.
local function AddButton(parent, text, cb)
    local btn = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98, 0, 0, 35)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = text
    btn.Font             = Enum.Font.GothamBold
    btn.TextColor3       = Theme.Text
    btn.TextSize         = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Theme.Stroke
    btn.MouseButton1Click:Connect(cb)
end

--- Adds a toggle with title, description, and pill switch.
--- Returns setV(bool) so you can force the visual state externally.
local function FluentToggle(parent, title, desc, callback)
    local state = false
    local btn   = Instance.new("TextButton", parent)
    btn.Size             = UDim2.new(0.98, 0, 0, 48)
    btn.BackgroundColor3 = Theme.Button
    btn.Text             = ""
    btn.AutoButtonColor  = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    local btnStroke = Instance.new("UIStroke", btn) ; btnStroke.Color = Theme.Stroke

    local tx = Instance.new("TextLabel", btn)
    tx.Size               = UDim2.new(0.72, 0, 0.5, 0)
    tx.Position           = UDim2.new(0, 10, 0, 5)
    tx.Text               = title
    tx.Font               = Enum.Font.GothamMedium
    tx.TextColor3         = Theme.Text
    tx.TextSize           = 12
    tx.TextXAlignment     = Enum.TextXAlignment.Left
    tx.BackgroundTransparency = 1

    local sub = Instance.new("TextLabel", btn)
    sub.Size              = UDim2.new(0.72, 0, 0.5, 0)
    sub.Position          = UDim2.new(0, 10, 0.5, 0)
    sub.Text              = desc
    sub.Font              = Enum.Font.Gotham
    sub.TextColor3        = Theme.SubText
    sub.TextSize          = 10
    sub.TextXAlignment    = Enum.TextXAlignment.Left
    sub.BackgroundTransparency = 1

    local pill = Instance.new("Frame", btn)
    pill.Size             = UDim2.new(0, 42, 0, 22)
    pill.Position         = UDim2.new(1, -52, 0.5, -11)
    pill.BackgroundColor3 = Theme.Button
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)
    local ps = Instance.new("UIStroke", pill) ; ps.Color = Theme.Stroke ; ps.Thickness = 1

    local pillTxt = Instance.new("TextLabel", pill)
    pillTxt.Size              = UDim2.new(1, 0, 1, 0)
    pillTxt.Text              = "OFF"
    pillTxt.Font              = Enum.Font.GothamBold
    pillTxt.TextColor3        = Theme.SubText
    pillTxt.TextSize          = 9
    pillTxt.BackgroundTransparency = 1

    local function setV(on)
        state                 = on
        pill.BackgroundColor3 = on and Theme.Accent or Theme.Button
        ps.Color              = on and Theme.Accent or Theme.Stroke
        pillTxt.Text          = on and "ON"  or "OFF"
        pillTxt.TextColor3    = on and Color3.new(1, 1, 1) or Theme.SubText
        btn.BackgroundColor3  = on and Color3.fromRGB(30, 42, 36) or Theme.Button
    end
    setV(false)
    btn.MouseButton1Click:Connect(function()
        local res = callback(not state)
        setV(res ~= nil and res or not state)
    end)
    return setV
end

--- Adds a draggable slider (snaps to nearest 10).
local function FluentSlider(parent, label, minV, maxV, defaultV, sweetspot, getV, setV)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(0.98, 0, 0, 62)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local rowStroke = Instance.new("UIStroke", row) ; rowStroke.Color = Theme.Stroke

    local nameLbl = Instance.new("TextLabel", row)
    nameLbl.Size          = UDim2.new(0.55, 0, 0, 20)
    nameLbl.Position      = UDim2.new(0, 10, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.Text          = label
    nameLbl.TextColor3    = Theme.Text
    nameLbl.Font          = Enum.Font.GothamMedium
    nameLbl.TextSize      = 12
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size           = UDim2.new(0.40, 0, 0, 20)
    valLbl.Position       = UDim2.new(0.58, 0, 0, 6)
    valLbl.BackgroundTransparency = 1
    valLbl.Font           = Enum.Font.GothamBold
    valLbl.TextSize       = 12
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track = Instance.new("Frame", row)
    track.Size            = UDim2.new(1, -20, 0, 6)
    track.Position        = UDim2.new(0, 10, 0, 36)
    track.BackgroundColor3 = Color3.fromRGB(14, 18, 28)
    track.BorderSizePixel = 0
    Instance.new("UICorner", track).CornerRadius = UDim.new(0, 3)

    local fill = Instance.new("Frame", track)
    fill.BorderSizePixel  = 0
    fill.Size             = UDim2.new(0, 0, 1, 0)
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 3)

    local knob = Instance.new("Frame", track)
    knob.Size             = UDim2.new(0, 14, 0, 14)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel  = 0
    Instance.new("UICorner", knob).CornerRadius = UDim.new(0, 7)

    local minTxt = Instance.new("TextLabel", row)
    minTxt.Size            = UDim2.new(0, 30, 0, 10)
    minTxt.Position        = UDim2.new(0, 10, 0, 48)
    minTxt.BackgroundTransparency = 1
    minTxt.Text            = tostring(minV)
    minTxt.TextColor3      = Theme.SubText
    minTxt.Font            = Enum.Font.Code
    minTxt.TextSize        = 8
    minTxt.TextXAlignment  = Enum.TextXAlignment.Left

    local maxTxt = Instance.new("TextLabel", row)
    maxTxt.Size            = UDim2.new(0, 40, 0, 10)
    maxTxt.Position        = UDim2.new(1, -50, 0, 48)
    maxTxt.BackgroundTransparency = 1
    maxTxt.Text            = tostring(maxV) .. " MAX"
    maxTxt.TextColor3      = Theme.Red
    maxTxt.Font            = Enum.Font.Code
    maxTxt.TextSize        = 8
    maxTxt.TextXAlignment  = Enum.TextXAlignment.Right

    local function updateFromPct(pct)
        pct = math.clamp(pct, 0, 1)
        local raw = minV + pct * (maxV - minV)
        local val = math.clamp(math.round(raw / 10) * 10, minV, maxV)
        setV(val)
        local rp  = (val - minV) / (maxV - minV)
        fill.Size         = UDim2.new(rp, 0, 1, 0)
        knob.Position     = UDim2.new(rp, -7, 0.5, -7)
        local col         = (val >= maxV) and Theme.Red or Theme.Accent
        valLbl.Text       = val .. ""
        valLbl.TextColor3 = col
        fill.BackgroundColor3 = col
        knob.BackgroundColor3 = (val >= maxV) and Theme.Red or Color3.new(1, 1, 1)
    end
    updateFromPct((defaultV - minV) / (maxV - minV))

    local dragging = false
    local function applyInput(inp)
        local ax = track.AbsolutePosition.X
        local aw = track.AbsoluteSize.X
        updateFromPct((inp.Position.X - ax) / aw)
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

--- Adds a < value > stepper row.
local function FluentStepper(parent, label, fmt, getV, decV, incV)
    local row = Instance.new("Frame", parent)
    row.Size             = UDim2.new(0.98, 0, 0, 38)
    row.BackgroundColor3 = Theme.Button
    row.BorderSizePixel  = 0
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)
    local rowStroke = Instance.new("UIStroke", row) ; rowStroke.Color = Theme.Stroke

    local lbl2 = Instance.new("TextLabel", row)
    lbl2.Size             = UDim2.new(0.52, 0, 1, 0)
    lbl2.Position         = UDim2.new(0, 10, 0, 0)
    lbl2.BackgroundTransparency = 1
    lbl2.Text             = string.format(fmt, getV())
    lbl2.TextColor3       = Theme.Text
    lbl2.Font             = Enum.Font.GothamMedium
    lbl2.TextSize         = 11
    lbl2.TextXAlignment   = Enum.TextXAlignment.Left

    local function mkB(t, xoff)
        local b = Instance.new("TextButton", row)
        b.Size             = UDim2.new(0, 28, 0, 26)
        b.Position         = UDim2.new(1, xoff, 0.5, -13)
        b.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
        b.TextColor3       = Theme.Text
        b.Text             = t
        b.Font             = Enum.Font.GothamBold
        b.TextSize         = 14
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
        return b
    end
    local btnDec = mkB("<", -62)
    btnDec.MouseButton1Click:Connect(function() decV() ; lbl2.Text = string.format(fmt, getV()) end)
    local btnInc = mkB(">", -30)
    btnInc.MouseButton1Click:Connect(function() incV() ; lbl2.Text = string.format(fmt, getV()) end)
end

-- ═════════════════════════════════════════════════════════════
--  TABS  ← rename / add icons as needed
-- ═════════════════════════════════════════════════════════════
local Tab1 = CreateTab("Tab 1", "🏁")
local Tab2 = CreateTab("Tab 2", "🚜")
local Tab3 = CreateTab("Tab 3", "🚗")
local Tab4 = CreateTab("Tab 4", "🌍")
local Tab5 = CreateTab("Tab 5", "⚙️")

-- ─────────────────────────────────────────────────────────────
--  TAB 1 CONTENT  ← add your UI elements here
-- ─────────────────────────────────────────────────────────────
-- Example usage (uncomment and customise):
--
-- Section(Tab1, "  SECTION HEADER")
--
-- AddButton(Tab1, "Do Something", function()
--     -- your code
-- end)
--
-- FluentToggle(Tab1, "Feature Name", "Short description", function(v)
--     -- Config.Feature = v
--     return v
-- end)
--
-- FluentSlider(Tab1, "Speed", 50, 500, 200, 300,
--     function() return Config.Speed end,
--     function(v) Config.Speed = v end)
--
-- FluentStepper(Tab1, "Count: %d", "%d",
--     function() return Config.Count end,
--     function() Config.Count = math.max(1, Config.Count - 1) end,
--     function() Config.Count = Config.Count + 1 end)

-- ─────────────────────────────────────────────────────────────
--  TAB 2 CONTENT
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
--  TAB 3 CONTENT
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
--  TAB 4 CONTENT
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
--  TAB 5 CONTENT
-- ─────────────────────────────────────────────────────────────

-- ── Activate first tab by default ────────────────────────────
if AllTabs[1] and AllTabBtns[1] then
    AllTabs[1].Frame.Visible              = true
    AllTabBtns[1].Btn.BackgroundTransparency = 0.82
    AllTabBtns[1].Btn.TextColor3          = Theme.Text
    AllTabBtns[1].Ind.Visible             = true
end

print("[UI_Template] Loaded successfully")

-- ═══════════════════════════════════════════════════════════════════════════
--  ██████████████████████████  FEATURE LOGIC  ████████████████████████████
--  Everything below is new feature code wired into the tabs above.
--  The template above is completely unaltered.
-- ═══════════════════════════════════════════════════════════════════════════

local RS          = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- ── Config ────────────────────────────────────────────────────────────────
local ESPConfig = { Enabled = true, Color = Color3.fromRGB(255, 0, 0) }
local MAX_HIGHLIGHTS  = 10
local FPS_LOOP_RATE   = 2.0    -- seconds between particle kill sweeps

-- ── Shared state ──────────────────────────────────────────────────────────
local Highlights       = {}
local PlayerCache      = {}
local CharRemovedConns = {}
local VelocityRef      = nil

-- ─────────────────────────────────────────────────────────────────────────
--  HELPERS: team check, distance
-- ─────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────
--  GC SCANNER UTILS
-- ─────────────────────────────────────────────────────────────────────────
local function FindVelocityTable()
    if VelocityRef then return VelocityRef end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "table"
        and rawget(v, "TargetSelection") and rawget(v, "Magnetism")
        and rawget(v, "RecoilAssist")   and rawget(v, "Friction") then
            VelocityRef = v ; return v
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
--  SMOKE BYPASS
-- ─────────────────────────────────────────────────────────────────────────
local smokeHooked = false
local function HookSmoke()
    if smokeHooked then return end
    local gc = getgc(true)
    for i = 1, #gc do
        local v = gc[i]
        if type(v) == "function" and debug.info(v, "n") == "doesRaycastIntersectSmoke" then
            hookfunction(v, function() return false end)
            smokeHooked = true ; break
        end
    end
end

-- ─────────────────────────────────────────────────────────────────────────
--  VELOCITY / AIMBOT
-- ─────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────
--  ESP
-- ─────────────────────────────────────────────────────────────────────────
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
        task.wait(math.clamp(0.10 + cnt * 0.004, 0.10, 0.35))
        if not ESPConfig.Enabled then
            for p in pairs(Highlights) do RemoveHL(p) end
        else
            local cands = {}
            for p in pairs(PlayerCache) do
                if IsEnemy(p) and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    cands[#cands+1] = { p = p, d = DistanceTo(p) }
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

-- ─────────────────────────────────────────────────────────────────────────
--  INFINITE AMMO  (3-path scanner — fixed for all weapons / all rounds)
-- ─────────────────────────────────────────────────────────────────────────
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
                local rounds = rawget(v, af)
                local cap    = rawget(v, mf)
                if type(rounds)=="number" and type(cap)=="number"
                and cap > 0 and rounds >= 0 and rawget(v,"DamagePerPart")==nil then
                    -- Path 2: Identifier string = definitive InventoryController state
                    if type(rawget(v,"Identifier")) == "string" then return v, af, mf end
                    -- Path 3 fallback candidates
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

local ammoActive  = false
local ammoConn    = nil   -- Heartbeat connection handle

-- ── Why Heartbeat instead of task.wait(0.05): ────────────────────────────
-- shoot() has TWO gates that block shots when ammo is "empty":
--
--   Gate 1:  if p_u_109.Rounds <= 0 then p_u_109:reload() ; return end
--            → triggers reload, sets IsReloading = true
--
--   Gate 2:  elseif p_u_109.IsReloading then return end
--            → every subsequent shot attempt returns early — no packet sent
--
-- At 50ms intervals our old thread was too slow. A fast weapon fires at
-- ~100ms per shot, so Rounds could hit 0 between two of our resets.
-- Once reload() ran, IsReloading stayed true until the full animation
-- finished (1-2s) — during which the gun "fired" (animation/sound) but
-- the actual RemoteEvent to the server was never sent → no damage.
--
-- Fix: run on Heartbeat (every frame, ~16ms) so Rounds NEVER reaches 0
-- between shots. Also write IsReloading = false every frame to abort any
-- reload that slipped through. Additionally keep Capacity topped up so
-- the reserve counter never runs dry either.

local function RunAmmoHook()
    local ic = GetIC()
    ammoConn = RunService.Heartbeat:Connect(function()
        if not ammoActive then return end

        -- PATH 1: InventoryController.getCurrentEquipped() — zero GC cost
        local handled = false
        if ic then
            local ok, eq = pcall(ic.getCurrentEquipped)
            if ok and eq then
                for _, pr in ipairs(AMMO_PAIRS) do
                    local a, m = pr[1], pr[2]
                    local cap = rawget(eq, m)
                    if type(cap) == "number" and cap > 0 then
                        -- Reset current-mag to full; also bump reserve
                        local magSize = (rawget(eq,"Properties") and rawget(eq.Properties,"Rounds"))
                                        or cap
                        pcall(function()
                            eq[a] = magSize          -- Rounds = full magazine
                            eq[m] = 9999             -- Capacity (reserve) = effectively infinite
                            eq.IsReloading  = false  -- abort reload gate
                            eq.IsBurstShooting = false
                        end)
                        handled = true ; break
                    end
                end
            end
        end

        -- PATH 2/3: GC scan fallback
        if not handled then
            local t, a, m = FindLiveWeaponGC()
            if t then
                local magSize = (rawget(t,"Properties") and rawget(t.Properties,"Rounds"))
                                or rawget(t, m) or 30
                pcall(function()
                    t[a] = magSize
                    t[m] = 9999
                    t.IsReloading  = false
                    t.IsBurstShooting = false
                end)
            end
        end
    end)
end

-- ─────────────────────────────────────────────────────────────────────────
--  ZERO SPREAD
-- ─────────────────────────────────────────────────────────────────────────
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

-- ─────────────────────────────────────────────────────────────────────────
--  FPS BOOST
-- ─────────────────────────────────────────────────────────────────────────
local fpsActive   = false
local fpsThread   = nil
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

-- ═══════════════════════════════════════════════════════════════════════════
--  WIRE FEATURES INTO TABS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
--  TAB 1  — Combat  (ESP, Max Velocity, Zero Spread)
-- ─────────────────────────────────────────────────────────────
Section(Tab1, "  ◆ VISUAL")

FluentToggle(Tab1, "Full Body ESP", "Enemy highlights through walls", function(v)
    ESPConfig.Enabled = v
    return v
end)(true)  -- starts ON

Section(Tab1, "  ◆ AIMBOT")

FluentToggle(Tab1, "Max Velocity", "Snap aimbot — PullStrength 65, head target", function(v)
    local t = FindVelocityTable()
    if t then
        if v then pcall(ApplyVelocityON, t); task.defer(HookSmoke)
        else       pcall(ApplyVelocityOFF, t) end
        return v
    end
    warn("[Bloxstrike] Velocity table not found — fire weapon first.")
    return false
end)

Section(Tab1, "  ◆ BULLET")

FluentToggle(Tab1, "Zero Spread", "Hooks applySpread — stays hooked until rejoin", function(v)
    if v then
        local ok = TryHookSpread()
        if not ok then warn("[Bloxstrike] Spread fn not found — fire weapon once then toggle.") end
        return ok and v or false
    end
    return false
end)

-- ─────────────────────────────────────────────────────────────
--  TAB 2  — Weapon  (Infinite Ammo)
-- ─────────────────────────────────────────────────────────────
Section(Tab2, "  ◆ AMMO")

FluentToggle(Tab2, "Infinite Ammo", "Heartbeat — resets Rounds+Capacity+IsReloading every frame", function(v)
    ammoActive = v
    if v then
        if ammoConn then ammoConn:Disconnect(); ammoConn = nil end
        RunAmmoHook()
    else
        if ammoConn then ammoConn:Disconnect(); ammoConn = nil end
    end
    return v
end)

-- ─────────────────────────────────────────────────────────────
--  TAB 3  — Performance  (FPS Boost)
-- ─────────────────────────────────────────────────────────────
Section(Tab3, "  ◆ RENDERING")

FluentToggle(Tab3, "FPS Boost", "Kills shadows, atmosphere, particles + Level01", function(v)
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

-- ─────────────────────────────────────────────────────────────
--  TAB 4  — (free for future features)
-- ─────────────────────────────────────────────────────────────

-- ─────────────────────────────────────────────────────────────
--  TAB 5  — Info / Notes
-- ─────────────────────────────────────────────────────────────
Section(Tab5, "  ◆ VERSION")
AddButton(Tab5, "v6.2  —  Velocity Suite", function() end)
Section(Tab5, "  ◆ NOTES")
AddButton(Tab5, "AutoFire & AutoHeadshot REMOVED", function() end)
AddButton(Tab5, "Infinite Ammo: Heartbeat, IsReloading fix", function() end)
AddButton(Tab5, "FPS Boost: shadows off + Level01", function() end)

-- ── Done ─────────────────────────────────────────────────────
print("[Bloxstrike] v6.2 Loaded — UI: Fluent Template")
print("  Tab 1: ESP | MaxVelocity | ZeroSpread")
print("  Tab 2: InfiniteAmmo (Heartbeat, IsReloading fix)")
print("  Tab 3: FPS Boost")
print("  Tab 5: Info")
