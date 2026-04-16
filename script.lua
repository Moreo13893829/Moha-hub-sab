-- ==============================================================================
-- DIAGNOSTIC V11-CORRIGÉ - Steal A Brainrot
-- Correction: Détection de position sans RootPart
-- ==============================================================================

print("[DIAG2-001] === SCRIPT STARTED ===")

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local HRP = Character:WaitForChild("HumanoidRootPart")

-- GUI Parent (Mobile)
local HubParent = gethui and gethui() or CoreGui

-- Cleanup
for _, child in pairs(HubParent:GetChildren()) do
    if child.Name == "DiagV11C_GUI" then child:Destroy() end
end

-- GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "DiagV11C_GUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = HubParent

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 200)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.Parent = Gui

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(130, 80, 255)
Instance.new("UIStroke", MainFrame).Thickness = 2

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.Position = UDim2.new(0, 0, 0, 5)
Title.BackgroundTransparency = 1
Title.Text = "DIAGNOSTIC V11-CORRIGÉ"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

-- Bouton Test Steal
local TestBtn = Instance.new("TextButton")
TestBtn.Size = UDim2.new(0.9, 0, 0, 40)
TestBtn.Position = UDim2.new(0.05, 0, 0.25, 0)
TestBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
TestBtn.Text = "TEST STEAL (CORRIGÉ)"
TestBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
TestBtn.TextSize = 14
TestBtn.Font = Enum.Font.GothamBold
TestBtn.Parent = MainFrame
Instance.new("UICorner", TestBtn).CornerRadius = UDim.new(0, 8)

-- Bouton Inspect Structure
local InspectBtn = Instance.new("TextButton")
InspectBtn.Size = UDim2.new(0.9, 0, 0, 35)
InspectBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
InspectBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 255)
InspectBtn.Text = "INSPECTER STRUCTURE"
InspectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
InspectBtn.TextSize = 12
InspectBtn.Font = Enum.Font.GothamBold
InspectBtn.Parent = MainFrame
Instance.new("UICorner", InspectBtn).CornerRadius = UDim.new(0, 8)

-- Status
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 50)
Status.Position = UDim2.new(0, 10, 0.75, 0)
Status.BackgroundTransparency = 1
Status.Text = "Status: Prêt"
Status.TextColor3 = Color3.fromRGB(170, 170, 170)
Status.TextSize = 11
Status.Font = Enum.Font.Gotham
Status.TextWrapped = true
Status.Parent = MainFrame

-- Draggable
local dragging = false
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- FONCTION: Obtenir la position d'un brainrot (MULTI-MÉTHODES)
-- ============================================================
local function GetBrainrotPosition(brainrot)
    print("[DIAG2] Checking brainrot: " .. brainrot.Name)
    
    -- Méthode 1: GetPivot() (fonctionne sur tous les Models)
    local success, pivot = pcall(function()
        return brainrot:GetPivot()
    end)
    if success and pivot then
        print("[DIAG2]  ✓ GetPivot() OK: " .. tostring(pivot.Position))
        return pivot.Position
    end
    
    -- Méthode 2: PrimaryPart
    if brainrot.PrimaryPart then
        print("[DIAG2]  ✓ PrimaryPart OK")
        return brainrot.PrimaryPart.Position
    end
    
    -- Méthode 3: Chercher Base -> Spawn
    local base = brainrot:FindFirstChild("Base")
    if base then
        if base:IsA("BasePart") then
            print("[DIAG2]  ✓ Base (BasePart) OK")
            return base.Position
        end
        local spawn = base:FindFirstChild("Spawn")
        if spawn and spawn:IsA("BasePart") then
            print("[DIAG2]  ✓ Base.Spawn OK")
            return spawn.Position
        end
    end
    
    -- Méthode 4: Premier BasePart trouvé
    for _, child in pairs(brainrot:GetDescendants()) do
        if child:IsA("BasePart") then
            print("[DIAG2]  ✓ First BasePart found: " .. child.Name)
            return child.Position
        end
    end
    
    print("[DIAG2]  ✗ No position found!")
    return nil
end

-- ============================================================
-- FONCTION: Obtenir le Prompt d'un brainrot
-- ============================================================
local function GetBrainrotPrompt(brainrot)
    local base = brainrot:FindFirstChild("Base")
    if not base then return nil end
    
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    
    local attachment = spawn:FindFirstChild("PromptAttachment")
    if not attachment then return nil end
    
    return attachment:FindFirstChildWhichIsA("ProximityPrompt")
end

