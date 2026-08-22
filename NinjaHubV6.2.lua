-- ============================================
-- Ninja Hub V6.2 - 自动化脚本增强版
-- ============================================
-- 新增(V6.2):
--  1. 连点器: 修复小球只开一个的问题, 多球模式可调节小球数量
--  2. 点击脚本: 自动化点击面板(坐标点击修正偏移, 顺序/延迟/独立延迟/执行次数)
--  3. 客户端脚本: 录制客户端活动并回放(走动/互动/切换道具, 变化才记录, 详细日志)
--  4. 远程互动: 一键互动所有ProximityPrompt(渐变圆角轮廓按钮)
--  5. 悬浮球面板化 + 预生成面板, 左右淡入淡出
--  6. 音乐API换成国际可用Deezer API
--  7. 数据/信息文本刷新动画(向上淡出/向下淡入)
-- ============================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local Stats = game:GetService("Stats")
local CoreGui = game:GetService("CoreGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

local LoadStartTime = tick()

local MAX_RENDER_DIST = 300

-- 角色引用
local character, humanoid, hrp
local function refreshCharacter()
	character = player.Character
	if character then
		humanoid = character:FindFirstChildOfClass("Humanoid")
		hrp = character:FindFirstChild("HumanoidRootPart")
	end
end
refreshCharacter()
player.CharacterAdded:Connect(function(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	hrp = char:WaitForChild("HumanoidRootPart")
	task.delay(0.5, applyActiveStates)
end)

-- ============================================
-- 高饱和配色方案
-- ============================================
local C = {
	Btn = Color3.fromRGB(88, 60, 160),
	BtnDark = Color3.fromRGB(64, 44, 120),
	Val = Color3.fromRGB(52, 36, 104),
	Row = Color3.fromRGB(46, 32, 96),
	RowBg = Color3.fromRGB(30, 20, 66),
	Drop = Color3.fromRGB(62, 42, 128),
	ToggleOff = Color3.fromRGB(96, 72, 170),
	ToggleOn = Color3.fromRGB(0, 210, 110),
	CardInner = Color3.fromRGB(26, 18, 62),
	LeftBar = Color3.fromRGB(22, 16, 56),
	PanelGradA = Color3.fromRGB(24, 14, 56),
	PanelGradB = Color3.fromRGB(38, 22, 84),
	Text = Color3.fromRGB(238, 238, 255),
	TextSub = Color3.fromRGB(190, 195, 245),
	Accent = Color3.fromRGB(120, 180, 255),
}
local function createGrayStroke(parent, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(185, 185, 225)
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

local PartColorOffsets = {}
local function getRainbowColor(offset, speed)
	speed = speed or 0.5
	local t = tick() * speed + (offset or 0)
	return Color3.fromHSV(t % 1, 1, 1)
end
local function getPartColor(key)
	if type(key) ~= "string" then key = tostring(key) end
	local off = PartColorOffsets[key]
	if not off then
		off = math.random() * 100
		PartColorOffsets[key] = off
	end
	return getRainbowColor(off, 0.05)
end

-- ============================================
-- 状态管理
-- ============================================
local States = {
	DynamicIsland = {Enabled = true},
	FloatBallPos = {0.5, -19, 0, 110},
	MusicPlayer = {Enabled = false, Favorites = {}},
	WalkSpeed = {Enabled = false, Value = 100, Default = 16},
	TpWalk = {Enabled = false, Value = 2},
	Fly1 = {Enabled = false, Value = 45},
	Fly2 = {Enabled = false, Value = 50, Flying = false},
	FreeMove = {Enabled = false, Value = 50},
	Noclip = {Enabled = false},
	BunnyHop = {Enabled = false, Value = 5},
	JumpHeight = {Enabled = false, Value = 100, Default = 7.2},
	AutoRun = {Enabled = false},
	SuperJump = {Enabled = false, Value = 200},
	WallClimb = {Enabled = false, Value = 50},
	GodMode = {Enabled = false},
	NoCooldown = {Enabled = false},
	InfiniteAmmo = {Enabled = false},
	AutoAttack = {Enabled = false},
	KillAura = {Enabled = false, Value = 20},
	Aimbot = {Enabled = false},
	RapidFire = {Enabled = false},
	NightVision = {Enabled = false},
	FullBright = {Enabled = false},
	ESP = {Enabled = false},
	Xray = {Enabled = false},
	NoFog = {Enabled = false},
	ColorFilter = {Enabled = false, Value = "Pink"},
	FreeCam = {Enabled = false},
	ThermalESP = {Enabled = false},
	AutoClicker = {Enabled = false, Value = 10},
	ClickerStart = {Enabled = false},
	ClickerMulti = {Enabled = false, ClickerCount = 2},
	FastInteract = {Enabled = false},
	AntiAfk = {Enabled = false},
	AutoSave = {Enabled = false},
	ShowFps = {Enabled = false},
	ShowCoords = {Enabled = false},
	GravityMod = {Enabled = false, Value = 50, Default = 196.2},
	TimeOfDay = {Enabled = false, Value = 12},
	SitAnywhere = {Enabled = false},
	GameInfo = {Enabled = false},
	DangerWarning = {Enabled = false, Value = 50},
	RemoteInteract = {Enabled = true},
	ClickScript = {Enabled = false},
	ClientScript = {Enabled = false},
	NpcDisplay = {Enabled = false, ShowHead = true, ShowTorso = true, ShowLimbs = true, ShowBones = true},
	PlayerDisplay = {Enabled = false, ShowHead = true, ShowTorso = true, ShowLimbs = true, ShowBones = true, ShowName = true, ShowDistance = true, ShowHealth = true},
	BoxCreature = {Enabled = false, BoxNpc = true, BoxPlayer = true, BoxOther = true, BoxAliveOnly = false, BoxMode = "3D", ShowHitbox = false, MaxDistance = 0},
	LineConnect = {Enabled = false, ConnectNpc = false, ConnectPlayer = true, ConnectOther = false, LineWallCheck = false, Origin = "Top", MaxDistance = 0},
	AimbotV2 = {Enabled = false, AimPlayer = true, AimNpc = false, AimOther = false, AimPart = "Head", CircleSize = 150, AimSpeed = 0.3, WallCheck = false, TeamCheck = false, AliveCheck = true, Smooth = true, Predict = false, CustomTarget = nil, MaxDistance = 0},
	AutoFire = {Enabled = false},
	AdvancedESP = {
		Enabled = false, ShowBox = true, BoxStyle = "Corner", BoxThickness = 1,
		ShowName = true, ShowHealth = true, ShowDistance = true, HealthStyle = "Bar",
		ShowChams = true, TeamCheck = false, ShowTeam = false, WallCheck = false,
		Tracer = false, TracerOrigin = "Bottom", Skeleton = false, MaxDistance = 300,
	},
}

local Conns = {}
local function bind(name, conn)
	if Conns[name] then Conns[name]:Disconnect() end
	Conns[name] = conn
end
local function unbind(name)
	if Conns[name] then
		if typeof(Conns[name]) == "RBXScriptConnection" then
			Conns[name]:Disconnect()
		end
		Conns[name] = nil
	end
end

local ClickerThread, ClickerCondThread, AntiAfkThread, AutoSaveThread

local ToggleRefreshers = {}
local ShortcutButtons = {}
local RowScBtns = {}
local Updaters = {}

local MoveStateNames = {"Climbing","FallingDown","Flying","Freefall","GettingUp","Jumping","Landed","Physics","PlatformStanding","Ragdoll","Running","RunningNoPhysics","Seated","StrafingNoPhysics","Swimming"}
local function disableMovementStates(hum)
	if not hum then return end
	for _, s in ipairs(MoveStateNames) do
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType[s], false) end)
	end
end
local function enableMovementStates(hum)
	if not hum then return end
	for _, s in ipairs(MoveStateNames) do
		pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType[s], true) end)
	end
end

-- 目标缓存
local TargetCache = {Players = {}, Npcs = {}, Others = {}, All = {}}
local LastNpcScan = 0
local function updateTargetCache()
	TargetCache.Players = {}
	TargetCache.All = {}
	for _, p in pairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			local hum = p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local hrp2 = p.Character:FindFirstChild("HumanoidRootPart") or p.Character:FindFirstChild("Torso")
				local e = {Obj = p.Character, Hum = hum, Hrp = hrp2, IsPlayer = true, Plr = p}
				table.insert(TargetCache.Players, e)
				table.insert(TargetCache.All, e)
			end
		end
	end
	local now = tick()
	if now - LastNpcScan >= 0.5 then
		LastNpcScan = now
		TargetCache.Npcs = {}
		TargetCache.Others = {}
		for _, m in pairs(Workspace:GetDescendants()) do
			if m:IsA("Model") and m ~= character and not Players:GetPlayerFromCharacter(m) then
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					local hrp2 = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Torso")
					local e = {Obj = m, Hum = hum, Hrp = hrp2, IsPlayer = false}
					table.insert(TargetCache.Npcs, e)
					table.insert(TargetCache.All, e)
				else
					if m:FindFirstChild("Head") or m.PrimaryPart then
						table.insert(TargetCache.Others, m)
					end
				end
			end
		end
	end
end

local function inRenderRange(partPos)
	if not hrp or not partPos then return false end
	return (hrp.Position - partPos).Magnitude <= MAX_RENDER_DIST
end

-- ============================================
-- GUI 基础
-- ============================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "NinjaHubV62"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 10000
local GuiParent = playerGui
pcall(function()
	if CoreGui then GuiParent = CoreGui end
end)
ScreenGui.Parent = GuiParent

local TweenFast = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TweenBounce = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenSmooth = TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local TweenPanelOpen = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenPanelClose = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TweenScalePop = TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local TweenSlide = TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local function tween(obj, props, info)
	if not obj or not obj.Parent then return nil end
	local ok, tw = pcall(function()
		return TweenService:Create(obj, info or TweenSmooth, props)
	end)
	if ok and tw then
		local ok2 = pcall(function() tw:Play() end)
		if ok2 then return tw end
	end
	return nil
end

local Gui = {}

-- ============================================
-- V6.2: 数据刷新动画工具
-- 新数据从下往上淡入淡出, 旧数据向上滑出淡出
-- ============================================
local function animateSwap(label, newText, fromBelow)
	if not label then return end
	fromBelow = (fromBelow == nil) and true or fromBelow
	local infoOut = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local infoIn = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if label.Text == newText then return end
	local xScale = label.Position.X.Scale
	local anim = function()
		if not label or not label.Parent then return end
		local pos = label.Position
		local dir = fromBelow and 18 or -18
		local oldT = TweenService:Create(label, infoOut, {TextTransparency = 1, Position = UDim2.new(xScale, pos.X.Offset, 0, -dir)})
		local done = false
		oldT.Completed:Connect(function() done = true end)
		oldT:Play()
		task.wait(0.2)
		if not label or not label.Parent then return end
		label.Text = newText
		label.Position = UDim2.new(xScale, label.Position.X.Offset, 0, dir)
		local newT = TweenService:Create(label, infoIn, {TextTransparency = label.TextTransparency, Position = UDim2.new(xScale, label.Position.X.Offset, 0, 0)})
		-- 从下往上淡入
		newT:Play()
	end
	task.spawn(anim)
end

-- ============================================
-- 加载弹窗
-- ============================================
local LoadingFrame
local LoadingText
do
	local outer = Instance.new("Frame")
	outer.Size = UDim2.new(0, 320, 0, 78)
	outer.Position = UDim2.new(0.5, -160, 0.5, -39)
	outer.AnchorPoint = Vector2.new(0.5, 0.5)
	outer.BackgroundTransparency = 0
	outer.BorderSizePixel = 0
	outer.ZIndex = 9900
	outer.Parent = ScreenGui
	local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0, 20); oc.Parent = outer
	local og = Instance.new("UIGradient")
	og.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(0.25, Color3.fromHSV(0.25, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
		ColorSequenceKeypoint.new(0.75, Color3.fromHSV(0.75, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	})
	og.Rotation = 45
	og.Parent = outer

	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -5, 1, -5)
	inner.Position = UDim2.new(0, 2.5, 0, 2.5)
	inner.BackgroundColor3 = Color3.fromRGB(10, 8, 22)
	inner.BackgroundTransparency = 0.1
	inner.BorderSizePixel = 0
	inner.Parent = outer
	local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, 17); ic.Parent = inner

	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.new(1, 0, 0, 26)
	t1.Position = UDim2.new(0, 0, 0, 9)
	t1.BackgroundTransparency = 1
	t1.Text = "⚡ Ninja Hub V6.2"
	t1.TextColor3 = Color3.fromRGB(255, 255, 255)
	t1.TextSize = 16
	t1.Font = Enum.Font.GothamBold
	t1.Parent = inner

	LoadingText = Instance.new("TextLabel")
	LoadingText.Size = UDim2.new(1, 0, 0, 22)
	LoadingText.Position = UDim2.new(0, 0, 0, 38)
	LoadingText.BackgroundTransparency = 1
	LoadingText.Text = "开始加载脚本..."
	LoadingText.TextColor3 = Color3.fromRGB(150, 200, 255)
	LoadingText.TextSize = 12
	LoadingText.Font = Enum.Font.Gotham
	LoadingText.Parent = inner

	task.spawn(function()
		local rot = 45
		while outer and outer.Parent do
			rot = rot + 1.2
			og.Rotation = rot
			task.wait(0.05)
		end
	end)
	task.spawn(function()
		local dots = 0
		while outer and outer.Parent and LoadingText do
			dots = dots + 1
			LoadingText.Text = "开始加载脚本" .. string.rep(".", (dots % 3) + 1)
			task.wait(0.12)
		end
	end)
	local ls = Instance.new("UIScale"); ls.Scale = 0.6; ls.Parent = outer
	tween(ls, {Scale = 1}, TweenScalePop)
	LoadingFrame = outer
end

local function raiseZIndex(root, minZ)
	if not root then return end
	local base = minZ or (root.ZIndex + 1)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") and d.ZIndex < base then
			d.ZIndex = base
		end
	end
end

local function setFeatureState(key, enabled)
	local state = States[key]
	if not state then return end
	state.Enabled = enabled
	if ToggleRefreshers[key] then pcall(ToggleRefreshers[key], enabled) end
	local sc = RowScBtns[key]
	if sc then
		tween(sc, {BackgroundColor3 = enabled and Color3.fromRGB(0,150,80) or C.BtnDark}, TweenFast)
	end
	local fb = ShortcutButtons[key]
	if fb then
		fb.BackgroundColor3 = enabled and Color3.fromRGB(0,150,80) or Color3.fromRGB(60, 44, 120)
	end
	local updater = Updaters[key]
	if updater then pcall(updater) end
end

local function createButton(parent, name, size, pos, color, text)
	local btn = Instance.new("TextButton")
	btn.Name = name; btn.Size = size; btn.Position = pos
	btn.BackgroundColor3 = color or C.Btn
	btn.Text = text or ""; btn.TextColor3 = Color3.fromRGB(255,255,255)
	btn.TextSize = 14; btn.Font = Enum.Font.GothamSemibold
	btn.AutoButtonColor = true; btn.Parent = parent
	local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = btn
	return btn
end

local function createCheckbox(parent, text, defaultValue, callback, compact)
	local frame = Instance.new("Frame")
	if compact then
		frame.Size = UDim2.new(0.485, 0, 0, 24)
	else
		frame.Size = UDim2.new(1, 0, 0, 24)
	end
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	local box = Instance.new("Frame")
	box.Size = UDim2.new(0,20,0,20); box.Position = UDim2.new(0,0,0.5,-10)
	box.BackgroundColor3 = defaultValue and Color3.fromRGB(0,210,110) or Color3.fromRGB(96,72,170)
	box.BorderSizePixel = 0
	box.Parent = frame
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0,6); bc.Parent = box
	createGrayStroke(box, 1.5)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1,-30,1,0); label.Position = UDim2.new(0,26,0,0)
	label.BackgroundTransparency = 1; label.Text = text
	label.TextColor3 = Color3.fromRGB(230,230,255); label.TextSize = 12
	label.Font = Enum.Font.Gotham; label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame

	local checked = defaultValue
	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Parent = box
	local lastPress = 0
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPress = tick()
		end
	end)
	hit.MouseButton1Click:Connect(function()
		if tick() - lastPress < 0.4 then
			checked = not checked
			tween(box, {BackgroundColor3 = checked and Color3.fromRGB(0,210,110) or Color3.fromRGB(96,72,170)}, TweenFast)
			if callback then callback(checked) end
		end
	end)
	return frame, function() return checked end
end

local function addCheckboxes(parent, specs)
	local row
	for i, spec in ipairs(specs) do
		local idx = (i - 1) % 2
		if idx == 0 then
			row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundTransparency = 1
			row.Parent = parent
		end
		local text, default, cb = table.unpack(spec)
		local frame = createCheckbox(row, text, default, cb, true)
		if idx == 1 then
			frame.Position = UDim2.new(0.515, 0, 0, 0)
		end
	end
end

local function createBtnRow(parent, height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,height or 26)
	row.BackgroundTransparency = 1
	row.Parent = parent
	return row
end

local function createDropdown(parent, title, defaultOpen, leftPadding, onHeightChange, width)
	local W = width or 336
	local container = Instance.new("Frame")
	container.Size = UDim2.new(0, W, 0, 34)
	container.BackgroundColor3 = Color3.fromRGB(62,42,128)
	container.BackgroundTransparency = 0.1
	container.BorderSizePixel = 0
	container.Parent = parent
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0,12); cc.Parent = container
	createGrayStroke(container, 1.5)

	local header = Instance.new("TextButton")
	header.Size = UDim2.new(1, 0, 0, 34)
	header.BackgroundTransparency = 1
	header.Text = ""
	header.AutoButtonColor = false
	header.Parent = container

	local headerText = Instance.new("TextLabel")
	headerText.Size = UDim2.new(1,-16,1,0)
	headerText.Position = UDim2.new(0,10,0,0)
	headerText.BackgroundTransparency = 1
	headerText.Text = "▼ " .. title
	headerText.TextColor3 = Color3.fromRGB(255,255,255)
	headerText.TextSize = 13
	headerText.Font = Enum.Font.GothamBold
	headerText.TextXAlignment = Enum.TextXAlignment.Left
	headerText.Parent = header

	local content = Instance.new("Frame")
	content.Size = UDim2.new(0, W - 48, 0, 0)
	content.Position = UDim2.new(0,42,0,34)
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true
	content.Parent = container

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0,4); list.Parent = content

	local open = defaultOpen or false
	local lastPress = 0
	local function update()
		if not container.Parent then return end
		if open then
			headerText.Text = "▼ " .. title
			local h = list.AbsoluteContentSize.Y + 8
			tween(container, {Size = UDim2.new(0, W, 0, 34+h)}, TweenFast)
			tween(content, {Size = UDim2.new(0, W - 48, 0, h)}, TweenFast)
			if onHeightChange then onHeightChange(34 + h) end
		else
			headerText.Text = "▶ " .. title
			tween(container, {Size = UDim2.new(0, W, 0, 34)}, TweenFast)
			tween(content, {Size = UDim2.new(0, W - 48, 0, 0)}, TweenFast)
			if onHeightChange then onHeightChange(34) end
		end
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPress = tick()
		end
	end)
	header.MouseButton1Click:Connect(function()
		if tick() - lastPress < 0.4 then
			open = not open
			update()
		end
	end)

	return content, function() return open end, function(v) open = v; update() end
end

local function createToggle(parent, stateKey, callback)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0,50,0,26)
	frame.BackgroundColor3 = Color3.fromRGB(96,72,170)
	frame.BorderSizePixel = 0; frame.Parent = parent
	local c1 = Instance.new("UICorner"); c1.CornerRadius = UDim.new(1,0); c1.Parent = frame
	createGrayStroke(frame, 2)

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0,22,0,22); circle.Position = UDim2.new(0,2,0.5,-11)
	circle.BackgroundColor3 = Color3.fromRGB(255,255,255); circle.BorderSizePixel = 0
	circle.Parent = frame
	local c2 = Instance.new("UICorner"); c2.CornerRadius = UDim.new(1,0); c2.Parent = circle

	local enabled = States[stateKey] and States[stateKey].Enabled or false
	local function update()
		if enabled then
			tween(frame, {BackgroundColor3 = Color3.fromRGB(0,210,110)}, TweenFast)
			tween(circle, {Position = UDim2.new(0,26,0.5,-11)}, TweenFast)
		else
			tween(frame, {BackgroundColor3 = Color3.fromRGB(96,72,170)}, TweenFast)
			tween(circle, {Position = UDim2.new(0,2,0.5,-11)}, TweenFast)
		end
	end
	update()

	ToggleRefreshers[stateKey] = function(v)
		enabled = v
		update()
	end

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Parent = frame
	local lastPress = 0
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPress = tick()
		end
	end)
	hit.MouseButton1Click:Connect(function()
		if tick() - lastPress < 0.4 then
			setFeatureState(stateKey, not States[stateKey].Enabled)
			if callback then callback(States[stateKey].Enabled) end
		end
	end)
	return frame, function() return enabled end
end

-- ============================================
-- 数值三段式控件
-- ============================================
local StepMap = {
	WalkSpeed = 10, TpWalk = 1, BunnyHop = 1, JumpHeight = 10,
	SuperJump = 10, WallClimb = 5, KillAura = 5, AutoClicker = 5,
	GravityMod = 10, TimeOfDay = 1, DangerWarning = 10,
}
local MinMap = {
	WalkSpeed = 1, TpWalk = 1, BunnyHop = 1, JumpHeight = 1,
	SuperJump = 1, WallClimb = 1, KillAura = 1, AutoClicker = 1,
	GravityMod = 0, TimeOfDay = 0, DangerWarning = 1,
}
local MaxMap = {
	WalkSpeed = 500, TpWalk = 100, BunnyHop = 100, JumpHeight = 500,
	SuperJump = 500, WallClimb = 200, KillAura = 100, AutoClicker = 5000,
	GravityMod = 1000, TimeOfDay = 24, DangerWarning = 500,
}

local function createStepControl(parent, stateKey)
	local step = StepMap[stateKey] or 5
	local minV = MinMap[stateKey] or 1
	local maxV = MaxMap[stateKey] or 999

	local minus = Instance.new("TextButton")
	minus.Size = UDim2.new(0, 24, 0, 26); minus.Position = UDim2.new(0, 214, 0.5, -13)
	minus.BackgroundColor3 = C.Btn
	minus.Text = "−"; minus.TextColor3 = Color3.fromRGB(255,255,255)
	minus.TextSize = 14; minus.Font = Enum.Font.GothamBold
	minus.Parent = parent
	local mC = Instance.new("UICorner"); mC.CornerRadius = UDim.new(0, 8); mC.Parent = minus
	createGrayStroke(minus, 1.5)

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 50, 0, 26); valLabel.Position = UDim2.new(0, 240, 0.5, -13)
	valLabel.BackgroundColor3 = C.Val
	valLabel.BackgroundTransparency = 0.1
	valLabel.Text = tostring(States[stateKey].Value or 0)
	valLabel.TextColor3 = Color3.fromRGB(255,255,255)
	valLabel.TextSize = 11; valLabel.Font = Enum.Font.Gotham
	valLabel.Parent = parent
	local vC = Instance.new("UICorner"); vC.CornerRadius = UDim.new(0, 8); vC.Parent = valLabel
	createGrayStroke(valLabel, 1.5)

	local plus = Instance.new("TextButton")
	plus.Size = UDim2.new(0, 24, 0, 26); plus.Position = UDim2.new(0, 292, 0.5, -13)
	plus.BackgroundColor3 = C.Btn
	plus.Text = "+"; plus.TextColor3 = Color3.fromRGB(255,255,255)
	plus.TextSize = 14; plus.Font = Enum.Font.GothamBold
	plus.Parent = parent
	local pC = Instance.new("UICorner"); pC.CornerRadius = UDim.new(0, 8); pC.Parent = plus
	createGrayStroke(plus, 1.5)

	local function updateLabel()
		valLabel.Text = tostring(States[stateKey].Value)
	end
	minus.MouseButton1Click:Connect(function()
		States[stateKey].Value = math.max(minV, (States[stateKey].Value or 0) - step)
		updateLabel()
	end)
	plus.MouseButton1Click:Connect(function()
		States[stateKey].Value = math.min(maxV, (States[stateKey].Value or 0) + step)
		updateLabel()
	end)
	return minus, valLabel, plus
end

local function createLabeledStep(parent, labelText, getVal, setVal, step, minV, maxV, fmtFn)
	local W = parent.AbsoluteSize.X
	if W <= 0 then W = 320 end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = C.RowBg
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Parent = parent
	local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 9); rc.Parent = row
	createGrayStroke(row, 1)

	local lab = Instance.new("TextLabel")
	lab.Size = UDim2.new(0, 170, 1, 0)
	lab.Position = UDim2.new(0, 10, 0, 0)
	lab.BackgroundTransparency = 1
	lab.Text = labelText
	lab.TextColor3 = C.TextSub
	lab.TextSize = 11
	lab.Font = Enum.Font.GothamSemibold
	lab.TextXAlignment = Enum.TextXAlignment.Left
	lab.Parent = row

	local function fmtVal(v)
		if fmtFn then return fmtFn(v) end
		if v == 0 then return "∞" end
		return tostring(v)
	end

	local minus = Instance.new("TextButton")
	minus.Size = UDim2.new(0, 26, 0, 22); minus.Position = UDim2.new(1, -100, 0.5, -11)
	minus.BackgroundColor3 = C.Btn
	minus.Text = "−"; minus.TextColor3 = Color3.fromRGB(255,255,255)
	minus.TextSize = 13; minus.Font = Enum.Font.GothamBold
	minus.Parent = row
	local mC = Instance.new("UICorner"); mC.CornerRadius = UDim.new(0, 7); mC.Parent = minus

	local valL = Instance.new("TextLabel")
	valL.Size = UDim2.new(0, 44, 0, 22); valL.Position = UDim2.new(1, -72, 0.5, -11)
	valL.BackgroundColor3 = C.Val
	valL.BackgroundTransparency = 0.1
	valL.Text = fmtVal(getVal())
	valL.TextColor3 = Color3.fromRGB(255, 255, 255)
	valL.TextSize = 11; valL.Font = Enum.Font.GothamBold
	valL.Parent = row
	local vC = Instance.new("UICorner"); vC.CornerRadius = UDim.new(0, 7); vC.Parent = valL

	local plus = Instance.new("TextButton")
	plus.Size = UDim2.new(0, 26, 0, 22); plus.Position = UDim2.new(1, -26, 0.5, -11)
	plus.BackgroundColor3 = C.Btn
	plus.Text = "+"; plus.TextColor3 = Color3.fromRGB(255,255,255)
	plus.TextSize = 13; plus.Font = Enum.Font.GothamBold
	plus.Parent = row
	local pC = Instance.new("UICorner"); pC.CornerRadius = UDim.new(0, 7); pC.Parent = plus

	minus.MouseButton1Click:Connect(function()
		setVal(math.max(minV, (getVal() or 0) - step))
		valL.Text = fmtVal(getVal())
	end)
	plus.MouseButton1Click:Connect(function()
		setVal(math.min(maxV, (getVal() or 0) + step))
		valL.Text = fmtVal(getVal())
	end)
	return row
end

