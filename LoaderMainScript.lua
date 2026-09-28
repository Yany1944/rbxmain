-- ════════════════════════════════════════════════════════════
--  Violite  ·  Linear design system
-- ════════════════════════════════════════════════════════════

if _G.__VIOLITE_ACTIVE then return end
_G.__VIOLITE_ACTIVE = true

local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CoreGui      = game:GetService("CoreGui")
local RunService   = game:GetService("RunService")
local LocalPlayer  = Players.LocalPlayer

--local VALID_PLACES = { [142823291] = true, [335132309] = true }
local MIN_SRC_LEN  = 128

local SCRIPT_URLS = {
    Main = "https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/MainScript.lua",
    Leaderboard = "https://raw.githubusercontent.com/Yany1944/rbxmain/refs/heads/main/leaderboard.lua"
}

-- ── Security ──────────────────────────────────────────────────────
local function securityCheck()
    if RunService:IsStudio() then return false, "Studio не поддерживается" end
    --if not VALID_PLACES[game.PlaceId] then return false, "PlaceId не поддерживается" end
    if not LocalPlayer then return false, "LocalPlayer недоступен" end
    return true
end

local passed, reason = securityCheck()
if not passed then
    _G.__VIOLITE_ACTIVE = nil
    LocalPlayer:Kick("Игра не поддерживается · " .. (reason or ""))
    return
end

-- ── Colors ────────────────────────────────────────────────────────
local C = {
    Canvas    = Color3.fromRGB(1, 1, 2),
    Surface1  = Color3.fromRGB(14, 14, 19),
    Surface2  = Color3.fromRGB(21, 21, 29),
    Surface3  = Color3.fromRGB(30, 30, 40),

    Hairline  = Color3.fromRGB(35, 37, 42),

    Primary   = Color3.fromRGB(94, 106, 210),
    PrimaryH  = Color3.fromRGB(130, 143, 255),
    PrimaryF  = Color3.fromRGB(94, 105, 209),

    Secondary  = Color3.fromRGB(48, 51, 58),
    SecondaryH = Color3.fromRGB(66, 70, 80),
    SecondaryF = Color3.fromRGB(40, 43, 50),

    Ink       = Color3.fromRGB(247, 248, 248),
    InkTert   = Color3.fromRGB(98, 102, 109),

    Success   = Color3.fromRGB(39, 166, 68),
    White     = Color3.fromRGB(255, 255, 255),
    Black     = Color3.fromRGB(0, 0, 0),
}

local W, H = 316, 270

-- ── Helpers ───────────────────────────────────────────────────────
local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do
        o[k] = v
    end
    if parent then
        o.Parent = parent
    end
    return o
end

local function corner(p, r)
    inst("UICorner", {
        CornerRadius = UDim.new(0, r),
        Parent = p
    })
end

local function hairline(p)
    inst("UIStroke", {
        Thickness = 1,
        Color = C.Hairline,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = p,
    })
end

local function tw(obj, dur, style, dir, props)
    TweenService:Create(
        obj,
        TweenInfo.new(
            dur,
            style or Enum.EasingStyle.Quad,
            dir or Enum.EasingDirection.Out
        ),
        props
    ):Play()
end

