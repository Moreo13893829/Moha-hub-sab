-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 11.0 MASSIVE (Ultimate Edition)
-- Jeu: Steal A Brainrot
-- ==============================================================================

-- ====================== SERVICES & MOBILE COMPATIBILITY ======================
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
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer
local _Camera = Workspace.CurrentCamera

-- MOBILE-ROBUST GUI PARENT (gethui fallback securise)
local HubParent = nil
local function GetSafeParent()
    if gethui then
        local success, result = pcall(function()
            local hui = gethui()
            if typeof(hui) == "Instance" then
                return hui
            end
            return nil
        end)
        if success and result then
            warn("[GUI] Using gethui() parent")
            return result
        end
    end
    
    local success, result = pcall(function()
        local testGui = Instance.new("ScreenGui")
        testGui.Name = "Test_" .. tostring(tick())
        testGui.Parent = CoreGui
        local valid = testGui.Parent ~= nil
        testGui:Destroy()
        return valid
    end)
    
    if success and result then
        warn("[GUI] Using CoreGui parent")
        return CoreGui
    end
    
    warn("[GUI] Fallback to PlayerGui (Mobile Compatibility Mode)")
    return LocalPlayer:WaitForChild("PlayerGui")
end

HubParent = GetSafeParent()

-- ====================== DEBUG & ERROR VISIBILITY ======================
local DEBUG_MODE = true

local function SafeCall(context, func, ...)
    local args = {...}
    local success, result = pcall(function()
        return func(unpack(args))
    end)
    
    if not success then
        warn("╔════════════════════════════════════════════════════════════╗")
        warn("║  [ERROR] " .. tostring(context))
        warn("╠════════════════════════════════════════════════════════════╣")
        warn("║  " .. tostring(result):sub(1, 100))
        warn("╚════════════════════════════════════════════════════════════╝")
        warn(debug.traceback())
        return nil
    end
    
    return result
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

local function GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
    local char = GetCharacter()
    return char:WaitForChild("Humanoid")
end

local function GetRootPart()
    local char = GetCharacter()
    return char:WaitForChild("HumanoidRootPart")
end