local ColorCycle = {"Red", "Blue", "Green", "Pink", "Yellow", "Cyan"}
local function createColorCycle(parent, stateKey)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 102, 0, 26); btn.Position = UDim2.new(0, 214, 0.5, -13)
	btn.BackgroundColor3 = C.Val
	btn.BackgroundTransparency = 0.1
	btn.Text = "颜色: " .. tostring(States[stateKey].Value or "Pink")
	btn.TextColor3 = Color3.fromRGB(255,255,255)
	btn.TextSize = 11; btn.Font = Enum.Font.Gotham
	btn.Parent = parent
	local cC = Instance.new("UICorner"); cC.CornerRadius = UDim.new(0, 8); cC.Parent = btn
	createGrayStroke(btn, 1.5)
	btn.MouseButton1Click:Connect(function()
		local cur = tostring(States[stateKey].Value or "Pink")
		local idx = 0
		for i, c in ipairs(ColorCycle) do
			if c:lower() == cur:lower() then idx = i break end
		end
		local next = ColorCycle[(idx % #ColorCycle) + 1]
		States[stateKey].Value = next
		btn.Text = "颜色: " .. next
		if States[stateKey].Enabled then
			local updater = Updaters[stateKey]
			if updater then pcall(updater) end
		end
	end)
	return btn
end

-- ============================================
-- 长按防误触拖拽
-- ============================================
local function makeDraggable(guiObject, handle, onRelease)
	handle = handle or guiObject
	local state = {pressing = false, active = false, pressTime = 0, pressStart = Vector2.zero, startPos = nil, moved = 0}
	local conn = nil
	local api = {
		cancel = function()
			state.pressing = false
			state.active = false
		end,
		isActive = function() return state.active end,
	}
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.pressing = true
			state.active = false
			state.pressTime = tick()
			state.pressStart = input.Position
			state.startPos = guiObject.Position
			state.moved = 0
			if conn then conn:Disconnect() end
			conn = UserInputService.InputChanged:Connect(function(changed)
				if not state.pressing or changed ~= input then return end
				local delta = changed.Position - state.pressStart
				state.moved = delta.Magnitude
				if not state.active then
					if tick() - state.pressTime >= 1.0 and state.moved < 40 then
						state.active = true
					end
				else
					local tX = state.startPos.X.Offset + delta.X * 0.35
					local tY = state.startPos.Y.Offset + delta.Y * 0.35
					local cur = guiObject.Position
					guiObject.Position = UDim2.new(
						cur.X.Scale, cur.X.Offset + (tX - cur.X.Offset) * 0.18,
						cur.Y.Scale, cur.Y.Offset + (tY - cur.Y.Offset) * 0.18
					)
				end
			end)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			state.pressing = false
			state.active = false
			if conn then conn:Disconnect(); conn = nil end
			if onRelease then onRelease() end
		end
	end)
	return api
end

-- ============================================
-- 音乐系统 V6.2 (国际可用 API - Deezer)
-- 国内API在海外游戏不可用, 改用Deezer公开接口
-- ============================================
local MUSIC_API = {
	search = {
		"https://api.deezer.com/search?q=%s&limit=20",
	},
	recommend = {
		"https://api.deezer.com/chart/0/tracks",
		"https://api.deezer.com/chart/1/tracks",
	},
	stream = "https://api.deezer.com/track/%s",
}
local Music = {
	Open = false, Tab = "Rec", List = {}, Idx = 1,
	Current = nil, Playing = false, Mode = 0,
	ModeNames = {"🔁 列表循环", "🔂 单曲循环", "➡️ 顺序播放"},
	HasBox = false,
}
local function musicToast(msg)
	if Gui.MusicToast then
		Gui.MusicToast.Text = msg
		Gui.MusicToast.Visible = true
		tween(Gui.MusicToast, {BackgroundTransparency = 0.15}, TweenFast)
		task.delay(2, function()
			if Gui.MusicToast then
				tween(Gui.MusicToast, {BackgroundTransparency = 1}, TweenFast)
				task.delay(0.3, function() if Gui.MusicToast then Gui.MusicToast.Visible = false end end)
			end
		end)
	end
end

local function isVip(statusCode)
	-- Deezer: 5=可试听需购买, 1=0完整. 这里将不能免费完整播放的标记为VIP
	return statusCode == 5 or statusCode == 1
end

-- 三通道HTTP请求: game:HttpGet → request → GetAsync
local function httpJson(url)
	local body = nil
	local ok1, b1 = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok1 and type(b1) == "string" and #b1 > 0 then
		body = b1
	else
		local ok2, res = pcall(function()
			local r = request({Url = url, Method = "GET"})
			return r
		end)
		if ok2 and res and res.StatusCode == 200 and res.Body and #res.Body > 0 then
			body = res.Body
		else
			local ok3, b3 = pcall(function() return HttpService:GetAsync(url) end)
			if ok3 and type(b3) == "string" and #b3 > 0 then
				body = b3
			end
		end
	end
	return body
end

-- 从Deezer数据解析歌曲(V6.2)
local function parseDeezerTracks(tracks)
	local list = {}
	for _, s in ipairs(tracks) do
		if type(s) == "table" and s.id then
			local artist = "未知"
			if s.artist and s.artist.name then artist = s.artist.name end
			table.insert(list, {
				id = tostring(s.id),
				name = s.title or "?",
				artist = artist,
				dt = (s.duration or 200) * 1000,
				vip = isVip(s.status or 0),
				preview = s.preview or "",
			})
		end
	end
	return list
end

-- V6.2: Deezer搜索
local function searchMusic(kw)
	local enc = ""
	pcall(function() enc = HttpService:UrlEncode(kw) end)
	if #enc == 0 then enc = kw end
	for _, u in ipairs(MUSIC_API.search) do
		local body = httpJson(string.format(u, enc))
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and data and data.data and #data.data > 0 then
				return parseDeezerTracks(data.data)
			end
		end
	end
	return nil
end

-- V6.2: Deezer热歌榜
local function getRecommend()
	for _, u in ipairs(MUSIC_API.recommend) do
		local body = httpJson(u)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and data and data.tracks and data.tracks.data and #data.tracks.data > 0 then
				return parseDeezerTracks(data.tracks.data)
			end
		end
	end
	return nil
end

-- V6.2: 下载音频(Deezer 30秒预览)
-- 优先取track接口的preview字段, 无则回退标准外链
local function downloadSong(id)
	local url = string.format(MUSIC_API.stream, id)
	local body = httpJson(url)
	if body then
		local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
		if ok and data and data.preview and #data.preview > 0 then
			local pUrl = data.preview
			-- 下载预览音频(二进制安全, request优先)
			local ok1, res = pcall(function()
				local r = request({Url = pUrl, Method = "GET"})
				return r
			end)
			if ok1 and res and res.StatusCode == 200 and res.Body and #res.Body > 2000 then
				return res.Body
			end
			local ok2, b2 = pcall(function() return game:HttpGet(pUrl, true) end)
			if ok2 and type(b2) == "string" and #b2 > 2000 then
				return b2
			end
			local ok3, b3 = pcall(function() return HttpService:GetAsync(pUrl) end)
			if ok3 and type(b3) == "string" and #b3 > 2000 then
				return b3
			end
		end
	end
	return nil
end

local MusicTimer = nil
local function playSongAt(idx)
	local list = Music.List
	local s = list[idx]
	if not s then return end
	Music.Idx = idx
	Music.Current = s
	if Gui.MusicNow then
		Gui.MusicNow.Text = "🎵 " .. (s.vip and "🔒" or "") .. s.name .. " - " .. s.artist
	end
	renderMusicList()
	task.spawn(function()
		local body = downloadSong(s.id)
		if body then
			local okW = pcall(function() writefile("NHMusic.mp3", body) end)
			local okP = pcall(function()
				if not playfile then error("no playfile") end
				playfile("NHMusic.mp3")
			end)
			if okW and okP then
				Music.Playing = true
				updateMusicPlayBtn()
				musicToast("▶ 播放: " .. s.name)
				if MusicTimer then task.cancel(MusicTimer) end
				MusicTimer = task.delay(math.max((s.dt or 200000) / 1000 + 1.5, 5), function()
					if Music.Current == s and Music.Playing then
						onMusicEnd()
					end
				end)
			else
				musicToast("⚠ 播放器不支持本地播放")
			end
		else
			Music.Current = s
			musicToast("🔒 " .. s.name .. " 无法获取音频")
			if Music.Current == s then
				onMusicEnd()
			end
		end
	end)
end

local function stopMusic()
	Music.Playing = false
	pcall(function() if stopfile then stopfile() end end)
	if MusicTimer then task.cancel(MusicTimer); MusicTimer = nil end
	updateMusicPlayBtn()
	if Gui.MusicNow then Gui.MusicNow.Text = "⏹ 已停止" end
end

local function onMusicEnd()
	if not Music.Playing and not Music.Current then return end
	if #Music.List == 0 then return end
	if Music.Mode == 1 then
		playSongAt(Music.Idx)
	elseif Music.Mode == 2 then
		if Music.Idx < #Music.List then
			playSongAt(Music.Idx + 1)
		else
			stopMusic()
			musicToast("✅ 播放列表已播完")
		end
	else
		playSongAt((Music.Idx % #Music.List) + 1)
	end
end

local function toggleMusicMode()
	Music.Mode = (Music.Mode + 1) % 3
	if Gui.MusicModeBtn then Gui.MusicModeBtn.Text = Music.ModeNames[Music.Mode + 1] end
end

local function isFav(id)
	for _, f in ipairs(States.MusicPlayer.Favorites) do
		if f.id == id then return true end
	end
	return false
end

local function toggleFav(song)
	local favs = States.MusicPlayer.Favorites
	for i, f in ipairs(favs) do
		if f.id == song.id then
			table.remove(favs, i)
			musicToast("💔 已取消收藏: " .. song.name)
			renderMusicList()
			return
		end
	end
	table.insert(favs, {id = song.id, name = song.name, artist = song.artist, dt = song.dt, vip = song.vip})
	musicToast("❤️ 已收藏: " .. song.name)
	renderMusicList()
end

local function updateMusicPlayBtn()
	if Gui.MusicPlayBtn then
		Gui.MusicPlayBtn.Text = Music.Playing and "⏸ 停止" or "▶ 播放"
		Gui.MusicPlayBtn.BackgroundColor3 = Music.Playing and Color3.fromRGB(180, 90, 40) or Color3.fromRGB(0, 140, 90)
	end
end

-- 音乐悬浮窗UI
local MusicPanel, MusicListFrame, MusicSearchBox
local function renderMusicList()
	if not MusicListFrame then return end
	for _, c in ipairs(MusicListFrame:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	local list = Music.List
	if #list == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 30)
		empty.Position = UDim2.new(0, 0, 0, 8)
		empty.BackgroundTransparency = 1
		empty.Text = Music.Tab == "Favs" and "暂无收藏" or "加载中..."
		empty.TextColor3 = Color3.fromRGB(170, 170, 200)
		empty.TextSize = 11
		empty.Font = Enum.Font.Gotham
		empty.Parent = MusicListFrame
		return
	end
	local y = 0
	for i, s in ipairs(list) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 30)
		row.Position = UDim2.new(0, 2, 0, y)
		row.BackgroundColor3 = Music.Current == s and Color3.fromRGB(0, 120, 80) or C.RowBg
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = MusicListFrame
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row
		createGrayStroke(row, 1)

		local playHit = Instance.new("TextButton")
		playHit.Size = UDim2.new(1, -36, 1, 0)
		playHit.BackgroundTransparency = 1
		playHit.Text = ""
		playHit.AutoButtonColor = false
		playHit.Parent = row
		local lastP = 0
		playHit.InputBegan:Connect(function(inp)
			if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then lastP = tick() end
		end)
		playHit.MouseButton1Click:Connect(function()
			if tick() - lastP < 0.4 then playSongAt(i) end
		end)

		local nameL = Instance.new("TextLabel")
		nameL.Size = UDim2.new(0, 190, 1, 0)
		nameL.Position = UDim2.new(0, 8, 0, 0)
		nameL.BackgroundTransparency = 1
		nameL.Text = (s.vip and "🔒 " or "") .. s.name
		nameL.TextColor3 = Color3.fromRGB(235, 235, 255)
		nameL.TextSize = 10
		nameL.Font = Enum.Font.GothamSemibold
		nameL.TextXAlignment = Enum.TextXAlignment.Left
		nameL.TextTruncate = Enum.TextTruncate.AtEnd
		nameL.Parent = row

		local artistL = Instance.new("TextLabel")
		artistL.Size = UDim2.new(0, 70, 1, 0)
		artistL.Position = UDim2.new(0, 196, 0, 0)
		artistL.BackgroundTransparency = 1
		artistL.Text = s.artist
		artistL.TextColor3 = Color3.fromRGB(150, 160, 220)
		artistL.TextSize = 9
		artistL.Font = Enum.Font.Gotham
		artistL.TextXAlignment = Enum.TextXAlignment.Left
		artistL.TextTruncate = Enum.TextTruncate.AtEnd
		artistL.Parent = row

		local favBtn = Instance.new("TextButton")
		favBtn.Size = UDim2.new(0, 28, 0, 24)
		favBtn.Position = UDim2.new(1, -32, 0.5, -12)
		favBtn.BackgroundColor3 = isFav(s.id) and Color3.fromRGB(220, 60, 90) or Color3.fromRGB(70, 50, 120)
		favBtn.Text = isFav(s.id) and "♥" or "♡"
		favBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		favBtn.TextSize = 12
		favBtn.Font = Enum.Font.GothamBold
		favBtn.Parent = row
		local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 8); fc.Parent = favBtn
		favBtn.MouseButton1Click:Connect(function()
			toggleFav(s)
		end)
		y = y + 32
	end
end

local function setMusicTab(tab)
	Music.Tab = tab
	if tab == "Search" then
		if Gui.MusicSearchRow then Gui.MusicSearchRow.Visible = true end
	else
		if Gui.MusicSearchRow then Gui.MusicSearchRow.Visible = false end
	end
	if tab == "Favs" then
		Music.List = {}
		for _, f in ipairs(States.MusicPlayer.Favorites) do
			table.insert(Music.List, {id = f.id, name = f.name, artist = f.artist, dt = f.dt or 200000, vip = f.vip})
		end
	elseif tab == "Rec" then
		Music.List = {}
		musicToast("📡 加载推荐中...")
		task.spawn(function()
			local list = getRecommend()
			if list and #list > 0 then
				Music.List = list
				Music.Idx = 1
				musicToast("✅ 推荐加载成功 " .. #list .. " 首")
			else
				musicToast("⚠ 推荐加载失败, 试试搜索")
			end
			renderMusicList()
		end)
	end
	renderMusicList()
end

local function buildMusicPanel()
	local panel = Instance.new("Frame")
	panel.Name = "MusicPanel"
	panel.Size = UDim2.new(0, 240, 0, 34)
	panel.Position = UDim2.new(0, 8, 0.45, -17)
	panel.BackgroundColor3 = Color3.fromRGB(20, 12, 48)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9450
	panel.ClipsDescendants = true
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 14); pc.Parent = panel
	createGrayStroke(panel, 2)
	local pGrad = Instance.new("UIGradient")
	pGrad.Color = ColorSequence.new(Color3.fromRGB(88, 30, 150), Color3.fromRGB(30, 60, 180))
	pGrad.Rotation = 90
	pGrad.Parent = panel

	local barHit = Instance.new("TextButton")
	barHit.Size = UDim2.new(1, 0, 0, 34)
	barHit.BackgroundTransparency = 1
	barHit.Text = ""
	barHit.AutoButtonColor = false
	barHit.Parent = panel
	local barText = Instance.new("TextLabel")
	barText.Size = UDim2.new(1, -80, 1, 0)
	barText.Position = UDim2.new(0, 10, 0, 0)
	barText.BackgroundTransparency = 1
	barText.Text = "🎵 音乐播放器"
	barText.TextColor3 = Color3.fromRGB(255, 255, 255)
	barText.TextSize = 13
	barText.Font = Enum.Font.GothamBold
	barText.TextXAlignment = Enum.TextXAlignment.Left
	barText.TextTruncate = Enum.TextTruncate.AtEnd
	barText.Parent = barHit
	Gui.MusicBarText = barText

	local barPlay = Instance.new("TextButton")
	barPlay.Size = UDim2.new(0, 30, 0, 26)
	barPlay.Position = UDim2.new(1, -68, 0.5, -13)
	barPlay.BackgroundColor3 = Color3.fromRGB(0, 140, 90)
	barPlay.Text = "▶"
	barPlay.TextColor3 = Color3.fromRGB(255, 255, 255)
	barPlay.TextSize = 12
	barPlay.Font = Enum.Font.GothamBold
	barPlay.Parent = barHit
	local bpC = Instance.new("UICorner"); bpC.CornerRadius = UDim.new(0, 8); bpC.Parent = barPlay
	Gui.MusicPlayBtn = barPlay
	barPlay.MouseButton1Click:Connect(function()
		if Music.Playing then
			stopMusic()
		else
			if Music.Current then
				playSongAt(Music.Idx)
			else
				musicToast("请先搜索或选择歌曲")
			end
		end
	end)

	local barClose = Instance.new("TextButton")
	barClose.Size = UDim2.new(0, 26, 0, 26)
	barClose.Position = UDim2.new(1, -36, 0.5, -13)
	barClose.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	barClose.Text = "×"
	barClose.TextColor3 = Color3.fromRGB(255, 255, 255)
	barClose.TextSize = 12
	barClose.Font = Enum.Font.GothamBold
	barClose.Parent = barHit
	local bcC = Instance.new("UICorner"); bcC.CornerRadius = UDim.new(0, 8); bcC.Parent = barClose
	barClose.MouseButton1Click:Connect(function()
		Music.Open = false
		tween(panel, {Size = UDim2.new(0, 240, 0, 34)}, TweenPanelClose)
		musicToast("🎵 悬浮窗已关闭, 音乐后台播放中")
	end)

	local lastPress = 0
	barHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			lastPress = tick()
		end
	end)
	barHit.MouseButton1Click:Connect(function()
		if tick() - lastPress < 0.4 then
			Music.Open = not Music.Open
			if Music.Open then
				tween(panel, {Size = UDim2.new(0, 380, 0, 380)}, TweenPanelOpen)
			else
				tween(panel, {Size = UDim2.new(0, 240, 0, 34)}, TweenPanelClose)
			end
		end
	end)

	local content = Instance.new("Frame")
	content.Size = UDim2.new(1, -12, 0, 340)
	content.Position = UDim2.new(0, 6, 0, 40)
	content.BackgroundTransparency = 1
	content.Parent = panel

	local nowL = Instance.new("TextLabel")
	nowL.Size = UDim2.new(1, 0, 0, 20)
	nowL.BackgroundTransparency = 1
	nowL.Text = "🎵 未播放"
	nowL.TextColor3 = Color3.fromRGB(140, 255, 190)
	nowL.TextSize = 10
	nowL.Font = Enum.Font.GothamBold
	nowL.TextXAlignment = Enum.TextXAlignment.Left
	nowL.TextTruncate = Enum.TextTruncate.AtEnd
	nowL.Parent = content
	Gui.MusicNow = nowL

	local ctrlRow = Instance.new("Frame")
	ctrlRow.Size = UDim2.new(1, 0, 0, 32)
	ctrlRow.Position = UDim2.new(0, 0, 0, 22)
	ctrlRow.BackgroundTransparency = 1
	ctrlRow.Parent = content

	local function ctrlBtn(text, x, color)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 62, 0, 28)
		b.Position = UDim2.new(0, x, 0, 2)
		b.BackgroundColor3 = color
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 11
		b.Font = Enum.Font.GothamBold
		b.Parent = ctrlRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		return b
	end

	local prevBtn = ctrlBtn("⏮", 0, Color3.fromRGB(70, 50, 140))
	prevBtn.MouseButton1Click:Connect(function()
		if #Music.List > 0 then
			playSongAt(((Music.Idx - 2) % #Music.List) + 1)
		end
	end)
	local modeBtn = ctrlBtn(Music.ModeNames[1], 68, Color3.fromRGB(90, 40, 130))
	modeBtn.MouseButton1Click:Connect(function()
		toggleMusicMode()
	end)
	Gui.MusicModeBtn = modeBtn
	local nextBtn = ctrlBtn("⏭", 136, Color3.fromRGB(70, 50, 140))
	nextBtn.MouseButton1Click:Connect(function()
		if #Music.List > 0 then
			playSongAt((Music.Idx % #Music.List) + 1)
		end
	end)
	local stopBtn = ctrlBtn("⏹ 停", 204, Color3.fromRGB(160, 70, 60))
	stopBtn.MouseButton1Click:Connect(function()
		stopMusic()
	end)

	local searchRow = Instance.new("Frame")
	searchRow.Size = UDim2.new(1, 0, 0, 32)
	searchRow.Position = UDim2.new(0, 0, 0, 56)
	searchRow.BackgroundTransparency = 1
	searchRow.Parent = content
	Gui.MusicSearchRow = searchRow

	MusicSearchBox = nil
	local okBox, box = pcall(function()
		local tb = Instance.new("TextBox")
		tb.Size = UDim2.new(1, -84, 0, 28)
		tb.Position = UDim2.new(0, 0, 0, 2)
		tb.BackgroundColor3 = Color3.fromRGB(40, 30, 90)
		tb.PlaceholderText = "搜索歌曲/歌手..."
		tb.PlaceholderColor3 = Color3.fromRGB(140, 140, 190)
		tb.Text = ""
		tb.TextColor3 = Color3.fromRGB(255, 255, 255)
		tb.TextSize = 12
		tb.Font = Enum.Font.Gotham
		tb.ClearTextOnFocus = true
		tb.Parent = searchRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = tb
		createGrayStroke(tb, 1)
		return tb
	end)
	if okBox then
		MusicSearchBox = box
		Music.HasBox = true
	end

	local searchBtn = Instance.new("TextButton")
	searchBtn.Size = UDim2.new(0, 78, 0, 28)
	searchBtn.Position = UDim2.new(1, -78, 0, 2)
	searchBtn.BackgroundColor3 = Color3.fromRGB(0, 140, 110)
	searchBtn.Text = "🔍 搜索"
	searchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	searchBtn.TextSize = 11
	searchBtn.Font = Enum.Font.GothamBold
	searchBtn.Parent = searchRow
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 8); sc.Parent = searchBtn
	searchBtn.MouseButton1Click:Connect(function()
		local kw = MusicSearchBox and MusicSearchBox.Text or ""
		if #kw == 0 then
			musicToast("⚠ 请输入搜索关键词")
			return
		end
		musicToast("🔍 搜索: " .. kw)
		task.spawn(function()
			local list = searchMusic(kw)
			if list and #list > 0 then
				Music.List = list
				Music.Idx = 1
				Music.Tab = "Search"
				renderMusicList()
				musicToast("✅ 找到 " .. #list .. " 首歌曲")
			else
				musicToast("❌ 未找到歌曲或网络失败")
			end
		end)
	end)

	local tabRow = Instance.new("Frame")
	tabRow.Size = UDim2.new(1, 0, 0, 28)
	tabRow.Position = UDim2.new(0, 0, 0, 90)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = content
	local tabs = {{"Rec", "🔥 推荐"}, {"Search", "🔍 搜索"}, {"Favs", "❤️ 收藏"}}
	for i, t in ipairs(tabs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 116, 0, 24)
		b.Position = UDim2.new(0, (i - 1) * 122, 0, 2)
		b.BackgroundColor3 = Color3.fromRGB(70, 50, 140)
		b.Text = t[2]
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 11
		b.Font = Enum.Font.GothamSemibold
		b.Parent = tabRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 8); c.Parent = b
		b.MouseButton1Click:Connect(function()
			setMusicTab(t[1])
		end)
	end

	MusicListFrame = Instance.new("Frame")
	MusicListFrame.Size = UDim2.new(1, 0, 0, 200)
	MusicListFrame.Position = UDim2.new(0, 0, 0, 122)
	MusicListFrame.BackgroundColor3 = Color3.fromRGB(12, 8, 30)
	MusicListFrame.BackgroundTransparency = 0.2
	MusicListFrame.BorderSizePixel = 0
	MusicListFrame.ClipsDescendants = true
	MusicListFrame.Parent = content
	local mlc = Instance.new("UICorner"); mlc.CornerRadius = UDim.new(0, 10); mlc.Parent = MusicListFrame

	local tipL = Instance.new("TextLabel")
	tipL.Size = UDim2.new(1, 0, 0, 16)
	tipL.Position = UDim2.new(0, 0, 0, 324)
	tipL.BackgroundTransparency = 1
	tipL.Text = "长按拖动 · 🔒为VIP歌曲 · 关闭窗口音乐继续播"
	tipL.TextColor3 = Color3.fromRGB(150, 150, 200)
	tipL.TextSize = 8
	tipL.Font = Enum.Font.Gotham
	tipL.Parent = content

	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 250, 0, 26)
	toast.Position = UDim2.new(0.5, -125, 1, -110)
	toast.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	toast.BackgroundTransparency = 1
	toast.Text = ""
	toast.TextColor3 = Color3.fromRGB(255, 220, 120)
	toast.TextSize = 11
	toast.Font = Enum.Font.GothamBold
	toast.Visible = false
	toast.ZIndex = 9600
	toast.Parent = ScreenGui
	local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 8); tc.Parent = toast
	createGrayStroke(toast, 1.5)
	Gui.MusicToast = toast

	makeDraggable(panel)
	raiseZIndex(panel, 9451)
	Gui.MusicPanel = panel
	return panel
end

-- ============================================
-- 面板常量 + 开关函数
-- ============================================
local ISLAND_W, ISLAND_H = 190, 38
local PANEL_W, PANEL_H = 600, 360
local PanelOpen = false

local function togglePanel()
	PanelOpen = not PanelOpen
	if Gui.MainPanel then Gui.MainPanel.Visible = true end
	if PanelOpen then
		if States.DynamicIsland and States.DynamicIsland.Enabled then
			Gui.MainPanel.Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)
		else
			Gui.MainPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
		end
		Gui.ContentScale.Scale = 0.9
		Gui.PanelScale.Scale = 0.92
		tween(Gui.MainPanel, {Size = UDim2.new(0, PANEL_W, 0, PANEL_H)}, TweenPanelOpen)
		tween(Gui.PanelScale, {Scale = 1}, TweenScalePop)
		tween(Gui.ContentScale, {Scale = 1}, TweenScalePop)
		staggerIn()
		pulseIsland()
		Gui.IslandRightText.Text = "✕ 收起"
	else
		if States.DynamicIsland and States.DynamicIsland.Enabled then
			tween(Gui.ContentScale, {Scale = 0.95}, TweenPanelClose)
			tween(Gui.PanelScale, {Scale = 0.96}, TweenPanelClose)
			local tw = tween(Gui.MainPanel, {Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)}, TweenPanelClose)
			if tw then
				tw.Completed:Connect(function()
					Gui.PanelScale.Scale = 1
					Gui.ContentScale.Scale = 1
				end)
			end
			Gui.IslandRightText.Text = "≡ 菜单"
		else
			tween(Gui.PanelScale, {Scale = 0.85}, TweenPanelClose)
			tween(Gui.ContentScale, {Scale = 0.85}, TweenPanelClose)
			task.delay(0.25, function()
				if Gui.MainPanel then Gui.MainPanel.Visible = false end
				Gui.PanelScale.Scale = 1
				Gui.ContentScale.Scale = 1
			end)
			Gui.IslandRightText.Text = "≡ 菜单"
		end
		pulseIsland()
	end
end

local function staggerIn()
	local delay = 0
	local keys = {"InfoSection", "LeftBar", "RightContent"}
	for _, key in ipairs(keys) do
		local obj = Gui[key]
		if obj then
			local base = obj.Position
			task.delay(delay, function()
				if not obj.Parent then return end
				obj.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, base.Y.Offset + 12)
				tween(obj, {Position = base}, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			end)
			delay = delay + 0.06
		end
	end
end

local function pulseIsland()
	if Gui.TitleBar then
		tween(Gui.TitleBar, {BackgroundTransparency = 0.5}, TweenFast)
		task.delay(0.15, function()
			if Gui.TitleBar then
				tween(Gui.TitleBar, {BackgroundTransparency = 1}, TweenFast)
			end
		end)
	end
	if Gui.BreatheDotScale then
		Gui.BreatheDotScale.Scale = 1.8
		tween(Gui.BreatheDotScale, {Scale = 1}, TweenScalePop)
	end
end

-- ============================================
-- V6.2: 悬浮球面板化(更像面板/快捷菜单)
-- 预生成, 从左到右淡入淡出
-- ============================================
local BallMenuPanel
local function buildBallMenu()
	if BallMenuPanel and BallMenuPanel.Parent then return BallMenuPanel end
	local panel = Instance.new("Frame")
	panel.Name = "NinjaBallMenu"
	panel.Size = UDim2.new(0, 170, 0, 66)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.15
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9115
	panel.Parent = ScreenGui
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 14); bc.Parent = panel
	createGrayStroke(panel, 2)
	local bgG = Instance.new("UIGradient")
	bgG.Color = ColorSequence.new(Color3.fromRGB(70, 40, 150), Color3.fromRGB(40, 40, 130))
	bgG.Rotation = 90
	bgG.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 20)
	title.Position = UDim2.new(0, 8, 0, 1)
	title.BackgroundTransparency = 1
	title.Text = "⚡ Ninja Hub"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 24, 0, 24)
	closeBtn.Position = UDim2.new(1, -26, 0, 0)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 13
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local ccC = Instance.new("UICorner"); ccC.CornerRadius = UDim.new(1, 0); ccC.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		toggleBallMenu()
	end)

	local btnRow = Instance.new("Frame")
	btnRow.Size = UDim2.new(1, -8, 0, 30)
	btnRow.Position = UDim2.new(0, 4, 0, 24)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent = panel
	Gui.BallMenuRow = btnRow

	local function menuPill(text, color)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.485, 0, 1, 0)
		b.BackgroundColor3 = color
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 11
		b.Font = Enum.Font.GothamBold
		b.Parent = btnRow
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 9); c.Parent = b
		createGrayStroke(b, 1.5)
		return b
	end
	local m1 = menuPill("🎵 音乐", Color3.fromRGB(150, 50, 180))
	m1.Position = UDim2.new(0, 0, 0, 0)
	m1.MouseButton1Click:Connect(function()
		toggleBallMenu()
		States.MusicPlayer.Enabled = true
		setFeatureState("MusicPlayer", true)
		if Updaters.MusicPlayer then Updaters.MusicPlayer() end
	end)
	local m2 = menuPill("🧹 一键互动", Color3.fromRGB(50, 130, 220))
	m2.Position = UDim2.new(0.515, 0, 0, 0)
	m2.MouseButton1Click:Connect(function()
		toggleBallMenu()
		if remoteInteractAll then remoteInteractAll() end
	end)
	local m3 = menuPill("🕹 点击脚本", Color3.fromRGB(200, 120, 40))
	m3.Position = UDim2.new(0, 0, 0, 33)
	m3.MouseButton1Click:Connect(function()
		toggleBallMenu()
		States.ClickScript.Enabled = true
		if Updaters.ClickScript then Updaters.ClickScript() end
	end)
	local m4 = menuPill("🎬 客户端", Color3.fromRGB(40, 170, 120))
	m4.Position = UDim2.new(0.515, 0, 0, 33)
	m4.MouseButton1Click:Connect(function()
		toggleBallMenu()
		States.ClientScript.Enabled = true
		if Updaters.ClientScript then Updaters.ClientScript() end
	end)

	makeDraggable(panel)
	raiseZIndex(panel, 9116)
	BallMenuPanel = panel
	return panel
end

local function toggleBallMenu(fromX)
	local panel = buildBallMenu()
	if not panel then return end
	if panel.Visible then
		-- 从右向左淡出
		tween(panel, {Position = UDim2.new(0, fromX or 0, 0, panel.Position.Y.Offset), BackgroundTransparency = 1}, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		local tr = TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(0, (fromX or 0) - 120, 0, panel.Position.Y.Offset)})
		tr.Completed:Connect(function() panel.Visible = false panel.Position = UDim2.new(0, fromX or 0, 0, panel.Position.Y.Offset) panel.BackgroundTransparency = 0.15 end)
		tr:Play()
	else
		panel.Visible = true
		panel.Position = UDim2.new(0, (fromX or 0) + 120, 0, panel.Position.Y.Offset)
		tween(panel, {Position = UDim2.new(0, (fromX or 0) - 8, 0, panel.Position.Y.Offset)}, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end
end

-- 悬浮球(V6.2 重组: 更像面板, 点击后预生成面板从右往左呼出)
local floatBallCache = {}
local function createFloatBall()
	if Gui.FloatBall then return Gui.FloatBall end
	local ball = Instance.new("Frame")
	ball.Name = "NinjaFloatBallV62"
	ball.Size = UDim2.new(0, 44, 0, 44)
	local savedPos = States.FloatBallPos
	if type(savedPos) == "table" and #savedPos == 4 then
		ball.Position = UDim2.new(savedPos[1], savedPos[2], savedPos[3], savedPos[4])
	else
		ball.Position = UDim2.new(0.5, -22, 0, 110)
	end
	ball.BackgroundTransparency = 0
	ball.BorderSizePixel = 0
	ball.ZIndex = 9100
	ball.Parent = ScreenGui

	local bg = Instance.new("UIGradient")
	bg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
	})
	bg.Rotation = 0
	bg.Parent = ball
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = ball

	local core = Instance.new("Frame")
	core.Size = UDim2.new(1, -6, 1, -6)
	core.Position = UDim2.new(0, 3, 0, 3)
	core.BackgroundColor3 = Color3.fromRGB(8, 6, 20)
	core.BackgroundTransparency = 0.35
	core.BorderSizePixel = 0
	core.Parent = ball
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(1, 0); cc.Parent = core

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.BackgroundTransparency = 1
	txt.Text = "⚡"
	txt.TextColor3 = Color3.fromRGB(255, 255, 255)
	txt.TextSize = 16
	txt.Font = Enum.Font.GothamBold
	txt.Parent = ball

	-- 小球下方小冒泡提示(更像面板)
	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(0, 40, 0, 12)
	badge.Position = UDim2.new(0.5, -20, 1, 2)
	badge.BackgroundColor3 = Color3.fromRGB(20, 14, 46)
	badge.BackgroundTransparency = 0.3
	badge.Visible = true
	badge.ZIndex = 9102
	badge.Parent = ball
	local bdC = Instance.new("UICorner"); bdC.CornerRadius = UDim.new(1, 0); bdC.Parent = badge
	local bdT = Instance.new("TextLabel")
	bdT.Size = UDim2.new(1, 0, 1, 0)
	bdT.BackgroundTransparency = 1
	bdT.Text = "菜单"
	bdT.TextColor3 = Color3.fromRGB(200, 200, 255)
	bdT.TextSize = 7
	bdT.Font = Enum.Font.GothamBold
	bdT.Parent = badge

	local ls = Instance.new("UIScale"); ls.Scale = 1; ls.Parent = ball

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Parent = ball
	hit.MouseButton1Click:Connect(function()
		tween(ls, {Scale = 0.85}, TweenFast)
		task.delay(0.09, function()
			if ls and ls.Parent then tween(ls, {Scale = 1.2}, TweenScalePop) end
		end)
		task.delay(0.34, function()
			if ls and ls.Parent then tween(ls, {Scale = 1}, TweenScalePop) end
		end)
		-- V6.2: 打开预生成面板(从右向左淡入)
		if States.DynamicIsland and not States.DynamicIsland.Enabled then
			local ap = BallMenuPanel and BallMenuPanel.Position or UDim2.new(0, ball.Position.X.Offset, 0, ball.Position.Y.Offset)
			toggleBallMenu(ball.Position.X.Offset + 22)
		end
	end)

	task.spawn(function()
		while ball and ball.Parent do
			core.BackgroundTransparency = 0.25 + 0.15 * math.sin(tick() * 2.6)
			task.wait(0.04)
		end
	end)
	task.spawn(function()
		local rot = 0
		while ball and ball.Parent do
			rot = rot + 1
			bg.Rotation = rot
			task.wait(0.05)
		end
	end)

	local function saveBallPos()
		if ball and ball.Parent then
			local p = ball.Position
			States.FloatBallPos = {p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset}
		end
	end
	makeDraggable(ball, hit, saveBallPos)
	raiseZIndex(ball, 9101)
	Gui.FloatBall = ball
	return ball
end

-- ============================================
-- 全局输入坐标命中检测
-- ============================================
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		if Gui.MainPanel and Gui.MainPanel.Visible then
			local pos = input.Position
			local vs = camera.ViewportSize
			if vs and vs.X > 0 then
				local w = Gui.MainPanel.Size.X.Offset
				if w <= 0 then w = ISLAND_W end
				local halfW = w / 2 + 16
				if pos.X >= vs.X/2 - halfW and pos.X <= vs.X/2 + halfW
					and pos.Y >= -4 and pos.Y <= ISLAND_H + 22 then
					togglePanel()
				end
			end
		end
	end
end)

-- ============================================
-- 玻璃卡片
-- ============================================
Gui.CardGrads = {}
local function createGlassCard(parent, size, radius)
	local outer = Instance.new("Frame")
	outer.Size = size
	outer.BackgroundTransparency = 0
	outer.BorderSizePixel = 0
	outer.Parent = parent
	local oc = Instance.new("UICorner"); oc.CornerRadius = UDim.new(0, radius or 16); oc.Parent = outer
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(255, 50, 160), Color3.fromRGB(50, 110, 255))
	grad.Rotation = 90
	grad.Parent = outer
	table.insert(Gui.CardGrads, grad)

	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -5, 1, -5)
	inner.Position = UDim2.new(0, 2.5, 0, 2.5)
	inner.BackgroundColor3 = Color3.fromRGB(26, 18, 62)
	inner.BackgroundTransparency = 0.15
	inner.BorderSizePixel = 0
	inner.Parent = outer
	local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(0, (radius or 16) - 3); ic.Parent = inner
	return inner, outer
end

