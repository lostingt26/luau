-- ============================================
-- Ninja Hub V6.4 - 超级自动化版
-- 新增: 点击脚本 / 远程互动 / 多球调节 / 自定义传送
-- V6.4: 按键映射 / 本地音乐 / 反作弊保护 / 删除客户端脚本
-- 优化: 悬浮球UI / 面板动画 / 数据刷新动画
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
-- 反作弊保护 (V6.4, 基于Ninja注入器钩子系统)
-- ============================================
do
	-- 兼容别名弱化: 若缺失则补空, 避免语法/运行报错
	_G.hookfunction = _G.hookfunction or function() end
	_G.hookmetamethod = _G.hookmetamethod or function() end
	_G.newcclosure = _G.newcclosure or function(f) return f end
	_G.getgenv = _G.getgenv or function() return _G end
	_G.getrawmetatable = _G.getrawmetatable or function() end
	_G.setreadonly = _G.setreadonly or function() end
	_G.checkcaller = _G.checkcaller or function() return true end

	-- 1) 保护注入环境表, 阻止反作弊改造/清空我们注册的全局
	local okGenv, genv = pcall(getgenv)
	if okGenv and type(genv) == "table" then
		pcall(function()
			setreadonly(genv, false)
			genv.NinjaHubSession = tick()
		end)
	end

	-- 2) 阻止游戏踢出/封禁 (反踢保护, 仅针对本地玩家)
	if typeof(Players) == "Instance" then
		pcall(function()
			local lp = Players.LocalPlayer
			if lp and typeof(lp) == "Instance" and lp.Kick then
				hookfunction(lp.Kick, newcclosure(function() return true end))
			end
		end)
	end
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
	ClickerMulti = {Enabled = false, BallCount = 4},
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
	NpcDisplay = {Enabled = false, ShowHead = true, ShowTorso = true, ShowLimbs = true, ShowBones = true},
	PlayerDisplay = {Enabled = false, ShowHead = true, ShowTorso = true, ShowLimbs = true, ShowBones = true, ShowName = true, ShowDistance = true, ShowHealth = true},
	BoxCreature = {Enabled = false, BoxNpc = true, BoxPlayer = true, BoxOther = true, BoxAliveOnly = false, BoxMode = "3D", ShowHitbox = false, MaxDistance = 0},
	LineConnect = {Enabled = false, ConnectNpc = false, ConnectPlayer = true, ConnectOther = false, LineWallCheck = false, Origin = "Top", MaxDistance = 0},
	AimbotV2 = {Enabled = false, AimPlayer = true, AimNpc = false, AimOther = false, AimPart = "Head", CircleSize = 150, AimSpeed = 0.3, WallCheck = false, TeamCheck = false, AliveCheck = true, Smooth = true, Predict = false, SelectedCustom = {}, MaxDistance = 0},
	AutoFire = {Enabled = false},
	AdvancedESP = {
		Enabled = false, ShowBox = true, BoxStyle = "Corner", BoxThickness = 1,
		ShowName = true, ShowHealth = true, ShowDistance = true, HealthStyle = "Bar",
		ShowChams = true, TeamCheck = false, ShowTeam = false, WallCheck = false,
		Tracer = false, TracerOrigin = "Bottom", Skeleton = false, MaxDistance = 300,
	},
	-- V6.2 新功能
	ClickScript = {Enabled = false, Steps = {}, Running = false, RepeatCount = 1, SavedScripts = {}},
	-- V6.3 新功能
	RemoteInteract = {Enabled = false, Range = 400},
	CustomTeleport = {Enabled = false, Mode = 1, Coords = {}},
	-- V6.4 按键映射
	KeyMapping = {Enabled = false, Recording = false, Keys = {}},
	-- V6.5 新功能
	FeatureHUD = {Enabled = false, Mode = "line", ShowBg = true, Bold = false, Direction = "forward", Palette = "rainbow", Colors = nil, Pos = nil},
	BigSpin = {Enabled = false, Speed = 30},
	GodSoul = {Enabled = false},
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

local ClickerThread, AntiAfkThread, AutoSaveThread
local ClickScriptThread

local ScriptClosed = false

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
local TweenFadeIn = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TweenFadeOut = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
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

-- ============================================
-- 关闭脚本: 清除全部UI并停止所有功能
-- ============================================
local function closeTheScript()
	if ScriptClosed then return end
	ScriptClosed = true
	-- 断开所有功能连接
	for name, conn in pairs(Conns) do
		if typeof(conn) == "RBXScriptConnection" then
			pcall(function() conn:Disconnect() end)
		end
		Conns[name] = nil
	end
	for k in pairs(Conns) do Conns[k] = nil end
	-- 关闭所有功能状态
	for key, state in pairs(States) do
		if type(state) == "table" then state.Enabled = false end
	end
	-- 清除全部UI
	pcall(function() ScreenGui:Destroy() end)
	-- 恢复被改动的角色属性
	pcall(function()
		if humanoid then
			humanoid.AutoRotate = true
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end
	end)
	pcall(function()
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
					part.CanTouch = true
					part.CanQuery = true
					part.Transparency = 0
				end
			end
		end
	end)
	print("[NinjaHubV6.2] 脚本已关闭, 所有功能和UI已清除")
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
	BigSpin = 5,
}
local MinMap = {
	WalkSpeed = 1, TpWalk = 1, BunnyHop = 1, JumpHeight = 1,
	SuperJump = 1, WallClimb = 1, KillAura = 1, AutoClicker = 1,
	GravityMod = 0, TimeOfDay = 0, DangerWarning = 1,
	BigSpin = 1,
}
local MaxMap = {
	WalkSpeed = 500, TpWalk = 100, BunnyHop = 100, JumpHeight = 500,
	SuperJump = 500, WallClimb = 200, KillAura = 100, AutoClicker = 5000,
	GravityMod = 1000, TimeOfDay = 24, DangerWarning = 500,
	BigSpin = 500,
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
local function makeDraggable(guiObject, handle, onRelease, pressDuration)
	pressDuration = pressDuration or 1.0
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
					if tick() - state.pressTime >= pressDuration and state.moved < 40 then
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

-- V6.2: 可调整大小的面板
local function makeResizable(panel, minSize, maxSize)
	minSize = minSize or Vector2.new(200, 150)
	maxSize = maxSize or Vector2.new(600, 500)
	local resizing = false
	local resizeStart = Vector2.zero
	local startSize = Vector2.new(0, 0)
	
	local handle = Instance.new("Frame")
	handle.Size = UDim2.new(0, 16, 0, 16)
	handle.Position = UDim2.new(1, -16, 1, -16)
	handle.BackgroundTransparency = 1
	handle.Parent = panel
	
	local resizeHit = Instance.new("TextButton")
	resizeHit.Size = UDim2.new(1, 0, 1, 0)
	resizeHit.BackgroundTransparency = 1
	resizeHit.Text = "◢"
	resizeHit.TextColor3 = Color3.fromRGB(255, 255, 255)
	resizeHit.TextSize = 10
	resizeHit.Parent = handle
	
	resizeHit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = true
			resizeStart = input.Position
			startSize = Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
		end
	end)
	
	UserInputService.InputChanged:Connect(function(input)
		if not resizing then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local dx = input.Position.X - resizeStart.X
			local dy = input.Position.Y - resizeStart.Y
			local newW = math.clamp(startSize.X + dx, minSize.X, maxSize.X)
			local newH = math.clamp(startSize.Y + dy, minSize.Y, maxSize.Y)
			panel.Size = UDim2.new(0, newW, 0, newH)
		end
	end)
	
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)
end

