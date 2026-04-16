-- ==============================================================================
-- DIAGNOSTIC MINIMAL V11 - Steal A Brainrot
-- Objectif: Identifier l'étape exacte du blocage
-- ==============================================================================

print("[DIAG-001] === SCRIPT STARTED ===")

-- ====================== ÉTAPE 1: SERVICES ======================
print("[DIAG-002] Loading services...")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
print("[DIAG-003] Services loaded OK")

-- ====================== ÉTAPE 2: VARIABLES JOUEUR ======================
print("[DIAG-004] Getting LocalPlayer...")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    print("[DIAG-ERROR] LocalPlayer is NIL!")
    return
end
print("[DIAG-005] LocalPlayer OK: " .. tostring(LocalPlayer.Name))

print("[DIAG-006] Waiting for Character...")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
print("[DIAG-007] Character OK")

print("[DIAG-008] Waiting for HumanoidRootPart...")
local HRP = Character:WaitForChild("HumanoidRootPart")
print("[DIAG-009] HRP OK")

-- ====================== ÉTAPE 3: GUI PARENT (MOBILE) ======================
print("[DIAG-010] Determining GUI parent...")
local HubParent = nil

if gethui then
    print("[DIAG-011] gethui() exists, trying...")
    local success, result = pcall(function()
        return gethui()
    end)
    if success and result then
        HubParent = result
        print("[DIAG-012] gethui() SUCCESS")
    else
        print("[DIAG-013] gethui() FAILED: " .. tostring(result))
    end
else
    print("[DIAG-014] gethui() not available")
end

if not HubParent then
    print("[DIAG-015] Fallback to CoreGui...")
    HubParent = CoreGui
    print("[DIAG-016] CoreGui selected")
end

print("[DIAG-017] HubParent = " .. tostring(HubParent))

-- ====================== ÉTAPE 4: NETTOYAGE GUI EXISTANT ======================
print("[DIAG-018] Cleaning old GUIs...")
local cleaned = 0
for _, child in pairs(HubParent:GetChildren()) do
    if child.Name == "DiagV11_GUI" then
        child:Destroy()
        cleaned = cleaned + 1
    end
end
print("[DIAG-019] Cleaned " .. cleaned .. " old GUI(s)")

-- ====================== ÉTAPE 5: CRÉATION GUI ======================
print("[DIAG-020] Creating ScreenGui...")
local Gui = Instance.new("ScreenGui")
Gui.Name = "DiagV11_GUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

print("[DIAG-021] Parenting GUI...")
local parentSuccess, parentError = pcall(function()
    Gui.Parent = HubParent
end)

if not parentSuccess then
    print("[DIAG-ERROR] GUI Parenting FAILED: " .. tostring(parentError))
    return
end
print("[DIAG-022] GUI Parented OK")

-- ====================== ÉTAPE 6: CRÉATION FRAME PRINCIPALE ======================
print("[DIAG-023] Creating Main Frame...")
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 300, 0, 150)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -75)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = Gui
print("[DIAG-024] Main Frame created")

print("[DIAG-025] Adding corner...")
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = MainFrame
print("[DIAG-026] Corner added")

print("[DIAG-027] Adding stroke...")
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(130, 80, 255)
stroke.Thickness = 2
stroke.Parent = MainFrame
print("[DIAG-028] Stroke added")

-- ====================== ÉTAPE 7: TITRE ======================
print("[DIAG-029] Creating Title...")
local Title = Instance.new("TextLabel")
Title.Name = "Title"
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "DIAGNOSTIC V11"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame
print("[DIAG-030] Title created")

-- ====================== ÉTAPE 8: BOUTON TEST STEAL ======================
print("[DIAG-031] Creating Test Button...")
local TestButton = Instance.new("TextButton")
TestButton.Name = "TestStealBtn"
TestButton.Size = UDim2.new(0.8, 0, 0, 50)
TestButton.Position = UDim2.new(0.1, 0, 0.5, 0)
TestButton.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
TestButton.Text = "TEST STEAL"
TestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
TestButton.TextSize = 16
TestButton.Font = Enum.Font.GothamBold
TestButton.Parent = MainFrame
print("[DIAG-032] Test Button created")

print("[DIAG-033] Adding button corner...")
local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = TestButton
print("[DIAG-034] Button corner added")

-- ====================== ÉTAPE 9: STATUS LABEL ======================
print("[DIAG-035] Creating Status Label...")
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "Status"
StatusLabel.Size = UDim2.new(1, -20, 0, 30)
StatusLabel.Position = UDim2.new(0, 10, 1, -35)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Ready"
StatusLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center
StatusLabel.Parent = MainFrame
print("[DIAG-036] Status Label created")

-- ====================== ÉTAPE 10: DRAGGABLE ======================
print("[DIAG-037] Making frame draggable...")
local dragging = false
local dragStart = nil
local startPos = nil

MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        print("[DIAG-038] Drag started")
    end
end)

MainFrame.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, 
            startPos.X.Offset + delta.X, 
            startPos.Y.Scale, 
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or 
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
print("[DIAG-039] Draggable setup complete")

-- ====================== ÉTAPE 11: FONCTION STEAL ======================
print("[DIAG-040] Defining Steal function...")