-- ====================== CONFIGURATION & DATABASE ======================
local InternalSystem = {
    Heros = {}, 
    ListeNomsHeros = {},
    ESPObjects = {},
    Connections = {},
    Parametres = {
        StealHighestGen = true, StealHighestValue = false, StealNearest = false,
        StealWalking = false, FloorSteal = false, InvisibleDuringSteal = false,
        PredictiveSteal = false, StealSpeedBoost = false, AutoUnlockBaseDoor = false,
        DisableStealAnimation = false,
        
        StableTP = false, BodySwapTP = false, TPHighestGen = false, TPHighestValue = false,
        TPAutoStart = false, ContinuousAutoTP = false, AutoCloneTP = false, 
        GotoBrainrotTP = false, AutoReturnBrainrot = false, InfiniteJump = false, 
        SpeedBoostMode = "Off", AntiRagdollV1 = false, AntiRagdollV2 = false,
        
        BrainrotESP = false, PlayerESP = false, TimerESP = false, RainbowBase = false,
        TargetBeam = false, XrayBase = false, ShowProgressBar = true,
        
        GUIScale = 1, NotificationsEnabled = true, LockGUIPos = false,
        BrainrotTimerGUI = false, AutoHideGUI = false, FavoritePriority = false,
        InstantCloner = false, MinGenConfig = 0, SearchQuery = "",
        FiltersEnabled = false, ItemsPanel = false,
        
        AutoDestroyTurret = false, LaserAimbotMode = "Off", PaintballAimbotMode = "Off",
        AimbotItemsGUI = false, EventGodMode = false, EventAutoSteal = false,
        EventAutoFarm = false, AutoFarmMinGen = 100, AutoKickAfterSteal = false,
        
        AntiCheatBypass = true, LoadingScreenBypass = true, TryhardMode = false,
        TuffOptimizer = false, AntiLag = false, AntiBeeDisco = false, DisableServerFull = false,

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
    local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
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
    for _, g in pairs(HubParent:GetChildren()) do
        if g.Name == "InternalMassiveV11" then g:Destroy() end
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "InternalMassiveV11"
    Gui.ResetOnSpawn = false
    Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    Gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
    
    local function SetParentWithRetry(instance, parent, maxRetries)
        maxRetries = maxRetries or 5
        for i = 1, maxRetries do
            local success = pcall(function()
                instance.Parent = parent
            end)
            if success and instance.Parent == parent then
                return true
            end
            warn("[GUI] Parenting attempt " .. i .. " failed, retrying...")
            task.wait(0.1 * i)
        end
        return false
    end
    
    if not SetParentWithRetry(Gui, HubParent, 5) then
        warn("[GUI] CRITICAL: Failed to parent GUI after 5 attempts")
        return nil
    end

    local Toggle = Instance.new("TextButton")
    Toggle.Name = "MiniGUI"
    Toggle.Size = UDim2.new(0, 60, 0, 60)
    Toggle.Position = UDim2.new(0, 20, 0.5, -30)
    Toggle.BackgroundColor3 = COLORS.bgAccent
    Toggle.Text = "⚡"
    Toggle.TextColor3 = COLORS.accent
    Toggle.TextSize = 28
    Toggle.Font = Enum.Font.GothamBlack
    Toggle.AutoButtonColor = true
    Toggle.Parent = Gui
    
    local corner = Instance.new("UICorner", Toggle)
    corner.CornerRadius = UDim.new(1, 0)
    
    local tStroke = Instance.new("UIStroke", Toggle)
    tStroke.Color = COLORS.accent
    tStroke.Thickness = 3
    tStroke.Transparency = 0.3

    local Main = Instance.new("CanvasGroup")
    Main.Name = "MainFrame"
    local screenSize = _Camera.ViewportSize
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    local guiWidth = isMobile and math.min(450, screenSize.X - 40) or 500
    local guiHeight = isMobile and math.min(500, screenSize.Y - 100) or 560
    
    Main.Size = UDim2.new(0, guiWidth, 0, guiHeight)
    Main.Position = UDim2.new(0.5, -guiWidth/2, 0.5, -guiHeight/2)
    Main.BackgroundColor3 = COLORS.bg
    Main.GroupTransparency = 1
    Main.Visible = false
    Main.Parent = Gui
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
    local mStroke = Instance.new("UIStroke", Main)
    mStroke.Color = COLORS.bgAccent
    mStroke.Thickness = 2

    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 80)
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
            for _, b in pairs(TabContainer:GetChildren()) do 
                if b:IsA("TextButton") then b.TextColor3 = COLORS.textDim end 
            end
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
            if callback then 
                local success, err = pcall(callback)
                if not success then
                    warn("[BUTTON ERROR] " .. text .. ": " .. tostring(err))
                end
            end 
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

    -- STEAL TAB
    AddToggle(pSteal, "⚡ Auto-Grab Brainrot", "AutoGrab_Actif")
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
    AddSlider(pSteal, "⏱️ Grab Delay", 1, 10, "GrabDelay")

    -- TELEPORT TAB
    AddButton(pTP, "🛰️ Stable TP System", function() 
        warn("[TP] Stable TP activated")
    end)
    AddToggle(pTP, "🔄 Body Swap TP", "BodySwapTP")
    AddToggle(pTP, "TP Highest Gen", "TPHighestGen")
    AddToggle(pTP, "TP Highest Value", "TPHighestValue")
    AddToggle(pTP, "Auto-TP on Start", "TPAutoStart")
    AddToggle(pTP, "Continuous Auto TP", "ContinuousAutoTP")
    AddToggle(pTP, "Auto Clone After TP", "AutoCloneTP")
    AddToggle(pTP, "Goto Brainrot After TP", "GotoBrainrotTP")
    AddToggle(pTP, "Return to Brainrot", "AutoReturnBrainrot")
    AddToggle(pTP, "Infinite Jump", "InfiniteJump")
    AddButton(pTP, "💨 Speed Boost (Mode Cycle)", function() 
        warn("[TP] Speed cycle activated")
    end)
    AddToggle(pTP, "🛑 Anti-Ragdoll V1", "AntiRagdollV1")
    AddToggle(pTP, "🛡️ Anti-Ragdoll V2", "AntiRagdollV2")
    AddButton(pTP, "💥 Self Ragdoll", function() 
        warn("[TP] Self ragdoll activated")
    end)
    AddButton(pTP, "👥 Spawn Clone", function() 
        warn("[TP] Spawn clone activated")
    end)
    AddButton(pTP, "🔄 Rejoin Server", function() 
        TeleportService:Teleport(game.PlaceId, LocalPlayer) 
    end)

    -- VISUALS TAB
    AddToggle(pVisuals, "🧠 Brainrot ESP", "BrainrotESP", function(state)
        if state then
            warn("[ESP] Brainrot ESP enabled")
        else
            warn("[ESP] Brainrot ESP disabled")
        end
    end)
    AddToggle(pVisuals, "👤 Player ESP", "PlayerESP")
    AddToggle(pVisuals, "⏰ Timer ESP (Bases)", "TimerESP")
    AddToggle(pVisuals, "🌈 Rainbow Base", "RainbowBase")
    AddToggle(pVisuals, "🔦 Target Brainrot Beam", "TargetBeam")
    AddToggle(pVisuals, "🩻 Xray Base", "XrayBase")
    AddToggle(pVisuals, "📊 Steal Progress Bar", "ShowProgressBar")

    -- AUTOMATION TAB
    AddSlider(pAuto, "📐 GUI Scale", 0.5, 2, "GUIScale", function(v) 
        if Main:FindFirstChild("UIScale") then
            Main.UIScale.Scale = v 
        end
    end)
    local scaleVal = Instance.new("UIScale", Main)
    scaleVal.Scale = InternalSystem.Parametres.GUIScale
    AddToggle(pAuto, "🔔 Notifications & Alerts", "NotificationsEnabled")
    AddToggle(pAuto, "🔒 Lock GUI Position", "LockGUIPos")
    AddButton(pAuto, "🔗 Join by Job ID", function() 
        warn("[AUTO] Job ID join activated")
    end)
    AddToggle(pAuto, "⏳ Brainrot Timer GUI", "BrainrotTimerGUI")
    AddButton(pAuto, "🔓 Unlock/Lock Base Buttons", function() 
        warn("[AUTO] Base buttons toggled")
    end)
    AddToggle(pAuto, "🙈 Auto-Hide GUI", "AutoHideGUI")
    AddButton(pAuto, "⌨️ Keybind Manager (8 Binds)", function() 
        warn("[AUTO] Keybind manager opened")
    end)
    AddSlider(pAuto, "📉 Min Gen (TP) Config", 0, 10000, "MinGenConfig")
    AddToggle(pAuto, "🧬 Mutation & Trait Filters", "FiltersEnabled")
    AddToggle(pAuto, "⭐ Favorites Priority", "FavoritePriority")
    AddToggle(pAuto, "🛠️ Instant Cloner", "InstantCloner")
    AddTextBox(pAuto, "🔍 Search Brainrot...", "SearchQuery")
    AddButton(pAuto, "📡 Plot/Base Scanner", function() 
        warn("[AUTO] Plot scanner activated")
    end)
    AddToggle(pAuto, "📦 Player Items Panel", "ItemsPanel")
    AddButton(pAuto, "🛑 Kick Self", function() 
        LocalPlayer:Kick("User Kick Request") 
    end)

    -- COMBAT TAB
    AddToggle(pCombat, "🔫 Auto-Destroy Turret", "AutoDestroyTurret")
    AddButton(pCombat, "🔴 Laser Aimbot (Cycle)", function() 
        warn("[COMBAT] Laser aimbot cycle")
    end)
    AddButton(pCombat, "🎨 Paintball Aimbot (Cycle)", function() 
        warn("[COMBAT] Paintball aimbot cycle")
    end)
    AddToggle(pCombat, "🎯 Aimbot Items GUI", "AimbotItemsGUI")
    AddToggle(pCombat, "🌊 Event God Mode (Tsunami)", "EventGodMode")
    AddToggle(pCombat, "🏆 Event Auto-Steal & ESP", "EventAutoSteal")
    AddToggle(pCombat, "🌾 Event Auto-Farm", "EventAutoFarm")
    AddSlider(pCombat, "🚜 Auto-Farm Min Gen", 0, 1000, "AutoFarmMinGen")
    AddToggle(pCombat, "👢 Auto-Kick After Steal", "AutoKickAfterSteal")

    -- SECURITY TAB
    AddToggle(pSecurity, "🛡️ Anti-Cheat Bypass", "AntiCheatBypass")
    AddToggle(pSecurity, "⏩ Loading Screen Bypass", "LoadingScreenBypass")
    AddToggle(pSecurity, "🔥 Tryhard Mode (No Effects)", "TryhardMode")
    AddToggle(pSecurity, "🔋 Tuff Optimizer", "TuffOptimizer")
    AddToggle(pSecurity, "🚀 Anti-Lag", "AntiLag")
    AddToggle(pSecurity, "🐝 Anti-Bee & Disco", "AntiBeeDisco")
    AddToggle(pSecurity, "🚫 Disable Server Full Error", "DisableServerFull")

    MakeDraggable(Main, Header)

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

    local open = false
    Toggle.MouseButton1Click:Connect(function()
        open = not open
        Main.Visible = true
        TweenService:Create(Main, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {GroupTransparency = open and 0 or 1}):Play()
        TweenService:Create(Toggle, TweenInfo.new(0.5), {Rotation = open and 90 or 0, BackgroundColor3 = open and COLORS.danger or COLORS.bgAccent}):Play()
        if not open then 
            task.delay(0.5, function() 
                if not open then 
                    Main.Visible = false 
                end 
            end) 
        end
    end)
    
    CloseBtn.MouseButton1Click:Connect(function() 
        open = false 
        TweenService:Create(Main, TweenInfo.new(0.5), {GroupTransparency = 1}):Play() 
        task.delay(0.5, function() 
            Main.Visible = false 
        end) 
    end)

    bSteal.TextColor3 = COLORS.accent
    pSteal.Visible = true

    return {Status = sLabel, Progress = pBar, Main = Main, Toggle = Toggle}
end

local HUD = CreateUI()
if not HUD then
    warn("[CRITICAL] GUI Creation Failed - Script cannot continue")
    return
end

-- ====================== GAME FOLDERS REFERENCES ======================
local GameFolders = {
    Plots = Workspace:WaitForChild("Plots"),
    RemoteSteal = nil,
    RemoteTeleport = nil
}

-- Trouver les remotes
local function FindRemotes()
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    if packages then
        local net = packages:FindFirstChild("Net")
        if net then
            GameFolders.RemoteSteal = net:FindFirstChild("RE/StealService/DeliverySteal") or net:FindFirstChild("DeliverySteal")
            GameFolders.RemoteTeleport = net:FindFirstChild("RE/TeleportService/Teleport") or net:FindFirstChild("Teleport")
        end
    end
    
    -- Chercher dans d'autres endroits
    if not GameFolders.RemoteSteal then
        GameFolders.RemoteSteal = ReplicatedStorage:FindFirstChild("DeliverySteal", true)
    end
    if not GameFolders.RemoteTeleport then
        GameFolders.RemoteTeleport = ReplicatedStorage:FindFirstChild("Teleport", true)
    end
    
    warn("[REMOTES] Steal: " .. tostring(GameFolders.RemoteSteal) .. " | Teleport: " .. tostring(GameFolders.RemoteTeleport))
end

FindRemotes()

-- ====================== AUTO-STEAL SYSTEM V11 ======================
local StealSystem = {
    Active = false,
    CurrentTarget = nil,
    StealConnection = nil,
    BrainrotCache = {},
    LastStealAttempt = 0,
    StealCooldown = 0.5,
    IsCarrying = false
}

local function GetStealPrompt(brainrotModel)
    if not brainrotModel then return nil end
    
    local base = brainrotModel:FindFirstChild("Base")
    if not base then return nil end
    
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    
    local attachment = spawn:FindFirstChild("PromptAttachment")
    if not attachment then return nil end
    
    return attachment:FindFirstChildWhichIsA("ProximityPrompt")
end

local function IsStealable(brainrotModel)
    if not brainrotModel or not brainrotModel.Parent then return false end
    
    local rootPart = brainrotModel:FindFirstChild("RootPart")
    if not rootPart then return false end
    
    for _, weld in pairs(rootPart:GetChildren()) do
        if weld:IsA("WeldConstraint") then
            if weld.Part0 and weld.Part0:IsDescendantOf(Workspace.Plots) then
                if weld.Part0 ~= LocalPlayer.Character and weld.Part0 ~= LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    return false
                end
            end
        end
    end
    
    local prompt = GetStealPrompt(brainrotModel)
    if not prompt then return false end
    
    return true
end

local function GetBrainrotValue(brainrotModel)
    if not brainrotModel then return 0, 0 end
    
    local config = brainrotModel:FindFirstChild("Configuration")
    if config then
        local gen = config:FindFirstChild("Gen")
        local value = config:FindFirstChild("Value") or config:FindFirstChild("Price")
        
        local genNum = gen and (typeof(gen) == "NumberValue" and gen.Value or tonumber(gen.Value)) or 0
        local valNum = value and (typeof(value) == "NumberValue" and value.Value or ConvertirEnNombre(value.Value)) or 0
        
        return genNum, valNum
    end
    
    local name = brainrotModel.Name
    if InternalSystem.Heros[name] then
        return InternalSystem.Heros[name].Gen or 0, InternalSystem.Heros[name].ValeurNum or 0
    end
    
    return 0, 0
end

local function ScanAllBrainrots()
    local brainrots = {}
    
    for _, plot in pairs(GameFolders.Plots:GetChildren()) do
        if plot:IsA("Model") or plot:IsA("Folder") then
            local animalPodiums = plot:FindFirstChild("AnimalPodiums")
            if animalPodiums then
                for _, podium in pairs(animalPodiums:GetChildren()) do
                    if podium:IsA("Model") and podium.Name ~= "UI" then
                        local gen, value = GetBrainrotValue(podium)
                        table.insert(brainrots, {
                            Model = podium,
                            Gen = gen,
                            Value = value,
                            Position = podium:GetPivot().Position,
                            Plot = plot
                        })
                    end
                end
            end
        end
    end
    
    return brainrots
end

local function SelectTarget(brainrots)
    if #brainrots == 0 then return nil end
    
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    local playerPos = rootPart.Position
    
    local bestTarget = nil
    local bestScore = -math.huge
    
    for _, data in pairs(brainrots) do
        if not IsStealable(data.Model) then continue end
        
        local score = 0
        local distance = (data.Position - playerPos).Magnitude
        
        if InternalSystem.Parametres.StealHighestGen then
            score = data.Gen * 1000000 - distance
        elseif InternalSystem.Parametres.StealHighestValue then
            score = data.Value - distance
        elseif InternalSystem.Parametres.StealNearest then
            score = -distance
        else
            score = data.Gen * 1000 - distance
        end
        
        if score > bestScore then
            bestScore = score
            bestTarget = data
        end
    end
    
    return bestTarget
end

local function ExecuteSteal(targetData)
    if not targetData or not targetData.Model then 
        warn("[STEAL] No target provided")
        return false 
    end
    
    local currentTime = tick()
    if currentTime - StealSystem.LastStealAttempt < StealSystem.StealCooldown then
        return false
    end
    StealSystem.LastStealAttempt = currentTime
    
    warn("[STEAL] Attempting to steal: " .. targetData.Model.Name .. " (Gen: " .. targetData.Gen .. ")")
    
    local prompt = GetStealPrompt(targetData.Model)
    if not prompt then
        warn("[STEAL] No ProximityPrompt found on " .. targetData.Model.Name)
        return false
    end
    
    if fireproximityprompt then
        fireproximityprompt(prompt, 0)
        warn("[STEAL] Fired ProximityPrompt instantly")
    else
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(0.05)
        prompt:InputHoldEnd()
        warn("[STEAL] Simulated prompt interaction")
    end
    
    local startTime = tick()
    local attached = false
    
    repeat
        task.wait(0.1)
        local rootPart = targetData.Model:FindFirstChild("RootPart")
        if rootPart then
            for _, weld in pairs(rootPart:GetChildren()) do
                if weld:IsA("WeldConstraint") then
                    local char = LocalPlayer.Character
                    if char and weld.Part0 == char:FindFirstChild("HumanoidRootPart") then
                        attached = true
                        break
                    end
                end
            end
        end
    until attached or (tick() - startTime > 2)
    
    if attached then
        warn("[STEAL] Brainrot attached! Firing DeliverySteal...")
        if GameFolders.RemoteSteal then
            GameFolders.RemoteSteal:FireServer()
        end
        
        if HUD and HUD.Status then
            HUD.Status.Text = "STATUS: STOLEN " .. string.upper(targetData.Model.Name) .. "!"
            HUD.Status.TextColor3 = COLORS.success
        end
        
        StealSystem.IsCarrying = true
        return true
    else
        warn("[STEAL] Brainrot did not attach in time")
        return false
    end
end

local function CheckIfCarrying()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj:FindFirstChild("RootPart") then
            local root = obj.RootPart
            for _, weld in pairs(root:GetChildren()) do
                if weld:IsA("WeldConstraint") and weld.Part0 == hrp then
                    return true
                end
            end
        end
    end
    
    return false
end

local function StealLoop()
    if not InternalSystem.Parametres.AutoGrab_Actif then return end
    
    if CheckIfCarrying() then
        StealSystem.IsCarrying = true
        if HUD and HUD.Status then
            HUD.Status.Text = "STATUS: CARRYING BRAINROT - RETURN TO BASE!"
            HUD.Status.TextColor3 = COLORS.warning
        end
        return
    else
        StealSystem.IsCarrying = false
    end
    
    local brainrots = ScanAllBrainrots()
    local target = SelectTarget(brainrots)
    
    if target then
        StealSystem.CurrentTarget = target
        ExecuteSteal(target)
    else
        if HUD and HUD.Status then
            HUD.Status.Text = "STATUS: SCANNING... NO TARGETS"
        end
    end
end

task.spawn(function()
    while true do
        task.wait(InternalSystem.Parametres.GrabDelay or 1)
        if InternalSystem.Parametres.AutoGrab_Actif then
            local success, err = pcall(StealLoop)
            if not success then
                warn("[STEAL LOOP ERROR] " .. tostring(err))
            end
        end
    end
end)

for _, plot in pairs(GameFolders.Plots:GetChildren()) do
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if podiums then
        podiums.ChildAdded:Connect(function(child)
            if InternalSystem.Parametres.AutoGrab_Actif and child:IsA("Model") then
                warn("[STEAL] New brainrot detected: " .. child.Name)
                task.wait(0.3)
                local success, err = pcall(StealLoop)
                if not success then
                    warn("[STEAL INSTANT ERROR] " .. tostring(err))
                end
            end
        end)
    end
end

-- ====================== TELEPORT SYSTEM ======================
local TeleportSystem = {
    LastTeleport = 0,
    TeleportCooldown = 2
}

local function FindBestBrainrotForTP()
    local brainrots = ScanAllBrainrots()
    local bestTarget = nil
    local bestValue = -1
    
    for _, data in pairs(brainrots) do
        if not IsStealable(data.Model) then continue end
        
        local value = 0
        if InternalSystem.Parametres.TPHighestGen then
            value = data.Gen
        elseif InternalSystem.Parametres.TPHighestValue then
            value = data.Value
        else
            value = data.Gen
        end
        
        if value > InternalSystem.Parametres.MinGenConfig and value > bestValue then
            bestValue = value
            bestTarget = data
        end
    end
    
    return bestTarget
end

local function TeleportToBrainrot(targetData)
    if not targetData then
        warn("[TP] No target for teleport")
        return false
    end
    
    local currentTime = tick()
    if currentTime - TeleportSystem.LastTeleport < TeleportSystem.TeleportCooldown then
        warn("[TP] Teleport on cooldown")
        return false
    end
    TeleportSystem.LastTeleport = currentTime
    
    local character = LocalPlayer.Character
    if not character then
        warn("[TP] No character")
        return false
    end
    
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        warn("[TP] No HumanoidRootPart")
        return false
    end
    
    warn("[TP] Teleporting to: " .. targetData.Model.Name)
    
    local targetPos = targetData.Position + Vector3.new(0, 5, 0)
    
    if InternalSystem.Parametres.StableTP then
        hrp.CFrame = CFrame.new(targetPos)
        task.wait(0.1)
        hrp.Velocity = Vector3.new(0, 0, 0)
    else
        hrp.CFrame = CFrame.new(targetPos)
    end
    
    if HUD and HUD.Status then
        HUD.Status.Text = "STATUS: TELEPORTED TO " .. string.upper(targetData.Model.Name)
        HUD.Status.TextColor3 = COLORS.accent2
    end
    
    return true
end

local function ContinuousTPLogic()
    if not InternalSystem.Parametres.ContinuousAutoTP then return end
    
    local target = FindBestBrainrotForTP()
    if target then
        TeleportToBrainrot(target)
    end
end

task.spawn(function()
    while true do
        task.wait(3)
        if InternalSystem.Parametres.ContinuousAutoTP then
            local success, err = pcall(ContinuousTPLogic)
            if not success then
                warn("[CONTINUOUS TP ERROR] " .. tostring(err))
            end
        end
    end
end)

-- ====================== ESP SYSTEM ======================
local ESPSystem = {
    Objects = {},
    Beams = {}
}

local function CreateESPForBrainrot(brainrotModel)
    if not brainrotModel or not brainrotModel.Parent then return nil end
    
    local espFolder = Instance.new("Folder")
    espFolder.Name = "ESP_" .. brainrotModel.Name
    
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 100, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = brainrotModel.Name
    label.TextColor3 = COLORS.accent
    label.Font = Enum.Font.GothamBold
    label.TextSize = 14
    label.Parent = billboard
    
    billboard.Parent = espFolder
    
    local highlight = Instance.new("Highlight")
    highlight.FillColor = COLORS.accent
    highlight.OutlineColor = COLORS.accent2
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0
    highlight.Parent = espFolder
    
    espFolder.Parent = brainrotModel
    
    return espFolder
end

local function UpdateESP()
    if not InternalSystem.Parametres.BrainrotESP then
        for _, obj in pairs(ESPSystem.Objects) do
            if obj and obj.Parent then
                obj:Destroy()
            end
        end
        ESPSystem.Objects = {}
        return
    end
    
    local brainrots = ScanAllBrainrots()
    local currentModels = {}
    
    for _, data in pairs(brainrots) do
        if IsStealable(data.Model) then
            currentModels[data.Model] = true
            if not data.Model:FindFirstChild("ESP_" .. data.Model.Name) then
                local esp = CreateESPForBrainrot(data.Model)
                if esp then
                    table.insert(ESPSystem.Objects, esp)
                end
            end
        end
    end
    
    -- Nettoyer les ESP orphelins
    for i = #ESPSystem.Objects, 1, -1 do
        local obj = ESPSystem.Objects[i]
        if not obj or not obj.Parent or not currentModels[obj.Parent] then
            if obj and obj.Parent then
                obj:Destroy()
            end
            table.remove(ESPSystem.Objects, i)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(1)
        local success, err = pcall(UpdateESP)
        if not success then
            warn("[ESP UPDATE ERROR] " .. tostring(err))
        end
    end
end)