-- ============================================
-- 音乐系统 V6.3 (Deezer国际版, 全球可用)
-- ============================================
local MUSIC_API = {
	search = {
		"https://api.deezer.com/search?q=%s&limit=20",
	},
	recommend = {
		"https://api.deezer.com/chart/0/tracks",
	},
}
local Music = {
	Open = false, Tab = "Rec", List = {}, Idx = 1,
	Current = nil, Playing = false, Mode = 0,
	ModeNames = {"🔁 列表循环", "🔂 单曲循环", "➡️ 顺序播放"},
	HasBox = false,
	-- V6.4: 本地音乐
	Src = "net", LocalPath = "musics", LocalIndex = 1,
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

local function isVip(fee)
	return fee == 1 or fee == 128 or fee == 6
end

-- V6.1: 三通道HTTP请求: game:HttpGet(注入器扩展) → request → GetAsync
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

local function parseSongs(songs)
	local list = {}
	for _, s in ipairs(songs) do
		local artist = "未知"
		-- Deezer 格式: artist={name=...}; 兼容旧格式 ar={[1]={name=...}}
		if s.artist and s.artist.name then artist = s.artist.name
		elseif s.ar and s.ar[1] then artist = s.ar[1].name end
		table.insert(list, {
			id = s.id, name = (s.title or s.name or "?"), artist = artist,
			-- Deezer duration为秒, 转毫秒
			dt = (s.duration and s.duration * 1000) or (s.dt or 200000),
			vip = false,
			preview = s.preview,
		})
	end
	return list
end

-- V6.3: Deezer搜索
local function searchMusic(kw)
	local enc = ""
	pcall(function() enc = HttpService:UrlEncode(kw) end)
	if #enc == 0 then enc = kw end
	for _, u in ipairs(MUSIC_API.search) do
		local body = httpJson(string.format(u, enc))
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and data and data.data and #data.data > 0 then
				return parseSongs(data.data)
			end
		end
	end
	return nil
end

-- V6.3: Deezer推荐榜单
local function getRecommend()
	for _, u in ipairs(MUSIC_API.recommend) do
		local body = httpJson(u)
		if body then
			local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
			if ok and data and data.data and #data.data > 0 then
				return parseSongs(data.data)
			end
		end
	end
	return nil
end

-- ============================================
-- V6.4: 本地音乐模式 (播放本地文件夹中的MP3)
-- 注入器申请了手机存储权限, 使用 io 读写本地文件
-- ============================================
local function localSourcePath()
	-- 优先使用 ninja 注入器工作区路径, 回退到根路径
	local ws = ""
	pcall(function() ws = ninja.GetWorkspacePath() or "" end)
	if #ws == 0 then
		pcall(function() ws = getworkspacepath() or "" end)
	end
	return ws
end

local function scanLocalMusic()
	-- 扫描本地文件夹下的 .mp3 文件列表
	local list = {}
	local base = localSourcePath()
	local folder = base .. "/" .. (Music.LocalPath or "musics")
	local files = {}
	pcall(function()
		local ls = io.popen('dir /b "' .. folder .. '" 2>nul')
		if ls then
			for line in ls:lines() do
				if string.find(string.lower(line), ".mp3") then
					table.insert(files, line)
				end
			end
			ls:close()
		end
	end)
	-- 兼容linux/mac的ls
	if #files == 0 then
		pcall(function()
			local ls = io.popen('ls "' .. folder .. '" 2>/dev/null')
			if ls then
				for line in ls:lines() do
					if string.find(string.lower(line), ".mp3") then
						table.insert(files, line)
					end
				end
				ls:close()
			end
		end)
	end
	for i, f in ipairs(files) do
		table.insert(list, {
			id = "local" .. i,
			name = f,
			artist = "本地",
			dt = 200000,
			vip = false,
			-- path 用于读取
			localPath = folder .. "/" .. f,
		})
	end
	return list
end

-- 读取本地MP3字节并通过 playfile 播放 (受引擎限制, 能读则尽量放)
local function playLocalSong(song)
	if not song.localPath then return false end
	local content = nil
	pcall(function()
		local f = io.open(song.localPath, "rb")
		if f then
			content = f:read("*a")
			f:close()
		end
	end)
	if not content then return false end
	local okW = pcall(function() writefile("NHMusic.mp3", content) end)
	if not okW then
		pcall(function()
			local f = io.open("NHMusic.mp3", "wb")
			f:write(content)
			f:close()
		end)
	end
	local okP = pcall(function()
		if not playfile then error("no playfile") end
		playfile("NHMusic.mp3")
	end)
	return okP
end

-- 扫playfile的本地路径(传完整路径尝试)
local function playLocalDirect(song)
	local okP = pcall(function()
		if not playfile then error("no playfile") end
		playfile(song.localPath)
	end)
	return okP
end

-- V6.3: 下载 mp3 (使用Deezer preview直链)
local function downloadSong(song)
	local url = song.preview or string.format("https://cdns-preview-d.dzcdn.net/stream/c-%s-1.mp3", tostring(song.id))
	local ok1, res = pcall(function()
		local r = request({Url = url, Method = "GET"})
		return r
	end)
	if ok1 and res and res.StatusCode == 200 and res.Body and #res.Body > 2000 then
		return res.Body
	end
	local ok2, b2 = pcall(function() return game:HttpGet(url, true) end)
	if ok2 and type(b2) == "string" and #b2 > 2000 and not b2:find("<html") and not b2:find("<!DOCTYPE") then
		return b2
	end
	local ok3, b3 = pcall(function() return HttpService:GetAsync(url) end)
	if ok3 and type(b3) == "string" and #b3 > 2000 and not b3:find("<html") and not b3:find("<!DOCTYPE") then
		return b3
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
		-- V6.4: 本地音乐优先走本地读取
		if s.localPath then
			local okP = playLocalDirect(s)
			if not okP then okP = playLocalSong(s) end
			if okP then
				Music.Playing = true
				updateMusicPlayBtn()
				musicToast("▶ 播放本地: " .. s.name)
				if MusicTimer then task.cancel(MusicTimer) end
				MusicTimer = task.delay(math.max((s.dt or 200000) / 1000 + 1.5, 5), function()
					if Music.Current == s and Music.Playing then
						onMusicEnd()
					end
				end)
			else
				musicToast("⚠ 无法播放: " .. s.name)
				onMusicEnd()
			end
			return
		end
		local body = downloadSong(s)
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
			musicToast("🔒 " .. s.name .. " 为VIP歌曲, 无法播放")
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
	table.insert(favs, {id = song.id, name = song.name, artist = song.artist, dt = song.dt or 200000, vip = song.vip})
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
	elseif tab == "Local" then
		-- V6.4: 本地音乐
		Music.List = {}
		musicToast("📂 扫描本地音乐中...")
		task.spawn(function()
			local list = scanLocalMusic()
			if list and #list > 0 then
				Music.List = list
				Music.Idx = 1
				musicToast("✅ 找到本地MP3 " .. #list .. " 首")
			else
				musicToast("⚠ 未找到MP3 (请在 " .. (Music.LocalPath or "musics") .. " 文件夹放入mp3)")
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
	local tabs = {{"Rec", "推荐"}, {"Search", "搜索"}, {"Local", "本地"}, {"Favs", "收藏"}}
	for i, t in ipairs(tabs) do
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0, 90, 0, 24)
		b.Position = UDim2.new(0, (i - 1) * 93, 0, 2)
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

-- V6.2: 预生成面板用于非灵动岛模式
local PreGeneratedPanel = nil
local function preGeneratePanel()
	if PreGeneratedPanel then return end
	PreGeneratedPanel = Instance.new("Frame")
	PreGeneratedPanel.Name = "PreGeneratedPanel"
	PreGeneratedPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
	PreGeneratedPanel.Position = UDim2.new(0.5, -PANEL_W/2, 0, 10)
	PreGeneratedPanel.AnchorPoint = Vector2.new(0.5, 0)
	PreGeneratedPanel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	PreGeneratedPanel.BackgroundTransparency = 0.35
	PreGeneratedPanel.ClipsDescendants = true
	PreGeneratedPanel.BorderSizePixel = 0
	PreGeneratedPanel.ZIndex = 9000
	PreGeneratedPanel.Visible = false
	PreGeneratedPanel.Parent = ScreenGui
	local mpC = Instance.new("UICorner"); mpC.CornerRadius = UDim.new(0, 24); mpC.Parent = PreGeneratedPanel
	local mpStroke = createGrayStroke(PreGeneratedPanel, 2)
	local mpGrad = Instance.new("UIGradient")
	mpGrad.Color = ColorSequence.new(Color3.fromRGB(24, 14, 56), Color3.fromRGB(38, 22, 84))
	mpGrad.Rotation = 90
	mpGrad.Parent = PreGeneratedPanel
	local PanelScale = Instance.new("UIScale")
	PanelScale.Scale = 1
	PanelScale.Parent = PreGeneratedPanel

	-- 复制主面板的所有内容到预生成面板
	local function cloneChildren(src, dst)
		for _, child in ipairs(src:GetChildren()) do
			local clone = child:Clone()
			clone.Parent = dst
			if child:IsA("Frame") or child:IsA("ScrollingFrame") then
				cloneChildren(child, clone)
			end
		end
	end
	-- 这里我们只克隆结构,实际内容在打开时刷新
end

local function togglePanel()
	PanelOpen = not PanelOpen
	if Gui.MainPanel then Gui.MainPanel.Visible = true end
	if PanelOpen then
		-- 打开面板
		if States.DynamicIsland and States.DynamicIsland.Enabled then
			Gui.MainPanel.Size = UDim2.new(0, ISLAND_W, 0, ISLAND_H)
			Gui.MainPanel.Position = UDim2.new(0.5, 0, 0, 10)
			Gui.MainPanel.AnchorPoint = Vector2.new(0.5, 0)
		else
			-- V6.2: 非灵动岛模式从左到右淡入
			Gui.MainPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
			Gui.MainPanel.Position = UDim2.new(-PANEL_W, 0, 0, 10)
			Gui.MainPanel.AnchorPoint = Vector2.new(0, 0)
			Gui.MainPanel.Visible = true
		end
		Gui.ContentScale.Scale = 0.9
		Gui.PanelScale.Scale = 0.92
		if States.DynamicIsland and States.DynamicIsland.Enabled then
			tween(Gui.MainPanel, {Size = UDim2.new(0, PANEL_W, 0, PANEL_H)}, TweenPanelOpen)
		else
			tween(Gui.MainPanel, {Position = UDim2.new(0.5, -PANEL_W/2, 0, 10)}, TweenFadeIn)
		end
		tween(Gui.PanelScale, {Scale = 1}, TweenScalePop)
		tween(Gui.ContentScale, {Scale = 1}, TweenScalePop)
		staggerIn()
		pulseIsland()
		Gui.IslandRightText.Text = "✕ 收起"
	else
		-- 关闭面板
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
			-- V6.2: 非灵动岛模式从左到右淡出
			tween(Gui.MainPanel, {Position = UDim2.new(-PANEL_W, 0, 0, 10)}, TweenFadeOut)
			task.delay(0.3, function()
				if Gui.MainPanel then Gui.MainPanel.Visible = false end
				Gui.MainPanel.Position = UDim2.new(0.5, -PANEL_W/2, 0, 10)
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
-- 悬浮球 V6.2 (更像面板)
-- ============================================
local function createFloatBall()
	if Gui.FloatBall then return Gui.FloatBall end
	local ball = Instance.new("Frame")
	ball.Name = "NinjaFloatBall"
	ball.Size = UDim2.new(0, 120, 0, 38)
	local savedPos = States.FloatBallPos
	if type(savedPos) == "table" and #savedPos == 4 then
		ball.Position = UDim2.new(savedPos[1], savedPos[2], savedPos[3], savedPos[4])
	else
		ball.Position = UDim2.new(0.5, -60, 0, 110)
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
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 12); bc.Parent = ball

	local core = Instance.new("Frame")
	core.Size = UDim2.new(1, -6, 1, -6)
	core.Position = UDim2.new(0, 3, 0, 3)
	core.BackgroundColor3 = Color3.fromRGB(5, 5, 15)
	core.BackgroundTransparency = 0.45
	core.BorderSizePixel = 0
	core.Parent = ball
	local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 10); cc.Parent = core

	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.new(1, 0, 1, 0)
	txt.BackgroundTransparency = 1
	txt.Text = "⚡ 菜单"
	txt.TextColor3 = Color3.fromRGB(255, 255, 255)
	txt.TextSize = 14
	txt.Font = Enum.Font.GothamBold
	txt.Parent = ball

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
			if ls and ls.Parent then tween(ls, {Scale = 1.15}, TweenScalePop) end
		end)
		task.delay(0.34, function()
			if ls and ls.Parent then tween(ls, {Scale = 1}, TweenScalePop) end
		end)
		-- V6.2: 修复非灵动岛模式点击悬浮球打开面板
		if not States.DynamicIsland.Enabled then
			if not PanelOpen then
				-- 打开面板
				PanelOpen = true
				if Gui.MainPanel then
					Gui.MainPanel.Visible = true
					Gui.MainPanel.Size = UDim2.new(0, PANEL_W, 0, PANEL_H)
					Gui.MainPanel.Position = UDim2.new(-PANEL_W, 0, 0, 10)
					Gui.MainPanel.AnchorPoint = Vector2.new(0, 0)
					tween(Gui.MainPanel, {Position = UDim2.new(0.5, -PANEL_W/2, 0, 10)}, TweenFadeIn)
				end
				Gui.IslandRightText.Text = "✕ 收起"
			else
				-- 关闭面板
				PanelOpen = false
				if Gui.MainPanel then
					tween(Gui.MainPanel, {Position = UDim2.new(-PANEL_W, 0, 0, 10)}, TweenFadeOut)
					task.delay(0.3, function()
						if Gui.MainPanel then Gui.MainPanel.Visible = false end
						Gui.MainPanel.Position = UDim2.new(0.5, -PANEL_W/2, 0, 10)
					end)
				end
				Gui.IslandRightText.Text = "≡ 菜单"
			end
		else
			togglePanel()
		end
	end)

	task.spawn(function()
		while ball and ball.Parent do
			core.BackgroundTransparency = 0.35 + 0.15 * math.sin(tick() * 2.6)
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
		-- V6.2: 非灵动岛模式不拦截顶部点击(让悬浮球正常工作)
		if Gui.MainPanel and Gui.MainPanel.Visible and States.DynamicIsland.Enabled then
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
				Gui.ServerInfoText.Text = string.format("服务器: %s\nPlaceId: %d\n延迟: %dms\nFPS: %d", Gui.GameName or "未知", game.PlaceId or 0, ping, fps)
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
				Gui.NearestText.Text = nearest and ("最近: " .. nearest.Plr.Name .. "  " .. string.format("%.1f", nd) .. "m") or "最近: 无"
			end
			if Gui.StatText then
				local count = 0
				for _, s in pairs(States) do
					if type(s) == "table" and s.Enabled then count = count + 1 end
				end
				Gui.StatText.Text = "已开启: " .. count .. " 个功能"
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
			Fly1SpeedLabel.Text = "速度: " .. States.Fly1.Value
		end
	end)
	Fly1MinusBtn.MouseButton1Click:Connect(function()
		States.Fly1.Value = math.max(1, States.Fly1.Value - 5)
		Fly1SpeedBox.Text = tostring(States.Fly1.Value)
		Fly1SpeedLabel.Text = "速度: " .. States.Fly1.Value
	end)
	Fly1PlusBtn.MouseButton1Click:Connect(function()
		States.Fly1.Value = math.min(500, States.Fly1.Value + 5)
		Fly1SpeedBox.Text = tostring(States.Fly1.Value)
		Fly1SpeedLabel.Text = "速度: " .. States.Fly1.Value
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
			Fly2SpeedLabel.Text = "速度: " .. States.Fly2.Value
		end
	end)
	Fly2MinusBtn.MouseButton1Click:Connect(function()
		States.Fly2.Value = math.max(1, States.Fly2.Value - 5)
		Fly2SpeedBox.Text = tostring(States.Fly2.Value)
		Fly2SpeedLabel.Text = "速度: " .. States.Fly2.Value
	end)
	Fly2PlusBtn.MouseButton1Click:Connect(function()
		States.Fly2.Value = math.min(500, States.Fly2.Value + 5)
		Fly2SpeedBox.Text = tostring(States.Fly2.Value)
		Fly2SpeedLabel.Text = "速度: " .. States.Fly2.Value
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
			FreeMoveSpeedLabel.Text = "速度:" .. States.FreeMove.Value
		end
	end)
	FreeMoveMinus.MouseButton1Click:Connect(function()
		States.FreeMove.Value = math.max(1, States.FreeMove.Value - 5)
		FreeMoveSpeedBox.Text = tostring(States.FreeMove.Value)
		FreeMoveSpeedLabel.Text = "速度:" .. States.FreeMove.Value
	end)
	FreeMovePlus.MouseButton1Click:Connect(function()
		States.FreeMove.Value = math.min(500, States.FreeMove.Value + 5)
		FreeMoveSpeedBox.Text = tostring(States.FreeMove.Value)
		FreeMoveSpeedLabel.Text = "速度:" .. States.FreeMove.Value
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
-- UI构建: 连点器系统
-- ============================================
local function buildClickerSystem()
	local ClickerBalls = {}
	local ClickerBallTemplate = Instance.new("Frame")
	ClickerBallTemplate.Size = UDim2.new(0,35,0,35)
	ClickerBallTemplate.BackgroundColor3 = Color3.fromRGB(100,200,255)
	ClickerBallTemplate.BackgroundTransparency = 0.2
	ClickerBallTemplate.Visible = false
	ClickerBallTemplate.ZIndex = 9100
	local cbC = Instance.new("UICorner"); cbC.CornerRadius = UDim.new(1,0); cbC.Parent = ClickerBallTemplate
	local cbS = Instance.new("UIStroke"); cbS.Color = Color3.fromRGB(160,200,240); cbS.Thickness = 2; cbS.Parent = ClickerBallTemplate

	local CrossH = Instance.new("Frame")
	CrossH.Size = UDim2.new(0,20,0,2); CrossH.Position = UDim2.new(0.5,-10,0.5,-1)
	CrossH.BackgroundColor3 = Color3.fromRGB(255,255,255); CrossH.BorderSizePixel = 0
	CrossH.Parent = ClickerBallTemplate
	local CrossV = Instance.new("Frame")
	CrossV.Size = UDim2.new(0,2,0,20); CrossV.Position = UDim2.new(0.5,-1,0.5,-10)
	CrossV.BackgroundColor3 = Color3.fromRGB(255,255,255); CrossV.BorderSizePixel = 0
	CrossV.Parent = ClickerBallTemplate
	local CenterDot = Instance.new("Frame")
	CenterDot.Size = UDim2.new(0,4,0,4); CenterDot.Position = UDim2.new(0.5,-2,0.5,-2)
	CenterDot.BackgroundColor3 = Color3.fromRGB(255,50,50); CenterDot.BorderSizePixel = 0
	CenterDot.Parent = ClickerBallTemplate
	local cdC = Instance.new("UICorner"); cdC.CornerRadius = UDim.new(1,0); cdC.Parent = CenterDot
	raiseZIndex(ClickerBallTemplate, 9101)

	-- V6.2: 序号标签
	local OrderLabel = Instance.new("TextLabel")
	OrderLabel.Name = "OrderLabel"
	OrderLabel.Size = UDim2.new(1, 0, 0, 14)
	OrderLabel.Position = UDim2.new(0, 0, -1, -14)
	OrderLabel.BackgroundTransparency = 1
	OrderLabel.Text = ""
	OrderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	OrderLabel.TextSize = 9
	OrderLabel.Font = Enum.Font.GothamBold
	OrderLabel.TextXAlignment = Enum.TextXAlignment.Center
	OrderLabel.Parent = ClickerBallTemplate

	local function createClickerBall()
		local ball = ClickerBallTemplate:Clone()
		ball.Position = UDim2.new(0.5,-17,0.5,-17)
		ball.Parent = ScreenGui
		ball.Visible = false

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
		return ball
	end

	-- V6.2: 初始创建 BallCount 个球
	for i = 1, (States.ClickerMulti.BallCount or 4) do
		table.insert(ClickerBalls, createClickerBall())
	end
	Gui.ClickerBalls = ClickerBalls
	Gui.createClickerBall = createClickerBall
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
	AimCircleStroke.Thickness = 1; AimCircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
		States.AimbotV2.SelectedCustom = {}
		CustomAimFrame.Visible = false
	end)

	makeDraggable(CustomAimFrame)
	raiseZIndex(CustomAimFrame, 9401)
end

local function refreshCustomAimList()
	for _, child in pairs(CustomAimList:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	updateTargetCache()
	local seen = {}
	local function isSelected(char)
		for _, c in ipairs(States.AimbotV2.SelectedCustom) do
			if c == char then return true end
		end
		return false
	end
	local function addRow(char, name)
		if not char or seen[char] then return end
		seen[char] = true
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1,0,0,26)
		row.BackgroundColor3 = C.BtnDark
		row.BackgroundTransparency = 0.3
		row.Text = name
		row.TextColor3 = Color3.fromRGB(255,255,255)
		row.TextSize = 11
		row.Font = Enum.Font.Gotham
		row.Parent = CustomAimList
		local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0,8); rc.Parent = row
		row.ZIndex = 9402
		local function updateSel()
			row.BackgroundColor3 = isSelected(char) and Color3.fromRGB(0,150,80) or C.BtnDark
		end
		updateSel()
		row.MouseButton1Click:Connect(function()
			-- 多选: 点击切换选中状态, 不去关闭面板
			local sel = States.AimbotV2.SelectedCustom
			local idx = nil
			for i, c in ipairs(sel) do
				if c == char then idx = i; break end
			end
			if idx then
				table.remove(sel, idx)
			else
				table.insert(sel, char)
			end
			updateSel()
		end)
	end
	for _, e in ipairs(TargetCache.Players) do
		addRow(e.Obj, "👤 " .. e.Plr.Name)
	end
	for _, e in ipairs(TargetCache.Npcs) do
		addRow(e.Obj, "🧟 " .. e.Obj.Name)
	end
	if #CustomAimList:GetChildren() == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1,0,0,40)
		empty.BackgroundTransparency = 1
		empty.Text = "未检测到目标"
		empty.TextColor3 = Color3.fromRGB(150,150,170)
		empty.TextSize = 12
		empty.Font = Enum.Font.Gotham
		empty.Parent = CustomAimList
		empty.ZIndex = 9402
	end
