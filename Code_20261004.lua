-- ================= Neon Tracker v2 =================
-- 追踪半径 200 格 | 密码保护 | 瞄头/瞄身 | 白/黑名单
-- ====================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- ============ 密码 ============
local _key = {57, 49, 57, 56, 55, 56}
local SECRET = ""
for _, n in ipairs(_key) do SECRET = SECRET .. string.char(n) end

-- ============ 全局配置 ============
local Config = {
    AutoTrack = false,
    WallBang = true,
    TrackRadius = 200,
    AimPart = "Head",
    ListMode = "Blacklist",
    PlayerList = {},
}
_G.TrackerConfig = Config

-- ============ 追踪目标 ============
local currentTarget = nil

local function isInList(plr)
    for _, n in ipairs(Config.PlayerList) do
        if n == plr.Name or n == plr.DisplayName then return true end
    end
    return false
end

local function getClosestTarget()
    local myChar = LocalPlayer.Character
    if not myChar then return nil end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local myPos = myRoot.Position
    local myTeam = LocalPlayer.Team
    local closest, closestDist = nil, math.huge
    local radius = Config.TrackRadius

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if myTeam and plr.Team == myTeam then continue end

        local inList = isInList(plr)
        if Config.ListMode == "Whitelist" then
            if not inList then continue end
        else
            if inList then continue end
        end

        local char = plr.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local dist = (root.Position - myPos).Magnitude
        if dist > radius then continue end

        if dist < closestDist then
            closest = char
            closestDist = dist
        end
    end
    return closest
end

RunService.RenderStepped:Connect(function()
    if Config.AutoTrack then
        currentTarget = getClosestTarget()
    else
        currentTarget = nil
    end
end)

-- ============ Raycast Hook ============
local originalRaycast = Workspace.Raycast

local function newRaycast(self, origin, direction, userParams)
    if not Config.WallBang and not (Config.AutoTrack and currentTarget) then
        return originalRaycast(self, origin, direction, userParams)
    end

    local params = userParams or RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local filter = params.FilterDescendantsInstances or {}
    if LocalPlayer.Character and not table.find(filter, LocalPlayer.Character) then
        table.insert(filter, LocalPlayer.Character)
    end
    params.FilterDescendantsInstances = filter

    local actualDir = direction
    if Config.AutoTrack and currentTarget then
        local aimPart = currentTarget:FindFirstChild(Config.AimPart)
        if not aimPart then aimPart = currentTarget:FindFirstChild("HumanoidRootPart") end
        if aimPart then actualDir = aimPart.Position - origin end
    end

    if not Config.WallBang then
        return originalRaycast(self, origin, actualDir, params)
    end

    local maxDist = actualDir.Magnitude
    if maxDist < 0.01 then return nil end
    local dirUnit = actualDir.Unit
    local curOrigin = origin
    local traveled = 0

    while traveled < maxDist do
        local remain = maxDist - traveled
        local result = originalRaycast(self, curOrigin, dirUnit * remain, params)
        if not result then return nil end
        local hitInst = result.Instance
        local hitPos = result.Position
        traveled += (hitPos - curOrigin).Magnitude

        local model = hitInst:FindFirstAncestorOfClass("Model")
        local hum = model and model:FindFirstChildOfClass("Humanoid")
        if hum then return result end

        table.insert(params.FilterDescendantsInstances, hitInst)
        curOrigin = hitPos + dirUnit * 0.1
    end
    return nil
end

if hookfunction then
    hookfunction(Workspace.Raycast, newRaycast)
else
    Workspace.Raycast = newRaycast
end

-- ====================================================
-- ======================= UI =========================
-- ====================================================

if game.CoreGui:FindFirstChild("TrackerUI") then
    game.CoreGui.TrackerUI:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "TrackerUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = game.CoreGui