-- ====================== PLAYER ESP ======================
local function UpdatePlayerESP()
    if not InternalSystem.Parametres.PlayerESP then return end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            if not char:FindFirstChild("PlayerESP") then
                local esp = Instance.new("Highlight")
                esp.Name = "PlayerESP"
                esp.FillColor = COLORS.danger
                esp.OutlineColor = COLORS.warning
                esp.FillTransparency = 0.9
                esp.Parent = char
            end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(2)
        if InternalSystem.Parametres.PlayerESP then
            local success, err = pcall(UpdatePlayerESP)
            if not success then
                warn("[PLAYER ESP ERROR] " .. tostring(err))
            end
        end
    end
end)

-- ====================== INFINITE JUMP ======================
UserInputService.JumpRequest:Connect(function()
    if InternalSystem.Parametres.InfiniteJump then
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    end
end)

-- ====================== ANTI-RAGDOLL ======================
task.spawn(function()
    while true do
        task.wait(0.5)
        if InternalSystem.Parametres.AntiRagdollV1 or InternalSystem.Parametres.AntiRagdollV2 then
            local character = LocalPlayer.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        if InternalSystem.Parametres.AntiRagdollV1 then
                            part.CanCollide = false
                        end
                        if InternalSystem.Parametres.AntiRagdollV2 then
                            part.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                            part.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                        end
                    end
                end
            end
        end
    end
end)

