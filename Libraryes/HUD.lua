-- ══════════════════════════════════════════════════════════════════════════════
-- БЛОК 1: ИНИЦИАЛИЗАЦИЯ, CONFIG И СОСТОЯНИЕ
-- ══════════════════════════════════════════════════════════════════════════════
-- HUD: центральная панель под курсором («violite ♥ mm2» + активные бинды) и
-- кроссхейр, который подменяет курсор shift-lock и прицел пистолета.
-- Грузится из MainScript (БЛОК 19) как фабрика: return function(env) ... end.
--
-- Оба курсора MM2 — это Mouse.Icon (MouseLockController ставит MouseLockedCursor,
-- скрипт пистолета — свой прицел). Поэтому кроссхейр активен, когда иконка мыши
-- переопределена или мышь залочена по центру: тогда системный курсор прячется
-- через MouseIconEnabled, а при открытом меню всё возвращается как было.
--
-- Рисуется обычным GUI, а не Drawing: Drawing в executor'е живёт в физических
-- пикселях, а мышь и вьюпорт Roblox — в логических. На мониторе с масштабом
-- Windows ≠ 100 % панель и прицел съезжали от центра и от курсора
return function(env)
    if not game:IsLoaded() then game.Loaded:Wait() end
    local okEnv, shared = pcall(function() return getgenv() end)
    assert(okEnv and shared, "HUD: executor environment unavailable")
    if shared.MM2_HUDModule then return shared.MM2_HUDModule end

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local CoreGui = game:GetService("CoreGui")
    local LocalPlayer = Players.LocalPlayer

    local Main = env.State            -- State из MainScript (Settings / Runtime)
    local GUI = env.GUI

    local CONFIG = {
        Brand = "violite",
        Tag = "mm2",
        TextSize = 13,
        StatusSize = 12,
        TextColor = Color3.fromRGB(230, 230, 230),
        StatusColor = Color3.fromRGB(170, 170, 170),
        StrokeColor = Color3.fromRGB(10, 10, 10),
        OutlineColor = Color3.fromRGB(15, 15, 15),
        -- Шрифты панели: Pixel — ProggyClean, тот же шрифт, которым Drawing рисует
        -- Font = 2 (ImGui-оверлей executor'а); Clean — шрифт меню
        Fonts = {"Pixel", "Clean"},
        PixelFont = {
            Url = "https://raw.githubusercontent.com/ocornut/imgui/master/misc/fonts/ProggyClean.ttf",
            File = "ProggyClean.ttf",
            Family = "ProggyClean.json",
            Size = 11,                -- по длине и высоте строки ≈ Clean 13, ещё без размытия
        },
        CursorClearance = 20,         -- панель ниже центра: под иконкой shift-lock (32 px)
        HeartSize = 9,
        BeatPeriod = 0.8, BeatGrow = 0.5, BeatShrink = 0.16,
        RotationScale = 5,            -- слайдер 0..100 → градусы в секунду × 5
        Crosshair = {Size = 5, Gap = 2, Thickness = 2, Rotation = 0},
        AssetFolders = {"VioCFG", "VioCFG/Violite", "VioCFG/Violite/Assets"},
        -- Активные бинды для строки состояния: подпись + проверка
        Binds = {
            {Label = "speed",     Check = function() return Main.Runtime.SpeedActive == true end},
            {Label = "fly",       Check = function() return Main.Settings.FlyEnabled == true end},
            {Label = "desync",    Check = function() return Main.Settings.FakePositionEnabled == true end},
            {Label = "noclip",    Check = function() return Main.Settings.NoClipEnabled == true end},
            {Label = "invisible", Check = function() return Main.Settings.IsInvisible == true end},
            {Label = "kill aura", Check = function() return Main.Settings.KillAuraEnabled == true end},
            {Label = "bhop",      Check = function()
                local movement = Main.Runtime.MovementModule
                return movement ~= nil and movement.State ~= nil and movement.State.Enabled == true
            end},
        },
        -- PNG сердца, контура удара и мягкой подложки (base64) → VioCFG/Violite/Assets
        Images = {
            Heart = {File = "HudHeart.png",
                Data = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsEAAA7BAbiRa+0AAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuMvu8A7YAAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAA2XYBAOgDAADZdgEA6AMAAFBhaW50Lk5FVCA1LjEuMgADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAACnKL6u+xXB7AAAAEZJREFUKFONj1sOADAEBOn976xWENVHOglWMh9QQbxAzcQ+RbHAzFgy29CWwgmIw/OTL2m7qVJvChYxBFsaEGHeP3GaQDQBlXYd/dTBOJ0AAAAASUVORK5CYII="},
            Overlay = {File = "HudHeartOverlay.png",
                Data = "iVBORw0KGgoAAAANSUhEUgAAAAkAAAAJCAYAAADgkQYQAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAAYdEVYdFNvZnR3YXJlAFBhaW50Lk5FVCA1LjEuMvu8A7YAAAC2ZVhJZklJKgAIAAAABQAaAQUAAQAAAEoAAAAbAQUAAQAAAFIAAAAoAQMAAQAAAAIAAAAxAQIAEAAAAFoAAABphwQAAQAAAGoAAAAAAAAA8nYBAOgDAADydgEA6AMAAFBhaW50Lk5FVCA1LjEuMgADAACQBwAEAAAAMDIzMAGgAwABAAAAAQAAAAWgBAABAAAAlAAAAAAAAAACAAEAAgAEAAAAUjk4AAIABwAEAAAAMDEwMAAAAACOO8FX0xe8TgAAADpJREFUKFNjgIH/UIDOBgFGEIEsgA4YQQCfAhhggtJ4AVGKiHMTlI1VIUwerggEkBUiG4ABME1kYAAAII4n8u04np4AAAAASUVORK5CYII="},
            Shadow = {File = "HudShadow.png",
                Data = "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAQAAABpN6lAAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QA/4ePzL8AAAAJcEhZcwAADsMAAA7DAcdvqGQAAAAHdElNRQfiAQkTIxqKm+UhAAACvElEQVR42u2dzY7aMBhFjxPHEzJQBolRq77/27XSwBCSkD/PwinS7LpBVwrfeYLjI4Ozuy6Cw+HIyHBkOMCxTiIQmYnMzEQi0S9Hz/EUePIlxDpJB58YGRiZmJlTgIKCQMkLYYmwTtLhe2509AwM6QbkFJRUbKnYEChWHGCgp6WhpoF0AzI8gYodB/bs2BDI1aYPYqKn5cIZR7oPkyejoGTLgZ+888aOEq82fRAjHRdOlEBkZGTwODwvVOx55zdH9rxSqE0fxMCVMxXQ0dHS4TwZOYENO9448osDW4La9EH01GyAhhOfBHKy9Ar4JcGeA0d2Kw5QAu3yT+fJcB7IyJdn8JUtO36sOAB0vFISKNJz7+9fgelTKBAIlGrThxEI3z743Fpf/P/GAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0FUAuosQBqATUWQC2gxgKoBdRYALWAGgugFlBjAdQCaiyAWkCNBVALqLEAagE1FkAtoMYCqAXUWAC1gBoLoBZQYwHUAmosgFpAjQVQC6ixAGoBNRZALaDGAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0FUAuosQBqATUWQC2gxgKoBdRYALWAGgugFlBjAdQCaiyAWkCNBVALqLEAagE1FkAtoMYCqAXUWAC1gBoLoBZQYwHUAmosgFpAjQVQC6ixAGoBNRZALaDGAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0FUAuosQBqATUWQC2gxgKoBdRYALWAGgugFlBjAdQCaiyAWkCNBVALqLEAagE1FkAtoMYCqAXUWAC1gBoLoBZQYwHUAmosgFpAjQVQC6ixAGoBNRZALaDGAqgF1FgAtYAaC6AWUGMB1AJqLIBaQI0nfpsi7enp1VIPI53uPriaVmfT9ORAT8eVmhJWvDZ3oea6TK5OzOkGzIz3Lc4N0K04QM0HZy609IzMRM98nyI9UQHt6ic3/3JaEkzMnsjIjYYzJdA8xejqH8403BjTDRjoqHFAx+lJZnc/qOkYmP3yD9AAkY7PJxpe7hnTT2BiAGZG2ieb3p6ILj75+LqL4O7Dq245/HoDpAjx32cQ8QtpRORenSWX2AAAABl0RVh0U29mdHdhcmUAcGFpbnQubmV0IDQuMC4xOdTWsmQAAAAASUVORK5CYII="},
        },
    }

    local State = {
        CenterPanel = false,
        ShowKeybinds = true,
        Font = "Pixel",
        PixelFace = nil,         -- Font из getcustomasset, nil — ещё не загружен
        PixelLoading = false,
        Crosshair = false,
        Values = table.clone(CONFIG.Crosshair),
        Assets = {},             -- имя → rbxasset из getcustomasset
        PanelGui = nil,          -- ScreenGui панели (под меню скрипта)
        Panel = nil,             -- {Root, Row, Brand, Tag, Status, Heart, Overlay, Shadow}
        CrossGui = nil,          -- ScreenGui прицела (поверх всего)
        Lines = {},              -- 4 линии прицела
        CrossRot = 0,
        LastBeat = 0,
        IconHidden = false,      -- системный курсор спрятан нами
        RenderConnection = nil,
        Connections = {},
        Unloaded = false,
    }
    local Module = {State = State, CONFIG = CONFIG, Handlers = {}}

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 2: ХЕЛПЕРЫ
    -- ══════════════════════════════════════════════════════════════════════════
    local function disconnect(connection)
        if connection then pcall(function() connection:Disconnect() end) end
    end

    local function connect(signal, callback)
        local connection = env.Connect and env.Connect(signal, callback) or signal:Connect(callback)
        table.insert(State.Connections, connection)
        return connection
    end

    local function inst(cls, props, parent)
        local o = Instance.new(cls)
        for k, v in pairs(props) do o[k] = v end
        if parent then o.Parent = parent end
        return o
    end

    local function accent()
        local ok, tokens = pcall(function() return GUI.GetThemeTokens() end)
        return ok and tokens and tokens.Accent or Color3.fromRGB(94, 106, 210)
    end

    local function font()
        if State.Font == "Pixel" and State.PixelFace then return State.PixelFace end
        local ok, face = pcall(function() return GUI.Theme.FONT.Bold end)
        if ok and typeof(face) == "Font" then return face end
        return Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
    end

    -- PNG из base64 пишется один раз в папку ассетов, дальше — getcustomasset
    local function asset(key)
        if State.Assets[key] ~= nil then return State.Assets[key] or nil end
        State.Assets[key] = false
        pcall(function()
            if not (writefile and isfile and getcustomasset) then return end
            local image = CONFIG.Images[key]
            local path = CONFIG.AssetFolders[#CONFIG.AssetFolders] .. "/" .. image.File
            if not isfile(path) then
                local decode = (crypt and crypt.base64decode) or base64_decode
                if not decode then return end
                if makefolder then
                    for _, dir in ipairs(CONFIG.AssetFolders) do
                        if not (isfolder and isfolder(dir)) then pcall(makefolder, dir) end
                    end
                end
                writefile(path, decode(image.Data))
            end
            State.Assets[key] = getcustomasset(path)
        end)
        return State.Assets[key] or nil
    end

    local function hudParent()
        local ok, hui = pcall(function() return gethui and gethui() end)
        return ok and hui or CoreGui
    end

    local function mainGui()
        return Main.Runtime.UIElements and Main.Runtime.UIElements.MainGui
    end

    -- Окно скрипта открыто: курсор нужен для меню, кроссхейр не подменяет его
    local function menuOpen()
        local gui = mainGui()
        local frame = gui and gui:FindFirstChild("MainFrame")
        return frame ~= nil and frame.Visible and gui.Enabled ~= false
    end

    -- IgnoreGuiInset: (0,0) — угол окна, как у GetMouseLocation, а центр
    -- ScreenGui совпадает с точкой, где залочен курсор shift-lock
    local function screenGui(name, displayOrder)
        return inst("ScreenGui", {Name = name, IgnoreGuiInset = true, ResetOnSpawn = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = displayOrder}, hudParent())
    end

    -- Шрифт и кегль подписей панели; Pixel без загруженного шрифта — пока Clean
    function Module.ApplyFont()
        local panel = State.Panel
        if not panel then return end
        local face = font()
        local pixel = State.Font == "Pixel" and State.PixelFace ~= nil
        for _, key in ipairs({"Brand", "Tag", "Status"}) do
            panel[key].FontFace = face
            panel[key].TextSize = pixel and CONFIG.PixelFont.Size or (key == "Status" and CONFIG.StatusSize or CONFIG.TextSize)
        end
    end

    -- ProggyClean: ttf скачивается один раз в папку ассетов, семейство шрифта —
    -- JSON со ссылкой на getcustomasset(ttf). Грузится фоном и применяется по готовности
    function Module.LoadPixelFont()
        if State.PixelFace or State.PixelLoading then return end
        if not (writefile and isfile and readfile and getcustomasset) then return end
        State.PixelLoading = true
        task.spawn(function()
            local ok, face = pcall(function()
                local dir = CONFIG.AssetFolders[#CONFIG.AssetFolders]
                local ttf, family = dir .. "/" .. CONFIG.PixelFont.File, dir .. "/" .. CONFIG.PixelFont.Family
                if makefolder then
                    for _, folder in ipairs(CONFIG.AssetFolders) do
                        if not (isfolder and isfolder(folder)) then pcall(makefolder, folder) end
                    end
                end
                if not isfile(ttf) then
                    local data = game:HttpGet(CONFIG.PixelFont.Url, true)
                    assert(type(data) == "string" and #data > 1000, "font download failed")
                    writefile(ttf, data)
                end
                -- id ассета живёт одну сессию: JSON переписываем при каждой загрузке
                writefile(family, game:GetService("HttpService"):JSONEncode({name = "ProggyClean",
                    faces = {{name = "Regular", weight = 400, style = "normal", assetId = getcustomasset(ttf)}}}))
                return Font.new(getcustomasset(family), Enum.FontWeight.Regular)
            end)
            State.PixelLoading = false
            if ok and typeof(face) == "Font" and not State.Unloaded then
                State.PixelFace = face
                Module.ApplyFont()
            elseif not ok then
                warn("[Violite] HUD pixel font: " .. tostring(face))
            end
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 3: ЦЕНТРАЛЬНАЯ ПАНЕЛЬ
    -- ══════════════════════════════════════════════════════════════════════════
    local function destroyPanel()
        if State.PanelGui then pcall(function() State.PanelGui:Destroy() end) end
        State.PanelGui, State.Panel = nil, nil
    end

    -- Верх панели — ниже курсора shift-lock и, если включён, ниже кроссхейра
    local function panelOffset()
        local clearance = CONFIG.CursorClearance
        if State.Crosshair then
            local v = State.Values
            clearance = math.max(clearance, v.Gap + v.Size + v.Thickness + 8)
        end
        return clearance
    end

    local function buildPanel()
        destroyPanel()
        -- Под окном скрипта: панель у центра не должна перекрывать меню
        local gui = mainGui()
        local order = gui and gui:IsA("ScreenGui") and gui.DisplayOrder - 1 or 0
        State.PanelGui = screenGui("VioliteHudPanel", order)
        local color, face = accent(), font()
        local root = inst("Frame", {Name = "Panel", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, panelOffset()), Size = UDim2.fromOffset(0, 16)}, State.PanelGui)
        local shadow = inst("ImageLabel", {Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
            Position = UDim2.new(0.5, 0, 0.5, 1), Size = UDim2.new(1, 12, 0, 14), Image = asset("Shadow") or "",
            ImageColor3 = color, ImageTransparency = 0.8, ZIndex = 1}, root)
        local row = inst("Frame", {Name = "Row", AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
            Size = UDim2.fromOffset(0, 16), ZIndex = 2}, root)
        inst("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4),
            VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, row)
        local function label(text, order, parent, size, colorValue)
            return inst("TextLabel", {Text = text, FontFace = face, TextSize = size, TextColor3 = colorValue,
                TextStrokeColor3 = CONFIG.StrokeColor, TextStrokeTransparency = 0.35, BackgroundTransparency = 1,
                AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 16), LayoutOrder = order, ZIndex = 3}, parent)
        end
        local brand = label(CONFIG.Brand, 1, row, CONFIG.TextSize, CONFIG.TextColor)
        local holder = inst("Frame", {Name = "HeartHolder", BackgroundTransparency = 1, LayoutOrder = 2, ZIndex = 3,
            Size = UDim2.fromOffset(CONFIG.HeartSize, CONFIG.HeartSize)}, row)
        local function heartImage(name, key, z)
            return inst("ImageLabel", {Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Size = UDim2.fromOffset(CONFIG.HeartSize, CONFIG.HeartSize), BackgroundTransparency = 1,
                Image = asset(key) or "", ImageColor3 = color, ResampleMode = Enum.ResamplerMode.Pixelated, ZIndex = z}, holder)
        end
        local overlay = heartImage("Overlay", "Overlay", 3)
        local heart = heartImage("Heart", "Heart", 4)
        local tag = label(CONFIG.Tag, 3, row, CONFIG.TextSize, CONFIG.TextColor)
        local status = label("", 0, root, CONFIG.StatusSize, CONFIG.StatusColor)
        status.AnchorPoint, status.Position = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 1, 1)
        -- корень = ширина строки: тень и строка состояния центрируются по ней
        local function fit() root.Size = UDim2.fromOffset(row.AbsoluteSize.X, 16) end
        row:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
        fit()
        State.Panel = {Root = root, Row = row, Brand = brand, Tag = tag, Status = status, Heart = heart, Overlay = overlay, Shadow = shadow}
        if State.Font == "Pixel" then Module.LoadPixelFont() end
        Module.ApplyFont()
        State.LastBeat = os.clock()
    end

    local function activeBinds()
        local list = {}
        for _, bind in ipairs(CONFIG.Binds) do
            local ok, on = pcall(bind.Check)
            if ok and on then list[#list + 1] = bind.Label end
        end
        return table.concat(list, " · ")
    end

    local function updatePanel()
        local panel = State.Panel
        if not panel then return end
        panel.Root.Position = UDim2.new(0.5, 0, 0.5, panelOffset())
        -- Сердце бьётся раз в BeatPeriod: сжимается и выпускает расходящийся контур
        local now = os.clock()
        local since = now - State.LastBeat
        if since > CONFIG.BeatPeriod then
            State.LastBeat, since = now, 0
        end
        local base = CONFIG.HeartSize
        local shrink = since < CONFIG.BeatShrink and base - 2 or base
        panel.Heart.Size = UDim2.fromOffset(shrink, shrink)
        local a = math.clamp(since / CONFIG.BeatGrow, 0, 1)
        local grow = base + 15 * a
        panel.Overlay.Size = UDim2.fromOffset(grow, grow)
        panel.Overlay.ImageTransparency = 0.35 + 0.65 * a
        local binds = State.ShowKeybinds and activeBinds() or ""
        if panel.Status.Text ~= binds then panel.Status.Text = binds end
        panel.Status.Visible = binds ~= ""
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 4: КРОССХЕЙР
    -- ══════════════════════════════════════════════════════════════════════════
    local function destroyCrosshair()
        if State.CrossGui then pcall(function() State.CrossGui:Destroy() end) end
        State.CrossGui = nil
        table.clear(State.Lines)
    end

    local function paintCrosshair()
        local color = accent()
        for _, line in ipairs(State.Lines) do
            line.Frame.BackgroundColor3 = color
            line.Stroke.Color = CONFIG.OutlineColor
        end
    end

    local function buildCrosshair()
        destroyCrosshair()
        -- Поверх всего: прицел заменяет курсор
        State.CrossGui = screenGui("VioliteHudCrosshair", 1000000)
        for i = 1, 4 do
            local frame = inst("Frame", {Name = "Line" .. i, BorderSizePixel = 0, Visible = false}, State.CrossGui)
            local stroke = inst("UIStroke", {Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
                LineJoinMode = Enum.LineJoinMode.Miter}, frame)
            State.Lines[i] = {Frame = frame, Stroke = stroke}
        end
        paintCrosshair()
    end

    local function setLinesVisible(on)
        for _, line in ipairs(State.Lines) do line.Frame.Visible = on end
    end

    -- Системный курсор прячем только сами и возвращаем только свой «спрятанный»
    local function setCursorHidden(hide)
        if hide == State.IconHidden then
            if hide and UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false end
            return
        end
        State.IconHidden = hide
        pcall(function() UserInputService.MouseIconEnabled = not hide end)
    end

    -- Подменяем только «особые» курсоры: shift-lock / первое лицо и прицел пистолета
    local function cursorOverridden()
        if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then return true end
        local ok, icon = pcall(function() return LocalPlayer:GetMouse().Icon end)
        return ok and icon ~= nil and icon ~= ""
    end

    local function place(line, x, y, w, h, rotation)
        local frame = line.Frame
        frame.Position = UDim2.fromOffset(x, y)
        frame.Size = UDim2.fromOffset(w, h)
        frame.Rotation = rotation
    end

    local function updateCrosshair(dt)
        if #State.Lines == 0 then return end
        local active = not menuOpen() and cursorOverridden()
        setCursorHidden(active)
        if not active then
            setLinesVisible(false)
            return
        end
        -- Точно в точку мыши, без сглаживания: с пистолетом любое запаздывание мешает целиться
        local mouse = UserInputService:GetMouseLocation()
        local v = State.Values
        local t, len, gap = v.Thickness, v.Size, v.Gap
        -- Центр — на границе пикселей при чётной толщине и в середине пикселя при нечётной:
        -- тогда обе пары линий симметричны и не размываются
        local cx = math.floor(mouse.X + 0.5) + (t % 2 == 1 and 0.5 or 0)
        local cy = math.floor(mouse.Y + 0.5) + (t % 2 == 1 and 0.5 or 0)
        State.CrossRot = v.Rotation > 0 and (State.CrossRot + dt * v.Rotation * CONFIG.RotationScale) % 360 or 0
        if State.CrossRot == 0 then
            local near, far = math.floor(cx + gap), math.ceil(cx - gap)
            local nearY, farY = math.floor(cy + gap), math.ceil(cy - gap)
            local left, top = cx - t / 2, cy - t / 2
            place(State.Lines[1], near, top, len, t, 0)               -- вправо
            place(State.Lines[2], far - len, top, len, t, 0)          -- влево
            place(State.Lines[3], left, nearY, t, len, 0)             -- вниз
            place(State.Lines[4], left, farY - len, t, len, 0)        -- вверх
        else
            -- Вращение: линия len×t повёрнута вокруг своего центра
            for i = 1, 4 do
                local angle = math.rad(State.CrossRot) + (i - 1) * math.pi / 2
                local mid = gap + len / 2
                local x = cx + math.cos(angle) * mid
                local y = cy + math.sin(angle) * mid
                place(State.Lines[i], x - len / 2, y - t / 2, len, t, math.deg(angle))
            end
        end
        setLinesVisible(true)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 5: ЦИКЛ И ПЕРЕКЛЮЧЕНИЕ ФИЧ
    -- ══════════════════════════════════════════════════════════════════════════
    local function step(dt)
        if State.Crosshair then pcall(updateCrosshair, dt) end
        if State.CenterPanel then pcall(updatePanel) end
    end

    -- RenderStepped держим, только пока включена хоть одна фича
    local function syncLoop()
        local need = (State.CenterPanel or State.Crosshair) and not State.Unloaded
        if need and not State.RenderConnection then
            State.RenderConnection = connect(RunService.RenderStepped, step)
        elseif not need and State.RenderConnection then
            disconnect(State.RenderConnection)
            State.RenderConnection = nil
        end
    end

    function Module.SetCenterPanel(on)
        State.CenterPanel = on == true
        if State.CenterPanel then buildPanel() else destroyPanel() end
        syncLoop()
    end

    function Module.SetCrosshair(on)
        State.Crosshair = on == true
        if State.Crosshair then
            buildCrosshair()
        else
            destroyCrosshair()
            setCursorHidden(false)
        end
        syncLoop()
    end

    -- Смена темы: акцент сердца, подложки и линий кроссхейра; шрифт окна
    if GUI.OnThemeChanged then
        GUI.OnThemeChanged(function()
            if State.Unloaded then return end
            local color = accent()
            local panel = State.Panel
            if panel then
                panel.Heart.ImageColor3, panel.Overlay.ImageColor3, panel.Shadow.ImageColor3 = color, color, color
            end
            paintCrosshair()
        end)
    end

    -- ══════════════════════════════════════════════════════════════════════════
    -- БЛОК 6: ХЕНДЛЕРЫ И GUI
    -- ══════════════════════════════════════════════════════════════════════════
    Module.Handlers.HudCenterPanel = function(on) Module.SetCenterPanel(on) end
    Module.Handlers.HudShowKeybinds = function(on) State.ShowKeybinds = on == true end
    Module.Handlers.HudPanelFont = function(name)
        if not table.find(CONFIG.Fonts, name) then return end
        State.Font = name
        if name == "Pixel" then Module.LoadPixelFont() end
        Module.ApplyFont()
    end
    Module.Handlers.HudCrosshair = function(on) Module.SetCrosshair(on) end
    Module.Handlers.HudCrosshairSize = function(v) State.Values.Size = tonumber(v) or State.Values.Size end
    Module.Handlers.HudCrosshairGap = function(v) State.Values.Gap = tonumber(v) or State.Values.Gap end
    Module.Handlers.HudCrosshairRotation = function(v) State.Values.Rotation = tonumber(v) or 0 end
    Module.Handlers.HudCrosshairThickness = function(v) State.Values.Thickness = tonumber(v) or State.Values.Thickness end

    -- Кроссхейр — левая колонка Visuals (под ESP), панель — правая (под Misc)
    function Module.BuildCrosshairSection(tab)
        local v = State.Values
        tab:CreateSection("CROSSHAIR")
        tab:CreateToggle("Custom Crosshair", "Replaces shift-lock and gun cursors", "HudCrosshair", false)
        tab:CreateSlider("Line Size", "Length of each line, px", 4, 30, v.Size, "HudCrosshairSize", 1)
        tab:CreateSlider("Gap Size", "Distance from center, px", 1, 30, v.Gap, "HudCrosshairGap", 1)
        tab:CreateSlider("Thickness", "Line width, px", 1, 4, v.Thickness, "HudCrosshairThickness", 1)
        tab:CreateSlider("Rotation", "Spin speed, 0 = static", 0, 100, v.Rotation, "HudCrosshairRotation", 1)
    end

    function Module.BuildPanelSection(tab)
        tab:CreateSection("CENTER PANEL", "right")
        tab:CreateToggle("Center Panel", "Brand plate under the cursor", "HudCenterPanel", false)
        tab:CreateToggle("Show Keybinds", "Active binds under the panel", "HudShowKeybinds", State.ShowKeybinds)
        tab:CreateDropdown("Font", "Pixel (ProggyClean) or menu font", CONFIG.Fonts, State.Font, "HudPanelFont")
    end

    function Module.Destroy()
        if State.Unloaded then return end
        Module.SetCenterPanel(false)
        Module.SetCrosshair(false)
        State.Unloaded = true
        for _, connection in ipairs(State.Connections) do disconnect(connection) end
        table.clear(State.Connections)
        State.RenderConnection = nil
        if shared.MM2_HUDModule == Module then shared.MM2_HUDModule = nil end
    end

    shared.MM2_HUDModule = Module
    return Module
end
