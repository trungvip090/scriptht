-- ==========================================
-- SERVICES
-- ==========================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

if getgenv().HTrungCleanup then pcall(getgenv().HTrungCleanup) end
local joinTime = tick()

-- ==========================================
-- TRẠNG THÁI
-- ==========================================
local States = {
    Fly=false, FlyUp=false, FlyDown=false, Noclip=false, InfJump=false, AutoJump=false, AutoRun=false,
    FreeCam=false, FreeCamSpeed=50, Aimbot=false, Hitbox=false, ESP=false, KillAura=false, Dodge=false,
    GodMode=false, Wallbang=false, AutoItemTp=false, AutoTpSelected=false, ItemTpSpeed=0, AntiAFK=false,
    Fullbright=false, AutoClick=false, RemoveParticles=false, AntiFling=false, Glide=false, ItemESP=false,
    XRay=false, AntiVoid=false, UnlockFPS=false, ResetTime=false, AutoClaim=false, SpamRemote=false,
    Speed=16, JumpPower=50, FlySpeed=60, HitboxSize=10, AuraRange=2000, GameSpeed=1
}
local freeCamCFrame = CFrame.new()
local freeCamRotX, freeCamRotY = 0, 0
local freeCamInput = {F=false,B=false,L=false,R=false,U=false,D=false}
local lastAuraAttack = 0
local godModeThread = nil
local oldRaycast = nil
local autoClickThread = nil
local autoItemTpThread = nil
local autoTpSelectedThread = nil
local scannedItems = {}
local selectedItemForLoop = nil
local savedPos1, savedPos2 = nil, nil
local autoTp1Active, autoTp2Active = false, false
local autoTp1Thread, autoTp2Thread = nil, nil
local Connections = {}
local ESPObjects = {}
local menuScale = 1
local ColorableElements = { Toggles = {}, ActiveTabBtn = nil, MenuStroke = nil }
local currentFps = 0
local currentPing = 0
local currentRobux = "Đang tải..."

-- ==========================================
-- THEME
-- ==========================================
local blur = Instance.new("BlurEffect") blur.Size = 0 blur.Parent = Lighting
local Theme = {
    MainBG = Color3.fromRGB(15, 8, 20), TopBar = Color3.fromRGB(30, 15, 40),
    SidebarBtn = Color3.fromRGB(45, 25, 60), SidebarBtnActive = Color3.fromRGB(255, 105, 180),
    Text = Color3.fromRGB(255, 255, 255), TextDim = Color3.fromRGB(200, 180, 210),
    AccentPink = Color3.fromRGB(255, 105, 180), AccentPurple = Color3.fromRGB(180, 100, 255),
    AccentCyan = Color3.fromRGB(0, 255, 255), AccentGold = Color3.fromRGB(255, 215, 0)
}

-- ==========================================
-- HÀM HỖ TRỢ
-- ==========================================
local function httpGet(url)
    local success, result = pcall(function()
        if syn and syn.request then return syn.request({Url = url, Method = "GET"}).Body
        elseif http_request then return http_request({Url = url, Method = "GET"}).Body
        elseif request then return request({Url = url, Method = "GET"}).Body
        else return game:HttpGet(url) end
    end)
    return success and result or nil
end

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
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then pressed = true end
    end)
    button.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) and pressed then
            pressed = false fire()
        end
    end)
end

local function makeDraggable(frame, dragArea)
    local dragging, dragInput, dragStart, startPos
    local dragThreshold = 5
    local hasMoved = false
    dragArea.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true hasMoved = false dragStart = input.Position startPos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragArea.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > dragThreshold then hasMoved = true end
            if hasMoved then frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y) end
        end
    end)
end

local function bindHold(button, callbackDown, callbackUp)
    button.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callbackDown() end
    end)
    button.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then callbackUp() end
    end)
end

if hookfunction and workspace.Raycast then
    pcall(function()
        oldRaycast = hookfunction(workspace.Raycast, function(self, origin, direction, params)
            if States.Wallbang and params then
                local newParams = RaycastParams.new()
                newParams.FilterType = Enum.RaycastFilterType.Include
                local chars = {}
                for _, plr in pairs(Players:GetPlayers()) do if plr.Character then table.insert(chars, plr.Character) end end
                newParams.FilterDescendantsInstances = chars
                return oldRaycast(self, origin, direction, newParams)
            end
            return oldRaycast(self, origin, direction, params)
        end)
    end)
end

-- ==========================================
-- SERVER FUNCTIONS
-- ==========================================
local function RejoinServer()
    pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
end

local function ServerHop()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local result = httpGet(url)
        if result then
            local servers = HttpService:JSONDecode(result)
            for _, server in pairs(servers.data) do
                if server.playing < server.maxPlayers and server.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer) break
                end
            end
        end
    end)
end

local function ServerVIP()
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local result = httpGet(url)
        if result then
            local servers = HttpService:JSONDecode(result)
            local bestServer = nil local minPlayers = 999
            for _, server in pairs(servers.data) do
                if server.playing < minPlayers and server.id ~= game.JobId then minPlayers = server.playing bestServer = server.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, bestServer, LocalPlayer) end
        end
    end)
end

task.spawn(function()
    local success, result = pcall(httpGet, "https://economy.roblox.com/v1/users/" .. LocalPlayer.UserId .. "/currency")
    if success and result then
        local ok, data = pcall(function() return HttpService:JSONDecode(result) end)
        if ok and data and data.robux then currentRobux = tostring(data.robux) else currentRobux = "Không thể lấy" end
    else currentRobux = "Không thể lấy" end
end)

-- ==========================================
-- GUI BASE
-- ==========================================
local gui = Instance.new("ScreenGui")
gui.Name = "HTrungVip" gui.ResetOnSpawn = false gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global gui.DisplayOrder = 999999

local openButton = Instance.new("ImageButton")
openButton.Size = UDim2.new(0, 50, 0, 50) openButton.Position = UDim2.new(0, 10, 0, 100)
openButton.BackgroundColor3 = Theme.MainBG openButton.BorderSizePixel = 0 openButton.ZIndex = 100
openButton.ScaleType = Enum.ScaleType.Crop
openButton.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
openButton.Parent = gui
local oc = Instance.new("UICorner") oc.CornerRadius = UDim.new(1, 0) oc.Parent = openButton
local openBtnStroke = Instance.new("UIStroke") openBtnStroke.Color = Theme.AccentPink openBtnStroke.Thickness = 2 openBtnStroke.Parent = openButton
makeDraggable(openButton, openButton)

-- ==========================================
-- OVERLAYS
-- ==========================================
local teleOverlay = Instance.new("Frame")
teleOverlay.Size = UDim2.new(0, 200, 0, 130) teleOverlay.Position = UDim2.new(1, -220, 1, -280)
teleOverlay.BackgroundColor3 = Theme.MainBG teleOverlay.BackgroundTransparency = 0.2
teleOverlay.BorderSizePixel = 0 teleOverlay.Visible = false teleOverlay.ZIndex = 90 teleOverlay.Parent = gui
local toc = Instance.new("UICorner") toc.CornerRadius = UDim.new(0, 8) toc.Parent = teleOverlay
local tos = Instance.new("UIStroke") tos.Color = Theme.AccentPurple tos.Thickness = 1 tos.Parent = teleOverlay
local teleTitle = Instance.new("TextLabel")
teleTitle.Size = UDim2.new(1, 0, 0, 25) teleTitle.BackgroundColor3 = Theme.TopBar teleTitle.TextColor3 = Theme.Text
teleTitle.Font = Enum.Font.GothamBold teleTitle.TextSize = 13 teleTitle.Text = "BẢNG TELE NHANH" teleTitle.ZIndex = 91 teleTitle.Parent = teleOverlay
local ttc = Instance.new("UICorner") ttc.CornerRadius = UDim.new(0, 8) ttc.Parent = teleTitle
makeDraggable(teleOverlay, teleTitle)

local function createOverlayBtn(text, x, y, bg, parent)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 58, 0, 28) b.Position = UDim2.new(0, x, 0, y) b.BackgroundColor3 = bg
    b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = text b.BorderSizePixel = 0 b.ZIndex = 91 b.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = b
    return b
end

local save1Btn = createOverlayBtn("Lưu 1", 5, 30, Theme.SidebarBtn, teleOverlay)
local tp1Btn = createOverlayBtn("Đến 1", 68, 30, Theme.AccentPurple, teleOverlay)
local auto1Btn = createOverlayBtn("Auto 1", 131, 30, Theme.SidebarBtn, teleOverlay)
local save2Btn = createOverlayBtn("Lưu 2", 5, 65, Theme.SidebarBtn, teleOverlay)
local tp2Btn = createOverlayBtn("Đến 2", 68, 65, Theme.AccentPurple, teleOverlay)
local auto2Btn = createOverlayBtn("Auto 2", 131, 65, Theme.SidebarBtn, teleOverlay)

