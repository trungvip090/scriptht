-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Очистка предыдущего запуска
if getgenv().HTrungCleanup then
    pcall(getgenv().HTrungCleanup)
end

-- Таблица состояний
local States = {
    Fly = false, FlyUp = false, FlyDown = false,
    Noclip = false, InfJump = false, AutoJump = false, AutoRun = false,
    FreeCam = false, FreeCamSpeed = 50,
    Aimbot = false, Hitbox = false, ESP = false, KillAura = false,
    Dodge = false, GodMode = false, Wallbang = false,
    AutoHatch = false, EggSpeed = 0.5,
    AutoItemTp = false, ItemTpSpeed = 0.5,
    AntiAFK = false, Fullbright = false, AutoClick = false, RemoveParticles = false,
    Speed = 16, JumpPower = 50, FlySpeed = 60, HitboxSize = 10, AuraRange = 2000
}

-- Переменные
local freeCamCFrame = CFrame.new()
local freeCamRotX, freeCamRotY = 0, 0
local freeCamInput = {F=false, B=false, L=false, R=false, U=false, D=false}
local lastAuraAttack = 0
local lastHealth = 100
local dodgeCooldown = 0
local godModeThread = nil
local oldRaycast = nil
local hatchThread = nil
local autoClickThread = nil
local autoItemTpThread = nil
local foundEggs = {}
local scannedItems = {}

local Connections = {}
local ESPObjects = {}

-- ==========================================
-- HTTP REQUEST CHO SERVER HOP
-- ==========================================
local function httpGet(url)
    if syn and syn.request then
        return syn.request({Url = url, Method = "GET"}).Body
    elseif http_request then
        return http_request({Url = url, Method = "GET"}).Body
    elseif request then
        return request({Url = url, Method = "GET"}).Body
    end
    return nil
end

-- ==========================================
-- HÀM CLICK CHUẨN CHO MOBILE
-- ==========================================
local function bindClick(button, callback)
    local lastFire = 0
    local function fire()
        local now = tick()
        if now - lastFire < 0.2 then return end
        lastFire = now
        callback()
    end

    button.Activated:Connect(fire)
    
    local pressed = false
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            pressed = true
        end
    end)
    button.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and pressed then
            pressed = false
            fire()
        end
    end)
end

local function makeDraggable(frame, dragArea)
    local dragging, dragInput, dragStart, startPos
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

local function bindHold(button, callbackDown, callbackUp)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            callbackDown()
        end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            callbackUp()
        end
    end)
end

-- ==========================================
-- HOOK WALLBANG (XUYÊN TƯỜNG)
-- ==========================================
if hookfunction and workspace.Raycast then
    oldRaycast = hookfunction(workspace.Raycast, function(self, origin, direction, params)
        if States.Wallbang and params then
            local newParams = RaycastParams.new()
            newParams.FilterType = Enum.RaycastFilterType.Include
            local chars = {}
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character then table.insert(chars, plr.Character) end
            end
            newParams.FilterDescendantsInstances = chars
            return oldRaycast(self, origin, direction, newParams)
        end
        return oldRaycast(self, origin, direction, params)
    end)
end

-- Создание GUI
local gui = Instance.new("ScreenGui")
gui.Name = "ScriptVipByHTrung"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.DisplayOrder = 2147483647

-- Nút mở menu
local openButton = Instance.new("ImageButton")
openButton.Size = UDim2.new(0, 50, 0, 50)
openButton.Position = UDim2.new(0, 10, 0, 100)
openButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
openButton.BackgroundTransparency = 0.2
openButton.BorderSizePixel = 0
openButton.ZIndex = 100
openButton.ScaleType = Enum.ScaleType.Crop 
openButton.Image = "rbxassetid://1054822530" 
openButton.Parent = gui

local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(0, 10) oc.Parent = openButton
local os = Instance.new("UIStroke") os.Color = Color3.fromRGB(255, 50, 50) os.Thickness = 2 os.Parent = openButton

-- ==========================================
-- NỔI BÊN NGOÀI: BẢNG ĐIỀU KHIỂN BAY (FLY)
-- ==========================================
local flyOverlay = Instance.new("Frame")
flyOverlay.Size = UDim2.new(0, 180, 0, 50)
flyOverlay.Position = UDim2.new(1, -200, 1, -150)
flyOverlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
flyOverlay.BackgroundTransparency = 0.3
flyOverlay.Visible = false
flyOverlay.ZIndex = 90
flyOverlay.Parent = gui
local foc = Instance.new("UICorner") foc.CornerRadius = UDim.new(0, 8) foc.Parent = flyOverlay
local fos = Instance.new("UIStroke") fos.Color = Color3.fromRGB(100, 100, 100) fos.Thickness = 1 fos.Parent = flyOverlay

