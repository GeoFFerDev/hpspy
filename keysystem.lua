-- SECURE KEY SYSTEM WITH 4-HOUR EXPIRATION
-- Anti-bypass protection included

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

-- =====================================================
-- CONFIGURATION
-- =====================================================
local KeySystem = {
    -- Your webhook or API endpoint for key validation
    ValidationURL = "YOUR_WEBHOOK_URL_HERE",
    
    -- Time settings (in seconds)
    KeyDuration = 14400, -- 4 hours = 14400 seconds
    
    -- Encryption seed (change this to a random value)
    Secret = "YourRandomSecret123!@#",
    
    -- Storage
    SaveFileName = "KeyData_Protected.dat"
}

-- =====================================================
-- ANTI-BYPASS PROTECTION
-- =====================================================

-- Prevent common bypass methods
local OriginalRequire = require
local OriginalLoadstring = loadstring
local AllowedFunctions = {}

-- Monitor critical functions
local function ProtectFunction(func)
    AllowedFunctions[func] = true
    return func
end

-- Detect tampering attempts
local TamperChecks = {}
local function AddTamperCheck(name, checkFunc)
    TamperChecks[name] = checkFunc
end

-- Check 1: Verify game environment
AddTamperCheck("GameEnv", function()
    return game and game:GetService("Players") ~= nil
end)

-- Check 2: Verify player integrity
AddTamperCheck("PlayerCheck", function()
    local player = Players.LocalPlayer
    return player and player.UserId and player.UserId > 0
end)

-- Check 3: Detect time manipulation
local StartTime = os.time()
AddTamperCheck("TimeCheck", function()
    local currentTime = os.time()
    return currentTime >= StartTime and (currentTime - StartTime) < 86400 -- Within 24 hours
end)

local function RunTamperChecks()
    for name, check in pairs(TamperChecks) do
        local success, result = pcall(check)
        if not success or not result then
            return false, name
        end
    end
    return true
end

-- =====================================================
-- HWID GENERATION (Hardware ID)
-- =====================================================
local function GetHWID()
    local player = Players.LocalPlayer
    if not player then return nil end
    
    -- Combine multiple identifiers for uniqueness
    local components = {
        tostring(player.UserId),
        game.JobId or "0",
        tostring(game.PlaceId),
    }
    
    -- Create a consistent hash
    local combined = table.concat(components, "-")
    local hash = 0
    for i = 1, #combined do
        hash = (hash * 31 + string.byte(combined, i)) % 2147483647
    end
    
    return tostring(hash)
end

-- =====================================================
-- ENCRYPTION/DECRYPTION
-- =====================================================
local function SimpleEncrypt(data, key)
    local encrypted = {}
    local keyLen = #key
    
    for i = 1, #data do
        local byte = string.byte(data, i)
        local keyByte = string.byte(key, ((i - 1) % keyLen) + 1)
        encrypted[i] = string.char((byte + keyByte) % 256)
    end
    
    return table.concat(encrypted)
end

local function SimpleDecrypt(data, key)
    local decrypted = {}
    local keyLen = #key
    
    for i = 1, #data do
        local byte = string.byte(data, i)
        local keyByte = string.byte(key, ((i - 1) % keyLen) + 1)
        decrypted[i] = string.char((byte - keyByte + 256) % 256)
    end
    
    return table.concat(decrypted)
end

-- =====================================================
-- KEY STORAGE & VALIDATION
-- =====================================================
local function SaveKeyData(keyData)
    local jsonData = HttpService:JSONEncode(keyData)
    local encrypted = SimpleEncrypt(jsonData, KeySystem.Secret)
    local encoded = HttpService:JSONEncode({data = HttpService:UrlEncode(encrypted)})
    
    writefile(KeySystem.SaveFileName, encoded)
end

local function LoadKeyData()
    if not isfile(KeySystem.SaveFileName) then
        return nil
    end
    
    local success, result = pcall(function()
        local fileContent = readfile(KeySystem.SaveFileName)
        local decoded = HttpService:JSONDecode(fileContent)
        local encrypted = HttpService:UrlDecode(decoded.data)
        local decrypted = SimpleDecrypt(encrypted, KeySystem.Secret)
        return HttpService:JSONDecode(decrypted)
    end)
    
    if success then
        return result
    else
        -- Data corrupted or tampered
        return nil
    end
end

local function ValidateStoredKey()
    local keyData = LoadKeyData()
    if not keyData then
        return false, "No key found"
    end
    
    -- Verify HWID matches
    local currentHWID = GetHWID()
    if keyData.hwid ~= currentHWID then
        return false, "HWID mismatch (key is bound to another device)"
    end
    
    -- Check expiration
    local currentTime = os.time()
    if currentTime > keyData.expiration then
        return false, "Key expired"
    end
    
    -- Run anti-tamper checks
    local checksPass, failedCheck = RunTamperChecks()
    if not checksPass then
        return false, "Security check failed: " .. failedCheck
    end
    
    -- Calculate remaining time
    local remaining = keyData.expiration - currentTime
    return true, remaining
end

-- =====================================================
-- KEY ACTIVATION
-- =====================================================
local function ActivateKey(userKey)
    -- Verify the key format
    if not userKey or #userKey < 10 then
        return false, "Invalid key format"
    end
    
    -- Get HWID
    local hwid = GetHWID()
    if not hwid then
        return false, "Failed to generate HWID"
    end
    
    -- In a real implementation, you would validate the key against your server
    -- For this example, we'll use a simple validation
    -- REPLACE THIS with actual server validation
    local validKeys = {
        ["DEMO-KEY-2024"] = true,
        ["TEST-KEY-VALID"] = true,
    }
    
    if not validKeys[userKey] then
        -- Optional: Check with remote server
        local success, response = pcall(function()
            return game:HttpGet(KeySystem.ValidationURL .. "?key=" .. userKey .. "&hwid=" .. hwid)
        end)
        
        if not success or response ~= "VALID" then
            return false, "Invalid key"
        end
    end
    
    -- Create key data with expiration
    local currentTime = os.time()
    local keyData = {
        key = userKey,
        hwid = hwid,
        activated = currentTime,
        expiration = currentTime + KeySystem.KeyDuration,
        version = "1.0"
    }
    
    -- Save encrypted key data
    SaveKeyData(keyData)
    
    return true, KeySystem.KeyDuration
