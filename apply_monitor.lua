-- ============================================================
-- SKIN APPLY MONITOR  (runs in PARALLEL with skinchanger.lua)
-- Logs the equipped weapon's full geometry to skin_monitor.txt and AUTO-DIFFS
-- every change, so we can see exactly what flips between the "inside-out" state
-- and the "fixed after I nudge a grip value" state.
--
-- Captured per state: Tool.Grip*, the RightGrip weld (hand→Handle) C0/C1,
-- Handle class/size/SpecialMesh, and every SKBody/SKLight/SKExtra part's CFrame
-- RELATIVE to the Handle (+ its weld C0/C1). Relative values only change when the
-- skinchanger (re)applies — so each logged "CHANGE" is one apply, and the diff
-- between the equip-apply and the nudge-fix-apply reveals the bug.
--
--   Watch ON/OFF : auto-log every geometry change (recommended — just equip, then
--                  nudge to fix; the file captures both with a diff).
--   Snapshot     : write a full state dump now (manual before/after).
--   Diff last 2  : diff the two most recent manual snapshots.
--   Clear log    : wipe skin_monitor.txt.
-- ============================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer      = Players.LocalPlayer

local LOGFILE = "skin_monitor.txt"

-- ============================================================
-- File logging (append; falls back to read+write)
-- ============================================================
local function logWrite(text)
    pcall(function()
        if appendfile then
            appendfile(LOGFILE, text .. "\n")
        else
            local existing = (isfile and isfile(LOGFILE)) and readfile(LOGFILE) or ""
            writefile(LOGFILE, existing .. text .. "\n")
        end
    end)
end

-- ============================================================
-- Helpers
-- ============================================================
local function v3s(v)
    return string.format("(%.3f, %.3f, %.3f)", v.X, v.Y, v.Z)
end
local function rotDeg(cf)
    local rx, ry, rz = cf:ToEulerAnglesXYZ()
    return string.format("(%.1f, %.1f, %.1f)", math.deg(rx), math.deg(ry), math.deg(rz))
end
local function partName(p) return p and p.Name or "nil" end

local function getWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, t in ipairs(char:GetChildren()) do
        if t:IsA("Tool") then
            local h = t:FindFirstChild("Handle")
            if h then return t, h end
        end
    end
    return nil
end

