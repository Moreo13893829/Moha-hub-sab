--!nocheck
-- Global upvalues and fallbacks to suppress IDE warnings and ensure cross-executor compatibility
local writefile = _G.writefile or function() end
local readfile = _G.readfile or function() return "" end
local isfile = _G.isfile or function() return false end
local getconnections = _G.getconnections or function() return {} end
local fireproximityprompt = _G.fireproximityprompt or function() end
local setfflag = _G.setfflag or function() end
local setfflags = _G.setfflags or function() end
local require = _G.require or require

local Lighting = game:GetService("Lighting")
local Workspace = workspace -- Redirect uppercase Workspace to lowercase workspace

local Config = { toggles = {}, panels = {}, sliders = {}, keybinds = {} }
local CONFIG_FILE = "zeno_config.json"
local configData = {
    SemiKeybind = "F",
    FullKeybind = "Y",
    ToggleUIKeybind = "F4",
    BalloonEnabled = false
}
local MainFrame = nil
local uiScale = nil
local ToggleHandlers = {}
local Toggles = {}

local UI_OPEN = true
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local UserInputService = UIS
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local player = LocalPlayer

-- =============================================
-- REFRACTORED & OPTIMIZED ENGINE HELPERS
-- =============================================
local gethui = rawget(getfenv(), "gethui") or _G.gethui
local CoreGui = game:GetService("CoreGui")
local function getUiParent()
    if gethui then
        local success, res = pcall(gethui)
        if success and res then return res end
    end
    if CoreGui then
        return CoreGui
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function getRandomName()
    local success, guid = pcall(function()
        return HttpService:GenerateGUID(false)
    end)
    if success and guid then
        return guid
    end
    return "Zeno_" .. tostring(math.random(100000, 999999))
end

local function teleportHRP(target)
    local lp = LocalPlayer
    local character = lp.Character or lp.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local targetCFrame = typeof(target) == "CFrame" and target or CFrame.new(target)
    local targetPosition = targetCFrame.Position
    
    if lp.RequestStreamAroundAsync then
        pcall(function()
            lp:RequestStreamAroundAsync(targetPosition)
        end)
    end
    
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    
    local distance = (hrp.Position - targetPosition).Magnitude
    if distance > 100 then
        local speed = 500
        local duration = math.clamp(distance / speed, 0.05, 0.4)
        local ti = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(hrp, ti, {CFrame = targetCFrame})
        
        local parts = {}
        for _, p in ipairs(character:GetDescendants()) do
            if p:IsA("BasePart") and not p.Anchored then
                p.Anchored = true
                table.insert(parts, p)
            end
        end
        
        tween:Play()
        tween.Completed:Wait()
        
        for _, p in ipairs(parts) do
            p.Anchored = false
        end
    else
        local ti = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        local tween = TweenService:Create(hrp, ti, {CFrame = targetCFrame})
        tween:Play()
        tween.Completed:Wait()
    end
end

local setToggleVisual = nil
local OpenInstantStealUI = nil
local AntiRagdollEnabled = false
local antiRagdollConnection = nil
local unlockBaseUI = nil
local autoGrabberEnabled = false
local _AutoGiantPotion = false
local _Mouse = LocalPlayer:GetMouse()
local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local isTablet = UIS.TouchEnabled and workspace.CurrentCamera.ViewportSize.X >= 768

local function getScaleFactor()
    local scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 1920, 0.5, 1.2)
    if isMobile and not isTablet then return math.clamp(scale * 0.85, 0.6, 0.9) end
    if isTablet then return math.clamp(scale * 1.0, 0.8, 1.1) end
    return scale
end
local Camera = workspace.CurrentCamera
local FriendsESPEnabled = false
local FriendsESPConnections = {}
local _PlayerESPEnabled = false
local PlayerESPData = {}
local PlayerESPConnections = {}

-- =============================================
-- RE-EXECUTE CLEANUP: Disconnect old connections & stop old loops
-- =============================================
if _G.ZenoHubConnections then
    for _, conn in ipairs(_G.ZenoHubConnections) do
        pcall(function() conn:Disconnect() end)
    end
end
_G.ZenoHubConnections = {}
_G.ZenoHubAlive = false -- signal old while loops to stop
task.wait() -- let old loops check the flag
_G.ZenoHubAlive = true

local function trackConnection(conn)
    table.insert(_G.ZenoHubConnections, conn)
    return conn
end

local function openAdminSpammerUI()
_G.AdminSpammerRunning = true

-- ðŸ”¥ REPLACE ALL CONFIG CODE WITH THIS (put at top, line ~100)

configData = Config.spammer or configData

local SemiKeybind = Enum.KeyCode[configData.SemiKeybind]
local FullKeybind = Enum.KeyCode[configData.FullKeybind]
local ToggleUIKeybind = Enum.KeyCode[configData.ToggleUIKeybind]
local BalloonEnabled = configData.BalloonEnabled

local waitingSemi = false
local waitingFull = false
local waitingToggleUI = false

local function getAdminFrames()
	local adminPanel = LocalPlayer.PlayerGui:FindFirstChild("AdminPanel")
	if not adminPanel then return end
	local panel = adminPanel:FindFirstChild("AdminPanel")
	if not panel then return end
	local content = panel:FindFirstChild("Content")
	local profiles = panel:FindFirstChild("Profiles")
	if not content or not profiles then return end
	return content:FindFirstChild("ScrollingFrame"), profiles:FindFirstChild("ScrollingFrame")
end

local function fireButton(guiObject)
	local ok, conns = pcall(getconnections, guiObject.Activated)
	if ok and type(conns) == "table" then
		for _, conn in ipairs(conns) do
			if type(conn.Function) == "function" then
				task.spawn(conn.Function)
			end
		end
	end
end

local function runCommandOnPlayer(commandName, target)
	local commandFrame, profileFrame = getAdminFrames()
	if not commandFrame or not profileFrame then return end

	local profileButton = profileFrame:FindFirstChild(target.Name)
	local commandButton = commandFrame:FindFirstChild(commandName)
	if not profileButton or not commandButton then return end

	fireButton(profileButton)
	task.wait(0.05)
	fireButton(commandButton)
	task.wait(0.05)
	fireButton(profileButton)
	task.wait(0.05)
	fireButton(commandButton)
end

if _G.ZenoAdminPanelInstance then
    pcall(function() _G.ZenoAdminPanelInstance:Destroy() end)
    _G.ZenoAdminPanelInstance = nil
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Parent = getUiParent()
ScreenGui.ResetOnSpawn = false
ScreenGui.Name = getRandomName()
ScreenGui.DisplayOrder = 999999
_G.ZenoAdminPanelInstance = ScreenGui
-- =============================================
-- ZENO TOGGLE BUTTON (ON UI - TOP RIGHT)
-- =============================================
local ZenoToggleBtn = Instance.new("TextButton")
ZenoToggleBtn.Name = "ZenoToggle"
ZenoToggleBtn.Size = isMobile and UDim2.new(0, 80, 0, 32) or UDim2.new(0, 90, 0, 32)
ZenoToggleBtn.Position = UDim2.new(1, isMobile and -88 or -98, 0, 8)
ZenoToggleBtn.BackgroundColor3 = Color3.fromRGB(10, 0, 0)
ZenoToggleBtn.BackgroundTransparency = 0.28  -- black with ~72% opacity = transparency
ZenoToggleBtn.Text = "Zeno â–¼"
ZenoToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ZenoToggleBtn.Font = Enum.Font.GothamBold
ZenoToggleBtn.TextSize = isMobile and 13 or 15
ZenoToggleBtn.BorderSizePixel = 0
ZenoToggleBtn.ZIndex = 1001
ZenoToggleBtn.Parent = ScreenGui  -- keeps it anchored to main frame

local ZenoCorner = Instance.new("UICorner")
ZenoCorner.CornerRadius = UDim.new(1, 0)  -- 
ZenoCorner.Parent = ZenoToggleBtn

local ZenoStroke = Instance.new("UIStroke")
ZenoStroke.Color = Color3.fromRGB(140, 80, 255)  -- red border
ZenoStroke.Thickness = 2
ZenoStroke.Parent = ZenoToggleBtn

-- Hover
ZenoToggleBtn.MouseEnter:Connect(function()
    TweenService:Create(ZenoToggleBtn, TweenInfo.new(0.18), {
        BackgroundTransparency = 0.15,
    }):Play()
end)
ZenoToggleBtn.MouseLeave:Connect(function()
    TweenService:Create(ZenoToggleBtn, TweenInfo.new(0.18), {
        BackgroundTransparency = 0.28,
    }):Play()
end)

-- Toggle
ZenoToggleBtn.MouseButton1Click:Connect(function()
    UI_OPEN = not UI_OPEN
    if UI_OPEN then
        MainFrame.Visible = true
        uiScale.Scale = 0.3
        TweenService:Create(uiScale, TweenInfo.new(0.35), {Scale = 1}):Play()
        ZenoToggleBtn.Text = "Zeno â–¼"
    else
        TweenService:Create(uiScale, TweenInfo.new(0.25), {Scale = 0.3}):Play()
        task.delay(0.25, function() MainFrame.Visible = false end)
        ZenoToggleBtn.Text = "Zeno â–²"
    end
end)

-- Mobile touch
ZenoToggleBtn.InputBegan:Connect(function(input_obj)
    if input_obj.UserInputType == Enum.UserInputType.Touch then
        UI_OPEN = not UI_OPEN
        if UI_OPEN then
            MainFrame.Visible = true
            uiScale.Scale = 0.3
            TweenService:Create(uiScale, TweenInfo.new(0.35), {Scale = 1}):Play()
            ZenoToggleBtn.Text = "Zeno â–¼"
        else
            TweenService:Create(uiScale, TweenInfo.new(0.25), {Scale = 0.3}):Play()
            task.delay(0.25, function() MainFrame.Visible = false end)
            ZenoToggleBtn.Text = "Zeno â–²"
        end
    end
end)


-- Mobile responsive sizing
local frameWidth = isMobile and 230 or 300
local frameHeight = isMobile and 290 or 380

local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, frameWidth, 0, frameHeight)
Main.Position = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
Main.AnchorPoint = Vector2.new(0.5, 0.5)
Main.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
Main.BackgroundTransparency = 0.15
Main.Active = false
Main.Parent = ScreenGui
Instance.new("UICorner",Main).CornerRadius = UDim.new(0,8)

local Stroke = Instance.new("UIStroke",Main)
Stroke.Color = Color3.fromRGB(140, 82, 255)
Stroke.Thickness = 1
Stroke.Transparency = 0.3
Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local Top = Instance.new("Frame",Main)
Top.Size = UDim2.new(1,0,0,42)
Top.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
Top.BackgroundTransparency = 0.2
Instance.new("UICorner",Top).CornerRadius = UDim.new(0,8)

-- Mobile drag handle
local DragHandle = Instance.new("TextButton")
DragHandle.Parent = Top
DragHandle.Size = UDim2.new(0,22,0,22)
DragHandle.Position = UDim2.new(0,6,0.5,-11)
DragHandle.BackgroundTransparency = 1
DragHandle.Text = "⋮⋮"
DragHandle.Font = Enum.Font.GothamBold
DragHandle.TextSize = 12
DragHandle.TextColor3 = Color3.fromRGB(160, 160, 200)
DragHandle.TextXAlignment = Enum.TextXAlignment.Center

local Title = Instance.new("TextLabel",Top)
Title.Size = UDim2.new(1,-55,1,0)
Title.Position = UDim2.new(0,30,0,0)
Title.BackgroundTransparency = 1
Title.Text = "ZENO SPAMMER"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = isMobile and 12 or 13
Title.TextXAlignment = Enum.TextXAlignment.Left

local Minimize = Instance.new("TextButton",Top)
Minimize.Size = UDim2.new(0,22,0,22)
Minimize.Position = UDim2.new(1,-28,0.5,-11)
Minimize.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Minimize.Text = "-"
Minimize.TextColor3 = Color3.new(1,1,1)
Minimize.Font = Enum.Font.GothamBold
Minimize.TextSize = 14
Instance.new("UICorner",Minimize).CornerRadius = UDim.new(0, 6)

local ToggleUI = Instance.new("TextButton", Top)
ToggleUI.Size = UDim2.new(0, 95, 0, 22)
ToggleUI.Position = UDim2.new(1, -130, 0.5, -11)
ToggleUI.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
ToggleUI.Text = "TOGGLE: " .. configData.ToggleUIKeybind
ToggleUI.TextColor3 = Color3.new(1, 1, 1)
ToggleUI.Font = Enum.Font.GothamBold
ToggleUI.TextSize = isMobile and 10 or 11
Instance.new("UICorner", ToggleUI).CornerRadius = UDim.new(0, 6)



-- Enhanced dragging system (PC + Mobile)
local dragging = false
local dragStart = nil
local startPos = nil
local touchConnection = nil

local function updateInputPosition(input)
	if dragging then
		local delta = input.Position - dragStart
		Main.Position = UDim2.new(
			startPos.X.Scale,
			startPos.X.Offset + delta.X,
			startPos.Y.Scale,
			startPos.Y.Offset + delta.Y
		)
	end
end

-- PC Mouse Dragging
Top.InputBegan:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input_obj.Position
		startPos = Main.Position
	end
end)

DragHandle.MouseButton1Down:Connect(function()
	dragging = true
	dragStart = UserInputService:GetMouseLocation()
	startPos = Main.Position
end)

UserInputService.InputChanged:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseMovement then
		updateInputPosition(input_obj)
	end
end)

UserInputService.InputEnded:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

-- Mobile Touch Dragging
DragHandle.InputBegan:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input_obj.Position
		startPos = Main.Position
		
		touchConnection = UserInputService.TouchMoved:Connect(function(touchPositions)
			local touchPos = touchPositions[1]
			if touchPos then
				updateInputPosition(touchPos)
			end
		end)
	end
end)

UserInputService.TouchEnded:Connect(function(input_obj, gameProcessed)
	if dragging then
		dragging = false
		if touchConnection then
			touchConnection:Disconnect()
			touchConnection = nil
		end
	end
end)

DragHandle.InputEnded:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		if touchConnection then
			touchConnection:Disconnect()
			touchConnection = nil
		end
	end
end)

ToggleUI.MouseButton2Click:Connect(function()
	if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) or isMobile then
		waitingToggleUI = true
		ToggleUI.Text = "TOGGLE: (...)"
	end
end)

local Content = Instance.new("Frame",Main)
Content.Size = UDim2.new(1,0,1,-38)
Content.Position = UDim2.new(0,0,0,38)
Content.BackgroundTransparency = 1

local Header = Instance.new("TextLabel",Content)
Header.Size = UDim2.new(1,-16,0,18)
Header.Position = UDim2.new(0,8,0,4)
Header.BackgroundTransparency = 1
Header.Text = "SELECT PLAYER TO SPAM"
Header.TextColor3 = Color3.fromRGB(140,140,140)
Header.Font = Enum.Font.Gotham
Header.TextSize = isMobile and 10 or 11
Header.TextXAlignment = Enum.TextXAlignment.Left

local StarBackground = Instance.new("Frame", Content)
StarBackground.Name = "StarBackground"
StarBackground.Size = UDim2.new(1, -16, 1, -60)
StarBackground.Position = UDim2.new(0, 8, 0, 22)
StarBackground.BackgroundTransparency = 1
StarBackground.ZIndex = 0

local PlayerList = Instance.new("ScrollingFrame",Content)
PlayerList.Size = UDim2.new(1,-16,1,-88)
PlayerList.Position = UDim2.new(0,8,0,22)
PlayerList.BackgroundTransparency = 1
PlayerList.ScrollBarThickness = isMobile and 6 or 4
PlayerList.ScrollBarImageColor3 = Color3.fromRGB(255,255,255)
PlayerList.ZIndex = 2

local Layout = Instance.new("UIListLayout",PlayerList)
Layout.Padding = UDim.new(0,4)

Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	PlayerList.CanvasSize = UDim2.new(0,0,0,Layout.AbsoluteContentSize.Y + 8)
end)

local dots = {}
local dotCount = isMobile and 20 or 30

local function createDot()
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, math.random(2, 3), 0, math.random(2, 3))
	dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
	dot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dot.BackgroundTransparency = math.random(75, 95) / 100
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner", dot)
	corner.CornerRadius = UDim.new(1, 0)
	dot.Parent = StarBackground
	
	local dotData = {
		frame = dot,
		speedX = (math.random() - 0.5) * 0.25,
		speedY = (math.random() - 0.5) * 0.25,
		sizeTween = TweenService:Create(dot, TweenInfo.new(math.random(3, 5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Size = UDim2.new(0, math.random(1, 2), 0, math.random(1, 2))})
	}
	
	dotData.sizeTween:Play()
	table.insert(dots, dotData)
end

for i = 1, dotCount do
	createDot()
end

RunService.Heartbeat:Connect(function()
    if not _G.AdminSpammerRunning then return end
	for i = #dots, 1, -1 do
		local dot = dots[i]
		if dot and dot.frame and dot.frame.Parent then
			local newX = dot.frame.Position.X.Offset + dot.speedX * 8
			local newY = dot.frame.Position.Y.Offset + dot.speedY * 8
			
			local bgSizeX = StarBackground.AbsoluteSize.X
			local bgSizeY = StarBackground.AbsoluteSize.Y
			
			if newX > bgSizeX then newX = newX - bgSizeX * 2
			elseif newX < -dot.frame.AbsoluteSize.X then newX = bgSizeX end
			if newY > bgSizeY then newY = newY - bgSizeY * 2
			elseif newY < -dot.frame.AbsoluteSize.Y then newY = bgSizeY end
			
			dot.frame.Position = UDim2.new(0, newX, 0, newY)
		else
			table.remove(dots, i)
		end
	end
end)

local function runSemiSpam(target)
	task.spawn(function()
		runCommandOnPlayer("rocket",target)
		task.wait(0.01)
		runCommandOnPlayer("jumpscare",target)
		task.wait(0.01)
		runCommandOnPlayer("morph",target)
		task.wait(0.01)
		if BalloonEnabled then
			runCommandOnPlayer("balloon",target)
		end
	end)
end

local function runFullSpam(target)
	task.spawn(function()
		runCommandOnPlayer("rocket",target)
		task.wait(0.01)
		runCommandOnPlayer("balloon",target)
		task.wait(0.01)
		runCommandOnPlayer("ragdoll",target)
		task.wait(0.01)
		runCommandOnPlayer("jumpscare",target)
		task.wait(0.01)
		runCommandOnPlayer("inverse",target)
		task.wait(0.01)
		runCommandOnPlayer("morph",target)
		task.wait(0.01)
		runCommandOnPlayer("jail",target)
	end)
end

local function CreatePlayerRow(plr)
	local Row = Instance.new("Frame",PlayerList)
	Row.Size = UDim2.new(1,0,0,36)
	Row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
	Row.BackgroundTransparency = 0.4
	Instance.new("UICorner",Row).CornerRadius = UDim.new(0, 6)

	local RowStroke = Instance.new("UIStroke", Row)
	RowStroke.Color = Color3.fromRGB(140, 82, 255)
	RowStroke.Thickness = 1
	RowStroke.Transparency = 0.85
	RowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local Avatar = Instance.new("ImageLabel",Row)
	Avatar.Size = UDim2.new(0,26,0,26)
	Avatar.Position = UDim2.new(0,6,0.5,-13)
	Avatar.BackgroundTransparency = 1
	Avatar.Image = Players:GetUserThumbnailAsync(plr.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
	local Corner = Instance.new("UICorner",Avatar)
	Corner.CornerRadius = UDim.new(1,0)

	local Name = Instance.new("TextLabel",Row)
	Name.Size = UDim2.new(0.48,0,1,0)
	Name.Position = UDim2.new(0,40,0,0)
	Name.BackgroundTransparency = 1
	Name.Text = plr.Name
	Name.TextColor3 = Color3.fromRGB(225, 225, 235)
	Name.Font = Enum.Font.GothamBold
	Name.TextSize = isMobile and 11 or 12
	Name.TextXAlignment = Enum.TextXAlignment.Left

	local Semi = Instance.new("TextButton",Row)
	Semi.Size = UDim2.new(0,48,0,22)
	Semi.Position = UDim2.new(1,-110,0.5,-11)
	Semi.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	Semi.Text = "SEMI ("..configData.SemiKeybind..")"
	Semi.TextColor3 = Color3.new(1,1,1)
	Semi.Font = Enum.Font.GothamBold
	Semi.TextSize = isMobile and 9 or 10
	Instance.new("UICorner",Semi).CornerRadius = UDim.new(0, 6)

	local Full = Instance.new("TextButton",Row)
	Full.Size = UDim2.new(0,48,0,22)
	Full.Position = UDim2.new(1,-56,0.5,-11)
	Full.BackgroundColor3 = Color3.fromRGB(140, 82, 255)
	Full.TextColor3 = Color3.new(1,1,1)
	Full.Text = "FULL ("..configData.FullKeybind..")"
	Full.Font = Enum.Font.GothamBold
	Full.TextSize = isMobile and 9 or 10
	Instance.new("UICorner",Full).CornerRadius = UDim.new(0, 6)

	Semi.MouseEnter:Connect(function()
		TweenService:Create(Semi, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(48, 48, 65)}):Play()
	end)
	Semi.MouseLeave:Connect(function()
		TweenService:Create(Semi, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 48)}):Play()
	end)

	Full.MouseEnter:Connect(function()
		TweenService:Create(Full, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(160, 100, 255)}):Play()
	end)
	Full.MouseLeave:Connect(function()
		TweenService:Create(Full, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(140, 82, 255)}):Play()
	end)

	-- Mobile touch support
	Semi.InputBegan:Connect(function(input_obj)
		if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
			runSemiSpam(plr)
		elseif input_obj.UserInputType == Enum.UserInputType.MouseButton2 or (isMobile and input_obj.UserInputType == Enum.UserInputType.Touch) then
			waitingSemi = true
			Semi.Text = "SEMI (...)"
		end
	end)

	Full.InputBegan:Connect(function(input_obj)
		if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
			runFullSpam(plr)
		elseif input_obj.UserInputType == Enum.UserInputType.MouseButton2 or (isMobile and input_obj.UserInputType == Enum.UserInputType.Touch) then
			waitingFull = true
			Full.Text = "FULL (...)"
		end
	end)
end

local function RefreshPlayers()
	for _,v in pairs(PlayerList:GetChildren()) do
		if v:IsA("Frame") then v:Destroy() end
	end
	for _,plr in pairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then CreatePlayerRow(plr) end
	end
end

Players.PlayerAdded:Connect(RefreshPlayers)
Players.PlayerRemoving:Connect(RefreshPlayers)
RefreshPlayers()

local Bottom = Instance.new("Frame",Content)
Bottom.Size = UDim2.new(1,0,0,34)
Bottom.Position = UDim2.new(0,0,1,-34)
Bottom.BackgroundTransparency = 1

local Check = Instance.new("TextButton",Bottom)
Check.Size = UDim2.new(0,18,0,18)
Check.Position = UDim2.new(0,8,0.5,-9)
Check.BackgroundColor3 = BalloonEnabled and Color3.fromRGB(140, 82, 255) or Color3.fromRGB(30, 30, 40)
Check.Text = ""
Instance.new("UICorner",Check).CornerRadius = UDim.new(0, 4)

local CheckStroke = Instance.new("UIStroke", Check)
CheckStroke.Color = Color3.fromRGB(140, 82, 255)
CheckStroke.Thickness = 1
CheckStroke.Transparency = 0.5
CheckStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

Check.InputBegan:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
		BalloonEnabled = not BalloonEnabled
		configData.BalloonEnabled = BalloonEnabled
		Check.BackgroundColor3 = BalloonEnabled and Color3.fromRGB(140, 82, 255) or Color3.fromRGB(30, 30, 40)
		saveConfig()
	end
end)

local Label = Instance.new("TextLabel",Bottom)
Label.Size = UDim2.new(0,130,1,0)
Label.Position = UDim2.new(0,30,0,0)
Label.BackgroundTransparency = 1
Label.Text = "Balloon On AP Spam"
Label.TextColor3 = Color3.fromRGB(200,200,200)
Label.Font = Enum.Font.GothamMedium
Label.TextSize = isMobile and 11 or 12
Label.TextXAlignment = Enum.TextXAlignment.Left

local Refresh = Instance.new("TextButton",Bottom)
Refresh.Size = UDim2.new(0,65,0,22)
Refresh.Position = UDim2.new(1,-75,0.5,-11)
Refresh.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
Refresh.Text = "Refresh"
Refresh.TextColor3 = Color3.new(1,1,1)
Refresh.Font = Enum.Font.GothamBold
Refresh.TextSize = isMobile and 10 or 11
Instance.new("UICorner",Refresh).CornerRadius = UDim.new(0, 6)

local RefreshStroke = Instance.new("UIStroke", Refresh)
RefreshStroke.Color = Color3.fromRGB(140, 82, 255)
RefreshStroke.Thickness = 1
RefreshStroke.Transparency = 0.6
RefreshStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

Refresh.MouseEnter:Connect(function()
	TweenService:Create(Refresh, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 58)}):Play()
end)
Refresh.MouseLeave:Connect(function()
	TweenService:Create(Refresh, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
end)
Refresh.InputBegan:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
		RefreshPlayers()
	end
end)

local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
TweenService:Create(Main, tweenInfo, {BackgroundTransparency = 0.08}):Play()
for _, obj in pairs(Main:GetDescendants()) do
	if obj:IsA("TextLabel") or obj:IsA("TextButton") then
		TweenService:Create(obj, tweenInfo, {TextTransparency = 0}):Play()
	elseif obj:IsA("ImageLabel") then
		TweenService:Create(obj, tweenInfo, {ImageTransparency = 0}):Play()
	end
end

local function FadeUI(show)
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad)
	TweenService:Create(Main, tweenInfo, {BackgroundTransparency = show and 1 or 0.08}):Play()
	for _, obj in pairs(Main:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			TweenService:Create(obj, tweenInfo, {TextTransparency = show and 1 or 0}):Play()
		elseif obj:IsA("ImageLabel") then
			TweenService:Create(obj, tweenInfo, {ImageTransparency = show and 1 or 0}):Play()
		end
	end
	Main.Visible = true
end

UserInputService.InputBegan:Connect(function(input_obj,gpe)
	if gpe then return end
	if UserInputService:GetFocusedTextBox() then return end
	if input_obj.KeyCode == Enum.KeyCode.Backspace then return end

	if waitingSemi and input_obj.KeyCode ~= Enum.KeyCode.Unknown then
		SemiKeybind = input_obj.KeyCode
		configData.SemiKeybind = input_obj.KeyCode.Name
		waitingSemi = false
		saveConfig()
		RefreshPlayers()
		return
	end

	if waitingFull and input_obj.KeyCode ~= Enum.KeyCode.Unknown then
		FullKeybind = input_obj.KeyCode
		configData.FullKeybind = input_obj.KeyCode.Name
		waitingFull = false
		saveConfig()
		RefreshPlayers()
		return
	end

	if waitingToggleUI and input_obj.KeyCode ~= Enum.KeyCode.Unknown then
		ToggleUIKeybind = input_obj.KeyCode
		configData.ToggleUIKeybind = input_obj.KeyCode.Name
		waitingToggleUI = false
		ToggleUI.Text = "TOGGLE: " .. input_obj.KeyCode.Name
		saveConfig()
		return
	end

	if input_obj.KeyCode == SemiKeybind then
		for _,plr in pairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				runSemiSpam(plr)
				break
			end
		end
	end

	if input_obj.KeyCode == FullKeybind then
		for _,plr in pairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				runFullSpam(plr)
				break
			end
		end
	end

	if input_obj.KeyCode == ToggleUIKeybind then
		if Main.Visible then
			FadeUI(true)
			task.delay(0.25,function()
				Main.Visible = false
			end)
		else
			Main.Visible = true
			FadeUI(false)
		end
	end
end)

local minimized = false
local fullSize = Main.Size

Minimize.InputBegan:Connect(function(input_obj)
	if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
		if minimized then
			Content.Visible = true
			TweenService:Create(Main, TweenInfo.new(0.25), {Size = fullSize}):Play()
			Minimize.Text = "-"
		else
			Content.Visible = false
			TweenService:Create(Main, TweenInfo.new(0.25), {Size = UDim2.new(0, frameWidth, 0, 38)}):Play()
			Minimize.Text = "+"
		end
		minimized = not minimized
	end
end)

task.spawn(function()
	while _G.ZenoHubAlive and ScreenGui.Parent do
		task.wait(30)
		configData.SemiKeybind = SemiKeybind.Name
		configData.FullKeybind = FullKeybind.Name
		configData.ToggleUIKeybind = ToggleUIKeybind.Name
		configData.BalloonEnabled = BalloonEnabled
		saveConfig()
	end
end)

print("Zeno Spammer" .. configData.ToggleUIKeybind .. " | balon: " .. tostring(BalloonEnabled))
end


local function createInstance(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props) do
        inst[k] = v
    end
    if parent then inst.Parent = parent end
    return inst
end



-- Config save/load implementations
Toggles = Config.toggles

saveConfig = function()
    if writefile then
        local success, err = pcall(function()
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end)
        if success then
        else
            warn("ðŸ’¾ Save failed:", err)
        end
    else
        print("ðŸ’¾ writefile not available")
    end
end

loadConfig = function()
    print("ðŸ“‚ Loading config...")
    if readfile and isfile and isfile(CONFIG_FILE) then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end)
        if success and data then
            Config.toggles = data.toggles or {}
            Config.panels = data.panels or {}
            Config.sliders = data.sliders or {}
            Config.keybinds = data.keybinds or {}
            Config.spammer = data.spammer or {
                SemiKeybind = "F", FullKeybind = "Y", 
                ToggleUIKeybind = "F4", BalloonEnabled = false
            }
            print("ðŸ“‚ Loaded config from file!")
            Toggles = Config.toggles
            configData = Config.spammer
        else
            print("ðŸ“‚ Config file corrupt, using defaults")
        end
    else
        print("ðŸ“‚ No config file found, starting fresh")
    end
end

loadConfig()

ToggleHandlers = {}


-- =============================================
-- FOV
-- =============================================

local _AnimalsData = {}

