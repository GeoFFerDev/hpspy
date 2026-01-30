-- ========================================
-- ESP LOADSTRING HOOK SCRIPT
-- ========================================
-- Run this script FIRST, then run your ESP
-- It will capture and save all downloaded code
-- ========================================

print("===========================================")
print("ESP Loadstring Hook - Starting...")
print("===========================================")

-- Table to store all captured scripts
_G.CapturedScripts = {}
local captureCount = 0

-- ========================================
-- HOOK 1: HttpGet (Captures downloads)
-- ========================================
local oldHttpGet = game.HttpGet
local oldHttpGetAsync = game.HttpGetAsync

game.HttpGet = newcclosure(function(self, url, ...)
    print("\n[HTTP GET INTERCEPTED]")
    print("URL:", url)
    
    -- Call original function to get content
    local content = oldHttpGet(self, url, ...)
    
    print("Content Length:", #content, "bytes")
    print("First 200 chars:")
    print(string.sub(content, 1, 200))
    print("...")
    
    -- Save to file
    captureCount = captureCount + 1
    local filename = "captured_http_" .. captureCount .. ".lua"
    
    -- Try to save file (works in most executors)
    local success, err = pcall(function()
        writefile(filename, content)
        print("✓ Saved to:", filename)
    end)
    
    if not success then
        print("⚠ Could not save file:", err)
        print("(Your executor might not support writefile)")
    end
    
    -- Store in table
    table.insert(_G.CapturedScripts, {
        type = "HttpGet",
        url = url,
        content = content,
        timestamp = os.time()
    })
    
    print("----------------------------------------")
    
    return content
end)

-- Also hook HttpGetAsync (some scripts use this)
game.HttpGetAsync = newcclosure(function(self, url, ...)
    print("\n[HTTP GET ASYNC INTERCEPTED]")
    print("URL:", url)
    
    local content = oldHttpGetAsync(self, url, ...)
    
    print("Content Length:", #content, "bytes")
    
    captureCount = captureCount + 1
    local filename = "captured_http_async_" .. captureCount .. ".lua"
    
    pcall(function()
        writefile(filename, content)
        print("✓ Saved to:", filename)
    end)
    
    table.insert(_G.CapturedScripts, {
        type = "HttpGetAsync",
        url = url,
        content = content,
        timestamp = os.time()
    })
    
    print("----------------------------------------")
    
    return content
end)

-- ========================================
-- HOOK 2: loadstring (Captures execution)
-- ========================================
local oldLoadstring = loadstring

loadstring = function(source, chunkname, ...)
    print("\n[LOADSTRING INTERCEPTED]")
    
    if type(source) == "string" then
        print("Source Length:", #source, "bytes")
        print("First 200 chars:")
        print(string.sub(source, 1, 200))
        print("...")
        
        -- Save to file
        captureCount = captureCount + 1
        local filename = "captured_loadstring_" .. captureCount .. ".lua"
        
        pcall(function()
            writefile(filename, source)
            print("✓ Saved to:", filename)
        end)
        
        -- Store in table
        table.insert(_G.CapturedScripts, {
            type = "loadstring",
            source = source,
            chunkname = chunkname,
            timestamp = os.time()
        })
    else
        print("Source Type:", type(source))
    end
    
    print("----------------------------------------")
    
    return oldLoadstring(source, chunkname, ...)
end

-- ========================================
-- HOOK 3: require (Catches module loads)
-- ========================================
local oldRequire = require

require = function(module, ...)
    if type(module) == "string" or (typeof(module) == "Instance" and module:IsA("ModuleScript")) then
        local moduleName = type(module) == "string" and module or module:GetFullName()
        
        -- Only log if it looks like it might be ESP-related
        if string.find(string.lower(moduleName), "esp") or 
           string.find(string.lower(moduleName), "hack") or
           string.find(string.lower(moduleName), "cheat") then
            print("\n[REQUIRE INTERCEPTED]")
            print("Module:", moduleName)
            print("----------------------------------------")
        end
    end
    
    return oldRequire(module, ...)
end

print("\n✓ Hooks installed successfully!")
print("✓ HttpGet is hooked")
print("✓ HttpGetAsync is hooked")
print("✓ loadstring is hooked")
print("✓ require is hooked")
print("\n===========================================")
print("Now run your ESP script!")
print("All captured code will be saved automatically")
print("===========================================\n")

-- ========================================
-- UTILITY FUNCTIONS
-- ========================================

-- Function to print all captured scripts
_G.PrintCapturedScripts = function()
    print("\n=== CAPTURED SCRIPTS SUMMARY ===")
    print("Total scripts captured:", #_G.CapturedScripts)
    
    for i, script in ipairs(_G.CapturedScripts) do
        print("\n[" .. i .. "] " .. script.type)
        if script.url then
            print("  URL:", script.url)
        end
        if script.content then
            print("  Size:", #script.content, "bytes")
        elseif script.source then
            print("  Size:", #script.source, "bytes")
        end
        print("  Time:", os.date("%H:%M:%S", script.timestamp))
    end
    print("================================\n")
end

-- Function to get a specific captured script
_G.GetCapturedScript = function(index)
    if _G.CapturedScripts[index] then
        local script = _G.CapturedScripts[index]
        return script.content or script.source
    else
        print("No script at index", index)
        return nil
    end
end

-- Function to save all captured scripts
_G.SaveAllCaptured = function()
    print("\n=== SAVING ALL CAPTURED SCRIPTS ===")
    
    for i, script in ipairs(_G.CapturedScripts) do
        local content = script.content or script.source
        if content then
            local filename = string.format("all_captured_%d_%s.lua", i, script.type)
            pcall(function()
                writefile(filename, content)
                print("Saved:", filename)
            end)
        end
    end
    
    print("====================================\n")
end

-- ========================================
-- AUTO-SAVE AFTER DELAY (Optional)
-- ========================================
task.spawn(function()
    task.wait(30) -- Wait 30 seconds after hooks are installed
    
    if #_G.CapturedScripts > 0 then
        print("\n[AUTO-SAVE] Detected", #_G.CapturedScripts, "captured scripts")
        print("[AUTO-SAVE] Use _G.PrintCapturedScripts() to see details")
        print("[AUTO-SAVE] Use _G.SaveAllCaptured() to save all files")
    else
        print("\n[AUTO-SAVE] No scripts captured yet")
        print("Make sure to run your ESP script!")
    end
end)

print("Hooks are ready! Waiting for ESP to load...")