bindClick(save1Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then savedPos1 = hrp.CFrame save1Btn.Text = "Đã lưu!" task.wait(1) save1Btn.Text = "Lưu 1" end
end)
bindClick(tp1Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and savedPos1 then hrp.CFrame = savedPos1 end
end)
bindClick(auto1Btn, function()
    if not savedPos1 then auto1Btn.Text = "Chưa lưu!" task.wait(1) auto1Btn.Text = autoTp1Active and "Auto 1 ON" or "Auto 1" return end
    if autoTp2Active then autoTp2Active = false if autoTp2Thread then task.cancel(autoTp2Thread) end auto2Btn.Text = "Auto 2" auto2Btn.BackgroundColor3 = Theme.SidebarBtn end
    autoTp1Active = not autoTp1Active
    if autoTp1Active then
        auto1Btn.Text = "Auto 1 ON" auto1Btn.BackgroundColor3 = Theme.AccentPink
        autoTp1Thread = task.spawn(function() while autoTp1Active do local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.CFrame = savedPos1 end task.wait(0.1) end end)
    else
        auto1Btn.Text = "Auto 1" auto1Btn.BackgroundColor3 = Theme.SidebarBtn
        if autoTp1Thread then task.cancel(autoTp1Thread) end
    end
end)
bindClick(save2Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then savedPos2 = hrp.CFrame save2Btn.Text = "Đã lưu!" task.wait(1) save2Btn.Text = "Lưu 2" end
end)
bindClick(tp2Btn, function()
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and savedPos2 then hrp.CFrame = savedPos2 end
end)
bindClick(auto2Btn, function()
    if not savedPos2 then auto2Btn.Text = "Chưa lưu!" task.wait(1) auto2Btn.Text = autoTp2Active and "Auto 2 ON" or "Auto 2" return end
    if autoTp1Active then autoTp1Active = false if autoTp1Thread then task.cancel(autoTp1Thread) end auto1Btn.Text = "Auto 1" auto1Btn.BackgroundColor3 = Theme.SidebarBtn end
    autoTp2Active = not autoTp2Active
    if autoTp2Active then
        auto2Btn.Text = "Auto 2 ON" auto2Btn.BackgroundColor3 = Theme.AccentPink
        autoTp2Thread = task.spawn(function() while autoTp2Active do local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") if hrp then hrp.CFrame = savedPos2 end task.wait(0.1) end end)
    else
        auto2Btn.Text = "Auto 2" auto2Btn.BackgroundColor3 = Theme.SidebarBtn
        if autoTp2Thread then task.cancel(autoTp2Thread) end
    end
end)

local flyOverlay = Instance.new("Frame")
flyOverlay.Size = UDim2.new(0, 180, 0, 50) flyOverlay.Position = UDim2.new(1, -200, 1, -150)
flyOverlay.BackgroundColor3 = Theme.MainBG flyOverlay.BackgroundTransparency = 0.3
flyOverlay.Visible = false flyOverlay.ZIndex = 90 flyOverlay.Parent = gui
local foc = Instance.new("UICorner") foc.CornerRadius = UDim.new(0, 8) foc.Parent = flyOverlay
local fos = Instance.new("UIStroke") fos.Color = Theme.AccentPurple fos.Thickness = 1 fos.Parent = flyOverlay
local btnFlyUp = Instance.new("TextButton") btnFlyUp.Size = UDim2.new(0.45, 0, 1, -10) btnFlyUp.Position = UDim2.new(0.03, 0, 0, 5) btnFlyUp.BackgroundColor3 = Theme.AccentPurple btnFlyUp.TextColor3 = Theme.Text btnFlyUp.Font = Enum.Font.GothamBold btnFlyUp.Text = "LÊN" btnFlyUp.TextSize = 13 btnFlyUp.ZIndex = 91 btnFlyUp.Parent = flyOverlay
local uc1 = Instance.new("UICorner") uc1.CornerRadius = UDim.new(0, 6) uc1.Parent = btnFlyUp
local btnFlyDown = Instance.new("TextButton") btnFlyDown.Size = UDim2.new(0.45, 0, 1, -10) btnFlyDown.Position = UDim2.new(0.52, 0, 0, 5) btnFlyDown.BackgroundColor3 = Theme.AccentPink btnFlyDown.TextColor3 = Theme.Text btnFlyDown.Font = Enum.Font.GothamBold btnFlyDown.Text = "XUỐNG" btnFlyDown.TextSize = 13 btnFlyDown.ZIndex = 91 btnFlyDown.Parent = flyOverlay
local dc1 = Instance.new("UICorner") dc1.CornerRadius = UDim.new(0, 6) dc1.Parent = btnFlyDown
bindHold(btnFlyUp, function() States.FlyUp = true end, function() States.FlyUp = false end)
bindHold(btnFlyDown, function() States.FlyDown = true end, function() States.FlyDown = false end)
makeDraggable(flyOverlay, flyOverlay)

local fcOverlay = Instance.new("Frame")
fcOverlay.Size = UDim2.new(0, 180, 0, 200) fcOverlay.Position = UDim2.new(1, -200, 1, -380)
fcOverlay.BackgroundColor3 = Theme.MainBG fcOverlay.BackgroundTransparency = 0.3
fcOverlay.Visible = false fcOverlay.ZIndex = 90 fcOverlay.Parent = gui
local fcoc = Instance.new("UICorner") fcoc.CornerRadius = UDim.new(0, 8) fcoc.Parent = fcOverlay
local fcos = Instance.new("UIStroke") fcos.Color = Theme.AccentPurple fcos.Thickness = 1 fcos.Parent = fcOverlay

local function createFcBtn(text, x, y, w, h, key)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(w, 0, h, 0) b.Position = UDim2.new(x, 0, y, 0) b.BackgroundColor3 = Theme.SidebarBtn
    b.TextColor3 = Theme.Text b.Font = Enum.Font.GothamBold b.TextSize = 12 b.Text = text b.ZIndex = 91 b.Parent = fcOverlay
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
teleBtn.Size = UDim2.new(0.9, 0, 0.15, 0) teleBtn.Position = UDim2.new(0.05, 0, 0.78, 0)
teleBtn.BackgroundColor3 = Theme.AccentPink teleBtn.TextColor3 = Theme.Text
teleBtn.Font = Enum.Font.GothamBold teleBtn.TextSize = 13 teleBtn.Text = "TELE ĐẾN ĐÂY" teleBtn.ZIndex = 91 teleBtn.Parent = fcOverlay
local teCorner = Instance.new("UICorner") teCorner.CornerRadius = UDim.new(0, 6) teCorner.Parent = teleBtn
bindClick(teleBtn, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.CFrame = Camera.CFrame + Vector3.new(0, 3, 0) end
end)
makeDraggable(fcOverlay, fcOverlay)

-- ==========================================
-- MAIN MENU
-- ==========================================
local menu = Instance.new("Frame")
menu.Size = UDim2.fromOffset(650, 450) menu.Position = UDim2.new(0.5, 0, 0.5, 0)
menu.AnchorPoint = Vector2.new(0.5, 0.5) menu.BackgroundColor3 = Theme.MainBG
menu.BackgroundTransparency = 0.15 menu.BorderSizePixel = 0 menu.Visible = false menu.ZIndex = 50 menu.Parent = gui

local mc = Instance.new("UICorner") mc.CornerRadius = UDim.new(0, 16) mc.Parent = menu
local ms = Instance.new("UIStroke") ms.Color = Color3.fromRGB(255, 255, 255) ms.Thickness = 2 ms.Transparency = 0.1 ms.Parent = menu
ColorableElements.MenuStroke = ms

local menuStrokeGradient = Instance.new("UIGradient")
menuStrokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Theme.AccentPink),
    ColorSequenceKeypoint.new(0.5, Theme.AccentCyan),
    ColorSequenceKeypoint.new(1, Theme.AccentPurple)
})
menuStrokeGradient.Parent = ms

local uiScale = Instance.new("UIScale") uiScale.Scale = 0.8 uiScale.Parent = menu

local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.new(1, 0, 1, 0) bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://13476434849" bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ImageTransparency = 0.6 bgImage.ZIndex = 50 bgImage.Parent = menu
local bgCorner = Instance.new("UICorner") bgCorner.CornerRadius = UDim.new(0, 16) bgCorner.Parent = bgImage

local bgOverlay = Instance.new("Frame")
bgOverlay.Size = UDim2.new(1, 0, 1, 0) bgOverlay.BackgroundColor3 = Theme.MainBG
bgOverlay.BackgroundTransparency = 0.3 bgOverlay.ZIndex = 51 bgOverlay.Parent = menu
local boCorner = Instance.new("UICorner") boCorner.CornerRadius = UDim.new(0, 16) boCorner.Parent = bgOverlay

local titleFrame = Instance.new("Frame")
titleFrame.Size = UDim2.new(1, 0, 0, 45) titleFrame.BackgroundColor3 = Theme.TopBar
titleFrame.BackgroundTransparency = 0.3 titleFrame.BorderSizePixel = 0 titleFrame.ZIndex = 52 titleFrame.Parent = menu
local tfc = Instance.new("UICorner") tfc.CornerRadius = UDim.new(0, 16) tfc.Parent = titleFrame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -250, 1, 0) title.BackgroundTransparency = 1 title.TextColor3 = Theme.Text
title.Font = Enum.Font.GothamBlack title.TextSize = 20 title.Text = "👑 HTrung Hub V3.9" title.ZIndex = 53 title.Parent = titleFrame
local titleStroke = Instance.new("UIStroke") titleStroke.Color = Theme.AccentPink titleStroke.Thickness = 1.5 titleStroke.Transparency = 0.4 titleStroke.Parent = title

local scaleFrame = Instance.new("Frame")
scaleFrame.Size = UDim2.new(0, 60, 0, 30) scaleFrame.Position = UDim2.new(1, -180, 0.5, -15)
scaleFrame.BackgroundTransparency = 1 scaleFrame.ZIndex = 53 scaleFrame.Parent = titleFrame

local function createScaleBtn(text, posX, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25) btn.Position = UDim2.new(0, posX, 0, 0) btn.BackgroundColor3 = color
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 14 btn.Text = text
    btn.BorderSizePixel = 0 btn.ZIndex = 54 btn.Parent = scaleFrame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = btn
    local bs = Instance.new("UIStroke") bs.Color = Theme.Text bs.Thickness = 1 bs.Transparency = 0.5 bs.Parent = btn
    return btn
end
local scaleOutBtn = createScaleBtn("-", 0, Theme.AccentPink)
local scaleInBtn = createScaleBtn("+", 30, Theme.AccentPurple)
bindClick(scaleOutBtn, function() menuScale = math.max(menuScale - 0.1, 0.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)
bindClick(scaleInBtn, function() menuScale = math.min(menuScale + 0.1, 1.5) TweenService:Create(uiScale, TweenInfo.new(0.2), {Scale = menuScale}):Play() end)

local controlFrame = Instance.new("Frame")
controlFrame.Size = UDim2.new(0, 90, 0, 30) controlFrame.Position = UDim2.new(1, -110, 0.5, -15)
controlFrame.BackgroundTransparency = 1 controlFrame.ZIndex = 53 controlFrame.Parent = titleFrame

local function createControlBtn(text, posX, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25) btn.Position = UDim2.new(0, posX, 0, 0) btn.BackgroundColor3 = color
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 14 btn.Text = text
    btn.BorderSizePixel = 0 btn.ZIndex = 54 btn.Parent = controlFrame
    local bc = Instance.new("UICorner") bc.CornerRadius = UDim.new(0, 6) bc.Parent = btn
    local bs = Instance.new("UIStroke") bs.Color = Theme.Text bs.Thickness = 1 bs.Transparency = 0.5 bs.Parent = btn
    return btn
end
local minBtn = createControlBtn("-", 0, Theme.SidebarBtn)
local maxBtn = createControlBtn("+", 30, Theme.AccentPurple)
local closeBtn = createControlBtn("X", 60, Theme.AccentPink)

local isAnimating = false
local function openMenu()
    if isAnimating or menu.Visible then return end
    isAnimating = true menu.Visible = true uiScale.Scale = 0.5 menu.BackgroundTransparency = 1 bgOverlay.BackgroundTransparency = 1 blur.Size = 0
    TweenService:Create(uiScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = menuScale}):Play()
    TweenService:Create(menu, TweenInfo.new(0.4), {BackgroundTransparency = 0.15}):Play()
    TweenService:Create(bgOverlay, TweenInfo.new(0.4), {BackgroundTransparency = 0.3}):Play()
    TweenService:Create(blur, TweenInfo.new(0.4), {Size = 15}):Play()
    task.wait(0.4) isAnimating = false
end
local function closeMenu()
    if isAnimating or not menu.Visible then return end
    isAnimating = true
    TweenService:Create(uiScale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.5}):Play()
    TweenService:Create(menu, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(bgOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
    task.wait(0.3) menu.Visible = false isAnimating = false
end
bindClick(minBtn, function() closeMenu() end)
bindClick(closeBtn, function() closeMenu() end)
bindClick(maxBtn, function() if menuScale == 1 then menuScale = 1.2 else menuScale = 1 end TweenService:Create(uiScale, TweenInfo.new(0.3), {Scale = menuScale}):Play() end)
bindClick(openButton, function() if menu.Visible then closeMenu() else openMenu() end end)
makeDraggable(menu, titleFrame)

task.spawn(function()
    while menu.Parent do
        TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0.5, TextColor3 = Theme.AccentCyan}):Play()
        task.wait(1)
        TweenService:Create(title, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {TextTransparency = 0, TextColor3 = Theme.Text}):Play()
        task.wait(1)
    end
end)

task.spawn(function()
    local rotation = 0
    while menu.Parent do rotation = (rotation + 1) % 360 if menuStrokeGradient then menuStrokeGradient.Rotation = rotation end task.wait(0.03) end
end)

local sidebar = Instance.new("ScrollingFrame")
sidebar.Size = UDim2.new(0, 130, 1, -55) sidebar.Position = UDim2.new(0, 10, 0, 50)
sidebar.BackgroundTransparency = 1 sidebar.BorderSizePixel = 0 sidebar.ScrollBarThickness = 0
sidebar.AutomaticCanvasSize = Enum.AutomaticSize.Y sidebar.ScrollingEnabled = true
sidebar.ScrollingDirection = Enum.ScrollingDirection.Y sidebar.ClipsDescendants = true sidebar.ZIndex = 52 sidebar.Parent = menu
local tabLayout = Instance.new("UIListLayout") tabLayout.Padding = UDim.new(0, 8) tabLayout.Parent = sidebar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -160, 1, -60) contentFrame.Position = UDim2.new(0, 150, 0, 50)
contentFrame.BackgroundTransparency = 1 contentFrame.ZIndex = 52 contentFrame.ClipsDescendants = true contentFrame.Parent = menu

