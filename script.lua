-- ==============================================================================
-- INTERNAL SYSTEM v11.0 MASSIVE - VERSION COMPLÈTE ET FONCTIONNELLE
-- Basé sur les diagnostics validés : GetPivot() + Toggle GUI fonctionnel
-- ==============================================================================

print("[V11] === INITIALISATION ===")

-- ====================== SERVICES ======================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local _Camera = Workspace.CurrentCamera

print("[V11] Services loaded")

-- ====================== GUI PARENT ======================
local HubParent = gethui and gethui() or CoreGui

-- Cleanup
for _, child in pairs(HubParent:GetChildren()) do
    if child.Name == "InternalV11_GUI" then 
        child:Destroy() 
        print("[V11] Cleaned old GUI")
    end
end

-- ====================== CONFIGURATION ======================
local Config = {
    AutoGrab = false,
    StealHighestGen = true,
    StealHighestValue = false,
    StealNearest = false,
    GrabRange = 50,
    GrabDelay = 0.8,
    GrabCooldown = 0.5,
    ContinuousTP = false,
    BrainrotESP = false,
    PlayerESP = false,
    RainbowBase = false,
    InfiniteJump = false,
    AntiRagdoll = false,
    SpeedBoost = false,
    XrayBase = false,
    ThemeColor = Color3.fromRGB(130, 80, 255)
}

-- ====================== COULEURS ======================
local COLORS = {
    bg = Color3.fromRGB(12, 12, 18),
    bgAccent = Color3.fromRGB(22, 22, 32),
    accent = Color3.fromRGB(130, 80, 255),
    accent2 = Color3.fromRGB(0, 220, 255),
    text = Color3.fromRGB(255, 255, 255),
    textDim = Color3.fromRGB(170, 170, 190),
    success = Color3.fromRGB(0, 255, 150),
    danger = Color3.fromRGB(255, 60, 90),
    warning = Color3.fromRGB(255, 210, 50)
}

-- ====================== UTILITAIRES ======================
local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

-- ====================== RÉFÉRENCES JEU ======================
local GameRefs = {
    Plots = Workspace:WaitForChild("Plots"),
    RemoteSteal = nil
}

-- Chercher le remote
local packages = ReplicatedStorage:FindFirstChild("Packages")
if packages then
    local net = packages:FindFirstChild("Net")
    if net then
        GameRefs.RemoteSteal = net:FindFirstChild("RE/StealService/DeliverySteal")
    end
end
if not GameRefs.RemoteSteal then
    GameRefs.RemoteSteal = ReplicatedStorage:FindFirstChild("DeliverySteal", true)
end

print("[V11] Plots: " .. tostring(GameRefs.Plots ~= nil) .. " | Remote: " .. tostring(GameRefs.RemoteSteal ~= nil))

-- ====================== FONCTIONS BRAINROT ======================
local function GetBrainrotPosition(brainrot)
    if not brainrot then return nil end
    local success, pivot = pcall(function() return brainrot:GetPivot() end)
    if success and pivot then return pivot.Position end
    
    if brainrot.PrimaryPart then return brainrot.PrimaryPart.Position end
    local base = brainrot:FindFirstChild("Base")
    if base and base:IsA("BasePart") then return base.Position end
    if base then
        local spawn = base:FindFirstChild("Spawn")
        if spawn and spawn:IsA("BasePart") then return spawn.Position end
    end
    for _, child in pairs(brainrot:GetDescendants()) do
        if child:IsA("BasePart") then return child.Position end
    end
    return nil
end

local function GetBrainrotPrompt(brainrot)
    if not brainrot then return nil end
    local base = brainrot:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local attachment = spawn:FindFirstChild("PromptAttachment")
    if not attachment then return nil end
    return attachment:FindFirstChildWhichIsA("ProximityPrompt")
end

local function GetBrainrotGen(brainrot)
    local config = brainrot:FindFirstChild("Configuration")
    if config then
        local gen = config:FindFirstChild("Gen")
        if gen then
            return typeof(gen) == "NumberValue" and gen.Value or tonumber(gen.Value) or 0
        end
    end
    return 0
end

