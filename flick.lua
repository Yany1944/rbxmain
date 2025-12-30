--[[
	WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

if game.PlaceId == 17625359962 then
local PlayerGui = game.CoreGui

local Simple = Instance.new("ScreenGui")
Simple.Name = "Simple"
Simple.ResetOnSpawn = true
Simple.Parent = PlayerGui

local Window = Instance.new("Frame")
Window.Name = "Window"
Window.Position = UDim2.new(0, 0, 0, 0)
Window.Size = UDim2.new(0.20000000298023224, 0, 0.5, 0)
Window.AnchorPoint = Vector2.new(0, 0)
Window.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Window.BorderSizePixel = 0
Window.Parent = Simple
Window.Active = true
Window.Draggable = true

local UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
UIAspectRatioConstraint.Name = "UIAspectRatioConstraint"
UIAspectRatioConstraint.Parent = Window
UIAspectRatioConstraint.AspectRatio = 0.8

local UIGradient = Instance.new("UIGradient")
UIGradient.Name = "UIGradient"
UIGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 10, 10)), ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 45, 45))})
UIGradient.Rotation = -90
UIGradient.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)})
UIGradient.Offset = Vector2.new(0, 0)
UIGradient.Parent = Window

local Container = Instance.new("Frame")
Container.Name = "Container"
Container.Position = UDim2.new(0, 5, 0.10000000149011612, 10)
Container.Size = UDim2.new(1, -10, 0.6000000238418579, 30)
Container.AnchorPoint = Vector2.new(0, 0)
Container.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Container.BackgroundTransparency = 1
Container.Parent = Window

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Name = "UIListLayout"
UIListLayout.Parent = Container
UIListLayout.Padding = UDim.new(0, 2)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder


local Toggle = Instance.new("Frame")
Toggle.Name = "Toggle"
Toggle.Position = UDim2.new(0, 0, 0, 0)
Toggle.Size = UDim2.new(1, 0, 0.10000000149011612, 0)
Toggle.AnchorPoint = Vector2.new(0, 0)
Toggle.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Toggle.BackgroundTransparency = 1
Toggle.Parent = Container
Toggle.LayoutOrder = 3


local effect = Instance.new("Frame")
effect.Name = "effect"
effect.Position = UDim2.new(0.8500000238418579, 0, 0, 0)
effect.Size = UDim2.new(0.12999999523162842, 0, 1, 0)
effect.AnchorPoint = Vector2.new(0, 0)
effect.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
effect.BackgroundTransparency = 1
effect.BorderSizePixel = 0
effect.Parent = Toggle

local EffectText = Instance.new("TextLabel")
EffectText.Name = "EffectText"
EffectText.Position = UDim2.new(0, 0, 0, 0)
EffectText.Size = UDim2.new(1, 0, 1, 0)
EffectText.AnchorPoint = Vector2.new(0, 0)
EffectText.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
EffectText.BackgroundTransparency = 1
EffectText.BorderSizePixel = 0
EffectText.Text = "OFF"
EffectText.TextColor3 = Color3.fromRGB(255, 0, 0)
EffectText.TextScaled = true
EffectText.TextSize = 8
EffectText.Font = Enum.Font.SourceSansBold
EffectText.TextXAlignment = Enum.TextXAlignment.Center
EffectText.TextYAlignment = Enum.TextYAlignment.Center
EffectText.ZIndex = 1
EffectText.Parent = effect


local TriggerButton = Instance.new("TextButton")
TriggerButton.Name = "Trigger"
TriggerButton.Parent = Toggle
TriggerButton.BackgroundTransparency = 1
TriggerButton.Size = UDim2.new(1, 0, 1, 0)
TriggerButton.Position = UDim2.new(0, 0, 0, 0)
TriggerButton.Text = ""
TriggerButton.ZIndex = 3


local toggle = false
local Lighting = game:GetService("Lighting")

