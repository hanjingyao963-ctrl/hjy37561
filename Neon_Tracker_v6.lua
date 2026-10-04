-- ================= Neon Tracker v6 (Void Protection & Neon UI) =================
-- 安全版：静默自瞄 | 无高危 Hook | 长按拖拽 | 视觉大头 | 穿墙防掉虚空 | 紫红霓虹UI
-- ==============================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============ 密码 ============
local _key = {57, 49, 57, 56, 55, 56}
local SECRET = ""
for _, n in ipairs(_key) do SECRET = SECRET .. string.char(n) end

-- ============ 全局配置 ============
local Config = {
    AutoTrack = false,
    TrackRadius = 200,
    AimPart = "Head",
    HitboxExpand = false,
    HitboxSize = 8,
    Noclip = false,          -- 穿墙
    VoidProtection = false,  -- 防掉虚空
    ListMode = "Blacklist",
    PlayerList = {},
    UIScale = 1,
}

-- ============ 追踪目标 ============
local currentTarget = nil
local originalHeadSizes = {}

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

-- ============ 核心：静默自瞄 ============
RunService.RenderStepped:Connect(function(deltaTime)
    if Config.AutoTrack then
        currentTarget = getClosestTarget()
    else
        currentTarget = nil
    end

    if not currentTarget then return end
    if UIS.TouchEnabled and #UIS:GetTouches() > 0 then return end

    local aimPart = currentTarget:FindFirstChild(Config.AimPart)
    if not aimPart then aimPart = currentTarget:FindFirstChild("HumanoidRootPart") end
    if not aimPart then return end

    local currentCFrame = Camera.CFrame
    local targetPos = aimPart.Position
    local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + (targetPos - currentCFrame.Position).Unit)
    
    Camera.CFrame = currentCFrame:Lerp(newCFrame, 0.6)
end)

-- ============ 核心：大头视觉 + 判定放大 ============
RunService.Heartbeat:Connect(function()
    if not Config.HitboxExpand then
        for head, data in pairs(originalHeadSizes) do
            if head and head.Parent then
                head.Size = data.size
                head.Transparency = data.transparency
            end
        end
        originalHeadSizes = {}
        return
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                if not originalHeadSizes[head] then
                    originalHeadSizes[head] = { size = head.Size, transparency = head.Transparency }
                end
                head.Size = Vector3.new(Config.HitboxSize, Config.HitboxSize, Config.HitboxSize)
                head.Transparency = originalHeadSizes[head].transparency
                head.CanCollide = false
                head.CanQuery = true
            end
        end
    end
end)

-- ============ 核心：穿墙 & 防掉虚空 ============
RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 1. 穿墙（Noclip）逻辑
    if Config.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.CanCollide = false
            end
        end
    end

    -- 2. 防掉虚空（Void Protection）
    if Config.VoidProtection and hrp.Position.Y < -50 then
        -- 瞬间拉回安全高度，避免掉入虚空
        hrp.CFrame = CFrame.new(hrp.Position.X, 50, hrp.Position.Z)
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end
    end
end)

-- ============ 安全关闭穿墙（防止卡墙） ============
local function safeDisableNoclip()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 把角色稍微往上挪一点，防止在墙里恢复碰撞被卡住
    hrp.CFrame = hrp.CFrame + Vector3.new(0, 3, 0)
    
    -- 恢复所有部件的碰撞
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
end

-- ====================================================
-- ============== UI 部分（紫红霓虹风） ================
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

-- ========== 悬浮球 ==========
local ball = Instance.new("TextButton")
ball.Size = UDim2.new(0, 60, 0, 60)
ball.Position = UDim2.new(0, 50, 0, 250)
ball.BackgroundColor3 = Color3.fromRGB(10, 8, 16) -- 紫黑
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
ballGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 255)), -- 紫色
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128)), -- 品红
})
ballGrad.Parent = ballStroke