-- ====================== SCANNER ======================
local function ScanBrainrots()
    local list = {}
    if not GameRefs.Plots then return list end
    
    for _, plot in pairs(GameRefs.Plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            for _, brainrot in pairs(podiums:GetChildren()) do
                if brainrot:IsA("Model") then
                    local pos = GetBrainrotPosition(brainrot)
                    if pos then
                        table.insert(list, {
                            Model = brainrot,
                            Position = pos,
                            Gen = GetBrainrotGen(brainrot),
                            Prompt = GetBrainrotPrompt(brainrot)
                        })
                    end
                end
            end
        end
    end
    return list
end

-- ====================== CRÉATION GUI ======================
local Gui = Instance.new("ScreenGui")
Gui.Name = "InternalV11_GUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = HubParent

-- Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 55, 0, 55)
ToggleBtn.Position = UDim2.new(0, 20, 0.5, -27)
ToggleBtn.BackgroundColor3 = COLORS.bgAccent
ToggleBtn.Text = "⚡"
ToggleBtn.TextColor3 = COLORS.accent
ToggleBtn.TextSize = 26
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.Parent = Gui

Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleBtn).Color = COLORS.accent
Instance.new("UIStroke", ToggleBtn).Thickness = 2

-- Main Frame
local Main = Instance.new("Frame")
Main.Name = "MainFrame"
Main.Size = UDim2.new(0, 480, 0, 520)
Main.Position = UDim2.new(0.5, -240, 0.5, -260)
Main.BackgroundColor3 = COLORS.bg
Main.BorderSizePixel = 0
Main.Visible = false
Main.Parent = Gui

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", Main).Color = COLORS.bgAccent
Instance.new("UIStroke", Main).Thickness = 2

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 70)
Header.BackgroundTransparency = 1
Header.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 0, 35)
Title.Position = UDim2.new(0, 20, 0, 12)
Title.BackgroundTransparency = 1
Title.Text = "INTERNAL <font color='#8250FF'>v11.0 MASSIVE</font>"
Title.RichText = true
Title.TextColor3 = COLORS.text
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 20
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Header

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -60, 0, 18)
Subtitle.Position = UDim2.new(0, 20, 0, 42)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "Premium Brainrot Controller"
Subtitle.TextColor3 = COLORS.textDim
Subtitle.Font = Enum.Font.GothamBold
Subtitle.TextSize = 11
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -47, 0, 19)
CloseBtn.BackgroundColor3 = COLORS.danger
CloseBtn.BackgroundTransparency = 0.9
CloseBtn.Text = "×"
CloseBtn.TextColor3 = COLORS.danger
CloseBtn.TextSize = 24
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- Tabs Container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -30, 0, 42)
TabContainer.Position = UDim2.new(0, 15, 0, 78)
TabContainer.BackgroundColor3 = COLORS.bgAccent
TabContainer.Parent = Main
Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 8)

local TabList = Instance.new("UIListLayout", TabContainer)
TabList.FillDirection = Enum.FillDirection.Horizontal
TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
TabList.Padding = UDim.new(0, 8)

-- Pages Container
local Pages = Instance.new("Frame")
Pages.Size = UDim2.new(1, -30, 1, -195)
Pages.Position = UDim2.new(0, 15, 0, 130)
Pages.BackgroundTransparency = 1
Pages.Parent = Main

-- Status Bar
local StatusBar = Instance.new("Frame")
StatusBar.Size = UDim2.new(1, -30, 0, 45)
StatusBar.Position = UDim2.new(0, 15, 1, -55)
StatusBar.BackgroundColor3 = COLORS.bgAccent
StatusBar.Parent = Main
Instance.new("UICorner", StatusBar).CornerRadius = UDim.new(0, 8)

local StatusText = Instance.new("TextLabel")
StatusText.Name = "StatusText"
StatusText.Size = UDim2.new(1, -20, 0, 20)
StatusText.Position = UDim2.new(0, 10, 0, 5)
StatusText.BackgroundTransparency = 1
StatusText.Text = "Status: Ready"
StatusText.TextColor3 = COLORS.textDim
StatusText.Font = Enum.Font.GothamBold
StatusText.TextSize = 11
StatusText.TextXAlignment = Enum.TextXAlignment.Left
StatusText.Parent = StatusBar

-- Draggable
local dragging, dragStart, startPos = false, nil, nil
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ====================== UI COMPONENTS ======================
local Tabs = {}

