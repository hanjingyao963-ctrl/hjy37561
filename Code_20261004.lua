-- ================= Neon Tracker v9.0 (Full Feature) =================
-- 矮胖UI | 大头倍数可调 | 追踪增强 | 穿墙修复 | NPC透视 | 开关弹窗
-- ====================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============ 密码与状态 ============
local SECRET = "919878"
local isUnlocked = false
local ballClickCount = 0

-- ============ 全局配置 ============
local Config = {
    AutoTrack = false,
    TrackRadius = 300,
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
    NPCESP = false,
    ShowFOV = false
}

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

-- ============ 核心：静默自瞄 ============
RunService.RenderStepped:Connect(function()
    if Config.AutoTrack then
        currentTarget = getClosestTarget()
    else
        currentTarget = nil
    end

    -- 玩家 ESP
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

    -- NPC ESP
    if Config.NPCESP then
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
                -- 排除玩家角色
                local isPlayerChar = false
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr.Character == obj then isPlayerChar = true break end
                end
                if not isPlayerChar then
                    local hl = obj:FindFirstChild("TrackerNPCESP")
                    if not hl then
                        hl = Instance.new("Highlight")
                        hl.Name = "TrackerNPCESP"
                        hl.FillColor = Color3.fromRGB(0, 255, 130)
                        hl.OutlineColor = Color3.fromRGB(0, 180, 90)
                        hl.FillTransparency = 0.55
                        hl.OutlineTransparency = 0
                        hl.Parent = obj
                    end
                end
            end
        end
    else
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Highlight") and obj.Name == "TrackerNPCESP" then
                obj:Destroy()
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

-- ============ 核心：大头（每帧强制刷新，确保生效） ============
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

                if Config.HitboxPhysics or Config.HitboxVisual then
                    targetSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                end
                if Config.HitboxPhysics then
                    targetQuery = true
                    targetCollide = false
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

-- ============ FOV / 穿墙 / 防虚空 ============
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

-- 【穿墙修复】每帧强制覆盖，防止游戏重置
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

    -- 【穿墙增强】强制覆盖所有部件的 CanCollide
    if Config.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
        -- 同时禁止 Humanoid 状态被墙壁阻挡
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding, true)
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
-- ================== UI 部分（矮胖布局） =============
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
local QUICK_BOUNCE = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- 【新功能】玻璃质感开关提示弹窗（右下角跳跃键上方）
local function showToggleNotification(label, isOn)
    local notif = Instance.new("Frame")
    notif.Name = "ToggleNotif"
    notif.Size = UDim2.new(0, 0, 0, 42)
    notif.Position = UDim2.new(1, -220, 1, -200) -- 右下角，跳跃键上方
    notif.AnchorPoint = Vector2.new(0, 0.5)
    notif.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
    notif.BackgroundTransparency = 0.25
    notif.BorderSizePixel = 0
    notif.Active = false -- 【关键】点击穿透，不挡跳跃键
    notif.Selectable = false
    notif.ZIndex = 50
    notif.Parent = gui

    local notifCorner = Instance.new("UICorner")
    notifCorner.CornerRadius = UDim.new(0, 10)
    notifCorner.Parent = notif

    -- 玻璃质感描边（紫红渐变）
    local notifStroke = Instance.new("UIStroke")
    notifStroke.Thickness = 1.5
    notifStroke.Transparency = 0.2
    notifStroke.Parent = notif

    local notifGrad = Instance.new("UIGradient")
    notifGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128)),
    })
    notifGrad.Parent = notifStroke

    -- 玻璃高光（顶部一层半透明白色，模拟玻璃）
    local glass = Instance.new("Frame")
    glass.Size = UDim2.new(1, 0, 0.5, 0)
    glass.Position = UDim2.new(0, 0, 0, 0)
    glass.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    glass.BackgroundTransparency = 0.88
    glass.BorderSizePixel = 0
    glass.ZIndex = 51
    glass.Parent = notif
    Instance.new("UICorner", glass).CornerRadius = UDim.new(0, 10)

    -- 状态圆点
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, 14, 0.5, -5)
    dot.BackgroundColor3 = isOn and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
    dot.BorderSizePixel = 0
    dot.ZIndex = 52
    dot.Parent = notif
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    -- 文字
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -34, 1, 0)
    txt.Position = UDim2.new(0, 30, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label .. (isOn and " 已开启" or " 已关闭")
    txt.TextColor3 = isOn and Color3.fromRGB(200, 255, 220) or Color3.fromRGB(255, 200, 200)
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = 13
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.ZIndex = 52
    txt.Parent = notif

    -- 弹出动画（QQ弹弹）
    TweenService:Create(notif, BOUNCE_OUT, {Size = UDim2.new(0, 200, 0, 42)}):Play()

    -- 1.5 秒后自动淡出
    task.spawn(function()
        task.wait(1.5)
        local fade = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 0, 0, 42)
        })
        fade:Play()
        for _, child in ipairs(notif:GetDescendants()) do
            if child:IsA("TextLabel") then
                TweenService:Create(child, TweenInfo.new(0.3), {TextTransparency = 1}):Play()
            elseif child:IsA("Frame") and child ~= notif then
                TweenService:Create(child, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
            elseif child:IsA("UIStroke") then
                TweenService:Create(child, TweenInfo.new(0.3), {Transparency = 1}):Play()
            end
        end
        fade.Completed:Connect(function()
            notif:Destroy()
        end)
    end)