-- ============================================
-- 主面板: 灵动岛一体化
-- ============================================
local function buildMainPanel()
	local MainPanel = Instance.new("Frame")
	MainPanel.Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)
	MainPanel.Position = UDim2.new(0.5, 0, 0, 10)
	MainPanel.AnchorPoint = Vector2.new(0.5, 0)
	MainPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	MainPanel.BackgroundTransparency = 0.35
	MainPanel.ClipsDescendants = true
	MainPanel.BorderSizePixel = 0
	MainPanel.ZIndex = 9000
	MainPanel.Parent = ScreenGui
	local mpC = Instance.new("UICorner"); mpC.CornerRadius = UDim.new(0, 24); mpC.Parent = MainPanel
	local mpStroke = createGrayStroke(MainPanel, 2)
	local mpGrad = Instance.new("UIGradient")
	mpGrad.Color = ColorSequence.new(Color3.fromRGB(24, 14, 56), Color3.fromRGB(38, 22, 84))
	mpGrad.Rotation = 90
	mpGrad.Parent = MainPanel
	local PanelScale = Instance.new("UIScale")
	PanelScale.Scale = 1
	PanelScale.Parent = MainPanel

	local GlassGlare = Instance.new("Frame")
	GlassGlare.Size = UDim2.new(1, 0, 0, 90)
	GlassGlare.Position = UDim2.new(0, 0, 0, 0)
	GlassGlare.BackgroundColor3 = Color3.fromRGB(255,255,255)
	GlassGlare.BackgroundTransparency = 1
	GlassGlare.BorderSizePixel = 0
	GlassGlare.Parent = MainPanel
	local ggGrad = Instance.new("UIGradient")
	ggGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
	ggGrad.Rotation = 90
	ggGrad.Transparency = NumberSequence.new(0.92, 1)
	ggGrad.Parent = GlassGlare

	local GlassUnder = Instance.new("Frame")
	GlassUnder.Size = UDim2.new(1, 0, 0, 60)
	GlassUnder.Position = UDim2.new(0, 0, 1, -60)
	GlassUnder.BackgroundColor3 = Color3.fromRGB(255,255,255)
	GlassUnder.BackgroundTransparency = 1
	GlassUnder.BorderSizePixel = 0
	GlassUnder.Parent = MainPanel
	local guGrad = Instance.new("UIGradient")
	guGrad.Color = ColorSequence.new(Color3.fromRGB(120,140,255), Color3.fromRGB(255,255,255))
	guGrad.Rotation = 90
	guGrad.Transparency = NumberSequence.new(1, 0.95)
	guGrad.Parent = GlassUnder

	local TitleBar = Instance.new("Frame")
	TitleBar.Size = UDim2.new(1, 0, 0, ISLAND_H)
	TitleBar.Position = UDim2.new(0, 0, 0, 0)
	TitleBar.BackgroundColor3 = Color3.fromRGB(255,255,255)
	TitleBar.BackgroundTransparency = 1
	TitleBar.BorderSizePixel = 0
	TitleBar.Parent = MainPanel

	local IslandLeftText = Instance.new("TextLabel")
	IslandLeftText.Size = UDim2.new(0, 110, 0, 20)
	IslandLeftText.Position = UDim2.new(0, 14, 0.5, -10)
	IslandLeftText.BackgroundTransparency = 1
	IslandLeftText.Text = "⚡ Ninja Hub"
	IslandLeftText.TextColor3 = Color3.fromRGB(255,255,255)
	IslandLeftText.TextSize = 13
	IslandLeftText.Font = Enum.Font.GothamBold
	IslandLeftText.TextXAlignment = Enum.TextXAlignment.Left
	IslandLeftText.Parent = TitleBar

	local IslandDiv = Instance.new("Frame")
	IslandDiv.Size = UDim2.new(0, 1, 0, 20)
	IslandDiv.Position = UDim2.new(0, 126, 0.5, -10)
	IslandDiv.BackgroundColor3 = Color3.fromRGB(200,200,220)
	IslandDiv.BackgroundTransparency = 0.3
	IslandDiv.BorderSizePixel = 0
	IslandDiv.Parent = TitleBar

	local BreatheDot = Instance.new("Frame")
	BreatheDot.Size = UDim2.new(0, 10, 0, 10)
	BreatheDot.Position = UDim2.new(0, 140, 0.5, -5)
	BreatheDot.AnchorPoint = Vector2.new(0.5, 0.5)
	BreatheDot.BackgroundColor3 = Color3.fromRGB(0,255,150)
	BreatheDot.BorderSizePixel = 0
	BreatheDot.Parent = TitleBar
	local bdC = Instance.new("UICorner"); bdC.CornerRadius = UDim.new(1,0); bdC.Parent = BreatheDot
	createGrayStroke(BreatheDot, 1)
	local BreatheDotScale = Instance.new("UIScale")
	BreatheDotScale.Scale = 1
	BreatheDotScale.Parent = BreatheDot

	local IslandRightText = Instance.new("TextLabel")
	IslandRightText.Size = UDim2.new(0, 44, 0, 20)
	IslandRightText.Position = UDim2.new(1, -52, 0.5, -10)
	IslandRightText.BackgroundTransparency = 1
	IslandRightText.Text = "≡ 菜单"
	IslandRightText.TextColor3 = Color3.fromRGB(255,255,255)
	IslandRightText.TextSize = 13
	IslandRightText.Font = Enum.Font.GothamBold
	IslandRightText.TextXAlignment = Enum.TextXAlignment.Right
	IslandRightText.Parent = TitleBar

	local TitleHit = Instance.new("Frame")
	TitleHit.Size = UDim2.new(1, 0, 1, 0)
	TitleHit.BackgroundTransparency = 1
	TitleHit.Active = true
	TitleHit.Parent = TitleBar
	TitleHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			togglePanel()
		end
	end)

	local ContentFrame = Instance.new("Frame")
	ContentFrame.Size = UDim2.new(1, 0, 1, -ISLAND_H)
	ContentFrame.Position = UDim2.new(0, 0, 0, ISLAND_H)
	ContentFrame.BackgroundTransparency = 1
	ContentFrame.ClipsDescendants = true
	ContentFrame.BorderSizePixel = 0
	ContentFrame.Parent = MainPanel
	local ContentScale = Instance.new("UIScale")
	ContentScale.Scale = 1
	ContentScale.Parent = ContentFrame

	local TopLine = Instance.new("Frame")
	TopLine.Size = UDim2.new(1, -80, 0, 1.5)
	TopLine.Position = UDim2.new(0, 40, 0, 2)
	TopLine.BackgroundColor3 = Color3.fromRGB(255,255,255)
	TopLine.BackgroundTransparency = 1
	TopLine.BorderSizePixel = 0
	TopLine.Parent = ContentFrame
	local tlGrad = Instance.new("UIGradient")
	tlGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
	tlGrad.Rotation = 90
	tlGrad.Transparency = NumberSequence.new(1, 0, 1)
	tlGrad.Parent = TopLine
	Gui.TopLineGrad = tlGrad

	local InfoSection = Instance.new("Frame")
	InfoSection.Size = UDim2.new(0, 104, 1, -14)
	InfoSection.Position = UDim2.new(0, 8, 0, 7)
	InfoSection.BackgroundTransparency = 1
	InfoSection.Parent = ContentFrame

	local CardLayout = Instance.new("UIListLayout")
	CardLayout.Padding = UDim.new(0, 7)
	CardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	CardLayout.Parent = InfoSection
	local CardPad = Instance.new("UIPadding"); CardPad.PaddingTop = UDim.new(0, 2); CardPad.Parent = InfoSection

	local avatarCardInner, _ = createGlassCard(InfoSection, UDim2.new(0, 66, 0, 66), 18)
	local AvatarImage = Instance.new("ImageLabel")
	AvatarImage.Size = UDim2.new(1, -10, 1, -10)
	AvatarImage.Position = UDim2.new(0, 5, 0, 5)
	AvatarImage.BackgroundColor3 = Color3.fromRGB(60, 45, 130)
	AvatarImage.BackgroundTransparency = 0
	AvatarImage.BorderSizePixel = 0
	AvatarImage.Parent = avatarCardInner
	local avC = Instance.new("UICorner"); avC.CornerRadius = UDim.new(0, 14); avC.Parent = AvatarImage
	local AvatarStroke = createGrayStroke(AvatarImage, 1.5)
	Gui.AvatarStroke = AvatarStroke
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and img and AvatarImage then
			AvatarImage.Image = img
		end
	end)

	local nameCardInner, _ = createGlassCard(InfoSection, UDim2.new(0, 92, 0, 28), 14)
	local PlayerNameLabel = Instance.new("TextLabel")
	PlayerNameLabel.Size = UDim2.new(1, -8, 1, 0)
	PlayerNameLabel.Position = UDim2.new(0, 4, 0, 0)
	PlayerNameLabel.BackgroundTransparency = 1
	PlayerNameLabel.Text = player.DisplayName or player.Name
	PlayerNameLabel.TextColor3 = Color3.fromRGB(255,255,255)
	PlayerNameLabel.TextSize = 11
	PlayerNameLabel.Font = Enum.Font.GothamBold
	PlayerNameLabel.TextWrapped = true
	PlayerNameLabel.Parent = nameCardInner

	local srvCardInner, _ = createGlassCard(InfoSection, UDim2.new(0, 92, 0, 86), 14)
	local ServerInfoText = Instance.new("TextLabel")
	ServerInfoText.Size = UDim2.new(1, -8, 1, 0)
	ServerInfoText.Position = UDim2.new(0, 4, 0, 2)
	ServerInfoText.BackgroundTransparency = 1
	ServerInfoText.Text = "加载中..."
	ServerInfoText.TextColor3 = Color3.fromRGB(200,220,255)
	ServerInfoText.TextSize = 10
	ServerInfoText.Font = Enum.Font.Gotham
	ServerInfoText.TextXAlignment = Enum.TextXAlignment.Left
	ServerInfoText.TextYAlignment = Enum.TextYAlignment.Top
	ServerInfoText.TextWrapped = true
	ServerInfoText.Parent = srvCardInner

	local nearCardInner, _ = createGlassCard(InfoSection, UDim2.new(0, 92, 0, 40), 14)
	local NearestText = Instance.new("TextLabel")
	NearestText.Size = UDim2.new(1, -8, 1, 0)
	NearestText.Position = UDim2.new(0, 4, 0, 0)
	NearestText.BackgroundTransparency = 1
	NearestText.Text = "最近: 搜索中..."
	NearestText.TextColor3 = Color3.fromRGB(150,255,180)
	NearestText.TextSize = 10
	NearestText.Font = Enum.Font.Gotham
	NearestText.TextXAlignment = Enum.TextXAlignment.Left
	NearestText.TextWrapped = true
	NearestText.Parent = nearCardInner
	NearestText.ClipsDescendants = true

	local statCardInner, _ = createGlassCard(InfoSection, UDim2.new(0, 92, 0, 36), 14)
	local StatText = Instance.new("TextLabel")
	StatText.Size = UDim2.new(1, -8, 1, 0)
	StatText.Position = UDim2.new(0, 4, 0, 0)
	StatText.BackgroundTransparency = 1
	StatText.Text = "已开启: 0 个功能"
	StatText.TextColor3 = Color3.fromRGB(255,220,120)
	StatText.TextSize = 10
	StatText.Font = Enum.Font.Gotham
	StatText.TextXAlignment = Enum.TextXAlignment.Left
	StatText.ClipsDescendants = true
	StatText.Parent = statCardInner

	raiseZIndex(InfoSection, 9003)

	local VDivider = Instance.new("Frame")
	VDivider.Size = UDim2.new(0, 1.5, 1, -14)
	VDivider.Position = UDim2.new(0, 114, 0, 7)
	VDivider.BackgroundColor3 = Color3.fromRGB(180,180,200)
	VDivider.BackgroundTransparency = 0.35
	VDivider.BorderSizePixel = 0
	VDivider.Parent = ContentFrame

	local LeftBar = Instance.new("Frame")
	LeftBar.Size = UDim2.new(0,84,1,-8)
	LeftBar.Position = UDim2.new(0,120,0,4)
	LeftBar.BackgroundColor3 = Color3.fromRGB(22, 16, 56)
	LeftBar.BackgroundTransparency = 0.25
	LeftBar.BorderSizePixel = 0
	LeftBar.Parent = ContentFrame
	local lbC = Instance.new("UICorner"); lbC.CornerRadius = UDim.new(0,16); lbC.Parent = LeftBar
	createGrayStroke(LeftBar, 1)

	local ButtonWrap = Instance.new("Frame")
	ButtonWrap.Size = UDim2.new(1, 0, 1, 0)
	ButtonWrap.BackgroundTransparency = 1
	ButtonWrap.Parent = LeftBar
	local LeftLayout = Instance.new("UIListLayout")
	LeftLayout.Padding = UDim.new(0,5); LeftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	LeftLayout.Parent = ButtonWrap
	local LeftPad = Instance.new("UIPadding"); LeftPad.PaddingTop = UDim.new(0,7); LeftPad.Parent = ButtonWrap

	Gui.CatGrads = {}
	local CatIndicator = Instance.new("Frame")
	CatIndicator.Size = UDim2.new(0, 74, 0, 30)
	CatIndicator.Position = UDim2.new(0, 5, 0, 9)
	CatIndicator.BackgroundTransparency = 0
	CatIndicator.BorderSizePixel = 0
	CatIndicator.ZIndex = 9005
	CatIndicator.Parent = LeftBar
	local ciC = Instance.new("UICorner"); ciC.CornerRadius = UDim.new(0, 10); ciC.Parent = CatIndicator
	local ciGrad = Instance.new("UIGradient")
	ciGrad.Color = ColorSequence.new(Color3.fromRGB(255, 50, 150), Color3.fromRGB(50, 110, 255))
	ciGrad.Rotation = 90
	ciGrad.Parent = CatIndicator
	table.insert(Gui.CatGrads, ciGrad)
	Gui.CatIndicator = CatIndicator

	local RightContent = Instance.new("Frame")
	RightContent.Size = UDim2.new(0, 380, 1, -8)
	RightContent.Position = UDim2.new(0, 208, 0, 4)
	RightContent.BackgroundTransparency = 1
	RightContent.ClipsDescendants = true
	RightContent.Active = true
	RightContent.Parent = ContentFrame

	local ScrollInner = Instance.new("Frame")
	ScrollInner.Size = UDim2.new(0, 368, 0, 0)
	ScrollInner.Position = UDim2.new(0, 6, 0, 0)
	ScrollInner.BackgroundTransparency = 1
	ScrollInner.Parent = RightContent

	local ScrollDrag = {dragging = false, startY = 0, baseY = 0, moved = false}
	local ScrollMoveConn
	RightContent.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			ScrollDrag.dragging = true
			ScrollDrag.moved = false
			ScrollDrag.startY = input.Position.Y
			ScrollDrag.baseY = ScrollInner.Position.Y.Offset
			if ScrollMoveConn then ScrollMoveConn:Disconnect() end
			ScrollMoveConn = UserInputService.InputChanged:Connect(function(changed)
				if ScrollDrag.dragging and changed == input then
					local dy = changed.Position.Y - ScrollDrag.startY
					if math.abs(dy) > 8 then ScrollDrag.moved = true end
					if ScrollDrag.moved then
						local viewH = RightContent.AbsoluteSize.Y
						local contentH = ScrollInner.Size.Y.Offset
						local minY = math.min(0, viewH - contentH)
						local ny = math.clamp(ScrollDrag.baseY + dy, minY, 0)
						ScrollInner.Position = UDim2.new(0, 6, 0, ny)
					end
				end
			end)
		end
	end)
	RightContent.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			ScrollDrag.dragging = false
			if ScrollMoveConn then ScrollMoveConn:Disconnect(); ScrollMoveConn = nil end
		end
	end)

	local BottomGlow = Instance.new("Frame")
	BottomGlow.Size = UDim2.new(1, -40, 0, 2)
	BottomGlow.Position = UDim2.new(0, 20, 1, -10)
	BottomGlow.BackgroundColor3 = Color3.fromRGB(255,255,255)
	BottomGlow.BackgroundTransparency = 1
	BottomGlow.BorderSizePixel = 0
	BottomGlow.Parent = ContentFrame
	local bgGrad = Instance.new("UIGradient")
	bgGrad.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(255,255,255))
	bgGrad.Rotation = 90
	bgGrad.Transparency = NumberSequence.new(1, 0, 1)
	bgGrad.Parent = BottomGlow
	Gui.BottomGlow = BottomGlow

	local Watermark = Instance.new("TextLabel")
	Watermark.Size = UDim2.new(0, 90, 0, 12)
	Watermark.Position = UDim2.new(1, -96, 1, -18)
	Watermark.BackgroundTransparency = 1
	Watermark.Text = "NINJA HUB V6.2"
	Watermark.TextColor3 = Color3.fromRGB(255,255,255)
	Watermark.TextTransparency = 0.5
	Watermark.TextSize = 8
	Watermark.Font = Enum.Font.GothamBold
	Watermark.TextXAlignment = Enum.TextXAlignment.Right
	Watermark.Parent = ContentFrame

	raiseZIndex(ContentFrame, 9003)

	Gui.MainPanel = MainPanel
	Gui.PanelScale = PanelScale
	Gui.TitleBar = TitleBar
	Gui.IslandLeftText = IslandLeftText
	Gui.IslandRightText = IslandRightText
	Gui.BreatheDot = BreatheDot
	Gui.BreatheDotScale = BreatheDotScale
	Gui.ContentFrame = ContentFrame
	Gui.ContentScale = ContentScale
	Gui.InfoSection = InfoSection
	Gui.LeftBar = LeftBar
	Gui.ButtonWrap = ButtonWrap
	Gui.RightContent = RightContent
	Gui.ScrollInner = ScrollInner
	Gui.ServerInfoText = ServerInfoText
	Gui.NearestText = NearestText
	Gui.StatText = StatText

	Gui.GameName = "未知"
	pcall(function() Gui.GameName = MarketplaceService:GetProductInfo(game.PlaceId).Name or "未知" end)
	return MainPanel
end

-- ============================================
-- 动态装饰
-- ============================================
task.spawn(function()
	while true do
		task.wait(0.08)
		local t = tick() * 0.15
		local c = Color3.fromHSV(t % 1, 1, 1)
		if Gui.MainPanel then
			local st = Gui.MainPanel:FindFirstChildOfClass("UIStroke")
			if st then st.Color = c end
		end
		if Gui.IslandLeftText then Gui.IslandLeftText.TextColor3 = c end
		if Gui.BreatheDot then
			Gui.BreatheDot.BackgroundColor3 = c
			local s = 0.7 + 0.3 * math.sin(tick() * 4)
			Gui.BreatheDot.Size = UDim2.new(0, 10 * s, 0, 10 * s)
		end
		if Gui.AvatarStroke then Gui.AvatarStroke.Color = c end
		if Gui.BottomGlow then
			local g = Gui.BottomGlow:FindFirstChildOfClass("UIGradient")
			if g then g.Color = ColorSequence.new(c, c) end
		end
		if Gui.TopLineGrad then Gui.TopLineGrad.Color = ColorSequence.new(c, c) end
		for i, g in ipairs(Gui.CardGrads) do
			local p = (t + i * 0.16) % 1
			g.Color = ColorSequence.new(
				Color3.fromHSV(p, 1, 1),
				Color3.fromHSV((p + 0.3) % 1, 1, 1)
			)
		end
		if Gui.CatGrads then
			for i, g in ipairs(Gui.CatGrads) do
				local p = (t + i * 0.11) % 1
				g.Color = ColorSequence.new(
					Color3.fromHSV(p, 1, 1),
					Color3.fromHSV((p + 0.25) % 1, 1, 1)
				)
			end
		end
	end
end)

local FpsCounter = 0
RunService.Heartbeat:Connect(function() FpsCounter = FpsCounter + 1 end)
task.spawn(function()
	while true do
		task.wait(1)
		local fps = FpsCounter
		FpsCounter = 0
		if Gui.MainPanel and Gui.MainPanel.Size.Y.Offset > 100 then
			local ping = 0
			pcall(function() ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
			if Gui.ServerInfoText then
				-- V6.2: 刷新动画
				animateSwap(Gui.ServerInfoText, string.format("服务器: %s\nPlaceId: %d\n延迟: %dms\nFPS: %d", Gui.GameName or "未知", game.PlaceId or 0, ping, fps))
			end
			if Gui.NearestText then
				local nearest, nd = nil, math.huge
				updateTargetCache()
				if hrp then
					for _, e in ipairs(TargetCache.Players) do
						if e.Hrp then
							local d = (hrp.Position - e.Hrp.Position).Magnitude
							if d < nd then nd = d; nearest = e end
						end
					end
				end
				animateSwap(Gui.NearestText, nearest and ("最近: " .. nearest.Plr.Name .. "  " .. string.format("%.1f", nd) .. "m") or "最近: 无")
			end
			if Gui.StatText then
				local count = 0
				for _, s in pairs(States) do
					if type(s) == "table" and s.Enabled then count = count + 1 end
				end
				animateSwap(Gui.StatText, "已开启: " .. count .. " 个功能")
			end
		end
	end
end)

-- ============================================
-- UI构建: 快捷键面板
-- ============================================
local function buildShortcutFrame()
	local ShortcutFrame = Instance.new("Frame")
	ShortcutFrame.Size = UDim2.new(0,90,0,0)
	ShortcutFrame.Position = UDim2.new(0,10,0,115)
	ShortcutFrame.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	ShortcutFrame.BackgroundTransparency = 0.25
	ShortcutFrame.BorderSizePixel = 0
	ShortcutFrame.Visible = false
	ShortcutFrame.ZIndex = 9200
	ShortcutFrame.AutomaticSize = Enum.AutomaticSize.Y
	ShortcutFrame.Parent = ScreenGui
	local sfC = Instance.new("UICorner"); sfC.CornerRadius = UDim.new(0,14); sfC.Parent = ShortcutFrame
	createGrayStroke(ShortcutFrame, 2)

	local ShortcutTitle = Instance.new("TextLabel")
	ShortcutTitle.Size = UDim2.new(1,0,0,22)
	ShortcutTitle.BackgroundTransparency = 1
	ShortcutTitle.Text = "快捷键"
	ShortcutTitle.TextColor3 = Color3.fromRGB(255,255,255)
	ShortcutTitle.TextSize = 11
	ShortcutTitle.Font = Enum.Font.GothamBold
	ShortcutTitle.Parent = ShortcutFrame

	local ShortcutLayout = Instance.new("UIListLayout")
	ShortcutLayout.Padding = UDim.new(0,4)
	ShortcutLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ShortcutLayout.Parent = ShortcutFrame
	local ShortcutPad = Instance.new("UIPadding")
	ShortcutPad.PaddingTop = UDim.new(0,24)
	ShortcutPad.PaddingBottom = UDim.new(0,4)
	ShortcutPad.Parent = ShortcutFrame

	local ShortcutHideBtn = Instance.new("TextButton")
	ShortcutHideBtn.Size = UDim2.new(0,20,0,20)
	ShortcutHideBtn.Position = UDim2.new(1,-22,0,2)
	ShortcutHideBtn.BackgroundColor3 = Color3.fromRGB(255,50,50)
	ShortcutHideBtn.Text = "×"
	ShortcutHideBtn.TextColor3 = Color3.fromRGB(255,255,255)
	ShortcutHideBtn.TextSize = 14
	ShortcutHideBtn.Font = Enum.Font.GothamBold
	ShortcutHideBtn.Parent = ShortcutFrame
	local shbC = Instance.new("UICorner"); shbC.CornerRadius = UDim.new(1,0); shbC.Parent = ShortcutHideBtn

	ShortcutHideBtn.MouseButton1Click:Connect(function()
		ShortcutFrame.Visible = false
	end)

	makeDraggable(ShortcutFrame)
	raiseZIndex(ShortcutFrame, 9201)
	Gui.ShortcutFrame = ShortcutFrame

	local function createShortcutButton(featKey, featName)
		if ShortcutButtons[featKey] then return ShortcutButtons[featKey] end
		local btn = Instance.new("TextButton")
		btn.Name = "SC_" .. featKey
		btn.Size = UDim2.new(0,80,0,28)
		btn.BackgroundColor3 = States[featKey].Enabled and Color3.fromRGB(0,150,80) or Color3.fromRGB(60, 44, 120)
		btn.Text = featName
		btn.TextColor3 = Color3.fromRGB(255,255,255)
		btn.TextSize = 10; btn.Font = Enum.Font.GothamBold
		btn.AutoButtonColor = true
		btn.Parent = ShortcutFrame
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,14); c.Parent = btn
		createGrayStroke(btn, 2)
		btn.MouseButton1Click:Connect(function()
			setFeatureState(featKey, not States[featKey].Enabled)
		end)
		ShortcutButtons[featKey] = btn
		raiseZIndex(btn, 9202)
		return btn
	end
	Gui.createShortcutButton = createShortcutButton
	return ShortcutFrame
end

-- ============================================
-- UI构建: 飞行1面板
-- ============================================
local function buildFly1Panel()
	local Fly1Panel = Instance.new("Frame")
	Fly1Panel.Name = "Fly1Panel"
	Fly1Panel.Size = UDim2.new(0,170,0,150)
	Fly1Panel.Position = UDim2.new(0.7,0,0.15,0)
	Fly1Panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	Fly1Panel.BackgroundTransparency = 0.25
	Fly1Panel.BorderSizePixel = 0
	Fly1Panel.Visible = false
	Fly1Panel.ZIndex = 9300
	Fly1Panel.Parent = ScreenGui
	local f1pC = Instance.new("UICorner"); f1pC.CornerRadius = UDim.new(0,14); f1pC.Parent = Fly1Panel
	createGrayStroke(Fly1Panel, 2)

	local Fly1Title = Instance.new("TextLabel")
	Fly1Title.Size = UDim2.new(1,0,0,24)
	Fly1Title.BackgroundTransparency = 1
	Fly1Title.Text = "飞行1控制 (WASD+空格)"
	Fly1Title.TextColor3 = Color3.fromRGB(255,255,255)
	Fly1Title.TextSize = 12
	Fly1Title.Font = Enum.Font.GothamBold
	Fly1Title.Parent = Fly1Panel

	local Fly1SpeedLabel = Instance.new("TextLabel")
	Fly1SpeedLabel.Size = UDim2.new(1,0,0,18)
	Fly1SpeedLabel.Position = UDim2.new(0,0,0,26)
	Fly1SpeedLabel.BackgroundTransparency = 1
	Fly1SpeedLabel.Text = "速度: " .. States.Fly1.Value
	Fly1SpeedLabel.TextColor3 = Color3.fromRGB(200,200,255)
	Fly1SpeedLabel.TextSize = 11
	Fly1SpeedLabel.Font = Enum.Font.Gotham
	Fly1SpeedLabel.Parent = Fly1Panel
	Fly1SpeedLabel.ClipsDescendants = true

	local Fly1SpeedBox = Instance.new("TextBox")
	Fly1SpeedBox.Size = UDim2.new(0,56,0,24)
	Fly1SpeedBox.Position = UDim2.new(0.5,-28,0,46)
	Fly1SpeedBox.BackgroundColor3 = C.BtnDark
	Fly1SpeedBox.Text = tostring(States.Fly1.Value)
	Fly1SpeedBox.TextColor3 = Color3.fromRGB(255,255,255)
	Fly1SpeedBox.PlaceholderText = "速度"
	Fly1SpeedBox.TextSize = 11
	Fly1SpeedBox.Font = Enum.Font.Gotham
	Fly1SpeedBox.Parent = Fly1Panel
	local f1sbC = Instance.new("UICorner"); f1sbC.CornerRadius = UDim.new(0,8); f1sbC.Parent = Fly1SpeedBox

	local Fly1MinusBtn = createButton(Fly1Panel, "Fly1Minus", UDim2.new(0,34,0,24), UDim2.new(0.5,-70,0,46), C.Btn, "-")
	local Fly1PlusBtn = createButton(Fly1Panel, "Fly1Plus", UDim2.new(0,34,0,24), UDim2.new(0.5,36,0,46), C.Btn, "+")

	local Fly1UpBtn = createButton(Fly1Panel, "Fly1Up", UDim2.new(0,66,0,26), UDim2.new(0.5,-72,0,76), Color3.fromRGB(60, 60, 170), "↑ 上升")
	local Fly1DownBtn = createButton(Fly1Panel, "Fly1Down", UDim2.new(0,66,0,26), UDim2.new(0.5,6,0,76), Color3.fromRGB(60, 60, 170), "↓ 下降")

	local Fly1StopBtn = createButton(Fly1Panel, "Fly1Stop", UDim2.new(0,130,0,26), UDim2.new(0.5,-65,0,108), Color3.fromRGB(180, 70, 70), "停止飞行")
	Fly1StopBtn.TextSize = 12

	local Fly1CloseBtn = Instance.new("TextButton")
	Fly1CloseBtn.Size = UDim2.new(0,22,0,22)
	Fly1CloseBtn.Position = UDim2.new(1,-26,0,2)
	Fly1CloseBtn.BackgroundColor3 = Color3.fromRGB(255,50,50)
	Fly1CloseBtn.Text = "×"
	Fly1CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
	Fly1CloseBtn.TextSize = 13
	Fly1CloseBtn.Font = Enum.Font.GothamBold
	Fly1CloseBtn.Parent = Fly1Panel
	local f1cbC = Instance.new("UICorner"); f1cbC.CornerRadius = UDim.new(1,0); f1cbC.Parent = Fly1CloseBtn

	Fly1UpBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Gui.Fly1BtnY = 1
		end
	end)
	Fly1UpBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if Gui.Fly1BtnY == 1 then Gui.Fly1BtnY = 0 end
		end
	end)
	Fly1DownBtn.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Gui.Fly1BtnY = -1
		end
	end)
	Fly1DownBtn.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if Gui.Fly1BtnY == -1 then Gui.Fly1BtnY = 0 end
		end
	end)

	Fly1CloseBtn.MouseButton1Click:Connect(function()
		States.Fly1.Enabled = false
		Updaters.Fly1()
	end)
	Fly1StopBtn.MouseButton1Click:Connect(function()
		States.Fly1.Enabled = false
		Updaters.Fly1()
	end)

	makeDraggable(Fly1Panel)
	raiseZIndex(Fly1Panel, 9301)

	Fly1SpeedBox.FocusLost:Connect(function()
		local n = tonumber(Fly1SpeedBox.Text)
		if n then
			States.Fly1.Value = math.clamp(n, 1, 500)
			animateSwap(Fly1SpeedLabel, "速度: " .. States.Fly1.Value)
		end
	end)
	Fly1MinusBtn.MouseButton1Click:Connect(function()
		States.Fly1.Value = math.max(1, States.Fly1.Value - 5)
		Fly1SpeedBox.Text = tostring(States.Fly1.Value)
		animateSwap(Fly1SpeedLabel, "速度: " .. States.Fly1.Value)
	end)
	Fly1PlusBtn.MouseButton1Click:Connect(function()
		States.Fly1.Value = math.min(500, States.Fly1.Value + 5)
		Fly1SpeedBox.Text = tostring(States.Fly1.Value)
		animateSwap(Fly1SpeedLabel, "速度: " .. States.Fly1.Value)
	end)

	Gui.Fly1Panel = Fly1Panel
	Gui.Fly1SpeedLabel = Fly1SpeedLabel
	Gui.Fly1BtnY = 0
	return Fly1Panel
end

-- ============================================
-- UI构建: 飞行2面板
-- ============================================
local function buildFly2Panel()
	local Fly2Panel = Instance.new("Frame")
	Fly2Panel.Name = "Fly2Panel"
	Fly2Panel.Size = UDim2.new(0,170,0,135)
	Fly2Panel.Position = UDim2.new(0.7,0,0.35,0)
	Fly2Panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	Fly2Panel.BackgroundTransparency = 0.25
	Fly2Panel.BorderSizePixel = 0
	Fly2Panel.Visible = false
	Fly2Panel.ZIndex = 9300
	Fly2Panel.Parent = ScreenGui
	local f2pC = Instance.new("UICorner"); f2pC.CornerRadius = UDim.new(0,14); f2pC.Parent = Fly2Panel
	createGrayStroke(Fly2Panel, 2)

	local Fly2Title = Instance.new("TextLabel")
	Fly2Title.Size = UDim2.new(1,0,0,24)
	Fly2Title.BackgroundTransparency = 1
	Fly2Title.Text = "飞行2控制"
	Fly2Title.TextColor3 = Color3.fromRGB(255,255,255)
	Fly2Title.TextSize = 13
	Fly2Title.Font = Enum.Font.GothamBold
	Fly2Title.Parent = Fly2Panel

	local Fly2SpeedLabel = Instance.new("TextLabel")
	Fly2SpeedLabel.Size = UDim2.new(1,0,0,18)
	Fly2SpeedLabel.Position = UDim2.new(0,0,0,26)
	Fly2SpeedLabel.BackgroundTransparency = 1
	Fly2SpeedLabel.Text = "速度: " .. States.Fly2.Value
	Fly2SpeedLabel.TextColor3 = Color3.fromRGB(200,200,255)
	Fly2SpeedLabel.TextSize = 11
	Fly2SpeedLabel.Font = Enum.Font.Gotham
	Fly2SpeedLabel.Parent = Fly2Panel
	Fly2SpeedLabel.ClipsDescendants = true

	local Fly2SpeedBox = Instance.new("TextBox")
	Fly2SpeedBox.Size = UDim2.new(0,56,0,24)
	Fly2SpeedBox.Position = UDim2.new(0.5,-28,0,46)
	Fly2SpeedBox.BackgroundColor3 = C.BtnDark
	Fly2SpeedBox.Text = tostring(States.Fly2.Value)
	Fly2SpeedBox.TextColor3 = Color3.fromRGB(255,255,255)
	Fly2SpeedBox.PlaceholderText = "速度"
	Fly2SpeedBox.TextSize = 11
	Fly2SpeedBox.Font = Enum.Font.Gotham
	Fly2SpeedBox.Parent = Fly2Panel
	local f2sbC = Instance.new("UICorner"); f2sbC.CornerRadius = UDim.new(0,8); f2sbC.Parent = Fly2SpeedBox

	local Fly2MinusBtn = createButton(Fly2Panel, "Fly2Minus", UDim2.new(0,34,0,24), UDim2.new(0.5,-70,0,46), C.Btn, "-")
	local Fly2PlusBtn = createButton(Fly2Panel, "Fly2Plus", UDim2.new(0,34,0,24), UDim2.new(0.5,36,0,46), C.Btn, "+")

	local Fly2ToggleBtn = createButton(Fly2Panel, "Fly2Toggle", UDim2.new(0,130,0,28), UDim2.new(0.5,-65,0,78), Color3.fromRGB(110, 70, 190), "开启飞行")
	Fly2ToggleBtn.TextSize = 12

	local Fly2CloseBtn = Instance.new("TextButton")
	Fly2CloseBtn.Size = UDim2.new(0,22,0,22)
	Fly2CloseBtn.Position = UDim2.new(1,-26,0,2)
	Fly2CloseBtn.BackgroundColor3 = Color3.fromRGB(255,50,50)
	Fly2CloseBtn.Text = "×"
	Fly2CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
	Fly2CloseBtn.TextSize = 13
	Fly2CloseBtn.Font = Enum.Font.GothamBold
	Fly2CloseBtn.Parent = Fly2Panel
	local f2cbC = Instance.new("UICorner"); f2cbC.CornerRadius = UDim.new(1,0); f2cbC.Parent = Fly2CloseBtn

	Fly2CloseBtn.MouseButton1Click:Connect(function()
		States.Fly2.Enabled = false
		Updaters.Fly2()
	end)

	makeDraggable(Fly2Panel)
	raiseZIndex(Fly2Panel, 9301)

	Fly2SpeedBox.FocusLost:Connect(function()
		local n = tonumber(Fly2SpeedBox.Text)
		if n then
			States.Fly2.Value = math.clamp(n, 1, 500)
			animateSwap(Fly2SpeedLabel, "速度: " .. States.Fly2.Value)
		end
	end)
	Fly2MinusBtn.MouseButton1Click:Connect(function()
		States.Fly2.Value = math.max(1, States.Fly2.Value - 5)
		Fly2SpeedBox.Text = tostring(States.Fly2.Value)
		animateSwap(Fly2SpeedLabel, "速度: " .. States.Fly2.Value)
	end)
	Fly2PlusBtn.MouseButton1Click:Connect(function()
		States.Fly2.Value = math.min(500, States.Fly2.Value + 5)
		Fly2SpeedBox.Text = tostring(States.Fly2.Value)
		animateSwap(Fly2SpeedLabel, "速度: " .. States.Fly2.Value)
	end)

	Fly2ToggleBtn.MouseButton1Click:Connect(function()
		States.Fly2.Flying = not States.Fly2.Flying
		Fly2ToggleBtn.Text = States.Fly2.Flying and "停止飞行" or "开启飞行"
		Fly2ToggleBtn.BackgroundColor3 = States.Fly2.Flying and Color3.fromRGB(0,150,80) or Color3.fromRGB(110, 70, 190)
	end)

	Gui.Fly2Panel = Fly2Panel
	Gui.Fly2ToggleBtn = Fly2ToggleBtn
	return Fly2Panel
end