local ballIcon = Instance.new("TextLabel")
ballIcon.Size = UDim2.new(1, 0, 1, 0)
ballIcon.BackgroundTransparency = 1
ballIcon.Text = "◎"
ballIcon.TextColor3 = Color3.fromRGB(200, 150, 255) -- 亮紫
ballIcon.Font = Enum.Font.GothamBold
ballIcon.TextSize = 30
ballIcon.Parent = ball

-- ========== 主面板 ==========
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 250, 0, 530)
panel.Position = UDim2.new(0, 150, 0, 120)
panel.BackgroundColor3 = Color3.fromRGB(10, 8, 16) -- 紫黑
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
psGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 0, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 128)),
})
psGrad.Parent = panelStroke

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 2)
topBar.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
topBar.BorderSizePixel = 0
topBar.Parent = panel
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 12)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundTransparency = 1
titleBar.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TRACKER v6 (Neon)"
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

-- 1. 自动追踪
local masterRow = Instance.new("TextButton")
masterRow.Size = UDim2.new(1, -20, 0, 45)
masterRow.Position = UDim2.new(0, 10, 0, 40)
masterRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40) -- 深紫
masterRow.Text = ""
masterRow.AutoButtonColor = false
masterRow.BorderSizePixel = 0
masterRow.Parent = panel
Instance.new("UICorner", masterRow).CornerRadius = UDim.new(0, 10)

local mrStroke = Instance.new("UIStroke")
mrStroke.Color = Color3.fromRGB(180, 0, 255)
mrStroke.Thickness = 1
mrStroke.Transparency = 0.6
mrStroke.Parent = masterRow

local mrLabel = Instance.new("TextLabel")
mrLabel.Size = UDim2.new(1, -100, 1, 0)
mrLabel.Position = UDim2.new(0, 12, 0, 0)
mrLabel.BackgroundTransparency = 1
mrLabel.Text = "自动追踪"
mrLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
mrLabel.Font = Enum.Font.GothamBold
mrLabel.TextSize = 13
mrLabel.TextXAlignment = Enum.TextXAlignment.Left
mrLabel.Parent = masterRow

local swTrack = Instance.new("Frame")
swTrack.Size = UDim2.new(0, 42, 0, 22)
swTrack.Position = UDim2.new(1, -54, 0.5, -11)
swTrack.BackgroundColor3 = Color3.fromRGB(60, 70, 90)
swTrack.BorderSizePixel = 0
swTrack.Parent = masterRow
Instance.new("UICorner", swTrack).CornerRadius = UDim.new(1, 0)

local swKnob = Instance.new("Frame")
swKnob.Size = UDim2.new(0, 18, 0, 18)
swKnob.Position = UDim2.new(0, 2, 0.5, -9)
swKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
swKnob.BorderSizePixel = 0
swKnob.Parent = swTrack
Instance.new("UICorner", swKnob).CornerRadius = UDim.new(1, 0)

