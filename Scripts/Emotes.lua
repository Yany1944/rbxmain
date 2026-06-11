--Made by Zyrovell Roblox:Oyuncu15q Discord:_ege.
-- V4.3 Better UI
-- OPEN SOURCE FOREVER!

--[[



$$\    $$\ $$$$$$$$\ $$\   $$\ $$$$$$$\   $$$$$$\         $$$$$$\  $$\   $$\       $$$$$$$$\  $$$$$$\  $$$$$$$\        $$\ 
$$ |   $$ |$$  _____|$$ |  $$ |$$  __$$\ $$  __$$\       $$  __$$\ $$$\  $$ |      \__$$  __|$$  __$$\ $$  __$$\       $$ |
$$ |   $$ |$$ |      \$$\ $$  |$$ |  $$ |$$ /  $$ |      $$ /  $$ |$$$$\ $$ |         $$ |   $$ /  $$ |$$ |  $$ |      $$ |
\$$\  $$  |$$$$$\     \$$$$  / $$$$$$$  |$$ |  $$ |      $$ |  $$ |$$ $$\$$ |         $$ |   $$ |  $$ |$$$$$$$  |      $$ |
 \$$\$$  / $$  __|    $$  $$<  $$  __$$< $$ |  $$ |      $$ |  $$ |$$ \$$$$ |         $$ |   $$ |  $$ |$$  ____/       \__|
  \$$$  /  $$ |      $$  /\$$\ $$ |  $$ |$$ |  $$ |      $$ |  $$ |$$ |\$$$ |         $$ |   $$ |  $$ |$$ |                
   \$  /   $$$$$$$$\ $$ /  $$ |$$ |  $$ | $$$$$$  |       $$$$$$  |$$ | \$$ |         $$ |    $$$$$$  |$$ |            $$\ 
    \_/    \________|\__|  \__|\__|  \__| \______/        \______/ \__|  \__|         \__|    \______/ \__|            \__|
                                                                                                                           
                                                                                                                           
                                                                                                                           
]]

-- Önceki instance temizle (re-run desteği)
pcall(function()
	local b = game:GetService("Lighting"):FindFirstChild("VexroGlassBlur")
	if b then b:Destroy() end
end)
local _genv = (type(getgenv) == "function") and getgenv or function() return {} end
if _genv().VexroEmotesCleanup then
	pcall(_genv().VexroEmotesCleanup)
	_genv().VexroEmotesCleanup = nil
end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui", 10)
if not playerGui then return end

local old = playerGui:FindFirstChild("VexroEmotes")
if old then old:Destroy() end

-- ===============================================================
-- DATA SYSTEM
-- ===============================================================

local DATA_FILE = "VexroEmotes_Data.json"
local Settings = {theme = "Dark", speed = 1, notifications = true, loopEmote = true, language = nil, copyEmoteEnabled = false, stopOnWalk = true, showHUD = true}

local FriendData = {
	friends        = {},   -- [userId:string] = {name, syncEnabled}
	autoReject     = false,
	acceptRequests = true,
	playFriendEmote = true,
	syncEmote      = true,
	addModeActive  = false,
	currentSyncPartner = nil,
}
local _friendConns = {}
local RefreshFriendList  -- forward declaration
local ShowFriendRequestPanel  -- forward declaration
local Favorites = {}
local Keybinds = {}
local RecentEmotes = {}
-- Bridge: _VexroExtend içindeki HUD fonksiyonlarını dış kapsama bağlar
local _onSpeedChanged  -- function(); HUD hız butonlarını + info panel'i günceller
local _onPauseStateChanged  -- function(isPaused); HUD duraklat butonunu günceller
local MAX_RECENT = 20

local _savePending = false
local function SaveData()
	if _savePending then return end
	_savePending = true
	task.delay(0.25, function()
		_savePending = false
		pcall(function()
			if writefile then
				writefile(DATA_FILE, HttpService:JSONEncode({
					favorites = Favorites,
					recent = RecentEmotes,
					settings = Settings,
					keybinds = Keybinds
				}))
			end
		end)
	end)
end

local function LoadData()
	pcall(function()
		if readfile and isfile and isfile(DATA_FILE) then
			local data = HttpService:JSONDecode(readfile(DATA_FILE))
			if data then
				-- FIX: ID
				Favorites = {}
				if data.favorites then
					for _, v in pairs(data.favorites) do
						table.insert(Favorites, tonumber(v)) 
					end
				end
				
				RecentEmotes = {}
				if data.recent then
					for _, v in pairs(data.recent) do
						table.insert(RecentEmotes, tonumber(v))
					end
				end

				if data.settings then
					Settings.theme = data.settings.theme or "Dark"
					Settings.speed = data.settings.speed or 1
					Settings.notifications = data.settings.notifications ~= false
					Settings.loopEmote = data.settings.loopEmote ~= false
					Settings.language = data.settings.language or nil
					-- copyEmoteEnabled intentionally NOT loaded — always starts off
					Settings.stopOnWalk = data.settings.stopOnWalk ~= false
					Settings.showHUD = data.settings.showHUD ~= false
				end

				Keybinds = {}
				if data.keybinds then
					for k, v in pairs(data.keybinds) do
						Keybinds[tonumber(k)] = v  -- {name="...", key="E"}
					end
				end
			end
		end
	end)
end

LoadData()

-- Hash set for O(1) favorite lookups
local FavoritesSet = {}
for _, v in ipairs(Favorites) do FavoritesSet[v] = true end

-- Keybind lookup table
local KeybindsSet = {}
for k, v in pairs(Keybinds) do KeybindsSet[tonumber(k)] = v end
local function GetKeybind(emoteId) return KeybindsSet[emoteId] end
local function SetKeybind(emoteId, name, keyStr)
	KeybindsSet[emoteId] = {name = name, key = keyStr}
	Keybinds[emoteId] = {name = name, key = keyStr}
	SaveData()
end
local function RemoveKeybind(emoteId)
	KeybindsSet[emoteId] = nil
	Keybinds[emoteId] = nil
	SaveData()
end

-- Lookup table for O(1) emote-by-ID access (populated after emotes load)
local EmotesById = {}

-- Cache for async-fetched Roblox catalog metadata (keyed by numeric asset ID)
local _emoteMetaCache = {}

-- ===============================================================
-- UTILITIES
-- ===============================================================

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

-- Auto Image/Decal resolver with cache
local _resolvedCache = {}
local function ResolveAssetImage(assetIdOrUrl)
	if not assetIdOrUrl then return "" end
	local str = tostring(assetIdOrUrl)
	local rawId = str:gsub("rbxassetid://", ""):gsub("[^%d]", "")
	if rawId == "" then return str end
	if _resolvedCache[rawId] then return _resolvedCache[rawId] end
	local resolved = nil
	pcall(function()
		local objects = game:GetObjects("rbxassetid://" .. rawId)
		if objects and #objects > 0 then
			local obj = objects[1]
			if obj:IsA("Decal") or obj:IsA("Texture") then
				resolved = obj.Texture
			elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				resolved = obj.Image
			end
		end
	end)
	if not resolved or resolved == "" then
		resolved = "rbxthumb://type=Asset&id=" .. rawId .. "&w=420&h=420"
	end
	_resolvedCache[rawId] = resolved
	return resolved
end

local logo = [[

                                                                                  
                                                                               ▄▄ 
██  ██ ██████ ██  ██ █████▄  ▄████▄   ▄████▄ ███  ██   ██████ ▄████▄ █████▄    ██ 
██▄▄██ ██▄▄    ████  ██▄▄██▄ ██  ██   ██  ██ ██ ▀▄██     ██   ██  ██ ██▄▄█▀    ██ 
 ▀██▀  ██▄▄▄▄ ██  ██ ██   ██ ▀████▀   ▀████▀ ██   ██     ██   ▀████▀ ██        ▄▄ 
                                                                                                                                                                                                            
]]

print(logo)

-- ===============================================================
-- THEMES
-- ===============================================================

local Themes = {
	-- Kontrast yapısı: primary(dip) → sidebar(+4) → secondary(+8) → tertiary(+12)
	-- Her tema kendi renk kişiliğiyle aynı mantığı izler.

	Dark = {
		primary     = Color3.fromRGB(0,  0,  0 ),   -- #000000  AMOLED siyah
		sidebar     = Color3.fromRGB(0,  0,  0 ),   -- #000000  AMOLED siyah
		secondary   = Color3.fromRGB(0,  0,  0 ),   -- #000000  AMOLED siyah
		tertiary    = Color3.fromRGB(22, 22, 22),   -- #161616  butonlar için koyu gri
		accent      = Color3.fromRGB(200, 200, 200), -- #C8C8C8  aktif sekme vurgusu
		text        = Color3.fromRGB(255, 255, 255), -- #FFFFFF  ana yazı
		textDim     = Color3.fromRGB(140, 140, 140), -- #8C8C8C  pasif yazı
		stroke      = Color3.fromRGB(22, 22, 22),   -- #161616  kenarlık / bölücü
		strokeHover = Color3.fromRGB(65, 65, 65),   -- #414141  kart hover kenarlık
		critical    = Color3.fromRGB(196, 30, 30),   -- #C41E1E  kapat butonu
		success     = Color3.fromRGB(80, 200, 100)
	},
	Purple = {
		primary     = Color3.fromRGB(10, 6, 18),
		sidebar     = Color3.fromRGB(14, 9, 24),
		secondary   = Color3.fromRGB(20, 13, 34),
		tertiary    = Color3.fromRGB(28, 18, 48),
		accent      = Color3.fromRGB(138, 43, 226),
		text        = Color3.fromRGB(255, 255, 255),
		textDim     = Color3.fromRGB(180, 155, 220),
		stroke      = Color3.fromRGB(55, 22, 90),
		strokeHover = Color3.fromRGB(110, 45, 190),
		critical    = Color3.fromRGB(255, 60, 100),
		success     = Color3.fromRGB(100, 240, 120)
	},
	Blue = {
		primary     = Color3.fromRGB(8, 11, 20),
		sidebar     = Color3.fromRGB(11, 15, 27),
		secondary   = Color3.fromRGB(16, 21, 36),
		tertiary    = Color3.fromRGB(22, 30, 50),
		accent      = Color3.fromRGB(0, 160, 255),
		text        = Color3.fromRGB(255, 255, 255),
		textDim     = Color3.fromRGB(150, 180, 220),
		stroke      = Color3.fromRGB(28, 55, 110),
		strokeHover = Color3.fromRGB(60, 130, 220),
		critical    = Color3.fromRGB(250, 60, 80),
		success     = Color3.fromRGB(60, 230, 140)
	},
	Green = {
		primary     = Color3.fromRGB(8, 14, 10),
		sidebar     = Color3.fromRGB(11, 18, 13),
		secondary   = Color3.fromRGB(14, 24, 17),
		tertiary    = Color3.fromRGB(20, 34, 24),
		accent      = Color3.fromRGB(0, 220, 110),
		text        = Color3.fromRGB(255, 255, 255),
		textDim     = Color3.fromRGB(150, 215, 170),
		stroke      = Color3.fromRGB(22, 80, 40),
		strokeHover = Color3.fromRGB(40, 180, 80),
		critical    = Color3.fromRGB(240, 80, 80),
		success     = Color3.fromRGB(120, 255, 120)
	},
	Red = {
		primary     = Color3.fromRGB(18, 7, 8),
		sidebar     = Color3.fromRGB(22, 9, 11),
		secondary   = Color3.fromRGB(28, 12, 14),
		tertiary    = Color3.fromRGB(38, 17, 20),
		accent      = Color3.fromRGB(255, 60, 80),
		text        = Color3.fromRGB(255, 255, 255),
		textDim     = Color3.fromRGB(220, 155, 165),
		stroke      = Color3.fromRGB(100, 28, 36),
		strokeHover = Color3.fromRGB(200, 55, 75),
		critical    = Color3.fromRGB(255, 30, 30),
		success     = Color3.fromRGB(80, 240, 100)
	},
	Light = {
		primary     = Color3.fromRGB(238, 238, 244),
		sidebar     = Color3.fromRGB(230, 230, 238),
		secondary   = Color3.fromRGB(248, 248, 252),
		tertiary    = Color3.fromRGB(255, 255, 255),
		accent      = Color3.fromRGB(75, 80, 105),
		text        = Color3.fromRGB(24, 24, 30),
		textDim     = Color3.fromRGB(115, 115, 128),
		stroke      = Color3.fromRGB(196, 196, 210),
		strokeHover = Color3.fromRGB(130, 130, 150),
		critical    = Color3.fromRGB(220, 50, 50),
		success     = Color3.fromRGB(50, 175, 75)
	},
	MaterialYou = {
		primary     = Color3.fromRGB(16, 18, 26),
		sidebar     = Color3.fromRGB(20, 22, 32),
		secondary   = Color3.fromRGB(24, 27, 38),
		tertiary    = Color3.fromRGB(32, 36, 52),
		accent      = Color3.fromRGB(130, 177, 255),
		text        = Color3.fromRGB(225, 228, 240),
		textDim     = Color3.fromRGB(138, 143, 163),
		stroke      = Color3.fromRGB(45, 52, 78),
		strokeHover = Color3.fromRGB(100, 130, 200),
		critical    = Color3.fromRGB(255, 130, 120),
		success     = Color3.fromRGB(120, 210, 160)
	},
	FrostedGlass = {
		primary     = Color3.fromRGB(198, 208, 228),
		sidebar     = Color3.fromRGB(188, 200, 222),
		secondary   = Color3.fromRGB(212, 222, 240),
		tertiary    = Color3.fromRGB(224, 232, 248),
		accent      = Color3.fromRGB(75, 125, 215),
		text        = Color3.fromRGB(18, 22, 38),
		textDim     = Color3.fromRGB(85, 96, 126),
		stroke      = Color3.fromRGB(155, 175, 212),
		strokeHover = Color3.fromRGB(110, 150, 218),
		critical    = Color3.fromRGB(210, 45, 55),
		success     = Color3.fromRGB(35, 175, 95)
	},
	DarkGlass = {
		primary     = Color3.fromRGB(13, 13, 17),
		sidebar     = Color3.fromRGB(17, 17, 22),
		secondary   = Color3.fromRGB(22, 22, 28),
		tertiary    = Color3.fromRGB(28, 28, 36),
		accent      = Color3.fromRGB(175, 196, 255),
		text        = Color3.fromRGB(228, 233, 255),
		textDim     = Color3.fromRGB(128, 138, 168),
		stroke      = Color3.fromRGB(52, 56, 88),
		strokeHover = Color3.fromRGB(118, 138, 220),
		critical    = Color3.fromRGB(255, 75, 85),
		success     = Color3.fromRGB(75, 218, 128)
	}
}

local currentTheme = Themes[Settings.theme] or Themes.Dark
local themeElements = {}
local mainStrokeGrad, miniIconGrad -- Forward declaration for the theme system
local UpdateTabStyles
local UpdateTabData
local _updateTitleGrad  -- forward declared; assigned after title label is created

local function RegisterTheme(el, prop, key)
	if el then themeElements[#themeElements + 1] = {el = el, prop = prop, key = key} end
end

local function Notify(title, text, iconId)
	if not Settings.notifications then return end
	pcall(function()
		local screenGui = playerGui:FindFirstChild("VexroEmotes") or game:GetService("CoreGui"):FindFirstChild("VexroEmotes")
		if not screenGui then
			game:GetService("StarterGui"):SetCore("SendNotification", {Title = title, Text = text, Duration = 3})
			return
		end
		
		local container = screenGui:FindFirstChild("NotificationContainer")
		if not container then
			container = Instance.new("Frame")
			container.Name = "NotificationContainer"
			container.Size = UDim2.new(0, 300, 1, -40)
			container.Position = UDim2.new(0.5, -150, 0, 20)
			container.BackgroundTransparency = 1
			container.ZIndex = 30000
			container.Parent = screenGui
			
			local uiList = Instance.new("UIListLayout")
			uiList.Padding = UDim.new(0, 10)
			uiList.HorizontalAlignment = Enum.HorizontalAlignment.Center
			uiList.VerticalAlignment = Enum.VerticalAlignment.Top
			uiList.Parent = container
		end
		
		local theme = currentTheme or Themes.Dark
		
		-- Wrapper for animation compatibility with UIListLayout
		local wrapper = Instance.new("Frame")
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 0, 60)
		wrapper.ClipsDescendants = true
		wrapper.Parent = container
		
		local toast = Instance.new("Frame")
		toast.Size = UDim2.new(1, 0, 1, 0)
		toast.Position = UDim2.new(0, 0, -1, -20)
		toast.BackgroundColor3 = theme.secondary
		toast.ZIndex = 30001
		toast.Parent = wrapper
		Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 10)
		
		local toastStroke = Instance.new("UIStroke")
		toastStroke.Color = theme.stroke
		toastStroke.Thickness = 2
		toastStroke.Parent = toast
		
		local iconOffset = 0
		if iconId then
			local notifIcon = Instance.new("ImageLabel")
			notifIcon.Size = UDim2.new(0, 22, 0, 22)
			notifIcon.AnchorPoint = Vector2.new(0, 0.5)
			notifIcon.Position = UDim2.new(0, 10, 0, 16)
			notifIcon.BackgroundTransparency = 1
			notifIcon.Image = ResolveAssetImage("rbxassetid://" .. tostring(iconId))
			notifIcon.ZIndex = 30003
			notifIcon.Parent = toast
			iconOffset = 28
		end

		local titleLbl = Instance.new("TextLabel")
		titleLbl.Size = UDim2.new(1, -(15 + iconOffset), 0, 25)
		titleLbl.Position = UDim2.new(0, 10 + iconOffset, 0, 5)
		titleLbl.BackgroundTransparency = 1
		titleLbl.Text = title
		titleLbl.Font = Enum.Font.GothamBold
		titleLbl.TextSize = 15
		titleLbl.TextColor3 = theme.text
		titleLbl.TextXAlignment = Enum.TextXAlignment.Left
		titleLbl.ZIndex = 30002
		titleLbl.Parent = toast
		
		local textLbl = Instance.new("TextLabel")
		textLbl.Size = UDim2.new(1, -15, 0, 25)
		textLbl.Position = UDim2.new(0, 10, 0, 30)
		textLbl.BackgroundTransparency = 1
		textLbl.Text = text
		textLbl.Font = Enum.Font.Gotham
		textLbl.TextSize = 13
		textLbl.TextColor3 = theme.textDim
		textLbl.TextXAlignment = Enum.TextXAlignment.Left
		textLbl.TextWrapped = true
		textLbl.ZIndex = 30002
		textLbl.Parent = toast
		
		-- Tween inside wrapper
		TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = UDim2.new(0, 0, 0, 0)}):Play()
		
		task.delay(3, function()
			local outTween = TweenService:Create(toast, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Position = UDim2.new(0, 0, -1, -20)})
			outTween:Play()
			task.wait(0.4)
			wrapper:Destroy()
		end)
	end)
end

local function ApplyTheme(name)
	currentTheme = Themes[name] or Themes.Dark
	-- Clean up destroyed elements and apply theme
	local alive = {}
	for i = 1, #themeElements do
		local t = themeElements[i]
		if t.el and t.el.Parent then
			alive[#alive + 1] = t
			if currentTheme[t.key] then
				pcall(function()
					TweenService:Create(t.el, TweenInfo.new(0.3), {[t.prop] = currentTheme[t.key]}):Play()
				end)
			end
		end
	end
	themeElements = alive
	
	if mainStrokeGrad then
		mainStrokeGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, currentTheme.stroke),
			ColorSequenceKeypoint.new(0.33, currentTheme.accent),
			ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
			ColorSequenceKeypoint.new(1, currentTheme.accent)
		}
	end
	
	if miniIconGrad then
		miniIconGrad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, currentTheme.stroke),
			ColorSequenceKeypoint.new(0.33, currentTheme.accent),
			ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
			ColorSequenceKeypoint.new(1, currentTheme.accent)
		}
	end

	if _updateTitleGrad then pcall(_updateTitleGrad) end
	if UpdateTabStyles then UpdateTabStyles() end
end

-- ===============================================================
-- GUI
-- ===============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "VexroEmotes"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.Parent = playerGui

-- ===============================================================
-- LANGUAGE SELECTION
-- ===============================================================

local selectedLang = nil
local rememberLang = false

-- Kayıtlı dil varsa direkt kullan, dil ekranını atla
if Settings.language and Settings.language ~= "" then
	selectedLang = Settings.language
end

if not selectedLang then

-- Dil ekranı her zaman kaydedilmiş temayı kullanır; tema yoksa Dark varsayılan
local langTheme = Themes[Settings.theme] or Themes.Dark
-- Eğer kaydedilmiş tema yoksa (ilk kez) veya tema Dark ise, Dark'ı zorla
if not Settings.theme or Settings.theme == "" then langTheme = Themes.Dark end

local langScreen = Instance.new("Frame")
langScreen.Size = UDim2.fromScale(1, 1)
langScreen.BackgroundColor3 = langTheme.primary
langScreen.ZIndex = 20000
langScreen.Parent = gui

for i = 1, 15 do
	local particle = Instance.new("Frame")
	local s = math.random(3, 8)
	particle.Size = UDim2.new(0, s, 0, s)
	particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
	particle.BackgroundColor3 = langTheme.accent
	particle.BackgroundTransparency = math.random(5, 8) / 10
	particle.ZIndex = 20000
	particle.Parent = langScreen
	Instance.new("UICorner", particle).CornerRadius = UDim.new(1, 0)
	
	task.spawn(function()
		while particle.Parent do
			TweenService:Create(particle, TweenInfo.new(math.random(3, 6), Enum.EasingStyle.Sine), {
				Position = UDim2.new(math.random(), 0, math.random(), 0)
			}):Play()
			task.wait(math.random(3, 6))
		end
	end)
end

local langBox = Instance.new("Frame")
langBox.Size = UDim2.new(0, 0, 0, 0)
langBox.Position = UDim2.fromScale(0.5, 0.5)
langBox.AnchorPoint = Vector2.new(0.5, 0.5)
langBox.BackgroundColor3 = langTheme.secondary
langBox.ZIndex = 20001
langBox.Rotation = -15
langBox.Parent = langScreen
Instance.new("UICorner", langBox).CornerRadius = UDim.new(0, 20)

local langBoxStroke = Instance.new("UIStroke")
langBoxStroke.Color = langTheme.stroke
langBoxStroke.Thickness = 2
langBoxStroke.Parent = langBox

local langStrokeGrad = Instance.new("UIGradient")
langStrokeGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, langTheme.accent),
	ColorSequenceKeypoint.new(0.5, langTheme.stroke),
	ColorSequenceKeypoint.new(1, langTheme.accent)
}
langStrokeGrad.Parent = langBoxStroke

task.spawn(function()
	local rot = 0
	while langBoxStroke.Parent do
		rot = rot + 360
		TweenService:Create(langStrokeGrad, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = rot}):Play()
		task.wait(2)
	end
end)

local langTitle = Instance.new("TextLabel")
langTitle.Size = UDim2.new(1, 0, 0, 45)
langTitle.Position = UDim2.new(0, 0, 0, 20)
langTitle.BackgroundTransparency = 1
langTitle.Text = "🌐 Select Language"
langTitle.TextColor3 = Color3.new(1, 1, 1)
langTitle.Font = Enum.Font.GothamBold
langTitle.TextScaled = true
langTitle.ZIndex = 20002
langTitle.Parent = langBox

local function MakeLangBtn(txt, index, lang)
	local col = index <= 4 and 0 or 1
	local row = (index - 1) % 4
	local x = col == 0 and 0.04 or 0.52
	local y = 80 + (row * 65)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.44, 0, 0, 55)
	btn.Position = UDim2.new(x, 0, 0, y)
	btn.BackgroundColor3 = langTheme.tertiary
	btn.Text = txt
	btn.TextColor3 = langTheme.text
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = isMobile and 14 or 16
	btn.ZIndex = 20003
	btn.Parent = langBox
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = langTheme.stroke
	btnStroke.Transparency = 0.5
	btnStroke.Parent = btn
	
	local shine = Instance.new("Frame")
	shine.Size = UDim2.new(0, 0, 1, 0)
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BackgroundTransparency = 0.9
	shine.ZIndex = 20004
	shine.Parent = btn
	Instance.new("UICorner", shine).CornerRadius = UDim.new(0, 12)
	
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = langTheme.accent}):Play()
		TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0, Color = langTheme.accent}):Play()
		TweenService:Create(shine, TweenInfo.new(0.3), {Size = UDim2.new(1, 0, 1, 0)}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = langTheme.tertiary}):Play()
		TweenService:Create(btnStroke, TweenInfo.new(0.2), {Transparency = 0.5, Color = langTheme.stroke}):Play()
		TweenService:Create(shine, TweenInfo.new(0.3), {Size = UDim2.new(0, 0, 1, 0)}):Play()
	end)
	btn.MouseButton1Click:Connect(function()
		local ripple = Instance.new("Frame")
		ripple.Size = UDim2.new(0, 0, 0, 0)
		ripple.Position = UDim2.new(0.5, 0, 0.5, 0)
		ripple.AnchorPoint = Vector2.new(0.5, 0.5)
		ripple.BackgroundColor3 = langTheme.accent
		ripple.BackgroundTransparency = 0.7
		ripple.ZIndex = 20005
		ripple.Parent = btn
		Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)

		TweenService:Create(ripple, TweenInfo.new(0.4), {Size = UDim2.new(2, 0, 2, 0), BackgroundTransparency = 1}):Play()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = langTheme.accent}):Play()
		task.delay(0.4, function() ripple:Destroy() end)
		task.wait(0.15)
		selectedLang = lang
	end)
end

MakeLangBtn("🇹🇷  Türkçe",   1, "TR")
MakeLangBtn("🇬🇧  English",  2, "EN")
MakeLangBtn("🇪🇸  Español",  3, "ES")
MakeLangBtn("🇸🇦  العربية",  4, "AR")
MakeLangBtn("🇫🇷  Français", 5, "FR")
MakeLangBtn("🇮🇳  हिन्दी",   6, "HI")
MakeLangBtn("🇵🇹  Português",7, "PT")
MakeLangBtn("🇷🇺  Русский",  8, "RU")

-- Remember Language butonu
local rememberBtn = Instance.new("TextButton")
rememberBtn.Size = UDim2.new(0.92, 0, 0, 40)
rememberBtn.Position = UDim2.new(0.04, 0, 1, -50)
rememberBtn.BackgroundColor3 = langTheme.tertiary
rememberBtn.Text = "💾  Remember Language"
rememberBtn.TextColor3 = langTheme.textDim
rememberBtn.Font = Enum.Font.GothamBold
rememberBtn.TextSize = isMobile and 13 or 15
rememberBtn.ZIndex = 20003
rememberBtn.Parent = langBox
Instance.new("UICorner", rememberBtn).CornerRadius = UDim.new(0, 12)

local rememberStroke = Instance.new("UIStroke")
rememberStroke.Color = langTheme.stroke
rememberStroke.Transparency = 0.5
rememberStroke.Parent = rememberBtn

rememberBtn.MouseButton1Click:Connect(function()
	rememberLang = not rememberLang
	if rememberLang then
		TweenService:Create(rememberBtn, TweenInfo.new(0.2),
			{BackgroundColor3 = langTheme.success}):Play()
		rememberBtn.Text       = "✅  Remember Language"
		rememberBtn.TextColor3 = Color3.new(1, 1, 1)
	else
		TweenService:Create(rememberBtn, TweenInfo.new(0.2),
			{BackgroundColor3 = langTheme.tertiary}):Play()
		rememberBtn.Text       = "💾  Remember Language"
		rememberBtn.TextColor3 = langTheme.textDim
	end
end)

local targetSize = isMobile and UDim2.new(0, 380, 0, 410) or UDim2.new(0, 480, 0, 410)
TweenService:Create(langBox, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = targetSize, Rotation = 0}):Play()

repeat task.wait(0.1) until selectedLang

-- Dil hatırlama seçiliyse kaydet
if rememberLang then
	Settings.language = selectedLang
	SaveData()
end

