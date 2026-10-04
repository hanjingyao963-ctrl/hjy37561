-- ================= Neon Tracker v8.4 (Scrollable UI & Dual BigHead) =================
-- 新增：UI 上下滑动 | 物理/视觉大头可同时开启 | 修复全部已知Bug
-- ====================================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- 密码与状态
local SECRET = "919878"
local isUnlocked = false
local ballClickCount = 0

-- 全局配置
local Config = {
    AutoTrack = false,
    TrackRadius = 200,
    AimPart = "Head",
    HitboxPhysics = false,
    HitboxVisual = false,
    HitboxSize = 24,
    Noclip = false,
    VoidProtection = false,
    ListMode = "Blacklist",
    PlayerList = {},
    UIScale = 1,
    Smoothing = 0.6,
    ESP = false,
    ShowFOV = false
}

-- 追踪与黑白名单逻辑
local currentTarget = nil
local originalHeadData = {}

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
        if dist <= radius and dist < closestDist then
            closest = char
            closestDist = dist
        end
    end
    return closest
end

-- 核心：静默自瞄 & 平滑度
RunService.RenderStepped:Connect(function(deltaTime)
    if Config.AutoTrack then
        currentTarget = getClosestTarget()
    else
        currentTarget = nil
    end

    if Config.ESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local hl = plr.Character:FindFirstChild("TrackerESP")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "TrackerESP"
                    hl.FillColor = Color3.fromRGB(255, 0, 128)
                    hl.OutlineColor = Color3.fromRGB(180, 0, 255)
                    hl.FillTransparency = 0.5
                    hl.OutlineTransparency = 0
                    hl.Parent = plr.Character
                end
            end
        end
    else
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character then
                local hl = plr.Character:FindFirstChild("TrackerESP")
                if hl then hl:Destroy() end
            end
        end
    end

    if not currentTarget then return end
    if UIS.TouchEnabled and #UIS:GetTouches() > 0 then return end

    local aimPart = currentTarget:FindFirstChild(Config.AimPart)
    if not aimPart then aimPart = currentTarget:FindFirstChild("HumanoidRootPart") end
    if not aimPart then return end

    local currentCFrame = Camera.CFrame
    local targetPos = aimPart.Position
    local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + (targetPos - currentCFrame.Position).Unit)
    Camera.CFrame = currentCFrame:Lerp(newCFrame, Config.Smoothing)
end)

-- 核心：双重大头 & 内存清理（允许同时开启）
RunService.Heartbeat:Connect(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                if not originalHeadData[head] then
                    originalHeadData[head] = { size = head.Size, transparency = head.Transparency, canQuery = head.CanQuery, canCollide = head.CanCollide }
                end
                
                local targetSize = originalHeadData[head].size
                local targetQuery = originalHeadData[head].canQuery
                local targetCollide = originalHeadData[head].canCollide
                
                -- 如果开启了物理大头，则放大判定，取消碰撞
                if Config.HitboxPhysics then
                    targetSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    targetQuery = true
                    targetCollide = false
                end
                
                -- 如果开启了视觉大头（即使物理大头也开着），保留外观放大
                if Config.HitboxVisual or Config.HitboxPhysics then
                    targetSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                end
                
                head.Size = targetSize
                head.CanQuery = targetQuery
                head.CanCollide = targetCollide
            end
        end
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then
        local head = plr.Character:FindFirstChild("Head")
        if head and originalHeadData[head] then
            originalHeadData[head] = nil
        end
    end
end)

-- FOV 圈、穿墙、防掉虚空
local fovCircle = Instance.new("Part")
fovCircle.Name = "FOVCircle"
fovCircle.Shape = Enum.PartType.Ball
fovCircle.Material = Enum.Material.ForceField
fovCircle.Color = Color3.fromRGB(180, 0, 255)
fovCircle.Transparency = 1
fovCircle.CanCollide = false
fovCircle.CanQuery = false
fovCircle.Anchored = true
fovCircle.Parent = Workspace

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if Config.ShowFOV then
        fovCircle.Size = Vector3.new(Config.TrackRadius * 2, Config.TrackRadius * 2, Config.TrackRadius * 2)
        fovCircle.CFrame = hrp.CFrame
        fovCircle.Transparency = 0.85
    else
        fovCircle.Transparency = 1
    end

    if Config.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end

    if Config.VoidProtection and hrp.Position.Y < -50 then
        hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end)