end

-- ============================================
-- V6.3: 自定义传送面板
-- ============================================
local TeleportPanel
local function buildTeleportPanel()
	local panel = Instance.new("Frame")
	panel.Name = "TeleportPanel"
	panel.Size = UDim2.new(0, 200, 0, 320)
	panel.Position = UDim2.new(0, 10, 0.5, -160)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9500
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 14); pc.Parent = panel
	createGrayStroke(panel, 2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -10, 0, 24)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "🧭 自定义传送"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -26, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1, 0); cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

	local coordList = Instance.new("ScrollingFrame")
	coordList.Size = UDim2.new(1, -16, 0, 170)
	coordList.Position = UDim2.new(0, 8, 0, 32)
	coordList.BackgroundTransparency = 1
	coordList.ScrollBarThickness = 3
	coordList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	coordList.Parent = panel
	local clLayout = Instance.new("UIListLayout")
	clLayout.Padding = UDim.new(0, 3)
	clLayout.Parent = coordList

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -16, 0, 16)
	infoLabel.Position = UDim2.new(0, 8, 0, 205)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "当前: ---"
	infoLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	infoLabel.TextSize = 9
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = panel

	local recordBtn = createButton(panel, "RecordCoord", UDim2.new(1, -16, 0, 26), UDim2.new(0, 8, 0, 225), Color3.fromRGB(0, 140, 110), "⛳ 记录当前坐标")
	recordBtn.TextSize = 11

	local modeRow = Instance.new("Frame")
	modeRow.Size = UDim2.new(1, 0, 0, 24)
	modeRow.Position = UDim2.new(0, 0, 0, 256)
	modeRow.BackgroundTransparency = 1
	modeRow.Parent = panel

	local modeBtn = createButton(modeRow, "ModeBtn", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), C.Btn, "⚡ 模式: 直接传送")
	modeBtn.TextSize = 10

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -16, 0, 20)
	statusLabel.Position = UDim2.new(0, 8, 0, 284)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "点击保存的坐标可传送"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 190)
	statusLabel.TextSize = 9
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = panel

	local function syncModeBtn()
		modeBtn.Text = States.CustomTeleport.Mode == 1 and "⚡ 模式: 直接传送" or "🦘 模式: 穿墙瞬移"
	end
	modeBtn.MouseButton1Click:Connect(function()
		States.CustomTeleport.Mode = States.CustomTeleport.Mode == 1 and 2 or 1
		syncModeBtn()
	end)
	syncModeBtn()

	local function renderCoordList()
		for _, c in ipairs(coordList:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
		end
		local coords = States.CustomTeleport.Coords
		if #coords == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = "暂无坐标"
			empty.TextColor3 = Color3.fromRGB(150, 150, 170)
			empty.TextSize = 10
			empty.Font = Enum.Font.Gotham
			empty.Parent = coordList
			return
		end
		for i, c in ipairs(coords) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 26)
			row.BackgroundColor3 = C.RowBg
			row.BackgroundTransparency = 0.2
			row.BorderSizePixel = 0
			row.Parent = coordList
			local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row

			local nameLabel = Instance.new("TextButton")
			nameLabel.Size = UDim2.new(1, -24, 1, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = c.Name
			nameLabel.TextColor3 = Color3.fromRGB(230, 230, 255)
			nameLabel.TextSize = 9
			nameLabel.Font = Enum.Font.Gotham
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
			nameLabel.Parent = row
			nameLabel.MouseButton1Click:Connect(function()
				if not hrp then return end
				statusLabel.Text = "🚀 传送中: " .. c.Name
				local target = c.Pos
				if States.CustomTeleport.Mode == 2 then
					teleportThrough(target)
				else
					teleportDirect(target)
				end
				statusLabel.Text = "✅ 已传送: " .. c.Name
			end)

			local delBtn = createButton(row, "DelC"..i, UDim2.new(0, 20, 0, 20), UDim2.new(1, -22, 0.5, -10), Color3.fromRGB(200, 60, 60), "×")
			delBtn.TextSize = 9
			delBtn.MouseButton1Click:Connect(function()
				table.remove(States.CustomTeleport.Coords, i)
				renderCoordList()
			end)
		end
	end

	recordBtn.MouseButton1Click:Connect(function()
		if not hrp then return end
		local p = hrp.Position
		table.insert(States.CustomTeleport.Coords, {
			Name = string.format("P%d (%.0f, %.0f, %.0f)", #States.CustomTeleport.Coords + 1, p.X, p.Y, p.Z),
			Pos = p,
		})
		renderCoordList()
		statusLabel.Text = "💾 已记录坐标"
	end)

	local updConn = RunService.Heartbeat:Connect(function()
		if not panel.Visible then return end
		if hrp then
			local p = hrp.Position
			infoLabel.Text = string.format("当前: %.0f, %.0f, %.0f", p.X, p.Y, p.Z)
		end
	end)

	renderCoordList()
	makeDraggable(panel, nil, nil, 0)
	makeResizable(panel, Vector2.new(180, 260), Vector2.new(420, 500))
	raiseZIndex(panel, 9501)
	TeleportPanel = panel
	Gui.TeleportPanel = panel
end

-- 两个传送逻辑: 直接传送 / 穿墙自由移动瞬移
-- 直接传送: 短暂锚定根节点并同步到目标点(清速度防物理回弹)
local function teleportDirect(target)
	if not hrp then return end
	if humanoid then
		pcall(function() humanoid.PlatformStand = true end)
		pcall(function() humanoid.Sit = false end)
	end
	local wasAnchored = false
	pcall(function()
		wasAnchored = hrp.Anchored
		hrp.Anchored = true
	end)
	for i = 1, 5 do
		pcall(function() hrp.CFrame = CFrame.new(target) end)
		pcall(function()
			hrp.Velocity = Vector3.zero
			if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
		end)
		task.wait()
	end
	if not wasAnchored then
		pcall(function() hrp.Anchored = false end)
	end
	if humanoid then
		pcall(function() humanoid.PlatformStand = false end)
		pcall(function() humanoid:MoveTo(target) end)
	end
	pcall(function()
		hrp.Velocity = Vector3.zero
		if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
	end)
end

-- 穿墙瞬移: 复用穿墙+自由移动(悬浮)的物理逻辑, 驱动速度快速飞到目标点, 上下皆可
local function teleportThrough(target)
	if not hrp then return end
	if humanoid then humanoid.PlatformStand = true end
	local needNoclip = not States.Noclip.Enabled
	if needNoclip then
		States.Noclip.Enabled = true
		pcall(Updaters.Noclip)
	end
	local bg = Instance.new("BodyGyro")
	bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
	bg.P = 9e4
	bg.D = 100
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp
	local bv = Instance.new("BodyVelocity")
	bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
	bv.P = 1e5
	bv.Velocity = Vector3.zero
	bv.Parent = hrp
	-- 传送速度: 按距离自适应, 距离远则更快, 上限 600
	local dist = (target - hrp.Position).Magnitude
	local speed = math.clamp(dist * 3, 80, 600)
	local frames = 0
	while frames < 900 do
		frames = frames + 1
		if not hrp or not hrp.Parent then break end
		local current = hrp.Position
		local dir = target - current
		local mag = dir.Magnitude
		if mag < 2 then break end
		bg.CFrame = CFrame.new(current, current + dir.Unit)
		bv.Velocity = dir.Unit * speed
		task.wait()
	end
	pcall(function() bv.Velocity = Vector3.zero end)
	task.wait()
	pcall(function() bv:Destroy() end)
	pcall(function() bg:Destroy() end)
	-- 精确落点并对齐水平朝向
	pcall(function() hrp.CFrame = CFrame.new(target) end)
	pcall(function()
		hrp.Velocity = Vector3.zero
		if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
	end)
	if humanoid then
		pcall(function() humanoid:MoveTo(target) end)
		pcall(function() humanoid.PlatformStand = false end)
	end
	if needNoclip then
		States.Noclip.Enabled = false
		pcall(Updaters.Noclip)
	end
end

-- ============================================
-- V6.2: 点击脚本面板
-- ============================================
local ClickScriptPanel
local function buildClickScriptPanel()
	local panel = Instance.new("Frame")
	panel.Name = "ClickScriptPanel"
	panel.Size = UDim2.new(0, 280, 0, 320)
	panel.Position = UDim2.new(0.5, -140, 0.5, -160)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.5
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9500
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 16); pc.Parent = panel
	createGrayStroke(panel, 2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -60, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "🖱 点击脚本"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 13
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 22, 0, 22)
	closeBtn.Position = UDim2.new(1, -28, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 13
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1, 0); cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

	local saveListFrame = Instance.new("ScrollingFrame")
	saveListFrame.Size = UDim2.new(0, 90, 0, 220)
	saveListFrame.Position = UDim2.new(0, 8, 0, 36)
	saveListFrame.BackgroundTransparency = 1
	saveListFrame.ScrollBarThickness = 2
	saveListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	saveListFrame.Parent = panel
	local slLayout = Instance.new("UIListLayout")
	slLayout.Padding = UDim.new(0, 3)
	slLayout.Parent = saveListFrame

	local saveTitle = Instance.new("TextLabel")
	saveTitle.Size = UDim2.new(1, 0, 0, 18)
	saveTitle.BackgroundTransparency = 1
	saveTitle.Text = "📁 已保存"
	saveTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
	saveTitle.TextSize = 10
	saveTitle.Font = Enum.Font.GothamBold
	saveTitle.Parent = panel

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Size = UDim2.new(0, 160, 0, 220)
	listFrame.Position = UDim2.new(0, 104, 0, 36)
	listFrame.BackgroundTransparency = 1
	listFrame.ScrollBarThickness = 2
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.Parent = panel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 3)
	listLayout.Parent = listFrame

	local stepsTitle = Instance.new("TextLabel")
	stepsTitle.Size = UDim2.new(1, 0, 0, 18)
	stepsTitle.Position = UDim2.new(0, 104, 0, 36)
	stepsTitle.BackgroundTransparency = 1
	stepsTitle.Text = "📝 当前步骤"
	stepsTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
	stepsTitle.TextSize = 10
	stepsTitle.Font = Enum.Font.GothamBold
	stepsTitle.Parent = panel

	local ctrlRow = Instance.new("Frame")
	ctrlRow.Size = UDim2.new(1, 0, 0, 26)
	ctrlRow.Position = UDim2.new(0, 0, 0, 260)
	ctrlRow.BackgroundTransparency = 1
	ctrlRow.Parent = panel

	local addStepBtn = createButton(ctrlRow, "AddStep", UDim2.new(0, 48, 0, 24), UDim2.new(0, 0, 0, 0), Color3.fromRGB(0, 140, 110), "➕")
	addStepBtn.TextSize = 10
	local saveBtn = createButton(ctrlRow, "SaveScript", UDim2.new(0, 48, 0, 24), UDim2.new(0, 58, 0, 0), Color3.fromRGB(0, 100, 180), "💾")
	saveBtn.TextSize = 10
	local runBtn = createButton(ctrlRow, "RunScript", UDim2.new(0, 48, 0, 24), UDim2.new(0, 116, 0, 0), Color3.fromRGB(0, 150, 80), "▶")
	runBtn.TextSize = 10
	local stopBtn = createButton(ctrlRow, "StopScript", UDim2.new(0, 48, 0, 24), UDim2.new(0, 174, 0, 0), Color3.fromRGB(200, 60, 60), "⏹")
	stopBtn.TextSize = 10
	local clearBtn = createButton(ctrlRow, "ClearScript", UDim2.new(0, 48, 0, 24), UDim2.new(0, 232, 0, 0), Color3.fromRGB(200, 100, 50), "🗑")
	clearBtn.TextSize = 10

	local repeatRow = Instance.new("Frame")
	repeatRow.Size = UDim2.new(1, 0, 0, 24)
	repeatRow.Position = UDim2.new(0, 0, 0, 290)
	repeatRow.BackgroundTransparency = 1
	repeatRow.Parent = panel

	local repeatLabel = Instance.new("TextLabel")
	repeatLabel.Size = UDim2.new(0, 60, 0, 24)
	repeatLabel.Position = UDim2.new(0, 8, 0, 0)
	repeatLabel.BackgroundTransparency = 1
	repeatLabel.Text = "循环:"
	repeatLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
	repeatLabel.TextSize = 10
	repeatLabel.Font = Enum.Font.Gotham
	repeatLabel.TextXAlignment = Enum.TextXAlignment.Left
	repeatLabel.Parent = repeatRow

	local repeatBox = Instance.new("TextBox")
	repeatBox.Size = UDim2.new(0, 44, 0, 22)
	repeatBox.Position = UDim2.new(0, 60, 0, 1)
	repeatBox.BackgroundColor3 = C.BtnDark
	repeatBox.Text = tostring(States.ClickScript.RepeatCount)
	repeatBox.TextColor3 = Color3.fromRGB(255, 255, 255)
	repeatBox.TextSize = 10
	repeatBox.Font = Enum.Font.Gotham
	repeatBox.Parent = repeatRow
	local rbc = Instance.new("UICorner"); rbc.CornerRadius = UDim.new(0, 6); rbc.Parent = repeatBox

	local repeatMinus = createButton(repeatRow, "RepMinus", UDim2.new(0, 20, 0, 22), UDim2.new(0, 106, 0, 1), C.Btn, "-")
	local repeatPlus = createButton(repeatRow, "RepPlus", UDim2.new(0, 20, 0, 22), UDim2.new(0, 128, 0, 1), C.Btn, "+")

	repeatMinus.MouseButton1Click:Connect(function()
		States.ClickScript.RepeatCount = math.max(1, States.ClickScript.RepeatCount - 1)
		repeatBox.Text = tostring(States.ClickScript.RepeatCount)
	end)
	repeatPlus.MouseButton1Click:Connect(function()
		States.ClickScript.RepeatCount = math.min(999, States.ClickScript.RepeatCount + 1)
		repeatBox.Text = tostring(States.ClickScript.RepeatCount)
	end)
	repeatBox.FocusLost:Connect(function()
		local n = tonumber(repeatBox.Text)
		if n and n >= 1 then
			States.ClickScript.RepeatCount = math.floor(n)
			repeatBox.Text = tostring(States.ClickScript.RepeatCount)
		end
	end)

	-- V6.4: 添加小球按钮(修复点击脚本无法添加小球的问题)
	local addBallBtn = createButton(repeatRow, "AddBall", UDim2.new(0, 44, 0, 22), UDim2.new(0, 152, 0, 1), Color3.fromRGB(0, 140, 190), "⚪ +球")
	addBallBtn.TextSize = 9
	addBallBtn.MouseButton1Click:Connect(function()
		pcall(function()
			Gui.createClickerBall()
		end)
		local n = #Gui.ClickerBalls
		statusLabel.Text = "✅ 已添加小球, 共 " .. n .. " 个 (点步骤的球号切换)"
		syncClickerBallVisibility()
		renderClickScriptSteps()
	end)
	-- 建议: 首次给默认值, 防止无球时切换越界
	local minBallBtn = createButton(repeatRow, "MinBall", UDim2.new(0, 20, 0, 22), UDim2.new(0, 198, 0, 1), Color3.fromRGB(200, 90, 60), "-球")
	minBallBtn.TextSize = 8
	minBallBtn.MouseButton1Click:Connect(function()
		if #Gui.ClickerBalls <= 1 then
			statusLabel.Text = "⚠ 至少保留 1 个球"
			return
		end
		local b = table.remove(Gui.ClickerBalls)
		if b then pcall(function() b:Destroy() end) end
		statusLabel.Text = "✅ 已移除小球, 剩余 " .. #Gui.ClickerBalls .. " 个"
		renderClickScriptSteps()
	end)

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -16, 0, 18)
	statusLabel.Position = UDim2.new(0, 8, 0, 318)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "就绪"
	statusLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	statusLabel.TextSize = 9
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = panel
	Gui.ClickScriptStatus = statusLabel

	function renderSaveList()
		for _, c in ipairs(saveListFrame:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
		end
		local saves = States.ClickScript.SavedScripts
		if #saves == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = "无保存"
			empty.TextColor3 = Color3.fromRGB(150, 150, 170)
			empty.TextSize = 9
			empty.Font = Enum.Font.Gotham
			empty.Parent = saveListFrame
			return
		end
		for i, save in ipairs(saves) do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundColor3 = C.BtnDark
			row.BackgroundTransparency = 0.3
			row.Text = save.Name or "脚本" .. i
			row.TextColor3 = Color3.fromRGB(255, 255, 255)
			row.TextSize = 9
			row.Font = Enum.Font.Gotham
			row.Parent = saveListFrame
			local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
			row.MouseButton1Click:Connect(function()
				States.ClickScript.Steps = table.clone(save.Steps)
				renderClickScriptSteps()
				statusLabel.Text = "📂 已加载: " .. (save.Name or "脚本" .. i)
			end)
			local delBtn = createButton(row, "DelSave"..i, UDim2.new(0, 18, 0, 18), UDim2.new(1, -20, 0.5, -9), Color3.fromRGB(200, 60, 60), "×")
			delBtn.TextSize = 8
			delBtn.MouseButton1Click:Connect(function()
				table.remove(saves, i)
				renderSaveList()
			end)
		end
	end

	function renderClickScriptSteps()
		for _, c in ipairs(listFrame:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
		end
		local steps = States.ClickScript.Steps
		if #steps == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 24)
			empty.BackgroundTransparency = 1
			empty.Text = "暂无步骤"
			empty.TextColor3 = Color3.fromRGB(150, 150, 170)
			empty.TextSize = 9
			empty.Font = Enum.Font.Gotham
			empty.Parent = listFrame
			return
		end
		for i, step in ipairs(steps) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 28)
			row.BackgroundColor3 = C.RowBg
			row.BackgroundTransparency = 0.3
			row.BorderSizePixel = 0
			row.Parent = listFrame
			local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row

			local idxLabel = Instance.new("TextLabel")
			idxLabel.Size = UDim2.new(0, 20, 0, 20)
			idxLabel.Position = UDim2.new(0, 3, 0.5, -10)
			idxLabel.BackgroundTransparency = 1
			idxLabel.Text = tostring(i)
			idxLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			idxLabel.TextSize = 10
			idxLabel.Font = Enum.Font.GothamBold
			idxLabel.Parent = row

			local ballLabel = Instance.new("TextLabel")
			ballLabel.Size = UDim2.new(0, 40, 0, 20)
			ballLabel.Position = UDim2.new(0, 24, 0.5, -10)
			ballLabel.BackgroundColor3 = C.BtnDark
			ballLabel.BackgroundTransparency = 0.2
			ballLabel.Text = "球" .. tostring(step.BallIndex)
			ballLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			ballLabel.TextSize = 9
			ballLabel.Font = Enum.Font.Gotham
			ballLabel.Parent = row
			local blc = Instance.new("UICorner"); blc.CornerRadius = UDim.new(0, 5); blc.Parent = ballLabel

			local delayLabel = Instance.new("TextLabel")
			delayLabel.Size = UDim2.new(0, 50, 0, 20)
			delayLabel.Position = UDim2.new(0, 68, 0.5, -10)
			delayLabel.BackgroundColor3 = C.BtnDark
			delayLabel.BackgroundTransparency = 0.2
			delayLabel.Text = tostring(step.Delay) .. "ms"
			delayLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			delayLabel.TextSize = 9
			delayLabel.Font = Enum.Font.Gotham
			delayLabel.Parent = row
			local dlc = Instance.new("UICorner"); dlc.CornerRadius = UDim.new(0, 5); dlc.Parent = delayLabel

			local delBtn = createButton(row, "DelStep"..i, UDim2.new(0, 20, 0, 20), UDim2.new(1, -22, 0.5, -10), Color3.fromRGB(200, 60, 60), "×")
			delBtn.TextSize = 9
			delBtn.MouseButton1Click:Connect(function()
				table.remove(States.ClickScript.Steps, i)
				renderClickScriptSteps()
			end)

			ballLabel.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					step.BallIndex = (step.BallIndex % #Gui.ClickerBalls) + 1
					ballLabel.Text = "球" .. tostring(step.BallIndex)
				end
			end)

			delayLabel.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					local newDelay = tonumber(game:GetService("GuiService"):PromptForInputAsync("延迟(ms):", player))
					if newDelay and newDelay >= 0 then
						step.Delay = math.floor(newDelay)
						delayLabel.Text = tostring(step.Delay) .. "ms"
					end
				end
			end)
		end
	end

	local function addStep()
		local step = {
			BallIndex = 1,
			Delay = 100,
			X = 0,
			Y = 0,
		}
		table.insert(States.ClickScript.Steps, step)
		renderClickScriptSteps()
	end

	addStepBtn.MouseButton1Click:Connect(addStep)
	clearBtn.MouseButton1Click:Connect(function()
		States.ClickScript.Steps = {}
		renderClickScriptSteps()
	end)

	saveBtn.MouseButton1Click:Connect(function()
		if #States.ClickScript.Steps == 0 then
			statusLabel.Text = "⚠ 没有步骤可保存"
			return
		end
		local name = "脚本" .. (#States.ClickScript.SavedScripts + 1)
		table.insert(States.ClickScript.SavedScripts, {
			Name = name,
			Steps = table.clone(States.ClickScript.Steps),
			Time = os.time()
		})
		renderSaveList()
		statusLabel.Text = "💾 已保存: " .. name
	end)

	local function runClickScript()
		if States.ClickScript.Running then return end
		if #States.ClickScript.Steps == 0 then
			statusLabel.Text = "⚠ 请先添加步骤"
			return
		end
		States.ClickScript.Running = true
		statusLabel.Text = "▶ 执行中..."
		local repeatCount = States.ClickScript.RepeatCount or 1
		local rep = 0
		while rep < repeatCount or repeatCount == 0 do
			if not States.ClickScript.Running then break end
			for i, step in ipairs(States.ClickScript.Steps) do
				if not States.ClickScript.Running then break end
				local ball = Gui.ClickerBalls[step.BallIndex]
				if ball and ball.Visible and ball.Parent then
					local pos = ball.AbsolutePosition + ball.AbsoluteSize / 2 + Vector2.new(3, -3)
					pcall(function()
						VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
						task.wait(0.01)
						VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
					end)
				end
				statusLabel.Text = string.format("▶ %d/%d (循环%d)", i, #States.ClickScript.Steps, rep + 1)
				task.wait(math.max(step.Delay or 0, 10) / 1000)
			end
			rep = rep + 1
			if repeatCount > 0 then
				statusLabel.Text = string.format("▶ 循环 %d/%d", rep, repeatCount)
			else
				statusLabel.Text = string.format("▶ 无限循环 %d", rep)
			end
		end
		States.ClickScript.Running = false
		statusLabel.Text = "✅ 执行完成"
	end

	runBtn.MouseButton1Click:Connect(runClickScript)
	stopBtn.MouseButton1Click:Connect(function()
		States.ClickScript.Running = false
		statusLabel.Text = "⏹ 已停止"
	end)

	makeDraggable(panel, nil, nil, 0)
	makeResizable(panel, Vector2.new(240, 260), Vector2.new(500, 500))
	raiseZIndex(panel, 9501)
	ClickScriptPanel = panel
	return panel
end

-- ============================================
-- V6.4: 按键映射面板
-- ============================================
local KeyMapPanel
local KeyMapBalls = {} -- 独立悬浮按钮
local function keyInputName(input)
	-- 键盘按键 / 鼠标按键 -> 名称与可发送对象
	if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
		return tostring(input.KeyCode.Name), Enum.UserInputType.Keyboard
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "Mouse1", Enum.UserInputType.MouseButton1
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		return "Mouse2", Enum.UserInputType.MouseButton2
	elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
		return "Mouse3", Enum.UserInputType.MouseButton3
	end
	return nil
end

local function pressKey(name, isDown)
	pcall(function()
		if name == "Mouse1" then
			VirtualInputManager:SendMouseButtonEvent(0, 0, 0, isDown, game, 0)
		elseif name == "Mouse2" then
			VirtualInputManager:SendMouseButtonEvent(0, 0, 1, isDown, game, 0)
		elseif name == "Mouse3" then
			VirtualInputManager:SendMouseButtonEvent(0, 0, 2, isDown, game, 0)
		else
			local code = Enum.KeyCode[name]
			if code then
				VirtualInputManager:SendKeyEvent(isDown, code, false, game)
			end
		end
	end)
end

local function buildKeyMapBall(key)
	-- 独立悬浮按钮
	local button = Instance.new("TextButton")
	button.Name = "KeyMapBall_" .. key.Name
	button.Size = UDim2.new(0, 70, 0, 32)
	button.Position = UDim2.new(0.5, -35 + #KeyMapBalls * 24, 0.3, 60 + #KeyMapBalls * 26)
	button.BackgroundColor3 = Color3.fromRGB(120, 70, 190)
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.Text = key.Name
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 12
	button.Font = Enum.Font.GothamBold
	button.ZIndex = 9600
	button.AutoButtonColor = false
	button.Parent = ScreenGui
	local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 10); bc.Parent = button
	createGrayStroke(button, 2)

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Size = UDim2.new(1, 0, 0, 14)
	modeLabel.BackgroundTransparency = 1
	modeLabel.Text = "点按" -- 点按/开关
	modeLabel.TextColor3 = Color3.fromRGB(220, 220, 255)
	modeLabel.TextSize = 9
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.Parent = button

	local closeX = Instance.new("TextButton")
	closeX.Size = UDim2.new(0, 16, 0, 16)
	closeX.Position = UDim2.new(1, -16, 0, 0)
	closeX.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeX.Text = "×"
	closeX.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeX.TextSize = 11
	closeX.Font = Enum.Font.GothamBold
	closeX.Parent = button
	closeX.MouseButton1Click:Connect(function()
		pcall(function() button:Destroy() end)
		for i, b in ipairs(KeyMapBalls) do
			if b == button then table.remove(KeyMapBalls, i) end
		end
	end)

	local isToggle = false
	local active = false
	local holdThread = nil
	modeLabel.MouseButton1Click:Connect(function()
		isToggle = not isToggle
		modeLabel.Text = isToggle and "开关" or "点按"
	end)
	button.MouseButton1Click:Connect(function()
		if isToggle then
			-- 开关模式: 常开反色, 再次点击关闭
			active = not active
			if active then
				tween(button, {BackgroundColor3 = Color3.fromRGB(0, 200, 90)}, TweenFast)
				-- 疯狂模拟多次点击
				if holdThread then task.cancel(holdThread) end
				holdThread = task.spawn(function()
					while active and button.Parent do
						pressKey(key.Name, true)
						task.wait(0.02)
						pressKey(key.Name, false)
						task.wait(0.01)
					end
				end)
			else
				tween(button, {BackgroundColor3 = Color3.fromRGB(120, 70, 190)}, TweenFast)
				if holdThread then task.cancel(holdThread); holdThread = nil end
			end
		else
			-- 点按模式: 颜色快速反转一次并发送一次按键
			tween(button, {BackgroundColor3 = Color3.fromRGB(255, 220, 80)}, TweenFast)
			pressKey(key.Name, true)
			task.delay(0.05, function()
				pressKey(key.Name, false)
				if button and button.Parent then
					tween(button, {BackgroundColor3 = Color3.fromRGB(120, 70, 190)}, TweenFast)
				end
			end)
		end
	end)

	makeDraggable(button, nil, nil, 0)
	table.insert(KeyMapBalls, button)
	return button
end

local function buildKeyMapPanel()
	local panel = Instance.new("Frame")
	panel.Name = "KeyMapPanel"
	panel.Size = UDim2.new(0, 220, 0, 300)
	panel.Position = UDim2.new(0, 10, 0.7, -150)
	panel.BackgroundColor3 = Color3.fromRGB(14, 10, 38)
	panel.BackgroundTransparency = 0.35
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 9500
	panel.Parent = ScreenGui
	local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(0, 14); pc.Parent = panel
	createGrayStroke(panel, 2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -10, 0, 24)
	title.Position = UDim2.new(0, 8, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "⌨ 按键映射"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 12
	title.Font = Enum.Font.GothamBold
	title.Parent = panel

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 20, 0, 20)
	closeBtn.Position = UDim2.new(1, -26, 0, 5)
	closeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	closeBtn.Text = "×"
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.TextSize = 12
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.Parent = panel
	local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(1, 0); cbc.Parent = closeBtn
	closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

	local recRow = Instance.new("Frame")
	recRow.Size = UDim2.new(1, 0, 0, 30)
	recRow.Position = UDim2.new(0, 8, 0, 30)
	recRow.BackgroundTransparency = 1
	recRow.Parent = panel

	local recBtn = createButton(recRow, "KeyRec", UDim2.new(0, 96, 0, 26), UDim2.new(0, 0, 0, 2), Color3.fromRGB(200, 70, 60), "⏺ 记录按键")
	recBtn.TextSize = 11

	local addFloatBtn = createButton(recRow, "KeyAddBall", UDim2.new(0, 96, 0, 26), UDim2.new(0, 100, 0, 2), Color3.fromRGB(0, 130, 180), "➕ 建悬浮钮")
	addFloatBtn.TextSize = 11

	local logLabel = Instance.new("TextLabel")
	logLabel.Size = UDim2.new(1, -16, 0, 16)
	logLabel.Position = UDim2.new(0, 8, 0, 62)
	logLabel.BackgroundTransparency = 1
	logLabel.Text = "⌨ 点“记录按键”后按任意键"
	logLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
	logLabel.TextSize = 9
	logLabel.Font = Enum.Font.Gotham
	logLabel.TextXAlignment = Enum.TextXAlignment.Left
	logLabel.Parent = panel

	local keyList = Instance.new("ScrollingFrame")
	keyList.Size = UDim2.new(1, -16, 0, 150)
	keyList.Position = UDim2.new(0, 8, 0, 82)
	keyList.BackgroundTransparency = 1
	keyList.ScrollBarThickness = 3
	keyList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	keyList.Parent = panel
	local klLayout = Instance.new("UIListLayout")
	klLayout.Padding = UDim.new(0, 3)
	klLayout.Parent = keyList

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.new(1, -16, 0, 18)
	statusLabel.Position = UDim2.new(0, 8, 0, 236)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "未开启"
	statusLabel.TextColor3 = Color3.fromRGB(150, 150, 190)
	statusLabel.TextSize = 9
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = panel

	local function renderKeyList(selectedName)
		for _, c in ipairs(keyList:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
		end
		local keys = States.KeyMapping.Keys
		if #keys == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 22)
			empty.BackgroundTransparency = 1
			empty.Text = "暂无记录"
			empty.TextColor3 = Color3.fromRGB(150, 150, 170)
			empty.TextSize = 10
			empty.Font = Enum.Font.Gotham
			empty.Parent = keyList
			return
		end
		for i, k in ipairs(keys) do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, 0, 0, 26)
			row.BackgroundColor3 = selectedName == k.Name and Color3.fromRGB(0, 150, 80) or C.BtnDark
			row.BackgroundTransparency = 0.2
			row.Text = "⌨ " .. k.Name .. (k.Count and (" (x" .. k.Count .. ")") or "")
			row.TextColor3 = Color3.fromRGB(255, 255, 255)
			row.TextSize = 10
			row.Font = Enum.Font.Gotham
			row.Parent = keyList
			local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 6); rc.Parent = row
			row.MouseButton1Click:Connect(function()
				States.KeyMapping.SelectedName = k.Name
				statusLabel.Text = "🎯 已选择: " .. k.Name .. " (可点右上角建悬浮钮)"
				renderKeyList(k.Name)
			end)
			local delBtn = createButton(row, "DelK"..i, UDim2.new(0, 18, 0, 18), UDim2.new(1, -20, 0.5, -9), Color3.fromRGB(200, 60, 60), "×")
			delBtn.TextSize = 8
			delBtn.MouseButton1Click:Connect(function()
				table.remove(States.KeyMapping.Keys, i)
				if States.KeyMapping.SelectedName == k.Name then States.KeyMapping.SelectedName = nil end
				renderKeyList()
			end)
		end
	end

	recBtn.MouseButton1Click:Connect(function()
		States.KeyMapping.Recording = not States.KeyMapping.Recording
		if States.KeyMapping.Recording then
			recBtn.Text = "⏺ 停止记录"
			tween(recBtn, {BackgroundColor3 = Color3.fromRGB(0, 150, 90)}, TweenFast)
			logLabel.Text = "🎙 记录中, 请按键..."
			States.KeyMapping.Keys = {}
			renderKeyList()
		else
			recBtn.Text = "⏺ 记录按键"
			tween(recBtn, {BackgroundColor3 = Color3.fromRGB(200, 70, 60)}, TweenFast)
			logLabel.Text = "✅ 已停止, 选择按键后可建悬浮钮"
		end
	end)

	addFloatBtn.MouseButton1Click:Connect(function()
		local name = States.KeyMapping.SelectedName
		if not name then
			statusLabel.Text = "⚠ 请先在列表中选择一个按键"
			return
		end
		local ok, ball = pcall(buildKeyMapBall, {Name = name})
		if ok and ball then
			statusLabel.Text = "⚪ 已创建悬浮钮: " .. name
		else
			statusLabel.Text = "⚠ 创建悬浮钮失败"
		end
	end)

	-- 全局监听录制按键
	local keyRecConn = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if not States.KeyMapping.Recording then return end
		local n, ut = keyInputName(input)
		if not n then return end
		local found = false
		for _, k in ipairs(States.KeyMapping.Keys) do
			if k.Name == n then
				k.Count = (k.Count or 0) + 1
				found = true
			end
		end
		if not found then
			table.insert(States.KeyMapping.Keys, {Name = n, Count = 1})
		end
		logLabel.Text = "🎙 记录: " .. n
		renderKeyList(States.KeyMapping.SelectedName)
	end)

	renderKeyList()
	makeDraggable(panel, nil, nil, 0)
	makeResizable(panel, Vector2.new(200, 260), Vector2.new(460, 520))
	raiseZIndex(panel, 9501)
	KeyMapPanel = panel
	Gui.KeyMapPanel = panel
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
	Box = {Beams = {}},
}

