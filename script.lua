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
local Camera = Workspace.CurrentCamera

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

local RemoteGrab = nil
do
    local ss = ReplicatedStorage:FindFirstChild("StealService", true)
    if ss then RemoteGrab = ss:FindFirstChild("Grab") end
    if not RemoteGrab then RemoteGrab = ReplicatedStorage:FindFirstChild("Grab", true) end
    if not RemoteGrab then
        for _, d in pairs(ReplicatedStorage:GetDescendants()) do
            if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) then
                local n = d.Name:lower()
                if n:find("grab") or n:find("steal") then RemoteGrab = d; break end
            end
        end
    end
end

-- ====================== MOTEUR MOHA HUB ======================
local MohaHub = {
    Heros = {}, ListeNomsHeros = {},
    Parametres = {
        AutoGrab_Actif = false, GrabMode = "Highest", GrabDelay = 1.0,
        GrabRange = 10, AfficherCercle = true, AutoRecall_Actif = false,
        BrainrotESP = false, GrabBrainrots = true
    }
}

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
local currentTab = 1

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
        currentTab = i
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
CreateSection(p2, "BRAINROT ESP")
CreateToggle(p2, "👁️ Activer Brainrot ESP", false, function(v) MohaHub.Parametres.BrainrotESP = v end)
CreateInfoCard(p2, "ℹ️ Comment ça marche", "L'ESP affiche le nom, la rareté et le prix de chaque brainrot à travers les murs. Les brainrots sont détectés depuis ReplicatedStorage > Models > Animals.")

-- Page 3 : DEFENSE
local p3 = TabPages[3]
CreateSection(p3, "BOUCLIER ANTI-STEAL")
CreateToggle(p3, "🛡️ Activer Auto-Recall", false, function(v) MohaHub.Parametres.AutoRecall_Actif = v end)
CreateInfoCard(p3, "ℹ️ Auto-Recall", "Rappelle automatiquement vos héros volés en spammant le Remote Grab sur vos podiums.")

-- Page 4 : INFO
local p4 = TabPages[4]
CreateSection(p4, "MOHA HUB v9 ULTIMATE")
CreateInfoCard(p4, "⚡ Moteur de vol", "5 méthodes: ProximityPrompt > Remote > ClickDetector > Plot Remotes > Bring Hitbox")
CreateInfoCard(p4, "📡 Remote Status", RemoteGrab and ("✅ Trouvé: "..RemoteGrab:GetFullName()) or "❌ Non trouvé")
CreateInfoCard(p4, "🧠 Brainrots", "Scan depuis ReplicatedStorage.Models.Animals\nNombre détecté: "..tostring(#BrainrotsScannes))

-- ====================== BARRE DE GRAB EN HAUT ======================
local GrabBarGui = Instance.new("ScreenGui")
GrabBarGui.Name = "MohaGrabBar"
GrabBarGui.Parent = HubParent
GrabBarGui.ResetOnSpawn = false
GrabBarGui.Enabled = false

local GrabBarFrame = Instance.new("Frame")
GrabBarFrame.Size = UDim2.new(1, 0, 0, 38)
GrabBarFrame.Position = UDim2.new(0, 0, 0, 0)
GrabBarFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 20)
GrabBarFrame.BorderSizePixel = 0
GrabBarFrame.Parent = GrabBarGui

local grabGrad = Instance.new("UIGradient")
grabGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 10, 40)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 5, 25))
})
grabGrad.Parent = GrabBarFrame

local GrabProgressBg = Instance.new("Frame")
GrabProgressBg.Size = UDim2.new(1, -20, 0, 6)
GrabProgressBg.Position = UDim2.new(0, 10, 1, -10)
GrabProgressBg.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
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
    ColorSequenceKeypoint.new(1, COLORS.accent2)
})
grabFillGrad.Parent = GrabProgressFill