local btnFlyUp = Instance.new("TextButton") btnFlyUp.Size = UDim2.new(0.45, 0, 1, -10) btnFlyUp.Position = UDim2.new(0.03, 0, 0, 5) btnFlyUp.BackgroundColor3 = Color3.fromRGB(30, 70, 30) btnFlyUp.TextColor3 = Color3.fromRGB(255, 255, 255) btnFlyUp.Font = Enum.Font.GothamBold btnFlyUp.Text = "LÊN" btnFlyUp.ZIndex = 91 btnFlyUp.Parent = flyOverlay
local uc1 = Instance.new("UICorner") uc1.CornerRadius = UDim.new(0, 6) uc1.Parent = btnFlyUp
local btnFlyDown = Instance.new("TextButton") btnFlyDown.Size = UDim2.new(0.45, 0, 1, -10) btnFlyDown.Position = UDim2.new(0.52, 0, 0, 5) btnFlyDown.BackgroundColor3 = Color3.fromRGB(70, 30, 30) btnFlyDown.TextColor3 = Color3.fromRGB(255, 255, 255) btnFlyDown.Font = Enum.Font.GothamBold btnFlyDown.Text = "XUỐNG" btnFlyDown.ZIndex = 91 btnFlyDown.Parent = flyOverlay
local dc1 = Instance.new("UICorner") dc1.CornerRadius = UDim.new(0, 6) dc1.Parent = btnFlyDown

bindHold(btnFlyUp, function() States.FlyUp = true end, function() States.FlyUp = false end)
bindHold(btnFlyDown, function() States.FlyDown = true end, function() States.FlyDown = false end)
makeDraggable(flyOverlay, flyOverlay)

-- ==========================================
-- NỔI BÊN NGOÀI: BẢNG ĐIỀU KHIỂN FREECAM
-- ==========================================
local fcOverlay = Instance.new("Frame")
fcOverlay.Size = UDim2.new(0, 180, 0, 200) 
fcOverlay.Position = UDim2.new(1, -200, 1, -380)
fcOverlay.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
fcOverlay.BackgroundTransparency = 0.3
fcOverlay.Visible = false
fcOverlay.ZIndex = 90
fcOverlay.Parent = gui
local fcoc = Instance.new("UICorner") fcoc.CornerRadius = UDim.new(0, 8) fcoc.Parent = fcOverlay
local fcos = Instance.new("UIStroke") fcos.Color = Color3.fromRGB(100, 100, 100) fcos.Thickness = 1 fcos.Parent = fcOverlay

local function createFcBtn(text, x, y, w, h, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w, 0, h, 0)
    b.Position = UDim2.new(x, 0, y, 0)
    b.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.Font = Enum.Font.GothamBold
    b.TextScaled = true
    b.Text = text
    b.ZIndex = 91
    b.Parent = fcOverlay
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
    bindHold(b, function() freeCamInput[key] = true end, function() freeCamInput[key] = false end)
    return b
end

createFcBtn("▲", 0.35, 0.05, 0.3, 0.15, "U")
createFcBtn("◀", 0.05, 0.22, 0.25, 0.15, "L")
createFcBtn("▼", 0.35, 0.4, 0.3, 0.15, "D")
createFcBtn("▶", 0.70, 0.22, 0.25, 0.15, "R")
createFcBtn("TIẾN", 0.35, 0.22, 0.3, 0.15, "F")
createFcBtn("LÙI", 0.35, 0.58, 0.3, 0.15, "B")

local teleBtn = Instance.new("TextButton")
teleBtn.Size = UDim2.new(0.9, 0, 0.15, 0)
teleBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
teleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
teleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
teleBtn.Font = Enum.Font.GothamBold
teleBtn.TextScaled = true
teleBtn.Text = "TELE ĐẾN ĐÂY"
teleBtn.ZIndex = 91
teleBtn.Parent = fcOverlay
local teCorner = Instance.new("UICorner") teCorner.CornerRadius = UDim.new(0, 6) teCorner.Parent = teleBtn