TweenService:Create(langBox, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), Rotation = 360}):Play()
TweenService:Create(langScreen, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play()
task.wait(0.4)
langScreen:Destroy()

end -- if not selectedLang

-- ===============================================================
-- LANGUAGE
-- ===============================================================

local isTR, isES, isAR, isFR, isHI, isPT, isRU = selectedLang == "TR", selectedLang == "ES", selectedLang == "AR", selectedLang == "FR", selectedLang == "HI", selectedLang == "PT", selectedLang == "RU"
local L = {
	r6Msg = isTR and "Sadece R15!" or (isES and "Solo R15!" or (isAR and "R15 فقط!" or (isFR and "R15 uniquement!" or (isHI and "केवल R15!" or (isPT and "Apenas R15!" or (isRU and "Только R15!" or "R15 only!")))))),
	loading = isTR and "Yükleniyor..." or (isES and "Cargando..." or (isAR and "جار التحميل..." or (isFR and "Chargement..." or (isHI and "लोड हो रहा है..." or (isPT and "Carregando..." or (isRU and "Загрузка..." or "Loading...")))))),
	madeBy = isTR and "Oyuncu15q tarafından yapıldı" or (isES and "Hecho por Oyuncu15q" or (isAR and "صنع بواسطة Oyuncu15q" or (isFR and "Fait par Oyuncu15q" or (isHI and "Oyuncu15q द्वारा निर्मित" or (isPT and "Feito por Oyuncu15q" or (isRU and "Сделано Oyuncu15q" or "Made by Oyuncu15q")))))),
	search = isTR and "Ara..." or (isES and "Buscar..." or (isAR and "بحث..." or (isFR and "Rechercher..." or (isHI and "खोजें..." or (isPT and "Pesquisar..." or (isRU and "Поиск..." or "Search...")))))),
	playing = isTR and "Oynatılıyor" or (isES and "Reproduciendo" or (isAR and "تشغيل" or (isFR and "En lecture" or (isHI and "चल रहा है" or (isPT and "Reproduzindo" or (isRU and "Воспроизведение" or "Playing")))))),
	stopped = isTR and "Durduruldu" or (isES and "Detenido" or (isAR and "توقف" or (isFR and "Arrêté" or (isHI and "रुक गया" or (isPT and "Parado" or (isRU and "Остановлено" or "Stopped")))))),
	ready = isTR and "Hazır!" or (isES and "Listo!" or (isAR and "جاهز!" or (isFR and "Prêt!" or (isHI and "तैयार!" or (isPT and "Pronto!" or (isRU and "Готово!" or "Ready!")))))),
	emotes = isTR and "Emoteler" or (isES and "Emotes" or (isAR and "رقصات" or (isFR and "Emotes" or (isHI and "इमोट्स" or (isPT and "Emotes" or (isRU and "Эмоции" or "Emotes")))))),
	favorites = isTR and "Favoriler" or (isES and "Favoritos" or (isAR and "المفضلة" or (isFR and "Favoris" or (isHI and "पसंदीदा" or (isPT and "Favoritos" or (isRU and "Избранное" or "Favorites")))))),
	recent = isTR and "Son Kullanılanlar" or (isES and "Recientes" or (isAR and "الأخيرة" or (isFR and "Récents" or (isHI and "हाल ही के" or (isPT and "Recentes" or (isRU and "Недавние" or "Recent")))))),
	settings = isTR and "Ayarlar" or (isES and "Ajustes" or (isAR and "الإعدادات" or (isFR and "Paramètres" or (isHI and "सेटिंग्स" or (isPT and "Configurações" or (isRU and "Настройки" or "Settings")))))),
	noFav = isTR and "Favori yok" or (isES and "Sin favoritos" or (isAR and "لا يوجد مفضلة" or (isFR and "Pas de favoris" or (isHI and "कोई पसंदीदा नहीं" or (isPT and "Sem favoritos" or (isRU and "Нет избранного" or "No favorites")))))),
	noRecent = isTR and "Geçmiş yok" or (isES and "Sin recientes" or (isAR and "لا يوجد سجل" or (isFR and "Pas de récents" or (isHI and "कोई हाल का नहीं" or (isPT and "Sem recentes" or (isRU and "Нет недавних" or "No recent")))))),
	theme = isTR and "Tema" or (isES and "Tema" or (isAR and "المظهر" or (isFR and "Thème" or (isHI and "थीम" or (isPT and "Tema" or (isRU and "Тема" or "Theme")))))),
	speed = isTR and "Hız" or (isES and "Velocidad" or (isAR and "السرعة" or (isFR and "Vitesse" or (isHI and "गति" or (isPT and "Velocidade" or (isRU and "Скорость" or "Speed")))))),
	notif = isTR and "Bildirimler" or (isES and "Notificaciones" or (isAR and "الإشعارات" or (isFR and "Notifications" or (isHI and "सूचनाएं" or (isPT and "Notificações" or (isRU and "Уведомления" or "Notifications")))))),
	on = isTR and "Açık" or (isES and "On" or (isAR and "تشغيل" or (isFR and "Activé" or (isHI and "चालू" or (isPT and "Ligado" or (isRU and "Вкл" or "On")))))),
	off = isTR and "Kapalı" or (isES and "Off" or (isAR and "إيقاف" or (isFR and "Désactivé" or (isHI and "बंद" or (isPT and "Desligado" or (isRU and "Выкл" or "Off")))))),
	copied = isTR and "Kopyalandı!" or (isES and "Copiado!" or (isAR and "تم النسخ!" or (isFR and "Copié!" or (isHI and "कॉपी किया गया!" or (isPT and "Copiado!" or (isRU and "Скопировано!" or "Copied!")))))),
	loopText    = isTR and "Döngü"         or (isES and "Bucle"         or (isAR and "تكرار"        or (isFR and "Boucle"          or (isHI and "लूप"           or (isPT and "Loop"        or (isRU and "Цикл"         or "Loop")))))),
	comboTitle  = isTR and "Combo Sırası" or (isES and "Cola de Combo" or (isAR and "قائمة الكومبو" or (isFR and "File Combo"       or (isHI and "कॉम्बो कतार"    or (isPT and "Fila de Combo" or (isRU and "Очередь комбо" or "Combo Queue")))))),
	addEmote    = isTR and "+ Ekle"       or (isES and "+ Añadir"      or (isAR and "+ إضافة"       or (isFR and "+ Ajouter"        or (isHI and "+ जोड़ें"       or (isPT and "+ Adicionar"   or (isRU and "+ Добавить"    or "+ Add")))))),
	playCombo   = isTR and "Oynat"        or (isES and "Reproducir"    or (isAR and "تشغيل"         or (isFR and "Jouer"            or (isHI and "चलाएं"         or (isPT and "Reproduzir"    or (isRU and "Играть"        or "Play")))))),
	clearCombo  = isTR and "Temizle"      or (isES and "Limpiar"       or (isAR and "مسح"           or (isFR and "Effacer"          or (isHI and "साफ़ करें"      or (isPT and "Limpar"        or (isRU and "Очистить"      or "Clear")))))),
	selectFirst = isTR and "Önce seç!"      or (isES and "¡Selecciona!"   or (isAR and "اختر أولاً!"    or (isFR and "Choisir d'abord!" or (isHI and "पहले चुनें!"    or (isPT and "Selecione!"     or (isRU and "Выберите!"      or "Select first!")))))),
	slotLabel   = isTR and "Slot"           or (isES and "Ranura"         or (isAR and "خانة"           or (isFR and "Slot"             or (isHI and "स्लॉट"          or (isPT and "Slot"           or (isRU and "Слот"           or "Slot")))))),
	-- Bilgi paneli
	infoTitle   = isTR and "Emote Bilgisi" or (isES and "Info del Emote" or (isAR and "معلومات الحركة" or (isFR and "Infos de l'Emote" or (isHI and "इमोट जानकारी"   or (isPT and "Info do Emote"  or (isRU and "Инфо Эмоции"    or "Emote Info")))))),
	noDesc      = isTR and "Açıklama yok"  or (isES and "Sin descripción" or (isAR and "لا يوجد وصف"   or (isFR and "Sans description" or (isHI and "कोई विवरण नहीं" or (isPT and "Sem descrição"   or (isRU and "Нет описания"   or "No description")))))),
	freePrice   = isTR and "Ücretsiz"      or (isES and "Gratis"          or (isAR and "مجاني"          or (isFR and "Gratuit"          or (isHI and "मुफ़्त"          or (isPT and "Grátis"          or (isRU and "Бесплатно"      or "Free")))))),
	copyId           = isTR and "ID Kopyala"         or (isES and "Copiar ID"              or (isAR and "نسخ المعرف"          or (isFR and "Copier ID"             or (isHI and "ID कॉपी करें"      or (isPT and "Copiar ID"            or (isRU and "Скопировать ID"    or "Copy ID")))))),
	copyEmote        = isTR and "Emote Kopyala"      or (isES and "Copiar Emote"           or (isAR and "نسخ الحركة"           or (isFR and "Copier Emote"          or (isHI and "इमोट कॉपी करें"    or (isPT and "Copiar Emote"         or (isRU and "Скопировать"       or "Copy Emote")))))),
	favLimit         = isTR and "Maksimum 25 favori!" or (isES and "¡Máximo 25 favoritos!"  or (isAR and "الحد الأقصى 25!"       or (isFR and "Maximum 25 favoris!"   or (isHI and "अधिकतम 25 पसंदीदा!" or (isPT and "Máximo 25 favoritos!" or (isRU and "Максимум 25!"       or "Max 25 favorites!")))))),
	copyEmoteDesc    = isTR and "Bir oyuncunun kullandığı emote'u kopyalar" or (isES and "Copia el emote que usa otro jugador" or (isAR and "ينسخ حركة يستخدمها لاعب آخر" or (isFR and "Copie l'émote utilisé par un autre joueur" or (isHI and "किसी खिलाड़ी का इमोट कॉपी करता है" or (isPT and "Copia o emote de outro jogador" or (isRU and "Копирует эмоцию другого игрока" or "Copies the emote used by another player")))))),
	stopOnWalk       = isTR and "Yürüyünce emote'u durdur" or (isES and "Parar emote al caminar" or (isAR and "ايقاف الحركة عند المشي" or (isFR and "Arreter emote en marchant" or (isHI and "चलने पर इमोट रोकें" or (isPT and "Parar emote ao andar" or (isRU and "Остановить эмоцию при ходьбе" or "Stop emote when walking")))))),
	stopOnWalkDesc   = isTR and "Oyuncu yürüdüğü zaman emote durur" or (isES and "El emote se detiene al caminar" or (isAR and "تتوقف الحركة تلقائيا عند المشي" or (isFR and "L'emote s'arrete automatiquement en marchant" or (isHI and "चलने पर इमोट अपने आप रुक जाता है" or (isPT and "O emote para automaticamente ao andar" or (isRU and "Эмоция останавливается при ходьбе" or "Emote stops automatically when walking")))))),
	showHUD          = isTR and "Oynatma barını göster" or (isES and "Mostrar barra de reproducción" or (isAR and "إظهار شريط التشغيل" or (isFR and "Afficher la barre de lecture" or (isHI and "प्लेबार दिखाएं" or (isPT and "Mostrar barra de reprodução" or (isRU and "Показать панель воспроизведения" or "Show playback bar")))))),
	friendTab        = isTR and "Arkadaşlar"                       or (isES and "Amigos"                  or (isAR and "الأصدقاء"            or (isFR and "Amis"                  or (isHI and "दोस्त"                  or (isPT and "Amigos"                 or (isRU and "Друзья"                 or "Friends")))))),
	accept           = isTR and "Kabul Et"                         or (isES and "Aceptar"                 or (isAR and "قبول"                  or (isFR and "Accepter"              or (isHI and "स्वीकार करें"              or (isPT and "Aceitar"                or (isRU and "Принять"                or "Accept")))))),
	reject           = isTR and "Reddet"                           or (isES and "Rechazar"                or (isAR and "رفض"                   or (isFR and "Refuser"               or (isHI and "अस्वीकार करें"              or (isPT and "Rejeitar"               or (isRU and "Отклонить"              or "Reject")))))),
	friendAlreadySyncing = isTR and "Hata! Oyuncu zaten başka birisiyle beraber emote oynuyor." or (isES and "Error! El jugador ya está sincronizado con otro." or (isAR and "خطأ! اللاعب يلعب مع شخص آخر." or (isFR and "Erreur! Le joueur est déjà synchronisé avec quelqu'un d'autre." or (isHI and "त्रुटि! खिलाड़ी पहले से किसी और के साथ खेल रहा है।" or (isPT and "Erro! O jogador já está sincronizado com outro." or (isRU and "Ошибка! Игрок уже играет с другим." or "Error! Player is already syncing with someone else.")))))),
	showHUDDesc      = isTR and "Emote oynarken altta oynatma barı görünsün" or (isES and "Muestra la barra de control al reproducir emotes" or (isAR and "يظهر شريط التحكم أسفل الشاشة أثناء تشغيل الحركة" or (isFR and "Affiche la barre de controle en bas lors de la lecture" or (isHI and "इमोट चलाते समय नीचे प्लेबार दिखाता है" or (isPT and "Exibe a barra de controle na parte inferior ao reproduzir" or (isRU and "Показывает панель управления внизу при воспроизведении" or "Shows the playback control bar while emote plays")))))),
	keybinds         = isTR and "Keybindler"           or (isES and "Teclas"               or (isAR and "اختصارات"             or (isFR and "Raccourcis"           or (isHI and "कीबाइंड"              or (isPT and "Teclas"               or (isRU and "Горячие клавиши"     or "Keybinds")))))),
	newKeybind       = isTR and "Yeni Keybind Oluştur" or (isES and "Crear Nuevo Keybind"  or (isAR and "إنشاء اختصار جديد"    or (isFR and "Nouveau Raccourci"     or (isHI and "नया कीबाइंड बनाएं"   or (isPT and "Novo Keybind"         or (isRU and "Новая клавиша"        or "New Keybind")))))),
	editKeybind      = isTR and "Keybind Değiştir"     or (isES and "Cambiar Keybind"      or (isAR and "تغيير الاختصار"        or (isFR and "Modifier Raccourci"    or (isHI and "कीबाइंड बदलें"       or (isPT and "Alterar Keybind"      or (isRU and "Изменить клавишу"     or "Edit Keybind")))))),
	kbName           = isTR and "İsim"                 or (isES and "Nombre"               or (isAR and "الاسم"                 or (isFR and "Nom"                   or (isHI and "नाम"                  or (isPT and "Nome"                 or (isRU and "Название"            or "Name")))))),
	kbAssign         = isTR and "Atama"                or (isES and "Asignación"           or (isAR and "التعيين"               or (isFR and "Attribution"           or (isHI and "असाइन करें"           or (isPT and "Atribuição"           or (isRU and "Назначение"          or "Assign")))))),
	kbRecording      = isTR and "Tuşa Bas"             or (isES and "Presiona Tecla"       or (isAR and "اضغط مفتاحاً"          or (isFR and "Appuyez sur Touche"    or (isHI and "कुंजी दबाएं"          or (isPT and "Pressione Tecla"      or (isRU and "Нажмите клавишу"     or "Press Key")))))),
	kbCancel         = isTR and "İptal"                or (isES and "Cancelar"             or (isAR and "إلغاء"                 or (isFR and "Annuler"               or (isHI and "रद्द करें"             or (isPT and "Cancelar"             or (isRU and "Отмена"              or "Cancel")))))),
	kbSave           = isTR and "Kaydet"               or (isES and "Guardar"              or (isAR and "حفظ"                   or (isFR and "Enregistrer"           or (isHI and "सहेजें"               or (isPT and "Salvar"               or (isRU and "Сохранить"           or "Save")))))),
	kbEmpty          = isTR and "Henüz keybind yok"    or (isES and "Sin keybinds aún"     or (isAR and "لا توجد اختصارات بعد"  or (isFR and "Aucun raccourci"        or (isHI and "कोई कीबाइंड नहीं"    or (isPT and "Nenhum keybind ainda" or (isRU and "Нет горячих клавиш"  or "No keybinds yet")))))),
	noSearch         = isTR and "Sonuç bulunamadı"     or (isES and "Sin resultados"        or (isAR and "لا توجد نتائج"            or (isFR and "Aucun résultat"         or (isHI and "कोई परिणाम नहीं"      or (isPT and "Sem resultados"       or (isRU and "Ничего не найдено"   or "No results found")))))),
	kbInvalidKey     = isTR and "Geçersiz tuş!"        or (isES and "¡Tecla inválida!"      or (isAR and "مفتاح غير صالح!"          or (isFR and "Touche invalide!"       or (isHI and "अमान्य कुंजी!"         or (isPT and "Tecla inválida!"      or (isRU and "Недопустимая клавиша!" or "Invalid key!")))))),
	autoRejectLbl    = isTR and "Arkadaş isteklerini otomatik reddet."     or (isES and "Rechazar solicitudes automáticamente."  or (isAR and "رفض طلبات الصداقة تلقائياً."         or (isFR and "Refuser les demandes automatiquement."    or (isHI and "मित्र अनुरोध स्वचालित रूप से अस्वीकार करें।" or (isPT and "Rejeitar pedidos automaticamente."      or (isRU and "Автоматически отклонять запросы."      or "Auto-reject friend requests.")))))),
	addFriendBtn     = isTR and "+ Arkadaş Ekle"                           or (isES and "+ Añadir Amigo"                         or (isAR and "+ إضافة صديق"                          or (isFR and "+ Ajouter Ami"                          or (isHI and "+ मित्र जोड़ें"                              or (isPT and "+ Adicionar Amigo"                    or (isRU and "+ Добавить друга"                     or "+ Add Friend")))))),
	blocked          = isTR and "Engellendi"                                or (isES and "Bloqueado"                              or (isAR and "محظور"                                 or (isFR and "Bloqué"                                  or (isHI and "ब्लॉक किया"                               or (isPT and "Bloqueado"                             or (isRU and "Заблокирован"                          or "Blocked")))))),
	requestSent      = isTR and "✓ İstek Gönderildi"                       or (isES and "✓ Solicitud Enviada"                    or (isAR and "✓ تم إرسال الطلب"                       or (isFR and "✓ Demande Envoyée"                        or (isHI and "✓ अनुरोध भेजा"                            or (isPT and "✓ Pedido Enviado"                      or (isRU and "✓ Запрос отправлен"                    or "✓ Request Sent")))))),
	addFriendMode    = isTR and "+ Arkadaş Ekle Modu"                      or (isES and "+ Modo Añadir Amigo"                    or (isAR and "+ وضع إضافة الأصدقاء"                  or (isFR and "+ Mode Ajout Ami"                         or (isHI and "+ मित्र जोड़ें मोड"                         or (isPT and "+ Modo Adicionar Amigo"               or (isRU and "+ Режим добавления друга"             or "+ Add Friend Mode")))))),
	friendInfoTxt    = isTR and "Arkadaş eklemek aynı emote'u arkadaşlarınızla veya arkadaşınızla beraber senkronize oynamanızı sağlar." or (isES and "Agregar amigos permite sincronizar emotes juntos." or (isAR and "إضافة أصدقاء تتيح مزامنة الحركات معاً." or (isFR and "Ajouter des amis permet de synchroniser les emotes ensemble." or (isHI and "मित्र जोड़ने से एक साथ इमोट सिंक्रनाइज़ करना संभव होता है।" or (isPT and "Adicionar amigos permite sincronizar emotes juntos." or (isRU and "Добавление друзей позволяет синхронизировать эмоции вместе." or "Adding friends lets you sync emotes together.")))))),
	friendListHeader = isTR and "Arkadaş Listesi"                          or (isES and "Lista de Amigos"                        or (isAR and "قائمة الأصدقاء"                         or (isFR and "Liste d'Amis"                             or (isHI and "मित्र सूची"                               or (isPT and "Lista de Amigos"                       or (isRU and "Список друзей"                         or "Friend List")))))),
	noFriends        = isTR and "Henüz arkadaş yok. Arkadaş Ekle butonunu kullan!" or (isES and "Sin amigos. ¡Usa el botón Añadir Amigo!" or (isAR and "لا أصدقاء بعد. استخدم زر إضافة صديق!" or (isFR and "Aucun ami. Utilisez le bouton Ajouter Ami!" or (isHI and "कोई मित्र नहीं। मित्र जोड़ें बटन का उपयोग करें!" or (isPT and "Sem amigos. Use o botão Adicionar Amigo!" or (isRU and "Нет друзей. Используйте кнопку добавления!" or "No friends yet. Use Add Friend button!")))))),
	emoteLoadFail    = isTR and "Emote yüklenemedi!"                        or (isES and "¡Error al cargar emote!"                or (isAR and "فشل تحميل الحركة!"                      or (isFR and "Échec du chargement!"                     or (isHI and "इमोट लोड नहीं हुआ!"                         or (isPT and "Falha ao carregar emote!"               or (isRU and "Ошибка загрузки эмоции!"               or "Failed to load emote!")))))),
	alreadyFriends   = isTR and "Zaten arkadaşsınız!"                       or (isES and "¡Ya son amigos!"                        or (isAR and "أنتم أصدقاء بالفعل!"                    or (isFR and "Vous êtes déjà amis!"                     or (isHI and "पहले से मित्र हैं!"                          or (isPT and "Já são amigos!"                        or (isRU and "Вы уже друзья!"                        or "Already friends!")))))),
	spamProtect      = isTR and "Spam koruması aktif! %ds bekle"            or (isES and "¡Protección spam! Espera %ds"           or (isAR and "حماية من الإسبام! انتظر %dث"            or (isFR and "Anti-spam actif! Attends %ds"             or (isHI and "स्पैम सुरक्षा! %dस प्रतीक्षा करें"            or (isPT and "Proteção spam! Aguarde %ds"             or (isRU and "Спам-защита! Подожди %dс"               or "Spam protection! Wait %ds")))))),
	waitRequest      = isTR and "Bu oyuncuya istek için %ds bekle"          or (isES and "Espera %ds para enviar solicitud"       or (isAR and "انتظر %dث لإرسال طلب لهذا اللاعب"       or (isFR and "Attends %ds pour envoyer demande"         or (isHI and "इस खिलाड़ी को अनुरोध के लिए %dस प्रतीक्षा करें" or (isPT and "Aguarde %ds para enviar pedido"          or (isRU and "Жди %dс для запроса"                   or "Wait %ds to send request")))))),
	tooFastRequest   = isTR and "Çok hızlı istek! %ds timeout"             or (isES and "¡Demasiado rápido! %ds timeout"         or (isAR and "طلب سريع جداً! %dث مهلة"                or (isFR and "Trop rapide! %ds timeout"                 or (isHI and "बहुत तेज़ अनुरोध! %dस टाइमआउट"              or (isPT and "Muito rápido! %ds timeout"              or (isRU and "Слишком быстро! %dс таймаут"            or "Too fast! %ds timeout")))))),
	friendReqSent    = isTR and "%s adlı oyuncuya arkadaşlık isteği gönderildi!" or (isES and "¡Solicitud enviada a %s!"         or (isAR and "تم إرسال طلب صداقة إلى %s!"              or (isFR and "Demande envoyée à %s!"                    or (isHI and "%s को मित्र अनुरोध भेजा!"                    or (isPT and "Pedido enviado para %s!"                or (isRU and "Запрос отправлен %s!"                  or "Friend request sent to %s!")))))),
	friendReqAcceptedYou = isTR and "%s arkadaşlık isteğini kabul ettin!"   or (isES and "¡Aceptaste la solicitud de %s!"        or (isAR and "قبلت طلب %s!"                            or (isFR and "Vous avez accepté la demande de %s!"      or (isHI and "आपने %s का अनुरोध स्वीकार किया!"              or (isPT and "Você aceitou o pedido de %s!"           or (isRU and "Вы приняли запрос %s!"                 or "You accepted %s's request!")))))),
	friendReqAcceptedThem = isTR and "%s arkadaşlık isteğini kabul etti!"   or (isES and "¡%s aceptó tu solicitud!"              or (isAR and "قبل %s طلبك!"                            or (isFR and "%s a accepté votre demande!"               or (isHI and "%s ने आपका अनुरोध स्वीकार किया!"              or (isPT and "%s aceitou seu pedido!"                 or (isRU and "%s принял ваш запрос!"                 or "%s accepted your request!")))))),
	acceptRequestsLbl  = isTR and "Arkadaş istekleri al"           or (isES and "Aceptar solicitudes"          or (isAR and "قبول طلبات الصداقة"       or (isFR and "Accepter les demandes"       or (isHI and "मित्र अनुरोध स्वीकार करें"    or (isPT and "Aceitar pedidos"              or (isRU and "Принимать запросы"            or "Accept friend requests")))))),
	resetLangLbl       = isTR and "Dil Sıfırla"                    or (isES and "Restablecer idioma"           or (isAR and "إعادة تعيين اللغة"        or (isFR and "Réinitialiser la langue"     or (isHI and "भाषा रीसेट करें"               or (isPT and "Redefinir idioma"             or (isRU and "Сбросить язык"                or "Reset Language")))))),
	resetLangDesc      = isTR and "Dili sıfırla ve yeniden seç"    or (isES and "Restablecer y reseleccionar"  or (isAR and "إعادة التعيين وإعادة الاختيار" or (isFR and "Réinitialiser et resélectionner" or (isHI and "रीसेट करें और पुनः चुनें"      or (isPT and "Redefinir e selecionar novamente" or (isRU and "Сбросить и выбрать снова"     or "Reset and reselect language")))))),
}

local Icons = {
	Emote = "rbxassetid://138124492647096",
	Sort = "rbxassetid://113816420281431", 
	Refresh = "rbxassetid://105648271243690",
	Info = "rbxassetid://84622089809608",
	Crown = "rbxassetid://73989246452336",
	Minus = "rbxassetid://113043537756950", 
	Close = "rbxassetid://71734731066706", -- X
	Search = "rbxassetid://100759629447583",
	FavoriteEmpty = "rbxassetid://139336655769578",
	FavoriteFull = "rbxassetid://114412745011584",
	Stop = "STOP_SHAPE",
	Keybind = "rbxassetid://122679509852670",
	KeybindActive = "rbxassetid://133187471200337",
	KeybindRemove = "rbxassetid://119388907849573",
	Settings = "rbxassetid://94488099205692", 
	Recent = "rbxassetid://89358357551545", 
	Check = "rbxassetid://71514022902819",
	Quatrefoil = "rbxassetid://98400541052448", 
}

-- ===============================================================
-- R15 CHECK
-- ===============================================================

local char = player.Character or player.CharacterAdded:Wait()
local hum = char:WaitForChild("Humanoid", 5)
if not hum or hum.RigType == Enum.HumanoidRigType.R6 then
	Notify(utf8.char(0x274C), L.r6Msg)
	gui:Destroy()
	return
end

-- Emotes must be declared at top scope (used by later code)
local Emotes = {}

-- ===============================================================
-- SPLASH SCREEN
-- ===============================================================

do
local _splashTheme = Themes[Settings.theme] or Themes.Dark
local _splashPrimary = _splashTheme.primary
local _splashAccent  = _splashTheme.accent
local _splashIsGlass = Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass"

-- BlurEffect loading ekranı arkası için (sadece splash süresince)
local splashBlur = Instance.new("BlurEffect")
splashBlur.Size = 24
splashBlur.Parent = game:GetService("Lighting")

local splash = Instance.new("Frame")
splash.Size = UDim2.fromScale(1, 1)
splash.BackgroundColor3 = _splashPrimary
-- Blur'un görünmesi için her temada yarı saydam, glass'ta daha saydam
splash.BackgroundTransparency = _splashIsGlass and 0.55 or 0.35
splash.ZIndex = 10000
splash.Parent = gui

local splashBgGrad = Instance.new("UIGradient")
splashBgGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,   _splashPrimary),
	ColorSequenceKeypoint.new(0.5, Color3.new(
		math.clamp(_splashPrimary.R + _splashAccent.R * 0.15, 0, 1),
		math.clamp(_splashPrimary.G + _splashAccent.G * 0.15, 0, 1),
		math.clamp(_splashPrimary.B + _splashAccent.B * 0.20, 0, 1)
	)),
	ColorSequenceKeypoint.new(1,   _splashPrimary)
}
splashBgGrad.Rotation = 45
splashBgGrad.Parent = splash

task.spawn(function()
	local rot = 0
	while splash.Parent do
		rot = (rot + 1) % 360
		splashBgGrad.Rotation = rot
		task.wait(0.05)
	end
end)

local splashBox = Instance.new("Frame")
splashBox.Size = UDim2.new(0, 0, 0, 0)
splashBox.Position = UDim2.fromScale(0.5, 0.5)
splashBox.AnchorPoint = Vector2.new(0.5, 0.5)
splashBox.BackgroundColor3 = _splashTheme.secondary
splashBox.BackgroundTransparency = _splashIsGlass and 0.45 or 0.08
splashBox.Rotation = -180
splashBox.ZIndex = 10001
splashBox.Parent = splash
Instance.new("UICorner", splashBox).CornerRadius = UDim.new(0, 22)

local splashStroke = Instance.new("UIStroke")
splashStroke.Color = _splashAccent
splashStroke.Thickness = 3
splashStroke.Parent = splashBox

local splashStrokeGrad = Instance.new("UIGradient")
splashStrokeGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,    _splashAccent),
	ColorSequenceKeypoint.new(0.33, _splashTheme.stroke),
	ColorSequenceKeypoint.new(0.66, _splashAccent),
	ColorSequenceKeypoint.new(1,    _splashAccent)
}
splashStrokeGrad.Parent = splashStroke

task.spawn(function()
	local rot = 0
	while splashStroke.Parent do
		rot = rot + 360
		TweenService:Create(splashStrokeGrad, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {Rotation = rot}):Play()
		task.wait(1.5)
	end
end)

local avatarHolder = Instance.new("Frame")
avatarHolder.Size = UDim2.new(1, -24, 0, 50)
avatarHolder.Position = UDim2.new(0, 12, 0, 12)
avatarHolder.BackgroundTransparency = 1
avatarHolder.ZIndex = 10002
avatarHolder.Parent = splashBox

local avatar = Instance.new("ImageLabel")
avatar.Size = UDim2.new(0, 44, 0, 44)
avatar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
avatar.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=3164346931&width=150&height=150&format=png"
avatar.ZIndex = 10003
avatar.Parent = avatarHolder
Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

local avatarGlow = Instance.new("UIStroke")
avatarGlow.Color = Color3.fromRGB(138, 43, 226)
avatarGlow.Thickness = 2
avatarGlow.Parent = avatar

task.spawn(function()
	while avatar.Parent do
		TweenService:Create(avatarGlow, TweenInfo.new(1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(186, 85, 211)}):Play()
		task.wait(1)
		TweenService:Create(avatarGlow, TweenInfo.new(1, Enum.EasingStyle.Sine), {Color = Color3.fromRGB(138, 43, 226)}):Play()
		task.wait(1)
	end
end)

local madeByLbl = Instance.new("TextLabel")
madeByLbl.Size = UDim2.new(1, -54, 1, 0)
madeByLbl.Position = UDim2.new(0, 52, 0, 0)
madeByLbl.BackgroundTransparency = 1
madeByLbl.Text = L.madeBy
madeByLbl.TextColor3 = _splashTheme.textDim
madeByLbl.Font = Enum.Font.GothamBold
madeByLbl.TextScaled = true
madeByLbl.TextXAlignment = Enum.TextXAlignment.Left
madeByLbl.ZIndex = 10003
madeByLbl.Parent = avatarHolder

local logo = Instance.new("TextLabel")
logo.Size = UDim2.new(1, -24, 0, 60)
logo.Position = UDim2.new(0, 12, 0, 70)
logo.BackgroundTransparency = 1
logo.Text = "Vexro Emotes"
logo.TextColor3 = _splashTheme.text
logo.Font = Enum.Font.GothamBlack
logo.TextScaled = true
logo.ZIndex = 10003
logo.Parent = splashBox

local logoGrad = Instance.new("UIGradient")
logoGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0,    _splashAccent),
	ColorSequenceKeypoint.new(0.25, _splashTheme.stroke),
	ColorSequenceKeypoint.new(0.5,  _splashAccent),
	ColorSequenceKeypoint.new(0.75, _splashTheme.stroke),
	ColorSequenceKeypoint.new(1,    _splashAccent)
}
logoGrad.Parent = logo

task.spawn(function()
	while logo.Parent do
		TweenService:Create(logoGrad, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)}):Play()
		task.wait(2)
		TweenService:Create(logoGrad, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(-1, 0)}):Play()
		task.wait(2)
	end
end)

local loadingLbl = Instance.new("TextLabel")
loadingLbl.Size = UDim2.new(1, 0, 0, 30)
loadingLbl.Position = UDim2.new(0, 0, 0, 140)
loadingLbl.BackgroundTransparency = 1
loadingLbl.Text = L.loading
loadingLbl.TextColor3 = _splashTheme.textDim
loadingLbl.Font = Enum.Font.GothamBold
loadingLbl.TextSize = 16
loadingLbl.ZIndex = 10003
loadingLbl.Parent = splashBox

task.spawn(function()
	local dots = {"", ".", "..", "..."}
	local i = 1
	while loadingLbl.Parent do
		loadingLbl.Text = "Vexro Emotes " .. L.loading .. dots[i]
		i = i % 4 + 1
		task.wait(0.4)
	end
end)

local loadingBarBg = Instance.new("Frame")
loadingBarBg.Size = UDim2.new(0.8, 0, 0, 6)
loadingBarBg.Position = UDim2.new(0.1, 0, 0, 175)
loadingBarBg.BackgroundColor3 = _splashTheme.tertiary
loadingBarBg.ZIndex = 10003
loadingBarBg.Parent = splashBox
Instance.new("UICorner", loadingBarBg).CornerRadius = UDim.new(1, 0)

