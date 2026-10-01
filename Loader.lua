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

local VALID_PLACES = { [142823291] = true, [335132309] = true }
local MIN_SRC_LEN  = 512
local LOAD_URL     = "https://api.jnkie.com/api/v1/luascripts/public/"
    .. "10201bcb39434fa92f342ad03f7cc96d616794eda20198906b2d678836e99fca/download"

-- ── Security ──────────────────────────────────────────────────────
local function securityCheck()
    if RunService:IsStudio() then return false, "Studio не поддерживается" end
    if not VALID_PLACES[game.PlaceId] then return false, "PlaceId не поддерживается" end
    if not LocalPlayer then return false, "LocalPlayer недоступен" end
    return true
end

local passed, reason = securityCheck()
if not passed then
    _G.__VIOLITE_ACTIVE = nil
    LocalPlayer:Kick("Игра не поддерживается · " .. (reason or ""))
    return
end

-- ── Linear colour tokens ──────────────────────────────────────────
--   canvas (#010102) → surface-1 → surface-2 → surface-3
--   single chromatic accent: lavender-blue #5e6ad2
local C = {
    Canvas    = Color3.fromRGB(  1,   1,   2),   -- #010102
    Surface1  = Color3.fromRGB( 14,  14,  19),   -- one step above canvas
    Surface2  = Color3.fromRGB( 21,  21,  29),   -- two steps
    Surface3  = Color3.fromRGB( 30,  30,  40),   -- three steps

    Hairline  = Color3.fromRGB( 35,  37,  42),   -- #23252a
    HairlineS = Color3.fromRGB( 48,  51,  58),   -- hairline-strong

    Primary   = Color3.fromRGB( 94, 106, 210),   -- #5e6ad2
    PrimaryH  = Color3.fromRGB(130, 143, 255),   -- #828fff  hover
    PrimaryF  = Color3.fromRGB( 94, 105, 209),   -- #5e69d1  pressed

    Ink       = Color3.fromRGB(247, 248, 248),   -- #f7f8f8
    InkMuted  = Color3.fromRGB(208, 214, 224),   -- #d0d6e0
    InkSubtle = Color3.fromRGB(138, 143, 152),   -- #8a8f98
    InkTert   = Color3.fromRGB( 98, 102, 109),   -- #62666d

    Success   = Color3.fromRGB( 39, 166,  68),   -- #27a644  semantic only
    White     = Color3.fromRGB(255, 255, 255),
    Black     = Color3.fromRGB(  0,   0,   0),
}

local W, H = 316, 220

-- ── Helpers ───────────────────────────────────────────────────────
local function inst(cls, props, parent)
    local o = Instance.new(cls)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner(p, r)
    inst("UICorner", { CornerRadius = UDim.new(0, r), Parent = p })
end

local function hairline(p, col, trans)
    inst("UIStroke", {
        Thickness       = 1,
        Color           = col   or C.Hairline,
        Transparency    = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent          = p,
    })
end

local function tw(obj, dur, style, dir, props)
    TweenService:Create(
        obj,
        TweenInfo.new(dur, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

-- ── Screen root ───────────────────────────────────────────────────
local gui = inst("ScreenGui", {
    Name           = "Violite",
    ResetOnSpawn   = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, CoreGui)

-- Overlay scrim
local scrim = inst("Frame", {
    Size                   = UDim2.new(1, 0, 1, 0),
    BackgroundColor3       = C.Black,
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
}, gui)

-- ── Window  (surface-1) ───────────────────────────────────────────
local win = inst("Frame", {
    Size                   = UDim2.new(0, W, 0, H),
    Position               = UDim2.new(0.5, -W/2, 0.5, -H/2),
    BackgroundColor3       = C.Surface1,
    BackgroundTransparency = 1,
    BorderSizePixel        = 0,
}, gui)
corner(win, 12)
hairline(win)


-- ── Title bar  (surface-2 lift) ───────────────────────────────────
local titleBar = inst("Frame", {
    Size             = UDim2.new(1, 0, 0, 40),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, win)
corner(titleBar, 12)

-- Mask bottom corners of title bar
inst("Frame", {
    Size             = UDim2.new(1, 0, 0.5, 0),
    Position         = UDim2.new(0, 0, 0.5, 0),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, titleBar)

-- 1px hairline separator below title
inst("Frame", {
    Size             = UDim2.new(1, 0, 0, 1),
    Position         = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.Hairline,
    BorderSizePixel  = 0,
    ZIndex           = 3,
}, titleBar)

inst("TextLabel", {
    Text                   = "VIOLITE",
    Size                   = UDim2.new(1, -70, 1, 0),
    Position               = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Font                   = Enum.Font.GothamBold,
    TextSize               = 11,
    TextColor3             = C.Ink,
    TextXAlignment         = Enum.TextXAlignment.Left,
    ZIndex                 = 3,
}, titleBar)

inst("TextLabel", {
    Text                   = "v1.0",
    Size                   = UDim2.new(0, 40, 1, 0),
    Position               = UDim2.new(1, -50, 0, 0),
    BackgroundTransparency = 1,
    Font                   = Enum.Font.Gotham,
    TextSize               = 11,
    TextColor3             = C.InkTert,
    TextXAlignment         = Enum.TextXAlignment.Right,
    ZIndex                 = 3,
}, titleBar)

-- ── Status card  (surface-2, rounded.lg 12px) ─────────────────────
local card = inst("Frame", {
    Size             = UDim2.new(1, -24, 0, 56),
    Position         = UDim2.new(0, 12, 0, 50),
    BackgroundColor3 = C.Surface2,
    BorderSizePixel  = 0,
    ZIndex           = 2,
}, win)
corner(card, 8)
hairline(card)

-- 2px success accent bar — the only semantic color on this surface
local successBar = inst("Frame", {
    Size             = UDim2.new(0, 2, 0, 26),
    Position         = UDim2.new(0, 0, 0.5, -13),
    BackgroundColor3 = C.Success,
    BorderSizePixel  = 0,
    ZIndex           = 3,
}, card)
corner(successBar, 1)

inst("TextLabel", {
    Text                   = "Murder Mystery 2",
    Size                   = UDim2.new(1, -20, 0, 20),
    Position               = UDim2.new(0, 14, 0, 8),
    BackgroundTransparency = 1,
    Font                   = Enum.Font.GothamMedium,
    TextSize               = 13,
    TextColor3             = C.Ink,
    TextXAlignment         = Enum.TextXAlignment.Left,
    ZIndex                 = 3,
}, card)

inst("TextLabel", {
    Text                   = "Supported  ·  PlaceId " .. tostring(game.PlaceId),
    Size                   = UDim2.new(1, -20, 0, 16),
    Position               = UDim2.new(0, 14, 0, 30),
    BackgroundTransparency = 1,
    Font                   = Enum.Font.Gotham,
    TextSize               = 11,
    TextColor3             = C.Success,
    TextXAlignment         = Enum.TextXAlignment.Left,
    ZIndex                 = 3,
}, card)

-- ── Progress track  (hidden, 2px) ────────────────────────────────
local track = inst("Frame", {
    Size             = UDim2.new(1, -24, 0, 2),
    Position         = UDim2.new(0, 12, 1, -58),
    BackgroundColor3 = C.Surface3,
    BorderSizePixel  = 0,
    Visible          = false,
    ZIndex           = 2,
}, win)
corner(track, 1)

local fill = inst("Frame", {
    Size             = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = C.Primary,
    BorderSizePixel  = 0,
    ZIndex           = 3,
}, track)
corner(fill, 1)

-- ── Primary CTA  (rounded.md 8px, flat #5e6ad2) ───────────────────
local btn = inst("TextButton", {
    Text             = "Продолжить",
    Size             = UDim2.new(1, -24, 0, 34),
    Position         = UDim2.new(0, 12, 1, -54),
    BackgroundColor3 = C.Primary,
    BorderSizePixel  = 0,
    Font             = Enum.Font.GothamMedium,
    TextSize         = 13,
    TextColor3       = C.White,
    AutoButtonColor  = false,
    ZIndex           = 2,
}, win)
corner(btn, 8)

-- ── Footer ────────────────────────────────────────────────────────
inst("TextLabel", {
    Text                   = "Secure connection",
    Size                   = UDim2.new(1, 0, 0, 14),
    Position               = UDim2.new(0, 0, 1, -20),
    BackgroundTransparency = 1,
    Font                   = Enum.Font.Gotham,
    TextSize               = 10,
    TextColor3             = C.InkTert,
    TextXAlignment         = Enum.TextXAlignment.Center,
    ZIndex                 = 2,
}, win)

-- ── Entrance ──────────────────────────────────────────────────────
local function entrance()
    win.Size     = UDim2.new(0, W * 0.95, 0, H * 0.95)
    win.Position = UDim2.new(0.5, -(W * 0.95)/2, 0.5, -(H * 0.95)/2)

    tw(scrim, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { BackgroundTransparency = 0.68 })
    tw(win, 0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, {
        BackgroundTransparency = 0,
        Size                   = UDim2.new(0, W, 0, H),
        Position               = UDim2.new(0.5, -W/2, 0.5, -H/2),
    })
end

-- ── Button interactions ───────────────────────────────────────────
local btnReady = true

btn.MouseEnter:Connect(function()
    if not btnReady then return end
    tw(btn, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { BackgroundColor3 = C.PrimaryH })
end)
btn.MouseLeave:Connect(function()
    if not btnReady then return end
    tw(btn, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { BackgroundColor3 = C.Primary })
end)
btn.MouseButton1Down:Connect(function()
    if not btnReady then return end
    tw(btn, 0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { BackgroundColor3 = C.PrimaryF })
end)

-- ── Loading dots ──────────────────────────────────────────────────
local dotsActive = false
local function startDots()
    dotsActive = true
    task.spawn(function()
        local seq = { "Загрузка", "Загрузка.", "Загрузка..", "Загрузка..." }
        local i = 1
        while dotsActive do
            btn.Text = seq[i]
            i = i % #seq + 1
            task.wait(0.30)
        end
    end)
end

-- ── Click ─────────────────────────────────────────────────────────
btn.MouseButton1Click:Connect(function()
    if not btnReady then return end
    btnReady = false

    tw(btn, 0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { BackgroundColor3 = C.PrimaryF })
    task.wait(0.08)

    btn.Font = Enum.Font.Gotham
    startDots()

    track.Visible = true
    tw(fill, 1.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut,
        { Size = UDim2.new(0.78, 0, 1, 0) })

    task.wait(1.9)

    -- [SEC-3] fetch
    local src
    local fetchOk, fetchErr = pcall(function()
        src = game:HttpGet(LOAD_URL, true)
    end)

    local failReason
    if not fetchOk then
        failReason = tostring(fetchErr)
    elseif type(src) ~= "string" or src == "" then
        failReason = "пустой ответ от сервера"
    elseif #src < MIN_SRC_LEN then
        failReason = "ответ слишком короткий (" .. #src .. " байт)"
    end

    if failReason then
        dotsActive = false
        btn.Text = "Ошибка загрузки"
        tw(btn, 0.12, nil, nil, { BackgroundColor3 = Color3.fromRGB(160, 50, 50) })
        task.wait(1.5)
        gui:Destroy()
        _G.__VIOLITE_ACTIVE = nil
        LocalPlayer:Kick("Ошибка загрузки · " .. failReason)
        return
    end

    -- [SEC-4] compile
    local fn, compileErr = loadstring(src)
    if not fn then
        dotsActive = false
        gui:Destroy()
        _G.__VIOLITE_ACTIVE = nil
        LocalPlayer:Kick("Ошибка компиляции · " .. tostring(compileErr))
        return
    end

    tw(fill, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
        { Size = UDim2.new(1, 0, 1, 0) })
    task.wait(0.12)

    dotsActive = false
    btn.Text = "Готово"
    task.wait(0.28)

    -- Exit
    tw(scrim, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In,
        { BackgroundTransparency = 1 })
    tw(win, 0.20, Enum.EasingStyle.Quad, Enum.EasingDirection.In, {
        BackgroundTransparency = 1,
        Size                   = UDim2.new(0, W * 0.95, 0, H * 0.95),
        Position               = UDim2.new(0.5, -(W*0.95)/2, 0.5, -(H*0.95)/2),
    })
    task.wait(0.22)
    gui:Destroy()

    -- [SEC-5] execute
    local runOk, runErr = pcall(fn)
    if not runOk then
        _G.__VIOLITE_ACTIVE = nil
        LocalPlayer:Kick("Ошибка выполнения · " .. tostring(runErr))
    end
end)

entrance()