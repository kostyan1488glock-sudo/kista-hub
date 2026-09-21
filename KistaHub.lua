--[[
    Kista Hub — минималистичный UI + ESP + предупреждение о монстре
    Для DOORS / Mines. Работает только через инжектор (Synapse/Delta и т.п.).
    Использование нарушает правила игры (ToS), риск бана — на твоей ответственности.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

----------------------------------------------------------------
-- НАСТРОЙКИ
----------------------------------------------------------------
local Settings = {
    ESP_Items = true,
    ESP_Doors = true,
    ESP_Carts = true,
    MonsterWarning = true,
    InfiniteJump = false,
    HighJump = false,
    JumpButton = true,
}

local JUMP_POWER = 90 -- сила прыжка при включённом HighJump (обычная ~50)

local ITEM_COLOR = Color3.fromRGB(255, 215, 0)
local DOOR_COLOR = Color3.fromRGB(0, 170, 255)
local CART_COLOR = Color3.fromRGB(255, 120, 0)

local MONSTER_TAGS = {"Giggles", "GrumbleBot", "Void", "Eyes", "Timothy", "Rush", "Ambush", "Screech", "Seek", "Halt", "Figure"}

----------------------------------------------------------------
-- ESP ЛОГИКА
----------------------------------------------------------------
local highlighted = {}

local function addHighlight(obj, color)
    if highlighted[obj] then return end
    local h = Instance.new("Highlight")
    h.FillColor = color
    h.FillTransparency = 0.5
    h.OutlineColor = color
    h.Parent = obj
    highlighted[obj] = h
end

local function clearHighlights()
    for obj, h in pairs(highlighted) do
        h:Destroy()
    end
    highlighted = {}
end

local function scan()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if highlighted[obj] then continue end
        local name = obj.Name:lower()

        if Settings.ESP_Items and (obj:IsA("Tool") or name:find("item") or name:find("pickaxe") or name:find("ore") or name:find("key")) then
            addHighlight(obj, ITEM_COLOR)
        elseif Settings.ESP_Doors and obj:IsA("Model") and (name:find("door") or name:find("exit") or name:find("gate")) then
            addHighlight(obj, DOOR_COLOR)
        elseif Settings.ESP_Carts and (name:find("cart") or name:find("rail")) then
            addHighlight(obj, CART_COLOR)
        end
    end
end

----------------------------------------------------------------
-- ПРЫЖКИ (Infinite Jump / High Jump)
----------------------------------------------------------------
local UIS = UserInputService

UIS.JumpRequest:Connect(function() end) -- заглушка, оставлено для совместимости

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Бесконечный прыжок: ловим нажатие пробела/кнопки прыжка на мобиле
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if Settings.InfiniteJump and (input.KeyCode == Enum.KeyCode.Space) then
        local hum = getHumanoid()
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Дублируем через Heartbeat, чтобы ловить зажатый пробел и прыжок на мобильных устройствах
RunService.Heartbeat:Connect(function()
    if Settings.InfiniteJump then
        local hum = getHumanoid()
        if hum and (UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Высота прыжка + автоприменение при респауне
local function applyJumpPower(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Settings.HighJump then
        hum.UseJumpPower = true
        hum.JumpPower = JUMP_POWER
    else
        hum.JumpPower = 50 -- значение по умолчанию в Roblox
    end
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    applyJumpPower(char)
end)

if player.Character then
    applyJumpPower(player.Character)
end

----------------------------------------------------------------
-- ИНТЕРФЕЙС "Kista Hub"
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "KistaHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Главное окно
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 260, 0, 460)
main.Position = UDim2.new(0.5, -130, 0.5, -230)
main.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
main.BorderSizePixel = 0
main.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = main

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 70, 80)
stroke.Thickness = 1
stroke.Parent = main

-- Шапка
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 10)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 10)
headerFix.Position = UDim2.new(0, 0, 1, -10)
headerFix.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Text = "KISTA HUB"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -40, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -36, 0, 4)
closeBtn.Parent = header

-- Контейнер тумблеров
local list = Instance.new("UIListLayout")
list.Padding = UDim.new(0, 10)
list.SortOrder = Enum.SortOrder.LayoutOrder

local body = Instance.new("Frame")
body.Size = UDim2.new(1, -28, 1, -60)
body.Position = UDim2.new(0, 14, 0, 50)
body.BackgroundTransparency = 1
body.Parent = main
list.Parent = body

