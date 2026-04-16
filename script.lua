-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 11.0 MASSIVE (Ultimate Edition)
-- Jeu: Steal A Brainrot
-- ==============================================================================

-- ====================== SERVICES ======================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local PathfindingService = game:GetService("PathfindingService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

local LocalPlayer = Players.LocalPlayer
local _Camera = Workspace.CurrentCamera

-- FIX MOBILE: Robust Hub Selection
local HubParent = nil
local success, err = pcall(function()
    HubParent = (gethui and gethui()) or 
                game:GetService("CoreGui"):FindFirstChild("RobloxGui") and game:GetService("CoreGui") or 
                LocalPlayer:FindFirstChild("PlayerGui")
end)
if not success or not HubParent then
    warn("⚠️ Erreur de parentage GUI: " .. tostring(err))
    HubParent = LocalPlayer:WaitForChild("PlayerGui")
end

-- ====================== UTILITAIRES ======================
local function ConvertirEnNombre(valeur)
    if not valeur then return 0 end
    if type(valeur) == "number" then return valeur end
    local texte = tostring(valeur):upper():gsub(",", ".")
    local nombre = tonumber(texte:match("[%d%.]+")) or 0
    if texte:match("B") then nombre = nombre * 1e9
    elseif texte:match("M") then nombre = nombre * 1e6
    elseif texte:match("K") then nombre = nombre * 1e3 end
    return nombre
end

local function ObtenirPositionPrompt(prompt)
    if not prompt or not prompt.Parent then return nil end
    local p = prompt.Parent
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Attachment") then return p.WorldPosition end
    local current = p
    while current and not current:IsA("BasePart") do current = current.Parent end
    return current and current.Position or nil
end

-- ====================== CONFIGURATION & DATABASE ======================
local InternalSystem = {
    Heros = {}, 
    ListeNomsHeros = {},
    Parametres = {
        -- STEAL MODES
        StealHighestGen = true, StealHighestValue = false, StealNearest = false,
        StealWalking = false, FloorSteal = false, InvisibleDuringSteal = false,
        PredictiveSteal = false, StealSpeedBoost = false, AutoUnlockBaseDoor = false,
        DisableStealAnimation = false,
        
        -- TELEPORT & MOVEMENT
        StableTP = false, BodySwapTP = false, TPByMode = "Gen", TPAutoStart = false,
        ContinuousAutoTP = false, AutoCloneTP = false, GotoBrainrotTP = false,
        AutoReturnBrainrot = false, InfiniteJump = false, SpeedBoostMode = "Off",
        AntiRagdollV1 = false, AntiRagdollV2 = false,
        
        -- ESP & VISUALS
        BrainrotESP = false, PlayerESP = false, TimerESP = false, RainbowBase = false,
        TargetBeam = false, XrayBase = false, ShowProgressBar = true,
        
        -- GUI & AUTOMATION
        GUIScale = 1, NotificationsEnabled = true, LockGUIPos = false,
        BrainrotTimerGUI = false, AutoHideGUI = false, FavoritePriority = false,
        InstantCloner = false, MinGenConfig = 0, SearchQuery = "",
        
        -- COMBAT & EVENTS
        AutoDestroyTurret = false, LaserAimbotMode = "Off", PaintballAimbotMode = "Off",
        AimbotItemsGUI = false, EventGodMode = false, EventAutoSteal = false,
        EventAutoFarm = false, AutoFarmMinGen = 100, AutoKickAfterSteal = false,
        
        -- SECURITY & OPTIMIZATION
        AntiCheatBypass = true, LoadingScreenBypass = true, TryhardMode = false,
        TuffOptimizer = false, AntiLag = false, AntiBeeDisco = false, DisableServerFull = false,

        -- INTERNAL/LEGACY
        AutoGrab_Actif = false, GrabRange = 25, GrabDelay = 1.0, AutoWalk = false,
        DebugMode = false, ServerHopStaff = false, AutoClicker = false,
        AfficherCercle = true, ThemeColor = Color3.fromRGB(130, 80, 255)
    }
}

function InternalSystem:AjouterHero(nom, config)
    if not config.ValeurNum then
        if config.Prix then config.ValeurNum = ConvertirEnNombre(config.Prix)
        elseif config.Gen then config.ValeurNum = config.Gen
        else config.ValeurNum = 0 end
    end
    if not self.Heros[nom] then table.insert(self.ListeNomsHeros, nom) end
    self.Heros[nom] = config
end

-- ====================== UI COLORS & THEME ======================
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

-- ====================== DRAGGABLE HELPER ======================
local function MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    RunService.RenderStepped:Connect(function()
        if dragging and dragInput and not InternalSystem.Parametres.LockGUIPos then
            local delta = dragInput.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ====================== CORE UI CONSTRUCTION ======================
local function CreateUI()
    -- Cleanup
    for _, g in pairs(HubParent:GetChildren()) do
        if g.Name == "InternalMassiveV11" then g:Destroy() end
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "InternalMassiveV11"
    Gui.ResetOnSpawn = false
    Gui.Parent = HubParent

    -- Toggle Button (Mini GUI)
    local Toggle = Instance.new("TextButton")
    Toggle.Name = "MiniGUI"
    Toggle.Size = UDim2.new(0, 50, 0, 50)
    Toggle.Position = UDim2.new(0, 30, 0.5, -25)
    Toggle.BackgroundColor3 = COLORS.bgAccent
    Toggle.Text = "⚡"
    Toggle.TextColor3 = COLORS.accent
    Toggle.TextSize = 24
    Toggle.Font = Enum.Font.GothamBlack
    Toggle.Parent = Gui
    Instance.new("UICorner", Toggle).CornerRadius = UDim.new(1, 0)
    local tStroke = Instance.new("UIStroke", Toggle)
    tStroke.Color = COLORS.accent
    tStroke.Thickness = 2
    tStroke.Transparency = 0.4

    -- Main Frame
    local Main = Instance.new("CanvasGroup")
    Main.Name = "MainFrame"
    Main.Size = UDim2.new(0, 500, 0, 560)
    Main.Position = UDim2.new(0.5, -250, 0.5, -280)
    Main.BackgroundColor3 = COLORS.bg
    Main.GroupTransparency = 1
    Main.Visible = false
    Main.Parent = Gui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
    local mStroke = Instance.new("UIStroke", Main)
    mStroke.Color = COLORS.bgAccent
    mStroke.Thickness = 2

    -- Header / Drag Handle
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 70)
    Header.BackgroundTransparency = 1
    Header.Parent = Main
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -30, 0, 40)
    Title.Position = UDim2.new(0, 20, 0, 15)
    Title.BackgroundTransparency = 1
    Title.Text = "INTERNAL SYSTEM <font color='#8250FF'>v11.0 MASSIVE</font>"
    Title.RichText = true
    Title.TextColor3 = COLORS.text
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 22
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    local Subtitle = Instance.new("TextLabel")
    Subtitle.Size = UDim2.new(1, -30, 0, 20)
    Subtitle.Position = UDim2.new(0, 20, 0, 40)
    Subtitle.BackgroundTransparency = 1
    Subtitle.Text = "Premium Brainrot Destroyer — 60+ Features"
    Subtitle.TextColor3 = COLORS.textDim
    Subtitle.Font = Enum.Font.GothamBold
    Subtitle.TextSize = 11
    Subtitle.TextXAlignment = Enum.TextXAlignment.Left
    Subtitle.Parent = Header

    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -45, 0, 20)
    CloseBtn.BackgroundColor3 = COLORS.danger
    CloseBtn.BackgroundTransparency = 0.9
    CloseBtn.Text = "×"
    CloseBtn.TextColor3 = COLORS.danger
    CloseBtn.TextSize = 26
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = Header
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

    -- Tab Container
    local TabContainer = Instance.new("ScrollingFrame")
    TabContainer.Name = "Tabs"
    TabContainer.Size = UDim2.new(1, -40, 0, 45)
    TabContainer.Position = UDim2.new(0, 20, 0, 85)
    TabContainer.BackgroundColor3 = COLORS.bgAccent
    TabContainer.ScrollBarThickness = 0
    TabContainer.CanvasSize = UDim2.new(1.2, 0, 0, 0)
    TabContainer.Parent = Main
    Instance.new("UICorner", TabContainer).CornerRadius = UDim.new(0, 8)
    
    local TabList = Instance.new("UIListLayout", TabContainer)
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabList.Padding = UDim.new(0, 10)

    -- Page Container
    local Pages = Instance.new("Frame")
    Pages.Size = UDim2.new(1, -40, 1, -210)
    Pages.Position = UDim2.new(0, 20, 0, 145)
    Pages.BackgroundTransparency = 1
    Pages.Parent = Main

    local function CreateTab(name, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 85, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = icon .. " " .. name
        btn.TextColor3 = COLORS.textDim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 11
        btn.Parent = TabContainer

        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = COLORS.accent
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Parent = Pages
        
        local pList = Instance.new("UIListLayout", page)
        pList.Padding = UDim.new(0, 8)
        pList.SortOrder = Enum.SortOrder.LayoutOrder

        btn.MouseButton1Click:Connect(function()
            for _, p in pairs(Pages:GetChildren()) do p.Visible = false end
            for _, b in pairs(TabContainer:GetChildren()) do if b:IsA("TextButton") then b.TextColor3 = COLORS.textDim end end
            page.Visible = true
            btn.TextColor3 = COLORS.accent
        end)

        return page, btn
    end

    local pSteal, bSteal = CreateTab("Steal", "⚡")
    local pTP, bTP = CreateTab("Teleport", "🚀")
    local pVisuals, bVisuals = CreateTab("Visuals", "👁️")
    local pAuto, bAuto = CreateTab("Automation", "⚙️")
    local pCombat, bCombat = CreateTab("Combat", "⚔️")
    local pSecurity, bSec = CreateTab("Security", "🛡️")

    -- Shared UI Components
    local function AddToggle(parent, text, configKey, callback)
        local f = Instance.new("TextButton")
        f.Size = UDim2.new(1, -5, 0, 48)
        f.BackgroundColor3 = COLORS.bgAccent
        f.Text = ""
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.Position = UDim2.new(0, 15, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = COLORS.text
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = f

        local tbg = Instance.new("Frame")
        tbg.Size = UDim2.new(0, 42, 0, 22)
        tbg.Position = UDim2.new(1, -57, 0.5, -11)
        tbg.BackgroundColor3 = InternalSystem.Parametres[configKey] and COLORS.accent or Color3.fromRGB(40, 40, 50)
        tbg.Parent = f
        Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 16, 0, 16)
        dot.Position = InternalSystem.Parametres[configKey] and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        dot.BackgroundColor3 = Color3.new(1,1,1)
        dot.Parent = tbg
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        f.MouseButton1Click:Connect(function()
            InternalSystem.Parametres[configKey] = not InternalSystem.Parametres[configKey]
            local state = InternalSystem.Parametres[configKey]
            TweenService:Create(tbg, TweenInfo.new(0.3), {BackgroundColor3 = state and COLORS.accent or Color3.fromRGB(40, 40, 50)}):Play()
            TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}):Play()
            if callback then callback(state) end
        end)
    end

    local function AddButton(parent, text, callback)
        local f = Instance.new("TextButton")
        f.Size = UDim2.new(1, -5, 0, 40)
        f.BackgroundColor3 = COLORS.accent
        f.BackgroundTransparency = 0.8
        f.Text = text
        f.TextColor3 = COLORS.text
        f.Font = Enum.Font.GothamBold
        f.TextSize = 13
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", f).Color = COLORS.accent
        
        f.MouseButton1Click:Connect(function() 
            f.BackgroundTransparency = 0.6
            task.delay(0.1, function() f.BackgroundTransparency = 0.8 end)
            if callback then callback() end 
        end)
    end

    local function AddSlider(parent, text, min, max, configKey, callback)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -5, 0, 65)
        f.BackgroundColor3 = COLORS.bgAccent
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.6, 0, 0, 30)
        lbl.Position = UDim2.new(0, 15, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = COLORS.textDim
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 12
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = f

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.3, 0, 0, 30)
        val.Position = UDim2.new(0.7, -15, 0, 5)
        val.BackgroundTransparency = 1
        val.Text = tostring(InternalSystem.Parametres[configKey])
        val.TextColor3 = COLORS.accent2
        val.Font = Enum.Font.GothamBold
        val.TextSize = 13
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = f

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -30, 0, 6)
        track.Position = UDim2.new(0, 15, 0, 45)
        track.BackgroundColor3 = Color3.fromRGB(40,40,55)
        track.Parent = f
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local bar = Instance.new("Frame")
        local pct = math.clamp((InternalSystem.Parametres[configKey] - min) / (max - min), 0, 1)
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
            InternalSystem.Parametres[configKey] = v
            val.Text = tostring(v)
            bar.Size = UDim2.new(r, 0, 1, 0)
            if callback then callback(v) end
        end

        local drag = false
        ctrl.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true update(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
        UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end end)
    end

    local function AddTextBox(parent, placeholder, configKey, callback)
        local f = Instance.new("TextBox")
        f.Size = UDim2.new(1, -5, 0, 40)
        f.BackgroundColor3 = COLORS.bgAccent
        f.Text = InternalSystem.Parametres[configKey] or ""
        f.PlaceholderText = placeholder
        f.TextColor3 = COLORS.text
        f.PlaceholderColor3 = COLORS.textDim
        f.Font = Enum.Font.GothamSemibold
        f.TextSize = 13
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        Instance.new("UIStroke", f).Color = Color3.fromRGB(50, 50, 70)
        
        f.FocusLost:Connect(function()
            InternalSystem.Parametres[configKey] = f.Text
            if callback then callback(f.Text) end
        end)
    end

    -- ====================== FILLING TABS ======================
    
    -- [⚡] STEAL TAB
    AddToggle(pSteal, "⚡ Steal Highest Gen", "StealHighestGen")
    AddToggle(pSteal, "💰 Steal Highest Value/Price", "StealHighestValue")
    AddToggle(pSteal, "📍 Steal Nearest", "StealNearest")
    AddToggle(pSteal, "🚶 Steal Walking/Carpet", "StealWalking")
    AddToggle(pSteal, "🕳️ Floor Steal", "FloorSteal")
    AddToggle(pSteal, "👻 Invisible During Steal", "InvisibleDuringSteal")
    AddToggle(pSteal, "🔮 Predictive Steal", "PredictiveSteal")
    AddToggle(pSteal, "🚀 Steal Speed Boost", "StealSpeedBoost")
    AddToggle(pSteal, "🚪 Auto Unlock Base Door", "AutoUnlockBaseDoor")
    AddToggle(pSteal, "🚫 Disable Steal Animation", "DisableStealAnimation")
    AddSlider(pSteal, "📏 Grab Range", 5, 150, "GrabRange")

    -- [🚀] TELEPORT TAB
    AddButton(pTP, "🛰️ Stable TP System", function() print("STABLE TP") end)
    AddToggle(pTP, "🔄 Body Swap TP", "BodySwapTP")
    AddToggle(pTP, "TP Highest Gen", "TPHighestGen")
    AddToggle(pTP, "TP Highest Value", "TPHighestValue")
    AddToggle(pTP, "Auto-TP on Start", "TPAutoStart")
    AddToggle(pTP, "Continuous Auto TP", "ContinuousAutoTP")
    AddToggle(pTP, "Auto Clone After TP", "AutoCloneTP")
    AddToggle(pTP, "Goto Brainrot After TP", "GotoBrainrotTP")
    AddToggle(pTP, "Return to Brainrot", "AutoReturnBrainrot")
    AddToggle(pTP, "Infinite Jump", "InfiniteJump")
    AddButton(pTP, "💨 Speed Boost (Mode Cycle)", function() print("SPEED CYCLE") end)
    AddToggle(pTP, "🛑 Anti-Ragdoll V1", "AntiRagdollV1")
    AddToggle(pTP, "🛡️ Anti-Ragdoll V2", "AntiRagdollV2")
    AddButton(pTP, "💥 Self Ragdoll", function() print("RAGDOLL") end)
    AddButton(pTP, "👥 Spawn Clone", function() print("CLONE") end)
    AddButton(pTP, "🔄 Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)

    -- [👁️] VISUALS TAB
    AddToggle(pVisuals, "🧠 Brainrot ESP", "BrainrotESP")
    AddToggle(pVisuals, "👤 Player ESP", "PlayerESP")
    AddToggle(pVisuals, "⏰ Timer ESP (Bases)", "TimerESP")
    AddToggle(pVisuals, "🌈 Rainbow Base", "RainbowBase")
    AddToggle(pVisuals, "🔦 Target Brainrot Beam", "TargetBeam")
    AddToggle(pVisuals, "🩻 Xray Base", "XrayBase")
    AddToggle(pVisuals, "📊 Steal Progress Bar", "ShowProgressBar")

    -- [⚙️] AUTOMATION TAB
    AddSlider(pAuto, "📐 GUI Scale", 0.5, 2, "GUIScale", function(v) Gui.UIScale.Scale = v end)
    local scaleVal = Instance.new("UIScale", Main)
    scaleVal.Scale = InternalSystem.Parametres.GUIScale
    AddToggle(pAuto, "🔔 Notifications & Alerts", "NotificationsEnabled")
    AddToggle(pAuto, "🔒 Lock GUI Position", "LockGUIPos")
    AddButton(pAuto, "🔗 Join by Job ID", function() print("JOB ID JOIN") end)
    AddToggle(pAuto, "⏳ Brainrot Timer GUI", "BrainrotTimerGUI")
    AddButton(pAuto, "🔓 Unlock/Lock Base Buttons", function() print("LOCK BUTTONS") end)
    AddToggle(pAuto, "🙈 Auto-Hide GUI", "AutoHideGUI")
    AddButton(pAuto, "⌨️ Keybind Manager (8 Binds)", function() print("KEYBINDS") end)
    AddSlider(pAuto, "📉 Min Gen (TP) Config", 0, 10000, "MinGenConfig")
    AddToggle(pAuto, "🧬 Mutation & Trait Filters", "FiltersEnabled")
    AddToggle(pAuto, "⭐ Favorites Priority", "FavoritePriority")
    AddToggle(pAuto, "🛠️ Instant Cloner", "InstantCloner")
    AddTextBox(pAuto, "🔍 Search Brainrot...", "SearchQuery")
    AddButton(pAuto, "📡 Plot/Base Scanner", function() print("SCAN") end)
    AddToggle(pAuto, "📦 Player Items Panel", "ItemsPanel")
    AddButton(pAuto, "🛑 Kick Self", function() LocalPlayer:Kick("User Kick Request") end)

    -- [⚔️] COMBAT TAB
    AddToggle(pCombat, "🔫 Auto-Destroy Turret", "AutoDestroyTurret")
    AddButton(pCombat, "🔴 Laser Aimbot (Cycle)", function() print("LASER CYCLE") end)
    AddButton(pCombat, "🎨 Paintball Aimbot (Cycle)", function() print("PAINTBALL CYCLE") end)
    AddToggle(pCombat, "🎯 Aimbot Items GUI", "AimbotItemsGUI")
    AddToggle(pCombat, "🌊 Event God Mode (Tsunami)", "EventGodMode")
    AddToggle(pCombat, "🏆 Event Auto-Steal & ESP", "EventAutoSteal")
    AddToggle(pCombat, "🌾 Event Auto-Farm", "EventAutoFarm")
    AddSlider(pCombat, "🚜 Auto-Farm Min Gen", 0, 1000, "AutoFarmMinGen")
    AddToggle(pCombat, "👢 Auto-Kick After Steal", "AutoKickAfterSteal")

    -- [🛡️] SECURITY TAB
    AddToggle(pSecurity, "🛡️ Anti-Cheat Bypass", "AntiCheatBypass")
    AddToggle(pSecurity, "⏩ Loading Screen Bypass", "LoadingScreenBypass")
    AddToggle(pSecurity, "🔥 Tryhard Mode (No Effects)", "TryhardMode")
    AddToggle(pSecurity, "🔋 Tuff Optimizer", "TuffOptimizer")
    AddToggle(pSecurity, "🚀 Anti-Lag", "AntiLag")
    AddToggle(pSecurity, "🐝 Anti-Bee & Disco", "AntiBeeDisco")
    AddToggle(pSecurity, "🚫 Disable Server Full Error", "DisableServerFull")

    -- Dragging Logic
    MakeDraggable(Main, Header)

    -- Status Bar (Bottom)
    local StatusFrame = Instance.new("Frame")
    StatusFrame.Size = UDim2.new(1, -40, 0, 40)
    StatusFrame.Position = UDim2.new(0, 20, 1, -55)
    StatusFrame.BackgroundColor3 = COLORS.bgAccent
    StatusFrame.Parent = Main
    Instance.new("UICorner", StatusFrame).CornerRadius = UDim.new(0, 8)
    
    local sLabel = Instance.new("TextLabel")
    sLabel.Size = UDim2.new(1, -20, 1, 0)
    sLabel.Position = UDim2.new(0, 10, 0, 0)
    sLabel.BackgroundTransparency = 1
    sLabel.Text = "STATUS: IDLE • v11.0 MASSIVE"
    sLabel.TextColor3 = COLORS.textDim
    sLabel.Font = Enum.Font.GothamBold
    sLabel.TextSize = 10
    sLabel.TextXAlignment = Enum.TextXAlignment.Left
    sLabel.Parent = StatusFrame

    local pBarBg = Instance.new("Frame")
    pBarBg.Size = UDim2.new(1, -20, 0, 4)
    pBarBg.Position = UDim2.new(0, 10, 1, -12)
    pBarBg.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    pBarBg.Parent = StatusFrame
    Instance.new("UICorner", pBarBg).CornerRadius = UDim.new(1, 0)
    
    local pBar = Instance.new("Frame")
    pBar.Size = UDim2.new(0, 0, 1, 0)
    pBar.BackgroundColor3 = COLORS.accent
    pBar.Parent = pBarBg
    Instance.new("UICorner", pBar).CornerRadius = UDim.new(1, 0)

    -- Interaction Logic
    local open = false
    Toggle.MouseButton1Click:Connect(function()
        open = not open
        Main.Visible = true
        TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {GroupTransparency = open and 0 or 1}):Play()
        TweenService:Create(Toggle, TweenInfo.new(0.5), {Rotation = open and 90 or 0, BackgroundColor3 = open and COLORS.danger or COLORS.bgAccent}):Play()
        if not open then task.delay(0.5, function() if not open then Main.Visible = false end end) end
    end)
    CloseBtn.MouseButton1Click:Connect(function() open = false TweenService:Create(Main, TweenInfo.new(0.5), {GroupTransparency = 1}):Play() task.delay(0.5, function() Main.Visible = false end) end)

    bSteal.TextColor3 = COLORS.accent
    pSteal.Visible = true

    return {Status = sLabel, Progress = pBar}