-- ====================== SPEED BOOST ======================
task.spawn(function()
    while true do
        task.wait(0.1)
        if InternalSystem.Parametres.SpeedBoostMode ~= "Off" then
            local character = LocalPlayer.Character
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    local speed = 16
                    if InternalSystem.Parametres.SpeedBoostMode == "Low" then
                        speed = 25
                    elseif InternalSystem.Parametres.SpeedBoostMode == "Medium" then
                        speed = 40
                    elseif InternalSystem.Parametres.SpeedBoostMode == "High" then
                        speed = 70
                    elseif InternalSystem.Parametres.SpeedBoostMode == "Extreme" then
                        speed = 100
                    end
                    humanoid.WalkSpeed = speed
                end
            end
        end
    end
end)

-- ====================== RAINBOW BASE ======================
task.spawn(function()
    local hue = 0
    while true do
        task.wait(0.05)
        if InternalSystem.Parametres.RainbowBase then
            hue = (hue + 0.01) % 1
            local plot = GameFolders.Plots:FindFirstChild(LocalPlayer.Name)
            if plot then
                local base = plot:FindFirstChild("Base")
                if base and base:IsA("BasePart") then
                    base.Color = Color3.fromHSV(hue, 1, 1)
                end
            end
        end
    end
end)

-- ====================== AUTO-TP ON START ======================
if InternalSystem.Parametres.TPAutoStart then
    task.delay(3, function()
        local target = FindBestBrainrotForTP()
        if target then
            TeleportToBrainrot(target)
        end
    end)