local function safeDisableNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

-- ====================================================
-- ================== UI 部分 =========================
-- ====================================================

if game.CoreGui:FindFirstChild("TrackerUI") then
    game.CoreGui.TrackerUI:Destroy()
end

local parentGui = (gethui and gethui()) or game.CoreGui
local gui = Instance.new("ScreenGui")
gui.Name = "TrackerUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999999
gui.Parent = parentGui

local uiScale = Instance.new("UIScale")
uiScale.Scale = Config.UIScale
uiScale.Parent = gui

local BOUNCE_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BOUNCE_IN = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local QUICK_BOUNCE = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- 悬浮球
local ball = Instance.new("TextButton")
ball.Size = UDim2.new(0, 60, 0, 60)
ball.Position = UDim2.new(0, 50, 0, 250)
ball.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
ball.Text = ""
ball.AutoButtonColor = false
ball.BorderSizePixel = 0
ball.Parent = gui
Instance.new("UICorner", ball).CornerRadius = UDim.new(1, 0)

local ballStroke = Instance.new("UIStroke")
ballStroke.Thickness = 2
ballStroke.Transparency = 0.15
ballStroke.Parent = ball
local ballGrad = Instance.new("UIGradient")
ballGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128))})
ballGrad.Parent = ballStroke

local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(1, 0, 1, 0)
ballIcon.BackgroundTransparency = 1
ballIcon.Text = "◎"
ballIcon.TextColor3 = Color3.fromRGB(200, 150, 255)
ballIcon.Font = Enum.Font.GothamBold
ballIcon.TextSize = 30
ballIcon.Parent = ball

-- 主面板（高度调整到 450，适配手机屏幕）
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 0, 450)
panel.Position = UDim2.new(0, 150, 0, 150)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.4
panelStroke.Parent = panel
local psGrad = Instance.new("UIGradient")
psGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128))})
psGrad.Parent = panelStroke

-- 标题栏（固定在面板顶部，不随滚动滑动）
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundTransparency = 1
titleBar.ZIndex = 2
titleBar.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TRACKER v8.4 (可滑动)"
title.TextColor3 = Color3.fromRGB(200, 150, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0.5, -16)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- 滚动容器（所有开关都放在这里）
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -40) -- 高度减去标题栏
scroll.Position = UDim2.new(0, 0, 0, 40)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 0, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 560) -- 内容总高度
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

-- 模块化开关（Parent 改为 scroll）
local function createToggle(yPos, labelText, getter, setter)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -20, 0, 35)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
    row.Text = ""
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -100, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(220,230,255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = Instance.new("TextLabel")
    state.Size = UDim2.new(0, 40, 1, 0)
    state.Position = UDim2.new(1, -52, 0, 0)
    state.BackgroundTransparency = 1
    state.Text = getter() and "ON" or "OFF"
    state.TextColor3 = getter() and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
    state.Font = Enum.Font.GothamBold
    state.TextSize = 12
    state.TextXAlignment = Enum.TextXAlignment.Right
    state.Parent = row

    local function updateUI()
        state.Text = getter() and "ON" or "OFF"
        state.TextColor3 = getter() and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            setter(not getter())
            updateUI()
            TweenService:Create(row, QUICK_BOUNCE, {BackgroundColor3 = getter() and Color3.fromRGB(35, 25, 55) or Color3.fromRGB(25, 18, 40)}):Play()
        end
    end)
    return updateUI
end

-- 开关列表
local updateTrackUI = createToggle(10, "自动追踪", function() return Config.AutoTrack end, function(v) Config.AutoTrack = v end)
local updatePhysUI = createToggle(50, "物理大头 (判定)", function() return Config.HitboxPhysics end, function(v) Config.HitboxPhysics = v end)
local updateVisUI = createToggle(90, "视觉大头 (外观)", function() return Config.HitboxVisual end, function(v) Config.HitboxVisual = v end)
local updateNoclipUI = createToggle(130, "穿墙模式", function() return Config.Noclip end, function(v) Config.Noclip = v; if not v then safeDisableNoclip() end end)
local updateVoidUI = createToggle(170, "防掉虚空", function() return Config.VoidProtection end, function(v) Config.VoidProtection = v end)
local updateESPUI = createToggle(210, "ESP 透视", function() return Config.ESP end, function(v) Config.ESP = v end)
local updateFOVUI = createToggle(250, "FOV 圈 (显示范围)", function() return Config.ShowFOV end, function(v) Config.ShowFOV = v end)