local GrabStatusLabel = Instance.new("TextLabel")
GrabStatusLabel.Size = UDim2.new(0.6, 0, 0, 22)
GrabStatusLabel.Position = UDim2.new(0, 14, 0, 2)
GrabStatusLabel.BackgroundTransparency = 1
GrabStatusLabel.Text = "⚡ Recherche..."
GrabStatusLabel.TextColor3 = COLORS.textPrimary
GrabStatusLabel.Font = Enum.Font.GothamBold
GrabStatusLabel.TextSize = 13
GrabStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
GrabStatusLabel.Parent = GrabBarFrame

local GrabTimeLabel = Instance.new("TextLabel")
GrabTimeLabel.Size = UDim2.new(0, 100, 0, 22)
GrabTimeLabel.Position = UDim2.new(1, -110, 0, 2)
GrabTimeLabel.BackgroundTransparency = 1
GrabTimeLabel.Text = "0.0s"
GrabTimeLabel.TextColor3 = COLORS.accent3
GrabTimeLabel.Font = Enum.Font.GothamBold
GrabTimeLabel.TextSize = 13
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
ToggleBtn.MouseButton1Click:Connect(function()
    guiOpen = not guiOpen
    MainFrame.Visible = guiOpen
    TweenService:Create(ToggleBtn, TweenInfo.new(0.3), {
        BackgroundColor3 = guiOpen and COLORS.accent2 or COLORS.accent1,
        Rotation = guiOpen and 90 or 0
    }):Play()
end)
CloseBtn.MouseButton1Click:Connect(function()
    guiOpen = false
    MainFrame.Visible = false
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

-- ====================== AUTO GRAB ENGINE ======================
local function ObtenirValeurDansPlot(plot)
    local vMax, nom = -1, "Inconnu"
    for _, e in pairs(plot:GetDescendants()) do
        local hd = MohaHub.Heros[e.Name]
        if hd and hd.ValeurNum and hd.ValeurNum > vMax then vMax = hd.ValeurNum; nom = e.Name end
    end
    return vMax, nom
end

local function ObtenirPlotIndex(plot)
    local idx = tonumber(plot.Name:match("%d+"))
    return idx or plot.Name
end

local enCoursDeGrab = false

local function ExecuterAutoGrab()
    if enCoursDeGrab then return end
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root or not DossierPlots then return end

    local mode = MohaHub.Parametres.GrabMode
    local range = MohaHub.Parametres.GrabRange
    local cibleHitbox, nomCible, plotCible = nil, "Cible", nil
    local minDist, maxVal = range, -1

    for _, plot in pairs(DossierPlots:GetChildren()) do
        local owner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
        if owner and owner:IsA("ObjectValue") and owner.Value == LocalPlayer then continue end
        if owner and owner:IsA("StringValue") and owner.Value == LocalPlayer.Name then continue end

        local hitbox = plot:FindFirstChild("StealHitbox", true)
        if hitbox and hitbox:IsA("BasePart") then
            local dist = (root.Position - hitbox.Position).Magnitude
            if dist <= range then
                if mode == "Nearest" then
                    if dist < minDist then minDist = dist; cibleHitbox = hitbox; plotCible = plot; _, nomCible = ObtenirValeurDansPlot(plot) end
                elseif mode == "Highest" then
                    local prix, nom = ObtenirValeurDansPlot(plot)
                    if prix > maxVal then maxVal = prix; cibleHitbox = hitbox; plotCible = plot; nomCible = nom end
                end
            end
        end
    end

    if not cibleHitbox or not plotCible then GrabBarGui.Enabled = false; return end

    enCoursDeGrab = true
    GrabBarGui.Enabled = true
    GrabStatusLabel.Text = "⚡ Vol: "..nomCible
    GrabProgressFill.Size = UDim2.new(0, 0, 1, 0)

    local temps = MohaHub.Parametres.GrabDelay
    local startTime = tick()

    -- Animate progress bar
    local tween = TweenService:Create(GrabProgressFill, TweenInfo.new(temps, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
    tween:Play()

    -- Update time label during animation
    local conn
    conn = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        if elapsed >= temps then
            GrabTimeLabel.Text = string.format("%.1fs", temps)
            conn:Disconnect()
        else
            GrabTimeLabel.Text = string.format("%.1fs / %.1fs", elapsed, temps)
        end
    end)

    tween.Completed:Wait()
    if conn.Connected then conn:Disconnect() end

    -- Multi-méthode steal
    local ok = false

    -- M1: ProximityPrompt
    if not ok then
        local prompt = plotCible:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function()
                local oH, oM, oE, oR = prompt.HoldDuration, prompt.MaxActivationDistance, prompt.Enabled, prompt.RequiresLineOfSight
                prompt.HoldDuration = 0; prompt.MaxActivationDistance = 9999; prompt.Enabled = true; prompt.RequiresLineOfSight = false
                if fireproximityprompt then fireproximityprompt(prompt); ok = true end
                task.delay(0.2, function() pcall(function() prompt.HoldDuration = oH; prompt.MaxActivationDistance = oM; prompt.Enabled = oE; prompt.RequiresLineOfSight = oR end) end)
            end)
        end
    end

    -- M2: Remote
    if not ok and RemoteGrab then
        local pi = ObtenirPlotIndex(plotCible)
        pcall(function()
            if RemoteGrab:IsA("RemoteEvent") then
                RemoteGrab:FireServer("Grab", pi); RemoteGrab:FireServer("Steal", pi); RemoteGrab:FireServer(pi); ok = true
            elseif RemoteGrab:IsA("RemoteFunction") then
                RemoteGrab:InvokeServer("Grab", pi); ok = true
            end
        end)
    end

    -- M3: ClickDetector
    if not ok then
        local cd = plotCible:FindFirstChildWhichIsA("ClickDetector", true)
        if cd and fireclickdetector then pcall(function() fireclickdetector(cd); ok = true end) end
    end

    -- M4: Plot Remotes
    if not ok then
        for _, d in pairs(plotCible:GetDescendants()) do
            if d:IsA("RemoteEvent") then pcall(function() d:FireServer(); ok = true end); if ok then break end end
        end
    end

    -- M5: Bring Hitbox
    if not ok then
        pcall(function()
            local orig = cibleHitbox.CFrame; cibleHitbox.CFrame = root.CFrame; task.wait(0.15); cibleHitbox.CFrame = orig
        end)
    end

    GrabBarGui.Enabled = false
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

-- ====================== AUTO RECALL ======================
task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoRecall_Actif and RemoteGrab then
            for i = 1, 10 do
                pcall(function()
                    if RemoteGrab:IsA("RemoteEvent") then RemoteGrab:FireServer("Grab", i)
                    elseif RemoteGrab:IsA("RemoteFunction") then RemoteGrab:InvokeServer("Grab", i) end
                end)
            end
        end
        task.wait(0.5)
    end
end)

