-- ==============================================================================
-- █▀▄▀█ █▀█ █░█ ▄▀█   █░█ █░█ █▄▄
-- █░▀░█ █▄█ █▀█ █▀█   █▀█ █▄█ █▄█
-- Version: 8.4 (Full Fix - Multi-Method Steal)
-- Jeu: Steal A Brainrot
-- ==============================================================================

-- ==============================================================================
-- [SECTION 1] : INITIALISATION DES SERVICES
-- ==============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local HubParent = (gethui and gethui()) or CoreGui

-- ==============================================================================
-- [SECTION 2] : CRÉATION DU HUD VISUEL (LA BARRE DE VOL)
-- ==============================================================================
local GrabHUD = Instance.new("ScreenGui")
GrabHUD.Name = "MohaGrabHUD"
GrabHUD.Parent = HubParent
GrabHUD.Enabled = false
GrabHUD.ResetOnSpawn = false

local HUDFrame = Instance.new("Frame")
HUDFrame.Size = UDim2.new(0, 300, 0, 70)
HUDFrame.Position = UDim2.new(0.5, -150, 0, 20)
HUDFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
HUDFrame.BorderSizePixel = 0
HUDFrame.Parent = GrabHUD
Instance.new("UICorner", HUDFrame).CornerRadius = UDim.new(0, 8)

local TextCible = Instance.new("TextLabel")
TextCible.Size = UDim2.new(1, 0, 0.5, 0)
TextCible.BackgroundTransparency = 1
TextCible.Text = "Recherche de cible..."
TextCible.TextColor3 = Color3.fromRGB(255, 255, 255)
TextCible.Font = Enum.Font.GothamBold
TextCible.TextSize = 15
TextCible.Parent = HUDFrame

local BarreFond = Instance.new("Frame")
BarreFond.Size = UDim2.new(0.9, 0, 0.2, 0)
BarreFond.Position = UDim2.new(0.05, 0, 0.6, 0)
BarreFond.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
BarreFond.Parent = HUDFrame
Instance.new("UICorner", BarreFond).CornerRadius = UDim.new(1, 0)

local BarreProgression = Instance.new("Frame")
BarreProgression.Size = UDim2.new(0, 0, 1, 0)
BarreProgression.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
BarreProgression.Parent = BarreFond
Instance.new("UICorner", BarreProgression).CornerRadius = UDim.new(1, 0)

-- ==============================================================================
-- [SECTION 3] : UTILITAIRES (CONVERSION DE PRIX)
-- ==============================================================================
-- FIX: ConvertirEnNombre est maintenant défini ICI, avant d'être utilisé
-- par les héros manuels de la Section 9 et le scan de la Section 8.
local function ConvertirEnNombre(valeur)
    if type(valeur) == "number" then return valeur end
    local texte = tostring(valeur):upper()
    local nombre = tonumber(texte:match("[%d%.]+")) or 0
    if texte:match("B") then nombre = nombre * 1000000000
    elseif texte:match("M") then nombre = nombre * 1000000
    elseif texte:match("K") then nombre = nombre * 1000
    end
    return nombre
end

-- ==============================================================================
-- [SECTION 4] : DOSSIERS, REMOTES ET MOTEUR MOHA HUB
-- ==============================================================================
local DossierModeles = ReplicatedStorage:WaitForChild("Models", 5)
local DossierAnimaux = DossierModeles and DossierModeles:WaitForChild("Animals", 5)
local DossierPlots = Workspace:WaitForChild("Plots", 5)

-- FIX: On cherche le Remote correctement en parcourant l'arborescence
-- Au lieu de FindFirstChild("StealService/Grab") qui cherche un nom littéral avec "/"
local RemoteGrab = nil
do
    -- Méthode 1 : Chercher StealService puis Grab dedans
    local stealService = ReplicatedStorage:FindFirstChild("StealService", true)
    if stealService then
        RemoteGrab = stealService:FindFirstChild("Grab")
    end
    -- Méthode 2 : Chercher directement un Remote nommé "Grab"
    if not RemoteGrab then
        RemoteGrab = ReplicatedStorage:FindFirstChild("Grab", true)
    end
    -- Méthode 3 : Chercher tout RemoteEvent/RemoteFunction contenant "Grab" ou "Steal"
    if not RemoteGrab then
        for _, descendant in pairs(ReplicatedStorage:GetDescendants()) do
            if (descendant:IsA("RemoteEvent") or descendant:IsA("RemoteFunction")) then
                local nomLower = descendant.Name:lower()
                if nomLower:find("grab") or nomLower:find("steal") then
                    RemoteGrab = descendant
                    break
                end
            end
        end
    end