-- ========== 悬浮球 ==========
local ball = Instance.new("TextButton")
ball.Size = UDim2.new(0, 52, 0, 52)
ball.Position = UDim2.new(0, 40, 0, 200)
ball.BackgroundColor3 = Color3.new(15/255, 20/255, 30/255)
ball.Text = ""
ball.AutoLocalize = false
ball.BorderSizePixel = 0
ball.Parent = gui
Instance.new("UICorner", ball).CornerRadius = UDim.new(1,0)

local ballStroke = Instance.new("UIStroke")
ballStroke.Thickness = 1.5
ballStroke.Transparency = 0.15
ballStroke.Parent = ball

local ballGrad = Instance.new("UIGradient")
ballGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(0,200/255,255/255)),
    ColorSequenceKeypoint.new(1, Color3.new(160/255,0,255/255))
}
ballGrad.Parent = ballStroke

local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(1,0,1,0)
ballIcon.BackgroundTransparency = 1
ballIcon.Text = "◎"
ballIcon.TextColor3 = Color3.new(0,220/255,255/255)
ballIcon.Font = Enum.Font.GothamBold
ballIcon.TextSize = 26
ballIcon.Parent = ball

task.spawn(function()
    while ball.Parent do
        TweenService:Create(ballStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency=0.6}):Play()
        task.wait(1.2)
        TweenService:Create(ballStroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine), {Transparency=0.15}):Play()
        task.wait(1.2)
    end
end)

-- ========== 主面板 ==========
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0,230,0,400)
panel.BackgroundColor3 = Color3.new(15/255,18/255,28/255)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0,12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness =1.2
panelStroke.Transparency =0.4
panelStroke.Parent = panel

local psGrad = Instance.new("UIGradient")
psGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(0,200/255,255/255)),
    ColorSequenceKeypoint.new(1, Color3.new(160/255,0,255/255))
}
psGrad.Parent = panelStroke

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1,0,0,2)
topBar.BackgroundColor3 = Color3.new(0,200/255,255/255)
topBar.BorderSizePixel =0
topBar.Parent = panel
local tbGrad = Instance.new("UIGradient")
tbGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(0,200/255,255/255)),
    ColorSequenceKeypoint.new(1, Color3.new(160/255,0,255/255))
}
tbGrad.Parent = topBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1,-50,0,30)
title.Position = UDim2.new(0,14,0,6)
title.BackgroundTransparency =1
title.Text = "TRACKER"
title.TextColor3 = Color3.new(0,220/255,255/255)
title.Font = Enum.Font.GothamBold
title.TextSize =13
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,24,0,24)
closeBtn.Position = UDim2.new(1,-32,0,6)
closeBtn.BackgroundColor3 = Color3.new(30/255,36/255,52/255)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(200/255,220/255,255/255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize =16
closeBtn.BorderSizePixel =0
closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0,6)

-- ========== 总开关行 ==========
local masterRow = Instance.new("TextButton")
masterRow.Size = UDim2.new(1,-20,0,52)
masterRow.Position = UDim2.new(0,10,0,40)
masterRow.BackgroundColor3 = Color3.new(22/255,27/255,40/255)
masterRow.Text = ""
masterRow.BorderSizePixel =0
masterRow.Parent = panel
Instance.new("UICorner", masterRow).CornerRadius = UDim.new(0,10)

local mrIcon = Instance.new("TextLabel")
mrIcon.Size = UDim2.new(1,-100,1,0)
mrIcon.Position = UDim2.new(0,12,0,0)
mrIcon.BackgroundTransparency =1
mrIcon.Text = "自动追踪"
mrIcon.TextColor3 = Color3.new(220/255,230/255,255/255)
mrIcon.Font = Enum.Font.GothamBold
mrIcon.TextSize =13
mrIcon.TextXAlignment = Enum.TextXAlignment.Left
mrIcon.Parent = masterRow

local mrSub = Instance.new("TextLabel")
mrSub.Size = UDim2.new(1,-100,0,14)
mrSub.Position = UDim2.new(0,12,0.5,2)
mrSub.BackgroundTransparency =1
mrSub.Text = "锁定最近的敌人"
mrSub.TextColor3 = Color3.new(120/255,140/255,170/255)
mrSub.Font = Enum.Font.Gotham
mrSub.TextSize =10
mrSub.TextXAlignment = Enum.TextXAlignment.Left
mrSub.Parent = masterRow