-- ====================== BRAINROT ESP ======================
local espFolder = Instance.new("Folder")
espFolder.Name = "MohaESP"
espFolder.Parent = CoreGui

local espObjects = {}

local RARITY_COLORS = {
    Legendary = Color3.fromRGB(255, 170, 0),
    Epic = Color3.fromRGB(180, 60, 255),
    Rare = Color3.fromRGB(0, 170, 255),
    Uncommon = Color3.fromRGB(80, 220, 120),
    Common = Color3.fromRGB(180, 180, 180),
    Normal = Color3.fromRGB(180, 180, 180),
}

local function CreateESPForPart(part, brainrotName, rarete, prix)
    if espObjects[part] then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "BrainrotESP_"..brainrotName
    bb.Adornee = part
    bb.Size = UDim2.new(0, 180, 0, 55)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = espFolder

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(15, 12, 25)
    bg.BackgroundTransparency = 0.25
    bg.BorderSizePixel = 0
    bg.Parent = bb
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local stroke = Instance.new("UIStroke")
    stroke.Parent = bg
    stroke.Color = RARITY_COLORS[rarete] or COLORS.espColor
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3

    local nameL = Instance.new("TextLabel")
    nameL.Size = UDim2.new(1, -10, 0, 20)
    nameL.Position = UDim2.new(0, 5, 0, 3)
    nameL.BackgroundTransparency = 1
    nameL.Text = "🧠 "..brainrotName
    nameL.TextColor3 = RARITY_COLORS[rarete] or COLORS.espColor
    nameL.Font = Enum.Font.GothamBold
    nameL.TextSize = 12
    nameL.TextScaled = true
    nameL.Parent = bg

    local infoL = Instance.new("TextLabel")
    infoL.Size = UDim2.new(1, -10, 0, 16)
    infoL.Position = UDim2.new(0, 5, 0, 24)
    infoL.BackgroundTransparency = 1
    infoL.Text = rarete.." | 💰"..prix
    infoL.TextColor3 = COLORS.textSecondary
    infoL.Font = Enum.Font.GothamSemibold
    infoL.TextSize = 10
    infoL.TextScaled = true
    infoL.Parent = bg

    local distL = Instance.new("TextLabel")
    distL.Size = UDim2.new(1, -10, 0, 12)
    distL.Position = UDim2.new(0, 5, 0, 40)
    distL.BackgroundTransparency = 1
    distL.Text = "..."
    distL.TextColor3 = COLORS.accent3
    distL.Font = Enum.Font.Gotham
    distL.TextSize = 9
    distL.Parent = bg

    espObjects[part] = {billboard = bb, distLabel = distL}
