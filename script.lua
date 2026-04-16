-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 10.0 SUPERIOR (Redux Edition)
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

local LocalPlayer = Players.LocalPlayer
local _Camera = Workspace.CurrentCamera
local HubParent = (gethui and gethui()) or CoreGui

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

local function EstVisible(position, ignorance)
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return false end
    
    local origin = head.Position
    local direction = (position - origin)
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char, ignorance or Workspace}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local result = Workspace:Raycast(origin, direction, params)
    local isPhysicallyVisible = result == nil or (result.Position - position).Magnitude < 2.5

    local _screenPoint, onScreen = _Camera:WorldToViewportPoint(position)
    return isPhysicallyVisible and onScreen
end

-- ====================== CONFIGURATION & DATABASE ======================
local InternalSystem = {
    Heros = {}, 
    ListeNomsHeros = {},
    Parametres = {
        AutoGrab_Actif = false, GrabMode = "Highest", GrabDelay = 1.0,
        GrabRange = 25, AfficherCercle = true, AutoRecall_Actif = false,
        BrainrotESP = false, PlayerESP = false, BaseTimerESP = false,
        GrabBrainrots = true, AutoWalk = false, DebugMode = false,
        ServerHopStaff = false, AutoClicker = false, 
        ThemeColor = Color3.fromRGB(130, 80, 255)
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

-- DATABASE EXPANSION (v10)
InternalSystem:AjouterHero("Strawberry Elephant", {Rarete="OG", Prix="500M", Gen=500000})
InternalSystem:AjouterHero("Skibidi Toilet", {Rarete="OG", Prix="450M", Gen=450000})
InternalSystem:AjouterHero("Meowl", {Rarete="OG", Prix="400M", Gen=400000})
InternalSystem:AjouterHero("Dragon Gingerini", {Rarete="Secret", Prix="200M", Gen=200000})
InternalSystem:AjouterHero("Dragon Cannelloni", {Rarete="Secret", Prix="190M", Gen=190000})
InternalSystem:AjouterHero("Giga Chad", {Rarete="Mythic", Prix="50M", Gen=50000})
InternalSystem:AjouterHero("Glorbo Fruttodrillo", {Rarete="Legendary", Prix="200K", Gen=938})
InternalSystem:AjouterHero("Trulimero Trulicina", {Rarete="Epic", Prix="20K", Gen=188})
InternalSystem:AjouterHero("Perochello Lemonchello", {Rarete="Epic", Prix="27.5K", Gen=160})
InternalSystem:AjouterHero("Cappuccino Assassino", {Rarete="Epic", Prix="10K", Gen=113})

-- ====================== LOGIQUE DE SCANNER ======================
local BrainrotsScannes = {}
local DossierPlots = Workspace:WaitForChild("Plots", 5)

task.spawn(function()
    local Assets = ReplicatedStorage:FindFirstChild("Models") or ReplicatedStorage:FindFirstChild("Assets")
    local Entities = Assets and (Assets:FindFirstChild("Animals") or Assets:FindFirstChild("Brainrots"))
    
    if Entities then
        for _, m in pairs(Entities:GetChildren()) do
            local p = m:FindFirstChild("Price") or m:FindFirstChild("Value")
            local r = m:FindFirstChild("Rarity")
            local vStr = p and tostring(p.Value) or "0"
            local rStr = r and tostring(r.Value) or "Normal"
            local vNum = ConvertirEnNombre(vStr)
            InternalSystem:AjouterHero(m.Name, {Rarete=rStr, Prix=vStr, ValeurNum=vNum})
        end
    end
end)

-- ====================== SÉCURITÉ & ANTI-BAN ======================
local function Log(...)
    if InternalSystem.Parametres.DebugMode then print("[v10]", unpack({...})) end
end

local function HandleStaff(joueur)
    local staffIDs = {165038031, 28350175, 4104118507}
    local isStaff = table.find(staffIDs, joueur.UserId) or (joueur:GetRoleInGroup(33423773) ~= "Guest")
    
    if isStaff then
        warn("⚠️ STAFF ALERT: " .. joueur.Name)
        if InternalSystem.Parametres.ServerHopStaff then
            -- Logic for Server Hop (TeleportService)
            local ts = game:GetService("TeleportService")
            ts:Teleport(game.PlaceId, LocalPlayer)
        else
            InternalSystem.Parametres.AutoGrab_Actif = false
            InternalSystem.Parametres.AutoWalk = false
        end
    end
end

Players.PlayerAdded:Connect(HandleStaff)

-- ====================== UI COLORS & THEME ======================
local COLORS = {
    bg = Color3.fromRGB(10, 10, 15),
    bgAccent = Color3.fromRGB(18, 18, 28),
    accent = Color3.fromRGB(130, 80, 255),
    accent2 = Color3.fromRGB(0, 220, 255),
    text = Color3.fromRGB(240, 240, 255),
    textDim = Color3.fromRGB(160, 160, 180),
    success = Color3.fromRGB(80, 255, 140),
    danger = Color3.fromRGB(255, 80, 100),
    warning = Color3.fromRGB(255, 200, 80)
}

-- ====================== CORE UI CONSTRUCTION ======================
local function CreateUI()
    -- Cleanup
    for _, g in pairs(HubParent:GetChildren()) do
        if g.Name == "SystemV10" then g:Destroy() end
    end

    local Gui = Instance.new("ScreenGui")
    Gui.Name = "SystemV10"
    Gui.ResetOnSpawn = false
    Gui.Parent = HubParent

    -- Toggle Button
    local Toggle = Instance.new("TextButton")
    Toggle.Size = UDim2.new(0, 48, 0, 48)
    Toggle.Position = UDim2.new(0, 20, 0.5, -24)
    Toggle.BackgroundColor3 = COLORS.bgAccent
    Toggle.Text = "⚡"
    Toggle.TextColor3 = COLORS.accent
    Toggle.TextSize = 22
    Toggle.Font = Enum.Font.GothamBlack
    Toggle.Parent = Gui
    
    local tCorner = Instance.new("UICorner", Toggle)
    tCorner.CornerRadius = UDim.new(1, 0)
    local tStroke = Instance.new("UIStroke", Toggle)
    tStroke.Color = COLORS.accent
    tStroke.Thickness = 2
    tStroke.Transparency = 0.5

    -- Main Container (CanvasGroup for fade)
    local Main = Instance.new("CanvasGroup")
    Main.Size = UDim2.new(0, 440, 0, 520)
    Main.Position = UDim2.new(0.5, -220, 0.5, -260)
    Main.BackgroundColor3 = COLORS.bg
    Main.GroupTransparency = 1
    Main.Visible = false
    Main.Parent = Gui
    
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 16)
    local mStroke = Instance.new("UIStroke", Main)
    mStroke.Color = COLORS.bgAccent
    mStroke.Thickness = 2

    local mGrad = Instance.new("UIGradient", Main)
    mGrad.Color = ColorSequence.new(COLORS.bg, Color3.fromRGB(5, 5, 10))
    mGrad.Rotation = 45

    -- Header
    local Header = Instance.new("Frame")
    Header.Size = UDim2.new(1, 0, 0, 60)
    Header.BackgroundTransparency = 1
    Header.Parent = Main

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -100, 1, 0)
    Title.Position = UDim2.new(0, 20, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "INTERNAL SYSTEM <font color='#8250FF'>v10</font>"
    Title.RichText = true
    Title.TextColor3 = COLORS.text
    Title.Font = Enum.Font.GothamBlack
    Title.TextSize = 20
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header

    local Close = Instance.new("TextButton")
    Close.Size = UDim2.new(0, 32, 0, 32)
    Close.Position = UDim2.new(1, -45, 0.5, -16)
    Close.BackgroundColor3 = COLORS.danger
    Close.BackgroundTransparency = 0.8
    Close.Text = "×"
    Close.TextColor3 = Color3.new(1,1,1)
    Close.TextSize = 20
    Close.Parent = Header
    Instance.new("UICorner", Close).CornerRadius = UDim.new(1, 0)

    -- Tab Bar
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -40, 0, 40)
    TabBar.Position = UDim2.new(0, 20, 0, 70)
    TabBar.BackgroundColor3 = COLORS.bgAccent
    TabBar.Parent = Main
    Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 8)

    local TabList = Instance.new("UIListLayout", TabBar)
    TabList.FillDirection = Enum.FillDirection.Horizontal
    TabList.Padding = UDim.new(0, 5)
    TabList.HorizontalAlignment = Enum.HorizontalAlignment.Center

    local Pages = Instance.new("Frame")
    Pages.Size = UDim2.new(1, -40, 1, -140)
    Pages.Position = UDim2.new(0, 20, 0, 120)
    Pages.BackgroundTransparency = 1
    Pages.Parent = Main

    local function CreateTab(name, icon)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 90, 1, -8)
        btn.Position = UDim2.new(0, 0, 0, 4)
        btn.BackgroundColor3 = COLORS.accent
        btn.BackgroundTransparency = 1
        btn.Text = icon .. " " .. name
        btn.TextColor3 = COLORS.textDim
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 12
        btn.Parent = TabBar
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.ScrollBarThickness = 2
        page.ScrollBarImageColor3 = COLORS.accent
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Parent = Pages
        Instance.new("UIListLayout", page).Padding = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(function()
            for _, p in pairs(Pages:GetChildren()) do p.Visible = false end
            for _, b in pairs(TabBar:GetChildren()) do 
                if b:IsA("TextButton") then
                    TweenService:Create(b, TweenInfo.new(0.3), {BackgroundTransparency = 1, TextColor3 = COLORS.textDim}):Play()
                end
            end
            page.Visible = true
            TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundTransparency = 0.2, TextColor3 = COLORS.text}):Play()
        end)

        return page, btn
    end

    local pSteal, bSteal = CreateTab("Steal", "⚔️")
    local pESP, bESP = CreateTab("ESP", "👁️")
    local pBase, bBase = CreateTab("Base", "🏠")
    local pConfig, bConfig = CreateTab("Config", "⚙️")

    -- Default Active
    pSteal.Visible = true
    bSteal.BackgroundTransparency = 0.2
    bSteal.TextColor3 = COLORS.text

    -- Components
    local function AddToggle(parent, text, configKey, callback)
        local f = Instance.new("TextButton")
        f.Size = UDim2.new(1, -10, 0, 45)
        f.BackgroundColor3 = COLORS.bgAccent
        f.Text = ""
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
        
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.7, 0, 1, 0)
        lbl.Position = UDim2.new(0, 15, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = COLORS.text
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = f

        local tbg = Instance.new("Frame")
        tbg.Size = UDim2.new(0, 44, 0, 24)
        tbg.Position = UDim2.new(1, -59, 0.5, -12)
        tbg.BackgroundColor3 = InternalSystem.Parametres[configKey] and COLORS.accent or Color3.fromRGB(40, 40, 50)
        tbg.Parent = f
        Instance.new("UICorner", tbg).CornerRadius = UDim.new(1, 0)

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(0, 18, 0, 18)
        dot.Position = InternalSystem.Parametres[configKey] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        dot.BackgroundColor3 = Color3.new(1,1,1)
        dot.Parent = tbg
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        f.MouseButton1Click:Connect(function()
            InternalSystem.Parametres[configKey] = not InternalSystem.Parametres[configKey]
            local state = InternalSystem.Parametres[configKey]
            TweenService:Create(tbg, TweenInfo.new(0.3), {BackgroundColor3 = state and COLORS.accent or Color3.fromRGB(40, 40, 50)}):Play()
            TweenService:Create(dot, TweenInfo.new(0.3, Enum.EasingStyle.Back), {Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)}):Play()
            if callback then callback(state) end
        end)
    end

    local function AddSlider(parent, text, min, max, configKey)
        local f = Instance.new("Frame")
        f.Size = UDim2.new(1, -10, 0, 70)
        f.BackgroundColor3 = COLORS.bgAccent
        f.Parent = parent
        Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 0, 30)
        lbl.Position = UDim2.new(0, 15, 0, 5)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = COLORS.text
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextSize = 13
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = f

        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.4, 0, 0, 30)
        val.Position = UDim2.new(0.6, -15, 0, 5)
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
        track.BackgroundColor3 = Color3.fromRGB(30,30,40)
        track.Parent = f
        Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

        local bar = Instance.new("Frame")
        local pct = (InternalSystem.Parametres[configKey] - min) / (max - min)
        bar.Size = UDim2.new(pct, 0, 1, 0)
        bar.BackgroundColor3 = COLORS.accent
        bar.Parent = track
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = f

        local function update(input)
            local r = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local v = math.floor(min + (max - min) * r)
            InternalSystem.Parametres[configKey] = v
            val.Text = tostring(v)
            bar.Size = UDim2.new(r, 0, 1, 0)
        end

        local drag = false
        btn.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true update(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
        UserInputService.InputChanged:Connect(function(i) if drag and i.UserInputType == Enum.UserInputType.MouseMovement then update(i) end end)
    end

    -- Fill Tabs
    AddToggle(pSteal, "🟢 Master Auto-Grab", "AutoGrab_Actif")
    AddToggle(pSteal, "🚶 Pathfinding Walk", "AutoWalk")
    AddToggle(pSteal, "🤖 Anti-AFK Humanizer", "DebugMode")
    AddSlider(pSteal, "📏 Grab Range", 5, 100, "GrabRange")
    AddSlider(pSteal, "⏱️ Action Delay", 1, 5, "GrabDelay")

    AddToggle(pESP, "🕵️ Brainrot Highlights", "BrainrotESP")
    AddToggle(pESP, "👤 Player Tracker", "PlayerESP")
    AddToggle(pESP, "🏘️ Base Status ESP", "BaseTimerESP")

    AddToggle(pBase, "🛡️ Shield Auto-Recall", "AutoRecall_Actif")
    AddToggle(pBase, "🖱️ Base Auto-Clicker", "AutoClicker")

    AddToggle(pConfig, "🌐 Server Hop (Staff)", "ServerHopStaff")
    AddToggle(pConfig, "🔮 Visual Aura", "AfficherCercle")

    -- Interaction Overlay (Bottom Bar)
    local Overlay = Instance.new("Frame")
    Overlay.Size = UDim2.new(0, 320, 0, 50)
    Overlay.Position = UDim2.new(0.5, -160, 1, -100)
    Overlay.BackgroundColor3 = COLORS.bg
    Overlay.Parent = Gui
    Instance.new("UICorner", Overlay).CornerRadius = UDim.new(0, 12)
    Instance.new("UIStroke", Overlay).Color = COLORS.bgAccent

    local oStatus = Instance.new("TextLabel")
    oStatus.Size = UDim2.new(1, -20, 0, 20)
    oStatus.Position = UDim2.new(0, 10, 0, 8)
    oStatus.BackgroundTransparency = 1
    oStatus.Text = "SYSTEM STANDBY"
    oStatus.TextColor3 = COLORS.textDim
    oStatus.Font = Enum.Font.GothamBold
    oStatus.TextSize = 12
    oStatus.Parent = Overlay

    local oBarBg = Instance.new("Frame")
    oBarBg.Size = UDim2.new(1, -20, 0, 6)
    oBarBg.Position = UDim2.new(0, 10, 0, 32)
    oBarBg.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    oBarBg.Parent = Overlay
    Instance.new("UICorner", oBarBg).CornerRadius = UDim.new(1, 0)

    local oBar = Instance.new("Frame")
    oBar.Size = UDim2.new(0, 0, 1, 0)
    oBar.BackgroundColor3 = COLORS.accent
    oBar.Parent = oBarBg
    Instance.new("UICorner", oBar).CornerRadius = UDim.new(1, 0)

    -- Toggle Logic
    local open = false
    Toggle.MouseButton1Click:Connect(function()
        open = not open
        Main.Visible = true
        TweenService:Create(Main, TweenInfo.new(0.4, Enum.EasingStyle.Cubic), {GroupTransparency = open and 0 or 1}):Play()
        TweenService:Create(Toggle, TweenInfo.new(0.4), {Rotation = open and 45 or 0, TextColor3 = open and COLORS.danger or COLORS.accent}):Play()
        if not open then task.delay(0.4, function() if not open then Main.Visible = false end end) end
    end)
    Close.MouseButton1Click:Connect(function() open = false TweenService:Create(Main, TweenInfo.new(0.4), {GroupTransparency = 1}):Play() task.delay(0.4, function() Main.Visible = false end) end)

    return {Status = oStatus, Progress = oBar}
end

local HUD = CreateUI()

-- ====================== LOGIQUE DE JEU (MOTEUR V10) ======================

local function GetClosestPlot(onlyMine)
    for _, plot in pairs(DossierPlots:GetChildren()) do
        local ownerVal = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
        local isMine = ownerVal and (ownerVal.Value == LocalPlayer or ownerVal.Value == LocalPlayer.Name)
        if onlyMine then if isMine then return plot end else if not isMine then return plot end end
    end
end

-- AUTO CLIQUER (MINE)
task.spawn(function()
    while true do
        if InternalSystem.Parametres.AutoClicker then
            local mine = GetClosestPlot(true)
            if mine then
                for _, btn in pairs(mine:GetDescendants()) do
                    if btn:IsA("ProximityPrompt") and btn.Enabled then
                        local at = btn.ActionText:lower()
                        if at:find("claim") or at:find("collect") or at:find("upgrade") then
                            fireproximityprompt(btn)
                        end
                    end
                end
            end
        end
        task.wait(1)
    end
end)

-- AUTO GRAB ENGINE
local isGrabbing = false
RunService.Heartbeat:Connect(function()
    if not InternalSystem.Parametres.AutoGrab_Actif or isGrabbing then return end
    
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Check if already carrying
    if LocalPlayer:GetAttribute("Stealing") then 
        HUD.Status.Text = "🧠 CARRYING BRAINROT"
        HUD.Status.TextColor3 = COLORS.success
        return 
    end

    local bestTarget, bestVal, bestDist = nil, -1, math.huge
    local range = InternalSystem.Parametres.GrabRange

    for _, plot in pairs(DossierPlots:GetChildren()) do
        -- Skip mine
        local o = plot:FindFirstChild("PlotOwner") or plot:FindFirstChild("Owner")
        if o and (o.Value == LocalPlayer or o.Value == LocalPlayer.Name) then continue end

        for _, d in pairs(plot:GetDescendants()) do
            if d:IsA("ProximityPrompt") and d.Enabled then
                local act = d.ActionText:lower()
                if act:find("unlock") or act:find("toggle") then continue end
                
                local pos = ObtenirPositionPrompt(d)
                if not pos then continue end
                local dist = (root.Position - pos).Magnitude
                if dist > range then continue end
                if not EstVisible(pos, d.Parent) then continue end

                -- Evaluation
                local val = 1
                local overhead = d.Parent:FindFirstChild("AnimalOverhead") or d.Parent.Parent:FindFirstChild("AnimalOverhead")
                if overhead and overhead:FindFirstChild("DisplayName") then
                    local name = overhead.DisplayName.Text
                    if InternalSystem.Heros[name] then val = InternalSystem.Heros[name].ValeurNum end
                end

                if InternalSystem.Parametres.GrabMode == "Highest" then
                    if val > bestVal then bestVal = val; bestDist = dist; bestTarget = d end
                else
                    if dist < bestDist then bestVal = val; bestDist = dist; bestTarget = d end
                end
            end
        end
    end

    if bestTarget then
        isGrabbing = true
        HUD.Status.Text = "⚡ STEALING..."
        HUD.Status.TextColor3 = COLORS.warning
        
        -- Pathfinding if far
        if InternalSystem.Parametres.AutoWalk and bestDist > 8 then
            local path = PathfindingService:CreatePath({AgentRadius = 3})
            path:ComputeAsync(root.Position, ObtenirPositionPrompt(bestTarget))
            if path.Status == Enum.PathStatus.Success then
                for _, w in pairs(path:GetWaypoints()) do
                    LocalPlayer.Character.Humanoid:MoveTo(w.Position)
                    if w.Action == Enum.PathWaypointAction.Jump then LocalPlayer.Character.Humanoid.Jump = true end
                    task.wait(0.1)
                end
            end
        end

        local hold = bestTarget.HoldDuration
        local duration = math.max(hold, InternalSystem.Parametres.GrabDelay)
        
        local start = tick()
        local conn
        conn = RunService.RenderStepped:Connect(function()
            local elapsed = tick() - start
            local pct = math.clamp(elapsed / duration, 0, 1)
            HUD.Progress.Size = UDim2.new(pct, 0, 1, 0)
            if pct >= 1 then conn:Disconnect() end
        end)

        fireproximityprompt(bestTarget)
        task.wait(duration + 0.2)
        
        HUD.Progress.Size = UDim2.new(0, 0, 1, 0)
        isGrabbing = false
    else
        HUD.Status.Text = "🔍 SCANNING AREA..."
        HUD.Status.TextColor3 = COLORS.textDim
    end
end)

-- AURA VISUELLE
local Aura = Instance.new("Part")
Aura.Shape = Enum.PartType.Cylinder
Aura.Material = Enum.Material.Neon
Aura.Transparency = 0.8
Aura.Anchored = true
Aura.CanCollide = false
Aura.CastShadow = false

RunService.RenderStepped:Connect(function()
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if InternalSystem.Parametres.AfficherCercle and root then
        local r = InternalSystem.Parametres.GrabRange * 2
        Aura.Size = Vector3.new(0.1, r, r)
        Aura.CFrame = root.CFrame * CFrame.new(0, -2.8, 0) * CFrame.Angles(0, 0, math.rad(90))
        Aura.Color = InternalSystem.Parametres.AutoGrab_Actif and COLORS.accent or COLORS.textDim
        Aura.Parent = Workspace
    else
        Aura.Parent = nil
    end
end)

-- HIGHLIGHT ESP
local HighFolder = Instance.new("Folder", CoreGui)
HighFolder.Name = "V10_Highlights"

task.spawn(function()
    while true do
        if InternalSystem.Parametres.BrainrotESP then
            for _, plot in pairs(DossierPlots:GetChildren()) do
                for _, m in pairs(plot:GetDescendants()) do
                    if m:IsA("Model") and InternalSystem.Heros[m.Name] then
                        if not m:FindFirstChild("Highlight") then
                            local h = Instance.new("Highlight", m)
                            h.FillColor = COLORS.accent
                            h.OutlineColor = COLORS.accent2
                            h.FillTransparency = 0.5
                        end
                    end
                end
            end
        else
            HighFolder:ClearAllChildren()
            for _, plot in pairs(DossierPlots:GetChildren()) do
                for _, m in pairs(plot:GetDescendants()) do
                    local h = m:FindFirstChild("Highlight")
                    if h then h:Destroy() end
                end
            end
        end
        task.wait(2)
    end
end)

Log("Internal System v10.0 SUPERIOR Loaded Successfully.")