end

local MohaHub = {
    Heros = {},
    ListeNomsHeros = {},
    Parametres = {
        AutoGrab_Actif = false,
        GrabMode = "Highest",
        GrabDelay = 1.0,
        GrabRange = 10,
        AfficherCercle = true,
        AutoRecall_Actif = false
    }
}

function MohaHub:AjouterHero(nom, config)
    -- FIX: Calcul automatique de ValeurNum si absent
    if not config.ValeurNum then
        if config.Prix then
            config.ValeurNum = ConvertirEnNombre(config.Prix)
        elseif config.Gen then
            config.ValeurNum = config.Gen
        else
            config.ValeurNum = 0
        end
    end
    -- FIX: Éviter les doublons dans la liste de noms
    if not self.Heros[nom] then
        table.insert(self.ListeNomsHeros, nom)
    end
    self.Heros[nom] = config
end

-- ==============================================================================
-- [SECTION 5] : CRÉATION DU CERCLE VISUEL (AURA)
-- ==============================================================================
local CercleAura = Instance.new("Part")
CercleAura.Shape = Enum.PartType.Cylinder
CercleAura.Color = Color3.fromRGB(138, 43, 226)
CercleAura.Material = Enum.Material.Neon
CercleAura.Transparency = 0.7
CercleAura.Anchored = true
CercleAura.CanCollide = false
CercleAura.CastShadow = false
CercleAura.Parent = nil -- On commence sans le montrer

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")

    if MohaHub.Parametres.AfficherCercle and MohaHub.Parametres.AutoGrab_Actif and rootPart then
        CercleAura.Position = rootPart.Position - Vector3.new(0, 2.5, 0)
        CercleAura.Orientation = Vector3.new(0, 0, 90)
        local diametre = MohaHub.Parametres.GrabRange * 2
        CercleAura.Size = Vector3.new(0.2, diametre, diametre)
        if not CercleAura.Parent then
            CercleAura.Parent = Workspace
        end
    else
        if CercleAura.Parent then
            CercleAura.Parent = nil
        end
    end
end)

-- ==============================================================================
-- [SECTION 6] : MODULE AUTO GRAB (MULTI-MÉTHODE FIABLE)
-- ==============================================================================
local function ObtenirValeurDansPlot(plot)
    local valeurMax = -1
    local nomBrainrot = "Inconnu"
    for _, enfant in pairs(plot:GetDescendants()) do
        local heroData = MohaHub.Heros[enfant.Name]
        if heroData and heroData.ValeurNum then
            if heroData.ValeurNum > valeurMax then
                valeurMax = heroData.ValeurNum
                nomBrainrot = enfant.Name
            end
        end
    end
    return valeurMax, nomBrainrot
end

-- FIX: Fonction pour obtenir l'index/nom du plot pour le Remote
local function ObtenirPlotIndex(plot)
    -- Essayer de trouver un numéro dans le nom du plot
    local index = tonumber(plot.Name:match("%d+"))
    if index then return index end
    -- Sinon retourner le nom du plot
    return plot.Name
end

local enCoursDeGrab = false -- FIX: Anti-spam pour éviter les doubles exécutions