local BEAM_W = 0.025

local function getBeam(pool, color, thickness)
	for _, b in ipairs(pool.Beams) do
		if not b.Enabled then
			b.Color = ColorSequence.new(color)
			b.Width0 = thickness
			b.Width1 = thickness
			b.Enabled = true
			return b
		end
	end
	local a0 = Instance.new("Attachment"); a0.Name = "A0"; a0.Parent = BeamFolder
	local a1 = Instance.new("Attachment"); a1.Name = "A1"; a1.Parent = BeamFolder
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(color)
	beam.Width0 = thickness; beam.Width1 = thickness
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 0
	beam.ZOffset = 0
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
	local sx, sy, sz = size.X, size.Y, size.Z
	if sx < 0.1 or sy < 0.1 or sz < 0.1 then return false end
	-- 仅渲染棱(12条边), 不渲染面; 复用原有3D线(Beam)绘制逻辑, 不改绘制线逻辑
	local p = cf.Position
	local hx, hy, hz = sx / 2, sy / 2, sz / 2
	local pts = {
		Vector3.new(p.X - hx, p.Y - hy, p.Z - hz),
		Vector3.new(p.X + hx, p.Y - hy, p.Z - hz),
		Vector3.new(p.X - hx, p.Y + hy, p.Z - hz),
		Vector3.new(p.X + hx, p.Y + hy, p.Z - hz),
		Vector3.new(p.X - hx, p.Y - hy, p.Z + hz),
		Vector3.new(p.X + hx, p.Y - hy, p.Z + hz),
		Vector3.new(p.X - hx, p.Y + hy, p.Z + hz),
		Vector3.new(p.X + hx, p.Y + hy, p.Z + hz),
	}
	local edges = {
		{1,2},{3,4},{1,3},{2,4},
		{5,6},{7,8},{5,7},{6,8},
		{1,5},{2,6},{3,7},{4,8},
	}
	for _, e in ipairs(edges) do
		draw3DLine(BeamPools.Box, pts[e[1]], pts[e[2]], color, BEAM_W * 0.8)
	end
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
	line.Size = UDim2.new(0, w, 0, t or 0.9)
	line.Position = UDim2.new(0, x, 0, y)
	line.Rotation = 0
	line.BackgroundColor3 = color
	line.Parent = parent
	return line
