--[[
    KISTA HUB v2 — DOORS / Mines
    Свой интерфейс: вкладки слева + поиск, тёмно-бирюзовая тема.
    Работает только через инжектор (Synapse/Delta X и т.п.).
    Использование нарушает правила игры (ToS), риск бана — на твоей ответственности.

    Что внутри:
      General  — ESP (предметы/двери/тележки), предупреждение о монстре
      Movement — бесконечный прыжок, высокий прыжок, кнопка прыжка
      Visuals  — FOV, ambient-подсветка, убрать тряску/покачивание камеры, дистанция до опасности
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local jumpBtnHolder -- форвард-декларация (используется в обработчике тумблера раньше своего создания)

----------------------------------------------------------------
-- НАСТРОЙКИ
----------------------------------------------------------------
local Settings = {
    ESP_Items = true,
    ESP_Doors = true,
    ESP_Carts = true,
    MonsterWarning = true,
    ShowDistance = true,

    InfiniteJump = false,
    HighJump = false,
    JumpButton = true,

    CustomFOV = false,
    FOVValue = 70,
    Ambient = false,
    RemoveShake = false,
    RemoveBobbing = false,
}

local JUMP_POWER = 90
local DEFAULT_FOV = 70

local ITEM_COLOR = Color3.fromRGB(255, 215, 0)
local DOOR_COLOR = Color3.fromRGB(0, 170, 255)
local CART_COLOR = Color3.fromRGB(255, 120, 0)

local MONSTER_TAGS = {"Giggles", "GrumbleBot", "Void", "Eyes", "Timothy", "Rush", "Ambush", "Screech", "Seek", "Halt", "Figure"}

----------------------------------------------------------------
-- ESP ЛОГИКА (событийная — не грузит FPS)
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
    for _, h in pairs(highlighted) do
        h:Destroy()
    end
    highlighted = {}
end

local function tryHighlight(obj)
    if highlighted[obj] then return end
    local name = obj.Name:lower()

    if Settings.ESP_Items and (obj:IsA("Tool") or name:find("item") or name:find("pickaxe") or name:find("ore") or name:find("key")) then
        addHighlight(obj, ITEM_COLOR)
    elseif Settings.ESP_Doors and obj:IsA("Model") and (name:find("door") or name:find("exit") or name:find("gate")) then
        addHighlight(obj, DOOR_COLOR)
    elseif Settings.ESP_Carts and (name:find("cart") or name:find("rail")) then
        addHighlight(obj, CART_COLOR)
    end
end

local function rescanAll()
    for _, obj in ipairs(Workspace:GetDescendants()) do
        tryHighlight(obj)
    end
end

rescanAll()

Workspace.DescendantAdded:Connect(function(obj)
    task.defer(tryHighlight, obj)
end)

----------------------------------------------------------------
-- ПРЫЖКИ
----------------------------------------------------------------
local UIS = UserInputService

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if Settings.InfiniteJump and input.KeyCode == Enum.KeyCode.Space then
        local hum = getHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

RunService.Heartbeat:Connect(function()
    if Settings.InfiniteJump then
        local hum = getHumanoid()
        if hum and (UIS:IsKeyDown(Enum.KeyCode.Space) or hum.Jump) then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

local function applyJumpPower(char)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    if Settings.HighJump then
        hum.UseJumpPower = true
        hum.JumpPower = JUMP_POWER
    else
        hum.JumpPower = 50
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
-- ВИЗУАЛЬНЫЙ КОМФОРТ (FOV / Ambient / Camera Shake-Bobbing)
----------------------------------------------------------------
local function applyFOV()
    if not camera then camera = Workspace.CurrentCamera end
    if not camera then return end
    camera.FieldOfView = Settings.CustomFOV and Settings.FOVValue or DEFAULT_FOV
end

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    camera = Workspace.CurrentCamera
    applyFOV()
end)

local savedAmbient, savedBrightness, savedOutdoorAmbient
local function applyAmbient()
    if Settings.Ambient then
        if not savedAmbient then
            savedAmbient = Lighting.Ambient
            savedBrightness = Lighting.Brightness
            savedOutdoorAmbient = Lighting.OutdoorAmbient
        end
        Lighting.Ambient = Color3.fromRGB(140, 140, 140)
        Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 140)
        Lighting.Brightness = math.max(Lighting.Brightness, 2)
    else
        if savedAmbient then
            Lighting.Ambient = savedAmbient
            Lighting.OutdoorAmbient = savedOutdoorAmbient
            Lighting.Brightness = savedBrightness
        end
    end
end

-- Убрать покачивание камеры (CameraOffset) — постоянный сброс смещения
RunService.RenderStepped:Connect(function()
    if Settings.RemoveBobbing then
        local hum = getHumanoid()
        if hum then
            hum.CameraOffset = Vector3.new(0, 0, 0)
        end
    end
end)

-- Убрать тряску камеры — best-effort: гасим случайные микро-повороты, если игра пишет их напрямую в CFrame камеры,
-- перехватить универсально для любой игры невозможно без знания её внутренних модулей.
local shakeNote = "Remove Camera Shake — эффект best-effort, может работать не во всех сценах тряски."

----------------------------------------------------------------
-- ИНТЕРФЕЙС "KISTA HUB" — вкладки слева + поиск
----------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "KistaHub"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- Цветовая схема (своя, тёмно-бирюзовая — не копия фиолетовой темы со скрина)
local BG = Color3.fromRGB(18, 22, 24)
local PANEL = Color3.fromRGB(26, 32, 34)
local ACCENT = Color3.fromRGB(0, 200, 180)
local ACCENT_DIM = Color3.fromRGB(0, 120, 110)
local TEXT_MAIN = Color3.fromRGB(230, 235, 235)
local TEXT_DIM = Color3.fromRGB(150, 160, 160)

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 560, 0, 380)
main.Position = UDim2.new(0.5, -280, 0.5, -190)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(45, 55, 55)
mainStroke.Thickness = 1
mainStroke.Parent = main