local function ExecuterAutoGrab()
    if enCoursDeGrab then return end
    
    local char = LocalPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    if not DossierPlots then return end

    local mode = MohaHub.Parametres.GrabMode
    local range = MohaHub.Parametres.GrabRange

    local cibleHitbox = nil
    local nomCible = "Cible"
    local plotCible = nil
    local minDistance = range
    local maxValeur = -1

    for _, plot in pairs(DossierPlots:GetChildren()) do
        -- FIX: Ignorer son propre plot
        local plotOwner = plot:FindFirstChild("Owner") or plot:FindFirstChild("PlotOwner")
        if plotOwner and plotOwner:IsA("ObjectValue") and plotOwner.Value == LocalPlayer then
            continue
        end
        if plotOwner and plotOwner:IsA("StringValue") and plotOwner.Value == LocalPlayer.Name then
            continue
        end

        local hitbox = plot:FindFirstChild("StealHitbox", true)
        if hitbox and hitbox:IsA("BasePart") then
            local dist = (rootPart.Position - hitbox.Position).Magnitude
            if dist <= range then
                if mode == "Nearest" then
                    if dist < minDistance then
                        minDistance = dist
                        cibleHitbox = hitbox
                        plotCible = plot
                        _, nomCible = ObtenirValeurDansPlot(plot)
                    end
                elseif mode == "Highest" then
                    local prix, nom = ObtenirValeurDansPlot(plot)
                    if prix > maxValeur then
                        maxValeur = prix
                        cibleHitbox = hitbox
                        plotCible = plot
                        nomCible = nom
                    end
                end
            end
        end
    end

    if not cibleHitbox or not plotCible then
        GrabHUD.Enabled = false
        return
    end

    -- Verrouiller le grab
    enCoursDeGrab = true
    GrabHUD.Enabled = true
    TextCible.Text = "Vol en cours : " .. nomCible
    BarreProgression.Size = UDim2.new(0, 0, 1, 0)

    local temps = MohaHub.Parametres.GrabDelay
    local tween = TweenService:Create(BarreProgression, TweenInfo.new(temps, Enum.EasingStyle.Linear), {Size = UDim2.new(1, 0, 1, 0)})
    tween:Play()
    tween.Completed:Wait()

    -- =====================================================================
    -- MULTI-MÉTHODE DE STEAL (du plus fiable au moins fiable)
    -- =====================================================================
    local stealReussi = false

    -- MÉTHODE 1 : ProximityPrompt (la plus fiable, simule l'interaction réelle)
    if not stealReussi then
        local prompt = plotCible:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then
            pcall(function()
                -- Sauvegarder les valeurs originales
                local origHoldDuration = prompt.HoldDuration
                local origMaxDistance = prompt.MaxActivationDistance
                local origEnabled = prompt.Enabled
                local origRequiresLineOfSight = prompt.RequiresLineOfSight

                -- Modifier temporairement pour garantir l'activation
                prompt.HoldDuration = 0
                prompt.MaxActivationDistance = 9999
                prompt.Enabled = true
                prompt.RequiresLineOfSight = false

                if fireproximityprompt then
                    fireproximityprompt(prompt)
                    stealReussi = true
                end

                -- Restaurer les valeurs originales
                task.delay(0.2, function()
                    pcall(function()
                        prompt.HoldDuration = origHoldDuration
                        prompt.MaxActivationDistance = origMaxDistance
                        prompt.Enabled = origEnabled
                        prompt.RequiresLineOfSight = origRequiresLineOfSight
                    end)
                end)
            end)
        end
    end

    -- MÉTHODE 2 : Remote Event/Function direct
    if not stealReussi and RemoteGrab then
        local plotIndex = ObtenirPlotIndex(plotCible)
        pcall(function()
            if RemoteGrab:IsA("RemoteEvent") then
                RemoteGrab:FireServer("Grab", plotIndex)
                RemoteGrab:FireServer("Steal", plotIndex)
                RemoteGrab:FireServer(plotIndex)
                stealReussi = true
            elseif RemoteGrab:IsA("RemoteFunction") then
                RemoteGrab:InvokeServer("Grab", plotIndex)
                stealReussi = true
            end
        end)
    end

    -- MÉTHODE 3 : Chercher un ClickDetector dans le plot
    if not stealReussi then
        local clickDetector = plotCible:FindFirstChildWhichIsA("ClickDetector", true)
        if clickDetector and fireclickdetector then
            pcall(function()
                fireclickdetector(clickDetector)
                stealReussi = true
            end)
        end
    end

    -- MÉTHODE 4 : Chercher tous les Remotes dans le plot lui-même
    if not stealReussi then
        for _, desc in pairs(plotCible:GetDescendants()) do
            if desc:IsA("RemoteEvent") then
                pcall(function()
                    desc:FireServer()
                    stealReussi = true
                end)
                if stealReussi then break end
            end
        end
    end

    -- MÉTHODE 5 : Bring Hitbox (dernier recours - téléporte la hitbox sur toi)
    -- NOTE: Ne fonctionne QUE si la hitbox n'est PAS contrôlée par le serveur
    if not stealReussi then
        pcall(function()
            local positionOriginale = cibleHitbox.CFrame
            cibleHitbox.CFrame = rootPart.CFrame
            task.wait(0.15)
            cibleHitbox.CFrame = positionOriginale
        end)
    end

    GrabHUD.Enabled = false
    enCoursDeGrab = false
end

task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoGrab_Actif then
            local ok, err = pcall(ExecuterAutoGrab)
            if not ok then
                warn("[MohaHub] Erreur Auto-Grab: " .. tostring(err))
            end
            task.wait(0.3) -- FIX: Cooldown un peu plus long pour éviter le rate-limit
        else
            GrabHUD.Enabled = false
            task.wait(0.5) -- Polling plus lent quand désactivé pour économiser les perfs
        end
    end
end)