end

local function drawVLine(pool, parent, x, y, h, color, t)
	local line = getFromPool(pool, parent)
	line.AnchorPoint = Vector2.new(0, 0)
	line.Size = UDim2.new(0, t or 0.9, 0, h)
	line.Position = UDim2.new(0, x, 0, y)
	line.Rotation = 0
	line.BackgroundColor3 = color
	line.Parent = parent
	return line
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
-- V6.2: 刷新动画工具
-- ============================================
local function animateLabelUpdate(label, newText)
	if not label then return end
	local oldText = label.Text
	if oldText == newText then return end
	-- 淡出
	tween(label, {TextTransparency = 1}, TweenFadeOut)
	task.wait(0.15)
	label.Text = newText
	-- 淡入
	tween(label, {TextTransparency = 0}, TweenFadeIn)
end

-- ============================================
-- 执行UI构建
-- ============================================
buildMainPanel()
buildShortcutFrame()
buildFly1Panel()
buildFly2Panel()
buildFreeMoveFrame()
buildClickerSystem()
buildLabels()
buildCustomAimFrame()
buildMusicPanel()
buildClickScriptPanel()
buildTeleportPanel()
buildKeyMapPanel()

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
	{Cat=1, Name="自定义传送", Key="CustomTeleport"},
	{Cat=1, Name="大陀螺", Key="BigSpin", Input=true, Place="速度"},
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
	{Cat=4, Name="多球模式", Key="ClickerMulti", HasDropdown=true},
	{Cat=4, Name="点击脚本", Key="ClickScript"},
	{Cat=4, Name="快速交互", Key="FastInteract"},
	{Cat=4, Name="远程互动", Key="RemoteInteract", HasDropdown=true},
	{Cat=4, Name="按键映射", Key="KeyMapping"},
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
	{Cat=6, Name="上帝模式", Key="GodSoul"},
	{Cat=6, Name="功能列表HUD", Key="FeatureHUD", HasDropdown=true},
	{Cat=6, Name="关闭脚本", Key="CloseScript", IsButton=true},
}

