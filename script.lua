-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 9.0 ULTIMATE (Custom GUI - Zero Dependencies)
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
local _Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local HubParent = (gethui and gethui()) or CoreGui

-- ====================== UTILITAIRES ======================
local function ConvertirEnNombre(valeur)
    if type(valeur) == "number" then return valeur end
    local texte = tostring(valeur):upper()
    local nombre = tonumber(texte:match("[%d%.]+")) or 0
    if texte:match("B") then nombre = nombre * 1e9
    elseif texte:match("M") then nombre = nombre * 1e6
    elseif texte:match("K") then nombre = nombre * 1e3 end
    return nombre
end

local function LerpColor(c1, c2, t)
    return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t)
end

-- ====================== DONNÉES JEUX ======================
local DossierModeles = ReplicatedStorage:WaitForChild("Models", 5)
local DossierAnimaux = DossierModeles and DossierModeles:WaitForChild("Animals", 5)
local DossierPlots = Workspace:WaitForChild("Plots", 5)

-- ====================== MODE SAFE (Anti-Ban) ======================
-- NE PAS toucher aux remotes UUID directement = BAN INSTANT
-- Le jeu valide les tokens avec SHA256 + timestamps serveur
-- SEULE méthode safe: fireproximityprompt (passe par le code légitime du jeu)

-- ====================== MOTEUR MOHA HUB ======================
local MohaHub = {
    Heros = {}, ListeNomsHeros = {},
    Parametres = {
        AutoGrab_Actif = false, GrabMode = "Highest", GrabDelay = 1.0,
        GrabRange = 10, AfficherCercle = true, AutoRecall_Actif = false,
        BrainrotESP = false, GrabBrainrots = true
    }
}

function MohaHub:ExtraireProprio(plot)
    if not plot then return nil end
    local o = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner") or plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName")
    if type(o) == "string" and o ~= "" and o ~= "Personne" then return o end
    if typeof(o) == "Instance" then
        if o:IsA("ObjectValue") and o.Value then 
            local val = o.Value
            return (val:IsA("Player") and val.DisplayName) or val.Name 
        end
        if o:IsA("StringValue") and o.Value ~= "" and o.Value ~= "Personne" then return o.Value end
    end
    -- Fallback: Chercher un StringValue ou ObjectValue enfant avec "Owner" dans le nom
    for _, v in pairs(plot:GetChildren()) do
        if v.Name:lower():find("owner") then
            if v:IsA("StringValue") and v.Value ~= "" then return v.Value end
            if v:IsA("ObjectValue") and v.Value then 
                local val = v.Value
                return (val:IsA("Player") and val.DisplayName) or val.Name
            end
        end
    end
    return nil
end

function MohaHub:EstVide(plot)
    if not plot then return true end
    -- Si on trouve un proprio, c'est pas vide
    if self:ExtraireProprio(plot) then return false end
    -- Si on trouve au moins un brainrot, c'est pas vide
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("Model") and self.Heros[desc.Name] then return false end
    end
    -- Si on trouve un bouton de "Réclamation", c'est vide
    if plot:FindFirstChild("Claim") or plot:FindFirstChild("ClaimPlot") then return true end
    return true
end

function MohaHub:EstProtege(plot)
    if not plot then return false end
    -- Check uniquement les Attributs du plot (pas de scan récursif = pas de faux positifs)
    if plot:GetAttribute("ShieldActive") == true then return true end
    if plot:GetAttribute("Locked") == true then return true end
    if plot:GetAttribute("Private") == true then return true end
    if plot:GetAttribute("StealProtected") == true then return true end
    -- Check ForceField direct (pas récursif)
    if plot:FindFirstChildOfClass("ForceField") then return true end
    return false
end

function MohaHub:AjouterHero(nom, config)
    if not config.ValeurNum then
        if config.Prix then config.ValeurNum = ConvertirEnNombre(config.Prix)
        elseif config.Gen then config.ValeurNum = config.Gen
        else config.ValeurNum = 0 end
    end
    if not self.Heros[nom] then table.insert(self.ListeNomsHeros, nom) end
    self.Heros[nom] = config
end

-- Héros de base
MohaHub:AjouterHero("Glorbo Fruttodrillo", {Rarete="Legendary", Prix="200K", Gen=938})
MohaHub:AjouterHero("Trulimero Trulicina", {Rarete="Epic", Prix="20K", Gen=188})
MohaHub:AjouterHero("Perochello Lemonchello", {Rarete="Epic", Prix="27.5K", Gen=160})
MohaHub:AjouterHero("Cappuccino Assassino", {Rarete="Epic", Prix="10K", Gen=113})
MohaHub:AjouterHero("Brr Brr Patapim", {Rarete="Epic", Prix="15K", Gen=100})

-- ====================== SCAN BRAINROTS ======================
local BrainrotsScannes = {}
task.spawn(function()
    task.wait(1)
    if DossierAnimaux then
        for _, modele in pairs(DossierAnimaux:GetChildren()) do
            local op = modele:FindFirstChild("Price") or modele:FindFirstChild("Prix") or modele:FindFirstChild("Value")
            local or_ = modele:FindFirstChild("Rarity") or modele:FindFirstChild("Rarete")
            local pT = op and tostring(op.Value) or "0"
            local rT = or_ and tostring(or_.Value) or "Normal"
            local vR = ConvertirEnNombre(pT)
            table.insert(BrainrotsScannes, {Nom=modele.Name, Rarete=rT, PrixStr=pT, ValeurDeTri=vR})
        end
        table.sort(BrainrotsScannes, function(a,b) return a.ValeurDeTri > b.ValeurDeTri end)
        for _, b in ipairs(BrainrotsScannes) do
            MohaHub:AjouterHero(b.Nom, {Rarete=b.Rarete, Prix=b.PrixStr, ValeurNum=b.ValeurDeTri})
        end
        print("[MohaHub] Scan: "..#BrainrotsScannes.." brainrots trouvés.")
    end
end)

-- ====================== COULEURS THÈME ======================
local COLORS = {
    bg = Color3.fromRGB(12, 12, 18),
    bgLight = Color3.fromRGB(22, 22, 32),
    card = Color3.fromRGB(28, 28, 40),
    cardHover = Color3.fromRGB(35, 35, 50),
    accent1 = Color3.fromRGB(130, 80, 255),   -- Violet
    accent2 = Color3.fromRGB(255, 60, 130),    -- Rose
    accent3 = Color3.fromRGB(0, 200, 255),     -- Cyan
    green = Color3.fromRGB(50, 220, 120),
    red = Color3.fromRGB(255, 60, 80),
    textPrimary = Color3.fromRGB(240, 240, 255),
    textSecondary = Color3.fromRGB(150, 150, 180),
    border = Color3.fromRGB(60, 60, 90),
    grabBar = Color3.fromRGB(130, 80, 255),
    espColor = Color3.fromRGB(255, 180, 0),
}

-- ====================== CRÉATION GUI PRINCIPAL ======================
task.defer(function()
    -- Nettoyer ancien GUI
    for _, g in pairs(HubParent:GetChildren()) do
        if g.Name == "MohaHubUltimate" or g.Name == "MohaGrabHUD" then g:Destroy() end
    end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MohaHubUltimate"
ScreenGui.Parent = HubParent
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ====================== BOUTON TOGGLE ======================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 15, 0.5, -25)
ToggleBtn.BackgroundColor3 = COLORS.accent1
ToggleBtn.Text = "M"
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.TextSize = 22
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Parent = ScreenGui
ToggleBtn.ZIndex = 100
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

local toggleGlow = Instance.new("UIStroke")
toggleGlow.Parent = ToggleBtn
toggleGlow.Color = COLORS.accent1
toggleGlow.Thickness = 2
toggleGlow.Transparency = 0.3

-- Animation pulsation bouton
task.spawn(function()
    while ToggleBtn.Parent do
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.7}):Play()
        task.wait(1.5)
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}):Play()
        task.wait(1.5)
    end
end)

-- ====================== PANEL PRINCIPAL ======================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 480)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -240)
MainFrame.BackgroundColor3 = COLORS.bg
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

local mainStroke = Instance.new("UIStroke")
mainStroke.Parent = MainFrame
mainStroke.Color = COLORS.accent1
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

-- Gradient de fond subtil
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 10, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 15))
})
bgGradient.Rotation = 145
bgGradient.Parent = MainFrame

-- Animation pulsation du cadre
task.spawn(function()
    while MainFrame.Parent do
        if MainFrame.Visible then
            TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}):Play()
            task.wait(2)
            TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.7}):Play()
            task.wait(2)
        else
            task.wait(1)
        end
    end
end)

-- ====================== HEADER ======================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 55)
Header.BackgroundColor3 = Color3.fromRGB(18, 15, 30)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 15, 35)),
    ColorSequenceKeypoint.new(1, COLORS.accent2)
})
headerGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.3, 0.95),
    NumberSequenceKeypoint.new(0.7, 0.95),
    NumberSequenceKeypoint.new(1, 0.6)
})
headerGrad.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ MOHA HUB v9"
TitleLabel.TextColor3 = COLORS.textPrimary
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 20
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 0, 14)
SubTitle.Position = UDim2.new(1, -210, 0.5, -7)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "ULTIMATE EDITION"
SubTitle.TextColor3 = COLORS.accent2
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 10
SubTitle.TextXAlignment = Enum.TextXAlignment.Right
SubTitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -45, 0.5, -17)
CloseBtn.BackgroundColor3 = COLORS.red
CloseBtn.BackgroundTransparency = 0.8
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = COLORS.red
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- ====================== ONGLETS ======================
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 36)
TabBar.Position = UDim2.new(0, 10, 0, 60)
TabBar.BackgroundColor3 = COLORS.bgLight
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = TabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 4)
tabPad.PaddingTop = UDim.new(0, 4)
tabPad.Parent = TabBar

local TAB_NAMES = {"⚔️ Steal", "🧠 ESP", "🛡️ Défense", "ℹ️ Info"}
local TabButtons = {}
local TabPages = {}
local _currentTab = 1

-- Pages container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -20, 1, -110)
PagesContainer.Position = UDim2.new(0, 10, 0, 102)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame
PagesContainer.ClipsDescendants = true

for i, tabName in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 0, 28)
    btn.BackgroundColor3 = i == 1 and COLORS.accent1 or COLORS.card
    btn.BackgroundTransparency = i == 1 and 0.2 or 0.5
    btn.Text = tabName
    btn.TextColor3 = i == 1 and Color3.new(1,1,1) or COLORS.textSecondary
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    TabButtons[i] = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = COLORS.accent1
    page.BorderSizePixel = 0
    page.Visible = (i == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = PagesContainer
    TabPages[i] = page

    local pl = Instance.new("UIListLayout")
    pl.Padding = UDim.new(0, 8)
    pl.Parent = page

    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, 5)
    pp.PaddingBottom = UDim.new(0, 10)
    pp.Parent = page

    btn.MouseButton1Click:Connect(function()
        local _currentTab = i
        for j, b in ipairs(TabButtons) do
            local active = (j == i)
            TweenService:Create(b, TweenInfo.new(0.25), {
                BackgroundColor3 = active and COLORS.accent1 or COLORS.card,
                BackgroundTransparency = active and 0.2 or 0.5,
                TextColor3 = active and Color3.new(1,1,1) or COLORS.textSecondary
            }):Play()
            TabPages[j].Visible = active
        end
    end)
end

-- ====================== COMPOSANTS UI ======================
local function CreateSection(page, title)
    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 28)
    sec.BackgroundTransparency = 1
    sec.Parent = page
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  "..title
    lbl.TextColor3 = COLORS.accent3
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = sec
    return sec
end

local function CreateToggle(page, name, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0, 44, 0, 24)
    toggleFrame.Position = UDim2.new(1, -56, 0.5, -12)
    toggleFrame.BackgroundColor3 = default and COLORS.green or Color3.fromRGB(60,60,75)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = container
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.new(1,1,1)
    circle.BorderSizePixel = 0
    circle.Parent = toggleFrame
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = container
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(toggleFrame, TweenInfo.new(0.3), {
            BackgroundColor3 = state and COLORS.green or Color3.fromRGB(60,60,75)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
        callback(state)
    end)
    return container
end

local function CreateSlider(page, name, min, max, default, suffix, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 56)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 0, 20)
    valLbl.Position = UDim2.new(1, -70, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)..suffix
    valLbl.TextColor3 = COLORS.accent1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 0, 24)
    lbl.Position = UDim2.new(0, 14, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = container
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    local pct = (default - min) / (max - min)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent1
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(pct, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knobStroke = Instance.new("UIStroke")
    knobStroke.Parent = knob
    knobStroke.Color = COLORS.accent1
    knobStroke.Thickness = 2

    local dragging = false
    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(1, 0, 0, 20)
    sliderBtn.Position = UDim2.new(0, 0, 0, 28)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.Parent = container

    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local val = min + (max - min) * rel
            -- snap
            if max <= 5 then val = math.floor(val * 10 + 0.5) / 10
            else val = math.floor(val + 0.5) end
            local p2 = (val - min) / (max - min)
            fill.Size = UDim2.new(p2, 0, 1, 0)
            knob.Position = UDim2.new(p2, -8, 0.5, -8)
            valLbl.Text = tostring(val)..suffix
            callback(val)
        end
    end)
    return container
end

local function CreateDropdown(page, name, options, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local selected = default
    local currentIdx = 1
    for i, v in ipairs(options) do if v == default then currentIdx = i end end

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 120, 0, 28)
    selectBtn.Position = UDim2.new(1, -132, 0.5, -14)
    selectBtn.BackgroundColor3 = COLORS.accent1
    selectBtn.BackgroundTransparency = 0.7
    selectBtn.Text = "◀ "..selected.." ▶"
    selectBtn.TextColor3 = COLORS.textPrimary
    selectBtn.TextSize = 12
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.BorderSizePixel = 0
    selectBtn.Parent = container
    Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 8)

    selectBtn.MouseButton1Click:Connect(function()
        currentIdx = currentIdx % #options + 1
        selected = options[currentIdx]
        selectBtn.Text = "◀ "..selected.." ▶"
        callback(selected)
    end)
    return container