-- ==============================================================================
-- [SECTION 7] : MODULE DÉFENSE (REMOTE SPOOFING)
-- ==============================================================================
task.spawn(function()
    while true do
        if MohaHub.Parametres.AutoRecall_Actif and RemoteGrab then
            for podiumIndex = 1, 10 do
                pcall(function()
                    if RemoteGrab:IsA("RemoteEvent") then
                        RemoteGrab:FireServer("Grab", podiumIndex)
                    elseif RemoteGrab:IsA("RemoteFunction") then
                        RemoteGrab:InvokeServer("Grab", podiumIndex)
                    end
                end)
            end
        end
        task.wait(0.5)
    end
end)

-- ==============================================================================
-- [SECTION 8] : TES HÉROS PERSONNELS
-- ==============================================================================
-- FIX: Maintenant ValeurNum est calculé automatiquement par AjouterHero()
-- grâce à ConvertirEnNombre qui est défini plus haut
MohaHub:AjouterHero("Glorbo Fruttodrillo", {Rarete = "Legendary", Prix = "200K", Gen = 938})
MohaHub:AjouterHero("Trulimero Trulicina", {Rarete = "Epic", Prix = "20K", Gen = 188})
MohaHub:AjouterHero("Perochello Lemonchello", {Rarete = "Epic", Prix = "27.5K", Gen = 160})
MohaHub:AjouterHero("Cappuccino Assassino", {Rarete = "Epic", Prix = "10K", Gen = 113})
MohaHub:AjouterHero("Brr Brr Patapim", {Rarete = "Epic", Prix = "15K", Gen = 100})

-- ==============================================================================
-- [SECTION 9] : AUTO-SCAN DES PRIX ET INJECTION
-- ==============================================================================
local BrainrotsScannes = {}

task.spawn(function()
    task.wait(1)
    if DossierAnimaux then
        for _, modele in pairs(DossierAnimaux:GetChildren()) do
            local objetPrix = modele:FindFirstChild("Price") or modele:FindFirstChild("Prix") or modele:FindFirstChild("Value")
            local objetRarete = modele:FindFirstChild("Rarity") or modele:FindFirstChild("Rarete")
            local prixTexte = objetPrix and tostring(objetPrix.Value) or "0"
            local rareteTexte = objetRarete and tostring(objetRarete.Value) or "Normal"
            local valeurReelle = ConvertirEnNombre(prixTexte)

            table.insert(BrainrotsScannes, {
                Nom = modele.Name,
                Rarete = rareteTexte,
                PrixStr = prixTexte,
                ValeurDeTri = valeurReelle
            })
        end

        table.sort(BrainrotsScannes, function(a, b) return a.ValeurDeTri > b.ValeurDeTri end)

        for _, brainrot in ipairs(BrainrotsScannes) do
            -- FIX: AjouterHero gère les doublons maintenant, 
            -- le scan met à jour les données scannées du jeu
            MohaHub:AjouterHero(brainrot.Nom, {
                Rarete = brainrot.Rarete,
                Prix = brainrot.PrixStr,
                ValeurNum = brainrot.ValeurDeTri
            })
        end

        print("[MohaHub] Scan terminé : " .. #BrainrotsScannes .. " brainrots trouvés.")
    else
        warn("[MohaHub] Dossier Animals introuvable ! Le scan des prix a échoué.")
    end
end)

-- ==============================================================================
-- [SECTION 10] : INTERFACE GRAPHIQUE (RAYFIELD)
-- ==============================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
    Name = "Moha Hub v8.4",
    LoadingTitle = "Chargement...",
    LoadingSubtitle = "Multi-Method Steal Engine",
    ConfigurationSaving = { Enabled = false }
})