-- ── GUI ───────────────────────────────────────────────────────────
local gui = inst("ScreenGui", {
    Name = "Violite",
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

local scrim = inst("Frame", {
    Size = UDim2.new(1,0,1,0),
    BackgroundColor3 = C.Black,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, gui)

local win = inst("Frame", {
    Size = UDim2.new(0, W, 0, H),
    Position = UDim2.new(0.5, -W/2, 0.5, -H/2),
    BackgroundColor3 = C.Surface1,
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, gui)

corner(win, 12)
hairline(win)

-- ── TitleBar ──────────────────────────────────────────────────────
local titleBar = inst("Frame", {
    Size = UDim2.new(1,0,0,40),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel = 0,
}, win)

corner(titleBar, 12)

inst("Frame", {
    Size = UDim2.new(1,0,0.5,0),
    Position = UDim2.new(0,0,0.5,0),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel = 0,
}, titleBar)

inst("Frame", {
    Size = UDim2.new(1,0,0,1),
    Position = UDim2.new(0,0,1,-1),
    BackgroundColor3 = C.Hairline,
    BorderSizePixel = 0,
}, titleBar)

inst("TextLabel", {
    Text = "VIOLITE",
    Size = UDim2.new(1,-70,1,0),
    Position = UDim2.new(0,16,0,0),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    TextColor3 = C.Ink,
    TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

inst("TextLabel", {
    Text = "v2.0",
    Size = UDim2.new(0,40,1,0),
    Position = UDim2.new(1,-50,0,0),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = C.InkTert,
    TextXAlignment = Enum.TextXAlignment.Right,
}, titleBar)

-- ── Status Card ───────────────────────────────────────────────────
local card = inst("Frame", {
    Size = UDim2.new(1,-24,0,56),
    Position = UDim2.new(0,12,0,50),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel = 0,
}, win)

corner(card, 8)
hairline(card)

local successBar = inst("Frame", {
    Size = UDim2.new(0,2,0,26),
    Position = UDim2.new(0,0,0.5,-13),
    BackgroundColor3 = C.Success,
    BorderSizePixel = 0,
}, card)

corner(successBar, 1)

inst("TextLabel", {
    Text = "Murder Mystery 2",
    Size = UDim2.new(1,-20,0,20),
    Position = UDim2.new(0,14,0,8),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    TextSize = 13,
    TextColor3 = C.Ink,
    TextXAlignment = Enum.TextXAlignment.Left,
}, card)

inst("TextLabel", {
    Text = "Select script to load",
    Size = UDim2.new(1,-20,0,16),
    Position = UDim2.new(0,14,0,30),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 11,
    TextColor3 = C.Success,
    TextXAlignment = Enum.TextXAlignment.Left,
}, card)

-- ── Progress ──────────────────────────────────────────────────────
local track = inst("Frame", {
    Size = UDim2.new(1,-24,0,2),
    Position = UDim2.new(0,12,1,-58),
    BackgroundColor3 = C.Surface3,
    BorderSizePixel = 0,
    Visible = false,
}, win)

corner(track, 1)

local fill = inst("Frame", {
    Size = UDim2.new(0,0,1,0),
    BackgroundColor3 = C.Primary,
    BorderSizePixel = 0,
}, track)

corner(fill, 1)

-- ── Buttons ───────────────────────────────────────────────────────
local function createButton(text, posY, color)
    local btn = inst("TextButton", {
        Text = text,
        Size = UDim2.new(1,-24,0,36),
        Position = UDim2.new(0,12,0,posY),
        BackgroundColor3 = color,
        BorderSizePixel = 0,
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = C.White,
        AutoButtonColor = false,
    }, win)

    corner(btn, 8)

    return btn
end

local mainBtn = createButton("Load Main Script", 126, C.Primary)
local lbBtn   = createButton("Load Leaderboard", 170, C.Secondary)

-- ── Footer ────────────────────────────────────────────────────────
inst("TextLabel", {
    Text = "Secure connection",
    Size = UDim2.new(1,0,0,14),
    Position = UDim2.new(0,0,1,-20),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextColor3 = C.InkTert,
    TextXAlignment = Enum.TextXAlignment.Center,
}, win)

-- ── Entrance ──────────────────────────────────────────────────────
local function entrance()
    win.Size = UDim2.new(0, W * 0.95, 0, H * 0.95)

    tw(scrim, 0.20, nil, nil, {
        BackgroundTransparency = 0.68
    })

    tw(win, 0.24, nil, nil, {
        BackgroundTransparency = 0,
        Size = UDim2.new(0, W, 0, H),
    })
end

-- ── Loader ────────────────────────────────────────────────────────
local busy = false

local function attachHover(btn, normal, hover, pressed)
    btn.MouseEnter:Connect(function()
        if busy then return end
        tw(btn, 0.12, nil, nil, {
            BackgroundColor3 = hover
        })
    end)

    btn.MouseLeave:Connect(function()
        if busy then return end
        tw(btn, 0.12, nil, nil, {
            BackgroundColor3 = normal
        })
    end)

    btn.MouseButton1Down:Connect(function()
        if busy then return end
        tw(btn, 0.06, nil, nil, {
            BackgroundColor3 = pressed
        })
    end)
end

attachHover(mainBtn, C.Primary, C.PrimaryH, C.PrimaryF)
attachHover(lbBtn, C.Secondary, C.SecondaryH, C.SecondaryF)

local function loadScript(url, clickedButton)
    if busy then return end
    busy = true

    mainBtn.Active = false
    lbBtn.Active = false

    local originalText = clickedButton.Text
    clickedButton.Text = "Loading..."

    track.Visible = true

    tw(fill, 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, {
        Size = UDim2.new(0.75,0,1,0)
    })

    local src
    local ok, err = pcall(function()
        src = game:HttpGet(url, true)
    end)

    local failReason

    if not ok then
        failReason = tostring(err)
    elseif type(src) ~= "string" or src == "" then
        failReason = "empty response"
    elseif #src < MIN_SRC_LEN then
        failReason = "script too short"
    end

    if failReason then
        clickedButton.Text = "Load failed"

        tw(clickedButton, 0.15, nil, nil, {
            BackgroundColor3 = Color3.fromRGB(160, 50, 50)
        })

        task.wait(1.5)

        gui:Destroy()
        _G.__VIOLITE_ACTIVE = nil

        LocalPlayer:Kick("Ошибка загрузки · " .. failReason)
        return
    end

    local fn, compileErr = loadstring(src)

    if not fn then
        gui:Destroy()
        _G.__VIOLITE_ACTIVE = nil

        LocalPlayer:Kick("Ошибка компиляции · " .. tostring(compileErr))
        return
    end

    tw(fill, 0.2, nil, nil, {
        Size = UDim2.new(1,0,1,0)
    })

    clickedButton.Text = "Loaded"

    task.wait(0.3)

    tw(scrim, 0.2, nil, nil, {
        BackgroundTransparency = 1
    })

    tw(win, 0.2, nil, nil, {
        BackgroundTransparency = 1,
        Size = UDim2.new(0, W * 0.95, 0, H * 0.95),
    })

    task.wait(0.22)

    gui:Destroy()

    local runOk, runErr = pcall(fn)

    if not runOk then
        _G.__VIOLITE_ACTIVE = nil
        LocalPlayer:Kick("Ошибка выполнения · " .. tostring(runErr))
    end
end

mainBtn.MouseButton1Click:Connect(function()
    loadScript(SCRIPT_URLS.Main, mainBtn)
end)

lbBtn.MouseButton1Click:Connect(function()
    loadScript(SCRIPT_URLS.Leaderboard, lbBtn)
end)

entrance()