local function setFOV(value)
    value = math.clamp(value, 40, 120)
    Camera.FieldOfView = value
end

do -- Game Stretcher scope
-- =============================================
-- GAME STRETCHER
-- =============================================


local gameStretcherEnabled = false
local gameStretcherConnection = nil

local function enableGameStretcher()
    gameStretcherEnabled = true

    if gameStretcherConnection then
        gameStretcherConnection:Disconnect()
    end

    gameStretcherConnection = trackConnection(RunService.RenderStepped:Connect(function()
        if not gameStretcherEnabled then return end

        local cam = workspace.CurrentCamera
        if cam then
            cam.FieldOfView = 100
        end
    end))
end

local function disableGameStretcher()
    gameStretcherEnabled = false

    if gameStretcherConnection then
        gameStretcherConnection:Disconnect()
        gameStretcherConnection = nil
    end

    local cam = workspace.CurrentCamera
    if cam then
        cam.FieldOfView = 70
    end
end

local resConnection = nil

ToggleHandlers.game_stretcher = function(state)
    if state then
        enableGameStretcher()
        resConnection = RunService.RenderStepped:Connect(function()
            Camera.CFrame = Camera.CFrame * CFrame.new(0, 0, 0, 1, 0, 0, 0, 0.7, 0, 0, 0, 1)
        end)
    else
        disableGameStretcher()
        if resConnection then
            resConnection:Disconnect()
            resConnection = nil
        end
    end
end
end -- Game Stretcher scope

-- =========================
-- SPEED BOOST SYSTEM
-- =========================

local speedEnabled = false
local walkSpeed = 50
local speedConnection = nil
local walkSpeedSlider = nil  -- set by initUI Booster panel
local jumpPowerSlider = nil  -- set by initUI Booster panel

local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

LocalPlayer.CharacterAdded:Connect(function(char)
    character = char
    humanoid = char:WaitForChild("Humanoid")
end)

local function enableSpeedBoost()
    speedEnabled = true

    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end

    speedConnection = trackConnection(RunService.Heartbeat:Connect(function()
        if not speedEnabled or not humanoid then return end

        local root = humanoid.Parent:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- Read live slider values (fall back to defaults if sliders not yet created)
        local ws = walkSpeedSlider and walkSpeedSlider.Get() or walkSpeed
        local jp = jumpPowerSlider and jumpPowerSlider.Get() or 50

        -- Apply jump power
        humanoid.UseJumpPower = true
        humanoid.JumpPower = jp

        local moveDir = humanoid.MoveDirection

        if moveDir.Magnitude > 0 then
            local direction = moveDir.Unit
            local currentVel = root.AssemblyLinearVelocity

            root.AssemblyLinearVelocity = Vector3.new(
                direction.X * ws,
                currentVel.Y,
                direction.Z * ws
            )
        end
    end))
end

local function disableSpeedBoost()
    speedEnabled = false

    if speedConnection then
        speedConnection:Disconnect()
        speedConnection = nil
    end

    -- Reset jump power to Roblox default
    if humanoid then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
    end
end

-- =============================================
-- BRAINROT ESP SYSTEM
-- =============================================

local _animalCache = {}
local _promptCache = {}
local _stealCache = {}
local _player = LocalPlayer
local _AutoStealV1 = false
local _AutoGiantPotion = false
local espBrainrotEnabled = false
local espBrainrotConnections = {}
local Animals = nil
local rarePets = {}

local function initializeESP()
    local success, result = pcall(function()
        return require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
    end)

    if success then
        Animals = result
        rarePets = {}

        for petName, petData in pairs(Animals) do
            if petData and (
                petData.Rarity == "Brainrot God" or
                petData.Rarity == "Secret" or
                petData.Rarity == "OG"
            ) then
                table.insert(rarePets, petName)
            end
        end
    end
end

local cachedPlayerBase = nil
local function findPlayerBase()
    if cachedPlayerBase and cachedPlayerBase.Parent == workspace:FindFirstChild("Plots") then
        return cachedPlayerBase
    end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end

    for _, plot in pairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local yourBase = sign:FindFirstChild("YourBase")
            if yourBase and yourBase.Enabled then
                cachedPlayerBase = plot
                return plot
            end
        end
    end
    return nil
end

local function isPlayerBase(model)
    local base = findPlayerBase()
    if not base then return false end

    local current = model
    while current and current ~= workspace do
        if current == base then return true end
        current = current.Parent
    end

    return false
end

local function _formatNumber(n)
    if not n then return "0" end

    if n >= 1e12 then
        return string.format("%.1fT", n / 1e12)
    elseif n >= 1e9 then
        return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then
        return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then
        return string.format("%.1fK", n / 1e3)
    else
        return tostring(math.floor(n))
    end
end

local function _getMutationInfo(model)
    local mutationName = "NORMAL"
    local mutationColor = Color3.fromRGB(255, 255, 255)

    local attrMutation = model:GetAttribute("Mutation")
    if typeof(attrMutation) == "string" and attrMutation ~= "" then
        mutationName = string.upper(attrMutation)
    end

    local attrColor = model:GetAttribute("MutationColor")
    if typeof(attrColor) == "Color3" then
        mutationColor = attrColor
    end

    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("StringValue") and d.Name:lower():find("mutation") and d.Value ~= "" then
            mutationName = string.upper(d.Value)
        elseif d:IsA("TextLabel") and d.Name:lower():find("mutation") and d.Text ~= "" then
            mutationName = string.upper(d.Text)
            mutationColor = d.TextColor3
        elseif d:IsA("Color3Value") and d.Name:lower():find("mutation") then
            mutationColor = d.Value
        end
    end

    return mutationName, mutationColor
end

local function formatMutationText(mutationName)
    if not mutationName or mutationName == "None" then return "" end
    local f = ""

    if mutationName == "Cursed" then
        f = "<font color='rgb(200,0,0)'>Cur</font><font color='rgb(0,0,0)'>sed</font>"

    elseif mutationName == "Gold" then
        f = "<font color='rgb(255,215,0)'>Gold</font>"

    elseif mutationName == "Diamond" then
        f = "<font color='rgb(0,255,255)'>Diamond</font>"

    elseif mutationName == "YinYang" then
        f = "<font color='rgb(255,255,255)'>Yin</font><font color='rgb(0,0,0)'>Yang</font>"

    elseif mutationName == "Candy" then
        f = "<font color='rgb(255,105,180)'>Candy</font>"

    elseif mutationName == "Divine" then
        f = "<font color='rgb(255,255,255)'>Divine</font>"

    elseif mutationName == "Rainbow" then
        local cols = {
            "rgb(255,0,0)","rgb(255,127,0)","rgb(255,255,0)",
            "rgb(0,255,0)","rgb(0,0,255)","rgb(75,0,130)","rgb(148,0,211)"
        }
        for i = 1, #mutationName do
            f = f .. "<font color='"..cols[(i-1)%#cols+1].."'>"..mutationName:sub(i,i).."</font>"
        end
    else
        f = mutationName
    end

    return f
end

local function createNameTag(model, petName)

    for _, v in ipairs(model:GetChildren()) do
        if v.Name == "PetNameTag" then
            v:Destroy()
        end
    end

    local bb = Instance.new("BillboardGui") -- âœ… FIX
    bb.Name = "PetNameTag"
    bb.Size = UDim2.new(0, 190, 0, 40)
    bb.StudsOffset = Vector3.new(0, 1.1, 0)
    bb.AlwaysOnTop = true
    bb.Parent = model

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Parent = bb

    local mutation = model:GetAttribute("Mutation") or "None"
    local formattedMutation = formatMutationText(mutation)

    -- MUTATION
    local mutLabel = Instance.new("TextLabel")
    mutLabel.Size = UDim2.new(1, 0, 0.5, 0)
    mutLabel.BackgroundTransparency = 1
    mutLabel.RichText = true
    mutLabel.Text = formattedMutation
    mutLabel.Font = Enum.Font.GothamBlack
    mutLabel.TextSize = 13
    mutLabel.TextStrokeTransparency = 0
    mutLabel.TextStrokeColor3 = Color3.new(0,0,0)
    mutLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    mutLabel.Parent = frame

    -- NAME
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
    nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = petName
    nameLabel.Font = Enum.Font.GothamBlack
    nameLabel.TextSize = 13
    nameLabel.TextColor3 = Color3.new(1,1,1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.TextStrokeColor3 = Color3.new(0,0,0)
    nameLabel.TextYAlignment = Enum.TextYAlignment.Top
    nameLabel.Parent = frame
end

local _progressTween = nil

local function checkForRarePet(model)
    if not Animals or isPlayerBase(model) then return end

    local name = model.Name

    for _, petName in ipairs(rarePets) do
        if name == petName or string.find(name, petName) then
            createNameTag(model, petName)
            return
        end
    end
end

local function scanPlots()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    local descendants = plots:GetDescendants()
    for i, plot in ipairs(descendants) do
        if plot:IsA("Model") then
            checkForRarePet(plot)
        end
        if i % 20 == 0 then
            task.wait(math.random(0.05, 0.15))
        end
    end
end

local function startESP()
    scanPlots()

    espBrainrotConnections.added = workspace.DescendantAdded:Connect(function(obj)
        if not espBrainrotEnabled then return end
        if obj:IsA("Model") then
            task.wait(0.2)
            checkForRarePet(obj)
        end
    end)
end

initializeESP()
if espBrainrotEnabled then
    startESP()
end

local function enableBrainrotESP()
    espBrainrotEnabled = true
    startESP()
end

local function disableBrainrotESP()
    espBrainrotEnabled = false

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "PetNameTag" then
            obj:Destroy()
        end
    end
end

-- =============================================
-- FULL PLAYER ESP SYSTEM (Username Only + GothamBlack)
-- =============================================

local function createPlayerESP(player)
    if player == LocalPlayer then return end
    
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Remove old ESP
    if PlayerESPData[player] then
        for _, esp in pairs(PlayerESPData[player]) do
            if esp and esp.Parent then esp:Destroy() end
        end
    end
    
    PlayerESPData[player] = {}
    
    -- FULL BODY HIGHLIGHT (covers entire character)
    local fullHighlight = Instance.new("Highlight")
    fullHighlight.Name = "ESP_FullBody"
    fullHighlight.Adornee = character
    fullHighlight.FillColor = Color3.fromRGB(255, 0, 100)  -- Pink glow
    fullHighlight.FillTransparency = 0.4
    fullHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)  -- White outline
    fullHighlight.OutlineTransparency = 0
    fullHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    fullHighlight.FillTransparency = 0.6
    fullHighlight.Parent = humanoidRootPart
    table.insert(PlayerESPData[player], fullHighlight)
    
    -- TORSO SELECTION BOX (extra thick highlight on torso)
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    if torso then
        local torsoBox = Instance.new("SelectionBox")
        torsoBox.Name = "ESP_Torso"
        torsoBox.Adornee = torso
        torsoBox.Color3 = Color3.fromRGB(255, 100, 0)  -- Orange for torso
        torsoBox.LineThickness = 0.3  -- THICK
        torsoBox.Transparency = 0
        torsoBox.Parent = humanoidRootPart
        table.insert(PlayerESPData[player], torsoBox)
    end
    
    -- USERNAME BILLBOARD (TINY SIZE)
local billboard = Instance.new("BillboardGui")
billboard.Name = "ESP_Username"
billboard.Adornee = humanoidRootPart
billboard.Size = UDim2.new(0, 140, 0, 25)  -- Tiny: 140x25
billboard.StudsOffset = Vector3.new(0, 2.5, 0)
billboard.AlwaysOnTop = true
billboard.LightInfluence = 0
billboard.Parent = humanoidRootPart

local frame = Instance.new("Frame")
frame.Size = UDim2.new(1, 0, 1, 0)
frame.BackgroundTransparency = 1
frame.Parent = billboard

local usernameLabel = Instance.new("TextLabel")
usernameLabel.Size = UDim2.new(1, 0, 1, 0)
usernameLabel.BackgroundTransparency = 1
usernameLabel.Text = player.Name
usernameLabel.Font = Enum.Font.GothamBlack
usernameLabel.TextSize = 13  -- Tiny: 13px
usernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
usernameLabel.TextStrokeTransparency = 0
usernameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
usernameLabel.TextScaled = true
usernameLabel.Parent = frame
    
    table.insert(PlayerESPData[player], billboard)
end

-- ðŸ”¥ SIMPLIFIED - NO DISTANCE UPDATE NEEDED
function startPlayerESP()
    -- Create ESP for existing players
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createPlayerESP(player)
        end
    end
    
    -- Track new players
    PlayerESPConnections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function()
            task.wait(0.5)
            createPlayerESP(player)
        end)
    end)
    
    -- Track character respawns
    PlayerESPConnections.CharacterAdded = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                createPlayerESP(player)
            end
        end
    end)
end

function stopPlayerESP()
    -- Disconnect connections
    for _, conn in pairs(PlayerESPConnections) do
        if conn then conn:Disconnect() end
    end
    PlayerESPConnections = {}
    
    -- Remove all ESP
    for player, espData in pairs(PlayerESPData) do
        for _, esp in pairs(espData) do
            if esp and esp.Parent then
                esp:Destroy()
            end
        end
    end
    PlayerESPData = {}
end


-- =============================================
-- =============================================
-- INSTANT STEAL V2 SYSTEM
-- =============================================
-- Proximity prompt auto-grab loop + Instant Steal TP GUI panel
-- Based on SheeshV2's proven approach

local ISTConnections = {}
local instaGrabEnabled = false

local function saveUIPosition(frame)
    if frame then
        _G.savedPos = frame.Position
    end
end

local instaRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
local instaHumanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid")

LocalPlayer.CharacterAdded:Connect(function(char)
    instaRootPart = char:WaitForChild("HumanoidRootPart")
    instaHumanoid = char:WaitForChild("Humanoid")
end)

local function instaGetPos(prompt)
    local p = prompt.Parent
    if p:IsA("BasePart") then return p.Position end
    if p:IsA("Model") then
        local prim = p.PrimaryPart or p:FindFirstChildWhichIsA("BasePart")
        return prim and prim.Position
    end
    if p:IsA("Attachment") then return p.WorldPosition end
    local part = p:FindFirstChildWhichIsA("BasePart", true)
    return part and part.Position
end

local function instaFindNearestStealPrompt()
    if not instaRootPart then return nil end
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local myPos = instaRootPart.Position
    local nearest = nil
    local nearestDist = math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        for _, obj in ipairs(plot:GetDescendants()) do
            if obj:IsA("ProximityPrompt") and obj.Enabled and obj.ActionText == "Steal" then
                local pos = instaGetPos(obj)
                if pos then
                    local dist = (myPos - pos).Magnitude
                    if dist <= obj.MaxActivationDistance and dist < nearestDist then
                        nearest = obj
                        nearestDist = dist
                    end
                end
            end
        end
    end
    return nearest
end

local function instaFirePrompt(prompt)
    if not prompt then return end
    local originalDist = prompt.MaxActivationDistance
    local originalLOS = prompt.RequiresLineOfSight
    local originalClickable = prompt.ClickablePrompt
    
    prompt.MaxActivationDistance = 9999
    prompt.RequiresLineOfSight = false
    prompt.ClickablePrompt = true
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local originalCFrame = hrp and hrp.CFrame
    local promptPart = prompt.Parent
    
    task.spawn(function()
        pcall(function()
            if hrp and promptPart and promptPart:IsA("BasePart") then
                hrp.CFrame = CFrame.new(promptPart.Position)
            end
            
            fireproximityprompt(prompt)
            prompt:InputHoldBegin()
            task.wait(0.04)
            prompt:InputHoldEnd()
            
            if hrp and originalCFrame then
                hrp.CFrame = originalCFrame
            end
            prompt.MaxActivationDistance = originalDist
            prompt.RequiresLineOfSight = originalLOS
            prompt.ClickablePrompt = originalClickable
        end)
    end)
end

task.spawn(function()
    while _G.ZenoHubAlive do
        if instaGrabEnabled and instaHumanoid and instaHumanoid.Health > 0 and instaHumanoid.WalkSpeed > 29 then
            local nearest = instaFindNearestStealPrompt()
            if nearest then
                -- Auto activate Giant Potion before stealing
                local bp = LocalPlayer:FindFirstChild("Backpack")
                local char = LocalPlayer.Character
                local potion = bp and bp:FindFirstChild("Giant Potion")
                if potion and char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        potion.Parent = char
                        potion:Activate()
                        task.wait(0.05)
                    end
                end
                task.wait(0.07)
                instaFirePrompt(nearest)
            end
        end
        task.wait(0.3)
    end
end)


do -- X-Ray scope
-- =============================================
-- X-RAY SYSTEM
-- =============================================

-- =============================================
-- UNLOCK BASE UI SYSTEM (AFTER initUI)
-- =============================================

-- =============================================
-- ðŸ”¥ COMPLETE UNLOCK BASE SYSTEM (FIXED)
-- =============================================
unlockBaseUI = nil

-- ðŸ”´ RED THEME
local Theme = {
    Background = Color3.fromRGB(10, 8, 14),
    Surface = Color3.fromRGB(22, 16, 32),
    Accent1 = Color3.fromRGB(170, 70, 255),
    Accent2 = Color3.fromRGB(100, 40, 180),
    TextPrimary = Color3.fromRGB(245, 240, 255),
}

-- Check if object is in your plot
local function isOwnPlot(obj)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end

    for _, plot in ipairs(plots:GetChildren()) do
        local isOwned = false

        if plot.Name == LocalPlayer.Name then
            isOwned = true
        else
            local ownerVal = plot:FindFirstChild("Owner")
            if ownerVal and ownerVal.Value == LocalPlayer.Name then
                isOwned = true
            end
        end

        if isOwned and obj:IsDescendantOf(plot) then
            return true
        end
    end

    return false
end

-- Check nearby players
local function isNearOtherPlayer(part, yLevel, Y_THRESHOLD)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local yDiff = math.abs(hrp.Position.Y - yLevel)
                local dist = (hrp.Position - part.Position).Magnitude
                if yDiff <= Y_THRESHOLD and dist <= 60 then
                    return true
                end
            end
        end
    end
    return false
end

-- Unlock logic
local function triggerClosestUnlock(yLevel, maxY)
    local character = LocalPlayer.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local playerY = yLevel or hrp.Position.Y
    local Y_THRESHOLD = 5

    local bestPromptSameLevel = nil
    local shortestDistSameLevel = math.huge
    local bestPromptFallback = nil
    local shortestDistFallback = math.huge

    local plots = workspace:FindFirstChild("Plots")
    if not plots then return end

    for _, obj in ipairs(plots:GetDescendants()) do
        if obj:IsA("ProximityPrompt") and obj.Enabled then
            if not isOwnPlot(obj) then
                local part = obj.Parent
                if part and part:IsA("BasePart") then
                    if not maxY or part.Position.Y <= maxY then
                        local distance = (hrp.Position - part.Position).Magnitude
                        local yDifference = math.abs(playerY - part.Position.Y)
                        local nearOther = isNearOtherPlayer(part, playerY, Y_THRESHOLD)

                        if yDifference <= Y_THRESHOLD then
                            if nearOther then
                                if distance < shortestDistSameLevel then
                                    shortestDistSameLevel = distance
                                    bestPromptSameLevel = obj
                                end
                            elseif bestPromptSameLevel == nil and distance < shortestDistFallback then
                                shortestDistFallback = distance
                                bestPromptFallback = obj
                            end
                        end
                    end
                end
            end
        end
    end

    local targetPrompt = bestPromptSameLevel or bestPromptFallback

    if targetPrompt then
        print("🔓 UNLOCKING BASE - Floor:", yLevel)
        local originalDist = targetPrompt.MaxActivationDistance
        local originalLOS = targetPrompt.RequiresLineOfSight
        local originalClickable = targetPrompt.ClickablePrompt
        
        targetPrompt.MaxActivationDistance = 9999
        targetPrompt.RequiresLineOfSight = false
        targetPrompt.ClickablePrompt = true

        local originalCFrame = hrp and hrp.CFrame
        
        if hrp and targetPrompt.Parent and targetPrompt.Parent:IsA("BasePart") then
            hrp.CFrame = CFrame.new(targetPrompt.Parent.Position)
        end

        if fireproximityprompt then
            fireproximityprompt(targetPrompt)
        else
            targetPrompt:InputBegan(Enum.UserInputType.MouseButton1)
            task.wait(0.05)
            targetPrompt:InputEnded(Enum.UserInputType.MouseButton1)
        end

        if hrp and originalCFrame then
            hrp.CFrame = originalCFrame
        end
        targetPrompt.MaxActivationDistance = originalDist
        targetPrompt.RequiresLineOfSight = originalLOS
        targetPrompt.ClickablePrompt = originalClickable
    else
        print("âŒ No unlock prompt found for floor:", yLevel)
    end
end

-- ðŸ”¥ MAIN UI CREATOR FUNCTION (TOGGLE READY)
function createUnlockBaseUI()
    print("ðŸŽ® Creating Unlock Base UI...")
    
    -- Destroy old UI
    if unlockBaseUI then
        unlockBaseUI:Destroy()
        unlockBaseUI = nil
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = getRandomName()
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 1001
    gui.Parent = getUiParent()
    unlockBaseUI = gui

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 240, 0, 80)
    frame.Position = UDim2.new(0.5, -120, 0.85, 0)
    frame.BackgroundColor3 = Theme.Background
    frame.BorderSizePixel = 0
    frame.Active = false
    frame.Parent = gui

    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 12)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color = Theme.Accent2
    stroke.Thickness = 1.5

    -- ðŸŸ© DRAGGABLE HEADER
    local header = Instance.new("Frame", frame)
    header.Size = UDim2.new(1, 0, 0, 30)
    header.BackgroundTransparency = 1

    local dragging = false
    local dragInput, dragStart, startPos

    header.InputBegan:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input_obj.Position
            startPos = frame.Position

            input_obj.Changed:Connect(function()
                if input_obj.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    header.InputChanged:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseMovement or input_obj.UserInputType == Enum.UserInputType.Touch then
            dragInput = input_obj
        end
    end)

    game:GetService("UserInputService").InputChanged:Connect(function(input_obj)
        if input_obj == dragInput and dragging then
            local delta = input_obj.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)

    -- Title
    local title = Instance.new("TextLabel", header)
    title.Size = UDim2.new(1, -10, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "ðŸ”“ UNLOCK BASE"
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 14
    title.TextColor3 = Theme.TextPrimary
    title.TextXAlignment = Enum.TextXAlignment.Left

    -- Container
    local container = Instance.new("Frame", frame)
    container.Size = UDim2.new(1, -20, 0, 35)
    container.Position = UDim2.new(0, 10, 0, 35)
    container.BackgroundTransparency = 1

    local grid = Instance.new("UIGridLayout", container)
    grid.CellSize = UDim2.new(0.3, 0, 0.8, 0)
    grid.CellPadding = UDim2.new(0.04, 0, 0, 0)
    grid.FillDirectionMaxCells = 3

    -- Floors
    local floors = {
        [1] = {yLevel = -2, maxY = 19},
        [2] = {yLevel = 15},
        [3] = {yLevel = 32},
    }

    -- Buttons
    for i = 1, 3 do
        local btn = Instance.new("TextButton")
        btn.Parent = container
        btn.BackgroundColor3 = Theme.Surface
        btn.Text = tostring(i)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 14
        btn.TextColor3 = Theme.TextPrimary

        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)

        local s = Instance.new("UIStroke", btn)
        s.Color = Theme.Accent1

        btn.MouseEnter:Connect(function()
            btn.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
            s.Transparency = 0
        end)

        btn.MouseLeave:Connect(function()
            btn.BackgroundColor3 = Theme.Surface
            s.Transparency = 0.3
        end)

        btn.MouseButton1Click:Connect(function()
            print("ðŸ”¥ FLOOR", i, "CLICKED!")
            local f = floors[i]
            triggerClosestUnlock(f.yLevel, f.maxY)

            btn.BackgroundColor3 = Theme.Accent1
            task.delay(0.15, function()
                btn.BackgroundColor3 = Theme.Surface
            end)
        end)

        btn.Activated:Connect(function()
            print("ðŸ”¥ FLOOR", i, "ACTIVATED!")
            local f = floors[i]
            triggerClosestUnlock(f.yLevel, f.maxY)

            btn.BackgroundColor3 = Theme.Accent1
            task.delay(0.15, function()
                btn.BackgroundColor3 = Theme.Surface
            end)
        end)
    end

    unlockBaseUI = gui
    print("âœ… UNLOCK BASE UI CREATED! ðŸŽ‰ Perfectly aligned 3 Floor buttons!")
    return gui
end

-- ðŸ”¥ TOGGLE HANDLER
ToggleHandlers.unlock_base_ui = function(state)
    print("ðŸ”“ Unlock Base UI toggled:", state and "ON" or "OFF")
    
    if state then
        unlockBaseUI = createUnlockBaseUI()
    else
        if unlockBaseUI then
            unlockBaseUI:Destroy()
            unlockBaseUI = nil
            print("ðŸ—‘ï¸ Unlock Base UI destroyed")
        end
    end
end


ToggleHandlers.player_esp_full = function(state)
    local _PlayerESPEnabled = state
    
    if state then
        startPlayerESP()
        print("âœ… Player ESP ENABLED")
    else
        stopPlayerESP()
        print("âŒ Player ESP DISABLED")
    end
end

-- ðŸ”¥ FIXED TOGGLE HANDLER (SIMPLE & RELIABLE)

local Xray = {
    isOn = false,
    cache = {}
}

local function findDecorationParts()
    local parts = {}
    for _, plots in ipairs(workspace:GetChildren()) do
        if plots:IsA("Folder") and plots.Name == "Plots" then
            for _, model in ipairs(plots:GetChildren()) do
                if model:IsA("Model") then
                    local dec = model:FindFirstChild("Decorations")
                    if dec then
                        for _, p in ipairs(dec:GetDescendants()) do
                            if p:IsA("BasePart") then
                                table.insert(parts, p)
                            end
                        end
                    end
                end
            end
        end
    end
    return parts
end

local function setXrayOn()
    for _, part in ipairs(findDecorationParts()) do
        if not Xray.cache[part] then
            Xray.cache[part] = part.Transparency
        end
        part.Transparency = 0.8
    end
    Xray.isOn = true
end

local function setXrayOff()
    for part, orig in pairs(Xray.cache) do
        if part and part.Parent then
            part.Transparency = orig
        end
    end
    Xray.isOn = false
end

ToggleHandlers.x_ray = function(state)
    if state then setXrayOn() else setXrayOff() end
end
end -- X-Ray scope

do -- FPS Boost scope
-- =============================================
-- FPS BOOST SYSTEM
-- =============================================

local FPS = {
    connections = {},
}

-- Services already available as upvalues

local function stripVisuals(obj)
    if obj:IsA("BasePart") then
        obj.Material = Enum.Material.SmoothPlastic
        obj.Reflectance = 0
        obj.CastShadow = false
    elseif obj:IsA("Decal") or obj:IsA("Texture") then
        obj:Destroy()
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
        obj:Destroy()
    end
end

local function applyLowQualityToPart(part)
    if part:IsA("BasePart") or part:IsA("MeshPart") then
        part.Material = Enum.Material.Plastic
        part.Reflectance = 0
        part.CastShadow = false

        if part.Transparency == 0 then
            part.Transparency = 0
        end
    end
end

local function destroyAllAccessories()
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant:IsA("Accessory") or descendant:IsA("MeshPartAccessory") then
            pcall(function()
                descendant:Destroy()
            end)
        end
    end
end

local function enableFPSBoost()
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 1e6
    Lighting.FogStart = 0
    Lighting.Brightness = 1
    Lighting.EnvironmentDiffuseScale = 0
    Lighting.EnvironmentSpecularScale = 0

    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("BloomEffect")
        or v:IsA("BlurEffect")
        or v:IsA("SunRaysEffect")
        or v:IsA("PostEffect")
        or v:IsA("Atmosphere") then
            v:Destroy()
        end
    end

    destroyAllAccessories()

    for _, obj in ipairs(Workspace:GetDescendants()) do
        stripVisuals(obj)
        applyLowQualityToPart(obj)
    end

    FPS.connections.descendant = Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Accessory") or obj:IsA("MeshPartAccessory") then
            pcall(function()
                obj:Destroy()
            end)
            return
        end

        stripVisuals(obj)
        applyLowQualityToPart(obj)
    end)

    local function removeMeshes(tool)
        if not tool:IsA("Tool") then return end

        local handle = tool:FindFirstChild("Handle")
        if not handle then return end

        for _, d in ipairs(handle:GetDescendants()) do
            if d:IsA("Mesh") or d:IsA("SpecialMesh") then
                d:Destroy()
            end
        end
    end

    local function onCharacter(char)
        char.ChildAdded:Connect(removeMeshes)

        for _, child in ipairs(char:GetChildren()) do
            removeMeshes(child)
        end
    end

    FPS.connections.player = Players.PlayerAdded:Connect(function(plr)
        plr.CharacterAdded:Connect(onCharacter)
    end)

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then
            onCharacter(plr.Character)
        end
    end
end

local function disableFPSBoost()
    for _, conn in pairs(FPS.connections) do
        if conn then conn:Disconnect() end
    end
    FPS.connections = {}
end

ToggleHandlers.fps_boost = function(state)
    if state then enableFPSBoost() else disableFPSBoost() end
end
end -- FPS Boost scope

do -- Remove Animations scope
-- =============================================
-- REMOVE ANIMATIONS SYSTEM
-- =============================================

local AnimRemove = {
    connections = {}
}

local function isLocalCharacter(model)
    return Players.LocalPlayer.Character == model
end

local function handleAnimator(animator)
    local model = animator:FindFirstAncestorOfClass("Model")
    if model and isLocalCharacter(model) then return end

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        track:Stop(0)
    end

    local conn = animator.AnimationPlayed:Connect(function(track)
        track:Stop(0)
    end)

    table.insert(AnimRemove.connections, conn)
end

local function enableRemoveAnimations()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Animator") then
            handleAnimator(obj)
        end
    end

    AnimRemove.connections.desc = workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Animator") then
            handleAnimator(obj)
        end
    end)
end

local function disableRemoveAnimations()
    for _, conn in pairs(AnimRemove.connections) do
        if conn then conn:Disconnect() end
    end
    AnimRemove.connections = {}