-- ============================================
-- UI构建: 强制移动面板
-- ============================================
local function buildFreeMoveFrame()
	local FreeMoveFrame = Instance.new("Frame")
	FreeMoveFrame.Name = "FreeMoveFrame"
	FreeMoveFrame.Size = UDim2.new(0,170,0,200)
	FreeMoveFrame.Position = UDim2.new(0.05,0,0.5,-100)
	FreeMoveFrame.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	FreeMoveFrame.BackgroundTransparency = 0.25
	FreeMoveFrame.BorderSizePixel = 0
	FreeMoveFrame.Visible = false
	FreeMoveFrame.ZIndex = 9300
	FreeMoveFrame.Parent = ScreenGui
	local fmfC = Instance.new("UICorner"); fmfC.CornerRadius = UDim.new(0,14); fmfC.Parent = FreeMoveFrame
	createGrayStroke(FreeMoveFrame, 2)

	local FreeMoveTitle = Instance.new("TextLabel")
	FreeMoveTitle.Size = UDim2.new(1,0,0,22)
	FreeMoveTitle.BackgroundTransparency = 1
	FreeMoveTitle.Text = "强制移动"
	FreeMoveTitle.TextColor3 = Color3.fromRGB(255,255,255)
	FreeMoveTitle.TextSize = 12
	FreeMoveTitle.Font = Enum.Font.GothamBold
	FreeMoveTitle.Parent = FreeMoveFrame

	local FreeMoveClose = Instance.new("TextButton")
	FreeMoveClose.Size = UDim2.new(0,22,0,22)
	FreeMoveClose.Position = UDim2.new(1,-26,0,1)
	FreeMoveClose.BackgroundColor3 = Color3.fromRGB(255,50,50)
	FreeMoveClose.Text = "×"
	FreeMoveClose.TextColor3 = Color3.fromRGB(255,255,255)
	FreeMoveClose.TextSize = 13
	FreeMoveClose.Font = Enum.Font.GothamBold
	FreeMoveClose.Parent = FreeMoveFrame
	local fmcC = Instance.new("UICorner"); fmcC.CornerRadius = UDim.new(1,0); fmcC.Parent = FreeMoveClose

	FreeMoveClose.MouseButton1Click:Connect(function()
		States.FreeMove.Enabled = false
		Updaters.FreeMove()
	end)

	local FreeMoveSpeedLabel = Instance.new("TextLabel")
	FreeMoveSpeedLabel.Size = UDim2.new(0,54,0,20)
	FreeMoveSpeedLabel.Position = UDim2.new(0,8,0,24)
	FreeMoveSpeedLabel.BackgroundTransparency = 1
	FreeMoveSpeedLabel.Text = "速度:" .. States.FreeMove.Value
	FreeMoveSpeedLabel.TextColor3 = Color3.fromRGB(200,200,255)
	FreeMoveSpeedLabel.TextSize = 10
	FreeMoveSpeedLabel.Font = Enum.Font.Gotham
	FreeMoveSpeedLabel.Parent = FreeMoveFrame
	FreeMoveSpeedLabel.ClipsDescendants = true

	local FreeMoveMinus = createButton(FreeMoveFrame, "FM_Minus", UDim2.new(0,24,0,20), UDim2.new(0,64,0,24), C.Btn, "-")
	local FreeMoveSpeedBox = Instance.new("TextBox")
	FreeMoveSpeedBox.Size = UDim2.new(0,44,0,20)
	FreeMoveSpeedBox.Position = UDim2.new(0,90,0,24)
	FreeMoveSpeedBox.BackgroundColor3 = C.BtnDark
	FreeMoveSpeedBox.Text = tostring(States.FreeMove.Value)
	FreeMoveSpeedBox.TextColor3 = Color3.fromRGB(255,255,255)
	FreeMoveSpeedBox.TextSize = 10
	FreeMoveSpeedBox.Font = Enum.Font.Gotham
	FreeMoveSpeedBox.Parent = FreeMoveFrame
	local fmsbC = Instance.new("UICorner"); fmsbC.CornerRadius = UDim.new(0,6); fmsbC.Parent = FreeMoveSpeedBox
	local FreeMovePlus = createButton(FreeMoveFrame, "FM_Plus", UDim2.new(0,24,0,20), UDim2.new(0,138,0,24), C.Btn, "+")

	local freeDrag = makeDraggable(FreeMoveFrame)

	local function createDirBtn(name, text, pos, parent)
		local btn = Instance.new("TextButton")
		btn.Name = name; btn.Size = UDim2.new(0,44,0,44); btn.Position = pos
		btn.BackgroundColor3 = Color3.fromRGB(70, 55, 150)
		btn.BackgroundTransparency = 0.25
		btn.Text = text
		btn.TextColor3 = Color3.fromRGB(255,255,255); btn.TextSize = 18
		btn.Font = Enum.Font.GothamBold; btn.AutoButtonColor = true
		btn.Parent = parent
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,10); c.Parent = btn
		createGrayStroke(btn, 1.5)

		local pressed = false
		btn.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = true
				freeDrag.cancel()
				tween(btn, {BackgroundColor3 = Color3.fromRGB(110, 90, 220)}, TweenFast)
			end
		end)
		btn.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = false
				tween(btn, {BackgroundColor3 = Color3.fromRGB(70, 55, 150)}, TweenFast)
			end
		end)
		return btn, function() return pressed end
	end

	local FreeUpBtn, FreeUpState = createDirBtn("FreeUp","↑", UDim2.new(0,10,0,50), FreeMoveFrame)
	local FreeLeftBtn, FreeLeftState = createDirBtn("FreeLeft","←", UDim2.new(0,10,0,98), FreeMoveFrame)
	local FreeDownBtn, FreeDownState = createDirBtn("FreeDown","↓", UDim2.new(0,10,0,146), FreeMoveFrame)
	local FreeRightBtn, FreeRightState = createDirBtn("FreeRight","→", UDim2.new(0,58,0,98), FreeMoveFrame)

	local FreeFlyUpBtn, FreeFlyUpState = createDirBtn("FreeFlyUp","上", UDim2.new(0,112,0,50), FreeMoveFrame)
	local FreeFlyDownBtn, FreeFlyDownState = createDirBtn("FreeFlyDown","下", UDim2.new(0,112,0,146), FreeMoveFrame)

	raiseZIndex(FreeMoveFrame, 9301)

	FreeMoveSpeedBox.FocusLost:Connect(function()
		local n = tonumber(FreeMoveSpeedBox.Text)
		if n then
			States.FreeMove.Value = math.clamp(n, 1, 500)
			animateSwap(FreeMoveSpeedLabel, "速度:" .. States.FreeMove.Value)
		end
	end)
	FreeMoveMinus.MouseButton1Click:Connect(function()
		States.FreeMove.Value = math.max(1, States.FreeMove.Value - 5)
		FreeMoveSpeedBox.Text = tostring(States.FreeMove.Value)
		animateSwap(FreeMoveSpeedLabel, "速度:" .. States.FreeMove.Value)
	end)
	FreeMovePlus.MouseButton1Click:Connect(function()
		States.FreeMove.Value = math.min(500, States.FreeMove.Value + 5)
		FreeMoveSpeedBox.Text = tostring(States.FreeMove.Value)
		animateSwap(FreeMoveSpeedLabel, "速度:" .. States.FreeMove.Value)
	end)

	Gui.FreeMoveFrame = FreeMoveFrame
	Gui.FreeUpState = FreeUpState
	Gui.FreeLeftState = FreeLeftState
	Gui.FreeDownState = FreeDownState
	Gui.FreeRightState = FreeRightState
	Gui.FreeFlyUpState = FreeFlyUpState
	Gui.FreeFlyDownState = FreeFlyDownState
	return FreeMoveFrame
end

-- ============================================
-- UI构建: 连点器系统 V6.2 (修复多球/数量调节)
-- ============================================
local ClickerBalls = {}
local function rebuildClickerBalls(count)
	count = math.clamp(count or States.ClickerMulti.ClickerCount, 1, 10)
	-- 删除多余
	while #ClickerBalls > count do
		local b = table.remove(ClickerBalls)
		if b then b:Destroy() end
	end
	-- 补齐
	while #ClickerBalls < count do
		local ball = Instance.new("Frame")
		ball.Size = UDim2.new(0, 35, 0, 35)
		ball.BackgroundColor3 = Color3.fromRGB(100, 200, 255)
		ball.BackgroundTransparency = 0.2
		ball.BorderSizePixel = 0
		ball.Visible = false
		ball.ZIndex = 9100
		local cbC = Instance.new("UICorner"); cbC.CornerRadius = UDim.new(1,0); cbC.Parent = ball
		local cbS = Instance.new("UIStroke"); cbS.Color = Color3.fromRGB(160,200,240); cbS.Thickness = 2; cbS.Parent = ball
		local CrossH = Instance.new("Frame")
		CrossH.Size = UDim2.new(0,20,0,2); CrossH.Position = UDim2.new(0.5,-10,0.5,-1)
		CrossH.BackgroundColor3 = Color3.fromRGB(255,255,255); CrossH.BorderSizePixel = 0
		CrossH.Parent = ball
		local CrossV = Instance.new("Frame")
		CrossV.Size = UDim2.new(0,2,0,20); CrossV.Position = UDim2.new(0.5,-1,0.5,-10)
		CrossV.BackgroundColor3 = Color3.fromRGB(255,255,255); CrossV.BorderSizePixel = 0
		CrossV.Parent = ball
		local CenterDot = Instance.new("Frame")
		CenterDot.Size = UDim2.new(0,4,0,4); CenterDot.Position = UDim2.new(0.5,-2,0.5,-2)
		CenterDot.BackgroundColor3 = Color3.fromRGB(255,50,50); CenterDot.BorderSizePixel = 0
		CenterDot.Parent = ball
		local cdC = Instance.new("UICorner"); cdC.CornerRadius = UDim.new(1,0); cdC.Parent = CenterDot
		-- 序号标签
		local idxL = Instance.new("TextLabel")
		idxL.Size = UDim2.new(1,0,0,14)
		idxL.Position = UDim2.new(0,0,1,0)
		idxL.BackgroundColor3 = Color3.fromRGB(20,10,20)
		idxL.BackgroundTransparency = 0.4
		idxL.Text = "#"..#ClickerBalls+1
		idxL.TextColor3 = Color3.fromRGB(255,255,90)
		idxL.TextSize = 9
		idxL.Font = Enum.Font.GothamBold
		idxL.Parent = ball
		raiseZIndex(ball, 9101)

		ball.Position = UDim2.new(0.5, -17, 0.5, -17)
		ball.Parent = ScreenGui

		local dragging, dragConn = false, nil
		local startPos, dragStart, hasMoved
		ball.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				hasMoved = false
				dragging = false
				startPos = ball.Position
				dragStart = input.Position
				if dragConn then dragConn:Disconnect() end
				dragConn = UserInputService.InputChanged:Connect(function(changed)
					if changed == input then
						local delta = (changed.Position - dragStart).Magnitude
						if delta > 5 then hasMoved = true end
						if hasMoved and not dragging then dragging = true end
						if dragging then
							local d = changed.Position - dragStart
							ball.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
						end
					end
				end)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				if dragConn then dragConn:Disconnect(); dragConn = nil end
				dragging = false
			end
		end)

		table.insert(ClickerBalls, ball)
	end
	Gui.ClickerBalls = ClickerBalls
	return #ClickerBalls
end

local function buildClickerSystem()
	rebuildClickerBalls(States.ClickerMulti.ClickerCount or 2)
	Gui.ClickerBalls = ClickerBalls
	Gui.buildClickerSystem = buildClickerSystem
	return
end

-- ============================================
-- UI构建: 信息标签/警告/自瞄圈
-- ============================================
local function buildLabels()
	local InfoLabel = Instance.new("TextLabel")
	InfoLabel.Size = UDim2.new(0,230,0,28); InfoLabel.Position = UDim2.new(0,10,0,65)
	InfoLabel.BackgroundColor3 = Color3.fromRGB(0,0,0); InfoLabel.BackgroundTransparency = 0.5
	InfoLabel.Text = ""; InfoLabel.TextColor3 = Color3.fromRGB(0,255,100)
	InfoLabel.TextSize = 13; InfoLabel.Font = Enum.Font.GothamBold; InfoLabel.Visible = false
	InfoLabel.ZIndex = 9350; InfoLabel.Parent = ScreenGui
	InfoLabel.ClipsDescendants = true
	InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	local ilC = Instance.new("UICorner"); ilC.CornerRadius = UDim.new(0,10); ilC.Parent = InfoLabel
	createGrayStroke(InfoLabel, 1.5)
	Gui.InfoLabel = InfoLabel

	local WarnLabel = Instance.new("TextLabel")
	WarnLabel.Size = UDim2.new(0,300,0,34); WarnLabel.Position = UDim2.new(0.5,-150,0.25,-17)
	WarnLabel.BackgroundColor3 = Color3.fromRGB(120,0,0); WarnLabel.BackgroundTransparency = 0.3
	WarnLabel.Text = ""; WarnLabel.TextColor3 = Color3.fromRGB(255,60,60)
	WarnLabel.TextSize = 14; WarnLabel.Font = Enum.Font.GothamBold
	WarnLabel.Visible = false; WarnLabel.ZIndex = 9360
	WarnLabel.Parent = ScreenGui
	local wlC = Instance.new("UICorner"); wlC.CornerRadius = UDim.new(0,12); wlC.Parent = WarnLabel
	createGrayStroke(WarnLabel, 2)
	Gui.WarnLabel = WarnLabel

	local AimCircle = Instance.new("Frame")
	AimCircle.Size = UDim2.new(0,300,0,300); AimCircle.Position = UDim2.new(0.5,-150,0.5,-150)
	AimCircle.BackgroundTransparency = 1; AimCircle.Visible = false
	AimCircle.ZIndex = 9100; AimCircle.Parent = ScreenGui
	local AimCircleStroke = Instance.new("UIStroke")
	AimCircleStroke.Color = getPartColor("aimcircle")
	AimCircleStroke.Thickness = 2; AimCircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	AimCircleStroke.Parent = AimCircle
	local AimCircleCorner = Instance.new("UICorner")
	AimCircleCorner.CornerRadius = UDim.new(1,0); AimCircleCorner.Parent = AimCircle
	local AimCenterDot = Instance.new("Frame")
	AimCenterDot.Size = UDim2.new(0,6,0,6); AimCenterDot.Position = UDim2.new(0.5,-3,0.5,-3)
	AimCenterDot.BackgroundColor3 = Color3.fromRGB(255,255,255); AimCenterDot.BorderSizePixel = 0
	AimCenterDot.ZIndex = 9101; AimCenterDot.Parent = AimCircle
	local acdC = Instance.new("UICorner"); acdC.CornerRadius = UDim.new(1,0); acdC.Parent = AimCenterDot
	Gui.AimCircle = AimCircle
	Gui.AimCircleStroke = AimCircleStroke
end

-- ============================================
-- UI构建: 自定义自瞄对象悬浮窗
-- ============================================
local CustomAimFrame
local CustomAimList
local function buildCustomAimFrame()
	CustomAimFrame = Instance.new("Frame")
	CustomAimFrame.Size = UDim2.new(0, 220, 0, 330)
	CustomAimFrame.Position = UDim2.new(0.5, -110, 0.5, -165)
	CustomAimFrame.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	CustomAimFrame.BackgroundTransparency = 0.25
	CustomAimFrame.BorderSizePixel = 0
	CustomAimFrame.Visible = false
	CustomAimFrame.ZIndex = 9400
	CustomAimFrame.Parent = ScreenGui
	local cafC = Instance.new("UICorner"); cafC.CornerRadius = UDim.new(0,20); cafC.Parent = CustomAimFrame
	createGrayStroke(CustomAimFrame, 2)

	local cafTitle = Instance.new("TextLabel")
	cafTitle.Size = UDim2.new(1,0,0,30)
	cafTitle.BackgroundTransparency = 1
	cafTitle.Text = "🎯 选择自瞄对象"
	cafTitle.TextColor3 = Color3.fromRGB(255,255,255)
	cafTitle.TextSize = 13
	cafTitle.Font = Enum.Font.GothamBold
	cafTitle.Parent = CustomAimFrame

	local cafClose = Instance.new("TextButton")
	cafClose.Size = UDim2.new(0,24,0,24)
	cafClose.Position = UDim2.new(1,-28,0,3)
	cafClose.BackgroundColor3 = Color3.fromRGB(255,50,50)
	cafClose.Text = "×"
	cafClose.TextColor3 = Color3.fromRGB(255,255,255)
	cafClose.TextSize = 14
	cafClose.Font = Enum.Font.GothamBold
	cafClose.Parent = CustomAimFrame
	local cafcC = Instance.new("UICorner"); cafcC.CornerRadius = UDim.new(1,0); cafcC.Parent = cafClose
	cafClose.MouseButton1Click:Connect(function() CustomAimFrame.Visible = false end)

	CustomAimList = Instance.new("ScrollingFrame")
	CustomAimList.Size = UDim2.new(1,-16,1,-74)
	CustomAimList.Position = UDim2.new(0,8,0,34)
	CustomAimList.BackgroundTransparency = 1
	CustomAimList.ScrollBarThickness = 3
	CustomAimList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	CustomAimList.Parent = CustomAimFrame
	local caLayout = Instance.new("UIListLayout")
	caLayout.Padding = UDim.new(0,4)
	caLayout.Parent = CustomAimList

	local cafAuto = createButton(CustomAimFrame, "CAF_Auto", UDim2.new(1,-16,0,26), UDim2.new(0,8,1,-32), Color3.fromRGB(90, 65, 160), "🔄 跟随自动(取消锁定)")
	cafAuto.TextSize = 12
	cafAuto.MouseButton1Click:Connect(function()
		States.AimbotV2.CustomTarget = nil
		CustomAimFrame.Visible = false
	end)

	makeDraggable(CustomAimFrame)
	raiseZIndex(CustomAimFrame, 9401)
end

-- ============================================
-- 渲染系统
-- ============================================
local RenderFolder = Instance.new("Folder")
RenderFolder.Name = "NinjaRender"; RenderFolder.Parent = ScreenGui

local Pools = {
	Npc = {Lines = {}, Dots = {}},
	Player = {Lines = {}, Dots = {}, Texts = {}},
	Box = {Lines = {}},
	Connect = {Lines = {}},
	Adv = {Boxes = {}, Lines = {}, Texts = {}, Bars = {}},
}

local function getFromPool(pool, parent)
	for i, obj in ipairs(pool) do
		if not obj.Parent then
			obj.Visible = true
			return obj
		end
	end
	local obj
	if pool == Pools.Npc.Lines or pool == Pools.Player.Lines or pool == Pools.Connect.Lines or pool == Pools.Adv.Lines or pool == Pools.Box.Lines then
		obj = Instance.new("Frame")
		obj.BorderSizePixel = 0
	elseif pool == Pools.Adv.Boxes then
		obj = Instance.new("Frame")
		obj.BorderSizePixel = 0
		obj.BackgroundTransparency = 1
	elseif pool == Pools.Npc.Dots or pool == Pools.Player.Dots then
		obj = Instance.new("Frame")
		obj.BorderSizePixel = 0
	elseif pool == Pools.Player.Texts or pool == Pools.Adv.Texts then
		obj = Instance.new("TextLabel")
		obj.BackgroundTransparency = 1
	elseif pool == Pools.Adv.Bars then
		obj = Instance.new("Frame")
		obj.BorderSizePixel = 0
	end
	obj.ZIndex = 9600
	table.insert(pool, obj)
	return obj
end

local function clearPool(pool)
	for _, obj in ipairs(pool) do
		if obj then obj.Visible = false; obj.Parent = nil end
	end
end

local BeamFolder = Instance.new("Folder")
BeamFolder.Name = "NinjaBeams"; BeamFolder.Parent = Workspace

local BeamPools = {
	Npc = {Beams = {}},
	Player = {Beams = {}},
	Connect = {Beams = {}},
	Adv = {Beams = {}},
}

local BEAM_W = 0.05

local function getBeam(pool, color, thickness)
	for _, b in ipairs(pool.Beams) do
		if not b.Enabled then
			b.Color = ColorSequence.new(color)
			b.Width0 = thickness or BEAM_W
			b.Width1 = thickness or BEAM_W
			b.Enabled = true
			return b
		end
	end
	local a0 = Instance.new("Attachment"); a0.Parent = BeamFolder
	local a1 = Instance.new("Attachment"); a1.Parent = BeamFolder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = thickness or BEAM_W; beam.Width1 = thickness or BEAM_W
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 0
	beam.Parent = BeamFolder
	table.insert(pool.Beams, beam)
	return beam
end

local function clearBeams(pool)
	for _, b in ipairs(pool.Beams) do
		b.Enabled = false
	end
end

local function draw3DLine(pool, p1, p2, color, thickness)
	local beam = getBeam(pool, color, thickness or BEAM_W)
	beam.Attachment0.WorldPosition = p1
	beam.Attachment1.WorldPosition = p2
	return beam
end

local AdornPools = {
	Box = {Adorns = {}},
	Hitbox = {Adorns = {}},
}

local function getAdorn(pool, color)
	for _, a in ipairs(pool.Adorns) do
		if not a.Visible then
			a.Color3 = color
			a.Visible = true
			return a
		end
	end
	local adorn = Instance.new("BoxHandleAdornment")
	adorn.Adornee = Workspace.Terrain
	adorn.AlwaysOnTop = true
	adorn.Transparency = 0
	adorn.Color3 = color
	adorn.ZIndex = 0
	pcall(function() adorn.LineThickness = 0.2 end)
	adorn.Parent = Workspace
	table.insert(pool.Adorns, adorn)
	return adorn
end

local function clearAdorns(pool)
	for _, a in ipairs(pool.Adorns) do
		a.Visible = false
	end
end

local function drawBox3D(pool, char, color)
	local cf, size = char:GetBoundingBox()
	if not cf then return false end
	if size.X < 0.1 or size.Y < 0.1 or size.Z < 0.1 then return false end
	local adorn = getAdorn(pool, color)
	adorn.Size = size
	adorn.CFrame = CFrame.new(cf.Position)
	return true
end

local function drawHitbox3D(pool, char, color)
	local drawn = 0
	for _, part in pairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			if drawn >= 12 then break end
			local size = part.Size
			if size.X < 0.1 or size.Y < 0.1 or size.Z < 0.1 then continue end
			local adorn = getAdorn(pool, color)
			adorn.Size = size
			adorn.CFrame = CFrame.new(part.Position)
			drawn = drawn + 1
		end
	end
	return drawn > 0
end

local function drawHLine(pool, parent, x, y, w, color, t)
	local line = getFromPool(pool, parent)
	line.AnchorPoint = Vector2.new(0, 0)
	line.Size = UDim2.new(0, w, 0, t or 1.5)
	line.Position = UDim2.new(0, x, 0, y)
	line.Rotation = 0
	line.BackgroundColor3 = color
	line.Parent = parent
	return line
end

local function drawVLine(pool, parent, x, y, h, color, t)
	local line = getFromPool(pool, parent)
	line.AnchorPoint = Vector2.new(0, 0)
	line.Size = UDim2.new(0, t or 1.5, 0, h)
	line.Position = UDim2.new(0, x, 0, y)
	line.Rotation = 0
	line.BackgroundColor3 = color
	line.Parent = parent
	return line
end

-- ============================================
-- 点击脚本&客户端脚本 共享工具
-- ============================================
local SavedScripts = {Click = {}, Client = {}}
local ClickScriptPanel, ClientScriptPanel, ClientRecordBar
local CS_Editor, CeEditor
local function getGuiInsetOffset()
	local inset = Vector2.zero
	pcall(function() inset = GuiService:GetGuiInset() end)
	return inset
end
local function mouseScreenPos()
	local pos = Vector2.zero
	pcall(function() pos = UserInputService:GetMouseLocation() end)
	local inset = getGuiInsetOffset()
	return pos - inset
end
local function parseNum(str, default)
	local n = tonumber(str)
	if n then return n end
	return default
end

-- 颜色渐变轮廓(为远程互动按钮复用)
local function gradientStroke(btn, palette)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = btn
	Gui.CardGrads = Gui.CardGrads or {}
	Gui.remoteStroke = stroke
	return stroke
end

local function drawBox2D(pool, parent, char, color)
	local hrp2 = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
	local head = char:FindFirstChild("Head")
	if not hrp2 or not head then return false end
	local sp = camera:WorldToViewportPoint(hrp2.Position)
	if sp.Z < 0 then return false end
	local hsp = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
	if hsp.Z < 0 then return false end
	local height = math.abs(hsp.Y - sp.Y) * 2.2
	local width = height * 0.6
	if height < 5 or width < 3 then return false end
	local x1, y1 = sp.X - width/2, sp.Y - height/2
	drawHLine(pool, parent, x1, y1, width, color)
	drawHLine(pool, parent, x1, y1 + height, width, color)
	drawVLine(pool, parent, x1, y1, height, color)
	drawVLine(pool, parent, x1 + width, y1, height, color)
	return true
end

local function drawBone(pool, p1, p2, color)
	if not p1 or not p2 then return nil end
	return draw3DLine(pool, p1.Position, p2.Position, color, BEAM_W)
end

local SkeletonR15 = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
	{"LowerTorso", "HumanoidRootPart"}
}
local SkeletonR6 = {
	{"Head", "Torso"},
	{"Torso", "Left Arm"}, {"Torso", "Right Arm"},
	{"Torso", "Left Leg"}, {"Torso", "Right Leg"}
}
local function getSkeleton(char)
	if char:FindFirstChild("UpperTorso") then return SkeletonR15 end
	return SkeletonR6
end

local AdvESPHighlights = {}
local ThermalHighlights = {}

local function clearRenderCache()
	for char, h in pairs(AdvESPHighlights) do
		pcall(function() h:Destroy() end)
		AdvESPHighlights[char] = nil
	end
	for _, pool in pairs(Pools) do
		for _, p in pairs(pool) do
			clearPool(p)
		end
	end
	for _, bp in pairs(BeamPools) do
		clearBeams(bp)
	end
	for _, ap in pairs(AdornPools) do
		clearAdorns(ap)
	end
end

local function worldToScreen(pos)
	local screenPos, onScreen = camera:WorldToViewportPoint(pos)
	return Vector2.new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

local function isBlockedByWall(targetPart, targetChar)
	if not targetPart then return false end
	local rayParams = RaycastParams.new()
	local ignore = {character}
	if targetChar then table.insert(ignore, targetChar) end
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local dir = targetPart.Position - camera.CFrame.Position
	local result = Workspace:Raycast(camera.CFrame.Position, dir, rayParams)
	if result then
		local hit = result.Instance
		if hit and targetChar and hit:IsDescendantOf(targetChar) then return false end
		return true
	end
	return false
end

-- ============================================
-- 分类与功能数据
-- ============================================
local Categories = {
	{Name = "移动", Color = Color3.fromRGB(0,150,255)},
	{Name = "战斗", Color = Color3.fromRGB(255,60,60)},
	{Name = "视觉", Color = Color3.fromRGB(150,50,255)},
	{Name = "工具", Color = Color3.fromRGB(0,200,100)},
	{Name = "人物", Color = Color3.fromRGB(255,100,0)},
	{Name = "其他", Color = Color3.fromRGB(255,180,0)},
}

local Features = {
	{Cat=1, Name="修改移速", Key="WalkSpeed", Input=true, Place="100"},
	{Cat=1, Name="传送行走", Key="TpWalk", Input=true, Place="距离"},
	{Cat=1, Name="飞行模式", Key="Fly1"},
	{Cat=1, Name="飞行模式2", Key="Fly2"},
	{Cat=1, Name="自由移动", Key="FreeMove"},
	{Cat=1, Name="穿墙模式", Key="Noclip"},
	{Cat=1, Name="超级连跳", Key="BunnyHop", Input=true, Place="增量"},
	{Cat=1, Name="跳高修改", Key="JumpHeight", Input=true, Place="高度"},
	{Cat=1, Name="自动奔跑", Key="AutoRun"},
	{Cat=1, Name="超级跳跃", Key="SuperJump", Input=true, Place="力度"},
	{Cat=1, Name="爬墙模式", Key="WallClimb", Input=true, Place="速度"},
	{Cat=2, Name="无敌模式", Key="GodMode"},
	{Cat=2, Name="攻击无间隔", Key="NoCooldown"},
	{Cat=2, Name="无限子弹", Key="InfiniteAmmo"},
	{Cat=2, Name="自动攻击", Key="AutoAttack"},
	{Cat=2, Name="杀戮光环", Key="KillAura", Input=true, Place="范围"},
	{Cat=2, Name="自动瞄准", Key="Aimbot"},
	{Cat=2, Name="快速射击", Key="RapidFire"},
	{Cat=3, Name="夜视模式", Key="NightVision"},
	{Cat=3, Name="全亮模式", Key="FullBright"},
	{Cat=3, Name="玩家透视", Key="ESP"},
	{Cat=3, Name="地图透视", Key="Xray"},
	{Cat=3, Name="清除迷雾", Key="NoFog"},
	{Cat=3, Name="颜色滤镜", Key="ColorFilter", Input=true, Place="颜色"},
	{Cat=3, Name="自由视角", Key="FreeCam"},
	{Cat=3, Name="热能透视", Key="ThermalESP"},
	{Cat=4, Name="音乐播放", Key="MusicPlayer"},
	{Cat=4, Name="连点器", Key="AutoClicker", Input=true, Place="间隔(ms)"},
	{Cat=4, Name="连点启动", Key="ClickerStart"},
	{Cat=4, Name="多球模式", Key="ClickerMulti"},
	{Cat=4, Name="快速交互", Key="FastInteract"},
	{Cat=4, Name="点击脚本", Key="ClickScript"},
	{Cat=4, Name="客户端脚本", Key="ClientScript"},
	{Cat=4, Name="远程互动", Key="RemoteInteract"},
	{Cat=4, Name="自动保存", Key="AutoSave"},
	{Cat=5, Name="NPC显示", Key="NpcDisplay", HasDropdown=true},
	{Cat=5, Name="玩家显示", Key="PlayerDisplay", HasDropdown=true},
	{Cat=5, Name="框选生物", Key="BoxCreature", HasDropdown=true},
	{Cat=5, Name="连线追踪", Key="LineConnect", HasDropdown=true},
	{Cat=5, Name="智能自瞄", Key="AimbotV2", HasDropdown=true},
	{Cat=5, Name="自动开火", Key="AutoFire"},
	{Cat=5, Name="高级透视", Key="AdvancedESP", HasDropdown=true},
	{Cat=6, Name="启用灵动岛", Key="DynamicIsland"},
	{Cat=6, Name="反挂机", Key="AntiAfk"},
	{Cat=6, Name="显示帧率", Key="ShowFps"},
	{Cat=6, Name="显示坐标", Key="ShowCoords"},
	{Cat=6, Name="重力修改", Key="GravityMod", Input=true, Place="重力值"},
	{Cat=6, Name="时间修改", Key="TimeOfDay", Input=true, Place="小时"},
	{Cat=6, Name="随处坐下", Key="SitAnywhere"},
	{Cat=6, Name="危险警告", Key="DangerWarning", Input=true, Place="距离"},
	{Cat=6, Name="游戏信息", Key="GameInfo", HasDropdown=true},
}

-- ============================================
-- 核心功能实现 (Updaters)
-- ============================================
local FreeMoveBG, FreeMoveBV
local NoclipCache = {}
local NoCdLast = 0
local InfAmmoLast = 0
local BunnyCount = 0
local OrigLighting = {}
local FpsCount, FpsLast = 0, tick()
local XrayTick = 0
local AimScanTick = 0
local AimClosest = nil

local function tryFireTool()
	local tool = character and character:FindFirstChildOfClass("Tool")
	if not tool then return end
	local now = tick()
	local last = tool:GetAttribute("NH_LastFire") or 0
	if now - last < 0.08 then return end
	local fired = false
	for _, evName in ipairs({"Fire", "Shoot", "Click", "Attack", "Activate", "RemoteEvent"}) do
		local ev = tool:FindFirstChild(evName)
		if ev and ev:IsA("RemoteEvent") then
			pcall(function() ev:FireServer() end)
			fired = true
			break
		end
	end
	if not fired then pcall(function() tool:Activate() end) end
	tool:SetAttribute("NH_LastFire", now)
end

Updaters.WalkSpeed = function()
	if States.WalkSpeed.Enabled then
		if Conns.WalkSpeed then return end
		Conns.WalkSpeed = RunService.Heartbeat:Connect(function()
			if not States.WalkSpeed.Enabled then return end
			if humanoid and humanoid.WalkSpeed ~= States.WalkSpeed.Value then
				humanoid.WalkSpeed = States.WalkSpeed.Value
			end
		end)
	else
		unbind("WalkSpeed")
		if humanoid then humanoid.WalkSpeed = States.WalkSpeed.Default or 16 end
	end
end

Updaters.JumpHeight = function()
	if States.JumpHeight.Enabled then
		if Conns.JumpHeight then return end
		Conns.JumpHeight = RunService.Heartbeat:Connect(function()
			if not States.JumpHeight.Enabled then return end
			if humanoid and humanoid.JumpHeight ~= States.JumpHeight.Value then
				humanoid.JumpHeight = States.JumpHeight.Value
			end
		end)
	else
		unbind("JumpHeight")
		if humanoid then humanoid.JumpHeight = States.JumpHeight.Default or 7.2 end
	end
end

Updaters.GravityMod = function()
	if States.GravityMod.Enabled then
		if Conns.GravityMod then return end
		Conns.GravityMod = RunService.Heartbeat:Connect(function()
			if not States.GravityMod.Enabled then return end
			if Workspace.Gravity ~= States.GravityMod.Value then
				Workspace.Gravity = States.GravityMod.Value
			end
		end)
	else
		unbind("GravityMod")
		Workspace.Gravity = States.GravityMod.Default or 196.2
	end
end

Updaters.TpWalk = function()
	if States.TpWalk.Enabled then
		if Conns.TpWalk then return end
		States.Fly1.Enabled = false; Updaters.Fly1()
		States.Fly2.Enabled = false; Updaters.Fly2()
		States.FreeMove.Enabled = false; Updaters.FreeMove()
		if humanoid then disableMovementStates(humanoid) end
		Conns.TpWalk = RunService.Heartbeat:Connect(function()
			if not States.TpWalk.Enabled then return end
			if not hrp or not humanoid then return end
			local dist = States.TpWalk.Value or 2
			local md = humanoid.MoveDirection
			if md.Magnitude > 0 then
				local rp = RaycastParams.new()
				rp.FilterDescendantsInstances = {character}
				rp.FilterType = Enum.RaycastFilterType.Blacklist
				local res = Workspace:Raycast(hrp.Position, md * dist, rp)
				if res then
					hrp.CFrame = hrp.CFrame + (res.Position - hrp.Position).Unit * dist
				else
					hrp.CFrame = hrp.CFrame + md * dist
				end
			end
		end)
	else
		unbind("TpWalk")
		if humanoid then enableMovementStates(humanoid) end
	end
end