local function TrySteal()
    print("[DIAG-041] === STEAL ATTEMPT STARTED ===")
    StatusLabel.Text = "Status: Steal started..."
    StatusLabel.TextColor3 = Color3.fromRGB(255, 210, 50)
    
    -- Étape 11a: Vérifier Plots
    print("[DIAG-042] Looking for Workspace.Plots...")
    local Plots = Workspace:FindFirstChild("Plots")
    if not Plots then
        print("[DIAG-ERROR] Workspace.Plots NOT FOUND!")
        StatusLabel.Text = "Status: ERROR - Plots not found"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    print("[DIAG-043] Plots found: " .. tostring(#Plots:GetChildren()) .. " children")
    
    -- Étape 11b: Chercher AnimalPodiums
    print("[DIAG-044] Searching for AnimalPodiums...")
    local allBrainrots = {}
    
    for _, plot in pairs(Plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            for _, brainrot in pairs(podiums:GetChildren()) do
                if brainrot:IsA("Model") then
                    table.insert(allBrainrots, brainrot)
                end
            end
        end
    end
    
    print("[DIAG-045] Found " .. tostring(#allBrainrots) .. " brainrot models")
    
    if #allBrainrots == 0 then
        print("[DIAG-ERROR] No brainrots found!")
        StatusLabel.Text = "Status: No brainrots found"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    
    -- Étape 11c: Trouver le plus proche
    print("[DIAG-046] Finding nearest brainrot...")
    local nearest = nil
    local shortestDist = math.huge
    
    for _, brainrot in pairs(allBrainrots) do
        local rootPart = brainrot:FindFirstChild("RootPart")
        if rootPart then
            local dist = (rootPart.Position - HRP.Position).Magnitude
            if dist < shortestDist then
                shortestDist = dist
                nearest = brainrot
            end
        end
    end
    
    if not nearest then
        print("[DIAG-ERROR] No brainrot with RootPart found!")
        StatusLabel.Text = "Status: No valid target"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    
    print("[DIAG-047] Target: " .. nearest.Name .. " at " .. tostring(math.floor(shortestDist)) .. " studs")
    StatusLabel.Text = "Status: Target: " .. nearest.Name
    
    -- Étape 11d: Chercher le ProximityPrompt
    print("[DIAG-048] Looking for ProximityPrompt...")
    local base = nearest:FindFirstChild("Base")
    if not base then
        print("[DIAG-ERROR] Base not found in brainrot!")
        StatusLabel.Text = "Status: ERROR - No Base"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    print("[DIAG-049] Base found")
    
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then
        print("[DIAG-ERROR] Spawn not found in Base!")
        StatusLabel.Text = "Status: ERROR - No Spawn"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    print("[DIAG-050] Spawn found")
    
    local attachment = spawn:FindFirstChild("PromptAttachment")
    if not attachment then
        print("[DIAG-ERROR] PromptAttachment not found!")
        StatusLabel.Text = "Status: ERROR - No Attachment"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    print("[DIAG-051] PromptAttachment found")
    
    local prompt = attachment:FindFirstChildWhichIsA("ProximityPrompt")
    if not prompt then
        print("[DIAG-ERROR] ProximityPrompt not found!")
        StatusLabel.Text = "Status: ERROR - No Prompt"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
        return
    end
    print("[DIAG-052] ProximityPrompt found!")
    
    -- Étape 11e: Téléportation proche (optionnel mais utile)
    print("[DIAG-053] Teleporting close to target...")
    local targetPos = nearest:GetPivot().Position + Vector3.new(0, 5, 5)
    HRP.CFrame = CFrame.new(targetPos)
    print("[DIAG-054] Teleported")
    
    task.wait(0.3)
    
    -- Étape 11f: Fire le prompt
    print("[DIAG-055] Firing ProximityPrompt...")
    if fireproximityprompt then
        print("[DIAG-056] Using fireproximityprompt...")
        fireproximityprompt(prompt, 0)
        print("[DIAG-057] fireproximityprompt executed")
    else
        print("[DIAG-058] fireproximityprompt not available, using manual method...")
        prompt:InputHoldBegin()
        task.wait(0.1)
        prompt:InputHoldEnd()
        print("[DIAG-059] Manual prompt interaction done")
    end
    
    -- Étape 11g: Chercher le Remote
    print("[DIAG-060] Looking for DeliverySteal remote...")
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
        print("[DIAG-061] Remote found, firing...")
        remote:FireServer()
        print("[DIAG-062] Remote fired")
    else
        print("[DIAG-WARNING] DeliverySteal remote not found!")
    end
    
    StatusLabel.Text = "Status: Steal attempted!"
    StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 150)
    print("[DIAG-063] === STEAL ATTEMPT COMPLETE ===")
end

print("[DIAG-064] Steal function defined")

-- ====================== ÉTAPE 12: CONNECTION BOUTON ======================
print("[DIAG-065] Connecting button...")

TestButton.MouseButton1Click:Connect(function()
    print("[DIAG-066] BUTTON CLICKED!")
    TestButton.BackgroundColor3 = Color3.fromRGB(100, 60, 200)
    
    local success, err = pcall(TrySteal)
    
    if not success then
        print("[DIAG-ERROR] Steal crashed: " .. tostring(err))
        StatusLabel.Text = "Status: CRASH - " .. tostring(err):sub(1, 30)
        StatusLabel.TextColor3 = Color3.fromRGB(255, 60, 90)
    end
    
    task.wait(0.2)
    TestButton.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
end)

print("[DIAG-067] Button connected")

-- ====================== ÉTAPE 13: ANIMATION D'ENTRÉE ======================
print("[DIAG-068] Playing entry animation...")
MainFrame.Size = UDim2.new(0, 0, 0, 0)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

TweenService:Create(MainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
    Size = UDim2.new(0, 300, 0, 150),
    Position = UDim2.new(0.5, -150, 0.5, -75)
}):Play()

print("[DIAG-069] Animation started")

-- ====================== ÉTAPE 14: FINAL ======================
print("[DIAG-070] === DIAGNOSTIC GUI FULLY LOADED ===")
print("[DIAG-071] If you see this, the GUI should be visible on screen")
print("[DIAG-072] Click the 'TEST STEAL' button to test the steal mechanic")

StatusLabel.Text = "Status: Ready - Click button to test"
