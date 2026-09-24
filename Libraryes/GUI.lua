-- GUI.lua
-- Библиотека GUI для MM2 скрипта — редизайн «Violite v2»
-- Сайдбар вместо ленты табов, секции-контейнеры со строками, футер-статусбар.
-- Публичный API совместим со старой версией, все колбэки — через env.Handlers.

return function(env)
    local CONFIG = env.CONFIG
    local State = env.State.Runtime or env.State
    local Settings = env.State.Settings or env.State
    local Players = env.Players
    local CoreGui = env.CoreGui
    local TweenService = env.TweenService
    local UserInputService = env.UserInputService
    local LocalPlayer = env.LocalPlayer
    local TrackConnection = env.TrackConnection
    local ShowNotification = env.ShowNotification
    local Handlers = env.Handlers

    local task = env.Tasks or task
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
        Nav       = 16,
        Section   = 15,
        Title     = 16,   -- label
        Desc      = 14,   -- body-md
        Button    = 15,
        Value     = 15,
        Chip      = 13,
        Status    = 13,
        Option    = 15,
        Search    = 15,
        StatLabel = 13,   -- подписи инфо-блока в сайдбаре
        StatValue = 14,
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
    local ROW_INSET_X  = 4    -- отступ подсветки строки от боков карточки
    local ROW_INSET_Y  = 2    -- то же по вертикали
    local NAV_H        = 36   -- высота пункта сайдбара
    local TITLE_GAP    = 6    -- зазор между заголовком группы и её карточкой
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
    -- Карточки чуть прозрачнее фона окна: сквозь них видно размытую сцену,
    -- за счёт этого блоки читаются как матовое стекло, а не как плашки.
    -- Контролы внутри (кнопки, поля, дропдауны) остаются непрозрачными —
    -- так они отделяются от подложки
    local CARD_TRANSPARENCY = 0.16
    local ROW_HOVER_ALPHA = 0.12   -- подсветка строки не плотнее карточки
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

    -- Angel outfit — Lorc / Game-icons.net, CC BY 3.0 (Assets/LICENSE.txt).
    -- Roblox использует PNG: белая маска из SVG окрашивается через ImageColor3.
    local AURA_ICON_PATH = "7yd7/Assets/GameIconsAngelOutfit_1b1061bf.png"
    local AURA_ICON_PNG = "\137\080\078\071\013\010\026\010\000\000\000\013\073\072\068\082\000\000\000\064\000\000\000\064\008\006\000\000\000\170\105\113\222\000\000\000\009\112\072\089\115\000\000\011\019\000\000\011\019\001\000\154\156\024\000\000\007\098\073\068\065\084\120\156\237\154\009\176\213\083\028\199\111\155\010\037\132\164\140\162\133\188\020\106\212\212\160\073\150\201\120\205\068\074\011\021\134\180\072\137\049\053\150\136\100\138\169\103\105\038\049\106\122\079\166\018\090\044\209\180\042\147\044\237\101\139\054\042\180\168\212\199\252\244\251\115\058\157\243\095\238\125\247\041\115\191\051\111\222\123\247\158\223\114\126\231\156\223\249\045\039\149\202\033\135\028\074\018\064\057\160\030\208\026\104\007\220\012\180\215\255\047\001\042\164\254\079\000\074\001\173\128\231\128\207\129\253\132\227\032\176\006\120\089\013\084\046\117\060\002\040\013\244\212\201\004\056\000\044\000\070\001\189\117\245\243\245\247\221\192\112\224\003\096\143\065\179\009\120\004\168\152\058\094\000\084\003\022\026\147\248\009\232\011\156\026\147\254\068\160\059\176\214\224\177\030\184\056\251\218\187\149\025\002\204\003\138\128\202\017\227\079\182\086\125\138\124\022\070\019\194\171\060\240\170\193\107\007\080\059\130\166\172\210\200\002\012\003\078\073\071\246\223\000\234\000\235\172\051\058\048\021\002\053\086\128\085\050\137\084\230\071\233\083\131\103\081\196\248\078\150\190\027\129\075\211\017\124\014\240\141\195\073\245\143\160\155\101\140\029\153\088\176\155\231\096\243\056\069\140\189\195\161\243\022\089\204\164\066\167\225\070\139\008\186\177\198\216\247\018\009\245\243\124\195\224\185\040\098\236\185\030\189\231\203\141\020\087\096\107\015\147\109\064\153\008\218\139\128\125\006\077\215\132\243\181\249\181\213\171\049\064\126\012\154\175\060\250\119\138\043\116\186\135\065\097\076\250\124\227\042\059\004\188\008\156\025\075\248\191\060\042\171\019\059\096\240\121\032\038\237\227\030\253\023\199\033\174\026\018\172\244\073\048\001\217\009\239\027\180\178\043\038\107\108\144\103\059\071\141\016\235\170\019\123\013\248\221\160\093\014\092\153\064\246\085\248\017\238\011\128\059\067\136\219\199\085\194\224\119\025\240\018\240\131\131\223\078\096\051\176\093\087\216\196\207\192\068\224\026\185\009\018\202\172\025\050\135\135\163\136\095\015\033\190\062\169\001\044\222\245\129\014\122\085\074\168\091\168\206\182\072\157\231\147\226\051\128\198\073\039\237\008\196\124\008\119\204\028\142\184\124\232\153\058\070\001\156\014\052\210\191\037\169\242\097\135\215\184\028\062\255\097\024\105\068\104\189\050\089\165\098\078\182\122\232\145\105\172\159\117\139\152\071\125\031\179\230\017\132\107\141\177\133\234\228\106\150\224\124\109\125\027\105\114\037\088\097\124\254\086\196\060\110\244\049\236\074\052\174\208\177\141\213\113\237\002\006\001\039\148\224\196\207\085\031\018\092\145\130\110\250\221\025\192\238\136\057\244\243\049\126\052\134\001\166\121\028\230\090\221\122\101\179\056\241\011\117\226\102\160\037\088\018\004\104\192\208\024\115\120\193\039\096\076\012\098\089\245\150\134\207\144\107\204\132\056\209\001\073\003\159\144\073\159\004\116\004\102\059\174\074\212\024\193\217\175\001\252\022\099\014\147\124\194\038\018\015\043\130\064\006\184\218\218\138\001\036\152\122\071\157\101\157\132\078\077\002\162\123\244\044\071\109\231\094\006\237\212\152\250\207\242\009\159\065\124\140\054\232\100\146\081\144\235\103\014\048\014\120\074\253\070\240\243\140\030\167\249\049\087\048\192\088\067\007\169\040\197\197\018\159\001\230\146\012\093\012\218\199\040\089\076\054\206\125\083\224\143\004\180\043\125\006\152\151\080\009\057\127\215\026\244\178\154\037\129\073\065\177\020\184\192\225\135\162\176\202\103\128\005\105\040\035\091\182\185\117\028\162\042\191\153\224\121\099\229\107\001\223\166\193\099\181\207\000\011\211\084\074\050\183\086\006\159\150\090\205\045\078\236\177\142\092\061\079\130\021\007\107\124\006\152\147\129\130\114\006\187\027\188\170\167\185\163\092\216\016\196\249\202\187\149\022\103\210\197\114\159\001\222\046\006\101\011\130\168\080\126\107\081\035\147\035\049\001\056\205\208\241\126\207\181\155\004\243\051\141\003\162\032\215\217\217\006\223\188\052\118\195\006\203\193\086\176\074\228\153\096\166\207\000\005\105\050\148\170\171\013\241\204\029\172\242\246\125\192\175\017\188\100\183\060\045\253\008\043\073\251\218\049\118\107\154\250\022\198\041\063\135\193\108\093\009\246\234\238\049\139\151\001\166\155\025\163\230\237\079\056\012\177\095\139\034\181\172\186\224\024\015\223\034\173\040\217\122\184\198\218\024\149\164\166\238\130\107\053\126\212\100\104\139\231\170\236\109\054\058\165\077\166\193\211\086\077\112\206\179\116\105\167\077\013\027\059\181\109\182\042\166\094\046\012\240\025\160\141\135\192\078\066\036\005\254\200\049\110\177\006\038\190\158\130\116\153\110\055\051\070\187\086\015\092\039\181\127\015\253\135\122\253\205\116\124\183\200\113\036\092\201\147\160\163\207\000\117\061\004\223\059\062\027\239\009\066\102\104\133\247\038\077\154\092\144\222\097\023\179\199\160\198\095\016\226\016\111\083\063\034\183\130\013\185\018\071\199\212\091\208\204\103\128\050\122\142\092\043\039\074\216\126\032\223\145\155\163\254\160\180\254\228\107\220\110\158\121\009\146\250\025\017\093\041\061\126\223\025\099\118\235\078\234\020\236\024\201\227\029\178\228\204\223\162\037\049\019\191\000\075\061\006\168\226\052\128\000\088\230\033\114\089\120\092\072\022\086\096\110\111\053\134\084\107\170\167\066\000\156\165\063\071\116\160\066\146\173\193\122\107\216\112\021\078\004\027\147\244\225\076\244\177\154\021\193\025\107\017\162\220\017\070\072\023\033\252\165\227\212\192\017\104\201\255\119\121\104\102\071\009\235\235\033\124\069\243\118\027\095\234\153\151\036\005\207\074\100\082\227\151\094\129\011\019\244\200\126\226\217\153\062\186\161\081\002\047\247\016\174\215\045\044\055\000\174\055\003\154\014\031\242\056\204\068\181\066\245\011\035\060\186\060\171\223\203\141\098\067\194\228\243\067\110\146\240\230\014\135\095\088\184\038\041\104\232\217\142\187\130\123\092\157\158\043\019\156\026\247\005\152\234\032\171\104\099\187\081\253\173\234\137\004\011\052\017\115\005\068\007\099\189\024\225\200\071\014\038\134\104\076\110\191\026\065\183\098\105\035\200\025\237\040\111\125\028\245\092\070\019\040\121\086\099\223\056\146\007\084\139\168\253\111\086\217\082\079\116\097\105\156\005\072\001\247\122\024\044\051\130\021\023\006\057\042\186\029\116\215\060\024\084\147\099\200\111\034\173\112\013\153\059\219\171\166\145\160\011\157\245\123\169\032\187\048\036\174\001\170\135\068\081\181\067\074\232\226\125\155\164\178\008\145\239\041\156\078\081\191\080\197\115\253\009\242\146\008\090\232\097\210\223\216\170\139\060\241\120\086\222\244\169\111\112\069\139\043\129\074\058\070\034\076\023\214\037\021\214\195\195\232\051\099\076\013\071\132\040\024\151\133\249\167\060\001\207\038\179\217\025\082\218\127\040\169\176\138\026\078\186\208\208\234\197\127\225\024\211\163\152\039\223\214\113\044\037\116\174\107\029\221\063\061\229\186\228\157\042\252\247\240\008\107\156\196\007\239\090\099\246\006\045\171\098\058\247\210\088\049\049\215\238\076\171\163\117\097\124\186\130\171\058\004\007\219\238\168\192\070\218\206\154\170\238\049\154\150\025\053\075\213\177\005\219\122\159\022\110\111\117\069\151\158\122\192\094\187\214\144\084\129\129\030\171\182\013\161\041\157\209\019\085\055\207\074\097\198\212\238\144\011\195\051\021\092\222\122\170\122\084\155\252\088\128\245\064\051\192\234\168\183\205\073\094\093\109\115\132\149\255\212\239\254\075\232\221\111\135\239\242\127\131\226\020\210\204\017\123\015\075\029\003\208\226\138\009\041\190\180\201\134\160\218\250\104\049\192\214\076\095\131\023\131\078\165\116\171\155\047\085\242\178\041\176\140\122\225\055\053\002\187\033\107\194\226\233\211\084\013\048\077\211\227\018\123\171\148\067\014\057\228\144\067\014\057\164\142\107\252\005\077\164\112\175\144\170\180\248\000\000\000\000\073\069\078\068\174\066\096\130"
    local auraIconAsset
    local function loadAuraIconAsset()
        if auraIconAsset then return auraIconAsset end
        pcall(function()
            if not (isfile and writefile and getcustomasset) then return end
            if not isfile(AURA_ICON_PATH) then
                if makefolder then
                    if not (isfolder and isfolder(LOGO_DIR)) then pcall(makefolder, LOGO_DIR) end
                    if not (isfolder and isfolder(LOGO_ASSETS)) then pcall(makefolder, LOGO_ASSETS) end
                end
                writefile(AURA_ICON_PATH, AURA_ICON_PNG)
            end
            auraIconAsset = getcustomasset(AURA_ICON_PATH)
        end)
        return auraIconAsset
    end

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
    -- МИНИ-ИКОНКИ 16x16 для системы конфигов (пилюля и строки списка).
    -- Основной путь — спрайт из пака WindUI geist, фолбэк — рисованный
    -- глиф из Frame/UIStroke (сетка 16x16, штрих ~1.4 — как иконки вкладок)
    ----------------------------------------------------------------

    local GLYPH_DRAW = {
        -- дискета: контур + шторка сверху + этикетка снизу
        save = function(h)
            glyphRing(h, 2, 2, 12, 12, 3, 1.4)
            glyphLine(h, 6, 2.5, 4.5, 3.5, 0, 1)
            glyphLine(h, 5, 8.5, 6, 3.5, 0, 1)
        end,
        -- три точки «...»
        ellipsis = function(h)
            glyphLine(h, 2, 6.75, 2.5, 2.5, 0, 2)
            glyphLine(h, 6.75, 6.75, 2.5, 2.5, 0, 2)
            glyphLine(h, 11.5, 6.75, 2.5, 2.5, 0, 2)
        end,
        -- плюс
        plus = function(h)
            glyphLine(h, 7.25, 3, 1.5, 10, 0, 1)
            glyphLine(h, 3, 7.25, 10, 1.5, 0, 1)
        end,
        -- корзина: ручка + крышка + корпус
        trash = function(h)
            glyphLine(h, 6.5, 1, 3, 1.5, 0, 1)
            glyphLine(h, 3, 3, 10, 1.5, 0, 1)
            glyphRing(h, 4, 6, 8, 9, 2, 1.4)
        end,
        -- карандаш: корпус по диагонали + грифель
        pencil = function(h)
            glyphLine(h, 7, 1.5, 2, 11, 45, 1)
            glyphLine(h, 2.5, 11.5, 2.2, 2.2, 0, 1)
        end,
        -- копирование (share): два наложенных листа
        copy = function(h)
            glyphRing(h, 2, 2, 9, 9, 2, 1.4)
            glyphRing(h, 5.5, 5.5, 9, 9, 2, 1.4)
        end,
    }

    -- Имена в паке WindUI geist, соответствующие нашим глифам
    local ICON_NAMES = {
        save = "save",
        ellipsis = "ellipsis",
        plus = "plus",
        trash = "trash-2",
        pencil = "pencil",
        copy = "copy",
    }

    -- Кнопка-иконка в стиле ghost (как closeButton): прозрачная, на hover
    -- подложка gray-200. size — сторона квадрата хитбокса.
    local function makeIconButton(parent, position, size, glyphName)
        local z = (parent.ZIndex or 1) + 2
        local btn = Create("TextButton", {
            Name = glyphName .. "IconButton",
            Text = "",
            BackgroundColor3 = G.Gray200,
            BackgroundTransparency = 1,
            Position = position,
            Size = UDim2.new(0, size, 0, size),
            AutoButtonColor = false,
            ZIndex = z,
            Parent = parent
        })
        AddCorner(btn, R_SM)

        local holder = Create("Frame", {
            Name = "Glyph",
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.new(0, 16, 0, 16),
            ZIndex = z + 1,
            Parent = btn
        })

        local data = iconData(ICON_NAMES[glyphName])
        if data then
            Create("ImageLabel", {
                Name = "Sprite",
                Image = data.Image,
                ImageRectOffset = data.Offset,
                ImageRectSize = data.Size,
                ImageColor3 = T.TextDark,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                ZIndex = z + 1,
                Parent = holder
            })
        elseif GLYPH_DRAW[glyphName] then
            GLYPH_DRAW[glyphName](holder)
        end

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        end)

        return btn
    end

    ----------------------------------------------------------------
    -- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ИЗ MAIN (через Handlers)
    ----------------------------------------------------------------

    local function callHandler(name, ...)
        local fn = Handlers[name]
        if fn then
            local result = fn(...)
            if env.SyncControls then env.SyncControls() end
            return result
        end
    end

    ----------------------------------------------------------------
    -- РЕЕСТР ЭЛЕМЕНТОВ (модель WindUI): каждый сохраняемый контрол —
    -- объект с типом, текущим значением и методом Set.
    --
    --   { __type = "Toggle", Flag = "MurderESP", Value = ..., Default = ...,
    --     Set = function(self, value, fire) ... end }
    --
    -- __type нужен конфиг-менеджеру: он подбирает по нему парсер и не даёт
    -- подсунуть, например, число в тогл. Set(value, fire) — единственный
    -- путь изменения: и клик пользователя, и загрузка конфига идут через
    -- него, поэтому визуал и State не расходятся.
    -- PlayerDropdown в реестр не попадает: выбранный игрок сессионный.
    ----------------------------------------------------------------

    GUI.Flags = {}

    local function registerElement(flag, element)
        -- функция вместо ключа (легаси-вызовы) — молча не регистрируем
        if type(flag) ~= "string" or flag == "" then return element end
        element.Flag = flag
        element.Default = element.Value
        GUI.Flags[flag] = element
        return element
    end

    -- Элементы отдаются конфиг-менеджеру хоста: сериализацию и типовые
    -- парсеры держит он, библиотека только ведёт реестр
    function GUI.GetElements()
        return GUI.Flags
    end

    -- Кейбинд — такой же элемент реестра, как тогл или слайдер (модель WindUI):
    -- значение хранится СТРОКОЙ ("F" / "Unknown"), Enum собирается только при
    -- записи в Settings.Keybinds. Источник истины для обработчиков ввода — сам
    -- Settings.Keybinds, поэтому Get читает его напрямую: бинд, назначенный через
    -- захват клавиши (хендлер SetKeybind хоста), всё равно попадёт в конфиг.
    -- Префикс во флаге — чтобы имена биндов (Fly, GodMode, KillAura) не
    -- столкнулись с ключами хендлеров.
    local function registerKeybind(keybindKey, button, emptyText)
        local element = {
            __type = "Keybind",
            Instance = button,
            KeybindKey = keybindKey,
        }

        function element:Get()
            local bound = Settings.Keybinds and Settings.Keybinds[keybindKey]
            return (bound and bound ~= Enum.KeyCode.Unknown) and bound.Name or "Unknown"
        end

        function element:Set(value, fire)
            local keyCode = Enum.KeyCode.Unknown
            if typeof(value) == "EnumItem" then
                keyCode = value
            elseif type(value) == "string" and value ~= "" then
                pcall(function()
                    if Enum.KeyCode[value] then keyCode = Enum.KeyCode[value] end
                end)
            end
            self.Value = keyCode.Name
            if Settings.Keybinds then
                Settings.Keybinds[keybindKey] = keyCode
            end
            button.Text = (keyCode ~= Enum.KeyCode.Unknown) and keyCode.Name or emptyText
            -- fire не используется: бинд не имеет колбэка, скрипт читает
            -- Settings.Keybinds напрямую в обработчиках ввода
        end

        element.Value = element:Get()
        return registerElement("Keybind:" .. keybindKey, element)
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
    -- ACRYLIC: размытие ТОЛЬКО под окном
    ----------------------------------------------------------------
    -- Честного backdrop-blur в Roblox нет: BlurEffect — это пост-обработка,
    -- он мылит кадр целиком и вырезать из него прямоугольник нельзя.
    -- Обход (техника Fluent, её же использует WindUI): перед камерой висит
    -- плоская деталь из материала Glass, натянутая ровно на прямоугольник
    -- окна. Стекло преломляет то, что за ним, а DepthOfFieldEffect с
    -- NearIntensity = 1 размывает ближнее поле — мылится только та часть
    -- сцены, что попала под деталь. Меню рисуется поверх мира и остаётся
    -- резким.
    --
    -- Ограничения, о которых надо помнить:
    --   • размывается только 3D-мир; чужие 2D-интерфейсы (худ игры, таблица
    --     игроков) рисуются поверх мира и сквозь стекло не видны;
    --   • преломление Glass требует достаточного уровня графики — на низких
    --     настройках эффект выродится в лёгкое затемнение;
    --   • деталь висит в дереве камеры, поэтому ей принудительно снимается
    --     CanQuery, иначе она ловила бы лучи ESP и аимбота.
    local ACRYLIC_DISTANCE = 0.001
    local ACRYLIC_ALPHA = 0.98

    local function attachAcrylic(target)
        local Workspace = game:GetService("Workspace")
        local Lighting = game:GetService("Lighting")
        if not Workspace.CurrentCamera then return nil end

        -- Свой DoF работает только когда чужие выключены, иначе они
        -- перебивают ближнее поле. Исходные значения запоминаем.
        local savedDof = {}
        for _, e in ipairs(Lighting:GetChildren()) do
            if e:IsA("DepthOfFieldEffect") then
                savedDof[e] = e.Enabled
                e.Enabled = false
            end
        end

        local dof = Create("DepthOfFieldEffect", {
            Name = "Violite_Acrylic",
            FarIntensity = 0,
            InFocusRadius = 0.1,
            NearIntensity = 1,
            Parent = Lighting
        })

        local folder = Create("Folder", {
            Name = "Violite_AcrylicBlur",
            Parent = Workspace.CurrentCamera
        })
        local part = Create("Part", {
            Name = "Body",
            Color = Color3.new(0, 0, 0),
            Material = Enum.Material.Glass,
            Size = Vector3.new(1, 1, 0),
            Anchored = true,
            CanCollide = false,
            Locked = true,
            CastShadow = false,
            Transparency = ACRYLIC_ALPHA,
            Parent = folder
        })
        -- свойства новые, на старых клиентах их может не быть
        pcall(function() part.CanQuery = false end)
        pcall(function() part.CanTouch = false end)

        local mesh = Create("SpecialMesh", {
            MeshType = Enum.MeshType.Brick,
            Offset = Vector3.new(0, 0, -0.000001),
            Parent = part
        })

        local function toWorld(cam, point)
            local ray = cam:ScreenPointToRay(point.X, point.Y)
            return ray.Origin + ray.Direction * ACRYLIC_DISTANCE
        end

        local function render()
            local cam = Workspace.CurrentCamera
            if not cam or not part.Parent or not target.Parent then return end
            -- Края стекла поджимаем, чтобы они не торчали из-под скруглений
            -- окна. Формула из Fluent: чем выше вьюпорт, тем больше запас.
            local offset = math.clamp(cam.ViewportSize.Y / 2560 * 48 + 8, 8, 56)
            local size = target.AbsoluteSize - Vector2.new(offset, offset)
            local pos = target.AbsolutePosition + Vector2.new(offset / 2, offset / 2)
            if size.X <= 0 or size.Y <= 0 then return end

            local topLeft = toWorld(cam, pos)
            local topRight = toWorld(cam, pos + Vector2.new(size.X, 0))
            local bottomRight = toWorld(cam, pos + size)

            local camCF = cam.CFrame
            part.CFrame = CFrame.fromMatrix(
                (topLeft + bottomRight) / 2,
                camCF.XVector, camCF.YVector, camCF.ZVector
            )
            mesh.Scale = Vector3.new(
                (topRight - topLeft).Magnitude,
                (topRight - bottomRight).Magnitude,
                0
            )
        end

        local conns = {}
        local function bindCamera()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            table.insert(conns, cam:GetPropertyChangedSignal("CFrame"):Connect(render))
            table.insert(conns, cam:GetPropertyChangedSignal("ViewportSize"):Connect(render))
            table.insert(conns, cam:GetPropertyChangedSignal("FieldOfView"):Connect(render))
        end
        bindCamera()
        table.insert(conns, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if Workspace.CurrentCamera then
                folder.Parent = Workspace.CurrentCamera
                bindCamera()
                render()
            end
        end))
        table.insert(conns, target:GetPropertyChangedSignal("AbsolutePosition"):Connect(render))
        table.insert(conns, target:GetPropertyChangedSignal("AbsoluteSize"):Connect(render))
        task.defer(render)

        return {
            SetVisible = function(on)
                pcall(function()
                    part.Transparency = on and ACRYLIC_ALPHA or 1
                    dof.Enabled = on
                    if on then render() end
                end)
            end,
            Destroy = function()
                for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
                pcall(function() folder:Destroy() end)
                pcall(function() dof:Destroy() end)
                for e, enabled in pairs(savedDof) do
                    pcall(function() e.Enabled = enabled end)
                end
            end,
        }
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
            Size = UDim2.new(0, 1000, 0, 690),
            ClipsDescendants = false,
            Active = true,
            Parent = gui
        })
        AddCorner(mainFrame, R_CARD)
        AddStroke(mainFrame, STROKE_W, T.Border)

        -- Размытие фона. Основной путь — acrylic: мылится только прямоугольник
        -- под окном. Если стекло не поднялось (нет камеры, старый клиент),
        -- откатываемся на глобальный BlurEffect — лучше так, чем никак.
        local acrylic
        do
            local ok, res = pcall(function() return attachAcrylic(mainFrame) end)
            if ok then acrylic = res end
        end
        State.UIElements.Acrylic = acrylic

        local blurEffect
        if not acrylic then
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
        end
        State.UIElements.Blur = blurEffect

        local function applyBlur(on)
            if acrylic then
                acrylic.SetVisible(on)
                return
            end
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

        -- Полоса под логотипом ровно на высоте HEADER_H — вместе с линией под
        -- хедером даёт одну сплошную горизонталь через всё окно
        Hairline({
            Name = "SidebarHeaderSep",
            BackgroundColor3 = T.Border,
            Position = UDim2.new(0, 0, 0, HEADER_H),
            Size = UDim2.new(0, SIDEBAR_W, 0, 1),
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
        local STAT_ROW_H = 22
        local STAT_KEYS = {"Name", "Role", "Coins", "CoinsPerHour", "Version"}
        local STAT_TITLES = {
            Name = "NAME", Role = "ROLE", Coins = "COINS",
            CoinsPerHour = "COINS/H", Version = "VER",
        }
        local STATS_TOGGLE_H = 16          -- полоска сворачивания снизу блока
        local STATS_ROWS_H = #STAT_KEYS * STAT_ROW_H + 12
        local STATS_H = STATS_ROWS_H + STATS_TOGGLE_H
        local SIDEBAR_BOTTOM = STATS_H + 30   -- блок + строка подписи

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

        local statsRows = Create("Frame", {
            Name = "Rows",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(1, 0, 0, STATS_ROWS_H),
            Parent = statsFrame
        })

        -- Сворачивание — полосой под блоком, во всю его ширину
        local statsToggle = Create("TextButton", {
            Name = "StatsToggle",
            Text = "",
            BackgroundColor3 = G.Gray200,
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 0, 1, 0),
            Size = UDim2.new(1, 0, 0, STATS_TOGGLE_H),
            AutoButtonColor = false,
            ZIndex = 3,
            Parent = statsFrame
        })
        AddCorner(statsToggle, R_SM)
        local statsChev, statsChevA, statsChevB = glyphChevron(statsToggle)
        -- шеврон по центру полосы, а не у правого края
        statsChev.AnchorPoint = Vector2.new(0.5, 0.5)
        statsChev.Position = UDim2.new(0.5, 0, 0.5, 0)

        local statsHidden = getgenv().Violite_StatsHidden == true
        local function applyStatsHidden()
            statsRows.Visible = not statsHidden
            -- свёрнутый блок: шеврон смотрит вверх, полоса прижимается к низу
            statsChevA.Rotation = statsHidden and 45 or -45
            statsChevB.Rotation = statsHidden and -45 or 45
            statsFrame.Size = UDim2.new(0, SIDEBAR_W - EDGE * 2, 0,
                statsHidden and STATS_TOGGLE_H or STATS_H)
            statsFrame.Position = UDim2.new(0, EDGE, 1,
                -((statsHidden and STATS_TOGGLE_H or STATS_H) + 30))
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

        ----------------------------------------------------------------
        -- ПИЛЮЛЯ КОНФИГА: вместо заголовка вкладки (имя вкладки и так
        -- подсвечено в сайдбаре). Слева — быстрое сохранение в текущий
        -- конфиг, по центру — имя конфига, справа — шеврон. Клик по пилюле
        -- открывает панель конфигов (собирается ниже, после makeOverlayList)
        ----------------------------------------------------------------

        local PILL_W, PILL_H = 190, 32
        local configPill = Create("TextButton", {
            Name = "ConfigPill",
            Text = "",
            BackgroundColor3 = T.Surface1,
            Position = UDim2.new(0, EDGE + 4, 0.5, -PILL_H / 2),
            Size = UDim2.new(0, PILL_W, 0, PILL_H),
            AutoButtonColor = false,
            ZIndex = 5,
            Parent = header
        })
        AddCorner(configPill, PILL_H / 2)
        local pillStroke = AddStroke(configPill, STROKE_W, T.Border)

        -- Быстрое сохранение — отдельный хитбокс поверх пилюли
        local pillSaveBtn = makeIconButton(
            configPill, UDim2.new(0, 5, 0.5, -11), 22, "save")

        local pillName = Create("TextLabel", {
            Name = "ConfigName",
            Text = "no config",
            Font = FONT.Bold,
            TextSize = TS.Button,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 34, 0, 0),
            Size = UDim2.new(1, -(34 + 26), 1, 0),
            ZIndex = 6,
            Parent = configPill
        })

        glyphChevron(configPill, -8)

        configPill.MouseEnter:Connect(function()
            TweenService:Create(pillStroke, TweenInfo.new(0.15), {Color = T.BorderHi}):Play()
        end)
        configPill.MouseLeave:Connect(function()
            TweenService:Create(pillStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
        end)

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

        -- Вертикальные поля контента — вдвое меньше боковых: по бокам EDGE,
        -- сверху и снизу EDGE/2. Так область не «висит» в пустоте между
        -- хедером и футером
        local pagesContainer = Create("Frame", {
            Name = "PagesContainer",
            BackgroundTransparency = 1,
            Position = UDim2.new(0, SIDEBAR_W + 1 + EDGE, 0, HEADER_H + EDGE / 2),
            Size = UDim2.new(
                1, -(SIDEBAR_W + 1 + EDGE * 2),
                1, -(HEADER_H + EDGE / 2 + FOOTER_H + EDGE / 2)
            ),
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

        -- Чипа роли в футере больше нет: роль показывает инфо-блок сайдбара,
        -- дублировать её внизу незачем. Пинг переехал влево на его место.
        local pingLabel = Create("TextLabel", {
            Text = "Ping: -- ms",
            Font = FONT.Mono,
            TextSize = TS.Status,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, EDGE, 0, 0),
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

        -- Раз в секунду обновляем пинг и сводку; цикл умирает вместе с gui
        task.spawn(function()
            while gui and gui.Parent do
                pcall(function()
                    local ms = probePingMs()
                    pingLabel.Text = ms and string.format("Ping: %d ms", ms) or "Ping: -- ms"

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
                (sec.holder or sec.frame).Visible = anyVisible
            end
        end

        ----------------------------------------------------------------
        -- ИКОНКИ ВКЛАДОК в стиле Geist Icons: сетка 16x16, штрих 1.5,
        -- геометрия из Frame/UIStroke, без внешних ассетов
        ----------------------------------------------------------------
        local ICON_STROKE = 1.5
        local ICON_SIZE = 20

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
            if tabName:lower() == "auras" then
                local asset = loadAuraIconAsset()
                if asset then data = {Image = asset, Offset = Vector2.zero, Size = Vector2.zero} end
            end
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
            if n == "auras" then
                -- Фолбэк для executor без файлового API: нимб и крылья.
                ring(5, 0, 6, 2.5, 3)
                line(6, 5, 4, 10, 0, 2)
                line(0.5, 7, 7, 2, 45, 1)
                line(8.5, 7, 7, 2, -45, 1)
                line(1, 10, 6, 2, 45, 1)
                line(9, 10, 6, 2, -45, 1)
            elseif n == "world" then
                -- LucideSun.svg: круг и восемь лучей; общий setter задаёт цвет темы.
                ring(4.67, 4.67, 6.66, 6.66, 4)
                line(7.25, 0, 1.5, 2)
                line(7.25, 14, 1.5, 2)
                line(0, 7.25, 2, 1.5)
                line(14, 7.25, 2, 1.5)
                line(1.3, 1.3, 2.5, 1.5, 45, 1)
                line(12.2, 1.3, 2.5, 1.5, -45, 1)
                line(1.3, 13.2, 2.5, 1.5, -45, 1)
                line(12.2, 13.2, 2.5, 1.5, 45, 1)
            elseif n == "main" then
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
        -- ПОПОВЕРЫ: общий оверлей-список и единая строка списка.
        -- Раньше makeOverlayList жил внутри CreateTab; поднят сюда, потому
        -- что панель конфигов живёт на уровне окна, а не вкладки.
        ----------------------------------------------------------------

        -- Выпадающий список поверх mainFrame + закрытие по клику мимо.
        -- opts.headerH > 0 добавляет нескроллируемую шапку над списком
        -- (панель конфигов); без opts поведение прежнее (дропдауны).
        -- Возвращает: overlay (ScrollingFrame со строками), openAt, close,
        -- root (то, что позиционируется и тянется), headerFrame (или nil).
        local function makeOverlayList(anchorBtn, width, opts)
            opts = opts or {}
            local headerH = opts.headerH or 0

            -- Active = true у всех подложек списка: без этого клик по пустому
            -- месту поповера проваливался на контрол под ним (поповер висит
            -- поверх строк вкладки и часто перекрывает поля ввода)
            local root, headerFrame, overlay
            if headerH > 0 then
                root = Create("Frame", {
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, width, 0, 0),
                    Visible = false,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    Active = true,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(root, R_CARD)
                AddStroke(root, STROKE_W, T.Border)

                headerFrame = Create("Frame", {
                    Name = "PanelHeader",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, headerH),
                    Active = true,
                    ZIndex = 1001,
                    Parent = root
                })

                overlay = Create("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, 0, 0, headerH),
                    Size = UDim2.new(1, 0, 1, -headerH),
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = G.Gray500,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    Active = true,
                    ZIndex = 1000,
                    Parent = root
                })
            else
                -- Geist popover: bg background-100, сплошная рамка, радиус 12,
                -- внутренний padding 6 и шаг строк 2 (--ds-popover-*)
                overlay = Create("ScrollingFrame", {
                    BackgroundColor3 = T.Surface1,
                    Position = UDim2.new(0, 0, 0, 0),
                    Size = UDim2.new(0, width, 0, 0),
                    Visible = false,
                    CanvasSize = UDim2.new(0, 0, 0, 0),
                    ScrollBarThickness = 4,
                    ScrollBarImageColor3 = G.Gray500,
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    Active = true,
                    ZIndex = 1000,
                    Parent = mainFrame
                })
                AddCorner(overlay, R_CARD)
                AddStroke(overlay, STROKE_W, T.Border)
                root = overlay
            end

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

            -- Скрытие после твина — через task.delay, а не блокирующий wait:
            -- close() зовут из обработчиков, поток которых может быть
            -- невыдаваемым (тогда wait ронял бы весь обработчик)
            local function close()
                if root.Visible then
                    TweenService:Create(
                        root,
                        TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                        {Size = UDim2.new(0, width, 0, 0)}
                    ):Play()
                    task.delay(0.2, function()
                        if root.Size.Y.Offset <= 0 then
                            root.Visible = false
                        end
                    end)
                end
            end

            local function openAt(targetHeight)
                local absPos = anchorBtn.AbsolutePosition
                local absSize = anchorBtn.AbsoluteSize
                local mainPos = mainFrame.AbsolutePosition
                root.Position = UDim2.new(
                    0, absPos.X - mainPos.X,
                    0, absPos.Y - mainPos.Y + absSize.Y + 5
                )
                root.Size = UDim2.new(0, width, 0, 0)
                root.Visible = true
                TweenService:Create(
                    root,
                    TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0, width, 0, targetHeight)}
                ):Play()
            end

            -- Закрытие по клику вне списка и вне кнопки
            local clickOutsideConnection = UserInputService.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and root.Visible then
                    local mousePos = UserInputService:GetMouseLocation()
                    local framePos = root.AbsolutePosition
                    local frameSize = root.AbsoluteSize
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

            return overlay, openAt, close, root, headerFrame
        end

        -- Единая строка поповера: 36px, радиус 6, hover — gray-200.
        -- opts: height, indent (левый паддинг), danger (красный текст),
        -- dim (приглушённый текст), order (LayoutOrder)
        local function popoverRow(overlay, text, opts)
            opts = opts or {}
            local btn = Create("TextButton", {
                Text = text,
                Font = FONT.Body,
                TextSize = TS.Option,
                TextColor3 = opts.danger and T.Danger or (opts.dim and T.TextDark or T.Text),
                BackgroundColor3 = G.Gray200,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, opts.height or POPOVER_ROW),
                AutoButtonColor = false,
                ZIndex = 1001,
                LayoutOrder = opts.order or 0,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                Parent = overlay
            })
            AddCorner(btn, R_CTRL)
            Create("UIPadding", {
                PaddingLeft = UDim.new(0, opts.indent or 8),
                PaddingRight = UDim.new(0, 8),
                Parent = btn
            })
            btn.MouseEnter:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
            end)
            btn.MouseLeave:Connect(function()
                TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
            end)
            return btn
        end

        ----------------------------------------------------------------
        -- ПАНЕЛЬ КОНФИГОВ: список профилей под пилюлей хедера.
        -- GUI не знает про файлы — все операции идут через менеджер,
        -- переданный хостом в GUI.AttachConfigSystem (контракт: List, Save,
        -- Load, Create, Delete, Rename, Share, SetAutoload, GetAutoload).
        ----------------------------------------------------------------

        local CFG_PANEL_W  = 250
        local CFG_HEADER_H = 40
        local CFG_SUB_H    = 30   -- строка «...»-подменю
        local CFG_MAX_H    = 380

        local configManager = nil
        local activeConfigName = nil
        local cfgExpanded = nil    -- конфиг с раскрытым «...»-меню
        local cfgRenaming = nil    -- конфиг в режиме переименования
        local cfgCreating = false  -- показывать строку ввода нового имени

        local cfgList, cfgOpenAt, cfgClose, cfgPanel, cfgHeader =
            makeOverlayList(configPill, CFG_PANEL_W, {headerH = CFG_HEADER_H})

        -- Шапка панели: подпись + «+» справа, разделитель снизу
        Create("TextLabel", {
            Text = "CONFIGS",
            Font = FONT.Bold,
            TextSize = TS.Chip,
            TextColor3 = T.TextDark,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 0),
            Size = UDim2.new(1, -50, 1, 0),
            ZIndex = 1001,
            Parent = cfgHeader
        })
        local cfgPlusBtn = makeIconButton(cfgHeader, UDim2.new(1, -31, 0.5, -11), 22, "plus")
        Hairline({
            Position = UDim2.new(0, POPOVER_PAD, 1, -1),
            Size = UDim2.new(1, -POPOVER_PAD * 2, 0, 1),
            ZIndex = 1001,
            Parent = cfgHeader
        })

        -- Фидбек конфиг-операций показываем всегда: ShowNotification хоста
        -- гейтится Settings.NotificationsEnabled, на время вызова форсируем флаг
        local function cfgNotify(msg)
            if not ShowNotification then return end
            pcall(function()
                local was = Settings.NotificationsEnabled
                Settings.NotificationsEnabled = true
                ShowNotification(msg)
                Settings.NotificationsEnabled = was
            end)
        end

        -- Тихое чтение (List/GetAutoload): ошибки не показываем
        local function managerGet(op, ...)
            if not configManager then return nil end
            local fn = configManager[op]
            if type(fn) ~= "function" then return nil end
            local ok, res = pcall(fn, ...)
            if ok then return res end
            return nil
        end

        -- Мутации: ошибка менеджера → нотификация
        local function managerCall(op, ...)
            if not configManager then
                cfgNotify("Config system unavailable")
                return false
            end
            local fn = configManager[op]
            if type(fn) ~= "function" then return false end
            local ok, res, err = pcall(fn, ...)
            if not ok then
                cfgNotify("Config error: " .. tostring(res))
                return false
            end
            if res == false then
                cfgNotify(tostring(err or "Config operation failed"))
                return false
            end
            return true
        end

        local rebuildAndResize   -- forward: нужен обработчикам строк

        -- Строка-инпут (создание/переименование). Enter — коммит,
        -- всё остальное — отмена режима
        local function addCfgInputRow(order, initialText, placeholder, onCommit)
            local row = Create("Frame", {
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, POPOVER_ROW),
                ZIndex = 1001,
                LayoutOrder = order,
                Parent = cfgList
            })
            local box = Create("TextBox", {
                Text = initialText or "",
                PlaceholderText = placeholder,
                Font = FONT.Body,
                TextSize = TS.Option,
                TextColor3 = T.Text,
                PlaceholderColor3 = T.TextDark,
                BackgroundColor3 = T.Surface2,
                Position = UDim2.new(0, 2, 0.5, -CTRL_H / 2),
                Size = UDim2.new(1, -4, 0, CTRL_H),
                ClearTextOnFocus = false,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 1002,
                Parent = row
            })
            AddCorner(box, R_CTRL)
            AddStroke(box, STROKE_W, T.BorderHi)
            Create("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = box})

            task.defer(function()
                pcall(function() box:CaptureFocus() end)
            end)

            box.FocusLost:Connect(function(enterPressed)
                local txt = (box.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if enterPressed and txt ~= "" then
                    onCommit(txt)
                else
                    cfgCreating, cfgRenaming = false, nil
                    rebuildAndResize()
                end
            end)
            return row
        end

        -- Обычная строка конфига: имя + save + «...». Активный — акцентом,
        -- автозагрузочный — с точкой слева
        local function addCfgRow(order, name, autoloadName)
            local isActive = (name == activeConfigName)
            local isAuto = (name == autoloadName)

            local row = Create("Frame", {
                Name = "Cfg_" .. name,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, POPOVER_ROW),
                ZIndex = 1001,
                LayoutOrder = order,
                Parent = cfgList
            })

            local fill = Create("TextButton", {
                Text = "",
                BackgroundColor3 = G.Gray200,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                AutoButtonColor = false,
                ZIndex = 1001,
                Parent = row
            })
            AddCorner(fill, R_CTRL)
            fill.MouseEnter:Connect(function()
                TweenService:Create(fill, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
            end)
            fill.MouseLeave:Connect(function()
                TweenService:Create(fill, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
            end)

            if isAuto then
                local dot = Create("Frame", {
                    BackgroundColor3 = T.Accent,
                    BorderSizePixel = 0,
                    Position = UDim2.new(0, 10, 0.5, -3),
                    Size = UDim2.new(0, 6, 0, 6),
                    ZIndex = 1002,
                    Parent = row
                })
                AddCorner(dot, 3)
            end

            local textX = isAuto and 22 or 10
            Create("TextLabel", {
                Text = name,
                Font = isActive and FONT.Bold or FONT.Body,
                TextSize = TS.Option,
                TextColor3 = isActive and T.Accent or T.Text,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
                BackgroundTransparency = 1,
                Position = UDim2.new(0, textX, 0, 0),
                Size = UDim2.new(1, -(textX + 54), 1, 0),
                ZIndex = 1002,
                Parent = row
            })

            local saveBtn = makeIconButton(row, UDim2.new(1, -50, 0.5, -11), 22, "save")
            local dotsBtn = makeIconButton(row, UDim2.new(1, -26, 0.5, -11), 22, "ellipsis")

            -- Клик по имени — загрузка конфига
            fill.MouseButton1Click:Connect(function()
                if managerCall("Load", name) then
                    GUI.SetActiveConfigName(name)
                    cfgClose()
                end
            end)
            saveBtn.MouseButton1Click:Connect(function()
                managerCall("Save", name)
            end)
            dotsBtn.MouseButton1Click:Connect(function()
                cfgExpanded = (cfgExpanded ~= name) and name or nil
                cfgRenaming = nil
                rebuildAndResize()
            end)
        end

        -- Полная пересборка списка. Возвращает целевую высоту панели
        local function rebuildConfigList()
            for _, child in ipairs(cfgList:GetChildren()) do
                if child:IsA("GuiObject") then child:Destroy() end
            end

            local contentH = POPOVER_PAD * 2
            local orderN = 0
            local function nextOrder(h)
                orderN = orderN + 1
                contentH = contentH + h + 2
                return orderN
            end

            if not configManager then
                popoverRow(cfgList, "Config system unavailable",
                    {dim = true, order = nextOrder(POPOVER_ROW)})
            else
                local names = managerGet("List")
                if type(names) ~= "table" then names = {} end
                local autoloadName = managerGet("GetAutoload")

                if cfgCreating then
                    addCfgInputRow(nextOrder(POPOVER_ROW), "", "Config name…", function(txt)
                        cfgCreating = false
                        managerCall("Create", txt)
                        rebuildAndResize()
                    end)
                end

                for _, name in ipairs(names) do
                    if cfgRenaming == name then
                        addCfgInputRow(nextOrder(POPOVER_ROW), name, "New name…", function(txt)
                            cfgRenaming = nil
                            if txt ~= name and managerCall("Rename", name, txt) then
                                if activeConfigName == name then
                                    GUI.SetActiveConfigName(txt)
                                end
                                if cfgExpanded == name then cfgExpanded = txt end
                            end
                            rebuildAndResize()
                        end)
                    else
                        addCfgRow(nextOrder(POPOVER_ROW), name, autoloadName)

                        if cfgExpanded == name then
                            local saveRow = popoverRow(cfgList, "Save current settings",
                                {height = CFG_SUB_H, indent = 26, order = nextOrder(CFG_SUB_H)})
                            saveRow.MouseButton1Click:Connect(function()
                                cfgExpanded = nil
                                managerCall("Save", name)
                                rebuildAndResize()
                            end)

                            local renameRow = popoverRow(cfgList, "Rename",
                                {height = CFG_SUB_H, indent = 26, order = nextOrder(CFG_SUB_H)})
                            renameRow.MouseButton1Click:Connect(function()
                                cfgRenaming = name
                                cfgExpanded = nil
                                rebuildAndResize()
                            end)

                            local shareRow = popoverRow(cfgList, "Share (copy to clipboard)",
                                {height = CFG_SUB_H, indent = 26, order = nextOrder(CFG_SUB_H)})
                            shareRow.MouseButton1Click:Connect(function()
                                managerCall("Share", name)
                            end)

                            local isAuto = (autoloadName == name)
                            local autoRow = popoverRow(cfgList,
                                isAuto and "Autoload: on" or "Autoload: off",
                                {height = CFG_SUB_H, indent = 26, order = nextOrder(CFG_SUB_H)})
                            autoRow.MouseButton1Click:Connect(function()
                                managerCall("SetAutoload", isAuto and nil or name)
                                rebuildAndResize()
                            end)

                            local deleteRow = popoverRow(cfgList, "Delete",
                                {height = CFG_SUB_H, indent = 26, danger = true,
                                 order = nextOrder(CFG_SUB_H)})
                            deleteRow.MouseButton1Click:Connect(function()
                                cfgExpanded = nil
                                if managerCall("Delete", name) then
                                    if activeConfigName == name then
                                        GUI.SetActiveConfigName(nil)
                                    end
                                end
                                rebuildAndResize()
                            end)
                        end
                    end
                end

                if #names == 0 and not cfgCreating then
                    popoverRow(cfgList, "No configs — press +",
                        {dim = true, order = nextOrder(POPOVER_ROW)})
                end
            end

            cfgList.CanvasSize = UDim2.new(0, 0, 0, contentH)
            return math.min(CFG_MAX_H, CFG_HEADER_H + contentH)
        end

        rebuildAndResize = function()
            local h = rebuildConfigList()
            if cfgPanel.Visible then
                TweenService:Create(cfgPanel, TweenInfo.new(0.15, Enum.EasingStyle.Quad),
                    {Size = UDim2.new(0, CFG_PANEL_W, 0, h)}):Play()
            end
        end

        -- Пилюля: клик — открыть/закрыть панель (режимы сбрасываются)
        configPill.MouseButton1Click:Connect(function()
            if cfgPanel.Visible then
                cfgClose()
            elseif not configManager then
                cfgNotify("Config system unavailable")
            else
                cfgExpanded, cfgRenaming, cfgCreating = nil, nil, false
                cfgOpenAt(rebuildConfigList())
            end
        end)

        -- Быстрое сохранение в текущий конфиг
        pillSaveBtn.MouseButton1Click:Connect(function()
            if not activeConfigName then
                cfgNotify("No config selected")
                return
            end
            managerCall("Save", activeConfigName)
        end)

        -- «+»: строка ввода имени нового конфига
        cfgPlusBtn.MouseButton1Click:Connect(function()
            cfgCreating = true
            cfgExpanded, cfgRenaming = nil, nil
            rebuildAndResize()
        end)

        -- Публичный API конфиг-системы
        function GUI.SetActiveConfigName(name)
            activeConfigName = name
            pillName.Text = name or "no config"
            pillName.TextColor3 = name and T.Text or T.TextDark
        end

        function GUI.AttachConfigSystem(manager)
            configManager = manager
            rebuildAndResize()
        end

        ----------------------------------------------------------------
        -- ВНУТРЕННИЙ КОНСТРУКТОР ТАБА + TabFunctions
        ----------------------------------------------------------------

        local function CreateTab(name)
            local tabBtn = Create("TextButton", {
                Text = "",
                BackgroundColor3 = G.Gray200,
                BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, NAV_H),
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
                -- Группа = заголовок НАД карточкой + сама карточка. Раньше
                -- заголовок лежал внутри рамки и читался как первая строка
                -- списка; вынесенный наружу он работает как подпись к блоку
                local holder = Create("Frame", {
                    Name = (title or "Section") .. "Group",
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 0),
                    AutomaticSize = Enum.AutomaticSize.Y,
                    Parent = currentPage
                })
                Create("UIListLayout", {
                    Padding = UDim.new(0, TITLE_GAP),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = holder
                })

                if title and title ~= "" then
                    local head = Create("TextLabel", {
                        Name = "GroupTitle",
                        Text = title,
                        Font = FONT.Bold,
                        TextSize = TS.Section,
                        TextColor3 = T.TextDark,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Bottom,
                        BackgroundTransparency = 1,
                        Size = UDim2.new(1, 0, 0, 20),
                        LayoutOrder = 1,
                        Parent = holder
                    })
                    Create("UIPadding", {PaddingLeft = UDim.new(0, 2), Parent = head})
                end

                local sec = Create("Frame", {
                    Name = (title or "Section") .. "Card",
                    BackgroundColor3 = T.Surface1,
                    BackgroundTransparency = CARD_TRANSPARENCY,
                    Size = UDim2.new(1, 0, 0, 0),
                    ClipsDescendants = true,
                    BorderSizePixel = 0,
                    LayoutOrder = 2,
                    Parent = holder
                })
                AddCorner(sec, R_CARD)
                AddStroke(sec, STROKE_W, T.Border)

                local layout = Create("UIListLayout", {
                    Padding = UDim.new(0, 0),
                    SortOrder = Enum.SortOrder.LayoutOrder,
                    Parent = sec
                })
                -- Высота ровно по содержимому: пустая полоса под последней
                -- строкой не нужна, воздух уже заложен внутрь самих строк
                layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                    sec.Size = UDim2.new(1, 0, 0, layout.AbsoluteContentSize.Y)
                end)

                local data = {frame = sec, holder = holder, layout = layout, rows = {}, order = 1}
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
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, height),
                    LayoutOrder = data.order,
                    Parent = data.frame
                })

                -- Подсветку рисует не сама строка, а вложенная скруглённая
                -- подложка с отступом от краёв. Прямоугольник во всю ширину
                -- перекрывал скругления карточки — верхняя и нижняя строки
                -- «квадратили» ей углы. Создаётся первой, поэтому лежит под
                -- текстом и контролами.
                local fill = Create("Frame", {
                    Name = "Fill",
                    BackgroundColor3 = G.Gray100,
                    BackgroundTransparency = 1,
                    Position = UDim2.new(0, ROW_INSET_X, 0, ROW_INSET_Y),
                    Size = UDim2.new(1, -ROW_INSET_X * 2, 1, -ROW_INSET_Y * 2),
                    BorderSizePixel = 0,
                    Parent = row
                })
                AddCorner(fill, R_CTRL)

                row.MouseEnter:Connect(function()
                    TweenService:Create(fill, TweenInfo.new(0.12), {BackgroundTransparency = ROW_HOVER_ALPHA}):Play()
                end)
                row.MouseLeave:Connect(function()
                    TweenService:Create(fill, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
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
                local bound = Settings.Keybinds and Settings.Keybinds[keybindKey]
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
                registerKeybind(keybindKey, chip, "—")

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

                -- Элемент-объект: Value всегда актуален, Set — единственный
                -- путь изменения (клик, загрузка конфига)
                local element = {
                    __type = "Toggle",
                    Value = default and true or false,
                    Instance = toggleBg,
                }

                function element:Set(value, fire)
                    self.Value = value and true or false
                    local targetColor = self.Value and T.Accent or T.TrackBg
                    local targetPos = UDim2.new(0, self.Value and KNOB_ON or KNOB_OFF, 0.5, -KNOB / 2)

                    TweenService:Create(toggleBg, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
                    TweenService:Create(toggleCircle, TweenInfo.new(0.15), {Position = targetPos}):Play()

                    if fire then
                        callHandler(handlerKey, self.Value)
                    end
                end

                registerElement(handlerKey, element)

                -- Сразу вызываем handler с начальным значением, чтобы State
                -- был синхронизирован с GUI
                if default then
                    task.spawn(function()
                        callHandler(handlerKey, default)
                    end)
                end

                TrackConnection(toggleBg.MouseButton1Click:Connect(function()
                    element:Set(not element.Value, true)
                end))

                return element
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

                -- Элемент-объект. Значение вне options просто ставится текстом:
                -- конфиг из другой версии не должен ронять загрузку
                local element = {
                    __type = "Dropdown",
                    Value = default,
                    Options = options,
                    Instance = dropdown,
                }

                function element:Set(option, fire)
                    self.Value = tostring(option)
                    dropdown.Text = self.Value
                    if fire then
                        callHandler(handlerKey, self.Value)
                    end
                end

                registerElement(handlerKey, element)

                -- строки поповера — единая фабрика popoverRow
                for _, option in ipairs(options) do
                    local optionBtn = popoverRow(overlay, option)
                    optionBtn.MouseButton1Click:Connect(function()
                        element:Set(option, true)
                        close()
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

                return element
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

                -- Элемент-объект. Нечисловое значение игнорируется
                local element = {
                    __type = "Input",
                    Value = tonumber(defaultValue),
                    Instance = inputBox,
                }

                function element:Set(v, fire)
                    local num = tonumber(v)
                    if not num then return end
                    self.Value = num
                    inputBox.Text = tostring(num)
                    if fire then
                        callHandler(handlerKey, num)
                    end
                end

                registerElement(handlerKey, element)

                inputBox.FocusLost:Connect(function()
                    TweenService:Create(inputStroke, TweenInfo.new(0.15), {Color = T.Border}):Play()
                    local value = tonumber(inputBox.Text)
                    if value then
                        element:Set(value, true)
                    else
                        inputBox.Text = tostring(element.Value)
                    end
                end)

                return element
            end

            function TabFunctions:CreateSlider(title, description, min, max, default, handlerKey, step)
                step = step or 1
                local hasDesc = description ~= nil and description ~= ""
                local row = addRow(hasDesc and ROW_H_DESC or ROW_H, title, description or "")
                addRowText(row, title, description, 200)

                -- Точность берём из шага: 1 → «22», 0.5 → «22.5», 0.05 → «0.85».
                -- Раньше было жёстко «%d» либо «%.2f», из-за чего дробный шаг
                -- всегда рисовал два знака, а дробное значение при шаге >= 1
                -- уходило в «%d» — в Lua 5.4 это вообще ошибка, в Luau молча
                -- обрезает. Формат ниже — «%.Nf», он безопасен для любых чисел
                local decimals = 0
                do
                    local frac = tostring(step):match("%.(%d+)")
                    if frac then
                        frac = frac:gsub("0+$", "")   -- «10.0» — это всё-таки целый шаг
                        decimals = math.min(#frac, 3)
                    end
                end
                local fmtSpec = "%." .. decimals .. "f"
                local roundFactor = 10 ^ decimals

                local function fmt(v)
                    return string.format(fmtSpec, v)
                end

                -- Квантование по шагу даёт мусор в младших разрядах
                -- (17 * 0.05 = 0.8500000000000001), поэтому дожимаем до
                -- точности шага — иначе этот мусор уедет в State и в конфиг
                local function quantize(v)
                    v = math.floor(v / step + 0.5) * step
                    return math.floor(v * roundFactor + 0.5) / roundFactor
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

                local element = {
                    __type = "Slider",
                    Value = default,
                    Min = min,
                    Max = max,
                    Step = step,
                    Instance = sliderBg,
                }

                function element:Set(value, fire)
                    value = tonumber(value)
                    if not value then return end
                    value = math.clamp(quantize(value), min, max)
                    currentValue = value
                    self.Value = value

                    local normalizedValue = (value - min) / (max - min)
                    sliderFill.Size = UDim2.new(normalizedValue, 0, 1, 0)
                    sliderButton.Position = UDim2.new(normalizedValue, -7, 0.5, -7)
                    valueBox.Text = fmt(value)

                    if fire then
                        callHandler(handlerKey, value)
                    end
                end

                -- локальный алиас для внутренних обработчиков ниже
                local function applyValue(value, fire)
                    element:Set(value, fire)
                end

                registerElement(handlerKey, element)

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

                return element
            end

            function TabFunctions:CreateKeybindButton(title, emoteId, keybindKey)
                local row = addRow(ROW_H, title, "")
                addRowText(row, title, nil, 136)

                -- Geist secondary button
                local bound = Settings.Keybinds and Settings.Keybinds[keybindKey]
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
                local element = registerKeybind(keybindKey, bindButton, "Not Bound")

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

                return element
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

                    -- строки — единая фабрика popoverRow; в реестр конфигов
                    -- этот список не попадает (stateKey, а не handlerKey)
                    for _, playerName in ipairs(players) do
                        local pb = popoverRow(overlay, playerName)
                        pb.MouseButton1Click:Connect(function()
                            State[stateKey] = playerName
                            -- длинные ники режет TextTruncate, вручную не обрезаем
                            dropdown.Text = playerName
                            close()
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

                -- Текст на кнопках всегда белый, поэтому и заливка везде
                -- достаточно тёмная/насыщенная. Прежний primary был светло-серым
                -- (gray-1000) с тёмным шрифтом — из-за него подписи и различались
                -- по цвету; теперь это тёмная кнопка с рамкой (Geist secondary).
                --   default (color = nil)  — тёмная заливка + рамка
                --   error   (color = Red)  — заливка red-800
                --   custom  (свой цвет)    — заливка переданным цветом
                local isDanger = color == CONFIG.Colors.Red
                local isDefault = color == nil
                local baseColor = isDanger and T.DangerBg or (isDefault and T.Surface1 or color)
                local hoverColor
                if isDefault then
                    hoverColor = G.Gray200
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
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundColor3 = baseColor,
                    -- 12 + 20 + 6 + 32 + 12 = 82 при заголовке; иначе строго по центру
                    Position = hasTitle and UDim2.new(0, EDGE, 0, 38) or UDim2.new(0, EDGE, 0.5, -CTRL_H / 2),
                    Size = UDim2.new(1, -EDGE * 2, 0, CTRL_H),
                    AutoButtonColor = false,
                    Parent = row
                })
                AddCorner(button, R_CTRL)
                if isDefault then
                    AddStroke(button, STROKE_W, T.Border)
                end

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
        -- Эффекты живут в Lighting и в дереве камеры, сами вместе с ScreenGui
        -- они не уберутся: стекло надо снять и вернуть чужие DepthOfField
        if State.UIElements.Acrylic then
            pcall(function()
                State.UIElements.Acrylic.Destroy()
            end)
            State.UIElements.Acrylic = nil
        end
        if State.UIElements.Blur then
            pcall(function()
                State.UIElements.Blur:Destroy()
            end)
            State.UIElements.Blur = nil
        end
    end

    return GUI
end