Updaters.Fly1 = function()
	if States.Fly1.Enabled then
		if Conns.Fly1 then return end
		States.Fly2.Enabled = false; Updaters.Fly2()
		States.FreeMove.Enabled = false; Updaters.FreeMove()
		States.TpWalk.Enabled = false; Updaters.TpWalk()
		Gui.Fly1Panel.Visible = true
		if humanoid then disableMovementStates(humanoid) end
		Conns.Fly1 = RunService.Heartbeat:Connect(function(dt)
			if not States.Fly1.Enabled then return end
			if not hrp then return end
			local speed = math.clamp(States.Fly1.Value or 45, 1, 500)
			local kbX = (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.A) and 1 or 0)
			local kbZ = (UserInputService:IsKeyDown(Enum.KeyCode.W) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0)
			local kbY = (UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0) - (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 1 or 0)
			local moveY = kbY ~= 0 and kbY or Gui.Fly1BtnY
			local camCF = camera.CFrame
			local dir = camCF.RightVector * kbX + camCF.LookVector * kbZ + Vector3.new(0, moveY, 0)
			if dir.Magnitude > 0 then
				hrp.CFrame = hrp.CFrame + dir.Unit * (speed * dt)
			end
		end)
	else
		unbind("Fly1")
		if Gui.Fly1Panel then Gui.Fly1Panel.Visible = false end
		if humanoid then enableMovementStates(humanoid) end
	end
end

Updaters.Fly2 = function()
	if States.Fly2.Enabled then
		Gui.Fly2Panel.Visible = true
		if Conns.Fly2 then return end
		States.Fly1.Enabled = false; Updaters.Fly1()
		States.FreeMove.Enabled = false; Updaters.FreeMove()
		States.TpWalk.Enabled = false; Updaters.TpWalk()
		if humanoid then disableMovementStates(humanoid) end
		Conns.Fly2 = RunService.Heartbeat:Connect(function(dt)
			if not States.Fly2.Enabled then return end
			if not hrp or not States.Fly2.Flying then return end
			local speed = math.clamp(States.Fly2.Value or 50, 1, 500)
			local moveY = (Gui.FreeFlyUpState() and 1 or 0) + (Gui.FreeFlyDownState() and -1 or 0)
			local moveX = (Gui.FreeRightState() and 1 or 0) + (Gui.FreeLeftState() and -1 or 0)
			local moveZ = (Gui.FreeUpState() and 1 or 0) + (Gui.FreeDownState() and -1 or 0)
			local camCF = camera.CFrame
			local forward = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
			if forward.Magnitude < 0.01 then forward = Vector3.new(0, 0, -1) end
			forward = forward.Unit
			local dir = camCF.RightVector * moveX + forward * moveZ + Vector3.new(0, moveY, 0)
			if dir.Magnitude > 0 then
				hrp.CFrame = hrp.CFrame + dir.Unit * (speed * dt)
			end
		end)
		Conns.Fly2Jump = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe then return end
			if input.KeyCode == Enum.KeyCode.Space and States.Fly2.Enabled and not States.Fly2.Flying then
				States.Fly2.Flying = true
				Gui.Fly2ToggleBtn.Text = "停止飞行"
				Gui.Fly2ToggleBtn.BackgroundColor3 = Color3.fromRGB(0,150,80)
			end
		end)
	else
		unbind("Fly2"); unbind("Fly2Jump")
		Gui.Fly2Panel.Visible = false
		States.Fly2.Flying = false
		Gui.Fly2ToggleBtn.Text = "开启飞行"
		Gui.Fly2ToggleBtn.BackgroundColor3 = Color3.fromRGB(110, 70, 190)
		if humanoid then enableMovementStates(humanoid) end
	end
end

Updaters.FreeMove = function()
	if States.FreeMove.Enabled then
		if Conns.FreeMove then return end
		States.Fly1.Enabled = false; Updaters.Fly1()
		States.Fly2.Enabled = false; Updaters.Fly2()
		States.TpWalk.Enabled = false; Updaters.TpWalk()
		Gui.FreeMoveFrame.Visible = true
		Conns.FreeMove = RunService.RenderStepped:Connect(function()
			if not States.FreeMove.Enabled then return end
			if not hrp or not humanoid then return end
			if not FreeMoveBG or not FreeMoveBG.Parent then
				FreeMoveBG = Instance.new("BodyGyro")
				FreeMoveBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
				FreeMoveBG.P = 9e4
				FreeMoveBG.D = 100
				FreeMoveBG.CFrame = hrp.CFrame
				FreeMoveBG.Parent = hrp
				FreeMoveBV = Instance.new("BodyVelocity")
				FreeMoveBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
				FreeMoveBV.P = 1e5
				FreeMoveBV.Velocity = Vector3.zero
				FreeMoveBV.Parent = hrp
				humanoid.PlatformStand = true
			end
			local speed = math.clamp(States.FreeMove.Value or 50, 1, 500)
			local moveZ = (Gui.FreeUpState() and 1 or 0) + (Gui.FreeDownState() and -1 or 0)
			local moveX = (Gui.FreeRightState() and 1 or 0) + (Gui.FreeLeftState() and -1 or 0)
			local moveY = (Gui.FreeFlyUpState() and 1 or 0) + (Gui.FreeFlyDownState() and -1 or 0)
			local camCF = camera.CFrame
			local rightVec = camCF.RightVector
			local forwardVec = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
			if forwardVec.Magnitude < 0.01 then forwardVec = Vector3.new(0, 0, -1) end
			forwardVec = forwardVec.Unit
			local offset = rightVec * moveX + Vector3.new(0, moveY, 0) + forwardVec * moveZ
			if offset.Magnitude > 0 then offset = offset.Unit end
			FreeMoveBV.Velocity = offset * speed
			if forwardVec.Magnitude > 0.01 then
				FreeMoveBG.CFrame = CFrame.new(hrp.Position, hrp.Position + forwardVec)
			end
		end)
	else
		unbind("FreeMove")
		Gui.FreeMoveFrame.Visible = false
		if FreeMoveBG then pcall(function() FreeMoveBG:Destroy() end); FreeMoveBG = nil end
		if FreeMoveBV then pcall(function() FreeMoveBV:Destroy() end); FreeMoveBV = nil end
		if humanoid then humanoid.PlatformStand = false end
	end
end

Updaters.Noclip = function()
	if States.Noclip.Enabled then
		if Conns.Noclip then return end
		NoclipCache = {}
		Conns.Noclip = RunService.Stepped:Connect(function()
			if not States.Noclip.Enabled then return end
			if not character then return end
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					if NoclipCache[part] == nil then NoclipCache[part] = part.CanCollide end
					part.CanCollide = false
				end
			end
		end)
	else
		unbind("Noclip")
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") and NoclipCache[part] ~= nil then
					part.CanCollide = NoclipCache[part]
				end
			end
		end
		NoclipCache = {}
	end
end

Updaters.BunnyHop = function()
	if States.BunnyHop.Enabled then
		if Conns.BunnyJump then return end
		BunnyCount = 0
		Conns.BunnyJump = UserInputService.JumpRequest:Connect(function()
			if not States.BunnyHop.Enabled then return end
			if not humanoid then return end
			BunnyCount = BunnyCount + 1
			local bonus = math.min(BunnyCount * States.BunnyHop.Value, 300)
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			task.delay(0.05, function()
				if hrp then
					local vel = hrp.AssemblyLinearVelocity
					hrp.AssemblyLinearVelocity = Vector3.new(vel.X, math.min(50 + bonus, 300), vel.Z)
				end
			end)
		end)
		Conns.BunnyLand = humanoid and humanoid.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				BunnyCount = 0
			end
		end) or nil
	else
		unbind("BunnyJump"); unbind("BunnyLand")
		BunnyCount = 0
	end
end

Updaters.AutoRun = function()
	if States.AutoRun.Enabled then
		if Conns.AutoRun then return end
		Conns.AutoRun = RunService.Heartbeat:Connect(function()
			if not States.AutoRun.Enabled then return end
			if humanoid then humanoid:Move(Vector3.new(0,0,-1), true) end
		end)
	else
		unbind("AutoRun")
	end
end

Updaters.SuperJump = function()
	if States.SuperJump.Enabled then
		if Conns.SuperJump then return end
		Conns.SuperJump = UserInputService.JumpRequest:Connect(function()
			if not States.SuperJump.Enabled then return end
			if hrp then
				local vel = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(vel.X, States.SuperJump.Value, vel.Z)
			end
		end)
	else
		unbind("SuperJump")
	end
end

Updaters.WallClimb = function()
	if States.WallClimb.Enabled then
		if Conns.WallClimb then return end
		Conns.WallClimb = RunService.Heartbeat:Connect(function()
			if not States.WallClimb.Enabled then return end
			if not hrp then return end
			local ray = Ray.new(hrp.Position, hrp.CFrame.LookVector * 2)
			local hit = Workspace:FindPartOnRay(ray, character)
			if hit then
				local vel = hrp.AssemblyLinearVelocity
				hrp.AssemblyLinearVelocity = Vector3.new(vel.X, States.WallClimb.Value, vel.Z)
			end
		end)
	else
		unbind("WallClimb")
	end
end

Updaters.GodMode = function()
	if States.GodMode.Enabled then
		if Conns.God then return end
		Conns.God = RunService.Heartbeat:Connect(function()
			if not States.GodMode.Enabled then return end
			if humanoid then
				humanoid.Health = humanoid.MaxHealth
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			end
			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then part.CanTouch = false end
				end
			end
		end)
	else
		unbind("God")
		if humanoid then humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanTouch = true end
			end
		end
	end
end

Updaters.NoCooldown = function()
	if States.NoCooldown.Enabled then
		if Conns.NoCooldown then return end
		NoCdLast = 0
		Conns.NoCooldown = RunService.Heartbeat:Connect(function()
			if not States.NoCooldown.Enabled then return end
			local now = tick()
			if now - NoCdLast < 0.5 then return end
			NoCdLast = now
			local function zeroTool(tool)
				if not tool then return end
				for _, obj in pairs(tool:GetDescendants()) do
					if obj:IsA("IntValue") or obj:IsA("NumberValue") or obj:IsA("DoubleConstrainedValue") then
						local n = obj.Name:lower()
						if n:find("cool") or n:find("cd") or n:find("delay") or n:find("interval") then
							obj.Value = 0
						end
					end
				end
			end
			local tool = character and character:FindFirstChildOfClass("Tool")
			zeroTool(tool)
			for _, t in pairs(player.Backpack:GetChildren()) do
				if t:IsA("Tool") then zeroTool(t) end
			end
		end)
	else
		unbind("NoCooldown")
	end
end

Updaters.InfiniteAmmo = function()
	if States.InfiniteAmmo.Enabled then
		if Conns.InfAmmo then return end
		InfAmmoLast = 0
		Conns.InfAmmo = RunService.Heartbeat:Connect(function()
			if not States.InfiniteAmmo.Enabled then return end
			local now = tick()
			if now - InfAmmoLast < 0.5 then return end
			InfAmmoLast = now
			local function refill(tool)
				if not tool then return end
				for _, obj in pairs(tool:GetDescendants()) do
					if obj:IsA("IntValue") or obj:IsA("NumberValue") then
						local n = obj.Name:lower()
						if n:find("ammo") or n:find("bullet") or n:find("mag") or n:find("clip") or n:find("reserve") then
							obj.Value = 9999
						end
					end
				end
			end
			local tool = character and character:FindFirstChildOfClass("Tool")
			refill(tool)
			for _, t in pairs(player.Backpack:GetChildren()) do
				if t:IsA("Tool") then refill(t) end
			end
		end)
	else
		unbind("InfAmmo")
	end
end

Updaters.AutoAttack = function()
	if States.AutoAttack.Enabled then
		if Conns.AutoAtk then return end
		Conns.AutoAtk = RunService.Heartbeat:Connect(function()
			if not States.AutoAttack.Enabled then return end
			tryFireTool()
		end)
	else
		unbind("AutoAtk")
	end
end

Updaters.KillAura = function()
	if States.KillAura.Enabled then
		if Conns.KillAura then return end
		local tickCount = 0
		Conns.KillAura = RunService.Heartbeat:Connect(function()
			if not States.KillAura.Enabled then return end
			if not hrp then return end
			tickCount = tickCount + 1
			if tickCount % 2 ~= 0 then return end
			local range = States.KillAura.Value
			updateTargetCache()
			for _, e in ipairs(TargetCache.All) do
				if e.Hrp and (hrp.Position - e.Hrp.Position).Magnitude <= range then
					if e.IsPlayer then tryFireTool() end
					pcall(function() e.Hum.Health = 0 end)
				end
			end
		end)
	else
		unbind("KillAura")
	end
end

Updaters.Aimbot = function()
	if States.Aimbot.Enabled then
		if Conns.Aimbot then return end
		Conns.Aimbot = RunService.Heartbeat:Connect(function()
			if not States.Aimbot.Enabled then return end
			if not hrp then return end
			local closest, minDist = nil, math.huge
			updateTargetCache()
			for _, e in ipairs(TargetCache.Players) do
				if e.Hrp then
					local d = (hrp.Position - e.Hrp.Position).Magnitude
					if d < minDist then minDist = d; closest = e.Hrp end
				end
			end
			if closest then
				camera.CFrame = CFrame.new(camera.CFrame.Position, closest.Position)
			end
		end)
	else
		unbind("Aimbot")
	end
end

Updaters.RapidFire = function()
	if States.RapidFire.Enabled then
		if Conns.Rapid then return end
		Conns.Rapid = RunService.Heartbeat:Connect(function()
			if not States.RapidFire.Enabled then return end
			tryFireTool()
		end)
	else
		unbind("Rapid")
	end
end

Updaters.NightVision = function()
	if States.NightVision.Enabled then
		if Conns.Night then return end
		OrigLighting.Brightness = Lighting.Brightness
		OrigLighting.ClockTime = Lighting.ClockTime
		OrigLighting.FogEnd = Lighting.FogEnd
		OrigLighting.GlobalShadows = Lighting.GlobalShadows
		Conns.Night = RunService.Heartbeat:Connect(function()
			if not States.NightVision.Enabled then return end
			Lighting.Brightness = 10
			Lighting.ClockTime = 14
			Lighting.FogEnd = 100000
			Lighting.GlobalShadows = false
		end)
	else
		unbind("Night")
		Lighting.Brightness = OrigLighting.Brightness or 1
		Lighting.ClockTime = OrigLighting.ClockTime or 12
		Lighting.FogEnd = OrigLighting.FogEnd or 1000
		Lighting.GlobalShadows = OrigLighting.GlobalShadows ~= false
	end
end

Updaters.FullBright = function()
	if States.FullBright.Enabled then
		if Conns.Bright then return end
		Conns.Bright = RunService.Heartbeat:Connect(function()
			if not States.FullBright.Enabled then return end
			Lighting.Brightness = 100
			Lighting.GlobalShadows = false
			for _, v in pairs(Lighting:GetDescendants()) do
				if v:IsA("PostEffect") then v.Enabled = false end
			end
		end)
	else
		unbind("Bright")
		Lighting.Brightness = 1
		Lighting.GlobalShadows = true
	end
end

local EspFolder = Instance.new("Folder")
EspFolder.Name = "NinjaESP"; EspFolder.Parent = ScreenGui
Updaters.ESP = function()
	if States.ESP.Enabled then
		if Conns.ESP then return end
		local tickCount = 0
		Conns.ESP = RunService.RenderStepped:Connect(function()
			if not States.ESP.Enabled then return end
			tickCount = tickCount + 1
			if tickCount % 2 ~= 0 then return end
			for _, v in pairs(EspFolder:GetChildren()) do v:Destroy() end
			updateTargetCache()
			for _, e in ipairs(TargetCache.Players) do
				local char = e.Obj
				local hrp2 = e.Hrp
				if not hrp2 then continue end
				if not inRenderRange(hrp2.Position) then continue end
				local minV = Vector3.new(math.huge, math.huge, math.huge)
				local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
				local hasPart = false
				for _, part in pairs(char:GetChildren()) do
					if part:IsA("BasePart") then
						hasPart = true
						local pos = part.Position
						minV = Vector3.new(math.min(minV.X, pos.X), math.min(minV.Y, pos.Y), math.min(minV.Z, pos.Z))
						maxV = Vector3.new(math.max(maxV.X, pos.X), math.max(maxV.Y, pos.Y), math.max(maxV.Z, pos.Z))
					end
				end
				if not hasPart then continue end
				local min2d = Vector2.new(math.huge, math.huge)
				local max2d = Vector2.new(-math.huge, -math.huge)
				local visible = false
				local pts = {
					Vector3.new(minV.X, minV.Y, minV.Z), Vector3.new(minV.X, maxV.Y, minV.Z),
					Vector3.new(maxV.X, minV.Y, minV.Z), Vector3.new(maxV.X, maxV.Y, minV.Z),
					Vector3.new(minV.X, minV.Y, maxV.Z), Vector3.new(minV.X, maxV.Y, maxV.Z),
					Vector3.new(maxV.X, minV.Y, maxV.Z), Vector3.new(maxV.X, maxV.Y, maxV.Z),
				}
				for _, pt in ipairs(pts) do
					local sp = camera:WorldToViewportPoint(pt)
					if sp.Z >= 0 then
						visible = true
						local p2 = Vector2.new(sp.X, sp.Y)
						min2d = Vector2.new(math.min(min2d.X, p2.X), math.min(min2d.Y, p2.Y))
						max2d = Vector2.new(math.max(max2d.X, p2.X), math.max(max2d.Y, p2.Y))
					end
				end
				if not visible then continue end
				local size = max2d - min2d
				if size.X < 3 or size.Y < 3 then continue end
				local box = Instance.new("Frame")
				box.Size = UDim2.new(0, size.X, 0, size.Y)
				box.Position = UDim2.new(0, min2d.X, 0, min2d.Y)
				box.BackgroundTransparency = 1
				box.BorderSizePixel = 0
				box.Parent = EspFolder
				local stroke = Instance.new("UIStroke")
				stroke.Color = getPartColor(e.Plr.Name .. "esp")
				stroke.Thickness = 1.5
				stroke.Parent = box
				local nl = Instance.new("TextLabel")
				nl.Size = UDim2.new(1,0,0,18); nl.Position = UDim2.new(0,0,0,-18)
				nl.BackgroundTransparency = 1; nl.Text = e.Plr.Name
				nl.TextColor3 = Color3.fromRGB(255,255,255); nl.TextSize = 11
				nl.Font = Enum.Font.GothamBold; nl.Parent = box
			end
		end)
	else
		unbind("ESP")
		for _, v in pairs(EspFolder:GetChildren()) do v:Destroy() end
	end
end

local function isCharPart(v)
	if character and v:IsDescendantOf(character) then return true end
	for _, p in pairs(Players:GetPlayers()) do
		if p.Character and v:IsDescendantOf(p.Character) then return true end
	end
	return false
end
Updaters.Xray = function()
	if States.Xray.Enabled then
		if Conns.Xray then return end
		local function applyXray()
			for _, v in pairs(Workspace:GetDescendants()) do
				if v:IsA("BasePart") then
					v.LocalTransparencyModifier = isCharPart(v) and 0 or 0.5
				end
			end
		end
		applyXray()
		Conns.Xray = Workspace.DescendantAdded:Connect(function(v)
			if States.Xray.Enabled and v:IsA("BasePart") then
				v.LocalTransparencyModifier = isCharPart(v) and 0 or 0.5
			end
		end)
		Conns.XrayTimer = RunService.Heartbeat:Connect(function()
			if not States.Xray.Enabled then return end
			XrayTick = XrayTick + 1
			if XrayTick >= 180 then
				XrayTick = 0
				applyXray()
			end
		end)
	else
		unbind("Xray"); unbind("XrayTimer")
		for _, v in pairs(Workspace:GetDescendants()) do
			if v:IsA("BasePart") then v.LocalTransparencyModifier = 0 end
		end
	end
end

Updaters.NoFog = function()
	if States.NoFog.Enabled then
		if Conns.NoFog then return end
		Conns.NoFog = RunService.Heartbeat:Connect(function()
			if not States.NoFog.Enabled then return end
			Lighting.FogEnd = 100000; Lighting.FogStart = 0
		end)
	else
		unbind("NoFog")
	end
end

local FilterFrame = Instance.new("Frame")
FilterFrame.Size = UDim2.new(1,0,1,0); FilterFrame.BackgroundTransparency = 1
FilterFrame.Visible = false; FilterFrame.ZIndex = 9000; FilterFrame.Parent = ScreenGui
Updaters.ColorFilter = function()
	if States.ColorFilter.Enabled then
		FilterFrame.Visible = true
		local c = tostring(States.ColorFilter.Value):lower()
		local colorMap = {
			red = Color3.fromRGB(255,0,0), ["红"] = Color3.fromRGB(255,0,0),
			blue = Color3.fromRGB(0,0,255), ["蓝"] = Color3.fromRGB(0,0,255),
			green = Color3.fromRGB(0,255,0), ["绿"] = Color3.fromRGB(0,255,0),
			pink = Color3.fromRGB(255,0,255), ["粉"] = Color3.fromRGB(255,0,255),
			yellow = Color3.fromRGB(255,255,0), ["黄"] = Color3.fromRGB(255,255,0),
			cyan = Color3.fromRGB(0,255,255), ["青"] = Color3.fromRGB(0,255,255),
		}
		FilterFrame.BackgroundColor3 = colorMap[c] or Color3.fromRGB(255,100,100)
		FilterFrame.BackgroundTransparency = 0.3
	else
		FilterFrame.Visible = false
	end
end

local OrigCamType = camera.CameraType
Updaters.FreeCam = function()
	if States.FreeCam.Enabled then
		if Conns.FreeCam then return end
		OrigCamType = camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		local camPos = camera.CFrame.Position
		local camRot = camera.CFrame.Rotation
		Conns.FreeCam = RunService.Heartbeat:Connect(function(dt)
			if not States.FreeCam.Enabled then return end
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
			if move.Magnitude > 0 then camPos = camPos + move.Unit * 50 * dt end
			local delta = UserInputService:GetMouseDelta()
			camRot = camRot * CFrame.Angles(math.rad(-delta.Y*0.3), math.rad(-delta.X*0.3), 0)
			camera.CFrame = CFrame.new(camPos) * camRot
		end)
	else
		unbind("FreeCam")
		camera.CameraType = OrigCamType
	end
end

Updaters.AutoClicker = function()
	if States.AutoClicker.Enabled then
		if Conns.ClickerColor then return end
		Conns.ClickerColor = RunService.Heartbeat:Connect(function()
			if not States.AutoClicker.Enabled then return end
			for i, ball in ipairs(Gui.ClickerBalls) do
				if ball and ball.Visible then
					ball.BackgroundColor3 = getPartColor("clicker" .. i)
					local stroke = ball:FindFirstChildOfClass("UIStroke")
					if stroke then stroke.Color = getPartColor("clicker" .. i .. "s") end
				end
			end
		end)
	else
		unbind("ClickerColor")
		for _, ball in ipairs(Gui.ClickerBalls) do
			if ball then ball.Visible = false end
		end
	end
end

local ClickerThread
Updaters.ClickerStart = function()
	if States.ClickerStart.Enabled then
		if ClickerThread then return end
		ClickerThread = task.spawn(function()
			local inset = getGuiInsetOffset()
			while States.ClickerStart.Enabled do
				for _, ball in ipairs(Gui.ClickerBalls) do
					if ball and ball.Visible and ball.Parent then
						local pos = ball.AbsolutePosition + ball.AbsoluteSize / 2
						local clickPos = Vector2.new(pos.X + inset.X, pos.Y + inset.Y)
						pcall(function()
							VirtualInputManager:SendMouseButtonEvent(clickPos.X, clickPos.Y, 0, true, game, 0)
							task.wait(0.01)
							VirtualInputManager:SendMouseButtonEvent(clickPos.X, clickPos.Y, 0, false, game, 0)
						end)
					end
				end
				task.wait(math.max(States.AutoClicker.Value or 10, 1) / 1000)
			end
			ClickerThread = nil
		end)
	else
		ClickerThread = nil
	end
end

Updaters.ClickerMulti = function()
	if States.ClickerMulti.Enabled then
		rebuildClickerBalls(States.ClickerMulti.ClickerCount or 2)
	else
		rebuildClickerBalls(2)
		for _, ball in ipairs(Gui.ClickerBalls) do
			ball.Visible = States.AutoClicker.Enabled
		end
	end
	for _, ball in ipairs(Gui.ClickerBalls) do
		ball.Visible = States.AutoClicker.Enabled
	end
end

Updaters.FastInteract = function()
	if States.FastInteract.Enabled then
		if Conns.FastInt then return end
		Conns.FastInt = RunService.Heartbeat:Connect(function()
			if not States.FastInteract.Enabled then return end
			for _, p in pairs(Workspace:GetDescendants()) do
				if p:IsA("ProximityPrompt") then p.HoldDuration = 0 end
			end
		end)
	else
		unbind("FastInt")
	end
end

local AutoSaveThread, AntiAfkThread
local function saveConfig()
	local success, data = pcall(function()
		local save = {}
		for k, v in pairs(States) do
			if type(v) == "table" then
				save[k] = {}
				for kk, vv in pairs(v) do
					if type(vv) ~= "function" and type(vv) ~= "userdata" and type(vv) ~= "Instance" then
						save[k][kk] = vv
					end
				end
			end
		end
		save.__SavedScripts = SavedScripts
		return HttpService:JSONEncode(save)
	end)
	if success then
		pcall(function() writefile("NinjaHubV6_2_Config.json", data) end)
		pcall(function()
			if player:FindFirstChild("NinjaHubConfig") then
				player.NinjaHubConfig.Value = data
			else
				local s = Instance.new("StringValue")
				s.Name = "NinjaHubConfig"
				s.Value = data
				s.Parent = player
			end
		end)
	end
end
if CoreGui and CoreGui.ChildRemoved then
	CoreGui.ChildRemoved:Connect(function(child)
		if child == ScreenGui then saveConfig() end
	end)
end
local function loadConfig()
	local data = nil
	pcall(function() data = readfile("NinjaHubV6_2_Config.json") end)
	if not data or #data == 0 then
		pcall(function()
			local s = player:FindFirstChild("NinjaHubConfig")
			if s then data = s.Value end
		end)
	end
	if data then
		pcall(function()
			local decoded = HttpService:JSONDecode(data)
			for k, v in pairs(decoded) do
				if k == "__SavedScripts" and type(v) == "table" then
					for sk, sv in pairs(v) do
						if SavedScripts[sk] and type(sv) == "table" then
							SavedScripts[sk] = sv
						end
					end
				elseif States[k] and type(v) == "table" then
					for kk, vv in pairs(v) do
						if States[k][kk] ~= nil and type(vv) ~= "userdata" and type(vv) ~= "Instance" then
							States[k][kk] = vv
						end
					end
				end
			end
		end)
	end
end

Updaters.AutoSave = function()
	if States.AutoSave.Enabled then
		if AutoSaveThread then return end
		saveConfig()
		AutoSaveThread = task.spawn(function()
			while States.AutoSave.Enabled do
				saveConfig()
				task.wait(15)
			end
			AutoSaveThread = nil
		end)
	else
		AutoSaveThread = nil
	end
end

Updaters.AntiAfk = function()
	if States.AntiAfk.Enabled then
		if AntiAfkThread then return end
		AntiAfkThread = task.spawn(function()
			while States.AntiAfk.Enabled do
				pcall(function()
					if hrp then
						local bv = Instance.new("BodyVelocity")
						bv.Velocity = Vector3.zero; bv.MaxForce = Vector3.zero
						bv.Parent = hrp; task.wait(0.1); bv:Destroy()
					end
				end)
				task.wait(60)
			end
			AntiAfkThread = nil
		end)
	else
		AntiAfkThread = nil
	end
end