local loadingBar = Instance.new("Frame")
loadingBar.Size = UDim2.new(0, 0, 1, 0)
loadingBar.BackgroundColor3 = _splashAccent
loadingBar.ZIndex = 10004
loadingBar.Parent = loadingBarBg
Instance.new("UICorner", loadingBar).CornerRadius = UDim.new(1, 0)

local loadingBarGrad = Instance.new("UIGradient")
loadingBarGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, _splashAccent),
	ColorSequenceKeypoint.new(0.5, _splashTheme.stroke),
	ColorSequenceKeypoint.new(1, _splashAccent)
}
loadingBarGrad.Parent = loadingBar

local discordBtn = Instance.new("TextButton")
discordBtn.Size = UDim2.new(0.85, 0, 0, 42)
discordBtn.Position = UDim2.new(0.075, 0, 1, -55)
discordBtn.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
discordBtn.Text = "Discord: 4Bs9WYSabf"
discordBtn.TextColor3 = Color3.new(1, 1, 1)
discordBtn.Font = Enum.Font.GothamBold
discordBtn.TextSize = 14
discordBtn.ZIndex = 10003
discordBtn.Parent = splashBox
Instance.new("UICorner", discordBtn).CornerRadius = UDim.new(0, 10)

discordBtn.MouseButton1Click:Connect(function()
	pcall(function() if setclipboard then setclipboard("https://discord.gg/4Bs9WYSabf") end end)
	Notify(utf8.char(0x2705), L.copied)
end)

local splashSize = isMobile and UDim2.new(0, 300, 0, 240) or UDim2.new(0, 400, 0, 280)
TweenService:Create(splashBox, TweenInfo.new(0.7, Enum.EasingStyle.Back), {Size = splashSize, Rotation = 0}):Play()

-- ===============================================================
-- EMOTE LOADING
-- ===============================================================

TweenService:Create(loadingBar, TweenInfo.new(0.5), {Size = UDim2.new(0.3, 0, 1, 0)}):Play()
task.wait(0.3)

local function LoadEmotes()
	local success, result = pcall(function()
		local response = game:HttpGet("https://raw.githubusercontent.com/zyrovell/Vexro/main/emotes.json")
		return HttpService:JSONDecode(response)
	end)
	
	if success and result then
		local data = type(result) == "table" and (result.data or result)
		local _seenIds = {}
		for _, emote in ipairs(data) do
			if emote.id and emote.name then
				local numId = tonumber(emote.id)
				if numId and not _seenIds[numId] then
					_seenIds[numId] = true
					Emotes[#Emotes + 1] = {
						name          = tostring(emote.name),
						id            = numId,
						creatorName   = tostring(emote.creatorName      or ""),
						description   = tostring(emote.description      or ""),
						price         = emote.price,
						priceStatus   = tostring(emote.priceStatus      or ""),
						favoriteCount = emote.favoriteCount,
						createdUtc    = tostring(emote.itemCreatedUtc   or ""),
					}
				end
			end
		end
	end
	
	if #Emotes == 0 then
		Emotes = {
			{name = "Wave", id = 3576686446},
			{name = "Point", id = 3576823880},
			{name = "Dance", id = 3576720708},
			{name = "Laugh", id = 3576777185},
			{name = "Cheer", id = 3576738018}
		}
	end
end

LoadEmotes()

-- Build lookup table for O(1) emote access by ID
-- Pre-compute lowercase names so search never calls .lower() at runtime
for _, emote in ipairs(Emotes) do
	EmotesById[emote.id] = emote
	emote._lname = emote.name:lower()
end
TweenService:Create(loadingBar, TweenInfo.new(1), {Size = UDim2.new(1, 0, 1, 0)}):Play()
task.wait(1)

loadingLbl.Text = utf8.char(0x2705) .. " " .. #Emotes .. " emotes!"
task.wait(1)

TweenService:Create(splash, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
TweenService:Create(splashBox, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), Rotation = 720}):Play()
task.wait(0.5)
pcall(function() splashBlur:Destroy() end)
splash:Destroy()
end -- SPLASH SCREEN scope

-- Forward declarations (dosya genelinde erişilebilir olması için)
local MakeRow, MakeSectionHeader, MakePillToggle

-- ===============================================================
-- UI SIZE SETTINGS
-- ===============================================================
local ICON_SCALE = 1.5     -- İkonların resim boyutu (1.0 = normal, 1.5 = %50 daha büyük)
local BUTTON_SCALE = 1.1   -- Kırpılmayı önlemek için buton kutusunu büyütme (1.0 = normal)
local FONT_SCALE = 1.2     -- Yazı karakteri ve zar/menü sembol boyutu

-- ===============================================================
-- VARIABLES
-- ===============================================================

local EMOTE_ICON = "rbxassetid://120313093991132"
local currentData, filtered = Emotes, Emotes
local currentTab = "emotes"
local page, perPage, pages, cols = 1, 14, 1, 7 -- Default to 7 cols
local cards = {}
local sideBarW = math.floor((isMobile and 50 or 60) * BUTTON_SCALE)
local bottomBarH = isMobile and 26 or 22
local currentCardSize = 0 -- Dynamic card size
local _badEmotes = {}     -- [tostring(id)] = true  →  asset failed to load
local _refreshPending = false

-- ===============================================================
-- FAVORITES & RECENT
-- ===============================================================

local function IsFavorite(id)
	return FavoritesSet[tonumber(id)] == true
end

local MAX_FAVORITES = 25

local function ToggleFavorite(id)
	id = tonumber(id)
	if FavoritesSet[id] then
		FavoritesSet[id] = nil
		for i = #Favorites, 1, -1 do
			if Favorites[i] == id then
				table.remove(Favorites, i)
				break
			end
		end
		SaveData()
		return false
	end
	if #Favorites >= MAX_FAVORITES then
		Notify("⭐ " .. L.favLimit, "")
		return false
	end
	FavoritesSet[id] = true
	Favorites[#Favorites + 1] = id
	SaveData()
	return true
end

local function AddToRecent(id)
	id = tonumber(id)
	for i = #RecentEmotes, 1, -1 do
		if RecentEmotes[i] == id then
			table.remove(RecentEmotes, i)
		end
	end
	table.insert(RecentEmotes, 1, id)
	while #RecentEmotes > MAX_RECENT do
		table.remove(RecentEmotes)
	end
	SaveData()
end

-- ===============================================================
-- EMOTE & SPEED SYSTEM
-- ===============================================================

local currentAnimTrack = nil
local lastEmoteTime = 0

local function GetAnimator()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function StopAllTracks()
	local animator = GetAnimator()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() 
				track:Stop(0.1)
			end)
		end
	end
	currentAnimTrack = nil
end

local function ApplySpeedToAllTracks()
	local animator = GetAnimator()
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function() track:AdjustSpeed(Settings.speed) end)
		end
	end
end


local function StopEmote(showNotif)
	StopAllTracks()
	if showNotif then Notify(L.stopped, "", 113416463749658) end
	if _genv().VexroBroadcastStop then
		pcall(_genv().VexroBroadcastStop)
	end
end

local _heartbeatConn = RunService.Heartbeat:Connect(function()
	if Settings.stopOnWalk and currentAnimTrack and currentAnimTrack.IsPlaying then
		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.MoveDirection.Magnitude > 0 then
				StopEmote(false)
			end
		end
	end
end)

-- Animation objesi cache (her emote ID için bir kez GetObjects çağrılır, lag önlenir)
local _animCache = {}

local function PlayEmote(id, name, silent)
	local animator = GetAnimator()
	if not animator then return end
	
	-- FIX: Yeni emote çalmadan önce eski emoteyi durdur (hareket etmeden geçişte takılmayı önler)
	StopAllTracks()
	
	-- MODIFIED: Save last played emote for Auto-Reload (Continue)
	_genv().lastVexroEmote = {id = id, name = name}
	
	-- FIX: Catalog ID'leri direkt LoadAnimation ile çalışmadığı için game:GetObjects ile asıl Animation'ı çekiyoruz.
	-- Cache kullanarak tekrarlanan çağrılardan kaynaklanan kasılmayı önlüyoruz.
	local success, err = pcall(function()
		local anim = _animCache[id]
		
		if not anim then
			local successObj, objects = pcall(function()
				return game:GetObjects("rbxassetid://" .. id)
			end)
			
			if successObj and objects and #objects > 0 then
				local item = objects[1]
				if item:IsA("Animation") then
					anim = item
				else
					-- Folder içindeki asıl Animation objesini bul (Face animasyonları yerine vücudu bulur)
					anim = item:FindFirstChildWhichIsA("Animation", true)
				end
			end
			
			-- Eğer exploit GetObjects desteklemiyorsa veya çalışmazsa normal şekilde dene
			if not anim then
				anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. id
			end
			
			_animCache[id] = anim
		end
		
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = Settings.loopEmote
		track:Play(0.1)
		
		task.delay(0.05, function()
			track:AdjustSpeed(Settings.speed)
		end)
		
		currentAnimTrack = track
		AddToRecent(id)
	end)
	
	if success then
		if not silent then
			local speedTxt = Settings.speed ~= 1 and " (" .. Settings.speed .. "x)" or ""
			Notify(L.playing .. speedTxt, name, 129338178452237)
		end
		lastEmoteTime = tick()
		-- Arkadaşlara sync gönder
		if _genv().VexroBroadcastSync then
			pcall(_genv().VexroBroadcastSync, id, name)
		end
	else
		Notify(utf8.char(0x274C), L.emoteLoadFail)
	end
end

-- ===============================================================
-- MAIN MENU
-- ===============================================================

-- TARGET CARD SIZES (Made larger for better visibility)
local TARGET_PC_CARD = 75 -- Was 75
local TARGET_MOBILE_CARD = 55 -- Was 55

local function GetDefaultSize()
	-- Calculate width needed for 7 columns exactly + padding
	local PAD = isMobile and 4 or 6
	local targetCard = isMobile and TARGET_MOBILE_CARD or TARGET_PC_CARD
	
	-- Width for 7 cards + sidebar
	local perfectWidth = (targetCard * 7) + (PAD * 6) + sideBarW + 20
	
	local vp = workspace.CurrentCamera.ViewportSize
	local finalW = math.clamp(perfectWidth, 400, vp.X * 0.95)
	
	-- Height for 2 rows approx
	local cardH = targetCard + (targetCard * 0.3 * 2) + PAD -- approx card total height
	local perfectHeight = (cardH * 2) + 60 + bottomBarH + 20
	
	local finalH = math.clamp(perfectHeight, 300, vp.Y * 0.8)
	
	return UDim2.new(0, finalW, 0, finalH)
end

local main = Instance.new("Frame")
main.Name = "MainMenu"
main.Size = UDim2.new(0, 0, 0, 0)
main.Position = UDim2.fromScale(0.5, 0.5)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = currentTheme.primary
main.BackgroundTransparency = 0 -- Saydamlığı kaldırdık ki içi dolsun
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 20) -- Daha yumuşak köşeler
RegisterTheme(main, "BackgroundColor3", "primary")

-- Tema gradyan renkleri [üst-sol, alt-sağ, rotasyon]
local ThemeGradients = {
	Dark        = {Color3.fromRGB(22, 22, 30),  Color3.fromRGB(10, 10, 14),  135},
	Purple      = {Color3.fromRGB(28, 18, 48),  Color3.fromRGB(10, 6, 18),   135},
	Blue        = {Color3.fromRGB(18, 28, 52),  Color3.fromRGB(6, 10, 20),   135},
	Green       = {Color3.fromRGB(16, 32, 22),  Color3.fromRGB(6, 12, 8),    135},
	Red         = {Color3.fromRGB(48, 16, 18),  Color3.fromRGB(18, 6, 8),    135},
	Light       = {Color3.fromRGB(255, 255, 255), Color3.fromRGB(228, 228, 238), 135},
	MaterialYou = {Color3.fromRGB(30, 34, 50),  Color3.fromRGB(12, 14, 20),  135},
	FrostedGlass= {Color3.fromRGB(230, 238, 255), Color3.fromRGB(190, 205, 235), 135},
	DarkGlass   = {Color3.fromRGB(24, 24, 34),  Color3.fromRGB(8, 8, 12),    135},
}

-- Buzlu cam + gradyan wrapper
local _glassApplyBase = ApplyTheme
ApplyTheme = function(name)
	_glassApplyBase(name)
	local isGlass = name == "FrostedGlass" or name == "DarkGlass"
	-- Eski blur varsa temizle
	pcall(function()
		local b = game:GetService("Lighting"):FindFirstChild("VexroGlassBlur")
		if b then b:Destroy() end
	end)
	-- Şeffaflık
	TweenService:Create(main, TweenInfo.new(0.3), {BackgroundTransparency = isGlass and 0.18 or 0}):Play()
	-- Noise overlay (cam temaları)
	local noiseOverlay = main:FindFirstChild("VexroGlassNoise")
	if isGlass then
		if not noiseOverlay then
			noiseOverlay = Instance.new("ImageLabel")
			noiseOverlay.Name = "VexroGlassNoise"
			noiseOverlay.Size = UDim2.new(1, 0, 1, 0)
			noiseOverlay.BackgroundTransparency = 1
			noiseOverlay.Image = "rbxassetid://9968344672"
			noiseOverlay.ScaleType = Enum.ScaleType.Tile
			noiseOverlay.TileSize = UDim2.new(0, 64, 0, 64)
			noiseOverlay.ZIndex = 1
			noiseOverlay.Parent = main
		end
		noiseOverlay.ImageTransparency = name == "FrostedGlass" and 0.82 or 0.88
	elseif noiseOverlay then
		noiseOverlay:Destroy()
	end
	-- Gradyan: ayrı bir arka plan frame içinde (BackgroundColor3 tween'iyle çakışmaz)
	local gradFrame = main:FindFirstChild("VexroGradFrame")
	if not gradFrame then
		gradFrame = Instance.new("Frame")
		gradFrame.Name = "VexroGradFrame"
		gradFrame.Size = UDim2.new(1, 0, 1, 0)
		gradFrame.BackgroundColor3 = Color3.new(1, 1, 1)
		gradFrame.BackgroundTransparency = 0
		gradFrame.BorderSizePixel = 0
		gradFrame.ZIndex = 1
		gradFrame.Parent = main
		Instance.new("UICorner", gradFrame).CornerRadius = UDim.new(0, 20)
		local grad = Instance.new("UIGradient")
		grad.Name = "VexroMainGrad"
		grad.Parent = gradFrame
	end
	-- Cam temalarında gradyan frame'i yarı saydam yap ki arkası görünsün
	TweenService:Create(gradFrame, TweenInfo.new(0.3), {BackgroundTransparency = isGlass and 0.45 or 0}):Play()
	local grad = gradFrame:FindFirstChild("VexroMainGrad")
	if grad then
		local g = ThemeGradients[name] or ThemeGradients.Dark
		grad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, g[1]),
			ColorSequenceKeypoint.new(1, g[2]),
		}
		grad.Rotation = g[3]
	end
end

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.new(1, 1, 1) -- Gradient kullanılacak
mainStroke.Thickness = 3
mainStroke.Transparency = 0
mainStroke.Parent = main

mainStrokeGrad = Instance.new("UIGradient")
mainStrokeGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, currentTheme.stroke),
	ColorSequenceKeypoint.new(0.33, currentTheme.accent),
	ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
	ColorSequenceKeypoint.new(1, currentTheme.accent)
}
mainStrokeGrad.Parent = mainStroke

-- Animasyonu başlat
task.spawn(function()
	local rot = 0
	while mainStroke.Parent do
		rot = rot + 360
		TweenService:Create(mainStrokeGrad, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = rot}):Play()
		task.wait(2)
	end
end)

-- Background Particles
local bgParticles = Instance.new("Frame")
bgParticles.Name = "BgParticles"
bgParticles.Size = UDim2.new(1, 0, 1, 0)
bgParticles.BackgroundTransparency = 1
bgParticles.ZIndex = 1
bgParticles.Parent = main

for i = 1, 20 do
	local particle = Instance.new("Frame")
	local s = math.random(5, 12)
	particle.Size = UDim2.new(0, s, 0, s)
	particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
	particle.BackgroundColor3 = currentTheme.accent
	particle.BackgroundTransparency = math.random(4, 8) / 10
	particle.ZIndex = 1
	particle.Parent = bgParticles
	Instance.new("UICorner", particle).CornerRadius = UDim.new(1, 0)
	
	RegisterTheme(particle, "BackgroundColor3", "accent")
	
	task.spawn(function()
		while particle.Parent do
			TweenService:Create(particle, TweenInfo.new(math.random(4, 8), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				Position = UDim2.new(math.random(), 0, math.random(), 0)
			}):Play()
			task.wait(math.random(4, 8))
		end
	end)
end

-- ===============================================================
-- SIDEBAR
-- ===============================================================

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, sideBarW, 1, 0)
sidebar.BackgroundColor3 = currentTheme.sidebar
sidebar.ClipsDescendants = true
sidebar.ZIndex = 8
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 14)
RegisterTheme(sidebar, "BackgroundColor3", "sidebar")

local sideOverlay = Instance.new("Frame")
sideOverlay.Size = UDim2.new(0, 10, 1, 0)
sideOverlay.Position = UDim2.new(1, -10, 0, 0)
sideOverlay.BackgroundColor3 = currentTheme.sidebar
sideOverlay.BorderSizePixel = 0
sideOverlay.ZIndex = 7
sideOverlay.Parent = sidebar
RegisterTheme(sideOverlay, "BackgroundColor3", "sidebar")

local tabBtns = {}
local tabBtnS = math.floor((isMobile and 40 or 48) * BUTTON_SCALE)

local function CreateTabBtn(icon, tabName, yPos, customScale, rawImage)
	local isUrl = type(icon) == "string" and (string.find(icon, "rbxassetid://") or string.find(icon, "http") or string.find(icon, "rbxthumb://"))
	
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, tabBtnS, 0, tabBtnS)
	btn.Position = UDim2.new(0.5, -tabBtnS/2, 0, yPos)
	btn.BackgroundColor3 = currentTheme.sidebar
	btn.BackgroundTransparency = 0.8
	btn.Text = ""
	btn.TextSize = isMobile and 28 or 34
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = currentTheme.text
	btn.ZIndex = 9
	btn.Parent = sidebar
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = currentTheme.sidebar
	stroke.Thickness = 2
	stroke.Transparency = 0.7
	stroke.Parent = btn
	
	local imgElement = nil
	if isUrl then
		local img = Instance.new("ImageLabel")
		local s = (tabName == "emotes") and 0.85 or (0.95 * ICON_SCALE)
		img.Size = UDim2.fromScale(s, s)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.BackgroundTransparency = 1
		img.Image = rawImage or ResolveAssetImage(icon)
		img.ImageColor3 = currentTheme.text
		img.ZIndex = 110
		img.Parent = btn
		RegisterTheme(img, "ImageColor3", "text")
		imgElement = img
	else
		btn.Text = icon
		RegisterTheme(btn, "TextColor3", "text")
	end

	btn.MouseEnter:Connect(function()
		if currentTab ~= tabName then
			TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.7, BackgroundColor3 = currentTheme.stroke, Size = UDim2.new(0, tabBtnS + 2, 0, tabBtnS + 2)}):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, tabBtnS, 0, tabBtnS)
		}):Play()
	end)
	
	-- Quatrefoil indicator (MaterialYou theme - asset tabanlı)
	local qSize = tabBtnS + 10
	local quatrefoil = Instance.new("ImageLabel")
	quatrefoil.Name = "Quatrefoil"
	quatrefoil.Size = UDim2.new(0, qSize, 0, qSize)
	quatrefoil.Position = UDim2.new(0.5, -qSize/2, 0, yPos + tabBtnS/2 - qSize/2)
	quatrefoil.BackgroundTransparency = 1
	quatrefoil.Image = ResolveAssetImage(Icons.Quatrefoil)
	quatrefoil.ImageColor3 = currentTheme.accent
	quatrefoil.ImageTransparency = 0.3
	quatrefoil.ScaleType = Enum.ScaleType.Fit
	quatrefoil.ZIndex = 9
	quatrefoil.Visible = false
	quatrefoil.Parent = sidebar
	
	tabBtns[tabName] = {btn = btn, stroke = stroke, img = imgElement, quatrefoil = quatrefoil, yPos = yPos}
	return btn
end

CreateTabBtn(Icons.Emote, "emotes", 8)
CreateTabBtn(Icons.FavoriteFull, "favorites", 8 + tabBtnS + 6)
CreateTabBtn(Icons.Recent, "recent", 8 + (tabBtnS + 6) * 2)
CreateTabBtn("rbxassetid://115725480722697", "friends", 8 + (tabBtnS + 6) * 3)
if not isMobile then
	CreateTabBtn(Icons.Keybind, "keybinds", 8 + (tabBtnS + 6) * 4)
end
CreateTabBtn(Icons.Settings, "settings", isMobile and 8 + (tabBtnS + 6) * 4 or 8 + (tabBtnS + 6) * 5)

-- Sliding active-tab indicator (replaces per-btn gradient; hidden for MaterialYou)
local _indS = tabBtnS + 4
local _tabIndicator = Instance.new("Frame")
_tabIndicator.Name = "TabIndicator"
_tabIndicator.Size = UDim2.new(0, _indS, 0, _indS)
_tabIndicator.Position = UDim2.new(0.5, -_indS/2, 0, 8 - 2)
_tabIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
_tabIndicator.BackgroundTransparency = 0
_tabIndicator.ZIndex = 8
_tabIndicator.Parent = sidebar
Instance.new("UICorner", _tabIndicator).CornerRadius = UDim.new(0, 12)

local _indStroke = Instance.new("UIStroke")
_indStroke.Color = Color3.new(1, 1, 1)
_indStroke.Thickness = 1.5
_indStroke.Transparency = 0.15
_indStroke.Parent = _tabIndicator

local _indGrad = Instance.new("UIGradient")
_indGrad.Rotation = 90
_indGrad.Transparency = NumberSequence.new{
	NumberSequenceKeypoint.new(0, 0.25),
	NumberSequenceKeypoint.new(1, 0.72)
}
_indGrad.Parent = _tabIndicator

local function _UpdateIndicatorGrad()
	local acc = currentTheme.accent
	local topC = Color3.new(math.min(1, acc.R + 0.18), math.min(1, acc.G + 0.18), math.min(1, acc.B + 0.18))
	local botC = Color3.new(acc.R * 0.25, acc.G * 0.25, acc.B * 0.25)
	_indGrad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, topC),
		ColorSequenceKeypoint.new(1, botC)
	}
end
_UpdateIndicatorGrad()

-- ===============================================================
-- CONTENT
-- ===============================================================

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -sideBarW, 1, 0)
content.Position = UDim2.new(0, sideBarW, 0, 0)
content.BackgroundTransparency = 1
content.Parent = main

local titleH = isMobile and 38 or 46
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, titleH)
titleBar.BackgroundColor3 = currentTheme.secondary
titleBar.ZIndex = 5
titleBar.Parent = content
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)
RegisterTheme(titleBar, "BackgroundColor3", "secondary")

local titleOverlay = Instance.new("Frame")
titleOverlay.Size = UDim2.new(0, 14, 1, 0)
titleOverlay.BackgroundColor3 = currentTheme.secondary
titleOverlay.BorderSizePixel = 0
titleOverlay.ZIndex = 4
titleOverlay.Parent = titleBar
RegisterTheme(titleOverlay, "BackgroundColor3", "secondary")

local titleIconSz = math.floor((isMobile and 32 or 36) * ICON_SCALE)
local titleIcon = Instance.new("ImageLabel")
titleIcon.Size = UDim2.new(0, titleIconSz, 0, titleIconSz)
titleIcon.Position = UDim2.new(0, 10, 0.5, 0)
titleIcon.AnchorPoint = Vector2.new(0, 0.5)
titleIcon.BackgroundTransparency = 1
titleIcon.Image = ResolveAssetImage(Icons.Emote)
titleIcon.ImageColor3 = currentTheme.text
titleIcon.ZIndex = 6
titleIcon.Parent = titleBar
RegisterTheme(titleIcon, "ImageColor3", "text")

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -160, 1, 0)
title.Position = UDim2.new(0, 10 + titleIconSz + 6, 0, 0)
title.BackgroundTransparency = 1
title.Text = L.emotes
title.TextColor3 = currentTheme.text
title.Font = Enum.Font.GothamBold
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
title.Parent = titleBar
Instance.new("UITextSizeConstraint", title).MaxTextSize = isMobile and 16 or 20
RegisterTheme(title, "TextColor3", "text")

local _textGrads = {}
local function _ApplyTextGrad(grad)
	local name = Settings.theme
	local topColor, botColor
	if name == "Dark" or name == "DarkGlass" then
		topColor = Color3.fromRGB(20, 20, 28)
		botColor = Color3.new(1, 1, 1)
	elseif name == "Light" or name == "FrostedGlass" then
		topColor = Color3.fromRGB(20, 20, 30)
		botColor = currentTheme.accent
	else
		topColor = currentTheme.accent
		botColor = Color3.new(1, 1, 1)
	end
	grad.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, topColor),
		ColorSequenceKeypoint.new(1, botColor)
	}
	grad.Rotation = 90
end
local function _AddTextGrad(textLabel)
	local g = Instance.new("UIGradient")
	_ApplyTextGrad(g)
	g.Parent = textLabel
	table.insert(_textGrads, g)
	return g
end
_updateTitleGrad = function()
	for i = #_textGrads, 1, -1 do
		local g = _textGrads[i]
		if g and g.Parent then
			_ApplyTextGrad(g)
		else
			table.remove(_textGrads, i)
		end
	end
end
_AddTextGrad(title)

local btnS = math.floor((isMobile and 28 or 36) * BUTTON_SCALE)

local function MakeBtn(icon, px, colorKey, customSize)
	local s = customSize or btnS
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0, s, 0, s)
	b.Position = UDim2.new(1, px, 0.5, -s/2)
	b.BackgroundColor3 = currentTheme.tertiary
	b.Text = ""
	b.ZIndex = 10
	b.Parent = titleBar
	Instance.new("UICorner", b).CornerRadius = UDim.new(0.25, 0)
	
	local useWhite = (colorKey == "critical" or colorKey == "accent" or colorKey == "success")
	
	local isImg = type(icon) == "string" and (string.find(icon, "rbxassetid://") or string.find(icon, "http") or string.find(icon, "rbxthumb://"))
	if isImg then
		local img = Instance.new("ImageLabel")
		img.Size = UDim2.new(0, math.floor(42 * ICON_SCALE), 0, math.floor(42 * ICON_SCALE))
		img.Position = UDim2.new(0.5, 0, 0.5, 0)
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.BackgroundTransparency = 1
		img.Parent = b
		img.Image = ResolveAssetImage(icon)
		img.ImageColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
		img.ZIndex = 110
		if not useWhite then
			RegisterTheme(img, "ImageColor3", "text")
		end
	else
		-- Minus için bold metin kullan (Görünürlük için en iyisi)
		if icon == "STOP_SHAPE" then
			b.Text = ""
			local sq = Instance.new("ImageLabel")
			sq.Size = UDim2.new(0.75, 0, 0.75, 0)
			sq.Position = UDim2.new(0.5, 0, 0.5, 0)
			sq.AnchorPoint = Vector2.new(0.5, 0.5)
			sq.BackgroundTransparency = 1
			sq.Image = ResolveAssetImage("rbxassetid://113416463749658")
			sq.ImageColor3 = Color3.new(1, 1, 1)
			sq.ScaleType = Enum.ScaleType.Fit
			sq.ZIndex = 110
			sq.Parent = b
		elseif icon == "CLOSE_SHAPE" then
			b.Text = ""
			local line1 = Instance.new("Frame")
			line1.BorderSizePixel = 0
			line1.Size = UDim2.new(0.40, 0, 0, math.floor(2 * math.max(1, ICON_SCALE))) -- Fixed: Reduced X size
			line1.Position = UDim2.new(0.5, 0, 0.5, 0)
			line1.AnchorPoint = Vector2.new(0.5, 0.5)
			line1.Rotation = 45
			line1.BackgroundColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
			line1.ZIndex = 110
			line1.Parent = b
			Instance.new("UICorner", line1).CornerRadius = UDim.new(0, 2)
			
			local line2 = line1:Clone()
			line2.Rotation = -45
			line2.Parent = b
			
			if not useWhite then
				RegisterTheme(line1, "BackgroundColor3", "text")
				RegisterTheme(line2, "BackgroundColor3", "text")
			end
		elseif icon == Icons.Minus or icon == "-" then
			b.Text = ""
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.Size = UDim2.new(0.40, 0, 0, math.floor(2 * math.max(1, ICON_SCALE))) -- Fixed: Reduced Minus size
			line.Position = UDim2.new(0.5, 0, 0.5, 0)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
			line.ZIndex = 110
			line.Parent = b
			Instance.new("UICorner", line).CornerRadius = UDim.new(0, 2)
			if not useWhite then
				RegisterTheme(line, "BackgroundColor3", "text")
			end
		elseif icon == Icons.Sort then
			b.Text = icon
			b.TextSize = math.floor((isMobile and 32 or 46) * FONT_SCALE)
		else
			b.Text = icon
			b.TextSize = math.floor((isMobile and 12 or 16) * FONT_SCALE)
		end
		b.TextColor3 = useWhite and Color3.new(1, 1, 1) or currentTheme.text
		b.Font = Enum.Font.GothamBlack
		if not useWhite then
			RegisterTheme(b, "TextColor3", "text")
		end
	end

	b.MouseEnter:Connect(function()
		local s = customSize or btnS
		TweenService:Create(b, TweenInfo.new(0.1), {
			Size = UDim2.new(0, s + 4, 0, s + 4),
			Position = UDim2.new(1, px - 2, 0.5, -(s + 4)/2)
		}):Play()
	end)
	b.MouseLeave:Connect(function()
		local s = customSize or btnS
		TweenService:Create(b, TweenInfo.new(0.1), {
			Size = UDim2.new(0, s, 0, s),
			Position = UDim2.new(1, px, 0.5, -s/2)
		}):Play()
	end)
	return b
end

local copyEmoteBtn = MakeBtn("rbxassetid://77508802666652", -(btnS*5 + 24), "critical")
local stopBtn = MakeBtn("STOP_SHAPE", -(btnS*4 + 18), "critical")
local randBtn = MakeBtn(Icons.Sort, -(btnS*3 + 12), "accent")
local minBtn = MakeBtn("-", -(btnS*2 + 6), "textDim")
local closeBtn = MakeBtn("CLOSE_SHAPE", -(btnS + 2), "critical")

if Settings.copyEmoteEnabled then
	RegisterTheme(copyEmoteBtn, "BackgroundColor3", "success")
else
	RegisterTheme(copyEmoteBtn, "BackgroundColor3", "tertiary")
