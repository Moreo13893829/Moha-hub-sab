--[[
    N1 x LENNZE Notifier
    Premium UI - Midnight Blue & Sky Blue Edition
    Full Port & Optimization from Reference Script
]]

local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Player = Players.LocalPlayer

-- [[ API Configuration ]]
local FARMSYNC_URL = "https://your-project-db.farmsync.io/" 

-- [[ UI Protection ]]
local guiParent = CoreGui
if gethui then
    local ok, result = pcall(gethui)
    if ok and result then guiParent = result end
end

if guiParent:FindFirstChild("N1xLENNZENotifier") then
    guiParent["N1xLENNZENotifier"]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "N1xLENNZENotifier"
ScreenGui.Parent = guiParent
ScreenGui.ResetOnSpawn = false

-- [[ Connection Tracker ]]
local ActiveConnections = {}
local function trackConnection(conn)
    table.insert(ActiveConnections, conn)
    return conn
end

local function cleanupConnections()
    for _, conn in ipairs(ActiveConnections) do
        if conn and typeof(conn) == "RBXScriptConnection" then
            pcall(function() conn:Disconnect() end)
        end
    end
    table.clear(ActiveConnections)
end

trackConnection(ScreenGui.Destroying:Connect(cleanupConnections))

-- [[ Theme Configuration: Midnight Blue & Sky Blue ]]
local Theme = {
    Background = Color3.fromRGB(10, 15, 30),    -- Midnight Blue
    TopBar = Color3.fromRGB(15, 25, 45),        -- Deeper Midnight
    Outline = Color3.fromRGB(0, 191, 255),      -- Sky Blue
    TextPrimary = Color3.fromRGB(245, 250, 255),
    TextSecondary = Color3.fromRGB(140, 210, 240), -- Sky Blue tint
    Accent = Color3.fromRGB(0, 191, 255),       -- Sky Blue
    ButtonBg = Color3.fromRGB(20, 30, 55),      -- Midnight Blue Button
    ButtonHover = Color3.fromRGB(35, 55, 90),
    Success = Color3.fromRGB(0, 255, 180) 
}

-- [[ Utility Functions ]]
local function create(className, properties)
    local inst = Instance.new(className)
    for k, v in pairs(properties) do inst[k] = v end
    return inst
end

local function addCorner(parent, radius)
    return create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function addStroke(parent, color, thickness, transparency)
    return create("UIStroke", { Color = color, Thickness = thickness, Transparency = transparency or 0, Parent = parent })
end

-- [[ Main Frame ]]
local MainFrame = create("CanvasGroup", {
    Name = "MainFrame",
    Parent = ScreenGui,
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 20), 
    Size = UDim2.new(0, 500, 0, 480),
    BackgroundColor3 = Theme.Background,
    BorderSizePixel = 0,
    GroupTransparency = 1,
})
addCorner(MainFrame, 10)
addStroke(MainFrame, Theme.Outline, 1, 0.3)

TweenService:Create(MainFrame, TweenInfo.new(0.6, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
    GroupTransparency = 0,
    Position = UDim2.new(0.5, 0, 0.5, 0)
}):Play()

-- [[ Dragging System ]]
local isDragging = false
local dragStartMouse, dragStartPos, dragTargetPos, dragCurrentPos, dragConnection

trackConnection(MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isDragging = true
        dragStartMouse = UserInputService:GetMouseLocation()
        dragStartPos = MainFrame.Position
        dragTargetPos = MainFrame.Position
        dragCurrentPos = MainFrame.Position

        if not dragConnection then
            dragConnection = RunService.RenderStepped:Connect(function(dt)
                if not isDragging then return end
                local mousePos = UserInputService:GetMouseLocation()
                local delta = mousePos - dragStartMouse
                dragTargetPos = UDim2.new(dragStartPos.X.Scale, dragStartPos.X.Offset + delta.X, dragStartPos.Y.Scale, dragStartPos.Y.Offset + delta.Y)

                local alpha = 1 - math.exp(-25 * dt)
                dragCurrentPos = UDim2.new(
                    dragCurrentPos.X.Scale, dragCurrentPos.X.Offset + (dragTargetPos.X.Offset - dragCurrentPos.X.Offset) * alpha,
                    dragCurrentPos.Y.Scale, dragCurrentPos.Y.Offset + (dragTargetPos.Y.Offset - dragCurrentPos.Y.Offset) * alpha
                )
                MainFrame.Position = dragCurrentPos
            end)
            trackConnection(dragConnection)
        end
    end
end))