local function createTab(name, icon)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, 0, 0, 40) tabBtn.BackgroundColor3 = Theme.SidebarBtn
    tabBtn.BackgroundTransparency = 0.5 tabBtn.TextColor3 = Theme.TextDim tabBtn.Font = Enum.Font.GothamBold
    tabBtn.TextSize = 14 tabBtn.Text = icon .. " " .. name tabBtn.TextXAlignment = Enum.TextXAlignment.Left
    tabBtn.BorderSizePixel = 0 tabBtn.ZIndex = 53 tabBtn.Parent = sidebar
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = tabBtn
    local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 10) pad.Parent = tabBtn
    local stroke = Instance.new("UIStroke") stroke.Color = Theme.AccentPurple stroke.Thickness = 0 stroke.Parent = tabBtn

    local frame = Instance.new("ScrollingFrame")
    frame.Size = UDim2.new(1, 0, 1, 0) frame.BackgroundTransparency = 1 frame.BorderSizePixel = 0
    frame.ScrollBarThickness = 4 frame.ScrollBarImageColor3 = Theme.AccentPink frame.Visible = false
    frame.ZIndex = 53 frame.ClipsDescendants = true frame.ScrollingEnabled = true
    frame.ScrollingDirection = Enum.ScrollingDirection.Y frame.AutomaticCanvasSize = Enum.AutomaticSize.Y frame.Parent = contentFrame
    local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 8) layout.Parent = frame
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        frame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
    end)
    bindClick(tabBtn, function()
        for _, child in pairs(contentFrame:GetChildren()) do if child:IsA("ScrollingFrame") then child.Visible = false end end
        for _, child in pairs(sidebar:GetChildren()) do
            if child:IsA("TextButton") then
                TweenService:Create(child, TweenInfo.new(0.2), {BackgroundTransparency = 0.5, TextColor3 = Theme.TextDim}):Play()
                child:FindFirstChild("UIStroke").Thickness = 0
            end
        end
        frame.Visible = true
        TweenService:Create(tabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1, TextColor3 = Theme.Text}):Play()
        tabBtn:FindFirstChild("UIStroke").Thickness = 1
        tabBtn:FindFirstChild("UIStroke").Color = Theme.AccentCyan
        ColorableElements.ActiveTabBtn = tabBtn
    end)
    return frame
end

local function createToggle(parent, text, initialState, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -10, 0, 38) container.BackgroundColor3 = Theme.SidebarBtn
    container.BackgroundTransparency = 0.5 container.BorderSizePixel = 0 container.ZIndex = 53 container.Parent = parent
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = container
    local s = Instance.new("UIStroke") s.Color = Theme.AccentPurple s.Thickness = 1 s.Transparency = 0.7 s.Parent = container
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -60, 1, 0) label.Position = UDim2.new(0, 10, 0, 0) label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text label.Font = Enum.Font.GothamBold label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left label.Text = text label.ZIndex = 54 label.Parent = container
    local switchBtn = Instance.new("TextButton")
    switchBtn.Size = UDim2.new(0, 40, 0, 20) switchBtn.Position = UDim2.new(1, -50, 0.5, -10)
    switchBtn.BackgroundColor3 = initialState and Theme.AccentPink or Color3.fromRGB(50, 50, 60)
    switchBtn.Text = "" switchBtn.BorderSizePixel = 0 switchBtn.ZIndex = 54 switchBtn.Parent = container
    local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(1, 0) sc.Parent = switchBtn
    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = initialState and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255) knob.BorderSizePixel = 0 knob.ZIndex = 55 knob.Parent = switchBtn
    local kc = Instance.new("UICorner") kc.CornerRadius = UDim.new(1, 0) kc.Parent = knob
    local state = initialState
    local data = { Button = switchBtn, State = state }
    table.insert(ColorableElements.Toggles, data)
    bindClick(switchBtn, function()
        state = not state data.State = state
        local targetColor = state and Theme.AccentPink or Color3.fromRGB(50, 50, 60)
        local targetPos = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        TweenService:Create(switchBtn, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {Position = targetPos}):Play()
        callback(state)
    end)
end

local function createSlider(parent, text, min, max, initial, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -10, 0, 38) frame.BackgroundColor3 = Theme.SidebarBtn
    frame.BackgroundTransparency = 0.5 frame.BorderSizePixel = 0 frame.ZIndex = 53 frame.Parent = parent
    local fc = Instance.new("UICorner") fc.CornerRadius = UDim.new(0, 8) fc.Parent = frame
    local fs = Instance.new("UIStroke") fs.Color = Theme.AccentPurple fs.Thickness = 1 fs.Transparency = 0.7 fs.Parent = frame
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.6, 0, 1, 0) label.Position = UDim2.new(0, 10, 0, 0) label.BackgroundTransparency = 1
    label.TextColor3 = Theme.Text label.Font = Enum.Font.GothamBold label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left label.Text = text .. ": " .. initial label.ZIndex = 54 label.Parent = frame
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 30, 0, 25) minus.Position = UDim2.new(1, -70, 0.5, -12.5) minus.BackgroundColor3 = Theme.AccentPink
    minus.TextColor3 = Theme.Text minus.Font = Enum.Font.GothamBold minus.TextSize = 14 minus.Text = "-" minus.ZIndex = 54 minus.Parent = frame
    local minc = Instance.new("UICorner") minc.CornerRadius = UDim.new(0, 6) minc.Parent = minus
    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 30, 0, 25) plus.Position = UDim2.new(1, -35, 0.5, -12.5) plus.BackgroundColor3 = Theme.AccentPurple
    plus.TextColor3 = Theme.Text plus.Font = Enum.Font.GothamBold plus.TextSize = 14 plus.Text = "+" plus.ZIndex = 54 plus.Parent = frame
    local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, 6) pc.Parent = plus
    local val = initial
    local step = (max > 100 and 50 or 0.1)
    if max == 2.0 and min == 0 then step = 0.1 end
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
-- TAB 1: INFO
-- ==========================================
local infoTab = createTab("Thông Tin", "🏠")
infoTab.AutomaticCanvasSize = Enum.AutomaticSize.Y
infoTab.CanvasSize = UDim2.new(0, 0, 0, 0)
infoTab.UIListLayout.Padding = UDim.new(0, 10)

local profileShowcase = Instance.new("Frame")
profileShowcase.Size = UDim2.new(1, -10, 0, 260) profileShowcase.BackgroundTransparency = 1
profileShowcase.ZIndex = 54 profileShowcase.LayoutOrder = 1 profileShowcase.Parent = infoTab

local ringContainer = Instance.new("Frame")
ringContainer.Size = UDim2.new(0, 140, 0, 140) ringContainer.Position = UDim2.new(0.5, 0, 0, 10)
ringContainer.AnchorPoint = Vector2.new(0.5, 0) ringContainer.BackgroundTransparency = 1
ringContainer.ZIndex = 55 ringContainer.Parent = profileShowcase

local ring1 = Instance.new("Frame")
ring1.Size = UDim2.new(1, 0, 1, 0) ring1.BackgroundTransparency = 1 ring1.ZIndex = 55 ring1.Parent = ringContainer
local r1c = Instance.new("UICorner") r1c.CornerRadius = UDim.new(1, 0) r1c.Parent = ring1
local r1s = Instance.new("UIStroke") r1s.Color = Theme.AccentPink r1s.Thickness = 4 r1s.Parent = ring1
local r1Gradient = Instance.new("UIGradient")
r1Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.AccentPink), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Theme.AccentCyan)})
r1Gradient.Parent = r1s

local ring2 = Instance.new("Frame")
ring2.Size = UDim2.new(0.85, 0, 0.85, 0) ring2.Position = UDim2.new(0.5, 0, 0.5, 0)
ring2.AnchorPoint = Vector2.new(0.5, 0.5) ring2.BackgroundTransparency = 1 ring2.ZIndex = 55 ring2.Parent = ringContainer
local r2c = Instance.new("UICorner") r2c.CornerRadius = UDim.new(1, 0) r2c.Parent = ring2
local r2s = Instance.new("UIStroke") r2s.Color = Theme.AccentPurple r2s.Thickness = 2 r2s.Transparency = 0.5 r2s.Parent = ring2
local r2Gradient = Instance.new("UIGradient")
r2Gradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.5, Theme.AccentPurple), ColorSequenceKeypoint.new(1, Theme.AccentPink)})
r2Gradient.Parent = r2s

local avatarImage = Instance.new("ImageLabel")
avatarImage.Size = UDim2.new(0, 110, 0, 110) avatarImage.Position = UDim2.new(0.5, 0, 0.5, 0)
avatarImage.AnchorPoint = Vector2.new(0.5, 0.5) avatarImage.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
avatarImage.Image = "rbxthumb://type=Avatar&id=" .. LocalPlayer.UserId .. "&w=420&h=420"
avatarImage.ScaleType = Enum.ScaleType.Crop avatarImage.ZIndex = 56 avatarImage.Parent = ringContainer
local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(1, 0) ac.Parent = avatarImage

task.spawn(function()
    local rot = 0
    while profileShowcase.Parent do
        rot = (rot + 2) % 360 r1Gradient.Rotation = rot r2Gradient.Rotation = -rot
        TweenService:Create(ring1, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1.08, 0, 1.08, 0)}):Play()
        TweenService:Create(avatarImage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, 0, 0.5, -15), Size = UDim2.new(0, 115, 0, 115)}):Play()
        task.wait(0.5)
        TweenService:Create(avatarImage, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 110, 0, 110)}):Play()
        task.wait(0.5)
        TweenService:Create(ring1, TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Size = UDim2.new(1, 0, 1, 0)}):Play()
        task.wait(1)
    end
end)

local nameLabel = Instance.new("TextLabel")
nameLabel.Size = UDim2.new(1, 0, 0, 50) nameLabel.Position = UDim2.new(0.5, 0, 0, 150)
nameLabel.AnchorPoint = Vector2.new(0.5, 0) nameLabel.BackgroundTransparency = 1
nameLabel.Text = LocalPlayer.DisplayName nameLabel.TextColor3 = Theme.Text
nameLabel.Font = Enum.Font.GothamBlack nameLabel.TextSize = 42 nameLabel.ZIndex = 55 nameLabel.Parent = profileShowcase
local textGradient = Instance.new("UIGradient")
textGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Theme.AccentPink), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Theme.AccentPurple)})
textGradient.Parent = nameLabel
local textStroke = Instance.new("UIStroke") textStroke.Color = Theme.AccentPurple textStroke.Thickness = 2 textStroke.Transparency = 0.3 textStroke.Parent = nameLabel

local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, 0, 0, 20) subLabel.Position = UDim2.new(0.5, 0, 0, 195)
subLabel.AnchorPoint = Vector2.new(0.5, 0) subLabel.BackgroundTransparency = 1
subLabel.Text = "Script Premium Roblox | ID: " .. LocalPlayer.UserId
subLabel.TextColor3 = Theme.TextDim subLabel.Font = Enum.Font.GothamBold subLabel.TextSize = 14 subLabel.ZIndex = 55 subLabel.Parent = profileShowcase

local gridFrame = Instance.new("Frame")
gridFrame.Size = UDim2.new(1, -10, 0, 320) gridFrame.BackgroundTransparency = 1
gridFrame.ZIndex = 54 gridFrame.LayoutOrder = 2 gridFrame.Parent = infoTab
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0.5, -5, 0.5, -5) gridLayout.CellPadding = UDim2.new(0, 10, 0, 10)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder gridLayout.Parent = gridFrame

