--[[
	NovaUI v2 - A custom Roblox interface library
	Inspired by libraries like Rayfield and Obsidian UI.
	Single file, no external dependencies. Works via loadstring or require().

	FEATURES:
		- Minimize (-) shrinks the window to a small floating logo you can drag
		  around and click to bring the window back.
		- Close (X) fully unloads the UI (NovaUI:Destroy()) - re-run the script
		  to bring it back.
		- Smoother, springier animations throughout (Back/Quad easing, fades,
		  cross-fading tabs via CanvasGroup).
		- Collapsible sections (accordion-style, opts.Collapsible = true).
		- Config system: NovaUI:SaveConfig(name) / NovaUI:LoadConfig(name)
		  (uses writefile/readfile - only works on executors that support it).
		- Upgraded ColorPicker with a real saturation/value box + hue slider.
		- Dropdown supports single-select or opts.Multi = true for a checklist.
		- Slider values are editable by clicking the number.
		- Hover tooltips: pass opts.Tooltip = "..." to any element.
		- Optional background blur: opts.Blur = true on CreateWindow.
		- Notifications are click-to-dismiss.
		- New elements: CreateParagraph, CreateDivider.
		- Resizable window (drag the bottom-right corner).
		- Three themes: "Dark", "Light", "AMOLED".

	BASIC USAGE:
		local NovaUI = loadstring(game:HttpGet("RAW_URL"))()
		local Window = NovaUI:CreateWindow({Name = "My Hub", Theme = "Dark"})
		local Tab = Window:CreateTab("Main")
		local Section = Tab:CreateSection("General", {Collapsible = true})

		Section:CreateButton({Name = "Click Me", Callback = function() end})
		Section:CreateToggle({Name = "Enable", Default = false, Callback = function(v) end})
		Section:CreateSlider({Name = "Speed", Min = 0, Max = 100, Default = 16, Callback = function(v) end})
		Section:CreateDropdown({Name = "Mode", Options = {"A","B"}, Default = "A", Callback = function(v) end})
		Section:CreateColorPicker({Name = "Color", Default = Color3.fromRGB(255,0,0), Callback = function(c) end})
		Section:CreateKeybind({Name = "Bind", Default = Enum.KeyCode.RightShift, Callback = function() end})
		Section:CreateTextbox({Name = "Text", PlaceholderText = "...", Callback = function(t) end})
		Section:CreateParagraph({Title = "Note", Content = "Some helper text."})
		Section:CreateDivider()
		Section:CreateLabel({Text = "A simple label"})

		NovaUI:Notify({Title = "Hi", Content = "Hello!", Duration = 3, Type = "Success"})
		NovaUI:SaveConfig("profile1")
		NovaUI:LoadConfig("profile1")
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

-- Safe task wrappers: some executors don't fully implement the `task` library.
local safeSpawn = (task and task.spawn) or spawn
local safeDelay = (task and task.delay) or delay
local safeWait  = (task and task.wait) or wait

-- Safe filesystem check: writefile/readfile/isfile/isfolder/makefolder are
-- executor-only globals and won't exist in plain Roblox Studio.
local function fsAvailable()
	return typeof(writefile) == "function" and typeof(readfile) == "function"
end

local NovaUI = {}
NovaUI.__index = NovaUI
NovaUI.Flags = {}     -- current value of every element, keyed by Name
NovaUI.Elements = {}  -- Get/Set handles for every element, keyed by Name
NovaUI._searchRegistry = {} -- {instance, keywords} pairs used by the topbar search box
NovaUI.ConfigFolder = "NovaUI"
NovaUI.AutoLoadFile = "NovaUI/autoload.txt"

--======================================================
-- THEMES
--======================================================
local Themes = {
	Dark = {
		Background     = Color3.fromRGB(24, 24, 27),
		Topbar         = Color3.fromRGB(30, 30, 34),
		Sidebar        = Color3.fromRGB(20, 20, 23),
		SectionBg      = Color3.fromRGB(30, 30, 34),
		ElementBg      = Color3.fromRGB(38, 38, 43),
		ElementBgHover = Color3.fromRGB(46, 46, 52),
		Accent         = Color3.fromRGB(114, 137, 218),
		TextColor      = Color3.fromRGB(240, 240, 240),
		SubTextColor   = Color3.fromRGB(160, 160, 165),
		Stroke         = Color3.fromRGB(50, 50, 56),
		Success        = Color3.fromRGB(60, 200, 100),
		Warning        = Color3.fromRGB(230, 180, 40),
		Error          = Color3.fromRGB(230, 70, 70),
	},
	Light = {
		Background     = Color3.fromRGB(245, 245, 247),
		Topbar         = Color3.fromRGB(235, 235, 238),
		Sidebar        = Color3.fromRGB(230, 230, 233),
		SectionBg      = Color3.fromRGB(255, 255, 255),
		ElementBg      = Color3.fromRGB(240, 240, 243),
		ElementBgHover = Color3.fromRGB(225, 225, 230),
		Accent         = Color3.fromRGB(88, 101, 242),
		TextColor      = Color3.fromRGB(20, 20, 20),
		SubTextColor   = Color3.fromRGB(90, 90, 95),
		Stroke         = Color3.fromRGB(210, 210, 215),
		Success        = Color3.fromRGB(40, 170, 90),
		Warning        = Color3.fromRGB(200, 150, 20),
		Error          = Color3.fromRGB(210, 60, 60),
	},
	AMOLED = {
		Background     = Color3.fromRGB(0, 0, 0),
		Topbar         = Color3.fromRGB(10, 10, 10),
		Sidebar        = Color3.fromRGB(6, 6, 6),
		SectionBg      = Color3.fromRGB(12, 12, 12),
		ElementBg      = Color3.fromRGB(18, 18, 18),
		ElementBgHover = Color3.fromRGB(28, 28, 28),
		Accent         = Color3.fromRGB(0, 200, 150),
		TextColor      = Color3.fromRGB(235, 235, 235),
		SubTextColor   = Color3.fromRGB(140, 140, 140),
		Stroke         = Color3.fromRGB(30, 30, 30),
		Success        = Color3.fromRGB(60, 200, 100),
		Warning        = Color3.fromRGB(230, 180, 40),
		Error          = Color3.fromRGB(230, 70, 70),
	},
}

--======================================================
-- UTILITIES
--======================================================
local function Create(class, props, children)
	local inst = Instance.new(class)
	for prop, value in pairs(props or {}) do
		inst[prop] = value
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	return inst
end

local function Tween(inst, props, time, style, dir)
	local info = TweenInfo.new(time or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	local tween = TweenService:Create(inst, info, props)
	tween:Play()
	return tween
end

local function MakeDraggable(dragHandle, frame)
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

	UserInputService.InputChanged:Connect(function(input)
		if not frame.Parent then dragging = false return end
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
end

local function Corner(radius)
	return Create("UICorner", {CornerRadius = UDim.new(0, radius or 6)})
end

local function Stroke(color, thickness)
	return Create("UIStroke", {Color = color, Thickness = thickness or 1})
end

local function Padding(l, r, t, b)
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, l or 8),
		PaddingRight = UDim.new(0, r or 8),
		PaddingTop = UDim.new(0, t or 8),
		PaddingBottom = UDim.new(0, b or 8),
	})
end

-- Built-in icon glyphs (no asset upload needed). Pass any of these names as
-- an `Icon` option, or pass "rbxassetid://..." / an http(s) URL for a custom image.
local Icons = {
	home     = "https://studio.lucide.dev/api/shadcn?value=2.15u1v-8En-1-1h-4En-1rv8M3r0Br_.709-1.528l7-6Bru.582nl7_6AJp1u1r0v9Br-o2H5Br-2-2z&name=house, -- ⌂
	settings = "\226\154\153", -- ⚙
	check    = "\226\156\147", -- ✓
	cross    = "\226\156\149", -- ✕
	star     = "\226\152\133", -- ★
	circle   = "\226\151\143", -- ●
	square   = "\226\150\160", -- ■
	warning  = "\226\154\160", -- ⚠
	info     = "\226\147\152", -- ⓘ
	chevronR = "\226\150\184", -- ▸
	chevronD = "\226\150\190", -- ▾
	dot      = "\226\128\162", -- ‣
	bolt     = "\226\154\161", -- ⚡ (may render as a simple glyph on some fonts)
}

-- Icon accepts three shapes:
--   1. A built-in glyph name (see the Icons table below) - zero setup.
--   2. A plain "rbxassetid://..." or http(s) image URL - your own single icon image.
--   3. A sprite-sheet entry {id, {w,h}, {x,y}} (or {id=.., size={w,h}, offset={x,y}}) -
--      the exact format used by icon-pack tables (e.g. a Lucide sprite sheet you
--      generate and upload yourself). This lets you plug in any icon-name -> entry
--      table without NovaUI needing to embed one itself.
local function CreateIcon(iconValue, size, color)
	if not iconValue then return nil end
	local t = typeof(iconValue)

	if t == "string" and (iconValue:match("^rbxassetid://") or iconValue:match("^https?://")) then
		return Create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(0, size, 0, size),
			Image = iconValue,
			ImageColor3 = color,
		})
	end

	if t == "table" then
		local id = iconValue.id or iconValue[1]
		local rectSize = iconValue.size or iconValue[2]
		local rectOffset = iconValue.offset or iconValue[3]
		if id then
			local imageId = typeof(id) == "number" and ("rbxassetid://" .. id) or tostring(id)
			local props = {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, size, 0, size),
				Image = imageId,
				ImageColor3 = color,
			}
			if rectSize and rectOffset then
				props.ImageRectOffset = Vector2.new(rectOffset[1], rectOffset[2])
				props.ImageRectSize = Vector2.new(rectSize[1], rectSize[2])
			end
			return Create("ImageLabel", props)
		end
	end

	local glyph = Icons[iconValue]
	if not glyph then return nil end
	return Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(0, size, 0, size),
		Font = Enum.Font.GothamBold,
		Text = glyph,
		TextColor3 = color,
		TextSize = size - 3,
	})