end

local function CreateInfoCard(page, title, content)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 80)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 0, 22)
    t.Position = UDim2.new(0, 12, 0, 6)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = COLORS.accent1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = container

    local c = Instance.new("TextLabel")
    c.Size = UDim2.new(1, -20, 1, -30)
    c.Position = UDim2.new(0, 12, 0, 28)
    c.BackgroundTransparency = 1
    c.Text = content
    c.TextColor3 = COLORS.textSecondary
    c.Font = Enum.Font.Gotham
    c.TextSize = 11
    c.TextXAlignment = Enum.TextXAlignment.Left
    c.TextYAlignment = Enum.TextYAlignment.Top
    c.TextWrapped = true
    c.Parent = container
    return container
end

-- ====================== REMPLISSAGE DES PAGES ======================
-- Page 1 : STEAL
local p1 = TabPages[1]
CreateSection(p1, "AUTO-GRAB ENGINE")
CreateToggle(p1, "🟢 Activer Auto Grab", false, function(v) MohaHub.Parametres.AutoGrab_Actif = v end)
CreateToggle(p1, "🧠 Voler aussi les Brainrots", true, function(v) MohaHub.Parametres.GrabBrainrots = v end)
CreateToggle(p1, "🔮 Afficher cercle visuel", true, function(v) MohaHub.Parametres.AfficherCercle = v end)
CreateSlider(p1, "📏 Range (Studs)", 1, 20, 10, " studs", function(v) MohaHub.Parametres.GrabRange = v end)
CreateSlider(p1, "⏱️ Délai de vol", 0.1, 5.0, 1.0, "s", function(v) MohaHub.Parametres.GrabDelay = v end)
CreateDropdown(p1, "🎯 Priorité", {"Highest", "Nearest"}, "Highest", function(v) MohaHub.Parametres.GrabMode = v end)

-- Page 2 : ESP
local p2 = TabPages[2]
CreateSection(p2, "VISUELS")
CreateToggle(p2, "👁️ Brainrot ESP", false, function(v) MohaHub.Parametres.BrainrotESP = v end)
CreateToggle(p2, "👤 Player ESP", false, function(v) MohaHub.Parametres.PlayerESP = v end)
CreateToggle(p2, "🏠 Base Timer ESP", false, function(v) MohaHub.Parametres.BaseTimerESP = v end)

CreateInfoCard(p2, "ℹ️ Info ESP", "L'ESP Player affiche les pseudos et distances.\nL'ESP Base affiche le proprio and le timer de vol.\nLe Brainrot ESP scanne les models invisibles.")

-- Page 3 : DEFENSE
local p3 = TabPages[3]
CreateSection(p3, "BOUCLIER ANTI-STEAL")
CreateToggle(p3, "🛡️ Activer Auto-Recall", false, function(v) MohaHub.Parametres.AutoRecall_Actif = v end)
CreateInfoCard(p3, "ℹ️ Auto-Recall", "Rappelle automatiquement vos héros volés en spammant le Remote Grab sur vos podiums.")

-- Page 4 : INFO
local p4 = TabPages[4]
CreateSection(p4, "MOHA HUB v9 ULTIMATE")
CreateInfoCard(p4, "⚡ Moteur de vol", "Mode SAFE: fireproximityprompt uniquement\nAnti-Ban: Pas de remotes UUID")
CreateInfoCard(p4, "📡 Status", "✅ Mode Safe actif - Pas de ban")
CreateInfoCard(p4, "🧠 Brainrots", "Scan depuis ReplicatedStorage.Models.Animals\nNombre détecté: "..tostring(#BrainrotsScannes))

-- ====================== BARRE DE GRAB EN HAUT (TOUJOURS VISIBLE) ======================
-- Nettoyer ancienne barre
for _, g in pairs(HubParent:GetChildren()) do
    if g.Name == "MohaGrabBar" then g:Destroy() end
end

local GrabBarGui = Instance.new("ScreenGui")
GrabBarGui.Name = "MohaGrabBar"
GrabBarGui.Parent = HubParent
GrabBarGui.ResetOnSpawn = false
GrabBarGui.Enabled = false
GrabBarGui.DisplayOrder = 999

local GrabBarFrame = Instance.new("Frame")
GrabBarFrame.Size = UDim2.new(0, 300, 0, 42)
GrabBarFrame.Position = UDim2.new(0.5, -150, 0, 5)
GrabBarFrame.BackgroundColor3 = Color3.fromRGB(8, 6, 18)
GrabBarFrame.BorderSizePixel = 0
GrabBarFrame.Active = false -- Empêche d'être cliqué/déplacé
GrabBarFrame.Parent = GrabBarGui

local barCorner = Instance.new("UICorner", GrabBarFrame)
barCorner.CornerRadius = UDim.new(0, 10)

local grabBarStroke = Instance.new("UIStroke")
grabBarStroke.Parent = GrabBarFrame
grabBarStroke.Color = COLORS.accent1
grabBarStroke.Thickness = 1.2
grabBarStroke.Transparency = 0.6

local grabBarGrad = Instance.new("UIGradient")
grabBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 10, 50)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 6, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 10, 50))
})
grabBarGrad.Parent = GrabBarFrame

-- Ligne lumineuse en bas de la barre
local GrabBarGlow = Instance.new("Frame")
GrabBarGlow.Size = UDim2.new(1, 0, 0, 2)
GrabBarGlow.Position = UDim2.new(0, 0, 1, -2)
GrabBarGlow.BackgroundColor3 = COLORS.accent1
GrabBarGlow.BorderSizePixel = 0
GrabBarGlow.Parent = GrabBarFrame
local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, COLORS.accent2),
    ColorSequenceKeypoint.new(1, COLORS.accent3)
})
glowGrad.Parent = GrabBarGlow

-- Barre de progression
local GrabProgressBg = Instance.new("Frame")
GrabProgressBg.Size = UDim2.new(1, -24, 0, 8)
GrabProgressBg.Position = UDim2.new(0, 12, 1, -14)
GrabProgressBg.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
GrabProgressBg.BorderSizePixel = 0
GrabProgressBg.Parent = GrabBarFrame
Instance.new("UICorner", GrabProgressBg).CornerRadius = UDim.new(1, 0)

local GrabProgressFill = Instance.new("Frame")
GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
GrabProgressFill.BackgroundColor3 = COLORS.accent1
GrabProgressFill.BorderSizePixel = 0
GrabProgressFill.Parent = GrabProgressBg
Instance.new("UICorner", GrabProgressFill).CornerRadius = UDim.new(1, 0)

local grabFillGrad = Instance.new("UIGradient")
grabFillGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, COLORS.accent2),
    ColorSequenceKeypoint.new(1, COLORS.accent3)
})
grabFillGrad.Parent = GrabProgressFill

-- Icône animée
local GrabIcon = Instance.new("TextLabel")
GrabIcon.Size = UDim2.new(0, 30, 0, 24)
GrabIcon.Position = UDim2.new(0, 10, 0, 2)
GrabIcon.BackgroundTransparency = 1
GrabIcon.Text = "⚡"
GrabIcon.TextSize = 18
GrabIcon.Font = Enum.Font.GothamBold
GrabIcon.Parent = GrabBarFrame

-- Status du grab
local GrabStatusLabel = Instance.new("TextLabel")
GrabStatusLabel.Size = UDim2.new(0.5, 0, 0, 24)
GrabStatusLabel.Position = UDim2.new(0, 40, 0, 2)
GrabStatusLabel.BackgroundTransparency = 1
GrabStatusLabel.Text = "Recherche de cible..."
GrabStatusLabel.TextColor3 = COLORS.textPrimary
GrabStatusLabel.Font = Enum.Font.GothamBold
GrabStatusLabel.TextSize = 14
GrabStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
GrabStatusLabel.Parent = GrabBarFrame

-- Timer
local GrabTimeLabel = Instance.new("TextLabel")
GrabTimeLabel.Size = UDim2.new(0, 120, 0, 24)
GrabTimeLabel.Position = UDim2.new(1, -130, 0, 2)
GrabTimeLabel.BackgroundTransparency = 1
GrabTimeLabel.Text = ""
GrabTimeLabel.TextColor3 = COLORS.accent3
GrabTimeLabel.Font = Enum.Font.GothamBold
GrabTimeLabel.TextSize = 14
GrabTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
GrabTimeLabel.Parent = GrabBarFrame

-- ====================== AURA VISUEL ======================
local CercleAura = Instance.new("Part")
CercleAura.Shape = Enum.PartType.Cylinder
CercleAura.Color = COLORS.accent1
CercleAura.Material = Enum.Material.Neon
CercleAura.Transparency = 0.7
CercleAura.Anchored = true
CercleAura.CanCollide = false
CercleAura.CastShadow = false

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if MohaHub.Parametres.AfficherCercle and MohaHub.Parametres.AutoGrab_Actif and root then
        CercleAura.Position = root.Position - Vector3.new(0, 2.5, 0)
        CercleAura.Orientation = Vector3.new(0, 0, 90)
        local d = MohaHub.Parametres.GrabRange * 2
        CercleAura.Size = Vector3.new(0.2, d, d)
        if not CercleAura.Parent then CercleAura.Parent = Workspace end
    else
        if CercleAura.Parent then CercleAura.Parent = nil end
    end
end)

-- ====================== TOGGLE OPEN/CLOSE ======================
local guiOpen = false
MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(0, 420, 0, 0)

ToggleBtn.MouseButton1Click:Connect(function()
    guiOpen = not guiOpen
    if guiOpen then
        MainFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 420, 0, 480), BackgroundTransparency = 0}):Play()
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 420, 0, 0), BackgroundTransparency = 1}):Play()
        task.delay(0.4, function() if not guiOpen then MainFrame.Visible = false end end)
    end
    
    TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {
        BackgroundColor3 = guiOpen and COLORS.accent2 or COLORS.accent1,
        Rotation = guiOpen and 90 or 0
    }):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    guiOpen = false
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 420, 0, 0), BackgroundTransparency = 1}):Play()
    task.delay(0.4, function() MainFrame.Visible = false end)
    
    TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {
        BackgroundColor3 = COLORS.accent1, Rotation = 0
    }):Play()
end)

-- Drag support
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ====================== AUTO GRAB ENGINE (FIXED) ======================
-- FIX: Trouver les brainrots VISIBLES sur un plot (pas les templates)
-- Les brainrots sont des Models enfants du plot qui matchent les noms scannés
local function TrouverBrainrotsVisibles(plot)
    local brainrots = {}
    for _, child in pairs(plot:GetDescendants()) do
        if child:IsA("Model") and MohaHub.Heros[child.Name] then
            -- Vérifier que le model a des parties visibles (pas invisible)
            local hasVisiblePart = false
            local primaryPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                for _, p in pairs(child:GetDescendants()) do
                    if p:IsA("BasePart") and p.Transparency < 0.9 then
                        hasVisiblePart = true
                        break
                    end
                end
            end
            if hasVisiblePart then
                table.insert(brainrots, child)
            end
        end
    end
    return brainrots
end

local function ObtenirMeilleurBrainrot(plot, mode, rootPos)
    local brainrots = TrouverBrainrotsVisibles(plot)
    local best = nil
    local bestVal = -1
    local bestDist = math.huge
    local bestName = "Inconnu"

    for _, brainrot in pairs(brainrots) do
        local hd = MohaHub.Heros[brainrot.Name]
        if hd then
            local part = brainrot.PrimaryPart or brainrot:FindFirstChildWhichIsA("BasePart")
            local dist = part and (rootPos - part.Position).Magnitude or math.huge

            if mode == "Highest" then
                if hd.ValeurNum and hd.ValeurNum > bestVal then
                    bestVal = hd.ValeurNum
                    best = brainrot
                    bestName = brainrot.Name
                end
            elseif mode == "Nearest" then
                if dist < bestDist then
                    bestDist = dist
                    best = brainrot
                    bestName = brainrot.Name
                end
            end
        end
    end
    return best, bestName, bestVal
end

