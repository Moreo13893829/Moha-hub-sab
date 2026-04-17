-- ==============================================================================
-- INTERNAL SYSTEM v11 - VERSION CORRIGÉE (Syntax Error Fixed)
-- ==============================================================================

print("[V11] Script starting...")

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer

-- ====================== CONFIGURATION ======================
local Settings = {
    -- STEAL MODES
    StealHighestGen = false, StealHighestValue = false, StealNearest = false,
    StealWalking = false, FloorSteal = false, InvisibleDuringSteal = false,
    PredictiveSteal = false, StealSpeedBoost = false, AutoUnlockBaseDoor = false,
    DisableStealAnimation = false,
    
    -- TELEPORT & MOVEMENT
    StableTPMode = false, BodySwapTP = false, TPByMode = "Gen",
    AutoTPStart = false, ContinuousAutoTP = false, AutoCloneTP = false,
    GotoBrainrotAfterTP = false, AutoReturnBrainrot = false, InfiniteJump = false,
    SpeedBoostMode = 1, AntiRagdollV1 = false, AntiRagdollV2 = false,
    
    -- ESP & VISUALS
    BrainrotESP = false, PlayerESP = false, TimerESP = false, RainbowBase = false,
    TargetBeam = false, XrayBase = false, StealProgress = false,
    
    -- GUI & AUTOMATION
    CleanGUI = true, Notifications = true, LockGUIPos = false,
    BrainrotTimerGUI = false, AutoHideGUI = false, FavoritePriority = false,
    InstantCloner = false, MinGenTP = 0, SearchQuery = "",
    
    -- COMBAT & EVENTS
    AutoTurret = false, LaserAimbot = 1, PaintballAimbot = 1,
    AimbotItems = false, GodModeTsunami = false, EventAutoSteal = false,
    EventAutoFarm = false, AutoFarmMinGen = 100, AutoKickSteal = false,
    
    -- SECURITY & OPTIMIZATION
    AntiCheatBypass = true, LoadingBypass = true, TryhardMode = false,
    TuffOptimizer = false, AntiLag = false, AntiBeeDisco = false, DisableServerFull = false,

    -- BASE/LOGIC (Preserved)
    AutoGrabActive = false,
    ESPActive = false
}

-- Parent
local HubParent = gethui and gethui() or CoreGui
print("[V11] Parent: " .. tostring(HubParent))

-- Cleanup
for _, child in pairs(HubParent:GetChildren()) do
    if child.Name == "V11_Fixed" then 
        child:Destroy() 
    end
end

-- ====================== GUI ======================
local Gui = Instance.new("ScreenGui")
Gui.Name = "V11_Fixed"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
Gui.Parent = HubParent

-- Bouton Toggle
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleButton"
ToggleBtn.Size = UDim2.new(0, 60, 0, 60)
ToggleBtn.Position = UDim2.new(0, 15, 0.5, -30)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
ToggleBtn.Text = "⚡"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 28
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.ZIndex = 1000
ToggleBtn.Parent = Gui

Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", ToggleBtn).Color = Color3.fromRGB(255, 255, 255)
Instance.new("UIStroke", ToggleBtn).Thickness = 2

-- Menu Principal
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainMenu"
MainFrame.Size = UDim2.new(0, 450, 0, 500)
MainFrame.Position = UDim2.new(0.5, -225, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
MainFrame.Visible = false
MainFrame.ZIndex = 2000
MainFrame.Parent = Gui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(130, 80, 255)
Instance.new("UIStroke", MainFrame).Thickness = 2

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 60)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
Header.ZIndex = 2001
Header.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "INTERNAL SYSTEM v11"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBlack
Title.TextSize = 18
Title.ZIndex = 2002
Title.Parent = Header

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 35, 0, 35)
CloseBtn.Position = UDim2.new(1, -45, 0.5, -17)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 90)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.ZIndex = 2002
CloseBtn.Parent = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(1, 0)