end

local function RegisterSearchable(instance, name)
	if not name then return end
	table.insert(NovaUI._searchRegistry, {instance = instance, keywords = tostring(name):lower()})
end

local function AttachTooltip(screenGui, theme, target, text)
	if not text or not screenGui then return end
	target.MouseEnter:Connect(function()
		local tip = Create("TextLabel", {
			BackgroundColor3 = theme.Topbar,
			AutomaticSize = Enum.AutomaticSize.XY,
			Font = Enum.Font.Gotham,
			Text = text,
			TextColor3 = theme.TextColor,
			TextSize = 12,
			TextWrapped = true,
			ZIndex = 1000,
			Parent = screenGui,
		}, {Corner(4), Stroke(theme.Stroke), Padding(6, 6, 4, 4)})

		local function reposition()
			local mousePos = UserInputService:GetMouseLocation()
			tip.Position = UDim2.new(0, mousePos.X + 16, 0, mousePos.Y + 16)
		end
		reposition()

		local moveConn
		moveConn = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement then
				reposition()
			end
		end)

		local leaveConn
		leaveConn = target.MouseLeave:Connect(function()
			if moveConn then moveConn:Disconnect() end
			if tip then tip:Destroy() end
			if leaveConn then leaveConn:Disconnect() end
		end)
	end)
end

-- Type-aware encode/decode so Color3 / EnumItem values survive a JSON round-trip.
local function encodeValue(v)
	local t = typeof(v)
	if t == "Color3" then
		return {__type = "Color3", R = v.R, G = v.G, B = v.B}
	elseif t == "EnumItem" then
		local enumTypeStr = tostring(v.EnumType)
		local enumName = enumTypeStr:match("^Enum%.(.+)$") or enumTypeStr
		return {__type = "EnumItem", Enum = enumName, Name = v.Name}
	else
		return v
	end
end

local function decodeValue(v)
	if typeof(v) == "table" and v.__type == "Color3" then
		return Color3.new(v.R, v.G, v.B)
	elseif typeof(v) == "table" and v.__type == "EnumItem" then
		local enumTable = Enum[v.Enum]
		return enumTable and enumTable[v.Name]
	else
		return v
	end
end

--======================================================
-- NOTIFICATIONS
--======================================================
local NotifHolder

local function EnsureNotifHolder(screenGui, theme)
	if NotifHolder and NotifHolder.Parent then return NotifHolder end
	NotifHolder = Create("Frame", {
		Name = "NotificationHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.new(0, 280, 1, -40),
		Parent = screenGui,
	}, {
		Create("UIListLayout", {
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		})
	})
	return NotifHolder
end

function NovaUI:Notify(opts)
	opts = opts or {}
	local title = opts.Title or "Notification"
	local content = opts.Content or ""
	local duration = opts.Duration or 4
	local ntype = opts.Type or "Info"

	local theme = self._theme or Themes.Dark
	local holder = EnsureNotifHolder(self._screenGui, theme)

	local accentColor = theme.Accent
	if ntype == "Success" then accentColor = theme.Success
	elseif ntype == "Warning" then accentColor = theme.Warning
	elseif ntype == "Error" then accentColor = theme.Error end

	local notif = Create("Frame", {
		BackgroundColor3 = theme.SectionBg,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
	}, {
		Corner(8),
		Stroke(theme.Stroke),
		Create("Frame", {
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = accentColor,
			BorderSizePixel = 0,
		}, {Corner(2)}),
		Create("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 0),
			Size = UDim2.new(1, -22, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, {
			Padding(0, 0, 8, 8),
			Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 18),
				Font = Enum.Font.GothamBold,
				Text = title,
				TextColor3 = theme.TextColor,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			Create("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				Font = Enum.Font.Gotham,
				Text = content,
				TextColor3 = theme.SubTextColor,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
		}),
	})
	notif.Parent = holder

	local dismissed = false
	local function dismiss()
		if dismissed then return end
		dismissed = true
		if notif and notif.Parent then
			Tween(notif, {BackgroundTransparency = 1}, 0.2, Enum.EasingStyle.Quad)
			safeWait(0.2)
			if notif then notif:Destroy() end
		end
	end

	local dismissBtn = Create("TextButton", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 10,
		Parent = notif,
	})
	dismissBtn.MouseButton1Click:Connect(dismiss)

	Tween(notif, {BackgroundTransparency = 0}, 0.25, Enum.EasingStyle.Quad)
	safeDelay(duration, function()
		if notif and notif.Parent and not dismissed then
			dismissed = true
			Tween(notif, {BackgroundTransparency = 1}, 0.25, Enum.EasingStyle.Quad)
			safeWait(0.25)
			if notif then notif:Destroy() end
		end
	end)