-- ============================================
-- 功能列表 HUD (FeatureHUD) - 完全重写
-- ============================================
do
	--================ 功能列表 HUD (完全重写版) ================
	-- 固定右上角: 右边缘与屏幕严丝合缝, 不可拖动
	-- 背景 25% 不透明度 (透明75%)
	-- 实时列出所有已开启功能(带序号), 连续流动渐变, 丝滑滑入/滑出
	local F = {}
	F.Rows = {}
	F.Order = {}
	F.LastSig = ""
	local ROW_H = 22
	local GAP = 3
	local TEXTSIZE = 14
	local PAD_R = 12
	local PAD_T = 6
	local PAD_B = 6
	local NUM_W = 22
	local CycleDur = 5.0 -- 一个完整渐变循环时长(秒)
	local RowDelay = 0.13 -- 相邻行间的相位延迟(秒), 形成向下流动的水波

	--=== 渐变配色 ===
	local Palettes = {
		rainbow = {Color3.fromRGB(89,183,255), Color3.fromRGB(7,216,239), Color3.fromRGB(110,239,198), Color3.fromRGB(204,252,165), Color3.fromRGB(255,224,130), Color3.fromRGB(255,150,124), Color3.fromRGB(255,78,182), Color3.fromRGB(156,86,255), Color3.fromRGB(89,183,255)},
		redorange = {Color3.fromRGB(255,70,70), Color3.fromRGB(255,150,50), Color3.fromRGB(255,215,60)},
		greenblue = {Color3.fromRGB(0,210,120), Color3.fromRGB(0,205,205), Color3.fromRGB(50,130,255)},
		pinkpurple = {Color3.fromRGB(255,100,190), Color3.fromRGB(225,95,255), Color3.fromRGB(150,95,255)},
		golden = {Color3.fromRGB(255,215,70), Color3.fromRGB(255,165,45), Color3.fromRGB(255,90,60)},
	}
	local function palette()
		local s = States.FeatureHUD
		if s.Colors and #s.Colors > 0 then return s.Colors end
		return Palettes[s.Palette] or Palettes.rainbow
	end
	-- 循环采样渐变色: t 在 [0,1) 沿调色板首尾相接平滑过渡
	local function gradColor(t)
		local cols = palette()
		local N = #cols
		if N == 0 then return Color3.white end
		if N == 1 then return cols[1] end
		t = t - math.floor(t)
		if t < 0 then t = t + 1 end
		local g = t * N
		local i0 = math.floor(g) % N
		local i1 = (i0 + 1) % N
		return cols[i0 + 1]:Lerp(cols[i1 + 1], g - math.floor(g))
	end

	--=== 文字宽度测量(排序与整体宽度用) ===
	local TSvc = game:GetService("TextService")
	local function boldFont()
		return (States.FeatureHUD.Bold == true) and Enum.Font.GothamBold or Enum.Font.Gotham
	end
	local function textW(str)
		local ok, b = pcall(function()
			return TSvc:GetTextBoundsAsync({Text = str, Font = boldFont(), TextSize = TEXTSIZE, Width = 0})
		end)
		if ok and typeof(b) == "Vector2" and b.X and b.X > 0 then return b.X + 6 end
		local n = #str
		pcall(function() n = utf8.len(str, 1, #str) end)
		return n * TEXTSIZE + 6
	end

	--=== 功能名固定序与名称 ===
	local FixedOrder = {}
	local nameOf = {}
	for i, feat in ipairs(Features) do
		FixedOrder[feat.Key] = i
		nameOf[feat.Key] = feat.Name
	end
	local function skip(key)
		if key == "FeatureHUD" or key == "DynamicIsland" or key == "CloseScript" or key == "MusicPlayer" then return true end
		if not FixedOrder[key] then return true end
		return false
	end
	local function enabledKeys()
		local out = {}
		for k, st in pairs(States) do
			if type(st) == "table" and st.Enabled and not skip(k) then out[#out+1] = k end
		end
		return out
	end
	-- 按宽度降序(最长在上), 等宽则按功能表序
	local function orderedKeys()
		local list = enabledKeys()
		local w = {}
		for _, k in ipairs(list) do w[k] = textW(nameOf[k] or k) end
		table.sort(list, function(a, b)
			if math.abs(w[a] - w[b]) > 1 then return w[a] > w[b] end
			return FixedOrder[a] < FixedOrder[b]
		end)
		return list
	end
	local function isIn(list, key)
		for _, k in ipairs(list) do if k == key then return true end end
		return false
	end

	--=== 框架: 固定右上角, 禁止拖动 ===
	local function buildFrame()
		if F.Frame and F.Frame.Parent then return F.Frame end
		local fr = Instance.new("Frame")
		fr.Name = "NH_FeatureHUD"
		fr.AnchorPoint = Vector2.new(1, 0)
		fr.Size = UDim2.new(0, 180, 0, 40)
		-- 背景 25% 不透明度(即透明75%), 严丝合缝贴靠屏幕右缘
		fr.BackgroundColor3 = Color3.fromRGB(12, 10, 26)
		fr.BackgroundTransparency = 0.75
		fr.BorderSizePixel = 0
		fr.Active = false
		fr.Selectable = false
		fr.ZIndex = 9800
		-- 右边缘与屏幕右缘贴合(XOffset=0), 顶部略下移避开系统状态栏
		fr.Position = UDim2.new(1, 0, 0, 16)
		fr.ClipsDescendants = true
		fr.Visible = false
		fr.Parent = ScreenGui
		local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 6); c.Parent = fr
		F.Frame = fr
		return fr
	end

	--=== 单行: 右对齐功能名 + 序号 + 左侧可选线条 ===
	local function makeRow(key, width)
		local s = States.FeatureHUD
		local mode = s.Mode or "line"
		local row = Instance.new("Frame")
		row.Name = "NH_FRow_" .. key
		row.Size = UDim2.new(0, width, 0, ROW_H)
		row.Position = UDim2.new(0, 0, 0, 0)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Active = false
		row.Selectable = false
		row.ZIndex = 9804
		row.Parent = F.Frame
		local res = {}
		-- 左侧线条(双线条模式)
		local lineL = Instance.new("Frame")
		lineL.Size = UDim2.new(0, 2, 0.8, 0)
		lineL.Position = UDim2.new(0, 2, 0.1, 0)
		lineL.BackgroundColor3 = Color3.fromRGB(255,255,255)
		lineL.BorderSizePixel = 0
		lineL.Active = false
		lineL.ZIndex = 9806
		lineL.Visible = mode == "dline"
		lineL.Parent = row
		res.lineL = lineL
		-- 功能名(右对齐)
		local name = Instance.new("TextLabel")
		name.Size = UDim2.new(1, -PAD_R - NUM_W, 1, 0)
		name.Position = UDim2.new(0, 4, 0, 0)
		name.BackgroundTransparency = 1
		name.Active = false
		name.Selectable = false
		name.Text = nameOf[key] or key
		name.TextColor3 = Color3.fromRGB(255,255,255)
		name.TextSize = TEXTSIZE
		name.Font = boldFont()
		name.TextXAlignment = Enum.TextXAlignment.Right
		name.TextYAlignment = Enum.TextYAlignment.Center
		name.ZIndex = 9807
		name.Parent = row
		res.name = name
		-- 序号(最右侧)
		local num = Instance.new("TextLabel")
		num.Size = UDim2.new(0, NUM_W, 1, 0)
		num.Position = UDim2.new(1, -NUM_W, 0, 0)
		num.BackgroundTransparency = 1
		num.Active = false
		num.Selectable = false
		num.Text = "0"
		num.TextColor3 = Color3.fromRGB(255,255,255)
		num.TextSize = 11
		num.Font = Enum.Font.GothamBold
		num.TextXAlignment = Enum.TextXAlignment.Right
		num.TextYAlignment = Enum.TextYAlignment.Center
		num.ZIndex = 9807
		num.Parent = row
		res.num = num
		row.Resources = res
		F.Rows[key] = row
		return row, res
	end

	local function applyStyle(res)
		local s = States.FeatureHUD
		local mode = s.Mode or "line"
		res.name.Font = s.Bold and Enum.Font.GothamBold or Enum.Font.Gotham
		res.lineL.Visible = mode == "dline"
	end

	--=== 布局: 计算顺序/宽度/高度并放置行, 处理增删的丝滑动画 ===
	local function layout()
		local fr = F.Frame
		if not fr or not fr.Parent or not States.FeatureHUD.Enabled then return end
		local list = orderedKeys()
		F.Order = list
		local n = #list
		if n == 0 then
			fr.Visible = false
			return
		end
		fr.Visible = true
		local s = States.FeatureHUD
		fr.BackgroundTransparency = (s.ShowBg ~= false) and 0.75 or 1
		local wid = 20
		for _, k in ipairs(list) do wid = math.max(wid, textW(nameOf[k] or k)) end
		local frameW = wid + PAD_R + NUM_W + 6
		local totalH = PAD_T + PAD_B + n * (ROW_H + GAP)
		tween(fr, {Size = UDim2.new(0, frameW, 0, totalH)}, TweenSmooth)
		for i, k in ipairs(list) do
			local y = PAD_T + (i - 1) * (ROW_H + GAP)
			local row = F.Rows[k]
			if not row then
				local _, res = makeRow(k, frameW)
				row = F.Rows[k]
				row.Position = UDim2.new(0, 40, 0, y)
				res.name.TextTransparency = 1
				res.num.TextTransparency = 1
				res.num.Text = tostring(i)
				tween(row, {Position = UDim2.new(0, 0, 0, y)}, TweenSlide)
				tween(res.name, {TextTransparency = 0}, TweenSmooth)
				tween(res.num, {TextTransparency = 0}, TweenSmooth)
			else
				local res = row.Resources
				res.num.Text = tostring(i)
				if math.abs(row.Position.X.Offset) > 1 or math.abs(row.Position.Y.Offset - y) > 1 then
					tween(row, {Position = UDim2.new(0, 0, 0, y)}, TweenSlide)
				else
					row.Position = UDim2.new(0, 0, 0, y)
				end
				if math.abs(row.Size.X.Offset - frameW) > 1 then
					tween(row, {Size = UDim2.new(0, frameW, 0, ROW_H)}, TweenSmooth)
				else
					row.Size = UDim2.new(0, frameW, 0, ROW_H)
				end
				applyStyle(res)
			end
		end
	end

	local function removeRow(key)
		local row = F.Rows[key]
		if not row then return end
		F.Rows[key] = nil
		local res = row.Resources
		pcall(function()
			local y = row.Position.Y.Offset
			tween(row, {Position = UDim2.new(0, 60, 0, y)}, TweenSlide)
			if res and res.name then tween(res.name, {TextTransparency = 1}, TweenFast) end
			if res and res.num then tween(res.num, {TextTransparency = 1}, TweenFast) end
			task.delay(0.3, function()
				if row.Parent then row:Destroy() end
			end)
		end)
	end

	local function sync()
		if not States.FeatureHUD.Enabled then return end
		if not F.Frame or not F.Frame.Parent then buildFrame() end
		local list = orderedKeys()
		for key in pairs(F.Rows) do
			if not isIn(list, key) then removeRow(key) end
		end
		layout()
	end

	--=== 连续渐变水波: 每帧刷新颜色 ===
	local function applyColors(now)
		local fr = F.Frame
		if not fr or not fr.Parent then return end
		local s = States.FeatureHUD
		local list = F.Order or {}
		local ph = now / CycleDur
		local dir = s.Direction or "forward"
		for i, k in ipairs(list) do
			local row = F.Rows[k]
			if not row then continue end
			local t
			if dir == "both" then
				t = math.abs(2 * (ph % 1) - 1) - (i - 1) * (RowDelay / CycleDur)
			elseif dir == "reverse" then
				t = ph + (i - 1) * (RowDelay / CycleDur)
			else
				t = ph - (i - 1) * (RowDelay / CycleDur)
			end
			local col = gradColor(t)
			local res = row.Resources
			res.name.TextColor3 = col
			res.num.TextColor3 = col
			if res.lineL then res.lineL.BackgroundColor3 = col end
		end
	end

	F.reapply = function()
		if not States.FeatureHUD.Enabled then
			if F.Frame then F.Frame.Visible = false end
			return
		end
		if not F.Frame or not F.Frame.Parent then buildFrame() end
		sync()
	end
	F.resetPos = function()
		if F.Frame and F.Frame.Parent then
			tween(F.Frame, {Position = UDim2.new(1, 0, 0, 16)}, TweenSmooth)
		end
	end
	Gui.FeatureHUD = F

	Updaters.FeatureHUD = function()
		if States.FeatureHUD.Enabled then
			if Conns.FeatureHUD then return end
			buildFrame()
			sync()
			F.LastSig = table.concat(orderedKeys(), "|")
			local baseT = os.clock()
			Conns.FeatureHUD = RunService.Heartbeat:Connect(function()
				if not States.FeatureHUD.Enabled then return end
				local sig = table.concat(orderedKeys(), "|")
				if sig ~= F.LastSig then
					F.LastSig = sig
					sync()
				end
				applyColors(os.clock() - baseT)
			end)
		else
			unbind("FeatureHUD")
			if F.Frame then
				pcall(function() F.Frame:Destroy() end)
				F.Frame = nil
				F.Rows = {}
				F.Order = {}
			end
		end
	end
end

local CurrentCategory = 1
local FeatureRows = {}
local ROW_W = 368

local function moveCatIndicator(i)
	local ind = Gui.CatIndicator
	if not ind or not ind.Parent then return end
	local y = 9 + (i - 1) * 39
	tween(ind, {Position = UDim2.new(0, 5, 0, y)}, TweenSlide)
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

-- ============================================
-- refreshFeatures - 逐行pcall保护
-- ============================================
local function refreshFeatures()
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
		if feat.Cat == CurrentCategory then
			local row = nil
			local ok = pcall(function()
				local isDrop = feat.HasDropdown
				local isBtn = feat.IsButton
				local rowH = isDrop and 34 or (isBtn and 34 or 42)
				row = Instance.new("Frame")
				row.Size = UDim2.new(0, ROW_W, 0, rowH)
				row.Position = UDim2.new(0, 0, 0, yOffset)
				row.BackgroundColor3 = Color3.fromRGB(30, 20, 66)
				row.BackgroundTransparency = 0.15
				row.BorderSizePixel = 0
				row.Parent = Gui.ScrollInner
				row.ZIndex = 9003
				local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = row
				createGrayStroke(row, 1.5)

				local scBtn = Instance.new("TextButton")
				scBtn.Size = UDim2.new(0,24,0,24); scBtn.Position = UDim2.new(0,2,0.5,-12)
				scBtn.BackgroundColor3 = C.BtnDark
				scBtn.Text = "⚡"; scBtn.TextColor3 = Color3.fromRGB(255,255,255)
				scBtn.TextSize = 11; scBtn.Font = Enum.Font.GothamBold
				scBtn.Parent = row
				local scC = Instance.new("UICorner"); scC.CornerRadius = UDim.new(0,8); scC.Parent = scBtn
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

				if isBtn then
					-- 通用按钮型功能(如关闭脚本)
					local btn = createButton(row, feat.Key, UDim2.new(0, 120, 0, 28), UDim2.new(0, 32, 0.5, -14),
						feat.Key == "CloseScript" and Color3.fromRGB(180, 40, 40) or Color3.fromRGB(90, 65, 160),
						feat.Key == "CloseScript" and "⏻ 关闭脚本" or "执行")
					btn.TextSize = 12
					local grad = Instance.new("UIGradient")
					grad.Color = feat.Key == "CloseScript"
						and ColorSequence.new(Color3.fromRGB(255, 60, 60), Color3.fromRGB(120, 20, 120))
						or ColorSequence.new(Color3.fromRGB(255, 50, 150), Color3.fromRGB(50, 110, 255))
					grad.Rotation = 90
					grad.Parent = btn
					btn.MouseButton1Click:Connect(function()
						if feat.Key == "CloseScript" then
							closeTheScript()
						end
					end)
				elseif isDrop then
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
						modeLabel.Size = UDim2.new(1,0,0,20); modeLabel.BackgroundTransparency = 1
						modeLabel.Text = "框模式: " .. (States.BoxCreature.BoxMode == "3D" and "3D立体框" or "2D平面框")
						modeLabel.TextColor3 = Color3.fromRGB(220,220,255); modeLabel.TextSize = 11
						modeLabel.Font = Enum.Font.Gotham; modeLabel.Parent = dropContent
						local modeRow = createBtnRow(dropContent, 26)
						local btn2D = createButton(modeRow, "Box2D", UDim2.new(0.48,0,0,24), UDim2.new(), C.BtnDark, "2D平面框")
						local btn3D = createButton(modeRow, "Box3D", UDim2.new(0.48,0,0,24), UDim2.new(0.52,0,0,0), C.BtnDark, "3D立体框")
						local function updateModeBtns()
							local is3D = States.BoxCreature.BoxMode == "3D"
							btn2D.BackgroundColor3 = is3D and C.BtnDark or Color3.fromRGB(0,150,80)
							btn3D.BackgroundColor3 = is3D and Color3.fromRGB(0,150,80) or C.BtnDark
							modeLabel.Text = "框模式: " .. (is3D and "3D立体框" or "2D平面框")
						end
						btn2D.MouseButton1Click:Connect(function()
							States.BoxCreature.BoxMode = "2D"
							updateModeBtns()
						end)
						btn3D.MouseButton1Click:Connect(function()
							States.BoxCreature.BoxMode = "3D"
							updateModeBtns()
						end)
						updateModeBtns()
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
						originLabel.Size = UDim2.new(1,0,0,20); originLabel.BackgroundTransparency = 1
						originLabel.Text = "线起点: " .. (States.LineConnect.Origin == "Top" and "上方" or (States.LineConnect.Origin == "Bottom" and "下方" or "准心"))
						originLabel.TextColor3 = Color3.fromRGB(220,220,255); originLabel.TextSize = 11
						originLabel.Font = Enum.Font.Gotham; originLabel.Parent = dropContent
						local originRow = createBtnRow(dropContent, 24)
						local btnTop = createButton(originRow, "LCTop", UDim2.new(0.32,0,0,22), UDim2.new(), C.BtnDark, "上方")
						local btnBot = createButton(originRow, "LCBot", UDim2.new(0.32,0,0,22), UDim2.new(0.34,0,0,0), C.BtnDark, "下方")
						local btnCross = createButton(originRow, "LCCross", UDim2.new(0.32,0,0,22), UDim2.new(0.68,0,0,0), C.BtnDark, "准心")
						local function updateOriginBtns()
							local o = States.LineConnect.Origin or "Top"
							btnTop.BackgroundColor3 = o == "Top" and Color3.fromRGB(0,150,80) or C.BtnDark
							btnBot.BackgroundColor3 = o == "Bottom" and Color3.fromRGB(0,150,80) or C.BtnDark
							btnCross.BackgroundColor3 = o == "Cross" and Color3.fromRGB(0,150,80) or C.BtnDark
							originLabel.Text = "线起点: " .. (o == "Top" and "上方" or (o == "Bottom" and "下方" or "准心"))
						end
						btnTop.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Top"; updateOriginBtns() end)
						btnBot.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Bottom"; updateOriginBtns() end)
						btnCross.MouseButton1Click:Connect(function() States.LineConnect.Origin = "Cross"; updateOriginBtns() end)
						updateOriginBtns()
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
						local customBtn = createButton(dropContent, "CustomAim", UDim2.new(1,0,0,26), UDim2.new(), Color3.fromRGB(90, 65, 160), "🎯 自定义自瞄对象")
						customBtn.TextSize = 12
						customBtn.MouseButton1Click:Connect(function()
							refreshCustomAimList()
							CustomAimFrame.Visible = true
						end)
						local parts = {"Head","HumanoidRootPart","Torso","UpperTorso","LowerTorso"}
						local aimLabel = Instance.new("TextLabel")
						aimLabel.Size = UDim2.new(1,0,0,20); aimLabel.BackgroundTransparency = 1
						aimLabel.Text = "🎯 瞄准部位: " .. States.AimbotV2.AimPart
						aimLabel.TextColor3 = Color3.fromRGB(220,220,255); aimLabel.TextSize = 11
						aimLabel.Font = Enum.Font.Gotham; aimLabel.Parent = dropContent
						local partRow = createBtnRow(dropContent, 26)
						for i, p in ipairs(parts) do
							local pBtn = createButton(partRow, p.."Aim", UDim2.new(0.18,0,0,22), UDim2.new((i-1)*0.205,0,0,0), C.BtnDark, p)
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
					elseif feat.Key == "FeatureHUD" then
						-- 显示模式
						local modeLabel = Instance.new("TextLabel")
						modeLabel.Size = UDim2.new(1,0,0,20); modeLabel.BackgroundTransparency = 1
						modeLabel.Text = "显示样式: 切换查看"
						modeLabel.TextColor3 = Color3.fromRGB(220,220,255); modeLabel.TextSize = 11
						modeLabel.Font = Enum.Font.Gotham; modeLabel.Parent = dropContent
						local modeRow = createBtnRow(dropContent, 26)
						local modes = {{"text","单文本"},{"line","线条"},{"dline","双线条"}}
						local modeBtns = {}
						for i, m in ipairs(modes) do
							local mb = createButton(modeRow, "HUDMode"..m[1], UDim2.new(0.32,0,0,22), UDim2.new((i-1)*0.34,0,0,0), C.BtnDark, m[2])
							mb.TextSize = 10
							mb.MouseButton1Click:Connect(function()
								States.FeatureHUD.Mode = m[1]
								if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
							end)
							modeBtns[m[1]] = mb
						end
						addCheckboxes(dropContent, {
							{"背景颜色", States.FeatureHUD.ShowBg, function(v)
								States.FeatureHUD.ShowBg = v
								if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
							end},
							{"字体加粗", States.FeatureHUD.Bold, function(v)
								States.FeatureHUD.Bold = v
								if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
							end},
						})
						-- 动画方向
						local dirLabel = Instance.new("TextLabel")
						dirLabel.Size = UDim2.new(1,0,0,20); dirLabel.BackgroundTransparency = 1
						dirLabel.Text = "🌐 动画方向: 切换查看"
						dirLabel.TextColor3 = Color3.fromRGB(220,220,255); dirLabel.TextSize = 11
						dirLabel.Font = Enum.Font.Gotham; dirLabel.Parent = dropContent
						local dirRow = createBtnRow(dropContent, 26)
						local dirs = {{"forward","正向"},{"reverse","反向"},{"both","双向"}}
						for i, d in ipairs(dirs) do
							local db = createButton(dirRow, "HUDDir"..d[1], UDim2.new(0.32,0,0,22), UDim2.new((i-1)*0.34,0,0,0), C.BtnDark, d[2])
							db.TextSize = 10
							db.MouseButton1Click:Connect(function()
								States.FeatureHUD.Direction = d[1]
								if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
							end)
						end
						-- 配色预置
						local palLabel = Instance.new("TextLabel")
						palLabel.Size = UDim2.new(1,0,0,20); palLabel.BackgroundTransparency = 1
						palLabel.Text = "🎨 渐变配色: 切换查看"
						palLabel.TextColor3 = Color3.fromRGB(220,220,255); palLabel.TextSize = 11
						palLabel.Font = Enum.Font.Gotham; palLabel.Parent = dropContent
						local palRow = createBtnRow(dropContent, 26)
						local pals = {{"rainbow","彩虹"},{"redorange","红橙"},{"greenblue","青蓝"},{"pinkpurple","粉紫"},{"golden","金红"}}
						for i, p in ipairs(pals) do
							local pb = createButton(palRow, "HUDPal"..p[1], UDim2.new(0.18,0,0,22), UDim2.new((i-1)*0.2,0,0,0), C.BtnDark, p[2])
							pb.TextSize = 9
							pb.MouseButton1Click:Connect(function()
								States.FeatureHUD.Palette = p[1]
								if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
							end)
						end
						-- 自定义多色选择
						local custLabel = Instance.new("TextLabel")
						custLabel.Size = UDim2.new(1,0,0,20); custLabel.BackgroundTransparency = 1
						custLabel.Text = "🖌️ 自选渐变色 (多选):"
						custLabel.TextColor3 = Color3.fromRGB(220,220,255); custLabel.TextSize = 11
						custLabel.Font = Enum.Font.Gotham; custLabel.Parent = dropContent
						local HUDBaseColors = {
							{"红", Color3.fromRGB(255,70,70)},
							{"橙", Color3.fromRGB(255,150,50)},
							{"黄", Color3.fromRGB(255,215,60)},
							{"绿", Color3.fromRGB(0,210,110)},
							{"青", Color3.fromRGB(0,210,210)},
							{"蓝", Color3.fromRGB(70,130,255)},
							{"紫", Color3.fromRGB(190,95,255)},
							{"粉", Color3.fromRGB(255,110,200)},
							{"白", Color3.fromRGB(255,255,255)},
						}
						local custWrap = Instance.new("Frame")
						custWrap.Size = UDim2.new(1,0,0,54)
						custWrap.BackgroundTransparency = 1
						custWrap.Parent = dropContent
						do
							local curCols = States.FeatureHUD.Colors or {}
							local selected = {}
							for _, c in ipairs(curCols) do
								for _, bc in ipairs(HUDBaseColors) do
									if bc[2] == c then selected[bc[1]] = true end
								end
							end
							local chips = {}
							for i, bc in ipairs(HUDBaseColors) do
								local chip = Instance.new("TextButton")
								chip.Size = UDim2.new(0, 38, 0, 24)
								chip.Position = UDim2.new(0, ((i-1)%5)*42, 0, (i<6 and 0 or 30))
								chip.BackgroundColor3 = bc[2]
								chip.BackgroundTransparency = selected[bc[1]] and 0 or 0.55
								chip.Text = bc[1]
								chip.TextColor3 = Color3.fromRGB(10,10,18)
								chip.TextSize = 9
								chip.Font = Enum.Font.GothamBold
								chip.BorderSizePixel = 0
								chip.Parent = custWrap
								local chipC = Instance.new("UICorner"); chipC.CornerRadius = UDim.new(0,7); chipC.Parent = chip
								if selected[bc[1]] then
									local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255,255,255); st.Thickness = 2; st.Parent = chip
								end
								chip.MouseButton1Click:Connect(function()
									local cur = States.FeatureHUD.Colors or {}
									local found = false
									for j = #cur, 1, -1 do
										if cur[j] == bc[2] then
											table.remove(cur, j); found = true
										end
									end
									if not found then table.insert(cur, bc[2]) end
									chip.BackgroundTransparency = (not found) and 0 or 0.55
									if found then
										local st = chip:FindFirstChildOfClass("UIStroke")
										if st then st:Destroy() end
									else
										if not chip:FindFirstChildOfClass("UIStroke") then
											local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255,255,255); st.Thickness = 2; st.Parent = chip
										end
									end
									if Gui.FeatureHUD then Gui.FeatureHUD.reapply() end
								end)
							end
						end
						local resetPos = createButton(dropContent, "HUDResetPos", UDim2.new(1,0,0,26), UDim2.new(), Color3.fromRGB(90,65,160), "📍 重置HUD位置")
						resetPos.TextSize = 11
						resetPos.MouseButton1Click:Connect(function()
							if Gui.FeatureHUD then Gui.FeatureHUD.resetPos() end
						end)
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
						boxStyleLabel.Size = UDim2.new(1,0,0,20); boxStyleLabel.BackgroundTransparency = 1
						boxStyleLabel.Text = "方框样式: " .. (States.AdvancedESP.BoxStyle == "Corner" and "角框" or "全框")
						boxStyleLabel.TextColor3 = Color3.fromRGB(220,220,255); boxStyleLabel.TextSize = 11
						boxStyleLabel.Font = Enum.Font.Gotham; boxStyleLabel.Parent = dropContent
						local bsRow = createBtnRow(dropContent, 24)
						local cornerBtn = createButton(bsRow, "BoxCorner", UDim2.new(0.48,0,0,22), UDim2.new(), C.BtnDark, "角框")
						local fullBtn = createButton(bsRow, "BoxFull", UDim2.new(0.48,0,0,22), UDim2.new(0.52,0,0,0), C.BtnDark, "全框")
						cornerBtn.MouseButton1Click:Connect(function() States.AdvancedESP.BoxStyle = "Corner"; boxStyleLabel.Text = "方框样式: 角框" end)
						fullBtn.MouseButton1Click:Connect(function() States.AdvancedESP.BoxStyle = "Full"; boxStyleLabel.Text = "方框样式: 全框" end)
						local hpStyleLabel = Instance.new("TextLabel")
						hpStyleLabel.Size = UDim2.new(1,0,0,20); hpStyleLabel.BackgroundTransparency = 1
						hpStyleLabel.Text = "血条样式: " .. (States.AdvancedESP.HealthStyle == "Bar" and "条形" or (States.AdvancedESP.HealthStyle == "Text" and "文本" or "两者"))
						hpStyleLabel.TextColor3 = Color3.fromRGB(220,220,255); hpStyleLabel.TextSize = 11
						hpStyleLabel.Font = Enum.Font.Gotham; hpStyleLabel.Parent = dropContent
						local hpRow = createBtnRow(dropContent, 24)
						local barBtn = createButton(hpRow, "HPBar", UDim2.new(0.32,0,0,22), UDim2.new(), C.BtnDark, "条形")
						local textBtn = createButton(hpRow, "HPText", UDim2.new(0.32,0,0,22), UDim2.new(0.34,0,0,0), C.BtnDark, "文本")
						local bothBtn = createButton(hpRow, "HPBoth", UDim2.new(0.32,0,0,22), UDim2.new(0.68,0,0,0), C.BtnDark, "两者")
						barBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Bar"; hpStyleLabel.Text = "血条样式: 条形" end)
						textBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Text"; hpStyleLabel.Text = "血条样式: 文本" end)
						bothBtn.MouseButton1Click:Connect(function() States.AdvancedESP.HealthStyle = "Both"; hpStyleLabel.Text = "血条样式: 两者" end)
						local advOriginLabel = Instance.new("TextLabel")
						advOriginLabel.Size = UDim2.new(1,0,0,20); advOriginLabel.BackgroundTransparency = 1
						advOriginLabel.Text = "线头位置: " .. (States.AdvancedESP.TracerOrigin == "Top" and "顶部" or "底部")
						advOriginLabel.TextColor3 = Color3.fromRGB(220,220,255); advOriginLabel.TextSize = 11
						advOriginLabel.Font = Enum.Font.Gotham; advOriginLabel.Parent = dropContent
						local toRow = createBtnRow(dropContent, 24)
						local advTopBtn = createButton(toRow, "AdvTop", UDim2.new(0.48,0,0,22), UDim2.new(), C.BtnDark, "顶部")
						local advBotBtn = createButton(toRow, "AdvBot", UDim2.new(0.48,0,0,22), UDim2.new(0.52,0,0,0), C.BtnDark, "底部")
						advTopBtn.MouseButton1Click:Connect(function() States.AdvancedESP.TracerOrigin = "Top"; advOriginLabel.Text = "线头位置: 顶部" end)
						advBotBtn.MouseButton1Click:Connect(function() States.AdvancedESP.TracerOrigin = "Bottom"; advOriginLabel.Text = "线头位置: 底部" end)
						createLabeledStep(dropContent, "📏 最大距离 (0=无限)",
							function() return States.AdvancedESP.MaxDistance end,
							function(v) States.AdvancedESP.MaxDistance = v end,
							100, 0, 5000)
					elseif feat.Key == "GameInfo" then
						local function addInfoRow(labelText, copyValue)
							local rowF = Instance.new("Frame")
							rowF.Size = UDim2.new(1,0,0,26)
							rowF.BackgroundColor3 = Color3.fromRGB(30, 20, 66)
							rowF.BackgroundTransparency = 0.25
							rowF.BorderSizePixel = 0
							rowF.Parent = dropContent
							local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 8); rc.Parent = rowF
							local lab = Instance.new("TextLabel")
							lab.Size = UDim2.new(1,-56,1,0)
							lab.Position = UDim2.new(0, 8, 0, 0)
							lab.BackgroundTransparency = 1
							lab.Text = labelText
							lab.TextColor3 = Color3.fromRGB(230,230,255)
							lab.TextSize = 11
							lab.Font = Enum.Font.Gotham
							lab.TextXAlignment = Enum.TextXAlignment.Left
							lab.Parent = rowF
							local copyBtn = createButton(rowF, "Copy", UDim2.new(0,50,0,20), UDim2.new(1,-56,0.5,-10), Color3.fromRGB(70, 55, 140), "复制")
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
						addInfoRow("PlaceId: " .. tostring(game.PlaceId or ""), game.PlaceId)
						local exeName = "未知"
						pcall(function() exeName = tostring(identifyexecutor() or "未知") end)
						addInfoRow("注入器: " .. exeName, exeName)
					elseif feat.Key == "ClickerMulti" then
						-- V6.2: 多球模式增加数量调节
						addCheckboxes(dropContent, {
							{"多球模式", States.ClickerMulti.Enabled, function(v) States.ClickerMulti.Enabled = v; Updaters.ClickerMulti() end},
						})
						createLabeledStep(dropContent, "⚪ 小球数量",
							function() return States.ClickerMulti.BallCount or 4 end,
							function(v) 
								States.ClickerMulti.BallCount = math.floor(v)
								Updaters.ClickerMulti()
							end,
							1, 2, 8,
						function(v) return tostring(math.floor(v)) end)
					elseif feat.Key == "RemoteInteract" then
						-- V6.3: 远程互动增加范围调节
						local riMark = Instance.new("TextLabel")
						riMark.Size = UDim2.new(1, 0, 0, 18)
						riMark.BackgroundTransparency = 1
						riMark.Text = "🌐 自动触发范围内所有可交互物"
						riMark.TextColor3 = Color3.fromRGB(220, 220, 255)
						riMark.TextSize = 10
						riMark.Font = Enum.Font.Gotham
						riMark.Parent = dropContent
						createLabeledStep(dropContent, "🎯 互动范围(m)",
							function() return States.RemoteInteract.Range or 400 end,
							function(v)
								States.RemoteInteract.Range = math.floor(v)
							end,
							50, 25, 50000,
							function(v) return tostring(math.floor(v)) end)
						local riRun = createButton(dropContent, "RIRun", UDim2.new(1, 0, 0, 28), UDim2.new(), Color3.fromRGB(90, 65, 160), "🌐 执行远程互动")
						riRun.TextSize = 12
						riRun.MouseButton1Click:Connect(function()
							musicToast("🌐 远程互动中...")
							task.spawn(function()
								local range = States.RemoteInteract.Range or 400
								local origin = hrp and hrp.Position or Vector3.zero
								local count = 0
								for _, p in pairs(Workspace:GetDescendants()) do
									if p:IsA("ProximityPrompt") then
										if p.Parent and p.Parent:IsA("BasePart") then
											local d = (p.Parent.Position - origin).Magnitude
											if d > range then continue end
										end
										pcall(function()
											p.HoldDuration = 0
											fireproximityprompt(p)
											count = count + 1
										end)
									end
								end
								musicToast("✅ 已互动 " .. count .. " 个对象")
							end)
						end)
					end

					local tg = createToggle(row, feat.Key)
					tg.Position = UDim2.new(0, 316, 0.5, -13)
				else
					local label = Instance.new("TextLabel")
					label.Size = UDim2.new(0,84,1,0); label.Position = UDim2.new(0,32,0,0)
					label.BackgroundTransparency = 1; label.Text = feat.Name
					label.TextColor3 = Color3.fromRGB(238,238,255); label.TextSize = 12
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

				raiseZIndex(row, 9004)
			end)
			if ok and row then
				table.insert(FeatureRows, row)
				yOffset = yOffset + (feat.HasDropdown and 39 or (feat.IsButton and 39 or 47))
			else
				if row then pcall(function() row:Destroy() end) end
			end
		end
	end

	Gui.ScrollInner.Size = UDim2.new(0, ROW_W, 0, yOffset)
	Gui.ScrollInner.Position = UDim2.new(0, 6, 0, 0)
