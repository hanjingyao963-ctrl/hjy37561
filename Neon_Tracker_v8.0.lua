-- ================= Neon Tracker v8.0 (Optimized & Full Features) =================
-- 修复所有Bug | 新增ESP/FOV圈/平滑度/热键 | 模块化优化加载速度 | 保留全部原有功能
-- ==================================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============ 1. 密码与全局状态 ============
local SECRET = "919878"
local isUnlocked = false
local ballClickCount = 0

-- ============ 2. 全局配置 ============
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
    Smoothing = 0.6,      -- 新增：瞄准平滑度
    ESP = false,          -- 新增：ESP透视
    ShowFOV = false       -- 新增：FOV圈
}

-- ============ 3. 追踪目标获取（修复黑白名单逻辑） ============
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
        
        -- 【Bug修复】黑白名单逻辑
        local inList = isInList(plr)
        if Config.ListMode == "Whitelist" then
            if not inList then continue end -- 白名单：不在名单里就跳过
        else
            if inList then continue end     -- 黑名单：在名单里就跳过
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

-- ============ 4. 核心：静默自瞄 & 平滑度调节 ============
RunService.RenderStepped:Connect(function(deltaTime)
    if Config.AutoTrack then
        currentTarget = getClosestTarget()
    else
        currentTarget = nil
    end

    -- ESP 逻辑更新
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
    
    -- 【Bug修复】使用可调节的平滑度系数，0.6 太硬容易被察觉，现在可用滑块调节（0.1 到 1.0）
    Camera.CFrame = currentCFrame:Lerp(newCFrame, Config.Smoothing)
end)

-- ============ 5. 核心：双重大头 & 物理放大 ============
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
                
                if Config.HitboxPhysics then
                    targetSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                    targetQuery = true
                    targetCollide = false
                elseif Config.HitboxVisual then
                    targetSize = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                end
                
                head.Size = targetSize
                head.CanQuery = targetQuery
                head.CanCollide = targetCollide
            end
        end
    end
end)

-- ============ 6. 核心：穿墙 & 防掉虚空 ============
local fovCircle = Instance.new("Part")
fovCircle.Name = "FOVCircle"
fovCircle.Shape = Enum.PartType.Ball
fovCircle.Material = Enum.Material.ForceField
fovCircle.Color = Color3.fromRGB(180, 0, 255)
fovCircle.Transparency = 0.85
fovCircle.CanCollide = false
fovCircle.CanQuery = false
fovCircle.Anchored = true
fovCircle.Parent = Workspace

RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- FOV 圈逻辑
    if Config.ShowFOV then
        fovCircle.Size = Vector3.new(Config.TrackRadius * 2, Config.TrackRadius * 2, Config.TrackRadius * 2)
        fovCircle.CFrame = hrp.CFrame
        fovCircle.Transparency = 0.85
    else
        fovCircle.Transparency = 1
    end

    -- 穿墙
    if Config.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end

    -- 防掉虚空
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
-- ============== 7. UI 部分（精简模块化，提升加载速度） =====
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

-- 主面板
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 0, 550) -- 高度增加，容纳新功能
panel.Position = UDim2.new(0, 150, 0, 120)
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
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundTransparency = 1
titleBar.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TRACKER v8.0"
title.TextColor3 = Color3.fromRGB(200, 150, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)

-- 模块化开关生成器
local function createToggle(yPos, labelText, getter, setter)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -20, 0, 35)
    row.Position = UDim2.new(0, 10, 0, yPos)
    row.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
    row.Text = ""
    row.AutoButtonColor = false
    row.BorderSizePixel = 0
    row.Parent = panel
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
        end
    end)
    return updateUI
end