TriggerButton.MouseButton1Click:Connect(function()
    toggle = not toggle
    if toggle then
        EffectText.Text = "ON"
        EffectText.TextColor3 = Color3.fromRGB(0, 255, 0)
        
        -- Soft night mode
        Lighting.TimeOfDay = "20:00:00" -- evening
        Lighting.Brightness = 1 -- not too dark
        Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 60) -- soft ambient light
        Lighting.FogEnd = 500 -- small fog effect
        Lighting.FogColor = Color3.fromRGB(50, 50, 60)
        
    else
        EffectText.Text = "OFF"
        EffectText.TextColor3 = Color3.fromRGB(255, 0, 0)
        
        -- Revert to normal daytime
        Lighting.TimeOfDay = "14:00:00"
        Lighting.Brightness = 2
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.FogEnd = 100000
        Lighting.FogColor = Color3.fromRGB(255, 255, 255)
    end
end)


local Text = Instance.new("TextLabel")
Text.Name = "Text"
Text.Position = UDim2.new(0, 0, 0, 0)
Text.Size = UDim2.new(1, -40, 1, 0)
Text.AnchorPoint = Vector2.new(0, 0)
Text.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Text.BackgroundTransparency = 1
Text.BorderSizePixel = 1
Text.Text = "Night mode"
Text.TextColor3 = Color3.fromRGB(255, 255, 255)
Text.TextScaled = true
Text.TextSize = 8
Text.Font = Enum.Font.SourceSansSemibold
Text.TextXAlignment = Enum.TextXAlignment.Left
Text.ZIndex = 1
Text.Parent = Toggle

local Toggle_2 = Instance.new("Frame")
Toggle_2.Name = "Toggle"
Toggle_2.Position = UDim2.new(0, 0, 0, 0)
Toggle_2.Size = UDim2.new(1, 0, 0.10000000149011612, 0)
Toggle_2.AnchorPoint = Vector2.new(0, 0)
Toggle_2.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Toggle_2.BackgroundTransparency = 1
Toggle_2.Parent = Container
Toggle_2.LayoutOrder = 4

local effect_2 = Instance.new("Frame")
effect_2.Name = "effect"
effect_2.Position = UDim2.new(0.8500000238418579, 0, 0, 0)
effect_2.Size = UDim2.new(0.12999999523162842, 0, 1, 0)
effect_2.AnchorPoint = Vector2.new(0, 0)
effect_2.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
effect_2.BackgroundTransparency = 1
effect_2.BorderSizePixel = 0
effect_2.Parent = Toggle_2

local EffectText_2 = Instance.new("TextLabel")
EffectText_2.Name = "EffectText"
EffectText_2.Position = UDim2.new(0, 0, 0, 0)
EffectText_2.Size = UDim2.new(1, 0, 1, 0)
EffectText_2.AnchorPoint = Vector2.new(0, 0)
EffectText_2.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
EffectText_2.BackgroundTransparency = 1
EffectText_2.BorderSizePixel = 0
EffectText_2.Text = "OFF"
EffectText_2.TextColor3 = Color3.fromRGB(255,0, 0)
EffectText_2.TextScaled = true
EffectText_2.TextSize = 8
EffectText_2.Font = Enum.Font.SourceSansBold
EffectText_2.TextXAlignment = Enum.TextXAlignment.Center
EffectText_2.TextYAlignment = Enum.TextYAlignment.Center
EffectText_2.ZIndex = 1
EffectText_2.Parent = effect_2

local Text_2 = Instance.new("TextLabel")
Text_2.Name = "Text"
Text_2.Position = UDim2.new(0, 0, 0, 0)
Text_2.Size = UDim2.new(1, -40, 1, 0)
Text_2.AnchorPoint = Vector2.new(0, 0)
Text_2.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Text_2.BackgroundTransparency = 1
Text_2.BorderSizePixel = 1
Text_2.Text = "Chams"
Text_2.TextColor3 = Color3.fromRGB(255, 255, 255)
Text_2.TextScaled = true
Text_2.TextSize = 8
Text_2.Font = Enum.Font.SourceSansSemibold
Text_2.TextXAlignment = Enum.TextXAlignment.Left
Text_2.ZIndex = 1
Text_2.Parent = Toggle_2