end
RegisterTheme(stopBtn, "BackgroundColor3", "tertiary")
RegisterTheme(randBtn, "BackgroundColor3", "accent")
RegisterTheme(minBtn, "BackgroundColor3", "stroke")
RegisterTheme(closeBtn, "BackgroundColor3", "critical")

local _isPaused = false
-- stopBtn içindeki stop karesi (duraklat/devam durumuna göre gizlenir)
local _stopBtnSquare = stopBtn:FindFirstChildWhichIsA("ImageLabel")

local _pauseTextSize = math.floor((isMobile and 14 or 18) * (ICON_SCALE or 1))

local function _SetPauseState(paused)
	_isPaused = paused
	-- stopBtn görselini güncelle: duraklat = kare gizli + ">" yaz, devam = kare göster
	if _stopBtnSquare then
		_stopBtnSquare.Image = paused and ResolveAssetImage("rbxassetid://129338178452237") or ResolveAssetImage("rbxassetid://113416463749658")
	end
	-- HUD duraklat butonunu güncelle (bridge)
	if _onPauseStateChanged then _onPauseStateChanged(paused) end
end

stopBtn.MouseButton1Click:Connect(function()
	-- Onceligi duraklat halini kontrol etmeye ver (hiz=0 oldugu icin IsPlaying hala true)
	if currentAnimTrack and _isPaused then
		-- Duraklatilmissa devam ettir
		pcall(function() currentAnimTrack:AdjustSpeed(Settings.speed) end)
		_SetPauseState(false)
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		-- Calan emoteyi mevcut pozisyonda dondur (hiz=0)
		pcall(function() currentAnimTrack:AdjustSpeed(0) end)
		_SetPauseState(true)
	else
		StopEmote(true)
	end
end)
randBtn.MouseButton1Click:Connect(function()
	if #currentData > 0 then
		local r = currentData[math.random(#currentData)]
		local speedTxt = Settings.speed ~= 1 and " (" .. Settings.speed .. "x)" or ""
		Notify("[~] " .. L.playing .. speedTxt, r.name)
		PlayEmote(r.id, r.name, true) -- Passing true to silence the default notification
	end
end)

local searchH = isMobile and 32 or 38
local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -16, 0, searchH)
search.Position = UDim2.new(0, 8, 0, titleH + 6)
search.BackgroundColor3 = currentTheme.tertiary
search.PlaceholderText = L.search
search.PlaceholderColor3 = currentTheme.textDim
search.Text = ""
search.TextColor3 = currentTheme.text
search.TextSize = isMobile and 13 or 15
search.Font = Enum.Font.Gotham
search.ZIndex = 5
search.ClearTextOnFocus = false
search.Parent = content
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 10)
Instance.new("UIPadding", search).PaddingLeft = UDim.new(0, 10)
RegisterTheme(search, "BackgroundColor3", "tertiary")
RegisterTheme(search, "TextColor3", "text")

local pageH = isMobile and 30 or 36
local pageBar = Instance.new("Frame")
pageBar.Size = UDim2.new(1, -16, 0, pageH)
pageBar.Position = UDim2.new(0, 8, 1, -(pageH + bottomBarH + 8))
pageBar.BackgroundColor3 = currentTheme.secondary
pageBar.ZIndex = 5
pageBar.Parent = content
Instance.new("UICorner", pageBar).CornerRadius = UDim.new(0, 10)
RegisterTheme(pageBar, "BackgroundColor3", "secondary")

local pageBtnW = isMobile and 45 or 60

local prevBtn = Instance.new("TextButton")
prevBtn.Size = UDim2.new(0, pageBtnW, 1, -4)
prevBtn.Position = UDim2.new(0, 2, 0, 2)
prevBtn.BackgroundColor3 = currentTheme.accent
prevBtn.Text = ""
prevBtn.ZIndex = 6
prevBtn.Parent = pageBar
Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0, 8)
RegisterTheme(prevBtn, "BackgroundColor3", "accent")

local function CreateChevron(parent, isNext)
	local container = Instance.new("Frame")
	container.Name = "ChevronIcon"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ZIndex = 7
	container.Parent = parent
	
	local effScale = math.min(ICON_SCALE, 1.4)
	local len = math.floor(14 * effScale)
	local thick = math.floor(1.6 * math.max(1, effScale))
	local offset = math.floor(len * 0.353)
	
	local tipX = isNext and offset or -offset
	local dx = isNext and -offset or offset
	
	local topL = Instance.new("Frame")
	topL.BorderSizePixel = 0
	topL.Size = UDim2.new(0, len, 0, thick)
	topL.AnchorPoint = Vector2.new(0.5, 0.5)
	topL.Position = UDim2.new(0.5, tipX + dx, 0.5, -offset)
	topL.Rotation = isNext and 45 or -45
	topL.BackgroundColor3 = Color3.new(1, 1, 1)
	topL.ZIndex = 7
	topL.Parent = container
	Instance.new("UICorner", topL).CornerRadius = UDim.new(0, 2)
	
	local botL = Instance.new("Frame")
	botL.BorderSizePixel = 0
	botL.Size = UDim2.new(0, len, 0, thick)
	botL.AnchorPoint = Vector2.new(0.5, 0.5)
	botL.Position = UDim2.new(0.5, tipX + dx, 0.5, offset)
	botL.Rotation = isNext and -45 or 45
	botL.BackgroundColor3 = Color3.new(1, 1, 1)
	botL.ZIndex = 7
	botL.Parent = container
	Instance.new("UICorner", botL).CornerRadius = UDim.new(0, 2)
end

local nextBtn = prevBtn:Clone()
nextBtn.Position = UDim2.new(1, -(pageBtnW + 2), 0, 2)
nextBtn.Parent = pageBar

CreateChevron(prevBtn, false)
CreateChevron(nextBtn, true)
RegisterTheme(nextBtn, "BackgroundColor3", "accent")

local pageNum = Instance.new("TextLabel")
pageNum.Size = UDim2.new(1, -(pageBtnW*2 + 16), 1, 0)
pageNum.Position = UDim2.new(0, pageBtnW + 8, 0, 0)
pageNum.BackgroundTransparency = 1
pageNum.Text = "1/1"
pageNum.TextColor3 = currentTheme.textDim
pageNum.Font = Enum.Font.GothamBold
pageNum.TextScaled = true
pageNum.ZIndex = 6
pageNum.Parent = pageBar
RegisterTheme(pageNum, "TextColor3", "textDim")

local emptyLbl = Instance.new("TextLabel")
emptyLbl.Size = UDim2.new(1, -20, 0, 50)
emptyLbl.Position = UDim2.fromScale(0.5, 0.45)
emptyLbl.AnchorPoint = Vector2.new(0.5, 0.5)
emptyLbl.BackgroundTransparency = 1
emptyLbl.Text = ""
emptyLbl.TextColor3 = currentTheme.textDim
emptyLbl.Font = Enum.Font.GothamBold
emptyLbl.TextScaled = true
emptyLbl.Visible = false
emptyLbl.ZIndex = 5
emptyLbl.Parent = content
RegisterTheme(emptyLbl, "TextColor3", "textDim")

-- ===============================================================
-- SETTINGS PANEL
-- ===============================================================

local settingsPanel = Instance.new("ScrollingFrame")
settingsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
settingsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
settingsPanel.BackgroundTransparency = 1
settingsPanel.ScrollBarThickness = isMobile and 6 or 4
settingsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
settingsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
settingsPanel.Visible = false
settingsPanel.ZIndex = 5
settingsPanel.Parent = content

local settingsLayout = Instance.new("UIListLayout")
settingsLayout.Padding = UDim.new(0, 6)
settingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
settingsLayout.Parent = settingsPanel

local friendsPanel = Instance.new("ScrollingFrame")
friendsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
friendsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
friendsPanel.BackgroundTransparency = 1
friendsPanel.ScrollBarThickness = isMobile and 6 or 4
friendsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
friendsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
friendsPanel.Visible = false
friendsPanel.ZIndex = 5
friendsPanel.Parent = content
local friendsPanelLayout = Instance.new("UIListLayout")
friendsPanelLayout.Padding = UDim.new(0, 10)
friendsPanelLayout.Parent = friendsPanel

local keybindsPanel = Instance.new("ScrollingFrame")
keybindsPanel.Size = UDim2.new(1, -16, 1, -(titleH + bottomBarH + 20))
keybindsPanel.Position = UDim2.new(0, 8, 0, titleH + 8)
keybindsPanel.BackgroundTransparency = 1
keybindsPanel.ScrollBarThickness = isMobile and 6 or 4
keybindsPanel.AutomaticCanvasSize = Enum.AutomaticSize.Y
keybindsPanel.CanvasSize = UDim2.new(0, 0, 0, 0)
keybindsPanel.Visible = false
keybindsPanel.ZIndex = 5
keybindsPanel.Parent = content
local keybindsPanelLayout = Instance.new("UIListLayout")
keybindsPanelLayout.Padding = UDim.new(0, 8)
keybindsPanelLayout.Parent = keybindsPanel

local RefreshKeybindsPanel  -- forward declaration (defined after ShowKeybindDialog)

-- ---------------------------------------------------------------
-- Yardımcı: bölüm başlığı
-- ---------------------------------------------------------------
MakeSectionHeader = function(text, order)
	-- Frame kullanmak zorundayız: TextLabel UIListLayout LayoutOrder'ı görmezden gelebiliyor
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 26)
	container.BackgroundTransparency = 1
	container.LayoutOrder = order
	container.ZIndex = 6
	container.Parent = settingsPanel

	local hdr = Instance.new("TextLabel")
	hdr.Size = UDim2.new(1, -4, 1, 0)
	hdr.BackgroundTransparency = 1
	hdr.Text = text:upper()
	hdr.TextColor3 = currentTheme.accent
	hdr.Font = Enum.Font.GothamBold
	hdr.TextSize = 11
	hdr.TextXAlignment = Enum.TextXAlignment.Left
	hdr.ZIndex = 7
	hdr.Parent = container
	RegisterTheme(hdr, "TextColor3", "accent")
	return container
end

-- ---------------------------------------------------------------
-- Yardımcı: ayar satırı (ikon + başlık + opsiyonel açıklama)
-- ---------------------------------------------------------------
MakeRow = function(imgId, title, subtitle, order, customH)
	local iconBoxSz = isMobile and 46 or 54
	local hasDesc = subtitle and subtitle ~= ""
	local h = customH or (hasDesc and 72 or 60)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, h)
	row.BackgroundColor3 = currentTheme.secondary
	row.LayoutOrder = order
	row.ZIndex = 6
	row.Parent = settingsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 14)
	RegisterTheme(row, "BackgroundColor3", "secondary")

	local leftPad = 12
	if imgId and imgId ~= "" then
		local iconBox = Instance.new("Frame")
		iconBox.Size = UDim2.new(0, iconBoxSz, 0, iconBoxSz)
		iconBox.AnchorPoint = Vector2.new(0, 0.5)
		iconBox.Position = UDim2.new(0, leftPad, 0.5, 0)
		iconBox.BackgroundColor3 = currentTheme.tertiary
		iconBox.ZIndex = 7
		iconBox.Parent = row
		Instance.new("UICorner", iconBox).CornerRadius = UDim.new(0, 9)
		RegisterTheme(iconBox, "BackgroundColor3", "tertiary")

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0.72, 0, 0.72, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Image = ResolveAssetImage("rbxassetid://" .. imgId)
		icon.ImageColor3 = currentTheme.accent
		icon.ZIndex = 8
		icon.Parent = iconBox
		RegisterTheme(icon, "ImageColor3", "accent")
	end

	local textLeft = (imgId and imgId ~= "") and (leftPad + iconBoxSz + 10) or leftPad
	local rightGap = 72

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = title
	titleLbl.TextColor3 = currentTheme.text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = isMobile and 13 or 14
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.ZIndex = 7
	titleLbl.Parent = row
	RegisterTheme(titleLbl, "TextColor3", "text")

	if hasDesc then
		titleLbl.Size = UDim2.new(1, -(textLeft + rightGap), 0, 20)
		titleLbl.Position = UDim2.new(0, textLeft, 0, 12)

		local subLbl = Instance.new("TextLabel")
		subLbl.Size = UDim2.new(1, -(textLeft + rightGap), 0, 18)
		subLbl.Position = UDim2.new(0, textLeft, 0, 33)
		subLbl.BackgroundTransparency = 1
		subLbl.Text = subtitle
		subLbl.TextColor3 = currentTheme.textDim
		subLbl.Font = Enum.Font.Gotham
		subLbl.TextSize = isMobile and 10 or 11
		subLbl.TextXAlignment = Enum.TextXAlignment.Left
		subLbl.TextWrapped = true
		subLbl.ZIndex = 7
		subLbl.Parent = row
		RegisterTheme(subLbl, "TextColor3", "textDim")
	else
		titleLbl.Size = UDim2.new(1, -(textLeft + rightGap), 1, 0)
		titleLbl.Position = UDim2.new(0, textLeft, 0, 0)
	end

	return row
end

-- ---------------------------------------------------------------
-- Yardımcı: pill toggle anahtarı
-- ---------------------------------------------------------------
MakePillToggle = function(parent, value, onChange)
	local pillW, pillH, pad = 50, 28, 3
	local knobSz = pillH - pad * 2

	local pill = Instance.new("Frame")
	pill.Size = UDim2.new(0, pillW, 0, pillH)
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -12, 0.5, 0)
	pill.BackgroundColor3 = value and currentTheme.success or currentTheme.stroke
	pill.ZIndex = 8
	pill.Parent = parent
	Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, knobSz, 0, knobSz)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = value
		and UDim2.new(1, -(knobSz + pad), 0.5, 0)
		or  UDim2.new(0, pad, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.ZIndex = 9
	knob.Parent = pill
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local state = value
	local pillBtn = Instance.new("TextButton")
	pillBtn.Size = UDim2.fromScale(1, 1)
	pillBtn.BackgroundTransparency = 1
	pillBtn.Text = ""
	pillBtn.ZIndex = 10
	pillBtn.Parent = pill

	local function SetState(v)
		state = v
		TweenService:Create(pill, TweenInfo.new(0.22), {
			BackgroundColor3 = v and currentTheme.success or currentTheme.stroke
		}):Play()
		TweenService:Create(knob, TweenInfo.new(0.22, Enum.EasingStyle.Back), {
			Position = v and UDim2.new(1, -(knobSz + pad), 0.5, 0) or UDim2.new(0, pad, 0.5, 0)
		}):Play()
	end

	pillBtn.MouseButton1Click:Connect(function()
		state = not state
		SetState(state)
		onChange(state)
	end)

	return SetState
end

-- ===============================================================
-- GÖRÜNÜM
-- ===============================================================
MakeSectionHeader(isTR and "Görünüm" or (isES and "Apariencia" or (isAR and "المظهر" or (isFR and "Apparence" or (isHI and "दिखावट" or (isPT and "Aparência" or (isRU and "Внешний вид" or "Appearance")))))), 1)

-- Tema
do
	local themeRow = MakeRow("110192525313214", L.theme, "", 2)
	local themeNames = {"Dark", "Purple", "Blue", "Green", "Red", "Light", "MaterialYou", "FrostedGlass", "DarkGlass"}

	local chip = Instance.new("TextButton")
	chip.Size = UDim2.new(0, 80, 0, 30)
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -12, 0.5, 0)
	chip.BackgroundColor3 = currentTheme.accent
	chip.Text = Settings.theme
	chip.TextColor3 = Color3.new(1, 1, 1)
	chip.Font = Enum.Font.GothamBold
	chip.TextSize = isMobile and 10 or 11
	chip.ZIndex = 8
	chip.Parent = themeRow
	Instance.new("UICorner", chip).CornerRadius = UDim.new(1, 0)
	RegisterTheme(chip, "BackgroundColor3", "accent")

	local themeIdx = 1
	for i, n in ipairs(themeNames) do if n == Settings.theme then themeIdx = i end end

	chip.MouseButton1Click:Connect(function()
		themeIdx = themeIdx % #themeNames + 1
		Settings.theme = themeNames[themeIdx]
		chip.Text = Settings.theme
		ApplyTheme(Settings.theme)
		SaveData()
	end)
end

-- Hız
do
	local speedRow = MakeRow("113837085020684", L.speed, "", 3, 78)
	local speeds = {0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3}
	local speedIdx = 4
	for i, s in ipairs(speeds) do if s == Settings.speed then speedIdx = i end end

	local speedLbl = Instance.new("TextLabel")
	speedLbl.Size = UDim2.new(0, 48, 0, 28)
	speedLbl.AnchorPoint = Vector2.new(1, 0)
	speedLbl.Position = UDim2.new(1, -12, 0, 12)
	speedLbl.BackgroundTransparency = 1
	speedLbl.Text = Settings.speed .. "x"
	speedLbl.TextColor3 = currentTheme.accent
	speedLbl.Font = Enum.Font.GothamBlack
	speedLbl.TextSize = isMobile and 14 or 15
	speedLbl.TextXAlignment = Enum.TextXAlignment.Right
	speedLbl.ZIndex = 8
	speedLbl.Parent = speedRow
	RegisterTheme(speedLbl, "TextColor3", "accent")

	local iconBoxSz = isMobile and 46 or 54
	local sliderLeft = 12 + iconBoxSz + 10
	local sliderBg = Instance.new("Frame")
	sliderBg.Size = UDim2.new(1, -(sliderLeft + 12), 0, 6)
	sliderBg.Position = UDim2.new(0, sliderLeft, 1, -20)
	sliderBg.BackgroundColor3 = currentTheme.tertiary
	sliderBg.ZIndex = 8
	sliderBg.Parent = speedRow
	Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
	RegisterTheme(sliderBg, "BackgroundColor3", "tertiary")

	local sliderFill = Instance.new("Frame")
	sliderFill.Size = UDim2.new(0, 0, 1, 0)
	sliderFill.BackgroundColor3 = currentTheme.accent
	sliderFill.ZIndex = 9
	sliderFill.Parent = sliderBg
	Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
	RegisterTheme(sliderFill, "BackgroundColor3", "accent")

	local sliderKnob = Instance.new("TextButton")
	sliderKnob.Size = UDim2.new(0, 18, 0, 18)
	sliderKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	sliderKnob.Position = UDim2.new(0, 0, 0.5, 0)
	sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1)
	sliderKnob.Text = ""
	sliderKnob.ZIndex = 10
	sliderKnob.Parent = sliderBg
	Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)

	local function UpdateSpeedUI()
		Settings.speed = speeds[speedIdx]
		speedLbl.Text = Settings.speed .. "x"
		local alpha = (speedIdx - 1) / (#speeds - 1)
		TweenService:Create(sliderFill, TweenInfo.new(0.2), {Size = UDim2.new(alpha, 0, 1, 0)}):Play()
		TweenService:Create(sliderKnob, TweenInfo.new(0.2), {Position = UDim2.new(alpha, 0, 0.5, 0)}):Play()
		SaveData()
		ApplySpeedToAllTracks()
		if _onSpeedChanged then _onSpeedChanged() end
	end

	local sliderDragging = false
	sliderKnob.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = true
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
			sliderDragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if sliderDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
			local ax = math.clamp((inp.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
			local ni = math.floor(ax * (#speeds - 1) + 1.5)
			if ni ~= speedIdx then speedIdx = ni; UpdateSpeedUI() end
		end
	end)

	UpdateSpeedUI()
end

-- ===============================================================
-- DAVRANIŞ
-- ===============================================================
MakeSectionHeader(isTR and "Davranış" or (isES and "Comportamiento" or (isAR and "السلوك" or (isFR and "Comportement" or (isHI and "व्यवहार" or (isPT and "Comportamento" or (isRU and "Поведение" or "Behaviour")))))), 9)

-- Bildirimler
do
	local row = MakeRow("99427666057293", L.notif, "", 10)
	MakePillToggle(row, Settings.notifications, function(v)
		Settings.notifications = v
		SaveData()
	end)
end

-- Döngü
do
	local row = MakeRow("103179694587186", L.loopText or "Loop", "", 11)
	MakePillToggle(row, Settings.loopEmote, function(v)
		Settings.loopEmote = v
		_genv().autoReloadEnabled_Vexro = v
		SaveData()
	end)
end

-- Yürüyünce Durdur
do
	local row = MakeRow("", L.stopOnWalk, L.stopOnWalkDesc, 12)
	MakePillToggle(row, Settings.stopOnWalk, function(v)
		Settings.stopOnWalk = v
		SaveData()
	end)
end

-- Oynatma Barı
do
	local row = MakeRow("", L.showHUD, L.showHUDDesc, 13)
	MakePillToggle(row, Settings.showHUD, function(v)
		Settings.showHUD = v
		if not v then HideEmoteHUD() end
		SaveData()
	end)
end

-- ===============================================================
-- GENEL
-- ===============================================================
MakeSectionHeader(isTR and "Genel" or (isES and "General" or (isAR and "عام" or (isFR and "Général" or (isHI and "सामान्य" or (isPT and "Geral" or (isRU and "Общее" or "General")))))), 19)

-- Dil Sıfırla
do
	local row = MakeRow("76975628127992", L.resetLangLbl, L.resetLangDesc, 20)

	local resetBtn = Instance.new("TextButton")
	resetBtn.Size = UDim2.new(0, 62, 0, 30)
	resetBtn.AnchorPoint = Vector2.new(1, 0.5)
	resetBtn.Position = UDim2.new(1, -12, 0.5, 0)
	resetBtn.BackgroundColor3 = currentTheme.critical
	resetBtn.Text = "Reset"
	resetBtn.TextColor3 = Color3.new(1, 1, 1)
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextSize = isMobile and 11 or 12
	resetBtn.ZIndex = 8
	resetBtn.Parent = row
	Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 10)
	RegisterTheme(resetBtn, "BackgroundColor3", "critical")

	resetBtn.MouseButton1Click:Connect(function()
		Settings.language = nil
		SaveData()
		gui:Destroy()
		pcall(function()
			if _genv().lastVexroEmote then _genv().lastVexroEmote = nil end
		end)
		loadstring(game:HttpGet("https://raw.githubusercontent.com/zyrovell/Vexro/main/vexroemotes.lua"))()
	end)
end


local PROMPT_TAG = "VexroCopyEmotePrompt"

local function MakeCopyPrompt(targetChar)
	local root = targetChar:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if root:FindFirstChild(PROMPT_TAG) then return end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name              = PROMPT_TAG
	prompt.ActionText        = L.copyEmote
	prompt.ObjectText        = ""
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration      = 0
	prompt.RequiresLineOfSight = false
	prompt.Enabled           = true
	prompt.Parent            = root
	prompt.Triggered:Connect(function()
		local h = targetChar:FindFirstChildOfClass("Humanoid")
		if not h then return end
		local anim = h:FindFirstChildOfClass("Animator")
		if not anim then return end
		for _, track in ipairs(anim:GetPlayingAnimationTracks()) do
			local animId = tonumber(track.Animation.AnimationId:match("%d+"))
			if animId and EmotesById[animId] then
				PlayEmote(animId, EmotesById[animId].name)
				return
			end
		end
	end)
end

local function RemoveCopyPrompt(targetChar)
	local root = targetChar:FindFirstChild("HumanoidRootPart")
	if root then
		local p = root:FindFirstChild(PROMPT_TAG)
		if p then p:Destroy() end
	end
end

local _copyEmoteConns = {}

local function EnableCopyEmotePrompts()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			MakeCopyPrompt(p.Character)
		end
	end
	_copyEmoteConns[#_copyEmoteConns + 1] = Players.PlayerAdded:Connect(function(p)
		_copyEmoteConns[#_copyEmoteConns + 1] = p.CharacterAdded:Connect(function(char)
			if Settings.copyEmoteEnabled then MakeCopyPrompt(char) end
		end)
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			_copyEmoteConns[#_copyEmoteConns + 1] = p.CharacterAdded:Connect(function(char)
				if Settings.copyEmoteEnabled then MakeCopyPrompt(char) end
			end)
		end
	end
end

local function DisableCopyEmotePrompts()
	for _, conn in ipairs(_copyEmoteConns) do conn:Disconnect() end
	_copyEmoteConns = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			RemoveCopyPrompt(p.Character)
		end
	end
end

if Settings.copyEmoteEnabled then
	EnableCopyEmotePrompts()
end

copyEmoteBtn.MouseButton1Click:Connect(function()
	Settings.copyEmoteEnabled = not Settings.copyEmoteEnabled
	TweenService:Create(copyEmoteBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = Settings.copyEmoteEnabled and currentTheme.success or currentTheme.critical
	}):Play()
	if Settings.copyEmoteEnabled then
		EnableCopyEmotePrompts()
	else
		DisableCopyEmotePrompts()
	end
	SaveData()
end)

-- ===============================================================
-- ===============================================================
-- ARKADAŞ & BERABER EMOTE SİSTEMİ
-- ===============================================================
local friendAddModeBtn
local _syncLock = false
do
local ATTR_REQ  = "VFR_Req"   -- "<targetUserId>"
local ATTR_RESP = "VFR_Resp"  -- "<senderId>:1|0"
local ATTR_SYNC = "VFR_Sync"  -- "<emoteId>|<emoteName>"
local ATTR_STOP = "VFR_Stop"  -- tick() as string

-- Spam koruması
local REQ_COOLDOWN        = 5   -- aynı kişiye tekrar istek için bekleme (sn)
local REQ_SPAM_WINDOW     = 5   -- spam penceresi (sn)
local REQ_SPAM_LIMIT      = 3   -- bu kadar hızlı istek → timeout
local REQ_TIMEOUT_DUR     = 30  -- timeout süresi (sn)
local INCOMING_COOLDOWN   = 5   -- aynı kişiden gelen isteği tekrar gösterme eşiği (sn)

local _reqCooldowns      = {}   -- [targetUserId] = lastSendTime
local _reqSpamStart      = 0
local _reqSpamCount      = 0
local _reqTimeoutUntil   = 0   -- timeout bitiş zamanı
local _incomingCooldowns = {}  -- [senderUserId] = lastReceivedTime

-- Kaydet / Yükle
local function _SaveFriend()
	pcall(function()
		local enc = HttpService:JSONEncode({
			friends        = FriendData.friends,
			autoReject     = FriendData.autoReject,
			acceptRequests = FriendData.acceptRequests,
			playFriendEmote = FriendData.playFriendEmote,
			syncEmote      = FriendData.syncEmote,
		})
		_genv().VexroFriendSave = enc
	end)
end

local function _LoadFriend()
	pcall(function()
		local raw = _genv().VexroFriendSave
		if not raw then return end
		local ok, d = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then return end
		FriendData.friends        = d.friends or {}
		FriendData.autoReject     = d.autoReject or false
		FriendData.acceptRequests = d.acceptRequests ~= false
		FriendData.playFriendEmote = d.playFriendEmote ~= false
		FriendData.syncEmote      = d.syncEmote ~= false
	end)
end
_LoadFriend()

-- Kendi karakterine attr yaz
local function _MyAttr(attr, val)
	pcall(function()
		local c = player.Character
		if c then c:SetAttribute(attr, val) end
	end)
end

-- Gelen istek paneli
ShowFriendRequestPanel = function(senderUserId, senderName)
	-- Arka plan karartıcı
	local dimmer = Instance.new("Frame")
	dimmer.Size = UDim2.new(1,0,1,0)
	dimmer.BackgroundColor3 = Color3.new(0,0,0)
	dimmer.BackgroundTransparency = 0.45
	dimmer.ZIndex = 98000
	dimmer.Parent = gui

	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0, 340, 0, 215)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = currentTheme.secondary
	panel.ZIndex = 98001
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
	local ps = Instance.new("UIStroke", panel); ps.Color = currentTheme.stroke; ps.Thickness = 1.5

	-- Brand
	local brand = Instance.new("TextLabel")
	brand.Size = UDim2.new(1, 0, 0, 20); brand.Position = UDim2.new(0,0,0,8)
	brand.BackgroundTransparency = 1; brand.Text = "Vexro Emote Player"
	brand.TextColor3 = currentTheme.accent; brand.Font = Enum.Font.GothamBold
	brand.TextSize = 11; brand.ZIndex = 98002; brand.Parent = panel

	-- Avatar
	local av = Instance.new("ImageLabel")
	av.Size = UDim2.new(0,48,0,48); av.Position = UDim2.new(0,14,0,34)
	av.BackgroundTransparency = 1
	av.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(senderUserId) .. "&w=150&h=150"
	av.ZIndex = 98002; av.Parent = panel
	Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

	-- İstek metni
	local reqTxt = Instance.new("TextLabel")
	reqTxt.Size = UDim2.new(1,-80,0,48); reqTxt.Position = UDim2.new(0,70,0,34)
	reqTxt.BackgroundTransparency = 1
	reqTxt.Text = tostring(senderName) .. " sizi arkadaş eklemek istiyor."
	reqTxt.TextColor3 = currentTheme.text; reqTxt.Font = Enum.Font.Gotham
	reqTxt.TextSize = 12; reqTxt.TextWrapped = true
	reqTxt.TextXAlignment = Enum.TextXAlignment.Left
	reqTxt.TextYAlignment = Enum.TextYAlignment.Center
	reqTxt.ZIndex = 98002; reqTxt.Parent = panel

	-- Otomatik reddet barı
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1,-28,0,34); bar.Position = UDim2.new(0,14,0,90)
	bar.BackgroundColor3 = currentTheme.tertiary; bar.ZIndex = 98002; bar.Parent = panel
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0,10)

	local cbBtn = Instance.new("TextButton")
	cbBtn.Size = UDim2.new(0,20,0,20); cbBtn.Position = UDim2.new(0,7,0.5,-10)
	cbBtn.BackgroundColor3 = currentTheme.secondary; cbBtn.Text = ""; cbBtn.ZIndex = 98003; cbBtn.Parent = bar
	Instance.new("UICorner", cbBtn).CornerRadius = UDim.new(1,0)
	local cbStroke = Instance.new("UIStroke", cbBtn); cbStroke.Color = currentTheme.stroke; cbStroke.Thickness = 1.5

	local cbDot = Instance.new("Frame")
	cbDot.Size = UDim2.new(0,10,0,10); cbDot.AnchorPoint = Vector2.new(0.5,0.5)
	cbDot.Position = UDim2.new(0.5,0,0.5,0); cbDot.BackgroundColor3 = currentTheme.accent
	cbDot.Visible = FriendData.autoReject; cbDot.ZIndex = 98004; cbDot.Parent = cbBtn
	Instance.new("UICorner", cbDot).CornerRadius = UDim.new(1,0)

	local autoLbl = Instance.new("TextLabel")
	autoLbl.Size = UDim2.new(1,-34,1,0); autoLbl.Position = UDim2.new(0,32,0,0)
	autoLbl.BackgroundTransparency = 1; autoLbl.Text = L.autoRejectLbl
	autoLbl.TextColor3 = currentTheme.textDim; autoLbl.Font = Enum.Font.Gotham
	autoLbl.TextSize = 11; autoLbl.TextXAlignment = Enum.TextXAlignment.Left
	autoLbl.ZIndex = 98003; autoLbl.Parent = bar

	cbBtn.MouseButton1Click:Connect(function()
		FriendData.autoReject = not FriendData.autoReject
		cbDot.Visible = FriendData.autoReject
		_SaveFriend()
	end)

	local function _close()
		pcall(function() dimmer:Destroy() end)
		pcall(function() panel:Destroy() end)
	end

	-- Reddet butonu
	local rejBtn = Instance.new("TextButton")
	rejBtn.Size = UDim2.new(0.46,0,0,40); rejBtn.Position = UDim2.new(0,14,0,138)
	rejBtn.BackgroundColor3 = currentTheme.critical; rejBtn.Text = L.reject or "Reddet"
	rejBtn.TextColor3 = Color3.new(1,1,1); rejBtn.Font = Enum.Font.GothamBold
	rejBtn.TextSize = 13; rejBtn.ZIndex = 98002; rejBtn.Parent = panel
	Instance.new("UICorner", rejBtn).CornerRadius = UDim.new(0,12)

	-- Kabul Et butonu
	local accBtn = Instance.new("TextButton")
	accBtn.Size = UDim2.new(0.46,0,0,40); accBtn.Position = UDim2.new(0.54,-14,0,138)
	accBtn.BackgroundColor3 = currentTheme.success; accBtn.Text = L.accept or "Kabul Et"
	accBtn.TextColor3 = Color3.new(1,1,1); accBtn.Font = Enum.Font.GothamBold
	accBtn.TextSize = 13; accBtn.ZIndex = 98002; accBtn.Parent = panel
	Instance.new("UICorner", accBtn).CornerRadius = UDim.new(0,12)

	rejBtn.MouseButton1Click:Connect(function()
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":0")
		task.delay(1, function() _MyAttr(ATTR_RESP, "") end)
		_close()
	end)

	accBtn.MouseButton1Click:Connect(function()
		FriendData.friends[tostring(senderUserId)] = {name = senderName, syncEnabled = true}
		_SaveFriend()
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":1")
		task.delay(1, function() _MyAttr(ATTR_RESP, "") end)
		RefreshFriendList()
		Notify(L.friendReqAcceptedYou:format(tostring(senderName)), "", nil)
		_close()
	end)

	-- Otomatik reddet aktifse hemen kapat
	if FriendData.autoReject then
		_MyAttr(ATTR_RESP, tostring(senderUserId) .. ":0")
		task.delay(0.5, function() _MyAttr(ATTR_RESP, "") end)
		_close()
	end