-- Capture the weapon's geometry as an ORDERED list of {key, value} pairs.
-- Returns (pairs, equipped:boolean).
local function captureState()
    local p = {}
    local function put(k, v) p[#p + 1] = { k, v } end

    local weapon, handle = getWeapon()
    if not handle then return p, false end

    put("Tool.Name",      weapon.Name)
    put("Grip.Pos",       v3s(weapon.GripPos))
    put("Grip.Forward",   v3s(weapon.GripForward))
    put("Grip.Right",     v3s(weapon.GripRight))
    put("Grip.Up",        v3s(weapon.GripUp))

    put("Handle.Class",        handle.ClassName)
    put("Handle.Size",         v3s(handle.Size))
    put("Handle.Transparency", string.format("%.2f", handle.Transparency))
    local sm = handle:FindFirstChildOfClass("SpecialMesh")
    if sm then
        put("Handle.SpecialMesh.MeshId",      tostring(sm.MeshId))
        put("Handle.SpecialMesh.Scale",       v3s(sm.Scale))
        put("Handle.SpecialMesh.Offset",      v3s(sm.Offset))
        put("Handle.SpecialMesh.VertexColor", v3s(sm.VertexColor))
    end
    if handle:IsA("MeshPart") then
        put("Handle.MeshId", tostring(handle.MeshId))
    end

    -- The RightGrip weld Roblox builds from Tool.Grip (hand -> Handle). Its C0/C1
    -- orientation IS the gun's pose; a stale/transient one = the "inside-out" look.
    local char = LocalPlayer.Character
    if char then
        for _, d in ipairs(char:GetDescendants()) do
            if (d:IsA("Weld") or d:IsA("Motor6D")) and (d.Part1 == handle or d.Part0 == handle) then
                local tag = "GripWeld[" .. d.Name .. "]"
                put(tag .. ".Part0",  partName(d.Part0))
                put(tag .. ".Part1",  partName(d.Part1))
                put(tag .. ".C0.pos", v3s(d.C0.Position))
                put(tag .. ".C0.rot", rotDeg(d.C0))
                put(tag .. ".C1.pos", v3s(d.C1.Position))
                put(tag .. ".C1.rot", rotDeg(d.C1))
            end
        end
    end

    -- Skin-built parts, RELATIVE to the Handle (stable except on re-apply).
    local hInv = handle.CFrame:Inverse()
    for _, c in ipairs(weapon:GetDescendants()) do
        if c:IsA("BasePart") and (c.Name == "SKBody" or c.Name == "SKLight"
            or c.Name:sub(1, 8) == "SKExtra_") then
            local tag = c.Name
            if c.Name == "SKLight" then
                tag = "SKLight[" .. tostring(c:GetAttribute("SKLightIdx") or "?") .. "]"
            end
            local rel = hInv * c.CFrame
            put(tag .. ".relPos", v3s(rel.Position))
            put(tag .. ".relRot", rotDeg(rel))
            put(tag .. ".size",   v3s(c.Size))
            if c:IsA("MeshPart") then
                put(tag .. ".DoubleSided", tostring(c.DoubleSided))
                put(tag .. ".MeshId",      tostring(c.MeshId))
            end
            for _, w in ipairs(c:GetChildren()) do
                if w:IsA("Weld") or w:IsA("WeldConstraint") then
                    put(tag .. ".weld.Class", w.ClassName)
                    put(tag .. ".weld.Part0", partName(w.Part0))
                    if w:IsA("Weld") then
                        put(tag .. ".weld.C0.pos", v3s(w.C0.Position))
                        put(tag .. ".weld.C0.rot", rotDeg(w.C0))
                        put(tag .. ".weld.C1.pos", v3s(w.C1.Position))
                        put(tag .. ".weld.C1.rot", rotDeg(w.C1))
                    end
                end
            end
        end
    end
    return p, true
end

local function toMap(p)
    local m = {}
    for _, kv in ipairs(p) do m[kv[1]] = kv[2] end
    return m
end

-- Lines that differ between two captures (added / changed / removed).
local function diffPairs(prev, cur)
    local pm, cm, out = toMap(prev), toMap(cur), {}
    for _, kv in ipairs(cur) do
        local k, v = kv[1], kv[2]
        if pm[k] == nil then out[#out + 1] = "  + " .. k .. " = " .. v
        elseif pm[k] ~= v then out[#out + 1] = "  ~ " .. k .. ":  " .. pm[k] .. "   ->   " .. v end
    end
    for _, kv in ipairs(prev) do
        if cm[kv[1]] == nil then out[#out + 1] = "  - " .. kv[1] .. "  (was " .. kv[2] .. ")" end
    end
    return out
end

local function fullText(label, p)
    local lines = { "===== " .. label .. "  @" .. os.date("%X")
        .. "  t=" .. string.format("%.2f", os.clock()) .. " =====" }
    for _, kv in ipairs(p) do lines[#lines + 1] = "  " .. kv[1] .. " = " .. kv[2] end
    return table.concat(lines, "\n")
end

-- ============================================================
-- GUI
-- ============================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "SkinApplyMonitor"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size             = UDim2.new(0, 280, 0, 232)
MainFrame.Position         = UDim2.new(0.5, 170, 0.5, -116)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
MainFrame.BorderSizePixel  = 0
MainFrame.Parent           = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel")
Title.Size             = UDim2.new(1, 0, 0, 36)
Title.BackgroundColor3 = Color3.fromRGB(32, 40, 50)
Title.BorderSizePixel  = 0
Title.Text             = "Skin Apply Monitor"
Title.TextColor3       = Color3.fromRGB(255, 255, 255)
Title.TextSize         = 15
Title.Font             = Enum.Font.GothamBold
Title.Parent           = MainFrame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local Status = Instance.new("TextLabel")
Status.Size             = UDim2.new(0.9, 0, 0, 26)
Status.Position         = UDim2.new(0.05, 0, 0, 42)
Status.BackgroundColor3 = Color3.fromRGB(30, 34, 42)
Status.BorderSizePixel  = 0
Status.Text             = "Watch: OFF   changes: 0"
Status.TextColor3       = Color3.fromRGB(180, 220, 180)
Status.TextSize         = 13
Status.Font             = Enum.Font.Gotham
Status.Parent           = MainFrame
Instance.new("UICorner", Status).CornerRadius = UDim.new(0, 6)

local function mkButton(text, y, color)
    local b = Instance.new("TextButton")
    b.Size             = UDim2.new(0.9, 0, 0, 32)
    b.Position         = UDim2.new(0.05, 0, 0, y)
    b.BackgroundColor3 = color
    b.BorderSizePixel  = 0
    b.Text             = text
    b.TextColor3       = Color3.fromRGB(255, 255, 255)
    b.TextSize         = 14
    b.Font             = Enum.Font.GothamBold
    b.Parent           = MainFrame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local WatchButton = mkButton("Watch: OFF (click to start)", 76,  Color3.fromRGB(55, 110, 200))
local SnapButton  = mkButton("Snapshot now",                114, Color3.fromRGB(95, 55, 190))
local DiffButton  = mkButton("Diff last 2 snapshots",       152, Color3.fromRGB(60, 130, 90))
local ClearButton = mkButton("Clear log",                   190, Color3.fromRGB(150, 70, 60))

local function flash(b, msg)
    local o = b.Text
    b.Text = msg
    task.delay(1.6, function() b.Text = o end)
end

-- ============================================================
-- State
-- ============================================================
local snapshots   = {}      -- manual snapshots for Diff
local watching    = false
local watchConn
local lastPairs    = nil
local lastEquipped = nil
local changeCount  = 0

local function setStatus()
    Status.Text = string.format("Watch: %s   changes: %d", watching and "ON" or "OFF", changeCount)
end

-- ============================================================
-- Watch — auto-diff on every geometry change
-- ============================================================
local function watchTick()
    local p, equipped = captureState()

    if equipped ~= lastEquipped then
        if equipped then
            logWrite("\n######## WEAPON EQUIPPED @" .. os.date("%X") .. " ########")
            logWrite(fullText("EQUIP baseline", p))
        else
            logWrite("\n######## WEAPON REMOVED @" .. os.date("%X") .. " ########")
        end
        lastEquipped = equipped
        lastPairs = equipped and p or nil
        return
    end

    if not equipped then return end
    if lastPairs then
        local d = diffPairs(lastPairs, p)
        if #d > 0 then
            changeCount = changeCount + 1
            setStatus()
            logWrite("\n---- CHANGE #" .. changeCount .. "  @" .. os.date("%X")
                .. "  t=" .. string.format("%.2f", os.clock()) .. " ----")
            for _, line in ipairs(d) do logWrite(line) end
            lastPairs = p
        end
    else
        lastPairs = p
    end
end

WatchButton.MouseButton1Click:Connect(function()
    watching = not watching
    if watching then
        WatchButton.Text = "Watch: ON (click to stop)"
        WatchButton.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
        lastPairs, lastEquipped = nil, nil
        logWrite("\n================ WATCH STARTED @" .. os.date("%c") .. " ================")
        local acc = 0
        watchConn = RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            if acc >= 0.2 then acc = 0; pcall(watchTick) end
        end)
    else
        WatchButton.Text = "Watch: OFF (click to start)"
        WatchButton.BackgroundColor3 = Color3.fromRGB(55, 110, 200)
        if watchConn then watchConn:Disconnect(); watchConn = nil end
        logWrite("\n================ WATCH STOPPED @" .. os.date("%c") .. " ================")
    end
    setStatus()
end)

SnapButton.MouseButton1Click:Connect(function()
    local p, equipped = captureState()
    if not equipped then flash(SnapButton, "No weapon!"); return end
    snapshots[#snapshots + 1] = p
    logWrite("\n" .. fullText("MANUAL SNAPSHOT #" .. #snapshots, p))
    print("[Monitor] Snapshot #" .. #snapshots .. " -> " .. LOGFILE)
    flash(SnapButton, "Saved snapshot #" .. #snapshots)
end)

DiffButton.MouseButton1Click:Connect(function()
    if #snapshots < 2 then flash(DiffButton, "Need 2 snapshots"); return end
    local a, b = snapshots[#snapshots - 1], snapshots[#snapshots]
    local d = diffPairs(a, b)
    logWrite("\n==== DIFF snapshot #" .. (#snapshots - 1) .. " -> #" .. #snapshots .. " ====")
    if #d == 0 then logWrite("  (identical)") else
        for _, line in ipairs(d) do logWrite(line) end
    end
    print("[Monitor] Diff #" .. (#snapshots - 1) .. "->#" .. #snapshots .. " (" .. #d .. " changes) -> " .. LOGFILE)
    flash(DiffButton, #d .. " changes -> file")
end)

ClearButton.MouseButton1Click:Connect(function()
    pcall(function() writefile(LOGFILE, "") end)
    snapshots = {}
    changeCount = 0
    lastPairs, lastEquipped = nil, nil
    setStatus()
    flash(ClearButton, "Log cleared")
end)

-- ============================================================
-- Drag
-- ============================================================
local dragging, dragStart, startPos
Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging, dragStart, startPos = true, input.Position, MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local d = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + d.X,
            startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)

setStatus()
logWrite("\n================ MONITOR LOADED @" .. os.date("%c") .. " ================")
print("Skin Apply Monitor loaded! Turn Watch ON, equip the gun (inside-out), then nudge a grip value to fix it. Read " .. LOGFILE)