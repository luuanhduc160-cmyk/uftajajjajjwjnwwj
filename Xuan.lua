local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait()
    LocalPlayer = Players.LocalPlayer
end

-- Remove old GUI if exists
local guiName = "FramArrowStandOutClean"
local parentGui = (gethui and gethui()) or CoreGui
if parentGui:FindFirstChild(guiName) then
    parentGui[guiName]:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = guiName
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- States (Persistent across server hops)
local autoPickEnabled = _G.AutoArrowState ~= nil and _G.AutoArrowState or false
local moveMode = _G.MoveModeState ~= nil and _G.MoveModeState or "Teleport"

local collectedCount = 0
local isCooldown = false

local tpWalkEnabled = false
local tpWalkSpeed = 50

local infJumpEnabled = false

local jumpPowerEnabled = false
local jumpPowerVal = 100

local espEnabled = false

-- Game Icon Asset
local gameIconAsset = "rbxassetid://6023426915"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.IconImageAssetId and info.IconImageAssetId > 0 then
        gameIconAsset = "rbxassetid://" .. tostring(info.IconImageAssetId)
    end
end)

-- ==========================================
-- DRAGGABLE UTILITY
-- ==========================================
local function makeDraggable(dragHandle, targetFrame)
    local dragging = false
    local dragInput, dragStart, startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = targetFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            targetFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ==========================================
-- FLOATING TOGGLE BUTTON (NO GLOW)
-- ==========================================
local FloatToggleBtn = Instance.new("ImageButton")
FloatToggleBtn.Name = "FloatToggleBtn"
FloatToggleBtn.Size = UDim2.new(0, 56, 0, 56)
FloatToggleBtn.Position = UDim2.new(0, 25, 0.3, 0)
FloatToggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
FloatToggleBtn.Image = gameIconAsset
FloatToggleBtn.AutoButtonColor = false
FloatToggleBtn.ZIndex = 10
FloatToggleBtn.Parent = ScreenGui

Instance.new("UICorner", FloatToggleBtn).CornerRadius = UDim.new(1, 0)

-- ==========================================
-- MAIN GUI
-- ==========================================
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 640, 0, 400)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundTransparency = 1
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local uiVisible = true
FloatToggleBtn.MouseButton1Down:Connect(function()
    uiVisible = not uiVisible
    MainFrame.Visible = uiVisible
    TweenService:Create(FloatToggleBtn, TweenInfo.new(0.15), {
        ImageTransparency = uiVisible and 0 or 0.4
    }):Play()
end)

-- Background Image
local BgImage = Instance.new("ImageLabel")
BgImage.Size = UDim2.new(1, 0, 1, 0)
BgImage.BackgroundTransparency = 1
BgImage.Image = gameIconAsset
BgImage.ImageTransparency = 0.15
BgImage.ScaleType = Enum.ScaleType.Crop
BgImage.Parent = MainFrame
Instance.new("UICorner", BgImage).CornerRadius = UDim.new(0, 20)

-- Dark overlay
local DarkOverlay = Instance.new("Frame")
DarkOverlay.Size = UDim2.new(1, 0, 1, 0)
DarkOverlay.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
DarkOverlay.BackgroundTransparency = 0.4
DarkOverlay.ZIndex = 2
DarkOverlay.Parent = MainFrame
Instance.new("UICorner", DarkOverlay).CornerRadius = UDim.new(0, 20)

-- Top Bar Title
local TopBar = Instance.new("TextLabel")
TopBar.Size = UDim2.new(1, -40, 0, 48)
TopBar.Position = UDim2.new(0, 20, 0, 15)
TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
TopBar.BackgroundTransparency = 0.3
TopBar.Text = "  Farm Arrow - Stand Out - xuân"
TopBar.TextColor3 = Color3.fromRGB(255, 220, 100)
TopBar.TextSize = 17
TopBar.Font = Enum.Font.GothamBold
TopBar.TextXAlignment = Enum.TextXAlignment.Left
TopBar.ZIndex = 3
TopBar.Parent = MainFrame
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 12)

makeDraggable(TopBar, MainFrame)
makeDraggable(FloatToggleBtn, FloatToggleBtn)

-- ==========================================
-- MAIN SECTION: FARM ARROW
-- ==========================================
local MainControlFrame = Instance.new("Frame")
MainControlFrame.Size = UDim2.new(1, -40, 0, 145)
MainControlFrame.Position = UDim2.new(0, 20, 0, 75)
MainControlFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 22)
MainControlFrame.BackgroundTransparency = 0.35
MainControlFrame.ZIndex = 3
MainControlFrame.Parent = MainFrame
Instance.new("UICorner", MainControlFrame).CornerRadius = UDim.new(0, 14)

