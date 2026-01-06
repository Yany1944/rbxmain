-- ESPIndicator.lua
-- Robust ESP module with arrows and grouping
-- Designed by YARHM

local ESPIndicator = {}
ESPIndicator.__index = ESPIndicator

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")

ESPIndicator.Groups = {}
ESPIndicator.TargetIndex = {}
ESPIndicator.Defaults = {
    AccentColor = Color3.new(1, 1, 0),
    HighlightFillTransparency = 0.7,
    HighlightOutlineTransparency = 0,
    HighlightDepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    ArrowShow = false,
    ArrowEdgePadding = 50,
    ArrowMinDistance = 0,
    ArrowSize = UDim2.new(0, 30, 0, 30),
    ArrowImage = "rbxassetid://97136202386756",
    ArrowShowDistanceText = true,
    ArrowDistanceFont = Enum.Font.Montserrat,
    ArrowDistanceTextSize = 18,
    ShowLabel = false,
    LabelText = "Target",
    LabelMaxDistance = 99999,
    LabelOffset = Vector3.new(0, 2, 0),
    Parent = game:GetService("CoreGui")
}

function ESPIndicator.new(settings)
    local self = setmetatable({}, ESPIndicator)
    
    self.Settings = {}
    for key, value in pairs(ESPIndicator.Defaults) do
        self.Settings[key] = (settings and settings[key] ~= nil and settings[key]) or value
    end
    
    local parent = self.Settings.Parent or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
    
    self.ScreenGui = Instance.new("ScreenGui")
    self.ScreenGui.Name = "ESPIndicators"
    self.ScreenGui.IgnoreGuiInset = true
    self.ScreenGui.ResetOnSpawn = false
    self.ScreenGui.Parent = parent
    
    self.ArrowTemplate = Instance.new("ImageLabel")
    self.ArrowTemplate.Name = "ArrowTemplate"
    self.ArrowTemplate.Size = self.Settings.ArrowSize
    self.ArrowTemplate.AnchorPoint = Vector2.new(0.5, 0.5)
    self.ArrowTemplate.BackgroundTransparency = 1
    self.ArrowTemplate.Image = self.Settings.ArrowImage
    self.ArrowTemplate.ImageColor3 = self.Settings.AccentColor
    self.ArrowTemplate.Visible = false
    self.ArrowTemplate.Parent = self.ScreenGui
    
    self.Scaler = Instance.new("UIScale")
    self.Scaler.Name = "Scaler"
    self.Scaler.Scale = 0
    self.Scaler.Parent = self.ArrowTemplate
    
    self.Indicators = {}
    
    self.updateConn = RunService.RenderStepped:Connect(function() self:update() end)
    self.cleanupConn = RunService.Heartbeat:Connect(function()
        self:cleanupOrphanedArrows()
        self:cleanupOrphanedHighlights()
        self:cleanupOrphanedLabels()
    end)
    
    return self
end

function ESPIndicator:AddGroup(groupName)
    local group = ESPIndicator.Groups[groupName]
    if not group then
        group = {enabled = true, properties = {}, targets = {}}
        ESPIndicator.Groups[groupName] = group
    end
    return group
end

function ESPIndicator:GetGroup(groupName)
    return ESPIndicator.Groups[groupName]
end

function ESPIndicator:RemoveGroup(groupName)
    local group = ESPIndicator.Groups[groupName]
    if not group then return false end
    
    for _, target in ipairs(group.targets) do
        local targetGroups = ESPIndicator.TargetIndex[target]
        if targetGroups then
            for i, name in ipairs(targetGroups) do
                if name == groupName then
                    table.remove(targetGroups, i)
                    break
                end
            end
            if #targetGroups == 0 then
                ESPIndicator.TargetIndex[target] = nil
            end
        end
        if not ESPIndicator.TargetIndex[target] then
            self:Remove(target)
        end
    end
    
    ESPIndicator.Groups[groupName] = nil
    return true
end

function ESPIndicator:ClearAllGroups()
    for groupName, _ in pairs(ESPIndicator.Groups) do
        self:RemoveGroup(groupName)
    end
end