end
Gui.refreshFeatures = refreshFeatures

-- ============================================
-- 分类按钮
-- ============================================
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
-- 核心功能实现
-- ============================================

Updaters.DynamicIsland = function()
	if States.DynamicIsland.Enabled then
		if Gui.FloatBall then
			pcall(function() Gui.FloatBall:Destroy() end)
			Gui.FloatBall = nil
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

-- 音乐播放器开关(V6.1: 开启自动展开面板)
Updaters.MusicPlayer = function()
	if States.MusicPlayer.Enabled then
		Gui.MusicPanel.Visible = true
		if Gui.MusicBarText then Gui.MusicBarText.Text = "🎵 音乐播放器" end
		if not Music.Open then
			Music.Open = true
			Gui.MusicPanel.ClipsDescendants = true
			Gui.MusicPanel.Size = UDim2.new(0, 380, 0, 380)
		end
		if #Music.List == 0 and Music.Tab ~= "Search" then
			setMusicTab("Rec")
		end
	else
		Gui.MusicPanel.Visible = false
	end
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
		Gui.Fly1SpeedLabel.Text = "速度: " .. States.Fly1.Value
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
		Gui.Fly1Panel.Visible = false
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
			if not hrp then return end
			if not States.Fly2.Flying then return end
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

local FreeMoveBG, FreeMoveBV
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