local function CreateTab(name, icon)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 75, 0, 32)
    btn.BackgroundTransparency = 1
    btn.Text = icon .. " " .. name
    btn.TextColor3 = COLORS.textDim
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = TabContainer

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = COLORS.accent
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = Pages
    
    local list = Instance.new("UIListLayout", page)
    list.Padding = UDim.new(0, 6)
    list.SortOrder = Enum.SortOrder.LayoutOrder

    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(Tabs) do
            t.page.Visible = false
            t.btn.TextColor3 = COLORS.textDim
        end
        page.Visible = true
        btn.TextColor3 = COLORS.accent
    end)

    table.insert(Tabs, {btn = btn, page = page})
    return page
end

local pSteal = CreateTab("Steal", "⚡")
local pTP = CreateTab("Teleport", "🚀")
local pVisuals = CreateTab("Visuals", "👁️")
local pAuto = CreateTab("Auto", "⚙️")
local pCombat = CreateTab("Combat", "⚔️")
local pSecurity = CreateTab("Sec", "🛡️")

local function AddToggle(parent, text, configKey, callback)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1, -4, 0, 44)
    f.BackgroundColor3 = COLORS.bgAccent
    f.Text = ""
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.65, 0, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = COLORS.text
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local tbg = Instance.new("Frame")
    tbg.Size = UDim2.new(0, 40, 0, 20)
    tbg.Position = UDim2.new(1, -52, 0.5, -10)
    tbg.BackgroundColor3 = Config[configKey] and COLORS.accent or Color3.fromRGB(40, 40, 50)
    tbg.Parent = f
    Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 14, 0, 14)
    dot.Position = Config[configKey] and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)
    dot.BackgroundColor3 = Color3.new(1,1,1)
    dot.Parent = tbg
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    f.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local state = Config[configKey]
        TweenService:Create(tbg, TweenInfo.new(0.25), {BackgroundColor3 = state and COLORS.accent or Color3.fromRGB(40, 40, 50)}):Play()
        TweenService:Create(dot, TweenInfo.new(0.25, Enum.EasingStyle.Back), {Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}):Play()
        if callback then callback(state) end
    end)
end

local function AddButton(parent, text, callback)
    local f = Instance.new("TextButton")
    f.Size = UDim2.new(1, -4, 0, 38)
    f.BackgroundColor3 = COLORS.accent
    f.BackgroundTransparency = 0.8
    f.Text = text
    f.TextColor3 = COLORS.text
    f.Font = Enum.Font.GothamBold
    f.TextSize = 12
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", f).Color = COLORS.accent
    
    f.MouseButton1Click:Connect(function() 
        f.BackgroundTransparency = 0.5
        task.delay(0.1, function() f.BackgroundTransparency = 0.8 end)
        if callback then callback() end 
    end)
end

local function AddSlider(parent, text, min, max, configKey, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -4, 0, 58)
    f.BackgroundColor3 = COLORS.bgAccent
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.6, 0, 0, 24)
    lbl.Position = UDim2.new(0, 12, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = COLORS.textDim
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = f

    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.3, 0, 0, 24)
    val.Position = UDim2.new(0.7, -10, 0, 4)
    val.BackgroundTransparency = 1
    val.Text = tostring(Config[configKey])
    val.TextColor3 = COLORS.accent2
    val.Font = Enum.Font.GothamBold
    val.TextSize = 12
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -24, 0, 5)
    track.Position = UDim2.new(0, 12, 0, 40)
    track.BackgroundColor3 = Color3.fromRGB(40,40,55)
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local bar = Instance.new("Frame")
    local pct = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    bar.Size = UDim2.new(pct, 0, 1, 0)
    bar.BackgroundColor3 = COLORS.accent
    bar.Parent = track
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local ctrl = Instance.new("TextButton")
    ctrl.Size = UDim2.new(1, 0, 1, 0)
    ctrl.BackgroundTransparency = 1
    ctrl.Text = ""
    ctrl.Parent = f

    local function update(input)
        local r = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local v = math.floor(min + (max - min) * r)
        Config[configKey] = v
        val.Text = tostring(v)
        bar.Size = UDim2.new(r, 0, 1, 0)
        if callback then callback(v) end
    end

    local drag = false
    ctrl.InputBegan:Connect(function(i) 
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
            drag = true 
            update(i) 
        end 
    end)
    UserInputService.InputEnded:Connect(function(i) 
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
            drag = false 
        end 
    end)
    UserInputService.InputChanged:Connect(function(i) 
        if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then 
            update(i) 
        end 
    end)