-- Функция создания тумблера
local function createToggle(labelText, key, order)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    row.LayoutOrder = order
    row.Parent = body

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent = row

    local label = Instance.new("TextLabel")
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 36, 0, 20)
    switch.Position = UDim2.new(1, -46, 0.5, -10)
    switch.BackgroundColor3 = Settings[key] and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(70, 70, 78)
    switch.Parent = row

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = Settings[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local btn = Instance.new("TextButton")
    btn.Text = ""
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.Parent = switch

    btn.MouseButton1Click:Connect(function()
        Settings[key] = not Settings[key]
        local targetColor = Settings[key] and Color3.fromRGB(80, 180, 100) or Color3.fromRGB(70, 70, 78)
        local targetPos = Settings[key] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(switch, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = targetPos}):Play()

        if not Settings[key] and (key == "ESP_Items" or key == "ESP_Doors" or key == "ESP_Carts") then
            clearHighlights()
        end

        if key == "HighJump" and player.Character then
            applyJumpPower(player.Character)
        end
    end)
end

createToggle("ESP: Предметы", "ESP_Items", 1)
createToggle("ESP: Двери", "ESP_Doors", 2)
createToggle("ESP: Тележки", "ESP_Carts", 3)
createToggle("Предупреждение о монстре", "MonsterWarning", 4)
createToggle("Бесконечный прыжок", "InfiniteJump", 5)
createToggle("Высокий прыжок", "HighJump", 6)
createToggle("Кнопка прыжка (как у Seek)", "JumpButton", 7)

-- Перетаскивание окна
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- Сворачивание по кнопке "×"
local minimized = false
local openBtn

local function createOpenButton()
    openBtn = Instance.new("TextButton")
    openBtn.Text = "K"
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 18
    openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    openBtn.Size = UDim2.new(0, 40, 0, 40)
    openBtn.Position = UDim2.new(0, 20, 0, 20)
    openBtn.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
    openBtn.Visible = false
    openBtn.Parent = gui

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = openBtn

    openBtn.MouseButton1Click:Connect(function()
        main.Visible = true
        openBtn.Visible = false
    end)
end
createOpenButton()

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    openBtn.Visible = true
end)

----------------------------------------------------------------
-- Кнопка прыжка (как в погоне от Seek в шахтах)
----------------------------------------------------------------
local jumpBtnHolder = Instance.new("Frame")
jumpBtnHolder.Size = UDim2.new(0, 90, 0, 90)
jumpBtnHolder.Position = UDim2.new(1, -120, 1, -140)
jumpBtnHolder.BackgroundTransparency = 1
jumpBtnHolder.Parent = gui

local jumpBtn = Instance.new("ImageButton")
jumpBtn.Size = UDim2.new(1, 0, 1, 0)
jumpBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
jumpBtn.BackgroundTransparency = 0.15
jumpBtn.Image = "rbxassetid://0" -- ⬅ сюда вставь свой Asset ID после загрузки картинки
jumpBtn.ScaleType = Enum.ScaleType.Fit
jumpBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
jumpBtn.AutoButtonColor = false
jumpBtn.Parent = jumpBtnHolder

local jumpBtnCorner = Instance.new("UICorner")
jumpBtnCorner.CornerRadius = UDim.new(1, 0)
jumpBtnCorner.Parent = jumpBtn

local jumpBtnStroke = Instance.new("UIStroke")
jumpBtnStroke.Color = Color3.fromRGB(255, 255, 255)
jumpBtnStroke.Thickness = 2
jumpBtnStroke.Transparency = 0.5
jumpBtnStroke.Parent = jumpBtn

local function doJump()
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

jumpBtn.MouseButton1Down:Connect(function()
    TweenService:Create(jumpBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    doJump()
end)

jumpBtn.MouseButton1Up:Connect(function()
    TweenService:Create(jumpBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
end)

RunService.RenderStepped:Connect(function()
    jumpBtnHolder.Visible = Settings.JumpButton
end)

----------------------------------------------------------------
-- Предупреждение о монстре (плавное)
----------------------------------------------------------------
local warnLabel = Instance.new("TextLabel")
warnLabel.Size = UDim2.new(0, 420, 0, 50)
warnLabel.Position = UDim2.new(0.5, -210, 0.05, 0)
warnLabel.BackgroundTransparency = 1
warnLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
warnLabel.TextStrokeTransparency = 0
warnLabel.Font = Enum.Font.GothamBold
warnLabel.TextSize = 26
warnLabel.TextTransparency = 1
warnLabel.TextStrokeTransparency = 1
warnLabel.Text = ""
warnLabel.Parent = gui

local warningShown = false
local function checkMonster()
    if not Settings.MonsterWarning then
        if warningShown then
            warningShown = false
            TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
        return
    end

    local foundName = nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        for _, tag in ipairs(MONSTER_TAGS) do
            if obj.Name == tag then
                foundName = tag
                break
            end
        end
        if foundName then break end
    end

    if foundName and not warningShown then
        warningShown = true
        warnLabel.Text = "⚠ ОПАСНОСТЬ: " .. foundName .. " РЯДОМ!"
        TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
    elseif not foundName and warningShown then
        warningShown = false
        TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end
end

----------------------------------------------------------------
-- ОСНОВНОЙ ЦИКЛ
----------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    scan()
    checkMonster()
end)