-- FIX: Lire le prix depuis le overhead BillboardGui du brainrot sur le plot
local function LirePrixOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            local priceLabel = desc:FindFirstChild("Price") or desc:FindFirstChild("prix")
            if priceLabel and priceLabel:IsA("TextLabel") then
                return priceLabel.Text
            end
            -- Chercher dans tous les TextLabels
            for _, lbl in pairs(desc:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Name:lower():find("price") then
                    return lbl.Text
                end
            end
        end
    end
    return nil
end

local enCoursDeGrab = false
local searchDots = 0

-- Trouver TOUS les ProximityPrompts dans un plot (méthode universelle)
local function TrouverTousPrompts(plot)
    local prompts = {}
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            table.insert(prompts, desc)
        end
    end
    return prompts
end

local function VerifierProtectionPlot(plot)
    return MohaHub:EstProtege(plot)
end

local function ExecuterAutoGrab()
    if enCoursDeGrab then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not DossierPlots then return end

    GrabBarGui.Enabled = true

    local mode = MohaHub.Parametres.GrabMode
    local range = MohaHub.Parametres.GrabRange
    local bestPrompt, bestCFrame, nomCible, bestDist, bestVal = nil, nil, "Cible", math.huge, -1

    local allPlots = DossierPlots:GetChildren()
    local totalPrompts = 0

    for _, plot in pairs(allPlots) do
        -- Skip notre propre plot
        local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
        local isMine = false
        if owner then
            if owner:IsA("ObjectValue") and (owner.Value == LocalPlayer or (owner.Value and owner.Value.Name == LocalPlayer.Name)) then isMine = true end
            if owner:IsA("StringValue") and (owner.Value == LocalPlayer.Name or owner.Value == tostring(LocalPlayer.UserId)) then isMine = true end
        end
        if isMine then continue end

        -- Trouver TOUS les prompts dans ce plot
        local prompts = TrouverTousPrompts(plot)
        totalPrompts = totalPrompts + #prompts

        for _, prompt in pairs(prompts) do
            -- Trouver la partie la plus proche du prompt pour le teleport
            local promptParent = prompt.Parent
            local targetPart = nil

            -- Méthode 1: Le prompt est directement dans un BasePart
            if promptParent and promptParent:IsA("BasePart") then
                targetPart = promptParent
            end

            -- Méthode 2: Le prompt est dans un Model, chercher Holder ou PrimaryPart
            if not targetPart then
                local parentModel = prompt:FindFirstAncestorWhichIsA("Model")
                if parentModel then
                    targetPart = parentModel:FindFirstChild("Holder")
                        or parentModel.PrimaryPart
                        or parentModel:FindFirstChildWhichIsA("BasePart")
                end
            end

            -- Méthode 3: Fallback - utiliser n'importe quel BasePart parent
            if not targetPart and promptParent then
                targetPart = promptParent:FindFirstChildWhichIsA("BasePart")
            end

            if targetPart then
                local dist = (root.Position - targetPart.Position).Magnitude
                if dist <= range then
                    -- Trouver le nom du brainrot
                    local brainrotName = "Brainrot"
                    -- Chercher un Model connu dans le plot
                    for _, desc in pairs(plot:GetDescendants()) do
                        if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                            brainrotName = desc.Name
                            break
                        end
                    end

                    local heroData = MohaHub.Heros[brainrotName]
                    local val = heroData and heroData.ValeurNum or 0

                    if mode == "Nearest" and dist < bestDist then
                        bestDist = dist
                        bestPrompt = prompt
                        bestCFrame = targetPart.CFrame
                        nomCible = brainrotName
                    elseif mode == "Highest" and val > bestVal then
                        bestVal = val
                        bestPrompt = prompt
                        bestCFrame = targetPart.CFrame
                        nomCible = brainrotName
                        bestDist = dist
                    end
                end
            end
        end
    end

    print("[MohaHub] Scan: " .. #allPlots .. " plots, " .. totalPrompts .. " prompts trouvés")

    -- Si pas de cible
    if not bestPrompt then
        searchDots = (searchDots % 3) + 1
        GrabStatusLabel.Text = "Recherche de cible" .. string.rep(".", searchDots)
        GrabStatusLabel.TextColor3 = COLORS.textSecondary
        GrabTimeLabel.Text = "Range: " .. range .. " studs"
        GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
        GrabBarGlow.BackgroundColor3 = COLORS.accent3
        return
    end

    -- Cible trouvée
    enCoursDeGrab = true
    GrabStatusLabel.Text = "⚡ VOL: " .. nomCible
    GrabStatusLabel.TextColor3 = COLORS.accent2
    GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
    GrabBarGlow.BackgroundColor3 = COLORS.accent2
    print("[MohaHub] Cible identifiée : " .. nomCible .. " à " .. math.floor(bestDist) .. "m")

    local temps = MohaHub.Parametres.GrabDelay
    local startTime = tick()

    local tween = TweenService:Create(GrabProgressFill, TweenInfo.new(temps, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
    tween:Play()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= temps then
            GrabTimeLabel.Text = string.format("%.1fs / %.1fs", temps, temps)
            if conn.Connected then conn:Disconnect() end
        else
            GrabTimeLabel.Text = string.format("%.1fs / %.1fs", elapsed, temps)
        end
    end)

    tween.Completed:Wait()
    if conn and conn.Connected then conn:Disconnect() end

    GrabStatusLabel.Text = "✅ Exécution du vol..."
    GrabBarGlow.BackgroundColor3 = COLORS.green

    -- ============================================================
    -- MÉTHODE SAFE: MICRO-TELEPORT + fireproximityprompt
    -- ============================================================
    local ok = false
    local originalCFrame = root.CFrame
    pcall(function()
        local oH = bestPrompt.HoldDuration
        local oM = bestPrompt.MaxActivationDistance
        local oE = bestPrompt.Enabled
        local oR = bestPrompt.RequiresLineOfSight

        bestPrompt.HoldDuration = 0
        bestPrompt.MaxActivationDistance = 9999
        bestPrompt.Enabled = true
        bestPrompt.RequiresLineOfSight = false

        -- Micro-Teleport avec offset vertical pour éviter collision
        if bestCFrame then
            root.CFrame = bestCFrame + Vector3.new(0, 2, 0)
            task.wait(0.08) -- Un peu plus lent pour assurer la synchro serveur
        end

        -- Success Verification: On regarde si un objet est ajouté au personnage
        local character = LocalPlayer.Character
        local itemsAvant = {}
        if character then
            for _, c in pairs(character:GetChildren()) do itemsAvant[c] = true end
        end

        if fireproximityprompt then
            print("[MohaHub] Tentative de grab sur : " .. nomCible)
            fireproximityprompt(bestPrompt)
            
            -- Attendre la réponse du serveur (0.3s au lieu de 0.2s)
            task.wait(0.3)
            
            if character then
                for _, c in pairs(character:GetChildren()) do
                    if not itemsAvant[c] and (c:IsA("Model") or c:IsA("Tool") or c:IsA("Accessory")) then
                        print("[MohaHub] Objet détecté dans l'inventaire : " .. c.Name)
                        ok = true
                        break
                    end
                end
            else
                ok = true
            end
        end

        -- Retour position originale immédiat
        root.CFrame = originalCFrame

        task.delay(0.2, function()
            pcall(function()
                bestPrompt.HoldDuration = oH
                bestPrompt.MaxActivationDistance = oM
                bestPrompt.Enabled = oE
                bestPrompt.RequiresLineOfSight = oR
            end)
        end)
    end)

    -- Fallback simple si détection manquée
    if not ok and fireproximityprompt then
        print("[MohaHub] Vérification manuelle de l'objet porté...")
        local character = LocalPlayer.Character
        if character then
            for _, c in pairs(character:GetChildren()) do
                if MohaHub.Heros[c.Name] then ok = true; break end
            end
        end
    end

    GrabStatusLabel.Text = ok and "✅ Vol terminé !" or "❌ Échec du vol"
    GrabStatusLabel.TextColor3 = ok and COLORS.green or COLORS.red
    if ok then print("[MohaHub] Vol RÉUSSI !") else print("[MohaHub] Vol ÉCHOUÉ") end
    
    task.wait(0.5)
    enCoursDeGrab = false
end

task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoGrab_Actif then
            pcall(ExecuterAutoGrab)
            task.wait(0.3)
        else
            GrabBarGui.Enabled = false
            task.wait(0.5)
        end
    end
end)

-- ====================== AUTO-RECALL (FIXED) ======================
-- Note: Le jeu détecte les spams de remotes, on simule donc légitimement
task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoRecall_Actif then
            -- On fire les prompts de SES PROPRES podiums
            local monPlot = nil
            for _, plot in pairs(DossierPlots:GetChildren()) do
                local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
                if owner and (owner.Value == LocalPlayer or owner.Value == LocalPlayer.Name) then
                    monPlot = plot
                    break
                end
            end
            if monPlot then
                for _, prompt in pairs(TrouverTousPrompts(monPlot)) do
                    if prompt.Name:lower():find("grab") or prompt.ActionText:lower():find("grab") then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end
        end
        task.wait(1.5)
    end
end)

-- ====================== BRAINROT ESP (FIXED) ======================
-- FIX: Ne scanner QUE les brainrots VISIBLES dans workspace.Plots
-- NE PAS scanner ReplicatedStorage (ce sont des templates invisibles)
local espFolder = Instance.new("Folder")
espFolder.Name = "MohaESP"
espFolder.Parent = CoreGui

local espObjects = {}

local RARITY_COLORS = {
    Legendary = Color3.fromRGB(255, 200, 0),
    Epic = Color3.fromRGB(180, 60, 255),
    Rare = Color3.fromRGB(0, 170, 255),
    Uncommon = Color3.fromRGB(80, 220, 120),
    Common = Color3.fromRGB(180, 180, 180),
    Normal = Color3.fromRGB(180, 180, 180),
    Mythic = Color3.fromRGB(255, 50, 100),
    Secret = Color3.fromRGB(255, 100, 255),
}

-- FIX: Vérifier qu'un model est un vrai brainrot VISIBLE (pas un template)
local function EstBrainrotVisible(model)
    if not model:IsA("Model") then return false end
    -- Doit avoir au moins une partie visible
    local hasVisible = false
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.9 then
            hasVisible = true
            break
        end
    end
    if not hasVisible then return false end
    -- Doit être dans workspace (pas dans ReplicatedStorage)
    local current = model.Parent
    while current do
        if current == ReplicatedStorage then return false end
        if current == Workspace then return true end
        current = current.Parent
    end
    return false
end

-- FIX: Lire le prix depuis le BillboardGui overhead du brainrot
local function LirePrixDepuisOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            -- Chercher le label Price
            local priceLbl = desc:FindFirstChild("Price")
            if priceLbl and (priceLbl:IsA("TextLabel") or priceLbl:IsA("TextButton")) then
                local txt = priceLbl.Text or ""
                if txt ~= "" then return txt end
            end
            -- Chercher dans tous les enfants
            for _, child in pairs(desc:GetDescendants()) do
                if (child:IsA("TextLabel") or child:IsA("TextButton")) then
                    local n = child.Name:lower()
                    if n:find("price") or n:find("prix") or n:find("value") or n:find("generation") or n:find("gen") then
                        local txt = child.Text or ""
                        if txt ~= "" and txt ~= "0" then return txt end
                    end
                end
            end
        end
    end
    return nil
end

-- FIX: Lire la rareté depuis le BillboardGui overhead
local function LireRareteDepuisOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            local rarLbl = desc:FindFirstChild("Rarity")
            if rarLbl and (rarLbl:IsA("TextLabel") or rarLbl:IsA("TextButton")) then
                local txt = rarLbl.Text or ""
                if txt ~= "" then return txt end
            end
        end
    end
    return nil
end

local function CreateESPForModel(model)
    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    if espObjects[model] then return end

    local brainrotName = model.Name
    local heroData = MohaHub.Heros[brainrotName]

    local prix = LirePrixDepuisOverhead(model)
    if not prix and heroData then prix = heroData.Prix end
    prix = prix or "?"

    local rarete = LireRareteDepuisOverhead(model)
    if not rarete and heroData then rarete = heroData.Rarete end
    rarete = rarete or "Normal"

    local rarColor = RARITY_COLORS[rarete] or COLORS.espColor

    -- ESP compact et joli
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 140, 0, 38)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 6, 16)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

    -- Bordure avec couleur de rareté
    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = rarColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15

    -- Barre colorée en haut (accent rareté)
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 2)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = rarColor
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 6)

    -- Nom du brainrot (1ère ligne)
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -8, 0, 16)
    nameL.Position = UDim2.new(0, 4, 0, 4)
    nameL.BackgroundTransparency = 1
    nameL.Text = brainrotName
    nameL.TextColor3 = rarColor
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 11
    nameL.TextScaled = true
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = bg

    -- Prix + Distance (2ème ligne)
    local distL = Instance.new("TextLabel")
    distL.Size = UDim2.new(1, -8, 0, 13)
    distL.Position = UDim2.new(0, 4, 0, 21)
    distL.BackgroundTransparency = 1
    distL.Text = tostring(prix) .. " · ..."
    distL.TextColor3 = COLORS.textSecondary
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 9
    distL.TextScaled = true
    distL.TextXAlignment = Enum.TextXAlignment.Left
    distL.Parent = bg

    espObjects[model] = {billboard = bb, distLabel = distL, part = part, prix = tostring(prix)}
end