end

ToggleHandlers.remove_animations = function(state)
    if state then enableRemoveAnimations() else disableRemoveAnimations() end
end
end -- Remove Animations scope

do -- Subspace Mine ESP scope
-- ================= SUBSPACE MINE ESP =================

local subspaceMineESPData = {}
local FolderName = "ToolsAdds"

Config.SubspaceMineESP = Config.SubspaceMineESP or false

local function getMineOwner(mineName)
    local ownerName = mineName:match("SubspaceTripmine(.+)")
    if not ownerName then return "Unknown" end 

    local foundPlayer = Players:FindFirstChild(ownerName)
    return foundPlayer and foundPlayer.DisplayName or ownerName
end

local function createMineESP(mine)
    local ownerName = getMineOwner(mine.Name)

    local selectionBox = Instance.new("SelectionBox")
    selectionBox.Name = "ESP_Hitbox"
    selectionBox.Adornee = mine
    selectionBox.Color3 = Color3.fromRGB(167, 142, 255)
    selectionBox.LineThickness = 0.05
    selectionBox.Parent = mine

    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "ESP_Label"
    billboardGui.Adornee = mine
    billboardGui.Size = UDim2.new(0, 250, 0, 50)
    billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
    billboardGui.AlwaysOnTop = true
    billboardGui.Parent = mine

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = ownerName .. "'s Subspace Mine"
    textLabel.TextColor3 = Color3.fromRGB(167, 142, 255)
    textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    textLabel.TextStrokeTransparency = 0
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextSize = 16
    textLabel.Parent = billboardGui

    return {
        selectionBox = selectionBox,
        billboardGui = billboardGui,
        mine = mine
    }
end

local function clearAllESP()
    for _, data in pairs(subspaceMineESPData) do
        if data.selectionBox then data.selectionBox:Destroy() end
        if data.billboardGui then data.billboardGui:Destroy() end
    end
    table.clear(subspaceMineESPData)
end

local function refreshSubspaceMineESP()
    if not Config.SubspaceMineESP then
        clearAllESP()
        return
    end

    local toolsFolder = workspace:FindFirstChild(FolderName)
    if not toolsFolder then return end

    local currentMines = {}

    for _, obj in pairs(toolsFolder:GetChildren()) do
        if obj:IsA("BasePart") and obj.Name:match("^SubspaceTripmine") then
            currentMines[obj] = true

            if not subspaceMineESPData[obj] then
                subspaceMineESPData[obj] = createMineESP(obj)
            end
        end
    end

    for mineObj, data in pairs(subspaceMineESPData) do
        if not currentMines[mineObj] or not mineObj.Parent then
            if data.selectionBox then data.selectionBox:Destroy() end
            if data.billboardGui then data.billboardGui:Destroy() end
            subspaceMineESPData[mineObj] = nil
        end
    end
end

-- ðŸ”¥ RUN LOOP (optimized)
RunService.Heartbeat:Connect(function()
    if Config.SubspaceMineESP then
        refreshSubspaceMineESP()
    end
end)

-- ðŸ”¥ TOGGLE HANDLER (CONNECTS TO YOUR UI)
ToggleHandlers.subspace_mine_esp = function(state)
    Config.SubspaceMineESP = state

    if not state then
        clearAllESP()
    end
end
end -- Subspace Mine ESP scope

do -- Base Timer ESP scope
-- ================= BASE TIMER ESP =================

local plotsFolder = workspace:FindFirstChild("Plots")
local baseEspInstances = {}
Config.BaseTimerESP = Config.BaseTimerESP or false

local function createBaseESP(plot, mainPart)
    if baseEspInstances[plot] then
        baseEspInstances[plot]:Destroy()
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "BaseTimerESP"
    billboard.Size = UDim2.new(0, 60, 0, 25)
    billboard.StudsOffset = Vector3.new(0, 5, 0)
    billboard.AlwaysOnTop = true
    billboard.Adornee = mainPart
    billboard.MaxDistance = 1000
    billboard.Parent = plot

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.TextScaled = false
    label.TextSize = 17 -- you can tweak (10â€“14)
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Parent = billboard

    baseEspInstances[plot] = billboard
    return billboard
end

local function clearBaseESP()
    for _, gui in pairs(baseEspInstances) do
        if gui then gui:Destroy() end
    end
    table.clear(baseEspInstances)
end

local function updateBaseESP()
    if not Config.BaseTimerESP then
        clearBaseESP()
        return
    end

    if not plotsFolder then return end

    for _, plot in ipairs(plotsFolder:GetChildren()) do
        local purchases = plot:FindFirstChild("Purchases")
        local plotBlock = purchases and purchases:FindFirstChild("PlotBlock")
        local mainPart = plotBlock and plotBlock:FindFirstChild("Main")

        local timeLabel = mainPart
            and mainPart:FindFirstChild("BillboardGui")
            and mainPart.BillboardGui:FindFirstChild("RemainingTime")

        if timeLabel and mainPart then
            local billboard = baseEspInstances[plot] or createBaseESP(plot, mainPart)
            local label = billboard:FindFirstChildWhichIsA("TextLabel")

            if label then
                label.Text = timeLabel.Text
            end
        else
            if baseEspInstances[plot] then
                baseEspInstances[plot]:Destroy()
                baseEspInstances[plot] = nil
            end
        end
    end
end

task.spawn(function()
    while _G.ZenoHubAlive do
        if Config.BaseTimerESP then
            pcall(updateBaseESP)
        end
        task.wait(0.3)
    end
end)

ToggleHandlers.base_timer_esp = function(state)
    Config.BaseTimerESP = state
    if not state then clearBaseESP() end
end
end -- Base Timer ESP scope

do -- Auto Kick On Steal scope
-- ================= AUTO KICK ON STEAL =================

local autoKickOnStealEnabled = false
local autoKickOnStealConnections = {}
local stealKeyword = "you stole"

-- ðŸ” check keyword
local function hasStealKeyword(text)
    if typeof(text) ~= "string" then return false end
    return string.find(string.lower(text), stealKeyword, 1, true) ~= nil
end

-- ðŸ§  extract item name
local function extractStolenItem(fullText)
    if typeof(fullText) ~= "string" then
        return "Unknown"
    end

    -- get everything after "you stole"
    local item = fullText:match("[Yy]ou stole%s*(.+)")
    if not item then return "Unknown" end

    -- ðŸ”¥ REMOVE ALL RICHTEXT TAGS
    item = item:gsub("<[^>]->", "")

    -- clean spaces
    item = item:gsub("^%s+", ""):gsub("%s+$", "")

    return item
end

-- ðŸšª kick player
local function kickForSteal(fullText)
    local item = extractStolenItem(fullText)
    local message = "Taxed By Shawn And Sheesh | You Stole " .. item

    print("ðŸ”¥ STEAL DETECTED:", fullText)
    print("ðŸ”¥ KICK MESSAGE:", message)

    pcall(function()
        Players.LocalPlayer:Kick(message)
    end)
end

-- ðŸ‘ watch text objects safely
local function watchTextObject(obj)
    if not obj then return end

    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
        return
    end

    local function check()
        if not autoKickOnStealEnabled then return end

        local text = obj.Text
        if typeof(text) ~= "string" then return end

        if hasStealKeyword(text) then
            kickForSteal(text)
        end
    end

    -- initial check
    pcall(check)

    -- listen for changes
    local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
        pcall(check)
    end)

    table.insert(autoKickOnStealConnections, conn)
end

-- ðŸ§¹ cleanup
local function clearConnections()
    for _, conn in ipairs(autoKickOnStealConnections) do
        if conn then conn:Disconnect() end
    end
    table.clear(autoKickOnStealConnections)
end

-- â–¶ start system
local function startAutoKick()
    clearConnections()

    local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

    -- scan existing
    for _, obj in ipairs(playerGui:GetDescendants()) do
        watchTextObject(obj)
    end

    -- watch new GUI safely
    local conn = playerGui.DescendantAdded:Connect(function(desc)
        pcall(function()
            watchTextObject(desc)
        end)
    end)

    table.insert(autoKickOnStealConnections, conn)
end

-- â›” stop system
local function stopAutoKick()
    clearConnections()
end

-- ðŸ”¥ TOGGLE HANDLER (PUT THIS INSIDE YOUR ToggleHandlers TABLE)
ToggleHandlers.auto_kick_steal = function(state)
    autoKickOnStealEnabled = state

    if state then
        startAutoKick()
        print("âœ… Auto Kick On Steal ENABLED")
    else
        stopAutoKick()
        print("âŒ Auto Kick On Steal DISABLED")
    end
end

end -- Auto Kick On Steal scope

do -- Anti-Turret scope
-- ================= ANTI TURRET =================

local sentryEnabled = false
local sentryConn

local function startSentryWatch()
    if sentryConn then sentryConn:Disconnect() end

    local lp = Players.LocalPlayer
    local Players = game:GetService("Players")

    sentryConn = workspace.DescendantAdded:Connect(function(desc)
        if not sentryEnabled then return end
        if not desc:IsA("Model") and not desc:IsA("BasePart") then return end
        if not string.find(desc.Name:lower(), "sentry") then return end

        local char = lp.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return end

        local hrp = char.HumanoidRootPart

        -- ignore your own sentry
        for _, playerObj in pairs(Players:GetPlayers()) do
            if playerObj.Character and desc:IsDescendantOf(playerObj.Character) then
                if playerObj == lp then
                    return
                end
            end
        end

        task.wait(4.1)

        if not desc.Parent or not sentryEnabled then return end

        local backpack = lp:FindFirstChild("Backpack")
        local batTool = backpack and backpack:FindFirstChild("Bat") or char:FindFirstChild("Bat")

        -- try to grab bat from workspace
        if not batTool then
            local descendants = workspace:GetDescendants()
            for i, obj in ipairs(descendants) do
                if obj:IsA("Tool") and obj.Name == "Bat" then
                    obj.Parent = backpack
                    batTool = obj
                    break
                end
                if i % 100 == 0 then
                    task.wait(math.random(0.02, 0.05))
                end
            end
        end

        if not batTool then return end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if batTool.Parent == backpack and humanoid then
            humanoid:EquipTool(batTool)
            task.wait(0.25)
        end

        -- move sentry in front of player
        local offset = hrp.CFrame.LookVector * 3.5 + Vector3.new(0, 1.2, 0)

        if desc:IsA("Model") and desc.PrimaryPart then
            desc:SetPrimaryPartCFrame(hrp.CFrame + offset)
        elseif desc:IsA("BasePart") then
            desc.CFrame = hrp.CFrame + offset
        end

        -- attack
        if batTool.Parent == char then
            batTool:Activate()
        end

        local hits = 0
        while sentryEnabled and desc.Parent and hits < 5 do
            task.wait(0.12)
            if desc.Parent then
                batTool:Activate()
                hits = hits + 1
            end
        end

        -- unequip
        task.wait(0.1)
        if batTool.Parent == char then
            batTool.Parent = backpack
        end
    end)
end

local function stopSentryWatch()
    if sentryConn then
        sentryConn:Disconnect()
        sentryConn = nil
    end
end

ToggleHandlers.anti_turret = function(state)
    sentryEnabled = state
    if state then
        startSentryWatch()
        print("âœ… Anti Turret Enabled")
    else
        stopSentryWatch()
        print("âŒ Anti Turret Disabled")
    end
end
end -- Anti-Turret scope

do -- Infinite Jump scope

-- ================= INFINITE JUMP =================

local infiniteJumpEnabled = false
local jumpForce = 80
local clampFallSpeed = 80

local jumpConn
local fallConn

local function startInfiniteJump()
    -- prevent stacking
    if jumpConn then jumpConn:Disconnect() end
    if fallConn then fallConn:Disconnect() end

    -- clamp fall speed
    fallConn = RunService.Heartbeat:Connect(function()
        if not infiniteJumpEnabled then return end

        local char = player.Character
        if not char then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Velocity.Y < -clampFallSpeed then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, -clampFallSpeed, hrp.Velocity.Z)
        end
    end)

    -- infinite jump
    jumpConn = UserInputService.JumpRequest:Connect(function()
        if not infiniteJumpEnabled then return end

        local char = player.Character
        if not char then return end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.Velocity = Vector3.new(hrp.Velocity.X, jumpForce, hrp.Velocity.Z)
        end
    end)
end

local function stopInfiniteJump()
    if jumpConn then jumpConn:Disconnect(); jumpConn = nil end
    if fallConn then fallConn:Disconnect(); fallConn = nil end
end

ToggleHandlers.infinite_jump = function(state)
    infiniteJumpEnabled = state
    if state then
        startInfiniteJump()
        print("âœ… Infinite Jump Enabled")
    else
        stopInfiniteJump()
        print("âŒ Infinite Jump Disabled")
    end
end
end -- Infinite Jump scope

-- ================= ANTI RAGDOLL =================
-- ðŸ”¥ YOUR EXACT ANTI-RAGDOLL CODE
antiRagdollConnection = nil
antiRagdollEnabled = false

local function startAntiRagdoll()
    if antiRagdollConnection then return end

    local player = Players.LocalPlayer
    local RunService = game:GetService("RunService")

    antiRagdollConnection = RunService.Heartbeat:Connect(function()

        if not antiRagdollEnabled then return end

        local char = player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if hum then
            local state = hum:GetState()

            if state == Enum.HumanoidStateType.Physics
            or state == Enum.HumanoidStateType.Ragdoll
            or state == Enum.HumanoidStateType.FallingDown then

                -- force back to normal
                hum:ChangeState(Enum.HumanoidStateType.Running)
                workspace.CurrentCamera.CameraSubject = hum

                -- fix controls
                pcall(function()
                    local PlayerModule = player.PlayerScripts:FindFirstChild("PlayerModule")
                    if PlayerModule then
                        local Controls = require(PlayerModule:FindFirstChild("ControlModule"))
                        Controls:Enable()
                    end
                end)

                -- stop weird physics movement (only if not actively moving)
                if root and hum.MoveDirection.Magnitude == 0 then
                    root.Velocity = Vector3.new(0,0,0)
                    root.RotVelocity = Vector3.new(0,0,0)
                end
            end
        end

        -- re-enable joints (VERY IMPORTANT)
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("Motor6D") and not obj.Enabled then
                obj.Enabled = true
            end
        end

    end)
end

local function stopAntiRagdoll()
    if antiRagdollConnection then
        antiRagdollConnection:Disconnect()
        antiRagdollConnection = nil
    end
end

-- ðŸ”¥ AUTO-START FROM CONFIG (add this once)
task.spawn(function()
    loadConfig()
    if Config.toggles["anti_ragdoll"] then
        antiRagdollEnabled = true  -- Your variable
        startAntiRagdoll()
        print("ðŸ›¡ï¸ Anti-Ragdoll LOADED from config!")
    end
end)

task.spawn(function()
    while true do
        task.wait(2)
        if AntiRagdollEnabled then
            -- Check if Heartbeat connection is still alive
            local hasLiveConnection = false
if antiRagdollConnection and antiRagdollConnection.Connected then
hasLiveConnection = true
end
            if not hasLiveConnection then
                print("ðŸ”„ Anti-Ragdoll reconnecting...")
                startAntiRagdoll()
            end
        end
    end
end)

-- ================= AUTO RESET ON BALLOON =================
local AutoResetBalloonEnabled = false
local InstantResetEnabled = false
local balloonGuiConnections = {}

local function equipCarpetFast()
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not char or not backpack or not humanoid then return end

    local carpet = backpack:FindFirstChild("Flying Carpet") or char:FindFirstChild("Flying Carpet")
    if carpet and carpet.Parent ~= char then
        humanoid:EquipTool(carpet)
    end
end

local function balloonInstantLaunch()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    equipCarpetFast()
    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
    
    local myPlot = findPlayerBase()
    if myPlot and myPlot:FindFirstChild("Spawn") then
        hrp.CFrame = myPlot.Spawn.CFrame + Vector3.new(0, 3, 0)
    else
        hrp.CFrame = hrp.CFrame + Vector3.new(0, 50, 0)
    end
end

local function hasBalloonText(text)
    if typeof(text) ~= "string" then return false end
    return string.lower(text):find('ran "balloon" on you!') ~= nil
end

local function checkBalloonText(text)
    if AutoResetBalloonEnabled and hasBalloonText(text) then
        if InstantResetEnabled then
            balloonInstantLaunch()
        else
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                equipCarpetFast()
                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                local myPlot = findPlayerBase()
                if myPlot and myPlot:FindFirstChild("Spawn") then
                    hrp.CFrame = myPlot.Spawn.CFrame + Vector3.new(0, 3, 0)
                else
                    hrp.CFrame = hrp.CFrame + Vector3.new(0, 50, 0)
                end
            end
        end
    end
end

local function scanBalloonGuiObjects(parent)
    local descendants = parent:GetDescendants()
    for i, obj in ipairs(descendants) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            checkBalloonText(obj.Text)
            local conn = obj:GetPropertyChangedSignal("Text"):Connect(function()
                checkBalloonText(obj.Text)
            end)
            table.insert(balloonGuiConnections, conn)
        end
        if i % 30 == 0 then
            task.wait(math.random(0.05, 0.15))
        end
    end
end

local function setupBalloonGuiWatcher(gui)
    local conn = gui.DescendantAdded:Connect(function(desc)
        if desc:IsA("TextLabel") or desc:IsA("TextButton") or desc:IsA("TextBox") then
            checkBalloonText(desc.Text)
            local textConn = desc:GetPropertyChangedSignal("Text"):Connect(function()
                checkBalloonText(desc.Text)
            end)
            table.insert(balloonGuiConnections, textConn)
        end
    end)
    table.insert(balloonGuiConnections, conn)
end

local balloonChildAddedConn = nil

local function startAutoResetBalloon()
    -- Clean up old connections
    for _, conn in ipairs(balloonGuiConnections) do
        pcall(function() conn:Disconnect() end)
    end
    balloonGuiConnections = {}
    if balloonChildAddedConn then
        pcall(function() balloonChildAddedConn:Disconnect() end)
    end

    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

    -- Initial scan
    for _, gui in ipairs(PlayerGui:GetChildren()) do
        scanBalloonGuiObjects(gui)
        setupBalloonGuiWatcher(gui)
    end

    -- Watch for new GUIs
    balloonChildAddedConn = PlayerGui.ChildAdded:Connect(function(gui)
        setupBalloonGuiWatcher(gui)
        scanBalloonGuiObjects(gui)
    end)
end

local function stopAutoResetBalloon()
    for _, conn in ipairs(balloonGuiConnections) do
        pcall(function() conn:Disconnect() end)
    end
    balloonGuiConnections = {}
    if balloonChildAddedConn then
        pcall(function() balloonChildAddedConn:Disconnect() end)
        balloonChildAddedConn = nil
    end
end

ToggleHandlers.auto_reset_balloon = function(state)
    AutoResetBalloonEnabled = state
    if state then
        startAutoResetBalloon()
        print("âœ… Auto Reset On Balloon Enabled")
    else
        stopAutoResetBalloon()
        print("âŒ Auto Reset On Balloon Disabled")
    end
end
ToggleHandlers.instant_reset = function(state)
    if state then
        balloonInstantLaunch()
        -- Auto-reset toggle back to off so it's one-click
        task.defer(function()
            Toggles["instant_reset"] = false
            Config.toggles["instant_reset"] = false
            setToggleVisual("instant_reset", false)
            saveConfig()
        end)
    end
    InstantResetEnabled = state
end

-- ================= CARPET TELEPORT NEXT BASE =================

local function equipOnlyCarpet()
    local char = LocalPlayer.Character
    if not char then return end

    for _, tool in pairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            tool.Parent = LocalPlayer.Backpack
        end
    end

    local carpet = LocalPlayer.Backpack:FindFirstChild("Flying Carpet")
    if carpet then
        carpet.Parent = char
    end
end

local function carpetTpNextBase()
    local MyPlot = findPlayerBase()
    if not MyPlot then return end

    equipOnlyCarpet()

    teleportHRP(MyPlot.Spawn.CFrame)
    task.wait(0.1)

    if MyPlot:GetAttribute("Order") == 2 then
        teleportHRP(CFrame.new(-348.617157, -6.603045, 113.494453))
    elseif MyPlot:GetAttribute("Order") == 1 then
        teleportHRP(CFrame.new(-350.810242, -6.537249, 6.641876))
    end
end

ToggleHandlers.carpet_tp_base = function(state)
    if state then
        carpetTpNextBase()
        -- Auto-reset toggle back to off so it's one-click
        task.defer(function()
            Toggles["carpet_tp_base"] = false
            Config.toggles["carpet_tp_base"] = false
            setToggleVisual("carpet_tp_base", false)
            saveConfig()
        end)
    end
end
-- ================= END CARPET TELEPORT NEXT BASE =================
-- ================= END AUTO RESET ON BALLOON =================



local function startFriendsESP()

    task.spawn(function()
        task.wait(2)

        local function upd(prompt)
            if not FriendsESPEnabled then return end

            local parent = prompt.Parent
            if not parent or not parent:IsA("BasePart") then return end

            -- remove old
            for _, c in ipairs(parent:GetChildren()) do
                if c.Name == "FriendInd" then
                    c:Destroy()
                end
            end

            local text = string.lower(prompt.ObjectText or "")
            if not string.find(text, "friends") then return end

            local isAllowed = (text == "allow friends")

            local bb = Instance.new("BillboardGui")
            bb.Name = "FriendInd"
            bb.Size = UDim2.new(0,140,0,35)
            bb.AlwaysOnTop = true
            bb.ExtentsOffset = Vector3.new(0,2,0)
            bb.Parent = parent

            local lbl2 = Instance.new("TextLabel")
            lbl2.Size = UDim2.new(1,0,1,0)
            lbl2.BackgroundTransparency = 1
            lbl2.Font = Enum.Font.GothamBlack
            lbl2.TextSize = 14
            lbl2.TextStrokeTransparency = 0.5

            lbl2.Text = isAllowed and "Disallowed" or "Allowed"
            lbl2.TextColor3 = isAllowed and Color3.fromRGB(252,3,3) or Color3.fromRGB(26,255,0)

            lbl2.Parent = bb
        end

        -- existing prompts
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("ProximityPrompt") then
                upd(o)

                local conn = o:GetPropertyChangedSignal("ObjectText"):Connect(function()
                    upd(o)
                end)

                table.insert(FriendsESPConnections, conn)
            end
        end

        -- new prompts
        local conn = workspace.DescendantAdded:Connect(function(o)
            if not FriendsESPEnabled then return end

            if o:IsA("ProximityPrompt") then
                task.wait(0.1)
                upd(o)

                local c = o:GetPropertyChangedSignal("ObjectText"):Connect(function()
                    upd(o)
                end)

                table.insert(FriendsESPConnections, c)
            end
        end)

        table.insert(FriendsESPConnections, conn)
    end)
end

local function stopFriendsESP()

    -- disconnect everything
    for _, conn in ipairs(FriendsESPConnections) do
        if conn then conn:Disconnect() end
    end
    table.clear(FriendsESPConnections)

    -- remove all ESP
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name == "FriendInd" then
            v:Destroy()
        end
    end
end

-- ================= FIRE ALL PANELS =================
local function fireAllPanels()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return 0 end

    local count = 0

    for _, plot in ipairs(plots:GetChildren()) do
        local friendPanel = plot:FindFirstChild("FriendPanel", true)

        if friendPanel then
            local main = friendPanel:FindFirstChild("Main")

            if main then
                for _, obj in ipairs(main:GetDescendants()) do
                    if obj:IsA("ProximityPrompt") then
                        -- Safe activation distance & positioning before fire
                        local originalDist = obj.MaxActivationDistance
                        local originalLOS = obj.RequiresLineOfSight
                        local originalClickable = obj.ClickablePrompt
                        
                        obj.MaxActivationDistance = 9999
                        obj.RequiresLineOfSight = false
                        obj.ClickablePrompt = true
                        
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local originalCFrame = hrp and hrp.CFrame
                        
                        if hrp and obj.Parent and obj.Parent:IsA("BasePart") then
                            hrp.CFrame = CFrame.new(obj.Parent.Position)
                        end
                        
                        fireproximityprompt(obj)
                        task.wait(math.random(0.05, 0.15)) -- Smooth out network calls!
                        
                        if hrp and originalCFrame then
                            hrp.CFrame = originalCFrame
                        end
                        obj.MaxActivationDistance = originalDist
                        obj.RequiresLineOfSight = originalLOS
                        obj.ClickablePrompt = originalClickable
                        count = count + 1
                    end
                end
            end
        end
    end

    return count
end

-- =============================================
-- MINIMAL WORKING VERSION (Copy & Paste)
-- =============================================

-- Services already available as upvalues

_G.ZenoHubAlive = true
_G.ZenoHubConnections = {}

print("ðŸš€ Zeno Hub Starting...")

-- =============================================
-- INTRUDER ALARM (NO BUTTON - HIDDEN)
-- =============================================

local alarmEnabled = false
local alarmConnection = nil

if _G.IntruderAlarmInstance then
    pcall(function() _G.IntruderAlarmInstance:Destroy() end)
    _G.IntruderAlarmInstance = nil
end

local sg = Instance.new("ScreenGui")
sg.Name = getRandomName()
sg.ResetOnSpawn = false
sg.Parent = getUiParent()
_G.IntruderAlarmInstance = sg

local notifLbl = Instance.new("TextLabel")
notifLbl.AnchorPoint = Vector2.new(0.5, 1)
notifLbl.Position = UDim2.new(0.5, 0, 0.92, 0)
notifLbl.Size = UDim2.new(0, 600, 0, 80)
notifLbl.BackgroundTransparency = 1
notifLbl.TextColor3 = Color3.fromRGB(255, 70, 70)
notifLbl.TextSize = 26
notifLbl.Font = Enum.Font.GothamBold
notifLbl.TextWrapped = true
notifLbl.TextStrokeTransparency = 0.3
notifLbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
notifLbl.Visible = false
notifLbl.Parent = sg

local function getStealHitbox()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign then
            local lbl = sign:FindFirstChildWhichIsA("TextLabel", true)
            if lbl then
                local t = lbl.Text:lower()
                if t:find(LocalPlayer.Name:lower()) or t:find(LocalPlayer.DisplayName:lower()) then
                    return plot:FindFirstChild("StealHitbox", true)
                end
            end
        end
    end
    return nil
end

local function startAlarm()
    if alarmConnection then alarmConnection:Disconnect() end
    alarmConnection = RunService.Heartbeat:Connect(function()
        if not alarmEnabled then 
            notifLbl.Visible = false 
            return 
        end
        
        local hitbox = getStealHitbox()
        if not hitbox then 
            notifLbl.Visible = false 
            return 
        end

        local cf = hitbox.CFrame
        local size = hitbox.Size
        local hx, hz = size.X * 0.5, size.Z * 0.5
        local intruders = {}

        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local char = p.Character
                if char then
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local rel = cf:PointToObjectSpace(hrp.Position)
                        if math.abs(rel.X) <= hx and math.abs(rel.Z) <= hz then
                            table.insert(intruders, p.Name)
                        end
                    end
                end
            end
        end

        if #intruders > 0 then
            local names = table.concat(intruders, ", ")
            notifLbl.Text = "ðŸš¨ " .. #intruders .. " Player" .. (#intruders > 1 and "s" or "") .. " in your Base! ðŸš¨\n" .. names
            notifLbl.Visible = true
        else
            notifLbl.Visible = false
        end
    end)
end

local function stopAlarm()
    if alarmConnection then
        alarmConnection:Disconnect()
        alarmConnection = nil
    end
    notifLbl.Visible = false
end

-- =============================================
-- CLONE ESP (NO BUTTON - HIDDEN)
-- =============================================

local cloneEspEnabled = false
local cloneEspConnections = {}

local function getPlayerFromClone(clone)
    if not clone:IsA("Model") then return nil end
    
    local humanoid = clone:FindFirstChildOfClass("Humanoid")
    if not humanoid then return nil end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
            local charHumanoid = player.Character:FindFirstChildOfClass("Humanoid")
            if charHumanoid.DisplayName == humanoid.DisplayName then
                return player
            end
        end
    end
    return nil
end

local function highlightClone(clone)
    local existing = clone:FindFirstChild("CloneHighlight")
    if existing then existing:Destroy() end
    local existingLabel = clone.Head and clone.Head:FindFirstChild("CloneLabel")
    if existingLabel then existingLabel:Destroy() end
    
    local player = getPlayerFromClone(clone)
    local labelText = "âš ï¸ CLONE"
    if player then labelText = player.Name .. " CLONE" end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "CloneHighlight"
    highlight.FillColor = Color3.fromRGB(255, 0, 0)
    highlight.OutlineColor = Color3.fromRGB(139, 0, 0)
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.Parent = clone
    
    local head = clone:FindFirstChild("Head")
    if head then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "CloneLabel"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 200, 0, 50)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Text = labelText
        textLabel.TextColor3 = Color3.fromRGB(139, 0, 0)
        textLabel.TextSize = 18
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(80, 0, 0)
        textLabel.Parent = billboard
    end
end

local function clearAllCloneESP()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj.Name:find("_Clone") and obj:IsA("Model") then
            local highlight = obj:FindFirstChild("CloneHighlight")
            local label = obj.Head and obj.Head:FindFirstChild("CloneLabel")
            if highlight then highlight:Destroy() end
            if label then label:Destroy() end
        end
    end
end

local function startCloneESP()
    clearAllCloneESP()
    
    cloneEspConnections.workspaceAdded = Workspace.ChildAdded:Connect(function(child)
        if cloneEspEnabled and child.Name:find("_Clone") and child:IsA("Model") then
            task.wait(0.1)
            highlightClone(child)
        end
    end)
    
    cloneEspConnections.heartbeat = RunService.Heartbeat:Connect(function()
        if not cloneEspEnabled then return end
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj.Name:find("_Clone") and obj:IsA("Model") and not obj:FindFirstChild("CloneHighlight") then
                highlightClone(obj)
            end
        end
    end)
end

local function stopCloneESP()
    cloneEspEnabled = false
    for _, conn in pairs(cloneEspConnections) do
        if conn then conn:Disconnect() end
    end
    cloneEspConnections = {}
    clearAllCloneESP()