local TriggerButton_2 = Instance.new("TextButton")
TriggerButton_2.Name = "Trigger_2"
TriggerButton_2.Parent = Toggle_2
TriggerButton_2.BackgroundTransparency = 1
TriggerButton_2.Size = UDim2.new(1, 0, 1, 0)
TriggerButton_2.Position = UDim2.new(0, 0, 0, 0)
TriggerButton_2.Text = ""
TriggerButton_2.ZIndex = 3



local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local ChamsEnabled = false
local VisibleColor = Color3.fromRGB(170,170,255)
local InvisibleColor = Color3.fromRGB(170,100,255)

local OriginalAppearance = {}

local function isVisible(part)
	if not part then return false end
	local origin = Camera.CFrame.Position
	local direction = (part.Position - origin).Unit * (part.Position - origin).Magnitude
	local ray = Ray.new(origin, direction)
	local hit = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
	return not hit or hit:IsDescendantOf(part.Parent)
end

local function applyChams(char)
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	if not OriginalAppearance[char] then
		OriginalAppearance[char] = {}
		for _, v in pairs(char:GetDescendants()) do
			if v:IsA("BasePart") or v:IsA("MeshPart") then
				OriginalAppearance[char][v] = {
					Color = v.Color,
					Material = v.Material,
					Transparency = v.Transparency
				}
			elseif v:IsA("Decal") or v:IsA("Texture") then
				OriginalAppearance[char][v] = {Transparency = v.Transparency}
			elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") then
				OriginalAppearance[char][v] = {Parent = v.Parent}
			elseif v:IsA("Accessory") then
				OriginalAppearance[char][v] = {Parent = v.Parent}
			end
		end
	end

	-- Remove decals, shirts, pants, accessories
	for _, v in pairs(char:GetDescendants()) do
		if v:IsA("Decal") or v:IsA("Texture") then
			v.Transparency = 1
		elseif v:IsA("Shirt") or v:IsA("Pants") or v:IsA("BodyColors") or v:IsA("Accessory") then
			v.Parent = nil
		end
	end

	-- Apply Neon to visible parts (skip transparency 1)
	for _, v in pairs(char:GetDescendants()) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and v.Transparency < 1 then
			v.Material = Enum.Material.Neon
			v.Color = VisibleColor
			v.Transparency = 0.45
		end
	end

	if not char:FindFirstChild("ChamsHighlight") then
		local hl = Instance.new("Highlight")
		hl.Name = "ChamsHighlight"
		hl.FillTransparency = 0
		hl.OutlineTransparency = 1
		hl.Enabled = false
		hl.FillColor = InvisibleColor
		hl.Adornee = char
		hl.Parent = char
	end
end

local function removeChams(char)
	if not char or not OriginalAppearance[char] then return end
	for v, props in pairs(OriginalAppearance[char]) do
		if (v:IsA("BasePart") or v:IsA("MeshPart")) and props.Transparency < 1 then
			v.Color = props.Color
			v.Material = props.Material
			v.Transparency = props.Transparency
		elseif v:IsA("Decal") or v:IsA("Texture") then
			v.Transparency = props.Transparency
		else
			v.Parent = props.Parent
		end
	end
	local hl = char:FindFirstChild("ChamsHighlight")
	if hl then hl:Destroy() end
	OriginalAppearance[char] = nil
end

local function updateChams()
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
			local visible = isVisible(plr.Character.HumanoidRootPart)
			local hl = plr.Character:FindFirstChild("ChamsHighlight")
			if hl then hl.Enabled = not visible end
		end
	end
end