end

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

-- 【矮胖】主面板 320 宽，400 高
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 320, 0, 400)
panel.Position = UDim2.new(0, 150, 0, 180)
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
title.Text = "TRACKER v9.0"
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

-- 滚动容器
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -40)
scroll.Position = UDim2.new(0, 0, 0, 40)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(180, 0, 255)
scroll.CanvasSize = UDim2.new(0, 0, 0, 620)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

-- 模块化开关（带弹窗通知）
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
    lbl.TextColor3 = Color3.fromRGB(220, 230, 255)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 12
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local state = Instance.new("TextLabel")
    state.Size = UDim2.new(0, 40, 1, 0)
    state.Position = UDim2.new(1, -50, 0, 0)
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
            -- 弹出玻璃提示
            showToggleNotification(labelText, getter())
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
local updateESPUI = createToggle(210, "ESP 玩家透视", function() return Config.ESP end, function(v) Config.ESP = v end)
local updateNPCUI = createToggle(250, "ESP NPC透视", function() return Config.NPCESP end, function(v) Config.NPCESP = v end)
local updateFOVUI = createToggle(290, "FOV 圈", function() return Config.ShowFOV end, function(v) Config.ShowFOV = v end)

-- 瞄准部位
local aimRow = Instance.new("Frame")
aimRow.Size = UDim2.new(1, -20, 0, 35)
aimRow.Position = UDim2.new(0, 10, 0, 330)
aimRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
aimRow.BorderSizePixel = 0
aimRow.Parent = scroll
Instance.new("UICorner", aimRow).CornerRadius = UDim.new(0, 10)

local aimLabel = Instance.new("TextLabel")
aimLabel.Size = UDim2.new(0, 80, 1, 0)
aimLabel.Position = UDim2.new(0, 12, 0, 0)
aimLabel.BackgroundTransparency = 1
aimLabel.Text = "瞄准部位"
aimLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
aimLabel.Font = Enum.Font.GothamBold
aimLabel.TextSize = 12
aimLabel.TextXAlignment = Enum.TextXAlignment.Left
aimLabel.Parent = aimRow