local function createInfoBox(titleText, icon, color1, color2, layoutOrder)
    local box = Instance.new("Frame")
    box.BackgroundColor3 = Theme.SidebarBtn box.BackgroundTransparency = 0.4 box.BorderSizePixel = 0
    box.ZIndex = 54 box.LayoutOrder = layoutOrder box.Parent = gridFrame
    local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, 12) corner.Parent = box
    local stroke = Instance.new("UIStroke") stroke.Color = Color3.fromRGB(255, 255, 255) stroke.Thickness = 1.5 stroke.Transparency = 0.5 stroke.Parent = box
    local strokeGradient = Instance.new("UIGradient")
    strokeGradient.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)}) strokeGradient.Parent = stroke
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -10, 0, 25) titleLbl.Position = UDim2.new(0, 10, 0, 5)
    titleLbl.BackgroundTransparency = 1 titleLbl.TextColor3 = color1 titleLbl.Font = Enum.Font.GothamBlack
    titleLbl.TextSize = 14 titleLbl.TextXAlignment = Enum.TextXAlignment.Left titleLbl.Text = icon .. " " .. titleText
    titleLbl.ZIndex = 55 titleLbl.Parent = box
    local listLayout = Instance.new("UIListLayout") listLayout.Padding = UDim.new(0, 5) listLayout.SortOrder = Enum.SortOrder.LayoutOrder listLayout.Parent = box
    local pad = Instance.new("UIPadding") pad.PaddingTop = UDim.new(0, 30) pad.PaddingLeft = UDim.new(0, 10) pad.PaddingRight = UDim.new(0, 10) pad.Parent = box
    return box
end

local function createStatRow(parent, text, layoutOrder)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 18) lbl.BackgroundTransparency = 1 lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.GothamBold lbl.TextSize = 12 lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = text lbl.ZIndex = 55 lbl.LayoutOrder = layoutOrder lbl.Parent = parent
    return lbl
end

local box1 = createInfoBox("Hiệu năng", "⚡", Theme.AccentCyan, Theme.AccentPurple, 1)
local fpsLabel = createStatRow(box1, "FPS: ...", 2)
local pingLabel = createStatRow(box1, "Ping: ... ms", 3)
local posLabel = createStatRow(box1, "Pos: ..., ..., ...", 4)
local box2 = createInfoBox("Phiên chơi", "⏱️", Theme.AccentPink, Theme.AccentPurple, 2)
local timeLbl = createStatRow(box2, "Giờ: " .. os.date("%H:%M:%S"), 2)
local dateLbl = createStatRow(box2, "Ngày: " .. os.date("%d/%m/%Y"), 3)
local playtimeLbl = createStatRow(box2, "Đã chơi: 00:00:00", 4)
local box3 = createInfoBox("Thông tin", "👤", Theme.AccentPurple, Theme.AccentPink, 3)
local gameNameLbl = createStatRow(box3, "🎮 Game: " .. game.Name, 2)
local userLbl = createStatRow(box3, "👑 Tên: " .. LocalPlayer.DisplayName, 3)
local robuxLbl = createStatRow(box3, "💰 Robux: " .. currentRobux, 4)
local box4 = createInfoBox("Update", "🔄", Theme.AccentCyan, Theme.AccentPurple, 4)
local updateLbl = Instance.new("TextLabel")
updateLbl.Size = UDim2.new(1, 0, 0, 40) updateLbl.BackgroundTransparency = 1
updateLbl.TextColor3 = Theme.Text updateLbl.Font = Enum.Font.GothamBold updateLbl.TextSize = 12
updateLbl.TextXAlignment = Enum.TextXAlignment.Left updateLbl.TextWrapped = true
updateLbl.Text = "V3.9: Game tab BRUTE-SCAN, delay=0 dùng Heartbeat."
updateLbl.ZIndex = 55 updateLbl.LayoutOrder = 2 updateLbl.Parent = box4

local serverFrame = Instance.new("Frame")
serverFrame.Size = UDim2.new(1, -10, 0, 45) serverFrame.BackgroundColor3 = Theme.SidebarBtn
serverFrame.BackgroundTransparency = 0.3 serverFrame.ZIndex = 54 serverFrame.LayoutOrder = 3 serverFrame.Parent = infoTab
local sfc = Instance.new("UICorner") sfc.CornerRadius = UDim.new(0, 10) sfc.Parent = serverFrame
local sfs = Instance.new("UIStroke") sfs.Color = Theme.AccentCyan sfs.Thickness = 1.5 sfs.Transparency = 0.3 sfs.Parent = serverFrame
local sLayout = Instance.new("UIListLayout")
sLayout.FillDirection = Enum.FillDirection.Horizontal sLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sLayout.VerticalAlignment = Enum.VerticalAlignment.Center sLayout.Padding = UDim.new(0, 10) sLayout.Parent = serverFrame

local function createServerBtn(text, icon, color, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.31, 0, 1, -10) btn.BackgroundColor3 = color btn.BackgroundTransparency = 0
    btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 12
    btn.Text = icon .. " " .. text btn.ZIndex = 55 btn.Parent = serverFrame
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
    local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(255,255,255) s.Thickness = 1 s.Transparency = 0.3 s.Parent = btn
    bindClick(btn, callback)
end
createServerBtn("Server Hop", "🔄", Theme.SidebarBtn, ServerHop)
createServerBtn("Rejoin", "🔁", Theme.AccentPurple, RejoinServer)
createServerBtn("Server VIP", "👑", Theme.AccentPink, ServerVIP)