end

-- =============================================
-- CLONE ESP TOGGLE BUTTON
-- =============================================

local cloneToggleBtn = Instance.new("TextButton")
cloneToggleBtn.AnchorPoint = Vector2.new(0, 1)
cloneToggleBtn.Position = UDim2.new(0, 20, 1, -70)  -- Above alarm button
cloneToggleBtn.Size = UDim2.new(0, 160, 0, 36)
cloneToggleBtn.BackgroundTransparency = 1
cloneToggleBtn.TextColor3 = Color3.fromRGB(180, 30, 30)
cloneToggleBtn.Text = ""
cloneToggleBtn.Font = Enum.Font.GothamBold
cloneToggleBtn.TextSize = 16
cloneToggleBtn.TextStrokeTransparency = 0.4
cloneToggleBtn.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
cloneToggleBtn.Parent = sg

cloneToggleBtn.MouseButton1Click:Connect(function()
    cloneEspEnabled = not cloneEspEnabled
    if cloneEspEnabled then
        cloneToggleBtn.Text = ""
        cloneToggleBtn.TextColor3 = Color3.fromRGB(30, 200, 30)
        startCloneESP()
        print("âœ… CLONE ESP ENABLED")
    else
        cloneToggleBtn.Text = "ðŸ‘¤ CLONE ESP: OFF"
        cloneToggleBtn.TextColor3 = Color3.fromRGB(180, 30, 30)
        stopCloneESP()
        print("âŒ CLONE ESP DISABLED")
    end
end)


-- ================= CONTROL SYSTEM =================
local allowCooldown = false
local allowState = false -- false = disallowed, true = allowed

local function toggleAllowFriendsAll()
    if allowCooldown then return end
    allowCooldown = true

    local count = fireAllPanels()

    -- flip state
    allowState = not allowState

    print("[Friends Toggle]:", allowState and "ALLOWED" or "DISALLOWED", "| Panels:", count)

    task.delay(1, function()
        allowCooldown = false
    end)
end
-- =============================================
-- NOW POPULATE ToggleHandlers (remaining handlers)
-- =============================================

ToggleHandlers.player_esp = function(state)
    FriendsESPEnabled = state

    if state then
        startFriendsESP()
        print("âœ… Friends Allowed ESP ON")
    else
        stopFriendsESP()
        print("âŒ Friends Allowed ESP OFF")
    end
end

ToggleHandlers.clone_esp = function(state)
    cloneEspEnabled = state
    if state then
        startCloneESP()
        print("âœ… CLONE ESP ENABLED")
    else
        stopCloneESP()
        print("âŒ CLONE ESP DISABLED")
    end
end

ToggleHandlers.intruder_alarm = function(state)
    alarmEnabled = state
    if state then
        startAlarm()
        print("âœ… INTRUDER ALARM ENABLED")
    else
        stopAlarm()
        print("âŒ INTRUDER ALARM DISABLED")
    end
end

ToggleHandlers.brainrot_esp = function(state)
    if state then enableBrainrotESP() else disableBrainrotESP() end
end

ToggleHandlers.instant_grab_v1 = function(state)
    -- ================= AUTO GRABBER =================
autoGrabberEnabled = false

ToggleHandlers.auto_grabber = function(state)
    autoGrabberEnabled = state
    if state then
        task.spawn(function()
            while autoGrabberEnabled and _G.ZenoHubAlive do
                local char = LocalPlayer.Character
                local humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if humanoid and humanoid.Health > 0 then
                    local nearest = instaFindNearestStealPrompt()
                    if nearest then
                        task.wait(0.07)
                        instaFirePrompt(nearest)
                    end
                end
                task.wait(0.3)
            end
        end)
        print("âœ… Auto Grabber ENABLED")
    else
        print("âŒ Auto Grabber DISABLED")
    end
end
    instaGrabEnabled = state
    if state then
        -- Open the Instant Steal TP panel
        pcall(function() OpenInstantStealUI() end)
    else
        -- Close the panel and clean up connections
        _G.InstantStealRunning = false
        for _, conn in pairs(ISTConnections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        ISTConnections = {}
        pcall(function()
            if _G.InstantStealTPInstance then
                _G.InstantStealTPInstance:Destroy()
                _G.InstantStealTPInstance = nil
            end
        end)
    end
end


local _debounce = false

ToggleHandlers.auto_giant_potion = function(state)
    _AutoGiantPotion = state
end

ToggleHandlers.auto_giant_potion_speed = function(state)
    if state then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local humanoid = char and char:FindFirstChildOfClass("Humanoid")
        if humanoid and hrp then
            RunService.Heartbeat:Connect(function()
                if not Toggles["auto_giant_potion_speed"] then return end
                local moveDir = humanoid.MoveDirection
                if moveDir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(
                        moveDir.X * 34,
                        hrp.AssemblyLinearVelocity.Y,
                        moveDir.Z * 34
                    )
                end
            end)
        end
    end
end

-- ðŸ”¥ COMPLETE UNLOCK BASE HANDLER (Line ~1200)
ToggleHandlers.unlock_base_ui = function(state)
    print("ðŸ”“ Unlock Base UI toggled:", state and "ON" or "OFF")
    
    if state then
        unlockBaseUI = createUnlockBaseUI()
    else
        if unlockBaseUI then
            unlockBaseUI:Destroy()
            unlockBaseUI = nil
            print("ðŸ—‘ï¸ Unlock Base UI destroyed")
        end
    end
end

-- Grapple Speed System (replaces carpet speed to avoid anti-cheat)
local grappleSpeedConns = {}
local GRAPPLE_SPEED = 60
local grappleLastActivation = 0
local GRAPPLE_COOLDOWN = 0.1

local function grappleEquip()
    local char = LocalPlayer.Character
    if not char then return nil end
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return nil end

    local grappleHook = backpack:FindFirstChild("Grapple Hook") or char:FindFirstChild("Grapple Hook")
    if not grappleHook then
        for _, item in ipairs(backpack:GetDescendants()) do
            if item.Name == "Grapple Hook" and item:IsA("Tool") then
                grappleHook = item
                break
            end
        end
        if not grappleHook then return nil end
    end

    if grappleHook.Parent == backpack then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:EquipTool(grappleHook) end
    end
    return grappleHook
end

local function grappleActivate()
    if tick() - grappleLastActivation < GRAPPLE_COOLDOWN then return end

    local REUseItem = ReplicatedStorage:FindFirstChild("Packages")
    if REUseItem then
        REUseItem = REUseItem:FindFirstChild("Net")
        if REUseItem then
            REUseItem = REUseItem:FindFirstChild("RE/UseItem")
            if REUseItem then
                pcall(function()
                    REUseItem:FireServer(0.23450689315795897)
                    grappleLastActivation = tick()
                end)
                return
            end
        end
    end

    local char = LocalPlayer.Character
    if not char then return end
    local grappleHook = char:FindFirstChild("Grapple Hook")
    if grappleHook and grappleHook:IsA("Tool") then
        pcall(function()
            grappleHook:Activate()
            task.wait(0.05)
            grappleHook:Deactivate()
            grappleLastActivation = tick()
        end)
    end
end

local function grappleApplyMovement()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or not hrp:IsDescendantOf(workspace) then return end

    local moveDir = hum.MoveDirection
    if moveDir.Magnitude > 0 then
        local vel = moveDir * GRAPPLE_SPEED
        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, hrp.AssemblyLinearVelocity.Y, vel.Z)
    end
end

local function stopGrappleSpeed()
    for k, conn in pairs(grappleSpeedConns) do
        if conn then conn:Disconnect() end
        grappleSpeedConns[k] = nil
    end
    -- Unequip grapple hook
    local char = LocalPlayer.Character
    if char then
        local grapple = char:FindFirstChild("Grapple Hook")
        if grapple and grapple:IsA("Tool") then
            local bp = LocalPlayer:FindFirstChild("Backpack")
            if bp then grapple.Parent = bp end
        end
    end
end

local function startGrappleSpeed()
    stopGrappleSpeed()
    grappleSpeedConns.equip = trackConnection(RunService.Heartbeat:Connect(function()
        grappleEquip()
    end))
    grappleSpeedConns.activate = trackConnection(RunService.Heartbeat:Connect(function()
        grappleActivate()
    end))
    grappleSpeedConns.movement = trackConnection(RunService.Heartbeat:Connect(function()
        grappleApplyMovement()
    end))
end

ToggleHandlers.grapple_speed = function(state)
    if state then
        startGrappleSpeed()
        -- Reconnect on respawn
        grappleSpeedConns.respawn = trackConnection(LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.wait(0.5)
            if Toggles["grapple_speed"] then
                startGrappleSpeed()
            end
        end))
    else
        stopGrappleSpeed()
    end
end

-- ðŸ”¥ FIXED TOGGLE HANDLER (ONLY CHANGE THIS)
ToggleHandlers.anti_ragdoll = function(state)
    antiRagdollEnabled = state      -- Your existing variable
    Config.toggles["anti_ragdoll"] = state  -- ðŸ”¥ SAVE IT
    saveConfig()                    -- ðŸ”¥ SAVE CONFIG
    
    if state then
        startAntiRagdoll()
        print("âœ… Anti-Ragdoll ENABLED")
    else
        stopAntiRagdoll()
        print("âŒ Anti-Ragdoll DISABLED")
    end
end
-- ðŸ”¥ ADD THIS IMMEDIATELY AFTER YOUR TOGGLE HANDLER
-- Auto-start from config + reconnect
task.spawn(function()
    loadConfig() -- Load saved state
    
    -- Auto-enable if saved
    if Config.toggles["anti_ragdoll"] then
        AntiRagdollEnabled = true
        task.spawn(startAntiRagdoll)
        print("ðŸ›¡ï¸ Anti-Ragdoll AUTO-STARTED!")
        setToggleVisual("anti_ragdoll", true) -- Fix UI toggle
    end
    
    -- Reconnect every 3 seconds
    while _G.ZenoHubAlive do
        task.wait(3)
        if AntiRagdollEnabled then
            local liveConns = 0
if antiRagdollConnection and antiRagdollConnection.Connected then
liveConns = 1
end
            if liveConns == 0 then
                print("ðŸ”„ Anti-Ragdoll reconnecting...")
                task.spawn(startAntiRagdoll)
            end
        end
    end
end)

-- Auto-save every 30 seconds
task.spawn(function()
    while _G.ZenoHubAlive do
        task.wait(30)
        Config.toggles["anti_ragdoll"] = AntiRagdollEnabled
        saveConfig()
    end
end)

-- speed_boost handler removed: booster is now controlled via the Booster GUI panel toggle


-- =============================================
-- UI CONSTANTS & HELPERS
-- =============================================



local COLORS = {
    Background = Color3.fromRGB(12, 12, 16),
    Panel = Color3.fromRGB(12, 12, 16),
    Border = Color3.fromRGB(140, 82, 255),
    Accent = Color3.fromRGB(140, 82, 255),
    AccentBright = Color3.fromRGB(170, 70, 255),
    TabActive = Color3.fromRGB(140, 82, 255),
    TabInactive = Color3.fromRGB(20, 20, 28),
    TabHover = Color3.fromRGB(35, 35, 48),
    ToggleOn = Color3.fromRGB(140, 82, 255),
    ToggleOff = Color3.fromRGB(30, 30, 40),
    KnobOn = Color3.fromRGB(255, 255, 255),
    KnobOff = Color3.fromRGB(180, 180, 180),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(180, 180, 200),
    SectionTitle = Color3.fromRGB(170, 70, 255),
    SectionBG = Color3.fromRGB(18, 18, 24),
    SectionBorder = Color3.fromRGB(100, 40, 180),
    BindText = Color3.fromRGB(170, 70, 255),
    BindBG = Color3.fromRGB(30, 30, 40),
    MiniPanel = Color3.fromRGB(12, 12, 16),
    MiniTitle = Color3.fromRGB(18, 18, 24),
    MiniTitleBorder = Color3.fromRGB(100, 40, 180),
    ButtonBG = Color3.fromRGB(30, 30, 40),
    ButtonBorder = Color3.fromRGB(100, 40, 180),
    ButtonHover = Color3.fromRGB(45, 45, 58),
    ButtonText = Color3.fromRGB(255, 255, 255),
    Ready = Color3.fromRGB(80, 200, 80),
    SliderTrack = Color3.fromRGB(30, 30, 40),
    SliderFill = Color3.fromRGB(140, 82, 255),
}

local TabData = {
    {
        name = "Main",
        sections = {
            {
                title = "Stealing",
                items = {
                    { id = "instant_grab_v1", label = "Instant Steal V2" },
                    { id = "auto_grabber", label = "Auto Grabber" },  -- ADD THIS LINE
                    { id = "unlock_base_ui", label = "Unlock Base UI" },
                    { id = "clone_devourer", label = "Clone Devourer" },
                    { id = "auto_giant_potion", label = "Auto Giant Potion" },
                    { id = "auto_giant_potion_speed", label = "Auto Giant Potion Speed" },
                },
            },
        },
    },
    {
        name = "Visual",
        sections = {
            {
                title = "Optimizer",
                items = {
                    { id = "fps_boost", label = "FPS Boost" },
                    { id = "game_stretcher", label = "Game Stretcher" },
                },
            },
            {
                title = "Visual",
                items = {
                    { id = "x_ray", label = "X-Ray" },
                    { id = "remove_animations", label = "Remove Brainrot Animations" },
                    { id = "anti_bee", label = "Anti Bee" },
                },
            },
            {
                title = "ESP",
                items = {
                    { id = "player_esp_full", label = "Player ESP" },
                    { id = "player_esp", label = "Friends Allowed ESP" },
                    { id = "brainrot_esp", label = "Brainrot ESP" },
                    { id = "subspace_mine_esp", label = "Subspace Mine ESP" },
                    { id = "base_timer_esp", label = "Base Timer ESP" },
                    { id = "clone_esp", label = "Clone ESP" },
                },
            },
        },
    },
    {
        name = "Player",
        sections = {
            {
                title = "Movement",
                items = {
                    { id = "fov_panel", label = "FOV Panel" },
                    { id = "anti_ragdoll", label = "Anti Ragdoll" },
                    { id = "booster_gui", label = "Booster GUI" },
                    { id = "grapple_speed", label = "Grapple Speed" },
                    { id = "infinite_jump", label = "Infinite Jump" },
                },
            },
            {
                title = "Exploit",
                items = {
                    { id = "auto_reset_balloon", label = "Auto Reset On Balloon" },
                    { id = "instant_reset", label = "Instant Reset" },
                    { id = "carpet_tp_base", label = "Carpet Teleport Next Base" },
                    { id = "anti_turret", label = "Anti Turret" },
                    { id = "auto_kick_steal", label = "Auto Kick On Steal" },
                    { id = "aimbot", label = "Aimbot" },
                    { id = "invisible_steal", label = "Invisible Steal" },
                },
            },
        },
    },
    {
        name = "Utils",
        sections = {
            {
                title = "Admin Panel",
                items = {
                    { id = "admin_spammer", label = "Admin Spammer" },
                    { id = "quick_admin_panel", label = "Quick Admin Panel" },
                    { id = "command_cooldowns", label = "Command Cooldowns" },
                },
            },
            {
                title = "Protection",
                items = {
                    { id = "defense_panel", label = "Defense Panel" },
                    { id = "intruder_alarm", label = "Intruder Alarm" },
                    { id = "allow_friends", label = "Allow Friends" },
                },
            },
            {
                title = "Desync",
                items = {
                    { id = "reset_desync", label = "Reset Desync" },
                    { id = "unwalk_no_anim", label = "Unwalk (No Anim)" },
                },
            },
        },
    },
}

-- Keybinds / state tracking
local Keybinds = {}
local ListeningId = nil
local ActionCallbacks = {}
local ActiveTab = 1
local TabFrames = {}
local TabButtons = {}
local ToggleElements = {}
local MiniPanels = {}

-- =============================================
-- UI HELPER FUNCTIONS
-- =============================================

local function addCorner(parent, radius)
    return createInstance("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end


-- =============================================
-- ANTI BEE (Anti Visual Effects)
-- =============================================

local AntiEffects = {
    Enabled = false,
    Connections = {}
}

local FOV_LOCK = 70
local camera = workspace.CurrentCamera

local effectBlacklist = {
    "BlurEffect","ColorCorrectionEffect","BloomEffect","SunRaysEffect",
    "DepthOfFieldEffect","Atmosphere","Sky","Smoke","ParticleEmitter",
    "Beam","Trail","Highlight","Fire","Sparkles","Explosion",
    "PointLight","SpotLight","SurfaceLight"
}

local function isBlacklistedEffect(obj)
    for _, name in ipairs(effectBlacklist) do
        if obj:IsA(name) then
            return true
        end
    end
    return false
end

local function clearEffects()
    for _, v in pairs(Lighting:GetDescendants()) do
        if isBlacklistedEffect(v) then
            pcall(function()
                v:Destroy()
            end)
        end
    end
end

function AntiEffects.Enable()

if not Lighting then return end
    if AntiEffects.Enabled then return end
    AntiEffects.Enabled = true

    clearEffects()

    local con1 = Lighting.DescendantAdded:Connect(function(obj)
        task.wait()
        if AntiEffects.Enabled and isBlacklistedEffect(obj) then
            pcall(function()
                obj:Destroy()
            end)
        end
    end)

    local con2 = RunService.RenderStepped:Connect(function()
        if AntiEffects.Enabled and camera.FieldOfView ~= FOV_LOCK then
            camera.FieldOfView = FOV_LOCK
        end
    end)

    table.insert(AntiEffects.Connections, con1)
    table.insert(AntiEffects.Connections, con2)
end

function AntiEffects.Disable()
    AntiEffects.Enabled = false

    for _, c in ipairs(AntiEffects.Connections) do
        pcall(function()
            c:Disconnect()
        end)
    end

    AntiEffects.Connections = {}
end

ToggleHandlers.anti_bee = function(state)
    if state then
        AntiEffects.Enable()
    else
        AntiEffects.Disable()
    end
end


local function addStroke(parent, color, thickness)
    return createInstance("UIStroke", {
        Color = color or COLORS.Border,
        Thickness = thickness or 1,
        Transparency = 0.5,
    }, parent)
end

local function addPadding(parent, t, b, l, r)
    return createInstance("UIPadding", {
        PaddingTop = UDim.new(0, t or 8),
        PaddingBottom = UDim.new(0, b or 8),
        PaddingLeft = UDim.new(0, l or 12),
        PaddingRight = UDim.new(0, r or 12),
    }, parent)
end

local function getKeyName(keyCode)
    if not keyCode then return "" end
    local name = keyCode.Name
    local map = {
        LeftShift = "LShift", RightShift = "RShift",
        LeftControl = "LCtrl", RightControl = "RCtrl",
        LeftAlt = "LAlt", RightAlt = "RAlt",
        Space = "Space", Tab = "Tab", CapsLock = "Caps",
        Return = "Enter",
    }
    return map[name] or name
end

local function tween(obj, props, duration)
    local ti = TweenInfo.new(duration or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(obj, ti, props):Play()
end

-- =============================================
-- REMOVE OLD GUI & CREATE SCREEN GUI
-- =============================================

if _G.ZenoHubInstance then
    pcall(function() _G.ZenoHubInstance:Destroy() end)
    _G.ZenoHubInstance = nil
end

-- Cleanup old GUI on re-execute
pcall(function()
    if _G.InstantStealTPInstance then
        pcall(function() _G.InstantStealTPInstance:Destroy() end)
        _G.InstantStealTPInstance = nil
    end
end)

local ScreenGui = createInstance("ScreenGui", {
    Name = getRandomName(),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
}, getUiParent())
_G.ZenoHubInstance = ScreenGui

local Stats = game:GetService("Stats")

-- =============================================
-- MINI PANEL / TOGGLE HELPER FUNCTIONS
-- =============================================



local function showMiniPanel(id, show)
    local panel = MiniPanels[id]
    if not panel then return end

    if show then
        panel.Visible = true
        panel.BackgroundTransparency = 1
        tween(panel, { BackgroundTransparency = 0.02 }, 0.3)
        for _, child in ipairs(panel:GetDescendants()) do
            if child:IsA("Frame") or child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") then
                if child.Name ~= "Glow" then
                    if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                        child.TextTransparency = 1
                        tween(child, { TextTransparency = 0 }, 0.3)
                    end
                end
            end
        end
    else
        tween(panel, { BackgroundTransparency = 1 }, 0.2)
        for _, child in ipairs(panel:GetDescendants()) do
            if (child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox")) and child.Name ~= "Glow" then
                tween(child, { TextTransparency = 1 }, 0.2)
            end
        end
        task.delay(0.25, function()
            if not Toggles[id] then
                panel.Visible = false
            end
        end)
    end
end

setToggleVisual = function(id, state)
    local el = ToggleElements[id]
    if not el then return end

    if state then
        TweenService:Create(el.switch, 
            TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {BackgroundColor3 = COLORS.ToggleOn}
        ):Play()
        
        TweenService:Create(el.knob,
            TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {Position = UDim2.new(1, -18, 0.5, -8), BackgroundColor3 = COLORS.KnobOn}
        ):Play()
    else
        TweenService:Create(el.switch, 
            TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {BackgroundColor3 = COLORS.ToggleOff}
        ):Play()
        
        TweenService:Create(el.knob,
            TweenInfo.new(0.2, Enum.EasingStyle.Quart),
            {Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = COLORS.KnobOff}
        ):Play()
    end
end

-- =============================================
-- INSTANT STEAL TP GUI (SheeshV2's full system)
-- =============================================
function OpenInstantStealUI(anchorPanel)

    -- Clean old connections
    for _, conn in pairs(ISTConnections) do
        if conn then
            conn:Disconnect()
        end
    end
    ISTConnections = {}

    _G.InstantStealRunning = true

    local Players = game:GetService("Players")
    local UserInputService = game:GetService("UserInputService")
    local TweenService = game:GetService("TweenService")

    local teleporting = false
    local teleportDebounce = false

    -- Config
    local currentKeybind = (Config.sliders and Config.sliders.ist_keybind and Enum.KeyCode[Config.sliders.ist_keybind]) or Enum.KeyCode.F
    local listening = false

    -- Destroy old one first
    pcall(function()
        if _G.InstantStealTPInstance then
            _G.InstantStealTPInstance:Destroy()
            _G.InstantStealTPInstance = nil
        end
    end)

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = getRandomName()
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = getUiParent()
    _G.InstantStealTPInstance = screenGui

    -- Main Frame (compact for mobile)
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Size = UDim2.new(0, 170, 0, 245)
    main.Active = false
    local pos = UDim2.new(0.5, -97, 0.5, -137)

    if anchorPanel then
        local absPos = anchorPanel.AbsolutePosition
        local absSize = anchorPanel.AbsoluteSize
        pos = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 5)
    end

    main.Position = _G.savedPos or pos
    main.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    main.BackgroundTransparency = 0.15
    main.BorderSizePixel = 0
    main.ZIndex = 2
    main.Parent = screenGui

    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, 0, 1, -40)
    content.Position = UDim2.new(0, 0, 0, 40)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = main
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local expandedSize = main.Size
    local minimizedSize = UDim2.new(0, 170, 0, 40)

    -- Drag support (works on mobile + desktop)
    local dragging = false
    local dragStart, startPos
    local header = nil -- forward declare, set below

    local dragConn = UserInputService.InputChanged:Connect(function(input_obj)
        if not dragging then return end
        if input_obj.UserInputType == Enum.UserInputType.MouseMovement or input_obj.UserInputType == Enum.UserInputType.Touch then
            local delta = input_obj.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    local minimized = false

    -- Animated border stroke
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(140, 82, 255)
    mainStroke.Thickness = 1
    mainStroke.Transparency = 0.3
    mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    mainStroke.Parent = main

    task.spawn(function()
        local t = 0
        while _G.ZenoHubAlive and screenGui.Parent do
            t = t + task.wait(0.03)
            local alpha = (math.sin(t * 1.2) + 1) / 2
            mainStroke.Color = Color3.fromRGB(
                math.floor(120 + alpha * (220 - 120)),
                math.floor(60  + alpha * (80  - 60)),
                math.floor(240 + alpha * (255 - 240))
            )
        end
    end)

    -- Gradient divider line under header
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, 0, 0, 1.5)
    divider.Position = UDim2.new(0, 0, 0, 40)
    divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    divider.BorderSizePixel = 0
    divider.ZIndex = 3
    divider.Parent = main

    local divGrad = Instance.new("UIGradient")
    divGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(100, 40, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 70, 255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 40, 180)),
    })
    divGrad.Parent = divider

    -- Header (draggable)