local function setupPlayer(plr)
	plr.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		task.wait(0.1)
		if ChamsEnabled then
			applyChams(char)
		end
	end)
	if plr.Character and ChamsEnabled then
		applyChams(plr.Character)
	end
end

for _, plr in pairs(Players:GetPlayers()) do
	if plr ~= LocalPlayer then setupPlayer(plr) end
end
Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(plr)
	if plr.Character then removeChams(plr.Character) end
end)

RunService.RenderStepped:Connect(function()
	if ChamsEnabled then updateChams() end
end)

-- // TriggerButton Toggle
TriggerButton_2.MouseButton1Click:Connect(function()
	if EffectText_2.Text == "OFF" then
		EffectText_2.Text = "ON"
		EffectText_2.TextColor3 = Color3.fromRGB(0, 255, 0)
		ChamsEnabled = true
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				applyChams(plr.Character)
			end
		end
	else
		EffectText_2.Text = "OFF"
		EffectText_2.TextColor3 = Color3.fromRGB(255, 0, 0)
		ChamsEnabled = false
		for _, plr in pairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				removeChams(plr.Character)
			end
		end
	end
end)

local Toggle_3 = Instance.new("Frame")
Toggle_3.Name = "Toggle"
Toggle_3.Position = UDim2.new(0, 0, 0, 0)
Toggle_3.Size = UDim2.new(1, 0, 0.10000000149011612, 0)
Toggle_3.AnchorPoint = Vector2.new(0, 0)
Toggle_3.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Toggle_3.BackgroundTransparency = 1
Toggle_3.LayoutOrder = 1
Toggle_3.Parent = Container






local effect_3 = Instance.new("Frame")
effect_3.Name = "effect"
effect_3.Position = UDim2.new(0.8500000238418579, 0, 0, 0)
effect_3.Size = UDim2.new(0.12999999523162842, 0, 1, 0)
effect_3.AnchorPoint = Vector2.new(0, 0)
effect_3.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
effect_3.BackgroundTransparency = 1
effect_3.BorderSizePixel = 0
effect_3.Parent = Toggle_3

local EffectText_3 = Instance.new("TextLabel")
EffectText_3.Name = "EffectText"
EffectText_3.Position = UDim2.new(0, 0, 0, 0)
EffectText_3.Size = UDim2.new(1, 0, 1, 0)
EffectText_3.AnchorPoint = Vector2.new(0, 0)
EffectText_3.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
EffectText_3.BackgroundTransparency = 1
EffectText_3.BorderSizePixel = 0
EffectText_3.Text = "OFF"
EffectText_3.TextColor3 = Color3.fromRGB(255, 0, 0)
EffectText_3.TextScaled = true
EffectText_3.TextSize = 8
EffectText_3.Font = Enum.Font.SourceSansBold
EffectText_3.TextXAlignment = Enum.TextXAlignment.Center
EffectText_3.TextYAlignment = Enum.TextYAlignment.Center
EffectText_3.ZIndex = 1
EffectText_3.Parent = effect_3


local TriggerButton_3 = Instance.new("TextButton")
TriggerButton_3.Name = "Trigger_3"
TriggerButton_3.Parent = Toggle_3
TriggerButton_3.BackgroundTransparency = 1
TriggerButton_3.Size = UDim2.new(1, 0, 1, 0)
TriggerButton_3.Position = UDim2.new(0, 0, 0, 0)
TriggerButton_3.Text = ""
TriggerButton_3.ZIndex = 3



local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local holdingMouse = false
local pcConnectionBegan, pcConnectionEnded