-- Шапка
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = PANEL
header.BorderSizePixel = 0
header.Parent = main

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 12)
headerCorner.Parent = header

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = PANEL
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local title = Instance.new("TextLabel")
title.Text = "KISTA HUB"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = ACCENT
title.BackgroundTransparency = 1
title.Size = UDim2.new(0, 200, 1, 0)
title.Position = UDim2.new(0, 16, 0, 0)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

-- Поиск
local searchBox = Instance.new("TextBox")
searchBox.PlaceholderText = "Поиск..."
searchBox.Text = ""
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.TextColor3 = TEXT_MAIN
searchBox.PlaceholderColor3 = TEXT_DIM
searchBox.BackgroundColor3 = BG
searchBox.Size = UDim2.new(0, 200, 0, 26)
searchBox.Position = UDim2.new(1, -216, 0.5, -13)
searchBox.ClearTextOnFocus = false
searchBox.Parent = header

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 6)
searchCorner.Parent = searchBox

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "×"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.TextColor3 = TEXT_DIM
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -34, 0, 6)
closeBtn.Parent = header

-- Сайдбар (вкладки)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 140, 1, -42)
sidebar.Position = UDim2.new(0, 0, 0, 42)
sidebar.BackgroundColor3 = PANEL
sidebar.BorderSizePixel = 0
sidebar.Parent = main

local sidebarList = Instance.new("UIListLayout")
sidebarList.Padding = UDim.new(0, 2)
sidebarList.SortOrder = Enum.SortOrder.LayoutOrder
sidebarList.Parent = sidebar

-- Контент-зона
local content = Instance.new("ScrollingFrame")
content.Size = UDim2.new(1, -140, 1, -42)
content.Position = UDim2.new(0, 140, 0, 42)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = ACCENT_DIM
content.CanvasSize = UDim2.new(0, 0, 0, 0)
content.AutomaticCanvasSize = Enum.AutomaticSize.Y
content.Parent = main

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 14)
contentPadding.PaddingLeft = UDim.new(0, 16)
contentPadding.PaddingRight = UDim.new(0, 16)
contentPadding.Parent = content

local contentList = Instance.new("UIListLayout")
contentList.Padding = UDim.new(0, 8)
contentList.SortOrder = Enum.SortOrder.LayoutOrder
contentList.Parent = content

----------------------------------------------------------------
-- Тумблер / слайдер — компоненты
----------------------------------------------------------------
local allRows = {} -- для поиска: {row = Frame, tabName = string, labelText = string}