header = Instance.new("Frame")
    header.Size = UDim2.new(1, 0, 0, 40)
    header.BackgroundTransparency = 1
    header.Active = true
    header.ZIndex = 3
    header.Parent = main

    -- Wire drag to header
    header.InputBegan:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input_obj.Position
            startPos = main.Position
        end
    end)

    local function stopDrag()
        if dragging then
            dragging = false
            _G.savedPos = main.Position
        end
    end
    UserInputService.InputEnded:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            stopDrag()
        end
    end)

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -50, 0, 20)
    titleLabel.Position = UDim2.new(0, 10, 0, 4)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Instant Steal TP"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 13
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.ZIndex = 4
    titleLabel.Parent = header

    local subLabel = Instance.new("TextLabel")
    subLabel.Size = UDim2.new(1, -50, 0, 12)
    subLabel.Position = UDim2.new(0, 10, 0, 24)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = "E/R Teleport Helper"
    subLabel.TextColor3 = Color3.fromRGB(140, 80, 80)
    subLabel.TextSize = 9
    subLabel.Font = Enum.Font.Gotham
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.ZIndex = 4
    subLabel.Parent = header

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 18, 0, 18)
    closeBtn.Position = UDim2.new(1, -24, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 12
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.ZIndex = 6
    closeBtn.Parent = header
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

    closeBtn.MouseEnter:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(210, 50, 50)}):Play()
    end)
    closeBtn.MouseLeave:Connect(function()
        TweenService:Create(closeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(180, 40, 40)}):Play()
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if dragConn then dragConn:Disconnect() end
        screenGui:Destroy()
        -- Also turn off the ZenoHub toggle
        instaGrabEnabled = false
        Toggles["instant_grab_v1"] = false
        Config.toggles["instant_grab_v1"] = false
        pcall(setToggleVisual, "instant_grab_v1", false)
        saveConfig()
    end)

    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
    minimizeBtn.Position = UDim2.new(1, -46, 0, 8)
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    minimizeBtn.Text = "-"
    minimizeBtn.TextColor3 = Color3.fromRGB(255,255,255)
    minimizeBtn.TextSize = 12
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.BorderSizePixel = 0
    minimizeBtn.ZIndex = 6
    minimizeBtn.Parent = header
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(0, 5)

    local minStroke = Instance.new("UIStroke", minimizeBtn)
    minStroke.Color = Color3.fromRGB(140, 82, 255)
    minStroke.Thickness = 1
    minStroke.Transparency = 0.6

    minimizeBtn.MouseEnter:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 58)}):Play()
    end)
    minimizeBtn.MouseLeave:Connect(function()
        TweenService:Create(minimizeBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
    end)

    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            minimizeBtn.Text = "+"
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = minimizedSize
            }):Play()
        else
            minimizeBtn.Text = "-"
            TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                Size = expandedSize
            }):Play()
        end
    end)

    -- Keybind label + button
    local keybindLabel = Instance.new("TextLabel")
    keybindLabel.Size = UDim2.new(1, -16, 0, 11)
    keybindLabel.Position = UDim2.new(0, 8, 0, 3)
    keybindLabel.BackgroundTransparency = 1
    keybindLabel.Text = "Keybind"
    keybindLabel.TextColor3 = Color3.fromRGB(140, 80, 80)
    keybindLabel.TextSize = 9
    keybindLabel.Font = Enum.Font.Gotham
    keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
    keybindLabel.ZIndex = 3
    keybindLabel.Parent = content

    local keybindBtn = Instance.new("TextButton")
    keybindBtn.Size = UDim2.new(1, -16, 0, 20)
    keybindBtn.Position = UDim2.new(0, 8, 0, 12)
    keybindBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    keybindBtn.Text = "[ F ]"
    if Config.sliders and Config.sliders.ist_keybind then
        keybindBtn.Text = "[ " .. Config.sliders.ist_keybind .. " ]"
    end
    keybindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    keybindBtn.TextSize = 11
    keybindBtn.Font = Enum.Font.GothamBold
    keybindBtn.BorderSizePixel = 0
    keybindBtn.ZIndex = 4
    keybindBtn.Parent = content
    Instance.new("UICorner", keybindBtn).CornerRadius = UDim.new(0, 6)

    local kbStroke = Instance.new("UIStroke")
    kbStroke.Color = Color3.fromRGB(140, 82, 255)
    kbStroke.Thickness = 1
    kbStroke.Transparency = 0.5
    kbStroke.Parent = keybindBtn

    keybindBtn.MouseEnter:Connect(function()
        TweenService:Create(keybindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(30, 30, 42)}):Play()
    end)
    keybindBtn.MouseLeave:Connect(function()
        TweenService:Create(keybindBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}):Play()
    end)

    -- Keybind bind logic
    keybindBtn.MouseButton1Click:Connect(function()
        if listening then return end
        listening = true
        keybindBtn.Text = "Press any key..."
        keybindBtn.TextColor3 = Color3.fromRGB(255, 200, 60)
        TweenService:Create(kbStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(170, 70, 255)}):Play()

        local conn
        conn = UserInputService.InputBegan:Connect(function(input_obj, gpe)
            if input_obj.UserInputType ~= Enum.UserInputType.Keyboard then return end
            local ignored = {
                [Enum.KeyCode.Escape]=true,[Enum.KeyCode.LeftShift]=true,
                [Enum.KeyCode.RightShift]=true,[Enum.KeyCode.LeftControl]=true,
                [Enum.KeyCode.RightControl]=true,[Enum.KeyCode.LeftAlt]=true,
                [Enum.KeyCode.RightAlt]=true,[Enum.KeyCode.LeftMeta]=true,
                [Enum.KeyCode.RightMeta]=true,
            }
            if ignored[input_obj.KeyCode] then return end
            conn:Disconnect()
            currentKeybind = input_obj.KeyCode
            keybindBtn.Text = "[ " .. input_obj.KeyCode.Name .. " ]"
            Config.sliders = Config.sliders or {}
            Config.sliders.ist_keybind = input_obj.KeyCode.Name
            saveConfig()
            keybindBtn.TextColor3 = Color3.fromRGB(215, 215, 230)
            TweenService:Create(kbStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(80, 50, 140)}):Play()
            task.wait()
            listening = false
        end)
        table.insert(ISTConnections, conn)
    end)

    -- Teleport Button
    local teleportBtn = Instance.new("TextButton")
    teleportBtn.Size = UDim2.new(1, -16, 0, 22)
    teleportBtn.Position = UDim2.new(0, 8, 0, 36)
    teleportBtn.BackgroundColor3 = Color3.fromRGB(140, 82, 255)
    teleportBtn.Text = "Teleport"
    teleportBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBtn.TextSize = 11
    teleportBtn.Font = Enum.Font.GothamBold
    teleportBtn.BorderSizePixel = 0
    teleportBtn.ZIndex = 4
    teleportBtn.Parent = content
    Instance.new("UICorner", teleportBtn).CornerRadius = UDim.new(0, 6)

    local telStroke = Instance.new("UIStroke", teleportBtn)
    telStroke.Color = Color3.fromRGB(170, 70, 255)
    telStroke.Thickness = 1
    telStroke.Transparency = 0.5

    teleportBtn.MouseEnter:Connect(function()
        TweenService:Create(teleportBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(160, 100, 255)}):Play()
    end)
    teleportBtn.MouseLeave:Connect(function()
        TweenService:Create(teleportBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(140, 82, 255)}):Play()
    end)

    local activateBtn = Instance.new("TextButton")
    activateBtn.Size = UDim2.new(1, -16, 0, 22)
    activateBtn.Position = UDim2.new(0, 8, 0, 61)
    activateBtn.BackgroundColor3 = Color3.fromRGB(140, 82, 255)
    activateBtn.Text = "Activate"
    activateBtn.TextColor3 = Color3.fromRGB(255,255,255)
    activateBtn.TextSize = 11
    activateBtn.Font = Enum.Font.GothamBold
    activateBtn.BorderSizePixel = 0
    activateBtn.ZIndex = 4
    activateBtn.Parent = content
    Instance.new("UICorner", activateBtn).CornerRadius = UDim.new(0, 6)

    local actStroke = Instance.new("UIStroke", activateBtn)
    actStroke.Color = Color3.fromRGB(170, 70, 255)
    actStroke.Thickness = 1
    actStroke.Transparency = 0.5

    activateBtn.MouseEnter:Connect(function()
        TweenService:Create(activateBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(160, 100, 255)}):Play()
    end)
    activateBtn.MouseLeave:Connect(function()
        TweenService:Create(activateBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(140, 82, 255)}):Play()
    end)

    activateBtn.MouseButton1Click:Connect(function()
        local char = LocalPlayer.Character
        if char then char:Destroy() end
        for i = 1, 10 do
            setfflags()
        end
    end)

    -- Toggle row helper
    local function createToggleRow(parent, yPos, labelText, defaultState, configKey)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -16, 0, 28)
        row.Position = UDim2.new(0, 8, 0, yPos)
        row.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
        row.BorderSizePixel = 0
        row.ZIndex = 4
        row.Parent = parent
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local rowStroke = Instance.new("UIStroke")
        rowStroke.Color = Color3.fromRGB(140, 82, 255)
        rowStroke.Thickness = 1
        rowStroke.Transparency = 0.5
        rowStroke.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -48, 1, 0)
        lbl.Position = UDim2.new(0, 8, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.ZIndex = 5
        lbl.Parent = row

        local pillBg = Instance.new("Frame")
        pillBg.Size = UDim2.new(0, 32, 0, 16)
        pillBg.Position = UDim2.new(1, -40, 0.5, -8)
        pillBg.BorderSizePixel = 0
        pillBg.ZIndex = 5
        pillBg.Parent = row
        Instance.new("UICorner", pillBg).CornerRadius = UDim.new(1, 0)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 10, 0, 10)
        knob.Position = UDim2.new(0, 3, 0.5, -5)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.ZIndex = 6
        knob.Parent = pillBg
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

        local state
        if configKey and Config.toggles["ist_" .. configKey] ~= nil then
            state = Config.toggles["ist_" .. configKey]
        else
            state = defaultState or false
        end

        local function applyState(on, animate)
            local targetColor = on and Color3.fromRGB(170, 70, 255) or Color3.fromRGB(35, 30, 48)
            local targetKnobX = on and UDim2.new(0, 19, 0.5, -5) or UDim2.new(0, 3, 0.5, -5)
            if animate then
                TweenService:Create(pillBg, TweenInfo.new(0.18), {BackgroundColor3 = targetColor}):Play()
                TweenService:Create(knob,   TweenInfo.new(0.18), {Position = targetKnobX}):Play()
            else
                pillBg.BackgroundColor3 = targetColor
                knob.Position = targetKnobX
            end
        end

        applyState(state, false)

        local clickBtn = Instance.new("TextButton")
        clickBtn.Size = UDim2.new(1, 0, 1, 0)
        clickBtn.BackgroundTransparency = 1
        clickBtn.Text = ""
        clickBtn.ZIndex = 7
        clickBtn.Parent = row

        clickBtn.MouseButton1Click:Connect(function()
            state = not state
            applyState(state, true)
            if configKey then
                Config.toggles["ist_" .. configKey] = state
                saveConfig()
            end
        end)

        clickBtn.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30, 30, 40)}):Play()
        end)
        clickBtn.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(20, 20, 28)}):Play()
        end)

        return function() return state end
    end

    -- Divider line above toggles
    local divider2 = Instance.new("Frame")
    divider2.Size = UDim2.new(1, -16, 0, 1)
    divider2.Position = UDim2.new(0, 8, 0, 87)
    divider2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    divider2.BorderSizePixel = 0
    divider2.ZIndex = 3
    divider2.Parent = content

    local div2Grad = Instance.new("UIGradient")
    div2Grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0,   Color3.fromRGB(100, 40, 180)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(170, 70, 255)),
        ColorSequenceKeypoint.new(1,   Color3.fromRGB(100, 40, 180)),
    })
    div2Grad.Parent = divider2

    -- "Options" sub-label
    local optLabel = Instance.new("TextLabel")
    optLabel.Size = UDim2.new(1, -16, 0, 11)
    optLabel.Position = UDim2.new(0, 8, 0, 90)
    optLabel.BackgroundTransparency = 1
    optLabel.Text = "Options"
    optLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
    optLabel.TextSize = 10
    optLabel.Font = Enum.Font.GothamBold
    optLabel.TextXAlignment = Enum.TextXAlignment.Left
    optLabel.ZIndex = 3
    optLabel.Parent = content

    -- Toggle rows
    local getPotionSteal = createToggleRow(content, 103, "Potion Steal", false, "potion_steal")
    local getStealSpeed  = createToggleRow(content, 133, "Steal Speed",  false, "steal_speed")

    -- Speed Slider
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, -16, 0, 28)
    sliderFrame.Position = UDim2.new(0, 8, 0, 163)
    sliderFrame.BackgroundTransparency = 1
    sliderFrame.Parent = content

    local sliderLabel = Instance.new("TextLabel")
    sliderLabel.Size = UDim2.new(1, 0, 0, 12)
    sliderLabel.BackgroundTransparency = 1
    sliderLabel.Text = "Speed: 28"
    sliderLabel.TextColor3 = Color3.fromRGB(255,255,255)
    sliderLabel.TextSize = 11
    sliderLabel.Font = Enum.Font.GothamMedium
    sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
    sliderLabel.Parent = sliderFrame

    local sliderBar = Instance.new("Frame")
    sliderBar.Size = UDim2.new(1, 0, 0, 6)
    sliderBar.Position = UDim2.new(0, 0, 0, 18)
    sliderBar.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    sliderBar.BorderSizePixel = 0
    sliderBar.Parent = sliderFrame
    Instance.new("UICorner", sliderBar).CornerRadius = UDim.new(1,0)

    local sliderFill = Instance.new("Frame")
    sliderFill.Size = UDim2.new(0.2, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(140, 82, 255)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBar
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1,0)

    local sliderKnob = Instance.new("Frame")
    sliderKnob.Size = UDim2.new(0, 12, 0, 12)
    sliderKnob.Position = UDim2.new(0.2, -6, 0.5, -6)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    sliderKnob.Parent = sliderBar
    Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1,0)

    local draggingSlider = false
    local minSpeed = 26
    local maxSpeed = 36
    local currentSpeed = (Config.sliders and Config.sliders.ist_speed) or 28

    local function updateSlider(x)
        local percent = math.clamp((x - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        sliderKnob.Position = UDim2.new(percent, -6, 0.5, -6)
        currentSpeed = math.floor(minSpeed + (maxSpeed - minSpeed) * percent)
        sliderLabel.Text = "Speed: " .. currentSpeed
        Config.sliders = Config.sliders or {}
        Config.sliders.ist_speed = currentSpeed
        saveConfig()
    end

    sliderKnob.InputBegan:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input_obj)
        if draggingSlider and (input_obj.UserInputType == Enum.UserInputType.MouseMovement or input_obj.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input_obj.Position.X)
        end
    end)

    sliderBar.InputBegan:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 or input_obj.UserInputType == Enum.UserInputType.Touch then
            updateSlider(input_obj.Position.X)
        end
    end)

    -- Restore saved slider
    if currentSpeed ~= 28 then
        task.defer(function()
            local percent = math.clamp((currentSpeed - minSpeed) / (maxSpeed - minSpeed), 0, 1)
            sliderFill.Size = UDim2.new(percent, 0, 1, 0)
            sliderKnob.Position = UDim2.new(percent, -6, 0.5, -6)
            sliderLabel.Text = "Speed: " .. currentSpeed
        end)
    end

    -- Internal services
    local _RunService = game:GetService("RunService")
    local _ReplicatedStorage = game:GetService("ReplicatedStorage")
    local _HttpService = game:GetService("HttpService")
    local Speed = false

    local PlotController = require(game.ReplicatedStorage.Controllers.PlotController)
    local MyPlot = PlotController:GetMyPlot().PlotModel

    -- FFlags
    local fflags = {
        GameNetPVHeaderRotationalVelocityZeroCutoffExponent = -5000,
        LargeReplicatorWrite5 = true,
        LargeReplicatorEnabled9 = true,
        AngularVelociryLimit = 360,
        TimestepArbiterVelocityCriteriaThresholdTwoDt = 2147483646,
        S2PhysicsSenderRate = 15000,
        DisableDPIScale = true,
        MaxDataPacketPerSend = 2147483647,
        PhysicsSenderMaxBandwidthBps = 20000,
        TimestepArbiterHumanoidLinearVelThreshold = 21,
        MaxMissedWorldStepsRemembered = -2147483648,
        PlayerHumanoidPropertyUpdateRestrict = true,
        SimDefaultHumanoidTimestepMultiplier = 0,
        StreamJobNOUVolumeLengthCap = 2147483647,
        DebugSendDistInSteps = -2147483648,
        GameNetDontSendRedundantNumTimes = 1,
        CheckPVLinearVelocityIntegrateVsDeltaPositionThresholdPercent = 1,
        CheckPVDifferencesForInterpolationMinVelThresholdStudsPerSecHundredth = 1,
        LargeReplicatorSerializeRead3 = true,
        ReplicationFocusNouExtentsSizeCutoffForPauseStuds = 2147483647,
        CheckPVCachedVelThresholdPercent = 10,
        CheckPVDifferencesForInterpolationMinRotVelThresholdRadsPerSecHundredth = 1,
        GameNetDontSendRedundantDeltaPositionMillionth = 1,
        InterpolationFrameVelocityThresholdMillionth = 5,
        StreamJobNOUVolumeCap = 2147483647,
        InterpolationFrameRotVelocityThresholdMillionth = 5,
        CheckPVCachedRotVelThresholdPercent = 10,
        WorldStepMax = 30,
        InterpolationFramePositionThresholdMillionth = 5,
        TimestepArbiterHumanoidTurningVelThreshold = 1,
        SimOwnedNOUCountThresholdMillionth = 2147483647,
        GameNetPVHeaderLinearVelocityZeroCutoffExponent = -5000,
        NextGenReplicatorEnabledWrite4 = true,
        TimestepArbiterOmegaThou = 1073741823,
        MaxAcceptableUpdateDelay = 1,
        LargeReplicatorSerializeWrite4 = true
    }

    local function setfflags()
        for k, v in pairs(fflags) do
            pcall(function()
                setfflag(k, tostring(v))
            end)
        end
    end

    local _delayTime = 0.12
local _debounce = false


    local function runStealLogic()
        local _a = 0.2
        local b=0.01
        local function g() return player.Character or player.CharacterAdded:Wait() end
        local function h()
            local i=g()
            return i:WaitForChild("HumanoidRootPart",5)
        end
        local j=h()
        local _k = g():WaitForChild("Humanoid")

        local function m(n)
            local o=n.Parent
            if o:IsA("BasePart") then return o end
            if o:IsA("Model") then
                return o.PrimaryPart or o:FindFirstChildWhichIsA("BasePart")
            end
            if o:IsA("Attachment") then return o.Parent end
            return o:FindFirstChildWhichIsA("BasePart",true)
        end

        local function p()
            local q=nil
            local r=math.huge
            local s=workspace:FindFirstChild("Plots")
            if not s then return nil end
            for _,t in pairs(s:GetDescendants()) do
                if t:IsA("ProximityPrompt") and t.Enabled and t.ActionText=="Steal" then
                    local u=m(t)
                    if u then
                        local v=(j.Position-u.Position).Magnitude
                        if v<r then
                            r=v
                            q=t
                        end
                    end
                end
            end
            return q
        end

        local function w(x)
            if not x or not x:IsDescendantOf(workspace) then return end
            local originalDist = x.MaxActivationDistance
            local originalLOS = x.RequiresLineOfSight
            local originalClickable = x.ClickablePrompt
            
            x.MaxActivationDistance = 9999
            x.RequiresLineOfSight = false
            x.ClickablePrompt = true
            
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local originalCFrame = hrp and hrp.CFrame
            local promptPart = x.Parent
            
            if hrp and promptPart and promptPart:IsA("BasePart") then
                hrp.CFrame = CFrame.new(promptPart.Position)
            end
            
            local y = pcall(function()
                fireproximityprompt(x)
            end)
            if not y then
                pcall(function()
                    x:InputHoldBegin()
                    task.wait(b)
                    x:InputHoldEnd()
                end)
            end
            
            if hrp and originalCFrame then
                hrp.CFrame = originalCFrame
            end
            x.MaxActivationDistance = originalDist
            x.RequiresLineOfSight = originalLOS
            x.ClickablePrompt = originalClickable
        end

        local z=p()
        if z then w(z) end
    end

    local Potion = false

    -- Speed heartbeat
    local S = {
        RunService = game:GetService("RunService"),
        UIS = game:GetService("UserInputService")
    }

    table.insert(ISTConnections,
        S.RunService.Heartbeat:Connect(function()
            if not Speed then return end
            local char = player.Character
            if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not humanoid or not hrp then return end
            local moveDir = humanoid.MoveDirection
            if moveDir.Magnitude > 0 then
                hrp.AssemblyLinearVelocity = Vector3.new(
                    moveDir.X * currentSpeed,
                    hrp.AssemblyLinearVelocity.Y,
                    moveDir.Z * currentSpeed
                )
            end
        end)
    )

    -- Grapple Hook speed system (replaces carpet to avoid anti-cheat)
    local GrappleSystem = {
        Enabled = false,
        Connections = {},
        LastActivation = 0,
        Cooldown = 0.1
    }

    function GrappleSystem:equipGrapple()
        local char = player.Character
        if not char then return nil end
        local backpack = player:FindFirstChild("Backpack")
        if not backpack then return nil end
        local grappleHook = backpack:FindFirstChild("Grapple Hook") or char:FindFirstChild("Grapple Hook")
        if not grappleHook then
            for _, item in ipairs(backpack:GetDescendants()) do
                if item.Name == "Grapple Hook" and item:IsA("Tool") then
                    grappleHook = item
                    break
                end
            end
            if not grappleHook then return nil end
        end
        if grappleHook.Parent == backpack then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(grappleHook) end
        end
        return grappleHook
    end

    function GrappleSystem:activateGrapple()
        if not self.Enabled then return end
        if tick() - self.LastActivation < self.Cooldown then return end
        local REUseItem = game:GetService("ReplicatedStorage"):FindFirstChild("Packages")
        if REUseItem then
            REUseItem = REUseItem:FindFirstChild("Net")
            if REUseItem then
                REUseItem = REUseItem:FindFirstChild("RE/UseItem")
                if REUseItem then
                    pcall(function()
                        REUseItem:FireServer(0.23450689315795897)
                        self.LastActivation = tick()
                    end)
                    return
                end
            end
        end
        local char = player.Character
        if not char then return end
        local grappleHook = char:FindFirstChild("Grapple Hook")
        if grappleHook and grappleHook:IsA("Tool") then
            pcall(function()
                grappleHook:Activate()
                task.wait(0.05)
                grappleHook:Deactivate()
                self.LastActivation = tick()
            end)
        end
    end

    function GrappleSystem:start()
        self.Enabled = true
        self.Connections.equip = RunService.Heartbeat:Connect(function()
            self:equipGrapple()
        end)
        self.Connections.activate = RunService.Heartbeat:Connect(function()
            self:activateGrapple()
        end)
    end

    function GrappleSystem:stop()
        self.Enabled = false
        for _, conn in pairs(self.Connections) do
            if conn then pcall(function() conn:Disconnect() end) end
        end
        self.Connections = {}
    end

    local function equipGrappleForTP()
        local char = player.Character
        local backpack = player:FindFirstChild("Backpack")
        if not char or not backpack then return end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                tool.Parent = backpack
            end
        end
        local carpet = backpack:FindFirstChild("Flying Carpet")
        if carpet then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:EquipTool(carpet) end
        end
    end

    local function Teleport()
    local _debounce = false
        -- Disable Auto Giant Potion only
        _AutoGiantPotion = false
        Toggles["auto_giant_potion"] = false
        Config.toggles["auto_giant_potion"] = false
        pcall(setToggleVisual, "auto_giant_potion", false)
        saveConfig()

        -- Disable Auto Grabber only
        autoGrabberEnabled = false
        Toggles["auto_grabber"] = false
        Config.toggles["auto_grabber"] = false
        pcall(setToggleVisual, "auto_grabber", false)
        saveConfig()

        for i = 1, 10 do
            setfflags()
            task.delay(1, function()
                _AutoGiantPotion = true
                Toggles["auto_giant_potion"] = true
                Config.toggles["auto_giant_potion"] = true
                pcall(setToggleVisual, "auto_giant_potion", true)

                autoGrabberEnabled = true
                Toggles["auto_grabber"] = true
                Config.toggles["auto_grabber"] = true
                pcall(setToggleVisual, "auto_grabber", true)

                saveConfig()
            end)
        end

        -- Set potion/speed from toggles
        if getPotionSteal() then
            Potion = true
        else
            Potion = false
        end

        Speed = getStealSpeed()

        if MyPlot:GetAttribute("Order") == 2 then
            _debounce = true
            equipGrappleForTP()
            Players.LocalPlayer.Character.HumanoidRootPart.CFrame = MyPlot.Spawn.CFrame
            task.wait(0.11)
            teleportHRP(Vector3.new(-368.18, -6.97, 69.17))
            task.wait(0.11)
            teleportHRP(Vector3.new(-335.650, -5.103, 100.070))
            task.wait(0.11)
            teleportHRP(Vector3.new(-351.980, -7.002, 75.540))
            if Potion == true then
                if Players.LocalPlayer.Backpack:FindFirstChild("Giant Potion") then
                    local potion = Players.LocalPlayer.Backpack:FindFirstChild("Giant Potion")
                    potion.Parent = Players.LocalPlayer.Character
                    potion:Activate()
                end
            end
            local bp = Players.LocalPlayer.Backpack
            local potionItem = bp:FindFirstChild("Giant Potion")
            if potionItem then
                potionItem.Parent = Players.LocalPlayer.Character
                potionItem:Activate()
            end
            runStealLogic()
            _debounce = false
        elseif MyPlot:GetAttribute("Order") == 1 then
            _debounce = true
            equipGrappleForTP()
            Players.LocalPlayer.Character.HumanoidRootPart.CFrame = MyPlot.Spawn.CFrame
            task.wait(0.11)
            teleportHRP(Vector3.new(-368.18, -7.02, 42.17))
            task.wait(0.11)
            teleportHRP(Vector3.new(-336.110, -5.037, 19.840))
            task.wait(0.11)
            teleportHRP(Vector3.new(-352.860, -7.002, 44.180))
            if Potion == true then
                if Players.LocalPlayer.Backpack:FindFirstChild("Giant Potion") then
                    local potion = Players.LocalPlayer.Backpack:FindFirstChild("Giant Potion")
                    potion.Parent = Players.LocalPlayer.Character
                    potion:Activate()
                end
            end
            runStealLogic()
            _debounce = false
        end
    end

    -- Teleport logic
    local function doTeleport()
        if teleporting or teleportDebounce then return end
        teleporting = true
        teleportDebounce = true
        local character = player.Character or player.CharacterAdded:Wait()
        local root = character:WaitForChild("HumanoidRootPart", 2)
        if not root then
            teleporting = false
            teleportDebounce = false
            return
        end
        task.spawn(function()
            task.wait(0.75)
            Teleport()
            task.wait(1.2)
            teleporting = false
            task.wait(0.5)
            teleportDebounce = false
        end)
    end

    table.insert(ISTConnections,
        teleportBtn.MouseButton1Click:Connect(doTeleport)
    )

    table.insert(ISTConnections,
        UserInputService.InputBegan:Connect(function(input_obj, gpe)
            if gpe or listening then return end
            if input_obj.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if input_obj.KeyCode == currentKeybind then
                doTeleport()
            end
        end)
    )

    -- Dragging
local teleportDragging, teleportDragStart, teleportStartPos = false, nil, nil

    header.InputBegan:Connect(function(input_obj)
if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
teleportDragging = true
teleportDragStart = input_obj.Position
teleportStartPos = main.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input_obj)
if teleportDragging and input_obj.UserInputType == Enum.UserInputType.MouseMovement then
local d = input_obj.Position - teleportDragStart
main.Position = UDim2.new(teleportStartPos.X.Scale, teleportStartPos.X.Offset + d.X, teleportStartPos.Y.Scale, teleportStartPos.Y.Offset + d.Y)
        end
    end)

    UserInputService.InputEnded:Connect(function(input_obj)
if input_obj.UserInputType == Enum.UserInputType.MouseButton1 and teleportDragging then
teleportDragging = false
            saveUIPosition(main)
        end
    end)

    return screenGui
end
-- END INSTANT STEAL TP GUI

local function toggleFeature(id)
    Toggles[id] = not Toggles[id]
    Config.toggles[id] = Toggles[id]
    saveConfig()
    
    setToggleVisual(id, Toggles[id])
    showMiniPanel(id, Toggles[id])

    local handler = ToggleHandlers[id]
    if handler then
        handler(Toggles[id])
    end
end

local function updateBindLabel(id)
    local el = ToggleElements[id]
    if not el or not el.bindLabel then return end

    if ListeningId == id then
        el.bindLabel.Text = "(...)"
        el.bindLabel.TextColor3 = COLORS.BindText
        el.bindLabel.Visible = true
    elseif Keybinds[id] then
        el.bindLabel.Text = "(" .. getKeyName(Keybinds[id]) .. ")"
        el.bindLabel.TextColor3 = COLORS.BindText
        el.bindLabel.Visible = true
    else
        el.bindLabel.Text = ""
        el.bindLabel.Visible = false
    end
end

-- =============================================
-- createMainToggle (preserved, not called currently)
-- =============================================

local function _createMainToggle(parent, item)
    local id = item.id
    local label = item.label
    local isOn = Config.toggles[id] or false

    local row = createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
    }, parent)

    local _text = createInstance("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        TextColor3 = COLORS.Text,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local switch = createInstance("Frame", {
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = COLORS.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    addCorner(switch, 9)

    local knob = createInstance("Frame", {
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = COLORS.KnobOff,
        BorderSizePixel = 0,
    }, switch)
    addCorner(knob, 7)

    -- APPLY SAVED STATE
    if isOn then
        switch.BackgroundColor3 = COLORS.ToggleOn
        knob.Position = UDim2.new(1, -16, 0.5, -7)
    end

    local btn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
    }, switch)

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        Config.toggles[id] = isOn

        local panel = MiniPanels[id]
        if panel then
            panel.Visible = isOn
        end

        saveConfig()

        -- visuals
        if isOn then
            switch.BackgroundColor3 = COLORS.ToggleOn
            knob.Position = UDim2.new(1, -16, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOn
        else
            switch.BackgroundColor3 = COLORS.ToggleOff
            knob.Position = UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOff
        end
    end)

    return row
end
do -- Credits UI scope

-- =============================================
-- CREDITS / HEADER UI
-- =============================================

local creditsFrame = Instance.new("Frame")
creditsFrame.Size = UDim2.new(0, 340, 0, 110)
creditsFrame.Position = UDim2.new(0.5, 0, 0, isMobile and 5 or 50)
creditsFrame.Size = UDim2.new(0, isMobile and 280 or 340, 0, isMobile and 80 or 110)
creditsFrame.AnchorPoint = Vector2.new(0.5, 0)
creditsFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
creditsFrame.BackgroundTransparency = 0.15
creditsFrame.BorderSizePixel = 0
creditsFrame.Parent = ScreenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 2)
layout.Parent = creditsFrame

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = creditsFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(140, 82, 255)
stroke.Thickness = 1
stroke.Transparency = 0.3
stroke.Parent = creditsFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 28)
title.Position = UDim2.new(0, 0, 0, 4)
title.BackgroundTransparency = 1
title.Text = "DEX HUB V1.2"
title.Font = Enum.Font.GothamBold
title.TextSize = isMobile and 13 or 16
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.TextStrokeTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Center
title.Parent = creditsFrame

local credits = Instance.new("TextLabel")
credits.Size = UDim2.new(1, 0, 0, 18)
credits.Position = UDim2.new(0, 0, 0, 30)
credits.BackgroundTransparency = 1
credits.Text = "Brainrot10071985 | mohamed79109 | randomguy12v"
credits.Font = Enum.Font.GothamMedium
credits.TextSize = isMobile and 9 or 12
credits.TextColor3 = Color3.fromRGB(180, 180, 200)
credits.TextStrokeTransparency = 1
credits.TextXAlignment = Enum.TextXAlignment.Center
credits.Parent = creditsFrame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 18)
subtitle.Position = UDim2.new(0, 0, 0, 48)
subtitle.BackgroundTransparency = 1
subtitle.Text = "dsc.gg/x8AYUCUu"
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextSize = 13
subtitle.TextColor3 = Color3.fromRGB(140, 82, 255)
subtitle.TextStrokeTransparency = 1
subtitle.TextXAlignment = Enum.TextXAlignment.Center
subtitle.Parent = creditsFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, 0, 0, 20)
statsLabel.Position = UDim2.new(0, 0, 0, 70)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "FPS: 0 | Ping: ..."
statsLabel.Font = Enum.Font.GothamBlack
statsLabel.TextSize = 14
statsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statsLabel.TextXAlignment = Enum.TextXAlignment.Center
statsLabel.Parent = creditsFrame

-- FPS Counter
local lastTime = tick()
local frames = 0
local currentFPS = 0

RunService.RenderStepped:Connect(function()
    frames = frames + 1
    if tick() - lastTime >= 1 then
        currentFPS = frames
        frames = 0
        lastTime = tick()
    end
end)

-- Ping Detection
local function getPing()
    local ping = nil

    pcall(function()
        local network = Stats:FindFirstChild("Network")
        if network then
            local serverStats = network:FindFirstChild("ServerStatsItem")
            if serverStats then
                local dataPing = serverStats:FindFirstChild("Data Ping")
                if dataPing then
                    ping = math.floor(dataPing:GetValue())
                end
            end
        end
    end)

    if not ping then
        pcall(function()
            local perf = Stats:FindFirstChild("PerformanceStats")
            if perf then
                for _, v in ipairs(perf:GetChildren()) do
                    if string.find(v.Name:lower(), "ping") then
                        ping = tonumber(v:GetValueString():match("%d+"))
                        break
                    end
                end
            end
        end)
    end

    return ping
end

task.spawn(function()
    while _G.ZenoHubAlive do
        local ping = getPing()

        if ping then
            pcall(function() statsLabel.Text = "FPS: " .. currentFPS .. " | Ping: " .. ping end)
        else
            pcall(function() statsLabel.Text = "FPS: " .. currentFPS .. " | Ping: ..." end)
        end

        task.wait(0.2)
    end
end)
end -- Credits UI scope


-- =============================================
-- MAIN FRAME
-- =============================================

MainFrame = createInstance("Frame", {
    Name = "MainFrame",
    Size = UDim2.new(0, isMobile and 420 or 380, 0, isMobile and 520 or 480),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = COLORS.Panel,
    BackgroundTransparency = 0.02,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    Draggable = true,
}, ScreenGui)
addCorner(MainFrame, 12)
addStroke(MainFrame, COLORS.Border, 1.5)

-- Restore saved main panel position
if Config.panels and Config.panels["MainFrame"] then
    MainFrame.Position = UDim2.new(
        Config.panels["MainFrame"].xScale,
        Config.panels["MainFrame"].xOffset,
        Config.panels["MainFrame"].yScale,
        Config.panels["MainFrame"].yOffset
    )
    MainFrame.AnchorPoint = Vector2.new(0, 0)
end

-- Save main panel position on drag
MainFrame:GetPropertyChangedSignal("Position"):Connect(function()
    Config.panels = Config.panels or {}
    Config.panels["MainFrame"] = {
        xScale = MainFrame.Position.X.Scale,
        xOffset = MainFrame.Position.X.Offset,
        yScale = MainFrame.Position.Y.Scale,
        yOffset = MainFrame.Position.Y.Offset,
    }
    saveConfig()
end)