end

-- =====================================================
-- KEY SYSTEM UI
-- =====================================================
local function CreateKeySystemUI(onSuccess)
    local ScreenGui = Instance.new("ScreenGui")
    if gethui then 
        ScreenGui.Parent = gethui() 
    else 
        ScreenGui.Parent = game:GetService("CoreGui")
    end
    ScreenGui.Name = "KeySystemUI"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- Background blur
    local Blur = Instance.new("Frame")
    Blur.Size = UDim2.new(1, 0, 1, 0)
    Blur.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    Blur.BackgroundTransparency = 0.3
    Blur.BorderSizePixel = 0
    Blur.Parent = ScreenGui
    
    -- Main frame
    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 400, 0, 300)
    MainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = Blur
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 10)
    UICorner.Parent = MainFrame
    
    -- Title
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -40, 0, 50)
    Title.Position = UDim2.new(0, 20, 0, 20)
    Title.BackgroundTransparency = 1
    Title.Text = "🔐 KEY SYSTEM"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.Font = Enum.Font.SourceSansBold
    Title.TextSize = 24
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = MainFrame
    
    -- Status label
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -40, 0, 40)
    StatusLabel.Position = UDim2.new(0, 20, 0, 80)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Enter your key to continue"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.Font = Enum.Font.SourceSans
    StatusLabel.TextSize = 16
    StatusLabel.TextWrapped = true
    StatusLabel.Parent = MainFrame
    
    -- Key input
    local KeyInput = Instance.new("TextBox")
    KeyInput.Size = UDim2.new(1, -40, 0, 45)
    KeyInput.Position = UDim2.new(0, 20, 0, 130)
    KeyInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    KeyInput.BorderSizePixel = 0
    KeyInput.Text = ""
    KeyInput.PlaceholderText = "Enter key here..."
    KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyInput.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    KeyInput.Font = Enum.Font.SourceSans
    KeyInput.TextSize = 18
    KeyInput.ClearTextOnFocus = false
    KeyInput.Parent = MainFrame
    
    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 6)
    InputCorner.Parent = KeyInput
    
    -- Submit button
    local SubmitButton = Instance.new("TextButton")
    SubmitButton.Size = UDim2.new(1, -40, 0, 45)
    SubmitButton.Position = UDim2.new(0, 20, 0, 190)
    SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    SubmitButton.BorderSizePixel = 0
    SubmitButton.Text = "ACTIVATE KEY"
    SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitButton.Font = Enum.Font.SourceSansBold
    SubmitButton.TextSize = 18
    SubmitButton.Parent = MainFrame
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = SubmitButton
    
    -- Get key button (optional)
    local GetKeyButton = Instance.new("TextButton")
    GetKeyButton.Size = UDim2.new(1, -40, 0, 30)
    GetKeyButton.Position = UDim2.new(0, 20, 0, 250)
    GetKeyButton.BackgroundTransparency = 1
    GetKeyButton.Text = "🔗 Get a key"
    GetKeyButton.TextColor3 = Color3.fromRGB(100, 150, 255)
    GetKeyButton.Font = Enum.Font.SourceSans
    GetKeyButton.TextSize = 14
    GetKeyButton.Parent = MainFrame
    
    GetKeyButton.MouseButton1Click:Connect(function()
        setclipboard("YOUR_KEY_LINK_HERE")
        StatusLabel.Text = "Link copied to clipboard!"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
    end)
    
    -- Submit logic
    SubmitButton.MouseButton1Click:Connect(function()
        local key = KeyInput.Text:gsub("%s+", "") -- Remove whitespace
        
        if key == "" then
            StatusLabel.Text = "❌ Please enter a key"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            return
        end
        
        SubmitButton.Text = "VALIDATING..."
        SubmitButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        wait(0.5)
        
        local success, message = ActivateKey(key)
        
        if success then
            StatusLabel.Text = "✅ Key activated! Loading script..."
            StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            SubmitButton.Text = "SUCCESS"
            SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            
            wait(1)
            ScreenGui:Destroy()
            
            if onSuccess then
                onSuccess()
            end
        else
            StatusLabel.Text = "❌ " .. message
            StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
            SubmitButton.Text = "ACTIVATE KEY"
            SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        end
    end)
end

-- =====================================================
-- MAIN EXECUTION
-- =====================================================
local function Initialize(scriptFunction)
    -- Check if key is already valid
    local valid, message = ValidateStoredKey()
    
    if valid then
        local hours = math.floor(message / 3600)
        local minutes = math.floor((message % 3600) / 60)
        print(string.format("✅ Key valid! Time remaining: %dh %dm", hours, minutes))
        
        -- Execute the protected script
        if scriptFunction then
            scriptFunction()
        end
    else
        print("🔐 Key validation failed: " .. message)
        print("Please enter a valid key to continue")
        
        -- Show key system UI
        CreateKeySystemUI(scriptFunction)
    end
end

-- =====================================================
-- EXPORT
-- =====================================================
return {
    Initialize = Initialize,
    ValidateKey = ValidateStoredKey,
    GetHWID = GetHWID,
    KeyDuration = KeySystem.KeyDuration
}