bindClick(teleBtn, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        char.HumanoidRootPart.CFrame = Camera.CFrame + Vector3.new(0, 3, 0)
    end
end)

makeDraggable(fcOverlay, fcOverlay)

-- ==========================================
-- GIAO DIỆN MENU CHÍNH
-- ==========================================
local menu = Instance.new("Frame")
menu.Size = UDim2.new(0, 500, 0, 420)
menu.Position = UDim2.new(0.5, -250, 0.5, -210)
menu.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
menu.BorderSizePixel = 0
menu.Visible = false
menu.ZIndex = 50
menu.Parent = gui
local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 8) mc.Parent = menu
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(60, 60, 60) ms.Thickness = 1 ms.Parent = menu

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Text = "Script Vip By HTrung"
title.ZIndex = 51
title.Parent = menu
local tc = Instance.new("UICorner") tc.CornerRadius = UDim.new(0, 8) tc.Parent = title

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -35, 0, 0)
closeButton.BackgroundColor3 = Color3.fromRGB(150, 30, 30)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "X"
closeButton.BorderSizePixel = 0
closeButton.ZIndex = 52
closeButton.Parent = menu

local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, 100, 1, -40)
sidebar.Position = UDim2.new(0, 5, 0, 35)
sidebar.BackgroundTransparency = 1
sidebar.BorderSizePixel = 0
sidebar.ScrollBarThickness = 2
sidebar.ZIndex = 51
sidebar.Parent = menu
local tabLayout = Instance.new("UIListLayout") tabLayout.Padding = UDim.new(0, 5) tabLayout.Parent = sidebar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -115, 1, -40)
contentFrame.Position = UDim2.new(0, 110, 0, 35)
contentFrame.BackgroundTransparency = 1
contentFrame.ZIndex = 51
contentFrame.Parent = menu

local function createTab(name)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -5, 0, 30)
    tabBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    tabBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 12
    tabBtn.Text = name
    tabBtn.BorderSizePixel = 0
    tabBtn.ZIndex = 52
    tabBtn.Parent = sidebar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = tabBtn
    
    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4
    frame.Visible = false
    frame.ZIndex = 52
    frame.Parent = contentFrame
    local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 5) layout.Parent = frame
    
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    
    bindClick(tabBtn, function()
        for _, child in pairs(contentFrame:GetChildren()) do if child:IsA("ScrollingFrame") then child.Visible = false end end
        for _, child in pairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then child.BackgroundColor3 = Color3.fromRGB(30, 30, 30) child.TextColor3 = Color3.fromRGB(200, 200, 200) end
        end
        frame.Visible = true
        tabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    end)
    return frame
end

local function createToggle(parent, text, initialState, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 30)
    btn.BackgroundColor3 = initialState and Color3.fromRGB(30, 70, 30) or Color3.fromRGB(40, 40, 40)
    btn.TextColor3 = initialState and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.Text = text .. ": " .. (initialState and "ON" or "OFF")
    btn.BorderSizePixel = 0
    btn.ZIndex = 53
    btn.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
    
    local state = initialState
    bindClick(btn, function()
        state = not state
        btn.BackgroundColor3 = state and Color3.fromRGB(30, 70, 30) or Color3.fromRGB(40, 40, 40)
        btn.TextColor3 = state and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 255, 255)
        btn.Text = text .. ": " .. (state and "ON" or "OFF")
        callback(state)
    end)
end