end

--======================================================
-- CONFIG (save / load current Flags to a file)
--======================================================
function NovaUI:SaveConfig(configName)
	configName = configName or "default"
	if not fsAvailable() then
		self:Notify({Title = "Config", Content = "This executor doesn't support file saving.", Type = "Error"})
		return false
	end
	pcall(function()
		if isfolder and makefolder and not isfolder(NovaUI.ConfigFolder) then
			makefolder(NovaUI.ConfigFolder)
		end
	end)

	local data = {}
	for name, value in pairs(NovaUI.Flags) do
		data[name] = encodeValue(value)
	end

	local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
	if not ok then
		self:Notify({Title = "Config", Content = "Failed to encode config.", Type = "Error"})
		return false
	end

	local path = NovaUI.ConfigFolder .. "/" .. configName .. ".json"
	local writeOk = pcall(function() writefile(path, encoded) end)
	if writeOk then
		self:Notify({Title = "Config Saved", Content = "Saved as \"" .. configName .. "\".", Type = "Success"})
	else
		self:Notify({Title = "Config", Content = "Failed to write config file.", Type = "Error"})
	end
	return writeOk
end

function NovaUI:LoadConfig(configName)
	configName = configName or "default"
	if not fsAvailable() then
		self:Notify({Title = "Config", Content = "This executor doesn't support file loading.", Type = "Error"})
		return false
	end

	local path = NovaUI.ConfigFolder .. "/" .. configName .. ".json"
	if not (isfile and isfile(path)) then
		self:Notify({Title = "Config", Content = "No config named \"" .. configName .. "\" found.", Type = "Warning"})
		return false
	end

	local readOk, raw = pcall(function() return readfile(path) end)
	if not readOk then
		self:Notify({Title = "Config", Content = "Failed to read config file.", Type = "Error"})
		return false
	end

	local decodeOk, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not decodeOk then
		self:Notify({Title = "Config", Content = "Failed to decode config file.", Type = "Error"})
		return false
	end

	for name, value in pairs(data) do
		local element = NovaUI.Elements[name]
		if element and element.Set then
			pcall(function() element.Set(decodeValue(value)) end)
		end
	end

	self:Notify({Title = "Config Loaded", Content = "Loaded \"" .. configName .. "\".", Type = "Success"})
	return true
end

function NovaUI:ListConfigs()
	if not fsAvailable() or typeof(listfiles) ~= "function" then return {} end
	local ok, files = pcall(function() return listfiles(NovaUI.ConfigFolder) end)
	if not ok or not files then return {} end
	local names = {}
	for _, path in ipairs(files) do
		local fname = path:match("([^/\\]+)%.json$")
		if fname then table.insert(names, fname) end
	end
	table.sort(names)
	return names
end

function NovaUI:DeleteConfig(configName)
	if not fsAvailable() or typeof(delfile) ~= "function" then
		self:Notify({Title = "Config", Content = "This executor doesn't support deleting files.", Type = "Error"})
		return false
	end
	local path = NovaUI.ConfigFolder .. "/" .. configName .. ".json"
	if not (isfile and isfile(path)) then
		self:Notify({Title = "Config", Content = "No config named \"" .. configName .. "\" found.", Type = "Warning"})
		return false
	end
	local ok = pcall(function() delfile(path) end)
	if ok then
		self:Notify({Title = "Config Deleted", Content = "Removed \"" .. configName .. "\".", Type = "Success"})
	else
		self:Notify({Title = "Config", Content = "Failed to delete config file.", Type = "Error"})
	end
	return ok
end

-- Autoload: remembers which config to load automatically next time
-- NovaUI:LoadAutoloadConfig() is called - typically once, at the end of your script.
function NovaUI:SetAutoloadConfig(configName)
	if not fsAvailable() then return false end
	local ok = pcall(function()
		if isfolder and makefolder and not isfolder(NovaUI.ConfigFolder) then
			makefolder(NovaUI.ConfigFolder)
		end
		writefile(NovaUI.AutoLoadFile, configName)
	end)
	return ok
end

function NovaUI:GetAutoloadConfig()
	if not fsAvailable() or not (isfile and isfile(NovaUI.AutoLoadFile)) then return nil end
	local ok, name = pcall(function() return readfile(NovaUI.AutoLoadFile) end)
	if ok and name and name ~= "" then return name end
	return nil
end

function NovaUI:ClearAutoloadConfig()
	if not fsAvailable() then return end
	pcall(function()
		if isfile and isfile(NovaUI.AutoLoadFile) and typeof(delfile) == "function" then
			delfile(NovaUI.AutoLoadFile)
		end
	end)
end

-- Call this once, after all your tabs/sections/elements are created, so every
-- element already has a registered Set() handle for the autoloaded values to land on.
function NovaUI:LoadAutoloadConfig()
	local name = self:GetAutoloadConfig()
	if name then
		self:LoadConfig(name)
		return true
	end
	return false
end