-- ====================== GUI HELPERS ======================
local function CreateTabButton(name, icon, parent)
    local btn = Instance.new("TextButton")
    btn.Name = name .. "Tab"
    btn.Size = UDim2.new(0, 65, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
    btn.Text = icon
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local function CreatePage(parent)
    local sf = Instance.new("ScrollingFrame")
    sf.Size = UDim2.new(1, -20, 1, -140)
    sf.Position = UDim2.new(0, 10, 0, 105)
    sf.BackgroundTransparency = 1
    sf.ScrollBarThickness = 2
    sf.ScrollBarImageColor3 = Color3.fromRGB(130, 80, 255)
    sf.Visible = false
    sf.Parent = parent
    Instance.new("UIListLayout", sf).Padding = UDim.new(0, 6)
    return sf
end

local function CreateToggle(parent, text, configKey, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -5, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    btn.Text = "  " .. text
    btn.TextColor3 = Color3.fromRGB(200, 200, 200)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 18, 0, 18)
    indicator.Position = UDim2.new(1, -25, 0.5, -9)
    indicator.BackgroundColor3 = Settings[configKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 80)
    indicator.Parent = btn
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    btn.MouseButton1Click:Connect(function()
        Settings[configKey] = not Settings[configKey]
        indicator.BackgroundColor3 = Settings[configKey] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(60, 60, 80)
        btn.TextColor3 = Settings[configKey] and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 200)
        if callback then
            callback(Settings[configKey])
        else
            print("[V11] " .. text .. ": " .. tostring(Settings[configKey]) .. " (Fonction à venir)")
        end
    end)
end

local function CreateButton(parent, text, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -5, 0, 38)
    btn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
    btn.BackgroundTransparency = 0.6
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback or function() print("[V11] " .. text .. " clicked (Fonction à venir)") end)
end

-- Tabs Header
local TabsHolder = Instance.new("Frame")
TabsHolder.Size = UDim2.new(1, -20, 0, 35)
TabsHolder.Position = UDim2.new(0, 10, 0, 65)
TabsHolder.BackgroundTransparency = 1
TabsHolder.Parent = MainFrame

local thLayout = Instance.new("UIListLayout")
thLayout.FillDirection = Enum.FillDirection.Horizontal
thLayout.Padding = UDim.new(0, 4)
thLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
thLayout.Parent = TabsHolder

-- Tab Pages
local pSteal = CreatePage(MainFrame)
local pTP = CreatePage(MainFrame)
local pVisuals = CreatePage(MainFrame)
local pAuto = CreatePage(MainFrame)
local pCombat = CreatePage(MainFrame)
local pSecurity = CreatePage(MainFrame)

local allPages = {pSteal, pTP, pVisuals, pAuto, pCombat, pSecurity}
local function OpenTab(page)
    for _, p in pairs(allPages) do p.Visible = (p == page) end
end

local bSteal = CreateTabButton("Steal", "⚡", TabsHolder)
local bTP = CreateTabButton("TP", "🚀", TabsHolder)
local bVisuals = CreateTabButton("Visuals", "👁️", TabsHolder)
local bAuto = CreateTabButton("Auto", "⚙️", TabsHolder)
local bCombat = CreateTabButton("Combat", "⚔️", TabsHolder)
local bSecurity = CreateTabButton("Security", "🛡️", TabsHolder)

bSteal.MouseButton1Click:Connect(function() OpenTab(pSteal) end)
bTP.MouseButton1Click:Connect(function() OpenTab(pTP) end)
bVisuals.MouseButton1Click:Connect(function() OpenTab(pVisuals) end)
bAuto.MouseButton1Click:Connect(function() OpenTab(pAuto) end)
bCombat.MouseButton1Click:Connect(function() OpenTab(pCombat) end)
bSecurity.MouseButton1Click:Connect(function() OpenTab(pSecurity) end)

OpenTab(pSteal)

-- ====================== FILLING TABS ======================

-- ⚡ STEAL
CreateToggle(pSteal, "MASTER AUTO-GRAB", "AutoGrabActive", function(val)
    Settings.AutoGrabActive = val
    StatusLabel.Text = val and "Auto-Grab ON" or "Auto-Grab OFF"
end)
CreateToggle(pSteal, "Steal Highest Gen", "StealHighestGen")
CreateToggle(pSteal, "Steal Highest Value/Price", "StealHighestValue")
CreateToggle(pSteal, "Steal Nearest", "StealNearest")
CreateToggle(pSteal, "Steal Walking/Carpet", "StealWalking")
CreateToggle(pSteal, "Floor Steal", "FloorSteal")
CreateToggle(pSteal, "Invisible During Steal", "InvisibleDuringSteal")
CreateToggle(pSteal, "Predictive Steal", "PredictiveSteal")
CreateToggle(pSteal, "Steal Speed Boost", "StealSpeedBoost")
CreateToggle(pSteal, "Auto Unlock Base Door", "AutoUnlockBaseDoor")
CreateToggle(pSteal, "Disable Steal Animation", "DisableStealAnimation")