end

-- Bir karakteri izle (attr değişikliklerini dinle)
local function _WatchChar(char, uid, uname)
	local function _conn(attr, fn)
		local ok, sig = pcall(function() return char:GetAttributeChangedSignal(attr) end)
		if ok and sig then
			local c = sig:Connect(fn)
			_friendConns[#_friendConns+1] = c
		end
	end

	-- Arkadaş isteği bana mı geliyor?
	_conn(ATTR_REQ, function()
		local v = char:GetAttribute(ATTR_REQ)
		if tostring(v) ~= tostring(player.UserId) then return end
		if not FriendData.acceptRequests then return end
		-- Aynı kişiden spam isteği yoksay
		local now = tick()
		local uid_s = tostring(uid)
		local lastIn = _incomingCooldowns[uid_s] or 0
		if now - lastIn < INCOMING_COOLDOWN then return end
		_incomingCooldowns[uid_s] = now
		ShowFriendRequestPanel(uid, uname)
	end)

	-- İstek cevabı (benim isteğime cevap)
	_conn(ATTR_RESP, function()
		local v = char:GetAttribute(ATTR_RESP)
		if not v then return end
		local parts = v:split(":")
		if #parts ~= 2 then return end
		if tostring(parts[1]) ~= tostring(player.UserId) then return end
		if parts[2] == "1" then
			FriendData.friends[tostring(uid)] = {name = uname, syncEnabled = true}
			_SaveFriend()
			RefreshFriendList()
			Notify(L.friendReqAcceptedThem:format(uname), "", nil)
		end
	end)

	-- Emote senkron
	_conn(ATTR_SYNC, function()
		if not FriendData.playFriendEmote then return end
		if _syncLock then return end
		local fdata = FriendData.friends[tostring(uid)]
		if not fdata or not fdata.syncEnabled then return end
		local v = char:GetAttribute(ATTR_SYNC)
		if not v or v == "" then return end
		-- Çakışma kontrolü: başka biriyle zaten senkronda mı
		if FriendData.currentSyncPartner and FriendData.currentSyncPartner ~= tostring(uid) then
			Notify(L.friendAlreadySyncing or "Hata! Zaten başka birisiyle senkrondayız.", "", nil)
			return
		end
		local sep = v:find("|")
		if not sep then return end
		local eid = tonumber(v:sub(1, sep-1))
		local ename = v:sub(sep+1)
		if eid and FriendData.syncEmote then
			_syncLock = true
			FriendData.currentSyncPartner = tostring(uid)
			PlayEmote(eid, ename, true)
			task.defer(function() _syncLock = false end)
		end
	end)

	-- Emote durdurma
	_conn(ATTR_STOP, function()
		if FriendData.currentSyncPartner == tostring(uid) then
			FriendData.currentSyncPartner = nil
			StopEmote(false)
		end
	end)
end

-- Tüm oyuncuları izle
local function _WatchAll()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			if p.Character then _WatchChar(p.Character, p.UserId, p.Name) end
			local cc = p.CharacterAdded:Connect(function(c)
				c:WaitForChild("HumanoidRootPart", 8)
				_WatchChar(c, p.UserId, p.Name)
				if FriendData.addModeActive then
					task.wait(0.3)
					pcall(function()
						if not FriendData.addModeActive then return end
						local head = c:FindFirstChild("Head")
						if head and not head:FindFirstChild("VexroFriendBB") then
							_MakeBillboard(p)
						end
					end)
				end
			end)
			_friendConns[#_friendConns+1] = cc
		end
	end
	local pa = Players.PlayerAdded:Connect(function(p)
		if p == player then return end
		local cc = p.CharacterAdded:Connect(function(c)
			c:WaitForChild("HumanoidRootPart", 8)
			_WatchChar(c, p.UserId, p.Name)
		end)
		_friendConns[#_friendConns+1] = cc
	end)
	_friendConns[#_friendConns+1] = pa
end
_WatchAll()

-- BillboardGui yönetimi
local _billConns = {}
local _MakeBillboard
local function _RemoveBillboard(p)
	pcall(function()
		local head = p.Character and p.Character:FindFirstChild("Head")
		if head then
			local bb = head:FindFirstChild("VexroFriendBB")
			if bb then bb:Destroy() end
		end
	end)
end

_MakeBillboard = function(p)
	if not p.Character then return end
	if FriendData.friends[tostring(p.UserId)] then return end
	local head = p.Character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VexroFriendBB") then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "VexroFriendBB"
	bb.Size = UDim2.new(0, 140, 0, 34)
	bb.StudsOffset = Vector3.new(0, 2.8, 0)
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	bb.Parent = head

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	btn.BackgroundTransparency = 0.08
	btn.TextColor3 = Color3.fromRGB(30, 30, 30)
	btn.Text = L.addFriendBtn
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.Parent = bb
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
	local btnStroke = Instance.new("UIStroke")
	btnStroke.Color = Color3.fromRGB(180, 180, 180)
	btnStroke.Thickness = 1
	btnStroke.Parent = btn

	local _btnBusy = false
	btn.MouseButton1Click:Connect(function()
		if _btnBusy then return end
		_btnBusy = true
		local function _done() _btnBusy = false end

		if FriendData.friends[tostring(p.UserId)] then
			Notify(L.alreadyFriends, "", nil); _done(); return
		end

		local now = tick()
		local uid_s = tostring(p.UserId)

		-- Global timeout kontrolü
		if now < _reqTimeoutUntil then
			local rem = math.ceil(_reqTimeoutUntil - now)
			Notify(L.spamProtect:format(rem), "", nil)
			_done(); return
		end

		-- Aynı kişiye tekrar istek cooldown
		local lastSent = _reqCooldowns[uid_s] or 0
		if now - lastSent < REQ_COOLDOWN then
			local rem = math.ceil(REQ_COOLDOWN - (now - lastSent))
			Notify(L.waitRequest:format(rem), "", nil)
			_done(); return
		end

		-- Spam sayacı güncelle
		if now - _reqSpamStart > REQ_SPAM_WINDOW then
			_reqSpamStart = now
			_reqSpamCount = 0
		end
		_reqSpamCount = _reqSpamCount + 1

		if _reqSpamCount >= REQ_SPAM_LIMIT then
			_reqTimeoutUntil = now + REQ_TIMEOUT_DUR
			_reqSpamCount = 0
			Notify(L.tooFastRequest:format(REQ_TIMEOUT_DUR), "", nil)
			btn.Text = L.blocked
			btn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
			_done(); return
		end

		-- İstek gönder
		_reqCooldowns[uid_s] = now
		_MyAttr(ATTR_REQ, uid_s)
		btn.Text = L.requestSent
		btn.BackgroundColor3 = Color3.fromRGB(60, 160, 90)
		btn.TextColor3 = Color3.new(1, 1, 1)
		Notify(L.friendReqSent:format(p.Name), "", nil)
		task.delay(3, function() _MyAttr(ATTR_REQ, "") end)
		_done()
	end)
end

local function _SetAddMode(on)
	FriendData.addModeActive = on
	-- Mevcut billboard bağlantılarını temizle
	for _, c in ipairs(_billConns) do pcall(function() c:Disconnect() end) end
	_billConns = {}
	if on then
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then _MakeBillboard(p) end
		end
	else
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then _RemoveBillboard(p) end
		end
	end
	-- Renk güncelle
	TweenService:Create(friendAddModeBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = on and currentTheme.success or currentTheme.critical
	}):Play()
end


-- Emote sync broadcast (PlayEmote sonrası çağrılır)
_genv().VexroBroadcastSync = function(emoteId, emoteName)
	if not FriendData.syncEmote then return end
	local hasSyncFriend = false
	for _, fd in pairs(FriendData.friends) do
		if fd.syncEnabled then hasSyncFriend = true; break end
	end
	if not hasSyncFriend then return end
	_MyAttr(ATTR_SYNC, tostring(emoteId) .. "|" .. tostring(emoteName))
end

_genv().VexroBroadcastStop = function()
	_MyAttr(ATTR_STOP, tostring(tick()))
	FriendData.currentSyncPartner = nil
end

-- Arkadaş sekmesi içeriği
local function _MakeFriendToggle(txt, desc, order, getVal, setVal)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,60)
	row.BackgroundColor3 = currentTheme.tertiary
	row.LayoutOrder = order; row.ZIndex = 6; row.Parent = friendsPanel
	Instance.new("UICorner", row).CornerRadius = UDim.new(0,12)
	RegisterTheme(row, "BackgroundColor3", "tertiary")

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.new(0.55,0,0,22); tl.Position = UDim2.new(0,12,0,8)
	tl.BackgroundTransparency = 1; tl.Text = txt; tl.TextColor3 = currentTheme.text
	tl.Font = Enum.Font.GothamBold; tl.TextSize = isMobile and 11 or 12
	tl.TextXAlignment = Enum.TextXAlignment.Left; tl.ZIndex = 7; tl.Parent = row
	RegisterTheme(tl, "TextColor3", "text")

	local dl = Instance.new("TextLabel")
	dl.Size = UDim2.new(0.55,0,0,26); dl.Position = UDim2.new(0,12,0,30)
	dl.BackgroundTransparency = 1; dl.Text = desc; dl.TextColor3 = currentTheme.textDim
	dl.Font = Enum.Font.Gotham; dl.TextSize = isMobile and 9 or 10
	dl.TextXAlignment = Enum.TextXAlignment.Left; dl.TextWrapped = true; dl.ZIndex = 7; dl.Parent = row
	RegisterTheme(dl, "TextColor3", "textDim")

	local tb = Instance.new("TextButton")
	tb.Size = UDim2.new(0.38,0,0,30); tb.Position = UDim2.new(0.58,0,0.5,-15)
	tb.BackgroundColor3 = getVal() and currentTheme.success or currentTheme.critical
	tb.Text = getVal() and (L.on or "Açık") or (L.off or "Kapalı")
	tb.TextColor3 = Color3.new(1,1,1); tb.Font = Enum.Font.GothamBold
	tb.TextSize = isMobile and 11 or 12; tb.ZIndex = 8; tb.Parent = row
	Instance.new("UICorner", tb).CornerRadius = UDim.new(0,10)

	tb.MouseButton1Click:Connect(function()
		local v = not getVal(); setVal(v)
		tb.Text = v and (L.on or "Açık") or (L.off or "Kapalı")
		TweenService:Create(tb, TweenInfo.new(0.2), {
			BackgroundColor3 = v and currentTheme.success or currentTheme.critical
		}):Play()
		_SaveFriend()
	end)
end

_MakeFriendToggle(
	"Arkadaşımın emote'unu oynat",
	"Arkadaşın emote başlattığında sende de otomatik oynar",
	1,
	function() return FriendData.playFriendEmote end,
	function(v) FriendData.playFriendEmote = v end
)
_MakeFriendToggle(
	"Emote'u arkadaşınla beraber oynat",
	"Emote oynatınca arkadaşlarına da senkron gönderir",
	2,
	function() return FriendData.syncEmote end,
	function(v) FriendData.syncEmote = v end
)

-- Arkadaş Ekle Modu butonu
local friendAddBtn = Instance.new("TextButton")
friendAddBtn.Size = UDim2.new(1, 0, 0, 38)
friendAddBtn.BackgroundColor3 = currentTheme.accent
friendAddBtn.Text = L.addFriendMode
friendAddBtn.TextColor3 = Color3.new(1, 1, 1)
friendAddBtn.Font = Enum.Font.GothamBold
friendAddBtn.TextSize = isMobile and 12 or 13
friendAddBtn.LayoutOrder = 3
friendAddBtn.ZIndex = 6
friendAddBtn.Parent = friendsPanel
Instance.new("UICorner", friendAddBtn).CornerRadius = UDim.new(0, 10)
RegisterTheme(friendAddBtn, "BackgroundColor3", "accent")

friendAddModeBtn = friendAddBtn

friendAddBtn.MouseButton1Click:Connect(function()
	_SetAddMode(not FriendData.addModeActive)
	TweenService:Create(friendAddBtn, TweenInfo.new(0.2), {
		BackgroundColor3 = FriendData.addModeActive and currentTheme.success or currentTheme.accent
	}):Play()
end)

-- Bilgi kutusu
local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, 0, 0, 52)
infoBox.BackgroundColor3 = Color3.fromRGB(40, 60, 100)
infoBox.BackgroundTransparency = 0.4
infoBox.LayoutOrder = 0
infoBox.ZIndex = 5
infoBox.Parent = friendsPanel
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 10)
local infoBoxLbl = Instance.new("TextLabel")
infoBoxLbl.Size = UDim2.new(1, -32, 1, 0)
infoBoxLbl.Position = UDim2.new(0, 32, 0, 0)
infoBoxLbl.BackgroundTransparency = 1
infoBoxLbl.Text = L.friendInfoTxt
infoBoxLbl.TextColor3 = Color3.fromRGB(200, 220, 255)
infoBoxLbl.Font = Enum.Font.Gotham
infoBoxLbl.TextSize = 10
infoBoxLbl.TextWrapped = true
infoBoxLbl.TextXAlignment = Enum.TextXAlignment.Left
infoBoxLbl.TextYAlignment = Enum.TextYAlignment.Center
infoBoxLbl.ZIndex = 6
infoBoxLbl.Parent = infoBox
local infoIcon = Instance.new("TextLabel")
infoIcon.Size = UDim2.new(0, 24, 0, 24)
infoIcon.Position = UDim2.new(0, 6, 0.5, -12)
infoIcon.BackgroundTransparency = 1
infoIcon.Text = "ℹ"
infoIcon.TextColor3 = Color3.fromRGB(150, 190, 255)
infoIcon.Font = Enum.Font.GothamBold
infoIcon.TextSize = 14
infoIcon.ZIndex = 6
infoIcon.Parent = infoBox

-- Arkadaş listesi başlığı
local flHeader = Instance.new("TextLabel")
flHeader.Size = UDim2.new(1,0,0,22); flHeader.BackgroundTransparency = 1
flHeader.Text = L.friendListHeader; flHeader.TextColor3 = currentTheme.textDim
flHeader.Font = Enum.Font.GothamBold; flHeader.TextSize = 11
flHeader.LayoutOrder = 4; flHeader.ZIndex = 5; flHeader.Parent = friendsPanel
RegisterTheme(flHeader, "TextColor3", "textDim")

local friendListContainer = Instance.new("Frame")
friendListContainer.Size = UDim2.new(1,0,0,0)
friendListContainer.AutomaticSize = Enum.AutomaticSize.Y
friendListContainer.BackgroundTransparency = 1
friendListContainer.LayoutOrder = 5; friendListContainer.ZIndex = 5; friendListContainer.Parent = friendsPanel
local flListLayout = Instance.new("UIListLayout")
flListLayout.Padding = UDim.new(0,6); flListLayout.Parent = friendListContainer

local emptyFriendLbl = Instance.new("TextLabel")
emptyFriendLbl.Size = UDim2.new(1,0,0,36); emptyFriendLbl.BackgroundTransparency = 1
emptyFriendLbl.Text = L.noFriends
emptyFriendLbl.TextColor3 = currentTheme.textDim; emptyFriendLbl.Font = Enum.Font.Gotham
emptyFriendLbl.TextSize = 11; emptyFriendLbl.TextWrapped = true
emptyFriendLbl.ZIndex = 6; emptyFriendLbl.Parent = friendListContainer
RegisterTheme(emptyFriendLbl, "TextColor3", "textDim")

RefreshFriendList = function()
	for _, ch in ipairs(friendListContainer:GetChildren()) do
		if ch:IsA("Frame") then ch:Destroy() end
	end
	local hasAny = false
	for userId, fdata in pairs(FriendData.friends) do
		hasAny = true
		local uid = tonumber(userId)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,0,0,50); row.BackgroundColor3 = currentTheme.tertiary
		row.ZIndex = 6; row.Parent = friendListContainer
		Instance.new("UICorner", row).CornerRadius = UDim.new(0,10)
		RegisterTheme(row, "BackgroundColor3", "tertiary")

		local av = Instance.new("ImageLabel")
		av.Size = UDim2.new(0,36,0,36); av.Position = UDim2.new(0,8,0.5,-18)
		av.BackgroundTransparency = 1
		av.Image = uid and ("rbxthumb://type=AvatarHeadShot&id=" .. uid .. "&w=150&h=150") or ""
		av.ZIndex = 7; av.Parent = row
		Instance.new("UICorner", av).CornerRadius = UDim.new(1,0)

		local nl = Instance.new("TextLabel")
		nl.Size = UDim2.new(1,-130,1,0); nl.Position = UDim2.new(0,52,0,0)
		nl.BackgroundTransparency = 1; nl.Text = fdata.name or userId
		nl.TextColor3 = currentTheme.text; nl.Font = Enum.Font.GothamBold
		nl.TextSize = isMobile and 11 or 12; nl.TextXAlignment = Enum.TextXAlignment.Left
		nl.ZIndex = 7; nl.Parent = row
		RegisterTheme(nl, "TextColor3", "text")

		local syncBtn = Instance.new("TextButton")
		syncBtn.Size = UDim2.new(0,46,0,24); syncBtn.Position = UDim2.new(1,-84,0.5,-12)
		syncBtn.BackgroundColor3 = fdata.syncEnabled and currentTheme.success or currentTheme.critical
		syncBtn.Text = fdata.syncEnabled and "Sync" or "Off"
		syncBtn.TextColor3 = Color3.new(1,1,1); syncBtn.Font = Enum.Font.GothamBold
		syncBtn.TextSize = 10; syncBtn.ZIndex = 7; syncBtn.Parent = row
		Instance.new("UICorner", syncBtn).CornerRadius = UDim.new(0,8)

		syncBtn.MouseButton1Click:Connect(function()
			fdata.syncEnabled = not fdata.syncEnabled
			syncBtn.Text = fdata.syncEnabled and "Sync" or "Off"
			TweenService:Create(syncBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = fdata.syncEnabled and currentTheme.success or currentTheme.critical
			}):Play()
			_SaveFriend()
		end)

		local rmBtn = Instance.new("TextButton")
		rmBtn.Size = UDim2.new(0,28,0,24); rmBtn.Position = UDim2.new(1,-30,0.5,-12)
		rmBtn.BackgroundColor3 = currentTheme.critical; rmBtn.Text = "-"
		rmBtn.TextColor3 = Color3.new(1,1,1); rmBtn.Font = Enum.Font.GothamBold
		rmBtn.TextSize = 16; rmBtn.ZIndex = 7; rmBtn.Parent = row
		Instance.new("UICorner", rmBtn).CornerRadius = UDim.new(0,8)

		rmBtn.MouseButton1Click:Connect(function()
			FriendData.friends[userId] = nil
			if FriendData.currentSyncPartner == userId then FriendData.currentSyncPartner = nil end
			_SaveFriend(); RefreshFriendList()
		end)
	end
	emptyFriendLbl.Visible = not hasAny
	flHeader.Visible = hasAny
end
RefreshFriendList()

-- Ayarlar paneline "Arkadaş istekleri al" satırı (Davranış bölümünün altı: order 15)
do
	local arRow = MakeRow("", L.acceptRequestsLbl, "", 15)
	MakePillToggle(arRow, FriendData.acceptRequests, function(v)
		FriendData.acceptRequests = v
		_SaveFriend()
	end)
end

-- Cleanup kaydı güncelle
local _prevClean = _genv().VexroEmotesCleanup
_genv().VexroEmotesCleanup = function()
	if _prevClean then pcall(_prevClean) end
	for _, c in ipairs(_friendConns) do pcall(function() c:Disconnect() end) end
	_friendConns = {}
	_SetAddMode(false)
	pcall(function() _genv().VexroBroadcastSync = nil end)
	pcall(function() _genv().VexroBroadcastStop = nil end)
end

end -- arkadaş sistemi do...end sonu

-- BOTTOM BAR
-- ===============================================================

local bottomBar = Instance.new("Frame")
bottomBar.Size = UDim2.new(1, 0, 0, bottomBarH)
bottomBar.Position = UDim2.new(0, 0, 1, -bottomBarH)
bottomBar.BackgroundColor3 = currentTheme.tertiary
bottomBar.ZIndex = 15
bottomBar.Parent = content
Instance.new("UICorner", bottomBar).CornerRadius = UDim.new(0, 14)
RegisterTheme(bottomBar, "BackgroundColor3", "tertiary")

local bottomOverlay = Instance.new("Frame")
bottomOverlay.Size = UDim2.new(1, 0, 0, 8)
bottomOverlay.BackgroundColor3 = currentTheme.tertiary
bottomOverlay.BorderSizePixel = 0
bottomOverlay.ZIndex = 14
bottomOverlay.Parent = bottomBar
RegisterTheme(bottomOverlay, "BackgroundColor3", "tertiary")

local grip = Instance.new("Frame")
grip.Size = UDim2.new(0, 40, 0, 4)
grip.Position = UDim2.new(0.5, -20, 0.5, -2)
grip.BackgroundColor3 = currentTheme.textDim
grip.ZIndex = 16
grip.Parent = bottomBar
Instance.new("UICorner", grip).CornerRadius = UDim.new(1, 0)
RegisterTheme(grip, "BackgroundColor3", "textDim")

local scrollY = titleH + searchH + 14
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -16, 1, -(scrollY + pageH + bottomBarH + 18))
scroll.Position = UDim2.new(0, 8, 0, scrollY)
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = isMobile and 3 or 5
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollBarImageColor3 = currentTheme.stroke
scroll.ZIndex = 1
scroll.Parent = content
RegisterTheme(scroll, "ScrollBarImageColor3", "stroke")

-- ===============================================================
-- CARD SYSTEM (RESPONSIVE GRID)
-- ===============================================================