function ESPIndicator:ToggleGroup(groupName, enabled)
    local group = ESPIndicator.Groups[groupName]
    if not group then return end
    
    group.enabled = (enabled ~= nil and enabled) or not group.enabled
    
    for _, target in ipairs(group.targets) do
        local indicator = self.Indicators[target]
        if indicator then
            if indicator.Highlight then
                indicator.Highlight.Enabled = group.enabled
            end
            if indicator.Arrow then
                indicator.Arrow.Visible = group.enabled and self.Settings.ArrowShow
            end
            if indicator.Label then
                indicator.Label.Enabled = group.enabled
            end
        end
    end
    
    return group.enabled
end

function ESPIndicator:SetGroupProperty(groupName, property, value)
    self:AddGroup(groupName)
    ESPIndicator.Groups[groupName].properties[property] = value
    
    for _, target in ipairs(ESPIndicator.Groups[groupName].targets) do
        local indicator = self.Indicators[target]
        if indicator then
            if property == "AccentColor" then
                if indicator.Highlight then
                    indicator.Highlight.FillColor = value
                    indicator.Highlight.OutlineColor = value
                end
                if indicator.Arrow then
                    indicator.Arrow.ImageColor3 = value
                end
                if indicator.DistanceLabel then
                    indicator.DistanceLabel.TextColor3 = value
                end
                if indicator.Label and indicator.Label:FindFirstChild("TextLabel") then
                    indicator.Label.TextLabel.TextColor3 = value
                end
            end
        end
    end
end

function ESPIndicator:Add(target, options)
    assert(target, "ESPIndicator:Add requires a non-nil target")
    options = options or {}
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "Highlight" .. HttpService:GenerateGUID(false)
    highlight.Adornee = target
    highlight.FillTransparency = options.HighlightFillTransparency or self.Settings.HighlightFillTransparency
    highlight.FillColor = options.AccentColor or self.Settings.AccentColor
    highlight.OutlineColor = options.AccentColor or self.Settings.AccentColor
    highlight.OutlineTransparency = options.HighlightOutlineTransparency or self.Settings.HighlightOutlineTransparency
    highlight.DepthMode = options.HighlightDepthMode or self.Settings.HighlightDepthMode
    highlight.Parent = self.ScreenGui
    
    local arrow, scaler, distanceLabel = nil, nil, nil
    
    if options.ArrowShow or self.Settings.ArrowShow then
        arrow = self.ArrowTemplate:Clone()
        arrow.Name = "Arrow" .. HttpService:GenerateGUID(false)
        arrow.ImageColor3 = options.AccentColor or self.Settings.AccentColor
        arrow.Visible = true
        arrow.Parent = self.ScreenGui
        
        scaler = arrow:FindFirstChild("Scaler")
        
        if options.ArrowShowDistanceText or self.Settings.ArrowShowDistanceText then
            distanceLabel = Instance.new("TextLabel")
            distanceLabel.Name = "DistanceLabel"
            distanceLabel.AnchorPoint = Vector2.new(0.5, 0)
            distanceLabel.BackgroundTransparency = 1
            distanceLabel.Font = options.ArrowDistanceFont or self.Settings.ArrowDistanceFont
            distanceLabel.TextSize = options.ArrowDistanceTextSize or self.Settings.ArrowDistanceTextSize
            distanceLabel.TextColor3 = options.AccentColor or self.Settings.AccentColor
            distanceLabel.Parent = arrow
        end
    end
    
    local label = nil
    if options.ShowLabel or self.Settings.ShowLabel then
        label = Instance.new("BillboardGui")
        label.Name = "Label" .. HttpService:GenerateGUID(false)
        label.AlwaysOnTop = true
        label.MaxDistance = self.Settings.LabelMaxDistance
        label.Size = UDim2.new(0, 70, 0, 70)
        label.StudsOffset = self.Settings.LabelOffset
        label.Adornee = target
        label.Parent = self.ScreenGui
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "TextLabel"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        textLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextScaled = true
        textLabel.TextWrapped = true
        textLabel.TextSize = 14
        textLabel.TextColor3 = options.AccentColor or self.Settings.AccentColor
        textLabel.Text = options.LabelText or self.Settings.LabelText
        textLabel.Parent = label
        
        Instance.new("UIStroke", textLabel)
    end
    
    self.Indicators[target] = {Highlight = highlight, Arrow = arrow, Scaler = scaler, DistanceLabel = distanceLabel, Label = label, Options = options}
    
    local groupName = options.GroupName or self.Settings.GroupName
    if groupName then
        self:AddToGroup(target, groupName)
    end
end