-- ==========================================
-- TAB 2: PLAYER
-- ==========================================
local playerTab = createTab("Player", "🎮")
createToggle(playerTab, "God Mode (Bất tử)", false, function(s)
    States.GodMode = s
    if s and not godModeThread then
        godModeThread = task.spawn(function()
            while States.GodMode do
                task.wait(0.1)
                local c = LocalPlayer.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then
                        if not c:FindFirstChild("GodModeForceField") then
                            local ff = Instance.new("ForceField") ff.Name = "GodModeForceField" ff.Visible = false ff.Parent = c
                        end
                        h.Health = h.MaxHealth
                    end
                end
            end
        end)
    elseif not s then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("GodModeForceField") then LocalPlayer.Character.GodModeForceField:Destroy() end
    end
end)
createSlider(playerTab, "WalkSpeed", 16, 500, 16, function(v) States.Speed = v end)
createSlider(playerTab, "JumpPower", 50, 500, 50, function(v) States.JumpPower = v end)
createToggle(playerTab, "Infinite Jump", false, function(s) States.InfJump = s end)
createToggle(playerTab, "Auto Run (Tự chạy)", false, function(s) States.AutoRun = s end)
createToggle(playerTab, "Auto Jump (Tự nhảy)", false, function(s) States.AutoJump = s end)
createToggle(playerTab, "Chống Văng (Anti-Fling)", false, function(s) States.AntiFling = s end)
createToggle(playerTab, "Lướt Trên Không (Glide)", false, function(s) States.Glide = s end)
createToggle(playerTab, "Noclip (Xuyên tường)", false, function(s)
    States.Noclip = s
    if not s and LocalPlayer.Character then
        for _, p in pairs(LocalPlayer.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end
    end
end)
createToggle(playerTab, "Fly (Bay)", false, function(s) States.Fly = s flyOverlay.Visible = s end)
createSlider(playerTab, "Fly Speed", 10, 500, 60, function(v) States.FlySpeed = v end)

-- ==========================================
-- TAB 3: VISUALS
-- ==========================================
local visualTab = createTab("Visuals", "👁️")
createToggle(visualTab, "Player ESP (Highlight)", false, function(s)
    States.ESP = s
    if not s then for _, obj in pairs(ESPObjects) do if obj then obj:Destroy() end end table.clear(ESPObjects) end
end)
createToggle(visualTab, "Hiện Vật Phẩm (Item ESP)", false, function(s) States.ItemESP = s end)
createToggle(visualTab, "Nhìn Xuyên Tường (X-Ray)", false, function(s)
    States.XRay = s
    if not s then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(LocalPlayer.Character) then obj.LocalTransparencyModifier = 0 end
        end
    end
end)
createSlider(visualTab, "FreeCam Speed", 10, 300, 50, function(v) States.FreeCamSpeed = v end)
createToggle(visualTab, "Free Camera (Tự do)", false, function(s)
    States.FreeCam = s
    local char = LocalPlayer.Character
    if s then
        freeCamCFrame = Camera.CFrame Camera.CameraType = Enum.CameraType.Scriptable
        if char and char:FindFirstChildOfClass("Humanoid") then
            Camera.CameraSubject = nil char.Humanoid.WalkSpeed = 0 char.Humanoid.JumpPower = 0
        end
        fcOverlay.Visible = true
        for k in pairs(freeCamInput) do freeCamInput[k] = false end
        local rx, ry, rz = freeCamCFrame:ToEulerAnglesYXZ() freeCamRotX = rx freeCamRotY = ry
    else
        Camera.CameraType = Enum.CameraType.Custom
        if char and char:FindFirstChildOfClass("Humanoid") then
            Camera.CameraSubject = char.Humanoid char.Humanoid.WalkSpeed = States.Speed char.Humanoid.JumpPower = States.JumpPower
        end
        fcOverlay.Visible = false
    end
end)

-- ==========================================
-- TAB 4: COMBAT
-- ==========================================
local combatTab = createTab("Combat", "⚔️")
createToggle(combatTab, "Hitbox Expander", false, function(s) States.Hitbox = s end)
createSlider(combatTab, "Hitbox Size", 5, 50, 10, function(v) States.HitboxSize = v end)
createToggle(combatTab, "Aimbot (Camera Lock)", false, function(s) States.Aimbot = s end)
createToggle(combatTab, "Wallbang (Bắn xuyên tường)", false, function(s) States.Wallbang = s end)
createToggle(combatTab, "Kill Aura (Auto-Kill)", false, function(s) States.KillAura = s end)
createSlider(combatTab, "Aura Range", 10, 2000, 2000, function(v) States.AuraRange = v end)
createToggle(combatTab, "Auto Dodge (Né lùi)", false, function(s) States.Dodge = s end)

-- ==========================================
-- TAB 5: FARM REWARD
-- ==========================================
local rewardTab = createTab("Farm Reward", "🌾")
createToggle(rewardTab, "Ép Thời Gian Về 0", false, function(s) States.ResetTime = s end)
createToggle(rewardTab, "Auto Bấm Nhận (UI)", false, function(s) States.AutoClaim = s end)
createToggle(rewardTab, "Spam Remote (Nhận Ngầm)", false, function(s) States.SpamRemote = s end)
createSlider(rewardTab, "SpeedHack (Tốc độ Game)", 1, 1000, 1, function(v)
    States.GameSpeed = v
    local char = LocalPlayer.Character
    if char then
        for _, obj in pairs(char:GetDescendants()) do
            if obj:IsA("Animator") then
                for _, track in pairs(obj:GetPlayingAnimationTracks()) do pcall(function() track:AdjustSpeed(v) end) end
            end
        end
    end
end)

local bypassDailyBtn = Instance.new("TextButton")
bypassDailyBtn.Size = UDim2.new(1, -10, 0, 45) bypassDailyBtn.BackgroundColor3 = Theme.AccentPink
bypassDailyBtn.TextColor3 = Theme.Text bypassDailyBtn.Font = Enum.Font.GothamBlack
bypassDailyBtn.TextSize = 15 bypassDailyBtn.Text = "BYPASS QUÀ & THỜI GIAN (CƠ BẢN)"
bypassDailyBtn.BorderSizePixel = 0 bypassDailyBtn.ZIndex = 54 bypassDailyBtn.Parent = rewardTab
local bdc = Instance.new("UICorner") bdc.CornerRadius = UDim.new(0, 8) bdc.Parent = bypassDailyBtn
local bds = Instance.new("UIStroke") bds.Color = Theme.AccentCyan bds.Thickness = 2 bds.Parent = bypassDailyBtn

bindClick(bypassDailyBtn, function()
    bypassDailyBtn.Text = "ĐANG BYPASS..." bypassDailyBtn.BackgroundColor3 = Theme.AccentPurple
    for i = 1, 10 do
        for _, remote in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                local name = string.lower(remote.Name)
                if string.find(name, "daily") or string.find(name, "login") or string.find(name, "gift") or string.find(name, "reward") or string.find(name, "claim") or string.find(name, "time") then
                    pcall(function()
                        if remote:IsA("RemoteEvent") then remote:FireServer() remote:FireServer(0) remote:FireServer(1)
                        else remote:InvokeServer() remote:InvokeServer(0) end
                    end)
                end
            end
        end
        task.wait(0.05)
    end
    for _, obj in pairs(game:GetService("Workspace"):GetDescendants()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") then
            local n = string.lower(obj.Name)
            if string.find(n, "time") or string.find(n, "timer") or string.find(n, "countdown") or string.find(n, "playtime") then pcall(function() obj.Value = 0 end) end
        end
    end
    for _, obj in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
        if obj:IsA("NumberValue") or obj:IsA("IntValue") then
            local n = string.lower(obj.Name)
            if string.find(n, "time") or string.find(n, "timer") or string.find(n, "countdown") or string.find(n, "playtime") then pcall(function() obj.Value = 0 end) end
        end
    end
    task.wait(1) bypassDailyBtn.Text = "ĐÃ BYPASS (KIỂM TRA GAME)" bypassDailyBtn.BackgroundColor3 = Theme.AccentCyan
    task.wait(2) bypassDailyBtn.Text = "BYPASS QUÀ & THỜI GIAN (CƠ BẢN)" bypassDailyBtn.BackgroundColor3 = Theme.AccentPink
end)

task.spawn(function()
    while true do
        task.wait(0.2)
        if States.ResetTime then
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("StringValue") then
                    local n = string.lower(obj.Name)
                    if string.find(n, "time") or string.find(n, "timer") or string.find(n, "countdown") or string.find(n, "cooldown") then
                        if obj:IsA("IntValue") or obj:IsA("NumberValue") then obj.Value = 0
                        elseif obj:IsA("StringValue") then obj.Value = "00:00" end
                    end
                end
            end
        end
        if States.AutoClaim then
            for _, obj in pairs(LocalPlayer.PlayerGui:GetDescendants()) do
                if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                    local text = string.lower(obj.Text)
                    if string.find(text, "nhận") or string.find(text, "claim") or string.find(text, "free") then
                        pcall(function() if firesignal then firesignal(obj.MouseButton1Click) else obj:Activate() end end)
                    end
                end
            end
        end
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        if States.SpamRemote then
            for _, remote in pairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local name = string.lower(remote.Name)
                    if string.find(name, "claim") or string.find(name, "reward") or string.find(name, "daily") or string.find(name, "nhan") then
                        pcall(function() if remote:IsA("RemoteEvent") then remote:FireServer() else remote:InvokeServer() end end)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- TAB 6: TELEPORT
-- ==========================================
local tpTab = createTab("Teleport", "📍")
local tpMouseBtn = Instance.new("TextButton")
tpMouseBtn.Size = UDim2.new(1, -10, 0, 35) tpMouseBtn.BackgroundColor3 = Theme.SidebarBtn
tpMouseBtn.TextColor3 = Theme.Text tpMouseBtn.Font = Enum.Font.GothamBold tpMouseBtn.TextSize = 13
tpMouseBtn.Text = "Dịch Đến Chuột (TP to Mouse)" tpMouseBtn.BorderSizePixel = 0 tpMouseBtn.ZIndex = 54 tpMouseBtn.Parent = tpTab
local tmc = Instance.new("UICorner") tmc.CornerRadius = UDim.new(0, 8) tmc.Parent = tpMouseBtn
bindClick(tpMouseBtn, function()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") and Mouse.Hit then char.HumanoidRootPart.CFrame = Mouse.Hit + Vector3.new(0, 3, 0) end
end)

local toggleTeleOverlayBtn = Instance.new("TextButton")
toggleTeleOverlayBtn.Size = UDim2.new(1, -10, 0, 35) toggleTeleOverlayBtn.BackgroundColor3 = Theme.SidebarBtn
toggleTeleOverlayBtn.TextColor3 = Theme.Text toggleTeleOverlayBtn.Font = Enum.Font.GothamBold
toggleTeleOverlayBtn.TextSize = 13 toggleTeleOverlayBtn.Text = "HIỆN BẢNG TELE (NGOÀI)"
toggleTeleOverlayBtn.BorderSizePixel = 0 toggleTeleOverlayBtn.ZIndex = 54 toggleTeleOverlayBtn.Parent = tpTab
local tto = Instance.new("UICorner") tto.CornerRadius = UDim.new(0, 8) tto.Parent = toggleTeleOverlayBtn
bindClick(toggleTeleOverlayBtn, function()
    teleOverlay.Visible = not teleOverlay.Visible
    if teleOverlay.Visible then
        toggleTeleOverlayBtn.Text = "ẨN BẢNG TELE (NGOÀI)" toggleTeleOverlayBtn.BackgroundColor3 = Theme.AccentPink
    else
        toggleTeleOverlayBtn.Text = "HIỆN BẢNG TELE (NGOÀI)" toggleTeleOverlayBtn.BackgroundColor3 = Theme.SidebarBtn
    end
end)

local plrScroll = Instance.new("ScrollingFrame")
plrScroll.Size = UDim2.new(1, -10, 0, 200) plrScroll.BackgroundTransparency = 1
plrScroll.BorderSizePixel = 0 plrScroll.ScrollBarThickness = 4 plrScroll.ZIndex = 54
plrScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y plrScroll.Parent = tpTab
local plrLayout = Instance.new("UIListLayout") plrLayout.Padding = UDim.new(0, 3) plrLayout.Parent = plrScroll

local function updatePlayerList()
    for _, child in pairs(plrScroll:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, 0, 0, 30) btn.BackgroundColor3 = Theme.SidebarBtn
            btn.TextColor3 = Theme.Text btn.Font = Enum.Font.GothamBold btn.TextSize = 12
            btn.Text = "Tele đến: " .. plr.Name btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = plrScroll
            local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
            bindClick(btn, function()
                local targetChar = plr.Character
                local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if targetHrp and myHrp then myHrp.CFrame = targetHrp.CFrame + Vector3.new(0, 3, 0) end
            end)
        end
    end
end
updatePlayerList()
table.insert(Connections, Players.PlayerAdded:Connect(updatePlayerList))
table.insert(Connections, Players.PlayerRemoving:Connect(function() task.wait(1) updatePlayerList() end))

-- ==========================================
-- TAB 7: MISC
-- ==========================================
local miscTab = createTab("Misc", "⚙️")
createToggle(miscTab, "Anti-AFK (Chống treo)", false, function(s) States.AntiAFK = s end)
createToggle(miscTab, "Fullbright (Sáng bản đồ)", false, function(s)
    States.Fullbright = s
    if s then
        Lighting.Brightness = 2 Lighting.ClockTime = 12 Lighting.GlobalShadows = false Lighting.FogEnd = 9e9
    else
        Lighting.Brightness = 1 Lighting.ClockTime = 14 Lighting.GlobalShadows = true Lighting.FogEnd = 100000
    end
end)
createToggle(miscTab, "Chống Rơi Vực (Anti-Void)", false, function(s) States.AntiVoid = s end)
createToggle(miscTab, "Mở Khóa FPS (Unlock FPS)", false, function(s)
    States.UnlockFPS = s
    if setfpscap then pcall(function() if s then setfpscap(240) else setfpscap(60) end end) end
end)
createToggle(miscTab, "Auto Clicker", false, function(s)
    States.AutoClick = s
    if s then
        if autoClickThread then task.cancel(autoClickThread) end
        autoClickThread = task.spawn(function() while States.AutoClick do task.wait(0.1) VirtualUser:CaptureController() VirtualUser:ClickButton1(Vector2.new(500, 500)) end end)
    else
        if autoClickThread then task.cancel(autoClickThread) autoClickThread = nil end
    end
end)
createToggle(miscTab, "Remove Particles", false, function(s)
    States.RemoveParticles = s
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Smoke") or obj:IsA("Fire") then obj.Enabled = not s end
    end
end)

-- ==========================================
-- TAB 8: SCAN ITEM
-- ==========================================
local scanItemTab = createTab("Scan Item", "🔍")
local itemInputBox = Instance.new("TextBox")
itemInputBox.Size = UDim2.new(1, -10, 0, 35) itemInputBox.BackgroundColor3 = Theme.SidebarBtn
itemInputBox.TextColor3 = Theme.Text itemInputBox.PlaceholderText = "Nhập tên vật phẩm (VD: coin)..."
itemInputBox.PlaceholderColor3 = Theme.TextDim itemInputBox.Text = "" itemInputBox.TextSize = 13
itemInputBox.Font = Enum.Font.GothamBold itemInputBox.BorderSizePixel = 0 itemInputBox.ClearTextOnFocus = false
itemInputBox.ZIndex = 54 itemInputBox.Parent = scanItemTab
local iic = Instance.new("UICorner") iic.CornerRadius = UDim.new(0, 8) iic.Parent = itemInputBox

local scanWinBtn = Instance.new("TextButton")
scanWinBtn.Size = UDim2.new(1, -10, 0, 35) scanWinBtn.BackgroundColor3 = Theme.AccentPink
scanWinBtn.TextColor3 = Theme.Text scanWinBtn.Font = Enum.Font.GothamBold scanWinBtn.TextSize = 13
scanWinBtn.Text = "QUÉT WINPART" scanWinBtn.BorderSizePixel = 0 scanWinBtn.ZIndex = 54 scanWinBtn.Parent = scanItemTab
local swb = Instance.new("UICorner") swb.CornerRadius = UDim.new(0, 8) swb.Parent = scanWinBtn

local scanItemBtn = Instance.new("TextButton")
scanItemBtn.Size = UDim2.new(1, -10, 0, 35) scanItemBtn.BackgroundColor3 = Theme.AccentPurple
scanItemBtn.TextColor3 = Theme.Text scanItemBtn.Font = Enum.Font.GothamBold scanItemBtn.TextSize = 13
scanItemBtn.Text = "QUÉT VẬT PHẨM (THEO TÊN)" scanItemBtn.BorderSizePixel = 0 scanItemBtn.ZIndex = 54 scanItemBtn.Parent = scanItemTab
local sib = Instance.new("UICorner") sib.CornerRadius = UDim.new(0, 8) sib.Parent = scanItemBtn

createSlider(scanItemTab, "Auto TP Delay", 0, 2.0, 0, function(v) States.ItemTpSpeed = v end)

local itemListFrame = Instance.new("ScrollingFrame")
itemListFrame.Size = UDim2.new(1, -10, 0, 250) itemListFrame.BackgroundColor3 = Theme.SidebarBtn
itemListFrame.BackgroundTransparency = 0.5 itemListFrame.BorderSizePixel = 0 itemListFrame.ScrollBarThickness = 6
itemListFrame.ScrollBarImageColor3 = Theme.AccentPink itemListFrame.ZIndex = 54
itemListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y itemListFrame.Parent = scanItemTab
local ilf = Instance.new("UICorner") ilf.CornerRadius = UDim.new(0, 8) ilf.Parent = itemListFrame
local ilLayout = Instance.new("UIListLayout") ilLayout.Padding = UDim.new(0, 4) ilLayout.Parent = itemListFrame

local function getObjDistance(target)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp or not target or not target.Parent then return "..." end
    local targetPos = nil
    if target:IsA("BasePart") then targetPos = target.Position
    elseif target:IsA("Model") then
        local ok, pivot = pcall(function() return target:GetPivot() end)
        if ok then targetPos = pivot.Position elseif target.PrimaryPart then targetPos = target.PrimaryPart.Position end
    end
    if targetPos then return math.floor((hrp.Position - targetPos).Magnitude) .. "m" end
    return "..."
end

local function addItemToUI(obj, nameOverride)
    table.insert(scannedItems, obj)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -8, 0, 30) btn.BackgroundColor3 = Theme.SidebarBtn btn.TextColor3 = Theme.Text
    btn.Font = Enum.Font.GothamBold btn.TextSize = 12 btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = itemListFrame
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 6) c.Parent = btn
    local baseText = "📦 " .. (nameOverride or obj.Name)
    btn.Text = baseText .. " | Cách: " .. getObjDistance(obj)
    task.spawn(function()
        while btn and btn.Parent do
            task.wait(0.5)
            if obj and obj.Parent then btn.Text = baseText .. " | Cách: " .. getObjDistance(obj)
            else btn.Text = baseText .. " | Cách: N/A" end
        end
    end)
    bindClick(btn, function()
        selectedItemForLoop = obj
        for _, child in pairs(itemListFrame:GetChildren()) do if child:IsA("TextButton") then child.BackgroundColor3 = Theme.SidebarBtn end end
        btn.BackgroundColor3 = Theme.AccentPink
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local targetPos = nil
            if obj:IsA("BasePart") then targetPos = obj.Position
            elseif obj:IsA("Model") then
                local ok, pivot = pcall(function() return obj:GetPivot() end)
                if ok then targetPos = pivot.Position elseif obj.PrimaryPart then targetPos = obj.PrimaryPart.Position end
            end
            if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
        end
    end)
end

local function performScan(isWinScan)
    local query = string.lower(itemInputBox.Text)
    if not isWinScan and query == "" then
        scanItemBtn.Text = "VUI LÒNG NHẬP TÊN!" task.wait(1.5) scanItemBtn.Text = "QUÉT VẬT PHẨM (THEO TÊN)" return
    end
    for _, child in pairs(itemListFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
    table.clear(scannedItems) selectedItemForLoop = nil
    local all = Workspace:GetDescendants() local total = #all local processed = 0 local count = 0
    for _, obj in ipairs(all) do
        processed = processed + 1
        if processed % 100 == 0 then
            if isWinScan then scanWinBtn.Text = "ĐANG QUÉT: " .. processed .. " / " .. total
            else scanItemBtn.Text = "ĐANG QUÉT: " .. processed .. " / " .. total end
            task.wait()
        end
        if (obj:IsA("BasePart") or obj:IsA("Model")) and not obj:IsDescendantOf(LocalPlayer.Character) then
            local nameLower = string.lower(obj.Name)
            local m = false
            if isWinScan then if string.find(nameLower, "winpart") then m = true end
            else if string.find(nameLower, query) then m = true end end
            if m then addItemToUI(obj) count = count + 1 end
        end
    end
    if isWinScan then scanWinBtn.Text = "TÌM THẤY: " .. count .. " WINPART"
    else scanItemBtn.Text = "TÌM THẤY: " .. count .. " VẬT PHẨM" end
end
bindClick(scanWinBtn, function() performScan(true) end)
bindClick(scanItemBtn, function() performScan(false) end)

createToggle(scanItemTab, "Auto Teleport Item (All)", false, function(s)
    States.AutoItemTp = s
    if s then
        if #scannedItems == 0 then performScan(true) task.wait(0.5) end
        if autoItemTpThread then task.cancel(autoItemTpThread) end
        autoItemTpThread = task.spawn(function()
            while States.AutoItemTp do
                if #scannedItems == 0 then performScan(true) task.wait(1)
                else
                    for _, item in ipairs(scannedItems) do
                        if not States.AutoItemTp then break end
                        if item and item.Parent then
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local targetPos = nil
                                if item:IsA("BasePart") then targetPos = item.Position
                                elseif item:IsA("Model") then
                                    local ok, pivot = pcall(function() return item:GetPivot() end)
                                    if ok then targetPos = pivot.Position elseif item.PrimaryPart then targetPos = item.PrimaryPart.Position end
                                end
                                if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
                            end
                            if States.ItemTpSpeed > 0 then task.wait(States.ItemTpSpeed) else RunService.Heartbeat:Wait() end
                        end
                    end
                    if States.AutoItemTp then table.clear(scannedItems) performScan(true) task.wait(0.5) end
                end
            end
        end)
    else
        if autoItemTpThread then task.cancel(autoItemTpThread) autoItemTpThread = nil end
    end
end)

createToggle(scanItemTab, "AUTO TP SELECTED (Vật phẩm đã chọn)", false, function(s)
    States.AutoTpSelected = s
    if s then
        if not selectedItemForLoop then States.AutoTpSelected = false return end
        if autoTpSelectedThread then task.cancel(autoTpSelectedThread) end
        autoTpSelectedThread = task.spawn(function()
            while States.AutoTpSelected do
                if selectedItemForLoop and selectedItemForLoop.Parent then
                    local char = LocalPlayer.Character
                    local hrp = char and char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        local targetPos = nil
                        if selectedItemForLoop:IsA("BasePart") then targetPos = selectedItemForLoop.Position
                        elseif selectedItemForLoop:IsA("Model") then
                            local ok, pivot = pcall(function() return selectedItemForLoop:GetPivot() end)
                            if ok then targetPos = pivot.Position elseif selectedItemForLoop.PrimaryPart then targetPos = selectedItemForLoop.PrimaryPart.Position end
                        end
                        if targetPos then hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 5, 0)) end
                    end
                else States.AutoTpSelected = false end
                if States.ItemTpSpeed > 0 then task.wait(States.ItemTpSpeed) else RunService.Heartbeat:Wait() end
            end
        end)
    else
        if autoTpSelectedThread then task.cancel(autoTpSelectedThread) autoTpSelectedThread = nil end
    end
end)