local function CalcLayout()
	local PAD = isMobile and 4 or 6
	local w = scroll.AbsoluteSize.X
	
	-- Determine minimal viable card size to allow more columns
	local minCardSize = isMobile and TARGET_MOBILE_CARD or TARGET_PC_CARD
	
	-- Calculate how many columns fit
	cols = math.floor(w / (minCardSize + PAD))
	if cols < 1 then cols = 1 end
	
	-- Expand card size slightly to fill gaps
	currentCardSize = (w - (PAD * (cols - 1))) / cols
	
	-- Calculate rows based on available height to fill page mostly
	local NAME_H = math.clamp(currentCardSize * 0.35, 18, 28)
	local FAV_H = math.clamp(currentCardSize * 0.3, 18, 24)
	local CARD_TOTAL_H = currentCardSize + NAME_H + FAV_H
	
	local rowsVisible = math.floor(scroll.AbsoluteSize.Y / (CARD_TOTAL_H + PAD))
	if rowsVisible < 2 then rowsVisible = 2 end
	
	-- Determine items per page dynamically
	perPage = cols * rowsVisible
	
	pages = math.max(1, math.ceil(#filtered / perPage))
	page = math.clamp(page, 1, pages)
end

local function UpdatePageUI()
	pageNum.Text = page .. "/" .. pages
	local show = pages > 1
	prevBtn.Visible = show
	nextBtn.Visible = show
	
	if prevBtn:FindFirstChild("ChevronIcon") then 
		for _, c in ipairs(prevBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(0, 0, 0) end
	end
	if nextBtn:FindFirstChild("ChevronIcon") then 
		for _, c in ipairs(nextBtn.ChevronIcon:GetChildren()) do c.BackgroundColor3 = Color3.new(0, 0, 0) end
	end
	
	pageBar.Visible = currentTab ~= "settings" and currentTab ~= "friends" and currentTab ~= "keybinds" and pages > 1
	
	local empty = #filtered == 0 and currentTab ~= "settings"
	emptyLbl.Visible = empty
	if empty then
		local q = search and search.Text ~= "" or false
		if q then
			emptyLbl.Text = L.noSearch or "No results found"
		elseif currentTab == "favorites" then
			emptyLbl.Text = L.noFav
		elseif currentTab == "recent" then
			emptyLbl.Text = L.noRecent
		else
			emptyLbl.Text = L.noSearch or "No results found"
		end
	end
end

local function _MarkBadEmote(emoteId)
	local key = tostring(emoteId)
	if _badEmotes[key] then return end
	_badEmotes[key] = true
	-- Remove from master Emotes list
	for i = #Emotes, 1, -1 do
		if tostring(Emotes[i].id) == key then table.remove(Emotes, i); break end
	end
	EmotesById[tonumber(key)] = nil
	-- Remove from current filtered list so page counts update
	for i = #filtered, 1, -1 do
		if tostring(filtered[i].id) == key then table.remove(filtered, i); break end
	end
	-- Debounced grid refresh so rapid failures coalesce into one redraw
	if not _refreshPending then
		_refreshPending = true
		task.delay(0.8, function()
			_refreshPending = false
			if currentTab ~= "settings" and currentTab ~= "friends" and currentTab ~= "keybinds" then
				page = math.clamp(page, 1, math.max(1, math.ceil(#filtered / perPage)))
				Refresh(false)
			end
		end)
	end
end

local function ClearCards()
	for _, c in pairs(cards) do
		if c and c.Parent then
			-- Cancel any running tweens to avoid they reference destroyed instances
			for _, desc in ipairs(c:GetDescendants()) do
				if desc:IsA("TweenBase") then pcall(function() desc:Cancel() end) end
			end
			c:Destroy()
		end
	end
	cards = {}
	-- Prune _textGrads of entries whose parent was just destroyed
	for i = #_textGrads, 1, -1 do
		local g = _textGrads[i]
		if not (g and g.Parent) then
			table.remove(_textGrads, i)
		end
	end
end

-- ===============================================================
-- KEYBIND DIALOG
-- ===============================================================

local function ShowKeybindDialog(emoteId, emote, isEdit)
	-- Remove existing overlay
	local existing = main:FindFirstChild("VexroKeybindOverlay")
	if existing then existing:Destroy() end

	local overlay = Instance.new("TextButton")
	overlay.Name = "VexroKeybindOverlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.Text = ""
	overlay.AutoButtonColor = false
	overlay.ZIndex = 200
	overlay.Parent = main
	overlay.MouseButton1Click:Connect(function() end) -- tüm tıklamaları yut

	local dialog = Instance.new("Frame")
	dialog.Size = UDim2.new(0.85, 0, 0, 260)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.BackgroundColor3 = currentTheme.secondary
	dialog.ZIndex = 201
	dialog.Parent = overlay
	Instance.new("UICorner", dialog).CornerRadius = UDim.new(0, 16)
	local dStroke = Instance.new("UIStroke")
	dStroke.Color = currentTheme.accent
	dStroke.Thickness = 2
	dStroke.Transparency = 0.4
	dStroke.Parent = dialog

	-- Title
	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -16, 0, 36)
	titleLbl.Position = UDim2.new(0, 8, 0, 8)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = isEdit and L.editKeybind or L.newKeybind
	titleLbl.TextColor3 = currentTheme.text
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.ZIndex = 202
	titleLbl.Parent = dialog

	-- Name label
	local nameLblTitle = Instance.new("TextLabel")
	nameLblTitle.Size = UDim2.new(0, 60, 0, 24)
	nameLblTitle.Position = UDim2.new(0, 12, 0, 52)
	nameLblTitle.BackgroundTransparency = 1
	nameLblTitle.Text = L.kbName
	nameLblTitle.TextColor3 = currentTheme.textDim
	nameLblTitle.Font = Enum.Font.GothamBold
	nameLblTitle.TextSize = 13
	nameLblTitle.TextXAlignment = Enum.TextXAlignment.Left
	nameLblTitle.ZIndex = 202
	nameLblTitle.Parent = dialog

	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(1, -24, 0, 32)
	nameBox.Position = UDim2.new(0, 12, 0, 78)
	nameBox.BackgroundColor3 = currentTheme.tertiary
	nameBox.PlaceholderText = emote.name
	nameBox.Text = isEdit and (GetKeybind(emoteId) and GetKeybind(emoteId).name or "") or ""
	nameBox.TextColor3 = currentTheme.text
	nameBox.PlaceholderColor3 = currentTheme.textDim
	nameBox.Font = Enum.Font.Gotham
	nameBox.TextSize = 13
	nameBox.ClearTextOnFocus = false
	nameBox.ZIndex = 202
	nameBox.Parent = dialog
	Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 8)
	local nbStroke = Instance.new("UIStroke")
	nbStroke.Color = currentTheme.stroke
	nbStroke.Thickness = 1.5
	nbStroke.Parent = nameBox

	-- Atama label
	local atamaLbl = Instance.new("TextLabel")
	atamaLbl.Size = UDim2.new(0, 80, 0, 24)
	atamaLbl.Position = UDim2.new(0, 12, 0, 122)
	atamaLbl.BackgroundTransparency = 1
	atamaLbl.Text = L.kbAssign
	atamaLbl.TextColor3 = currentTheme.textDim
	atamaLbl.Font = Enum.Font.GothamBold
	atamaLbl.TextSize = 13
	atamaLbl.TextXAlignment = Enum.TextXAlignment.Left
	atamaLbl.ZIndex = 202
	atamaLbl.Parent = dialog

	-- Key recording button
	local recordedKey = isEdit and (GetKeybind(emoteId) and GetKeybind(emoteId).key or nil) or nil
	local isRecording = false
	local recordConn

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(1, -24, 0, 36)
	keyBtn.Position = UDim2.new(0, 12, 0, 148)
	keyBtn.BackgroundColor3 = currentTheme.tertiary
	keyBtn.Text = recordedKey and ("[" .. recordedKey .. "]") or L.kbRecording
	keyBtn.TextColor3 = recordedKey and currentTheme.accent or currentTheme.textDim
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 13
	keyBtn.ZIndex = 202
	keyBtn.Parent = dialog
	Instance.new("UICorner", keyBtn).CornerRadius = UDim.new(0, 8)
	local kbStroke = Instance.new("UIStroke")
	kbStroke.Color = currentTheme.stroke
	kbStroke.Thickness = 1.5
	kbStroke.Parent = keyBtn

	keyBtn.MouseButton1Click:Connect(function()
		if isRecording then return end
		isRecording = true
		keyBtn.Text = "..."
		kbStroke.Color = currentTheme.accent
		TweenService:Create(kbStroke, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7}):Play()
		local UIS2 = game:GetService("UserInputService")
		recordConn = UIS2.InputBegan:Connect(function(inp, gp)
			if gp then return end
			if inp.UserInputType == Enum.UserInputType.Keyboard then
				recordedKey = inp.KeyCode.Name
				isRecording = false
				recordConn:Disconnect()
				keyBtn.Text = "[" .. recordedKey .. "]"
				keyBtn.TextColor3 = currentTheme.accent
				kbStroke.Color = currentTheme.stroke
				TweenService:Create(kbStroke, TweenInfo.new(0.1), {Transparency = 0}):Play()
			end
		end)
	end)

	-- Cancel button
	local cancelBtn = Instance.new("TextButton")
	cancelBtn.Size = UDim2.new(0.45, -6, 0, 38)
	cancelBtn.Position = UDim2.new(0, 12, 0, 208)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
	cancelBtn.Text = L.kbCancel
	cancelBtn.TextColor3 = Color3.new(1, 1, 1)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 14
	cancelBtn.ZIndex = 202
	cancelBtn.Parent = dialog
	Instance.new("UICorner", cancelBtn).CornerRadius = UDim.new(0, 10)

	-- Save button
	local saveBtn = Instance.new("TextButton")
	saveBtn.Size = UDim2.new(0.55, -18, 0, 38)
	saveBtn.Position = UDim2.new(0.45, 6, 0, 208)
	saveBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
	saveBtn.Text = L.kbSave
	saveBtn.TextColor3 = Color3.new(1, 1, 1)
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 14
	saveBtn.ZIndex = 202
	saveBtn.Parent = dialog
	Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 10)

	cancelBtn.MouseButton1Click:Connect(function()
		if recordConn then pcall(function() recordConn:Disconnect() end) end
		overlay:Destroy()
	end)

	local _KB_BLACKLIST = {Unknown=true, Backspace=true, Delete=true, Escape=true,
		Return=true, Tab=true, CapsLock=true, LeftShift=true, RightShift=true,
		LeftControl=true, RightControl=true, LeftAlt=true, RightAlt=true,
		LeftMeta=true, RightMeta=true, Insert=true, Home=true, End=true,
		PageUp=true, PageDown=true, NumLock=true, ScrollLock=true, Pause=true, Print=true}

	saveBtn.MouseButton1Click:Connect(function()
		if not recordedKey then return end
		if _KB_BLACKLIST[recordedKey] then
			keyBtn.Text = L.kbInvalidKey or "Invalid key!"
			keyBtn.TextColor3 = Color3.fromRGB(220, 50, 50)
			task.delay(1.5, function()
				if recordedKey then
					keyBtn.Text = "[" .. recordedKey .. "]"
					keyBtn.TextColor3 = currentTheme.accent
				end
			end)
			return
		end
		if recordConn then pcall(function() recordConn:Disconnect() end) end
		local kbName = nameBox.Text ~= "" and nameBox.Text or emote.name
		SetKeybind(emoteId, kbName, recordedKey)
		overlay:Destroy()
		Refresh(false)
		if currentTab == "keybinds" and RefreshKeybindsPanel then RefreshKeybindsPanel() end
	end)

	-- Entry animation
	dialog.Size = UDim2.new(0, 0, 0, 0)
	TweenService:Create(dialog, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = UDim2.new(0.85, 0, 0, 260)}):Play()
end

-- Assign RefreshKeybindsPanel (forward-declared above keybindsPanel)
RefreshKeybindsPanel = function()
	for _, c in ipairs(keybindsPanel:GetChildren()) do
		if not c:IsA("UIListLayout") then c:Destroy() end
	end
	local hasAny = false
	for emoteId, kb in pairs(KeybindsSet) do
		hasAny = true
		local emote = EmotesById[emoteId]
		local emoteName = emote and emote.name or ("Emote #"..emoteId)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = currentTheme.secondary
		row.BorderSizePixel = 0
		row.ZIndex = 6
		row.Parent = keybindsPanel
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
		-- Emote thumbnail
		local thumb = Instance.new("ImageLabel")
		thumb.Size = UDim2.new(0, 44, 0, 44)
		thumb.Position = UDim2.new(0, 6, 0.5, -22)
		thumb.BackgroundTransparency = 1
		thumb.Image = "rbxthumb://type=Asset&id="..emoteId.."&w=420&h=420"
		thumb.ZIndex = 7
		thumb.Parent = row
		Instance.new("UICorner", thumb).CornerRadius = UDim.new(0, 6)
		-- Name
		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -130, 0, 20)
		nameLbl.Position = UDim2.new(0, 56, 0, 8)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = emoteName
		nameLbl.TextColor3 = currentTheme.text
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.ZIndex = 7
		nameLbl.Parent = row
		-- Key badge
		local keyLbl = Instance.new("TextLabel")
		keyLbl.Size = UDim2.new(0, 38, 0, 24)
		keyLbl.Position = UDim2.new(0, 56, 0, 28)
		keyLbl.BackgroundColor3 = currentTheme.accent
		keyLbl.Text = kb.key
		keyLbl.TextColor3 = currentTheme.primary
		keyLbl.Font = Enum.Font.GothamBold
		keyLbl.TextSize = 12
		keyLbl.ZIndex = 7
		keyLbl.Parent = row
		Instance.new("UICorner", keyLbl).CornerRadius = UDim.new(0, 6)
		-- Custom name label
		local customName = Instance.new("TextLabel")
		customName.Size = UDim2.new(1, -110, 0, 14)
		customName.Position = UDim2.new(0, 100, 0, 30)
		customName.BackgroundTransparency = 1
		customName.Text = kb.name ~= "" and kb.name or ""
		customName.TextColor3 = currentTheme.textDim
		customName.Font = Enum.Font.Gotham
		customName.TextSize = 11
		customName.TextXAlignment = Enum.TextXAlignment.Left
		customName.ZIndex = 7
		customName.Parent = row
		-- Delete button
		local delBtn = Instance.new("ImageButton")
		delBtn.Size = UDim2.new(0, 42, 0, 42)
		delBtn.Position = UDim2.new(1, -40, 0.5, -16)
		delBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
		delBtn.Image = ResolveAssetImage(Icons.KeybindRemove)
		delBtn.ImageColor3 = Color3.new(1,1,1)
		delBtn.ZIndex = 7
		delBtn.Parent = row
		Instance.new("UICorner", delBtn).CornerRadius = UDim.new(1, 0)
		delBtn.MouseButton1Click:Connect(function()
			RemoveKeybind(emoteId)
			RefreshKeybindsPanel()
		end)
	end
	if not hasAny then
		local emptyLbl2 = Instance.new("TextLabel")
		emptyLbl2.Size = UDim2.new(1, 0, 0, 60)
		emptyLbl2.BackgroundTransparency = 1
		emptyLbl2.Text = L.kbEmpty
		emptyLbl2.TextColor3 = currentTheme.textDim
		emptyLbl2.Font = Enum.Font.Gotham
		emptyLbl2.TextSize = 14
		emptyLbl2.ZIndex = 6
		emptyLbl2.Parent = keybindsPanel
	end
end

-- ===============================================================
-- CARD SYSTEM
-- ===============================================================

local function MakeCard(emote, ci, animate)
	local CARD = currentCardSize
	local PAD = isMobile and 4 or 6

	-- Dynamic text height based on card size, but capped
	local NAME_H = math.clamp(CARD * 0.35, 18, 28)
	local FAV_H = math.clamp(CARD * 0.3, 18, 24)
	local KB_H = (not isMobile) and math.clamp(CARD * 0.45, 30, 40) or 0  -- keybind row height (PC only)
	local CARD_TOTAL_H = KB_H + CARD + NAME_H + FAV_H

	-- Ana kart container
	local cardContainer = Instance.new("Frame")
	cardContainer.Size = UDim2.new(0, CARD, 0, CARD_TOTAL_H)
	cardContainer.BackgroundTransparency = 1
	cardContainer.ZIndex = 2
	cardContainer.Parent = scroll
	
	local col = ci % cols
	local row = math.floor(ci / cols)
	
	-- Position logic for grid
	local targetX = col * (CARD + PAD)
	local targetY = PAD + row * (CARD_TOTAL_H + PAD)
	
	if animate then
		cardContainer.Position = UDim2.new(0, targetX, 0, targetY + 30)
		cardContainer.BackgroundTransparency = 1
		
		task.delay(ci * 0.02, function()
			if cardContainer.Parent then
				TweenService:Create(cardContainer, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
					Position = UDim2.new(0, targetX, 0, targetY)
				}):Play()
			end
		end)
	else
		cardContainer.Position = UDim2.new(0, targetX, 0, targetY)
	end
	
	local card = Instance.new("ImageButton")
	card.Size = UDim2.new(1, 0, 0, CARD)
	card.Position = UDim2.new(0, 0, 0, KB_H)
	card.BackgroundColor3 = currentTheme.tertiary
	card.ScaleType = Enum.ScaleType.Fit
	card.ZIndex = 3
	card.Parent = cardContainer
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)
	
	card.Image = "rbxthumb://type=Asset&id=" .. emote.id .. "&w=420&h=420"
	-- Cards are dynamic, register/unregister is complex. We set color directly on refresh.
	card.BackgroundColor3 = currentTheme.tertiary

	-- Async asset validation with 15-second timeout
	task.spawn(function()
		local _done = false
		local function _onResult(_, status)
			if _done then return end
			_done = true
			if status == Enum.AssetFetchStatus.Failure then
				task.defer(function()
					if cardContainer and cardContainer.Parent then cardContainer:Destroy() end
					_MarkBadEmote(emote.id)
				end)
			end
		end
		task.delay(15, function() _onResult(nil, Enum.AssetFetchStatus.Failure) end)
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({card}, _onResult)
		end)
	end)
	
	if animate then
		card.ImageTransparency = 1
		task.delay(ci * 0.02, function()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.25), {ImageTransparency = 0}):Play()
			end
		end)
	end
	
	local stroke = Instance.new("UIStroke")
	stroke.Color = currentTheme.accent
	stroke.Thickness = 2
	stroke.Transparency = 0.6
	stroke.Parent = card
	
	-- İsim Label (resmin altında)
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, -4, 0, NAME_H - 2) 
	nameLbl.Position = UDim2.new(0, 2, 0, KB_H + CARD)
	nameLbl.BackgroundColor3 = currentTheme.secondary
	nameLbl.Text = #emote.name > 20 and emote.name:sub(1, 19) .. "…" or emote.name
	nameLbl.TextColor3 = currentTheme.text
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.TextWrapped = true 
	nameLbl.Active = true 
	nameLbl.ZIndex = 3
	nameLbl.Parent = cardContainer
	Instance.new("UICorner", nameLbl).CornerRadius = UDim.new(0, 4)
	_AddTextGrad(nameLbl)

	nameLbl.MouseEnter:Connect(function()
		TweenService:Create(nameLbl, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, 4, 0, NAME_H + 4),
			Rotation = math.random(-2, 2)
		}):Play()
	end)
	
	nameLbl.MouseLeave:Connect(function()
		TweenService:Create(nameLbl, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, -4, 0, NAME_H - 2),
			Rotation = 0
		}):Play()
	end)
	
	
	local isFav = IsFavorite(emote.id)
	local favBtn = Instance.new("TextButton")
	favBtn.Size = UDim2.new(1, 0, 0, FAV_H)
	favBtn.Position = UDim2.new(0, 0, 0, KB_H + CARD + NAME_H)
	favBtn.BackgroundColor3 = currentTheme.accent
	favBtn.BackgroundTransparency = 1 -- Kareyi kaldır
	favBtn.Text = ""
	favBtn.ZIndex = 4
	favBtn.Parent = cardContainer
	Instance.new("UICorner", favBtn).CornerRadius = UDim.new(0, 4)

	local favIcon = Instance.new("TextLabel")
	local iconSize = isMobile and 28 or 34
	favIcon.Size = UDim2.new(0, iconSize, 0, iconSize)
	favIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	favIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	favIcon.BackgroundTransparency = 1
	favIcon.Text = isFav and utf8.char(0x2605) or utf8.char(0x2606)
	favIcon.TextColor3 = isFav and Color3.fromRGB(255, 215, 0) or currentTheme.accent
	favIcon.Font = Enum.Font.SourceSansLight
	favIcon.TextSize = isMobile and 26 or 32
	favIcon.TextScaled = false
	favIcon.ZIndex = 50
	favIcon.Parent = favBtn
	
	favBtn.MouseEnter:Connect(function()
		TweenService:Create(favBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.accent,
			Size = UDim2.new(1, 6, 0, FAV_H + 6),
			Rotation = math.random(-2, 2)
		}):Play()
	end)
	favBtn.MouseLeave:Connect(function()
		TweenService:Create(favBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.stroke,
			Size = UDim2.new(1, 0, 0, FAV_H),
			Rotation = 0
		}):Play()
	end)
	
	favBtn.MouseButton1Click:Connect(function()
		isFav = ToggleFavorite(emote.id)
		
		if isFav then
			favIcon.Text = utf8.char(0x2605)
			favIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
		else
			favIcon.Text = utf8.char(0x2606)
			favIcon.TextColor3 = currentTheme.accent
		end
		
		TweenService:Create(favBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = isFav and currentTheme.tertiary or currentTheme.stroke
		}):Play()
		
		-- YILDIZ PATLAMA ANİMASYONU
		if isFav then
			favIcon.Size = UDim2.new(0, 0, 0, 0)
			TweenService:Create(favIcon, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, iconSize + 6, 0, iconSize + 6)
			}):Play()
			task.delay(0.2, function()
				TweenService:Create(favIcon, TweenInfo.new(0.3, Enum.EasingStyle.Sine), {
					Size = UDim2.new(0, iconSize, 0, iconSize)
				}):Play()
			end)
			
			local ripple = Instance.new("Frame")
			ripple.Size = UDim2.new(0, 0, 0, 0)
			ripple.Position = UDim2.fromScale(0.5, 0.5)
			ripple.AnchorPoint = Vector2.new(0.5, 0.5)
			ripple.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			ripple.BackgroundTransparency = 0.3
			ripple.ZIndex = 4
			ripple.Parent = favBtn
			Instance.new("UICorner", ripple).CornerRadius = UDim.new(1, 0)
			
			TweenService:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(2, 0, 2, 0),
				BackgroundTransparency = 1
			}):Play()
			task.delay(0.4, function() if ripple then ripple:Destroy() end end)
		else
			-- Geri alırken küçük bir küçülme efekti
			TweenService:Create(favIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
				Size = UDim2.new(0, iconSize - 4, 0, iconSize - 4)
			}):Play()
			task.delay(0.2, function()
				TweenService:Create(favIcon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, iconSize, 0, iconSize)
				}):Play()
			end)
		end
		
		if currentTab == "favorites" then
			task.delay(0.4, function()
				if currentTab == "favorites" then UpdateTabData() end
			end)
		end
	end)

	-- Keybind button row at TOP of card (PC only, same style as favBtn at bottom)
	local kbHasBinding = GetKeybind(emote.id) ~= nil
	if not isMobile then
		local kbBtn = Instance.new("TextButton")
		kbBtn.Size = UDim2.new(1, 0, 0, KB_H)
		kbBtn.Position = UDim2.new(0, 0, 0, 0)
		kbBtn.BackgroundColor3 = currentTheme.accent
		kbBtn.BackgroundTransparency = 1
		kbBtn.Text = ""
		kbBtn.ZIndex = 4
		kbBtn.ClipsDescendants = true
		kbBtn.Parent = cardContainer
		Instance.new("UICorner", kbBtn).CornerRadius = UDim.new(0, 4)

		local kbIcon = Instance.new("ImageLabel")
		kbIcon.Size = UDim2.new(0.95, 0, 0.95, 0)
		kbIcon.Position = UDim2.fromScale(0.5, 0.5)
		kbIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		kbIcon.BackgroundTransparency = 1
		kbIcon.ScaleType = Enum.ScaleType.Fit
		kbIcon.Image = ResolveAssetImage(kbHasBinding and Icons.KeybindActive or Icons.Keybind)
		kbIcon.ImageColor3 = kbHasBinding and currentTheme.accent or currentTheme.textDim
		kbIcon.ZIndex = 5
		kbIcon.Parent = kbBtn

		kbBtn.MouseEnter:Connect(function()
			TweenService:Create(kbBtn, TweenInfo.new(0.15, Enum.EasingStyle.Back), {
				BackgroundColor3 = kbHasBinding and currentTheme.tertiary or currentTheme.accent,
				Size = UDim2.new(1, 6, 0, KB_H + 6),
				Rotation = math.random(-2, 2)
			}):Play()
		end)
		kbBtn.MouseLeave:Connect(function()
			TweenService:Create(kbBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
				BackgroundColor3 = currentTheme.stroke,
				Size = UDim2.new(1, 0, 0, KB_H),
				Rotation = 0
			}):Play()
		end)

		kbBtn.MouseButton1Click:Connect(function()
			ShowKeybindDialog(emote.id, emote, kbHasBinding)
			-- Update icon after dialog closes via Refresh
		end)

		-- Long press: show red remove overlay on card
		local longPressTimer = nil
		local longPressOverlay = nil

		local function ShowRemoveOverlay()
			if not GetKeybind(emote.id) then return end
			if longPressOverlay then return end
			longPressOverlay = Instance.new("Frame")
			longPressOverlay.Size = UDim2.new(1, 0, 0, 0)
			longPressOverlay.Position = UDim2.new(0, 0, 1, 0)
			longPressOverlay.AnchorPoint = Vector2.new(0, 1)
			longPressOverlay.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
			longPressOverlay.BackgroundTransparency = 0.2
			longPressOverlay.ZIndex = 15
			longPressOverlay.ClipsDescendants = true
			longPressOverlay.Parent = card
			Instance.new("UICorner", longPressOverlay).CornerRadius = UDim.new(0, 8)
			TweenService:Create(longPressOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0)
			}):Play()
			local removeIcon = Instance.new("ImageButton")
			removeIcon.Size = UDim2.new(0, 42, 0, 42)
			removeIcon.Position = UDim2.fromScale(0.5, 0.5)
			removeIcon.AnchorPoint = Vector2.new(0.5, 0.5)
			removeIcon.BackgroundTransparency = 1
			removeIcon.Image = ResolveAssetImage(Icons.KeybindRemove)
			removeIcon.ImageColor3 = Color3.new(1, 1, 1)
			removeIcon.ZIndex = 16
			removeIcon.Parent = longPressOverlay
			removeIcon.MouseButton1Click:Connect(function()
				RemoveKeybind(emote.id)
				kbHasBinding = false
				kbIcon.Image = ResolveAssetImage(Icons.Keybind)
				kbIcon.ImageColor3 = currentTheme.textDim
				if longPressOverlay then longPressOverlay:Destroy(); longPressOverlay = nil end
			end)
			task.delay(2.5, function()
				if longPressOverlay then
					TweenService:Create(longPressOverlay, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play()
					task.delay(0.2, function()
						if longPressOverlay then longPressOverlay:Destroy(); longPressOverlay = nil end
					end)
				end
			end)
		end

		local pressStart = 0
		card.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				pressStart = tick()
				longPressTimer = task.delay(0.6, ShowRemoveOverlay)
			end
		end)
		card.InputEnded:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 then
				if longPressTimer then task.cancel(longPressTimer); longPressTimer = nil end
				if tick() - pressStart < 0.4 and longPressOverlay then
					longPressOverlay:Destroy(); longPressOverlay = nil
				end
			end
		end)
	end -- isMobile check for keybind block

	card.MouseEnter:Connect(function()
		-- Hafif büyütme ve tilt efekti
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
			Size = UDim2.new(1, 6, 0, CARD + 6),
			Rotation = math.random(-2, 2)
		}):Play()
		-- Stroke parlaması
		local hoverColor = currentTheme.strokeHover or currentTheme.accent
		TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0, Thickness = 2.5, Color = hoverColor}):Play()
	end)

	card.MouseLeave:Connect(function()
		-- Normale dönüş
		TweenService:Create(card, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, 0, 0, CARD),
			Rotation = 0
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.2), {Transparency = 0.6, Thickness = 2, Color = currentTheme.stroke}):Play()
	end)
	
	
	card.MouseButton1Click:Connect(function()
		-- İçeri göçme (Jelly)
		TweenService:Create(card, TweenInfo.new(0.1, Enum.EasingStyle.Quad), {Size = UDim2.new(0.9, 0, 0, CARD * 0.9)}):Play()
		
		task.delay(0.1, function()
			-- Geri fırlama
			TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), {Size = UDim2.new(1, 0, 0, CARD)}):Play()
		end)
		
		TweenService:Create(stroke, TweenInfo.new(0.1), {Color = Color3.fromRGB(80, 220, 120)}):Play()
		task.delay(0.3, function()
			if card.Parent then
				TweenService:Create(stroke, TweenInfo.new(0.2), {Color = currentTheme.accent}):Play()
			end
		end)
		
		-- Break any active friend sync when user manually picks a new emote
		if FriendData and FriendData.currentSyncPartner then
			FriendData.currentSyncPartner = nil
		end
		PlayEmote(emote.id, emote.name)
	end)

	return cardContainer
end

local function UpdateCards(animate)
	ClearCards()
	
	local startIdx = (page - 1) * perPage + 1
	local endIdx = math.min(page * perPage, #filtered)
	
	local ci = 0
	for i = startIdx, endIdx do
		if filtered[i] then
			cards[i] = MakeCard(filtered[i], ci, animate)
			ci = ci + 1
		end
	end
	
	local CARD = currentCardSize
	local PAD = isMobile and 4 or 6
	local NAME_H = math.clamp(CARD * 0.35, 18, 28)
	local FAV_H = math.clamp(CARD * 0.3, 18, 24)
	local CARD_TOTAL_H = CARD + NAME_H + FAV_H
	
	local rows = math.ceil(ci / math.max(cols, 1))
	scroll.CanvasSize = UDim2.new(0, 0, 0, rows * (CARD_TOTAL_H + PAD) + PAD)
	scroll.CanvasPosition = Vector2.zero

	-- Background preload next page thumbnails so page changes feel instant
	local _npStart = page * perPage + 1
	local _npEnd   = math.min((page + 1) * perPage, #filtered)
	if _npStart <= _npEnd then
		task.spawn(function()
			local _imgs = {}
			for _i = _npStart, _npEnd do
				local _fe = filtered[_i]
				if _fe and not _badEmotes[tostring(_fe.id)] then
					local _img = Instance.new("ImageLabel")
					_img.Image = "rbxthumb://type=Asset&id=" .. _fe.id .. "&w=420&h=420"
					_imgs[#_imgs + 1] = _img
				end
			end
			if #_imgs > 0 then
				pcall(function() game:GetService("ContentProvider"):PreloadAsync(_imgs) end)
				for _, _img in ipairs(_imgs) do _img:Destroy() end
			end
		end)
	end
end

local function Refresh(animate)
	CalcLayout()
	UpdatePageUI()
	UpdateCards(animate ~= false)
end

prevBtn.MouseButton1Click:Connect(function()
	if pages <= 1 then return end
	if page > 1 then 
		page = page - 1
	else 
		page = pages -- Loop to end
	end
	Refresh(true)
end)
nextBtn.MouseButton1Click:Connect(function()
	if pages <= 1 then return end
	if page < pages then 
		page = page + 1
	else 
		page = 1 -- Loop to start
	end
	Refresh(true)
end)

-- ===============================================================
-- TAB SYSTEM
-- ===============================================================

UpdateTabStyles = function()
	local isM3 = Settings.theme == "MaterialYou"
	for name, data in pairs(tabBtns) do
		local active = currentTab == name
		local targetColor = active and currentTheme.accent or currentTheme.sidebar
		local targetIconColor = active and Color3.new(1, 1, 1) or currentTheme.text
		
		-- Quatrefoil göstergesi (sadece MaterialYou)
		if data.quatrefoil then
			if isM3 and active then
				data.quatrefoil.Visible = true
				data.quatrefoil.ImageColor3 = currentTheme.accent
				local qSize = tabBtnS + 10
				data.quatrefoil.Size = UDim2.new(0, 0, 0, 0)
				TweenService:Create(data.quatrefoil, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, qSize, 0, qSize),
					ImageTransparency = 0.3
				}):Play()
			else
				if data.quatrefoil.Visible then
					local qRef = data.quatrefoil
					TweenService:Create(qRef, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = UDim2.new(0, 0, 0, 0),
						ImageTransparency = 1
					}):Play()
					task.delay(0.2, function()
						if qRef and qRef.Parent then qRef.Visible = false end
					end)
				end
			end
		end
		
		-- Tüm temalarda butonlar şeffaf; aktif gösterge ayrı frame'de
		TweenService:Create(data.btn, TweenInfo.new(0.2), {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, tabBtnS, 0, tabBtnS)
		}):Play()
		data.stroke.Transparency = 1

		if isM3 then
			-- MaterialYou: quatrefoil göstergesi, sliding indicator gizli
			if _tabIndicator then _tabIndicator.Visible = false end
		else
			-- Diğer temalar: sliding indicator göster, aktif tab'a kaydır
			if _tabIndicator then
				_tabIndicator.Visible = true
				if active then
					_UpdateIndicatorGrad()
					local targetY = data.yPos - 2
					TweenService:Create(_tabIndicator, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
						Position = UDim2.new(0.5, -_indS/2, 0, targetY)
					}):Play()
				end
			end
		end
		
		if data.img then
			TweenService:Create(data.img, TweenInfo.new(0.2), {
				ImageColor3 = targetIconColor
			}):Play()
		else
			TweenService:Create(data.btn, TweenInfo.new(0.2), {
				TextColor3 = targetIconColor
			}):Play()
		end
	end
end