Updaters.ShowFps = function()
	if States.ShowFps.Enabled then
		Gui.InfoLabel.Visible = true
		if Conns.FPS then return end
		Conns.FPS = RunService.Heartbeat:Connect(function()
			FpsCount = FpsCount + 1
			local now = tick()
			if now - FpsLast >= 1 then
				local fps = FpsCount
				local txt = "FPS: " .. fps
				if States.ShowCoords.Enabled and hrp then
					local pos = hrp.Position
					txt = txt .. string.format(" | %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
				end
				animateSwap(Gui.InfoLabel, txt)
				Gui.InfoLabel.TextColor3 = getPartColor("info")
				FpsCount = 0; FpsLast = now
			end
		end)
	else
		unbind("FPS")
		if not States.ShowCoords.Enabled then Gui.InfoLabel.Visible = false end
	end
end

Updaters.ShowCoords = function()
	if States.ShowCoords.Enabled then
		Gui.InfoLabel.Visible = true
		if Conns.Coords then return end
		Conns.Coords = RunService.Heartbeat:Connect(function()
			if not States.ShowCoords.Enabled then return end
			if hrp then
				local pos = hrp.Position
				local txt = string.format("坐标: %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
				if States.ShowFps.Enabled then
					txt = (Gui.InfoLabel.Text:match("FPS: %d+") or "FPS: --") .. " | " .. txt
				end
				animateSwap(Gui.InfoLabel, txt)
				Gui.InfoLabel.TextColor3 = getPartColor("info")
			end
		end)
	else
		unbind("Coords")
		if not States.ShowFps.Enabled then Gui.InfoLabel.Visible = false end
	end
end

Updaters.TimeOfDay = function()
	if States.TimeOfDay.Enabled then
		if Conns.Time then return end
		Conns.Time = RunService.Heartbeat:Connect(function()
			if not States.TimeOfDay.Enabled then return end
			Lighting.ClockTime = States.TimeOfDay.Value
		end)
	else
		unbind("Time")
	end
end

Updaters.SitAnywhere = function()
	if States.SitAnywhere.Enabled then
		if Conns.Sit then return end
		Conns.Sit = UserInputService.InputBegan:Connect(function(input)
			if input.KeyCode == Enum.KeyCode.X and States.SitAnywhere.Enabled then
				if humanoid then humanoid.Sit = true end
			end
		end)
	else
		unbind("Sit")
	end
end

Updaters.DangerWarning = function()
	if States.DangerWarning.Enabled then
		if Conns.Danger then return end
		local tickCount = 0
		Conns.Danger = RunService.Heartbeat:Connect(function()
			if not States.DangerWarning.Enabled then return end
			tickCount = tickCount + 1
			if tickCount % 3 ~= 0 then return end
			if not hrp then Gui.WarnLabel.Visible = false; return end
			local range = States.DangerWarning.Value or 50
			local closest, closestDist = nil, math.huge
			updateTargetCache()
			for _, e in ipairs(TargetCache.All) do
				if e.Hrp then
					local d = (hrp.Position - e.Hrp.Position).Magnitude
					if d < closestDist then closestDist = d; closest = e end
				end
			end
			if closest and closestDist <= range then
				local name = closest.IsPlayer and closest.Plr.Name or closest.Obj.Name
				animateSwap(Gui.WarnLabel, string.format("⚠ %s 接近中! (%.0fm)", name, closestDist))
				Gui.WarnLabel.Visible = true
			else
				Gui.WarnLabel.Visible = false
			end
		end)
	else
		unbind("Danger")
		Gui.WarnLabel.Visible = false
	end
end

Updaters.AutoFire = function()
	if States.AutoFire.Enabled then
		if Conns.AutoFire then return end
		local tickCount = 0
		Conns.AutoFire = RunService.Heartbeat:Connect(function()
			if not States.AutoFire.Enabled then return end
			if not States.AimbotV2.Enabled then return end
			tickCount = tickCount + 1
			if tickCount % 3 ~= 0 then return end
			local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
			local radius = States.AimbotV2.CircleSize / 2
			updateTargetCache()
			local targets = {}
			local ct = States.AimbotV2.CustomTarget
			if ct and ct.Parent then
				table.insert(targets, ct)
			else
				if States.AimbotV2.AimPlayer then
					for _, e in ipairs(TargetCache.Players) do table.insert(targets, e.Obj) end
				end
				if States.AimbotV2.AimNpc then
					for _, e in ipairs(TargetCache.Npcs) do table.insert(targets, e.Obj) end
				end
			end
			for _, char in ipairs(targets) do
				local aimPart = char:FindFirstChild(States.AimbotV2.AimPart) or char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
				if aimPart then
					local sp, onScreen = camera:WorldToViewportPoint(aimPart.Position)
					if onScreen and sp.Z >= 0 then
						local dist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
						if dist <= radius then
							tryFireTool()
							break
						end
					end
				end
			end
		end)
	else
		unbind("AutoFire")
	end
end

Updaters.NpcDisplay = function()
	if States.NpcDisplay.Enabled then
		if Conns.NpcDisp then return end
		local tickCount = 0
		Conns.NpcDisp = RunService.RenderStepped:Connect(function()
			if not States.NpcDisplay.Enabled then return end
			tickCount = tickCount + 1
			if tickCount % 2 ~= 0 then return end
			clearBeams(BeamPools.Npc)
			clearPool(Pools.Npc.Dots)
			updateTargetCache()
			local count = 0
			for _, e in ipairs(TargetCache.Npcs) do
				if count >= 50 then break end
				local model = e.Obj
				if e.Hrp and not inRenderRange(e.Hrp.Position) then continue end
				local skeleton = getSkeleton(model)
				for _, pair in ipairs(skeleton) do
					local p1 = model:FindFirstChild(pair[1])
					local p2 = model:FindFirstChild(pair[2])
					if p1 and p2 and States.NpcDisplay.ShowBones then
						drawBone(BeamPools.Npc, p1, p2, getPartColor(model.Name .. ":" .. pair[1]))
					end
				end
				for _, partName in ipairs({"Head","UpperTorso","LowerTorso","Torso","LeftUpperArm","RightUpperArm","LeftUpperLeg","RightUpperLeg"}) do
					local part = model:FindFirstChild(partName)
					if part and part:IsA("BasePart") then
						local sp, onScreen = worldToScreen(part.Position)
						if onScreen then
							local shouldShow = false
							if partName == "Head" and States.NpcDisplay.ShowHead then shouldShow = true end
							if (partName == "UpperTorso" or partName == "LowerTorso" or partName == "Torso") and States.NpcDisplay.ShowTorso then shouldShow = true end
							if (partName:find("Arm") or partName:find("Leg")) and States.NpcDisplay.ShowLimbs then shouldShow = true end
							if shouldShow then
								local dot = getFromPool(Pools.Npc.Dots, RenderFolder)
								dot.Size = UDim2.new(0,6,0,6)
								dot.Position = UDim2.new(0,sp.X-3,0,sp.Y-3)
								dot.BackgroundColor3 = getPartColor(model.Name .. ":" .. partName)
								dot.Parent = RenderFolder
							end
						end
					end
				end
				count = count + 1
			end
		end)
	else
		unbind("NpcDisp")
		clearBeams(BeamPools.Npc)
		clearPool(Pools.Npc.Dots)
	end
end

Updaters.PlayerDisplay = function()
	if States.PlayerDisplay.Enabled then
		if Conns.PlayerDisp then return end
		Conns.PlayerDisp = RunService.RenderStepped:Connect(function()
			if not States.PlayerDisplay.Enabled then return end
			clearBeams(BeamPools.Player)
			clearPool(Pools.Player.Dots)
			clearPool(Pools.Player.Texts)
			updateTargetCache()
			for _, e in ipairs(TargetCache.Players) do
				local char = e.Obj
				local p = e.Plr
				local hum = e.Hum
				local targetHrp = e.Hrp
				if not targetHrp then continue end
				if not inRenderRange(targetHrp.Position) then continue end
				local skeleton = getSkeleton(char)
				for _, pair in ipairs(skeleton) do
					local p1 = char:FindFirstChild(pair[1])
					local p2 = char:FindFirstChild(pair[2])
					if p1 and p2 and States.PlayerDisplay.ShowBones then
						drawBone(BeamPools.Player, p1, p2, getPartColor(p.Name .. ":" .. pair[1]))
					end
				end
				local sp, onScreen = worldToScreen(targetHrp.Position)
				if onScreen then
					local txtLines = {}
					if States.PlayerDisplay.ShowName then table.insert(txtLines, p.Name) end
					if States.PlayerDisplay.ShowHealth and hum then table.insert(txtLines, string.format("❤ %.0f", hum.Health)) end
					if States.PlayerDisplay.ShowDistance and hrp and targetHrp then table.insert(txtLines, string.format("%.1fm", (hrp.Position - targetHrp.Position).Magnitude)) end
					if #txtLines > 0 then
						local label = getFromPool(Pools.Player.Texts, RenderFolder)
						label.Size = UDim2.new(0,130,0,44)
						label.Position = UDim2.new(0, sp.X-65, 0, sp.Y-58)
						label.Text = table.concat(txtLines, "\n")
						label.TextColor3 = getPartColor(p.Name .. "info")
						label.TextSize = 11
						label.Font = Enum.Font.GothamBold
						label.Parent = RenderFolder
					end
					for _, partName in ipairs({"Head","UpperTorso","LowerTorso","Torso"}) do
						local part = char:FindFirstChild(partName)
						if part and part:IsA("BasePart") then
							local psp, pon = worldToScreen(part.Position)
							if pon then
								local shouldShow = false
								if partName == "Head" and States.PlayerDisplay.ShowHead then shouldShow = true end
								if (partName == "UpperTorso" or partName == "LowerTorso" or partName == "Torso") and States.PlayerDisplay.ShowTorso then shouldShow = true end
								if shouldShow then
									local dot = getFromPool(Pools.Player.Dots, RenderFolder)
									dot.Size = UDim2.new(0,6,0,6)
									dot.Position = UDim2.new(0,psp.X-3,0,psp.Y-3)
									dot.BackgroundColor3 = getPartColor(p.Name .. ":" .. partName)
									dot.Parent = RenderFolder
								end
							end
						end
					end
				end
			end
		end)
	else
		unbind("PlayerDisp")
		clearBeams(BeamPools.Player)
		clearPool(Pools.Player.Dots)
		clearPool(Pools.Player.Texts)
	end
end

Updaters.BoxCreature = function()
	if States.BoxCreature.Enabled then
		if Conns.BoxCreature then return end
		Conns.BoxCreature = RunService.RenderStepped:Connect(function()
			if not States.BoxCreature.Enabled then return end
			clearPool(Pools.Box.Lines)
			clearAdorns(AdornPools.Box)
			clearAdorns(AdornPools.Hitbox)
			updateTargetCache()
			local maxD = States.BoxCreature.MaxDistance or 0
			local function drawFor(char, key)
				local hrp2 = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("Head")
				if hrp2 and not inRenderRange(hrp2.Position) then return end
				if maxD ~= 0 and hrp and hrp2 then
					if (hrp.Position - hrp2.Position).Magnitude > maxD then return end
				end
				if States.BoxCreature.ShowHitbox then
					drawHitbox3D(AdornPools.Hitbox, char, Color3.fromRGB(255,255,255))
				elseif States.BoxCreature.BoxMode == "3D" then
					drawBox3D(AdornPools.Box, char, getPartColor(key .. "box"))
				else
					drawBox2D(Pools.Box.Lines, RenderFolder, char, getPartColor(key .. "box"))
				end
			end
			if States.BoxCreature.BoxPlayer then
				for _, e in ipairs(TargetCache.Players) do drawFor(e.Obj, e.Obj.Name) end
			end
			if States.BoxCreature.BoxNpc then
				for _, e in ipairs(TargetCache.Npcs) do drawFor(e.Obj, e.Obj.Name) end
			end
			if States.BoxCreature.BoxOther then
				for _, m in ipairs(TargetCache.Others) do drawFor(m, m.Name) end
			end
		end)
	else
		unbind("BoxCreature")
		clearPool(Pools.Box.Lines)
		clearAdorns(AdornPools.Box)
		clearAdorns(AdornPools.Hitbox)
	end
end

Updaters.LineConnect = function()
	if States.LineConnect.Enabled then
		if Conns.LineConnect then return end
		Conns.LineConnect = RunService.RenderStepped:Connect(function()
			if not States.LineConnect.Enabled then return end
			clearBeams(BeamPools.Connect)
			updateTargetCache()
			local o = States.LineConnect.Origin or "Top"
			local maxD = States.LineConnect.MaxDistance or 0
			local offsetY = o == "Top" and 3 or (o == "Bottom" and -3 or 0)
			local origin = camera.CFrame:PointToWorldSpace(Vector3.new(0, offsetY, -6))
			local function drawLineTo(char, key)
				if not char then return end
				local endPos
				if States.BoxCreature.Enabled then
					local bcf = char:GetBoundingBox()
					if bcf then endPos = bcf.Position end
				end
				if not endPos then
					local head = char:FindFirstChild("Head")
					local hrp2 = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
					endPos = head and head.Position or (hrp2 and hrp2.Position or nil)
				end
				if not endPos then return end
				if not inRenderRange(endPos) then return end
				if maxD ~= 0 and hrp then
					if (hrp.Position - endPos).Magnitude > maxD then return end
				end
				if States.LineConnect.LineWallCheck then
					local checkPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
					if checkPart and isBlockedByWall(checkPart, char) then return end
				end
				draw3DLine(BeamPools.Connect, origin, endPos, getPartColor(key), BEAM_W)
			end
			if States.LineConnect.ConnectPlayer then
				for _, e in ipairs(TargetCache.Players) do drawLineTo(e.Obj, e.Plr.Name .. "line") end
			end
			if States.LineConnect.ConnectNpc then
				for _, e in ipairs(TargetCache.Npcs) do drawLineTo(e.Obj, e.Obj.Name .. "line") end
			end
			if States.LineConnect.ConnectOther then
				for _, m in ipairs(TargetCache.Others) do drawLineTo(m, m.Name .. "line") end
			end
		end)
	else
		unbind("LineConnect")
		clearBeams(BeamPools.Connect)
	end
end

Updaters.AimbotV2 = function()
	if States.AimbotV2.Enabled then
		if Conns.AimbotV2 then return end
		Gui.AimCircle.Visible = true
		AimClosest = nil
		AimScanTick = 0
		Conns.AimbotV2 = RunService.RenderStepped:Connect(function()
			if not States.AimbotV2.Enabled then return end
			local csize = States.AimbotV2.CircleSize
			Gui.AimCircle.Size = UDim2.new(0, csize, 0, csize)
			Gui.AimCircle.Position = UDim2.new(0.5, -csize/2, 0.5, -csize/2)
			if Gui.AimCircleStroke then Gui.AimCircleStroke.Color = getPartColor("aimcircle") end
			AimScanTick = AimScanTick + 1
			if AimScanTick % 3 == 0 then
				local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
				local radius = csize / 2
				local maxD = States.AimbotV2.MaxDistance or 0
				local best, bestDist = nil, math.huge
				updateTargetCache()
				local targets = {}
				local ct = States.AimbotV2.CustomTarget
				if ct and ct.Parent then
					local hum = ct:FindFirstChildOfClass("Humanoid")
					local hrp2 = ct:FindFirstChild("HumanoidRootPart") or ct:FindFirstChild("Torso")
					table.insert(targets, {Obj = ct, Hum = hum, Hrp = hrp2})
				else
					States.AimbotV2.CustomTarget = nil
					if States.AimbotV2.AimPlayer then
						for _, e in ipairs(TargetCache.Players) do table.insert(targets, e) end
					end
					if States.AimbotV2.AimNpc then
						for _, e in ipairs(TargetCache.Npcs) do table.insert(targets, e) end
					end
					if States.AimbotV2.AimOther then
						for _, m in ipairs(TargetCache.Others) do
							table.insert(targets, {Obj = m, Hum = nil, Hrp = m.PrimaryPart})
						end
					end
				end
				for _, e in ipairs(targets) do
					local char = e.Obj
					local hum = e.Hum
					if States.AimbotV2.AliveCheck and hum and hum.Health <= 0 then continue end
					if States.AimbotV2.TeamCheck and e.Plr and e.Plr.Team ~= nil and e.Plr.Team == player.Team then continue end
					local aimPart = char:FindFirstChild(States.AimbotV2.AimPart) or char:FindFirstChild("Head") or e.Hrp
					if not aimPart then continue end
					local sp, onScreen = worldToScreen(aimPart.Position)
					if not onScreen then continue end
					if (Vector2.new(sp.X, sp.Y) - center).Magnitude > radius then continue end
					if States.AimbotV2.WallCheck and isBlockedByWall(aimPart, char) then continue end
					local worldDist = hrp and (hrp.Position - aimPart.Position).Magnitude or 0
					if maxD ~= 0 and worldDist > maxD then continue end
					local aimPos = aimPart.Position
					if States.AimbotV2.Predict and aimPart:IsA("BasePart") then
						local dist3 = (camera.CFrame.Position - aimPos).Magnitude
						aimPos = aimPos + aimPart.AssemblyLinearVelocity * (dist3 / 1000)
					end
					if worldDist < bestDist then
						bestDist = worldDist
						best = aimPos
					end
				end
				AimClosest = best
			end
			if AimClosest then
				local targetCF = CFrame.new(camera.CFrame.Position, AimClosest)
				if States.AimbotV2.Smooth then
					camera.CFrame = camera.CFrame:Lerp(targetCF, States.AimbotV2.AimSpeed or 0.3)
				else
					camera.CFrame = targetCF
				end
			end
		end)
	else
		unbind("AimbotV2")
		Gui.AimCircle.Visible = false
		AimClosest = nil
	end
end

Updaters.ThermalESP = function()
	if States.ThermalESP.Enabled then
		if Conns.Thermal then return end
		Conns.Thermal = RunService.Heartbeat:Connect(function()
			if not States.ThermalESP.Enabled then return end
			updateTargetCache()
			local seen = {}
			for _, e in ipairs(TargetCache.Players) do
				local p = e.Plr
				local char = e.Obj
				if e.Hrp and not inRenderRange(e.Hrp.Position) then continue end
				seen[p] = true
				local h = ThermalHighlights[p]
				if not h or not h.Parent then
					h = Instance.new("Highlight")
					h.Name = "NH_Thermal"
					h.FillTransparency = 0.4
					h.OutlineTransparency = 0
					h.OutlineColor = Color3.fromRGB(255,255,255)
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Adornee = char
					h.Parent = char
					ThermalHighlights[p] = h
				end
				h.FillColor = getPartColor(p.Name .. "thermal")
			end
			for p, h in pairs(ThermalHighlights) do
				if not seen[p] then
					pcall(function() h:Destroy() end)
					ThermalHighlights[p] = nil
				end
			end
		end)
	else
		unbind("Thermal")
		for p, h in pairs(ThermalHighlights) do
			pcall(function() h:Destroy() end)
			ThermalHighlights[p] = nil
		end
	end
end

Updaters.AdvancedESP = function()
	if States.AdvancedESP.Enabled then
		if Conns.AdvESP then return end
		local tickCount = 0
		Conns.AdvESP = RunService.RenderStepped:Connect(function()
			if not States.AdvancedESP.Enabled then return end
			tickCount = tickCount + 1
			if tickCount % 2 ~= 0 then return end
			clearPool(Pools.Adv.Boxes)
			clearPool(Pools.Adv.Lines)
			clearPool(Pools.Adv.Texts)
			clearPool(Pools.Adv.Bars)
			clearBeams(BeamPools.Adv)
			local valid = {}
			local targets = {}
			updateTargetCache()
			for _, e in ipairs(TargetCache.Players) do
				table.insert(targets, {Char=e.Obj, Hum=e.Hum, IsPlayer=true, Plr=e.Plr})
			end
			for _, e in ipairs(TargetCache.Npcs) do
				table.insert(targets, {Char=e.Obj, Hum=e.Hum, IsPlayer=false})
			end
			local maxDist = States.AdvancedESP.MaxDistance or 300
			local camPos = camera.CFrame.Position
			for _, t in ipairs(targets) do
				local hum = t.Hum
				local char = t.Char
				if t.IsPlayer and States.AdvancedESP.TeamCheck and not States.AdvancedESP.ShowTeam
					and t.Plr.Team ~= nil and t.Plr.Team == player.Team then continue end
				local hrp2 = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
				local head = char:FindFirstChild("Head")
				if not hrp2 or not head then continue end
				if not inRenderRange(hrp2.Position) then continue end
				local sp, onScreen = worldToScreen(hrp2.Position)
				if not onScreen then continue end
				local dist = (hrp2.Position - camPos).Magnitude
				if maxDist ~= 0 and dist > maxDist then continue end
				if States.AdvancedESP.WallCheck and isBlockedByWall(hrp2, char) then continue end
				valid[char] = true
				if States.AdvancedESP.ShowChams then
					local h = AdvESPHighlights[char]
					if not h or not h.Parent then
						h = Instance.new("Highlight")
						h.Name = "NH_AdvESP"
						h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
						h.FillTransparency = 0.7
						h.OutlineTransparency = 0
						h.Adornee = char
						h.Parent = char
						AdvESPHighlights[char] = h
					end
					local c = getPartColor(char.Name .. "chams")
					h.FillColor = c
					h.OutlineColor = c
				end
				local headSp = worldToScreen(head.Position)
				local height = math.abs(headSp.Y - sp.Y) * 2.2
				local width = height * 0.6
				if States.AdvancedESP.ShowBox and height >= 5 then
					local boxX = sp.X - width/2
					local boxY = sp.Y - height/2
					local color = getPartColor(char.Name .. "adv")
					local thickness = States.AdvancedESP.BoxThickness or 1
					local function segH(x, y, w) drawHLine(Pools.Adv.Lines, RenderFolder, x, y, w, color, thickness) end
					local function segV(x, y, h) drawVLine(Pools.Adv.Lines, RenderFolder, x, y, h, color, thickness) end
					if States.AdvancedESP.BoxStyle == "Corner" then
						local cs = width * 0.2
						segH(boxX, boxY, cs); segV(boxX, boxY, cs)
						segH(boxX + width - cs, boxY, cs); segV(boxX + width, boxY, cs)
						segH(boxX, boxY + height, cs); segV(boxX, boxY + height - cs, cs)
						segH(boxX + width - cs, boxY + height, cs); segV(boxX + width, boxY + height - cs, cs)
					else
						segH(boxX, boxY, width); segH(boxX, boxY + height, width)
						segV(boxX, boxY, height); segV(boxX + width, boxY, height)
					end
					if States.AdvancedESP.ShowHealth and hum and States.AdvancedESP.HealthStyle ~= "Text" then
						local barBg = getFromPool(Pools.Adv.Bars, RenderFolder)
						barBg.Size = UDim2.new(0, 4, 0, height)
						barBg.Position = UDim2.new(0, boxX - 6, 0, boxY)
						barBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
						barBg.BackgroundTransparency = 0.4
						barBg.Parent = RenderFolder
						local ratio = hum.Health / hum.MaxHealth
						local barFill = getFromPool(Pools.Adv.Bars, RenderFolder)
						barFill.Size = UDim2.new(0, 4, 0, math.max(0, height * ratio))
						barFill.Position = UDim2.new(0, boxX - 6, 0, boxY + height * (1 - ratio))
						barFill.BackgroundColor3 = ratio > 0.6 and Color3.fromRGB(0,255,80) or (ratio > 0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,60,60))
						barFill.Parent = RenderFolder
					end
				end
				if States.AdvancedESP.ShowName then
					local nameL = getFromPool(Pools.Adv.Texts, RenderFolder)
					nameL.Size = UDim2.new(0,120,0,16)
					nameL.Position = UDim2.new(0, headSp.X - 60, 0, headSp.Y - 20)
					nameL.Text = t.IsPlayer and t.Plr.Name or char.Name
					nameL.TextColor3 = getPartColor(char.Name .. "advname")
					nameL.TextSize = 12
					nameL.Font = Enum.Font.GothamBold
					nameL.Parent = RenderFolder
				end
				if States.AdvancedESP.ShowHealth and hum and States.AdvancedESP.HealthStyle ~= "Bar" then
					local hpL = getFromPool(Pools.Adv.Texts, RenderFolder)
					hpL.Size = UDim2.new(0,120,0,14)
					hpL.Position = UDim2.new(0, headSp.X - 60, 0, headSp.Y - 5)
					local ratio = hum.Health / hum.MaxHealth
					hpL.Text = string.format("❤ %.0f/%.0f", hum.Health, hum.MaxHealth)
					hpL.TextColor3 = ratio > 0.6 and Color3.fromRGB(0,255,100) or (ratio > 0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,60,60))
					hpL.TextSize = 10
					hpL.Font = Enum.Font.Gotham
					hpL.Parent = RenderFolder
				end
				if States.AdvancedESP.ShowDistance then
					local dL = getFromPool(Pools.Adv.Texts, RenderFolder)
					dL.Size = UDim2.new(0,120,0,14)
					dL.Position = UDim2.new(0, headSp.X - 60, 0, headSp.Y + 10)
					dL.Text = string.format("%.0fm", dist)
					dL.TextColor3 = getPartColor(char.Name .. "advdist")
					dL.TextSize = 10
					dL.Font = Enum.Font.Gotham
					dL.Parent = RenderFolder
				end
				if States.AdvancedESP.Tracer then
					draw3DLine(BeamPools.Adv, camPos, hrp2.Position, getPartColor(char.Name .. "tracer"), BEAM_W)
				end
				if States.AdvancedESP.Skeleton then
					local skeleton = getSkeleton(char)
					for _, pair in ipairs(skeleton) do
						local p1 = char:FindFirstChild(pair[1])
						local p2 = char:FindFirstChild(pair[2])
						if p1 and p2 then
							drawBone(BeamPools.Adv, p1, p2, getPartColor(char.Name .. ":" .. pair[1]))
						end
					end
				end
			end
			for char, h in pairs(AdvESPHighlights) do
				if not valid[char] then
					pcall(function() h:Destroy() end)
					AdvESPHighlights[char] = nil
				end
			end
		end)
	else
		unbind("AdvESP")
		clearPool(Pools.Adv.Boxes)
		clearPool(Pools.Adv.Lines)
		clearPool(Pools.Adv.Texts)
		clearPool(Pools.Adv.Bars)
		clearBeams(BeamPools.Adv)
		for char, h in pairs(AdvESPHighlights) do
			pcall(function() h:Destroy() end)
			AdvESPHighlights[char] = nil
		end
	end
end

-- ============================================
-- V6.2 附加段A: 灵动岛/音乐/远程互动
-- ============================================
Updaters.DynamicIsland = function()
	if States.DynamicIsland.Enabled then
		if Gui.FloatBall then
			pcall(function() Gui.FloatBall:Destroy() end)
			Gui.FloatBall = nil
			if BallMenuPanel and BallMenuPanel.Parent then
				pcall(function() BallMenuPanel:Destroy() end)
				BallMenuPanel = nil
			end
		end
		if Gui.MainPanel then
			Gui.MainPanel.Visible = true
			if not PanelOpen then
				Gui.MainPanel.Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)
			end
		end
	else
		if Gui.MainPanel then Gui.MainPanel.Visible = false end
		if not Gui.FloatBall then createFloatBall() end
	end
end

Updaters.MusicPlayer = function()
	if States.MusicPlayer.Enabled then
		if Gui.MusicPanel then
			Gui.MusicPanel.Visible = true
			if not Music.Open then
				Music.Open = true
				Gui.MusicPanel.ClipsDescendants = true
				Gui.MusicPanel.Size = UDim2.new(0, 380, 0, 380)
			end
		end
		if Gui.MusicBarText then Gui.MusicBarText.Text = "🎵 音乐播放器" end
		if #Music.List == 0 and Music.Tab ~= "Search" then
			setMusicTab("Rec")
		end
	else
		if Gui.MusicPanel then Gui.MusicPanel.Visible = false end
	end
end

-- 远程互动: 一键互动地图上可互动物体(把互动距离改到客户端)
local function findAllPrompts()
	local prompts = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			table.insert(prompts, d)
		end
	end
	return prompts
end

function remoteInteractAll()
	local prompts = findAllPrompts()
	for _, p in ipairs(prompts) do
		pcall(function()
			if p.MaxActivationDistance < 2000 then p.MaxActivationDistance = 2000 end
			p.RequiresLineOfSight = false
			p.HoldDuration = 0
		end)
	end
	local filled = 0
	task.spawn(function()
		for i = 1, math.max(#prompts, 1) do
			pcall(function()
				VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
				task.wait(0.03)
				VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
				filled = filled + 1
			end)
			task.wait(0.15)
		end
	end)
	if musicToast then musicToast("🧹 远程互动 " .. #prompts .. " 个可互动目标") end
end

Updaters.RemoteInteract = function()
	-- 远程互动无需开关, 此updater仅自动扩展互动距离(常驻轻量)
	if States.RemoteInteract and States.RemoteInteract.Enabled then
		if Conns.RemoteInt then return end
		local tickCount = 0
		Conns.RemoteInt = RunService.Heartbeat:Connect(function()
			tickCount = tickCount + 1
			if tickCount % 40 ~= 0 then return end
			for _, d in ipairs(Workspace:GetDescendants()) do
				if d:IsA("ProximityPrompt") then
					pcall(function()
						if (d.MaxActivationDistance or 0) < 500 then
							d.MaxActivationDistance = 500
							d.RequiresLineOfSight = false
						end
					end)
				end
			end
		end)
	else
		unbind("RemoteInt")
	end
end

-- ============================================
-- V6.2 附加段B: 点击脚本 (自动化点击)
-- ============================================
local CSScript = {Points = {}, Running = false, Thread = nil, Loops = 1, AddMode = false}
local CSPanel, CSAddBtn, CSLoopsBox, CSStatusLabel, CSPointFrame, CSSavedFrame
local CSMarkers = {}
local CS_AddIgnoreUntil = 0

local function csSaveToFile()
	pcall(function()
		writefile("NH_CScripts.json", HttpService:JSONEncode(SavedScripts.Click))
	end)
end
local function csLoadFromFile()
	pcall(function()
		local data = readfile("NH_CScripts.json")
		if data and #data > 0 then
			local dec = HttpService:JSONDecode(data)
			if type(dec) == "table" then SavedScripts.Click = dec end
		end
	end)
end

local function csMarkersRender()
	-- 根据坐标放置标记球(顺序+延迟)
	for _, m in ipairs(CSMarkers) do
		if m and m.Parent then m:Destroy() end
	end
	CSMarkers = {}
	for i, p in ipairs(CSScript.Points) do
		local marker = Instance.new("Frame")
		marker.Size = UDim2.new(0, 30, 0, 30)
		marker.Position = UDim2.new(0, p.x - 15, 0, p.y - 15)
		marker.BackgroundColor3 = Color3.fromRGB(0, 150, 200)
		marker.BackgroundTransparency = 0.15
		marker.BorderSizePixel = 0
		marker.ZIndex = 9500
		marker.Parent = ScreenGui
		local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(1, 0); mc.Parent = marker
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 2; stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = Color3.fromHSV(math.fmod(p.delay > 0 and 0.42 or 0.0, 1), 1, 1)
		stroke.Parent = marker
		local num = Instance.new("TextLabel")
		num.Size = UDim2.new(1, 0, 0, 18); num.Position = UDim2.new(0, 0, 0.5, -14)
		num.BackgroundTransparency = 1
		num.Text = tostring(i)
		num.TextColor3 = Color3.fromRGB(255,255,255)
		num.TextSize = 12; num.Font = Enum.Font.GothamBold
		num.Parent = marker
		local dLabel = Instance.new("TextLabel")
		dLabel.Size = UDim2.new(1, 0, 0, 12); dLabel.Position = UDim2.new(0, 0, 0.5, 2)
		dLabel.BackgroundColor3 = Color3.fromRGB(10,10,10); dLabel.BackgroundTransparency = 0.3
		dLabel.Text = string.format("%dms", p.delay)
		dLabel.TextColor3 = Color3.fromRGB(255,220,120)
		dLabel.TextSize = 8; dLabel.Font = Enum.Font.GothamBold
		dLabel.Parent = marker
		local dragApi = makeDraggable(marker)
		local pidx = i
		-- marker 是 Frame, 无 MouseButton1Click 属性; 点击点仅用于显示顺序/延迟, 拖拽调整由 makeDraggable 处理
		table.insert(CSMarkers, marker)
	end
end

local function csRenderPointList()
	if not CSPointFrame then return end
	for _, c in ipairs(CSPointFrame:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	if #CSScript.Points == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 28); empty.BackgroundTransparency = 1
		empty.Text = "点击「➕ 添加点击」然后点击屏幕 或 直接拖动下方点球"
		empty.TextColor3 = Color3.fromRGB(160,165,210); empty.TextSize = 10
		empty.Font = Enum.Font.Gotham; empty.TextWrapped = true
		empty.Parent = CSPointFrame
		return
	end
	local y = 0
	for i, p in ipairs(CSScript.Points) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 30); row.Position = UDim2.new(0, 2, 0, y)
		row.BackgroundColor3 = C.RowBg; row.BackgroundTransparency = 0.25
		row.BorderSizePixel = 0; row.Parent = CSPointFrame
		local rr = Instance.new("UICorner"); rr.CornerRadius = UDim.new(0, 8); rr.Parent = row
		local lab = Instance.new("TextLabel")
		lab.Size = UDim2.new(0, 60, 1, 0); lab.Position = UDim2.new(0, 6, 0, 0)
		lab.BackgroundTransparency = 1
		lab.Text = "点击#" .. i
		lab.TextColor3 = Color3.fromRGB(235,235,255); lab.TextSize = 10
		lab.Font = Enum.Font.GothamBold; lab.TextXAlignment = Enum.TextXAlignment.Left
		lab.Parent = row
		local coord = Instance.new("TextLabel")
		coord.Size = UDim2.new(0, 74, 1, 0); coord.Position = UDim2.new(0, 60, 0, 0)
		coord.BackgroundTransparency = 1
		coord.Text = string.format("%d,%d", p.x, p.y)
		coord.TextColor3 = Color3.fromRGB(150,200,255); coord.TextSize = 8
		coord.Font = Enum.Font.Gotham; coord.TextXAlignment = Enum.TextXAlignment.Left
		coord.Parent = row
		local dm = Instance.new("TextButton")
		dm.Size = UDim2.new(0, 20, 0, 18); dm.Position = UDim2.new(0, 136, 0.5, -9)
		dm.BackgroundColor3 = C.Btn; dm.Text = "−"; dm.TextColor3 = Color3.fromRGB(255,255,255)
		dm.TextSize = 12; dm.Font = Enum.Font.GothamBold
		dm.Parent = row
		local dmc = Instance.new("UICorner"); dmc.CornerRadius = UDim.new(0, 6); dmc.Parent = dm
		local dl = Instance.new("TextLabel")
		dl.Size = UDim2.new(0, 44, 0, 18); dl.Position = UDim2.new(0, 158, 0.5, -9)
		dl.BackgroundColor3 = C.Val; dl.Text = tostring(p.delay)
		dl.TextColor3 = Color3.fromRGB(255,255,255); dl.TextSize = 9
		dl.Font = Enum.Font.GothamBold; dl.Parent = row
		local dlc = Instance.new("UICorner"); dlc.CornerRadius = UDim.new(0, 6); dlc.Parent = dl
		local dp = Instance.new("TextButton")
		dp.Size = UDim2.new(0, 20, 0, 18); dp.Position = UDim2.new(0, 204, 0.5, -9)
		dp.BackgroundColor3 = C.Btn; dp.Text = "+"; dp.TextColor3 = Color3.fromRGB(255,255,255)
		dp.TextSize = 12; dp.Font = Enum.Font.GothamBold
		dp.Parent = row
		local dpc = Instance.new("UICorner"); dpc.CornerRadius = UDim.new(0, 6); dpc.Parent = dp
		local del = Instance.new("TextButton")
		del.Size = UDim2.new(0, 40, 0, 20); del.Position = UDim2.new(1, -44, 0.5, -10)
		del.BackgroundColor3 = Color3.fromRGB(200,70,70); del.Text = "删"
		del.TextColor3 = Color3.fromRGB(255,255,255); del.TextSize = 10
		del.Font = Enum.Font.GothamBold
		del.Parent = row
		local delc = Instance.new("UICorner"); delc.CornerRadius = UDim.new(0, 7); delc.Parent = del
		local pobj = p
		local iobj = i
		dm.MouseButton1Click:Connect(function()
			pobj.delay = math.max(0, (pobj.delay or 0) - 50)
			csRenderPointList()
			csMarkersRender()
		end)
		dp.MouseButton1Click:Connect(function()
			pobj.delay = math.min(10000, (pobj.delay or 0) + 50)
			csRenderPointList()
			csMarkersRender()
		end)
		del.MouseButton1Click:Connect(function()
			table.remove(CSScript.Points, iobj)
			csRenderPointList()
			csMarkersRender()
		end)
		y = y + 32
	end
end

local function csRenderSaved()
	if not CSSavedFrame then return end
	for _, c in ipairs(CSSavedFrame:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	if #SavedScripts.Click == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 26); empty.BackgroundTransparency = 1
		empty.Text = "暂无已保存脚本"
		empty.TextColor3 = Color3.fromRGB(150,155,200); empty.TextSize = 10
		empty.Font = Enum.Font.Gotham; empty.Parent = CSSavedFrame
		return
	end
	local y = 0
	for i, s in ipairs(SavedScripts.Click) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 30); row.Position = UDim2.new(0, 2, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(26,20,60); row.BackgroundTransparency = 0.3
		row.BorderSizePixel = 0; row.Parent = CSSavedFrame
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row
		local loadBtn = Instance.new("TextButton")
		loadBtn.Size = UDim2.new(1, -44, 1, 0)
		loadBtn.BackgroundTransparency = 1; loadBtn.Text = "▶ " .. s.name .. " (" .. #s.points .. " 点)"
		loadBtn.TextColor3 = Color3.fromRGB(235,235,255); loadBtn.TextSize = 9
		loadBtn.Font = Enum.Font.GothamBold; loadBtn.TextXAlignment = Enum.TextXAlignment.Left
		loadBtn.Parent = row
		local sIdx = i
		loadBtn.MouseButton1Click:Connect(function()
			CSScript.Points = {}
			for _, pt in ipairs(SavedScripts.Click[sIdx].points) do
				table.insert(CSScript.Points, {x = pt.x, y = pt.y, delay = pt.delay or 150})
			end
			CSScript.Loops = SavedScripts.Click[sIdx].loops or 1
			if CSLoopsBox then CSLoopsBox.Text = tostring(CSScript.Loops) end
			csRenderPointList()
			csMarkersRender()
			if CSStatusLabel then animateSwap(CSStatusLabel, "已加载: " .. s.name) end
		end)
		local delBtn = Instance.new("TextButton")
		delBtn.Size = UDim2.new(0, 40, 0, 20); delBtn.Position = UDim2.new(1, -44, 0.5, -10)
		delBtn.BackgroundColor3 = Color3.fromRGB(200,70,70); delBtn.Text = "删"
		delBtn.TextColor3 = Color3.fromRGB(255,255,255); delBtn.TextSize = 10
		delBtn.Font = Enum.Font.GothamBold
		delBtn.Parent = row
		local delc2 = Instance.new("UICorner"); delc2.CornerRadius = UDim.new(0, 7); delc2.Parent = delBtn
		local di = i
		delBtn.MouseButton1Click:Connect(function()
			table.remove(SavedScripts.Click, di)
			csSaveToFile()
			csRenderSaved()
		end)
		y = y + 32
	end
end

local function csClickCoord(x, y)
	local inset = getGuiInsetOffset()
	pcall(function()
		VirtualInputManager:SendMouseButtonEvent(x + inset.X, y + inset.Y, 0, true, game, 0)
		task.wait(0.02)
		VirtualInputManager:SendMouseButtonEvent(x + inset.X, y + inset.Y, 0, false, game, 0)
	end)
end

local function csRun()
	if CSScript.Running or #CSScript.Points == 0 then return end
	CSScript.Running = true
	if CSStatusLabel then animateSwap(CSStatusLabel, "▶ 执行中... (点击停止可中断)") end
	CSScript.Thread = task.spawn(function()
		local loopsToDo = CSScript.Loops
		local loopIdx = 0
		while CSScript.Running do
			loopIdx = loopIdx + 1
			if CSScript.Loops ~= 0 and loopIdx > CSScript.Loops then break end
			for i, p in ipairs(CSScript.Points) do
				if not CSScript.Running then break end
				csClickCoord(p.x, p.y)
				local delayMs = math.max(p.delay or 150, 1)
				local waited = 0
				while waited < delayMs / 1000 and CSScript.Running do
					task.wait(0.02)
					waited = waited + 0.02
				end
			end
		end
		CSScript.Running = false
		if CSStatusLabel then animateSwap(CSStatusLabel, "✅ 完成 (循环 " .. (loopIdx - 1) .. " 次)") end
	end)
end

local function csStop()
	CSScript.Running = false
	if CSScript.Thread then task.cancel(CSScript.Thread); CSScript.Thread = nil end
	if CSStatusLabel then animateSwap(CSStatusLabel, "⏹ 已停止") end
end

local function buildClickScriptPanel()
	if CSPanel and CSPanel.Parent then return CSPanel end
	local panel = Instance.new("Frame")
	panel.Name = "ClickScriptPanel"
	panel.Size = UDim2.new(0, 430, 0, 400)
	panel.Position = UDim2.new(0.5, -215, 0.5, -200)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0; panel.Visible = false; panel.ZIndex = 9500
	panel.ClipsDescendants = true
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 18); pc.Parent = panel
	createGrayStroke(panel, 2)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(60, 40, 150), Color3.fromRGB(20, 70, 150))
	grad.Rotation = 90; grad.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1; title.Text = "🖱 点击脚本 (自动执行)"
	title.TextColor3 = Color3.fromRGB(255,255,255); title.TextSize = 14
	title.Font = Enum.Font.GothamBold; title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26); closeBtn.Position = UDim2.new(1, -30, 0, 2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200,60,60); closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255,255,255); closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1,0); cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		States.ClickScript.Enabled = false
		setFeatureState("ClickScript", false)
		csStop()
		panel.Visible = false
	end)

	-- 左侧: 已保存脚本列表
	local leftHead = Instance.new("TextLabel")
	leftHead.Size = UDim2.new(0, 128, 0, 20); leftHead.Position = UDim2.new(0, 8, 0, 34)
	leftHead.BackgroundTransparency = 1; leftHead.Text = "📚 已保存脚本"
	leftHead.TextColor3 = Color3.fromRGB(200,210,255); leftHead.TextSize = 11
	leftHead.Font = Enum.Font.GothamBold
	leftHead.TextXAlignment = Enum.TextXAlignment.Left
	leftHead.Parent = panel
	CSSavedFrame = Instance.new("Frame")
	CSSavedFrame.Size = UDim2.new(0, 128, 0, 286); CSSavedFrame.Position = UDim2.new(0, 8, 0, 56)
	CSSavedFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 26); CSSavedFrame.BackgroundTransparency = 0.2
	CSSavedFrame.BorderSizePixel = 0; CSSavedFrame.ClipsDescendants = true
	CSSavedFrame.Parent = panel
	local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 10); sc.Parent = CSSavedFrame

	-- 右侧: 编辑器
	local editorBg = Instance.new("Frame")
	editorBg.Size = UDim2.new(0, 276, 0, 320); editorBg.Position = UDim2.new(1, -286, 0, 34)
	editorBg.BackgroundColor3 = Color3.fromRGB(22, 16, 52); editorBg.BackgroundTransparency = 0.15
	editorBg.BorderSizePixel = 0; editorBg.Parent = panel
	local ebc = Instance.new("UICorner"); ebc.CornerRadius = UDim.new(0, 12); ebc.Parent = editorBg

	CSStatusLabel = Instance.new("TextLabel")
	CSStatusLabel.Size = UDim2.new(1, -12, 0, 18); CSStatusLabel.Position = UDim2.new(0, 6, 1, -62)
	CSStatusLabel.BackgroundTransparency = 1; CSStatusLabel.Text = "闲置"
	CSStatusLabel.TextColor3 = Color3.fromRGB(150,220,255)
	CSStatusLabel.TextSize = 10; CSStatusLabel.Font = Enum.Font.Gotham; CSStatusLabel.Parent = panel

	-- 循环次数行
	local lpRow = Instance.new("Frame")
	lpRow.Size = UDim2.new(0, 270, 0, 30); lpRow.Position = UDim2.new(0, 6, 0, 38)
	lpRow.BackgroundTransparency = 1; lpRow.Parent = editorBg
	local lpLab = Instance.new("TextLabel")
	lpLab.Size = UDim2.new(0, 120, 1, 0); lpLab.Position = UDim2.new(0, 6, 0, 0)
	lpLab.BackgroundTransparency = 1; lpLab.Text = "执行次数 (0=无限)"
	lpLab.TextColor3 = Color3.fromRGB(210,215,255); lpLab.TextSize = 10
	lpLab.Font = Enum.Font.GothamBold; lpLab.TextXAlignment = Enum.TextXAlignment.Left
	lpLab.Parent = lpRow
	CSLoopsBox = Instance.new("TextBox")
	CSLoopsBox.Size = UDim2.new(0, 80, 0, 24); CSLoopsBox.Position = UDim2.new(1, -90, 0.5, -12)
	CSLoopsBox.BackgroundColor3 = C.Val; CSLoopsBox.Text = "1"
	CSLoopsBox.TextColor3 = Color3.fromRGB(255,255,255); CSLoopsBox.TextSize = 11
	CSLoopsBox.Font = Enum.Font.GothamBold; CSLoopsBox.Parent = lpRow
	local lpc = Instance.new("UICorner"); lpc.CornerRadius = UDim.new(0, 7); lpc.Parent = CSLoopsBox
	CSLoopsBox.FocusLost:Connect(function()
		local n = tonumber(CSLoopsBox.Text)
		if n then CSScript.Loops = math.max(0, math.floor(n)) end
		CSLoopsBox.Text = tostring(CSScript.Loops)
	end)

	-- 添加/清除
	CSAddBtn = createButton(editorBg, "CAdd", UDim2.new(0, 126, 0, 26), UDim2.new(0, 6, 0, 72), Color3.fromRGB(0, 150, 90), "➕ 添加点击")
	CSAddBtn.TextSize = 11
	CSAddBtn.MouseButton1Click:Connect(function()
		CSScript.AddMode = not CSScript.AddMode
		CS_AddIgnoreUntil = tick()
		CSAddBtn.BackgroundColor3 = CSScript.AddMode and Color3.fromRGB(220, 100, 40) or Color3.fromRGB(0, 150, 90)
		CSAddBtn.Text = CSScript.AddMode and "⏸ 点击屏幕添加" or "➕ 添加点击"
	end)
	local clrBtn = createButton(editorBg, "CClear", UDim2.new(0, 60, 0, 26), UDim2.new(0, 138, 0, 72), Color3.fromRGB(180, 60, 60), "清空")
	clrBtn.TextSize = 11
	clrBtn.MouseButton1Click:Connect(function()
		CSScript.Points = {}
		csRenderPointList(); csMarkersRender()
	end)

	-- 保存为脚本
	local svRow = Instance.new("Frame")
	svRow.Size = UDim2.new(0, 270, 0, 30); svRow.Position = UDim2.new(0, 6, 0, 104)
	svRow.BackgroundTransparency = 1; svRow.Parent = editorBg
	local csNameBox = Instance.new("TextBox")
	csNameBox.Size = UDim2.new(0, 112, 0, 24); csNameBox.Position = UDim2.new(0, 6, 0.5, -12)
	csNameBox.BackgroundColor3 = C.Val; csNameBox.PlaceholderText = "脚本名"
	csNameBox.PlaceholderColor3 = Color3.fromRGB(130,135,175); csNameBox.Text = ""
	csNameBox.TextColor3 = Color3.fromRGB(255,255,255); csNameBox.TextSize = 10
	csNameBox.Font = Enum.Font.Gotham; csNameBox.Parent = svRow
	local nbc = Instance.new("UICorner"); nbc.CornerRadius = UDim.new(0, 7); nbc.Parent = csNameBox
	local svBtn = createButton(svRow, "CSave", UDim2.new(0, 90, 0, 24), UDim2.new(1, -132, 0.5, -12), Color3.fromRGB(60, 110, 220), "💾 保存")
	svBtn.TextSize = 10
	svBtn.MouseButton1Click:Connect(function()
		if #CSScript.Points == 0 then return end
		local nm = csNameBox.Text
		if #nm == 0 then nm = "点击脚本" .. (#SavedScripts.Click + 1) end
		local pts = {}
		for _, p in ipairs(CSScript.Points) do
			table.insert(pts, {x = p.x, y = p.y, delay = p.delay})
		end
		table.insert(SavedScripts.Click, {name = nm, points = pts, loops = CSScript.Loops})
		csSaveToFile()
		csRenderSaved()
		csNameBox.Text = ""
	end)

	-- 运行/停止
	local runBtn = createButton(editorBg, "CRun", UDim2.new(0, 128, 0, 30), UDim2.new(0, 6, 0, 138), Color3.fromRGB(0, 160, 120), "▶ 开始执行")
	runBtn.TextSize = 12
	runBtn.MouseButton1Click:Connect(function() csRun() end)
	local stpBtn = createButton(editorBg, "CStop", UDim2.new(0, 128, 0, 30), UDim2.new(0, 140, 0, 138), Color3.fromRGB(180, 70, 70), "⏹ 停止")
	stpBtn.TextSize = 12
	stpBtn.MouseButton1Click:Connect(function() csStop() end)

	-- 点击点列表
	CSPointFrame = Instance.new("Frame")
	CSPointFrame.Size = UDim2.new(1, -12, 0, 150); CSPointFrame.Position = UDim2.new(0, 6, 0, 172)
	CSPointFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 26); CSPointFrame.BackgroundTransparency = 0.2
	CSPointFrame.BorderSizePixel = 0; CSPointFrame.ClipsDescendants = true
	CSPointFrame.Parent = editorBg
	local plc = Instance.new("UICorner"); plc.CornerRadius = UDim.new(0, 10); plc.Parent = CSPointFrame

	makeDraggable(panel)
	raiseZIndex(panel, 9501)
	csLoadFromFile()
	csRenderSaved()
	csRenderPointList()
	Gui.CS_Panel = panel
	return panel