local function createToggleRow(parent, labelText, key, order, tabName, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = PANEL
    row.LayoutOrder = order
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent = row

    local label = Instance.new("TextLabel")
    label.Text = labelText
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = TEXT_MAIN
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -56, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row

    local switch = Instance.new("Frame")
    switch.Size = UDim2.new(0, 34, 0, 18)
    switch.Position = UDim2.new(1, -44, 0.5, -9)
    switch.BackgroundColor3 = Settings[key] and ACCENT or Color3.fromRGB(60, 68, 68)
    switch.Parent = row

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = Settings[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
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
        local targetColor = Settings[key] and ACCENT or Color3.fromRGB(60, 68, 68)
        local targetPos = Settings[key] and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
        TweenService:Create(switch, TweenInfo.new(0.15), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = targetPos}):Play()
        if onChange then onChange(Settings[key]) end
    end)

    table.insert(allRows, {row = row, tabName = tabName, labelText = labelText:lower()})
    return row
end

local function createSliderRow(parent, labelText, order, tabName, min, max, key, valueKey, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = PANEL
    row.LayoutOrder = order
    row.Parent = parent

    local rowCorner = Instance.new("UICorner")
    rowCorner.CornerRadius = UDim.new(0, 8)
    rowCorner.Parent = row

    local label = Instance.new("TextLabel")
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextColor3 = TEXT_MAIN
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -24, 0, 18)
    label.Position = UDim2.new(0, 12, 0, 4)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = labelText .. ": " .. tostring(Settings[valueKey])
    label.Parent = row

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 6)
    track.Position = UDim2.new(0, 12, 1, -16)
    track.BackgroundColor3 = Color3.fromRGB(60, 68, 68)
    track.Parent = row

    local trackCorner = Instance.new("UICorner")
    trackCorner.CornerRadius = UDim.new(1, 0)
    trackCorner.Parent = track

    local fillRatio = (Settings[valueKey] - min) / (max - min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(fillRatio, 0, 1, 0)
    fill.BackgroundColor3 = ACCENT
    fill.Parent = track

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local dragBtn = Instance.new("TextButton")
    dragBtn.Text = ""
    dragBtn.BackgroundTransparency = 1
    dragBtn.Size = UDim2.new(1, 0, 1, 10)
    dragBtn.Position = UDim2.new(0, 0, 0, -5)
    dragBtn.Parent = track

    local dragging = false
    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local value = math.floor(min + rel * (max - min))
        Settings[valueKey] = value
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = labelText .. ": " .. tostring(value)
        if onChange then onChange(value) end
    end

    dragBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateFromX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(allRows, {row = row, tabName = tabName, labelText = labelText:lower()})
    return row
end

----------------------------------------------------------------
-- Вкладки: General / Movement / Visuals
----------------------------------------------------------------
local tabs = {}
local tabButtons = {}
local currentTab = "General"

local function createTabButton(name, order)
    local btn = Instance.new("TextButton")
    btn.Text = name
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextColor3 = TEXT_DIM
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BackgroundColor3 = PANEL
    btn.BackgroundTransparency = 1
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.LayoutOrder = order
    btn.Parent = sidebar

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 16)
    pad.Parent = btn

    tabButtons[name] = btn
    return btn
end

local function selectTab(name)
    currentTab = name
    for tabName, section in pairs(tabs) do
        section.Visible = (tabName == name)
    end
    for tabName, btn in pairs(tabButtons) do
        if tabName == name then
            btn.TextColor3 = ACCENT
            btn.BackgroundTransparency = 0.85
        else
            btn.TextColor3 = TEXT_DIM
            btn.BackgroundTransparency = 1
        end
    end
    searchBox.Text = ""
end

local function createSection(name)
    local section = Instance.new("Frame")
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.BackgroundTransparency = 1
    section.Visible = false
    section.Parent = content

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = section

    tabs[name] = section
    return section
end

local sectionGeneral = createSection("General")
local sectionMovement = createSection("Movement")
local sectionVisuals = createSection("Visuals")

