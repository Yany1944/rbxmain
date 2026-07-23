-- GUI.lua
-- Библиотека GUI для MM2 скрипта — редизайн «Violite v2»
-- Сайдбар вместо ленты табов, секции-контейнеры со строками, футер-статусбар.
-- Публичный API совместим со старой версией, все колбэки — через env.Handlers.

return function(env)
    local CONFIG = env.CONFIG
    local State = env.State
    local Players = env.Players
    local CoreGui = env.CoreGui
    local TweenService = env.TweenService
    local UserInputService = env.UserInputService
    local LocalPlayer = env.LocalPlayer
    local TrackConnection = env.TrackConnection
    local ShowNotification = env.ShowNotification
    local Handlers = env.Handlers

    local GUI = {}

    ----------------------------------------------------------------
    -- ТОКЕНЫ ДИЗАЙНА — Vercel Geist (dark theme)
    -- Значения сняты с живого vercel.com/geist: --ds-gray-*, --ds-background-*.
    -- Ключевое отличие от прошлой версии: бордеры СПЛОШНЫЕ (gray-400 #2E2E2E),
    -- а не полупрозрачный белый — именно из-за альфы обводка выглядела грязной.
    ----------------------------------------------------------------
    local G = {
        Bg100    = Color3.fromRGB(10, 10, 10),     -- background-100: карточки, поля
        Bg200    = Color3.fromRGB(0, 0, 0),        -- background-200: полотно окна
        Gray100  = Color3.fromRGB(26, 26, 26),     -- default bg (hover строки)
        Gray200  = Color3.fromRGB(31, 31, 31),     -- hover bg
        Gray300  = Color3.fromRGB(41, 41, 41),     -- active bg / разделители
        Gray400  = Color3.fromRGB(46, 46, 46),     -- border
        Gray500  = Color3.fromRGB(69, 69, 69),     -- border hover / скроллбар
        Gray600  = Color3.fromRGB(135, 135, 135),  -- high-contrast bg
        Gray700  = Color3.fromRGB(143, 143, 143),  -- вторичный текст, иконки
        Gray1000 = Color3.fromRGB(237, 237, 237),  -- основной текст
        Blue700  = Color3.fromRGB(0, 112, 243),    -- #0070F3
        Blue900  = Color3.fromRGB(82, 173, 250),   -- focus / ссылки
        Purple700 = Color3.fromRGB(142, 78, 198),  -- #8E4EC6
        Red800   = Color3.fromRGB(217, 48, 54),    -- заливка destructive-кнопки
        Red900   = Color3.fromRGB(255, 97, 102),   -- текст ошибки на тёмном
        Amber800 = Color3.fromRGB(255, 153, 10),
        Green900 = Color3.fromRGB(98, 193, 116),
    }

    -- Семантические алиасы: код ниже работает с ними, а не с номерами шкалы
    local T = {
        Canvas    = G.Bg200,      -- полотно окна
        Surface1  = G.Bg100,      -- карточка секции, поле ввода, поповер
        Surface2  = G.Gray100,    -- заливка контрола / hover строки
        Border    = G.Gray400,    -- обводка (сплошная!)
        BorderHi  = G.Gray500,    -- обводка на hover
        Divider   = G.Gray200,    -- разделитель строк внутри карточки (тише рамки)
        Text      = G.Gray1000,
        TextDark  = G.Gray700,
        Accent    = CONFIG.Colors.Accent or G.Purple700,
        AccentInk = G.Bg100,      -- тёмный текст на светлой/акцентной заливке
        Danger    = G.Red900,
        DangerBg  = G.Red800,
        TrackBg   = G.Gray400,    -- трек слайдера / выключенный тогл (Geist)
    }

    ----------------------------------------------------------------
    -- ШРИФТЫ: Geist Sans ≈ Inter. В Roblox Inter нет (проверено —
    -- rbxasset://fonts/families/Inter.json не резолвится), ближайший
    -- нейтральный гротеск — BuilderSans. Веса как в Geist: 400 для текста,
    -- 500 для названий и кнопок, 600 для логотипа. Никаких Bold-700 на
    -- мелком кегле — от него и была «жирная квадратность».
    ----------------------------------------------------------------
    local FONT_FAMILY = "rbxasset://fonts/families/BuilderSans.json"
    local FONT_FAMILY_FALLBACK = "rbxasset://fonts/families/GothamSSm.json"

    local FONT
    do
        local function face(weight, fallbackEnum)
            local ok, f = pcall(function()
                return Font.new(FONT_FAMILY, weight, Enum.FontStyle.Normal)
            end)
            if ok and f then return f end
            ok, f = pcall(function()
                return Font.new(FONT_FAMILY_FALLBACK, weight, Enum.FontStyle.Normal)
            end)
            if ok and f then return f end
            return fallbackEnum
        end
        FONT = {
            -- Bold/Body/Mono — исторические имена ключей, менять их незачем
            Bold = face(Enum.FontWeight.Medium, Enum.Font.GothamSemibold),   -- 500
            Body = face(Enum.FontWeight.Regular, Enum.Font.Gotham),          -- 400
            Mono = face(Enum.FontWeight.Regular, Enum.Font.Gotham),          -- значения
            Head = face(Enum.FontWeight.SemiBold, Enum.Font.GothamSemibold), -- 600
        }
    end

    -- Кегли по шкале Geist: heading-md 20/600 — заголовок вкладки,
    -- label-sm 500 — названия и кнопки, body 400 — описания.
    -- Вся типографика поднята на ступень: мелкий текст читался «дёшево»
    local TS = {
        Logo      = 20,   -- heading-md
        LogoSub   = 13,
        TabTitle  = 22,   -- заголовок вкладки — самый крупный текст окна
        Nav       = 15,
        Section   = 15,
        Title     = 16,   -- label
        Desc      = 14,   -- body-md
        Button    = 15,
        Value     = 15,
        Chip      = 13,
        Status    = 13,
        Option    = 15,
        Search    = 15,
        StatLabel = 12,   -- подписи инфо-блока в сайдбаре
        StatValue = 13,
    }

    -- Геометрия Geist: --ds-size-medium 36 под увеличенный кегль,
    -- радиус контролов 6, карточек 12, строка поповера 36 при padding 6.
    -- Высота контролов НЕ растёт вместе с кеглем: чем больше текста
    -- относительно хрома, тем легче читается интерфейс
    local ROW_H        = 42   -- строка без описания
    local ROW_H_DESC   = 56   -- строка с описанием
    local CTRL_H       = 28   -- высота дропдаунов/кнопок/полей
    local EDGE         = 14   -- горизонтальный отступ внутри карточки
    local COL_GAP      = 14   -- зазор между колонками
    local CARD_GAP     = 12   -- зазор между карточками
    local CARD_PAD_B   = 6    -- нижний воздух карточки
    local PAGE_PAD     = 2    -- запас в колонке, чтобы не срезалась обводка карточек
    local R_CTRL       = 6    -- --geist-radius
    local R_CARD       = 12   -- карточка секции, окно, поповер
    local R_SM         = 4    -- мелкие элементы (чипы списка)
    local POPOVER_PAD  = 6    -- --ds-popover-padding
    local POPOVER_ROW  = 36   -- --ds-popover-row-height
    local STROKE_W     = 1

    -- Полупрозрачность окна работает в паре с размытием фона: без блюра
    -- сквозь окно лезла игровая картинка и мешала читать текст
    local ROOT_TRANSPARENCY = 0.12
    local CARD_TRANSPARENCY = 0.04
    local BLUR_SIZE = 18

    local SIDEBAR_W  = 200
    local HEADER_H   = 56
    local FOOTER_H   = 32

    ----------------------------------------------------------------
    -- ВНЕШНИЕ АССЕТЫ: пак иконок WindUI и логотип бренда
    ----------------------------------------------------------------

    -- Иконки вкладок — пак «geist» из набора WindUI (Footagesus/Icons).
    -- Формат: Spritesheets[n] = rbxassetid, Icons[name] = {Image = n,
    -- ImageRectPosition, ImageRectSize} — тайлы 128x128 на общем листе.
    -- Тянем один раз за сессию и кэшируем в getgenv, чтобы каждая
    -- перезагрузка GUI не ходила в сеть.
    local ICON_PACK_URL =
        "https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua"

    local function loadIconPack()
        local cached = getgenv().Violite_GeistIcons
        if cached ~= nil then
            return cached or nil
        end
        local pack
        pcall(function()
            local src = game:HttpGet(ICON_PACK_URL, true)
            if type(src) ~= "string" or #src == 0 then return end
            local chunk = loadstring(src)
            if not chunk then return end
            local ok, res = pcall(chunk)
            if ok and type(res) == "table" and type(res.Icons) == "table"
                and type(res.Spritesheets) == "table" then
                pack = res
            end
        end)
        getgenv().Violite_GeistIcons = pack or false
        return pack
    end

    local ICON_PACK = loadIconPack()

    -- Возвращает {Image = "rbxassetid://…", Offset = Vector2, Size = Vector2}
    -- или nil, если пак недоступен либо имени в нём нет
    local function iconData(name)
        if not ICON_PACK or not name then return nil end
        local entry = ICON_PACK.Icons[name]
        if not entry then return nil end
        local sheet = ICON_PACK.Spritesheets[tostring(entry.Image)]
            or ICON_PACK.Spritesheets[entry.Image]
        if type(sheet) ~= "string" then return nil end
        return {
            Image = sheet,
            Offset = entry.ImageRectPosition,
            Size = entry.ImageRectSize,
        }
    end

    -- Логотип бренда: PNG из репозитория кладём в 7yd7/Assets и отдаём
    -- движку через getcustomasset. Если executor не умеет в файлы —
    -- фолбэк на нарисованный акцентный ромб
    local LOGO_URL = "https://raw.githubusercontent.com/Yany1944/rbxmain/main/V_pale_pink_glow_fullhd.png"
    local LOGO_DIR = "7yd7"
    local LOGO_ASSETS = "7yd7/Assets"
    local LOGO_PATH = "7yd7/Assets/violite_logo.png"

    local function loadLogoAsset()
        local cached = getgenv().Violite_LogoAsset
        if cached ~= nil then
            return cached or nil
        end
        local asset
        pcall(function()
            if not (isfile and writefile and getcustomasset) then return end
            if not isfile(LOGO_PATH) then
                if makefolder then
                    if not (isfolder and isfolder(LOGO_DIR)) then pcall(makefolder, LOGO_DIR) end
                    if not (isfolder and isfolder(LOGO_ASSETS)) then pcall(makefolder, LOGO_ASSETS) end
                end
                local data = game:HttpGet(LOGO_URL, true)
                if type(data) ~= "string" or #data == 0 then return end
                writefile(LOGO_PATH, data)
            end
            if isfile(LOGO_PATH) then
                asset = getcustomasset(LOGO_PATH)
            end
        end)
        getgenv().Violite_LogoAsset = asset or false
        return asset
    end

    ----------------------------------------------------------------
    -- ХЕЛПЕРЫ UI (БЛОК 19)
    ----------------------------------------------------------------

    -- Font = <Font-объект> кладём в FontFace (весовые шрифты), Font = <Enum>
    -- остаётся обычным Font — так все существующие вызовы работают без правок
    local function Create(className, properties, children)
        local obj = Instance.new(className)
        for k, v in pairs(properties or {}) do
            if k == "Font" and typeof(v) == "Font" then
                local ok = pcall(function() obj.FontFace = v end)
                if not ok then obj.Font = Enum.Font.GothamSemibold end
            else
                obj[k] = v
            end
        end
        for _, child in ipairs(children or {}) do
            child.Parent = obj
        end
        return obj
    end

    local function AddCorner(parent, radius)
        return Create("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
    end

    -- Сплошная обводка Geist. transparency оставлен в сигнатуре ради
    -- совместимости вызовов, по умолчанию — 0 (никакой альфы)
    local function AddStroke(parent, thickness, color, transparency)
        return Create("UIStroke", {
            Thickness = thickness or STROKE_W,
            Color = color or T.Border,
            Transparency = transparency or 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = parent
        })
    end

    -- Разделитель строк: сплошной gray-300, без прозрачности
    local function Hairline(props)
        props = props or {}
        props.BackgroundColor3 = props.BackgroundColor3 or T.Divider
        props.BackgroundTransparency = 0
        props.BorderSizePixel = 0
        return Create("Frame", props)
    end

    ----------------------------------------------------------------
    -- ГЛИФ-ФАБРИКИ: рисованные значки вместо текстовых символов.
    -- ✕, ▾, ↘ отсутствуют в Gotham/Code и рендерятся «тофу»-квадратами,
    -- поэтому все такие глифы собираются из Frame/UIStroke.
    ----------------------------------------------------------------

    -- Заполненная линия/точка (штрих глифа)
    local function glyphLine(parent, x, y, w, h, rot, corner)
        local f = Create("Frame", {
            BackgroundColor3 = T.TextDark,
            BorderSizePixel = 0,
            Position = UDim2.new(0, x, 0, y),
            Size = UDim2.new(0, w, 0, h),
            Rotation = rot or 0,
            ZIndex = parent.ZIndex or 1,
            Parent = parent
        })
        if corner then AddCorner(f, corner) end
        return f
    end

    -- Контур (кольцо/рамка) — возвращает фрейм и его UIStroke
    local function glyphRing(parent, x, y, w, h, corner, thickness)
        local f = Create("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, x, 0, y),
            Size = UDim2.new(0, w, 0, h),
            ZIndex = parent.ZIndex or 1,
            Parent = parent
        })
        AddCorner(f, corner)
        local s = Create("UIStroke", {
            Thickness = thickness or 1.2,
            Color = T.TextDark,
            Transparency = 0,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
            Parent = f
        })
        return f, s
    end

    -- Крест «✕» по центру родителя: два штриха 1.4x12 под ±45°.
    -- Возвращает список штрихов, чтобы их можно было перекрасить на hover.
    local function glyphCross(parent)
        local strokes = {}
        for _, rot in ipairs({45, -45}) do
            local f = Create("Frame", {
                BackgroundColor3 = T.TextDark,
                BorderSizePixel = 0,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, 1.5, 0, 11),
                Rotation = rot,
                ZIndex = (parent.ZIndex or 1) + 1,
                Parent = parent
            })
            table.insert(strokes, f)
        end
        return strokes
    end

    -- Шеврон-уголок вниз «▾» у правого края родителя: два штриха 1.4x6 под ±45°.
    -- padRight компенсирует UIPadding родителя: дети живут в уже сжатой
    -- области, поэтому холдер надо вернуть обратно к реальному краю кнопки.
    local function glyphChevron(parent, padRight)
        local z = (parent.ZIndex or 1) + 1
        local holder = Create("Frame", {
            Name = "Chevron",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, (padRight or 0) - 10, 0.5, 0),
            Size = UDim2.new(0, 10, 0, 10),
            ZIndex = z,
            Parent = parent
        })
        -- центры штрихов — (2.88, 5) и (7.12, 5), сходятся внизу по центру
        local a = glyphLine(holder, 2.18, 2, 1.4, 6, -45)
        local b = glyphLine(holder, 6.42, 2, 1.4, 6, 45)
        a.ZIndex, b.ZIndex = z, z
        return holder, a, b
    end

    -- Уголок ресайза «↘»: две параллельные диагонали в правом нижнем углу
    local function glyphResizeCorner(parent)
        local z = (parent.ZIndex or 1)
        local a = glyphLine(parent, 10.5, 6.5, 1, 9, 45)
        local b = glyphLine(parent, 13.5, 11.5, 1, 5, 45)
        a.ZIndex, b.ZIndex = z, z
        return a, b
    end

    ----------------------------------------------------------------
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ИЗ MAIN (через Handlers)
    ----------------------------------------------------------------

    local function callHandler(name, ...)
        local fn = Handlers[name]
        if fn then
            fn(...)
        end
    end

    local function getAllPlayers()
        local list = {}
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                table.insert(list, plr.Name)
            end
        end
        table.sort(list)
        return list
    end

    -- Пинг для статусбара (набор Stats отличается между executor'ами — всё в pcall)
    local function probePingMs()
        local ms
        local okItem, item = pcall(function()
            return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]
        end)
        if okItem and item then
            local okStr, s = pcall(function() return item:GetValueString() end)
            if okStr and s and tonumber(s) then
                ms = tonumber(s)
            else
                local okVal, v = pcall(function() return item:GetValue() end)
                if okVal and typeof(v) == "number" then ms = v end
            end
        end
        return ms
    end

    ----------------------------------------------------------------
    -- СОЗДАНИЕ UI (БЛОК 20 → CreateUI, TabFunctions и т.д.)
    ----------------------------------------------------------------

    local function CreateUI()
        for _, child in ipairs(CoreGui:GetChildren()) do
            if child.Name == "MM2_ESP_UI" then child:Destroy() end
        end

        local gui = Create("ScreenGui", {
            Name = "MM2_ESP_UI",
            Parent = CoreGui
        })
        State.UIElements.MainGui = gui

        local mainFrame = Create("Frame", {
            Name = "MainFrame",
            BackgroundColor3 = T.Canvas,
            BackgroundTransparency = ROOT_TRANSPARENCY,
            Position = UDim2.new(0.5, -500, 0.5, -340),
            Size = UDim2.new(0, 1000, 0, 680),
            ClipsDescendants = false,
            Active = true,
            Parent = gui
        })
        AddCorner(mainFrame, R_CARD)
        AddStroke(mainFrame, STROKE_W, T.Border)

        -- Мягкое размытие фона. Настоящего backdrop-blur (размытия только под
        -- окном) в Roblox нет, поэтому размываем сцену через BlurEffect в
        -- Lighting и держим его ровно пока окно видно. В паре с
        -- полупрозрачным окном это и даёт «матовое стекло»
        local blurEffect
        pcall(function()
            local Lighting = game:GetService("Lighting")
            local old = Lighting:FindFirstChild("Violite_Blur")
            if old then old:Destroy() end
            blurEffect = Create("BlurEffect", {
                Name = "Violite_Blur",
                Size = 0,
                Parent = Lighting
            })
        end)
        State.UIElements.Blur = blurEffect

        local function applyBlur(on)
            if not blurEffect or not blurEffect.Parent then return end
            pcall(function()
                TweenService:Create(
                    blurEffect,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad),
                    {Size = on and BLUR_SIZE or 0}
                ):Play()
            end)
        end
        applyBlur(true)
        mainFrame:GetPropertyChangedSignal("Visible"):Connect(function()
            applyBlur(mainFrame.Visible)
        end)

        ----------------------------------------------------------------
        -- САЙДБАР: логотип + вертикальная навигация вкладок
        ----------------------------------------------------------------

        local sidebar = Create("Frame", {
            Name = "Sidebar",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, SIDEBAR_W, 1, 0),
            Parent = mainFrame
        })

        Hairline({
            Name = "SidebarSep",
            BackgroundColor3 = T.Border,
            Position = UDim2.new(0, SIDEBAR_W, 0, 0),
            Size = UDim2.new(0, 1, 1, 0),
            Parent = mainFrame
        })

        -- Логотип бренда. Исходник 1920x1080, светящийся глиф «V» занимает
        -- по центру всего ~304px высоты — при обычном кропе всего кадра знак
        -- утонул бы в пустом поле. Резать пиксельным ImageRect нельзя:
        -- движок ужимает текстуры больше 1024px, и координаты исходника
        -- промахиваются. Поэтому кроп делаем геометрией: картинка со
        -- ScaleType.Crop берётся заведомо крупнее рамки, а рамка её клипает.
        -- Множитель 1080/400 наводит на глиф, пропорции не трогаются.
        local LOGO_BOX = 26
        local LOGO_ZOOM = 1080 / 400
        local logoAsset = loadLogoAsset()
        if logoAsset then
            local logoBox = Create("Frame", {
                Name = "LogoMark",
                BackgroundTransparency = 1,
                ClipsDescendants = true,
                Position = UDim2.new(0, EDGE, 0, 17),
                Size = UDim2.new(0, LOGO_BOX, 0, LOGO_BOX),
                Parent = sidebar
            })
            AddCorner(logoBox, R_CTRL)
            Create("ImageLabel", {
                Name = "Image",
                Image = logoAsset,
                ScaleType = Enum.ScaleType.Crop,
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                Size = UDim2.new(0, math.floor(LOGO_BOX * LOGO_ZOOM),
                                 0, math.floor(LOGO_BOX * LOGO_ZOOM)),
                Parent = logoBox
            })
        else
            local logoMark = Create("Frame", {
                Name = "LogoMark",
                BackgroundColor3 = T.Accent,
                BorderSizePixel = 0,
                Position = UDim2.new(0, EDGE + 6, 0, 23),
                Size = UDim2.new(0, 13, 0, 13),
                Rotation = 45,
                Parent = sidebar
            })
            AddCorner(logoMark, 3)
        end

        local LOGO_TEXT_X = EDGE + LOGO_BOX + 8

        Create("TextLabel", {
            Name = "LogoName",
            Text = "Violite",
            Font = FONT.Head,
            TextSize = TS.Logo,
            TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, LOGO_TEXT_X, 0, 15),
            Size = UDim2.new(0, 150, 0, 20),
            Parent = sidebar
        })

        Create("TextLabel", {
            Name = "LogoSub",
            Text = "mm2",
            Font = FONT.Body,
            TextSize = TS.LogoSub,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, LOGO_TEXT_X, 0, 35),
            Size = UDim2.new(0, 150, 0, 16),
            Parent = sidebar
        })

        -- Инфо-блок внизу сайдбара: COINS / NAME / COINS PER HOUR / ROLE /
        -- VERSION. Высота = 5 строк + подпись + отступы
        local STAT_ROW_H = 18
        local STAT_KEYS = {"Name", "Role", "Coins", "CoinsPerHour", "Version"}
        local STAT_TITLES = {
            Name = "NAME", Role = "ROLE", Coins = "COINS",
            CoinsPerHour = "COINS/H", Version = "VER",
        }
        local STATS_H = #STAT_KEYS * STAT_ROW_H + 14
        local SIDEBAR_BOTTOM = STATS_H + 32   -- блок + строка подписи

        local navScroll = Create("ScrollingFrame", {
            Name = "NavScroll",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 8, 0, 84),
            Size = UDim2.new(0, SIDEBAR_W - 16, 1, -(84 + SIDEBAR_BOTTOM + 12)),
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollBarThickness = 0,
            BorderSizePixel = 0,
            Parent = sidebar
        })

        local navLayout = Create("UIListLayout", {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
            Parent = navScroll
        })
        navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            navScroll.CanvasSize = UDim2.new(0, 0, 0, navLayout.AbsoluteContentSize.Y + 4)
        end)

        -- Сводка сессии: подпись слева, значение справа. Значения тянутся из
        -- Handlers (если MainScript их отдаёт) либо ставятся через GUI.SetStat
        local statValues = {}

        local statsFrame = Create("Frame", {
            Name = "Stats",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, EDGE, 1, -(STATS_H + 32)),
            Size = UDim2.new(0, SIDEBAR_W - EDGE * 2, 0, STATS_H),
            Parent = sidebar
        })

        Hairline({
            Name = "StatsSep",
            BackgroundColor3 = T.Border,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, 1),
            Parent = statsFrame
        })

        -- Кнопка сворачивания блока: шеврон у правого края линии-разделителя
        local statsRows = Create("Frame", {
            Name = "Rows",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 1, 0),
            Parent = statsFrame
        })

        local statsToggle = Create("TextButton", {
            Name = "StatsToggle",
            Text = "",
            BackgroundColor3 = G.Gray200,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 2),
            Size = UDim2.new(0, 18, 0, 14),
            AutoButtonColor = false,
            ZIndex = 3,
            Parent = statsFrame
        })
        AddCorner(statsToggle, R_SM)
        local _, statsChevA, statsChevB = glyphChevron(statsToggle)

        local statsHidden = getgenv().Violite_StatsHidden == true
        local function applyStatsHidden()
            statsRows.Visible = not statsHidden
            -- свёрнутый блок: шеврон смотрит вверх
            statsChevA.Rotation = statsHidden and 45 or -45
            statsChevB.Rotation = statsHidden and -45 or 45
        end

        statsToggle.MouseButton1Click:Connect(function()
            statsHidden = not statsHidden
            getgenv().Violite_StatsHidden = statsHidden
            applyStatsHidden()
        end)
        statsToggle.MouseEnter:Connect(function()
            TweenService:Create(statsToggle, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
        end)
        statsToggle.MouseLeave:Connect(function()
            TweenService:Create(statsToggle, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        end)

        for i, key in ipairs(STAT_KEYS) do
            local y = 12 + (i - 1) * STAT_ROW_H
            Create("TextLabel", {
                Name = key .. "Label",
                Text = STAT_TITLES[key],
                Font = FONT.Body,
                TextSize = TS.StatLabel,
                TextColor3 = T.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, y),
                Size = UDim2.new(0.62, 0, 0, STAT_ROW_H),
                Parent = statsRows
            })
            statValues[key] = Create("TextLabel", {
                Name = key .. "Value",
                Text = "—",
                Font = FONT.Bold,
                TextSize = TS.StatValue,
                TextColor3 = T.Text,
                TextXAlignment = Enum.TextXAlignment.Right,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BackgroundTransparency = 1,
                Position = UDim2.new(0.62, 0, 0, y),
                Size = UDim2.new(0.38, 0, 0, STAT_ROW_H),
                Parent = statsRows
            })
        end

        applyStatsHidden()

        -- Публичный сеттер: MainScript может пушить значения напрямую
        function GUI.SetStat(key, value)
            local label = statValues[key]
            if label then
                label.Text = (value == nil or value == "") and "—" or tostring(value)
            end
        end

        -- Программное скрытие/показ блока
        function GUI.SetStatsVisible(on)
            statsHidden = not on
            getgenv().Violite_StatsHidden = statsHidden
            applyStatsHidden()
        end

        -- Личная подпись внизу сайдбара — переехала из заголовка старой версии
        Create("TextLabel", {
            Name = "Dedication",
            Text = "for my кошичка жена",
            Font = FONT.Body,
            TextSize = TS.LogoSub,
            TextColor3 = Color3.fromRGB(220, 145, 230),
            TextTransparency = 0.35,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, EDGE, 1, -26),
            Size = UDim2.new(0, 170, 0, 16),
            Parent = sidebar
        })

        ----------------------------------------------------------------
        -- ХЕДЕР: название вкладки, поиск, закрытие. Драг окна — за хедер
        ----------------------------------------------------------------

        local header = Create("Frame", {
            Name = "Header",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1, 0, 0),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, HEADER_H),
            Active = true,
            Parent = mainFrame
        })

        local tabTitle = Create("TextLabel", {
            Name = "TabTitle",
            Text = "",
            Font = FONT.Head,
            TextSize = TS.TabTitle,
            TextColor3 = T.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, EDGE + 4, 0, 0),
            Size = UDim2.new(0, 300, 1, 0),
            Parent = header
        })

        local searchBox = Create("TextBox", {
            Name = "SearchBox",
            PlaceholderText = "Search...",
            Text = "",
            Font = FONT.Body,
            TextSize = TS.Search,
            TextColor3 = T.Text,
            PlaceholderColor3 = T.TextDark,
            BackgroundColor3 = T.Surface1,
            Position = UDim2.new(1, -(240 + CTRL_H + 8 + EDGE), 0.5, -CTRL_H / 2),
            Size = UDim2.new(0, 240, 0, CTRL_H),
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            Parent = header,
        })
        AddCorner(searchBox, R_CTRL)
        local searchStroke = AddStroke(searchBox, STROKE_W, T.Border)
        Create("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = searchBox})
        -- Geist input: рамка подсвечивается на фокусе, а не на hover
        searchBox.Focused:Connect(function()
            TweenService:Create(searchStroke, TweenInfo.new(0.15), {Color = G.Gray600}):Play()
        end)
        searchBox.FocusLost:Connect(function()
            TweenService:Create(searchStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
        end)

        local closeButton = Create("TextButton", {
            Text = "",
            BackgroundColor3 = G.Gray200,
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -(CTRL_H + EDGE), 0.5, -CTRL_H / 2),
            Size = UDim2.new(0, CTRL_H, 0, CTRL_H),
            AutoButtonColor = false,
            Parent = header
        })
        AddCorner(closeButton, R_CTRL)
        local closeStrokes = glyphCross(closeButton)

        Hairline({
            Name = "HeaderSep",
            BackgroundColor3 = T.Border,
            Position = UDim2.new(0, SIDEBAR_W + 1, 0, HEADER_H),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 1),
            Parent = mainFrame
        })

        ----------------------------------------------------------------
        -- КОНТЕНТ (страницы вкладок) + ФУТЕР-СТАТУСБАР
        ----------------------------------------------------------------

        local pagesContainer = Create("Frame", {
            Name = "PagesContainer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1 + EDGE, 0, HEADER_H + EDGE),
            Size = UDim2.new(1, -(SIDEBAR_W + 1 + EDGE * 2), 1, -(HEADER_H + EDGE + FOOTER_H + EDGE)),
            Parent = mainFrame
        })

        Hairline({
            Name = "FooterSep",
            BackgroundColor3 = T.Border,
            Position = UDim2.new(0, SIDEBAR_W + 1, 1, -(FOOTER_H + 1)),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, 1),
            Parent = mainFrame
        })

        local footer = Create("Frame", {
            Name = "Footer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1, 1, -FOOTER_H),
            Size = UDim2.new(1, -(SIDEBAR_W + 1), 0, FOOTER_H),
            Parent = mainFrame
        })

        -- Чип роли: скрыт, пока MainScript не отдаст Handlers.GetRole
        local roleChip = Create("Frame", {
            Name = "RoleChip",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, EDGE, 0, 0),
            Size = UDim2.new(0, 140, 1, 0),
            Visible = false,
            Parent = footer
        })
        local roleDot = Create("Frame", {
            BackgroundColor3 = T.TextDark,
            Position = UDim2.new(0, 0, 0.5, -3),
            Size = UDim2.new(0, 6, 0, 6),
            BorderSizePixel = 0,
            Parent = roleChip
        })
        AddCorner(roleDot, 3)
        local roleText = Create("TextLabel", {
            Text = "",
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 0),
            Size = UDim2.new(0, 120, 1, 0),
            Parent = roleChip
        })

        local pingLabel = Create("TextLabel", {
            Text = "Ping: -- ms",
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -110, 0, 0),
            Size = UDim2.new(0, 220, 1, 0),
            Parent = footer
        })

        Create("TextLabel", {
            Text = "Toggle: " .. CONFIG.HideKey.Name,
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Right,
            BackgroundTransparency = 1,
            -- правая граница -36, чтобы не залезать под уголок ресайза
            Position = UDim2.new(1, -196, 0, 0),
            Size = UDim2.new(0, 160, 1, 0),
            Parent = footer
        })

        -- Раз в секунду обновляем пинг и роль; цикл умирает вместе с gui
        local roleColorMap = {
            Murderer = CONFIG.Colors.Murder,
            Murder   = CONFIG.Colors.Murder,
            Sheriff  = CONFIG.Colors.Sheriff,
            Innocent = CONFIG.Colors.Innocent,
        }
        task.spawn(function()
            while gui and gui.Parent do
                pcall(function()
                    local ms = probePingMs()
                    pingLabel.Text = ms and string.format("Ping: %d ms", ms) or "Ping: -- ms"

                    local getRole = Handlers.GetRole
                    if getRole then
                        local ok, role = pcall(getRole)
                        if ok and type(role) == "string" and role ~= "" then
                            local col = roleColorMap[role] or T.TextDark
                            roleChip.Visible = true
                            roleDot.BackgroundColor3 = col
                            roleText.Text = role:upper()
                            roleText.TextColor3 = col
                        else
                            roleChip.Visible = false
                        end
                    else
                        roleChip.Visible = false
                    end

                    -- Сводка в сайдбаре. Handlers необязательны: чего нет —
                    -- остаётся прочерк, ставить можно и через GUI.SetStat
                    local function pull(handlerName)
                        local fn = Handlers[handlerName]
                        if not fn then return nil end
                        local ok, res = pcall(fn)
                        if ok and res ~= nil and res ~= "" then return tostring(res) end
                        return nil
                    end

                    GUI.SetStat("Name", LocalPlayer and LocalPlayer.Name or nil)
                    GUI.SetStat("Coins", pull("GetCoins"))
                    GUI.SetStat("CoinsPerHour", pull("GetCoinsPerHour"))
                    GUI.SetStat("Role", pull("GetRole"))
                    GUI.SetStat("Version", CONFIG.Version or pull("GetVersion"))
                end)
                task.wait(1)
            end
        end)

        local Tabs = {}
        local currentTab = nil
        local sections = {}   -- {frame, layout, rows = {{row, sep, name, desc}, ...}}

        ----------------------------------------------------------------
        -- КАСТОМНЫЙ SCROLLBAR (thumb без родного track)
        ----------------------------------------------------------------
        -- Geist: скроллбар нейтральный (gray-500), а не акцентный
        local SCROLL_THUMB_COLOR = G.Gray500
        local SCROLL_THUMB_TRANSPARENCY = 0
        local SCROLL_THUMB_WIDTH = 4

        local function AttachCustomScrollbar(scrollingFrame, container, anchorX)
            local thumb = Create("Frame", {
                Name = "CustomScrollbar",
                BackgroundColor3 = SCROLL_THUMB_COLOR,
                BackgroundTransparency = SCROLL_THUMB_TRANSPARENCY,
                BorderSizePixel = 0,
                Position = UDim2.new(anchorX.Scale, anchorX.Offset, 0, 0),
                Size = UDim2.new(0, SCROLL_THUMB_WIDTH, 0, 30),
                Visible = false,
                ZIndex = 10,
                Parent = container
            })
            AddCorner(thumb, 2)

            local function update()
                local canvasH = scrollingFrame.CanvasSize.Y.Offset
                local viewH = scrollingFrame.AbsoluteSize.Y
                if canvasH <= viewH or viewH <= 0 then
                    thumb.Visible = false
                    return
                end
                thumb.Visible = true
                local thumbH = math.max(20, viewH * (viewH / canvasH))
                local maxScroll = canvasH - viewH
                local scrollRatio = maxScroll > 0 and (scrollingFrame.CanvasPosition.Y / maxScroll) or 0
                local thumbY = scrollRatio * (viewH - thumbH)
                thumb.Size = UDim2.new(0, SCROLL_THUMB_WIDTH, 0, thumbH)
                thumb.Position = UDim2.new(anchorX.Scale, anchorX.Offset, 0, thumbY)
            end

            TrackConnection(scrollingFrame:GetPropertyChangedSignal("CanvasPosition"):Connect(update))
            TrackConnection(scrollingFrame:GetPropertyChangedSignal("CanvasSize"):Connect(update))
            TrackConnection(scrollingFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))

            local dragging = false
            local dragStartMouseY = 0
            local dragStartCanvasY = 0

            thumb.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    dragStartMouseY = UserInputService:GetMouseLocation().Y
                    dragStartCanvasY = scrollingFrame.CanvasPosition.Y
                end
            end)

            TrackConnection(UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    local canvasH = scrollingFrame.CanvasSize.Y.Offset
                    local viewH = scrollingFrame.AbsoluteSize.Y
                    local maxScroll = canvasH - viewH
                    if maxScroll <= 0 then return end
                    local thumbH = math.max(20, viewH * (viewH / canvasH))
                    local trackH = viewH - thumbH
                    if trackH <= 0 then return end
                    local deltaY = UserInputService:GetMouseLocation().Y - dragStartMouseY
                    local newCanvasY = math.clamp(dragStartCanvasY + (deltaY / trackH) * maxScroll, 0, maxScroll)
                    scrollingFrame.CanvasPosition = Vector2.new(0, newCanvasY)
                end
            end))

            TrackConnection(UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end))

            task.defer(update)
            return thumb
        end

        ----------------------------------------------------------------
        -- ПОИСК: фильтрация строк, скрытие пустых секций
        ----------------------------------------------------------------

        local function applySearch(query)
            local q = query:lower()
            for _, sec in ipairs(sections) do
                local anyVisible = false
                local firstShown = true
                for _, entry in ipairs(sec.rows) do
                    local vis = q == ""
                        or entry.name:find(q, 1, true) ~= nil
                        or entry.desc:find(q, 1, true) ~= nil
                    entry.row.Visible = vis
                    if entry.sep then
                        entry.sep.Visible = vis and not firstShown
                    end
                    if vis then
                        anyVisible = true
                        firstShown = false
                    end
                end
                sec.frame.Visible = anyVisible
            end
        end

        ----------------------------------------------------------------
        -- ИКОНКИ ВКЛАДОК в стиле Geist Icons: сетка 16x16, штрих 1.5,
        -- геометрия из Frame/UIStroke, без внешних ассетов
        ----------------------------------------------------------------
        local ICON_STROKE = 1.5
        local ICON_SIZE = 18

        -- Имя вкладки → имя иконки в паке geist (WindUI)
        local TAB_ICON_NAMES = {
            main     = "grid-square",
            home     = "grid-square",
            aim      = "target",
            visuals  = "eye",
            visual   = "eye",
            esp      = "eye",
            combat   = "crosshair",
            farming  = "dollar",
            farm     = "dollar",
            fun      = "sparkles",
            troll    = "lightning",
            server   = "servers",
            servers  = "servers",
            settings = "settings-sliders",
            config   = "settings-gear",
            player   = "user",
            players  = "users",
            misc     = "box",
            shop     = "coins",
            debug    = "bug",
        }

        local function makeTabIcon(tabName, parent)
            local holder = Create("Frame", {
                Name = "Icon",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 10, 0.5, -ICON_SIZE / 2),
                Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE),
                Parent = parent
            })

            -- Основной путь: спрайт из пака WindUI
            local data = iconData(TAB_ICON_NAMES[tabName:lower()])
            if data then
                local img = Create("ImageLabel", {
                    Name = "Sprite",
                    Image = data.Image,
                    ImageRectOffset = data.Offset,
                    ImageRectSize = data.Size,
                    ImageColor3 = T.TextDark,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Parent = holder
                })
                return function(col)
                    img.ImageColor3 = col
                end
            end
            -- Фолбэк (нет сети / имени нет в паке): рисованная иконка

            local fills, strokes, labels = {}, {}, {}

            -- Обёртки над общими глиф-фабриками: складывают созданное
            -- в списки, чтобы setColor мог перекрасить иконку целиком
            local function line(x, y, w, h, rot, corner)
                local f = glyphLine(holder, x, y, w, h, rot, corner)
                table.insert(fills, f)
                return f
            end

            local function ring(x, y, w, h, corner)
                local f, s = glyphRing(holder, x, y, w, h, corner, ICON_STROKE)
                table.insert(strokes, s)
                return f
            end

            -- Текстовый глиф внутри иконки (например «$» на монете)
            local function label(text, size)
                local l = Create("TextLabel", {
                    Text = text,
                    Font = FONT.Bold,
                    TextSize = size or 10,
                    TextColor3 = T.TextDark,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 1, 0),
                    Parent = holder
                })
                table.insert(labels, l)
                return l
            end

            -- Все штрихи 1.5px, радиусы кратны 2 — как в наборе Geist Icons
            local n = tabName:lower()
            if n == "main" then
                -- grid 2x2 (dashboard)
                ring(1, 1, 6, 6, 2)
                ring(9, 1, 6, 6, 2)
                ring(1, 9, 6, 6, 2)
                ring(9, 9, 6, 6, 2)
            elseif n == "aim" then
                -- target: два кольца и точка
                ring(1, 1, 14, 14, 7)
                ring(5, 5, 6, 6, 3)
                line(7, 7, 2, 2, 0, 1)
            elseif n == "combat" then
                -- crosshair: кольцо + 4 риски
                ring(2, 2, 12, 12, 6)
                line(7.25, 0, 1.5, 3)
                line(7.25, 13, 1.5, 3)
                line(0, 7.25, 3, 1.5)
                line(13, 7.25, 3, 1.5)
            elseif n == "visuals" then
                -- eye: пилюля-контур + зрачок
                ring(0, 4, 16, 8, 4)
                line(6, 6, 4, 4, 0, 2)
            elseif n == "farming" or n == "farm" then
                -- dollar: кольцо + «$» по центру
                ring(2, 2, 12, 12, 6)
                label("$", 10)
            elseif n == "fun" then
                -- sparkle: 4 луча из центра
                line(7.25, 1, 1.5, 14)
                line(1, 7.25, 14, 1.5)
                line(7.25, 2, 1.5, 12, 45)
                line(7.25, 2, 1.5, 12, -45)
            elseif n == "troll" then
                -- smiley: кольцо + глаза + рот
                ring(2, 2, 12, 12, 6)
                line(5, 6, 2, 2, 0, 1)
                line(9, 6, 2, 2, 0, 1)
                line(5, 10, 6, 1.5, 0, 1)
            elseif n == "server" or n == "servers" then
                -- stack: две плашки-контура друг над другом
                ring(1, 2, 14, 5, 2)
                ring(1, 9, 14, 5, 2)
                line(3.5, 4, 1.5, 1.5, 0, 1)
                line(3.5, 11, 1.5, 1.5, 0, 1)
            elseif n == "player" or n == "players" then
                -- user: голова + плечи
                ring(5, 1, 6, 6, 3)
                ring(2, 9, 12, 10, 5)
            elseif n == "settings" then
                -- sliders: 3 линии с бегунками
                line(2, 3, 12, 1.5)
                line(4, 1, 3, 4, 0, 1)
                line(2, 7.25, 12, 1.5)
                line(9, 5, 3, 4, 0, 1)
                line(2, 11.5, 12, 1.5)
                line(6, 9.5, 3, 4, 0, 1)
            else
                -- дефолт: скруглённая рамка
                ring(2, 2, 12, 12, 4)
            end

            local function setColor(col)
                for _, f in ipairs(fills) do f.BackgroundColor3 = col end
                for _, s in ipairs(strokes) do s.Color = col end
                for _, l in ipairs(labels) do l.TextColor3 = col end
            end

            return setColor
        end

        ----------------------------------------------------------------
        -- ВНУТРЕННИЙ КОНСТРУКТОР ТАБА + TabFunctions
        ----------------------------------------------------------------

        local function CreateTab(name)
            local tabBtn = Create("TextButton", {
                Text = "",
                BackgroundColor3 = G.Gray200,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, CTRL_H),
                AutoButtonColor = false,
                Parent = navScroll
            })
            AddCorner(tabBtn, R_CTRL)

            local setIconColor = makeTabIcon(name, tabBtn)

            local tabLabel = Create("TextLabel", {
                Text = name,
                Font = FONT.Bold,
                TextSize = TS.Nav,
                TextColor3 = T.TextDark,
                TextXAlignment = Enum.TextXAlignment.Left,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 34, 0, 0),
                Size = UDim2.new(1, -42, 1, 0),
                Parent = tabBtn
            })

            -- Контейнер двух колонок для этой вкладки
            local pageHolder = Create("Frame", {
                Name = name .. "PageHolder",
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                Visible = false,
                Parent = pagesContainer
            })

            local leftPage = Create("ScrollingFrame", {
                Name = name .. "PageLeft",
                BackgroundTransparency = 1,
                Position = UDim2.new(0, 0, 0, 0),
                Size = UDim2.new(0.5, -COL_GAP / 2, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                BorderSizePixel = 0,
                Parent = pageHolder
            })
            local leftLayout = Create("UIListLayout", {
                Padding = UDim.new(0, CARD_GAP),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = leftPage
            })
            -- UIStroke рисуется СНАРУЖИ фрейма, а ScrollingFrame режет всё,
            -- что вышло за его границы: без этого паддинга у верхней карточки
            -- пропадала верхняя грань обводки (оставались только уголки),
            -- а у крайних — боковые. Паддинг учтён в CanvasSize.
            Create("UIPadding", {
                PaddingTop = UDim.new(0, PAGE_PAD),
                PaddingLeft = UDim.new(0, PAGE_PAD),
                PaddingRight = UDim.new(0, PAGE_PAD),
                Parent = leftPage
            })
            leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                leftPage.CanvasSize = UDim2.new(0, 0, 0,
                    leftLayout.AbsoluteContentSize.Y + PAGE_PAD * 2 + 20)
            end)
            AttachCustomScrollbar(leftPage, pageHolder, UDim.new(0.5, -COL_GAP / 2 + 4))

            local rightPage = Create("ScrollingFrame", {
                Name = name .. "PageRight",
                BackgroundTransparency = 1,
                Position = UDim2.new(0.5, COL_GAP / 2, 0, 0),
                Size = UDim2.new(0.5, -COL_GAP / 2, 1, 0),
                CanvasSize = UDim2.new(0, 0, 0, 0),
                ScrollBarThickness = 0,
                BorderSizePixel = 0,
                Parent = pageHolder
            })
            local rightLayout = Create("UIListLayout", {
                Padding = UDim.new(0, CARD_GAP),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = rightPage
            })
            Create("UIPadding", {
                PaddingTop = UDim.new(0, PAGE_PAD),
                PaddingLeft = UDim.new(0, PAGE_PAD),
                PaddingRight = UDim.new(0, PAGE_PAD),
                Parent = rightPage
            })
            rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                rightPage.CanvasSize = UDim2.new(0, 0, 0,
                    rightLayout.AbsoluteContentSize.Y + PAGE_PAD * 2 + 20)
            end)
            AttachCustomScrollbar(rightPage, pageHolder, UDim.new(1, 4))

            local currentPage = leftPage
            local currentSectionData = nil

            local function isActive()
                return currentTab ~= nil and currentTab.Btn == tabBtn
            end

            local function Activate()
                if State.UIElements.OpenDropdowns then
                    for _, closeFunc in ipairs(State.UIElements.OpenDropdowns) do
                        pcall(closeFunc)
                    end
                end
                if currentTab then
                    TweenService:Create(
                        currentTab.Btn,
                        TweenInfo.new(0.12, Enum.EasingStyle.Quad),
                        {BackgroundTransparency = 1}
                    ):Play()
                    currentTab.Label.TextColor3 = T.TextDark
                    currentTab.SetIcon(T.TextDark)
                    currentTab.Holder.Visible = false
                end
                currentTab = {
                    Btn = tabBtn, Holder = pageHolder,
                    Label = tabLabel, SetIcon = setIconColor
                }
                -- активный пункт: gray-200 подложка + gray-1000 текст (Geist nav)
                tabBtn.BackgroundColor3 = G.Gray200
                TweenService:Create(
                    tabBtn,
                    TweenInfo.new(0.12, Enum.EasingStyle.Quad),
                    {BackgroundTransparency = 0}
                ):Play()
                tabLabel.TextColor3 = T.Text
                setIconColor(T.Text)
                pageHolder.Visible = true
                tabTitle.Text = name
            end

            tabBtn.MouseButton1Click:Connect(Activate)

            tabBtn.MouseEnter:Connect(function()
                if not isActive() then
                    tabBtn.BackgroundColor3 = G.Gray100
                    TweenService:Create(tabBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 0
                    }):Play()
                    tabLabel.TextColor3 = T.Text
                    setIconColor(T.Text)
                end
            end)
            tabBtn.MouseLeave:Connect(function()
                if not isActive() then
                    TweenService:Create(tabBtn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                        BackgroundTransparency = 1
                    }):Play()
                    tabLabel.TextColor3 = T.TextDark
                    setIconColor(T.TextDark)
                end
            end)

            if #Tabs == 0 then
                Activate()
            end
            table.insert(Tabs, {Btn = tabBtn, Holder = pageHolder})

            --------------------------------------------
            -- Секции-контейнеры и строки внутри них
            --------------------------------------------

            local function newSection(title)
                local sec = Create("Frame", {
                    Name = (title or "Section") .. "Card",
                    BackgroundColor3 = T.Surface1,
                    BackgroundTransparency = CARD_TRANSPARENCY,
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    Parent = currentPage
                })
                AddCorner(sec, R_CARD)
                AddStroke(sec, STROKE_W, T.Border)

                local layout = Create("UIListLayout", {
                    Padding = UDim.new(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = sec
                })
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    sec.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y + CARD_PAD_B)
                end)

                -- Шапка карточки: компактная строка 32px, gray-700
                if title and title ~= "" then
                    local head = Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Section,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 32),
                        LayoutOrder = 1,
                        Parent = sec
                    })
                    Create("UIPadding", {PaddingLeft = UDim.new(0, EDGE), PaddingTop = UDim.new(0, 8), Parent = head})
                end

                local data = {frame = sec, layout = layout, rows = {}, order = 1}
                table.insert(sections, data)
                return data
            end

            local function ensureSection()
                if not currentSectionData then
                    currentSectionData = newSection(nil)
                end
                return currentSectionData
            end

            -- Строка контрола: подсветка при hover, регистрация в поиске.
            -- Разделителей между строками нет — строки разделяет ритм и
            -- hover-подложка; линии на каждой строке делали карточку решёткой
            local function addRow(height, searchName, searchDesc)
                local data = ensureSection()
                local sep = nil
                data.order = data.order + 1
                local row = Create("Frame", {
                    -- hover-подложка строки = gray-100 (Geist «default background»)
                    BackgroundColor3 = G.Gray100,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, height),
                    LayoutOrder = data.order,
                    Parent = data.frame
                })
                row.MouseEnter:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
                end)
                row.MouseLeave:Connect(function()
                    TweenService:Create(row, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
                end)
                table.insert(data.rows, {
                    row = row,
                    sep = sep,
                    name = (searchName or ""):lower(),
                    desc = (searchDesc or ""):lower()
                })
                return row
            end

            -- Заголовок и описание внутри строки.
            -- reserved — ширина правого блока контролов вместе с отступами:
            -- текст обрезается ровно по его границе и не налезает на контрол
            local function addRowText(row, title, desc, reserved)
                reserved = reserved or 200
                if desc and desc ~= "" then
                    -- 9 + 20 + 18 + 9 = ROW_H_DESC: сверху и снизу поровну
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 9),
                        Size = UDim2.new(1, -reserved, 0, 20),
                        Parent = row
                    })
                    Create("TextLabel", {
                        Text = desc,
                        Font = FONT.Body,
                        TextSize = TS.Desc,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 29),
                        Size = UDim2.new(1, -reserved, 0, 18),
                        Parent = row
                    })
                else
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Center,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 0),
                        Size = UDim2.new(1, -reserved, 1, 0),
                        Parent = row
                    })
                end
            end

            -- Мини-кнопка бинда (чип) — общая для CreateToggle/CreateKeybindButton
            local function makeKeybindChip(parent, keybindKey, width, height, posX)
                local bound = State.Keybinds and State.Keybinds[keybindKey]
                local chip = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "—",
                    Font = FONT.Bold,
                    TextSize = TS.Chip,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface1,
                    Position = posX,
                    Size = UDim2.new(0, width, 0, height),
                    AutoButtonColor = false,
                    Parent = parent
                })
                AddCorner(chip, R_CTRL)
                local chipStroke = AddStroke(chip, STROKE_W, T.Border)

                State.UIElements[keybindKey .. "_Button"] = chip

                chip.MouseButton1Click:Connect(function()
                    chip.Text = "..."
                    State.ListeningForKeybind = {key = keybindKey, button = chip}
                end)
                -- Geist secondary button: на hover светлеет только рамка и фон
                chip.MouseEnter:Connect(function()
                    TweenService:Create(chipStroke, TweenInfo.new(0.15), {Color = T.BorderHi}):Play()
                    TweenService:Create(chip, TweenInfo.new(0.15), {BackgroundColor3 = G.Gray200}):Play()
                end)
                chip.MouseLeave:Connect(function()
                    TweenService:Create(chipStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                    TweenService:Create(chip, TweenInfo.new(0.15), {BackgroundColor3 = T.Surface1}):Play()
                end)
                return chip
            end

            -- Выпадающий список поверх mainFrame + закрытие по клику мимо.
            -- Общая механика для CreateDropdown и CreatePlayerDropdown.
            local function makeOverlayList(anchorBtn, width)
                -- Geist popover: bg background-100, сплошная рамка, радиус 12,
                -- внутренний padding 6 и шаг строк 2 (--ds-popover-*)
                local overlay = Create("ScrollingFrame", {
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, width, 0, 0),
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = G.Gray500,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(overlay, R_CARD)
                AddStroke(overlay, STROKE_W, T.Border)

                Create("UIListLayout", {
                    Padding = UDim.new(0, 2),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = overlay
                })
                Create("UIPadding", {
                    PaddingTop = UDim.new(0, POPOVER_PAD),
                    PaddingBottom = UDim.new(0, POPOVER_PAD),
                    PaddingLeft = UDim.new(0, POPOVER_PAD),
                    PaddingRight = UDim.new(0, POPOVER_PAD),
                    Parent = overlay
                })

                local function close()
                    if overlay.Visible then
                        TweenService:Create(
                            overlay,
                            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                            {Size = UDim2.new(0, width, 0, 0)}
                        ):Play()
                        task.wait(0.2)
                        overlay.Visible = false
                    end
                end

                local function openAt(targetHeight)
                    local absPos = anchorBtn.AbsolutePosition
                    local absSize = anchorBtn.AbsoluteSize
                    local mainPos = mainFrame.AbsolutePosition
                    overlay.Position = UDim2.new(
                        0, absPos.X - mainPos.X,
                        0, absPos.Y - mainPos.Y + absSize.Y + 5
                    )
                    overlay.Size = UDim2.new(0, width, 0, 0)
                    TweenService:Create(
                        overlay,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                        {Size = UDim2.new(0, width, 0, targetHeight)}
                    ):Play()
                end

                -- Закрытие по клику вне списка и вне кнопки
                local clickOutsideConnection = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 and overlay.Visible then
                        local mousePos = UserInputService:GetMouseLocation()
                        local framePos = overlay.AbsolutePosition
                        local frameSize = overlay.AbsoluteSize
                        local btnPos = anchorBtn.AbsolutePosition
                        local btnSize = anchorBtn.AbsoluteSize

                        local outsideFrame =
                            mousePos.X < framePos.X or mousePos.X > framePos.X + frameSize.X or
                            mousePos.Y < framePos.Y or mousePos.Y > framePos.Y + frameSize.Y

                        local outsideButton =
                            mousePos.X < btnPos.X or mousePos.X > btnPos.X + btnSize.X or
                            mousePos.Y < btnPos.Y or mousePos.Y > btnPos.Y + btnSize.Y

                        if outsideFrame and outsideButton then
                            close()
                        end
                    end
                end)
                table.insert(State.Connections, clickOutsideConnection)

                if not State.UIElements.OpenDropdowns then
                    State.UIElements.OpenDropdowns = {}
                end
                table.insert(State.UIElements.OpenDropdowns, close)

                return overlay, openAt, close
            end

            --------------------------------------------
            -- TabFunctions (API 1:1, всё через Handlers)
            --------------------------------------------
            local TabFunctions = {}

            function TabFunctions:CreateSection(title, column)
                if column == "right" then
                    currentPage = rightPage
                elseif column == "left" then
                    currentPage = leftPage
                end
                currentSectionData = newSection(title)
            end

            function TabFunctions:CreateToggle(title, desc, handlerKey, default, keybindKey)
                default = default or false
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                -- правый блок: 40(тогл)+16 и, если есть чип, ещё 60+8 слева
                addRowText(row, title, desc, keybindKey and 148 or 80)

                -- Geist Toggle (large): трек 40x24, ручка 20 с инсетом 2,
                -- выкл. — gray-400, вкл. — акцент. Обводки у трека нет
                local TOG_W, TOG_H, KNOB = 40, 24, 20
                local KNOB_ON  = TOG_W - KNOB - 2
                local KNOB_OFF = 2

                local toggleBg = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = default and T.Accent or T.TrackBg,
                    Position = UDim2.new(1, -(TOG_W + EDGE), 0.5, -TOG_H / 2),
                    Size = UDim2.new(0, TOG_W, 0, TOG_H),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(toggleBg, TOG_H / 2)

                local toggleCircle = Create("Frame", {
                    BackgroundColor3 = T.Text,
                    BackgroundTransparency = 0.16,   -- rgba(237,237,237,.84) в Geist
                    Position = UDim2.new(0, default and KNOB_ON or KNOB_OFF, 0.5, -KNOB / 2),
                    Size = UDim2.new(0, KNOB, 0, KNOB),
                    BorderSizePixel = 0,
                    Parent = toggleBg
                })
                AddCorner(toggleCircle, KNOB / 2)

                -- Опциональный чип бинда слева от тогла
                if keybindKey then
                    makeKeybindChip(row, keybindKey, 60, CTRL_H, UDim2.new(1, -(TOG_W + EDGE + 8 + 60), 0.5, -CTRL_H / 2))
                end

                local state = default

                -- Сразу вызываем handler с начальным значением, чтобы State
                -- был синхронизирован с GUI
                if default then
                    task.spawn(function()
                        callHandler(handlerKey, default)
                    end)
                end

                TrackConnection(toggleBg.MouseButton1Click:Connect(function()
                    state = not state
                    local targetColor = state and T.Accent or T.TrackBg
                    local targetPos = UDim2.new(0, state and KNOB_ON or KNOB_OFF, 0.5, -KNOB / 2)

                    TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
                    TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = targetPos}):Play()

                    callHandler(handlerKey, state)
                end))

                return toggleBg
            end

            function TabFunctions:CreateDropdown(title, desc, options, default, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 152)

                local DD_W = 112
                local dropdown = Create("TextButton", {
                    Text = default,
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(1, -(DD_W + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, DD_W, 0, CTRL_H),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, R_CTRL)
                local ddStroke = AddStroke(dropdown, STROKE_W, T.Border)
                -- правый паддинг 24 — место под рисованный шеврон
                Create("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 24),
                    Parent = dropdown
                })
                glyphChevron(dropdown, 24)
                dropdown.MouseEnter:Connect(function()
                    TweenService:Create(ddStroke, TweenInfo.new(0.15), {Color = T.BorderHi}):Play()
                end)
                dropdown.MouseLeave:Connect(function()
                    TweenService:Create(ddStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                end)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                -- строка поповера Geist: 36px, радиус 6, hover — gray-200
                for _, option in ipairs(options) do
                    local optionBtn = Create("TextButton", {
                        Text = option,
                        Font = FONT.Body,
                        TextSize = TS.Option,
                        TextColor3 = T.Text,
                        BackgroundColor3 = G.Gray200,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, POPOVER_ROW),
                        AutoButtonColor = false,
                        ZIndex = 1001,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        Parent = overlay
                    })
                    AddCorner(optionBtn, R_CTRL)
                    Create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = optionBtn})

                    optionBtn.MouseButton1Click:Connect(function()
                        dropdown.Text = option
                        callHandler(handlerKey, option)
                        close()
                    end)

                    optionBtn.MouseEnter:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.12), {
                            BackgroundTransparency = 0
                        }):Play()
                    end)

                    optionBtn.MouseLeave:Connect(function()
                        TweenService:Create(optionBtn, TweenInfo.new(0.12), {
                            BackgroundTransparency = 1
                        }):Play()
                    end)
                end

                local function listHeight()
                    return #options * (POPOVER_ROW + 2) + POPOVER_PAD * 2
                end

                dropdown.MouseButton1Click:Connect(function()
                    if overlay.Visible then
                        close()
                    else
                        overlay.Visible = true
                        overlay.CanvasSize = UDim2.new(0, 0, 0, listHeight())
                        openAt(math.min(232, listHeight()))
                    end
                end)

                return dropdown
            end

            function TabFunctions:CreateInputField(title, desc, defaultValue, handlerKey)
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 92)

                local inputBox = Create("TextBox", {
                    Text = tostring(defaultValue),
                    Font = FONT.Mono,
                    TextSize = TS.Value,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(1, -(52 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 52, 0, CTRL_H),
                    PlaceholderText = "…",
                    PlaceholderColor3 = T.TextDark,
                    ClearTextOnFocus = false,
                    Parent = row
                })
                AddCorner(inputBox, R_CTRL)
                local inputStroke = AddStroke(inputBox, STROKE_W, T.Border)
                Create("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = inputBox})
                inputBox.Focused:Connect(function()
                    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = G.Gray600}):Play()
                end)

                inputBox.FocusLost:Connect(function()
                    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                    local value = tonumber(inputBox.Text)
                    if value then
                        callHandler(handlerKey, value)
                    else
                        inputBox.Text = tostring(defaultValue)
                    end
                end)
            end

            function TabFunctions:CreateSlider(title, description, min, max, default, handlerKey, step)
                step = step or 1
                local hasDesc = description ~= nil and description ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, description or "")
                addRowText(row, title, description, 200)

                local function fmt(v)
                    return step >= 1 and string.format("%d", v) or string.format("%.2f", v)
                end

                local currentValue = default

                -- Трек 100x4, кончается за 12px до поля значения (Geist slider:
                -- gray-400 фон, акцентная заливка, ручка gray-1000 в кольце фона)
                local sliderBg = Create("Frame", {
                    BackgroundColor3 = T.TrackBg,
                    Position = UDim2.new(1, -174, 0.5, -2),
                    Size = UDim2.new(0, 100, 0, 4),
                    BorderSizePixel = 0,
                    Parent = row
                })
                AddCorner(sliderBg, 2)

                local sliderFill = Create("Frame", {
                    BackgroundColor3 = T.Accent,
                    Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
                    BorderSizePixel = 0,
                    Parent = sliderBg
                })
                AddCorner(sliderFill, 2)

                local sliderButton = Create("TextButton", {
                    Text = "",
                    BackgroundColor3 = T.Text,
                    Position = UDim2.new((default - min) / (max - min), -7, 0.5, -7),
                    Size = UDim2.new(0, 14, 0, 14),
                    AutoButtonColor = false,
                    ZIndex = 3,
                    Parent = sliderBg
                })
                AddCorner(sliderButton, 7)
                AddStroke(sliderButton, 2, T.Surface1)

                local valueBox = Create("TextBox", {
                    Text = fmt(default),
                    Font = FONT.Mono,
                    TextSize = TS.Value,
                    TextColor3 = T.Text,
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(1, -(48 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 48, 0, CTRL_H),
                    ClearTextOnFocus = true,
                    Parent = row
                })
                AddCorner(valueBox, R_CTRL)
                AddStroke(valueBox, STROKE_W, T.Border)

                local function applyValue(value, fire)
                    value = math.floor(value / step + 0.5) * step
                    value = math.clamp(value, min, max)
                    currentValue = value

                    local normalizedValue = (value - min) / (max - min)
                    sliderFill.Size = UDim2.new(normalizedValue, 0, 1, 0)
                    sliderButton.Position = UDim2.new(normalizedValue, -7, 0.5, -7)
                    valueBox.Text = fmt(value)

                    if fire then
                        callHandler(handlerKey, value)
                    end
                end

                local dragging = false
                local function updateSlider(input)
                    local pos = sliderBg.AbsolutePosition.X
                    local size = sliderBg.AbsoluteSize.X
                    local mouseX = input.Position.X
                    local alpha = math.clamp((mouseX - pos) / size, 0, 1)
                    applyValue(min + alpha * (max - min), true)
                end

                sliderButton.MouseButton1Down:Connect(function() dragging = true end)
                sliderBg.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateSlider(input)
                    end
                end)
                TrackConnection(UserInputService.InputChanged:Connect(function(input)
                    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                        updateSlider(input)
                    end
                end))
                TrackConnection(UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
                end))

                -- Ручной ввод значения: clamp по min/max, округление до step
                valueBox.FocusLost:Connect(function()
                    local value = tonumber(valueBox.Text)
                    if value then
                        applyValue(value, true)
                    else
                        valueBox.Text = fmt(currentValue)
                    end
                end)
            end

            function TabFunctions:CreateKeybindButton(title, emoteId, keybindKey)
                local row = addRow(ROW_H, title, "")
                addRowText(row, title, nil, 136)

                -- Geist secondary button
                local bound = State.Keybinds and State.Keybinds[keybindKey]
                local bindButton = Create("TextButton", {
                    Name = keybindKey .. "_Button",
                    Text = (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "Not Bound",
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(1, -(96 + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, 96, 0, CTRL_H),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(bindButton, R_CTRL)
                local bindStroke = AddStroke(bindButton, STROKE_W, T.Border)

                State.UIElements[keybindKey .. "_Button"] = bindButton

                bindButton.MouseButton1Click:Connect(function()
                    bindButton.Text = "Press Key..."
                    State.ListeningForKeybind = {key = keybindKey, button = bindButton}
                end)
                bindButton.MouseEnter:Connect(function()
                    TweenService:Create(bindStroke, TweenInfo.new(0.15), {Color = T.BorderHi}):Play()
                    TweenService:Create(bindButton, TweenInfo.new(0.15), {BackgroundColor3 = G.Gray200}):Play()
                end)
                bindButton.MouseLeave:Connect(function()
                    TweenService:Create(bindStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                    TweenService:Create(bindButton, TweenInfo.new(0.15), {BackgroundColor3 = T.Surface1}):Play()
                end)

                return bindButton
            end

            -- stateKey - в какое поле State писать выбор. Разные вкладки передают
            -- разные ключи, иначе списки затирают друг друга.
            function TabFunctions:CreatePlayerDropdown(title, desc, stateKey)
                stateKey = stateKey or "SelectedPlayerForFling"
                local hasDesc = desc ~= nil and desc ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, desc or "")
                addRowText(row, title, desc, 200)

                local DD_W = 160
                local dropdown = Create("TextButton", {
                    Text = "Select player",
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = T.Text,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextTruncate = Enum.TextTruncate.AtEnd,
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(1, -(DD_W + EDGE), 0.5, -CTRL_H / 2),
                    Size = UDim2.new(0, DD_W, 0, CTRL_H),
                    AutoButtonColor = false,
                    ZIndex = 5,
                    Parent = row
                })
                AddCorner(dropdown, R_CTRL)
                local pdStroke = AddStroke(dropdown, STROKE_W, T.Border)
                -- правый паддинг 24 — место под рисованный шеврон
                Create("UIPadding", {
                    PaddingLeft = UDim.new(0, 12),
                    PaddingRight = UDim.new(0, 24),
                    Parent = dropdown
                })
                glyphChevron(dropdown, 24)
                dropdown.MouseEnter:Connect(function()
                    TweenService:Create(pdStroke, TweenInfo.new(0.15), {Color = T.BorderHi}):Play()
                end)
                dropdown.MouseLeave:Connect(function()
                    TweenService:Create(pdStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                end)

                local overlay, openAt, close = makeOverlayList(dropdown, DD_W)

                local function updatePlayerList()
                    for _, child in ipairs(overlay:GetChildren()) do
                        if child:IsA("TextButton") or child:IsA("TextLabel") then
                            child:Destroy()
                        end
                    end

                    local players = getAllPlayers()
                    if #players == 0 then
                        local empty = Create("TextLabel", {
                            Text = "No players",
                            Font = FONT.Body,
                            TextSize = TS.Option,
                            TextColor3 = T.TextDark,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, POPOVER_ROW),
                            ZIndex = 1001,
                            Parent = overlay
                        })
                        Create("UIPadding", {PaddingLeft = UDim.new(0, 8), Parent = empty})
                        overlay.CanvasSize = UDim2.new(0, 0, 0, POPOVER_ROW + POPOVER_PAD * 2)
                        return
                    end

                    -- ширина строк — на всю ширину списка: UIListLayout всё равно
                    -- перебивает Position, а инсет давал «съеденный» правый край
                    local buttonSpacing = 2
                    overlay.CanvasSize = UDim2.new(0, 0, 0,
                        #players * (POPOVER_ROW + buttonSpacing) + POPOVER_PAD * 2)

                    for _, playerName in ipairs(players) do
                        local pb = Create("TextButton", {
                            Text = playerName,
                            Font = FONT.Body,
                            TextSize = TS.Option,
                            TextColor3 = T.Text,
                            BackgroundColor3 = G.Gray200,
                            BackgroundTransparency = 1,
                            Size = UDim2.new(1, 0, 0, POPOVER_ROW),
                            AutoButtonColor = false,
                            ZIndex = 1001,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            TextTruncate = Enum.TextTruncate.AtEnd,
                            Parent = overlay
                        })
                        AddCorner(pb, R_CTRL)
                        Create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = pb})

                        pb.MouseButton1Click:Connect(function()
                            State[stateKey] = playerName
                            -- длинные ники режет TextTruncate, вручную не обрезаем
                            dropdown.Text = playerName
                            close()
                        end)

                        pb.MouseEnter:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.12), {
                                BackgroundTransparency = 0
                            }):Play()
                        end)

                        pb.MouseLeave:Connect(function()
                            TweenService:Create(pb, TweenInfo.new(0.12), {
                                BackgroundTransparency = 1
                            }):Play()
                        end)
                    end
                end

                dropdown.MouseButton1Click:Connect(function()
                    if overlay.Visible then
                        close()
                    else
                        overlay.Visible = true
                        updatePlayerList()
                        local playerCount = math.max(1, #getAllPlayers())
                        openAt(math.min(240, playerCount * (POPOVER_ROW + 2) + POPOVER_PAD * 2))
                    end
                end)

                TrackConnection(Players.PlayerAdded:Connect(function()
                    if overlay.Visible then
                        updatePlayerList()
                    end
                end))

                TrackConnection(Players.PlayerRemoving:Connect(function()
                    if overlay.Visible then
                        updatePlayerList()
                    end
                end))

                return dropdown
            end

            function TabFunctions:CreateButton(title, buttonText, color, handlerKey)
                local hasTitle = title ~= nil and title ~= ""
                local row = addRow(hasTitle and 82 or ROW_H + 8, title or "", buttonText)

                if hasTitle then
                    Create("TextLabel", {
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Title,
                        TextColor3 = T.Text,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        BackgroundTransparency = 1,
                        Position = UDim2.new(0, EDGE, 0, 12),
                        Size = UDim2.new(1, -EDGE * 2, 0, 20),
                        Parent = row
                    })
                end

                -- Варианты кнопки Geist:
                --   primary  (color = nil)  — заливка gray-1000, тёмный текст
                --   error    (color = Red)  — заливка red-800, белый текст
                --   custom   (свой цвет)    — заливка переданным цветом
                local isDanger = color == CONFIG.Colors.Red
                local isPrimary = color == nil
                local baseColor = isDanger and T.DangerBg or (isPrimary and T.Text or color)
                local hoverColor
                if isPrimary then
                    hoverColor = Color3.fromRGB(255, 255, 255)          -- primary hover: белее
                elseif isDanger then
                    hoverColor = Color3.fromRGB(233, 68, 74)
                else
                    hoverColor = Color3.fromRGB(
                        math.min(255, baseColor.R * 255 + 20),
                        math.min(255, baseColor.G * 255 + 20),
                        math.min(255, baseColor.B * 255 + 20)
                    )
                end

                local button = Create("TextButton", {
                    Text = buttonText,
                    Font = FONT.Bold,
                    TextSize = TS.Button,
                    TextColor3 = isDanger and Color3.fromRGB(255, 255, 255) or T.AccentInk,
                    BackgroundColor3 = baseColor,
                    -- 12 + 20 + 6 + 32 + 12 = 82 при заголовке; иначе строго по центру
                    Position = hasTitle and UDim2.new(0, EDGE, 0, 38) or UDim2.new(0, EDGE, 0.5, -CTRL_H / 2),
                    Size = UDim2.new(1, -EDGE * 2, 0, CTRL_H),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(button, R_CTRL)

                button.MouseButton1Click:Connect(function()
                    callHandler(handlerKey)
                end)

                button.MouseEnter:Connect(function()
                    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
                end)
                button.MouseLeave:Connect(function()
                    TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play()
                end)

                return button
            end

            return TabFunctions
        end
        GUI.CreateTab = CreateTab

        ----------------------------------------------------------------
        -- Кнопка закрытия, поиск, драг за хедер, инпут
        ----------------------------------------------------------------

        closeButton.MouseButton1Click:Connect(function()
            callHandler("Shutdown")
        end)

        -- Geist ghost button: на hover подложка gray-200, иконка gray-1000
        closeButton.MouseEnter:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 0
            }):Play()
            for _, s in ipairs(closeStrokes) do
                TweenService:Create(s, TweenInfo.new(0.15), {BackgroundColor3 = T.Text}):Play()
            end
        end)
        closeButton.MouseLeave:Connect(function()
            TweenService:Create(closeButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 1
            }):Play()
            for _, s in ipairs(closeStrokes) do
                TweenService:Create(s, TweenInfo.new(0.15), {BackgroundColor3 = T.TextDark}):Play()
            end
        end)

        -- Поиск: фильтрация строк и скрытие пустых секций
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            applySearch(searchBox.Text)
        end)

        -- Перетаскивание окна за хедер (кастомный драг вместо Draggable)
        local winDragging = false
        local winDragStart = nil
        local winStartPos = nil

        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                winDragging = true
                winDragStart = UserInputService:GetMouseLocation()
                winStartPos = mainFrame.Position
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if winDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = UserInputService:GetMouseLocation() - winDragStart
                mainFrame.Position = UDim2.new(
                    winStartPos.X.Scale, winStartPos.X.Offset + delta.X,
                    winStartPos.Y.Scale, winStartPos.Y.Offset + delta.Y
                )
            end
        end))
        TrackConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                winDragging = false
            end
        end))

        local inputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
            if not processed and input.KeyCode == CONFIG.HideKey then
                mainFrame.Visible = not mainFrame.Visible
            end

            if processed then return end

            -- Листенер на выбор кейбинда
            if State.ListeningForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode
                local bindData = State.ListeningForKeybind

                if key == Enum.KeyCode.Delete or key == Enum.KeyCode.Backspace then
                    callHandler("ClearKeybind", bindData.key, bindData.button)
                    State.ListeningForKeybind = nil
                    return
                end

                callHandler("SetKeybind", bindData.key, key, bindData.button)
                State.ListeningForKeybind = nil
                return
            end

            -- Эмоты
            callHandler("OnInputEmotes", input)

            -- Actions (knifeThrow, shootMurderer, PickupGun, ClickTP, GodMode toggle, FlingPlayer, NoClip)
            callHandler("OnInputActions", input)
        end)
        table.insert(State.Connections, inputBeganConnection)

        local inputEndedConnection = UserInputService.InputEnded:Connect(function(input)
            callHandler("OnInputEnded", input)
        end)
        table.insert(State.Connections, inputEndedConnection)

        local mouse = LocalPlayer:GetMouse()
        local mouseClickConnection = mouse.Button1Down:Connect(function()
            callHandler("OnMouseClick")
        end)
        table.insert(State.Connections, mouseClickConnection)

        -- ResizeGrip: изменение размера окна мышью
        local resizeGrip = Create("TextButton", {
            Name = "ResizeGrip",
            Text = "",
            BackgroundTransparency = 1,
            Position = UDim2.new(1, -20, 1, -20),
            Size = UDim2.new(0, 18, 0, 18),
            AutoButtonColor = false,
            Active = true,
            ZIndex = 10,
            Parent = mainFrame,
        })
        glyphResizeCorner(resizeGrip)

        local resizing = false
        local resizeStart = nil
        local frameStartSize = nil

        resizeGrip.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = true
                resizeStart = UserInputService:GetMouseLocation()
                frameStartSize = mainFrame.AbsoluteSize
            end
        end)
        TrackConnection(UserInputService.InputChanged:Connect(function(input)
            if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
                local mouseLoc = UserInputService:GetMouseLocation()
                local delta = mouseLoc - resizeStart
                local newW = math.clamp(frameStartSize.X + delta.X, 720, 1400)
                local newH = math.clamp(frameStartSize.Y + delta.Y, 480, 900)
                mainFrame.Size = UDim2.new(0, newW, 0, newH)
            end
        end))
        TrackConnection(UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                resizing = false
            end
        end))
    end

    ----------------------------------------------------------------
    -- API
    ----------------------------------------------------------------

    function GUI.Init()
        CreateUI()
    end

    function GUI.Cleanup()
        if State.UIElements.MainGui then
            pcall(function()
                State.UIElements.MainGui:Destroy()
            end)
            State.UIElements.MainGui = nil
        end
        -- BlurEffect живёт в Lighting, сам он не уберётся вместе с ScreenGui
        if State.UIElements.Blur then
            pcall(function()
                State.UIElements.Blur:Destroy()
            end)
            State.UIElements.Blur = nil
        end
    end

    return GUI
end