local function ClearESP()
    for _, data in pairs(espObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    espObjects = {}
end

-- ESP update loop - FIX: UNIQUEMENT les brainrots dans workspace.Plots
task.spawn(function()
    while true do
        if MohaHub.Parametres.BrainrotESP then
            -- Scanner UNIQUEMENT workspace.Plots pour les brainrots visibles
            if DossierPlots then
                for _, plot in pairs(DossierPlots:GetChildren()) do
                    for _, desc in pairs(plot:GetDescendants()) do
                        -- Matcher le nom contre notre base de données scannée
                        if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                            if EstBrainrotVisible(desc) then
                                CreateESPForModel(desc)
                            end
                        end
                    end
                end
            end

            -- Aussi scanner les brainrots portés par les joueurs (en cours de vol)
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, desc in pairs(player.Character:GetDescendants()) do
                        if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                            if EstBrainrotVisible(desc) then
                                CreateESPForModel(desc)
                            end
                        end
                    end
                end
            end

            -- Update distances & cleanup des ESP invalides
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            for model, data in pairs(espObjects) do
                if not model.Parent or not data.part or not data.part.Parent then
                    data.billboard:Destroy()
                    espObjects[model] = nil
                elseif root and data.part then
                    local dist = math.floor((root.Position - data.part.Position).Magnitude)
                    data.distLabel.Text = (data.prix or "?") .. " · " .. dist .. "m"
                end
            end
        else
            ClearESP()
        end
        task.wait(1.5)
    end
end)
-- ====================== PLAYER ESP ======================
local playerEspFolder = Instance.new("Folder")
playerEspFolder.Name = "MohaPlayerESP"
playerEspFolder.Parent = CoreGui

local playerEspObjects = {}

local function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    if playerEspObjects[player] then return end

    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerESP_" .. player.Name
    bb.Adornee = head
    bb.Size = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = playerEspFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
    bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = COLORS.accent3
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    -- Gradient top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 3)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = COLORS.accent3
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    local tGrad = Instance.new("UIGradient")
    tGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.accent3),
        ColorSequenceKeypoint.new(0.5, COLORS.accent1),
        ColorSequenceKeypoint.new(1, COLORS.accent2)
    })
    tGrad.Parent = topBar

    -- Player icon + name
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -8, 0, 18)
    nameL.Position = UDim2.new(0, 4, 0, 5)
    nameL.BackgroundTransparency = 1
    nameL.Text = "👤 " .. player.DisplayName
    nameL.TextColor3 = COLORS.accent3
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12
    nameL.TextScaled = true
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = bg

    -- Distance + health
    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, -8, 0, 14)
    infoL.Position = UDim2.new(0, 4, 0, 24)
    infoL.BackgroundTransparency = 1
    infoL.Text = "..."
    infoL.TextColor3 = COLORS.textSecondary
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 10
    infoL.TextScaled = true
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.Parent = bg

    playerEspObjects[player] = {billboard = bb, infoLabel = infoL, player = player}
end

local function ClearPlayerESP()
    for _, data in pairs(playerEspObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    playerEspObjects = {}
end

-- ====================== BASE TIMER ESP ======================
local baseEspFolder = Instance.new("Folder")
baseEspFolder.Name = "MohaBaseESP"
baseEspFolder.Parent = CoreGui

local baseEspObjects = {}

-- Scrape timers from game's native Billboards (Plot.Purchases or Plot.AnimalPodiums)
local function ScrapeTimerFromUI(plot)
    local timers = {}
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("BillboardGui") and desc.Enabled then
            local lbl = desc:FindFirstChild("RemainingTime") or desc:FindFirstChild("Timer") or desc:FindFirstChild("Countdown")
            if lbl and (lbl:IsA("TextLabel") or lbl:IsA("TextButton")) and lbl.Visible then
                local txt = lbl.Text:gsub("<[^>]+>", "") -- Remove RichText tags
                if txt ~= "" and (txt:find(":") or txt:find("s") or txt:find("READY")) then
                    table.insert(timers, txt)
                end
            end
        end
    end
    -- Pick the most relevant timer (usually the longest or formatted x:xx)
    if #timers > 0 then
        table.sort(timers, function(a, b) return (#a > #b) end) -- Prioritize long formatted strings
        return timers[1]
    end
    return nil
end

local function CreateBaseESP(plot)
    if baseEspObjects[plot] then return end

    -- Trouver le centre du plot
    local center = nil
    for _, child in pairs(plot:GetChildren()) do
        if child:IsA("BasePart") and (child.Name == "Base" or child.Name == "Floor" or child.Name == "Ground") then
            center = child
            break
        end
    end
    if not center then
        -- Fallback: premier BasePart trouvé
        center = plot:FindFirstChildWhichIsA("BasePart")
    end
    if not center then return end

    -- Trouver le propriétaire (Système robuste)
    local ownerName = MohaHub:ExtraireProprio(plot)
    
    -- Si vraiment vide (pas de proprio et pas de brainrots), on skip
    if not ownerName and MohaHub:EstVide(plot) then 
        if baseEspObjects[plot] then
            baseEspObjects[plot].billboard:Destroy()
            baseEspObjects[plot] = nil
        end
        return 
    end
    
    ownerName = ownerName or "Base Inconnue"

    local bb = Instance.new("BillboardGui")
    bb.Name = "BaseESP_" .. plot.Name:sub(1, 8)
    bb.Adornee = center
    bb.Size = UDim2.new(0, 180, 0, 56)
    bb.StudsOffset = Vector3.new(0, 8, 0)
    bb.AlwaysOnTop = true
    bb.Parent = baseEspFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(12, 8, 22)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = COLORS.accent1
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    -- Gradient top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 3)
    topBar.BackgroundColor3 = COLORS.accent1
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    local bGrad = Instance.new("UIGradient")
    bGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.accent1),
        ColorSequenceKeypoint.new(1, COLORS.accent2)
    })
    bGrad.Parent = topBar

    -- Owner name
    local ownerL = Instance.new("TextLabel")
    ownerL.Size = UDim2.new(1, -8, 0, 16)
    ownerL.Position = UDim2.new(0, 4, 0, 5)
    ownerL.BackgroundTransparency = 1
    ownerL.Text = "🏠 " .. ownerName
    ownerL.TextColor3 = COLORS.accent1
    ownerL.Font = Enum.Font.GothamBold
    ownerL.TextSize = 11
    ownerL.TextScaled = true
    ownerL.TextXAlignment = Enum.TextXAlignment.Left
    ownerL.Parent = bg

    -- Brainrot count + distance
    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, -8, 0, 13)
    infoL.Position = UDim2.new(0, 4, 0, 21)
    infoL.BackgroundTransparency = 1
    infoL.Text = "..."
    infoL.TextColor3 = COLORS.textSecondary
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 9
    infoL.TextScaled = true
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.Parent = bg

    -- Timer (steal cooldown)
    local timerL = Instance.new("TextLabel")
    timerL.Size = UDim2.new(1, -8, 0, 13)
    timerL.Position = UDim2.new(0, 4, 0, 35)
    timerL.BackgroundTransparency = 1
    timerL.Text = "⏱ ..."
    timerL.TextColor3 = COLORS.accent2
    timerL.Font = Enum.Font.GothamBold
    timerL.TextSize = 9
    timerL.TextScaled = true
    timerL.TextXAlignment = Enum.TextXAlignment.Left
    timerL.Parent = bg

    baseEspObjects[plot] = {billboard = bb, infoLabel = infoL, timerLabel = timerL, center = center, ownerName = ownerName}
end

local function ClearBaseESP()
    for _, data in pairs(baseEspObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    baseEspObjects = {}
end

-- ====================== PLAYER ESP + BASE ESP UPDATE LOOP ======================
-- Ajout parametres dans MohaHub
MohaHub.Parametres.PlayerESP = false
MohaHub.Parametres.BaseTimerESP = false

task.spawn(function()
    while true do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        -- ===== PLAYER ESP =====
        if MohaHub.Parametres.PlayerESP then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    CreatePlayerESP(player)
                end
            end
            -- Update distances
            for player, data in pairs(playerEspObjects) do
                local pChar = player.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                local pHead = pChar and pChar:FindFirstChild("Head")
                if not pChar or not pRoot or not pHead then
                    data.billboard:Destroy()
                    playerEspObjects[player] = nil
                elseif root then
                    local dist = math.floor((root.Position - pRoot.Position).Magnitude)
                    local hum = pChar:FindFirstChildWhichIsA("Humanoid")
                    local hp = hum and math.floor(hum.Health) or "?"
                    data.infoLabel.Text = "📏 " .. dist .. "m · ❤️ " .. tostring(hp)
                    data.billboard.Adornee = pHead
                end
            end
        else
            ClearPlayerESP()
        end

        -- ===== BASE TIMER ESP =====
        if MohaHub.Parametres.BaseTimerESP and DossierPlots then
            for _, plot in pairs(DossierPlots:GetChildren()) do
                CreateBaseESP(plot)
            end
            -- Update info
            for plot, data in pairs(baseEspObjects) do
                -- Nettoyer si le plot n'existe plus
                if not plot.Parent or not data.center or not data.center.Parent then
                    data.billboard:Destroy()
                    baseEspObjects[plot] = nil
                else
                    -- Vérifier si le proprio est toujours là
                    local currentOwner = MohaHub:ExtraireProprio(plot)
                    if not currentOwner then
                        -- Plus de proprio = base vide, on supprime l'ESP
                        data.billboard:Destroy()
                        baseEspObjects[plot] = nil
                    elseif root then
                        local dist = math.floor((root.Position - data.center.Position).Magnitude)
                        -- Compter les brainrots dans ce plot
                        local brainrotCount = 0
                        for _, desc in pairs(plot:GetDescendants()) do
                            if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                                brainrotCount = brainrotCount + 1
                            end
                        end
                        data.infoLabel.Text = "🧠 " .. brainrotCount .. " brainrots · 📏 " .. dist .. "m"

                        -- Timer de protection steal
                        local isP = MohaHub:EstProtege(plot)
                        local stealTimer = plot:GetAttribute("StealTimer") or plot:GetAttribute("StealCooldown") or plot:GetAttribute("Timer")
                        
                        if isP then
                            data.timerLabel.Text = "🔒 Protégé / Privé"
                            data.timerLabel.TextColor3 = COLORS.accent1
                        elseif stealTimer and type(stealTimer) == "number" then
                            local serverTime = Workspace:GetServerTimeNow()
                            local remaining = math.max(0, stealTimer - serverTime)
                            if remaining > 0 then
                                local mins = math.floor(remaining / 60)
                                local secs = math.floor(remaining % 60)
                                data.timerLabel.Text = "⏱ Protection: " .. string.format("%d:%02d", mins, secs)
                                data.timerLabel.TextColor3 = COLORS.red
                            else
                                data.timerLabel.Text = "⏱ Vulnérable !"
                                data.timerLabel.TextColor3 = COLORS.green
                            end
                        else
                            -- Chercher un timer dans les enfants
                            local timerVal = nil
                            for _, child in pairs(plot:GetChildren()) do
                                if child:IsA("NumberValue") and (child.Name:lower():find("timer") or child.Name:lower():find("cooldown") or child.Name:lower():find("steal")) then
                                    timerVal = child.Value
                                    break
                                end
                            end
                            if timerVal and timerVal > 0 then
                                local mins = math.floor(timerVal / 60)
                                local secs = math.floor(timerVal % 60)
                                data.timerLabel.Text = "⏱ " .. string.format("%d:%02d", mins, secs)
                                data.timerLabel.TextColor3 = COLORS.accent2
                            else
                                data.timerLabel.Text = "⏱ Prêt à voler"
                                data.timerLabel.TextColor3 = COLORS.green
                            end
                        end
                    end
                end
            end
        else
            ClearBaseESP()
        end

        task.wait(1)
    end
end)

-- ====================== FIN ======================
print("[MohaHub] v9 ULTIMATE chargé ! (MODE SAFE)")
print("[MohaHub] Méthode: fireproximityprompt uniquement")
print("[MohaHub] Anti-Ban: Aucun remote UUID touché")
print("[MohaHub] ESP: Brainrot + Player + Base Timer")
print("[MohaHub] GUI Custom - Mode Safe")
end)
-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 9.0 ULTIMATE (Custom GUI - Zero Dependencies)
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
local _Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
local HubParent = (gethui and gethui()) or CoreGui

-- ====================== UTILITAIRES ======================
local function ConvertirEnNombre(valeur)
    if type(valeur) == "number" then return valeur end
    local texte = tostring(valeur):upper()
    local nombre = tonumber(texte:match("[%d%.]+")) or 0
    if texte:match("B") then nombre = nombre * 1e9
    elseif texte:match("M") then nombre = nombre * 1e6
    elseif texte:match("K") then nombre = nombre * 1e3 end
    return nombre
end

local function LerpColor(c1, c2, t)
    return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t)
end

-- ====================== DONNÉES JEUX ======================
local DossierModeles = ReplicatedStorage:WaitForChild("Models", 5)
local DossierAnimaux = DossierModeles and DossierModeles:WaitForChild("Animals", 5)
local DossierPlots = Workspace:WaitForChild("Plots", 5)

-- ====================== MODE SAFE (Anti-Ban) ======================
-- NE PAS toucher aux remotes UUID directement = BAN INSTANT
-- Le jeu valide les tokens avec SHA256 + timestamps serveur
-- SEULE méthode safe: fireproximityprompt (passe par le code légitime du jeu)

-- ====================== MOTEUR MOHA HUB ======================
local MohaHub = {
    Heros = {}, ListeNomsHeros = {},
    Parametres = {
        AutoGrab_Actif = false, GrabMode = "Highest", GrabDelay = 1.0,
        GrabRange = 10, AfficherCercle = true, AutoRecall_Actif = false,
        BrainrotESP = false, GrabBrainrots = true
    }
}

function MohaHub:ExtraireProprio(plot)
    if not plot then return nil end
    local o = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner") or plot:GetAttribute("Owner") or plot:GetAttribute("OwnerName")
    if type(o) == "string" and o ~= "" and o ~= "Personne" then return o end
    if typeof(o) == "Instance" then
        if o:IsA("ObjectValue") and o.Value then 
            local val = o.Value
            return (val:IsA("Player") and val.DisplayName) or val.Name 
        end
        if o:IsA("StringValue") and o.Value ~= "" and o.Value ~= "Personne" then return o.Value end
    end
    -- Fallback: Chercher un StringValue ou ObjectValue enfant avec "Owner" dans le nom
    for _, v in pairs(plot:GetChildren()) do
        if v.Name:lower():find("owner") then
            if v:IsA("StringValue") and v.Value ~= "" then return v.Value end
            if v:IsA("ObjectValue") and v.Value then 
                local val = v.Value
                return (val:IsA("Player") and val.DisplayName) or val.Name
            end
        end
    end
    return nil