local headBtn = Instance.new("TextButton")
headBtn.Size = UDim2.new(0, 60, 0, 22)
headBtn.Position = UDim2.new(1, -134, 0.5, -11)
headBtn.Text = "头部"
headBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
headBtn.Font = Enum.Font.GothamBold
headBtn.TextSize = 11
headBtn.AutoButtonColor = false
headBtn.BorderSizePixel = 0
headBtn.Parent = aimRow
Instance.new("UICorner", headBtn).CornerRadius = UDim.new(0, 5)

local bodyBtn = Instance.new("TextButton")
bodyBtn.Size = UDim2.new(0, 60, 0, 22)
bodyBtn.Position = UDim2.new(1, -68, 0.5, -11)
bodyBtn.Text = "身体"
bodyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bodyBtn.Font = Enum.Font.GothamBold
bodyBtn.TextSize = 11
bodyBtn.AutoButtonColor = false
bodyBtn.BorderSizePixel = 0
bodyBtn.Parent = aimRow
Instance.new("UICorner", bodyBtn).CornerRadius = UDim.new(0, 5)

local function updateAimUI()
    local isHead = Config.AimPart == "Head"
    TweenService:Create(headBtn, QUICK_BOUNCE, {BackgroundColor3 = isHead and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
    TweenService:Create(bodyBtn, QUICK_BOUNCE, {BackgroundColor3 = (not isHead) and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
end
updateAimUI()

headBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Config.AimPart = "Head"; updateAimUI() end end)
bodyBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Config.AimPart = "HumanoidRootPart"; updateAimUI() end end)

-- 追踪半径
local radiusRow = Instance.new("Frame")
radiusRow.Size = UDim2.new(1, -20, 0, 45)
radiusRow.Position = UDim2.new(0, 10, 0, 375)
radiusRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
radiusRow.BorderSizePixel = 0
radiusRow.Parent = scroll
Instance.new("UICorner", radiusRow).CornerRadius = UDim.new(0, 10)

local radiusValue = Instance.new("TextLabel")
radiusValue.Size = UDim2.new(1, -24, 0, 18)
radiusValue.Position = UDim2.new(0, 12, 0, 2)
radiusValue.BackgroundTransparency = 1
radiusValue.Text = "追踪半径: " .. Config.TrackRadius .. " 格"
radiusValue.TextColor3 = Color3.fromRGB(200, 150, 255)
radiusValue.Font = Enum.Font.GothamBold
radiusValue.TextSize = 11
radiusValue.TextXAlignment = Enum.TextXAlignment.Left
radiusValue.Parent = radiusRow

local R_MIN, R_MAX = 50, 1500
local R_RANGE = R_MAX - R_MIN
local trackBg = Instance.new("Frame")
trackBg.Size = UDim2.new(1, -24, 0, 6)
trackBg.Position = UDim2.new(0, 12, 1, -14)
trackBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
trackBg.BorderSizePixel = 0
trackBg.Parent = radiusRow
Instance.new("UICorner", trackBg).CornerRadius = UDim.new(1, 0)

local fill = Instance.new("Frame")
fill.Size = UDim2.new((Config.TrackRadius - R_MIN) / R_RANGE, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
fill.BorderSizePixel = 0
fill.Parent = trackBg
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local knob = Instance.new("Frame")
knob.Size = UDim2.new(0, 12, 0, 12)
knob.Position = UDim2.new((Config.TrackRadius - R_MIN) / R_RANGE, -6, 0.5, -6)
knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
knob.BorderSizePixel = 0
knob.ZIndex = 2
knob.Parent = trackBg
Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

-- 【新功能】大头倍数滑块
local hitboxRow = Instance.new("Frame")
hitboxRow.Size = UDim2.new(1, -20, 0, 45)
hitboxRow.Position = UDim2.new(0, 10, 0, 425)
hitboxRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
hitboxRow.BorderSizePixel = 0
hitboxRow.Parent = scroll
Instance.new("UICorner", hitboxRow).CornerRadius = UDim.new(0, 10)

local hitboxValue = Instance.new("TextLabel")
hitboxValue.Size = UDim2.new(1, -24, 0, 18)
hitboxValue.Position = UDim2.new(0, 12, 0, 2)
hitboxValue.BackgroundTransparency = 1
hitboxValue.Text = "大头倍数: " .. Config.HitboxSize
hitboxValue.TextColor3 = Color3.fromRGB(200, 150, 255)
hitboxValue.Font = Enum.Font.GothamBold
hitboxValue.TextSize = 11
hitboxValue.TextXAlignment = Enum.TextXAlignment.Left
hitboxValue.Parent = hitboxRow

local H_MIN, H_MAX = 10, 60
local H_RANGE = H_MAX - H_MIN
local hTrackBg = Instance.new("Frame")
hTrackBg.Size = UDim2.new(1, -24, 0, 6)
hTrackBg.Position = UDim2.new(0, 12, 1, -14)
hTrackBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
hTrackBg.BorderSizePixel = 0
hTrackBg.Parent = hitboxRow
Instance.new("UICorner", hTrackBg).CornerRadius = UDim.new(1, 0)

local hFill = Instance.new("Frame")
hFill.Size = UDim2.new((Config.HitboxSize - H_MIN) / H_RANGE, 0, 1, 0)
hFill.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
hFill.BorderSizePixel = 0
hFill.Parent = hTrackBg
Instance.new("UICorner", hFill).CornerRadius = UDim.new(1, 0)

local hKnob = Instance.new("Frame")
hKnob.Size = UDim2.new(0, 12, 0, 12)
hKnob.Position = UDim2.new((Config.HitboxSize - H_MIN) / H_RANGE, -6, 0.5, -6)
hKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
hKnob.BorderSizePixel = 0
hKnob.ZIndex = 2
hKnob.Parent = hTrackBg
Instance.new("UICorner", hKnob).CornerRadius = UDim.new(1, 0)

-- 平滑度
local smoothRow = Instance.new("Frame")
smoothRow.Size = UDim2.new(1, -20, 0, 45)
smoothRow.Position = UDim2.new(0, 10, 0, 475)
smoothRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
smoothRow.BorderSizePixel = 0
smoothRow.Parent = scroll
Instance.new("UICorner", smoothRow).CornerRadius = UDim.new(0, 10)

local smoothValue = Instance.new("TextLabel")
smoothValue.Size = UDim2.new(1, -24, 0, 18)
smoothValue.Position = UDim2.new(0, 12, 0, 2)
smoothValue.BackgroundTransparency = 1
smoothValue.Text = "瞄准平滑度: " .. Config.Smoothing
smoothValue.TextColor3 = Color3.fromRGB(200, 150, 255)
smoothValue.Font = Enum.Font.GothamBold
smoothValue.TextSize = 11
smoothValue.TextXAlignment = Enum.TextXAlignment.Left
smoothValue.Parent = smoothRow

local sMin, sMax = 0.1, 1.0
local sTrackBg = Instance.new("Frame")
sTrackBg.Size = UDim2.new(1, -24, 0, 6)
sTrackBg.Position = UDim2.new(0, 12, 1, -14)
sTrackBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
sTrackBg.BorderSizePixel = 0
sTrackBg.Parent = smoothRow
Instance.new("UICorner", sTrackBg).CornerRadius = UDim.new(1, 0)

local sFill = Instance.new("Frame")
sFill.Size = UDim2.new((Config.Smoothing - sMin) / (sMax - sMin), 0, 1, 0)
sFill.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
sFill.BorderSizePixel = 0
sFill.Parent = sTrackBg
Instance.new("UICorner", sFill).CornerRadius = UDim.new(1, 0)

local sKnob = Instance.new("Frame")
sKnob.Size = UDim2.new(0, 12, 0, 12)
sKnob.Position = UDim2.new((Config.Smoothing - sMin) / (sMax - sMin), -6, 0.5, -6)
sKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sKnob.BorderSizePixel = 0
sKnob.ZIndex = 2
sKnob.Parent = sTrackBg
Instance.new("UICorner", sKnob).CornerRadius = UDim.new(1, 0)

-- 滑块绑定
local function bindSlider(track, fill, knob, min, max, callback)
    local draggingSlider = false
    local function updateSlider(inputX)
        local relX = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        local val = min + relX * (max - min)
        callback(val, relX)
    end
    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true
            updateSlider(input.Position.X)
            TweenService:Create(knob, QUICK_BOUNCE, {Size = UDim2.new(0, 16, 0, 16)}):Play()
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if draggingSlider then
                draggingSlider = false
                TweenService:Create(knob, QUICK_BOUNCE, {Size = UDim2.new(0, 12, 0, 12)}):Play()
            end
        end
    end)
end

bindSlider(trackBg, fill, knob, R_MIN, R_MAX, function(val, relX)
    val = math.floor(val / 10 + 0.5) * 10
    Config.TrackRadius = val
    radiusValue.Text = "追踪半径: " .. val .. " 格"
    fill.Size = UDim2.new(relX, 0, 1, 0)
    knob.Position = UDim2.new(relX, -8, 0.5, -8)
end)

bindSlider(hTrackBg, hFill, hKnob, H_MIN, H_MAX, function(val, relX)
    val = math.floor(val + 0.5)
    Config.HitboxSize = val
    hitboxValue.Text = "大头倍数: " .. val
    hFill.Size = UDim2.new(relX, 0, 1, 0)
    hKnob.Position = UDim2.new(relX, -8, 0.5, -8)
end)

bindSlider(sTrackBg, sFill, sKnob, sMin, sMax, function(val, relX)
    Config.Smoothing = math.floor(val * 100 + 0.5) / 100
    smoothValue.Text = "瞄准平滑度: " .. Config.Smoothing
    sFill.Size = UDim2.new(relX, 0, 1, 0)
    sKnob.Position = UDim2.new(relX, -8, 0.5, -8)
end)

-- ============ 密码弹窗 ============
local passOverlay = Instance.new("Frame")
passOverlay.Size = UDim2.new(1, 0, 1, 0)
passOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
passOverlay.BackgroundTransparency = 0.6
passOverlay.BorderSizePixel = 0
passOverlay.Visible = false
passOverlay.ZIndex = 60
passOverlay.Parent = gui

local passBox = Instance.new("Frame")
passBox.Size = UDim2.new(0, 240, 0, 160)
passBox.Position = UDim2.new(0.5, -120, 0.5, -80)
passBox.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
passBox.BorderSizePixel = 0
passBox.ZIndex = 61
passBox.Parent = passOverlay
Instance.new("UICorner", passBox).CornerRadius = UDim.new(0, 12)

local pbTitle = Instance.new("TextLabel")
pbTitle.Size = UDim2.new(1, -20, 0, 26)
pbTitle.Position = UDim2.new(0, 14, 0, 10)
pbTitle.BackgroundTransparency = 1
pbTitle.Text = "◆ 密码验证"
pbTitle.TextColor3 = Color3.fromRGB(200, 150, 255)
pbTitle.Font = Enum.Font.GothamBold
pbTitle.TextSize = 13
pbTitle.TextXAlignment = Enum.TextXAlignment.Left
pbTitle.ZIndex = 62
pbTitle.Parent = passBox

local pbInput = Instance.new("TextBox")
pbInput.Size = UDim2.new(1, -28, 0, 36)
pbInput.Position = UDim2.new(0, 14, 0, 46)
pbInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
pbInput.BorderSizePixel = 0
pbInput.Text = ""
pbInput.PlaceholderText = "请输入密码"
pbInput.PlaceholderColor3 = Color3.fromRGB(110, 130, 160)
pbInput.TextColor3 = Color3.fromRGB(230, 240, 255)
pbInput.Font = Enum.Font.GothamMedium
pbInput.TextSize = 13
pbInput.ClearTextOnFocus = false
pbInput.TextEditable = true
pbInput.Selectable = true
pbInput.ZIndex = 62
pbInput.Parent = passBox
Instance.new("UICorner", pbInput).CornerRadius = UDim.new(0, 8)

local pbErr = Instance.new("TextLabel")
pbErr.Size = UDim2.new(1, -28, 0, 14)
pbErr.Position = UDim2.new(0, 14, 0, 86)
pbErr.BackgroundTransparency = 1
pbErr.Text = ""
pbErr.TextColor3 = Color3.fromRGB(255, 90, 90)
pbErr.Font = Enum.Font.GothamMedium
pbErr.TextSize = 10
pbErr.TextXAlignment = Enum.TextXAlignment.Left
pbErr.ZIndex = 62
pbErr.Parent = passBox

local pbOk = Instance.new("TextButton")
pbOk.Size = UDim2.new(0, 95, 0, 32)
pbOk.Position = UDim2.new(1, -109, 1, -45)
pbOk.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
pbOk.Text = "确认"
pbOk.TextColor3 = Color3.fromRGB(255, 255, 255)
pbOk.Font = Enum.Font.GothamBold
pbOk.TextSize = 12
pbOk.AutoButtonColor = false
pbOk.BorderSizePixel = 0
pbOk.ZIndex = 62
pbOk.Parent = passBox
Instance.new("UICorner", pbOk).CornerRadius = UDim.new(0, 8)

local pbCancel = Instance.new("TextButton")
pbCancel.Size = UDim2.new(0, 70, 0, 32)
pbCancel.Position = UDim2.new(1, -189, 1, -45)
pbCancel.BackgroundColor3 = Color3.fromRGB(40, 46, 62)
pbCancel.Text = "取消"
pbCancel.TextColor3 = Color3.fromRGB(200, 210, 230)
pbCancel.Font = Enum.Font.GothamBold
pbCancel.TextSize = 12
pbCancel.AutoButtonColor = false
pbCancel.BorderSizePixel = 0
pbCancel.ZIndex = 62
pbCancel.Parent = passBox
Instance.new("UICorner", pbCancel).CornerRadius = UDim.new(0, 8)

local function openPass()
    pbInput.Text = ""
    pbErr.Text = ""
    passOverlay.Visible = true
    task.wait(0.2)
    pbInput:CaptureFocus()
end

local function closePass()
    passOverlay.Visible = false
    pbInput:ReleaseFocus()
end

local function shake(frame)
    local base = frame.Position
    for i = 1, 4 do
        TweenService:Create(frame, TweenInfo.new(0.05), {Position = base + UDim2.new(0, (i % 2 == 0 and -6 or 6), 0, 0)}):Play()
        task.wait(0.05)
    end
    TweenService:Create(frame, TweenInfo.new(0.05), {Position = base}):Play()
end

local function showWelcomeAnimation()
    local welcomeText = Instance.new("TextLabel")
    welcomeText.Name = "WelcomeText"
    welcomeText.Size = UDim2.new(0, 0, 0, 0)
    welcomeText.Position = UDim2.new(0.5, 0, 0.5, 0)
    welcomeText.AnchorPoint = Vector2.new(0.5, 0.5)
    welcomeText.BackgroundTransparency = 1
    welcomeText.Text = "欢迎使用jy脚本"
    welcomeText.TextColor3 = Color3.fromRGB(200, 150, 255)
    welcomeText.TextStrokeTransparency = 0
    welcomeText.TextStrokeColor3 = Color3.fromRGB(255, 0, 128)
    welcomeText.Font = Enum.Font.GothamBlack
    welcomeText.TextSize = 28
    welcomeText.ZIndex = 100
    welcomeText.Parent = gui

    TweenService:Create(welcomeText, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 350, 0, 70)
    }):Play()

    task.wait(2)

    local fadeOut = TweenService:Create(welcomeText, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        TextTransparency = 1,
        TextStrokeTransparency = 1
    })
    fadeOut:Play()
    fadeOut.Completed:Connect(function()
        welcomeText:Destroy()
    end)