UpdateTabData = function()
	search.Text = ""
	page = 1
	
	local isSettings  = currentTab == "settings"
	local isFriends   = currentTab == "friends"
	local isKeybinds  = currentTab == "keybinds"
	settingsPanel.Visible  = isSettings
	friendsPanel.Visible   = isFriends
	keybindsPanel.Visible  = isKeybinds
	local hideNormal = isSettings or isFriends or isKeybinds
	scroll.Visible  = not hideNormal
	search.Visible  = not hideNormal
	pageBar.Visible = not hideNormal
	if hideNormal then
		emptyLbl.Visible = false
	end
	if isKeybinds then
		if RefreshKeybindsPanel then RefreshKeybindsPanel() end
	end
	
	if currentTab == "emotes" then
		currentData = Emotes
		-- If bad emotes exist, build a clean filtered copy; otherwise share the table
		if next(_badEmotes) then
			filtered = {}
			for _, e in ipairs(Emotes) do
				if not _badEmotes[tostring(e.id)] then filtered[#filtered + 1] = e end
			end
		else
			filtered = Emotes
		end
		title.Text = L.emotes
		titleIcon.Image = ResolveAssetImage(Icons.Emote)
		titleIcon.ImageColor3 = currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "favorites" then
		currentData = {}
		for i = 1, #Favorites do
			local emote = EmotesById[Favorites[i]]
			if emote then
				currentData[#currentData + 1] = emote
			end
		end
		filtered = currentData
		title.Text = L.favorites
		titleIcon.Image = ResolveAssetImage(Icons.FavoriteFull)
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true

	elseif currentTab == "recent" then
		currentData = {}
		for i = 1, #RecentEmotes do
			local emote = EmotesById[RecentEmotes[i]]
			if emote then
				currentData[#currentData + 1] = emote
			end
		end
		filtered = currentData
		title.Text = L.recent
		titleIcon.Image = ResolveAssetImage(Icons.Recent)
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "settings" then
		title.Text = L.settings
		titleIcon.Image = ResolveAssetImage(Icons.Settings)
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "friends" then
		title.Text = L.friendTab or "Arkadaşlar"
		titleIcon.Image = ResolveAssetImage("rbxassetid://115725480722697")
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	elseif currentTab == "keybinds" then
		title.Text = L.keybinds
		titleIcon.Image = ResolveAssetImage("rbxassetid://122679509852670")
		titleIcon.ImageColor3 = (Settings.theme == "FrostedGlass" or Settings.theme == "DarkGlass") and currentTheme.accent or currentTheme.text
		titleIcon.Visible = true
	end
	
	local tabIconSz = titleIconSz
	if currentTab ~= "emotes" then
		tabIconSz = math.floor(titleIconSz * 1.3)
	end
	titleIcon.Size = UDim2.new(0, tabIconSz, 0, tabIconSz)
	title.Position = UDim2.new(0, titleIcon.Visible and (10 + tabIconSz + 6) or 10, 0, 0)
	
	UpdateTabStyles()
	if not isSettings and not isKeybinds and not isFriends then Refresh(true) end
end

tabBtns["emotes"].btn.MouseButton1Click:Connect(function() currentTab = "emotes"; UpdateTabData() end)
tabBtns["favorites"].btn.MouseButton1Click:Connect(function() currentTab = "favorites"; UpdateTabData() end)

tabBtns["recent"].btn.MouseButton1Click:Connect(function() currentTab = "recent"; UpdateTabData() end)
tabBtns["settings"].btn.MouseButton1Click:Connect(function() currentTab = "settings"; UpdateTabData() end)
tabBtns["friends"].btn.MouseButton1Click:Connect(function() currentTab = "friends"; UpdateTabData() end)
if not isMobile then tabBtns["keybinds"].btn.MouseButton1Click:Connect(function() currentTab = "keybinds"; UpdateTabData() end) end

local searchToken = 0
search:GetPropertyChangedSignal("Text"):Connect(function()
	if currentTab == "settings" then return end
	searchToken = searchToken + 1
	local myToken = searchToken
	task.wait(0.08)
	if myToken ~= searchToken then return end -- Newer input supersedes
	local q = search.Text:lower()
	filtered = {}
	for i = 1, #currentData do
		local e = currentData[i]
		if not _badEmotes[tostring(e.id)] and (q == "" or (#q <= #(e._lname or e.name) and (e._lname or e.name:lower()):find(q, 1, true))) then
			filtered[#filtered + 1] = e
		end
	end
	page = 1
	Refresh(true)
end)

-- ===============================================================
-- MINI ICON
-- ===============================================================

do
local iconS = isMobile and 50 or 60
local miniIcon = Instance.new("ImageButton")
miniIcon.Size = UDim2.new(0, iconS, 0, iconS)
miniIcon.Position = UDim2.new(0, 20, 0.5, -iconS/2)
miniIcon.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
miniIcon.Image = "rbxassetid://88874992610290"
miniIcon.Visible = false
miniIcon.ZIndex = 1000
miniIcon.Parent = gui
Instance.new("UICorner", miniIcon).CornerRadius = UDim.new(1, 0)

local miniIconStroke = Instance.new("UIStroke")
miniIconStroke.Color = Color3.new(1, 1, 1) -- Gradient için beyaz taban
miniIconStroke.Thickness = 3
miniIconStroke.Parent = miniIcon

miniIconGrad = Instance.new("UIGradient")
miniIconGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, currentTheme.stroke),
	ColorSequenceKeypoint.new(0.33, currentTheme.accent),
	ColorSequenceKeypoint.new(0.66, currentTheme.stroke),
	ColorSequenceKeypoint.new(1, currentTheme.accent)
}
miniIconGrad.Parent = miniIconStroke

task.spawn(function()
	local rot = 0
	while miniIcon.Parent do
		rot = rot + 360
		TweenService:Create(miniIconGrad, TweenInfo.new(2, Enum.EasingStyle.Linear), {Rotation = rot}):Play()
		task.wait(2)
	end
end)

task.spawn(function()
	while miniIcon.Parent do
		if miniIcon.Visible then
			TweenService:Create(miniIcon, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = UDim2.new(0, iconS + 4, 0, iconS + 4)}):Play()
			task.wait(1)
			TweenService:Create(miniIcon, TweenInfo.new(1, Enum.EasingStyle.Sine), {Size = UDim2.new(0, iconS, 0, iconS)}):Play()
			task.wait(1)
		else
			task.wait(0.5)
		end
	end
end)

do
local savedPos, savedSize = nil, nil
local iconDragging, iconDragStart, iconStartPos = false, nil, nil

miniIcon.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		iconDragging = true
		iconDragStart = input.Position
		iconStartPos = miniIcon.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if iconDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - iconDragStart
		miniIcon.Position = UDim2.new(iconStartPos.X.Scale, iconStartPos.X.Offset + delta.X, iconStartPos.Y.Scale, iconStartPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		if iconDragging then
			local delta = input.Position - iconDragStart
			if math.abs(delta.X) < 5 and math.abs(delta.Y) < 5 then
				miniIcon.Visible = false
				main.Visible = true
				main.ClipsDescendants = true
				main.Size = UDim2.new(0, 0, 0, 0)
				main.BackgroundTransparency = 1
				main.Rotation = -15
				
				local targetSize = savedSize or GetDefaultSize()
				local targetPos = savedPos or UDim2.fromScale(0.5, 0.5)
				main.Position = targetPos
				
				TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back), {Size = targetSize, BackgroundTransparency = 0, Rotation = 0}):Play()
				TweenService:Create(mainStroke, TweenInfo.new(0.35), {Transparency = 0}):Play()
				
				task.delay(0.4, function()
					main.ClipsDescendants = false
					if currentTab ~= "settings" then Refresh(true) end
				end)
			end
		end
		iconDragging = false
	end
end)

minBtn.MouseButton1Click:Connect(function()
	savedPos = main.Position
	savedSize = main.Size
	
	TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Size = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Rotation = 15}):Play()
	TweenService:Create(mainStroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
	
	task.delay(0.3, function()
		main.Visible = false
		miniIcon.Visible = true
	end)
end)

-- Tüm bağlantıları kesip scripti temizle
local function _CleanupScript()
	pcall(function() _heartbeatConn:Disconnect() end)
	pcall(function() _charAddedConn:Disconnect() end)
	pcall(function() if _keybindInputConn then _keybindInputConn:Disconnect() end end)
	pcall(function() DisableCopyEmotePrompts() end)
	pcall(function() StopHUDTracking() end)
	_genv().VexroEmotesCleanup = nil
	_genv().lastVexroEmote = nil
	_genv().autoReloadEnabled_Vexro = nil
	pcall(function() gui:Destroy() end)
end

_genv().VexroEmotesCleanup = _CleanupScript

closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false  -- tüm input'u hemen kes
	main.ClipsDescendants = true
	TweenService:Create(main, TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1
	}):Play()
	task.delay(0.22, _CleanupScript)
end)
end -- iconDrag scope
end -- miniIcon/iconS scope

-- ===============================================================
-- DRAG & RESIZE
-- ===============================================================

do
local dragging, dragStart, startPos = false, nil, nil

local function StartDrag(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
	end
end

titleBar.InputBegan:Connect(StartDrag)
bottomBar.InputBegan:Connect(StartDrag)
sidebar.InputBegan:Connect(StartDrag)

UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)

local resizeS = isMobile and 28 or 22
local resizeBtn = Instance.new("TextButton")
resizeBtn.Size = UDim2.new(0, resizeS, 0, resizeS)
resizeBtn.Position = UDim2.new(1, -resizeS - 3, 1, -resizeS - 3)
resizeBtn.BackgroundColor3 = currentTheme.stroke
resizeBtn.BackgroundTransparency = 0.4
resizeBtn.Text = "/"
resizeBtn.TextColor3 = currentTheme.textDim
resizeBtn.TextSize = isMobile and 12 or 14
resizeBtn.ZIndex = 100
resizeBtn.Parent = main
Instance.new("UICorner", resizeBtn).CornerRadius = UDim.new(0, 8)

do
local resizing, resizeStart, sizeStart = false, nil, nil
local lastRefreshTime = 0

resizeBtn.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		resizing = true
		resizeStart = input.Position
		sizeStart = main.AbsoluteSize
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - resizeStart
		-- Min height: enough for all tabs + padding (6 tabs on PC, 5 on mobile)
		local tabCount = isMobile and 5 or 6
		local minH = 8 + (tabBtnS + 6) * tabCount + tabBtnS + 16
		local newW = math.clamp(sizeStart.X + delta.X, 400, 1200)
		local newH = math.clamp(sizeStart.Y + delta.Y, minH, 800)
		main.Size = UDim2.new(0, newW, 0, newH)
		
		local now = tick()
		if now - lastRefreshTime > 0.1 then
			lastRefreshTime = now
			if currentTab ~= "settings" then Refresh(false) end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) and resizing then
		resizing = false
		if currentTab ~= "settings" then Refresh(false) end
	end
end)
end -- resize scope
end -- drag scope

-- ===============================================================
-- CHARACTER RESPAWN & AUTO-RELOAD
-- ===============================================================

-- Enable auto reload before listener registration
_genv().autoReloadEnabled_Vexro = Settings.loopEmote

local _charAddedConn = player.CharacterAdded:Connect(function(newChar)
	local newHum = newChar:WaitForChild("Humanoid", 5)
	if not newHum then return end
	
	-- R6 check
	if newHum.RigType == Enum.HumanoidRigType.R6 then
		Notify(utf8.char(0x274C), L.r6Msg)
		task.wait(2)
		gui:Destroy()
		return
	end
	
	-- Auto-reload last emote after respawn
	if _genv().lastVexroEmote and _genv().autoReloadEnabled_Vexro then
		task.wait(1)
		PlayEmote(_genv().lastVexroEmote.id, _genv().lastVexroEmote.name, true)
		Notify("[R]", L.ready or "Emote reapplied")
	end
end)

-- ===============================================================
-- INITIALIZE
-- ===============================================================

main.Rotation = -10
local openSize = GetDefaultSize()
TweenService:Create(main, TweenInfo.new(0.45, Enum.EasingStyle.Back), {Size = openSize, BackgroundTransparency = 0, Rotation = 0}):Play()
TweenService:Create(mainStroke, TweenInfo.new(0.45), {Transparency = 0}):Play()

task.wait(0.5)

main.ClipsDescendants = false
ApplyTheme(Settings.theme)
UpdateTabStyles()
UpdateTabData()

-- Keybind playback listener (PC only)
local _keybindInputConn = nil
if not isMobile then
	_keybindInputConn = UserInputService.InputBegan:Connect(function(inp, gp)
		if gp then return end
		if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
		local keyName = inp.KeyCode.Name
		for emoteId, kb in pairs(KeybindsSet) do
			if kb.key == keyName then
				local emote = EmotesById[emoteId]
				if emote then
					PlayEmote(emote.id, emote.name)
				end
				break
			end
		end
	end)
end

task.wait(0.25)
Notify(utf8.char(0x2705) .. " " .. L.ready, #Emotes .. " emotes")

-- ================================================================
-- VEXRO EXTENDED MODULES v1.0
-- Bölüm 1: Dinamik Tema  |  Bölüm 2: Animation Blending & Combo
-- Bölüm 3: Canlı Emote HUD  |  Bölüm 4: Entegrasyon
-- NOT: do...end bloğu Lua'nın 200 local sınırını aşmamak için
-- ================================================================
local function _VexroExtend() -- Ayrı fonksiyon: kendi 200 register tablosu

-- ----------------------------------------------------------------
-- ----------------------------------------------------------------



-- Lighting.OutdoorAmbient → vurgu rengi
-- Max 0.72 ile sınırlıyoruz: buton arka planı asla beyaza dönmesin
-- Forward declarations
local HUD, infoPanel, infoSpeedLbl, comboSlots, comboQueue_UI
local _currentInfoId, _currentInfoName
local _comboLoopEnabled = false
local _comboLoopList    = {}


-- ----------------------------------------------------------------
-- BÖLÜM 2 — ANİMASYON BLENDING & SEQUENCING (Combo Sistemi)
-- AnimationTrack:Play(0.3) ile 0.3s fade-in/out harmanlama,
-- Stopped sinyali ile otomatik sıralama, max 3 emote combo.
-- ----------------------------------------------------------------

-- Forward declaration: HUD fonksiyonları aşağıda tanımlanır
local ShowEmoteHUD, HideEmoteHUD

local ComboQueue    = {} -- {id, name} tablosu
local isComboActive = false

-- 0.3 saniyelik smooth fade ile tek bir combo adımını oynat
local function PlayComboStep(emoteId, emoteName)
	local animator = GetAnimator()
	if not animator then return end

	-- Mevcut animasyonu 0.3s fade-out ile durdur
	if currentAnimTrack and currentAnimTrack.IsPlaying then
		currentAnimTrack:Stop(0.3)
		task.wait(0.08)
	end

	-- Animasyonu cache'den al veya yükle
	local anim = _animCache[emoteId]
	if not anim then
		pcall(function()
			local ok, objects = pcall(function()
				return game:GetObjects("rbxassetid://" .. emoteId)
			end)
			if ok and objects and #objects > 0 then
				local item = objects[1]
				anim = item:IsA("Animation") and item
					or item:FindFirstChildWhichIsA("Animation", true)
			end
			if not anim then
				anim = Instance.new("Animation")
				anim.AnimationId = "rbxassetid://" .. emoteId
			end
			_animCache[emoteId] = anim
		end)
	end
	if not anim then return end

	pcall(function()
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped   = false             -- Combo modunda döngü kapalı

		track:Play(0.3)                    -- 0.3s FADE-IN (harmanlama)
		task.delay(0.05, function()
			if track.IsPlaying then
				track:AdjustSpeed(Settings.speed)
			end
		end)

		currentAnimTrack = track
		_genv().lastVexroEmote = {id = emoteId, name = emoteName}
		AddToRecent(emoteId)

		-- HUD'u göster (defer: ShowEmoteHUD aşağıda tanımlanır)
		task.defer(function()
			if ShowEmoteHUD then ShowEmoteHUD(emoteId, emoteName) end
		end)

		-- Track durduğunda → kuyrukta sonraki varsa çal, yoksa bitir
		track.Stopped:Connect(function()
			if not isComboActive then return end
			if #ComboQueue > 0 then
				local nxt = table.remove(ComboQueue, 1)
				PlayComboStep(nxt.id, nxt.name)
			else
				-- Döngü açıksa listeyi yeniden başlat, kuyruğu sıfırlama
				if _comboLoopEnabled and #_comboLoopList > 0 then
					ComboQueue = {}
					for i = 2, #_comboLoopList do
						ComboQueue[#ComboQueue + 1] = _comboLoopList[i]
					end
					PlayComboStep(_comboLoopList[1].id, _comboLoopList[1].name)
				else
					isComboActive = false
					task.defer(function()
						if HideEmoteHUD then HideEmoteHUD() end
					end)
					-- Combo bitince slot UI'ını sıfırla
					task.defer(function()
						if comboQueue_UI then comboQueue_UI = {} end
						if comboSlots then
							for j = 1, 3 do
								if comboSlots[j] then
									comboSlots[j].Text = L.slotLabel .. " " .. j
									TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
										BackgroundColor3 = Color3.fromRGB(30, 30, 46)
									}):Play()
								end
							end
						end
					end)
				end
			end
		end)
	end)
end

-- Combo sıralamasını başlat
local function StartCombo(emoteList)
	if #emoteList == 0 then return end
	isComboActive = true
	-- Döngü için orijinal listeyi sakla
	_comboLoopList = {}
	for _, e in ipairs(emoteList) do
		_comboLoopList[#_comboLoopList + 1] = {id = e.id, name = e.name}
	end
	ComboQueue = {}
	for i = 2, #emoteList do
		ComboQueue[#ComboQueue + 1] = emoteList[i]
	end
	PlayComboStep(emoteList[1].id, emoteList[1].name)
end

-- ----------------------------------------------------------------
-- BÖLÜM 3 — CANLI EMOTE HUD (Alt-Orta Şeffaf Panel)
-- RenderStepped canlı slider, hız butonları (0.1x–2x),
-- bilgi popup, sürüklenebilir knob, Disconnect ile FPS koruması.
-- ----------------------------------------------------------------

local hudTrackerConn = nil  -- RenderStepped bağlantısı (yönetilir)
local _hudHideToken  = 0   -- Hızlı emote geçişlerinde eski hide task'ını iptal eder

-- ▸ Ana HUD çerçevesi (forward declared above — do NOT add local here)
HUD = Instance.new("Frame")
HUD.Name                   = "VexroHUD"
HUD.Size                   = isMobile and UDim2.new(0, 320, 0, 100) or UDim2.new(0, 500, 0, 104)
HUD.Position               = UDim2.new(0.5, 0, 1, -120)
HUD.AnchorPoint            = Vector2.new(0.5, 1)
HUD.BackgroundColor3       = Color3.fromRGB(8, 8, 12)
HUD.BackgroundTransparency = 0.30
HUD.BorderSizePixel        = 0
HUD.Visible                = false
HUD.ZIndex                 = 500
HUD.ClipsDescendants       = false
HUD.Parent                 = gui
Instance.new("UICorner", HUD).CornerRadius = UDim.new(0, 14)

local hudStroke = Instance.new("UIStroke")
hudStroke.Color        = currentTheme.stroke
hudStroke.Thickness    = 1.5
hudStroke.Transparency = 0.25
hudStroke.Parent       = HUD

-- ▸ Sol üst: Favori yıldızı
local hudFavBtn = Instance.new("ImageButton")
hudFavBtn.Size                   = UDim2.new(0, 22, 0, 22)
hudFavBtn.Position               = UDim2.new(0, 9, 0, 6)
hudFavBtn.BackgroundColor3       = Color3.fromRGB(30, 30, 46)
hudFavBtn.BackgroundTransparency = 0.20
hudFavBtn.Image                  = ResolveAssetImage(Icons.FavoriteEmpty)
hudFavBtn.ImageColor3            = currentTheme.accent
hudFavBtn.ZIndex                 = 502
hudFavBtn.Parent                 = HUD
Instance.new("UICorner", hudFavBtn).CornerRadius = UDim.new(1, 0)

local function RefreshHUDFavBtn()
	if not _currentInfoId then return end
	local isFav = IsFavorite(_currentInfoId)
	hudFavBtn.Image      = ResolveAssetImage(isFav and Icons.FavoriteFull or Icons.FavoriteEmpty)
	TweenService:Create(hudFavBtn, TweenInfo.new(0.15), {
		ImageColor3      = isFav and Color3.fromRGB(255, 215, 0) or currentTheme.accent,
		BackgroundColor3 = isFav and Color3.fromRGB(55, 45, 10) or Color3.fromRGB(30, 30, 46)
	}):Play()
end

hudFavBtn.MouseButton1Click:Connect(function()
	if not _currentInfoId then return end
	ToggleFavorite(_currentInfoId)
	RefreshHUDFavBtn()
end)

-- ▸ Sol alt: "i" bilgi ikonu
local hudInfoBtn = Instance.new("TextButton")
hudInfoBtn.Size                   = UDim2.new(0, 22, 0, 22)
hudInfoBtn.Position               = UDim2.new(0, 9, 0, 32)
hudInfoBtn.BackgroundColor3       = currentTheme.accent
hudInfoBtn.BackgroundTransparency = 0.40
hudInfoBtn.Text                   = "i"
hudInfoBtn.TextColor3             = Color3.new(1, 1, 1)
hudInfoBtn.Font                   = Enum.Font.GothamBold
hudInfoBtn.TextSize               = 12
hudInfoBtn.ZIndex                 = 502
hudInfoBtn.Parent                 = HUD
Instance.new("UICorner", hudInfoBtn).CornerRadius = UDim.new(1, 0)

-- ▸ Orta üst: Emote adı
local hudName = Instance.new("TextLabel")
hudName.Size                   = UDim2.new(1, -130, 0, 22)
hudName.Position               = UDim2.new(0, 44, 0, 7)
hudName.BackgroundTransparency = 1
hudName.Text                   = ""
hudName.TextColor3             = Color3.new(1, 1, 1)
hudName.Font                   = Enum.Font.GothamBold
hudName.TextSize               = isMobile and 13 or 15
hudName.TextXAlignment         = Enum.TextXAlignment.Left
hudName.TextTruncate           = Enum.TextTruncate.AtEnd
hudName.ZIndex                 = 501
hudName.Parent                 = HUD

-- ▸ Orta alt: Creator (daha küçük, sönük)
local hudCreator = Instance.new("TextLabel")
hudCreator.Size                   = UDim2.new(1, -130, 0, 15)
hudCreator.Position               = UDim2.new(0, 44, 0, 30)
hudCreator.BackgroundTransparency = 1
hudCreator.Text                   = "Vexro Emotes"
hudCreator.TextColor3             = Color3.fromRGB(120, 120, 145)
hudCreator.Font                   = Enum.Font.Gotham
hudCreator.TextSize               = isMobile and 10 or 11
hudCreator.TextXAlignment         = Enum.TextXAlignment.Left
hudCreator.ZIndex                 = 501
hudCreator.Parent                 = HUD

-- ▸ Progress slider arka planı
local hudSliderBg = Instance.new("Frame")
hudSliderBg.Size             = UDim2.new(1, -148, 0, 4)
hudSliderBg.Position         = UDim2.new(0, 44, 0, 54)
hudSliderBg.BackgroundColor3 = Color3.fromRGB(42, 42, 58)
hudSliderBg.ZIndex           = 501
hudSliderBg.Parent           = HUD
Instance.new("UICorner", hudSliderBg).CornerRadius = UDim.new(1, 0)

-- İlerleme (fill) kısmı
local hudFill = Instance.new("Frame")
hudFill.Size             = UDim2.new(0, 0, 1, 0)
hudFill.BackgroundColor3 = currentTheme.accent
hudFill.ZIndex           = 502
hudFill.Parent           = hudSliderBg
Instance.new("UICorner", hudFill).CornerRadius = UDim.new(1, 0)

-- Sürüklenebilir tutaç (knob)
local hudKnob = Instance.new("TextButton")
hudKnob.Size             = UDim2.new(0, 12, 0, 12)
hudKnob.AnchorPoint      = Vector2.new(0.5, 0.5)
hudKnob.Position         = UDim2.new(0, 0, 0.5, 0)
hudKnob.BackgroundColor3 = Color3.new(1, 1, 1)
hudKnob.Text             = ""
hudKnob.ZIndex           = 503
hudKnob.Parent           = hudSliderBg
Instance.new("UICorner", hudKnob).CornerRadius = UDim.new(1, 0)

-- ▸ Orta-alt: Duraklat / Devam Et butonu
local hudPauseBtn = Instance.new("ImageButton")
hudPauseBtn.Size                   = UDim2.new(0, 60, 0, 22)
hudPauseBtn.AnchorPoint            = Vector2.new(0.5, 0)
hudPauseBtn.Position               = UDim2.new(0.5, 0, 0, 66)
hudPauseBtn.BackgroundColor3       = Color3.fromRGB(30, 30, 46)
hudPauseBtn.BackgroundTransparency = 0.10
hudPauseBtn.Image                  = ResolveAssetImage("rbxassetid://113416463749658")
hudPauseBtn.ImageColor3            = Color3.new(1, 1, 1)
hudPauseBtn.ScaleType              = Enum.ScaleType.Fit
hudPauseBtn.ZIndex                 = 503
hudPauseBtn.Parent                 = HUD
Instance.new("UICorner", hudPauseBtn).CornerRadius = UDim.new(0, 7)

local hudPauseBtnStroke = Instance.new("UIStroke")
hudPauseBtnStroke.Color       = currentTheme.stroke
hudPauseBtnStroke.Thickness   = 1
hudPauseBtnStroke.Transparency = 0.40
hudPauseBtnStroke.Parent      = hudPauseBtn

local function RefreshHudPauseBtn()
	if _isPaused then
		hudPauseBtn.Image = ResolveAssetImage("rbxassetid://129338178452237")
		hudPauseBtn.BackgroundColor3 = currentTheme.accent
	else
		hudPauseBtn.Image = ResolveAssetImage("rbxassetid://113416463749658")
		hudPauseBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
	end
end

hudPauseBtn.MouseButton1Click:Connect(function()
	-- Onceligi duraklat halini kontrol etmeye ver (hiz=0 iken IsPlaying hala true)
	if currentAnimTrack and _isPaused then
		pcall(function() currentAnimTrack:AdjustSpeed(Settings.speed) end)
		_SetPauseState(false)
	elseif currentAnimTrack and currentAnimTrack.IsPlaying then
		pcall(function() currentAnimTrack:AdjustSpeed(0) end)
		_SetPauseState(true)
	end
end)

-- Bridge'i buraya bağla: stopBtn _onPauseStateChanged'i çağırınca hudPauseBtn güncellenir
_onPauseStateChanged = function(paused)
	RefreshHudPauseBtn()
end

-- ▸ Sağ: Hız kontrol butonları (0.1x  0.5x  1x  1.5x  2x)
local HUD_SPEEDS = {0.1, 0.5, 1, 1.5, 2}
local HUD_LABELS = {"0.1", "0.5", "1x", "1.5", "2x"}
local hudSpeedBtns = {}
local spBtnW   = isMobile and 26 or 30
local spBtnGap = 3
local spTotalW = #HUD_SPEEDS * spBtnW + (#HUD_SPEEDS - 1) * spBtnGap

-- Aktif hız butonunu vurgula
local function RefreshHUDSpeedBtns()
	for i, btn in ipairs(hudSpeedBtns) do
		local active = math.abs(HUD_SPEEDS[i] - Settings.speed) < 0.01
		TweenService:Create(btn, TweenInfo.new(0.15), {
			BackgroundColor3 = active and currentTheme.accent or Color3.fromRGB(30, 30, 46)
		}):Play()
	end
end

for si, spd in ipairs(HUD_SPEEDS) do
	local xOff = -(spTotalW + 8) + (si - 1) * (spBtnW + spBtnGap)
	local sBtn = Instance.new("TextButton")
	sBtn.Size                   = UDim2.new(0, spBtnW, 0, 20)
	sBtn.Position               = UDim2.new(1, xOff, 0, 7)
	sBtn.BackgroundColor3       = (math.abs(spd - Settings.speed) < 0.01)
		and currentTheme.accent or Color3.fromRGB(30, 30, 46)
	sBtn.BackgroundTransparency = 0.15
	sBtn.Text                   = HUD_LABELS[si]
	sBtn.TextColor3             = Color3.new(1, 1, 1)
	sBtn.Font                   = Enum.Font.GothamBold
	sBtn.TextSize               = 10
	sBtn.ZIndex                 = 502
	sBtn.Parent                 = HUD
	Instance.new("UICorner", sBtn).CornerRadius = UDim.new(0, 5)
	hudSpeedBtns[si] = sBtn

	sBtn.MouseButton1Click:Connect(function()
		Settings.speed = spd
		-- Anlık hız uygula (AdjustSpeed)
		if currentAnimTrack and currentAnimTrack.IsPlaying then
			pcall(function() currentAnimTrack:AdjustSpeed(spd) end)
		end
		RefreshHUDSpeedBtns()
		SaveData()
	end)
end

-- ▸ Bilgi Paneli — gui'ye bağlı ayrı sekme (HUD'a değil)
-- HUD'dan bağımsız; ClipsDescendants sorunu olmaz (forward declared above — do NOT add local here)
infoPanel = Instance.new("Frame")
infoPanel.Name                   = "VexroInfoPanel"
infoPanel.Size                   = UDim2.new(0, 270, 0, 260)
infoPanel.Position               = UDim2.new(0, -290, 1, -285) -- Başlangıç: sol dışarıda
infoPanel.BackgroundColor3       = Color3.fromRGB(10, 10, 18)
infoPanel.BackgroundTransparency = 0.08
infoPanel.BorderSizePixel        = 0
infoPanel.Visible                = false
infoPanel.ZIndex                 = 700
infoPanel.Parent                 = gui
Instance.new("UICorner", infoPanel).CornerRadius = UDim.new(0, 14)

local infoPanelStroke = Instance.new("UIStroke")
infoPanelStroke.Color       = currentTheme.accent
infoPanelStroke.Thickness   = 1.5
infoPanelStroke.Transparency = 0.30
infoPanelStroke.Parent      = infoPanel

-- Başlık çubuğu (sürükleme tutacağı)
local infoPanelTitle = Instance.new("Frame")
infoPanelTitle.Size             = UDim2.new(1, 0, 0, 36)
infoPanelTitle.BackgroundColor3 = currentTheme.accent
infoPanelTitle.BackgroundTransparency = 0.55
infoPanelTitle.ZIndex           = 701
infoPanelTitle.Active           = true   -- input alabilsin
infoPanelTitle.Parent           = infoPanel
Instance.new("UICorner", infoPanelTitle).CornerRadius = UDim.new(0, 14)
-- Alt köşeleri düzeltmek için overlay
local infoPanelTitleOverlay = Instance.new("Frame")
infoPanelTitleOverlay.Size             = UDim2.new(1, 0, 0, 14)
infoPanelTitleOverlay.Position         = UDim2.new(0, 0, 1, -14)
infoPanelTitleOverlay.BackgroundColor3 = currentTheme.accent
infoPanelTitleOverlay.BackgroundTransparency = 0.55
infoPanelTitleOverlay.BorderSizePixel  = 0
infoPanelTitleOverlay.ZIndex           = 701
infoPanelTitleOverlay.Parent           = infoPanelTitle

-- Başlık ikonu (Icons.Info)
local infoPanelTitleIcon = Instance.new("ImageLabel")
infoPanelTitleIcon.Size             = UDim2.new(0, 20, 0, 20)
infoPanelTitleIcon.Position         = UDim2.new(0, 10, 0.5, -10)
infoPanelTitleIcon.BackgroundTransparency = 1
infoPanelTitleIcon.Image            = ResolveAssetImage(Icons.Info)
infoPanelTitleIcon.ImageColor3      = Color3.new(1, 1, 1)
infoPanelTitleIcon.ZIndex           = 702
infoPanelTitleIcon.Parent           = infoPanelTitle

local infoPanelTitleLbl = Instance.new("TextLabel")
infoPanelTitleLbl.Size                   = UDim2.new(1, -62, 1, 0)
infoPanelTitleLbl.Position               = UDim2.new(0, 36, 0, 0)
infoPanelTitleLbl.BackgroundTransparency = 1
infoPanelTitleLbl.Text                   = L.infoTitle
infoPanelTitleLbl.TextColor3             = Color3.new(1, 1, 1)
infoPanelTitleLbl.Font                   = Enum.Font.GothamBold
infoPanelTitleLbl.TextSize               = 14
infoPanelTitleLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoPanelTitleLbl.ZIndex                 = 702
infoPanelTitleLbl.Parent                 = infoPanelTitle

-- Kapat butonu — orijinal CLOSE_SHAPE (iki çapraz çizgi, emoji yok)
local infoPanelClose = Instance.new("TextButton")
infoPanelClose.Size             = UDim2.new(0, 24, 0, 24)
infoPanelClose.Position         = UDim2.new(1, -30, 0.5, -12)
infoPanelClose.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
infoPanelClose.BackgroundTransparency = 0.30
infoPanelClose.Text             = ""
infoPanelClose.ZIndex           = 703
infoPanelClose.Parent           = infoPanelTitle
Instance.new("UICorner", infoPanelClose).CornerRadius = UDim.new(1, 0)

-- Çarpı çizgileri (MakeBtn'deki CLOSE_SHAPE ile aynı mantık)
do
	local thick = 2
	local lineLen = 10
	local cl1 = Instance.new("Frame")
	cl1.BorderSizePixel = 0
	cl1.Size       = UDim2.new(0, lineLen, 0, thick)
	cl1.AnchorPoint = Vector2.new(0.5, 0.5)
	cl1.Position   = UDim2.fromScale(0.5, 0.5)
	cl1.Rotation   = 45
	cl1.BackgroundColor3 = Color3.new(1, 1, 1)
	cl1.ZIndex     = 704
	cl1.Parent     = infoPanelClose
	Instance.new("UICorner", cl1).CornerRadius = UDim.new(0, 2)
	local cl2 = cl1:Clone()
	cl2.Rotation  = -45
	cl2.Parent    = infoPanelClose
end

-- İçerik alanı
local infoPanelBody = Instance.new("Frame")
infoPanelBody.Size                   = UDim2.new(1, -24, 1, -46)
infoPanelBody.Position               = UDim2.new(0, 12, 0, 42)
infoPanelBody.BackgroundTransparency = 1
infoPanelBody.ZIndex                 = 701
infoPanelBody.Parent                 = infoPanel

-- 1) Emote adı
local infoEmoteName = Instance.new("TextLabel")
infoEmoteName.Size                   = UDim2.new(1, 0, 0, 22)
infoEmoteName.Position               = UDim2.new(0, 0, 0, 0)
infoEmoteName.BackgroundTransparency = 1
infoEmoteName.Text                   = "—"
infoEmoteName.TextColor3             = Color3.new(1, 1, 1)
infoEmoteName.Font                   = Enum.Font.GothamBold
infoEmoteName.TextSize               = 16
infoEmoteName.TextXAlignment         = Enum.TextXAlignment.Left
infoEmoteName.TextTruncate           = Enum.TextTruncate.AtEnd
infoEmoteName.ZIndex                 = 702
infoEmoteName.Parent                 = infoPanelBody

-- 2) Açıklama (ismin hemen altı)
local infoDescLbl = Instance.new("TextLabel")
infoDescLbl.Size                   = UDim2.new(1, 0, 0, 28)
infoDescLbl.Position               = UDim2.new(0, 0, 0, 24)
infoDescLbl.BackgroundTransparency = 1
infoDescLbl.Text                   = "—"
infoDescLbl.TextColor3             = Color3.fromRGB(140, 140, 165)
infoDescLbl.Font                   = Enum.Font.Gotham
infoDescLbl.TextSize               = 11
infoDescLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoDescLbl.TextYAlignment         = Enum.TextYAlignment.Top
infoDescLbl.TextWrapped            = true
infoDescLbl.ZIndex                 = 702
infoDescLbl.Parent                 = infoPanelBody