local swTrack = Instance.new("Frame")
swTrack.Size = UDim2.new(0,42,0,22)
swTrack.Position = UDim2.new(1,-54,0.5,-11)
swTrack.BackgroundColor3 = Color3.new(60/255,70/255,90/255)
swTrack.BorderSizePixel =0
swTrack.Parent = masterRow
Instance.new("UICorner", swTrack).CornerRadius = UDim.new(1,0)

local swKnob = Instance.new("Frame")
swKnob.Size = UDim2.new(0,18,0,18)
swKnob.Position = UDim2.new(0,2,0.5,-9)
swKnob.BackgroundColor3 = Color3.new(1,1,1)
swKnob.BorderSizePixel =0
swKnob.Parent = swTrack
Instance.new("UICorner", swKnob).CornerRadius = UDim.new(1,0)

local function updateSwitch(anim)
    local tweenInfo = anim and TweenInfo.new(0.2) or TweenInfo.new(0)
    if Config.AutoTrack then
        TweenService:Create(swKnob, tweenInfo, {Position=UDim2.new(1,-20,0.5,-9)}):Play()
        TweenService:Create(swTrack, tweenInfo, {BackgroundColor3=Color3.new(0,180/255,110/255)}):Play()
    else
        TweenService:Create(swKnob, tweenInfo, {Position=UDim2.new(0,2,0.5,-9)}):Play()
        TweenService:Create(swTrack, tweenInfo, {BackgroundColor3=Color3.new(60/255,70/255,90/255)}):Play()
    end
end
updateSwitch(false)

-- ========== 半径滑块 ==========
local radiusRow = Instance.new("Frame")
radiusRow.Size = UDim2.new(1,-20,0,44)
radiusRow.Position = UDim2.new(0,10,0,102)
radiusRow.BackgroundColor3 = Color3.new(22/255,27/255,40/255)
radiusRow.BorderSizePixel =0
radiusRow.Parent = panel
Instance.new("UICorner", radiusRow).CornerRadius = UDim.new(0,10)

local rLabel = Instance.new("TextLabel")
rLabel.Size = UDim2.new(1,-14,0,20)
rLabel.Position = UDim2.new(0,7,0,4)
rLabel.BackgroundTransparency =1
rLabel.Text = string.format("追踪距离：%d 格", Config.TrackRadius)
rLabel.TextColor3 = Color3.new(220/255,230/255,255/255)
rLabel.Font = Enum.Font.GothamBold
rLabel.TextSize =11
rLabel.TextXAlignment = Enum.TextXAlignment.Left
rLabel.Parent = radiusRow

local R_MIN, R_MAX = 50, 1000
local R_RANGE = R_MAX - R_MIN

local trackBarBg = Instance.new("Frame")
trackBarBg.Size = UDim2.new(1,-14,0,6)
trackBarBg.Position = UDim2.new(0,7,0,26)
trackBarBg.BackgroundColor3 = Color3.new(40/255,48/255,64/255)
trackBarBg.BorderSizePixel =0
trackBarBg.Parent = radiusRow
Instance.new("UICorner", trackBarBg).CornerRadius = UDim.new(1,0)

local trackBarFill = Instance.new("Frame")
trackBarFill.Size = UDim2.new((Config.TrackRadius-R_MIN)/R_RANGE,0,1,0)
trackBarFill.BackgroundColor3 = Color3.new(0,200/255,255/255)
trackBarFill.BorderSizePixel =0
trackBarFill.Parent = trackBarBg
Instance.new("UICorner", trackBarFill).CornerRadius = UDim.new(1,0)
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.new(0,200/255,255/255)),
    ColorSequenceKeypoint.new(1, Color3.new(160/255,0,255/255))
}
fillGrad.Parent = trackBarFill

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0,12,0,12)
knob.AnchorPoint = Vector2.new(0.5,0.5)
knob.Position = UDim2.new((Config.TrackRadius-R_MIN)/R_RANGE,0,0.5,0)
knob.BackgroundColor3 = Color3.new(1,1,1)
knob.BorderSizePixel =0
knob.ZIndex = 2
knob.Parent = trackBarBg
Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