-- 瞄准部位选择
local aimRow = Instance.new("Frame")
aimRow.Size = UDim2.new(1, -20, 0, 35)
aimRow.Position = UDim2.new(0, 10, 0, 290)
aimRow.BackgroundColor3 = Color3.fromRGB(25,18,40)
aimRow.BorderSizePixel = 0
aimRow.Parent = scroll
Instance.new("UICorner", aimRow).CornerRadius = UDim.new(0,10)

local aimLabel = Instance.new("TextLabel")
aimLabel.Size = UDim2.new(0,80,1,0)
aimLabel.Position = UDim2.new(0,12,0,0)
aimLabel.BackgroundTransparency = 1
aimLabel.Text = "瞄准部位"
aimLabel.TextColor3 = Color3.fromRGB(220,230,255)
aimLabel.Font = Enum.Font.GothamBold
aimLabel.TextSize = 12
aimLabel.TextXAlignment = Enum.TextXAlignment.Left
aimLabel.Parent = aimRow

local headBtn = Instance.new("TextButton")
headBtn.Size = UDim2.new(0,52,0,24)
headBtn.Position = UDim2.new(1, -110, 0.5, -12)
headBtn.BackgroundColor3 = Color3.fromRGB(40,46,62)
headBtn.Text = "头部"
headBtn.TextColor3 = Color3.new(1,1,1)
headBtn.Font = Enum.Font.GothamBold
headBtn.TextSize = 11
headBtn.AutoButtonColor = false
headBtn.BorderSizePixel = 0
headBtn.Parent = aimRow
Instance.new("UICorner", headBtn).CornerRadius = UDim.new(0,6)

local bodyBtn = Instance.new("TextButton")
bodyBtn.Size = UDim2.new(0,52,0,24)
bodyBtn.Position = UDim2.new(1, -54, 0.5, -12)
bodyBtn.BackgroundColor3 = Color3.fromRGB(40,46,62)
bodyBtn.Text = "身体"
bodyBtn.TextColor3 = Color3.new(1,1,1)
bodyBtn.Font = Enum.Font.GothamBold
bodyBtn.TextSize = 11
bodyBtn.AutoButtonColor = false
bodyBtn.BorderSizePixel = 0
bodyBtn.Parent = aimRow
Instance.new("UICorner", bodyBtn).CornerRadius = UDim.new(0,6)

local function updateAimUI()
    local isHead = Config.AimPart == "Head"
    TweenService:Create(headBtn, QUICK_BOUNCE, {BackgroundColor3 = isHead and Color3.fromRGB(180,0,255) or Color3.fromRGB(40,46,62)}):Play()
    TweenService:Create(bodyBtn, QUICK_BOUNCE, {BackgroundColor3 = not isHead and Color3.fromRGB(180,0,255) or Color3.fromRGB(40,46,62)}):Play()
end
updateAimUI()

headBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.AimPart = "Head"
        updateAimUI()
    end
end)
bodyBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.AimPart = "HumanoidRootPart"
        updateAimUI()
    end
end)

-- 追踪半径滑块
local radiusRow = Instance.new("Frame")
radiusRow.Size = UDim2.new(1,-20,0,45)
radiusRow.Position = UDim2.new(0,10,0,335)
radiusRow.BackgroundColor3 = Color3.fromRGB(25,18,40)
radiusRow.BorderSizePixel = 0
radiusRow.Parent = scroll
Instance.new("UICorner", radiusRow).CornerRadius = UDim.new(0,10)

local radiusLabel = Instance.new("TextLabel")
radiusLabel.Size = UDim2.new(1,-24,0,18)
radiusLabel.Position = UDim2.new(0,12,0,4)
radiusLabel.BackgroundTransparency = 1
radiusLabel.Text = "追踪半径: 200 格"
radiusLabel.Name = "radiusValueLabel"
radiusLabel.TextColor3 = Color3.fromRGB(200,150,255)
radiusLabel.Font = Enum.Font.GothamBold
radiusLabel.TextSize = 11
radiusLabel.TextXAlignment = Enum.TextXAlignment.Left
radiusLabel.Parent = radiusRow