-- ==========================================
-- TAB 9: GAME (AUTO REBIRTH) — BRUTE-SCAN, DELAY=0
-- ==========================================
getgenv().HTrungRebirth = { enabled = false, thread = nil, counter = 0, delay = 0, learned = {} }

pcall(function()
    local gameTab = createTab("Game", "🎯")
    local RB = getgenv().HTrungRebirth

    local function getRebirthCount()
        local ls = LocalPlayer:FindFirstChild("leaderstats")
        if ls then
            for _, v in ipairs(ls:GetChildren()) do
                if v:IsA("IntValue") or v:IsA("NumberValue") then
                    local n = string.lower(v.Name)
                    if string.find(n, "rebirth") or string.find(n, "reborn") or string.find(n, "prestige") or
                       string.find(n, "ascend") or string.find(n, "reset") or string.find(n, "taisinh") then
                        return v.Value
                    end
                end
            end
        end
        for _, attr in ipairs({"Rebirths","Rebirth","RebirthCount","Prestige","Prestiges","Reset","RebirthsCount"}) do
            local ok, v = pcall(function() return LocalPlayer:GetAttribute(attr) end)
            if ok and v and type(v) == "number" then return v end
        end
        for _, obj in ipairs(LocalPlayer:GetChildren()) do
            if obj:IsA("IntValue") or obj:IsA("NumberValue") then
                local n = string.lower(obj.Name)
                if string.find(n, "rebirth") or string.find(n, "reborn") or string.find(n, "prestige") then
                    return obj.Value
                end
            end
        end
        return nil
    end

    local rebirthStatus = Instance.new("TextLabel")
    rebirthStatus.Size = UDim2.new(1, -10, 0, 34) rebirthStatus.BackgroundColor3 = Theme.SidebarBtn
    rebirthStatus.BackgroundTransparency = 0.5 rebirthStatus.TextColor3 = Theme.Text
    rebirthStatus.Font = Enum.Font.GothamBold rebirthStatus.TextSize = 12
    rebirthStatus.Text = "Trạng thái: Chưa có lệnh. Bấm QUÉT."
    rebirthStatus.BorderSizePixel = 0 rebirthStatus.ZIndex = 54 rebirthStatus.Parent = gameTab
    local rsc = Instance.new("UICorner") rsc.CornerRadius = UDim.new(0, 8) rsc.Parent = rebirthStatus

    local logBox = Instance.new("ScrollingFrame")
    logBox.Size = UDim2.new(1, -10, 0, 150) logBox.BackgroundColor3 = Theme.MainBG
    logBox.BackgroundTransparency = 0.3 logBox.BorderSizePixel = 0 logBox.ScrollBarThickness = 4
    logBox.ScrollBarImageColor3 = Theme.AccentPink logBox.ZIndex = 54
    logBox.AutomaticCanvasSize = Enum.AutomaticSize.Y logBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    logBox.Parent = gameTab
    local lbc = Instance.new("UICorner") lbc.CornerRadius = UDim.new(0, 8) lbc.Parent = logBox
    local ll = Instance.new("UIListLayout") ll.Padding = UDim.new(0, 2) ll.Parent = logBox

    local function logUI(text, color)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -6, 0, 16) lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color or Theme.TextDim lbl.Font = Enum.Font.Code lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left lbl.Text = "> " .. text lbl.ZIndex = 55 lbl.Parent = logBox
        task.defer(function() logBox.CanvasPosition = Vector2.new(0, ll.AbsoluteContentSize.Y) end)
    end

    local scanning = false

    local function scanAndLearn()
        if scanning then return end
        scanning = true
        local before = getRebirthCount()
        if before == nil then
            logUI("⚠ Không tìm thấy stat rebirth (leaderstats/attribute)", Theme.AccentPink)
            logUI("  Vẫn thử fire tất cả ứng viên (sẽ không verify được)", Theme.TextDim)
        else
            logUI("Stat rebirth hiện tại: " .. tostring(before), Theme.AccentCyan)
        end

        local candidates = {}
        local kws = {
            {"rebirth", 1}, {"reborn", 1}, {"taisinh", 1},
            {"prestige", 2}, {"ascend", 2},
            {"reset", 3}, {"evolve", 3}
        }

        local ok1, rs = pcall(function() return game:GetService("ReplicatedStorage"):GetDescendants() end)
        if ok1 and rs then
            for _, remote in ipairs(rs) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    local n = string.lower(remote.Name)
                    for _, kw in ipairs(kws) do
                        if string.find(n, kw[1], 1, true) then
                            table.insert(candidates, {remote = remote, priority = kw[2], isButton = false}) break
                        end
                    end
                end
            end
        end

        local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
        if playerGui then
            for _, gui in ipairs(playerGui:GetChildren()) do
                for _, obj in ipairs(gui:GetDescendants()) do
                    if obj:IsA("TextButton") or obj:IsA("ImageButton") then
                        local n = string.lower(obj.Name)
                        local t = "" pcall(function() t = string.lower(obj.Text) end)
                        for _, kw in ipairs(kws) do
                            if string.find(n, kw[1], 1, true) or string.find(t, kw[1], 1, true) then
                                table.insert(candidates, {button = obj, priority = kw[2], isButton = true}) break
                            end
                        end
                    end
                end
            end
        end

        table.sort(candidates, function(a, b) return a.priority < b.priority end)
        logUI("Tìm thấy " .. #candidates .. " ứng viên. Bắt đầu thử...", Theme.AccentCyan)

        RB.learned = {}
        local currentStat = before
        for i, c in ipairs(candidates) do
            if before ~= nil and currentStat ~= nil and currentStat > before then break end
            local name = c.isButton and c.button:GetFullName() or c.remote:GetFullName()
            logUI("Thử #" .. i .. ": " .. name, Theme.TextDim)

            pcall(function()
                if c.isButton then
                    if firesignal then firesignal(c.button.MouseButton1Click) end
                    pcall(function() c.button:Activate() end)
                else
                    if c.remote:IsA("RemoteEvent") then c.remote:FireServer()
                    else c.remote:InvokeServer() end
                end
            end)

            task.wait(1.2)
            local after = getRebirthCount()
            if before ~= nil and after ~= nil and after > currentStat then
                logUI("✅ ĐÚNG: " .. name, Theme.AccentCyan)
                if c.isButton then
                    table.insert(RB.learned, {button = c.button})
                else
                    table.insert(RB.learned, {remote = c.remote, method = c.remote:IsA("RemoteEvent") and "FireServer" or "InvokeServer"})
                end
                currentStat = after
            else
                logUI("  -> không đổi", Theme.TextDim)
            end
        end

        if #RB.learned > 0 then
            rebirthStatus.Text = "Đã học " .. #RB.learned .. " lệnh. Sẵn sàng."
            rebirthStatus.TextColor3 = Theme.AccentCyan
        elseif #candidates == 0 then
            rebirthStatus.Text = "Không có ứng viên nào"
            rebirthStatus.TextColor3 = Theme.AccentPink
        else
            rebirthStatus.Text = "Không lệnh nào tăng stat"
            rebirthStatus.TextColor3 = Theme.AccentPink
        end
        scanning = false
    end

    local scanBtn = Instance.new("TextButton")
    scanBtn.Size = UDim2.new(1, -10, 0, 42) scanBtn.BackgroundColor3 = Theme.AccentCyan
    scanBtn.TextColor3 = Theme.Text scanBtn.Font = Enum.Font.GothamBlack scanBtn.TextSize = 12
    scanBtn.Text = "🔍 QUÉT VÀ HỌC LỆNH (tự tìm lệnh tái sinh)"
    scanBtn.BorderSizePixel = 0 scanBtn.ZIndex = 54 scanBtn.Parent = gameTab
    local sbc = Instance.new("UICorner") sbc.CornerRadius = UDim.new(0, 8) sbc.Parent = scanBtn
    bindClick(scanBtn, function() task.spawn(scanAndLearn) end)

    local manualBtn = Instance.new("TextButton")
    manualBtn.Size = UDim2.new(1, -10, 0, 38) manualBtn.BackgroundColor3 = Theme.AccentPurple
    manualBtn.TextColor3 = Theme.Text manualBtn.Font = Enum.Font.GothamBlack manualBtn.TextSize = 13
    manualBtn.Text = "⚡ TÁI SINH NGAY (replay lệnh đã học)"
    manualBtn.BorderSizePixel = 0 manualBtn.ZIndex = 54 manualBtn.Parent = gameTab
    local mbc = Instance.new("UICorner") mbc.CornerRadius = UDim.new(0, 8) mbc.Parent = manualBtn
    bindClick(manualBtn, function()
        if #RB.learned == 0 then
            rebirthStatus.Text = "Chưa có lệnh! Bấm QUÉT trước."
            rebirthStatus.TextColor3 = Theme.AccentPink
            return
        end
        local before = getRebirthCount()
        for _, e in ipairs(RB.learned) do
            pcall(function()
                if e.button then
                    if firesignal then firesignal(e.button.MouseButton1Click) end
                    pcall(function() e.button:Activate() end)
                elseif e.remote then
                    if e.method == "FireServer" then e.remote:FireServer()
                    else e.remote:InvokeServer() end
                end
            end)
        end
        task.wait(1.5)
        local after = getRebirthCount()
        if before ~= nil and after ~= nil then
            if after > before then
                rebirthStatus.Text = "✅ OK! Stat " .. before .. " → " .. after
                rebirthStatus.TextColor3 = Theme.AccentCyan
            else
                rebirthStatus.Text = "⚠ Stat không đổi (" .. before .. " → " .. after .. ")"
                rebirthStatus.TextColor3 = Theme.AccentGold
            end
        else
            rebirthStatus.Text = "Đã gửi (không có stat verify)"
            rebirthStatus.TextColor3 = Theme.AccentGold
        end
    end)

    createSlider(gameTab, "Delay auto (giây)", 0, 30.0, 0, function(v) RB.delay = v end)

    createToggle(gameTab, "Auto Rebirth (tự động tái sinh)", false, function(s)
        RB.enabled = s
        if s then
            if #RB.learned == 0 then
                logUI("Chưa có lệnh → tự quét trước...", Theme.AccentGold)
                scanAndLearn()
                if #RB.learned == 0 then
                    RB.enabled = false
                    rebirthStatus.Text = "Không quét được lệnh"
                    rebirthStatus.TextColor3 = Theme.AccentPink
                    return
                end
            end
            if RB.thread then pcall(task.cancel, RB.thread) end
            RB.thread = task.spawn(function()
                while RB.enabled do
                    local before = getRebirthCount()
                    for _, e in ipairs(RB.learned) do
                        if not RB.enabled then break end
                        pcall(function()
                            if e.button then
                                if firesignal then firesignal(e.button.MouseButton1Click) end
                                pcall(function() e.button:Activate() end)
                            elseif e.remote then
                                if e.method == "FireServer" then e.remote:FireServer()
                                else e.remote:InvokeServer() end
                            end
                        end)
                    end
                    local verifyWait = (RB.delay <= 0) and 0.3 or 1.0
                    task.wait(verifyWait)
                    local after = getRebirthCount()
                    if before ~= nil and after ~= nil and after > before then
                        RB.counter = RB.counter + 1
                        rebirthStatus.Text = "✅ Tái sinh #" .. RB.counter .. " (" .. before .. "→" .. after .. ")"
                        rebirthStatus.TextColor3 = Theme.AccentCyan
                        logUI("OK #" .. RB.counter, Theme.AccentCyan)
                    else
                        rebirthStatus.Text = "Đã gửi (chưa thấy đổi stat)"
                        rebirthStatus.TextColor3 = Theme.AccentGold
                    end
                    if not RB.enabled then break end
                    if RB.delay <= 0 then
                        RunService.Heartbeat:Wait()
                    else
                        task.wait(RB.delay)
                    end
                end
                rebirthStatus.Text = "Trạng thái: Đã tắt"
                rebirthStatus.TextColor3 = Theme.Text
            end)
        else
            if RB.thread then pcall(task.cancel, RB.thread) RB.thread = nil end
            rebirthStatus.Text = "Trạng thái: Đã tắt"
            rebirthStatus.TextColor3 = Theme.Text
        end
    end)

    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(1, -10, 0, 30) clearBtn.BackgroundColor3 = Theme.SidebarBtn
    clearBtn.TextColor3 = Theme.AccentPink clearBtn.Font = Enum.Font.GothamBold clearBtn.TextSize = 12
    clearBtn.Text = "🗑️ XÓA LỆNH ĐÃ HỌC" clearBtn.BorderSizePixel = 0 clearBtn.ZIndex = 54 clearBtn.Parent = gameTab
    local cbc = Instance.new("UICorner") cbc.CornerRadius = UDim.new(0, 8) cbc.Parent = clearBtn
    bindClick(clearBtn, function()
        RB.learned = {} RB.counter = 0
        rebirthStatus.Text = "Đã xóa." rebirthStatus.TextColor3 = Theme.Text
        logUI("Cleared.", Theme.AccentPink)
    end)
end)