end

-- 全局点击添加模式监听
UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	local isClick = input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	if not isClick then return end
	if not (States.ClickScript and States.ClickScript.Enabled) then return end
	if not CSScript.AddMode then return end
	if tick() - CS_AddIgnoreUntil < 0.5 then return end
	local pos = mouseScreenPos()
	table.insert(CSScript.Points, {x = math.floor(pos.X), y = math.floor(pos.Y), delay = 150})
	csRenderPointList()
	csMarkersRender()
end)

Updaters.ClickScript = function()
	if States.ClickScript.Enabled then
		local p = buildClickScriptPanel()
		if p then p.Visible = true end
	else
		csStop()
		local pm = buildClickScriptPanel()
		if pm then pm.Visible = false end
	end
end

-- ============================================
-- V6.2 附加段D: 客户端脚本 (录制/回放客户活动)
-- 记录: 移动(分段距离+坐标) / 互动(目标对象+坐标+区域) / 切换道具
-- 回放: 结合坐标+分段距离模拟移动, 到达互动区域自动互动
-- ============================================
local Ce = {Recording = false, Playing = false, Thread = nil, Loop = 1, Events = {}, CurStep = 0}
local CeRecordWindow = nil
local CePlayZone = 8
local CeMoveSpeed = 30

local CeLogBtn
local CeLastPos, CeSegDist = nil, 0
local CeLastSample = nil
local CeLastTool = nil
local CeMouseInteractConn = nil

local function ceNormalize(v)
	return math.floor((v or 0) * 10) / 10
end

local function cePushEvent(ev)
	table.insert(Ce.Events, ev)
end

-- 判断是否有可互动的ProximityPrompt在记录区域
local function cePromptAtPart(part)
	if not part then return nil end
	for _, child in ipairs(part:GetDescendants()) do
		if child:IsA("ProximityPrompt") then return child end
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	return prompt
end

-- 反向找部件: 通过世界坐标最近的同名部件/可互动对象
local function ceFindPartAt(cx, cz)
	local best, bestD = nil, math.huge
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Size.Magnitude > 0.01 then
			local pos = d.Position
			local hd = math.sqrt((pos.X - cx)^2 + (pos.Z - cz)^2)
			if hd < bestD then bestD = hd; best = d end
		end
	end
	if best and bestD <= 30 then return best end
	return nil
end

local function ceFormatMove(ev, current)
	local d = current or ev.d or 0
	local dirName = "向前"
	if ev.rx and ev.rz then
		local dotF = math.abs(ev.rx)
		local dotR = math.abs(ev.rz)
		if dotR > dotF and ev.rz < -0.6 then dirName = "向右" end
		if dotR > dotF and ev.rz > 0.6 then dirName = "向左" end
		if dotF >= dotR and ev.rx > 0.6 then dirName = "向前" end
		if dotF >= dotR and ev.rx < -0.6 then dirName = "向后" end
	end
	return string.format("%s %.1f米", dirName, d)
end

-- 右上角半透明悬浮条: 实时显示当前记录/回放进度
local function buildCeRecordBar()
	if CeRecordWindow and CeRecordWindow.Parent then return CeRecordWindow end
	local bar = Instance.new("Frame")
	bar.Name = "CeStatusBar"
	bar.Size = UDim2.new(0, 250, 0, 34)
	bar.Position = UDim2.new(1, -260, 0, 70)
	bar.AnchorPoint = Vector2.new(1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(10, 10, 24)
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.ZIndex = 9700
	bar.ClipsDescendants = true
	bar.Parent = ScreenGui
	local bC = Instance.new("UICorner"); bC.CornerRadius = UDim.new(0, 12); bC.Parent = bar
	createGrayStroke(bar, 2)

	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.new(0, 76, 0, 20); t1.Position = UDim2.new(0, 6, 0.05, 0)
	t1.BackgroundTransparency = 1; t1.Text = "● 记录中"
	t1.TextColor3 = Color3.fromRGB(255, 80, 80); t1.TextSize = 11
	t1.Font = Enum.Font.GothamBold; t1.TextXAlignment = Enum.TextXAlignment.Left
	t1.Parent = bar

	local t2 = Instance.new("TextLabel")
	t2.Size = UDim2.new(1, -90, 0, 20); t2.Position = UDim2.new(0, 84, 0.05, 0)
	t2.BackgroundTransparency = 1; t2.Text = "骤0/0"
	t2.TextColor3 = Color3.fromRGB(255, 255, 255); t2.TextSize = 11
	t2.Font = Enum.Font.GothamBold; t2.TextXAlignment = Enum.TextXAlignment.Left
	t2.TextTruncate = Enum.TextTruncate.AtEnd
	t2.Parent = bar

	local t3 = Instance.new("TextLabel")
	t3.Size = UDim2.new(1, -12, 0, 12); t3.Position = UDim2.new(0, 6, 0.88, -12)
	t3.BackgroundTransparency = 1; t3.Text = "坐标: -"
	t3.TextColor3 = Color3.fromRGB(180, 200, 255); t3.TextSize = 8
	t3.Font = Enum.Font.Gotham; t3.TextXAlignment = Enum.TextXAlignment.Left
	t3.TextTruncate = Enum.TextTruncate.AtEnd
	t3.Parent = bar

	local stop = Instance.new("TextButton")
	stop.Size = UDim2.new(0, 22, 0, 22); stop.Position = UDim2.new(1, -25, 0.5, -11)
	stop.BackgroundColor3 = Color3.fromRGB(200, 60, 60); stop.Text = "✕"
	stop.TextColor3 = Color3.fromRGB(255,255,255); stop.TextSize = 11
	stop.Font = Enum.Font.GothamBold
	stop.Parent = bar
	local sC = Instance.new("UICorner"); sC.CornerRadius = UDim.new(1, 0); sC.Parent = stop
	stop.MouseButton1Click:Connect(function()
		ceStop()
	end)

	makeDraggable(bar)
	raiseZIndex(bar, 9701)
	CeRecordWindow = bar
	return bar
end

local function ceSetBar(text)
	local bar = buildCeRecordBar()
	if not bar then return end
	local kids = bar:GetChildren()
	local t1, t2, t3
	for _, k in ipairs(kids) do
		if k:IsA("TextLabel") then
			if k.Position.X.Offset <= 80 then t1 = k
			elseif k.Position.X.Offset > 80 and k.TextSize > 9 then t2 = k
			else t3 = k end
		end
	end
	local curStep, total = Ce.CurStep, #Ce.Events
	t1.Text = (Ce.Recording and "● 记录中" or "▶ 回放中")
	t1.TextColor3 = Ce.Recording and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(90, 255, 160)
	t2.Text = "骤 " .. curStep .. "/" .. total
	if text then
		animateSwap(t3, text, true)
	end
end

-- 记录时的后台采样循环
local function ceSampleLoop()
	Ce.Recording = true
	CeSegDist = 0
	CeLastPos = hrp and hrp.Position or nil
	CeLastSample = hrp and hrp.Position or nil
	CeLastTool = character and character:FindFirstChildOfClass("Tool") or nil
	-- 记录互动: 监听点击目标
	if not CeMouseInteractConn then
		CeMouseInteractConn = UserInputService.InputBegan:Connect(function(input, gpe)
			if gpe or not Ce.Recording then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				task.delay(0.05, function()
					if not Ce.Recording or not hrp then return end
					-- 检测屏幕中央或点击处的可互动对象
					local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
					local res = Workspace:Raycast(camera.CFrame.Position, ray.Direction * 100)
					local target = res and res.Instance
					local name = "未知"
					if target then
						name = target.Name
						local anc = target
						while anc and not anc:FindFirstChildOfClass("ProximityPrompt") and anc.Parent do
							anc = anc.Parent
						end
						if anc and anc:FindFirstChildOfClass("ProximityPrompt") then
							name = anc.Name
						end
					end
					local pos = res and res.Position or (hrp.Position + camera.CFrame.LookVector * 6)
					cePushEvent({t = "i", x = ceNormalize(pos.X), y = ceNormalize(res and res.Position.Y or hrp.Position.Y), z = ceNormalize(pos.Z), name = name, zone = CePlayZone})
					Ce.CurStep = #Ce.Events
					ceSetBar(string.format("互动: %s @(%.0f,%.0f)", name, pos.X, pos.Z))
				end)
			end
		end)
	end
	-- 记录切道具
	task.spawn(function()
		while Ce.Recording do
			task.wait(0.2)
			if not hrp or not character then continue end
			local tool = character:FindFirstChildOfClass("Tool")
			if tool and tool ~= CeLastTool then
				CeLastTool = tool
				cePushEvent({t = "s", name = tool.Name})
				Ce.CurStep = #Ce.Events
				ceSetBar("切换道具: " .. tool.Name)
			end
		end
	end)
	-- 主采样
	while Ce.Recording do
		RunService.RenderStepped:Wait()
		if not hrp or not hrp.Parent then continue end
		local p = hrp.Position
		if CeLastPos then
			local stepDist = (p - CeLastPos).Magnitude
			CeSegDist = CeSegDist + stepDist
			local h = Vector3.new(0, 1, 0)
			-- 方向变化较大时提前分段
			local fwd = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
			if fwd.Magnitude < 0.01 then fwd = Vector3.new(0, 0, -1) end
			fwd = fwd.Unit
			local nd = (p - CeLastSample)
			local horizD = math.sqrt(nd.X * nd.X + nd.Z * nd.Z)
			if horizD >= 1.0 then
				-- 记录移动分段(方向+坐标)
				local dx = (p - CeLastSample)
				dx = dx * (fwd.Y - fwd.Y) -- noop
				local rx, rz = nd.X, nd.Z
				if (math.abs(rx) + math.abs(rz)) > 0.01 then
					rx = rx / horizD; rz = rz / horizD
				end
				cePushEvent({t = "m", x = ceNormalize(p.X), y = ceNormalize(p.Y), z = ceNormalize(p.Z), d = math.ceil(horizD * 10) / 10, rx = rx, rz = rz})
				Ce.CurStep = #Ce.Events
				ceSetBar(ceFormatMove(Ce.Events[#Ce.Events]))
				CeLastSample = p
			end
		end
		CeLastPos = p
	end
	Ce.Recording = false
	Ce.CurStep = #Ce.Events
	if CeRecordWindow then CeRecordWindow.Visible = false end
end

-- 回放: 移动到坐标/到达区域互动
local function cePlayEvent(ev)
	if ev.t == "m" then
		local target = Vector3.new(ev.x, ev.y, ev.z)
		-- 水平移动
		while hrp and hrp.Parent do
			local pp = hrp.Position
			local d = math.sqrt((pp.X - target.X)^2 + (pp.Z - target.Z)^2)
			if d <= 1.2 then break end
			local dir = Vector3.new(target.X - pp.X, 0, target.Z - pp.Z).Unit
			if humanoid then humanoid:Move(dir * 1) end
			Ce.CurStep = math.min(Ce.CurStep + 1, #Ce.Events)
			ceSetBar(string.format("移动中 剩余 %.1f米", d))
			RunService.RenderStepped:Wait()
		end
		if humanoid then humanoid:Move(Vector3.zero) end
		Ce.CurStep = math.min(Ce.CurStep + 1, #Ce.Events)
	elseif ev.t == "i" then
		-- 到达互动区域后互动
		local part = ceFindPartAt(ev.x, ev.z)
		local prompt = part and cePromptAtPart(part)
		ceSetBar("互动: " .. (ev.name or "对象"))
		-- 移动片段已在上一事件完成, 直接交互
		pcall(function()
			if prompt then
				if prompt.MaxActivationDistance < 2000 then prompt.MaxActivationDistance = 2000 end
				prompt.RequiresLineOfSight = false
			end
			VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
			task.wait(0.06)
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
		end)
		task.wait(0.3)
		Ce.CurStep = math.min(Ce.CurStep + 1, #Ce.Events)
	elseif ev.t == "s" then
		ceSetBar("切换道具: " .. (ev.name or ""))
		local tool
		if character then tool = character:FindFirstChild(ev.name or "") end
		if not tool and player then
			local back = player:FindFirstChild("Backpack")
			if back then tool = back:FindFirstChild(ev.name or "") end
		end
		if tool then
			pcall(function() tool.Parent = character end)
		end
		task.wait(0.15)
		Ce.CurStep = math.min(Ce.CurStep + 1, #Ce.Events)
	end
end

local function ceRun()
	if Ce.Playing then return end
	if #Ce.Events == 0 then return end
	Ce.Playing = true
	Ce.CurStep = 0
	buildCeRecordBar().Visible = true
	-- 锁定用户移动
	if humanoid then humanoid.PlatformStand = false end
	local baseLocked = {humanoid and humanoid.WalkSpeed or 16}
	Ce.Thread = task.spawn(function()
		local loops = math.max(math.floor(Ce.Loop or 1), 1)
		for li = 1, loops do
			if not Ce.Playing then break end
			for _, ev in ipairs(Ce.Events) do
				if not Ce.Playing then break end
				cePlayEvent(ev)
			end
		end
		ceStop()
		if CeStatusTip then CeStatusTip.Text = "✅ 客户端脚本执行完成" end
	end)
end

local function ceStop()
	Ce.Playing = false
	Ce.Recording = false
	if Ce.Thread then task.cancel(Ce.Thread); Ce.Thread = nil end
	if humanoid then humanoid:Move(Vector3.zero); humanoid.PlatformStand = false end
	if CeRecordWindow then CeRecordWindow.Visible = false end
end

local function ceSaveCurrent()
	if #Ce.Events == 0 then return end
	local key = "客户端_" .. math.floor(tick()) % 100000
	SavedScripts.Client[key] = {events = Ce.Events, time = os.time()}
	pcall(function() writefile("NH_CScripts.json", HttpService:JSONEncode(SavedScripts)) end)
	ceRenderSaved()
end

local function ceDelete(key)
	SavedScripts.Client[key] = nil
	pcall(function() writefile("NH_CScripts.json", HttpService:JSONEncode(SavedScripts)) end)
	ceRenderSaved()
end

local function ceRenderSaved()
	if not CeSavedList then return end
	for _, c in ipairs(CeSavedList:GetChildren()) do
		if c:IsA("TextButton") or c:IsA("Frame") then c:Destroy() end
	end
	local keys = {}
	for k in pairs(SavedScripts.Client) do table.insert(keys, k) end
	table.sort(keys)
	if #keys == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "暂无保存的脚本\n录制后点击保存"
		empty.TextColor3 = Color3.fromRGB(150, 150, 190)
		empty.TextSize = 10
		empty.Font = Enum.Font.Gotham
		empty.Parent = CeSavedList
		return
	end
	local y = 0
	for _, k in ipairs(keys) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -4, 0, 44)
		row.Position = UDim2.new(0, 2, 0, y)
		row.BackgroundColor3 = Color3.fromRGB(28, 22, 62)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = CeSavedList
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row
		local data = SavedScripts.Client[k]
		local n = data and data.events and #data.events or 0
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -20, 1, 0)
		btn.BackgroundTransparency = 1; btn.Text = ""
		btn.Parent = row
		btn.MouseButton1Click:Connect(function()
			Ce.Events = {}
			if data and data.events then
				for _, e in ipairs(data.events) do Ce.Events[#Ce.Events+1] = e end
			end
			ceRenderLog()
			if CeStatusTip then
				CeStatusTip.Text = "已加载 [ " .. k .. " ] " .. n .. " 步"
				setFeatureState("ClientScript", true)
			end
		end)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, 20); t.Position = UDim2.new(0, 4, 0, 0)
		t.BackgroundTransparency = 1
		t.Text = k
		t.TextColor3 = Color3.fromRGB(255, 220, 140)
		t.TextSize = 9; t.Font = Enum.Font.GothamBold
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Parent = row
		local sub = Instance.new("TextLabel")
		sub.Size = UDim2.new(1, 0, 0, 16); sub.Position = UDim2.new(0, 4, 0, 20)
		sub.BackgroundTransparency = 1
		sub.Text = n .. " 步"
		sub.TextColor3 = Color3.fromRGB(160, 170, 220)
		sub.TextSize = 8; sub.Font = Enum.Font.Gotham
		sub.TextXAlignment = Enum.TextXAlignment.Left
		sub.Parent = row
		local del = Instance.new("TextButton")
		del.Size = UDim2.new(0, 18, 0, 18); del.Position = UDim2.new(1, -20, 0.5, -9)
		del.BackgroundColor3 = Color3.fromRGB(200, 60, 60); del.Text = "×"
		del.TextColor3 = Color3.fromRGB(255,255,255); del.TextSize = 10
		del.Font = Enum.Font.GothamBold
		del.Parent = row
		local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1, 0); dc.Parent = del
		del.MouseButton1Click:Connect(function() ceDelete(k) end)
		y = y + 52
	end
end

local function ceRenderLog()
	if not CeLogFrame then return end
	for _, c in ipairs(CeLogFrame:GetChildren()) do
		if c:IsA("TextLabel") then c:Destroy() end
	end
	if #Ce.Events == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "暂无活动\n开始记录后自动生成"
		empty.TextColor3 = Color3.fromRGB(150, 150, 190)
		empty.TextSize = 10
		empty.Font = Enum.Font.Gotham
		empty.Parent = CeLogFrame
		return
	end
	local txt = {}
	for i, ev in ipairs(Ce.Events) do
		if ev.t == "m" then
			table.insert(txt, string.format("%d. %s 坐标(%.0f, %.0f)", i, ceFormatMove(ev), ev.x, ev.z))
		elseif ev.t == "i" then
			table.insert(txt, string.format("%d. 互动「%s」 @(%.0f,%.0f)", i, ev.name or "对象", ev.x, ev.z))
		elseif ev.t == "s" then
			table.insert(txt, string.format("%d. 切换道具「%s」", i, ev.name or ""))
		end
	end
	for _, line in ipairs(txt) do
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, 0, 0, 16)
		l.BackgroundTransparency = 1
		l.Text = line
		l.TextColor3 = Color3.fromRGB(215, 220, 255)
		l.TextSize = 9
		l.Font = Enum.Font.Gotham
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Parent = CeLogFrame
	end
end

local function buildClientScriptPanel()
	if ClientScriptPanel and ClientScriptPanel.Parent then return ClientScriptPanel end
	local panel = Instance.new("Frame")
	panel.Name = "ClientScriptPanel"
	panel.Size = UDim2.new(0, 460, 0, 420)
	panel.Position = UDim2.new(0.5, -230, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.12
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9500
	panel.ClipsDescendants = true
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 18); pc.Parent = panel
	createGrayStroke(panel, 2)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromRGB(20, 120, 90), Color3.fromRGB(40, 60, 170))
	grad.Rotation = 90; grad.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.Text = "🎬 客户端脚本 (录制/回放)"
	title.TextColor3 = Color3.fromRGB(255, 255, 255); title.TextSize = 14
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 26, 0, 26); closeBtn.Position = UDim2.new(1, -30, 0, 2)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60); closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.TextSize = 14
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1, 0); cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function()
		States.ClientScript.Enabled = false
		setFeatureState("ClientScript", false)
		ceStop()
		panel.Visible = false
	end)

	-- 左侧: 已保存脚本
	local leftHead = Instance.new("TextLabel")
	leftHead.Size = UDim2.new(0, 150, 0, 20); leftHead.Position = UDim2.new(0, 8, 0, 34)
	leftHead.BackgroundTransparency = 1
	leftHead.Text = "📚 已保存客户端脚本"
	leftHead.TextColor3 = Color3.fromRGB(200, 210, 255); leftHead.TextSize = 11
	leftHead.Font = Enum.Font.GothamBold; leftHead.TextXAlignment = Enum.TextXAlignment.Left
	leftHead.Parent = panel
	CeSavedList = Instance.new("Frame")
	CeSavedList.Size = UDim2.new(0, 150, 0, 340); CeSavedList.Position = UDim2.new(0, 8, 0, 56)
	CeSavedList.BackgroundColor3 = Color3.fromRGB(10, 8, 26); CeSavedList.BackgroundTransparency = 0.2
	CeSavedList.BorderSizePixel = 0; CeSavedList.ClipsDescendants = true
	CeSavedList.Parent = panel
	local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 10); lc.Parent = CeSavedList

	-- 右侧主体
	local body = Instance.new("Frame")
	body.Size = UDim2.new(0, 290, 0, 350); body.Position = UDim2.new(1, -298, 0, 34)
	body.BackgroundColor3 = Color3.fromRGB(22, 16, 52); body.BackgroundTransparency = 0.15
	body.BorderSizePixel = 0
	body.Parent = panel
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 12); bc.Parent = body

	CeStatusTip = Instance.new("TextLabel")
	CeStatusTip.Size = UDim2.new(1, -12, 0, 20); CeStatusTip.Position = UDim2.new(0, 6, 0, 6)
	CeStatusTip.BackgroundTransparency = 1
	CeStatusTip.Text = "点击「开始记录」, 执行操作"
	CeStatusTip.TextColor3 = Color3.fromRGB(180, 220, 200); CeStatusTip.TextSize = 10
	CeStatusTip.Font = Enum.Font.Gotham; CeStatusTip.TextXAlignment = Enum.TextXAlignment.Left
	CeStatusTip.Parent = body

	local recBtn = createButton(body, "CeRec", UDim2.new(0, 128, 0, 30), UDim2.new(0, 6, 0, 30), Color3.fromRGB(200, 70, 70), "● 开始记录")
	recBtn.TextSize = 12
	recBtn.MouseButton1Click:Connect(function()
		if Ce.Recording then
			Ce.Recording = false
			recBtn.Text = "● 开始记录"
			recBtn.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
			ceSetBar(nil)
			ceSaveCurrent()
			ceRenderLog()
		else
			Ce.Events = {}
			Ce.CurStep = 0
			ceRenderLog()
			recBtn.Text = "⏸ 停止记录"
			recBtn.BackgroundColor3 = Color3.fromRGB(180, 120, 40)
			task.spawn(ceSampleLoop)
			buildCeRecordBar().Visible = true
			ceSetBar("开始记录...")
		end
	end)

	local saveBtn = createButton(body, "CeSave", UDim2.new(0, 128, 0, 30), UDim2.new(0, 140, 0, 30), Color3.fromRGB(60, 130, 90), "💾 保存脚本")
	saveBtn.TextSize = 12
	saveBtn.MouseButton1Click:Connect(function()
		ceSaveCurrent()
	end)

	local runBtn = createButton(body, "CeRun", UDim2.new(0, 128, 0, 32), UDim2.new(0, 6, 0, 66), Color3.fromRGB(0, 160, 120), "▶ 开始回放")
	runBtn.TextSize = 12
	runBtn.MouseButton1Click:Connect(function()
		if Ce.Playing then return end
		if #Ce.Events == 0 then
			CeStatusTip.Text = "⚠ 还没有脚本, 先录制或加载"
			return
		end
		ceRun()
	end)
	local stopBtn = createButton(body, "CeStop", UDim2.new(0, 128, 0, 32), UDim2.new(0, 140, 0, 66), Color3.fromRGB(180, 70, 70), "⏹ 停止")
	stopBtn.TextSize = 12
	stopBtn.MouseButton1Click:Connect(function()
		ceStop()
		CeStatusTip.Text = "已停止"
	end)

	-- 循环次数
	local lpLab = Instance.new("TextLabel")
	lpLab.Size = UDim2.new(0, 120, 0, 22); lpLab.Position = UDim2.new(0, 6, 0, 104)
	lpLab.BackgroundTransparency = 1
	lpLab.Text = "循环次数 (0=无限)"
	lpLab.TextColor3 = Color3.fromRGB(210, 215, 255); lpLab.TextSize = 10
	lpLab.Font = Enum.Font.GothamBold; lpLab.TextXAlignment = Enum.TextXAlignment.Left
	lpLab.Parent = body
	CeLoopsBox = Instance.new("TextBox")
	CeLoopsBox.Size = UDim2.new(0, 80, 0, 24); CeLoopsBox.Position = UDim2.new(1, -92, 0, 102)
	CeLoopsBox.BackgroundColor3 = C.Val; CeLoopsBox.Text = "1"
	CeLoopsBox.TextColor3 = Color3.fromRGB(255, 255, 255); CeLoopsBox.TextSize = 11
	CeLoopsBox.Font = Enum.Font.GothamBold
	CeLoopsBox.Parent = body
	local lpc = Instance.new("UICorner"); lpc.CornerRadius = UDim.new(0, 7); lpc.Parent = CeLoopsBox
	CeLoopsBox.FocusLost:Connect(function()
		Ce.Loop = parseNum(CeLoopsBox.Text, 1)
	end)

	CeLogFrame = Instance.new("Frame")
	CeLogFrame.Size = UDim2.new(1, -12, 0, 200); CeLogFrame.Position = UDim2.new(0, 6, 0, 134)
	CeLogFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 26); CeLogFrame.BackgroundTransparency = 0.2
	CeLogFrame.BorderSizePixel = 0; CeLogFrame.ClipsDescendants = true
	CeLogFrame.Parent = body
	local lfc = Instance.new("UICorner"); lfc.CornerRadius = UDim.new(0, 10); lfc.Parent = CeLogFrame

	makeDraggable(panel)
	raiseZIndex(panel, 9501)
	ClientScriptPanel = panel
	ceRenderSaved()
	ceRenderLog()
	return panel
end

Updaters.ClientScript = function()
	if States.ClientScript.Enabled then
		local p = buildClientScriptPanel()
		if p then p.Visible = true end
	else
		ceStop()
		local pm = buildClientScriptPanel()
		if pm then pm.Visible = false end
	end