local CounterLabel = Instance.new("TextLabel")
CounterLabel.Size = UDim2.new(1, -150, 0, 28)
CounterLabel.Position = UDim2.new(0, 12, 0, 8)
CounterLabel.BackgroundTransparency = 1
CounterLabel.Text = "Collected: 0"
CounterLabel.TextColor3 = Color3.fromRGB(220, 240, 255)
CounterLabel.TextSize = 14
CounterLabel.Font = Enum.Font.GothamSemibold
CounterLabel.TextXAlignment = Enum.TextXAlignment.Left
CounterLabel.ZIndex = 4
CounterLabel.Parent = MainControlFrame

-- Mode Selector (TP / Tween)
local ModeSelectBtn = Instance.new("TextButton")
ModeSelectBtn.Size = UDim2.new(0, 125, 0, 26)
ModeSelectBtn.Position = UDim2.new(1, -135, 0, 8)
ModeSelectBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
ModeSelectBtn.BackgroundTransparency = 0.3
ModeSelectBtn.Text = "Mode: " .. moveMode .. " >"
ModeSelectBtn.TextColor3 = Color3.fromRGB(255, 220, 100)
ModeSelectBtn.TextSize = 12
ModeSelectBtn.Font = Enum.Font.GothamBold
ModeSelectBtn.ZIndex = 5
ModeSelectBtn.Parent = MainControlFrame
Instance.new("UICorner", ModeSelectBtn).CornerRadius = UDim.new(0, 6)

local ModeDropdown = Instance.new("Frame")
ModeDropdown.Size = UDim2.new(0, 125, 0, 60)
ModeDropdown.Position = UDim2.new(1, -135, 0, 36)
ModeDropdown.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
ModeDropdown.BackgroundTransparency = 0.2
ModeDropdown.Visible = false
ModeDropdown.ZIndex = 6
ModeDropdown.Parent = MainControlFrame
Instance.new("UICorner", ModeDropdown).CornerRadius = UDim.new(0, 6)

local tpOption = Instance.new("TextButton")
tpOption.Size = UDim2.new(1, 0, 0, 30)
tpOption.BackgroundColor3 = (moveMode == "Teleport") and Color3.fromRGB(40, 185, 95) or Color3.fromRGB(30, 30, 40)
tpOption.Text = "Teleport"
tpOption.TextColor3 = Color3.fromRGB(255, 255, 255)
tpOption.TextSize = 12
tpOption.Font = Enum.Font.GothamSemibold
tpOption.ZIndex = 7
tpOption.Parent = ModeDropdown
Instance.new("UICorner", tpOption).CornerRadius = UDim.new(0, 6)

local tweenOption = Instance.new("TextButton")
tweenOption.Size = UDim2.new(1, 0, 0, 30)
tweenOption.Position = UDim2.new(0, 0, 0, 30)
tweenOption.BackgroundColor3 = (moveMode == "Tween") and Color3.fromRGB(40, 185, 95) or Color3.fromRGB(30, 30, 40)
tweenOption.Text = "Tween (100)"
tweenOption.TextColor3 = Color3.fromRGB(255, 255, 255)
tweenOption.TextSize = 12
tweenOption.Font = Enum.Font.GothamSemibold
tweenOption.ZIndex = 7
tweenOption.Parent = ModeDropdown
Instance.new("UICorner", tweenOption).CornerRadius = UDim.new(0, 6)

ModeSelectBtn.MouseButton1Down:Connect(function()
    ModeDropdown.Visible = not ModeDropdown.Visible
end)

tpOption.MouseButton1Down:Connect(function()
    moveMode = "Teleport"
    _G.MoveModeState = moveMode
    ModeSelectBtn.Text = "Mode: Teleport >"
    tpOption.BackgroundColor3 = Color3.fromRGB(40, 185, 95)
    tweenOption.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ModeDropdown.Visible = false
end)

tweenOption.MouseButton1Down:Connect(function()
    moveMode = "Tween"
    _G.MoveModeState = moveMode
    ModeSelectBtn.Text = "Mode: Tween >"
    tweenOption.BackgroundColor3 = Color3.fromRGB(40, 185, 95)
    tpOption.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    ModeDropdown.Visible = false
end)

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -24, 0, 26)
StatusLabel.Position = UDim2.new(0, 12, 0, 36)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = Color3.fromRGB(190, 200, 220)
StatusLabel.TextSize = 13
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 4
StatusLabel.Parent = MainControlFrame