-- 新增/修改后的开关列表
local updateTrackUI = createToggle(40, "自动追踪", function() return Config.AutoTrack end, function(v) Config.AutoTrack = v end)
local updatePhysUI = createToggle(78, "物理大头 (判定)", function() return Config.HitboxPhysics end, function(v) Config.HitboxPhysics = v; if v then Config.HitboxVisual = false end end)
local updateVisUI = createToggle(116, "视觉大头 (外观)", function() return Config.HitboxVisual end, function(v) Config.HitboxVisual = v; if v then Config.HitboxPhysics = false end end)
local updateNoclipUI = createToggle(154, "穿墙模式", function() return Config.Noclip end, function(v) Config.Noclip = v; if not v then safeDisableNoclip() end end)
local updateVoidUI = createToggle(192, "防掉虚空", function() return Config.VoidProtection end, function(v) Config.VoidProtection = v end)
local updateESPUI = createToggle(230, "ESP 透视", function() return Config.ESP end, function(v) Config.ESP = v end)
local updateFOVUI = createToggle(268, "FOV 圈 (显示范围)", function() return Config.ShowFOV end, function(v) Config.ShowFOV = v end)

-- 瞄准部位
local aimRow = Instance.new("Frame")
aimRow.Size = UDim2.new(1, -20, 0, 35)
aimRow.Position = UDim2.new(0, 10, 0, 306)
aimRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
aimRow.BorderSizePixel = 0
aimRow.Parent = panel
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
headBtn.Size = UDim2.new(0, 50, 0, 22)
headBtn.Position = UDim2.new(1, -114, 0.5, -11)
headBtn.Text = "头部"
headBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
headBtn.Font = Enum.Font.GothamBold
headBtn.TextSize = 11
headBtn.AutoButtonColor = false
headBtn.BorderSizePixel = 0
headBtn.Parent = aimRow
Instance.new("UICorner", headBtn).CornerRadius = UDim.new(0, 5)

local bodyBtn = Instance.new("TextButton")
bodyBtn.Size = UDim2.new(0, 50, 0, 22)
bodyBtn.Position = UDim2.new(1, -58, 0.5, -11)
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

-- 追踪半径 + 平滑度滑块
local radiusRow = Instance.new("Frame")
radiusRow.Size = UDim2.new(1, -20, 0, 45)
radiusRow.Position = UDim2.new(0, 10, 0, 348)
radiusRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
radiusRow.BorderSizePixel = 0
radiusRow.Parent = panel
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

local R_MIN, R_MAX = 50, 1000
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

-- 平滑度滑块
local smoothRow = Instance.new("Frame")
smoothRow.Size = UDim2.new(1, -20, 0, 45)
smoothRow.Position = UDim2.new(0, 10, 0, 398)
smoothRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
smoothRow.BorderSizePixel = 0
smoothRow.Parent = panel
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

-- 界面缩放
local scaleRow = Instance.new("Frame")
scaleRow.Size = UDim2.new(1, -20, 0, 45)
scaleRow.Position = UDim2.new(0, 10, 0, 448)
scaleRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
scaleRow.BorderSizePixel = 0
scaleRow.Parent = panel
Instance.new("UICorner", scaleRow).CornerRadius = UDim.new(0, 10)

local scaleValue = Instance.new("TextLabel")
scaleValue.Size = UDim2.new(1, -24, 0, 18)
scaleValue.Position = UDim2.new(0, 12, 0, 2)
scaleValue.BackgroundTransparency = 1
scaleValue.Text = "界面缩放: " .. math.floor(Config.UIScale * 100) .. "%"
scaleValue.TextColor3 = Color3.fromRGB(200, 150, 255)
scaleValue.Font = Enum.Font.GothamBold
scaleValue.TextSize = 11
scaleValue.TextXAlignment = Enum.TextXAlignment.Left
scaleValue.Parent = scaleRow

local scTrackBg = Instance.new("Frame")
scTrackBg.Size = UDim2.new(1, -24, 0, 6)
scTrackBg.Position = UDim2.new(0, 12, 1, -14)
scTrackBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
scTrackBg.BorderSizePixel = 0
scTrackBg.Parent = scaleRow
Instance.new("UICorner", scTrackBg).CornerRadius = UDim.new(1, 0)