local function updateSwitch(anim)
    local on = Config.AutoTrack
    local info = anim and TweenInfo.new(0.2) or TweenInfo.new(0)
    TweenService:Create(swTrack, info, {BackgroundColor3 = on and Color3.fromRGB(0, 180, 110) or Color3.fromRGB(60, 70, 90)}):Play()
    TweenService:Create(swKnob, info, {Position = on and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
end
updateSwitch(false)

-- 2. 瞄准部位
local aimRow = Instance.new("Frame")
aimRow.Size = UDim2.new(1, -20, 0, 35)
aimRow.Position = UDim2.new(0, 10, 0, 92)
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
    TweenService:Create(headBtn, TweenInfo.new(0.15), {BackgroundColor3 = isHead and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
    TweenService:Create(bodyBtn, TweenInfo.new(0.15), {BackgroundColor3 = (not isHead) and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
end
updateAimUI()

-- 3. 大头模式
local hitboxRow = Instance.new("TextButton")
hitboxRow.Size = UDim2.new(1, -20, 0, 35)
hitboxRow.Position = UDim2.new(0, 10, 0, 132)
hitboxRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
hitboxRow.Text = ""
hitboxRow.AutoButtonColor = false
hitboxRow.BorderSizePixel = 0
hitboxRow.Parent = panel
Instance.new("UICorner", hitboxRow).CornerRadius = UDim.new(0, 10)

local hbLabel = Instance.new("TextLabel")
hbLabel.Size = UDim2.new(1, -100, 1, 0)
hbLabel.Position = UDim2.new(0, 12, 0, 0)
hbLabel.BackgroundTransparency = 1
hbLabel.Text = "大头模式"
hbLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
hbLabel.Font = Enum.Font.GothamBold
hbLabel.TextSize = 12
hbLabel.TextXAlignment = Enum.TextXAlignment.Left
hbLabel.Parent = hitboxRow

local hbStatus = Instance.new("TextLabel")
hbStatus.Size = UDim2.new(0, 40, 1, 0)
hbStatus.Position = UDim2.new(1, -50, 0, 0)
hbStatus.BackgroundTransparency = 1
hbStatus.Text = "OFF"
hbStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
hbStatus.Font = Enum.Font.GothamBold
hbStatus.TextSize = 12
hbStatus.TextXAlignment = Enum.TextXAlignment.Right
hbStatus.Parent = hitboxRow

local function updateHitboxUI()
    hbStatus.Text = Config.HitboxExpand and "ON" or "OFF"
    hbStatus.TextColor3 = Config.HitboxExpand and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
end
updateHitboxUI()

-- 4. 穿墙
local noclipRow = Instance.new("TextButton")
noclipRow.Size = UDim2.new(1, -20, 0, 35)
noclipRow.Position = UDim2.new(0, 10, 0, 172)
noclipRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
noclipRow.Text = ""
noclipRow.AutoButtonColor = false
noclipRow.BorderSizePixel = 0
noclipRow.Parent = panel
Instance.new("UICorner", noclipRow).CornerRadius = UDim.new(0, 10)

local ncLabel = Instance.new("TextLabel")
ncLabel.Size = UDim2.new(1, -100, 1, 0)
ncLabel.Position = UDim2.new(0, 12, 0, 0)
ncLabel.BackgroundTransparency = 1
ncLabel.Text = "穿墙模式"
ncLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
ncLabel.Font = Enum.Font.GothamBold
ncLabel.TextSize = 12
ncLabel.TextXAlignment = Enum.TextXAlignment.Left
ncLabel.Parent = noclipRow

local ncStatus = Instance.new("TextLabel")
ncStatus.Size = UDim2.new(0, 40, 1, 0)
ncStatus.Position = UDim2.new(1, -50, 0, 0)
ncStatus.BackgroundTransparency = 1
ncStatus.Text = "OFF"
ncStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
ncStatus.Font = Enum.Font.GothamBold
ncStatus.TextSize = 12
ncStatus.TextXAlignment = Enum.TextXAlignment.Right
ncStatus.Parent = noclipRow

local function updateNoclipUI()
    ncStatus.Text = Config.Noclip and "ON" or "OFF"
    ncStatus.TextColor3 = Config.Noclip and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
end
updateNoclipUI()

-- 5. 防掉虚空
local voidRow = Instance.new("TextButton")
voidRow.Size = UDim2.new(1, -20, 0, 35)
voidRow.Position = UDim2.new(0, 10, 0, 212)
voidRow.BackgroundColor3 = Color3.fromRGB(25, 18, 40)
voidRow.Text = ""
voidRow.AutoButtonColor = false
voidRow.BorderSizePixel = 0
voidRow.Parent = panel
Instance.new("UICorner", voidRow).CornerRadius = UDim.new(0, 10)

local vdLabel = Instance.new("TextLabel")
vdLabel.Size = UDim2.new(1, -100, 1, 0)
vdLabel.Position = UDim2.new(0, 12, 0, 0)
vdLabel.BackgroundTransparency = 1
vdLabel.Text = "防掉虚空"
vdLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
vdLabel.Font = Enum.Font.GothamBold
vdLabel.TextSize = 12
vdLabel.TextXAlignment = Enum.TextXAlignment.Left
vdLabel.Parent = voidRow

local vdStatus = Instance.new("TextLabel")
vdStatus.Size = UDim2.new(0, 40, 1, 0)
vdStatus.Position = UDim2.new(1, -50, 0, 0)
vdStatus.BackgroundTransparency = 1
vdStatus.Text = "OFF"
vdStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
vdStatus.Font = Enum.Font.GothamBold
vdStatus.TextSize = 12
vdStatus.TextXAlignment = Enum.TextXAlignment.Right
vdStatus.Parent = voidRow

local function updateVoidUI()
    vdStatus.Text = Config.VoidProtection and "ON" or "OFF"
    vdStatus.TextColor3 = Config.VoidProtection and Color3.fromRGB(0, 255, 130) or Color3.fromRGB(255, 80, 80)
end
updateVoidUI()

-- 追踪半径滑块
local radiusRow = Instance.new("Frame")
radiusRow.Size = UDim2.new(1, -20, 0, 48)
radiusRow.Position = UDim2.new(0, 10, 0, 252)
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

-- 界面缩放
local scaleRow = Instance.new("Frame")
scaleRow.Size = UDim2.new(1, -20, 0, 48)
scaleRow.Position = UDim2.new(0, 10, 0, 305)
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

local sTrackBg = Instance.new("Frame")
sTrackBg.Size = UDim2.new(1, -24, 0, 6)
sTrackBg.Position = UDim2.new(0, 12, 1, -14)
sTrackBg.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
sTrackBg.BorderSizePixel = 0
sTrackBg.Parent = scaleRow
Instance.new("UICorner", sTrackBg).CornerRadius = UDim.new(1, 0)

local sFill = Instance.new("Frame")
sFill.Size = UDim2.new((Config.UIScale - 0.5) / 1.5, 0, 1, 0)
sFill.BackgroundColor3 = Color3.fromRGB(180, 0, 255)
sFill.BorderSizePixel = 0
sFill.Parent = sTrackBg
Instance.new("UICorner", sFill).CornerRadius = UDim.new(1, 0)

local sKnob = Instance.new("Frame")
sKnob.Size = UDim2.new(0, 12, 0, 12)
sKnob.Position = UDim2.new((Config.UIScale - 0.5) / 1.5, -6, 0.5, -6)
sKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
sKnob.BorderSizePixel = 0
sKnob.ZIndex = 2
sKnob.Parent = sTrackBg
Instance.new("UICorner", sKnob).CornerRadius = UDim.new(1, 0)

-- 名单模式
local listHeader = Instance.new("Frame")
listHeader.Size = UDim2.new(1, -20, 0, 26)
listHeader.Position = UDim2.new(0, 10, 0, 358)
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
    TweenService:Create(wlBtn, TweenInfo.new(0.15), {BackgroundColor3 = isWL and Color3.fromRGB(180, 0, 255) or Color3.fromRGB(40, 46, 62)}):Play()
    TweenService:Create(blBtn, TweenInfo.new(0.15), {BackgroundColor3 = (not isWL) and Color3.fromRGB(255, 0, 128) or Color3.fromRGB(40, 46, 62)}):Play()
end
updateModeUI()

-- 输入框
local inputRow = Instance.new("Frame")
inputRow.Size = UDim2.new(1, -20, 0, 28)
inputRow.Position = UDim2.new(0, 10, 0, 390)
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

-- 名单列表
local listScroll = Instance.new("ScrollingFrame")
listScroll.Size = UDim2.new(1, -20, 0, 80)
listScroll.Position = UDim2.new(0, 10, 0, 425)
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
    local name = playerInput.Text
    if name == "" then return end
    if table.find(Config.PlayerList, name) then
        playerInput.Text = ""
        return
    end
    table.insert(Config.PlayerList, name)
    playerInput.Text = ""
    rebuildList()
end

addBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        addPlayer()
    end
end)
playerInput.FocusLost:Connect(function(enter)
    if enter then addPlayer() end
end)
rebuildList()

-- ========== 密码弹窗 ==========
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
pbTitle.Text = "◆ 需要密码验证"
pbTitle.TextColor3 = Color3.fromRGB(200, 150, 255)
pbTitle.Font = Enum.Font.GothamBold
pbTitle.TextSize = 13
pbTitle.TextXAlignment = Enum.TextXAlignment.Left
pbTitle.ZIndex = 22
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
    task.wait(0.1)
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

local function tryUnlock()
    if pbInput.Text == SECRET then
        Config.AutoTrack = true
        updateSwitch(true)
        closePass()
    else
        pbErr.Text = "密码错误"
        pbInput.Text = ""
        shake(passBox)
    end
end

pbOk.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        tryUnlock()
    end
end)
pbInput.FocusLost:Connect(function(enter)
    if enter then tryUnlock() end
end)
pbCancel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        closePass()
    end
end)

-- ========== 移动端触摸绑定（长按/轻点区分） ==========
local function makeDraggable(frame, dragHandle)
    local dragging, dragInput, dragStart, startPos

    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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

local getPanelMoved = makeDraggable(panel, titleBar)

-- 悬浮球：长按拖动 + 轻点打开
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
        TweenService:Create(ball, TweenInfo.new(0.1), {Size = UDim2.new(0, 50, 0, 50)}):Play()
    end
end)

UIS.InputChanged:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - ballDragStart
        if math.abs(delta.X) > 5 or math.abs(delta.Y) > 5 then
            ballMoved = true
        end
        if ballMoved then
            ball.Position = UDim2.new(ballStartPos.X.Scale, ballStartPos.X.Offset + delta.X, ballStartPos.Y.Scale, ballStartPos.Y.Offset + delta.Y)
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    if ballDragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        ballDragging = false
        TweenService:Create(ball, TweenInfo.new(0.1), {Size = UDim2.new(0, 60, 0, 60)}):Play()

        local holdTime = tick() - ballHoldStart
        if holdTime < 0.3 and not ballMoved then
            panel.Visible = true
            panel.Size = UDim2.new(0, 0, 0, 0)
            panel.Position = UDim2.new(0.5, -125, 0.5, -265)
            TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 250, 0, 530)
            }):Play()
            ball.Visible = false
        end
    end