end

-- ====================== REMPLISSAGE TABS ======================

-- STEAL TAB
AddToggle(pSteal, "⚡ Auto-Grab Brainrot", "AutoGrab", function(state)
    Notify("Auto-Grab", state and "Activated!" or "Deactivated", 2)
    StatusText.Text = state and "Auto-Grab: ON" or "Auto-Grab: OFF"
end)
AddToggle(pSteal, "🎯 Steal Highest Gen", "StealHighestGen", function()
    Config.StealHighestValue = false
    Config.StealNearest = false
end)
AddToggle(pSteal, "💰 Steal Highest Value", "StealHighestValue", function()
    Config.StealHighestGen = false
    Config.StealNearest = false
end)
AddToggle(pSteal, "📍 Steal Nearest", "StealNearest", function()
    Config.StealHighestGen = false
    Config.StealHighestValue = false
end)
AddSlider(pSteal, "📏 Grab Range", 5, 150, "GrabRange")
AddSlider(pSteal, "⏱️ Grab Delay", 1, 10, "GrabDelay")
AddButton(pSteal, "🔍 Scan Brainrots", function()
    local list = ScanBrainrots()
    Notify("Scan", "Found " .. #list .. " brainrots", 3)
    StatusText.Text = "Found " .. #list .. " brainrots"
end)

-- TELEPORT TAB
AddButton(pTP, "🛰️ TP to Best Gen", function()
    local list = ScanBrainrots()
    local best = nil
    local bestGen = -1
    for _, b in pairs(list) do
        if b.Gen > bestGen then
            bestGen = b.Gen
            best = b
        end
    end
    if best then
        local hrp = GetHRP()
        if hrp then
            hrp.CFrame = CFrame.new(best.Position + Vector3.new(0, 5, 5))
            StatusText.Text = "TP to " .. best.Model.Name .. " (Gen " .. best.Gen .. ")"
        end
    end
end)
AddButton(pTP, "🎯 TP to Nearest", function()
    local list = ScanBrainrots()
    local hrp = GetHRP()
    if not hrp then return end
    local nearest = nil
    local minDist = math.huge
    for _, b in pairs(list) do
        local dist = (b.Position - hrp.Position).Magnitude
        if dist < minDist then
            minDist = dist
            nearest = b
        end
    end
    if nearest then
        hrp.CFrame = CFrame.new(nearest.Position + Vector3.new(0, 5, 5))
        StatusText.Text = "TP to nearest: " .. nearest.Model.Name
    end
end)
AddToggle(pTP, "🔄 Continuous Auto-TP", "ContinuousTP")
AddToggle(pTP, "♾️ Infinite Jump", "InfiniteJump")
AddToggle(pTP, "🛡️ Anti-Ragdoll", "AntiRagdoll")
AddToggle(pTP, "💨 Speed Boost", "SpeedBoost")
AddButton(pTP, "🔄 Rejoin Server", function()
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

-- VISUALS TAB
AddToggle(pVisuals, "🧠 Brainrot ESP", "BrainrotESP", function(state)
    StatusText.Text = state and "ESP Enabled" or "ESP Disabled"
    if not state then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "ESP_Highlight" or obj.Name == "ESP_Label" then
                obj:Destroy()
            end
        end
    end
end)
AddToggle(pVisuals, "👤 Player ESP", "PlayerESP")
AddToggle(pVisuals, "🌈 Rainbow Base", "RainbowBase")
AddToggle(pVisuals, "🩻 Xray Base", "XrayBase")

-- AUTO TAB
AddSlider(pAuto, "📐 GUI Scale", 0.5, 2, "GUIScale", function(v)
    -- GUI scale implementation
end)
AddButton(pAuto, "🛑 Kick Self", function()
    LocalPlayer:Kick("User request")
end)

-- COMBAT TAB
AddButton(pCombat, "🔴 Laser Aimbot", function()
    Notify("Combat", "Feature not implemented", 2)
end)
AddButton(pCombat, "🎨 Paintball Aimbot", function()
    Notify("Combat", "Feature not implemented", 2)
end)

-- SECURITY TAB
AddToggle(pSecurity, "🛡️ Anti-Cheat Bypass", "AntiCheat")
AddToggle(pSecurity, "⏩ Loading Bypass", "LoadingBypass")

-- ====================== TOGGLE LOGIC ======================
local isOpen = false

ToggleBtn.MouseButton1Click:Connect(function()
    isOpen = not isOpen
    Main.Visible = true
    
    if isOpen then
        -- Animation ouverture
        Main.Size = UDim2.new(0, 0, 0, 0)
        Main.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 480, 0, 520),
            Position = UDim2.new(0.5, -240, 0.5, -260)
        }):Play()
        
        ToggleBtn.BackgroundColor3 = COLORS.danger
        ToggleBtn.Text = "✕"
    else
        -- Animation fermeture
        TweenService:Create(Main, TweenInfo.new(0.3), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }):Play()
        
        task.delay(0.3, function()
            if not isOpen then Main.Visible = false end
        end)
        
        ToggleBtn.BackgroundColor3 = COLORS.bgAccent
        ToggleBtn.Text = "⚡"
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    isOpen = false
    TweenService:Create(Main, TweenInfo.new(0.3), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    task.delay(0.3, function() Main.Visible = false end)
    ToggleBtn.BackgroundColor3 = COLORS.bgAccent
    ToggleBtn.Text = "⚡"
end)