function ESPIndicator:Remove(target)
    local indicator = self.Indicators[target]
    if not indicator then return end
    
    if indicator.Highlight then
        indicator.Highlight.Adornee = nil
        indicator.Highlight:Destroy()
    end
    if indicator.Arrow then
        indicator.Arrow:Destroy()
    end
    if indicator.Label then
        indicator.Label:Destroy()
    end
    
    local targetGroups = ESPIndicator.TargetIndex[target]
    if targetGroups then
        for _, groupName in ipairs(targetGroups) do
            local group = ESPIndicator.Groups[groupName]
            if group then
                for i, t in ipairs(group.targets) do
                    if t == target then
                        table.remove(group.targets, i)
                        break
                    end
                end
            end
        end
        ESPIndicator.TargetIndex[target] = nil
    end
    
    self.Indicators[target] = nil
end

function ESPIndicator:AddToGroup(target, groupName)
    self:AddGroup(groupName)
    
    if not table.find(ESPIndicator.Groups[groupName].targets, target) then
        table.insert(ESPIndicator.Groups[groupName].targets, target)
    end
    
    local targetGroups = ESPIndicator.TargetIndex[target]
    if not targetGroups then
        targetGroups = {}
        ESPIndicator.TargetIndex[target] = targetGroups
    end
    
    if not table.find(targetGroups, groupName) then
        table.insert(targetGroups, groupName)
    end
    
    for property, value in pairs(ESPIndicator.Groups[groupName].properties) do
        self:SetGroupProperty(groupName, property, value)
    end
    
    if not ESPIndicator.Groups[groupName].enabled then
        local indicator = self.Indicators[target]
        if indicator and indicator.Highlight then
            indicator.Highlight.Enabled = false
        end
    end
    
    return true
end

function ESPIndicator:RemoveFromGroup(target, groupName)
    local group = ESPIndicator.Groups[groupName]
    if not group then return false end
    
    if table.find(group.targets, target) then
        for i, t in ipairs(group.targets) do
            if t == target then
                table.remove(group.targets, i)
                break
            end
        end
    else
        return false
    end
    
    local targetGroups = ESPIndicator.TargetIndex[target]
    if targetGroups then
        for i, name in ipairs(targetGroups) do
            if name == groupName then
                table.remove(targetGroups, i)
                break
            end
        end
        if #targetGroups == 0 then
            ESPIndicator.TargetIndex[target] = nil
        end
    end
    
    return true
end

function ESPIndicator:GetGroupTargets(groupName)
    local group = ESPIndicator.Groups[groupName]
    return (group and group.targets) or {}
end

function ESPIndicator:GetTargetGroups(target)
    return ESPIndicator.TargetIndex[target] or {}
end

function ESPIndicator:cleanupOrphanedHighlights()
    for _, child in ipairs(self.ScreenGui:GetChildren()) do
        if child:IsA("Highlight") and not table.find(self:allHighlights(), child) then
            child.Adornee = nil
            child:Destroy()
        end
    end
end

function ESPIndicator:allHighlights()
    local highlights = {}
    for _, indicator in pairs(self.Indicators) do
        if indicator.Highlight then
            table.insert(highlights, indicator.Highlight)
        end
    end
    return highlights
end

function ESPIndicator:cleanupOrphanedArrows()
    for _, child in ipairs(self.ScreenGui:GetChildren()) do
        if child:IsA("ImageLabel") and child.Name:match("Arrow") then
            if not table.find(self:allArrows(), child) then
                child:Destroy()
            end
        end
    end
end

function ESPIndicator:allArrows()
    local arrows = {}
    for _, indicator in pairs(self.Indicators) do
        if indicator.Arrow then
            table.insert(arrows, indicator.Arrow)
        end
    end
    return arrows
end

function ESPIndicator:cleanupOrphanedLabels()
    for _, child in ipairs(self.ScreenGui:GetChildren()) do
        if child:IsA("BillboardGui") and child.Name:match("Label") then
            if not table.find(self:allLabels(), child) then
                child.Adornee = nil
                child:Destroy()
            end
        end
    end
end

function ESPIndicator:allLabels()
    local labels = {}
    for _, indicator in pairs(self.Indicators) do
        if indicator.Label then
            table.insert(labels, indicator.Label)
        end
    end
    return labels
end