-- Big Toggle Button
local ToggleBtn = Instance.new("TextButton")
ToggleBtn.Size = UDim2.new(1, -24, 0, 58)
ToggleBtn.Position = UDim2.new(0, 12, 0, 72)
ToggleBtn.BackgroundColor3 = autoPickEnabled and Color3.fromRGB(40, 185, 95) or Color3.fromRGB(190, 50, 50)
ToggleBtn.BackgroundTransparency = 0.1
ToggleBtn.Text = autoPickEnabled and "Farm Arrow: ON" or "Farm Arrow: OFF"
ToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleBtn.TextSize = 17
ToggleBtn.Font = Enum.Font.GothamBold
ToggleBtn.AutoButtonColor = false
ToggleBtn.ZIndex = 4
ToggleBtn.Parent = MainControlFrame
Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 12)

-- ==========================================
-- SCROLLING SECTION (SECONDARY FEATURES)
-- ==========================================
local ScrollingContainer = Instance.new("ScrollingFrame")
ScrollingContainer.Size = UDim2.new(1, -40, 0, 145)
ScrollingContainer.Position = UDim2.new(0, 20, 0, 232)
ScrollingContainer.BackgroundTransparency = 1
ScrollingContainer.CanvasSize = UDim2.new(0, 0, 0, 320)
ScrollingContainer.ScrollBarThickness = 6
ScrollingContainer.ZIndex = 3
ScrollingContainer.Parent = MainFrame

local UIList = Instance.new("UIListLayout")
UIList.SortOrder = Enum.SortOrder.LayoutOrder
UIList.Padding = UDim.new(0, 10)
UIList.Parent = ScrollingContainer

-- Slider Creator (Max 1000)
local function createSlider(parent, title, minVal, maxVal, defaultVal, callback)
    local sliderFrame = Instance.new("Frame")
    sliderFrame.Size = UDim2.new(1, 0, 0, 48)
    sliderFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    sliderFrame.BackgroundTransparency = 0.4
    sliderFrame.ZIndex = 4
    sliderFrame.Parent = parent
    Instance.new("UICorner", sliderFrame).CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -16, 0, 20)
    label.Position = UDim2.new(0, 8, 0, 4)
    label.BackgroundTransparency = 1
    label.Text = title .. ": " .. tostring(defaultVal)
    label.TextColor3 = Color3.fromRGB(220, 230, 255)
    label.TextSize = 12
    label.Font = Enum.Font.GothamSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.ZIndex = 5
    label.Parent = sliderFrame
    
    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, -16, 0, 8)
    bar.Position = UDim2.new(0, 8, 0, 30)
    bar.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    bar.BorderSizePixel = 0
    bar.ZIndex = 5
    bar.Parent = sliderFrame
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)
    
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((defaultVal - minVal)/(maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(40, 185, 95)
    fill.BorderSizePixel = 0
    fill.ZIndex = 6
    fill.Parent = bar
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    
    local val = defaultVal
    local draggingSlider = false
    
    local function updateInput(input)
        local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(pos, 0, 1, 0)
        val = math.floor(minVal + pos * (maxVal - minVal))
        label.Text = title .. ": " .. tostring(val)
        callback(val)
    end
    
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateInput(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateInput(input)
        end
    end)
    
    return sliderFrame
end

-- Toggle with Slider Creator
local function createFeatureToggleWithSlider(name, defaultState, defaultValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, defaultState and 102 or 48)
    container.BackgroundTransparency = 1
    container.ZIndex = 4
    container.Parent = ScrollingContainer
    
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 48)
    btn.BackgroundColor3 = defaultState and Color3.fromRGB(40, 185, 95) or Color3.fromRGB(25, 25, 35)
    btn.BackgroundTransparency = 0.3
    btn.Text = name .. ": " .. (defaultState and "ON" or "OFF")
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.ZIndex = 5
    btn.Parent = container
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    
    local sliderObj = nil
    if defaultValue then
        sliderObj = createSlider(container, name .. " Value", 1, 1000, defaultValue, function(val)
            callback(true, val)
        end)
        sliderObj.Position = UDim2.new(0, 0, 0, 54)
        sliderObj.Visible = defaultState
    end
    
    local state = defaultState
    btn.MouseButton1Down:Connect(function()
        state = not state
        btn.Text = name .. ": " .. (state and "ON" or "OFF")
        TweenService:Create(btn, TweenInfo.new(0.15), {
            BackgroundColor3 = state and Color3.fromRGB(40, 185, 95) or Color3.fromRGB(25, 25, 35)
        }):Play()
        
        if sliderObj then
            sliderObj.Visible = state
            container.Size = UDim2.new(1, 0, 0, state and 102 or 48)
        end
        
        if defaultValue then
            callback(state, defaultValue)
        else
            callback(state)
        end
    end)
    return container
end

-- Action Button Creator
local function createActionButton(name, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 48)
    btn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
    btn.BackgroundTransparency = 0.3
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 14
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.ZIndex = 4
    btn.Parent = ScrollingContainer
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(70, 150, 255)}):Play()
        task.wait(0.1)
        TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(45, 120, 210)}):Play()
        callback()
    end)