end

function MohaHub:EstVide(plot)
    if not plot then return true end
    -- Si on trouve un proprio, c'est pas vide
    if self:ExtraireProprio(plot) then return false end
    -- Si on trouve au moins un brainrot, c'est pas vide
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("Model") and self.Heros[desc.Name] then return false end
    end
    -- Si on trouve un bouton de "Réclamation", c'est vide
    if plot:FindFirstChild("Claim") or plot:FindFirstChild("ClaimPlot") then return true end
    return true
end

function MohaHub:EstProtege(plot)
    if not plot then return false end
    -- Check uniquement les Attributs du plot (pas de scan récursif = pas de faux positifs)
    if plot:GetAttribute("ShieldActive") == true then return true end
    if plot:GetAttribute("Locked") == true then return true end
    if plot:GetAttribute("Private") == true then return true end
    if plot:GetAttribute("StealProtected") == true then return true end
    -- Check ForceField direct (pas récursif)
    if plot:FindFirstChildOfClass("ForceField") then return true end
    return false
end

function MohaHub:AjouterHero(nom, config)
    if not config.ValeurNum then
        if config.Prix then config.ValeurNum = ConvertirEnNombre(config.Prix)
        elseif config.Gen then config.ValeurNum = config.Gen
        else config.ValeurNum = 0 end
    end
    if not self.Heros[nom] then table.insert(self.ListeNomsHeros, nom) end
    self.Heros[nom] = config
end

-- Héros de base
MohaHub:AjouterHero("Glorbo Fruttodrillo", {Rarete="Legendary", Prix="200K", Gen=938})
MohaHub:AjouterHero("Trulimero Trulicina", {Rarete="Epic", Prix="20K", Gen=188})
MohaHub:AjouterHero("Perochello Lemonchello", {Rarete="Epic", Prix="27.5K", Gen=160})
MohaHub:AjouterHero("Cappuccino Assassino", {Rarete="Epic", Prix="10K", Gen=113})
MohaHub:AjouterHero("Brr Brr Patapim", {Rarete="Epic", Prix="15K", Gen=100})

-- ====================== SCAN BRAINROTS ======================
local BrainrotsScannes = {}
task.spawn(function()
    task.wait(1)
    if DossierAnimaux then
        for _, modele in pairs(DossierAnimaux:GetChildren()) do
            local op = modele:FindFirstChild("Price") or modele:FindFirstChild("Prix") or modele:FindFirstChild("Value")
            local or_ = modele:FindFirstChild("Rarity") or modele:FindFirstChild("Rarete")
            local pT = op and tostring(op.Value) or "0"
            local rT = or_ and tostring(or_.Value) or "Normal"
            local vR = ConvertirEnNombre(pT)
            table.insert(BrainrotsScannes, {Nom=modele.Name, Rarete=rT, PrixStr=pT, ValeurDeTri=vR})
        end
        table.sort(BrainrotsScannes, function(a,b) return a.ValeurDeTri > b.ValeurDeTri end)
        for _, b in ipairs(BrainrotsScannes) do
            MohaHub:AjouterHero(b.Nom, {Rarete=b.Rarete, Prix=b.PrixStr, ValeurNum=b.ValeurDeTri})
        end
        print("[MohaHub] Scan: "..#BrainrotsScannes.." brainrots trouvés.")
    end
end)

-- ====================== COULEURS THÈME ======================
local COLORS = {
    bg = Color3.fromRGB(12, 12, 18),
    bgLight = Color3.fromRGB(22, 22, 32),
    card = Color3.fromRGB(28, 28, 40),
    cardHover = Color3.fromRGB(35, 35, 50),
    accent1 = Color3.fromRGB(130, 80, 255),   -- Violet
    accent2 = Color3.fromRGB(255, 60, 130),    -- Rose
    accent3 = Color3.fromRGB(0, 200, 255),     -- Cyan
    green = Color3.fromRGB(50, 220, 120),
    red = Color3.fromRGB(255, 60, 80),
    textPrimary = Color3.fromRGB(240, 240, 255),
    textSecondary = Color3.fromRGB(150, 150, 180),
    border = Color3.fromRGB(60, 60, 90),
    grabBar = Color3.fromRGB(130, 80, 255),
    espColor = Color3.fromRGB(255, 180, 0),
}

-- ====================== CRÉATION GUI PRINCIPAL ======================
task.defer(function()
    -- Nettoyer ancien GUI
    for _, g in pairs(HubParent:GetChildren()) do
        if g.Name == "MohaHubUltimate" or g.Name == "MohaGrabHUD" then g:Destroy() end
    end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MohaHubUltimate"
ScreenGui.Parent = HubParent
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- ====================== BOUTON TOGGLE ======================
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleBtn"
ToggleBtn.Size = UDim2.new(0, 50, 0, 50)
ToggleBtn.Position = UDim2.new(0, 15, 0.5, -25)
ToggleBtn.BackgroundColor3 = COLORS.accent1
ToggleBtn.Text = "M"
ToggleBtn.TextColor3 = Color3.new(1,1,1)
ToggleBtn.TextSize = 22
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.BorderSizePixel = 0
ToggleBtn.Parent = ScreenGui
ToggleBtn.ZIndex = 100
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)

local toggleGlow = Instance.new("UIStroke")
toggleGlow.Parent = ToggleBtn
toggleGlow.Color = COLORS.accent1
toggleGlow.Thickness = 2
toggleGlow.Transparency = 0.3

-- Animation pulsation bouton
task.spawn(function()
    while ToggleBtn.Parent do
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.7}):Play()
        task.wait(1.5)
        TweenService:Create(toggleGlow, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}):Play()
        task.wait(1.5)
    end
end)

-- ====================== PANEL PRINCIPAL ======================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 480)
MainFrame.Position = UDim2.new(0.5, -210, 0.5, -240)
MainFrame.BackgroundColor3 = COLORS.bg
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false
MainFrame.Parent = ScreenGui
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 16)

local mainStroke = Instance.new("UIStroke")
mainStroke.Parent = MainFrame
mainStroke.Color = COLORS.accent1
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.5

-- Gradient de fond subtil
local bgGradient = Instance.new("UIGradient")
bgGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 10, 30)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 8, 15))
})
bgGradient.Rotation = 145
bgGradient.Parent = MainFrame

-- Animation pulsation du cadre
task.spawn(function()
    while MainFrame.Parent do
        if MainFrame.Visible then
            TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.2}):Play()
            task.wait(2)
            TweenService:Create(mainStroke, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Transparency = 0.7}):Play()
            task.wait(2)
        else
            task.wait(1)
        end
    end
end)

-- ====================== HEADER ======================
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 55)
Header.BackgroundColor3 = Color3.fromRGB(18, 15, 30)
Header.BorderSizePixel = 0
Header.Parent = MainFrame
Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 16)

local headerGrad = Instance.new("UIGradient")
headerGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 15, 35)),
    ColorSequenceKeypoint.new(1, COLORS.accent2)
})
headerGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.6),
    NumberSequenceKeypoint.new(0.3, 0.95),
    NumberSequenceKeypoint.new(0.7, 0.95),
    NumberSequenceKeypoint.new(1, 0.6)
})
headerGrad.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -60, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ MOHA HUB v9"
TitleLabel.TextColor3 = COLORS.textPrimary
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.TextSize = 20
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local SubTitle = Instance.new("TextLabel")
SubTitle.Size = UDim2.new(0, 200, 0, 14)
SubTitle.Position = UDim2.new(1, -210, 0.5, -7)
SubTitle.BackgroundTransparency = 1
SubTitle.Text = "ULTIMATE EDITION"
SubTitle.TextColor3 = COLORS.accent2
SubTitle.Font = Enum.Font.GothamBold
SubTitle.TextSize = 10
SubTitle.TextXAlignment = Enum.TextXAlignment.Right
SubTitle.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -45, 0.5, -17)
CloseBtn.BackgroundColor3 = COLORS.red
CloseBtn.BackgroundTransparency = 0.8
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = COLORS.red
CloseBtn.TextSize = 16
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- ====================== ONGLETS ======================
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, -20, 0, 36)
TabBar.Position = UDim2.new(0, 10, 0, 60)
TabBar.BackgroundColor3 = COLORS.bgLight
TabBar.BorderSizePixel = 0
TabBar.Parent = MainFrame
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 10)

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.Padding = UDim.new(0, 4)
tabLayout.Parent = TabBar

local tabPad = Instance.new("UIPadding")
tabPad.PaddingLeft = UDim.new(0, 4)
tabPad.PaddingTop = UDim.new(0, 4)
tabPad.Parent = TabBar

local TAB_NAMES = {"⚔️ Steal", "🧠 ESP", "🛡️ Défense", "ℹ️ Info"}
local TabButtons = {}
local TabPages = {}
local _currentTab = 1

-- Pages container
local PagesContainer = Instance.new("Frame")
PagesContainer.Size = UDim2.new(1, -20, 1, -110)
PagesContainer.Position = UDim2.new(0, 10, 0, 102)
PagesContainer.BackgroundTransparency = 1
PagesContainer.Parent = MainFrame
PagesContainer.ClipsDescendants = true

for i, tabName in ipairs(TAB_NAMES) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 95, 0, 28)
    btn.BackgroundColor3 = i == 1 and COLORS.accent1 or COLORS.card
    btn.BackgroundTransparency = i == 1 and 0.2 or 0.5
    btn.Text = tabName
    btn.TextColor3 = i == 1 and Color3.new(1,1,1) or COLORS.textSecondary
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.BorderSizePixel = 0
    btn.Parent = TabBar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    TabButtons[i] = btn

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = COLORS.accent1
    page.BorderSizePixel = 0
    page.Visible = (i == 1)
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Parent = PagesContainer
    TabPages[i] = page

    local pl = Instance.new("UIListLayout")
    pl.Padding = UDim.new(0, 8)
    pl.Parent = page

    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, 5)
    pp.PaddingBottom = UDim.new(0, 10)
    pp.Parent = page

    btn.MouseButton1Click:Connect(function()
        local _currentTab = i
        for j, b in ipairs(TabButtons) do
            local active = (j == i)
            TweenService:Create(b, TweenInfo.new(0.25), {
                BackgroundColor3 = active and COLORS.accent1 or COLORS.card,
                BackgroundTransparency = active and 0.2 or 0.5,
                TextColor3 = active and Color3.new(1,1,1) or COLORS.textSecondary
            }):Play()
            TabPages[j].Visible = active
        end
    end)
end

-- ====================== COMPOSANTS UI ======================
local function CreateSection(page, title)
    local sec = Instance.new("Frame")
    sec.Size = UDim2.new(1, 0, 0, 28)
    sec.BackgroundTransparency = 1
    sec.Parent = page
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "  "..title
    lbl.TextColor3 = COLORS.accent3
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = sec
    return sec
end

local function CreateToggle(page, name, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local toggleFrame = Instance.new("Frame")
    toggleFrame.Size = UDim2.new(0, 44, 0, 24)
    toggleFrame.Position = UDim2.new(1, -56, 0.5, -12)
    toggleFrame.BackgroundColor3 = default and COLORS.green or Color3.fromRGB(60,60,75)
    toggleFrame.BorderSizePixel = 0
    toggleFrame.Parent = container
    Instance.new("UICorner", toggleFrame).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    circle.BackgroundColor3 = Color3.new(1,1,1)
    circle.BorderSizePixel = 0
    circle.Parent = toggleFrame
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local state = default
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = container
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(toggleFrame, TweenInfo.new(0.3), {
            BackgroundColor3 = state and COLORS.green or Color3.fromRGB(60,60,75)
        }):Play()
        TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
        callback(state)
    end)
    return container
end

local function CreateSlider(page, name, min, max, default, suffix, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 56)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local valLbl = Instance.new("TextLabel")
    valLbl.Size = UDim2.new(0, 60, 0, 20)
    valLbl.Position = UDim2.new(1, -70, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)..suffix
    valLbl.TextColor3 = COLORS.accent1
    valLbl.Font = Enum.Font.GothamBold
    valLbl.TextSize = 13
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Parent = container

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 0, 24)
    lbl.Position = UDim2.new(0, 14, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -28, 0, 6)
    track.Position = UDim2.new(0, 14, 0, 38)
    track.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    track.BorderSizePixel = 0
    track.Parent = container
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    local pct = (default - min) / (max - min)
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = COLORS.accent1
    fill.BorderSizePixel = 0
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new(pct, -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knobStroke = Instance.new("UIStroke")
    knobStroke.Parent = knob
    knobStroke.Color = COLORS.accent1
    knobStroke.Thickness = 2

    local dragging = false
    local sliderBtn = Instance.new("TextButton")
    sliderBtn.Size = UDim2.new(1, 0, 0, 20)
    sliderBtn.Position = UDim2.new(0, 0, 0, 28)
    sliderBtn.BackgroundTransparency = 1
    sliderBtn.Text = ""
    sliderBtn.Parent = container

    sliderBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            local rel = math.clamp((input.Position.X - absPos) / absSize, 0, 1)
            local val = min + (max - min) * rel
            -- snap
            if max <= 5 then val = math.floor(val * 10 + 0.5) / 10
            else val = math.floor(val + 0.5) end
            local p2 = (val - min) / (max - min)
            fill.Size = UDim2.new(p2, 0, 1, 0)
            knob.Position = UDim2.new(p2, -8, 0.5, -8)
            valLbl.Text = tostring(val)..suffix
            callback(val)
        end
    end)
    return container
