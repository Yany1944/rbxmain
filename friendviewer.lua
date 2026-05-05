print("loaded friendviewer.lua")

local players = game:GetService("Players")
local cam = workspace.CurrentCamera
local drawing = Drawing.new
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")

-- Тогл (вкл/выкл)
local enabled = true 

-- === КНОПКА ON/OFF ===
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local Button = Instance.new("TextButton", ScreenGui)

Button.Size = UDim2.new(0, 120, 0, 40)
Button.Position = UDim2.new(0.05, 0, 0.2, 0)
Button.Text = "FriendViewer: ON"
Button.TextColor3 = Color3.new(1,1,1)
Button.Font = Enum.Font.SourceSansBold
Button.TextSize = 18
Button.BackgroundColor3 = Color3.new(1,0,0)
Button.AutoButtonColor = false
Button.Active = true
Button.Draggable = true -- сенсорне перетягування

-- Плавное изменение цвета кнопки
task.spawn(function()
    local t = 0
    while task.wait(0.05) do
        t += 0.01
        local r = 0.5 + 0.5 * math.sin(t*2)
        local g = 0.5 + 0.5 * math.sin(t*2 + 2)
        local b = 0.5 + 0.5 * math.sin(t*2 + 4)
        Button.BackgroundColor3 = Color3.new(r,g,b)
    end
end)

-- Клик по кнопке
Button.MouseButton1Click:Connect(function()
    enabled = not enabled
    if enabled then
        Button.Text = "FriendViewer: ON"
    else
        Button.Text = "FriendViewer: OFF"
    end
end)

-- === СТАРЫЙ КОД ДЛЯ ВИЗУАЛИЗАЦИИ  ===
local threshold = 25
local friendships = {}

function trackplayers(p1, p2)
    while true do
        task.wait(0)
        if not enabled then continue end -- ✨ toggle
        if not p1 or not p2 then continue end

        local p1Char = p1.Character or p1.CharacterAdded:Wait()
        local p2Char = p2.Character or p2.CharacterAdded:Wait()
        local p1Piv, p2Piv = p1Char:GetPivot(), p2Char:GetPivot()
        local dist = (p1Piv.Position - p2Piv.Position).Magnitude
        local color = Color3.fromRGB(255,0,0):Lerp(Color3.fromRGB(0,255,0), math.clamp(1 / (dist / threshold), 0, 1))

        local p1Pos, vis1 = cam:WorldToViewportPoint(p1Piv.Position)
        local p2Pos, vis2 = cam:WorldToViewportPoint(p2Piv.Position)
        if vis1 == false and vis2 == false then continue end

        if p1Pos.Z < 0 then p1Pos = Vector3.new(-p1Pos.X, math.sign(p1Pos.Y), -p1Pos.Z) end
        if p2Pos.Z < 0 then p2Pos = Vector3.new(-p2Pos.X, math.sign(p2Pos.Y), -p2Pos.Z) end

        p1Pos = Vector2.new(p1Pos.X, p1Pos.Y)
        p2Pos = Vector2.new(p2Pos.X, p2Pos.Y)

        local line = drawing("Line")
        local dot1 = drawing("Circle")
        local dot2 = drawing("Circle")

        -- линия
        line.Visible = true
        line.From = p1Pos
        line.To = p2Pos
        line.Color = color
        line.Thickness = 2
        line.Transparency = 0.5

        -- точки
        dot1.Visible = vis1
        dot1.Position = p1Pos
        dot1.Color = color
        dot1.Thickness = 2
        dot1.Radius = 6
        dot1.Filled = true
        dot1.NumSides = 25
        dot1.Transparency = 0.5

        dot2.Visible = vis2
        dot2.Position = p2Pos
        dot2.Color = color
        dot2.Thickness = 2
        dot2.Radius = 6
        dot2.Filled = true
        dot2.NumSides = 25
        dot2.Transparency = 0.5

        task.delay(0, function()
            line:Remove()
            dot1:Remove()
            dot2:Remove()
        end)
    end
end

function getfriends()
    for _,p1:Player in players:GetPlayers() do
        task.spawn(function()
            for _,p2:Player in players:GetPlayers() do
                if not p1 then break end
                if not p2 then continue end
                if p2.Name == p1.Name then continue end
                if p2:IsFriendsWith(p1.UserId) then
                    for _,v in friendships do
                        if table.find(v, p1.Name) and table.find(v, p2.Name) then
                            return
                        end
                    end
                    table.insert(friendships, {p1.Name, p2.Name})
                    task.spawn(function()
                        trackplayers(p1, p2)
                    end)
                end
            end
        end)
    end
end

getfriends()
players.PlayerAdded:Connect(getfriends)