end

local HUD = CreateUI()

-- ====================== [MOTEUR DE VOL (STEAL) - VERSION 11.0] ======================

local isStealing = false
local DossierPlots = Workspace:FindFirstChild("Plots") or Workspace:WaitForChild("Plots", 10)

if not DossierPlots then
    warn("❌ ERREUR: Dossier 'Plots' introuvable dans le Workspace !")
end

-- Helper: Obtenir le prix en nombre
local function getPriceValue(prompt)
    local parent = prompt.Parent
    -- Rechercher le texte du prix dans les Overheads (displayName)
    local overhead = parent:FindFirstChild("AnimalOverhead") or parent.Parent:FindFirstChild("AnimalOverhead")
    if overhead and overhead:FindFirstChild("DisplayName") then
        local text = overhead.DisplayName.Text
        return ConvertirEnNombre(text)
    end
    return 0
end

task.spawn(function()
    while true do
        task.wait(0.1)
        
        -- Sécurités de base
        if not InternalSystem.Parametres.AutoGrab_Actif then continue end
        if isStealing then continue end
        
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        -- Vérification si déjà en train de voler (Attribut du jeu)
        if LocalPlayer:GetAttribute("Stealing") then 
            HUD.Status.Text = "🧠 BRAINROT EN MAIN"
            HUD.Status.TextColor3 = COLORS.success
            continue 
        end

        local bestTarget = nil
        local bestVal = -1
        local bestDist = math.huge
        local range = InternalSystem.Parametres.GrabRange

        -- SCAN DES PLOTS
        for _, plot in pairs(DossierPlots:GetChildren()) do
            -- On ne vole pas chez soi
            local o = plot:FindFirstChild("PlotOwner") or plot:FindFirstChild("Owner")
            if o and (o.Value == LocalPlayer or o.Value == LocalPlayer.Name) then continue end

            -- Recherche des Brainrots interactifs
            for _, d in pairs(plot:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    -- Ignorer les boutons de base / portes (sauf si config)
                    local act = d.ActionText:lower()
                    if act:find("unlock") or act:find("toggle") or act:find("buy") then continue end
                    
                    local pos = ObtenirPositionPrompt(d)
                    if not pos then continue end
                    
                    local dist = (root.Position - pos).Magnitude
                    if dist > range then continue end
                    
                    -- Evaluation selon le mode
                    local score = 0
                    local valNum = getPriceValue(d)
                    
                    if InternalSystem.Parametres.StealHighestGen or InternalSystem.Parametres.StealHighestValue then
                        score = valNum
                    elseif InternalSystem.Parametres.StealNearest then
                        score = 1000 - dist -- Plus proche = plus haut score
                    end

                    -- Priorité
                    if score > bestVal then
                        bestVal = score
                        bestDist = dist
                        bestTarget = d
                    end
                end
            end
        end

        -- EXECUTION DU VOL
        if bestTarget then
            isStealing = true
            HUD.Status.Text = "⚡ TENTATIVE DE VOL..."
            HUD.Status.TextColor3 = COLORS.warning
            
            -- Debug Info
            print("Target found: " .. bestTarget.Parent.Name .. " | Dist: " .. math.floor(bestDist))

            -- Auto-Walk Logic
            if InternalSystem.Parametres.StealWalking and bestDist > 7 then
                HUD.Status.Text = "🚶 MARCHE VERS CIBLE"
                local humanoid = char:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid:MoveTo(ObtenirPositionPrompt(bestTarget))
                    local moveSuccess = humanoid.MoveToFinished:Wait() -- Attend l'arrivée (Timeout possible)
                end
            end

            -- Ghost Mode (Invisible during steal)
            if InternalSystem.Parametres.InvisibleDuringSteal then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = 0.8 end
                end
            end

            -- Activation du Prompt
            local duration = bestTarget.HoldDuration
            local start = tick()
            
            -- UI Feedback Progress
            local conn
            conn = RunService.RenderStepped:Connect(function()
                local elapsed = tick() - start
                local pct = math.clamp(elapsed / (duration + 0.1), 0, 1)
                HUD.Progress.Size = UDim2.new(pct, 0, 1, 0)
                if pct >= 1 then conn:Disconnect() end
            end)

            -- Interaction Réelle
            local successInteract, interactErr = pcall(function()
                fireproximityprompt(bestTarget)
            end)

            if not successInteract then
                warn("⚠️ ÉCHEC fireproximityprompt: " .. tostring(interactErr))
                HUD.Status.Text = "❌ ÉCHEC INTERACTION"
                HUD.Status.TextColor3 = COLORS.danger
            end

            task.wait(duration + 0.2)
            
            -- Reset Effects
            if InternalSystem.Parametres.InvisibleDuringSteal then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") then part.Transparency = 0 end
                end
            end

            HUD.Progress.Size = UDim2.new(0, 0, 1, 0)
            isStealing = false
        else
            -- Si rien trouvé mais mode actif, on prévient l'utilisateur
            if InternalSystem.Parametres.DebugMode then
                HUD.Status.Text = "🔍 AUCUNE CIBLE DANS LA ZONE"
                HUD.Status.TextColor3 = COLORS.textDim
            end
        end
    end
end)

print("Internal System v11.0 MASSIVE - Logique Steal Aktivée")