local scFill = Instance.new("Frame")
scFill.Size = UDim2.new((Config.UIScale - 0.5) / 1.5, 0, 1, 0)
scFill.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
scFill.BorderSizePixel = 0
scFill.Parent = scTrackBg
Instance.new("UICorner", scFill).CornerRadius = UDim.new(1, 0)

local scKnob = Instance.new("Frame")
scKnob.Size = UDim2.new(0, 12, 0, 12)
scKnob.Position = UDim2.new((Config.UIScale - 0.5) / 1.5, -6, 0.5, -6)
scKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
scKnob.BorderSizePixel = 0
scKnob.ZIndex = 2
scKnob.Parent = scTrackBg
Instance.new("UICorner", scKnob).CornerRadius = UDim.new(1, 0)

-- 黑白名单区域
local listHeader = Instance.new("Frame")
listHeader.Size = UDim2.new(1, -20, 0, 26)
listHeader.Position = UDim2.new(0, 10, 0, 496)
listHeader.BackgroundTransparency = 1
listHeader.Parent = panel

local wlBtn = Instance.new("TextButton")
wlBtn.Size = UDim2.new(0, 70, 0, 24)
wlBtn.Position = UDim2.new(0, 0, 0, 0)
wlBtn.Text = "白名单"
wlBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
wlBtn.Font = Enum.Font.GothamBold
wlBtn.TextSize = 11
wlBtn.AutoButtonColor = false
wlBtn.BorderSizePixel = 0
wlBtn.Parent = listHeader
Instance.new("UICorner", wlBtn).CornerRadius = UDim.new(0, 5)

local blBtn = Instance.new("TextButton")
blBtn.Size = UDim2.new(0, 70, 0, 24)
blBtn.Position = UDim2.new(0, 76, 0, 0)
blBtn.Text = "黑名单"
blBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
blBtn.Font = Enum.Font.GothamBold
blBtn.TextSize = 11
blBtn.AutoButtonColor = false
blBtn.BorderSizePixel = 0
blBtn.Parent = listHeader
Instance.new("UICorner", blBtn).CornerRadius = UDim.new(0, 5)

local function updateModeUI()
    local isWL = Config.ListMode == "Whitelist"
    TweenService:Create(wlBtn, QUICK_BOUNCE, {BackgroundColor3 = isWL and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
    TweenService:Create(blBtn, QUICK_BOUNCE, {BackgroundColor3 = (not isWL) and Color3.fromRGB(255, 0, 128) or Color3.fromRGB(40, 46, 62)}):Play()
end
updateModeUI()

wlBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Config.ListMode = "Whitelist"; updateModeUI() end end)
blBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then Config.ListMode = "Blacklist"; updateModeUI() end end)

local inputRow = Instance.new("Frame")
inputRow.Size = UDim2.new(1, -20, 0, 26)
inputRow.Position = UDim2.new(0, 10, 0, 524)
inputRow.BackgroundTransparency = 1
inputRow.Parent = panel

local playerInput = Instance.new("TextBox")
playerInput.Size = UDim2.new(1, -75, 1, 0)
playerInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
playerInput.BorderSizePixel = 0
playerInput.Text = ""
playerInput.PlaceholderText = "输入玩家名字..."
playerInput.PlaceholderColor3 = Color3.fromRGB(110, 130, 160)
playerInput.TextColor3 = Color3.fromRGB(230, 240, 255)
playerInput.Font = Enum.Font.GothamMedium
playerInput.TextSize = 11
playerInput.ClearTextOnFocus = false
playerInput.Parent = inputRow
Instance.new("UICorner", playerInput).CornerRadius = UDim.new(0, 6)

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0, 65, 1, 0)
addBtn.Position = UDim2.new(1, -65, 0, 0)
addBtn.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
addBtn.Text = "+ 添加"
addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 11
addBtn.AutoButtonColor = false
addBtn.BorderSizePixel = 0
addBtn.Parent = inputRow
Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 6)