trackConnection(UserInputService.InputEnded:Connect(function(input)
    if isDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        isDragging = false
    end
end))

-- [[ Top Bar Elements ]]
local TopBar = create("Frame", { Name = "TopBar", Parent = MainFrame, Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Theme.TopBar, BorderSizePixel = 0 })
addCorner(TopBar, 10)
create("Frame", { Parent = TopBar, Size = UDim2.new(1, 0, 0, 10), Position = UDim2.new(0, 0, 1, -10), BackgroundColor3 = Theme.Background, BorderSizePixel = 0 })

local Title = create("TextLabel", { Name = "Title", Parent = TopBar, Position = UDim2.new(0, 15, 0, 0), Size = UDim2.new(0, 250, 1, 0), BackgroundTransparency = 1, Text = "N1 x LENNZE Notifier", TextColor3 = Theme.TextPrimary, TextSize = 15, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left })

local CloseBtn = create("TextButton", { Name = "CloseBtn", Parent = TopBar, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -15, 0.5, 0), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "X", TextColor3 = Theme.TextSecondary, TextSize = 16, Font = Enum.Font.GothamBold })
local MinimizeBtn = create("TextButton", { Name = "MinimizeBtn", Parent = TopBar, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -45, 0.5, 0), Size = UDim2.new(0, 24, 0, 24), BackgroundTransparency = 1, Text = "-", TextColor3 = Theme.TextSecondary, TextSize = 20, Font = Enum.Font.GothamBold })

-- [[ Layout & Tabs ]]
local TabsMenu = create("Frame", { Name = "TabsMenu", Parent = MainFrame, Position = UDim2.new(0, 0, 0, 45), Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1 })
create("UIListLayout", { Parent = TabsMenu, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 30) })
local ContentArea = create("Frame", { Name = "ContentArea", Parent = MainFrame, Position = UDim2.new(0, 15, 0, 90), Size = UDim2.new(1, -30, 1, -130), BackgroundTransparency = 1 })
local BottomBar = create("Frame", { Name = "BottomBar", Parent = MainFrame, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 35), BackgroundTransparency = 1 })

local tabs = {}
local function createTab(name, order)
    local TabBtn = create("TextButton", { Name = name.."Tab", Parent = TabsMenu, Size = UDim2.new(0, 0, 1, 0), BackgroundTransparency = 1, Text = name:upper(), TextColor3 = Theme.TextSecondary, TextSize = 12, Font = Enum.Font.GothamBold, LayoutOrder = order, AutomaticSize = Enum.AutomaticSize.X })
    local TabIndicator = create("Frame", { Name = "Indicator", Parent = TabBtn, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })
    local TabContent = create("ScrollingFrame", { Name = name.."Content", Parent = ContentArea, Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, ScrollBarThickness = 2, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarImageColor3 = Theme.Outline })
    create("UIListLayout", { Parent = TabContent, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
    
    tabs[name] = {Btn = TabBtn, Content = TabContent, Indicator = TabIndicator}
    trackConnection(TabBtn.MouseButton1Click:Connect(function()
        for tName, tData in pairs(tabs) do
            local isSelected = (tName == name)
            tData.Content.Visible = isSelected
            TweenService:Create(tData.Btn, TweenInfo.new(0.2), {TextColor3 = isSelected and Theme.TextPrimary or Theme.TextSecondary}):Play()
            TweenService:Create(tData.Indicator, TweenInfo.new(0.2), {Size = isSelected and UDim2.new(1, 0, 0, 2) or UDim2.new(0, 0, 0, 2)}):Play()
        end
    end))
    return TabContent
end

local FiltersTab = createTab("Filters", 1)
local GeneralTab = createTab("General", 2)
local LiveFeedTab = createTab("Live Feed", 3)
local AboutTab = createTab("About", 4)

tabs["Filters"].Btn.TextColor3 = Theme.TextPrimary
tabs["Filters"].Indicator.Size = UDim2.new(1, 0, 0, 2)
tabs["Filters"].Content.Visible = true

-- [[ Window Controls Logic ]]
local isMinimized = false
local function ToggleMinimize()
    isMinimized = not isMinimized
    local targetSize = isMinimized and UDim2.new(0, 500, 0, 45) or UDim2.new(0, 500, 0, 480)
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Size = targetSize}):Play()
    ContentArea.Visible = not isMinimized
    TabsMenu.Visible = not isMinimized
    BottomBar.Visible = not isMinimized
end

trackConnection(CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end))
trackConnection(MinimizeBtn.MouseButton1Click:Connect(ToggleMinimize))