end

-- ============================================
-- V6.2 附加段E: 功能列表界面 + 最终装配
-- ============================================

-- 自瞄对象列表刷新(需在buildCustomAimFrame之后使用)
refreshCustomAimList = refreshCustomAimList or function()
	local list = CustomAimList
	if not list then return end
	for _, child in pairs(list:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
	end
	updateTargetCache()
	local seen = {}
	local function addRow(char, name)
		if not char or seen[char] then return end
		seen[char] = true
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 26)
		row.BackgroundColor3 = C.BtnDark
		row.BackgroundTransparency = 0.3
		row.Text = name
		row.TextColor3 = Color3.fromRGB(255, 255, 255)
		row.TextSize = 11
		row.Font = Enum.Font.Gotham
		row.Parent = list
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = row
		row.ZIndex = 9402
		if States.AimbotV2.CustomTarget == char then
			row.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
		end
		row.MouseButton1Click:Connect(function()
			States.AimbotV2.CustomTarget = char
			CustomAimFrame.Visible = false
		end)
	end
	for _, e in ipairs(TargetCache.Players) do
		addRow(e.Obj, "👤 " .. e.Plr.Name)
	end
	for _, e in ipairs(TargetCache.Npcs) do
		addRow(e.Obj, "🧟 " .. e.Obj.Name)
	end
	if #list:GetChildren() == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "未检测到目标"
		empty.TextColor3 = Color3.fromRGB(150, 150, 170)
		empty.TextSize = 12
		empty.Font = Enum.Font.Gotham
		empty.Parent = list
		empty.ZIndex = 9402
	end
end

-- 执行UI构建(全部面板)
buildMainPanel()
buildShortcutFrame()
buildFly1Panel()
buildFly2Panel()
buildFreeMoveFrame()
buildClickerSystem()
buildLabels()
buildCustomAimFrame()
buildMusicPanel()
if States.DynamicIsland and not States.DynamicIsland.Enabled then
	createFloatBall()
end

-- 远程互动渐变轮廓按钮循环变色
local RemoteHitBtn
local function pulseRemoteStroke()
	if not Gui.CardGrads then Gui.CardGrads = {} end
	task.spawn(function()
		while true do
			task.wait(0.12)
			if RemoteHitBtn then
				local st = RemoteHitBtn:FindFirstChildOfClass("UIStroke")
				if st then st.Color = getPartColor("remoteStroke") end
			end
		end
	end)
end

-- 功能列表
local CurrentCategory = 1
local FeatureRows = {}
local ROW_W = 368

local function moveCatIndicator(i)
	local ind = Gui.CatIndicator
	if not ind or not ind.Parent then return end
	local y = 9 + (i - 1) * 39
	tween(ind, {Position = UDim2.new(0, 5, 0, y)}, TweenSmooth)
end

local function relayoutRows()
	if not Gui.ScrollInner then return end
	local yOffset = 0
	for _, r in ipairs(FeatureRows) do
		if r.Parent then
			tween(r, {Position = UDim2.new(0, 0, 0, yOffset)}, TweenFast)
		end
		yOffset = yOffset + r.Size.Y.Offset + 5
	end
	Gui.ScrollInner.Size = UDim2.new(0, ROW_W, 0, yOffset)
	if Gui.ScrollInner.Position.Y.Offset < 0 then
		local viewH = Gui.RightContent.AbsoluteSize.Y
		local minY = math.min(0, viewH - yOffset)
		if Gui.ScrollInner.Position.Y.Offset < minY then
			Gui.ScrollInner.Position = UDim2.new(0, 6, 0, minY)
		end
	end
end

local function refreshFeatures()
	if not Gui.ScrollInner then return end
	for _, child in ipairs(Gui.ScrollInner:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextButton") then
			child:Destroy()
		end
	end
	FeatureRows = {}
	for k in pairs(RowScBtns) do RowScBtns[k] = nil end
	for k in pairs(ToggleRefreshers) do ToggleRefreshers[k] = nil end

	local yOffset = 0
	for _, feat in ipairs(Features) do
		if feat.Cat ~= CurrentCategory then continue end
		local row = nil
		local ok = pcall(function()
			local isDrop = feat.HasDropdown
			local rowH = isDrop and 34 or 42
			row = Instance.new("Frame")
			row.Size = UDim2.new(0, ROW_W, 0, rowH)
			row.Position = UDim2.new(0, 0, 0, yOffset)
			row.BackgroundColor3 = Color3.fromRGB(30, 20, 66)
			row.BackgroundTransparency = 0.15
			row.BorderSizePixel = 0
			row.Parent = Gui.ScrollInner
			row.ZIndex = 9003
			local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = row
			createGrayStroke(row, 1.5)

			local scBtn = Instance.new("TextButton")
			scBtn.Size = UDim2.new(0, 24, 0, 24); scBtn.Position = UDim2.new(0, 2, 0.5, -12)
			scBtn.BackgroundColor3 = C.BtnDark
			scBtn.Text = "⚡"; scBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			scBtn.TextSize = 11; scBtn.Font = Enum.Font.GothamBold
			scBtn.Parent = row
			local scC = Instance.new("UICorner"); scC.CornerRadius = UDim.new(0, 8); scC.Parent = scBtn
			createGrayStroke(scBtn, 1.5)
			RowScBtns[feat.Key] = scBtn

			scBtn.MouseButton1Click:Connect(function()
				local nowOn = not States[feat.Key].Enabled
				setFeatureState(feat.Key, nowOn)
				if nowOn then
					Gui.createShortcutButton(feat.Key, feat.Name)
					Gui.ShortcutFrame.Visible = true
				else
					if ShortcutButtons[feat.Key] then
						ShortcutButtons[feat.Key]:Destroy()
						ShortcutButtons[feat.Key] = nil
					end
				end
			end)

			-- 特殊: 远程互动 - 渐变圆角按钮(非开关)
			if feat.Key == "RemoteInteract" then
				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(0, 190, 1, 0); label.Position = UDim2.new(0, 32, 0, 0)
				label.BackgroundTransparency = 1; label.Text = "远程互动"
				label.TextColor3 = Color3.fromRGB(238, 238, 255); label.TextSize = 12
				label.Font = Enum.Font.GothamSemibold; label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = row
				RemoteHitBtn = Instance.new("TextButton")
				RemoteHitBtn.Size = UDim2.new(0, 76, 0, 32)
				RemoteHitBtn.Position = UDim2.new(0, 286, 0.5, -16)
				RemoteHitBtn.BackgroundColor3 = Color3.fromRGB(70, 45, 150)
				RemoteHitBtn.BackgroundTransparency = 0.2
				RemoteHitBtn.Text = "🧹 一键互动"
				RemoteHitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
				RemoteHitBtn.TextSize = 10
				RemoteHitBtn.Font = Enum.Font.GothamBold
				RemoteHitBtn.Parent = row
				local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 10); rc.Parent = RemoteHitBtn
				local rst = gradientStroke(RemoteHitBtn)
				RemoteHitBtn.MouseButton1Click:Connect(function()
					if remoteInteractAll then remoteInteractAll() end
				end)
				pulseRemoteStroke()
			-- 特殊: 多球模式 - 数量调节
			elseif feat.Key == "ClickerMulti" then
				local label = Instance.new("TextLabel")
				label.Size = UDim2.new(0, 84, 1, 0); label.Position = UDim2.new(0, 32, 0, 0)
				label.BackgroundTransparency = 1; label.Text = feat.Name
				label.TextColor3 = Color3.fromRGB(238, 238, 255); label.TextSize = 12
				label.Font = Enum.Font.GothamSemibold; label.TextXAlignment = Enum.TextXAlignment.Left
				label.Parent = row
				local mBtn = Instance.new("TextButton")
				mBtn.Size = UDim2.new(0, 24, 0, 26); mBtn.Position = UDim2.new(0, 214, 0.5, -13)
				mBtn.BackgroundColor3 = C.Btn; mBtn.Text = "−"
				mBtn.TextColor3 = Color3.fromRGB(255,255,255); mBtn.TextSize = 14
				mBtn.Font = Enum.Font.GothamBold; mBtn.Parent = row
				local mC = Instance.new("UICorner"); mC.CornerRadius = UDim.new(0, 8); mC.Parent = mBtn
				local vL = Instance.new("TextLabel")
				vL.Size = UDim2.new(0, 50, 0, 26); vL.Position = UDim2.new(0, 240, 0.5, -13)
				vL.BackgroundColor3 = C.Val; vL.BackgroundTransparency = 0.1
				vL.Text = tostring(States.ClickerMulti.ClickerCount or 2)
				vL.TextColor3 = Color3.fromRGB(255,255,255); vL.TextSize = 11
				vL.Font = Enum.Font.Gotham; vL.Parent = row
				local vC = Instance.new("UICorner"); vC.CornerRadius = UDim.new(0, 8); vC.Parent = vL
				local pBtn = Instance.new("TextButton")
				pBtn.Size = UDim2.new(0, 24, 0, 26); pBtn.Position = UDim2.new(0, 292, 0.5, -13)
				pBtn.BackgroundColor3 = C.Btn; pBtn.Text = "+"
				pBtn.TextColor3 = Color3.fromRGB(255,255,255); pBtn.TextSize = 14
				pBtn.Font = Enum.Font.GothamBold; pBtn.Parent = row
				local pC = Instance.new("UICorner"); pC.CornerRadius = UDim.new(0, 8); pC.Parent = pBtn
				local function updateCount()
					vL.Text = tostring(States.ClickerMulti.ClickerCount or 2)
					rebuildClickerBalls(States.ClickerMulti.ClickerCount or 2)
					setFeatureState("ClickerMulti", States.ClickerMulti.Enabled)
				end
				mBtn.MouseButton1Click:Connect(function()
					States.ClickerMulti.ClickerCount = math.max(1, (States.ClickerMulti.ClickerCount or 2) - 1)
					updateCount()
				end)
				pBtn.MouseButton1Click:Connect(function()
					States.ClickerMulti.ClickerCount = math.min(10, (States.ClickerMulti.ClickerCount or 2) + 1)
					updateCount()
				end)
				local tg = createToggle(row, feat.Key)
				tg.Position = UDim2.new(0, 316, 0.5, -13)
				local _, getCheck = createCheckbox(row, "即时落地", States.ClickerTile or false, function(v) States.ClickerTile = v end)
			else
				if isDrop then
					local dropContent = createDropdown(row, feat.Name, false, 10, function(newHeight)
						if not row.Parent then return end
						row.Size = UDim2.new(0, ROW_W, 0, newHeight)
						relayoutRows()
					end, ROW_W - 32)
					local dropContainer = dropContent.Parent
					dropContainer.Position = UDim2.new(0, 32, 0, 0)

					if feat.Key == "NpcDisplay" then
						addCheckboxes(dropContent, {
							{"渲染头部", States.NpcDisplay.ShowHead, function(v) States.NpcDisplay.ShowHead = v end},
							{"渲染身体", States.NpcDisplay.ShowTorso, function(v) States.NpcDisplay.ShowTorso = v end},
							{"渲染四肢", States.NpcDisplay.ShowLimbs, function(v) States.NpcDisplay.ShowLimbs = v end},
							{"显示骨骼", States.NpcDisplay.ShowBones, function(v) States.NpcDisplay.ShowBones = v end},
						})
					elseif feat.Key == "PlayerDisplay" then
						addCheckboxes(dropContent, {
							{"渲染头部", States.PlayerDisplay.ShowHead, function(v) States.PlayerDisplay.ShowHead = v end},
							{"渲染身体", States.PlayerDisplay.ShowTorso, function(v) States.PlayerDisplay.ShowTorso = v end},
							{"渲染四肢", States.PlayerDisplay.ShowLimbs, function(v) States.PlayerDisplay.ShowLimbs = v end},
							{"显示骨骼", States.PlayerDisplay.ShowBones, function(v) States.PlayerDisplay.ShowBones = v end},
							{"显示名字", States.PlayerDisplay.ShowName, function(v) States.PlayerDisplay.ShowName = v end},
							{"显示距离", States.PlayerDisplay.ShowDistance, function(v) States.PlayerDisplay.ShowDistance = v end},
							{"显示血量", States.PlayerDisplay.ShowHealth, function(v) States.PlayerDisplay.ShowHealth = v end},
						})
					elseif feat.Key == "BoxCreature" then
						addCheckboxes(dropContent, {
							{"框选NPC", States.BoxCreature.BoxNpc, function(v) States.BoxCreature.BoxNpc = v end},
							{"框选玩家", States.BoxCreature.BoxPlayer, function(v) States.BoxCreature.BoxPlayer = v end},
							{"框选其他", States.BoxCreature.BoxOther, function(v) States.BoxCreature.BoxOther = v end},
							{"只框存活", States.BoxCreature.BoxAliveOnly, function(v) States.BoxCreature.BoxAliveOnly = v end},
						})
						local modeLabel = Instance.new("TextLabel")
						modeLabel.Size = UDim2.new(1, 0, 0, 20); modeLabel.BackgroundTransparency = 1
						modeLabel.Text = "框模式: " .. (States.BoxCreature.BoxMode == "3D" and "3D立体框" or "2D平面框")
						modeLabel.TextColor3 = Color3.fromRGB(220, 220, 255); modeLabel.TextSize = 11
						modeLabel.Font = Enum.Font.Gotham; modeLabel.Parent = dropContent
						local modeRow = createBtnRow(dropContent, 26)
						local btn2D = createButton(modeRow, "Box2D", UDim2.new(0.48, 0, 0, 24), UDim2.new(), C.BtnDark, "2D平面框")
						local btn3D = createButton(modeRow, "Box3D", UDim2.new(0.48, 0, 0, 24), UDim2.new(0.52, 0, 0, 0), C.BtnDark, "3D立体框")
						local btns = {btn2D, btn3D}
						btn2D.MouseButton1Click:Connect(function()
							States.BoxCreature.BoxMode = "2D"
							btn2D.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
							btn3D.BackgroundColor3 = C.BtnDark
							modeLabel.Text = "框模式: 2D平面框"
						end)
						btn3D.MouseButton1Click:Connect(function()
							States.BoxCreature.BoxMode = "3D"
							btn3D.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
							btn2D.BackgroundColor3 = C.BtnDark
							modeLabel.Text = "框模式: 3D立体框"
						end)
						if States.BoxCreature.BoxMode == "3D" then btn3D.BackgroundColor3 = Color3.fromRGB(0, 150, 80) else btn2D.BackgroundColor3 = Color3.fromRGB(0, 150, 80) end
						createCheckbox(dropContent, "显示碰撞箱", States.BoxCreature.ShowHitbox, function(v) States.BoxCreature.ShowHitbox = v end)
						createLabeledStep(dropContent, "📏 框选距离 (0=无限)",
							function() return States.BoxCreature.MaxDistance end,
							function(v) States.BoxCreature.MaxDistance = v end,
							50, 0, 5000)
					elseif feat.Key == "LineConnect" then
						addCheckboxes(dropContent, {
							{"连接玩家", States.LineConnect.ConnectPlayer, function(v) States.LineConnect.ConnectPlayer = v end},
							{"连接NPC", States.LineConnect.ConnectNpc, function(v) States.LineConnect.ConnectNpc = v end},
							{"连接其他", States.LineConnect.ConnectOther, function(v) States.LineConnect.ConnectOther = v end},
							{"检测墙体", States.LineConnect.LineWallCheck, function(v) States.LineConnect.LineWallCheck = v end},
						})
						local originLabel = Instance.new("TextLabel")
						originLabel.Size = UDim2.new(1, 0, 0, 20); originLabel.BackgroundTransparency = 1
						originLabel.Text = "线起点: 上方"
						originLabel.TextColor3 = Color3.fromRGB(220, 220, 255); originLabel.TextSize = 11
						originLabel.Font = Enum.Font.Gotham; originLabel.Parent = dropContent
						local originRow = createBtnRow(dropContent, 24)
						local btnTop = createButton(originRow, "LCTop", UDim2.new(0.32, 0, 0, 22), UDim2.new(), C.BtnDark, "上方")
						local btnBot = createButton(originRow, "LCBot", UDim2.new(0.32, 0, 0, 22), UDim2.new(0.34, 0, 0, 0), C.BtnDark, "下方")
						local btnCross = createButton(originRow, "LCCross", UDim2.new(0.32, 0, 0, 22), UDim2.new(0.68, 0, 0, 0), C.BtnDark, "准心")
						local function updateOrigin()
							local o = States.LineConnect.Origin or "Top"
							btnTop.BackgroundColor3 = o == "Top" and Color3.fromRGB(0,150,80) or C.BtnDark
							btnBot.BackgroundColor3 = o == "Bottom" and Color3.fromRGB(0,150,80) or C.BtnDark
							btnCross.BackgroundColor3 = o == "Cross" and Color3.fromRGB(0,150,80) or C.BtnDark
							originLabel.Text = "线起点: " .. (o == "Top" and "上方" or (o == "Bottom" and "下方" or "准心"))
						end
						btnTop.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Top"; updateOrigin() end)
						btnBot.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Bottom"; updateOrigin() end)
						btnCross.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Cross"; updateOrigin() end)
						updateOrigin()
						createLabeledStep(dropContent, "📏 连线距离 (0=无限)",
							function() return States.LineConnect.MaxDistance end,
							function(v) States.LineConnect.MaxDistance = v end,
							50, 0, 5000)
					elseif feat.Key == "AimbotV2" then
						addCheckboxes(dropContent, {
							{"自瞄玩家", States.AimbotV2.AimPlayer, function(v) States.AimbotV2.AimPlayer = v end},
							{"自瞄NPC", States.AimbotV2.AimNpc, function(v) States.AimbotV2.AimNpc = v end},
							{"自瞄其他生物", States.AimbotV2.AimOther, function(v) States.AimbotV2.AimOther = v end},
							{"检测墙体", States.AimbotV2.WallCheck, function(v) States.AimbotV2.WallCheck = v end},
							{"同队跳过", States.AimbotV2.TeamCheck, function(v) States.AimbotV2.TeamCheck = v end},
							{"存活检测", States.AimbotV2.AliveCheck, function(v) States.AimbotV2.AliveCheck = v end},
							{"平滑瞄准", States.AimbotV2.Smooth, function(v) States.AimbotV2.Smooth = v end},
							{"预判自瞄", States.AimbotV2.Predict, function(v) States.AimbotV2.Predict = v end},
						})
						local customBtn = createButton(dropContent, "CustomAim", UDim2.new(1, 0, 0, 26), UDim2.new(), Color3.fromRGB(90, 65, 160), "🎯 自定义自瞄对象")
						customBtn.TextSize = 12
						customBtn.MouseButton1Click:Connect(function()
							refreshCustomAimList()
							CustomAimFrame.Visible = true
						end)
						local parts = {"Head", "HumanoidRootPart", "Torso", "UpperTorso", "LowerTorso"}
						local aimLabel = Instance.new("TextLabel")
						aimLabel.Size = UDim2.new(1, 0, 0, 20); aimLabel.BackgroundTransparency = 1
						aimLabel.Text = "🎯 瞄准部位: " .. tostring(States.AimbotV2.AimPart)
						aimLabel.TextColor3 = Color3.fromRGB(220, 220, 255); aimLabel.TextSize = 11
						aimLabel.Font = Enum.Font.Gotham; aimLabel.Parent = dropContent
						local partRow = createBtnRow(dropContent, 26)
						for i, p in ipairs(parts) do
							local pBtn = createButton(partRow, p.."Aim", UDim2.new(0.18, 0, 0, 22), UDim2.new((i-1) * 0.205, 0, 0, 0), C.BtnDark, p)
							pBtn.TextSize = 9
							pBtn.MouseButton1Click:Connect(function()
								States.AimbotV2.AimPart = p
								aimLabel.Text = "🎯 瞄准部位: " .. p
							end)
						end
						createLabeledStep(dropContent, "⚡ 平移速度",
							function() return States.AimbotV2.AimSpeed end,
							function(v) States.AimbotV2.AimSpeed = v end,
							0.05, 0.02, 0.9,
							function(v) return string.format("%.2f", v) end)
						createLabeledStep(dropContent, "⭕ 圆圈大小",
							function() return States.AimbotV2.CircleSize end,
							function(v) States.AimbotV2.CircleSize = v end,
							10, 50, 500)
						createLabeledStep(dropContent, "📏 自瞄距离 (0=无限)",
							function() return States.AimbotV2.MaxDistance end,
							function(v) States.AimbotV2.MaxDistance = v end,
							50, 0, 5000)
					elseif feat.Key == "AdvancedESP" then
						addCheckboxes(dropContent, {
							{"显示方框", States.AdvancedESP.ShowBox, function(v) States.AdvancedESP.ShowBox = v end},
							{"显示名字", States.AdvancedESP.ShowName, function(v) States.AdvancedESP.ShowName = v end},
							{"显示血量", States.AdvancedESP.ShowHealth, function(v) States.AdvancedESP.ShowHealth = v end},
							{"显示距离", States.AdvancedESP.ShowDistance, function(v) States.AdvancedESP.ShowDistance = v end},
							{"骨骼线", States.AdvancedESP.Skeleton, function(v) States.AdvancedESP.Skeleton = v end},
							{"追踪线", States.AdvancedESP.Tracer, function(v) States.AdvancedESP.Tracer = v end},
							{"上色渲染(Chams)", States.AdvancedESP.ShowChams, function(v) States.AdvancedESP.ShowChams = v end},
							{"同队跳过", States.AdvancedESP.TeamCheck, function(v) States.AdvancedESP.TeamCheck = v end},
							{"显示同队", States.AdvancedESP.ShowTeam, function(v) States.AdvancedESP.ShowTeam = v end},
							{"检测墙体", States.AdvancedESP.WallCheck, function(v) States.AdvancedESP.WallCheck = v end},
						})
						local boxStyleLabel = Instance.new("TextLabel")
						boxStyleLabel.Size = UDim2.new(1, 0, 0, 20); boxStyleLabel.BackgroundTransparency = 1
						boxStyleLabel.Text = "方框样式: " .. (States.AdvancedESP.BoxStyle == "Corner" and "角框" or "全框")
						boxStyleLabel.TextColor3 = Color3.fromRGB(220, 220, 255); boxStyleLabel.TextSize = 11
						boxStyleLabel.Font = Enum.Font.Gotham; boxStyleLabel.Parent = dropContent
						local bsRow = createBtnRow(dropContent, 24)
						local cornerBtn = createButton(bsRow, "BoxCorner", UDim2.new(0.48, 0, 0, 22), UDim2.new(), C.BtnDark, "角框")
						local fullBtn = createButton(bsRow, "BoxFull", UDim2.new(0.48, 0, 0, 22), UDim2.new(0.52, 0, 0, 0), C.BtnDark, "全框")
						cornerBtn.MouseButton1Click:Connect(function() States.AdvancedESP.BoxStyle = "Corner"; boxStyleLabel.Text = "方框样式: 角框" end)
						fullBtn.MouseButton1Click:Connect(function() States.AdvancedESP.BoxStyle = "Full"; boxStyleLabel.Text = "方框样式: 全框" end)
						local hpStyleLabel = Instance.new("TextLabel")
						hpStyleLabel.Size = UDim2.new(1, 0, 0, 20); hpStyleLabel.BackgroundTransparency = 1
						hpStyleLabel.Text = "血条样式: 条形"
						hpStyleLabel.TextColor3 = Color3.fromRGB(220, 220, 255); hpStyleLabel.TextSize = 11
						hpStyleLabel.Font = Enum.Font.Gotham; hpStyleLabel.Parent = dropContent
						local hpRow = createBtnRow(dropContent, 24)
						local barBtn = createButton(hpRow, "HPBar", UDim2.new(0.32, 0, 0, 22), UDim2.new(), C.BtnDark, "条形")
						local textBtn = createButton(hpRow, "HPText", UDim2.new(0.32, 0, 0, 22), UDim2.new(0.34, 0, 0, 0), C.BtnDark, "文本")
						local bothBtn = createButton(hpRow, "HPBoth", UDim2.new(0.32, 0, 0, 22), UDim2.new(0.68, 0, 0, 0), C.BtnDark, "两者")
						local function updateHpButtons()
							local hs = States.AdvancedESP.HealthStyle or "Bar"
							barBtn.BackgroundColor3 = hs == "Bar" and Color3.fromRGB(0,150,80) or C.BtnDark
							textBtn.BackgroundColor3 = hs == "Text" and Color3.fromRGB(0,150,80) or C.BtnDark
							bothBtn.BackgroundColor3 = hs == "Both" and Color3.fromRGB(0,150,80) or C.BtnDark
							hpStyleLabel.Text = "血条样式: " .. (hs == "Bar" and "条形" or (hs == "Text" and "文本" or "两者"))
						end
						barBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Bar"; updateHpButtons() end)
						textBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Text"; updateHpButtons() end)
						bothBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Both"; updateHpButtons() end)
						updateHpButtons()
						local advOriginLabel = Instance.new("TextLabel")
						advOriginLabel.Size = UDim2.new(1, 0, 0, 20); advOriginLabel.BackgroundTransparency = 1
						advOriginLabel.Text = "线头位置: 底部"
						advOriginLabel.TextColor3 = Color3.fromRGB(220, 220, 255); advOriginLabel.TextSize = 11
						advOriginLabel.Font = Enum.Font.Gotham; advOriginLabel.Parent = dropContent
						local toRow = createBtnRow(dropContent, 24)
						local advTopBtn = createButton(toRow, "AdvTop", UDim2.new(0.48, 0, 0, 22), UDim2.new(), C.BtnDark, "顶部")
						local advBotBtn = createButton(toRow, "AdvBot", UDim2.new(0.48, 0, 0, 22), UDim2.new(0.52, 0, 0, 0), C.BtnDark, "底部")
						advTopBtn.MouseButton1Click:Connect(function() States.AdvancedESP.TracerOrigin = "Top"; advOriginLabel.Text = "线头位置: 顶部" end)
						advBotBtn.MouseButton1Click:Connect(function() States.AdvancedESP.TracerOrigin = "Bottom"; advOriginLabel.Text = "线头位置: 底部" end)
						createLabeledStep(dropContent, "📏 最大距离 (0=无限)",
							function() return States.AdvancedESP.MaxDistance end,
							function(v) States.AdvancedESP.MaxDistance = v end,
							100, 0, 5000)
					elseif feat.Key == "GameInfo" then
						local function addInfoRow(labelText, copyValue)
							local rowF = Instance.new("Frame")
							rowF.Size = UDim2.new(1, 0, 0, 26)
							rowF.BackgroundColor3 = Color3.fromRGB(30, 20, 66)
							rowF.BackgroundTransparency = 0.25
							rowF.BorderSizePixel = 0
							rowF.Parent = dropContent
							local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = rowF
							local lab = Instance.new("TextLabel")
							lab.Size = UDim2.new(1, -56, 1, 0)
							lab.Position = UDim2.new(0, 8, 0, 0)
							lab.BackgroundTransparency = 1
							lab.Text = labelText
							lab.TextColor3 = Color3.fromRGB(230, 230, 255)
							lab.TextSize = 11
							lab.Font = Enum.Font.Gotham
							lab.TextXAlignment = Enum.TextXAlignment.Left
							lab.Parent = rowF
							local copyBtn = createButton(rowF, "Copy", UDim2.new(0, 50, 0, 20), UDim2.new(1, -56, 0.5, -10), Color3.fromRGB(70, 55, 140), "复制")
							copyBtn.TextSize = 10
							copyBtn.MouseButton1Click:Connect(function()
								pcall(function() setclipboard(tostring(copyValue)) end)
							end)
						end
						addInfoRow("显示名称: " .. tostring(player.DisplayName or ""), player.DisplayName)
						addInfoRow("用户名: " .. tostring(player.Name or ""), player.Name)
						addInfoRow("用户ID: " .. tostring(player.UserId or ""), player.UserId)
						addInfoRow("注册天数: " .. tostring(player.AccountAge or ""), player.AccountAge)
						local placeName = "未知"
						pcall(function() placeName = MarketplaceService:GetProductInfo(game.PlaceId).Name or "未知" end)
						addInfoRow("服务器名称: " .. placeName, placeName)
						addInfoRow("PlaceId: " .. tostring(game.PlaceId or 0), game.PlaceId)
						local exeName = "未知"
						pcall(function() exeName = tostring(identifyexecutor() or "未知") end)
						addInfoRow("注入器: " .. exeName, exeName)
					end

					local tg = createToggle(row, feat.Key)
					tg.Position = UDim2.new(0, 316, 0.5, -13)
				else
					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(0, 84, 1, 0); label.Position = UDim2.new(0, 32, 0, 0)
					label.BackgroundTransparency = 1; label.Text = feat.Name
					label.TextColor3 = Color3.fromRGB(238, 238, 255); label.TextSize = 12
					label.Font = Enum.Font.GothamSemibold; label.TextXAlignment = Enum.TextXAlignment.Left
					label.Parent = row

					local tg = createToggle(row, feat.Key)
					tg.Position = UDim2.new(0, 316, 0.5, -13)

					if feat.Input then
						if feat.Key == "ColorFilter" then
							createColorCycle(row, feat.Key)
						else
							createStepControl(row, feat.Key)
						end
					end
				end
			end

			raiseZIndex(row, 9004)
		end)
		if ok and row then
			table.insert(FeatureRows, row)
			yOffset = yOffset + (feat.HasDropdown and 39 or 47)
		else
			if row then pcall(function() row:Destroy() end) end
		end
	end

	Gui.ScrollInner.Size = UDim2.new(0, ROW_W, 0, yOffset)
	Gui.ScrollInner.Position = UDim2.new(0, 6, 0, 0)
end
Gui.refreshFeatures = refreshFeatures

-- 分类按钮
local CatBtns = {}
for i, cat in ipairs(Categories) do
	local outer = Instance.new("Frame")
	outer.Size = UDim2.new(0, 78, 0, 34)
	outer.BackgroundTransparency = 0
	outer.BorderSizePixel = 0
	outer.Parent = Gui.ButtonWrap
	local oC = Instance.new("UICorner"); oC.CornerRadius = UDim.new(0, 12); oC.Parent = outer
	local oGrad = Instance.new("UIGradient")
	oGrad.Color = ColorSequence.new(Color3.fromRGB(255, 50, 150), Color3.fromRGB(50, 110, 255))
	oGrad.Rotation = 90
	oGrad.Parent = outer
	Gui.CatGrads = Gui.CatGrads or {}
	table.insert(Gui.CatGrads, oGrad)

	local inner = Instance.new("Frame")
	inner.Size = UDim2.new(1, -4, 1, -4)
	inner.Position = UDim2.new(0, 2, 0, 2)
	inner.BackgroundColor3 = Color3.fromRGB(22, 16, 56)
	inner.BackgroundTransparency = 0.3
	inner.BorderSizePixel = 0
	inner.Parent = outer
	local iC = Instance.new("UICorner"); iC.CornerRadius = UDim.new(0, 10); iC.Parent = inner

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Text = cat.Name
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.TextSize = 12
	text.Font = Enum.Font.GothamBold
	text.ZIndex = 9012
	text.Parent = outer

	local hit = Instance.new("Frame")
	hit.Size = UDim2.new(1, 0, 1, 0)
	hit.BackgroundTransparency = 1
	hit.Active = true
	hit.ZIndex = 9007
	hit.Parent = outer
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			CurrentCategory = i
			moveCatIndicator(i)
			pcall(Gui.refreshFeatures)
		end
	end)
	CatBtns[i] = hit
end

pcall(refreshFeatures)

-- ============================================
-- 保险机制: 每2秒检查已开启功能
-- ============================================
task.spawn(function()
	while true do
		task.wait(2)
		for key, state in pairs(States) do
			if type(state) == "table" and state.Enabled and Updaters[key] then
				local skip = key == "AutoSave" or key == "AntiAfk" or key == "ClickerStart" or key == "DynamicIsland" or key == "MusicPlayer" or key == "RemoteInteract"
				if not skip and Conns[key] == nil then
					pcall(Updaters[key])
				end
			end
		end
	end
end)

-- ============================================
-- 形态保险机制: 每0.5秒强制执行正确形态
-- ============================================
task.spawn(function()
	while true do
		task.wait(0.5)
		if States.DynamicIsland and not States.DynamicIsland.Enabled then
			if Gui.MainPanel and not PanelOpen and Gui.MainPanel.Visible then
				Gui.MainPanel.Visible = false
			end
			if not Gui.FloatBall or not Gui.FloatBall.Parent then
				createFloatBall()
			end
		else
			if Gui.FloatBall then
				pcall(function() Gui.FloatBall:Destroy() end)
				Gui.FloatBall = nil
			end
		end
	end
end)

-- ============================================
-- 重生后自动恢复状态
-- ============================================
function applyActiveStates()
	for key, _ in pairs(States) do
		local updater = Updaters[key]
		if updater and States[key].Enabled then
			pcall(updater)
		end
	end
end

player.CharacterRemoving:Connect(function()
	if CeMouseInteractConn then
		pcall(function() CeMouseInteractConn:Disconnect() end)
		CeMouseInteractConn = nil
	end
	for name, conn in pairs(Conns) do
		if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
		Conns[name] = nil
	end
	clearRenderCache()
end)

-- ============================================
-- 加载配置 + 应用已启用功能 + 加载完成
-- ============================================
loadConfig()
for key, state in pairs(States) do
	if ToggleRefreshers[key] then pcall(ToggleRefreshers[key], state.Enabled) end
	if type(state) == "table" and state.Enabled and Updaters[key] then
		pcall(Updaters[key])
	end
end
pcall(Gui.refreshFeatures)

local elapsed = tick() - LoadStartTime
if LoadingText then
	LoadingText.Text = string.format("✅ 加载完成 | 耗时 %.2fs | V6.2", elapsed)
	LoadingText.TextColor3 = Color3.fromRGB(120, 255, 160)
end
task.delay(0.6, function()
	if LoadingFrame and LoadingFrame.Parent then
		local ls = LoadingFrame:FindFirstChildOfClass("UIScale")
		if ls then tween(ls, {Scale = 0.5}, TweenSmooth) end
		tween(LoadingFrame, {Position = UDim2.new(0.5, -160, 0.3, -39)}, TweenSmooth)
		task.delay(0.45, function()
			if LoadingFrame then pcall(function() LoadingFrame:Destroy() end) end
		end)
	end
end)

print("[NinjaHubV6.2] 加载完成 | 全套6.2功能已启用")
--[[V62_END]]