--======================================================
-- WINDOW
--======================================================
function NovaUI:Hide()
	if self._destroyed then return end
	local main, logo = self._main, self._logo
	if not main or not main.Visible then return end
	local size = self._winSize or Vector2.new(main.AbsoluteSize.X, main.AbsoluteSize.Y)

	Tween(main, {
		Size = UDim2.new(0, size.X * 0.85, 0, size.Y * 0.85),
		BackgroundTransparency = 1,
	}, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

	safeDelay(0.2, function()
		if main then main.Visible = false end
	end)

	if logo then
		logo.Visible = true
		logo.Size = UDim2.new(0, 0, 0, 0)
		Tween(logo, {Size = UDim2.new(0, 50, 0, 50)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	if self._blur then
		Tween(self._blur, {Size = 0}, 0.2, Enum.EasingStyle.Quad)
	end
end

function NovaUI:Show()
	if self._destroyed then return end
	local main, logo = self._main, self._logo
	if main and main.Visible then return end
	local size = self._winSize or Vector2.new(560, 380)

	if logo then
		Tween(logo, {Size = UDim2.new(0, 0, 0, 0)}, 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		safeDelay(0.15, function() if logo then logo.Visible = false end end)
	end

	if main then
		main.Visible = true
		main.Size = UDim2.new(0, size.X * 0.85, 0, size.Y * 0.85)
		main.BackgroundTransparency = 1
		Tween(main, {
			Size = UDim2.new(0, size.X, 0, size.Y),
			BackgroundTransparency = 0,
		}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	end

	if self._blur then
		Tween(self._blur, {Size = self._blurSize or 16}, 0.3, Enum.EasingStyle.Quad)
	end
end

function NovaUI:Toggle()
	if self._destroyed then return end
	if self._main and self._main.Visible then
		self:Hide()
	else
		self:Show()
	end
end

function NovaUI:Destroy()
	self._destroyed = true
	if self._blur then
		pcall(function() self._blur:Destroy() end)
		self._blur = nil
	end
	if self._screenGui then
		pcall(function() self._screenGui:Destroy() end)
	end
	NotifHolder = nil
	NovaUI.Flags = {}
	NovaUI.Elements = {}
end

local function FormatKeyName(keyCode)
	local name = keyCode.Name
	local spaced = name:gsub("(%u)", " %1"):gsub("^%s+", "")
	return spaced:upper()
end

local function CreateTrafficDot(parent, color)
	return Create("TextButton", {
		Size = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = color,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, {Corner(6)})
end

function NovaUI:CreateCategory(name)
	local theme = self._theme
	return Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.GothamBold,
		Text = name:upper(),
		TextColor3 = theme.SubTextColor,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._sidebar,
	})
end

function NovaUI:CreateWindow(opts)
	opts = opts or {}
	local themeName = opts.Theme or "Dark"
	local theme = Themes[themeName] or Themes.Dark
	local toggleKey = opts.ToggleKeybind or Enum.KeyCode.RightControl

	local existing = CoreGui:FindFirstChild("NovaUI_ScreenGui")
	if existing then existing:Destroy() end
	local existingBlur = Lighting:FindFirstChild("NovaUI_Blur")
	if existingBlur then existingBlur:Destroy() end

	local screenGui = Create("ScreenGui", {
		Name = "NovaUI_ScreenGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local parentOk = pcall(function() screenGui.Parent = CoreGui end)
	if not parentOk then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	local winW = (opts.Size and opts.Size.X) or 560
	local winH = (opts.Size and opts.Size.Y) or 380
	local minW, minH = 420, 260

	local main = Create("Frame", {
		Name = "Main",
		Size = UDim2.new(0, winW * 0.9, 0, winH * 0.9),
		Position = UDim2.new(0.5, -winW / 2, 0.5, -winH / 2),
		BackgroundColor3 = theme.Background,
		BackgroundTransparency = 1,
		Parent = screenGui,
	}, {
		Corner(10),
		Stroke(theme.Stroke),
	})

	Tween(main, {
		Size = UDim2.new(0, winW, 0, winH),
		BackgroundTransparency = 0,
	}, 0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	NovaUI._searchRegistry = {}

	local topbar = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = theme.Topbar,
		Parent = main,
	}, {
		Corner(10),
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 68, 0, 0),
			Size = UDim2.new(0, 140, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = opts.Name or "NovaUI",
			TextColor3 = theme.TextColor,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	local Window -- forward declare so callbacks below can reference it

	-- traffic-light window controls (red = close/destroy, yellow = minimize to logo, green = maximize)
	local dots = Create("Frame", {
		Position = UDim2.new(0, 14, 0.5, -6),
		Size = UDim2.new(0, 44, 0, 12),
		BackgroundTransparency = 1,
		Parent = topbar,
	}, {
		Create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	local redDot = CreateTrafficDot(dots, theme.Error)
	local yellowDot = CreateTrafficDot(dots, theme.Warning)
	local greenDot = CreateTrafficDot(dots, theme.Success)

	redDot.MouseEnter:Connect(function() Tween(redDot, {Size = UDim2.new(0, 14, 0, 14)}, 0.1) end)
	redDot.MouseLeave:Connect(function() Tween(redDot, {Size = UDim2.new(0, 12, 0, 12)}, 0.1) end)
	redDot.MouseButton1Click:Connect(function()
		Window:Destroy() -- fully unloads the UI; re-run the script to bring it back
	end)

	yellowDot.MouseEnter:Connect(function() Tween(yellowDot, {Size = UDim2.new(0, 14, 0, 14)}, 0.1) end)
	yellowDot.MouseLeave:Connect(function() Tween(yellowDot, {Size = UDim2.new(0, 12, 0, 12)}, 0.1) end)
	yellowDot.MouseButton1Click:Connect(function()
		Window:Hide() -- shrink to the floating logo
	end)

	local maximized = false
	greenDot.MouseEnter:Connect(function() Tween(greenDot, {Size = UDim2.new(0, 14, 0, 14)}, 0.1) end)
	greenDot.MouseLeave:Connect(function() Tween(greenDot, {Size = UDim2.new(0, 12, 0, 12)}, 0.1) end)
	greenDot.MouseButton1Click:Connect(function()
		maximized = not maximized
		local targetX = maximized and math.min(winW * 1.35, 900) or winW
		local targetY = maximized and math.min(winH * 1.35, 650) or winH
		Window._winSize = Vector2.new(targetX, targetY)
		Tween(main, {Size = UDim2.new(0, targetX, 0, targetY)}, 0.25, Enum.EasingStyle.Quad)
	end)

	-- keybind badge (shows the current show/hide hotkey)
	Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, 110, 0, 20),
		BackgroundColor3 = theme.ElementBg,
		Font = Enum.Font.GothamBold,
		Text = FormatKeyName(toggleKey),
		TextColor3 = theme.SubTextColor,
		TextSize = 10,
		Parent = topbar,
	}, {Corner(4)})

	-- live search bar: filters every element across every tab by name
	local searchBox = Create("TextBox", {
		Position = UDim2.new(0, 220, 0, 7),
		Size = UDim2.new(1, -350, 0, 26),
		BackgroundColor3 = theme.ElementBg,
		PlaceholderText = "Search features... (Ctrl+K)",
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = theme.TextColor,
		ClearTextOnFocus = false,
		Parent = topbar,
	}, {Corner(6), Padding(10, 10, 0, 0)})

	local function applySearch(query)
		query = (query or ""):lower()
		for _, entry in ipairs(NovaUI._searchRegistry) do
			if entry.instance and entry.instance.Parent then
				if query == "" then
					entry.instance.Visible = true
				else
					entry.instance.Visible = entry.keywords:find(query, 1, true) ~= nil
				end
			end
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() applySearch(searchBox.Text) end)

	local body = Create("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		Parent = main,
	})

	MakeDraggable(topbar, main)

	local sidebar = Create("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 140, 1, 0),
		BackgroundColor3 = theme.Sidebar,
		Parent = body,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder}),
		Padding(6, 6, 8, 8),
	})

	local pages = Create("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 140, 0, 0),
		Size = UDim2.new(1, -140, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})

	-- resize grip (bottom-right corner)
	local resizeGrip = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -4),
		Size = UDim2.new(0, 18, 0, 18),
		BackgroundTransparency = 1,
		Text = "◢",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = theme.SubTextColor,
		AutoButtonColor = false,
		Parent = main,
	})
	do
		local resizing = false
		local startSize, startPos
		resizeGrip.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = true
				startSize = main.AbsoluteSize
				startPos = input.Position
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				resizing = false
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if not main.Parent then resizing = false return end
			if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				local delta = input.Position - startPos
				local newW = math.max(minW, startSize.X + delta.X)
				local newH = math.max(minH, startSize.Y + delta.Y)
				main.Size = UDim2.new(0, newW, 0, newH)
				if Window then Window._winSize = Vector2.new(newW, newH) end
			end
		end)
	end

	-- floating logo shown when the window is hidden
	local logo = Create("TextButton", {
		Name = "NovaUI_Logo",
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.LogoPosition or UDim2.new(0, 50, 0, 50),
		Size = UDim2.new(0, 50, 0, 50),
		BackgroundColor3 = theme.Accent,
		AutoButtonColor = false,
		Text = "",
		Parent = screenGui,
	}, {
		Corner(25),
		Stroke(theme.Stroke, 2),
	})
	if opts.LogoIcon then
		local icon = CreateIcon(opts.LogoIcon, 26, Color3.fromRGB(255, 255, 255))
		if icon then
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.new(0.5, 0, 0.5, 0)
			icon.Parent = logo
		end
	end
	if not logo:FindFirstChildWhichIsA("ImageLabel") then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = opts.LogoText or string.sub(opts.Name or "N", 1, 1):upper(),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 20,
			Parent = logo,
		})
	end
	MakeDraggable(logo, logo)
	logo.MouseButton1Click:Connect(function()
		Window:Show()
	end)
	logo.MouseEnter:Connect(function() Tween(logo, {Size = UDim2.new(0, 56, 0, 56)}, 0.15, Enum.EasingStyle.Back) end)
	logo.MouseLeave:Connect(function() Tween(logo, {Size = UDim2.new(0, 50, 0, 50)}, 0.15, Enum.EasingStyle.Back) end)

	local blur
	if opts.Blur then
		blur = Create("BlurEffect", {Name = "NovaUI_Blur", Size = 0, Parent = Lighting})
		Tween(blur, {Size = opts.BlurSize or 16}, 0.35, Enum.EasingStyle.Quad)
	end

	Window = setmetatable({
		_theme = theme,
		_screenGui = screenGui,
		_main = main,
		_sidebar = sidebar,
		_pages = pages,
		_tabs = {},
		_logo = logo,
		_winSize = Vector2.new(winW, winH),
		_blur = blur,
		_blurSize = opts.BlurSize or 16,
	}, NovaUI)

	self._theme = theme
	self._screenGui = screenGui

	UserInputService.InputBegan:Connect(function(input, processed)
		if not main.Parent then return end
		if processed then return end
		if input.KeyCode == toggleKey then
			Window:Toggle()
		elseif input.KeyCode == Enum.KeyCode.K and
			(UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
			searchBox:CaptureFocus()
		end
	end)

	return Window
end

--======================================================
-- TAB
--======================================================
function NovaUI:CreateTab(name, tabOpts)
	tabOpts = tabOpts or {}
	local theme = self._theme
	local pagesFrame = self._pages
	local sidebarFrame = self._sidebar

	local tabBtn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = theme.ElementBg,
		Text = "",
		AutoButtonColor = false,
		Parent = sidebarFrame,
	}, {Corner(6)})

	local indicator = Create("Frame", {
		Name = "Indicator",
		Size = UDim2.new(0, 3, 0.6, 0),
		Position = UDim2.new(0, 0, 0.2, 0),
		BackgroundColor3 = theme.Accent,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = tabBtn,
	}, {Corner(2)})

	local labelX = 12
	if tabOpts.Icon then
		local icon = CreateIcon(tabOpts.Icon, 16, theme.SubTextColor)
		if icon then
			icon.Name = "Icon"
			icon.Position = UDim2.new(0, 10, 0.5, -8)
			icon.Parent = tabBtn
			labelX = 32
		end
	end

	Create("TextLabel", {
		Name = "Label",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, labelX, 0, 0),
		Size = UDim2.new(1, -labelX, 1, 0),
		Font = Enum.Font.Gotham,
		Text = name,
		TextColor3 = theme.SubTextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = tabBtn,
	})

	local pageGroup = Create("CanvasGroup", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		GroupTransparency = 1,
		Visible = false,
		Parent = pagesFrame,
	})

	local page = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = pageGroup,
	}, {
		Padding(14, 14, 14, 14),
		Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	local Tab = setmetatable({
		_theme = theme,
		_page = page,
		_screenGui = self._screenGui,
	}, NovaUI)

	local function selectTab()
		for _, child in ipairs(pagesFrame:GetChildren()) do
			if child:IsA("CanvasGroup") and child ~= pageGroup then
				local other = child
				Tween(other, {GroupTransparency = 1}, 0.12, Enum.EasingStyle.Quad)
				safeDelay(0.12, function()
					if other then other.Visible = false end
				end)
			end
		end
		for _, child in ipairs(sidebarFrame:GetChildren()) do
			if child:IsA("TextButton") then
				Tween(child, {BackgroundColor3 = theme.ElementBg}, 0.15, Enum.EasingStyle.Quad)
				local lbl = child:FindFirstChild("Label")
				if lbl then Tween(lbl, {TextColor3 = theme.SubTextColor}, 0.15, Enum.EasingStyle.Quad) end
				local icn = child:FindFirstChild("Icon")
				if icn then
					if icn:IsA("ImageLabel") then Tween(icn, {ImageColor3 = theme.SubTextColor}, 0.15, Enum.EasingStyle.Quad)
					else Tween(icn, {TextColor3 = theme.SubTextColor}, 0.15, Enum.EasingStyle.Quad) end
				end
				local ind = child:FindFirstChild("Indicator")
				if ind then Tween(ind, {BackgroundTransparency = 1}, 0.15, Enum.EasingStyle.Quad) end
			end
		end

		pageGroup.Visible = true
		Tween(pageGroup, {GroupTransparency = 0}, 0.18, Enum.EasingStyle.Quad)
		Tween(tabBtn, {BackgroundColor3 = theme.Accent}, 0.15, Enum.EasingStyle.Quad)
		local myLabel = tabBtn:FindFirstChild("Label")
		if myLabel then Tween(myLabel, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15, Enum.EasingStyle.Quad) end
		local myIcon = tabBtn:FindFirstChild("Icon")
		if myIcon then
			if myIcon:IsA("ImageLabel") then Tween(myIcon, {ImageColor3 = Color3.fromRGB(255, 255, 255)}, 0.15, Enum.EasingStyle.Quad)
			else Tween(myIcon, {TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15, Enum.EasingStyle.Quad) end
		end
		Tween(indicator, {BackgroundTransparency = 0}, 0.15, Enum.EasingStyle.Quad)
	end

	tabBtn.MouseButton1Click:Connect(selectTab)
	tabBtn.MouseEnter:Connect(function()
		if pageGroup.Visible then return end
		Tween(tabBtn, {BackgroundColor3 = theme.ElementBgHover}, 0.12, Enum.EasingStyle.Quad)
	end)
	tabBtn.MouseLeave:Connect(function()
		if pageGroup.Visible then return end
		Tween(tabBtn, {BackgroundColor3 = theme.ElementBg}, 0.12, Enum.EasingStyle.Quad)
	end)

	if #self._tabs == 0 then
		pageGroup.Visible = true
		selectTab()
	end
	table.insert(self._tabs, Tab)

	return Tab
end

--======================================================
-- SECTION
--======================================================
function NovaUI:CreateSection(name, sectionOpts)
	sectionOpts = sectionOpts or {}
	local theme = self._theme
	local collapsible = sectionOpts.Collapsible or false

	local section = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.SectionBg,
		Parent = self._page,
	}, {
		Corner(8),
		Stroke(theme.Stroke),
		Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBgHover,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = section,
	})

	local labelX = 12
	if sectionOpts.Icon then
		local icon = CreateIcon(sectionOpts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 12, 0.5, -8)
			icon.Parent = header
			labelX = 34
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, labelX, 0, 0),
		Size = UDim2.new(1, -labelX - 22, 1, 0),
		Font = Enum.Font.GothamBold,
		Text = name,
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local chevron
	if collapsible then
		chevron = Create("TextLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.new(0, 16, 0, 16),
			Font = Enum.Font.GothamBold,
			Text = "\226\150\190", -- ▾
			TextColor3 = theme.SubTextColor,
			TextSize = 14,
			Parent = header,
		})
	end

	local content = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = section,
	}, {
		Padding(12, 12, 4, 12),
		Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	header.MouseEnter:Connect(function() Tween(header, {BackgroundTransparency = 0.9}, 0.12, Enum.EasingStyle.Quad) end)
	header.MouseLeave:Connect(function() Tween(header, {BackgroundTransparency = 1}, 0.12, Enum.EasingStyle.Quad) end)

	local collapsed = false
	local expandedHeight = 0

	local function setCollapsed(state)
		if not collapsible or state == collapsed then return end
		collapsed = state
		if collapsed then
			expandedHeight = content.AbsoluteSize.Y
			content.AutomaticSize = Enum.AutomaticSize.None
			content.Size = UDim2.new(1, 0, 0, expandedHeight)
			Tween(content, {Size = UDim2.new(1, 0, 0, 0)}, 0.2, Enum.EasingStyle.Quad)
			safeDelay(0.2, function()
				if content then content.Visible = false end
			end)
			if chevron then Tween(chevron, {Rotation = -90}, 0.2, Enum.EasingStyle.Quad) end
		else
			content.Visible = true
			content.AutomaticSize = Enum.AutomaticSize.None
			content.Size = UDim2.new(1, 0, 0, 0)
			Tween(content, {Size = UDim2.new(1, 0, 0, expandedHeight)}, 0.2, Enum.EasingStyle.Quad)
			safeDelay(0.2, function()
				if content then content.AutomaticSize = Enum.AutomaticSize.Y end
			end)
			if chevron then Tween(chevron, {Rotation = 0}, 0.2, Enum.EasingStyle.Quad) end
		end
	end

	if collapsible then
		header.MouseButton1Click:Connect(function() setCollapsed(not collapsed) end)
	end

	local SectionObj = setmetatable({_theme = theme, _container = content, _screenGui = self._screenGui}, NovaUI)
	SectionObj.Collapse = function() setCollapsed(true) end
	SectionObj.Expand = function() setCollapsed(false) end
	SectionObj.ToggleCollapse = function() setCollapsed(not collapsed) end
	return SectionObj
end

--======================================================
-- ELEMENTS
--======================================================

function NovaUI:CreateButton(opts)
	opts = opts or {}
	local theme = self._theme
	local btn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Text = opts.Icon and "" or (opts.Name or "Button"),
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = theme.TextColor,
		AutoButtonColor = false,
		Parent = self._container,
	}, {Corner(6)})

	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 18, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 10, 0.5, -9)
			icon.Parent = btn
		end
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 34, 0, 0),
			Size = UDim2.new(1, -40, 1, 0),
			Font = Enum.Font.Gotham,
			Text = opts.Name or "Button",
			TextColor3 = theme.TextColor,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
	end

	btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = theme.ElementBgHover}, 0.15, Enum.EasingStyle.Quad) end)
	btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = theme.ElementBg}, 0.15, Enum.EasingStyle.Quad) end)
	btn.MouseButton1Click:Connect(function()
		if opts.Callback then
			safeSpawn(opts.Callback)
		end
	end)
	RegisterSearchable(btn, opts.Name or "Button")
	AttachTooltip(self._screenGui, theme, btn, opts.Tooltip)
	return btn
