-- ==============================================================================
-- DIAGNOSTIC BOUTON TOGGLE - Test minimal
-- ==============================================================================

print("[TOGGLE-DIAG] Script started")

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Parent
local HubParent = gethui and gethui() or CoreGui
print("[TOGGLE-DIAG] Parent: " .. tostring(HubParent))

-- Cleanup
for _, child in pairs(HubParent:GetChildren()) do
    if child.Name == "TestToggleGUI" then
        child:Destroy()
        print("[TOGGLE-DIAG] Cleaned old GUI")
    end
end

-- Création GUI
local Gui = Instance.new("ScreenGui")
Gui.Name = "TestToggleGUI"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local success, err = pcall(function()
    Gui.Parent = HubParent
end)

if not success then
    print("[TOGGLE-DIAG] ERROR parenting GUI: " .. tostring(err))
    return
end

print("[TOGGLE-DIAG] GUI created")

-- Bouton Toggle (petit bouton rond)
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Name = "ToggleButton"
ToggleBtn.Size = UDim2.new(0, 60, 0, 60)
ToggleBtn.Position = UDim2.new(0, 30, 0.5, -30)
ToggleBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
ToggleBtn.Text = "⚡"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 30
ToggleBtn.Font = Enum.Font.GothamBlack
ToggleBtn.Parent = Gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = ToggleBtn

print("[TOGGLE-DIAG] Toggle button created at " .. tostring(ToggleBtn.Position))

-- Frame principale (cachée au début)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainPanel"
MainFrame.Size = UDim2.new(0, 300, 0, 200)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Visible = false -- Caché au début
MainFrame.Parent = Gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 12)
mainCorner.Parent = MainFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(130, 80, 255)
stroke.Thickness = 2
stroke.Parent = MainFrame

-- Titre dans la frame
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "MENU TEST"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 20
Title.Font = Enum.Font.GothamBold
Title.Parent = MainFrame

-- Texte d'état
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 30)
Status.Position = UDim2.new(0, 0, 0.5, 0)
Status.BackgroundTransparency = 1
Status.Text = "Clique le bouton ⚡"
Status.TextColor3 = Color3.fromRGB(200, 200, 200)
Status.TextSize = 14
Status.Parent = MainFrame

print("[TOGGLE-DIAG] Main frame created")

-- Variable d'état
local isOpen = false

-- CONNECTION BOUTON
print("[TOGGLE-DIAG] Connecting button...")

ToggleBtn.MouseButton1Click:Connect(function()
    print("[TOGGLE-DIAG] >>> BUTTON CLICKED! <<<")
    isOpen = not isOpen
    
    if isOpen then
        print("[TOGGLE-DIAG] Opening menu...")
        MainFrame.Visible = true
        MainFrame.Size = UDim2.new(0, 0, 0, 0)
        MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        TweenService:Create(MainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
            Size = UDim2.new(0, 300, 0, 200),
            Position = UDim2.new(0.5, -150, 0.5, -100)
        }):Play()
        
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 60, 90)
        Status.Text = "Menu OUVERT!"
        print("[TOGGLE-DIAG] Menu should be visible now")
    else
        print("[TOGGLE-DIAG] Closing menu...")
        TweenService:Create(MainFrame, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, 0, 0.5, 0)
        }):Play()
        
        task.delay(0.2, function()
            MainFrame.Visible = false
        end)
        
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(130, 80, 255)
        print("[TOGGLE-DIAG] Menu closed")
    end
end)

print("[TOGGLE-DIAG] Button connected")
print("[TOGGLE-DIAG] === READY ===")
print("[TOGGLE-DIAG] Clique sur le bouton violet ⚡ en haut à gauche")