uiScale = Instance.new("UIScale")
uiScale.Scale = getScaleFactor()
uiScale.Parent = MainFrame

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if not UI_OPEN then return end
    uiScale.Scale = getScaleFactor()
    MainFrame.Size = UDim2.new(0, isMobile and 420 or 380, 0, 0)
MainFrame.BackgroundTransparency = 1
tween(MainFrame, { Size = UDim2.new(0, isMobile and 420 or 380, 0, isMobile and 520 or 480), BackgroundTransparency = 0.02 }, 0.35)
end)

local _Glow = createInstance("ImageLabel", {
    Name = "Glow",
    Size = UDim2.new(1, 60, 1, 60),
    Position = UDim2.new(0, -30, 0, -30),
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageColor3 = COLORS.Accent,
    ImageTransparency = 0.92,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(24, 24, 276, 276),
    ZIndex = 0,
}, MainFrame)

local Header = createInstance("Frame", {
    Name = "Header",
    Size = UDim2.new(1, 0, 0, 46),
    BackgroundTransparency = 1,
}, MainFrame)

local _Title = createInstance("TextLabel", {
    Name = "Title",
    Size = UDim2.new(1, -24, 1, 0),
    Position = UDim2.new(0, 16, 0, 0),
    BackgroundTransparency = 1,
    Text = "Dex Hub v1.2",
    Font = Enum.Font.GothamBold,
    TextColor3 = COLORS.Text,
    TextSize = 18,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Header)

local TabBar = createInstance("Frame", {
    Name = "TabBar",
    Size = UDim2.new(1, -4, 0, isMobile and 38 or 34),
    Position = UDim2.new(0, 12, 0, 46),
    BackgroundTransparency = 1,
}, MainFrame)

local _TabLayout = createInstance("UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    Padding = UDim.new(0, 8),
    SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Left,
}, TabBar)

local ContentArea = createInstance("ScrollingFrame", {
    Name = "ContentArea",
    Size = UDim2.new(1, -8, 1, -92),
    Position = UDim2.new(0, 4, 0, 88),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = COLORS.Accent,
    ScrollBarImageTransparency = 0.5,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
}, MainFrame)




-- =============================================
-- MINI PANEL BUILDER
-- =============================================

local function createMiniPanel(name, position, size)
    local panel = createInstance("Frame", {
        Name = "Mini_" .. name,
        Size = UDim2.new(0, isMobile and 280 or 260, 0, 0),
        Position = position,
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.Panel,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
        Draggable = true,
        ClipsDescendants = true,
    }, ScreenGui)

    addCorner(panel, 12)
    addStroke(panel, COLORS.Border, 1.5)

    local titleBar = createInstance("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = COLORS.MiniTitle,
        BorderSizePixel = 0,
    }, panel)

    addCorner(titleBar, 12)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = name,
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, titleBar)

    local minimizeBtn = createInstance("TextButton", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -30, 0.5, -11),
        BackgroundTransparency = 1,
        Text = "â€”",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.AccentBright,
        TextSize = 14,
    }, titleBar)

    local content = createInstance("Frame", {
        Name = "Content",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 30),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, panel)

    addPadding(content, 6, 10, 10, 10)

    createInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 5),
    }, content)

    local minimized = false

    minimizeBtn.MouseButton1Click:Connect(function()
        minimized = not minimized

        if minimized then
            tween(content, {
                Position = UDim2.new(0, 0, 0, -content.AbsoluteSize.Y)
            }, 0.25)

            for _, child in ipairs(content:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    tween(child, { TextTransparency = 1 }, 0.2)
                end
            end

            task.delay(0.25, function()
                content.Visible = false
                tween(panel, {
                    Size = UDim2.new(0, panel.Size.X.Offset, 0, 30)
                }, 0.2)
            end)

        else
            tween(panel, {
                Size = UDim2.new(0, panel.Size.X.Offset, 0, 0)
            }, 0.2)

            content.Visible = true

            content.Position = UDim2.new(0, 0, 0, -content.AbsoluteSize.Y)

            tween(content, {
                Position = UDim2.new(0, 0, 0, 30)
            }, 0.25)

            for _, child in ipairs(content:GetDescendants()) do
                if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("TextBox") then
                    child.TextTransparency = 1
                    tween(child, { TextTransparency = 0 }, 0.25)
                end
            end
        end
    end)

    if Config.panels[name] then
        panel.Position = UDim2.new(
            Config.panels[name].xScale,
            Config.panels[name].xOffset,
            Config.panels[name].yScale,
            Config.panels[name].yOffset
        )
        panel.Visible = Config.panels[name].visible
    end

    panel:GetPropertyChangedSignal("Position"):Connect(function()
        Config.panels[name] = {
            xScale = panel.Position.X.Scale,
            xOffset = panel.Position.X.Offset,
            yScale = panel.Position.Y.Scale,
            yOffset = panel.Position.Y.Offset,
            visible = panel.Visible
        }
        saveConfig()
    end)

    panel:GetPropertyChangedSignal("Visible"):Connect(function()
        Config.panels[name] = Config.panels[name] or {}
        Config.panels[name].visible = panel.Visible
        saveConfig()
    end)

    return panel, content
end

local function createMiniToggle(parent, label, order, onToggle, bindId)
    local row = createInstance("Frame", {
        Name = "Row_" .. label,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = COLORS.SectionBG,
        BackgroundTransparency = 0.4,
        BorderSizePixel = 0,
        LayoutOrder = order or 0,
    }, parent)
    addCorner(row, 6)
    
    createInstance("UIStroke", {
        Color = COLORS.Border,
        Thickness = 1,
        Transparency = 0.85,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, row)

    local lbl = createInstance("TextButton", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, row)

    local switch = createInstance("Frame", {
        Name = "Switch",
        Size = UDim2.new(0, 32, 0, 16),
        Position = UDim2.new(1, -42, 0.5, -8),
        BackgroundColor3 = COLORS.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    addCorner(switch, 8)
    
    createInstance("UIStroke", {
        Color = COLORS.Border,
        Thickness = 1,
        Transparency = 0.5,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, switch)

    local knob = createInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0, 3, 0.5, -5),
        BackgroundColor3 = COLORS.KnobOff,
        BorderSizePixel = 0,
    }, switch)
    addCorner(knob, 5)

    local isOn = Config.toggles[label] or false

    local function applyState(state, animate)
        local targetColor = state and COLORS.ToggleOn or COLORS.ToggleOff
        local targetKnobX = state and UDim2.new(0, 19, 0.5, -5) or UDim2.new(0, 3, 0.5, -5)
        local targetKnobColor = state and COLORS.KnobOn or COLORS.KnobOff
        
        if animate then
            TweenService:Create(switch, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetKnobX, BackgroundColor3 = targetKnobColor}):Play()
        else
            switch.BackgroundColor3 = targetColor
            knob.Position = targetKnobX
            knob.BackgroundColor3 = targetKnobColor
        end
    end

    applyState(isOn, false)

    lbl.MouseEnter:Connect(function()
        tween(row, { BackgroundColor3 = Color3.fromRGB(24, 24, 32), BackgroundTransparency = 0.2 }, 0.15)
    end)
    lbl.MouseLeave:Connect(function()
        tween(row, { BackgroundColor3 = COLORS.SectionBG, BackgroundTransparency = 0.4 }, 0.15)
    end)

    -- Auto-restore: fire callback if saved state was ON
    if isOn and onToggle then
        task.defer(function()
            onToggle(true)
        end)
    end

    local btn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, switch)

    btn.MouseButton1Click:Connect(function()
        isOn = not isOn
        Config.toggles[label] = isOn
        saveConfig()

        if isOn then
            switch.BackgroundColor3 = COLORS.ToggleOn
            knob.Position = UDim2.new(1, -16, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOn
        else
            switch.BackgroundColor3 = COLORS.ToggleOff
            knob.Position = UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOff
        end
        if onToggle then
            onToggle(isOn)
        end
    end)

    -- Keybind support
    if bindId then
        local bindLabel = createInstance("TextLabel", {
            Name = "BindLabel",
            Size = UDim2.new(0, 40, 1, 0),
            Position = UDim2.new(1, -90, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.BindText,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
        }, row)

        ToggleElements[bindId] = { bindLabel = bindLabel }

        ActionCallbacks[bindId] = function()
            isOn = not isOn
            Config.toggles[label] = isOn
            saveConfig()
            if isOn then
                switch.BackgroundColor3 = COLORS.ToggleOn
                knob.Position = UDim2.new(1, -16, 0.5, -7)
                knob.BackgroundColor3 = COLORS.KnobOn
            else
                switch.BackgroundColor3 = COLORS.ToggleOff
                knob.Position = UDim2.new(0, 2, 0.5, -7)
                knob.BackgroundColor3 = COLORS.KnobOff
            end
            if onToggle then onToggle(isOn) end
        end

        lbl.MouseButton2Click:Connect(function()
            if ListeningId == bindId then
                ListeningId = nil
                updateBindLabel(bindId)
                return
            end
            local prev = ListeningId
            ListeningId = bindId
            if prev then updateBindLabel(prev) end
            updateBindLabel(bindId)
        end)

        if Config.keybinds[bindId] then
            local ok, key = pcall(function() return Enum.KeyCode[Config.keybinds[bindId]] end)
            if ok and key then
                Keybinds[bindId] = key
                updateBindLabel(bindId)
            end
        end
    end

    return row, function() return isOn end
end

local function createMiniButton(parent, label, order, bindId)
    local btn = createInstance("TextButton", {
        Name = "Btn_" .. label,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = COLORS.ButtonBG,
        BorderSizePixel = 0,
        Text = label,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 11,
        AutoButtonColor = false,
        LayoutOrder = order or 0,
    }, parent)
    addCorner(btn, 6)
    
    local btnStroke = createInstance("UIStroke", {
        Color = COLORS.Border,
        Thickness = 1,
        Transparency = 0.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, btn)

    btn.MouseEnter:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.ButtonHover }, 0.15)
        tween(btnStroke, { Color = COLORS.AccentBright }, 0.15)
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.ButtonBG }, 0.15)
        tween(btnStroke, { Color = COLORS.Border }, 0.15)
    end)
    btn.MouseButton1Click:Connect(function()
        tween(btn, { BackgroundColor3 = COLORS.Accent }, 0.08)
        task.delay(0.12, function()
            tween(btn, { BackgroundColor3 = COLORS.ButtonBG }, 0.15)
        end)
    end)

    -- Keybind support
    if bindId then
        local bindLabel = createInstance("TextLabel", {
            Name = "BindLabel",
            Size = UDim2.new(0, 40, 0, 30),
            Position = UDim2.new(1, -45, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.BindText,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
        }, btn)

        ToggleElements[bindId] = { bindLabel = bindLabel }

        btn.MouseButton2Click:Connect(function()
            if ListeningId == bindId then
                ListeningId = nil
                updateBindLabel(bindId)
                return
            end
            local prev = ListeningId
            ListeningId = bindId
            if prev then updateBindLabel(prev) end
            updateBindLabel(bindId)
        end)

        if Config.keybinds[bindId] then
            local ok, key = pcall(function() return Enum.KeyCode[Config.keybinds[bindId]] end)
            if ok and key then
                Keybinds[bindId] = key
                updateBindLabel(bindId)
            end
        end
    end

    return btn
end

local function createMiniSlider(parent, label, min, max, default, order, onChanged)
local setValue = nil
local currentValue = nil
    local container = createInstance("Frame", {
        Name = "Slider_" .. label,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = order or 0,
    }, parent)

    local _lbl = createInstance("TextLabel", {
        Size = UDim2.new(0.55, 0, 0, 16),
        Position = UDim2.new(0, 4, 0, 0),
        BackgroundTransparency = 1,
        Text = label,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, container)

    local valueBox = createInstance("TextBox", {
        Name = "Value",
        Size = UDim2.new(0.3, 0, 0, 16),
        Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 40),
        BackgroundTransparency = 0.3,
        Text = tostring(Config.sliders[label] or default),
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.AccentBright,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        ClearTextOnFocus = true,
    }, container)
    addCorner(valueBox, 4)
    createInstance("UIStroke", {
        Color = COLORS.Border,
        Thickness = 1,
        Transparency = 0.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    }, valueBox)
    local valueLabel = valueBox

    valueBox.FocusLost:Connect(function(enterPressed)
        local typed = tonumber(valueBox.Text)
        if typed then
            typed = math.clamp(math.floor(typed), min, max)
            setValue(typed)
        else
            valueBox.Text = tostring(currentValue)
        end
    end)

    -- Load saved value BEFORE creating visual elements so fill/knob match
currentValue = Config.sliders[label] or default
    local dragging = false

    local track = createInstance("Frame", {
        Name = "Track",
        Size = UDim2.new(1, -8, 0, 6),
        Position = UDim2.new(0, 4, 0, 24),
        BackgroundColor3 = COLORS.SliderTrack,
        BorderSizePixel = 0,
    }, container)
    addCorner(track, 3)

    local pct = (currentValue - min) / (max - min)
    local fill = createInstance("Frame", {
        Name = "Fill",
        Size = UDim2.new(pct, 0, 1, 0),
        BackgroundColor3 = COLORS.SliderFill,
        BorderSizePixel = 0,
    }, track)
    addCorner(fill, 3)

    local sliderKnob = createInstance("Frame", {
        Name = "SliderKnob",
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new(pct, -6, 0.5, -6),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 3,
    }, track)
    addCorner(sliderKnob, 6)
    addStroke(sliderKnob, COLORS.AccentBright, 1.5)

    setValue = function(v)
        currentValue = math.clamp(v, min, max)

        Config.sliders[label] = currentValue
        saveConfig()

        local rel = (currentValue - min) / (max - min)

        valueLabel.Text = tostring(currentValue)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        sliderKnob.Position = UDim2.new(rel, -7, 0.5, -7)
        if onChanged then
            onChanged(currentValue)
        end
    end

    local dragBtn = createInstance("TextButton", {
        Size = UDim2.new(1, 10, 1, 10),
        Position = UDim2.new(0, -5, 0, -5),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, track)

    dragBtn.MouseButton1Down:Connect(function()
        dragging = true
    end)
    dragBtn.InputBegan:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.Touch then
            dragging = true
        end
    end)
    dragBtn.InputEnded:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            Config.sliders[label] = currentValue
            saveConfig()
            if onChanged then onChanged(currentValue) end
        end
    end)

    UIS.InputEnded:Connect(function(input_obj)
        if input_obj.UserInputType == Enum.UserInputType.MouseButton1 then
            if dragging then
                dragging = false
                -- Save final value to Config
                Config.sliders[label] = currentValue
                saveConfig()
                if onChanged then
                    onChanged(currentValue)
                end
            end
        end
    end)

        UIS.InputChanged:Connect(function(input_obj)
        if not dragging then return end
        if input_obj.UserInputType == Enum.UserInputType.MouseMovement or
           input_obj.UserInputType == Enum.UserInputType.Touch then
            local mx = input_obj.Position.X
            local absPos = track.AbsolutePosition.X
            local absSize = track.AbsoluteSize.X
            local rel = math.clamp((mx - absPos) / absSize, 0, 1)
            currentValue = math.floor(min + (max - min) * rel)
            if not valueBox:IsFocused() then
                valueBox.Text = tostring(currentValue)
            end
            fill.Size = UDim2.new(rel, 0, 1, 0)
            sliderKnob.Position = UDim2.new(rel, -7, 0.5, -7)
        end
    end)  -- â† This was missing!

    -- Initialize with saved/default value
    setValue(currentValue)

    return {
        Container = container,
        Track = track,
        Fill = fill,
        SliderKnob = sliderKnob,
        Value = valueLabel,
        Get = function() return currentValue end,
        Set = setValue
    }
end  -- â† Keep this one only