end

function NovaUI:CreateToggle(opts)
	opts = opts or {}
	local theme = self._theme
	local state = opts.Default or false
	local hasDesc = opts.Description ~= nil
	local rowHeight = hasDesc and 50 or 34

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	local labelX = 10
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = hasDesc and UDim2.new(0, 10, 0, 8) or UDim2.new(0, 10, 0.5, -8)
			icon.Parent = holder
			labelX = 32
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, labelX, 0, hasDesc and 6 or 0),
		Size = UDim2.new(1, -labelX - 50, 0, hasDesc and 16 or rowHeight),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Toggle",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Parent = holder,
	})

	if hasDesc then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, labelX, 0, 24),
			Size = UDim2.new(1, -labelX - 50, 0, 16),
			Font = Enum.Font.Gotham,
			Text = opts.Description,
			TextColor3 = theme.SubTextColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Parent = holder,
		})
	end

	local switchBg = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 20),
		BackgroundColor3 = state and theme.Accent or theme.Sidebar,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	}, {Corner(10)})

	local knob = Create("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		Parent = switchBg,
	}, {Corner(8)})

	local function setState(new, fire)
		state = new
		NovaUI.Flags[opts.Name or "Toggle"] = state
		Tween(switchBg, {BackgroundColor3 = state and theme.Accent or theme.Sidebar}, 0.15, Enum.EasingStyle.Quad)
		Tween(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		if fire and opts.Callback then safeSpawn(opts.Callback, state) end
	end

	switchBg.MouseButton1Click:Connect(function()
		setState(not state, true)
	end)

	setState(state, false)

	RegisterSearchable(holder, opts.Name or "Toggle")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)
	NovaUI.Elements[opts.Name or "Toggle"] = {Get = function() return state end, Set = function(v) setState(v, false) end}
	return {Set = function(v) setState(v, true) end, Get = function() return state end}