TriggerButton_3.MouseButton1Click:Connect(function()
	if EffectText_3.Text == "OFF" then
		EffectText_3.Text = "ON"
		EffectText_3.TextColor3 = Color3.fromRGB(0, 255, 0)

		local Players = game:GetService("Players")
		local Workspace = game:GetService("Workspace")
		local Camera = Workspace.CurrentCamera
		local LocalPlayer = Players.LocalPlayer
		local FOV = 600
		local flickTime = 0.1
		local flicking = false

		local function isVisible(part)
			if not part or not part:IsA("BasePart") then return false end
			local origin = Camera.CFrame.Position
			local direction = (part.Position - origin)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
			local result = Workspace:Raycast(origin, direction, raycastParams)
			if result and result.Instance then
				return result.Instance:IsDescendantOf(part.Parent)
			end
			return true
		end

		local function getClosestHead()
			local closestTarget, shortestDistance = nil, FOV
			local teamCheck = false
			for _, player in pairs(Players:GetPlayers()) do
				if player.Team ~= nil then
					teamCheck = true
					break
				end
			end

			local function checkCharacter(char, player)
				if not char then return end
				local head = char:FindFirstChild("Head")
				local humanoid = char:FindFirstChildOfClass("Humanoid")
				if head and humanoid and humanoid.Health > 0 then
					if teamCheck and player and player.Team == LocalPlayer.Team then return end
					if isVisible(head) then
						local pos, visible = Camera:WorldToViewportPoint(head.Position)
						if visible then
							local screenCenter = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
							local distance = (Vector2.new(pos.X,pos.Y)-screenCenter).Magnitude
							if distance < shortestDistance then
								shortestDistance = distance
								closestTarget = head
							end
						end
					end
				end
			end

			for _, player in pairs(Players:GetPlayers()) do
				if player ~= LocalPlayer then
					checkCharacter(player.Character, player)
				end
			end

			local zombieFolder = Workspace:FindFirstChild("Zombie Tower")
			if zombieFolder and zombieFolder:FindFirstChild("Entities") then
				for _, zombie in pairs(zombieFolder.Entities:GetChildren()) do
					checkCharacter(zombie)
				end
			end

			return closestTarget
		end

		local function flickAimbot()
			local targetHead = getClosestHead()
			if targetHead then
				local oldCFrame = Camera.CFrame
				Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHead.Position)
				task.wait(flickTime)
				Camera.CFrame = oldCFrame
			end
		end

		-- Mobile button
		local function connectShootButton()
			local success, shootButton = pcall(function()
				return LocalPlayer.PlayerGui:WaitForChild("MainGui"):WaitForChild("MobileButtons"):FindFirstChild("mobile_shoot")
					or LocalPlayer.PlayerGui:WaitForChild("MobileControls"):WaitForChild("Frame"):FindFirstChild("FireButton")
			end)
			if success and shootButton then
				shootButton.MouseButton1Down:Connect(function()
					if not flicking then
						flicking = true
						task.spawn(function()
							while holdingMouse do
								flickAimbot()
							end
							flicking = false
						end)
					end
				end)
			end
		end
		connectShootButton()
		LocalPlayer.CharacterAdded:Connect(function()
			task.wait(1)
			connectShootButton()
		end)

		-- PC Mouse
		pcConnectionBegan = UserInputService.InputBegan:Connect(function(input, gp)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and not gp then
				holdingMouse = true
				if not flicking then
					flicking = true
					task.spawn(function()
						while holdingMouse do
							flickAimbot()
						end
						flicking = false
					end)
				end
			end
		end)

		pcConnectionEnded = UserInputService.InputEnded:Connect(function(input, gp)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				holdingMouse = false
			end
		end)

	else
		EffectText_3.Text = "OFF"
		EffectText_3.TextColor3 = Color3.fromRGB(255, 0, 0)
		holdingMouse = false
		if pcConnectionBegan then pcConnectionBegan:Disconnect() end
		if pcConnectionEnded then pcConnectionEnded:Disconnect() end
	end
end)