local function createCommandRow(parent, cmdName, order)
    local row = createInstance("Frame", {
        Name = "Cmd_" .. cmdName,
        Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = COLORS.SectionBG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        LayoutOrder = order or 0,
    }, parent)
    addCorner(row, 5)

    local _lbl = createInstance("TextLabel", {
        Size = UDim2.new(0.6, 0, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = cmdName,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local status = createInstance("TextLabel", {
        Size = UDim2.new(0.35, 0, 1, 0),
        Position = UDim2.new(0.6, 0, 0, 0),
        BackgroundTransparency = 1,
        Text = "READY",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.Ready,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)

    return row, status
end

local function initUI()
-- =============================================
-- BUILD ALL MINI PANELS
-- =============================================

do
    local panel, content = createMiniPanel("Booster", UDim2.new(0, 20, 0.3, 0), UDim2.new(0, 210, 0, 0))
    createMiniToggle(content, "Booster", 1, function(isOn)
        if isOn then enableSpeedBoost() else disableSpeedBoost() end
    end, "mini_booster")
    walkSpeedSlider = createMiniSlider(content, "Walk Speed", 1, 200, 32, 2)
    jumpPowerSlider = createMiniSlider(content, "Jump Power", 1, 200, 50, 3)
    MiniPanels["booster_gui"] = panel
end

do
    local panel, content = createMiniPanel("FOV Controller", UDim2.new(0.4, 0, 0.2, 0), UDim2.new(0, 220, 0, 0))

    local slider = createMiniSlider(content, "Field Of View", 40, 120, 70, 1)
    local revertBtn = createMiniButton(content, "Change Back To Original", 2, "mini_fov_revert")

    ActionCallbacks["mini_fov_revert"] = function()
        slider.Set(70)
    end

    revertBtn.MouseButton1Click:Connect(function()
        slider.Set(70)
    end)

    RunService.RenderStepped:Connect(function()
        setFOV(slider.Get())
    end)

    MiniPanels["fov_panel"] = panel
end


    local allowFriendsEnabled = false

do
    local friendsPanel, friendsContent = createMiniPanel(
        "Friends Panel",
        UDim2.new(0.65, 0, 0.3, 0),
        UDim2.new(0, 220, 0, 0)
    )

    local toggleBtn = createMiniButton(friendsContent, "Allow/Disallow", 1, "mini_allow_disallow")

    ActionCallbacks["mini_allow_disallow"] = function()
        allowFriendsEnabled = not allowFriendsEnabled
        toggleAllowFriendsAll()
    end

    toggleBtn.MouseButton1Click:Connect(function()
        allowFriendsEnabled = not allowFriendsEnabled

        -- ðŸ”¥ call the system
        toggleAllowFriendsAll()
    end)

    MiniPanels["allow_friends"] = friendsPanel
end

local intruderAlarmPanel, intruderAlarmContent = createMiniPanel("Intruder Alarm", UDim2.new(0.85, 0, 0.25, 0), UDim2.new(0, 180, 0, 0))
createMiniToggle(intruderAlarmContent, "Base Alarm", 1, function(state)
    ToggleHandlers.intruder_alarm(state)
end)
MiniPanels["intruder_alarm"] = intruderAlarmPanel

-- =============================================
-- INVISIBLE STEAL â€” Core Logic
-- =============================================

local invisAnimPlaying = false
local invisTracks = {}
local invisClone, invisOldRoot, invisHip, invisConnection
local invisFolderConnections = {}
local _INVIS_SINK_AMOUNT = 5
local invisServerGhosts = {}
local invisGhostEnabled = true
local invisLagbackCallCount = 0
local invisLagbackWindowStart = 0
local invisLastLagbackTime = 0
local invisErrorOrbActive = false
local invisErrorOrb = nil
local invisErrorOrbConnection = nil

local function invisClearErrorOrb()
    if invisErrorOrb and invisErrorOrb.Parent then invisErrorOrb:Destroy() end
    invisErrorOrb = nil; invisErrorOrbActive = false
    if invisErrorOrbConnection then invisErrorOrbConnection:Disconnect(); invisErrorOrbConnection = nil end
end

local function invisCreateErrorOrb()
    if invisErrorOrbActive then return end
    invisErrorOrbActive = true
    for _, ghost in pairs(invisServerGhosts) do if ghost and ghost.Parent then ghost:Destroy() end end
    invisServerGhosts = {}
    if _G.ErrorOrbGuiInstance then
        pcall(function() _G.ErrorOrbGuiInstance:Destroy() end)
        _G.ErrorOrbGuiInstance = nil
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = getRandomName(); sg.ResetOnSpawn = false
    sg.Parent = getUiParent()
    _G.ErrorOrbGuiInstance = sg
    local fr = Instance.new("Frame")
    fr.Size = UDim2.new(0, 500, 0, 80)
    fr.Position = UDim2.new(0.5, -250, 0.3, 0)
    fr.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
    fr.BackgroundTransparency = 0.15
    fr.BorderSizePixel = 0
    fr.Parent = sg
    Instance.new("UICorner", fr).CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", fr)
    stroke.Color = Color3.fromRGB(255, 70, 70)
    stroke.Thickness = 1
    stroke.Transparency = 0.3

    local l1 = Instance.new("TextLabel")
    l1.Size = UDim2.new(1, 0, 0.5, 0); l1.BackgroundTransparency = 1
    l1.Text = "ERROR CAUSED BY PLAYER DEATH"
    l1.TextColor3 = Color3.fromRGB(255, 70, 70)
    l1.TextStrokeTransparency = 1
    l1.Font = Enum.Font.GothamBold; l1.TextSize = 16; l1.Parent = fr
    local l2 = Instance.new("TextLabel")
    l2.Size = UDim2.new(1, 0, 0.5, 0); l2.Position = UDim2.new(0, 0, 0.5, 0)
    l2.BackgroundTransparency = 1; l2.Text = "MUST RESET TO FIX ERROR"
    l2.TextColor3 = Color3.fromRGB(255, 70, 70)
    l2.TextStrokeTransparency = 1
    l2.Font = Enum.Font.GothamBold; l2.TextSize = 14; l2.Parent = fr
    invisErrorOrb = sg
end

local function invisCreateServerGhost(position)
    if not invisGhostEnabled or invisErrorOrbActive then return end
    local now = tick()
    if now - invisLastLagbackTime < 0.05 then return end
    invisLastLagbackTime = now
    if now - invisLagbackWindowStart > 1 then invisLagbackCallCount = 0; invisLagbackWindowStart = now end
    invisLagbackCallCount = invisLagbackCallCount + 1
    if invisLagbackCallCount >= 7 then invisCreateErrorOrb(); return end
    for _, g in pairs(invisServerGhosts) do if g and g.Parent then g:Destroy() end end
    invisServerGhosts = {}
    if _G.LagbackNotificationInstance then
        pcall(function() _G.LagbackNotificationInstance:Destroy() end)
        _G.LagbackNotificationInstance = nil
    end
    local sg = Instance.new("ScreenGui")
    sg.Name = getRandomName(); sg.ResetOnSpawn = false
    sg.Parent = getUiParent()
    _G.LagbackNotificationInstance = sg
    local sl = Instance.new("TextLabel")
    sl.Size = UDim2.new(0, 500, 0, 30); sl.Position = UDim2.new(0.5, -250, 0.15, 0)
    sl.BackgroundTransparency = 1; sl.Text = "LAGBACK DETECTED"
    sl.TextColor3 = Color3.fromRGB(255, 70, 70)
    sl.TextStrokeTransparency = 1
    sl.Font = Enum.Font.GothamBold; sl.TextSize = 18; sl.Parent = sg
    local sw = Instance.new("TextLabel")
    sw.Size = UDim2.new(0, 650, 0, 25); sw.Position = UDim2.new(0.5, -325, 0.15, 32)
    sw.BackgroundTransparency = 1
    sw.Text = "DISABLE INVISIBLE STEAL NOW OR YOU WILL BE KILLED BY ANTICHEAT"
    sw.TextColor3 = Color3.fromRGB(200, 200, 200)
    sw.TextStrokeTransparency = 1
    sw.Font = Enum.Font.GothamMedium; sw.TextSize = 13; sw.Parent = sg
    task.delay(1.5, function() if sg and sg.Parent then sg:Destroy() end end)
    local ghost = Instance.new("Part")
    ghost.Name = "LagbackGhost"; ghost.Shape = Enum.PartType.Ball
    ghost.Size = Vector3.new(3, 3, 3); ghost.Color = Color3.fromRGB(255, 0, 0)
    ghost.Material = Enum.Material.Glass; ghost.Transparency = 0.3
    ghost.CanCollide = false; ghost.Anchored = true; ghost.CastShadow = false
    ghost.Position = position + Vector3.new(0, 5, 0); ghost.Parent = Workspace.CurrentCamera
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0, 400, 0, 60); bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true; bb.Parent = ghost
    local bl = Instance.new("TextLabel")
    bl.Size = UDim2.new(1, 0, 0, 25); bl.BackgroundTransparency = 1
    bl.Text = "LAGBACK DETECTED"; bl.TextColor3 = Color3.fromRGB(255, 0, 0)
    bl.TextStrokeTransparency = 0; bl.TextStrokeColor3 = Color3.new(0, 0, 0)
    bl.Font = Enum.Font.SourceSansBold; bl.TextScaled = true; bl.Parent = bb
    local bw = Instance.new("TextLabel")
    bw.Size = UDim2.new(1, 0, 0, 25); bw.Position = UDim2.new(0, 0, 0, 25)
    bw.BackgroundTransparency = 1
    bw.Text = "DISABLE INVISIBLE STEAL NOW OR YOU WILL BE KILLED BY ANTICHEAT"
    bw.TextColor3 = Color3.fromRGB(200, 200, 200)
    bw.TextStrokeTransparency = 0; bw.TextStrokeColor3 = Color3.new(0, 0, 0)
    bw.Font = Enum.Font.SourceSansBold; bw.TextScaled = true; bw.Parent = bb
    table.insert(invisServerGhosts, ghost)
end

local function invisClearAllGhosts()
    for _, ghost in pairs(invisServerGhosts) do pcall(function() if ghost and ghost.Parent then ghost:Destroy() end end) end
    invisServerGhosts = {}; invisClearErrorOrb(); invisLagbackCallCount = 0; invisLastLagbackTime = 0
    if _G.LagbackNotificationInstance then
        pcall(function() _G.LagbackNotificationInstance:Destroy() end)
        _G.LagbackNotificationInstance = nil
    end
    pcall(function() if Workspace.CurrentCamera then for _, c in pairs(Workspace.CurrentCamera:GetChildren()) do if c.Name == "LagbackGhost" then c:Destroy() end end end end)
    pcall(function() for _, c in pairs(Workspace:GetDescendants()) do if c.Name == "LagbackGhost" then c:Destroy() end end end)
end

local function invisRemoveFolders()
    local pf = Workspace:FindFirstChild(LocalPlayer.Name)
    if not pf then return end
    local dr = pf:FindFirstChild("DoubleRig")
    if dr then
        local rr = dr:FindFirstChild("HumanoidRootPart") or dr:FindFirstChildWhichIsA("BasePart")
        if rr and invisGhostEnabled then invisCreateServerGhost(rr.Position) end
        dr:Destroy()
    end
    local cs = pf:FindFirstChild("Constraints")
    if cs then cs:Destroy() end
    local conn = pf.ChildAdded:Connect(function(child)
        if child.Name == "DoubleRig" then
            task.defer(function()
                local rr = child:FindFirstChild("HumanoidRootPart") or child:FindFirstChildWhichIsA("BasePart")
                if rr and invisGhostEnabled then invisCreateServerGhost(rr.Position) end
                child:Destroy()
            end)
        elseif child.Name == "Constraints" then child:Destroy() end
    end)
    table.insert(invisFolderConnections, conn)
end

local function invisDoClone()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        invisHip = character.Humanoid.HipHeight
        invisOldRoot = character:FindFirstChild("HumanoidRootPart")
        if not invisOldRoot or not invisOldRoot.Parent then return false end
        
        local tmp = Instance.new("Model")
        tmp.Parent = game
        character.Parent = tmp
        
        invisClone = invisOldRoot:Clone()
        invisClone.Name = getRandomName()
        invisClone.Parent = character
        
        invisOldRoot.Parent = Workspace.CurrentCamera
        invisClone.CFrame = invisOldRoot.CFrame
        character.PrimaryPart = invisClone
        character.Parent = Workspace
        
        -- Client-side anchor the original HumanoidRootPart to preserve network ownership
        -- and prevent it from drifting/falling
        invisOldRoot.Anchored = true
        
        for _, v in pairs(character:GetDescendants()) do
            if v:IsA("Weld") or v:IsA("Motor6D") then
                if v.Part0 == invisOldRoot then v.Part0 = invisClone end
                if v.Part1 == invisOldRoot then v.Part1 = invisClone end
            end
        end
        
        -- Copy attachments to clone so we don't break beams/attachments
        for _, c in ipairs(invisOldRoot:GetChildren()) do
            if c:IsA("Attachment") then
                local attClone = c:Clone()
                attClone.Parent = invisClone
            end
        end
        
        tmp:Destroy()
        return true
    end
    return false
end

local function invisRevertClone()
    local character = LocalPlayer.Character
    if not invisOldRoot or not invisOldRoot:IsDescendantOf(Workspace) or not character or character.Humanoid.Health <= 0 then return end
    
    -- Unanchor real root part
    invisOldRoot.Anchored = false
    
    local tmp = Instance.new("Model")
    tmp.Parent = game
    character.Parent = tmp
    
    invisOldRoot.Parent = character
    character.PrimaryPart = invisOldRoot
    character.Parent = Workspace
    invisOldRoot.CanCollide = true
    
    for _, v in pairs(character:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("Motor6D") then
            if v.Part0 == invisClone then v.Part0 = invisOldRoot end
            if v.Part1 == invisClone then v.Part1 = invisOldRoot end
        end
    end
    
    if invisClone then 
        local p = invisClone.CFrame
        invisClone:Destroy()
        invisClone = nil
        invisOldRoot.CFrame = p 
    end
    invisOldRoot = nil
    if character and character.Humanoid then character.Humanoid.HipHeight = invisHip end
    invisClearAllGhosts()
end

local function invisAnimationTrickery()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 then
        local anim = Instance.new("Animation")
        anim.AnimationId = "http://www.roblox.com/asset/?id=18537363391"
        local humanoid = character.Humanoid
        local animator = humanoid:FindFirstChild("Animator") or Instance.new("Animator", humanoid)
        local animTrack = animator:LoadAnimation(anim)
        animTrack.Priority = Enum.AnimationPriority.Action4
        animTrack:Play(0, 1, 0); anim:Destroy()
        table.insert(invisTracks, animTrack)
        animTrack.Stopped:Connect(function() if invisAnimPlaying then invisAnimationTrickery() end end)
        task.delay(0, function()
            animTrack.TimePosition = 0.7
            task.delay(0.3, function() if animTrack then animTrack:AdjustSpeed(math.huge) end end)
        end)
    end
end

-- Forward-declared reference for visual updates
local invisUpdateVisualState = nil

local function invisTurnOff()
    invisClearAllGhosts()
    if not invisAnimPlaying then return end
    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    invisAnimPlaying = false; _G.invisibleStealEnabled = false
    for _, t in pairs(invisTracks) do pcall(function() t:Stop() end) end
    invisTracks = {}
    if invisConnection then invisConnection:Disconnect(); invisConnection = nil end
    for _, c in ipairs(invisFolderConnections) do if c then c:Disconnect() end end
    invisFolderConnections = {}
    invisRevertClone(); invisClearAllGhosts()
    if humanoid then pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end) end
    if invisUpdateVisualState then pcall(invisUpdateVisualState, false) end
end

local function invisTurnOn()
    if invisAnimPlaying then return end
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    invisAnimPlaying = true; _G.invisibleStealEnabled = true
    if invisUpdateVisualState then pcall(invisUpdateVisualState, true) end
    invisTracks = {}; invisRemoveFolders()
    local success = invisDoClone()
    if success then
        task.wait(0.05); invisAnimationTrickery()
        task.defer(function()
            if _G.resetBrainrotBeam then pcall(_G.resetBrainrotBeam) end
            if _G.resetPlotBeam then pcall(_G.resetPlotBeam) end
            task.wait(0.1)
            if _G.updateBrainrotBeam then pcall(_G.updateBrainrotBeam) end
            if _G.createPlotBeam then pcall(_G.createPlotBeam) end
        end)
        local lastSetPosition = nil; local skipFrames = 5
        invisConnection = RunService.PreSimulation:Connect(function()
            if character and character:FindFirstChild("Humanoid") and character.Humanoid.Health > 0 and invisOldRoot then
                local root = character.PrimaryPart or character:FindFirstChild("HumanoidRootPart")
                if root then
                    if skipFrames > 0 then skipFrames = skipFrames - 1; lastSetPosition = nil
                    elseif lastSetPosition and invisGhostEnabled then
                        local currentPos = invisOldRoot.Position
                        local jumpDist = (currentPos - lastSetPosition).Magnitude
                        if jumpDist > 3 and not _G.RecoveryInProgress then
                            lastSetPosition = nil; invisCreateServerGhost(currentPos)
                            if _G.AutoRecoverLagback and _G.toggleInvisibleSteal then
                                _G.RecoveryInProgress = true
                                task.spawn(function()
                                    pcall(_G.toggleInvisibleSteal); task.wait(0.5)
                                    pcall(_G.toggleInvisibleSteal); _G.RecoveryInProgress = false
                                end)
                            end
                        end
                    end
                    if invisClone then invisClone.CanCollide = false end
                    for _, c in pairs(invisOldRoot:GetChildren()) do
                        if c:IsA("Attachment") or c:IsA("Beam") then c:Destroy() end
                    end
                    local rotAngle = _G.InvisStealAngle or 180
                    local sa = (_G.SinkSliderValue or 5) * 0.5
                    local cf = root.CFrame - Vector3.new(0, sa, 0)
                    invisOldRoot.CFrame = cf * CFrame.Angles(math.rad(rotAngle), 0, 0)
                    invisOldRoot.AssemblyLinearVelocity = root.AssemblyLinearVelocity; invisOldRoot.CanCollide = false
                    lastSetPosition = invisOldRoot.Position
                end
            end
        end)
    end
end

_G.toggleInvisibleSteal = function()
    if invisAnimPlaying then invisTurnOff() else invisTurnOn() end
end

_G.InvisStealAngle = Config.sliders["Invis Rotation"] or 180
_G.SinkSliderValue = Config.sliders["Invis Depth"] or 5
_G.AutoRecoverLagback = Config.toggles["invis_auto_fix_lagback"] or false
_G.AutoInvisDuringSteal = Config.toggles["invis_auto_during_steal"] or false

-- Character added handler for invisible steal
local function invisOnCharacterAdded(newChar)
    invisClearErrorOrb(); invisClearAllGhosts(); invisLagbackCallCount = 0
    pcall(function() for _, c in pairs(Workspace.CurrentCamera:GetChildren()) do if c:IsA("BasePart") and c.Name == "HumanoidRootPart" then c:Destroy() end end end)
    if invisOldRoot then pcall(function() invisOldRoot:Destroy() end); invisOldRoot = nil end
    if invisClone then pcall(function() invisClone:Destroy() end); invisClone = nil end
    invisAnimPlaying = false; _G.invisibleStealEnabled = false
    if invisUpdateVisualState then pcall(invisUpdateVisualState, false) end
    task.wait(0.2)
    local camera = Workspace.CurrentCamera
    if camera and newChar then
        local h = newChar:FindFirstChildOfClass("Humanoid")
        if h then camera.CameraSubject = h; camera.CameraType = Enum.CameraType.Custom end
    end
end
LocalPlayer.CharacterAdded:Connect(invisOnCharacterAdded)

-- Death listener for invisible steal
local function invisSetupDeathListener()
    local ch = LocalPlayer.Character
    if ch then
        local h = ch:FindFirstChildOfClass("Humanoid")
        if h then h.Died:Connect(function() invisClearErrorOrb(); invisClearAllGhosts(); invisLagbackCallCount = 0 end) end
    end
end
invisSetupDeathListener()
LocalPlayer.CharacterAdded:Connect(function() task.wait(0.1); invisSetupDeathListener() end)

-- Anti-Die system
task.spawn(function()
    local currentAntiDieConn = nil
    _G.AntiDieConnection = nil
    _G.AntiDieDisabled = false
    local function setupAntiDie()
        if _G.AntiDieDisabled then return end
        local character = LocalPlayer.Character
        if not character then return end
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid then return end
        if currentAntiDieConn then pcall(function() currentAntiDieConn:Disconnect() end) end
        currentAntiDieConn = humanoid:GetPropertyChangedSignal("Health"):Connect(function()
            if _G.AntiDieDisabled then return end
            if humanoid.Health <= 0 then
                humanoid.Health = humanoid.MaxHealth
            end
        end)
        _G.AntiDieConnection = currentAntiDieConn
    end
    _G.setupAntiDie = setupAntiDie
    setupAntiDie()
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        if not _G.AntiDieDisabled then
            setupAntiDie()
        end
    end)
end)

-- Auto-invis during steal loop
task.spawn(function()
    local wasStealingForInvis = false
    local _invisWasEnabledBefore = false
    local autoEnabledInvis = false
    task.wait(1)
    while task.wait(0.1) do
        if _G.AutoInvisDuringSteal == false then
            wasStealingForInvis = false
            autoEnabledInvis = false
        else
            local isStealing = LocalPlayer:GetAttribute("Stealing")
            if isStealing and not wasStealingForInvis then
                _invisWasEnabledBefore = _G.invisibleStealEnabled or false
                if not _G.invisibleStealEnabled and _G.toggleInvisibleSteal then
                    task.delay(0.25, function()
                        if LocalPlayer:GetAttribute("Stealing") and not _G.invisibleStealEnabled then
                            pcall(_G.toggleInvisibleSteal)
                            autoEnabledInvis = true
                        end
                    end)
                end
            end
            if not isStealing and autoEnabledInvis and _G.invisibleStealEnabled and _G.toggleInvisibleSteal then
                pcall(_G.toggleInvisibleSteal)
                autoEnabledInvis = false
            end
            wasStealingForInvis = isStealing
        end
    end
end)

-- =============================================
-- INVISIBLE STEAL â€” Mini Panel
-- =============================================

do
    local panel, content = createMiniPanel("Invisible Steal", UDim2.new(0.3, 0, 0.25, 0), UDim2.new(0, 260, 0, 0))

    -- Custom main toggle with external visual sync
    local row = createInstance("Frame", {
        Name = "Row_InvisToggle",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = COLORS.SectionBG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    }, content)
    addCorner(row, 6)

    local lbl = createInstance("TextButton", {
        Size = UDim2.new(1, -90, 1, 0),
        Position = UDim2.new(0, 8, 0, 0),
        BackgroundTransparency = 1,
        Text = "Invisible Steal",
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, row)

    local switch = createInstance("Frame", {
        Name = "Switch",
        Size = UDim2.new(0, 36, 0, 18),
        Position = UDim2.new(1, -44, 0.5, -9),
        BackgroundColor3 = COLORS.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    addCorner(switch, 9)
    addStroke(switch, Color3.fromRGB(80, 50, 140), 1)

    local knob = createInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 14, 0, 14),
        Position = UDim2.new(0, 2, 0.5, -7),
        BackgroundColor3 = COLORS.KnobOff,
        BorderSizePixel = 0,
    }, switch)
    addCorner(knob, 7)

    local bindLabel = createInstance("TextLabel", {
        Name = "BindLabel",
        Size = UDim2.new(0, 40, 1, 0),
        Position = UDim2.new(1, -90, 0, 0),
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.BindText,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
        Visible = false,
    }, row)

    ToggleElements["mini_invisible_steal"] = { bindLabel = bindLabel }

    local function setInvisVisual(on)
        if on then
            switch.BackgroundColor3 = COLORS.ToggleOn
            knob.Position = UDim2.new(1, -16, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOn
        else
            switch.BackgroundColor3 = COLORS.ToggleOff
            knob.Position = UDim2.new(0, 2, 0.5, -7)
            knob.BackgroundColor3 = COLORS.KnobOff
        end
    end

    -- Set initial visual if was on
    if _G.invisibleStealEnabled then setInvisVisual(true) end

    local btn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, switch)

    btn.MouseButton1Click:Connect(function()
        pcall(_G.toggleInvisibleSteal)
        setInvisVisual(_G.invisibleStealEnabled or false)
    end)

    -- Register ActionCallback for keybind
    ActionCallbacks["mini_invisible_steal"] = function()
        pcall(_G.toggleInvisibleSteal)
        setInvisVisual(_G.invisibleStealEnabled or false)
    end

    -- Right-click to bind key
    lbl.MouseButton2Click:Connect(function()
        if ListeningId == "mini_invisible_steal" then
            ListeningId = nil
            updateBindLabel("mini_invisible_steal")
            return
        end
        local prev = ListeningId
        ListeningId = "mini_invisible_steal"
        if prev then updateBindLabel(prev) end
        updateBindLabel("mini_invisible_steal")
    end)

    -- Load saved keybind
    if Config.keybinds["mini_invisible_steal"] then
        local ok, key = pcall(function() return Enum.KeyCode[Config.keybinds["mini_invisible_steal"]] end)
        if ok and key then
            Keybinds["mini_invisible_steal"] = key
            updateBindLabel("mini_invisible_steal")
        end
    end

    -- Wire up the visual state updater so external toggles (keybind, auto-steal) sync the UI
    invisUpdateVisualState = function(on)
        setInvisVisual(on)
    end

    -- Auto Invisible During Steal toggle (custom with keybind)
    do
        local aiRow = createInstance("Frame", {
            Name = "Row_AutoInvisDuringSteal",
            Size = UDim2.new(1, 0, 0, 30),
            BackgroundColor3 = COLORS.SectionBG,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            LayoutOrder = 2,
        }, content)
        addCorner(aiRow, 6)

        local aiLbl = createInstance("TextButton", {
            Size = UDim2.new(1, -90, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = "Auto Invisible During Steal",
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        }, aiRow)

        local aiSwitch = createInstance("Frame", {
            Name = "Switch",
            Size = UDim2.new(0, 36, 0, 18),
            Position = UDim2.new(1, -44, 0.5, -9),
            BackgroundColor3 = COLORS.ToggleOff,
            BorderSizePixel = 0,
        }, aiRow)
        addCorner(aiSwitch, 9)
        addStroke(aiSwitch, Color3.fromRGB(80, 50, 140), 1)

        local aiKnob = createInstance("Frame", {
            Name = "Knob",
            Size = UDim2.new(0, 14, 0, 14),
            Position = UDim2.new(0, 2, 0.5, -7),
            BackgroundColor3 = COLORS.KnobOff,
            BorderSizePixel = 0,
        }, aiSwitch)
        addCorner(aiKnob, 7)

        local aiBindLabel = createInstance("TextLabel", {
            Name = "BindLabel",
            Size = UDim2.new(0, 40, 1, 0),
            Position = UDim2.new(1, -90, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.BindText,
            TextSize = 9,
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
        }, aiRow)

        ToggleElements["mini_auto_invis_steal"] = { bindLabel = aiBindLabel }

        local function setAutoInvisVisual(on)
            if on then
                aiSwitch.BackgroundColor3 = COLORS.ToggleOn
                aiKnob.Position = UDim2.new(1, -16, 0.5, -7)
                aiKnob.BackgroundColor3 = COLORS.KnobOn
            else
                aiSwitch.BackgroundColor3 = COLORS.ToggleOff
                aiKnob.Position = UDim2.new(0, 2, 0.5, -7)
                aiKnob.BackgroundColor3 = COLORS.KnobOff
            end
        end

        -- Set initial visual
        if _G.AutoInvisDuringSteal then setAutoInvisVisual(true) end

        local aiBtn = createInstance("TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 5,
        }, aiSwitch)

        local function toggleAutoInvis()
            _G.AutoInvisDuringSteal = not _G.AutoInvisDuringSteal
            setAutoInvisVisual(_G.AutoInvisDuringSteal)
            Config.toggles["invis_auto_during_steal"] = _G.AutoInvisDuringSteal
            saveConfig()
        end

        aiBtn.MouseButton1Click:Connect(toggleAutoInvis)

        ActionCallbacks["mini_auto_invis_steal"] = function()
            toggleAutoInvis()
        end

        aiLbl.MouseButton2Click:Connect(function()
            if ListeningId == "mini_auto_invis_steal" then
                ListeningId = nil
                updateBindLabel("mini_auto_invis_steal")
                return
            end
            local prev = ListeningId
            ListeningId = "mini_auto_invis_steal"
            if prev then updateBindLabel(prev) end
            updateBindLabel("mini_auto_invis_steal")
        end)

        if Config.keybinds["mini_auto_invis_steal"] then
            local ok, key = pcall(function() return Enum.KeyCode[Config.keybinds["mini_auto_invis_steal"]] end)
            if ok and key then
                Keybinds["mini_auto_invis_steal"] = key
                updateBindLabel("mini_auto_invis_steal")
            end
        end
    end

    -- Auto Fix Lagback toggle
    createMiniToggle(content, "Auto Fix Lagback", 3, function(isOn)
        _G.AutoRecoverLagback = isOn
        Config.toggles["invis_auto_fix_lagback"] = isOn
        saveConfig()
    end, "mini_invis_lagback")

    -- Rotation slider (180-360)
    createMiniSlider(content, "Invis Rotation", 180, 360, 180, 4, function(val)
        _G.InvisStealAngle = val
    end)

    -- Depth slider (1-10, multiplied by 0.5 in core logic)
    createMiniSlider(content, "Invis Depth", 1, 10, 5, 5, function(val)
        _G.SinkSliderValue = val
    end)

    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.SectionBorder,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = 2,
    }, content)

    MiniPanels["invisible_steal"] = panel
end

do
    -- =============================================
    -- QUICK ADMIN PANEL â€” Player Detection + Emoji Commands
    -- =============================================
    local QAP_WIDTH = 320
    local QAP_HEIGHT = 260
    local QAP_ROW_HEIGHT = 30

    local panel = createInstance("Frame", {
        Name = "MiniPanel_AdminPanel",
        Size = UDim2.new(0, QAP_WIDTH, 0, QAP_HEIGHT),
        Position = UDim2.new(0.5, -QAP_WIDTH / 2, 0.78, 0),
        BackgroundColor3 = COLORS.Panel,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
        Draggable = true,
        ClipsDescendants = true,
        ZIndex = 15,
    }, ScreenGui)
    addCorner(panel, 10)
    addStroke(panel, COLORS.Border, 1.5)

    createInstance("ImageLabel", {
        Name = "Glow",
        Size = UDim2.new(1, 30, 1, 30),
        Position = UDim2.new(0, -15, 0, -15),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6015897843",
        ImageColor3 = COLORS.Accent,
        ImageTransparency = 0.88,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 14,
    }, panel)

    -- Title bar
    local titleBar = createInstance("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = COLORS.MiniTitle,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ZIndex = 16,
    }, panel)
    addCorner(titleBar, 10)

    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 10),
        Position = UDim2.new(0, 0, 1, -10),
        BackgroundColor3 = COLORS.MiniTitle,
        BorderSizePixel = 0,
        ZIndex = 16,
    }, titleBar)

    createInstance("TextLabel", {
        Size = UDim2.new(1, -40, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = "Admin Panel",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 17,
    }, titleBar)

    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        Position = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = COLORS.MiniTitleBorder,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 17,
    }, titleBar)

    local minimizeBtn = createInstance("TextButton", {
        Name = "MinimizeBtn",
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(1, -30, 0.5, -11),
        BackgroundTransparency = 1,
        Text = "â€”",
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.AccentBright,
        TextSize = 14,
        AutoButtonColor = false,
        ZIndex = 18,
    }, titleBar)

    -- Scrollable player list
    local playerScroll = createInstance("ScrollingFrame", {
        Name = "PlayerList",
        Size = UDim2.new(1, -12, 1, -34),
        Position = UDim2.new(0, 6, 0, 31),
        BackgroundTransparency = 1,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = COLORS.AccentBright,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ZIndex = 16,
    }, panel)

    local listLayout = createInstance("UIListLayout", {
        Padding = UDim.new(0, 3),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, playerScroll)

    listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        playerScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)
    end)

    -- Emoji â†’ command map (matches in-game admin panel order)
    local adminCommands = {
        { name = "tiny",    emoji = "\xF0\x9F\xA4\x8F" },  -- ðŸ¤
        { name = "jail",    emoji = "\xF0\x9F\x94\x92" },  -- ðŸ”’
        { name = "rocket",  emoji = "\xF0\x9F\x9A\x80" },  -- ðŸš€
        { name = "ragdoll", emoji = "\xF0\x9F\x8F\x83" },  -- ðŸƒ
        { name = "balloon", emoji = "\xF0\x9F\x8E\x88" },  -- ðŸŽˆ
    }

    -- Reads real cooldown state from in-game AdminPanel Timer objects
    local qapCooldownBtns = {}  -- qapCooldownBtns[cmdName] = { {btn, emoji}, ... }

    for _, cmd in ipairs(adminCommands) do
        qapCooldownBtns[cmd.name] = {}
    end

    local function qapGetInGameScrollFrame()
        local ok, sf = pcall(function()
            return LocalPlayer.PlayerGui.AdminPanel.AdminPanel.Content.ScrollingFrame
        end)
        return ok and sf or nil
    end

    local function qapIsOnCooldown(cmdName)
        local sf = qapGetInGameScrollFrame()
        if not sf then return false end
        local cmdFrame = sf:FindFirstChild(cmdName)
        if not cmdFrame then return false end
        local timer = cmdFrame:FindFirstChild("Timer")
        if not timer then return false end
        return timer.Visible == true
    end

    local function qapGetCooldownText(cmdName)
        local sf = qapGetInGameScrollFrame()
        if not sf then return nil end
        local cmdFrame = sf:FindFirstChild(cmdName)
        if not cmdFrame then return nil end
        local timer = cmdFrame:FindFirstChild("Timer")
        if not timer or not timer.Visible then return nil end
        return timer.Text or ""
    end

    -- Cooldown UI updater â€” reads from actual in-game Timer objects
    local qapCooldownRunning = false
    local function qapRunCooldownLoop()
        if qapCooldownRunning then return end
        qapCooldownRunning = true
        task.spawn(function()
            while panel and panel.Parent and panel.Visible do
                for _, cmd in ipairs(adminCommands) do
                    local onCD = qapIsOnCooldown(cmd.name)
                    local cdText = onCD and qapGetCooldownText(cmd.name) or nil
                    for _, entry in ipairs(qapCooldownBtns[cmd.name]) do
                        local btn, emoji = entry[1], entry[2]
                        if btn and btn.Parent then
                            if onCD and cdText then
                                btn.Text = cdText
                                btn.TextSize = 10
                                btn.TextColor3 = Color3.fromRGB(255, 100, 100)
                                btn.BackgroundTransparency = 0.65
                            else
                                btn.Text = emoji
                                btn.TextSize = 14
                                btn.TextColor3 = COLORS.Text
                                btn.BackgroundTransparency = 0.3
                            end
                        end
                    end
                end
                task.wait(0.25)
            end
            qapCooldownRunning = false
        end)
    end

    -- Command execution system (accesses in-game AdminPanel)
    local qapCommandCache = {}
    local qapProfileCache = {}

    local function qapGetAdminFrames()
        local ap = LocalPlayer.PlayerGui:FindFirstChild("AdminPanel")
        if not ap then return end
        local inner = ap:FindFirstChild("AdminPanel")
        if not inner then return end
        local content = inner:FindFirstChild("Content")
        local profiles = inner:FindFirstChild("Profiles")
        if not content or not profiles then return end
        return content:FindFirstChild("ScrollingFrame"), profiles:FindFirstChild("ScrollingFrame")
    end

    local function qapCacheActivated(guiObject)
        local cached = {}
        local ok, conns = pcall(getconnections, guiObject.Activated)
        if ok and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                if type(conn.Function) == "function" then
                    table.insert(cached, conn.Function)
                end
            end
        end
        return cached
    end

    local function qapFireActivated(cached)
        for _, fn in ipairs(cached) do task.spawn(fn) end
    end

    local function qapRunCommand(commandName, target)
        local commandFrame, profileFrame = qapGetAdminFrames()
        if not commandFrame or not profileFrame then return end

        local profileButton = profileFrame:FindFirstChild(target.Name)
        local commandButton = commandFrame:FindFirstChild(commandName)
        if not profileButton or not commandButton then return end

        if not qapProfileCache[target.Name] then
            qapProfileCache[target.Name] = qapCacheActivated(profileButton)
        end
        if not qapCommandCache[commandName] then
            qapCommandCache[commandName] = qapCacheActivated(commandButton)
        end

        qapFireActivated(qapProfileCache[target.Name])
        task.wait()
        qapFireActivated(qapCommandCache[commandName])
    end

    -- Build a single player row with emoji command buttons
    local function createQAPPlayerRow(plr, order)
        local row = createInstance("Frame", {
            Name = "QAP_" .. plr.Name,
            Size = UDim2.new(1, -4, 0, QAP_ROW_HEIGHT),
            BackgroundColor3 = COLORS.SectionBG,
            BackgroundTransparency = 0.15,
            BorderSizePixel = 0,
            LayoutOrder = order,
            ZIndex = 16,
        }, playerScroll)
        addCorner(row, 6)

        -- Player name: DisplayName (@Username)
        local displayText = plr.DisplayName
        if plr.DisplayName ~= plr.Name then
            displayText = plr.DisplayName .. " (@" .. plr.Name .. ")"
        end

        createInstance("TextLabel", {
            Size = UDim2.new(0, 155, 1, 0),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = displayText,
            Font = Enum.Font.GothamMedium,
            TextColor3 = COLORS.Text,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 17,
        }, row)

        -- Emoji command buttons
        local btnSize = 22
        local btnGap = 2
        local startX = 165

        for i, cmd in ipairs(adminCommands) do
            local btn = createInstance("TextButton", {
                Name = "Cmd_" .. cmd.name,
                Size = UDim2.new(0, btnSize, 0, btnSize),
                Position = UDim2.new(0, startX + (i - 1) * (btnSize + btnGap), 0.5, -btnSize / 2),
                BackgroundColor3 = COLORS.ButtonBG,
                BackgroundTransparency = 0.3,
                Text = cmd.emoji,
                TextSize = 14,
                Font = Enum.Font.SourceSans,
                AutoButtonColor = false,
                ZIndex = 17,
            }, row)
            addCorner(btn, 4)

            -- Register button for cooldown tracking
            table.insert(qapCooldownBtns[cmd.name], { btn, cmd.emoji })

            btn.MouseEnter:Connect(function()
                if not qapIsOnCooldown(cmd.name) then
                    tween(btn, { BackgroundTransparency = 0, BackgroundColor3 = COLORS.ButtonHover }, 0.12)
                end
            end)
            btn.MouseLeave:Connect(function()
                if not qapIsOnCooldown(cmd.name) then
                    tween(btn, { BackgroundTransparency = 0.3, BackgroundColor3 = COLORS.ButtonBG }, 0.12)
                end
            end)

            local function fireCommand()
                if qapIsOnCooldown(cmd.name) then return end
                task.spawn(function() qapRunCommand(cmd.name, plr) end)
                -- Click flash
                tween(btn, { BackgroundColor3 = COLORS.AccentBright }, 0.08)
                task.delay(0.2, function()
                    tween(btn, { BackgroundColor3 = COLORS.ButtonBG }, 0.15)
                end)
            end

            btn.MouseButton1Click:Connect(fireCommand)

            -- Mobile touch support
            btn.InputBegan:Connect(function(input_obj)
                if input_obj.UserInputType == Enum.UserInputType.Touch then
                    fireCommand()
                end
            end)
        end

        return row
    end

    -- "No targets found" fallback label
    local noTargetLabel = createInstance("TextLabel", {
        Name = "NoTargetLabel",
        Size = UDim2.new(1, -20, 0, 28),
        Position = UDim2.new(0, 10, 0, 31),
        BackgroundTransparency = 1,
        Text = "No targets found",
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.TextDim,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center,
        Visible = true,
        ZIndex = 16,
    }, panel)

    -- Refresh the player list
    local function refreshQAPPlayers()
        -- Clear old button references (they'll be re-registered by createQAPPlayerRow)
        for _, cmd in ipairs(adminCommands) do
            qapCooldownBtns[cmd.name] = {}
        end

        for _, child in ipairs(playerScroll:GetChildren()) do
            if child:IsA("Frame") then child:Destroy() end
        end

        local order = 1
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                createQAPPlayerRow(plr, order)
                order = order + 1
            end
        end

        noTargetLabel.Visible = (order == 1) -- show if no other players
        playerScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 6)

        -- Start cooldown UI loop
        qapRunCooldownLoop()
    end

    -- Auto-refresh on player join/leave
    Players.PlayerAdded:Connect(function(plr)
        task.wait(0.3)
        refreshQAPPlayers()
    end)
    Players.PlayerRemoving:Connect(function(plr)
        qapProfileCache[plr.Name] = nil -- invalidate cache
        task.wait(0.3)
        refreshQAPPlayers()
    end)

    -- Initial population
    task.defer(refreshQAPPlayers)

    -- Minimize / restore
    local adminMinimized = false
    minimizeBtn.MouseButton1Click:Connect(function()
        adminMinimized = not adminMinimized
        if adminMinimized then
            tween(panel, { Size = UDim2.new(0, QAP_WIDTH, 0, 28) }, 0.2)
            playerScroll.Visible = false
            noTargetLabel.Visible = false
        else
            tween(panel, { Size = UDim2.new(0, QAP_WIDTH, 0, QAP_HEIGHT) }, 0.2)
            playerScroll.Visible = true
            refreshQAPPlayers()
        end
    end)

    MiniPanels["quick_admin_panel"] = panel

    -- Restore saved Quick Admin Panel position
    if Config.panels and Config.panels["quick_admin_panel"] then
        panel.Position = UDim2.new(
            Config.panels["quick_admin_panel"].xScale,
            Config.panels["quick_admin_panel"].xOffset,
            Config.panels["quick_admin_panel"].yScale,
            Config.panels["quick_admin_panel"].yOffset
        )
    end

    -- Save Quick Admin Panel position on drag
    panel:GetPropertyChangedSignal("Position"):Connect(function()
        Config.panels = Config.panels or {}
        Config.panels["quick_admin_panel"] = {
            xScale = panel.Position.X.Scale,
            xOffset = panel.Position.X.Offset,
            yScale = panel.Position.Y.Scale,
            yOffset = panel.Position.Y.Offset,
        }
        saveConfig()
    end)
end

do
    local panel, content = createMiniPanel("Command Cooldowns", UDim2.new(0.28, 0, 0.35, 0), UDim2.new(0, 220, 0, 0))

    local commands = {"rocket", "ragdoll", "balloon", "inverse", "jail", "control", "titty", "jumpscare", "morph"}
    -- Map display names to actual in-game command names for Timer lookup
    local cmdNameMap = { titty = "tiny" }
    local statusLabels = {}
    for i, cmd in ipairs(commands) do
        local _, status = createCommandRow(content, cmd, i)
        statusLabels[cmd] = status
    end

    -- Live update loop â€” reads Timer objects from in-game AdminPanel
    task.spawn(function()
        while _G.ZenoHubAlive and task.wait(0.3) do
            pcall(function()
                local sf = LocalPlayer.PlayerGui.AdminPanel.AdminPanel.Content.ScrollingFrame
                for _, cmd in ipairs(commands) do
                    local lbl = statusLabels[cmd]
                    if lbl and lbl.Parent then
                        local inGameName = cmdNameMap[cmd] or cmd
                        local cmdFrame = sf:FindFirstChild(inGameName)
                        if cmdFrame then
                            local timer = cmdFrame:FindFirstChild("Timer")
                            if timer and timer.Visible then
                                lbl.Text = timer.Text or "..."
                                lbl.TextColor3 = Color3.fromRGB(255, 100, 100)
                            else
                                lbl.Text = "READY"
                                lbl.TextColor3 = COLORS.Ready
                            end
                        end
                    end
                end
            end)
        end
    end)

    MiniPanels["command_cooldowns"] = panel
end


-- =============================================
-- AUTO DEFENSE SYSTEM
-- =============================================

local AutoDefenseEnabled = false
local AntiTPEnabled_state = false
local function AntiTPEnabled() return AntiTPEnabled_state end
local kickNoCmdsEnabled = false
local defenseTarget1, defenseTarget2 = nil, nil
local lastDefenseExecuteTime = 0
local defenseCommandCache = {}
local defenseProfileCache = {}