end

function NovaUI:CreateSlider(opts)
	opts = opts or {}
	local theme = self._theme
	local min, max = opts.Min or 0, opts.Max or 100
	local value = math.clamp(opts.Default or min, min, max)
	local hasDesc = opts.Description ~= nil
	local rowHeight = hasDesc and 58 or 44
	local trackY = hasDesc and 40 or 26

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, rowHeight),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6), Padding(10, 10, 6, 6)})

	local labelX = 0
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 14, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 0, 0, 1)
			icon.Parent = holder
			labelX = 18
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, labelX, 0, 0),
		Size = UDim2.new(1, -labelX, 0, 16),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Slider",
		TextColor3 = theme.TextColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	if hasDesc then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, labelX, 0, 17),
			Size = UDim2.new(1, -labelX - 60, 0, 15),
			Font = Enum.Font.Gotham,
			Text = opts.Description,
			TextColor3 = theme.SubTextColor,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			Parent = holder,
		})
	end

	local valueBox = Create("TextBox", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 50, 0, 16),
		Font = Enum.Font.Gotham,
		Text = tostring(value),
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		ClearTextOnFocus = false,
		Parent = holder,
	})

	local track = Create("Frame", {
		Position = UDim2.new(0, 0, 0, trackY),
		Size = UDim2.new(1, -14, 0, 6),
		BackgroundColor3 = theme.Sidebar,
		Parent = holder,
	}, {Corner(3)})

	local fill = Create("Frame", {
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = theme.Accent,
		Parent = track,
	}, {Corner(3)})

	-- round drag-handle thumb, riding on the edge of the fill
	local thumb = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
		Size = UDim2.new(0, 14, 0, 14),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		ZIndex = 2,
		Parent = track,
	}, {Corner(7), Stroke(theme.Accent, 2)})

	local function setValue(newVal, fire)
		value = math.clamp(math.floor(newVal + 0.5), min, max)
		local rel = (value - min) / (max - min)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		thumb.Position = UDim2.new(rel, 0, 0.5, 0)
		valueBox.Text = tostring(value)
		NovaUI.Flags[opts.Name or "Slider"] = value
		if fire and opts.Callback then safeSpawn(opts.Callback, value) end
	end

	local dragging = false
	local function updateFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(min + (max - min) * rel, true)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			Tween(thumb, {Size = UDim2.new(0, 18, 0, 18)}, 0.1, Enum.EasingStyle.Back)
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if dragging then Tween(thumb, {Size = UDim2.new(0, 14, 0, 14)}, 0.1, Enum.EasingStyle.Back) end
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not track.Parent then dragging = false return end
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)

	RegisterSearchable(holder, opts.Name or "Slider")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)

	valueBox.FocusLost:Connect(function()
		local num = tonumber(valueBox.Text)
		if num then
			setValue(num, true)
		else
			valueBox.Text = tostring(value)
		end
	end)

	setValue(value, false)

	NovaUI.Elements[opts.Name or "Slider"] = {Get = function() return value end, Set = function(v) setValue(v, false) end}
	return {Set = function(v) setValue(v, true) end, Get = function() return value end}