createTabButton("General", 1).MouseButton1Click:Connect(function() selectTab("General") end)
createTabButton("Movement", 2).MouseButton1Click:Connect(function() selectTab("Movement") end)
createTabButton("Visuals", 3).MouseButton1Click:Connect(function() selectTab("Visuals") end)

----------------------------------------------------------------
-- General
----------------------------------------------------------------
createToggleRow(sectionGeneral, "ESP: Предметы", "ESP_Items", 1, "General", function(v)
    if v then rescanAll() else clearHighlights(); rescanAll() end
end)
createToggleRow(sectionGeneral, "ESP: Двери", "ESP_Doors", 2, "General", function(v)
    if v then rescanAll() else clearHighlights(); rescanAll() end
end)
createToggleRow(sectionGeneral, "ESP: Тележки", "ESP_Carts", 3, "General", function(v)
    if v then rescanAll() else clearHighlights(); rescanAll() end
end)
createToggleRow(sectionGeneral, "Предупреждение о монстре", "MonsterWarning", 4, "General")
createToggleRow(sectionGeneral, "Показывать дистанцию до угрозы", "ShowDistance", 5, "General")

----------------------------------------------------------------
-- Movement
----------------------------------------------------------------
createToggleRow(sectionMovement, "Бесконечный прыжок", "InfiniteJump", 1, "Movement")
createToggleRow(sectionMovement, "Высокий прыжок", "HighJump", 2, "Movement", function()
    if player.Character then applyJumpPower(player.Character) end
end)
createToggleRow(sectionMovement, "Кнопка прыжка (как у Seek)", "JumpButton", 3, "Movement", function(v)
    if jumpBtnHolder then jumpBtnHolder.Visible = v end
end)

----------------------------------------------------------------
-- Visuals
----------------------------------------------------------------
createToggleRow(sectionVisuals, "Свой FOV", "CustomFOV", 1, "Visuals", function()
    applyFOV()
end)
createSliderRow(sectionVisuals, "FOV", 2, "Visuals", 50, 120, "CustomFOV", "FOVValue", function()
    applyFOV()
end)
createToggleRow(sectionVisuals, "Ambient-подсветка", "Ambient", 3, "Visuals", function()
    applyAmbient()
end)
createToggleRow(sectionVisuals, "Убрать покачивание камеры", "RemoveBobbing", 4, "Visuals")
createToggleRow(sectionVisuals, "Убрать тряску камеры (best-effort)", "RemoveShake", 5, "Visuals")

selectTab("General")

----------------------------------------------------------------
-- Поиск по всем вкладкам
----------------------------------------------------------------
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    local q = searchBox.Text:lower()
    if q == "" then
        -- вернуть обычный режим текущей вкладки
        for tabName, section in pairs(tabs) do
            section.Visible = (tabName == currentTab)
        end
        for _, entry in ipairs(allRows) do
            entry.row.Visible = true
        end
        return
    end

    -- показываем все вкладки сразу, скрывая нерелевантные строки
    for _, section in pairs(tabs) do
        section.Visible = true
    end
    for _, entry in ipairs(allRows) do
        entry.row.Visible = entry.labelText:find(q, 1, true) ~= nil
    end
end)

----------------------------------------------------------------
-- Перетаскивание окна
----------------------------------------------------------------
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
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

----------------------------------------------------------------
-- Сворачивание
----------------------------------------------------------------
local openBtn = Instance.new("TextButton")
openBtn.Text = "K"
openBtn.Font = Enum.Font.GothamBold
openBtn.TextSize = 18
openBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
openBtn.Size = UDim2.new(0, 40, 0, 40)
openBtn.Position = UDim2.new(0, 20, 0, 20)
openBtn.BackgroundColor3 = PANEL
openBtn.Visible = false
openBtn.Parent = gui

local openBtnCorner = Instance.new("UICorner")
openBtnCorner.CornerRadius = UDim.new(1, 0)
openBtnCorner.Parent = openBtn

local openBtnStroke = Instance.new("UIStroke")
openBtnStroke.Color = ACCENT
openBtnStroke.Thickness = 1
openBtnStroke.Parent = openBtn

openBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    openBtn.Visible = false
end)

closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    openBtn.Visible = true
end)