end

local function unlockAndOpen()
    isUnlocked = true
    ballClickCount = 0
    closePass()
    panel.Visible = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Position = UDim2.new(0.5, -160, 0.5, -200)
    TweenService:Create(panel, BOUNCE_OUT, {Size = UDim2.new(0, 320, 0, 400)}):Play()
    ball.Visible = true
    TweenService:Create(ball, QUICK_BOUNCE, {Size = UDim2.new(0, 60, 0, 60), Position = UDim2.new(0, 110, 0, 120)}):Play()
    showWelcomeAnimation()
end

local function tryUnlock()
    local entered = pbInput.Text
    entered = entered:gsub("%s", "")
    entered = entered:gsub("０","0"):gsub("１","1"):gsub("２","2"):gsub("３","3"):gsub("４","4"):gsub("５","5"):gsub("６","6"):gsub("７","7"):gsub("８","8"):gsub("９","9")
    entered = entered:gsub("%D", "")

    if entered == SECRET then
        unlockAndOpen()
    else
        pbErr.Text = "密码错误，请重试"
        pbInput.Text = ""
        shake(passBox)
    end
end

pbOk.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryUnlock()
    end
end)
pbInput.FocusLost:Connect(function(enter) if enter then tryUnlock() end end)
pbCancel.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then closePass() end end)