end

function NovaUI:CreateDropdown(opts)
	opts = opts or {}
	local theme = self._theme
	local options = opts.Options or {}
	local isMulti = opts.Multi or false
	local open = false

	-- single mode: `selected` is one value. multi mode: `selectedSet` maps option -> true.
	local selected = opts.Default or options[1]
	local selectedSet = {}
	if isMulti then
		for _, v in ipairs(opts.Default or {}) do selectedSet[v] = true end
	end

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		ClipsDescendants = true,
		Parent = self._container,
	}, {Corner(6)})

	local header = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	})

	local dropdownLabelX = 10
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 10, 0, 9)
			icon.Parent = header
			dropdownLabelX = 32
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, dropdownLabelX, 0, 0),
		Size = UDim2.new(1, -dropdownLabelX - 20, 0, 34),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Dropdown",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})

	local valueLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 0),
		Size = UDim2.new(0, 120, 0, 34),
		Font = Enum.Font.Gotham,
		Text = "",
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = header,
	})

	local list = Create("Frame", {
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, #options * 28),
		BackgroundTransparency = 1,
		Parent = holder,
	}, {
		Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	local optButtons = {}

	local function refreshLabel()
		if isMulti then
			local names = {}
			for _, optName in ipairs(options) do
				if selectedSet[optName] then table.insert(names, tostring(optName)) end
			end
			valueLabel.Text = #names > 0 and table.concat(names, ", ") or "None"
		else
			valueLabel.Text = tostring(selected or "")
		end
	end

	local function setSelected(optName, fire)
		selected = optName
		refreshLabel()
		NovaUI.Flags[opts.Name or "Dropdown"] = optName
		if fire and opts.Callback then safeSpawn(opts.Callback, optName) end
	end

	local function toggleMulti(optName, fire)
		selectedSet[optName] = not selectedSet[optName] or nil
		if optButtons[optName] then
			Tween(optButtons[optName], {BackgroundColor3 = selectedSet[optName] and theme.Accent or theme.ElementBgHover}, 0.12, Enum.EasingStyle.Quad)
		end
		refreshLabel()
		local list_ = {}
		for _, optName2 in ipairs(options) do
			if selectedSet[optName2] then table.insert(list_, optName2) end
		end
		NovaUI.Flags[opts.Name or "Dropdown"] = list_
		if fire and opts.Callback then safeSpawn(opts.Callback, list_) end
	end

	local function rebuildOptions(newOptions)
		options = newOptions or options
		optButtons = {}
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, optName in ipairs(options) do
			local optBtn = Create("TextButton", {
				Size = UDim2.new(1, 0, 0, 28),
				BackgroundColor3 = (isMulti and selectedSet[optName]) and theme.Accent or theme.ElementBgHover,
				Text = tostring(optName),
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextColor3 = theme.TextColor,
				AutoButtonColor = false,
				Parent = list,
			})
			optButtons[optName] = optBtn
			optBtn.MouseEnter:Connect(function()
				if not (isMulti and selectedSet[optName]) then
					Tween(optBtn, {BackgroundColor3 = theme.Accent}, 0.1, Enum.EasingStyle.Quad)
				end
			end)
			optBtn.MouseLeave:Connect(function()
				if not (isMulti and selectedSet[optName]) then
					Tween(optBtn, {BackgroundColor3 = theme.ElementBgHover}, 0.1, Enum.EasingStyle.Quad)
				end
			end)
			optBtn.MouseButton1Click:Connect(function()
				if isMulti then
					toggleMulti(optName, true)
				else
					setSelected(optName, true)
					open = false
					Tween(holder, {Size = UDim2.new(1, 0, 0, 34)}, 0.18, Enum.EasingStyle.Quad)
				end
			end)
		end
		list.Size = UDim2.new(1, 0, 0, #options * 28)
		if open then
			Tween(holder, {Size = UDim2.new(1, 0, 0, 34 + #options * 28)}, 0.15, Enum.EasingStyle.Quad)
		end
		if not isMulti and (not selected or not table.find(options, selected)) then
			setSelected(options[1], false)
		end
		refreshLabel()
	end

	rebuildOptions(options)

	header.MouseButton1Click:Connect(function()
		open = not open
		Tween(holder, {Size = open and UDim2.new(1, 0, 0, 34 + #options * 28) or UDim2.new(1, 0, 0, 34)}, 0.18, Enum.EasingStyle.Quad)
	end)

	if isMulti then
		refreshLabel()
		local list_ = {}
		for _, optName in ipairs(options) do
			if selectedSet[optName] then table.insert(list_, optName) end
		end
		NovaUI.Flags[opts.Name or "Dropdown"] = list_
	else
		setSelected(selected, false)
	end

	RegisterSearchable(holder, opts.Name or "Dropdown")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)

	if isMulti then
		local function getList()
			local list_ = {}
			for _, optName in ipairs(options) do
				if selectedSet[optName] then table.insert(list_, optName) end
			end
			return list_
		end
		NovaUI.Elements[opts.Name or "Dropdown"] = {
			Get = getList,
			Set = function(v)
				selectedSet = {}
				for _, optName in ipairs(v or {}) do selectedSet[optName] = true end
				for optName, btn in pairs(optButtons) do
					btn.BackgroundColor3 = selectedSet[optName] and theme.Accent or theme.ElementBgHover
				end
				refreshLabel()
			end,
		}
		return {Get = getList, Set = function(v) NovaUI.Elements[opts.Name or "Dropdown"].Set(v) end, RefreshOptions = rebuildOptions}
	else
		NovaUI.Elements[opts.Name or "Dropdown"] = {Get = function() return selected end, Set = function(v) setSelected(v, false) end}
		return {Get = function() return selected end, Set = function(v) setSelected(v, true) end, RefreshOptions = rebuildOptions}
	end
end

function NovaUI:CreateColorPicker(opts)
	opts = opts or {}
	local theme = self._theme
	local color = opts.Default or Color3.fromRGB(255, 255, 255)
	local h, s, v = Color3.toHSV(color)
	local open = false

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		ClipsDescendants = true,
		Parent = self._container,
	}, {Corner(6)})

	local colorLabelX = 10
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 10, 0, 9)
			icon.Parent = holder
			colorLabelX = 32
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, colorLabelX, 0, 0),
		Size = UDim2.new(1, -colorLabelX - 100, 0, 34),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Color",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local hexLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 0),
		Size = UDim2.new(0, 60, 0, 34),
		Font = Enum.Font.Code,
		Text = "#" .. color:ToHex():upper(),
		TextColor3 = theme.SubTextColor,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})

	local swatch = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0, 17),
		Size = UDim2.new(0, 28, 0, 18),
		BackgroundColor3 = color,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	}, {Corner(4), Stroke(theme.Stroke)})

	local panel = Create("Frame", {
		Position = UDim2.new(0, 0, 0, 34),
		Size = UDim2.new(1, 0, 0, 116),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = holder,
	}, {
		Padding(10, 10, 8, 8),
	})

	local svBox = Create("Frame", {
		Size = UDim2.new(1, -30, 0, 100),
		BackgroundColor3 = Color3.fromHSV(h, 1, 1),
		Parent = panel,
	}, {
		Corner(4),
		Create("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local blackOverlay = Create("Frame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		Parent = svBox,
	}, {
		Corner(4),
		Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}),
	})

	local svCursor = Create("Frame", {
		Size = UDim2.new(0, 8, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(s, 0, 1 - v, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = svBox,
	}, {Corner(4), Stroke(Color3.fromRGB(0, 0, 0), 1)})

	local hueSlider = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 18, 0, 100),
		Parent = panel,
	}, {
		Corner(4),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
			}),
		}),
	})

	local hueCursor = Create("Frame", {
		Size = UDim2.new(1, 4, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, h, 0),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = hueSlider,
	}, {Corner(2), Stroke(Color3.fromRGB(0, 0, 0), 1)})

	local function updateVisuals()
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		hexLabel.Text = "#" .. color:ToHex():upper()
		svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		NovaUI.Flags[opts.Name or "Color"] = color
	end

	local draggingSV, draggingHue = false, false

	svBox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSV = true
			local relX = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
			local relY = math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
			s, v = relX, 1 - relY
			svCursor.Position = UDim2.new(relX, 0, relY, 0)
			updateVisuals()
		end
	end)
	hueSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingHue = true
			local relY = math.clamp((input.Position.Y - hueSlider.AbsolutePosition.Y) / hueSlider.AbsoluteSize.Y, 0, 1)
			h = relY
			hueCursor.Position = UDim2.new(0.5, 0, relY, 0)
			updateVisuals()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if (draggingSV or draggingHue) and opts.Callback then safeSpawn(opts.Callback, color) end
			draggingSV = false
			draggingHue = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not svBox.Parent then draggingSV = false draggingHue = false return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if draggingSV then
			local relX = math.clamp((input.Position.X - svBox.AbsolutePosition.X) / svBox.AbsoluteSize.X, 0, 1)
			local relY = math.clamp((input.Position.Y - svBox.AbsolutePosition.Y) / svBox.AbsoluteSize.Y, 0, 1)
			s, v = relX, 1 - relY
			svCursor.Position = UDim2.new(relX, 0, relY, 0)
			updateVisuals()
		elseif draggingHue then
			local relY = math.clamp((input.Position.Y - hueSlider.AbsolutePosition.Y) / hueSlider.AbsoluteSize.Y, 0, 1)
			h = relY
			hueCursor.Position = UDim2.new(0.5, 0, relY, 0)
			updateVisuals()
		end
	end)

	swatch.MouseButton1Click:Connect(function()
		open = not open
		panel.Visible = open
		Tween(holder, {Size = open and UDim2.new(1, 0, 0, 34 + 116) or UDim2.new(1, 0, 0, 34)}, 0.2, Enum.EasingStyle.Quad)
	end)

	updateVisuals()

	local function setColor(newColor, fire)
		color = newColor
		h, s, v = Color3.toHSV(color)
		svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
		hueCursor.Position = UDim2.new(0.5, 0, h, 0)
		updateVisuals()
		if fire and opts.Callback then safeSpawn(opts.Callback, color) end
	end

	RegisterSearchable(holder, opts.Name or "Color")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)
	NovaUI.Elements[opts.Name or "Color"] = {Get = function() return color end, Set = function(c) setColor(c, false) end}
	return {Get = function() return color end, Set = function(c) setColor(c, true) end}