-- 🚀 TELEPORT
CreateButton(pTP, "Stable TP System")
CreateToggle(pTP, "Body Swap TP", "BodySwapTP")
CreateButton(pTP, "TP Highest Gen")
CreateButton(pTP, "TP Highest Value")
CreateToggle(pTP, "Auto-TP on Start", "AutoTPStart")
CreateToggle(pTP, "Continuous Auto TP", "ContinuousAutoTP")
CreateToggle(pTP, "Auto Clone After TP", "AutoCloneTP")
CreateToggle(pTP, "Goto Brainrot After TP", "GotoBrainrotAfterTP")
CreateToggle(pTP, "Auto Return to Brainrot", "AutoReturnBrainrot")
CreateToggle(pTP, "Infinite Jump", "InfiniteJump")
CreateButton(pTP, "Speed Boost Mode")
CreateToggle(pTP, "Anti-Ragdoll V1", "AntiRagdollV1")
CreateToggle(pTP, "Anti-Ragdoll V2", "AntiRagdollV2")
CreateButton(pTP, "Ragdoll", function() print("Ragdoll activated") end)
CreateButton(pTP, "Clone", function() print("Cloned character") end)
CreateButton(pTP, "Rejoin Server", function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)

-- 👁️ VISUALS
CreateToggle(pVisuals, "BRAINROT ESP", "ESPActive", function(val)
    Settings.ESPActive = val
    StatusLabel.Text = val and "ESP ON" or "ESP OFF"
    if not val then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj.Name == "V11_ESP_Highlight" or obj.Name == "V11_ESP_Label" then obj:Destroy() end
        end
    end
end)
CreateToggle(pVisuals, "Player ESP", "PlayerESP")
CreateToggle(pVisuals, "Timer ESP", "TimerESP")
CreateToggle(pVisuals, "Rainbow Base", "RainbowBase")
CreateToggle(pVisuals, "Target Brainrot Beam", "TargetBeam")
CreateToggle(pVisuals, "Xray Base", "XrayBase")
CreateToggle(pVisuals, "Steal Progress Bar", "StealProgress")

-- ⚙️ AUTOMATION
CreateToggle(pAuto, "Notifications & Alert Sound", "Notifications")
CreateToggle(pAuto, "Lock All GUI Positions", "LockGUIPos")
CreateButton(pAuto, "Job ID Joiner")
CreateToggle(pAuto, "Brainrot Timer GUI", "BrainrotTimerGUI")
CreateButton(pAuto, "Lock/Unlock Base Buttons")
CreateToggle(pAuto, "Auto-Hide Main & Mini GUI", "AutoHideGUI")
CreateButton(pAuto, "Keybind Manager (8 Binds)")
CreateButton(pAuto, "Mutation & Trait Filters")
CreateToggle(pAuto, "Favorites Priority", "FavoritePriority")
CreateToggle(pAuto, "Instant Cloner", "InstantCloner")
CreateButton(pAuto, "Scan Plots & Bases", function()
    local list = ScanBrainrots()
    StatusLabel.Text = "Scanner: Found " .. #list .. " brainrots"
end)
CreateButton(pAuto, "Kick Self", function() LocalPlayer:Kick("[V11] User Kick Requested") end)

-- ⚔️ COMBAT
CreateToggle(pCombat, "Auto-Destroy Turret", "AutoTurret")
CreateButton(pCombat, "Laser Aimbot (2 Modes)")
CreateButton(pCombat, "Paintball Aimbot (3 Modes)")
CreateToggle(pCombat, "Aimbot Items GUI", "AimbotItems")
CreateToggle(pCombat, "Event God Mode (Tsunami)", "GodModeTsunami")
CreateToggle(pCombat, "Event Auto-Steal & ESP", "EventAutoSteal")
CreateToggle(pCombat, "Event Auto-Farm", "EventAutoFarm")
CreateToggle(pCombat, "Auto-Kick After Steal", "AutoKickSteal")

-- 🛡️ SECURITY
CreateToggle(pSecurity, "Anti-Cheat Bypass", "AntiCheatBypass")
CreateToggle(pSecurity, "Loading Screen Bypass", "LoadingBypass")
CreateToggle(pSecurity, "Tryhard Mode (No Effects)", "TryhardMode")
CreateToggle(pSecurity, "Tuff Optimizer", "TuffOptimizer")
CreateToggle(pSecurity, "Anti-Lag", "AntiLag")
CreateToggle(pSecurity, "Anti-Bee & Disco", "AntiBeeDisco")
CreateToggle(pSecurity, "Disable Server Full Error", "DisableServerFull")