-- ⚠️ ИСПРАВЛЕННАЯ ФУНКЦИЯ UPDATE - ПРАВИЛЬНАЯ РАБОТА С 3D
function ESPIndicator:update()
    local camera = workspace.CurrentCamera
    local viewportSize = camera.ViewportSize
    local centerX, centerY = viewportSize.X / 2, viewportSize.Y / 2

    for target, indicator in pairs(self.Indicators) do
        local options = indicator.Options
        local arrow = indicator.Arrow
        local scaler = indicator.Scaler

        if (not arrow or not scaler) and self.Settings.ArrowShow then
            self:Remove(target)
            continue
        end

        if not arrow then continue end

        local worldPosition
        if target:IsA("Model") then
            worldPosition = (target.PrimaryPart and target.PrimaryPart.Position) or target:GetModelCFrame().p
        elseif target:IsA("BasePart") then
            worldPosition = target.Position
        else
            continue
        end

        local viewportPoint, onScreen = camera:WorldToViewportPoint(worldPosition)
        local distance = (camera.CFrame.p - worldPosition).Magnitude

        local minDistance = options.ArrowMinDistance or self.Settings.ArrowMinDistance
        local edgePadding = options.ArrowEdgePadding or self.Settings.ArrowEdgePadding

        -- Скрываем стрелку если объект НА ЭКРАНЕ и БЛИЗКО
        if onScreen and viewportPoint.Z > 0 and distance > minDistance then
            TweenService:Create(scaler, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0}):Play()
            continue
        end

        -- Проверяем, видим ли объект полностью на экране
        local isFullyOnScreen = onScreen and 
                                viewportPoint.Z > 0 and
                                viewportPoint.X >= edgePadding and 
                                viewportPoint.X <= viewportSize.X - edgePadding and
                                viewportPoint.Y >= edgePadding and 
                                viewportPoint.Y <= viewportSize.Y - edgePadding

        if isFullyOnScreen then
            TweenService:Create(scaler, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 0}):Play()
        else
            TweenService:Create(scaler, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1}):Play()

            -- Вектор от камеры к цели
            local vectorToTarget = (worldPosition - camera.CFrame.Position).Unit
            
            -- Конвертируем в локальное пространство камеры
            local localVector = camera.CFrame:VectorToObjectSpace(vectorToTarget)
            
            -- Проецируем на 2D (X, Y), игнорируя Z (глубину)
            local direction2D = Vector2.new(localVector.X, -localVector.Y).Unit
            
            -- Рассчитываем позицию на краю экрана
            local maxX = (viewportSize.X - edgePadding) / 2
            local maxY = (viewportSize.Y - edgePadding) / 2
            
            local finalPos
            if math.abs(direction2D.X / maxX) > math.abs(direction2D.Y / maxY) then
                -- Ограничено по X
                local scale = maxX / math.abs(direction2D.X)
                finalPos = direction2D * scale
            else
                -- Ограничено по Y
                local scale = maxY / math.abs(direction2D.Y)
                finalPos = direction2D * scale
            end
            
            local finalX = centerX + finalPos.X
            local finalY = centerY + finalPos.Y
            
            -- Угол поворота стрелки
            local angle = math.atan2(direction2D.X, direction2D.Y)

            TweenService:Create(arrow, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Position = UDim2.fromOffset(finalX, finalY),
                Rotation = math.deg(angle)
            }):Play()
        end

        -- Обновление текста расстояния
        if indicator.DistanceLabel then
            indicator.DistanceLabel.Text = string.format("%dm", math.round(distance))
            local arrowHeight = (options.ArrowSize and options.ArrowSize.Y.Offset or self.Settings.ArrowSize.Y.Offset) + 16
            indicator.DistanceLabel.Position = UDim2.new(0.5, 0, 0, arrowHeight)
        end
    end
end

function ESPIndicator:Destroy()
    if self.updateConn then
        self.updateConn:Disconnect()
    end
    if self.cleanupConn then
        self.cleanupConn:Disconnect()
    end
    
    self:ClearAllGroups()
    
    for _, indicator in pairs(self.Indicators) do
        if indicator.Highlight then
            indicator.Highlight:Destroy()
        end
        if indicator.Arrow then
            indicator.Arrow:Destroy()
        end
        if indicator.Label then
            indicator.Label:Destroy()
        end
    end
    
    self.ScreenGui:Destroy()
    self.Indicators = {}
    ESPIndicator.Groups = {}
    ESPIndicator.TargetIndex = {}
end

return ESPIndicator