-- Select first tab
Tabs[1].btn.TextColor3 = COLORS.accent
Tabs[1].page.Visible = true

print("[V11] GUI Created")

-- ====================== SYSTÈME AUTO-GRAB ======================
local StealSystem = {
    LastSteal = 0,
    IsCarrying = false
}

local function IsCarryingBrainrot()
    local hrp = GetHRP()
    if not hrp then return false end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") then
            local root = obj:FindFirstChild("RootPart")
            if root then
                for _, weld in pairs(root:GetChildren()) do
                    if weld:IsA("WeldConstraint") and weld.Part0 == hrp then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function ExecuteSteal(target)
    if not target or not target.Prompt then return false end
    
    local currentTime = tick()
    if currentTime - StealSystem.LastSteal < Config.GrabCooldown then return false end
    StealSystem.LastSteal = currentTime
    
    local hrp = GetHRP()
    if not hrp then return false end
    
    -- TP proche
    hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 3))
    task.wait(0.2)
    
    -- Fire prompt
    if fireproximityprompt then
        fireproximityprompt(target.Prompt, 0)
    else
        target.Prompt:InputHoldBegin()
        task.wait(0.05)
        target.Prompt:InputHoldEnd()
    end
    
    -- Fire remote
    if GameRefs.RemoteSteal then
        task.wait(0.2)
        GameRefs.RemoteSteal:FireServer()
    end
    
    return true
end

local function StealLogic()
    if not Config.AutoGrab then return end
    
    if IsCarryingBrainrot() then
        StealSystem.IsCarrying = true
        StatusText.Text = "CARRYING - Return to base!"
        StatusText.TextColor3 = COLORS.warning
        return
    else
        StealSystem.IsCarrying = false
    end
    
    local brainrots = ScanBrainrots()
    if #brainrots == 0 then
        StatusText.Text = "No brainrots found"
        return
    end
    
    local hrp = GetHRP()
    if not hrp then return end
    
    -- Filtrer par range
    local inRange = {}
    for _, b in pairs(brainrots) do
        local dist = (b.Position - hrp.Position).Magnitude
        if dist <= Config.GrabRange then
            table.insert(inRange, b)
        end
    end
    
    if #inRange == 0 then
        StatusText.Text = "No targets in range (" .. Config.GrabRange .. ")"
        return
    end
    
    -- Sélectionner cible
    local target = nil
    local bestScore = -math.huge
    
    for _, b in pairs(inRange) do
        local score = 0
        local dist = (b.Position - hrp.Position).Magnitude
        
        if Config.StealHighestGen then
            score = b.Gen * 1000000 - dist
        elseif Config.StealHighestValue then
            score = -dist
        elseif Config.StealNearest then
            score = -dist
        else
            score = b.Gen * 1000 - dist
        end
        
        if score > bestScore then
            bestScore = score
            target = b
        end
    end
    
    if target then
        StatusText.Text = "Stealing: " .. target.Model.Name .. " (Gen " .. target.Gen .. ")"
        StatusText.TextColor3 = COLORS.accent
        ExecuteSteal(target)
    end
end

-- Loop Auto-Grab
task.spawn(function()
    while true do
        task.wait(Config.GrabDelay)
        if Config.AutoGrab then
            local success, err = pcall(StealLogic)
            if not success then warn("[STEAL ERROR] " .. tostring(err)) end
        end
    end
end)