-- Ayırıcı çizgi
local infoDivider = Instance.new("Frame")
infoDivider.Size             = UDim2.new(1, 0, 0, 1)
infoDivider.Position         = UDim2.new(0, 0, 0, 56)
infoDivider.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
infoDivider.BorderSizePixel  = 0
infoDivider.ZIndex           = 702
infoDivider.Parent           = infoPanelBody

-- 3) Creator
do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 63)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Crown; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
local infoCreatorLbl = Instance.new("TextLabel")
infoCreatorLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoCreatorLbl.Position               = UDim2.new(0, 18, 0, 61)
infoCreatorLbl.BackgroundTransparency = 1
infoCreatorLbl.Text                   = "—"
infoCreatorLbl.TextColor3             = Color3.fromRGB(140, 200, 255)
infoCreatorLbl.Font                   = Enum.Font.Gotham
infoCreatorLbl.TextSize               = 12
infoCreatorLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoCreatorLbl.ZIndex                 = 702
infoCreatorLbl.Parent                 = infoPanelBody

-- 4) Hız
do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 83)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Emote; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
-- infoSpeedLbl: forward declared above
infoSpeedLbl = Instance.new("TextLabel")
infoSpeedLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoSpeedLbl.Position               = UDim2.new(0, 18, 0, 81)
infoSpeedLbl.BackgroundTransparency = 1
infoSpeedLbl.Text                   = L.speed .. ": 1x"
infoSpeedLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
infoSpeedLbl.Font                   = Enum.Font.Gotham
infoSpeedLbl.TextSize               = 12
infoSpeedLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoSpeedLbl.ZIndex                 = 702
infoSpeedLbl.Parent                 = infoPanelBody

-- RefreshHUDSpeedBtns ve infoSpeedLbl artık tanımlı — bridge'i bağla
_onSpeedChanged = function()
	RefreshHUDSpeedBtns()
	if infoSpeedLbl then
		infoSpeedLbl.Text = L.speed .. ": " .. tostring(Settings.speed) .. "x"
	end
end

-- 5) Fiyat (tam genişlik)
local infoPriceLbl = Instance.new("TextLabel")
infoPriceLbl.Size                   = UDim2.new(1, 0, 0, 16)
infoPriceLbl.Position               = UDim2.new(0, 0, 0, 101)
infoPriceLbl.BackgroundTransparency = 1
infoPriceLbl.Text                   = "—"
infoPriceLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
infoPriceLbl.Font                   = Enum.Font.GothamBold
infoPriceLbl.TextSize               = 12
infoPriceLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoPriceLbl.ZIndex                 = 702
infoPriceLbl.Parent                 = infoPanelBody

-- 6) Favori sayısı (tam genişlik)
local infoFavLbl = Instance.new("TextLabel")
infoFavLbl.Size                   = UDim2.new(1, 0, 0, 16)
infoFavLbl.Position               = UDim2.new(0, 0, 0, 120)
infoFavLbl.BackgroundTransparency = 1
infoFavLbl.Text                   = "—"
infoFavLbl.TextColor3             = Color3.fromRGB(160, 160, 185)
infoFavLbl.Font                   = Enum.Font.Gotham
infoFavLbl.TextSize               = 12
infoFavLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoFavLbl.ZIndex                 = 702
infoFavLbl.Parent                 = infoPanelBody

-- 7) Yaratılma tarihi
do
	local ic = Instance.new("ImageLabel")
	ic.Size = UDim2.new(0, 13, 0, 13); ic.Position = UDim2.new(0, 0, 0, 141)
	ic.BackgroundTransparency = 1; ic.Image = Icons.Recent; ic.ZIndex = 702
	ic.Parent = infoPanelBody
end
local infoDateLbl = Instance.new("TextLabel")
infoDateLbl.Size                   = UDim2.new(1, -18, 0, 16)
infoDateLbl.Position               = UDim2.new(0, 18, 0, 139)
infoDateLbl.BackgroundTransparency = 1
infoDateLbl.Text                   = "—"
infoDateLbl.TextColor3             = Color3.fromRGB(130, 130, 155)
infoDateLbl.Font                   = Enum.Font.Gotham
infoDateLbl.TextSize               = 11
infoDateLbl.TextXAlignment         = Enum.TextXAlignment.Left
infoDateLbl.ZIndex                 = 702
infoDateLbl.Parent                 = infoPanelBody

-- 8) Copy ID butonu + Arkadaş Ekle Modu butonu
friendAddModeBtn = Instance.new("TextButton")
friendAddModeBtn.Size             = UDim2.new(0.48, -2, 0, 26)
friendAddModeBtn.Position         = UDim2.new(0, 0, 0, 161)
friendAddModeBtn.BackgroundColor3 = currentTheme.critical
friendAddModeBtn.Text             = ""
friendAddModeBtn.ZIndex           = 703
friendAddModeBtn.Parent           = infoPanelBody
Instance.new("UICorner", friendAddModeBtn).CornerRadius = UDim.new(0, 8)
local _faBtnImg = Instance.new("ImageLabel")
_faBtnImg.Size = UDim2.new(0, 16, 0, 16)
_faBtnImg.AnchorPoint = Vector2.new(0.5, 0.5)
_faBtnImg.Position = UDim2.new(0.5, 0, 0.5, 0)
_faBtnImg.BackgroundTransparency = 1
_faBtnImg.Image = ResolveAssetImage("rbxassetid://119398141999369")
_faBtnImg.ImageColor3 = Color3.new(1,1,1)
_faBtnImg.ZIndex = 704
_faBtnImg.Parent = friendAddModeBtn

friendAddModeBtn.MouseButton1Click:Connect(function()
	_SetAddMode(not FriendData.addModeActive)
end)

local copyIdBtn = Instance.new("TextButton")
copyIdBtn.Size             = UDim2.new(0.52, -2, 0, 26)
copyIdBtn.Position         = UDim2.new(0.48, 2, 0, 161)
copyIdBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
copyIdBtn.Text             = L.copyId
copyIdBtn.TextColor3       = Color3.fromRGB(180, 180, 210)
copyIdBtn.Font             = Enum.Font.GothamBold
copyIdBtn.TextSize         = 12
copyIdBtn.ZIndex           = 703
copyIdBtn.Parent           = infoPanelBody
Instance.new("UICorner", copyIdBtn).CornerRadius = UDim.new(0, 8)
local copyIdStroke = Instance.new("UIStroke")
copyIdStroke.Color       = Color3.fromRGB(70, 70, 100)
copyIdStroke.Thickness   = 1
copyIdStroke.Parent      = copyIdBtn

local infoIdLbl = nil -- eski referans (kaldırıldı)

-- Panel aç/kapa fonksiyonu
local infoPanelOpen = false
local INFO_OPEN_POS  = UDim2.new(0, 10, 1, -285)
local INFO_CLOSE_POS = UDim2.new(0, -290, 1, -285)

local _copyIdTarget = 0  -- Copy ID için mevcut emote id'si

local function _applyMetaToInfoPanel(meta)
	-- Yaratıcı
	infoCreatorLbl.Text = (meta.creatorName and meta.creatorName ~= "") and meta.creatorName or "—"
	-- Açıklama
	infoDescLbl.Text    = (meta.description and meta.description ~= "") and meta.description or L.noDesc
	-- Fiyat
	if meta.priceStatus == "Free" or meta.price == 0 then
		infoPriceLbl.Text       = L.freePrice
		infoPriceLbl.TextColor3 = Color3.fromRGB(100, 220, 130)
	elseif meta.price and meta.price > 0 then
		infoPriceLbl.Text       = tostring(meta.price) .. " R$"
		infoPriceLbl.TextColor3 = Color3.fromRGB(255, 200, 80)
	else
		infoPriceLbl.Text       = (meta.priceStatus and meta.priceStatus ~= "") and meta.priceStatus or "—"
		infoPriceLbl.TextColor3 = Color3.fromRGB(160, 160, 185)
	end
	-- Favori sayısı
	infoFavLbl.Text = meta.favoriteCount
		and ("♥ " .. tostring(meta.favoriteCount))
		or "—"
	-- Tarih
	if meta.createdUtc and meta.createdUtc ~= "" then
		infoDateLbl.Text = meta.createdUtc:sub(1, 10)
	else
		infoDateLbl.Text = "—"
	end
	-- HUD creator
	hudCreator.Text = (meta.creatorName and meta.creatorName ~= "") and meta.creatorName or "Vexro Emotes"
end

local function _fetchAndCacheMeta(numId, targetId)
	-- MarketplaceService ile metadata çek (native Roblox, HTTP'ye gerek yok)
	local ok, info = pcall(function()
		return game:GetService("MarketplaceService"):GetProductInfo(numId)
	end)
	if not ok or not info then return end

	local price      = info.PriceInRobux
	local isFree     = info.IsPublicDomain or (price and price == 0)
	local isNotSale  = info.IsForSale == false and not isFree

	local meta = {
		creatorName   = tostring((info.Creator and info.Creator.Name) or ""),
		description   = tostring(info.Description or ""),
		price         = isFree and 0 or price,
		priceStatus   = isFree and "Free" or (isNotSale and "Not for sale" or ""),
		favoriteCount = nil,
		createdUtc    = "",
	}

	_emoteMetaCache[numId] = meta

	-- emotes tablosunu da güncelle (gelecekteki arama için)
	local eData = EmotesById[numId]
	if eData then
		eData.creatorName   = meta.creatorName
		eData.description   = meta.description
		eData.price         = meta.price
		eData.priceStatus   = meta.priceStatus
		eData.favoriteCount = meta.favoriteCount
		eData.createdUtc    = meta.createdUtc
	end

	-- Panel hâlâ aynı emote için açıksa UI'yi güncelle
	if infoPanelOpen and _copyIdTarget == numId then
		_applyMetaToInfoPanel(meta)
	end
end

local function OpenInfoPanel(emoteId, emoteName)
	infoEmoteName.Text  = emoteName or "—"
	infoSpeedLbl.Text   = L.speed .. ": " .. tostring(Settings.speed) .. "x"
	infoPanelStroke.Color           = currentTheme.accent
	infoPanelTitle.BackgroundColor3 = currentTheme.accent
	_copyIdTarget = tonumber(emoteId) or 0

	local numId = tonumber(emoteId)

	-- Önce önbellekten veya Emotes tablosundan bak
	local meta = _emoteMetaCache[numId]
	if not meta then
		local eData = EmotesById[numId]
		if eData and eData.creatorName ~= "" then
			-- Emotes tablosunda zaten tam veri var
			meta = eData
		end
	end

	if meta then
		_applyMetaToInfoPanel(meta)
	else
		-- Placeholder göster, arka planda çek
		infoCreatorLbl.Text = "…"
		infoDescLbl.Text    = "…"
		infoPriceLbl.Text   = "…"
		infoPriceLbl.TextColor3 = Color3.fromRGB(160, 160, 185)
		infoFavLbl.Text     = "…"
		infoDateLbl.Text    = "…"
		hudCreator.Text     = "Vexro Emotes"
		if numId and numId > 0 then
			task.spawn(_fetchAndCacheMeta, numId, numId)
		end
	end

	-- Copy ID buton tıklama
	copyIdBtn.Text = L.copyId .. ": " .. tostring(numId)

	infoPanel.Position = INFO_CLOSE_POS
	infoPanel.Visible  = true
	infoPanelOpen      = true
	TweenService:Create(infoPanel,
		TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = INFO_OPEN_POS}
	):Play()
	TweenService:Create(hudInfoBtn, TweenInfo.new(0.15),
		{BackgroundTransparency = 0.05}):Play()
end

copyIdBtn.MouseButton1Click:Connect(function()
	pcall(function()
		if setclipboard then
			setclipboard(tostring(_copyIdTarget))
		end
	end)
	local orig = copyIdBtn.Text
	copyIdBtn.Text            = L.copied
	copyIdBtn.TextColor3      = Color3.fromRGB(100, 220, 130)
	task.delay(1.5, function()
		copyIdBtn.Text       = orig
		copyIdBtn.TextColor3 = Color3.fromRGB(180, 180, 210)
	end)
end)

local function CloseInfoPanel()
	infoPanelOpen = false
	-- Panelin şu anki konumundan sola kayarak kapan (sürüklendiyse oradan çıkar)
	local curX = infoPanel.AbsolutePosition.X
	local curY = infoPanel.AbsolutePosition.Y
	local exitPos = UDim2.new(0, curX - 300, 0, curY)
	TweenService:Create(infoPanel,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = exitPos}
	):Play()
	TweenService:Create(hudInfoBtn, TweenInfo.new(0.15),
		{BackgroundTransparency = 0.40}):Play()
	task.delay(0.22, function()
		if not infoPanelOpen then infoPanel.Visible = false end
	end)
end

-- "i" butonuna tıklayınca panel aç/kapat
hudInfoBtn.MouseButton1Click:Connect(function()
	if infoPanelOpen then
		CloseInfoPanel()
	else
		OpenInfoPanel(_currentInfoId or 0, _currentInfoName or "Emote")
	end
end)
infoPanelClose.MouseButton1Click:Connect(CloseInfoPanel)

-- ▸ InfoPanel sürükle-bırak — başlık çubuğundan tutarak taşı
local _ipDragActive     = false
local _ipDragMouseStart = Vector2.zero
local _ipDragPanelStart = Vector2.zero

infoPanelTitle.InputBegan:Connect(function(inp)
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	_ipDragActive     = true
	_ipDragMouseStart = Vector2.new(inp.Position.X, inp.Position.Y)
	_ipDragPanelStart = Vector2.new(
		infoPanel.AbsolutePosition.X,
		infoPanel.AbsolutePosition.Y
	)
end)

UserInputService.InputChanged:Connect(function(inp)
	if not _ipDragActive then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	local delta = Vector2.new(inp.Position.X, inp.Position.Y) - _ipDragMouseStart
	infoPanel.Position = UDim2.new(0, _ipDragPanelStart.X + delta.X,
	                               0, _ipDragPanelStart.Y + delta.Y)
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		_ipDragActive = false
	end
end)

-- ▸ Slider knob sürükleme
local hudKnobDragging = false

hudKnob.InputBegan:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		hudKnobDragging = true
	end
end)

-- Slider arka planına tıkla → o noktaya atla
hudSliderBg.InputBegan:Connect(function(inp)
	if inp.UserInputType ~= Enum.UserInputType.MouseButton1
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	if currentAnimTrack and currentAnimTrack.Length and currentAnimTrack.Length > 0 then
		local alpha = math.clamp(
			(inp.Position.X - hudSliderBg.AbsolutePosition.X) / hudSliderBg.AbsoluteSize.X,
			0, 1)
		pcall(function() currentAnimTrack.TimePosition = alpha * currentAnimTrack.Length end)
	end
end)

UserInputService.InputEnded:Connect(function(inp)
	if inp.UserInputType == Enum.UserInputType.MouseButton1
	or inp.UserInputType == Enum.UserInputType.Touch then
		hudKnobDragging = false
	end
end)

-- Sürükleme → TimePosition güncelle
UserInputService.InputChanged:Connect(function(inp)
	if not hudKnobDragging then return end
	if inp.UserInputType ~= Enum.UserInputType.MouseMovement
	and inp.UserInputType ~= Enum.UserInputType.Touch then return end
	if currentAnimTrack and currentAnimTrack.Length and currentAnimTrack.Length > 0 then
		local alpha = math.clamp(
			(inp.Position.X - hudSliderBg.AbsolutePosition.X) / hudSliderBg.AbsoluteSize.X,
			0, 1)
		pcall(function() currentAnimTrack.TimePosition = alpha * currentAnimTrack.Length end)
	end
end)

-- ▸ RenderStepped: slider'ı her kare canlı güncelle
local function StartHUDTracking()
	-- Önceki bağlantıyı kes → FPS kaybını önle
	if hudTrackerConn then
		hudTrackerConn:Disconnect()
		hudTrackerConn = nil
	end

	hudTrackerConn = RunService.RenderStepped:Connect(function()
		if not currentAnimTrack or not currentAnimTrack.IsPlaying then return end
		local len = currentAnimTrack.Length
		if not len or len <= 0 then return end

		-- TimePosition / Length = ilerleme oranı (0..1)
		local alpha = math.clamp(currentAnimTrack.TimePosition / len, 0, 1)

		-- Slider fill ve knob'u güncelle (tween gerekmez, her frame smooth)
		hudFill.Size     = UDim2.new(alpha, 0, 1, 0)
		hudKnob.Position = UDim2.new(alpha, 0, 0.5, 0)

		-- Tema renkleriyle senkron tut
		hudFill.BackgroundColor3    = currentTheme.accent
		hudStroke.Color             = currentTheme.stroke
		hudInfoBtn.BackgroundColor3 = currentTheme.accent
		infoPanelStroke.Color       = currentTheme.accent
	end)
end

local function StopHUDTracking()
	-- Disconnect -> RenderStepped baglantisini kes (FPS korunur)
	if hudTrackerConn then
		hudTrackerConn:Disconnect()
		hudTrackerConn = nil
	end
end

-- ShowEmoteHUD: HUD'u asagidan kaydirarak goster
ShowEmoteHUD = function(emoteId, emoteName)
	if not Settings.showHUD then return end
	-- Bekleyen gizleme işlemini iptal et (hızlı geçiş hatası düzeltmesi)
	_hudHideToken = _hudHideToken + 1

	_currentInfoId   = emoteId
	_currentInfoName = emoteName

	RefreshHUDFavBtn()
	hudName.Text    = emoteName or "Emote"
	hudCreator.Text = "Vexro Emotes"

	-- Duraklat butonunu sıfırla
	_isPaused = false
	RefreshHudPauseBtn()

	if infoPanelOpen then
		OpenInfoPanel(emoteId, emoteName)
	end

	HUD.Position               = UDim2.new(0.5, 0, 1, -88)
	HUD.BackgroundTransparency = 1
	HUD.Visible                = true

	TweenService:Create(HUD,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = UDim2.new(0.5, 0, 1, -120), BackgroundTransparency = 0.30}
	):Play()

	RefreshHUDSpeedBtns()
	StartHUDTracking()
end

-- HideEmoteHUD: HUD'u asagiya kaydirarak gizle
HideEmoteHUD = function()
	_isPaused = false
	RefreshHudPauseBtn()
	-- stopBtn görselini sıfırla (doğrudan, döngü yaratmamak için)
	if _stopBtnSquare then _stopBtnSquare.Image = ResolveAssetImage("rbxassetid://113416463749658") end
	StopHUDTracking()
	TweenService:Create(HUD,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{Position = UDim2.new(0.5, 0, 1, -88), BackgroundTransparency = 1}
	):Play()
	-- Token tabanlı iptal: sadece güncel token eşleşiyorsa gizle
	local token = _hudHideToken
	task.delay(0.22, function()
		if HUD and _hudHideToken == token then
			HUD.Visible = false
		end
	end)
	if infoPanelOpen then CloseInfoPanel() end
end

-- ----------------------------------------------------------------
-- BOLUM 4 - HUD & BLENDING ENTEGRASYONU
-- ----------------------------------------------------------------

local _origPlayEmote = PlayEmote
PlayEmote = function(id, name, silent)
	_origPlayEmote(id, name, silent)
	-- Anlık token'ı yakala: bu emote için geçerli token
	local myToken = _hudHideToken + 1
	_hudHideToken = myToken
	task.defer(function()
		-- Başka bir emote daha geçildiyse bu defer'ı atla
		if _hudHideToken ~= myToken then return end
		if currentAnimTrack then
			ShowEmoteHUD(id, name)
			local tracked = currentAnimTrack
			tracked.Stopped:Connect(function()
				if (currentAnimTrack == tracked or not currentAnimTrack)
				and not isComboActive then
					HideEmoteHUD()
				end
			end)
		end
	end)
end

local _origStopEmote = StopEmote
StopEmote = function(showNotif)
	_origStopEmote(showNotif)
	isComboActive = false
	ComboQueue    = {}
	HideEmoteHUD()
end

-- ----------------------------------------------------------------
-- BOLUM 5 - COMBO SIRASI
-- ----------------------------------------------------------------

-- comboQueue_UI forward declared above; reset here
comboQueue_UI = {}

local comboRow = MakeRow("", L.comboTitle, "", 25, 196)
comboRow.Size             = UDim2.new(1, 0, 0, 196)
comboRow.ClipsDescendants = true

local comboTitleLbl = comboRow:FindFirstChildWhichIsA("TextLabel")
if comboTitleLbl then
	comboTitleLbl.Size     = UDim2.new(1, -12, 0, 20)
	comboTitleLbl.Position = UDim2.new(0, 10, 0, 5)
	comboTitleLbl.TextSize = 13
end

local slotHolder = Instance.new("Frame")
slotHolder.Size             = UDim2.new(1, -12, 0, 36)
slotHolder.Position         = UDim2.new(0, 6, 0, 28)
slotHolder.BackgroundTransparency = 1
slotHolder.ZIndex           = 9
slotHolder.Parent           = comboRow
local slotLayout = Instance.new("UIListLayout")
slotLayout.FillDirection    = Enum.FillDirection.Horizontal
slotLayout.Padding          = UDim.new(0, 5)
slotLayout.Parent           = slotHolder

-- comboSlots forward declared above; populate here
comboSlots = {}
for si = 1, 3 do
	local s = Instance.new("TextButton")
	s.Size             = UDim2.new(0.316, 0, 1, 0)
	s.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
	s.Text             = L.slotLabel .. " " .. si
	s.TextColor3       = Color3.fromRGB(120, 120, 148)
	s.Font             = Enum.Font.Gotham
	s.TextSize         = 11
	s.ZIndex           = 9
	s.Parent           = slotHolder
	Instance.new("UICorner", s).CornerRadius = UDim.new(0, 8)
	comboSlots[si] = s
	s.MouseButton1Click:Connect(function()
		if comboQueue_UI[si] then
			table.remove(comboQueue_UI, si)
			for j = 1, 3 do
				local e = comboQueue_UI[j]
				comboSlots[j].Text = e and e.name:sub(1,9) or ("Slot " .. j)
				TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
					BackgroundColor3 = e and currentTheme.accent or Color3.fromRGB(30,30,46)
				}):Play()
			end
		end
	end)
end

local comboBtnHolder = Instance.new("Frame")
comboBtnHolder.Size             = UDim2.new(1, -12, 0, 30)
comboBtnHolder.Position         = UDim2.new(0, 6, 0, 70)
comboBtnHolder.BackgroundTransparency = 1
comboBtnHolder.ZIndex           = 9
comboBtnHolder.Parent           = comboRow
local comboBtnLayout = Instance.new("UIListLayout")
comboBtnLayout.FillDirection    = Enum.FillDirection.Horizontal
comboBtnLayout.Padding          = UDim.new(0, 5)
comboBtnLayout.Parent           = comboBtnHolder

local addComboBtn = Instance.new("TextButton")
addComboBtn.Size             = UDim2.new(0.5, -2, 1, 0)
addComboBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 170)
addComboBtn.Text             = L.addEmote
addComboBtn.TextColor3       = Color3.new(1, 1, 1)
addComboBtn.Font             = Enum.Font.GothamBold
addComboBtn.TextSize         = 12
addComboBtn.ZIndex           = 9
addComboBtn.Parent           = comboBtnHolder
Instance.new("UICorner", addComboBtn).CornerRadius = UDim.new(0, 8)

local playComboBtn = Instance.new("TextButton")
playComboBtn.Size             = UDim2.new(0.5, -2, 1, 0)
playComboBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 80)
playComboBtn.Text             = L.playCombo
playComboBtn.TextColor3       = Color3.new(1, 1, 1)
playComboBtn.Font             = Enum.Font.GothamBold
playComboBtn.TextSize         = 12
playComboBtn.ZIndex           = 9
playComboBtn.Parent           = comboBtnHolder
Instance.new("UICorner", playComboBtn).CornerRadius = UDim.new(0, 8)

-- ▸ Loop toggle butonu
local loopComboBtn = Instance.new("TextButton")
loopComboBtn.Size             = UDim2.new(1, -12, 0, 26)
loopComboBtn.Position         = UDim2.new(0, 6, 0, 106)
loopComboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
loopComboBtn.Text             = L.loopText .. ": " .. L.off
loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
loopComboBtn.Font             = Enum.Font.GothamBold
loopComboBtn.TextSize         = 12
loopComboBtn.ZIndex           = 9
loopComboBtn.Parent           = comboRow
Instance.new("UICorner", loopComboBtn).CornerRadius = UDim.new(0, 8)
local loopStroke = Instance.new("UIStroke")
loopStroke.Color        = Color3.fromRGB(60, 60, 90)
loopStroke.Thickness    = 1
loopStroke.Transparency = 0.5
loopStroke.Parent       = loopComboBtn
-- Sol taraftaki loop ikonu (Icons.Refresh asset'i)
local loopIcon = Instance.new("ImageLabel")
loopIcon.Size                   = UDim2.new(0, 14, 0, 14)
loopIcon.Position               = UDim2.new(0, 8, 0.5, -7)
loopIcon.BackgroundTransparency = 1
loopIcon.Image                  = ResolveAssetImage(Icons.Refresh)
loopIcon.ImageColor3            = Color3.fromRGB(120, 120, 148)
loopIcon.ZIndex                 = 10
loopIcon.Parent                 = loopComboBtn
-- İkona yer açmak için text'i sağa kaydır
loopComboBtn.TextXAlignment = Enum.TextXAlignment.Center

loopComboBtn.MouseButton1Click:Connect(function()
	_comboLoopEnabled = not _comboLoopEnabled
	if _comboLoopEnabled then
		loopComboBtn.Text             = L.loopText .. ": " .. L.on
		loopComboBtn.TextColor3       = Color3.new(1, 1, 1)
		loopIcon.ImageColor3          = Color3.new(1, 1, 1)
		TweenService:Create(loopComboBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = currentTheme.accent
		}):Play()
		loopStroke.Color = currentTheme.accent
	else
		loopComboBtn.Text             = L.loopText .. ": " .. L.off
		loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
		loopIcon.ImageColor3          = Color3.fromRGB(120, 120, 148)
		TweenService:Create(loopComboBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(30, 30, 46)
		}):Play()
		loopStroke.Color = Color3.fromRGB(60, 60, 90)
	end
end)

local clearComboBtn = Instance.new("TextButton")
clearComboBtn.Size             = UDim2.new(1, -12, 0, 26)
clearComboBtn.Position         = UDim2.new(0, 6, 0, 138)
clearComboBtn.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
clearComboBtn.Text             = L.clearCombo
clearComboBtn.TextColor3       = Color3.new(1, 1, 1)
clearComboBtn.Font             = Enum.Font.GothamBold
clearComboBtn.TextSize         = 12
clearComboBtn.ZIndex           = 9
clearComboBtn.Parent           = comboRow
Instance.new("UICorner", clearComboBtn).CornerRadius = UDim.new(0, 8)

addComboBtn.MouseButton1Click:Connect(function()
	if #comboQueue_UI >= 3 then return end
	if not _currentInfoId then
		-- Emote seçilmedi — butonu kısa süre kırmızı yak
		local origCol = addComboBtn.BackgroundColor3
		addComboBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
		addComboBtn.Text = L.selectFirst
		task.delay(0.7, function()
			addComboBtn.BackgroundColor3 = origCol
			addComboBtn.Text = L.addEmote
		end)
		return
	end
	table.insert(comboQueue_UI, {id = _currentInfoId, name = _currentInfoName or "Emote"})
	local idx = #comboQueue_UI
	comboSlots[idx].Text = (comboQueue_UI[idx].name):sub(1, 9)
	TweenService:Create(comboSlots[idx], TweenInfo.new(0.15), {
		BackgroundColor3 = currentTheme.accent
	}):Play()
end)

playComboBtn.MouseButton1Click:Connect(function()
	if #comboQueue_UI == 0 then return end
	local list = {}
	for _, e in ipairs(comboQueue_UI) do
		table.insert(list, {id = e.id, name = e.name})
	end
	StartCombo(list)
end)

clearComboBtn.MouseButton1Click:Connect(function()
	comboQueue_UI    = {}
	isComboActive    = false
	ComboQueue       = {}
	_comboLoopList   = {}
	-- Loop kapatılsın
	if _comboLoopEnabled then
		_comboLoopEnabled             = false
		loopComboBtn.Text             = L.loopText .. ": " .. L.off
		loopComboBtn.TextColor3       = Color3.fromRGB(120, 120, 148)
		loopComboBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 46)
		loopStroke.Color              = Color3.fromRGB(60, 60, 90)
		loopIcon.ImageColor3          = Color3.fromRGB(120, 120, 148)
	end
	for j = 1, 3 do
		comboSlots[j].Text = L.slotLabel .. " " .. j
		TweenService:Create(comboSlots[j], TweenInfo.new(0.15), {
			BackgroundColor3 = Color3.fromRGB(30, 30, 46)
		}):Play()
	end
end)

-- Tema değişince loop butonu aktifse yeni accent rengine güncelle
do
	local _prevApply = ApplyTheme
	ApplyTheme = function(name)
		_prevApply(name)
		if _comboLoopEnabled and loopComboBtn and loopComboBtn.Parent then
			pcall(function()
				loopComboBtn.BackgroundColor3 = currentTheme.accent
				loopStroke.Color             = currentTheme.accent
				loopIcon.ImageColor3         = Color3.new(1, 1, 1)
			end)
		end
	end
end

end -- _VexroExtend kapatiliyor
_VexroExtend()