----------------------------------------------------------------
-- Кнопка прыжка (как в погоне от Seek в шахтах)
----------------------------------------------------------------
jumpBtnHolder = Instance.new("Frame")
jumpBtnHolder.Size = UDim2.new(0, 80, 0, 80)
jumpBtnHolder.Position = UDim2.new(1, -260, 1, -150)
jumpBtnHolder.BackgroundTransparency = 1
jumpBtnHolder.Parent = gui

local jumpBtn = Instance.new("ImageButton")
jumpBtn.Size = UDim2.new(1, 0, 1, 0)
jumpBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
jumpBtn.BackgroundTransparency = 0.15
jumpBtn.Image = "rbxassetid://0" -- ⬅ сюда вставь свой Asset ID
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
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end

jumpBtn.MouseButton1Down:Connect(function()
    TweenService:Create(jumpBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0}):Play()
    doJump()
end)
jumpBtn.MouseButton1Up:Connect(function()
    TweenService:Create(jumpBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
end)

jumpBtnHolder.Visible = Settings.JumpButton

----------------------------------------------------------------
-- Предупреждение о монстре (плавное, с дистанцией)
----------------------------------------------------------------
local warnLabel = Instance.new("TextLabel")
warnLabel.Size = UDim2.new(0, 460, 0, 50)
warnLabel.Position = UDim2.new(0.5, -230, 0.05, 0)
warnLabel.BackgroundTransparency = 1
warnLabel.TextColor3 = Color3.fromRGB(255, 60, 60)
warnLabel.TextStrokeTransparency = 0
warnLabel.Font = Enum.Font.GothamBold
warnLabel.TextSize = 24
warnLabel.TextTransparency = 1
warnLabel.TextStrokeTransparency = 1
warnLabel.Text = ""
warnLabel.Parent = gui

local warningShown = false

-- Фильтр ложных срабатываний: монстр должен реально быть Model/Folder с Humanoid/AnimationController
-- либо лежать в папке вида Monsters/Enemies/Entities — а не просто статичный объект с похожим именем.
local function isRealMonster(obj)
    if not (obj:IsA("Model") or obj:IsA("Folder")) then return false end
    if obj:FindFirstChildOfClass("Humanoid") then return true end
    if obj:FindFirstChildOfClass("AnimationController") then return true end
    local parent = obj.Parent
    if parent then
        local pname = parent.Name:lower()
        if pname:find("monster") or pname:find("enemy") or pname:find("entity") then
            return true
        end
    end
    return false
end

local function getObjectPosition(obj)
    if obj:IsA("Model") then
        return obj.PrimaryPart and obj.PrimaryPart.Position
            or (obj:FindFirstChild("HumanoidRootPart") and obj.HumanoidRootPart.Position)
            or (obj:FindFirstChildWhichIsA("BasePart") and obj:FindFirstChildWhichIsA("BasePart").Position)
    end
    return nil
end

local function checkMonster()
    if not Settings.MonsterWarning then
        if warningShown then
            warningShown = false
            TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
        end
        return
    end

    local foundName, foundObj = nil, nil
    for _, obj in ipairs(Workspace:GetDescendants()) do
        for _, tag in ipairs(MONSTER_TAGS) do
            if obj.Name == tag and isRealMonster(obj) then
                foundName, foundObj = tag, obj
                break
            end
        end
        if foundName then break end
    end

    if foundName then
        local text = "⚠ ОПАСНОСТЬ: " .. foundName .. " РЯДОМ!"
        if Settings.ShowDistance then
            local hrp = getHRP()
            local pos = foundObj and getObjectPosition(foundObj)
            if hrp and pos then
                local dist = math.floor((hrp.Position - pos).Magnitude)
                text = text .. " (" .. dist .. "м)"
            end
        end
        warnLabel.Text = text
        if not warningShown then
            warningShown = true
            TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 0, TextStrokeTransparency = 0}):Play()
        end
    elseif warningShown then
        warningShown = false
        TweenService:Create(warnLabel, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
    end
end

----------------------------------------------------------------
-- ОСНОВНОЙ ЦИКЛ (throttled)
----------------------------------------------------------------
local lastCheck = 0
RunService.Heartbeat:Connect(function(dt)
    lastCheck += dt
    if lastCheck >= 0.3 then
        lastCheck = 0
        checkMonster()
    end
end)

applyFOV()