local function defenseCacheActivated(guiObject)
    local cached = {}
    local ok, conns = pcall(getconnections, guiObject.Activated)
    if ok and type(conns) == "table" then
        for _, conn in ipairs(conns) do
            if type(conn.Function) == "function" then
                table.insert(cached, conn.Function)
            end
        end
    end
    return cached
end

local function defenseFireActivated(cached)
    for _, fn in ipairs(cached) do
        task.spawn(fn)
    end
end

local function getDefenseAdminPanel()
    local player = Players.LocalPlayer
    local adminPanel = player.PlayerGui:FindFirstChild("AdminPanel")
    if not adminPanel then return nil, nil end
    local panel = adminPanel:FindFirstChild("AdminPanel")
    if not panel then return nil, nil end
    local content = panel:FindFirstChild("Content")
    local profiles = panel:FindFirstChild("Profiles")
    if not content or not profiles then return nil, nil end
    local commandFrame = content:FindFirstChild("ScrollingFrame")
    local profileFrame = profiles:FindFirstChild("ScrollingFrame")
    return commandFrame, profileFrame
end

local function buildDefenseCache(targetPlayer)
    local commandFrame, profileFrame = getDefenseAdminPanel()
    if not commandFrame or not profileFrame then return false end

    local profileButton = profileFrame:FindFirstChild(targetPlayer.Name)
    if not profileButton then return false end

    if not defenseProfileCache[targetPlayer.Name] then
        defenseProfileCache[targetPlayer.Name] = defenseCacheActivated(profileButton)
    end

    local commands = {"balloon", "ragdoll", "rocket", "inverse", "tiny", "jail", "jumpscare", "morph"}
    for _, cmd in ipairs(commands) do
        if not defenseCommandCache[cmd] then
            local btn = commandFrame:FindFirstChild(cmd)
            if btn then
                defenseCommandCache[cmd] = defenseCacheActivated(btn)
            end
        end
    end

    return true
end

local function defenseExecuteCommandsOnPlayer(targetPlayer, commandList)
    if not defenseProfileCache[targetPlayer.Name] or #defenseProfileCache[targetPlayer.Name] == 0 then
        if not buildDefenseCache(targetPlayer) then return false end
    end

    local profileConns = defenseProfileCache[targetPlayer.Name]
    for _, command in ipairs(commandList) do
        local cmdConns = defenseCommandCache[command]
        if cmdConns and #cmdConns > 0 then
            defenseFireActivated(cmdConns)
            defenseFireActivated(profileConns)
        end
    end

    return true
end

local function _defenseInvalidatePlayerCache(playerName)
    defenseProfileCache[playerName] = nil
end

local defenseCmdSwitch = false
task.spawn(function()
    while _G.ZenoHubAlive and task.wait(0.1) do
        pcall(function()
            local player = Players.LocalPlayer
            local sf = player.PlayerGui.AdminPanel.AdminPanel.Content.ScrollingFrame
            if not sf.balloon.Timer.Visible then
                defenseCmdSwitch = false
            elseif not sf.ragdoll.Timer.Visible then
                defenseCmdSwitch = true
            end
        end)
    end
end)

local defenseExecuteCooldown = 0.05

local function defenseAutoSelectClosest()
    local player = Players.LocalPlayer
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player then
            defenseTarget1 = plr
            break
        end
    end
end

local function defenseRunCommands()
    if (tick() - lastDefenseExecuteTime) < defenseExecuteCooldown then return end

    if not defenseTarget1 and not defenseTarget2 then
        defenseAutoSelectClosest()
    end

    local validPlayers = {}
    if defenseTarget1 and defenseTarget1.Parent == Players then table.insert(validPlayers, defenseTarget1) end
    if defenseTarget2 and defenseTarget2.Parent == Players then table.insert(validPlayers, defenseTarget2) end

    if #validPlayers == 0 then return end
    lastDefenseExecuteTime = tick()

    if #validPlayers == 1 then
        task.spawn(function()
            defenseExecuteCommandsOnPlayer(validPlayers[1], {"balloon", "tiny", "rocket", "inverse", "jumpscare", "morph"})
        end)
    elseif #validPlayers >= 2 then
        task.spawn(function()
            defenseExecuteCommandsOnPlayer(validPlayers[1], {"balloon", "tiny", "rocket", "inverse"})
        end)
        task.spawn(function()
            defenseExecuteCommandsOnPlayer(validPlayers[2], {"ragdoll", "jail", "jumpscare", "morph"})
        end)
    end
end

local function defenseRunDefenseCommands()
    local player = Players.LocalPlayer
    if (tick() - lastDefenseExecuteTime) < defenseExecuteCooldown then return end

    if not defenseTarget1 and not defenseTarget2 then
        defenseAutoSelectClosest()
    end

    local validPlayers = {}
    if defenseTarget1 and defenseTarget1.Parent == Players then table.insert(validPlayers, defenseTarget1) end
    if defenseTarget2 and defenseTarget2.Parent == Players then table.insert(validPlayers, defenseTarget2) end

    if #validPlayers == 0 then return end

    if #validPlayers == 1 then
        if not defenseCmdSwitch then
            task.spawn(function()
                defenseExecuteCommandsOnPlayer(validPlayers[1], {"balloon"})
            end)
        else
            task.spawn(function()
                defenseExecuteCommandsOnPlayer(validPlayers[1], {"ragdoll", "tiny", "inverse", "rocket", "jumpscare"})
            end)
            if kickNoCmdsEnabled then
                task.spawn(function()
                    task.wait(1)
                    player:Kick("Safety Kick: Out of commands")
                end)
            end
        end
    elseif #validPlayers >= 2 then
        task.spawn(function()
            defenseExecuteCommandsOnPlayer(validPlayers[1], {"balloon", "tiny", "inverse", "rocket"})
        end)
        task.spawn(function()
            defenseExecuteCommandsOnPlayer(validPlayers[2], {"ragdoll", "jail", "jumpscare", "morph"})
        end)
    end
    lastDefenseExecuteTime = tick()
end

-- Remote event listener for auto defense (steal detection)
for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
    if obj:IsA("RemoteEvent") then
        obj.OnClientEvent:Connect(function(...)
            if not AutoDefenseEnabled then return end
            for _, arg in ipairs({...}) do
                if type(arg) == "string" and string.find(string.lower(arg), "stealing") then
                    defenseRunDefenseCommands()
                    break
                end
            end
        end)
    end
end

-- Anti TP Scam: Plot & Podium detection
local defensePlot = nil
local defensePodiums = {}
local defenseTPThreshold = 12

local function findDefensePlot()
local plots = workspace:FindFirstChild("Plots")
if not plots then return nil end
for _, plot in ipairs(plots:GetChildren()) do
if plot:IsA("Model") then
local sign = plot:FindFirstChild("PlotSign")
if sign then
local yourBase = sign:FindFirstChild("YourBase")
if yourBase and yourBase:IsA("BillboardGui") and yourBase.Enabled == true then
return plot
end
end
end
end
return nil
end

local function getDefensePodiumPositions(plot)
    local pos = {}
    local folder = plot:FindFirstChild("AnimalPodiums")
    if not folder then return pos end
    for i = 1, 10 do
        local p = folder:FindFirstChild(tostring(i))
        if p then
            table.insert(pos, p:GetPivot().Position)
        end
    end
    return pos
end

task.spawn(function()
    task.wait(2)
    defensePlot = findDefensePlot()
    if defensePlot then
        defensePodiums = getDefensePodiumPositions(defensePlot)
    end
end)

-- Anti TP Scam detection loop
task.spawn(function()
    while _G.ZenoHubAlive and task.wait(0.1) do
        if AntiTPEnabled() and defensePlot and #defensePodiums > 0 then
            local player = Players.LocalPlayer
            for _, plr in Players:GetPlayers() do
                if plr ~= player and plr.Character then
                    local root = plr.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        for _, pos in ipairs(defensePodiums) do
                            if (root.Position - pos).Magnitude < defenseTPThreshold then
                                -- Anti TP Scam defense
                                if AntiTPEnabled() then
                                    if (tick() - lastDefenseExecuteTime) > 0.5 then
                                        defenseTarget1 = plr
                                        lastDefenseExecuteTime = tick()
                                        defenseRunCommands()
                                    end
                                end
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

do
    local panel, defenseContent = createMiniPanel("Zeno Defense", UDim2.new(0.7, 0, 0.15, 0), UDim2.new(0, 200, 0, 0))
    createMiniToggle(defenseContent, "Auto Defense", 1, function(state)
        AutoDefenseEnabled = state
    end)
    createMiniToggle(defenseContent, "Anti TP Scam", 2, function(state)
        AntiTPEnabled_state = state
        if state then
            task.spawn(function()
                local hitboxStates = {}
                -- hitboxStates[uid] = nil (never entered), "in" (currently inside), "out" (left, eligible for ragdoll on reentry)
                while AntiTPEnabled_state and task.wait(0.05) do
                    local hitbox = getStealHitbox()
                    if not hitbox then continue end
                    local cf = hitbox.CFrame
                    local size = hitbox.Size
                    local hx, hz = size.X * 0.5, size.Z * 0.5
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local uid = p.UserId
                                local rel = cf:PointToObjectSpace(hrp.Position)
                                local inside = math.abs(rel.X) <= hx and math.abs(rel.Z) <= hz

                                if inside then
                                    if hitboxStates[uid] == nil then
                                        -- first entry = instant balloon + jail
                                        hitboxStates[uid] = "in"
                                        defenseTarget1 = p
                                        defenseExecuteCommandsOnPlayer(p, {"balloon", "jail"})
                                    elseif hitboxStates[uid] == "out" then
                                        -- re-entry = instant ragdoll
                                        hitboxStates[uid] = "in"
                                        defenseTarget1 = p
                                        defenseExecuteCommandsOnPlayer(p, {"ragdoll"})
                                    end
                                    -- if already "in" do nothing
                                else
                                    if hitboxStates[uid] == "in" then
                                        -- they left
                                        hitboxStates[uid] = "out"
                                    end
                                end
                            end
                        end
                    end
                end
            end)
        end
    end)
    MiniPanels["defense_panel"] = panel
end


do
    local panel, content = createMiniPanel(
        "Zeno Admin Spammer",
        UDim2.new(0.7, 0, 0.35, 0),
        UDim2.new(0, 220, 0, 0)
    )

    -- divider (optional)
    createInstance("Frame", {
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = COLORS.SectionBorder,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        LayoutOrder = 1,
    }, content)

    -- ðŸ”¥ MAIN TOGGLE (ONLY THING YOU NEED)
    createMiniToggle(content, "Admin Spammer", 2, function(state)
        local _player = Players.LocalPlayer
        local gui = _G.ZenoAdminPanelInstance

        if state then
            if not gui or not gui.Parent then
                openAdminSpammerUI()
            end
        else
            if _G.ZenoAdminPanelInstance then
                pcall(function() _G.ZenoAdminPanelInstance:Destroy() end)
                _G.ZenoAdminPanelInstance = nil
            end
            _G.AdminSpammerRunning = false
        end
    end)

    MiniPanels["admin_spammer"] = panel
end

do
    local panel, content = createMiniPanel("Actions Panel", UDim2.new(0.75, 0, 0.55, 0), UDim2.new(0, 190, 0, 0))

    local actionDefs = {
        { id = "action_rejoin", label = "Rejoin", order = 1, fn = function()
            local TeleportService = game:GetService("TeleportService")
            TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
        end },
        { id = "action_kick", label = "Kick Self", order = 2, fn = function()
            Players.LocalPlayer:Kick("Kicking Player | By Zeno")
        end },
        { id = "action_ragdoll", label = "Ragdoll Self", order = 3, fn = (function()
    -- Persistent caches (survive between calls)
    local selfCommandCache = {}
    local selfProfileCache = {}

    local function selfCacheActivated(guiObject)
        local cached = {}
        local ok, conns = pcall(getconnections, guiObject.Activated)
        if ok and type(conns) == "table" then
            for _, conn in ipairs(conns) do
                if type(conn.Function) == "function" then
                    table.insert(cached, conn.Function)
                end
            end
        end
        return cached
    end

    local function selfFireActivated(cached)
        for _, fn in ipairs(cached) do
            task.spawn(fn)
        end
    end

    local function selfGetAdminFrames()
        local adminPanel = LocalPlayer.PlayerGui:FindFirstChild("AdminPanel")
        if not adminPanel then return end

        local panel = adminPanel:FindFirstChild("AdminPanel")
        if not panel then return end

        local content = panel:FindFirstChild("Content")
        local profiles = panel:FindFirstChild("Profiles")
        if not content or not profiles then return end

        return content:FindFirstChild("ScrollingFrame"), profiles:FindFirstChild("ScrollingFrame")
    end

    return function()
        local commandFrame, profileFrame = selfGetAdminFrames()
        if not commandFrame or not profileFrame then return end

        local profileButton = profileFrame:FindFirstChild(LocalPlayer.Name)
        local ragdollButton = commandFrame:FindFirstChild("ragdoll")

        if not profileButton or not ragdollButton then return end

        if not selfProfileCache[LocalPlayer.Name] then
            selfProfileCache[LocalPlayer.Name] = selfCacheActivated(profileButton)
        end

        if not selfCommandCache["ragdoll"] then
            selfCommandCache["ragdoll"] = selfCacheActivated(ragdollButton)
        end

        -- ðŸ”¥ FIRE COMMAND (your 2-line fix handles the rest)
        selfFireActivated(selfCommandCache["ragdoll"])
        task.wait()
        selfFireActivated(selfProfileCache[LocalPlayer.Name])
    end
end)() },
        { id = "action_reset", label = "Reset Character", order = 4, fn = function()
            local char = Players.LocalPlayer.Character
            if char then char:Destroy() end
        end },
    }

    for _, def in ipairs(actionDefs) do
        local btn = createMiniButton(content, def.label, def.order)

        local bindLabel = createInstance("TextLabel", {
            Name = "BindLabel",
            Size = UDim2.new(0, 50, 1, 0),
            Position = UDim2.new(1, -55, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.BindText,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
        }, btn)

        ToggleElements[def.id] = { bindLabel = bindLabel }
        ActionCallbacks[def.id] = def.fn

        -- Load saved keybind
        if Config.keybinds[def.id] then
            local ok, key = pcall(function() return Enum.KeyCode[Config.keybinds[def.id]] end)
            if ok and key then
                Keybinds[def.id] = key
                updateBindLabel(def.id)
            end
        end

        btn.MouseButton1Click:Connect(function()
            pcall(def.fn)
        end)

        btn.MouseButton2Click:Connect(function()
            if ListeningId == def.id then
                ListeningId = nil
                updateBindLabel(def.id)
                return
            end
            local prev = ListeningId
            ListeningId = def.id
            if prev then updateBindLabel(prev) end
            updateBindLabel(def.id)
        end)
    end

    panel.Visible = true
    MiniPanels["_actions"] = panel
end

-- =============================================
-- BUILD TOGGLE ROWS (MAIN UI)
-- =============================================

local NO_KEYBIND_IDS = { command_cooldowns = true, quick_admin_panel = true }

local function buildToggleRow(item, parent)
    local id = item.id
    local isOn = Config.toggles[id] or false
    local allowBind = not NO_KEYBIND_IDS[id]
    
    local row = createInstance("Frame", {
        Name = "Row_" .. id,
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
    }, parent)

    local hoverFrame = createInstance("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = COLORS.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ZIndex = 0,
    }, row)
    addCorner(hoverFrame, 4)

    local label = createInstance("TextButton", {
        Name = "Label",
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 12, 0, 0),
        BackgroundTransparency = 1,
        Text = item.label,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
    }, row)

    local bindLabel = nil
    if allowBind then
        bindLabel = createInstance("TextLabel", {
            Name = "BindLabel",
            Size = UDim2.new(0, 60, 1, 0),
            Position = UDim2.new(1, -68, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.BindText,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Right,
            Visible = false,
        }, label)
    end

    local switch = createInstance("Frame", {
        Name = "Switch",
        Size = UDim2.new(0, 38, 0, 20),
        Position = UDim2.new(1, -52, 0.5, -10),
        BackgroundColor3 = isOn and COLORS.ToggleOn or COLORS.ToggleOff,
        BorderSizePixel = 0,
    }, row)
    addCorner(switch, 10)
    addStroke(switch, Color3.fromRGB(80, 50, 140), 1)

    local knob = createInstance("Frame", {
        Name = "Knob",
        Size = UDim2.new(0, 16, 0, 16),
        Position = isOn and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = isOn and COLORS.KnobOn or COLORS.KnobOff,
        BorderSizePixel = 0,
    }, switch)
    addCorner(knob, 8)

    Toggles[id] = isOn
    ToggleElements[id] = {
        switch = switch,
        knob = knob,
        label = label,
        bindLabel = bindLabel,
        row = row,
    }

    local switchBtn = createInstance("TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 5,
    }, switch)
    
    switchBtn.MouseButton1Click:Connect(function()
        local newState = not Toggles[id]
        Toggles[id] = newState
        Config.toggles[id] = newState
        saveConfig()
        
        -- Smooth tween animations
        TweenService:Create(switch, 
            TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {BackgroundColor3 = newState and COLORS.ToggleOn or COLORS.ToggleOff}
        ):Play()
        
        TweenService:Create(knob,
            TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            {
                Position = newState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
                BackgroundColor3 = newState and COLORS.KnobOn or COLORS.KnobOff
            }
        ):Play()
        
        -- Run handler (pcall so errors don't break toggle visuals)
        local handler = ToggleHandlers[id]
        if handler then
            local ok, err = pcall(handler, newState)
            if not ok then
                warn("[Zeno Hub] Toggle handler error for '" .. tostring(id) .. "': " .. tostring(err))
            end
        end
        
        -- Show/hide mini panel
        showMiniPanel(id, newState)
    end)

    -- Hover effects
    row.MouseEnter:Connect(function()
        tween(hoverFrame, { BackgroundTransparency = 0.92 }, 0.15)
    end)
    row.MouseLeave:Connect(function()
        tween(hoverFrame, { BackgroundTransparency = 1 }, 0.15)
    end)

    -- Keybind (right click) - excluded for command_cooldowns, quick_admin_panel, admin_spammer
    if allowBind then
        label.MouseButton2Click:Connect(function()
            if ListeningId == id then
                ListeningId = nil
                updateBindLabel(id)
                return
            end
            local prev = ListeningId
            ListeningId = id
            if prev then updateBindLabel(prev) end
            updateBindLabel(id)
        end)
    end

    return row
end

local function buildSection(sectionData, parent)
    local container = createInstance("Frame", {
        Name = "Section_" .. sectionData.title,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
    }, parent)

    createInstance("TextLabel", {
        Name = "SectionTitle",
        Size = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        Text = sectionData.title,
        Font = Enum.Font.GothamBold,
        TextColor3 = COLORS.SectionTitle,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTransparency = 0.2,
    }, container)

    local body = createInstance("Frame", {
        Name = "SectionBody",
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 0, 22),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = COLORS.SectionBG,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, container)
    addCorner(body, 8)
    addStroke(body, COLORS.SectionBorder, 1)

    createInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
    }, body)

    createInstance("UIPadding", {
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 2),
    }, body)

    for _, item in ipairs(sectionData.items) do
        buildToggleRow(item, body)
    end

    return container
end

local function buildTabContent(tabIndex, tabInfo)
    local frame = createInstance("Frame", {
        Name = "Tab_" .. tabInfo.name,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1,
        Visible = (tabIndex == 1),
    }, ContentArea)

    createInstance("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 12),
    }, frame)

    for _, section in ipairs(tabInfo.sections) do
        buildSection(section, frame)
    end

    TabFrames[tabIndex] = frame
end

-- =============================================
-- BUILD TABS
-- =============================================

for i, tabInfo in ipairs(TabData) do
    local btn = createInstance("TextButton", {
        Name = "Tab_" .. tabInfo.name,
        Size = UDim2.new(0, isMobile and 75 or 80, 0, isMobile and 34 or 30),
        BackgroundColor3 = (i == 1) and COLORS.TabActive or COLORS.TabInactive,
        BorderSizePixel = 0,
        Text = tabInfo.name,
        Font = Enum.Font.GothamBold,
        TextColor3 = (i == 1) and COLORS.Text or COLORS.TextDim,
        TextSize = isMobile and 9 or 12,
        AutoButtonColor = false,
        LayoutOrder = i,
    }, TabBar)
    addCorner(btn, 7)

    if i == 1 then
        addStroke(btn, COLORS.AccentBright, 0).Name = "ActiveStroke"
    end

    TabButtons[i] = btn

    btn.MouseButton1Click:Connect(function()
        if ActiveTab == i then return end

        local oldBtn = TabButtons[ActiveTab]
        tween(oldBtn, { BackgroundColor3 = COLORS.TabInactive, TextColor3 = COLORS.TextDim }, 0.2)
        local oldStroke = oldBtn:FindFirstChild("ActiveStroke")
        if oldStroke then oldStroke:Destroy() end
        TabFrames[ActiveTab].Visible = false

        ActiveTab = i
        tween(btn, { BackgroundColor3 = COLORS.TabActive, TextColor3 = COLORS.Text }, 0.2)
        addStroke(btn, COLORS.AccentBright, 0).Name = "ActiveStroke"
        TabFrames[i].Visible = true

        ContentArea.CanvasPosition = Vector2.new(0, 0)
    end)

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= i then
            tween(btn, { BackgroundColor3 = COLORS.TabHover }, 0.15)
        end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= i then
            tween(btn, { BackgroundColor3 = COLORS.TabInactive }, 0.15)
        end
    end)

    buildTabContent(i, tabInfo)
end

-- =============================================
-- INPUT HANDLING (keybinds)
-- =============================================

UIS.InputBegan:Connect(function(input_obj, gameProcessed)
    -- Block keybinds while typing in chat/textboxes or game is not focused
    if gameProcessed then return end
    if UIS:GetFocusedTextBox() then return end

    if not ListeningId then
        if input_obj.UserInputType == Enum.UserInputType.Keyboard then
            for id, keyCode in pairs(Keybinds) do
                if input_obj.KeyCode == keyCode then
                    if ActionCallbacks[id] then
                        pcall(ActionCallbacks[id])
                    else
                        toggleFeature(id)
                    end
                    break
                end
            end
        end
        return
    end

    if input_obj.UserInputType == Enum.UserInputType.Keyboard then
        local currentId = ListeningId

        if input_obj.KeyCode == Enum.KeyCode.Backspace then
            Keybinds[currentId] = nil
            Config.keybinds[currentId] = nil
            ListeningId = nil
            updateBindLabel(currentId)
            saveConfig()
        elseif input_obj.KeyCode == Enum.KeyCode.Escape then
            ListeningId = nil
            updateBindLabel(currentId)
        else
            for otherId, otherKey in pairs(Keybinds) do
                if otherKey == input_obj.KeyCode and otherId ~= currentId then
                    Keybinds[otherId] = nil
                    Config.keybinds[otherId] = nil
                    updateBindLabel(otherId)
                end
            end

            Keybinds[currentId] = input_obj.KeyCode
            Config.keybinds[currentId] = input_obj.KeyCode.Name
            ListeningId = nil
            updateBindLabel(currentId)
            saveConfig()
        end
    end
end)

-- Blinking cursor for keybind listening
task.spawn(function()
    local visible = true
    while _G.ZenoHubAlive and ScreenGui and ScreenGui.Parent do
        task.wait(0.5)
        if ListeningId then
            local el = ToggleElements[ListeningId]
            if el and el.bindLabel then
                visible = not visible
                el.bindLabel.TextTransparency = visible and 0 or 0.6
            end
        end
    end
end)

-- =============================================
-- OPEN ANIMATION
-- =============================================

MainFrame.Size = UDim2.new(0, 320 * getScaleFactor(), 0, 0)
MainFrame.BackgroundTransparency = 1
tween(MainFrame, { Size = UDim2.new(0, 320 * getScaleFactor(), 0, 400 * getScaleFactor()), BackgroundTransparency = 0.02 }, 0.35)

-- =============================================
-- TOGGLE UI VISIBILITY (Left Ctrl)
-- =============================================

UIS.InputBegan:Connect(function(input_obj, gameProcessed)
    if gameProcessed then return end
    if input_obj.UserInputType ~= Enum.UserInputType.Keyboard then return end

    if input_obj.KeyCode == Enum.KeyCode.LeftControl then
        UI_OPEN = not UI_OPEN

        if UI_OPEN then
            MainFrame.Visible = true
            uiScale.Scale = 0.3

            tween(uiScale, { Scale = getScaleFactor() }, 0.35)
        else
            tween(uiScale, {
                Scale = 0.3
            }, 0.25)

            task.delay(0.25, function()
                MainFrame.Visible = false
            end)
        end
    end
end)

-- =============================================
-- RESTORE SAVED TOGGLE STATES (single unified block)
-- =============================================


-- One-click actions that should never auto-fire on restore
local SKIP_ON_RESTORE = {
    instant_reset = true,
    carpet_tp_base = true,
}

task.defer(function()
    for id, state in pairs(Config.toggles) do
        -- Skip one-click actions and force them off
        if SKIP_ON_RESTORE[id] then
            Config.toggles[id] = false
            Toggles[id] = false
            setToggleVisual(id, false)
            continue
        end

        if state then
            -- Restore the toggle state variable + visual
            Toggles[id] = true
            pcall(setToggleVisual, id, true)

            -- Fire the toggle handler to re-enable the feature (pcall so one error doesn't break all)
            local handler = ToggleHandlers[id]
            if handler then
                local ok, err = pcall(handler, true)
                if not ok then
                    warn("[Zeno Hub] Restore handler error for '" .. tostring(id) .. "': " .. tostring(err))
                end
            end

            -- Also re-show mini panels so panel-based features work after rejoin
            if MiniPanels[id] then
                pcall(showMiniPanel, id, true)
            end
        end
    end

    -- Booster state is now auto-restored by createMiniToggle's onToggle callback

    -- Restore keybinds from saved config
    for id, keyName in pairs(Config.keybinds) do
        local ok, keyCode = pcall(function()
            return Enum.KeyCode[keyName]
        end)
        if ok and keyCode then
            Keybinds[id] = keyCode
            updateBindLabel(id)
        end
    end
end)
end -- initUI

do
    -- Only create the UI if on mobile
    if not isMobile then
        -- Still register empty MiniPanels entries so toggle handlers don't error
        MiniPanels["grapple_speed"] = Instance.new("Frame") -- invisible dummy
        MiniPanels["carpet_tp_base"] = Instance.new("Frame")
    else
        -- =============================================
        -- GRAPPLE SPEED MINI PANEL (Mobile Only)
        -- =============================================
        local carpetPanel, carpetContent = createMiniPanel(
            "Speed Controls",
            UDim2.new(0.5, -100, 0.1, 0),  -- top-center of screen
            UDim2.new(0, 220, 0, 0)
        )

        -- Override position for mobile (lower so it's reachable by thumb)
        carpetPanel.Position = UDim2.new(0.5, -110, 0.75, 0)
        carpetPanel.Size = UDim2.new(0, 220, 0, 0)  -- AutomaticSize handles height

        -- â”€â”€ Grapple Speed toggle â”€â”€
        local _carpetSpeedRow, _getCarpetSpeedState = createMiniToggle(
            carpetContent,
            "Grapple Speed",
            1,
            function(isOn)
                -- Call the existing toggle handler
                if ToggleHandlers.grapple_speed then
                    ToggleHandlers.grapple_speed(isOn)
                end
                -- Sync the main UI toggle visual
                pcall(setToggleVisual, "grapple_speed", isOn)
                Toggles["grapple_speed"] = isOn
                Config.toggles["grapple_speed"] = isOn
                saveConfig()
            end,
            "mobile_carpet_speed"
        )

        -- Sub-label under "Grapple Speed"
        local carpetSpeedSub = Instance.new("TextLabel")
        carpetSpeedSub.Size = UDim2.new(1, -16, 0, 14)
        carpetSpeedSub.BackgroundTransparency = 1
        carpetSpeedSub.Text = "Grapple Speed"
        carpetSpeedSub.Font = Enum.Font.Gotham
        carpetSpeedSub.TextSize = 10
        carpetSpeedSub.TextColor3 = COLORS.TextDim
        carpetSpeedSub.TextXAlignment = Enum.TextXAlignment.Left
        carpetSpeedSub.LayoutOrder = 2
        carpetSpeedSub.Parent = carpetContent

        -- Divider
        createInstance("Frame", {
            Size = UDim2.new(1, 0, 0, 1),
            BackgroundColor3 = COLORS.SectionBorder,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            LayoutOrder = 3,
        }, carpetContent)

        -- â”€â”€ Carpet TP Next Base toggle â”€â”€
        local _carpetTPRow, _getCarpetTPState = createMiniToggle(
            carpetContent,
            "Carpet Teleport",
            4,
            function(isOn)
                if isOn then
                    -- Fire the teleport, then auto-reset (one-click action)
                    if ToggleHandlers.carpet_tp_base then
                        ToggleHandlers.carpet_tp_base(true)
                    end
                end
            end,
            "mobile_carpet_tp"
        )

        -- Sub-label under "Carpet Teleport"
        local carpetTPSub = Instance.new("TextLabel")
        carpetTPSub.Size = UDim2.new(1, -16, 0, 14)
        carpetTPSub.BackgroundTransparency = 1
        carpetTPSub.Text = "Carpet Teleport Next Base"
        carpetTPSub.Font = Enum.Font.Gotham
        carpetTPSub.TextSize = 10
        carpetTPSub.TextColor3 = COLORS.TextDim
        carpetTPSub.TextXAlignment = Enum.TextXAlignment.Left
        carpetTPSub.LayoutOrder = 5
        carpetTPSub.Parent = carpetContent

        -- Register panels so the main toggle shows/hides this panel
        MiniPanels["grapple_speed"]   = carpetPanel
        MiniPanels["carpet_tp_base"]  = carpetPanel

        -- Keep this panel always visible on mobile (floating above main UI)
        -- so players can reach it with their thumb without opening the main UI
        carpetPanel.Visible = true

        -- Sync initial toggle states from config on load
        task.defer(function()
            if Config.toggles["grapple_speed"] then
                pcall(setToggleVisual, "mobile_carpet_speed", true)
            end
        end)
    end
end

initUI()