local NoclipCache = {}
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

local BunnyCount = 0
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
					if part:IsA("BasePart") then
						part.CanTouch = false
					end
				end
			end
		end)
	else
		unbind("God")
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
		end
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanTouch = true
				end
			end
		end
	end
end

-- ============================================
-- 大陀螺: 仅旋转身体, 不改变视角与移动方向
-- ============================================
Updaters.BigSpin = function()
	if States.BigSpin.Enabled then
		if Conns.BigSpin then return end
		local spin = 0
		if humanoid then pcall(function() humanoid.AutoRotate = false end) end
		Conns.BigSpin = RunService.RenderStepped:Connect(function(dt)
			if not States.BigSpin.Enabled then return end
			if humanoid then pcall(function() humanoid.AutoRotate = false end) end
			local root = hrp
			if not root then
				refreshCharacter()
				root = hrp
			end
			if not root then
				root = character and (character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso"))
			end
			if not root then return end
			local spd = States.BigSpin.Value or States.BigSpin.Speed or 30
			-- 匀速: 每帧累加固定角(度/秒), 不叠加已有旋转, 保证转速恒定
			spin = spin + math.rad(spd) * (dt or 0.016)
			spin = spin % (math.pi * 2)
			-- 仅绕自身竖直轴旋转, 位置不动, 视角与移动方向不受影响
			root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, spin, 0)
		end)
	else
		unbind("BigSpin")
		if humanoid then pcall(function() humanoid.AutoRotate = true end) end
	end
end

-- ============================================
-- 上帝模式(灵魂出窍简化版): 无敌+幽灵穿墙
-- ============================================
local GodSoulOrigMax = 100
Updaters.GodSoul = function()
	if States.GodSoul.Enabled then
		if Conns.GodSoul then return end
		if humanoid then GodSoulOrigMax = humanoid.MaxHealth end
		Conns.GodSoul = RunService.Heartbeat:Connect(function()
			if not States.GodSoul.Enabled then return end
			if humanoid then
				pcall(function()
					humanoid.MaxHealth = 1e9
					humanoid.Health = 1e9
					humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
				end)
			end
			if character then
				for _, part in pairs(character:GetDescendants()) do
					if part:IsA("BasePart") then
						-- 灵魂体: 不可碰撞/不可被击杀/不被射线命中/接近隐身
						part.CanCollide = false
						part.CanTouch = false
						part.CanQuery = false
						if part.Transparency < 0.6 then part.Transparency = 0.6 end
					end
				end
			end
		end)
		pcall(function()
			if humanoid then humanoid.WalkSpeed = math.max(humanoid.WalkSpeed, 28) end
		end)
	else
		unbind("GodSoul")
		if humanoid then
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
				humanoid.MaxHealth = GodSoulOrigMax
				humanoid.Health = humanoid.MaxHealth
			end)
		end
		if character then
			for _, part in pairs(character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = true
					part.CanTouch = true
					part.CanQuery = true
					part.Transparency = 0
				end
			end
		end
	end
end

local NoCdLast = 0
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

local InfAmmoLast = 0
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

local OrigLighting = {}
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
local XrayTick = 0
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
		local c = States.ColorFilter.Value:lower()
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
		syncClickerBallVisibility()
	end
end

Updaters.ClickerStart = function()
	if States.ClickerStart.Enabled then
		if ClickerThread then return end
		ClickerThread = task.spawn(function()
			local inset = GuiService:GetGuiInset()
			while States.ClickerStart.Enabled do
				for _, ball in ipairs(Gui.ClickerBalls) do
					if ball and ball.Visible and ball.Parent then
						-- V6.2: 修正点击位置偏移(左下方偏移修正)
						local pos = ball.AbsolutePosition + ball.AbsoluteSize / 2 + Vector2.new(inset.X, inset.Y) + Vector2.new(3, -3)
						pcall(function()
							VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
							task.wait(0.01)
							VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
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

-- V6.3: 统一控制点击小球显示(连点/点击脚本/客户端脚本任一开启则显示)
local function syncClickerBallVisibility()
	local show = States.AutoClicker.Enabled or States.ClickScript.Enabled
	for _, ball in ipairs(Gui.ClickerBalls) do
		if ball then ball.Visible = show end
	end
end

Updaters.ClickerMulti = function()
	if States.ClickerMulti.Enabled then
		local targetCount = States.ClickerMulti.BallCount or 4
		while #Gui.ClickerBalls < targetCount do
			Gui.createClickerBall()
		end
		while #Gui.ClickerBalls > targetCount do
			local b = table.remove(Gui.ClickerBalls)
			if b then b:Destroy() end
		end
	else
		while #Gui.ClickerBalls > 2 do
			local b = table.remove(Gui.ClickerBalls)
			if b then b:Destroy() end
		end
	end
	for _, ball in ipairs(Gui.ClickerBalls) do
		-- 更新序号
		local idx = table.find(Gui.ClickerBalls, ball)
		local orderLbl = ball:FindFirstChild("OrderLabel")
		if orderLbl then
			orderLbl.Text = idx and tostring(idx) or ""
		end
	end
	syncClickerBallVisibility()
end

Updaters.ClickScript = function()
	-- 点击脚本面板显示/隐藏
	if ClickScriptPanel then
		ClickScriptPanel.Visible = States.ClickScript.Enabled
		-- V6.3: 开启点击脚本即显示所有小球(不再依赖连点器)
		syncClickerBallVisibility()
	end
	if not States.ClickScript.Enabled then
		syncClickerBallVisibility()
		States.ClickScript.Running = false
		if ClickScriptThread then
			ClickScriptThread = nil
		end
	end
end

Updaters.RemoteInteract = function()
	-- 远程互动按钮不需要持续更新
end

Updaters.CustomTeleport = function()
	-- V6.3: 自定义传送面板显示/隐藏
	if TeleportPanel then
		TeleportPanel.Visible = States.CustomTeleport.Enabled
	end
	if not States.CustomTeleport.Enabled then
		if TeleportPanel then TeleportPanel.Visible = false end
	end
end

Updaters.KeyMapping = function()
	-- V6.4: 按键映射面板显示/隐藏
	if KeyMapPanel then
		KeyMapPanel.Visible = States.KeyMapping.Enabled
	end
	if not States.KeyMapping.Enabled then
		if KeyMapPanel then KeyMapPanel.Visible = false end
		States.KeyMapping.Recording = false
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

-- ============================================
-- 自动保存配置
-- ============================================
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
		return HttpService:JSONEncode(save)
	end)
	if success then
		pcall(function() writefile("NinjaHubV2_Config.json", data) end)
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

CoreGui.ChildRemoved:Connect(function(child)
	if child == ScreenGui then
		saveConfig()
	end
end)

local function loadConfig()
	local data = nil
	pcall(function() data = readfile("NinjaHubV2_Config.json") end)
	if not data then
		pcall(function()
			local s = player:FindFirstChild("NinjaHubConfig")
			if s then data = s.Value end
		end)
	end
	if data then
		pcall(function()
			local decoded = HttpService:JSONDecode(data)
			for k, v in pairs(decoded) do
				if States[k] and type(v) == "table" then
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

local FpsCount, FpsLast = 0, tick()
Updaters.ShowFps = function()
	if States.ShowFps.Enabled then
		Gui.InfoLabel.Visible = true
		if Conns.FPS then return end
		Conns.FPS = RunService.Heartbeat:Connect(function()
			FpsCount = FpsCount + 1
			local now = tick()
			if now - FpsLast >= 1 then
				local txt = "FPS: " .. FpsCount
				if States.ShowCoords.Enabled and hrp then
					local pos = hrp.Position
					txt = txt .. string.format(" | %.1f, %.1f, %.1f", pos.X, pos.Y, pos.Z)
				end
				-- V6.2: 平滑动画更新
				animateLabelUpdate(Gui.InfoLabel, txt)
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
				-- V6.2: 平滑动画更新
				animateLabelUpdate(Gui.InfoLabel, txt)
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
				Gui.WarnLabel.Text = string.format("⚠ %s 接近中! (%.0fm)", name, closestDist)
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
			local sel = States.AimbotV2.SelectedCustom or {}
			local hasSel = false
			for _, c in ipairs(sel) do
				if c and c.Parent then hasSel = true; break end
			end
			if hasSel then
				-- 多选: 只开火已勾选的对象
				for _, c in ipairs(sel) do
					if c and c.Parent then table.insert(targets, c) end
				end
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

-- ============================================
-- 人物渲染系统
-- ============================================

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
					if States.PlayerDisplay.ShowName then
						table.insert(txtLines, p.Name)
					end
					if States.PlayerDisplay.ShowHealth and hum then
						table.insert(txtLines, string.format("❤ %.0f", hum.Health))
					end
					if States.PlayerDisplay.ShowDistance and hrp and targetHrp then
						table.insert(txtLines, string.format("%.1fm", (hrp.Position - targetHrp.Position).Magnitude))
					end
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

-- 框选生物(距离限制)
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
				for _, e in ipairs(TargetCache.Players) do
					drawFor(e.Obj, e.Obj.Name)
				end
			end
			if States.BoxCreature.BoxNpc then
				for _, e in ipairs(TargetCache.Npcs) do
					drawFor(e.Obj, e.Obj.Name)
				end
			end
			if States.BoxCreature.BoxOther then
				for _, m in ipairs(TargetCache.Others) do
					drawFor(m, m.Name)
				end
			end
		end)
	else
		unbind("BoxCreature")
		clearPool(Pools.Box.Lines)
		clearAdorns(AdornPools.Box)
		clearAdorns(AdornPools.Hitbox)
	end
end

-- 连线追踪(距离限制)
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
					if bcf then
						endPos = bcf.Position
					end
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
				for _, e in ipairs(TargetCache.Players) do
					drawLineTo(e.Obj, e.Plr.Name .. "line")
				end
			end
			if States.LineConnect.ConnectNpc then
				for _, e in ipairs(TargetCache.Npcs) do
					drawLineTo(e.Obj, e.Obj.Name .. "line")
				end
			end
			if States.LineConnect.ConnectOther then
				for _, m in ipairs(TargetCache.Others) do
					drawLineTo(m, m.Name .. "line")
				end
			end
		end)
	else
		unbind("LineConnect")
		clearBeams(BeamPools.Connect)
	end
end

-- 智能自瞄V2(距离限制)
local AimScanTick = 0
local AimClosest = nil
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
			if Gui.AimCircleStroke then
				Gui.AimCircleStroke.Color = getPartColor("aimcircle")
			end
			AimScanTick = AimScanTick + 1
			if AimScanTick % 3 == 0 then
				local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
				local radius = csize / 2
				local maxD = States.AimbotV2.MaxDistance or 0
				local best, bestDist = nil, math.huge
				updateTargetCache()
				local targets = {}
				local sel = States.AimbotV2.SelectedCustom or {}
				local hasSel = false
				for _, c in ipairs(sel) do
					if c and c.Parent then hasSel = true; break end
				end
				if hasSel then
					-- 多选: 只锁定已勾选的对象, 其余不参与自瞄
					for _, c in ipairs(sel) do
						if c and c.Parent then
							local hum = c:FindFirstChildOfClass("Humanoid")
							local hrp2 = c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso")
							table.insert(targets, {Obj = c, Hum = hum, Hrp = hrp2})
						end
					end
				else
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
					local function segH(x, y, w)
						drawHLine(Pools.Adv.Lines, RenderFolder, x, y, w, color, thickness)
					end
					local function segV(x, y, h)
						drawVLine(Pools.Adv.Lines, RenderFolder, x, y, h, color, thickness)
					end
					if States.AdvancedESP.BoxStyle == "Corner" then
						local cs = width * 0.2
						segH(boxX, boxY, cs)
						segV(boxX, boxY, cs)
						segH(boxX + width - cs, boxY, cs)
						segV(boxX + width, boxY, cs)
						segH(boxX, boxY + height, cs)
						segV(boxX, boxY + height - cs, cs)
						segH(boxX + width - cs, boxY + height, cs)
						segV(boxX + width, boxY + height - cs, cs)
					else
						segH(boxX, boxY, width)
						segH(boxX, boxY + height, width)
						segV(boxX, boxY, height)
						segV(boxX + width, boxY, height)
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
-- 保险机制: 每2秒检查已开启功能
-- ============================================
task.spawn(function()
	while true do
		task.wait(2)
		if ScriptClosed then return end
		for key, state in pairs(States) do
			if type(state) == "table" and state.Enabled and Updaters[key] then
				local skip = key == "AutoSave" or key == "AntiAfk" or key == "ClickerStart" or key == "DynamicIsland" or key == "MusicPlayer" or key == "ClickScript" or key == "RemoteInteract" or key == "KeyMapping"
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
		if ScriptClosed then return end
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
	if ScriptClosed then return end
	for key, _ in pairs(States) do
		local updater = Updaters[key]
		if updater and States[key].Enabled then
			pcall(updater)
		end
	end
end

player.CharacterRemoving:Connect(function()
	for name, conn in pairs(Conns) do
		if typeof(conn) == "RBXScriptConnection" then conn:Disconnect() end
		Conns[name] = nil
	end
	if FreeMoveBG then pcall(function() FreeMoveBG:Destroy() end); FreeMoveBG = nil end
	if FreeMoveBV then pcall(function() FreeMoveBV:Destroy() end); FreeMoveBV = nil end
	clearRenderCache()
end)

-- ============================================
-- 加载配置(秒加载)
-- ============================================
loadConfig()
for key, state in pairs(States) do
	if ToggleRefreshers[key] then pcall(ToggleRefreshers[key], state.Enabled) end
end
pcall(Gui.refreshFeatures)
for key, state in pairs(States) do
	if type(state) == "table" and state.Enabled then
		local updater = Updaters[key]
		if updater then
			pcall(updater)
		end
	end
end

-- ============================================
-- 加载完成
-- ============================================
local elapsed = tick() - LoadStartTime
if LoadingText then
	LoadingText.Text = string.format("✅ 加载完成 | 耗时 %.2fs", elapsed)
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

print(string.format("[NinjaHubV6.2] 加载完成 | 耗时 %.2fs | 超级自动化版", elapsed))