local draggingSlider = false
local function updateSlider(inputX)
    local absX = math.clamp(inputX - trackBarBg.AbsolutePosition.X, 0, trackBarBg.AbsoluteSize.X)
    local rel = absX / trackBarBg.AbsoluteSize.X
    local rawVal = R_MIN + rel * R_RANGE
    local val = math.floor(rawVal /10 + 0.5)*10
    Config.TrackRadius = val
    rLabel.Text = string.format("追踪距离：%d 格", val)
    trackBarFill.Size = UDim2.new(rel,0,1,0)
    knob.Position = UDim2.new(rel,0,0.5,0)
end

trackBarBg.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = true
        updateSlider(i.Position.X)
    end
end)
UIS.InputChanged:Connect(function(i)
    if draggingSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
        updateSlider(i.Position.X)
    end
end)
UIS.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingSlider = false
    end
end)

-- ========== 名单模式切换 ==========
local listHeaderRow = Instance.new("Frame")
listHeaderRow.Size = UDim2.new(1,-20,0,28)
listHeaderRow.Position = UDim2.new(0,10,0,152)
listHeaderRow.BackgroundTransparency =1
listHeaderRow.Parent = panel

local listTitle = Instance.new("TextLabel")
listTitle.Size = UDim2.new(0.4,0,1,0)
listTitle.BackgroundTransparency =1
listTitle.Text = "玩家名单"
listTitle.TextColor3 = Color3.new(220/255,230/255,255/255)
listTitle.Font = Enum.Font.GothamBold
listTitle.TextSize =11
listTitle.TextXAlignment = Enum.TextXAlignment.Left
listTitle.Parent = listHeaderRow

local wlBtn = Instance.new("TextButton")
wlBtn.Size = UDim2.new(0,50,0,22)
wlBtn.Position = UDim2.new(0.42,0,0,3)
wlBtn.BackgroundColor3 = Color3.new(40/255,46/255,60/255)
wlBtn.Text = "白名单"
wlBtn.TextColor3 = Color3.new(255,255,255)
wlBtn.Font = Enum.Font.GothamBold
wlBtn.TextSize =10
wlBtn.BorderSizePixel =0
wlBtn.Parent = listHeaderRow
Instance.new("UICorner", wlBtn).CornerRadius = UDim.new(0,5)

local blBtn = Instance.new("TextButton")
blBtn.Size = UDim2.new(0,50,0,22)
blBtn.Position = UDim2.new(0.64,0,0,3)
blBtn.BackgroundColor3 = Color3.new(40/255,46/255,60/255)
blBtn.Text = "黑名单"
blBtn.TextColor3 = Color3.new(255,255,255)
blBtn.Font = Enum.Font.GothamBold
blBtn.TextSize =10
blBtn.BorderSizePixel =0
blBtn.Parent = listHeaderRow
Instance.new("UICorner", blBtn).CornerRadius = UDim.new(0,5)

local function updateModeUI()
    local isWL = Config.ListMode == "Whitelist"
    wlBtn.BackgroundColor3 = isWL and Color3.new(0,120/255,180/255) or Color3.new(40/255,46/255,60/255)
    blBtn.BackgroundColor3 = not isWL and Color3.new(180/255,80/255,80/255) or Color3.new(40/255,46/255,60/255)
end
updateModeUI()

wlBtn.MouseButton1Click:Connect(function()
    Config.ListMode = "Whitelist"
    updateModeUI()
end)
blBtn.MouseButton1Click:Connect(function()
    Config.ListMode = "Blacklist"
    updateModeUI()
end)

-- ========== 添加玩家输入行 ==========
local inputRow = Instance.new("Frame")
inputRow.Size = UDim2.new(1,-20,0,30)
inputRow.Position = UDim2.new(0,10,0,184)
inputRow.BackgroundTransparency =1
inputRow.Parent = panel