-- ============ 触摸与拖拽 ============
local function makeDraggable(frame, dragHandle)
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

makeDraggable(panel, titleBar)

-- 悬浮球触摸
local ballHoldStart = 0
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
            ball.Position = UDim2.new(ballStartPos.X.Scale, ballStartPos.X.Offset + delta.X, ballStartPos.Y.Scale, ballStartPos.Y.Offset + delta.Y)
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
                    panel.Position = UDim2.new(0.5, -160, 0.5, -200)
                    TweenService:Create(panel, BOUNCE_OUT, {Size = UDim2.new(0, 320, 0, 400)}):Play()
                end
            end
        end
    end
end)

closeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        panel.Visible = false
        TweenService:Create(ball, QUICK_BOUNCE, {Size = UDim2.new(0, 60, 0, 60)}):Play()
    end
end)

-- 点击空白缩回
UIS.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if not panel.Visible then return end
        local mousePos = input.Position
        local pX, pY = panel.AbsolutePosition.X, panel.AbsolutePosition.Y
        local pW, pH = panel.AbsoluteSize.X, panel.AbsoluteSize.Y
        local inPanel = mousePos.X >= pX and mousePos.X <= pX + pW and mousePos.Y >= pY and mousePos.Y <= pY + pH
        local bX, bY = ball.AbsolutePosition.X, ball.AbsolutePosition.Y
        local bW, bH = ball.AbsoluteSize.X, ball.AbsoluteSize.Y
        local inBall = mousePos.X >= bX and mousePos.X <= bX + bW and mousePos.Y >= bY and mousePos.Y <= bY + bH
        if not inPanel and not inBall then
            panel.Visible = false
            TweenService:Create(ball, QUICK_BOUNCE, {Size = UDim2.new(0, 60, 0, 60)}):Play()
        end
    end
end)

-- 热键
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        if UIS:GetFocusedTextBox() then return end
        Config.AutoTrack = not Config.AutoTrack
        if updateTrackUI then updateTrackUI() end
        showToggleNotification("自动追踪", Config.AutoTrack)
    end
end)

print("[Neon Tracker v9.0] 已加载 | 矮胖UI | 大头倍数可调 | NPC透视 | 玻璃弹窗")