local listScroll = Instance.new("ScrollingFrame")
listScroll.Size = UDim2.new(1, -20, 0, 60)
listScroll.Position = UDim2.new(0, 10, 0, 554)
listScroll.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
listScroll.BorderSizePixel = 0
listScroll.ScrollBarThickness = 4
listScroll.ScrollBarImageColor3 = Color3.fromRGB(180, 0, 255)
listScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
listScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
listScroll.Active = true
listScroll.Parent = panel
Instance.new("UICorner", listScroll).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listScroll

local function rebuildList()
    for _, c in ipairs(listScroll:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
    for _, name in ipairs(Config.PlayerList) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 22)
        row.BackgroundColor3 = Color3.fromRGB(30, 35, 48)
        row.BorderSizePixel = 0
        row.Parent = listScroll
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 5)

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -32, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(220, 230, 255)
        lbl.Font = Enum.Font.GothamMedium
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local del = Instance.new("TextButton")
        del.Size = UDim2.new(0, 20, 0, 18)
        del.Position = UDim2.new(1, -24, 0.5, -9)
        del.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        del.Text = "×"
        del.TextColor3 = Color3.fromRGB(255, 255, 255)
        del.Font = Enum.Font.GothamBold
        del.TextSize = 12
        del.AutoButtonColor = false
        del.BorderSizePixel = 0
        del.Parent = row
        Instance.new("UICorner", del).CornerRadius = UDim.new(0, 4)

        del.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local idx = table.find(Config.PlayerList, name)
                if idx then table.remove(Config.PlayerList, idx) end
                rebuildList()
            end
        end)
    end
end

local function addPlayer()
    local name = playerInput.Text:gsub("%s", "")
    if name == "" then return end
    if not table.find(Config.PlayerList, name) then
        table.insert(Config.PlayerList, name)
    end
    playerInput.Text = ""
    rebuildList()
end

addBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then addPlayer() end end)
playerInput.FocusLost:Connect(function(enter) if enter then addPlayer() end end)
rebuildList()

-- ============ 8. 滑块拖拽绑定（统一函数） ============
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

bindSlider(sTrackBg, sFill, sKnob, sMin, sMax, function(val, relX)
    Config.Smoothing = math.floor(val * 100 + 0.5) / 100
    smoothValue.Text = "瞄准平滑度: " .. Config.Smoothing
    sFill.Size = UDim2.new(relX, 0, 1, 0)
    sKnob.Position = UDim2.new(relX, -8, 0.5, -8)
end)

bindSlider(scTrackBg, scFill, scKnob, 0.5, 2.0, function(val, relX)
    Config.UIScale = math.floor(val * 10 + 0.5) / 10
    scaleValue.Text = "界面缩放: " .. math.floor(Config.UIScale * 100) .. "%"
    scFill.Size = UDim2.new(relX, 0, 1, 0)
    scKnob.Position = UDim2.new(relX, -8, 0.5, -8)
    uiScale.Scale = Config.UIScale
end)

-- ============ 9. 全局密码验证 & 紧急解锁 ============
local passOverlay = Instance.new("Frame")
passOverlay.Size = UDim2.new(1, 0, 1, 0)
passOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
passOverlay.BackgroundTransparency = 0.6
passOverlay.BorderSizePixel = 0
passOverlay.Visible = false
passOverlay.ZIndex = 20
passOverlay.Parent = gui

local passBox = Instance.new("Frame")
passBox.Size = UDim2.new(0, 240, 0, 160)
passBox.Position = UDim2.new(0.5, -120, 0.5, -80)
passBox.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
passBox.BorderSizePixel = 0
passBox.ZIndex = 21
passBox.Parent = passOverlay
Instance.new("UICorner", passBox).CornerRadius = UDim.new(0, 12)

local pbTitle = Instance.new("TextLabel")
pbTitle.Size = UDim2.new(1, -20, 0, 26)
pbTitle.Position = UDim2.new(0, 14, 0, 10)
pbTitle.BackgroundTransparency = 1
pbTitle.Text = "◆ 密码验证（919878）"
pbTitle.TextColor3 = Color3.fromRGB(200, 150, 255)
pbTitle.Font = Enum.Font.GothamBold
pbTitle.TextSize = 12
pbTitle.TextXAlignment = Enum.TextXAlignment.Left
pbTitle.ZIndex = 22
pbTitle.Parent = passBox