local trackBg = Instance.new("Frame")
trackBg.Size = UDim2.new(1,-24,0,8)
trackBg.Position = UDim2.new(0,12,1,-14)
trackBg.BackgroundColor3 = Color3.fromRGB(42,34,60)
trackBg.BorderSizePixel = 0
trackBg.Parent = radiusRow
Instance.new("UICorner", trackBg).CornerRadius = UDim.new(1,0)

local fill = Instance.new("Frame")
fill.Size = UDim2.new(0.15,0,1,0)
fill.BackgroundColor3 = Color3.fromRGB(180,0,255)
fill.BorderSizePixel = 0
fill.Parent = trackBg
Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0,12,0,12)
knob.Position = UDim2.new(0.15, -6, 0.5, -6)
knob.BackgroundColor3 = Color3.new(1,1,1)
knob.BorderSizePixel = 0
knob.ZIndex = 3
knob.Parent = trackBg
Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

-- 平滑度滑块
local smoothRow = Instance.new("Frame")
smoothRow.Size = UDim2.new(1,-20,0,45)
smoothRow.Position = UDim2.new(0,10,0,390)
smoothRow.BackgroundColor3 = Color3.fromRGB(25,18,40)
smoothRow.BorderSizePixel = 0
smoothRow.Parent = scroll
Instance.new("UICorner", smoothRow).CornerRadius = UDim.new(0,10)

local smoothLabel = Instance.new("TextLabel")
smoothLabel.Size = UDim2.new(1,-24,0,18)
smoothLabel.Position = UDim2.new(0,12,0,4)
smoothLabel.BackgroundTransparency = 1
smoothLabel.Text = "瞄准平滑度: 0.60"
smoothLabel.Name = "smoothValueLabel"
smoothLabel.TextColor3 = Color3.fromRGB(200,150,255)
smoothLabel.Font = Enum.Font.GothamBold
smoothLabel.TextSize = 11
smoothLabel.TextXAlignment = Enum.TextXAlignment.Left
smoothLabel.Parent = smoothRow

local sTrackBg = Instance.new("Frame")
sTrackBg.Size = UDim2.new(1,-24,0,8)
sTrackBg.Position = UDim2.new(0,12,1,-14)
sTrackBg.BackgroundColor3 = Color3.fromRGB(42,34,60)
sTrackBg.BorderSizePixel = 0
sTrackBg.Parent = smoothRow
Instance.new("UICorner", sTrackBg).CornerRadius = UDim.new(1,0)

local sFill = Instance.new("Frame")
sFill.Size = UDim2.new(0.5,0,1,0)
sFill.BackgroundColor3 = Color3.fromRGB(180,0,255)
sFill.BorderSizePixel = 0
sFill.Parent = sTrackBg
Instance.new("UICorner", sFill).CornerRadius = UDim.new(1,0)

local sKnob = Instance.new("Frame")
sKnob.Size = UDim2.new(0,12,0,12)
sKnob.Position = UDim2.new(0.5, -6, 0.5, -6)
sKnob.BackgroundColor3 = Color3.new(1,1,1)
sKnob.BorderSizePixel = 0
sKnob.ZIndex = 3
sKnob.Parent = sTrackBg
Instance.new("UICorner", sKnob).CornerRadius = UDim.new(1,0)

-- UI缩放滑块
local scaleRow = Instance.new("Frame")
scaleRow.Size = UDim2.new(1,-20,0,45)
scaleRow.Position = UDim2.new(0,10,0,445)
scaleRow.BackgroundColor3 = Color3.fromRGB(25,18,40)
scaleRow.BorderSizePixel = 0
scaleRow.Parent = scroll
Instance.new("UICorner", scaleRow).CornerRadius = UDim.new(0,10)

local scaleLabel = Instance.new("TextLabel")
scaleLabel.Size = UDim2.new(1,-24,0,18)
scaleLabel.Position = UDim2.new(0,12,0,4)
scaleLabel.BackgroundTransparency = 1
scaleLabel.Text = "界面缩放: 100%"
scaleLabel.Name = "scaleValueLabel"
scaleLabel.TextColor3 = Color3.fromRGB(200,150,255)
scaleLabel.Font = Enum.Font.GothamBold
scaleLabel.TextSize = 11
scaleLabel.TextXAlignment = Enum.TextXAlignment.Left
scaleLabel.Parent = scaleRow