end

-- 1. TP Walk
createFeatureToggleWithSlider("TP Walk", false, 50, function(state, val)
    tpWalkEnabled = state
    if val then tpWalkSpeed = val end
end)

-- 2. Inf Jump
createFeatureToggleWithSlider("Inf Jump", false, nil, function(state)
    infJumpEnabled = state
end)

-- 3. Jump Power
createFeatureToggleWithSlider("Jump Power", false, 100, function(state, val)
    jumpPowerEnabled = state
    if val then jumpPowerVal = val end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = state and jumpPowerVal or 50
    end
end)

-- 4. TP Random
createActionButton("TP Random", function()
    pcall(function()
        local pList = Players:GetPlayers()
        local targets = {}
        for _, p in ipairs(pList) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(targets, p.Character.HumanoidRootPart)
            end
        end
        if #targets > 0 then
            local chosen = targets[math.random(1, #targets)]
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = chosen.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end)
end)

-- 5. Player ESP
createFeatureToggleWithSlider("Player ESP", false, nil, function(state)
    espEnabled = state
end)

-- ==========================================
-- FEATURE LOGIC
-- ==========================================
UserInputService.JumpRequest:Connect(function()
    if infJumpEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if tpWalkEnabled then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.MoveDirection.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + (hum.MoveDirection * (tpWalkSpeed / 100))
        end
    end
    
    if jumpPowerEnabled then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = jumpPowerVal
        end
    end
end)

-- Rainbow ESP
local espGuiCache = {}

local function removeEsp(player)
    if espGuiCache[player] then
        pcall(function() espGuiCache[player]:Destroy() end)
        espGuiCache[player] = nil
    end
end

local function addEsp(player)
    if player == LocalPlayer then return end
    removeEsp(player)
    
    local function setupCharacter(char)
        local head = char:WaitForChild("Head", 5)
        if not head then return end
        
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "ServerPlayerESP"
        billboard.Adornee = head
        billboard.Size = UDim2.new(0, 120, 0, 40)
        billboard.StudsOffset = Vector3.new(0, 2.8, 0)
        billboard.AlwaysOnTop = true
        
        local txt = Instance.new("TextLabel")
        txt.Size = UDim2.new(1, 0, 1, 0)
        txt.BackgroundTransparency = 1
        txt.Text = player.Name
        txt.TextSize = 13
        txt.Font = Enum.Font.GothamBold
        txt.TextColor3 = Color3.fromRGB(255, 255, 255)
        txt.TextStrokeTransparency = 0.4
        txt.Parent = billboard
        
        billboard.Parent = head
        espGuiCache[player] = billboard
    end
    
    if player.Character then
        task.spawn(function() setupCharacter(player.Character) end)
    end
    player.CharacterAdded:Connect(setupCharacter)
end

for _, p in ipairs(Players:GetPlayers()) do
    addEsp(p)
end
Players.PlayerAdded:Connect(addEsp)
Players.PlayerRemoving:Connect(removeEsp)

RunService.RenderStepped:Connect(function()
    if espEnabled then
        local hue = (tick() % 4) / 4
        local rainbowColor = Color3.fromHSV(hue, 1, 1)
        for _, billboard in pairs(espGuiCache) do
            if billboard and billboard:FindFirstChild("TextLabel") then
                billboard.TextLabel.Visible = true
                billboard.TextLabel.TextColor3 = rainbowColor
            end
        end
    else
        for _, billboard in pairs(espGuiCache) do
            if billboard and billboard:FindFirstChild("TextLabel") then
                billboard.TextLabel.Visible = false
            end
        end
    end
end)

-- ==========================================
-- SERVER HOP & STATE PERSISTENCE
-- ==========================================
local function serverHop()
    if not autoPickEnabled then return end
    StatusLabel.Text = "Status: Hopping server..."
    task.wait(0.5)
    
    if queue_on_teleport then
        queue_on_teleport([[
            _G.AutoArrowState = true
            _G.MoveModeState = "]] .. moveMode .. [["
        ]])
    end
    
    local servers = {}
    local success, page = pcall(function()
        return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    
    if success and page and page.data then
        for _, s in ipairs(page.data) do
            if type(s) == "table" and s.maxPlayers and s.playing and s.id then
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    table.insert(servers, s.id)
                end
            end
        end
    end
    
    if #servers > 0 then
        local targetServer = servers[math.random(1, #servers)]
        TeleportService:TeleportToPlaceInstance(game.PlaceId, targetServer, LocalPlayer)
    else
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
end

-- ==========================================
-- FARM ARROW LOGIC
-- ==========================================
local function isValidRealArrow(obj)
    local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    if not prompt or not prompt.Enabled then return false end
    if not prompt.Parent or not prompt.Parent:IsA("BasePart") then return false end

    local nameLower = string.lower(obj.Name)
    local actionText = string.lower(prompt.ActionText or "")
    local objectText = string.lower(prompt.ObjectText or "")
    local combinedText = nameLower .. " " .. actionText .. " " .. objectText

    if string.find(combinedText, "fake") or string.find(combinedText, "dummy") or string.find(combinedText, "rock") then
        return false
    end

    if string.find(combinedText, "arrow") or string.find(combinedText, "stand arrow") or string.find(combinedText, "mũi tên") then
        return true
    end

    return false
end

local function collectRealArrow(obj)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    local prompt = obj:FindFirstChildWhichIsA("ProximityPrompt", true)
    local targetPart = prompt and prompt.Parent
    if not targetPart or not targetPart:IsA("BasePart") then return false end

    local destCFrame = targetPart.CFrame + Vector3.new(0, 2, 0)

    if moveMode == "Teleport" then
        hrp.CFrame = destCFrame
        task.wait(0.25)
    else
        local dist = (hrp.Position - targetPart.Position).Magnitude
        local speed = 100
        local timeTaken = dist / speed
        local tweenInfo = TweenInfo.new(timeTaken, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = destCFrame})
        tween:Play()
        tween.Completed:Wait()
    end

    if prompt and prompt.Enabled and prompt.Parent then
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            local duration = prompt.HoldDuration or 0.5
            task.wait(duration + 0.1)
            prompt:InputHoldEnd()
        end
        
        task.wait(0.5)
        if prompt.Parent and prompt.Enabled then
            isCooldown = true
            StatusLabel.Text = "Status: Cooldown / Limit reached"
            return false
        else
            collectedCount = collectedCount + 1
            CounterLabel.Text = "Collected: " .. tostring(collectedCount)
            StatusLabel.Text = "Status: Collected successfully!"
            return true
        end
    end
    return false
end

-- Main Loop
task.spawn(function()
    task.wait(1.5)
    
    while true do
        task.wait(0.5)
        if autoPickEnabled and not isCooldown then
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then
                StatusLabel.Text = "Status: Waiting respawn..."
                task.wait(1)
                continue
            end

            local foundArrow = false
            
            pcall(function()
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if not autoPickEnabled or isCooldown then break end
                    if isValidRealArrow(obj) and not Players:GetPlayerFromCharacter(obj.Parent) then
                        foundArrow = true
                        StatusLabel.Text = "Status: Collecting (" .. moveMode .. ")..."
                        local success = collectRealArrow(obj)
                        if success then
                            task.wait(0.5)
                        else
                            break
                        end
                    end
                end
            end)
            
            if isCooldown then
                task.wait(6)
                isCooldown = false
            elseif autoPickEnabled and not foundArrow then
                StatusLabel.Text = "Status: No arrows -> Hopping server..."
                task.wait(1)
                serverHop()
                task.wait(5)
            end
        elseif isCooldown then
            task.wait(3)
            isCooldown = false
        end
    end
end)

-- Toggle Button Event
ToggleBtn.MouseButton1Down:Connect(function()
    autoPickEnabled = not autoPickEnabled
    _G.AutoArrowState = autoPickEnabled
    
    if autoPickEnabled then
        ToggleBtn.Text = "Farm Arrow: ON"
        StatusLabel.Text = "Status: Scanning..."
        TweenService:Create(ToggleBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(40, 185, 95)
        }):Play()
    else
        ToggleBtn.Text = "Farm Arrow: OFF"
        StatusLabel.Text = "Status: Paused"
        TweenService:Create(ToggleBtn, TweenInfo.new(0.15), {
            BackgroundColor3 = Color3.fromRGB(190, 50, 50)
        }):Play()
    end
end)

print("[Fram Arrow Clean] Script loaded successfully!")