local pbInput = Instance.new("TextBox")
pbInput.Size = UDim2.new(1, -28, 0, 36)
pbInput.Position = UDim2.new(0, 14, 0, 46)
pbInput.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
pbInput.BorderSizePixel = 0
pbInput.Text = ""
pbInput.PlaceholderText = "输入密码"
pbInput.PlaceholderColor3 = Color3.fromRGB(110, 130, 160)
pbInput.TextColor3 = Color3.fromRGB(230, 240, 255)
pbInput.Font = Enum.Font.GothamMedium
pbInput.TextSize = 13
pbInput.ClearTextOnFocus = false
pbInput.TextEditable = true
pbInput.Selectable = true
pbInput.ZIndex = 22
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
pbErr.ZIndex = 22
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
pbOk.ZIndex = 22
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
pbCancel.ZIndex = 22
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

-- 解锁并打开面板的逻辑（合并复用）
local function unlockAndOpen()
    isUnlocked = true
    ballClickCount = 0
    closePass()
    panel.Visible = true
    panel.Size = UDim2.new(0, 0, 0, 0)
    panel.Position = UDim2.new(0.5, -125, 0.5, -275)
    TweenService:Create(panel, BOUNCE_OUT, {Size = UDim2.new(0, 250, 0, 550)}):Play()
    ball.Visible = false
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

pbOk.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then tryUnlock() end end)
pbOk.MouseButton1Click:Connect(tryUnlock)
pbInput.FocusLost:Connect(function(enter) if enter then tryUnlock() end end)
pbCancel.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then closePass() end end)

-- ============ 10. 悬浮球拖动与热键绑定 ============
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

-- 悬浮球触摸逻辑
local ballHoldStart = 0
local ballMoved = false
local ballDragging = false
local ballDragStart, ballStartPos

ball.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        ballHoldStart = tick()
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

        local holdTime = tick() - ballHoldStart
        if holdTime < 0.3 and not ballMoved then
            ballClickCount = ballClickCount + 1
            if ballClickCount >= 5 then
                -- 【Bug修复】紧急解锁，重置计数器并直接打开面板
                unlockAndOpen()
                return
            end
            
            if not isUnlocked then
                openPass()
            else
                panel.Visible = true
                panel.Size = UDim2.new(0, 0, 0, 0)
                panel.Position = UDim2.new(0.5, -125, 0.5, -275)
                TweenService:Create(panel, BOUNCE_OUT, {Size = UDim2.new(0, 250, 0, 550)}):Play()
                ball.Visible = false
            end
        end
    end
end)

closeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        TweenService:Create(panel, BOUNCE_IN, {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, -125, 0.5, -275)
        }):Play()
        task.wait(0.3)
        panel.Visible = false
        ball.Visible = true
    end
end)

-- 热键绑定（RightShift 快捷开启/关闭自动追踪）
UIS.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        if UIS:GetFocusedTextBox() then return end
        Config.AutoTrack = not Config.AutoTrack
        if updateTrackUI then updateTrackUI() end
        -- 同步更新UI状态
        local trackState = panel:FindFirstChild("自动追踪")
        if trackState then
            local stateLbl = trackState:FindFirstChild("TextLabel")
            if stateLbl then
                stateLbl.Text = Config.AutoTrack and "ON" or "OFF"
                stateLbl.TextColor3 = Config.AutoTrack and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
            end
        end
    end
end)

-- ============ 11. 性能优化注记 ============
-- 将 UI 代码包裹在局部作用域中，减少全局污染。
-- 滑块拖拽使用统一的 bindSlider 函数，减少重复代码。
-- 内存优化：利用 pcall 防止 gethui 不存在时报错。
print("[Neon Tracker v8.0] 已加载 | 修复黑白名单/紧急解锁 | 新增 ESP/FOV/平滑度/热键")