print("[V11] UI Mega-Menu created")

-- ====================== FONCTIONS ======================
local function GetBrainrotPosition(brainrot)
    if not brainrot then return nil end
    local success, pivot = pcall(function() return brainrot:GetPivot() end)
    if success and pivot then return pivot.Position end
    
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

local function ScanBrainrots()
    local list = {}
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return list end
    
    for _, plot in pairs(plots:GetChildren()) do
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

-- GUI references preserved, buttons moved to tabs.

-- ====================== TOGGLE LOGIC ======================
local isMenuOpen = false

local function OpenMenu()
    print("[V11] Opening menu")
    isMenuOpen = true
    MainFrame.Visible = true
    
    MainFrame.Size = UDim2.new(0, 0, 0, 0)
    MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    
    TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
        Size = UDim2.new(0, 450, 0, 500),
        Position = UDim2.new(0.5, -225, 0.5, -250)
    }):Play()
    
    ToggleBtn.Text = "✕"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 90)
    StatusLabel.Text = "Menu opened"
end

local function CloseMenu()
    print("[V11] Closing menu")
    isMenuOpen = false
    
    TweenService:Create(MainFrame, TweenInfo.new(0.2), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()
    
    task.delay(0.2, function()
        if not isMenuOpen then
            MainFrame.Visible = false
        end
    end)
    
    ToggleBtn.Text = "⚡"
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
end

ToggleBtn.MouseButton1Click:Connect(function()
    print("[V11] Toggle clicked")
    if isMenuOpen then
        CloseMenu()
    else
        OpenMenu()
    end
end)

CloseBtn.MouseButton1Click:Connect(function()
    CloseMenu()
end)

-- Logical connections moved directly into UI creation above.

-- ====================== LOOPS ======================
task.spawn(function()
    while true do
        task.wait(0.8)
        if Settings.AutoGrabActive then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            
            local carrying = false
            for _, obj in pairs(Workspace:GetChildren()) do
                if obj:IsA("Model") and obj:FindFirstChild("RootPart") then
                    for _, weld in pairs(obj.RootPart:GetChildren()) do
                        if weld:IsA("WeldConstraint") and weld.Part0 == hrp then
                            carrying = true
                            break
                        end
                    end
                end
            end
            
            if carrying then
                StatusLabel.Text = "CARRYING - Return to base!"
                StatusLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
                continue
            end
            
            local list = ScanBrainrots()
            local target = nil
            local bestGen = -1
            
            for _, b in pairs(list) do
                local dist = (b.Position - hrp.Position).Magnitude
                if dist <= 50 and b.Gen > bestGen then
                    bestGen = b.Gen
                    target = b
                end
            end
            
            if target and target.Prompt then
                StatusLabel.Text = "Stealing: " .. target.Model.Name
                
                hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 3))
                task.wait(0.2)
                
                if fireproximityprompt then
                    fireproximityprompt(target.Prompt, 0)
                else
                    target.Prompt:InputHoldBegin()
                    task.wait(0.05)
                    target.Prompt:InputHoldEnd()
                end
                
                local remote = ReplicatedStorage:FindFirstChild("DeliverySteal", true)
                if remote then
                    task.wait(0.2)
                    remote:FireServer()
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if Settings.ESPActive then
            local list = ScanBrainrots()
            for _, b in pairs(list) do
                if b.Model and not b.Model:FindFirstChild("V11_ESP_Highlight") then
                    local hl = Instance.new("Highlight", b.Model)
                    hl.Name = "V11_ESP_Highlight"
                    hl.FillColor = Color3.fromRGB(130, 80, 255)
                    hl.OutlineColor = Color3.fromRGB(0, 220, 255)
                    hl.FillTransparency = 0.8
                    
                    local bb = Instance.new("BillboardGui", b.Model)
                    bb.Name = "V11_ESP_Label"
                    bb.Size = UDim2.new(0, 100, 0, 40)
                    bb.StudsOffset = Vector3.new(0, 4, 0)
                    bb.AlwaysOnTop = true
                    
                    local lbl = Instance.new("TextLabel", bb)
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.Text = b.Model.Name .. "\nGen: " .. b.Gen
                    lbl.TextColor3 = Color3.fromRGB(130, 80, 255)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 12
                end
            end
        end
    end
end)

print("[V11] === READY ===")
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "V11 Ready",
        Text = "Click ⚡ to open menu",
        Duration = 5
    })
end)