end

-- ====================== LOADING SCREEN BYPASS ======================
if InternalSystem.Parametres.LoadingScreenBypass then
    local gui = LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        for _, g in pairs(gui:GetChildren()) do
            if g.Name:lower():find("loading") or g.Name:lower():find("intro") then
                g:Destroy()
                warn("[BYPASS] Destroyed loading screen: " .. g.Name)
            end
        end
    end
end

-- ====================== ANTI-LAG ======================
if InternalSystem.Parametres.AntiLag then
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles") then
            obj:Destroy()
        end
        if obj:IsA("BasePart") and obj.Name:lower():find("decoration") then
            obj.Transparency = 1
        end
    end
    warn("[ANTI-LAG] Cleaned up effects")
end

-- ====================== NOTIFICATION SYSTEM ======================
local function Notify(title, message, duration)
    duration = duration or 3
    if not InternalSystem.Parametres.NotificationsEnabled then return end
    
    StarterGui:SetCore("SendNotification", {
        Title = title,
        Text = message,
        Duration = duration
    })
end

-- ====================== CHARACTER SETUP ======================
LocalPlayer.CharacterAdded:Connect(function(char)
    warn("[CHARACTER] New character spawned")
    task.wait(1)
    
    if InternalSystem.Parametres.InfiniteJump then
        -- Reconnect si necessaire
    end
end)

-- ====================== FINAL INITIALIZATION ======================
warn("╔════════════════════════════════════════════════════════════╗")
warn("║     INTERNAL SYSTEM v11.0 MASSIVE - LOADED                 ║")
warn("║     Features: Steal | TP | ESP | Combat | Security         ║")
warn("╚════════════════════════════════════════════════════════════╝")

Notify("Internal System v11", "Loaded Successfully!", 5)

print("Internal System v11.0 MASSIVE - Loaded Successfully")