-- ==========================================
-- TAB 10: SETTINGS
-- ==========================================
local settingsTab = createTab("Cài Đặt", "🛠️")
local colorTitle = Instance.new("TextLabel")
colorTitle.Size = UDim2.new(1, -10, 0, 25) colorTitle.BackgroundTransparency = 1
colorTitle.TextColor3 = Color3.fromRGB(255, 215, 0) colorTitle.Font = Enum.Font.GothamBold
colorTitle.TextSize = 14 colorTitle.TextXAlignment = Enum.TextXAlignment.Left
colorTitle.Text = "Đổi Màu Chủ Đạo" colorTitle.ZIndex = 54 colorTitle.Parent = settingsTab

local colorFrame = Instance.new("Frame")
colorFrame.Size = UDim2.new(1, -10, 0, 45) colorFrame.BackgroundColor3 = Theme.SidebarBtn
colorFrame.BackgroundTransparency = 0.5 colorFrame.BorderSizePixel = 0 colorFrame.ZIndex = 54 colorFrame.Parent = settingsTab
local cfc = Instance.new("UICorner") cfc.CornerRadius = UDim.new(0, 8) cfc.Parent = colorFrame
local cfl = Instance.new("UIListLayout")
cfl.FillDirection = Enum.FillDirection.Horizontal cfl.HorizontalAlignment = Enum.HorizontalAlignment.Center
cfl.VerticalAlignment = Enum.VerticalAlignment.Center cfl.Padding = UDim.new(0, 10) cfl.Parent = colorFrame

local function createColorBtn(color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 25, 0, 25) btn.BackgroundColor3 = color btn.Text = ""
    btn.BorderSizePixel = 0 btn.ZIndex = 55 btn.Parent = colorFrame
    local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = btn
    bindClick(btn, function()
        Theme.AccentPink = color Theme.SidebarBtnActive = color
        Theme.AccentPurple = Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7)
        ms.Color = color openBtnStroke.Color = color
        if ColorableElements.ActiveTabBtn then ColorableElements.ActiveTabBtn.BackgroundColor3 = color end
        for _, data in ipairs(ColorableElements.Toggles) do if data.State then data.Button.BackgroundColor3 = color end end
    end)
end
createColorBtn(Color3.fromRGB(255, 105, 180))
createColorBtn(Color3.fromRGB(255, 182, 193))
createColorBtn(Color3.fromRGB(0, 150, 255))
createColorBtn(Color3.fromRGB(50, 255, 100))
createColorBtn(Color3.fromRGB(255, 150, 0))
createColorBtn(Color3.fromRGB(150, 50, 255))

local bgTitle = Instance.new("TextLabel")
bgTitle.Size = UDim2.new(1, -10, 0, 25) bgTitle.BackgroundTransparency = 1
bgTitle.TextColor3 = Color3.fromRGB(255, 215, 0) bgTitle.Font = Enum.Font.GothamBold
bgTitle.TextSize = 14 bgTitle.TextXAlignment = Enum.TextXAlignment.Left
bgTitle.Text = "Đổi Hình Nền (Nhập ID ảnh)" bgTitle.ZIndex = 54 bgTitle.Parent = settingsTab

local bgInputFrame = Instance.new("Frame")
bgInputFrame.Size = UDim2.new(1, -10, 0, 45) bgInputFrame.BackgroundColor3 = Theme.SidebarBtn
bgInputFrame.BackgroundTransparency = 0.5 bgInputFrame.BorderSizePixel = 0 bgInputFrame.ZIndex = 54 bgInputFrame.Parent = settingsTab
local bifc = Instance.new("UICorner") bifc.CornerRadius = UDim.new(0, 8) bifc.Parent = bgInputFrame
local bifp = Instance.new("UIPadding")
bifp.PaddingTop = UDim.new(0, 8) bifp.PaddingBottom = UDim.new(0, 8)
bifp.PaddingLeft = UDim.new(0, 8) bifp.PaddingRight = UDim.new(0, 8) bifp.Parent = bgInputFrame

local bgInput = Instance.new("TextBox")
bgInput.Size = UDim2.new(1, -80, 1, 0) bgInput.Position = UDim2.new(0, 0, 0, 0)
bgInput.BackgroundColor3 = Theme.MainBG bgInput.TextColor3 = Theme.Text
bgInput.PlaceholderText = "Nhập ID ảnh (VD: 13476434849)" bgInput.PlaceholderColor3 = Theme.TextDim
bgInput.Text = "13476434849" bgInput.TextSize = 13 bgInput.Font = Enum.Font.GothamBold
bgInput.BorderSizePixel = 0 bgInput.ClearTextOnFocus = false bgInput.ZIndex = 55 bgInput.Parent = bgInputFrame
local bic = Instance.new("UICorner") bic.CornerRadius = UDim.new(0, 6) bic.Parent = bgInput