local TabSteal = Window:CreateTab("Steal", 10886562335)
local TabDefend = Window:CreateTab("Defense", 10886562335)
local TabInfo = Window:CreateTab("Info", 10886562335)

-- =============== TAB STEAL ===============
TabSteal:CreateSection("Auto-Grab (Multi-Méthode)")

TabSteal:CreateToggle({
    Name = "Activer l'Auto Grab",
    CurrentValue = false,
    Flag = "GrabToggle",
    Callback = function(Value)
        MohaHub.Parametres.AutoGrab_Actif = Value
    end
})

TabSteal:CreateToggle({
    Name = "Afficher le cercle visuel",
    CurrentValue = true,
    Flag = "CircleToggle",
    Callback = function(Value)
        MohaHub.Parametres.AfficherCercle = Value
    end
})

TabSteal:CreateSlider({
    Name = "Taille du cercle (Studs)",
    Range = {1, 20},
    Increment = 1,
    CurrentValue = 10,
    Suffix = " Studs",
    Flag = "GrabRange",
    Callback = function(Value)
        MohaHub.Parametres.GrabRange = Value
    end
})

TabSteal:CreateDropdown({
    Name = "Priorité dans le cercle",
    Options = {"Highest", "Nearest"},
    CurrentOption = {"Highest"},
    MultipleOptions = false,
    Flag = "GrabMode",
    Callback = function(Option)
        -- FIX: Gestion des deux formats de retour possibles (table ou string)
        if type(Option) == "table" then
            MohaHub.Parametres.GrabMode = Option[1]
        else
            MohaHub.Parametres.GrabMode = Option
        end
    end
})

TabSteal:CreateSlider({
    Name = "Délai de vol (Sécurité)",
    Range = {0.1, 5.0},
    Increment = 0.1,
    CurrentValue = 1.0,
    Suffix = "s",
    Flag = "GrabDelay",
    Callback = function(Value)
        MohaHub.Parametres.GrabDelay = Value
    end
})

-- =============== TAB DEFENSE ===============
TabDefend:CreateSection("Bouclier Anti-Steal")

TabDefend:CreateToggle({
    Name = "Activer l'Auto-Recall",
    CurrentValue = false,
    Flag = "RecallToggle",
    Callback = function(Value)
        MohaHub.Parametres.AutoRecall_Actif = Value
    end
})

-- =============== TAB INFO ===============
TabInfo:CreateSection("Informations")

TabInfo:CreateParagraph({
    Title = "Moha Hub v8.4",
    Content = "Multi-Method Steal Engine\n\n"
        .. "Méthodes de vol :\n"
        .. "1. ProximityPrompt (le plus fiable)\n"
        .. "2. RemoteEvent/Function\n"
        .. "3. ClickDetector\n"
        .. "4. Remotes dans le Plot\n"
        .. "5. Bring Hitbox (dernier recours)"
})

TabInfo:CreateParagraph({
    Title = "Remote Grab Status",
    Content = RemoteGrab and ("Trouvé : " .. RemoteGrab:GetFullName()) or "Non trouvé (Méthodes 2 & 7 désactivées)"
})

print("[MohaHub] v8.4 chargé avec succès !")
print("[MohaHub] Remote Grab : " .. (RemoteGrab and RemoteGrab:GetFullName() or "NON TROUVÉ"))