end

local function CreateDropdown(page, name, options, default, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 42)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = COLORS.textPrimary
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = container

    local selected = default
    local currentIdx = 1
    for i, v in ipairs(options) do if v == default then currentIdx = i end end

    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 120, 0, 28)
    selectBtn.Position = UDim2.new(1, -132, 0.5, -14)
    selectBtn.BackgroundColor3 = COLORS.accent1
    selectBtn.BackgroundTransparency = 0.7
    selectBtn.Text = "◀ "..selected.." ▶"
    selectBtn.TextColor3 = COLORS.textPrimary
    selectBtn.TextSize = 12
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.BorderSizePixel = 0
    selectBtn.Parent = container
    Instance.new("UICorner", selectBtn).CornerRadius = UDim.new(0, 8)

    selectBtn.MouseButton1Click:Connect(function()
        currentIdx = currentIdx % #options + 1
        selected = options[currentIdx]
        selectBtn.Text = "◀ "..selected.." ▶"
        callback(selected)
    end)
    return container
end

local function CreateInfoCard(page, title, content)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 80)
    container.BackgroundColor3 = COLORS.card
    container.BackgroundTransparency = 0.2
    container.BorderSizePixel = 0
    container.Parent = page
    Instance.new("UICorner", container).CornerRadius = UDim.new(0, 10)

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -20, 0, 22)
    t.Position = UDim2.new(0, 12, 0, 6)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = COLORS.accent1
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = container

    local c = Instance.new("TextLabel")
    c.Size = UDim2.new(1, -20, 1, -30)
    c.Position = UDim2.new(0, 12, 0, 28)
    c.BackgroundTransparency = 1
    c.Text = content
    c.TextColor3 = COLORS.textSecondary
    c.Font = Enum.Font.Gotham
    c.TextSize = 11
    c.TextXAlignment = Enum.TextXAlignment.Left
    c.TextYAlignment = Enum.TextYAlignment.Top
    c.TextWrapped = true
    c.Parent = container
    return container
end

-- ====================== REMPLISSAGE DES PAGES ======================
-- Page 1 : STEAL
local p1 = TabPages[1]
CreateSection(p1, "AUTO-GRAB ENGINE")
CreateToggle(p1, "🟢 Activer Auto Grab", false, function(v) MohaHub.Parametres.AutoGrab_Actif = v end)
CreateToggle(p1, "🧠 Voler aussi les Brainrots", true, function(v) MohaHub.Parametres.GrabBrainrots = v end)
CreateToggle(p1, "🔮 Afficher cercle visuel", true, function(v) MohaHub.Parametres.AfficherCercle = v end)
CreateSlider(p1, "📏 Range (Studs)", 1, 20, 10, " studs", function(v) MohaHub.Parametres.GrabRange = v end)
CreateSlider(p1, "⏱️ Délai de vol", 0.1, 5.0, 1.0, "s", function(v) MohaHub.Parametres.GrabDelay = v end)
CreateDropdown(p1, "🎯 Priorité", {"Highest", "Nearest"}, "Highest", function(v) MohaHub.Parametres.GrabMode = v end)

-- Page 2 : ESP
local p2 = TabPages[2]
CreateSection(p2, "VISUELS")
CreateToggle(p2, "👁️ Brainrot ESP", false, function(v) MohaHub.Parametres.BrainrotESP = v end)
CreateToggle(p2, "👤 Player ESP", false, function(v) MohaHub.Parametres.PlayerESP = v end)
CreateToggle(p2, "🏠 Base Timer ESP", false, function(v) MohaHub.Parametres.BaseTimerESP = v end)

CreateInfoCard(p2, "ℹ️ Info ESP", "L'ESP Player affiche les pseudos et distances.\nL'ESP Base affiche le proprio and le timer de vol.\nLe Brainrot ESP scanne les models invisibles.")

-- Page 3 : DEFENSE
local p3 = TabPages[3]
CreateSection(p3, "BOUCLIER ANTI-STEAL")
CreateToggle(p3, "🛡️ Activer Auto-Recall", false, function(v) MohaHub.Parametres.AutoRecall_Actif = v end)
CreateInfoCard(p3, "ℹ️ Auto-Recall", "Rappelle automatiquement vos héros volés en spammant le Remote Grab sur vos podiums.")

-- Page 4 : INFO
local p4 = TabPages[4]
CreateSection(p4, "MOHA HUB v9 ULTIMATE")
CreateInfoCard(p4, "⚡ Moteur de vol", "Mode SAFE: fireproximityprompt uniquement\nAnti-Ban: Pas de remotes UUID")
CreateInfoCard(p4, "📡 Status", "✅ Mode Safe actif - Pas de ban")
CreateInfoCard(p4, "🧠 Brainrots", "Scan depuis ReplicatedStorage.Models.Animals\nNombre détecté: "..tostring(#BrainrotsScannes))

-- ====================== BARRE DE GRAB EN HAUT (TOUJOURS VISIBLE) ======================
-- Nettoyer ancienne barre
for _, g in pairs(HubParent:GetChildren()) do
    if g.Name == "MohaGrabBar" then g:Destroy() end
end

local GrabBarGui = Instance.new("ScreenGui")
GrabBarGui.Name = "MohaGrabBar"
GrabBarGui.Parent = HubParent
GrabBarGui.ResetOnSpawn = false
GrabBarGui.Enabled = false
GrabBarGui.DisplayOrder = 999

local GrabBarFrame = Instance.new("Frame")
GrabBarFrame.Size = UDim2.new(0, 300, 0, 42)
GrabBarFrame.Position = UDim2.new(0.5, -150, 0, 5)
GrabBarFrame.BackgroundColor3 = Color3.fromRGB(8, 6, 18)
GrabBarFrame.BorderSizePixel = 0
GrabBarFrame.Active = false -- Empêche d'être cliqué/déplacé
GrabBarFrame.Parent = GrabBarGui

local barCorner = Instance.new("UICorner", GrabBarFrame)
barCorner.CornerRadius = UDim.new(0, 10)

local grabBarStroke = Instance.new("UIStroke")
grabBarStroke.Parent = GrabBarFrame
grabBarStroke.Color = COLORS.accent1
grabBarStroke.Thickness = 1.2
grabBarStroke.Transparency = 0.6

local grabBarGrad = Instance.new("UIGradient")
grabBarGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 10, 50)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 6, 18)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 10, 50))
})
grabBarGrad.Parent = GrabBarFrame

-- Ligne lumineuse en bas de la barre
local GrabBarGlow = Instance.new("Frame")
GrabBarGlow.Size = UDim2.new(1, 0, 0, 2)
GrabBarGlow.Position = UDim2.new(0, 0, 1, -2)
GrabBarGlow.BackgroundColor3 = COLORS.accent1
GrabBarGlow.BorderSizePixel = 0
GrabBarGlow.Parent = GrabBarFrame
local glowGrad = Instance.new("UIGradient")
glowGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, COLORS.accent2),
    ColorSequenceKeypoint.new(1, COLORS.accent3)
})
glowGrad.Parent = GrabBarGlow

-- Barre de progression
local GrabProgressBg = Instance.new("Frame")
GrabProgressBg.Size = UDim2.new(1, -24, 0, 8)
GrabProgressBg.Position = UDim2.new(0, 12, 1, -14)
GrabProgressBg.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
GrabProgressBg.BorderSizePixel = 0
GrabProgressBg.Parent = GrabBarFrame
Instance.new("UICorner", GrabProgressBg).CornerRadius = UDim.new(1, 0)

local GrabProgressFill = Instance.new("Frame")
GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
GrabProgressFill.BackgroundColor3 = COLORS.accent1
GrabProgressFill.BorderSizePixel = 0
GrabProgressFill.Parent = GrabProgressBg
Instance.new("UICorner", GrabProgressFill).CornerRadius = UDim.new(1, 0)

local grabFillGrad = Instance.new("UIGradient")
grabFillGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, COLORS.accent1),
    ColorSequenceKeypoint.new(0.5, COLORS.accent2),
    ColorSequenceKeypoint.new(1, COLORS.accent3)
})
grabFillGrad.Parent = GrabProgressFill

-- Icône animée
local GrabIcon = Instance.new("TextLabel")
GrabIcon.Size = UDim2.new(0, 30, 0, 24)
GrabIcon.Position = UDim2.new(0, 10, 0, 2)
GrabIcon.BackgroundTransparency = 1
GrabIcon.Text = "⚡"
GrabIcon.TextSize = 18
GrabIcon.Font = Enum.Font.GothamBold
GrabIcon.Parent = GrabBarFrame

-- Status du grab
local GrabStatusLabel = Instance.new("TextLabel")
GrabStatusLabel.Size = UDim2.new(0.5, 0, 0, 24)
GrabStatusLabel.Position = UDim2.new(0, 40, 0, 2)
GrabStatusLabel.BackgroundTransparency = 1
GrabStatusLabel.Text = "Recherche de cible..."
GrabStatusLabel.TextColor3 = COLORS.textPrimary
GrabStatusLabel.Font = Enum.Font.GothamBold
GrabStatusLabel.TextSize = 14
GrabStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
GrabStatusLabel.Parent = GrabBarFrame

-- Timer
local GrabTimeLabel = Instance.new("TextLabel")
GrabTimeLabel.Size = UDim2.new(0, 120, 0, 24)
GrabTimeLabel.Position = UDim2.new(1, -130, 0, 2)
GrabTimeLabel.BackgroundTransparency = 1
GrabTimeLabel.Text = ""
GrabTimeLabel.TextColor3 = COLORS.accent3
GrabTimeLabel.Font = Enum.Font.GothamBold
GrabTimeLabel.TextSize = 14
GrabTimeLabel.TextXAlignment = Enum.TextXAlignment.Right
GrabTimeLabel.Parent = GrabBarFrame

-- ====================== AURA VISUEL ======================
local CercleAura = Instance.new("Part")
CercleAura.Shape = Enum.PartType.Cylinder
CercleAura.Color = COLORS.accent1
CercleAura.Material = Enum.Material.Neon
CercleAura.Transparency = 0.7
CercleAura.Anchored = true
CercleAura.CanCollide = false
CercleAura.CastShadow = false

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if MohaHub.Parametres.AfficherCercle and MohaHub.Parametres.AutoGrab_Actif and root then
        CercleAura.Position = root.Position - Vector3.new(0, 2.5, 0)
        CercleAura.Orientation = Vector3.new(0, 0, 90)
        local d = MohaHub.Parametres.GrabRange * 2
        CercleAura.Size = Vector3.new(0.2, d, d)
        if not CercleAura.Parent then CercleAura.Parent = Workspace end
    else
        if CercleAura.Parent then CercleAura.Parent = nil end
    end
end)

-- ====================== TOGGLE OPEN/CLOSE ======================
local guiOpen = false
MainFrame.BackgroundTransparency = 1
MainFrame.Size = UDim2.new(0, 420, 0, 0)

ToggleBtn.MouseButton1Click:Connect(function()
    guiOpen = not guiOpen
    if guiOpen then
        MainFrame.Visible = true
        TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 420, 0, 480), BackgroundTransparency = 0}):Play()
    else
        TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 420, 0, 0), BackgroundTransparency = 1}):Play()
        task.delay(0.4, function() if not guiOpen then MainFrame.Visible = false end end)
    end
    
    TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {
        BackgroundColor3 = guiOpen and COLORS.accent2 or COLORS.accent1,
        Rotation = guiOpen and 90 or 0
    }):Play()
end)

CloseBtn.MouseButton1Click:Connect(function()
    guiOpen = false
    TweenService:Create(MainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(0, 420, 0, 0), BackgroundTransparency = 1}):Play()
    task.delay(0.4, function() MainFrame.Visible = false end)
    
    TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {
        BackgroundColor3 = COLORS.accent1, Rotation = 0
    }):Play()
end)

-- Drag support
local dragging, dragStart, startPos
Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
    end
end)
Header.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

-- ====================== AUTO GRAB ENGINE (FIXED) ======================
-- FIX: Trouver les brainrots VISIBLES sur un plot (pas les templates)
-- Les brainrots sont des Models enfants du plot qui matchent les noms scannés
local function TrouverBrainrotsVisibles(plot)
    local brainrots = {}
    for _, child in pairs(plot:GetDescendants()) do
        if child:IsA("Model") and MohaHub.Heros[child.Name] then
            -- Vérifier que le model a des parties visibles (pas invisible)
            local hasVisiblePart = false
            local primaryPart = child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart")
            if primaryPart then
                for _, p in pairs(child:GetDescendants()) do
                    if p:IsA("BasePart") and p.Transparency < 0.9 then
                        hasVisiblePart = true
                        break
                    end
                end
            end
            if hasVisiblePart then
                table.insert(brainrots, child)
            end
        end
    end
    return brainrots
end

local function ObtenirMeilleurBrainrot(plot, mode, rootPos)
    local brainrots = TrouverBrainrotsVisibles(plot)
    local best = nil
    local bestVal = -1
    local bestDist = math.huge
    local bestName = "Inconnu"

    for _, brainrot in pairs(brainrots) do
        local hd = MohaHub.Heros[brainrot.Name]
        if hd then
            local part = brainrot.PrimaryPart or brainrot:FindFirstChildWhichIsA("BasePart")
            local dist = part and (rootPos - part.Position).Magnitude or math.huge

            if mode == "Highest" then
                if hd.ValeurNum and hd.ValeurNum > bestVal then
                    bestVal = hd.ValeurNum
                    best = brainrot
                    bestName = brainrot.Name
                end
            elseif mode == "Nearest" then
                if dist < bestDist then
                    bestDist = dist
                    best = brainrot
                    bestName = brainrot.Name
                end
            end
        end
    end
    return best, bestName, bestVal