local applyBgBtn = Instance.new("TextButton")
applyBgBtn.Size = UDim2.new(0, 70, 1, 0) applyBgBtn.Position = UDim2.new(1, -70, 0, 0)
applyBgBtn.BackgroundColor3 = Theme.AccentPink applyBgBtn.TextColor3 = Theme.Text
applyBgBtn.Font = Enum.Font.GothamBold applyBgBtn.TextSize = 13 applyBgBtn.Text = "Áp Dụng"
applyBgBtn.BorderSizePixel = 0 applyBgBtn.ZIndex = 55 applyBgBtn.Parent = bgInputFrame
local abc = Instance.new("UICorner") abc.CornerRadius = UDim.new(0, 6) abc.Parent = applyBgBtn
bindClick(applyBgBtn, function()
    local id = bgInput.Text
    if id ~= "" then id = string.gsub(id, "rbxassetid://", "") bgImage.Image = "rbxassetid://" .. id end
end)

local firstTab = sidebar:GetChildren()[1]
if firstTab and firstTab:IsA("TextButton") then
    firstTab.BackgroundTransparency = 0.1 firstTab.TextColor3 = Theme.Text
    firstTab:FindFirstChild("UIStroke").Thickness = 1
    firstTab:FindFirstChild("UIStroke").Color = Theme.AccentCyan
    infoTab.Visible = true ColorableElements.ActiveTabBtn = firstTab
end

-- ==========================================
-- LOGIC UPDATES & HEARTBEAT
-- ==========================================
local lastFpsUpdate = tick() local frameCount = 0
table.insert(Connections, RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    if tick() - lastFpsUpdate >= 1 then
        currentFps = frameCount frameCount = 0 lastFpsUpdate = tick()
        fpsLabel.Text = "FPS: " .. currentFps
    end
end))

task.spawn(function()
    while task.wait(1) do
        pcall(function() currentPing = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        pingLabel.Text = "Ping: " .. currentPing .. " ms"
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local pos = char.HumanoidRootPart.Position
            posLabel.Text = string.format("Pos: %d, %d, %d", pos.X, pos.Y, pos.Z)
        end
        timeLbl.Text = "Giờ: " .. os.date("%H:%M:%S")
        local playSecs = math.floor(tick() - joinTime)
        playtimeLbl.Text = string.format("Đã chơi: %02d:%02d:%02d", math.floor(playSecs/3600), math.floor((playSecs%3600)/60), playSecs%60)
    end
end)

table.insert(Connections, RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    if States.AntiFling and hrp.Velocity.Magnitude > 50 then hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0) end
    if States.Glide and hum:GetState() == Enum.HumanoidStateType.Freefall and hrp.Velocity.Y < -15 then hrp.Velocity = Vector3.new(hrp.Velocity.X, -15, hrp.Velocity.Z) end
    if States.AntiVoid and hrp.Position.Y < -50 then hrp.CFrame = CFrame.new(0, 50, 0) end
    if States.XRay then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj:IsDescendantOf(char) then obj.LocalTransparencyModifier = 0.5 end
        end
    end
    if States.ItemESP then
        for _, obj in pairs(Workspace:GetDescendants()) do
            if (obj:IsA("BasePart") or obj:IsA("Model")) and not obj:IsDescendantOf(char) then
                local n = string.lower(obj.Name)
                if string.find(n, "coin") or string.find(n, "cash") or string.find(n, "gem") or string.find(n, "xu") then
                    if not obj:FindFirstChild("LermItemESP") then
                        local h = Instance.new("Highlight") h.Name = "LermItemESP" h.FillColor = Theme.AccentPink h.OutlineColor = Theme.Text h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = obj
                        table.insert(ESPObjects, h)
                    end
                end
            end
        end
    end
    if States.Noclip then
        for _, p in pairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end
    end
    if not States.FreeCam then
        local targetSpeed = States.Speed * States.GameSpeed
        local targetJump = States.JumpPower * States.GameSpeed
        if targetSpeed > 5000 then targetSpeed = 5000 end
        if targetJump > 5000 then targetJump = 5000 end
        if hum.WalkSpeed ~= targetSpeed then hum.WalkSpeed = targetSpeed end
        if hum.JumpPower ~= targetJump then hum.JumpPower = targetJump end
    end
    if States.Fly then
        local bv = hrp:FindFirstChild("LermMaxFlyVel") local bg = hrp:FindFirstChild("LermMaxFlyGyro")
        if not bv then
            hum.PlatformStand = true
            bv = Instance.new("BodyVelocity") bv.Name = "LermMaxFlyVel" bv.MaxForce = Vector3.new(1e9, 1e9, 1e9) bv.Velocity = Vector3.zero bv.Parent = hrp
            bg = Instance.new("BodyGyro") bg.Name = "LermMaxFlyGyro" bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9) bg.P = 10000 bg.D = 500 bg.CFrame = hrp.CFrame bg.Parent = hrp
        end
        if bv and bg then
            local dir = Vector3.zero
            if hum.MoveDirection.Magnitude > 0 then dir = hum.MoveDirection end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) or States.FlyUp then dir += Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or States.FlyDown then dir -= Vector3.new(0, 1, 0) end
            local flySpd = States.FlySpeed * States.GameSpeed
            if flySpd > 5000 then flySpd = 5000 end
            bv.Velocity = dir.Magnitude > 0 and dir.Unit * flySpd or Vector3.zero
            bg.CFrame = CFrame.new(hrp.Position, hrp.Position + Camera.CFrame.LookVector)
        end
    else
        local bv = hrp:FindFirstChild("LermMaxFlyVel") if bv then bv:Destroy() end
        local bg = hrp:FindFirstChild("LermMaxFlyGyro") if bg then bg:Destroy() end
        if hum.PlatformStand then hum.PlatformStand = false end
    end
    if States.ESP then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if not plr.Character.HumanoidRootPart:FindFirstChild("LermMaxESP") then
                    local h = Instance.new("Highlight") h.Name = "LermMaxESP" h.FillColor = Theme.AccentPink h.OutlineColor = Theme.Text h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop h.Parent = plr.Character
                    table.insert(ESPObjects, h)
                end
            end
        end
    end
    if States.Hitbox then
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                plr.Character.HumanoidRootPart.Size = Vector3.new(States.HitboxSize, States.HitboxSize, States.HitboxSize)
                plr.Character.HumanoidRootPart.Transparency = 0.7
                plr.Character.HumanoidRootPart.BrickColor = BrickColor.new("Really red")
                plr.Character.HumanoidRootPart.Material = Enum.Material.Neon
            end
        end
    else
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                if plr.Character.HumanoidRootPart.Size ~= Vector3.new(2, 2, 1) then
                    plr.Character.HumanoidRootPart.Size = Vector3.new(2, 2, 1)
                    plr.Character.HumanoidRootPart.Transparency = 1
                    plr.Character.HumanoidRootPart.Material = Enum.Material.Plastic
                end
            end
        end
    end
    if States.KillAura then
        local currentTime = tick()
        if currentTime - lastAuraAttack > 0.05 then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then
                local closestTarget = nil local shortestDist = States.AuraRange
                for _, plr in pairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.Character then
                        local targetHum = plr.Character:FindFirstChildOfClass("Humanoid")
                        local targetHrp = plr.Character:FindFirstChild("HumanoidRootPart") or plr.Character:FindFirstChild("Head")
                        if targetHum and targetHrp and targetHum.Health > 0 then
                            local dist = (hrp.Position - targetHrp.Position).Magnitude
                            if dist < shortestDist then shortestDist = dist closestTarget = targetHrp end
                        end
                    end
                end
                if closestTarget then Camera.CFrame = CFrame.new(Camera.CFrame.Position, closestTarget.Position) tool:Activate() lastAuraAttack = currentTime end
            end
        end
    elseif States.Aimbot and not States.FreeCam then
        local closestPlr = nil local shortestDist = math.huge
        for _, plr in pairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("Head") then
                local dist = (plr.Character.Head.Position - Camera.CFrame.Position).Magnitude
                if dist < shortestDist then shortestDist = dist closestPlr = plr.Character.Head end
            end
        end
        if closestPlr then Camera.CFrame = CFrame.new(Camera.CFrame.Position, closestPlr.Position) end
    end
    if States.AutoJump and not States.FreeCam then
        if hum:GetState() ~= Enum.HumanoidStateType.Jumping and hum:GetState() ~= Enum.HumanoidStateType.Freefall then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
    if States.AutoRun and not States.Fly and not States.FreeCam then
        local flatLook = Vector3.new(Camera.CFrame.LookVector.X, 0, Camera.CFrame.LookVector.Z)
        if flatLook.Magnitude > 0 then hum:Move(flatLook.Unit, true) hum:MoveTo(hrp.Position + flatLook.Unit * 10) end
    end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function(dt)
    if States.FreeCam then
        freeCamCFrame = CFrame.new(freeCamCFrame.Position) * CFrame.Angles(0, freeCamRotX, 0) * CFrame.Angles(freeCamRotY, 0, 0)
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) or freeCamInput.F then moveDir += Vector3.new(0, 0, -1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) or freeCamInput.B then moveDir += Vector3.new(0, 0, 1) end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) or freeCamInput.L then moveDir += Vector3.new(-1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) or freeCamInput.R then moveDir += Vector3.new(1, 0, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) or freeCamInput.U then moveDir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or freeCamInput.D then moveDir += Vector3.new(0, -1, 0) end
        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
            local finalMove = (freeCamCFrame.RightVector * moveDir.X) + (Vector3.new(0,1,0) * moveDir.Y) + (freeCamCFrame.LookVector * -moveDir.Z)
            freeCamCFrame = freeCamCFrame + (finalMove * States.FreeCamSpeed * States.GameSpeed * dt)
        end
        Camera.CFrame = freeCamCFrame
    else
        freeCamCFrame = Camera.CFrame
    end
end))

table.insert(Connections, UserInputService.InputChanged:Connect(function(input)
    if not States.FreeCam then return end
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Delta
        if delta.Magnitude > 0 then
            freeCamRotX = freeCamRotX - math.rad(delta.X * 0.5)
            freeCamRotY = math.clamp(freeCamRotY - math.rad(delta.Y * 0.5), math.rad(-89), math.rad(89))
        end
    end
end))

table.insert(Connections, UserInputService.JumpRequest:Connect(function()
    if States.InfJump and not States.FreeCam then
        local char = LocalPlayer.Character
        if char then local hum = char:FindFirstChildOfClass("Humanoid") if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end end
    end
end))

table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if States.AntiAFK then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end
end))

table.insert(Connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if States.Fly then States.Fly = false States.FlyUp = false States.FlyDown = false flyOverlay.Visible = false end
    if States.FreeCam then States.FreeCam = false fcOverlay.Visible = false Camera.CameraType = Enum.CameraType.Custom end
    if States.UnlockFPS and setfpscap then pcall(function() setfpscap(60) end) end
end))

gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

getgenv().HTrungCleanup = function()
    pcall(function()
        if getgenv().HTrungRebirth then
            getgenv().HTrungRebirth.enabled = false
            if getgenv().HTrungRebirth.thread then
                pcall(task.cancel, getgenv().HTrungRebirth.thread)
                getgenv().HTrungRebirth.thread = nil
            end
        end
    end)
    if autoItemTpThread then task.cancel(autoItemTpThread) end
    if autoTpSelectedThread then task.cancel(autoTpSelectedThread) end
    if godModeThread then task.cancel(godModeThread) end
    if autoClickThread then task.cancel(autoClickThread) end
    if oldRaycast then hookfunction(workspace.Raycast, oldRaycast) end
    if setfpscap then pcall(function() setfpscap(60) end) end
    if blur then blur:Destroy() end
    for _, conn in pairs(Connections) do if conn then conn:Disconnect() end end
    if gui then gui:Destroy() end
end