local Text_3 = Instance.new("TextLabel")
Text_3.Name = "Text"
Text_3.Position = UDim2.new(0, 0, 0, 0)
Text_3.Size = UDim2.new(1, -40, 1, 0)
Text_3.AnchorPoint = Vector2.new(0, 0)
Text_3.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Text_3.BackgroundTransparency = 1
Text_3.BorderSizePixel = 1
Text_3.Text = "Silent Aim"
Text_3.TextColor3 = Color3.fromRGB(255, 255, 255)
Text_3.TextScaled = true
Text_3.TextSize = 8
Text_3.Font = Enum.Font.SourceSansSemibold
Text_3.TextXAlignment = Enum.TextXAlignment.Left
Text_3.ZIndex = 1
Text_3.Parent = Toggle_3


local Toggle_4 = Instance.new("Frame")
Toggle_4.Name = "Toggle"
Toggle_4.Position = UDim2.new(0, 0, 0, 0)
Toggle_4.Size = UDim2.new(1, 0, 0.10000000149011612, 0)
Toggle_4.AnchorPoint = Vector2.new(0, 0)
Toggle_4.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Toggle_4.BackgroundTransparency = 1
Toggle_4.Parent = Container

Toggle_4.LayoutOrder = 2



local effect_4 = Instance.new("Frame")
effect_4.Name = "effect"
effect_4.Position = UDim2.new(0.8500000238418579, 0, 0, 0)
effect_4.Size = UDim2.new(0.12999999523162842, 0, 1, 0)
effect_4.AnchorPoint = Vector2.new(0, 0)
effect_4.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
effect_4.BackgroundTransparency = 1
effect_4.BorderSizePixel = 0
effect_4.Parent = Toggle_4

local EffectText_4 = Instance.new("TextLabel")
EffectText_4.Name = "EffectText"
EffectText_4.Position = UDim2.new(0, 0, 0, 0)
EffectText_4.Size = UDim2.new(1, 0, 1, 0)
EffectText_4.AnchorPoint = Vector2.new(0, 0)
EffectText_4.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
EffectText_4.BackgroundTransparency = 1
EffectText_4.BorderSizePixel = 0
EffectText_4.Text = "OFF"
EffectText_4.TextColor3 = Color3.fromRGB(255,0, 0)
EffectText_4.TextScaled = true
EffectText_4.TextSize = 8
EffectText_4.Font = Enum.Font.SourceSansBold
EffectText_4.TextXAlignment = Enum.TextXAlignment.Center
EffectText_4.TextYAlignment = Enum.TextYAlignment.Center
EffectText_4.ZIndex = 1
EffectText_4.Parent = effect_4

local Text_4 = Instance.new("TextLabel")
Text_4.Name = "Text"
Text_4.Position = UDim2.new(0, 0, 0, 0)
Text_4.Size = UDim2.new(1, -40, 1, 0)
Text_4.AnchorPoint = Vector2.new(0, 0)
Text_4.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Text_4.BackgroundTransparency = 1
Text_4.BorderSizePixel = 1
Text_4.Text = "ESP"
Text_4.TextColor3 = Color3.fromRGB(255, 255, 255)
Text_4.TextScaled = true
Text_4.TextSize = 8
Text_4.Font = Enum.Font.SourceSansSemibold
Text_4.TextXAlignment = Enum.TextXAlignment.Left
Text_4.ZIndex = 1
Text_4.Parent = Toggle_4

local TriggerButton_4 = Instance.new("TextButton")
TriggerButton_4.Name = "Trigger_4"
TriggerButton_4.Parent = Toggle_4
TriggerButton_4.BackgroundTransparency = 1
TriggerButton_4.Size = UDim2.new(1, 0, 1, 0)
TriggerButton_4.Position = UDim2.new(0, 0, 0, 0)
TriggerButton_4.Text = ""
TriggerButton_4.ZIndex = 3


local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "ESP"
ESPFolder.Parent = game.CoreGui

local btoggle = false
local ESPConnections = {}