end

-- FIX: Lire le prix depuis le overhead BillboardGui du brainrot sur le plot
local function LirePrixOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            local priceLabel = desc:FindFirstChild("Price") or desc:FindFirstChild("prix")
            if priceLabel and priceLabel:IsA("TextLabel") then
                return priceLabel.Text
            end
            -- Chercher dans tous les TextLabels
            for _, lbl in pairs(desc:GetDescendants()) do
                if lbl:IsA("TextLabel") and lbl.Name:lower():find("price") then
                    return lbl.Text
                end
            end
        end
    end
    return nil
end

local enCoursDeGrab = false
local searchDots = 0

-- Trouver TOUS les ProximityPrompts dans un plot (méthode universelle)
local function TrouverTousPrompts(plot)
    local prompts = {}
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            table.insert(prompts, desc)
        end
    end
    return prompts
end

local function VerifierProtectionPlot(plot)
    return MohaHub:EstProtege(plot)
end

local function ExecuterAutoGrab()
    if enCoursDeGrab then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not DossierPlots then return end

    GrabBarGui.Enabled = true

    local mode = MohaHub.Parametres.GrabMode
    local range = MohaHub.Parametres.GrabRange
    local bestPrompt, bestCFrame, nomCible, bestDist, bestVal = nil, nil, "Cible", math.huge, -1

    print("[MohaHub] Analyse de " .. #DossierPlots:GetChildren() .. " plots...")

    for _, plot in pairs(DossierPlots:GetChildren()) do
        -- Skip notre propre plot
        local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
        local isMine = false
        if owner then
            if owner:IsA("ObjectValue") and (owner.Value == LocalPlayer or (owner.Value and owner.Value.Name == LocalPlayer.Name)) then isMine = true end
            if owner:IsA("StringValue") and (owner.Value == LocalPlayer.Name or owner.Value == tostring(LocalPlayer.UserId)) then isMine = true end
        end
        if isMine then continue end

        -- Vérifier si le plot est protégé/fermé (système exhaustif)
        if VerifierProtectionPlot(plot) then continue end

        -- Trouver prompts de vol
        local prompts = TrouverTousPrompts(plot)
        for _, prompt in pairs(prompts) do
            -- Accepter TOUS les prompts (le jeu peut avoir n'importe quel texte)

            local parentModel = prompt:FindFirstAncestorWhichIsA("Model")
            local holderPart = parentModel and parentModel:FindFirstChild("Holder")
            local targetCFrame = nil
            
            if holderPart then
                local attachment = holderPart:FindFirstChild("BrainrotRootPartAttachement")
                targetCFrame = attachment and attachment.WorldCFrame or holderPart.CFrame
                
                local dist = (root.Position - holderPart.Position).Magnitude
                if dist <= range then
                    -- Trouver le brainrot spécifiquement lié à ce prompt
                    local brainrotName = parentModel.Name
                    -- Si le parent s'appelle "Prompt" ou "Interaction", on cherche un model frère
                    if brainrotName == "Prompt" or brainrotName == "Interaction" then
                        local sibling = parentModel.Parent:FindFirstChildWhichIsA("Model")
                        if sibling then brainrotName = sibling.Name end
                    end

                    local heroData = MohaHub.Heros[brainrotName]
                    local val = heroData and heroData.ValeurNum or 0

                    if mode == "Nearest" and dist < bestDist then
                        bestDist = dist
                        bestPrompt = prompt
                        bestCFrame = targetCFrame
                        nomCible = brainrotName
                    elseif mode == "Highest" and val > bestVal then
                        bestVal = val
                        bestPrompt = prompt
                        bestCFrame = targetCFrame
                        nomCible = brainrotName
                        bestDist = dist
                    end
                end
            end
        end
    end

    -- Si pas de cible
    if not bestPrompt then
        searchDots = (searchDots % 3) + 1
        GrabStatusLabel.Text = "Recherche de cible" .. string.rep(".", searchDots)
        GrabStatusLabel.TextColor3 = COLORS.textSecondary
        GrabTimeLabel.Text = "Range: " .. range .. " studs"
        GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
        GrabBarGlow.BackgroundColor3 = COLORS.accent3
        return
    end

    -- Cible trouvée
    enCoursDeGrab = true
    GrabStatusLabel.Text = "⚡ VOL: " .. nomCible
    GrabStatusLabel.TextColor3 = COLORS.accent2
    GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)
    GrabBarGlow.BackgroundColor3 = COLORS.accent2
    print("[MohaHub] Cible identifiée : " .. nomCible .. " à " .. math.floor(bestDist) .. "m")

    local temps = MohaHub.Parametres.GrabDelay
    local startTime = tick()

    local tween = TweenService:Create(GrabProgressFill, TweenInfo.new(temps, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
    tween:Play()

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= temps then
            GrabTimeLabel.Text = string.format("%.1fs / %.1fs", temps, temps)
            if conn.Connected then conn:Disconnect() end
        else
            GrabTimeLabel.Text = string.format("%.1fs / %.1fs", elapsed, temps)
        end
    end)

    tween.Completed:Wait()
    if conn and conn.Connected then conn:Disconnect() end

    GrabStatusLabel.Text = "✅ Exécution du vol..."
    GrabBarGlow.BackgroundColor3 = COLORS.green

    -- ============================================================
    -- MÉTHODE SAFE: MICRO-TELEPORT + fireproximityprompt
    -- ============================================================
    local ok = false
    local originalCFrame = root.CFrame
    pcall(function()
        local oH = bestPrompt.HoldDuration
        local oM = bestPrompt.MaxActivationDistance
        local oE = bestPrompt.Enabled
        local oR = bestPrompt.RequiresLineOfSight

        bestPrompt.HoldDuration = 0
        bestPrompt.MaxActivationDistance = 9999
        bestPrompt.Enabled = true
        bestPrompt.RequiresLineOfSight = false

        -- Micro-Teleport avec offset vertical pour éviter collision
        if bestCFrame then
            root.CFrame = bestCFrame + Vector3.new(0, 2, 0)
            task.wait(0.08) -- Un peu plus lent pour assurer la synchro serveur
        end

        -- Success Verification: On regarde si un objet est ajouté au personnage
        local character = LocalPlayer.Character
        local itemsAvant = {}
        if character then
            for _, c in pairs(character:GetChildren()) do itemsAvant[c] = true end
        end

        if fireproximityprompt then
            print("[MohaHub] Tentative de grab sur : " .. nomCible)
            fireproximityprompt(bestPrompt)
            
            -- Attendre la réponse du serveur (0.3s au lieu de 0.2s)
            task.wait(0.3)
            
            if character then
                for _, c in pairs(character:GetChildren()) do
                    if not itemsAvant[c] and (c:IsA("Model") or c:IsA("Tool") or c:IsA("Accessory")) then
                        print("[MohaHub] Objet détecté dans l'inventaire : " .. c.Name)
                        ok = true
                        break
                    end
                end
            else
                ok = true
            end
        end

        -- Retour position originale immédiat
        root.CFrame = originalCFrame

        task.delay(0.2, function()
            pcall(function()
                bestPrompt.HoldDuration = oH
                bestPrompt.MaxActivationDistance = oM
                bestPrompt.Enabled = oE
                bestPrompt.RequiresLineOfSight = oR
            end)
        end)
    end)

    -- Fallback simple si détection manquée
    if not ok and fireproximityprompt then
        print("[MohaHub] Vérification manuelle de l'objet porté...")
        local character = LocalPlayer.Character
        if character then
            for _, c in pairs(character:GetChildren()) do
                if MohaHub.Heros[c.Name] then ok = true; break end
            end
        end
    end

    GrabStatusLabel.Text = ok and "✅ Vol terminé !" or "❌ Échec du vol"
    GrabStatusLabel.TextColor3 = ok and COLORS.green or COLORS.red
    if ok then print("[MohaHub] Vol RÉUSSI !") else print("[MohaHub] Vol ÉCHOUÉ") end
    
    task.wait(0.5)
    enCoursDeGrab = false
end

task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoGrab_Actif then
            pcall(ExecuterAutoGrab)
            task.wait(0.3)
        else
            GrabBarGui.Enabled = false
            task.wait(0.5)
        end
    end
end)

-- ====================== AUTO-RECALL (FIXED) ======================
-- Note: Le jeu détecte les spams de remotes, on simule donc légitimement
task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoRecall_Actif then
            -- On fire les prompts de SES PROPRES podiums
            local monPlot = nil
            for _, plot in pairs(DossierPlots:GetChildren()) do
                local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
                if owner and (owner.Value == LocalPlayer or owner.Value == LocalPlayer.Name) then
                    monPlot = plot
                    break
                end
            end
            if monPlot then
                for _, prompt in pairs(TrouverTousPrompts(monPlot)) do
                    if prompt.Name:lower():find("grab") or prompt.ActionText:lower():find("grab") then
                        pcall(function() fireproximityprompt(prompt) end)
                    end
                end
            end
        end
        task.wait(1.5)
    end
end)

-- ====================== BRAINROT ESP (FIXED) ======================
-- FIX: Ne scanner QUE les brainrots VISIBLES dans workspace.Plots
-- NE PAS scanner ReplicatedStorage (ce sont des templates invisibles)
local espFolder = Instance.new("Folder")
espFolder.Name = "MohaESP"
espFolder.Parent = CoreGui

local espObjects = {}

local RARITY_COLORS = {
    Legendary = Color3.fromRGB(255, 200, 0),
    Epic = Color3.fromRGB(180, 60, 255),
    Rare = Color3.fromRGB(0, 170, 255),
    Uncommon = Color3.fromRGB(80, 220, 120),
    Common = Color3.fromRGB(180, 180, 180),
    Normal = Color3.fromRGB(180, 180, 180),
    Mythic = Color3.fromRGB(255, 50, 100),
    Secret = Color3.fromRGB(255, 100, 255),
}

-- FIX: Vérifier qu'un model est un vrai brainrot VISIBLE (pas un template)
local function EstBrainrotVisible(model)
    if not model:IsA("Model") then return false end
    -- Doit avoir au moins une partie visible
    local hasVisible = false
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") and part.Transparency < 0.9 then
            hasVisible = true
            break
        end
    end
    if not hasVisible then return false end
    -- Doit être dans workspace (pas dans ReplicatedStorage)
    local current = model.Parent
    while current do
        if current == ReplicatedStorage then return false end
        if current == Workspace then return true end
        current = current.Parent
    end
    return false
end

-- FIX: Lire le prix depuis le BillboardGui overhead du brainrot
local function LirePrixDepuisOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            -- Chercher le label Price
            local priceLbl = desc:FindFirstChild("Price")
            if priceLbl and (priceLbl:IsA("TextLabel") or priceLbl:IsA("TextButton")) then
                local txt = priceLbl.Text or ""
                if txt ~= "" then return txt end
            end
            -- Chercher dans tous les enfants
            for _, child in pairs(desc:GetDescendants()) do
                if (child:IsA("TextLabel") or child:IsA("TextButton")) then
                    local n = child.Name:lower()
                    if n:find("price") or n:find("prix") or n:find("value") or n:find("generation") or n:find("gen") then
                        local txt = child.Text or ""
                        if txt ~= "" and txt ~= "0" then return txt end
                    end
                end
            end
        end
    end
    return nil
end

-- FIX: Lire la rareté depuis le BillboardGui overhead
local function LireRareteDepuisOverhead(model)
    for _, desc in pairs(model:GetDescendants()) do
        if desc:IsA("BillboardGui") then
            local rarLbl = desc:FindFirstChild("Rarity")
            if rarLbl and (rarLbl:IsA("TextLabel") or rarLbl:IsA("TextButton")) then
                local txt = rarLbl.Text or ""
                if txt ~= "" then return txt end
            end
        end
    end
    return nil
end

local function CreateESPForModel(model)
    local part = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
    if not part then return end
    if espObjects[model] then return end

    local brainrotName = model.Name
    local heroData = MohaHub.Heros[brainrotName]

    local prix = LirePrixDepuisOverhead(model)
    if not prix and heroData then prix = heroData.Prix end
    prix = prix or "?"

    local rarete = LireRareteDepuisOverhead(model)
    if not rarete and heroData then rarete = heroData.Rarete end
    rarete = rarete or "Normal"

    local rarColor = RARITY_COLORS[rarete] or COLORS.espColor

    -- ESP compact et joli
    local bb = Instance.new("BillboardGui")
    bb.Name = "ESP"
    bb.Adornee = part
    bb.Size = UDim2.new(0, 140, 0, 38)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(8, 6, 16)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 6)

    -- Bordure avec couleur de rareté
    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = rarColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.15

    -- Barre colorée en haut (accent rareté)
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 2)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = rarColor
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 6)

    -- Nom du brainrot (1ère ligne)
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -8, 0, 16)
    nameL.Position = UDim2.new(0, 4, 0, 4)
    nameL.BackgroundTransparency = 1
    nameL.Text = brainrotName
    nameL.TextColor3 = rarColor
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 11
    nameL.TextScaled = true
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = bg

    -- Prix + Distance (2ème ligne)
    local distL = Instance.new("TextLabel")
    distL.Size = UDim2.new(1, -8, 0, 13)
    distL.Position = UDim2.new(0, 4, 0, 21)
    distL.BackgroundTransparency = 1
    distL.Text = tostring(prix) .. " · ..."
    distL.TextColor3 = COLORS.textSecondary
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 9
    distL.TextScaled = true
    distL.TextXAlignment = Enum.TextXAlignment.Left
    distL.Parent = bg

    espObjects[model] = {billboard = bb, distLabel = distL, part = part, prix = tostring(prix)}