-- [[ Status Indicator ]]
local StatusDot = create("Frame", { Name = "StatusDot", Parent = BottomBar, Position = UDim2.new(0, 15, 0.5, -4), Size = UDim2.new(0, 8, 0, 8), BackgroundColor3 = Theme.Accent, BorderSizePixel = 0 })
addCorner(StatusDot, 10)
local StatusText = create("TextLabel", { Parent = BottomBar, Position = UDim2.new(0, 32, 0, 0), Size = UDim2.new(0, 180, 1, 0), BackgroundTransparency = 1, Text = "Waiting for logs", TextColor3 = Theme.TextSecondary, TextSize = 12, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
create("TextLabel", { Parent = BottomBar, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -15, 1, 0), BackgroundTransparency = 1, Text = "therealroyalcrown.gg", TextColor3 = Theme.TextSecondary, TextSize = 12, Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right })

local function SetStatus(active)
    StatusText.Text = active and "Notifier is active" or "Waiting for logs"
    TweenService:Create(StatusDot, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = active and 0 or 0.6}):Play()
end
SetStatus(false)

-- [[ General Tab Elements ]]
local SettingsState = { Sound = true, AutoJoin = false }
local SettingsInputs = {}

local function createHeader(parent, text, order)
    create("TextLabel", { Parent = parent, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextSecondary, TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = order })
end

local function createToggle(parent, text, key, default, order)
    SettingsState[key] = default
    local frame = create("Frame", { Parent = parent, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order })
    create("TextLabel", { Parent = frame, Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextPrimary, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
    local tgl = create("TextButton", { Parent = frame, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 38, 0, 20), BackgroundColor3 = default and Theme.Accent or Theme.ButtonBg, Text = "" })
    addCorner(tgl, 10) addStroke(tgl, Theme.Outline, 1, 0.2)
    local dot = create("Frame", { Parent = tgl, Position = default and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7), Size = UDim2.new(0, 14, 0, 14), BackgroundColor3 = Color3.new(1,1,1) })
    addCorner(dot, 10)
    
    tgl.MouseButton1Click:Connect(function()
        SettingsState[key] = not SettingsState[key]
        local s = SettingsState[key]
        TweenService:Create(tgl, TweenInfo.new(0.2), {BackgroundColor3 = s and Theme.Accent or Theme.ButtonBg}):Play()
        TweenService:Create(dot, TweenInfo.new(0.2), {Position = s and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)}):Play()
    end)
end

local function createInput(id, text, default, order)
    local frame = create("Frame", { Parent = GeneralTab, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order })
    create("TextLabel", { Parent = frame, Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextPrimary, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
    local bg = create("Frame", { Parent = frame, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 26), BackgroundColor3 = Theme.ButtonBg })
    addCorner(bg, 6) addStroke(bg, Theme.Outline, 1, 0.2)
    local box = create("TextBox", { Parent = bg, Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 5, 0, 0), BackgroundTransparency = 1, Text = default, TextColor3 = Theme.TextSecondary, TextSize = 12, Font = Enum.Font.Gotham, ClearTextOnFocus = false })
    SettingsInputs[id] = box
end

local function createKeybind(text, default, order)
    local frame = create("Frame", { Parent = GeneralTab, Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order })
    create("TextLabel", { Parent = frame, Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Theme.TextPrimary, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
    local btn = create("TextButton", { Parent = frame, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 140, 0, 26), BackgroundColor3 = Theme.ButtonBg, Text = default, TextColor3 = Theme.TextSecondary, TextSize = 12, Font = Enum.Font.Gotham })
    addCorner(btn, 6) addStroke(btn, Theme.Outline, 1, 0.2)
    
    local listening = false
    local key = Enum.KeyCode[default]
    btn.MouseButton1Click:Connect(function()
        listening = true btn.Text = "..."
    end)
    UserInputService.InputBegan:Connect(function(i, p)
        if listening and i.UserInputType == Enum.UserInputType.Keyboard then
            listening = false key = i.KeyCode btn.Text = key.Name
        elseif not listening and not p and i.KeyCode == key and text == "Open/Close Menu" then
            ToggleMinimize()
        end
    end)
end

createHeader(GeneralTab, "TOGGLE KEYBIND", 1)
createKeybind("Open/Close Menu", "RightShift", 2)
createHeader(GeneralTab, "NOTIFICATION SETTINGS", 3)
createToggle(GeneralTab, "Notification Sound", "Sound", true, 4)
createInput("SoundID", "Sound ID", "1342568949118398", 5)
createHeader(GeneralTab, "JOIN SETTINGS", 6)
createInput("Retries", "Retries", "10", 7)
createInput("MinValue", "Min Join Value", "100", 8)
createToggle(GeneralTab, "Auto-Join", "AutoJoin", false, 9)

-- [[ Live Feed System ]]
local FeedFilters = create("Frame", { Parent = LiveFeedTab, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = 1 })
create("UIListLayout", { Parent = FeedFilters, FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) })