TriggerButton_4.MouseButton1Click:Connect(function()
    btoggle = not btoggle
    if btoggle then
        EffectText_4.Text = "ON"
        EffectText_4.TextColor3 = Color3.fromRGB(0, 255, 0)

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                ESPConnections[player] = createESP(player)
            end
        end
    else
        EffectText_4.Text = "OFF"
        EffectText_4.TextColor3 = Color3.fromRGB(255, 0, 0)

        ESPFolder:ClearAllChildren()
        for _, conn in pairs(ESPConnections) do
            if conn then conn:Disconnect() end
        end
        ESPConnections = {}
    end
end)

function createESP(player)
    if player.Character == nil then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = player.Name .. "_ESP"
    billboard.Size = UDim2.new(0, 20, 0, 60) -- width small for thin bar
    billboard.Adornee = player.Character:FindFirstChild("HumanoidRootPart")
    billboard.AlwaysOnTop = true
    billboard.StudsOffset = Vector3.new(-2, 3, 0) -- left side
    billboard.Parent = ESPFolder

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0, 20)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.SourceSansBold
    nameLabel.TextSize = 14
    nameLabel.Text = player.Name
    nameLabel.Parent = billboard

    local healthBarBG = Instance.new("Frame")
    healthBarBG.Size = UDim2.new(0, 4, 0, 40) -- thin width
    healthBarBG.Position = UDim2.new(0, 0, 0, 20)
    healthBarBG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    healthBarBG.BorderSizePixel = 0
    healthBarBG.Parent = billboard

    local healthBar = Instance.new("Frame")
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.Position = UDim2.new(0, 0, 0, 0)
    healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
    healthBar.BorderSizePixel = 0
    healthBar.Parent = healthBarBG

    local uiGradient = Instance.new("UIGradient")
    uiGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0,255,0)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255,0,0))
    }
    uiGradient.Rotation = 90 -- vertical gradient
    uiGradient.Parent = healthBar

    local conn = RunService.RenderStepped:Connect(function()
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            local healthPercent = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
            healthBar.Size = UDim2.new(1, 0, healthPercent, 0) -- scale height with health
            billboard.Adornee = character:FindFirstChild("HumanoidRootPart")
        end
    end)

    return conn
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        if btoggle and player ~= LocalPlayer then
            ESPConnections[player] = createESP(player)
        end
    end)
end)

local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Position = UDim2.new(0, 0, 0, 0)
Title.Size = UDim2.new(1, 0, 0.10000000149011612, 0)
Title.AnchorPoint = Vector2.new(0, 0)
Title.BackgroundColor3 = Color3.fromRGB(162, 162, 162)
Title.BackgroundTransparency = 1
Title.BorderSizePixel = 1
Title.Text = "CludeHub"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextScaled = true
Title.TextSize = 8
Title.Font = Enum.Font.SourceSansBold
Title.TextYAlignment = Enum.TextYAlignment.Center
Title.ZIndex = 1
Title.Parent = Window

local Line = Instance.new("Frame")
Line.Name = "Line"
Line.Position = UDim2.new(0, 0, 1, 0)
Line.Size = UDim2.new(1, 0, 0, 1)
Line.AnchorPoint = Vector2.new(0, 0)
Line.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Line.BorderSizePixel = 0
Line.Parent = Title

local UIGradient_2 = Instance.new("UIGradient")
UIGradient_2.Name = "UIGradient"
UIGradient_2.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))})
UIGradient_2.Rotation = 0
UIGradient_2.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0, 0), NumberSequenceKeypoint.new(1, 0, 0)})
UIGradient_2.Offset = Vector2.new(0, 0)
UIGradient_2.Parent = Line


local bloom = Instance.new("BloomEffect")
    bloom.Name = "bloom"
    bloom.Size = 24
    bloom.Intensity = 1
    bloom.Threshold = 0.9
    bloom.Parent = game.Lighting

game:GetService("CoreGui").e1f0bc5c8c2deebbf6feaaeb750d44dadc3d8e39339a0ce400c5f6c05b67cf6c:Destroy()
end