local playerInput = Instance.new("TextBox")
playerInput.Size = UDim2.new(1,-72,1,0)
playerInput.BackgroundColor3 = Color3.new(25/255,30/255,42/255)
playerInput.BorderSizePixel =0
playerInput.PlaceholderText = "输入玩家名字..."
playerInput.PlaceholderColor3 = Color3.new(110/255,130/255,160/255)
playerInput.Text = ""
playerInput.TextColor3 = Color3.new(230/255,240/255,255/255)
playerInput.Font = Enum.Font.GothamMedium
playerInput.TextSize =11
playerInput.TextXAlignment = Enum.TextXAlignment.Left
playerInput.Parent = inputRow
Instance.new("UICorner", playerInput).CornerRadius = UDim.new(0,6)
Instance.new("UIPadding", playerInput).PaddingLeft = UDim.new(0,8)

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0,60,1,0)
addBtn.Position = UDim2.new(1,-60,0,0)
addBtn.BackgroundColor3 = Color3.new(0,160/255,220/255)
addBtn.Text = "+ 添加"
addBtn.TextColor3 = Color3.new(1,1,1)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize =11
addBtn.BorderSizePixel =0
addBtn.Parent = inputRow
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0,6)

-- ========== 名单滚动框 ==========
local listScroll = Instance.new("ScrollingFrame")
listScroll.Size = UDim2.new(1,-20,0,124)
listScroll.Position = UDim2.new(0,10,0,218)
listScroll.BackgroundColor3 = Color3.new(18/255,22/255,32/255)
listScroll.BorderSizePixel =0
listScroll.ScrollBarThickness =4
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.CanvasSize = UDim2.new(0,0,0,0)
listScroll.Parent = panel
Instance.new("UICorner", listScroll).CornerRadius = UDim.new(0,8)
local listStroke = Instance.new("UIStroke")
listStroke.Thickness =1
listStroke.Transparency =0.7
listStroke.Color = Color3.new(0,200/255,255/255)
listStroke.Parent = listScroll
local listPad = Instance.new("UIPadding")
listPad.PaddingTop = UDim.new(0,6)
listPad.PaddingBottom = UDim.new(0,6)
listPad.PaddingLeft = UDim.new(0,6)
listPad.PaddingRight = UDim.new(0,6)
listPad.Parent = listScroll

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0,4)
listLayout.Parent = listScroll

local function rebuildList()
    for _,child in ipairs(listScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    for _,nameStr in ipairs(Config.PlayerList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,0,0,24)
        row.BackgroundColor3 = Color3.new(30/255,36/255,50/255)
        row.BorderSizePixel =0
        row.Parent = listScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,4)

        local nameLab = Instance.new("TextLabel")
        nameLab.Size = UDim2.new(1,-28,1,0)
        nameLab.Position = UDim2.new(0,8,0,0)
        nameLab.BackgroundTransparency =1
        nameLab.Text = nameStr
        nameLab.TextColor3 = Color3.new(220/255,230/255,255/255)
        nameLab.Font = Enum.Font.GothamMedium
        nameLab.TextSize =11
        nameLab.TextXAlignment = Enum.TextXAlignment.Left
        nameLab.Parent = row

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0,20,0,20)
        delBtn.Position = UDim2.new(1,-24,0.5,-10)
        delBtn.BackgroundColor3 = Color3.new(180/255,50/255,50/255)
        delBtn.Text = "×"
        delBtn.TextColor3 = Color3.new(1,1,1)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize =12
        delBtn.BorderSizePixel =0
        delBtn.Parent = row
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0,4)

        delBtn.MouseButton1Click:Connect(function()
            local idx = table.find(Config.PlayerList, nameStr)
            if idx then table.remove(Config.PlayerList, idx) end
            rebuildList()
        end)
    end
end