-- ============================================================
-- BOUTON: INSPECTER STRUCTURE
-- ============================================================
InspectBtn.MouseButton1Click:Connect(function()
    print("[DIAG2] === STRUCTURE INSPECTION ===")
    Status.Text = "Inspection..."
    
    local Plots = Workspace:FindFirstChild("Plots")
    if not Plots then
        Status.Text = "Plots non trouvé!"
        return
    end
    
    -- Prendre le premier plot avec des brainrots
    for _, plot in pairs(Plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums and #podiums:GetChildren() > 0 then
            local firstBrainrot = podiums:GetChildren()[1]
            print("[DIAG2] Inspecting: " .. firstBrainrot.Name)
            print("[DIAG2] Class: " .. firstBrainrot.ClassName)
            print("[DIAG2] Children:")
            
            for _, child in pairs(firstBrainrot:GetChildren()) do
                print("  - " .. child.Name .. " (" .. child.ClassName .. ")")
                if child:FindFirstChild("Spawn") then
                    print("    -> Has Spawn child!")
                end
            end
            
            -- Tester GetPivot
            local pos = GetBrainrotPosition(firstBrainrot)
            if pos then
                Status.Text = "Structure OK!\nPosition: " .. tostring(math.floor(pos.X)) .. "," .. tostring(math.floor(pos.Y)) .. "," .. tostring(math.floor(pos.Z))
                print("[DIAG2] Position found: " .. tostring(pos))
            else
                Status.Text = "Structure inconnue!"
            end
            return
        end
    end
end)

-- ============================================================
-- BOUTON: TEST STEAL CORRIGÉ
-- ============================================================
TestBtn.MouseButton1Click:Connect(function()
    print("[DIAG2] === TEST STEAL STARTED ===")
    Status.Text = "Recherche des brainrots..."
    Status.TextColor3 = Color3.fromRGB(255, 210, 50)
    
    local Plots = Workspace:FindFirstChild("Plots")
    if not Plots then
        Status.Text = "ERROR: Plots not found"
        Status.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    
    -- Collecter tous les brainrots avec leur position
    local brainrots = {}
    
    for _, plot in pairs(Plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            for _, brainrot in pairs(podiums:GetChildren()) do
                if brainrot:IsA("Model") then
                    local pos = GetBrainrotPosition(brainrot)
                    if pos then
                        table.insert(brainrots, {
                            Model = brainrot,
                            Position = pos,
                            Prompt = GetBrainrotPrompt(brainrot)
                        })
                    end
                end
            end
        end
    end
    
    print("[DIAG2] Found " .. #brainrots .. " brainrots with valid positions")
    
    if #brainrots == 0 then
        Status.Text = "ERROR: Aucun brainrot avec position!"
        Status.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    
    -- Trouver le plus proche
    local nearest = nil
    local minDist = math.huge
    
    for _, data in pairs(brainrots) do
        local dist = (data.Position - HRP.Position).Magnitude
        if dist < minDist then
            minDist = dist
            nearest = data
        end
    end
    
    if not nearest then
        Status.Text = "ERROR: Pas de cible trouvée"
        return
    end
    
    print("[DIAG2] Target: " .. nearest.Model.Name .. " at " .. math.floor(minDist) .. " studs")
    Status.Text = "Cible: " .. nearest.Model.Name .. "\nDistance: " .. math.floor(minDist)
    
    -- Vérifier le prompt
    if not nearest.Prompt then
        print("[DIAG2] ERROR: No ProximityPrompt on target!")
        Status.Text = "ERROR: Pas de Prompt sur " .. nearest.Model.Name
        Status.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    
    print("[DIAG2] Prompt found!")
    
    -- Téléportation proche
    print("[DIAG2] Teleporting...")
    local targetPos = nearest.Position + Vector3.new(0, 3, 3)
    HRP.CFrame = CFrame.new(targetPos)
    Status.Text = "Téléportation..."
    
    task.wait(0.3)
    
    -- Fire le prompt
    print("[DIAG2] Firing prompt...")
    if fireproximityprompt then
        fireproximityprompt(nearest.Prompt, 0)
        print("[DIAG2] fireproximityprompt executed!")
    else
        nearest.Prompt:InputHoldBegin()
        task.wait(0.1)
        nearest.Prompt:InputHoldEnd()
        print("[DIAG2] Manual interaction done!")
    end
    
    -- Chercher et fire le remote
    task.wait(0.2)
    print("[DIAG2] Looking for DeliverySteal remote...")
    
    local remote = nil
    local packages = ReplicatedStorage:FindFirstChild("Packages")
    if packages then
        local net = packages:FindFirstChild("Net")
        if net then
            remote = net:FindFirstChild("RE/StealService/DeliverySteal")
        end
    end
    
    if not remote then
        remote = ReplicatedStorage:FindFirstChild("DeliverySteal", true)
    end
    
    if remote then
        print("[DIAG2] Firing remote...")
        remote:FireServer()
        Status.Text = "✓ Steal tenté sur " .. nearest.Model.Name
        Status.TextColor3 = Color3.fromRGB(0, 255, 150)
    else
        print("[DIAG2] Remote not found, but prompt fired!")
        Status.Text = "Prompt activé!\n(remote non trouvé)"
        Status.TextColor3 = Color3.fromRGB(255, 210, 50)
    end
    
    print("[DIAG2] === TEST COMPLETE ===")
end)

-- Animation d'entrée
MainFrame.Size = UDim2.new(0, 0, 0, 0)
TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 320, 0, 200)
}):Play()

print("[DIAG2-070] === GUI LOADED ===")
print("[DIAG2] Clique sur 'INSPECTER STRUCTURE' d'abord pour vérifier")
print("[DIAG2] Puis clique sur 'TEST STEAL (CORRIGÉ)'")
Status.Text = "Prêt! Clique 'INSPECTER STRUCTURE' d'abord"