-- ====================== CONTINUOUS TP ======================
task.spawn(function()
    while true do
        task.wait(3)
        if Config.ContinuousTP then
            local success, err = pcall(function()
                local list = ScanBrainrots()
                local best = nil
                local bestGen = -1
                for _, b in pairs(list) do
                    if b.Gen > bestGen then
                        bestGen = b.Gen
                        best = b
                    end
                end
                if best then
                    local hrp = GetHRP()
                    if hrp then
                        hrp.CFrame = CFrame.new(best.Position + Vector3.new(0, 5, 5))
                    end
                end
            end)
            if not success then warn("[TP ERROR] " .. tostring(err)) end
        end
    end
end)

-- ====================== ESP SYSTEM ======================
local ESPObjects = {}

local function CreateESP(brainrot)
    if not brainrot.Model or not brainrot.Model.Parent then return end
    if brainrot.Model:FindFirstChild("ESP_Highlight") then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_Highlight"
    highlight.FillColor = COLORS.accent
    highlight.OutlineColor = COLORS.accent2
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0
    highlight.Parent = brainrot.Model
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_Label"
    billboard.Size = UDim2.new(0, 80, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = brainrot.Model.Name .. "\nGen: " .. brainrot.Gen
    label.TextColor3 = COLORS.accent
    label.Font = Enum.Font.GothamBold
    label.TextSize = 10
    label.Parent = billboard
    
    billboard.Parent = brainrot.Model
end

local function UpdateESP()
    if not Config.BrainrotESP then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "ESP_Highlight" or obj.Name == "ESP_Label" then
                obj:Destroy()
            end
        end
        return
    end
    
    local brainrots = ScanBrainrots()
    for _, b in pairs(brainrots) do
        if not b.Model:FindFirstChild("ESP_Highlight") then
            CreateESP(b)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        if Config.BrainrotESP then
            local success, err = pcall(UpdateESP)
            if not success then warn("[ESP ERROR] " .. tostring(err)) end
        end
    end
end)

-- ====================== PLAYER ESP ======================
task.spawn(function()
    while true do
        task.wait(2)
        if Config.PlayerESP then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    if not player.Character:FindFirstChild("PlayerESP") then
                        local esp = Instance.new("Highlight")
                        esp.Name = "PlayerESP"
                        esp.FillColor = COLORS.danger
                        esp.OutlineColor = COLORS.warning
                        esp.FillTransparency = 0.9
                        esp.Parent = player.Character
                    end
                end
            end
        end
    end
end)

-- ====================== INFINITE JUMP ======================
UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local hum = GetHumanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ====================== ANTI-RAGDOLL ======================
task.spawn(function()
    while true do
        task.wait(0.3)
        if Config.AntiRagdoll then
            local char = LocalPlayer.Character
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end
    end
end)

-- ====================== SPEED BOOST ======================
task.spawn(function()
    while true do
        task.wait(0.1)
        if Config.SpeedBoost then
            local hum = GetHumanoid()
            if hum and hum.WalkSpeed < 50 then hum.WalkSpeed = 50 end
        end
    end
end)

-- ====================== RAINBOW BASE ======================
task.spawn(function()
    local hue = 0
    while true do
        task.wait(0.05)
        if Config.RainbowBase then
            hue = (hue + 0.01) % 1
            local plot = GameRefs.Plots and GameRefs.Plots:FindFirstChild(LocalPlayer.Name)
            if plot then
                local base = plot:FindFirstChild("Base")
                if base and base:IsA("BasePart") then base.Color = Color3.fromHSV(hue, 1, 1) end
            end
        end
    end
end)

-- ====================== XRAY BASE ======================
task.spawn(function()
    while true do
        task.wait(1)
        if Config.XrayBase then
            local plot = GameRefs.Plots and GameRefs.Plots:FindFirstChild(LocalPlayer.Name)
            if plot then
                for _, part in pairs(plot:GetDescendants()) do
                    if part:IsA("BasePart") and part.Transparency < 0.5 then
                        part.Transparency = 0.7
                    end
                end
            end
        end
    end
end)

-- ====================== NOTIFICATION FINALE ======================
print("[V11] === ALL SYSTEMS LOADED ===")
Notify("Internal System v11", "Loaded Successfully! Click ⚡ to open", 5)