local function addPlayerFunc()
    local txt = playerInput.Text
    if txt == "" then return end
    if table.find(Config.PlayerList, txt) then
        playerInput.Text = ""
        return
    end
    table.insert(Config.PlayerList, txt)
    playerInput.Text = ""
    rebuildList()
end
addBtn.MouseButton1Click:Connect(addPlayerFunc)
playerInput.FocusLost:Connect(function(enter)
    if enter then addPlayerFunc() end
end)
rebuildList()

-- ========== 密码弹窗 ==========
local passOverlay = Instance.new("Frame")
passOverlay.Size = UDim2.new(1,0,1,0)
passOverlay.BackgroundColor3 = Color3.new(0,0,0)
passOverlay.BackgroundTransparency =0.55
passOverlay.Visible = false
passOverlay.ZIndex =20
passOverlay.Parent = gui

local passBox = Instance.new("Frame")
passBox.Size = UDim2.new(0,230,0,150)
passBox.AnchorPoint = Vector2.new(0.5,0.5)
passBox.Position = UDim2.new(0.5,0,0.5,0)
passBox.BackgroundColor3 = Color3.new(15/255,18/255,28/255)
passBox.BorderSizePixel =0
passBox.Parent = passOverlay
Instance.new("UICorner", passBox).CornerRadius = UDim.new(0,12)
local pbStroke = Instance.new("UIStroke")
pbStroke.Thickness =1.2
pbStroke.Transparency =0.3
pbStroke.Color = Color3.new(0,200/255,255/255)
pbStroke.Parent = passBox

local pbTitle = Instance.new("TextLabel")
pbTitle.Size = UDim2.new(1,-24,0,26)
pbTitle.Position = UDim2.new(0,12,0,10)
pbTitle.BackgroundTransparency =1
pbTitle.Text = "◆ 需要密码验证"
pbTitle.TextColor3 = Color3.new(0,220/255,255/255)
pbTitle.Font = Enum.Font.GothamBold
pbTitle.TextSize =13
pbTitle.TextXAlignment = Enum.TextXAlignment.Left
pbTitle.Parent = passBox

local passTextBox = Instance.new("TextBox")
passTextBox.Size = UDim2.new(1,-24,0,32)
passTextBox.Position = UDim2.new(0,12,0,44)
passTextBox.BackgroundColor3 = Color3.new(25/255,30/255,42/255)
passTextBox.BorderSizePixel =0
passTextBox.PlaceholderText = "请输入密码"
passTextBox.Text = ""
passTextBox.TextColor3 = Color3.new(230/255,240/255,255/255)
passTextBox.Font = Enum.Font.GothamMedium
passTextBox.TextSize =13
passTextBox.Parent = passBox
Instance.new("UICorner", passTextBox).CornerRadius = UDim.new(0,8)
Instance.new("UIPadding", passTextBox).PaddingLeft = UDim.new(0,10)

local errLabel = Instance.new("TextLabel")
errLabel.Size = UDim2.new(1,-24,0,16)
errLabel.Position = UDim2.new(0,12,0,80)
errLabel.BackgroundTransparency =1
errLabel.Text = ""
errLabel.TextColor3 = Color3.new(255/255,90/255,90/255)
errLabel.Font = Enum.Font.Gotham
errLabel.TextSize =10
errLabel.TextXAlignment = Enum.TextXAlignment.Left
errLabel.Parent = passBox

local passBtnContainer = Instance.new("Frame")
passBtnContainer.Size = UDim2.new(1,-24,0,30)
passBtnContainer.Position = UDim2.new(0,12,0,104)
passBtnContainer.BackgroundTransparency =1
passBtnContainer.Parent = passBox

local passOk = Instance.new("TextButton")
passOk.Size = UDim2.new(0.48,0,1,0)
passOk.BackgroundColor3 = Color3.new(0,180/255,110/255)
passOk.Text = "确认"
passOk.TextColor3 = Color3.new(1,1,1)
passOk.Font = Enum.Font.GothamBold
passOk.TextSize =12
passOk.BorderSizePixel =0
passOk.Parent = passBtnContainer
Instance.new("UICorner", passOk).CornerRadius = UDim.new(0,8)