end

function NovaUI:CreateKeybind(opts)
	opts = opts or {}
	local theme = self._theme
	local bind = opts.Default or Enum.KeyCode.Unknown
	local listening = false

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	local keybindLabelX = 10
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 10, 0.5, -8)
			icon.Parent = holder
			keybindLabelX = 32
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, keybindLabelX, 0, 0),
		Size = UDim2.new(1, -keybindLabelX - 90, 1, 0),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Keybind",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local keyBtn = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, 80, 0, 24),
		BackgroundColor3 = theme.Sidebar,
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = theme.SubTextColor,
		Text = bind.Name,
		AutoButtonColor = false,
		Parent = holder,
	}, {Corner(4)})

	local function setBind(newBind)
		bind = newBind
		keyBtn.Text = bind.Name
		NovaUI.Flags[opts.Name or "Keybind"] = bind
	end

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not holder.Parent then return end
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			setBind(input.KeyCode)
			listening = false
		elseif not processed and input.KeyCode == bind then
			if opts.Callback then safeSpawn(opts.Callback) end
		end
	end)

	RegisterSearchable(holder, opts.Name or "Keybind")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)
	NovaUI.Elements[opts.Name or "Keybind"] = {Get = function() return bind end, Set = setBind}
	return {Get = function() return bind end, Set = setBind}
end

function NovaUI:CreateTextbox(opts)
	opts = opts or {}
	local theme = self._theme

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	local textboxLabelX = 10
	if opts.Icon then
		local icon = CreateIcon(opts.Icon, 16, theme.TextColor)
		if icon then
			icon.Position = UDim2.new(0, 10, 0.5, -8)
			icon.Parent = holder
			textboxLabelX = 32
		end
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, textboxLabelX, 0, 0),
		Size = UDim2.new(0, 100, 1, 0),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local box = Create("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 200, 0, 24),
		BackgroundColor3 = theme.Sidebar,
		PlaceholderText = opts.PlaceholderText or "",
		Text = opts.Default or "",
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = theme.TextColor,
		ClearTextOnFocus = false,
		Parent = holder,
	}, {Corner(4), Padding(6, 6, 0, 0)})

	box.FocusLost:Connect(function(enterPressed)
		NovaUI.Flags[opts.Name or "Textbox"] = box.Text
		if opts.Callback then safeSpawn(opts.Callback, box.Text, enterPressed) end
	end)

	RegisterSearchable(holder, opts.Name or "Textbox")
	AttachTooltip(self._screenGui, theme, holder, opts.Tooltip)
	NovaUI.Elements[opts.Name or "Textbox"] = {
		Get = function() return box.Text end,
		Set = function(v) box.Text = v end,
	}
	return {Get = function() return box.Text end, Set = function(v) box.Text = v end}
end

function NovaUI:CreateParagraph(opts)
	opts = opts or {}
	local theme = self._theme

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = self._container,
	}, {
		Create("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	if opts.Title then
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 16),
			Font = Enum.Font.GothamBold,
			Text = opts.Title,
			TextColor3 = theme.TextColor,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = holder,
		})
	end

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.Gotham,
		Text = opts.Content or opts.Text or "",
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	if opts.Title then
		RegisterSearchable(holder, opts.Title)
	end

	return holder
end

function NovaUI:CreateDivider()
	local theme = self._theme
	return Create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = theme.Stroke,
		BorderSizePixel = 0,
		Parent = self._container,
	})
end

function NovaUI:CreateLabel(opts)
	opts = opts or {}
	local theme = self._theme
	return Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Enum.Font.Gotham,
		Text = opts.Text or "",
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = self._container,
	})
end

return NovaUI