end

local function ClearESP()
    for part, data in pairs(espObjects) do
        if data.billboard then data.billboard:Destroy() end
    end
    espObjects = {}
end

-- ESP update loop
task.spawn(function()
    while true do
        if MohaHub.Parametres.BrainrotESP then
            -- Scan workspace plots for brainrots
            if DossierPlots then
                for _, plot in pairs(DossierPlots:GetChildren()) do
                    for _, desc in pairs(plot:GetDescendants()) do
                        local heroData = MohaHub.Heros[desc.Name]
                        if heroData and desc:IsA("BasePart") or (desc:IsA("Model") and desc:FindFirstChild("HumanoidRootPart")) then
                            local part = desc
                            if desc:IsA("Model") then part = desc:FindFirstChild("HumanoidRootPart") or desc:FindFirstChildWhichIsA("BasePart") end
                            if part and part:IsA("BasePart") and heroData then
                                CreateESPForPart(part, desc.Name, heroData.Rarete or "Normal", heroData.Prix or "?")
                            end
                        end
                    end
                end
            end

            -- Also scan workspace directly for brainrot models
            for _, child in pairs(Workspace:GetDescendants()) do
                local heroData = MohaHub.Heros[child.Name]
                if heroData and (child:IsA("Model") or child:IsA("BasePart")) then
                    local part = child
                    if child:IsA("Model") then part = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart") end
                    if part and part:IsA("BasePart") then
                        CreateESPForPart(part, child.Name, heroData.Rarete or "Normal", heroData.Prix or "?")
                    end
                end
            end

            -- Update distances & cleanup
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            for part, data in pairs(espObjects) do
                if not part.Parent then
                    data.billboard:Destroy()
                    espObjects[part] = nil
                elseif root then
                    local dist = math.floor((root.Position - part.Position).Magnitude)
                    data.distLabel.Text = "📍 "..dist.." studs"
                end
            end
        else
            ClearESP()
        end
        task.wait(1)
    end
end)

-- ====================== FIN ======================
print("[MohaHub] v9 ULTIMATE chargé !")
print("[MohaHub] Remote: "..(RemoteGrab and RemoteGrab:GetFullName() or "NON TROUVÉ"))
print("[MohaHub] GUI Custom - Zero Dépendances")