local function createSlider(parent, text, min, max, initial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.BackgroundTransparency = 1
    frame.ZIndex = 53
    frame.Parent = parent
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.Text = text .. ": " .. initial
    label.ZIndex = 54
    label.Parent = frame
    local lc = Instance.new("UICorner") lc.CornerRadius = UDim.new(0, 6) lc.Parent = label
    
    local minus = Instance.new("TextButton") minus.Size = UDim2.new(0.15, -2, 1, 0) minus.Position = UDim2.new(0.61, 0, 0, 0) minus.BackgroundColor3 = Color3.fromRGB(70, 30, 30) minus.TextColor3 = Color3.fromRGB(255, 255, 255) minus.Font = Enum.Font.GothamBold minus.Text = "-" minus.ZIndex = 54 minus.Parent = frame
    local minc = Instance.new("UICorner") minc.CornerRadius = UDim.new(0, 6) minc.Parent = minus
    local plus = Instance.new("TextButton") plus.Size = UDim2.new(0.15, -2, 1, 0) plus.Position = UDim2.new(0.77, 0, 0, 0) plus.BackgroundColor3 = Color3.fromRGB(30, 70, 30) plus.TextColor3 = Color3.fromRGB(255, 255, 255) plus.Font = Enum.Font.GothamBold plus.Text = "+" plus.ZIndex = 54 plus.Parent = frame
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = plus
    
    local val = initial
    local step = (max > 100 and 50 or 0.1)
    bindClick(minus, function() 
        val = math.max(min, val - step) 
        if max <= 100 then label.Text = text .. ": " .. string.format("%.1f", val) else label.Text = text .. ": " .. val end
        callback(val) 
    end)
    bindClick(plus, function() 
        val = math.min(max, val + step) 
        if max <= 100 then label.Text = text .. ": " .. string.format("%.1f", val) else label.Text = text .. ": " .. val end
        callback(val) 
    end)
end

-- ==========================================
-- VKЛАДКА 1: INFO (CẬP NHẬT AVATAR)
-- ==========================================
local infoTab = createTab("INFO")

-- Khung chứa Avatar và Tên
local profileBox = Instance.new("Frame")
profileBox.Size = UDim2.new(1, -10, 0, 80)
profileBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
profileBox.BorderSizePixel = 0
profileBox.ZIndex = 53
profileBox.Parent = infoTab
local pbc = Instance.new("UICorner") pbc.CornerRadius = UDim.new(0, 8) pbc.Parent = profileBox

-- Avatar Image
local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 60, 0, 60)
avatarImage.Position = UDim2.new(0, 10, 0.5, -30)
avatarImage.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
avatarImage.BorderSizePixel = 0
avatarImage.Image = "rbxthumb://type=Avatar&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
avatarImage.ScaleType = Enum.ScaleType.Crop
avatarImage.ZIndex = 54
avatarImage.Parent = profileBox
local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(1, 0) ac.Parent = avatarImage

-- Tên và ID
local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, -85, 0, 20)
nameLabel.Position = UDim2.new(0, 80, 0, 20)
nameLabel.BackgroundTransparency = 1
nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
nameLabel.Font = Enum.Font.GothamBold
nameLabel.TextSize = 14
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Text = LocalPlayer.DisplayName
nameLabel.ZIndex = 54
nameLabel.Parent = profileBox

local idLabel = Instance.new("TextLabel")
idLabel.Size = UDim2.new(1, -85, 0, 20)
idLabel.Position = UDim2.new(0, 80, 0, 40)
idLabel.BackgroundTransparency = 1
idLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
idLabel.Font = Enum.Font.Gotham
idLabel.TextSize = 12
idLabel.TextXAlignment = Enum.TextXAlignment.Left
idLabel.Text = "@" .. LocalPlayer.Name .. " (" .. LocalPlayer.UserId .. ")"
idLabel.ZIndex = 54
idLabel.Parent = profileBox

-- Khối 2: Trạng thái
local statBox = Instance.new("Frame")
statBox.Size = UDim2.new(1, -10, 0, 0)
statBox.AutomaticSize = Enum.AutomaticSize.Y
statBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
statBox.BorderSizePixel = 0
statBox.ZIndex = 53
statBox.Parent = infoTab
local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 8) sbc.Parent = statBox
local sbPad = Instance.new("UIPadding") sbPad.PaddingTop = UDim.new(0, 8) sbPad.PaddingBottom = UDim.new(0, 8) sbPad.PaddingLeft = UDim.new(0, 10) sbPad.PaddingRight = UDim.new(0, 10) sbPad.Parent = statBox
local sbLayout = Instance.new("UIListLayout") sbLayout.SortOrder = Enum.SortOrder.LayoutOrder sbLayout.Padding = UDim.new(0, 4) sbLayout.Parent = statBox

local statTitle = Instance.new("TextLabel")
statTitle.Size = UDim2.new(1, 0, 0, 20)
statTitle.BackgroundTransparency = 1
statTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
statTitle.Font = Enum.Font.GothamBold
statTitle.TextSize = 13
statTitle.TextXAlignment = Enum.TextXAlignment.Left
statTitle.Text = "📊 THÔNG SỐ KỸ THUẬT"
statTitle.ZIndex = 54
statTitle.LayoutOrder = 1
statTitle.Parent = statBox

local fpsLabel = Instance.new("TextLabel") fpsLabel.Size = UDim2.new(1, 0, 0, 18) fps