end)

-- 关闭面板
closeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 0, 0, 0),
            Position = UDim2.new(0.5, -125, 0.5, -265)
        }):Play()
        task.wait(0.2)
        panel.Visible = false
        ball.Visible = true
    end
end)

-- 开关绑定
masterRow.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if Config.AutoTrack then
            Config.AutoTrack = false
            updateSwitch(true)
        else
            openPass()
        end
    end
end)

hitboxRow.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.HitboxExpand = not Config.HitboxExpand
        updateHitboxUI()
    end
end)

noclipRow.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.Noclip = not Config.Noclip
        updateNoclipUI()
        if not Config.Noclip then
            safeDisableNoclip()
        end
    end
end)

voidRow.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.VoidProtection = not Config.VoidProtection
        updateVoidUI()
    end
end)

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

wlBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.ListMode = "Whitelist"
        updateModeUI()
    end
end)

blBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Config.ListMode = "Blacklist"
        updateModeUI()
    end
end)

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
        end
    end)

    UIS.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = false
        end
    end)
end

bindSlider(trackBg, fill, knob, R_MIN, R_MAX, function(val, relX)
    val = math.floor(val / 10 + 0.5) * 10
    Config.TrackRadius = val
    radiusValue.Text = "追踪半径: " .. val .. " 格"
    fill.Size = UDim2.new(relX, 0, 1, 0)
    knob.Position = UDim2.new(relX, -6, 0.5, -6)
end)

bindSlider(sTrackBg, sFill, sKnob, 0.5, 2.0, function(val, relX)
    Config.UIScale = math.floor(val * 10 + 0.5) / 10
    scaleValue.Text = "界面缩放: " .. math.floor(Config.UIScale * 100) .. "%"
    sFill.Size = UDim2.new(relX, 0, 1, 0)
    sKnob.Position = UDim2.new(relX, -6, 0.5, -6)
    uiScale.Scale = Config.UIScale
end)

print("[Neon Tracker v6 - Neon] 已加载 | 穿墙防掉 | 紫红霓虹UI | 安全版")