end

local function ClearESP()
    for _, data in pairs(espObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    espObjects = {}
end

-- ESP update loop - FIX: UNIQUEMENT les brainrots dans workspace.Plots
task.spawn(function()
    while true do
        if MohaHub.Parametres.BrainrotESP then
            -- Scanner UNIQUEMENT workspace.Plots pour les brainrots visibles
            if DossierPlots then
                for _, plot in pairs(DossierPlots:GetChildren()) do
                    for _, desc in pairs(plot:GetDescendants()) do
                        -- Matcher le nom contre notre base de données scannée
                        if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                            if EstBrainrotVisible(desc) then
                                CreateESPForModel(desc)
                            end
                        end
                    end
                end
            end

            -- Aussi scanner les brainrots portés par les joueurs (en cours de vol)
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    for _, desc in pairs(player.Character:GetDescendants()) do
                        if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                            if EstBrainrotVisible(desc) then
                                CreateESPForModel(desc)
                            end
                        end
                    end
                end
            end

            -- Update distances & cleanup des ESP invalides
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            for model, data in pairs(espObjects) do
                if not model.Parent or not data.part or not data.part.Parent then
                    data.billboard:Destroy()
                    espObjects[model] = nil
                elseif root and data.part then
                    local dist = math.floor((root.Position - data.part.Position).Magnitude)
                    data.distLabel.Text = (data.prix or "?") .. " · " .. dist .. "m"
                end
            end
        else
            ClearESP()
        end
        task.wait(1.5)
    end
end)
-- ====================== PLAYER ESP ======================
local playerEspFolder = Instance.new("Folder")
playerEspFolder.Name = "MohaPlayerESP"
playerEspFolder.Parent = CoreGui

local playerEspObjects = {}

local function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    if playerEspObjects[player] then return end

    local char = player.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "PlayerESP_" .. player.Name
    bb.Adornee = head
    bb.Size = UDim2.new(0, 160, 0, 44)
    bb.StudsOffset = Vector3.new(0, 2.5, 0)
    bb.AlwaysOnTop = true
    bb.Parent = playerEspFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
    bg.BackgroundTransparency = 0.15
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = COLORS.accent3
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    -- Gradient top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 3)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = COLORS.accent3
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    local tGrad = Instance.new("UIGradient")
    tGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.accent3),
        ColorSequenceKeypoint.new(0.5, COLORS.accent1),
        ColorSequenceKeypoint.new(1, COLORS.accent2)
    })
    tGrad.Parent = topBar

    -- Player icon + name
    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -8, 0, 18)
    nameL.Position = UDim2.new(0, 4, 0, 5)
    nameL.BackgroundTransparency = 1
    nameL.Text = "👤 " .. player.DisplayName
    nameL.TextColor3 = COLORS.accent3
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12
    nameL.TextScaled = true
    nameL.TextXAlignment = Enum.TextXAlignment.Left
    nameL.Parent = bg

    -- Distance + health
    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, -8, 0, 14)
    infoL.Position = UDim2.new(0, 4, 0, 24)
    infoL.BackgroundTransparency = 1
    infoL.Text = "..."
    infoL.TextColor3 = COLORS.textSecondary
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 10
    infoL.TextScaled = true
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.Parent = bg

    playerEspObjects[player] = {billboard = bb, infoLabel = infoL, player = player}
end

local function ClearPlayerESP()
    for _, data in pairs(playerEspObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    playerEspObjects = {}
end

-- ====================== BASE TIMER ESP ======================
local baseEspFolder = Instance.new("Folder")
baseEspFolder.Name = "MohaBaseESP"
baseEspFolder.Parent = CoreGui

local baseEspObjects = {}

-- Scrape timers from game's native Billboards (Plot.Purchases or Plot.AnimalPodiums)
local function ScrapeTimerFromUI(plot)
    local timers = {}
    for _, desc in pairs(plot:GetDescendants()) do
        if desc:IsA("BillboardGui") and desc.Enabled then
            local lbl = desc:FindFirstChild("RemainingTime") or desc:FindFirstChild("Timer") or desc:FindFirstChild("Countdown")
            if lbl and (lbl:IsA("TextLabel") or lbl:IsA("TextButton")) and lbl.Visible then
                local txt = lbl.Text:gsub("<[^>]+>", "") -- Remove RichText tags
                if txt ~= "" and (txt:find(":") or txt:find("s") or txt:find("READY")) then
                    table.insert(timers, txt)
                end
            end
        end
    end
    -- Pick the most relevant timer (usually the longest or formatted x:xx)
    if #timers > 0 then
        table.sort(timers, function(a, b) return (#a > #b) end) -- Prioritize long formatted strings
        return timers[1]
    end
    return nil
end

local function CreateBaseESP(plot)
    if baseEspObjects[plot] then return end

    -- Trouver le centre du plot
    local center = nil
    for _, child in pairs(plot:GetChildren()) do
        if child:IsA("BasePart") and (child.Name == "Base" or child.Name == "Floor" or child.Name == "Ground") then
            center = child
            break
        end
    end
    if not center then
        -- Fallback: premier BasePart trouvé
        center = plot:FindFirstChildWhichIsA("BasePart")
    end
    if not center then return end

    -- Trouver le propriétaire (Système robuste)
    local ownerName = MohaHub:ExtraireProprio(plot)
    
    -- Si vraiment vide (pas de proprio et pas de brainrots), on skip
    if not ownerName and MohaHub:EstVide(plot) then 
        if baseEspObjects[plot] then
            baseEspObjects[plot].billboard:Destroy()
            baseEspObjects[plot] = nil
        end
        return 
    end
    
    ownerName = ownerName or "Base Inconnue"

    local bb = Instance.new("BillboardGui")
    bb.Name = "BaseESP_" .. plot.Name:sub(1, 8)
    bb.Adornee = center
    bb.Size = UDim2.new(0, 180, 0, 56)
    bb.StudsOffset = Vector3.new(0, 8, 0)
    bb.AlwaysOnTop = true
    bb.Parent = baseEspFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(12, 8, 22)
    bg.BackgroundTransparency = 0.1
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = COLORS.accent1
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2

    -- Gradient top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 3)
    topBar.BackgroundColor3 = COLORS.accent1
    topBar.BorderSizePixel = 0
    topBar.Parent = bg
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)
    local bGrad = Instance.new("UIGradient")
    bGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, COLORS.accent1),
        ColorSequenceKeypoint.new(1, COLORS.accent2)
    })
    bGrad.Parent = topBar

    -- Owner name
    local ownerL = Instance.new("TextLabel")
    ownerL.Size = UDim2.new(1, -8, 0, 16)
    ownerL.Position = UDim2.new(0, 4, 0, 5)
    ownerL.BackgroundTransparency = 1
    ownerL.Text = "🏠 " .. ownerName
    ownerL.TextColor3 = COLORS.accent1
    ownerL.Font = Enum.Font.GothamBold
    ownerL.TextSize = 11
    ownerL.TextScaled = true
    ownerL.TextXAlignment = Enum.TextXAlignment.Left
    ownerL.Parent = bg

    -- Brainrot count + distance
    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, -8, 0, 13)
    infoL.Position = UDim2.new(0, 4, 0, 21)
    infoL.BackgroundTransparency = 1
    infoL.Text = "..."
    infoL.TextColor3 = COLORS.textSecondary
    infoL.Font = Enum.Font.Gotham
    infoL.TextSize = 9
    infoL.TextScaled = true
    infoL.TextXAlignment = Enum.TextXAlignment.Left
    infoL.Parent = bg

    -- Timer (steal cooldown)
    local timerL = Instance.new("TextLabel")
    timerL.Size = UDim2.new(1, -8, 0, 13)
    timerL.Position = UDim2.new(0, 4, 0, 35)
    timerL.BackgroundTransparency = 1
    timerL.Text = "⏱ ..."
    timerL.TextColor3 = COLORS.accent2
    timerL.Font = Enum.Font.GothamBold
    timerL.TextSize = 9
    timerL.TextScaled = true
    timerL.TextXAlignment = Enum.TextXAlignment.Left
    timerL.Parent = bg

    baseEspObjects[plot] = {billboard = bb, infoLabel = infoL, timerLabel = timerL, center = center, ownerName = ownerName}
end

local function ClearBaseESP()
    for _, data in pairs(baseEspObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    baseEspObjects = {}
end

-- ====================== PLAYER ESP + BASE ESP UPDATE LOOP ======================
-- Ajout parametres dans MohaHub
MohaHub.Parametres.PlayerESP = false
MohaHub.Parametres.BaseTimerESP = false

task.spawn(function()
    while true do
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")

        -- ===== PLAYER ESP =====
        if MohaHub.Parametres.PlayerESP then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    CreatePlayerESP(player)
                end
            end
            -- Update distances
            for player, data in pairs(playerEspObjects) do
                local pChar = player.Character
                local pRoot = pChar and pChar:FindFirstChild("HumanoidRootPart")
                local pHead = pChar and pChar:FindFirstChild("Head")
                if not pChar or not pRoot or not pHead then
                    data.billboard:Destroy()
                    playerEspObjects[player] = nil
                elseif root then
                    local dist = math.floor((root.Position - pRoot.Position).Magnitude)
                    local hum = pChar:FindFirstChildWhichIsA("Humanoid")
                    local hp = hum and math.floor(hum.Health) or "?"
                    data.infoLabel.Text = "📏 " .. dist .. "m · ❤️ " .. tostring(hp)
                    data.billboard.Adornee = pHead
                end
            end
        else
            ClearPlayerESP()
        end

        -- ===== BASE TIMER ESP =====
        if MohaHub.Parametres.BaseTimerESP and DossierPlots then
            for _, plot in pairs(DossierPlots:GetChildren()) do
                CreateBaseESP(plot)
            end
            -- Update info
            for plot, data in pairs(baseEspObjects) do
                -- Nettoyer si le plot n'existe plus
                if not plot.Parent or not data.center or not data.center.Parent then
                    data.billboard:Destroy()
                    baseEspObjects[plot] = nil
                else
                    -- Vérifier si le proprio est toujours là
                    local currentOwner = MohaHub:ExtraireProprio(plot)
                    if not currentOwner then
                        -- Plus de proprio = base vide, on supprime l'ESP
                        data.billboard:Destroy()
                        baseEspObjects[plot] = nil
                    elseif root then
                        local dist = math.floor((root.Position - data.center.Position).Magnitude)
                        -- Compter les brainrots dans ce plot
                        local brainrotCount = 0
                        for _, desc in pairs(plot:GetDescendants()) do
                            if desc:IsA("Model") and MohaHub.Heros[desc.Name] then
                                brainrotCount = brainrotCount + 1
                            end
                        end
                        data.infoLabel.Text = "🧠 " .. brainrotCount .. " brainrots · 📏 " .. dist .. "m"

                        -- Timer de protection steal
                        local isP = MohaHub:EstProtege(plot)
                        local stealTimer = plot:GetAttribute("StealTimer") or plot:GetAttribute("StealCooldown") or plot:GetAttribute("Timer")
                        
                        if isP then
                            data.timerLabel.Text = "🔒 Protégé / Privé"
                            data.timerLabel.TextColor3 = COLORS.accent1
                        elseif stealTimer and type(stealTimer) == "number" then
                            local serverTime = Workspace:GetServerTimeNow()
                            local remaining = math.max(0, stealTimer - serverTime)
                            if remaining > 0 then
                                local mins = math.floor(remaining / 60)
                                local secs = math.floor(remaining % 60)
                                data.timerLabel.Text = "⏱ Protection: " .. string.format("%d:%02d", mins, secs)
                                data.timerLabel.TextColor3 = COLORS.red
                            else
                                data.timerLabel.Text = "⏱ Vulnérable !"
                                data.timerLabel.TextColor3 = COLORS.green
                            end
                        else
                            -- Chercher un timer dans les enfants
                            local timerVal = nil
                            for _, child in pairs(plot:GetChildren()) do
                                if child:IsA("NumberValue") and (child.Name:lower():find("timer") or child.Name:lower():find("cooldown") or child.Name:lower():find("steal")) then
                                    timerVal = child.Value
                                    break
                                end
                            end
                            if timerVal and timerVal > 0 then
                                local mins = math.floor(timerVal / 60)
                                local secs = math.floor(timerVal % 60)
                                data.timerLabel.Text = "⏱ " .. string.format("%d:%02d", mins, secs)
                                data.timerLabel.TextColor3 = COLORS.accent2
                            else
                                data.timerLabel.Text = "⏱ Prêt à voler"
                                data.timerLabel.TextColor3 = COLORS.green
                            end
                        end
                    end
                end
            end
        else
            ClearBaseESP()
        end

        task.wait(1)
    end
end)

-- ====================== FIN ======================
print("[MohaHub] v9 ULTIMATE chargé ! (MODE SAFE)")
print("[MohaHub] Méthode: fireproximityprompt uniquement")
print("[MohaHub] Anti-Ban: Aucun remote UUID touché")
print("[MohaHub] ESP: Brainrot + Player + Base Timer")
print("[MohaHub] GUI Custom - Mode Safe")
end)