local passCancel = Instance.new("TextButton")
passCancel.Size = UDim2.new(0.48,0,1,0)
passCancel.Position = UDim2.new(0.52,0,0,0)
passCancel.BackgroundColor3 = Color3.new(40/255,46/255,62/255)
passCancel.Text = "取消"
passCancel.TextColor3 = Color3.new(200/255,210/255,230/255)
passCancel.Font = Enum.Font.GothamBold
passCancel.TextSize =12
passCancel.BorderSizePixel =0
passCancel.Parent = passBtnContainer
Instance.new("UICorner", passCancel).CornerRadius = UDim.new(0,8)

local function openPass()
    passTextBox.Text = ""
    errLabel.Text = ""
    passOverlay.Visible = true
    task.wait()
    passTextBox:CaptureFocus()
end
local function closePass()
    passOverlay.Visible = false
    passTextBox:ReleaseFocus()
end

local function shakePassBox()
    local orig = passBox.Position
    for i=1,4 do
        TweenService:Create(passBox, TweenInfo.new(0.05), {Position=orig + UDim2.new(0, (i%2==0 and -6 or 6),0,0)}):Play()
        task.wait(0.05)
    end
    TweenService:Create(passBox, TweenInfo.new(0.05), {Position=orig}):Play()
end

local function tryUnlockPass()
    if passTextBox.Text == SECRET then
        Config.AutoTrack = true
        updateSwitch(true)
        closePass()
    else
        errLabel.Text = "密码错误"
        passTextBox.Text = ""
        shakePassBox()
        task.wait()
        passTextBox:CaptureFocus()
    end
end

passOk.MouseButton1Click:Connect(tryUnlockPass)
passTextBox.FocusLost:Connect(function(enter)
    if enter then tryUnlockPass() end
end)
passCancel.MouseButton1Click:Connect(closePass)

-- ========== 主开关点击逻辑 ==========
masterRow.MouseButton1Click:Connect(function()
    if Config.AutoTrack then
        Config.AutoTrack = false
        updateSwitch(true)
    else
        openPass()
    end
end)

-- ========== 面板打开关闭 ==========
local panelIsOpen = false
local function openPanelFunc()
    if panelIsOpen then return end
    panelIsOpen = true
    local vp = gui.AbsoluteSize
    local bx = ball.AbsolutePosition.X
    local by = ball.AbsolutePosition.Y
    local pw = panel.AbsoluteSize.X
    local ph = panel.AbsoluteSize.Y
    local px = bx + ball.AbsoluteSize.X + 8
    if px + pw > vp.X - 8 then px = bx - pw - 8 end
    px = math.clamp(px, 8, math.max(8, vp.X - pw - 8))
    local py = math.clamp(by, 8, math.max(8, vp.Y - ph - 8))
    panel.Position = UDim2.new(0,px,0,py)
    panel.Visible = true
    ball.Visible = false
end

local function closePanelFunc()
    if not panelIsOpen then return end
    panelIsOpen = false
    panel.Visible = false
    ball.Visible = true
end
closeBtn.MouseButton1Click:Connect(closePanelFunc)

-- ========== 悬浮球拖拽 ==========
local dragBall, dragMoved = false, false
local dragStartPos, ballStartPos
ball.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragBall = true
        dragMoved = false
        dragStartPos = input.Position
        ballStartPos = ball.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragBall and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStartPos
        if math.abs(delta.X) >4 or math.abs(delta.Y) >4 then dragMoved = true end
        ball.Position = UDim2.new(
            ballStartPos.X.Scale, ballStartPos.X.Offset + delta.X,
            ballStartPos.Y.Scale, ballStartPos.Y.Offset + delta.Y
        )
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        if dragBall and not dragMoved then
            openPanelFunc()
        end
        dragBall = false
        dragMoved = false
    end
end)

print("[Neon Tracker v2] 已加载 | 密码保护 | 瞄头/瞄身 | 黑白名单")