local scTrackBg = Instance.new("Frame")
scTrackBg.Size = UDim2.new(1,-24,0,8)
scTrackBg.Position = UDim2.new(0,12,1,-14)
scTrackBg.BackgroundColor3 = Color3.fromRGB(42,34,60)
scTrackBg.BorderSizePixel = 0
scTrackBg.Parent = scaleRow
Instance.new("UICorner", scTrackBg).CornerRadius = UDim.new(1,0)

local scFill = Instance.new("Frame")
scFill.Size = UDim2.new(0.3333,0,1,0)
scFill.BackgroundColor3 = Color3.fromRGB(180,0,255)
scFill.BorderSizePixel = 0
scFill.Parent = scTrackBg
Instance.new("UICorner", scFill).CornerRadius = UDim.new(1,0)

local scKnob = Instance.new("Frame")
scKnob.Size = UDim2.new(0,12,0,12)
scKnob.Position = UDim2.new(0.3333, -6, 0.5, -6)
scKnob.BackgroundColor3 = Color3.new(1,1,1)
scKnob.BorderSizePixel = 0
scKnob.ZIndex = 3
scKnob.Parent = scTrackBg
Instance.new("UICorner", scKnob).CornerRadius = UDim.new(1,0)

-- 滑块绑定函数
local function bindSlider(trackFrame, fillFrame, knobFrame, minVal, maxVal, callback)
    local dragging = false
    local function updateByX(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local rel = math.clamp((inputX - absPos)/absSize,0,1)
        local val = minVal + rel*(maxVal-minVal)
        callback(val, rel)
    end
    trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateByX(input.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateByX(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

bindSlider(trackBg, fill, knob, 50, 1000, function(val, rel)
    val = math.floor(val/10+0.5)*10
    Config.TrackRadius = val
    radiusLabel.Text = "追踪半径: "..val.." 格"
    fill.Size = UDim2.new(rel,0,1,0)
    knob.Position = UDim2.new(rel, -6,0.5,-6)
end)

bindSlider(sTrackBg, sFill, sKnob, 0.1, 1.0, function(val, rel)
    Config.Smoothing = math.floor(val*100)/100
    smoothLabel.Text = "瞄准平滑度: "..string.format("%.2f", Config.Smoothing)
    sFill.Size = UDim2.new(rel,0,1,0)
    sKnob.Position = UDim2.new(rel, -6,0.5,-6)
end)

bindSlider(scTrackBg, scFill, scKnob, 0.5, 2.0, function(val, rel)
    Config.UIScale = math.floor(val*10)/10
    scaleLabel.Text = "界面缩放: "..tostring(math.floor(Config.UIScale*100)).."%"
    uiScale.Scale = Config.UIScale
    scFill.Size = UDim2.new(rel,0,1,0)
    scKnob.Position = UDim2.new(rel, -6,0.5,-6)
end)

-- ============ 密码弹窗 ============
local passOverlay = Instance.new("Frame")
passOverlay.Size = UDim2.new(1, 0, 1, 0)
passOverlay.BackgroundColor3 = Color3.new(0,0,0)
passOverlay.BackgroundTransparency = 0.6
passOverlay.BorderSizePixel = 0
passOverlay.Visible = false
passOverlay.ZIndex = 20
passOverlay.Parent = gui

local passBox = Instance.new("Frame")
passBox.Size = UDim2.new(0,260,0,140)
passBox.Position = UDim2.new(0.5,-130,0.5,-70)
passBox.BackgroundColor3 = Color3.fromRGB(12,10,20)
passBox.BorderSizePixel = 0
passBox.Parent = passOverlay
Instance.new("UICorner", passBox).CornerRadius = UDim.new(0,12)

local passTitle = Instance.new("TextLabel")
passTitle.Size = UDim2.new(1,-20,0,28)
passTitle.Position = UDim2.new(0,10,0,8)
passTitle.BackgroundTransparency = 1
passTitle.Text = "🔐 请输入密码解锁"
passTitle.TextColor3 = Color3.fromRGB(200,150,255)
passTitle.Font = Enum.Font.GothamBold
passTitle.TextSize = 14
passTitle.TextXAlignment = Enum.TextXAlignment.Left
passTitle.Parent = passBox

local pbInput = Instance.new("TextBox")
pbInput.Size = UDim2.new(1,-24,0,34)
pbInput.Position = UDim2.new(0,12,0,40)
pbInput.BackgroundColor3 = Color3.fromRGB(28,24,44)
pbInput.Text = ""
pbInput.PlaceholderText = "密码"
pbInput.TextColor3 = Color3.new(1,1,1)
pbInput.Font = Enum.Font.Gotham
pbInput.TextSize = 13
pbInput.ClearTextOnFocus = false
pbInput.BorderSizePixel = 0
pbInput.Parent = passBox
Instance.new("UICorner", pbInput).CornerRadius = UDim.new(0,8)

local pbErr = Instance.new("TextLabel")
pbErr.Size = UDim2.new(1,-20,0,16)
pbErr.Position = UDim2.new(0,10,0,78)
pbErr.BackgroundTransparency = 1
pbErr.Text = ""
pbErr.TextColor3 = Color3.fromRGB(255,90,90)
pbErr.Font = Enum.Font.Gotham
pbErr.TextSize = 11
pbErr.TextXAlignment = Enum.TextXAlignment.Left
pbErr.Parent = passBox

local pbOk = Instance.new("TextButton")
pbOk.Size = UDim2.new(0,110,0,30)
pbOk.Position = UDim2.new(0,12,1,-36)
pbOk.BackgroundColor3 = Color3.fromRGB(110,0,170)
pbOk.Text = "确认"
pbOk.TextColor3 = Color3.new(1,1,1)
pbOk.Font = Enum.Font.GothamBold
pbOk.TextSize = 12
pbOk.AutoButtonColor = false
pbOk.BorderSizePixel = 0
pbOk.Parent = passBox
Instance.new("UICorner", pbOk).CornerRadius = UDim.new(0,8)

local pbCancel = Instance.new("TextButton")
pbCancel.Size = UDim2.new(0,110,0,30)
pbCancel.Position = UDim2.new(1, -122,1,-36)
pbCancel.BackgroundColor3 = Color3.fromRGB(50,50,70)
pbCancel.Text = "取消"
pbCancel.TextColor3 = Color3.new(1,1,1)
pbCancel.Font = Enum.Font.GothamBold
pbCancel.TextSize = 12
pbCancel.AutoButtonColor = false
pbCancel.BorderSizePixel = 0
pbCancel.Parent = passBox
Instance.new("UICorner", pbCancel).CornerRadius = UDim.new(0,8)

local function openPass()
    pbInput.Text = ""
    pbErr.Text = ""
    passOverlay.Visible = true
    task.wait(0.15)
    pbInput:CaptureFocus()
end

local function closePass()
    passOverlay.Visible = false
    pbInput:ReleaseFocus()
end

local function shake(frame)
    local orig = frame.Position
    for i=1,4 do
        frame.Position = orig + UDim2.new(0,(i%2==1 and -6 or 6),0,0)
        task.wait(0.04)
    end
    frame.Position = orig
end

local function showWelcomeAnimation()
    local welcomeText = Instance.new("TextLabel")
    welcomeText.Name = "WelcomeText"
    welcomeText.Size = UDim2.new(0,400,0,80)
    welcomeText.AnchorPoint = Vector2.new(0.5,0.5)
    welcomeText.Position = UDim2.new(0.5,0,0.4,0)
    welcomeText.BackgroundTransparency = 1
    welcomeText.Text = "欢迎使用 Neon‑Tracker v8.4"
    welcomeText.TextColor3 = Color3.fromRGB(200, 150, 255)
    welcomeText.TextStrokeTransparency = 0.35
    welcomeText.Font = Enum.Font.GothamBlack
    welcomeText.TextSize = 26
    welcomeText.ZIndex = 100
    welcomeText.Parent = gui

    task.wait(1.8)
    local tween = TweenService:Create(welcomeText, TweenInfo.new(0.45), {TextTransparency=1, TextStrokeTransparency=1, Size=UDim2.new(0,100,0,20)})
    tween:Play()
    tween.Completed:Connect(function() welcomeText:Destroy() end)
end

local function unlockAndOpen()
    isUnlocked = true
    ballClickCount = 0
    closePass()
    panel.Visible = true
    panel.Size = UDim2.new(0,0,0,0)
    panel.Position = UDim2.new(0.5,-125,0.5,-225)
    TweenService:Create(panel, BOUNCE_OUT, {Size=UDim2.new(0,250,0,450)}):Play()
    ball.Visible = true
    TweenService:Create(ball, QUICK_BOUNCE, {Size=UDim2.new(0,60,0,60), Position=UDim2.new(0,110,0,120)}):Play()
    showWelcomeAnimation()
end

local function tryUnlock()
    local raw = pbInput.Text
    local cleaned = raw:gsub("%s+",""):gsub("[^0-9]","")
    if cleaned == SECRET then
        unlockAndOpen()
    else
        pbErr.Text = "密码错误，请重试"
        pbInput.Text = ""
        shake(passBox)
    end
end

pbOk.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tryUnlock() end
end)
pbInput.FocusLost:Connect(function(enter) if enter then tryUnlock() end end)
pbCancel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then closePass() end
end)

-- ============ 拖拽工具函数 ============
local function makeDraggable(targetFrame, handleFrame)
    local dragging, dragStartPos, frameStartPos
    handleFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStartPos = input.Position
            frameStartPos = targetFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStartPos
            targetFrame.Position = UDim2.new(
                frameStartPos.X.Scale, frameStartPos.X.Offset + delta.X,
                frameStartPos.Y.Scale, frameStartPos.Y.Offset + delta.Y
            )
        end
    end)