local LogsContainer = create("ScrollingFrame", { Parent = LiveFeedTab, Size = UDim2.new(1, 0, 1, -40), BackgroundTransparency = 1, ScrollBarThickness = 2, LayoutOrder = 2, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0,0,0,0) })
create("UIListLayout", { Parent = LogsContainer, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder })

local function AddLog(name, value, jobId)
    local frame = create("CanvasGroup", { Parent = LogsContainer, Size = UDim2.new(1, -5, 0, 45), BackgroundColor3 = Theme.ButtonBg, GroupTransparency = 1 })
    addCorner(frame, 8) addStroke(frame, Theme.Outline, 1, 0.2)
    create("TextLabel", { Parent = frame, Position = UDim2.new(0, 10, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = Theme.TextPrimary, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
    create("TextLabel", { Parent = frame, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.2, 0, 1, 0), BackgroundTransparency = 1, Text = value .. "M", TextColor3 = Theme.Accent, TextSize = 14, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Right })
    
    local btn = create("TextButton", { Parent = frame, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 60, 0, 26), BackgroundColor3 = Theme.Accent, Text = "JOIN", TextColor3 = Color3.new(1,1,1), TextSize = 11, Font = Enum.Font.GothamBlack })
    addCorner(btn, 6)
    
    btn.MouseButton1Click:Connect(function()
        btn.Text = "..."
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, Player) end)
    end)
    
    TweenService:Create(frame, TweenInfo.new(0.4), {GroupTransparency = 0}):Play()
    SetStatus(true)
end

local CurrentFilter = "10M+"
local filters = {"10M+", "50M+", "100M+", "300M+", "1B+"}
for i, f in ipairs(filters) do
    local b = create("TextButton", { Parent = FeedFilters, Size = UDim2.new(0, 55, 0, 24), BackgroundColor3 = (f == CurrentFilter) and Theme.Accent or Theme.ButtonBg, Text = f, TextColor3 = Theme.TextPrimary, TextSize = 11, Font = Enum.Font.GothamBold })
    addCorner(b, 12)
    b.MouseButton1Click:Connect(function()
        CurrentFilter = f
        for _, child in ipairs(FeedFilters:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = Theme.ButtonBg end end
        b.BackgroundColor3 = Theme.Accent
        for _, log in ipairs(LogsContainer:GetChildren()) do if log:IsA("CanvasGroup") then log:Destroy() end end
        SetStatus(false)
    end)
end

-- [[ About Tab ]]
local function createAboutBox(title, value, isLink)
    createHeader(AboutTab, title, 1)
    local box = create("Frame", { Parent = AboutTab, Size = UDim2.new(1, 0, 0, 45), BackgroundColor3 = Theme.ButtonBg })
    addCorner(box, 8) addStroke(box, Theme.Outline, 1, 0.2)
    create("TextLabel", { Parent = box, Position = UDim2.new(0, 12, 0, 0), Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = value, TextColor3 = Theme.TextPrimary, TextSize = 13, Font = Enum.Font.GothamMedium, TextXAlignment = Enum.TextXAlignment.Left })
    
    if isLink then
        local btn = create("TextButton", { Parent = box, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0, 70, 0, 26), BackgroundColor3 = Theme.TopBar, Text = "Copy", TextColor3 = Theme.TextPrimary, TextSize = 12, Font = Enum.Font.GothamBold })
        addCorner(btn, 6)
        btn.MouseButton1Click:Connect(function()
            if setclipboard then setclipboard(value) btn.Text = "Copied!" task.wait(2) btn.Text = "Copy" end
        end)
    end
end

createAboutBox("OWNER", "N1 and Lennze", false)
createAboutBox("DISCORD", "https://discord.gg/RBABRNaVQ", true)

-- [[ Filters Tab (Empty for User) ]]
createHeader(FiltersTab, "OCS", 1)
createHeader(FiltersTab, "HIGH VALUE ITEMS", 2)

-- [[ Data Loop ]]
task.spawn(function()
    while task.wait(3) do
        -- Logic simulation for Status logic demo
        if #LogsContainer:GetChildren() > 1 then SetStatus(true) else SetStatus(false) end
    end
end)

print("N1 x LENNZE Notifier Loaded - Full Restoration")