end

makeDraggable(panel, titleBar)

-- 悬浮球拖拽+点击
local ballHoldStart
local ballMoved = false
local ballDragging = false
local ballDragStart, ballStartPos

ball.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ballHoldStart = os.clock()
        ballMoved = false
        ballDragging = true
        ballDragStart = input.Position
        ballStartPos = ball.Position
        TweenService:Create(ball, QUICK_BOUNCE, {Size = UDim2.new(0, 48, 0, 48)}):Play()
    end
end)

UIS.InputChanged:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - ballDragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then ballMoved = true end
        if ballMoved then
            ball.Position = UDim2.new(
                ballStartPos.X.Scale, ballStartPos.X.Offset + delta.X,
                ballStartPos.Y.Scale, ballStartPos.Y.Offset + delta.Y
            )
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        ballDragging = false
        TweenService:Create(ball, QUICK_BOUNCE, {Size = UDim2.new(0, 60, 0, 60)}):Play()

        local holdTime = os.clock() - ballHoldStart
        if holdTime < 0.3 and not ballMoved then
            ballClickCount = ballClickCount + 1
            if ballClickCount >= 5 then
                unlockAndOpen()
                return
            end
            if not isUnlocked then
                openPass()
            else
                if panel.Visible then
                    panel.Visible = false
                else
                    panel.Visible = true
                    panel.Size = UDim2.new(0, 0, 0, 0)
                    panel.Position = UDim2.new(0.5, -125, 0.5, -225)
                    TweenService:Create(panel, BOUNCE_OUT, {Size = UDim2.new(0, 250, 0, 450)}):Play()
                end
            end
        end
    end
end)

closeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        panel.Visible = false
    end
end)

-- 点击空白关闭面板
UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if not panel.Visible then return end
        local mx, my = input.Position.X, input.Position.Y
        local pa = panel.AbsolutePosition
        local ps = panel.AbsoluteSize
        local inPanel = mx >= pa.X and mx <= pa.X+ps.X and my >= pa.Y and my <= pa.Y+ps.Y

        local ba = ball.AbsolutePosition
        local bs = ball.AbsoluteSize
        local inBall = mx >= ba.X and mx <= ba.X+bs.X and my >= ba.Y and my <= ba.Y+bs.Y

        if not inPanel and not inBall then
            panel.Visible = false
        end
    end
end)

-- 热键 RightShift 开关自瞄
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if UIS:GetFocusedTextBox() then return end
        Config.AutoTrack = not Config.AutoTrack
        if updateTrackUI then updateTrackUI() end
    end
end)

print("[Neon Tracker v8.4] 已加载 | UI 可滑动 | 双重大头可同时开启")