--[[
	NovaUI - A custom Roblox interface library
	Inspired by the layout/feature set of libraries like Rayfield and Obsidian UI.
	Single ModuleScript, no external dependencies.

	USAGE (from a LocalScript):
		local NovaUI = loadstring(game:HttpGet("PATH_TO_THIS_FILE"))()
		-- or if you're using it inside Roblox Studio as a ModuleScript:
		-- local NovaUI = require(path.to.NovaUI)

		local Window = NovaUI:CreateWindow({
			Name = "My Hub",
			Theme = "Dark", -- "Dark" or "Light"
		})

		local Tab = Window:CreateTab("Main")
		local Section = Tab:CreateSection("General")

		Section:CreateButton({
			Name = "Click Me",
			Callback = function()
				NovaUI:Notify({Title = "Hello", Content = "Button pressed!", Duration = 3})
			end
		})

		Section:CreateToggle({
			Name = "Enable Thing",
			Default = false,
			Callback = function(value) print("Toggle:", value) end
		})

		Section:CreateSlider({
			Name = "Speed", Min = 0, Max = 100, Default = 16,
			Callback = function(value) print("Slider:", value) end
		})

		Section:CreateDropdown({
			Name = "Mode", Options = {"A", "B", "C"}, Default = "A",
			Callback = function(value) print("Dropdown:", value) end
		})

		Section:CreateColorPicker({
			Name = "Color", Default = Color3.fromRGB(255,0,0),
			Callback = function(color) print(color) end
		})

		Section:CreateKeybind({
			Name = "Toggle UI", Default = Enum.KeyCode.RightShift,
			Callback = function() print("keybind fired") end
		})

		Section:CreateTextbox({
			Name = "Enter text", PlaceholderText = "...",
			Callback = function(text) print(text) end
		})

		Section:CreateLabel({Text = "This is a label"})
]]

local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local NovaUI = {}
NovaUI.__index = NovaUI
NovaUI.Flags = {} -- stores current value of every element by Flag/Name, like Rayfield's Flags table

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

local function MakeDraggable(topbar, frame)
	local dragging, dragInput, dragStart, startPos

	topbar.InputBegan:Connect(function(input)
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

	topbar.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
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

	local theme = self._theme or Themes.Dark
	local holder = EnsureNotifHolder(self._screenGui, theme)

	local notif = Create("Frame", {
		BackgroundColor3 = theme.SectionBg,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
	}, {
		Corner(8),
		Stroke(theme.Stroke),
		Padding(10, 10, 8, 8),
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
	})
	notif.Parent = holder
	notif.BackgroundTransparency = 1

	Tween(notif, {BackgroundTransparency = 0}, 0.25)
	task.delay(duration, function()
		if notif and notif.Parent then
			Tween(notif, {BackgroundTransparency = 1}, 0.25)
			task.wait(0.25)
			notif:Destroy()
		end
	end)
end

--======================================================
-- WINDOW
--======================================================
function NovaUI:CreateWindow(opts)
	opts = opts or {}
	local themeName = opts.Theme or "Dark"
	local theme = Themes[themeName] or Themes.Dark

	-- Remove any previous instance of this UI
	local existing = CoreGui:FindFirstChild("NovaUI_ScreenGui")
	if existing then existing:Destroy() end

	local screenGui = Create("ScreenGui", {
		Name = "NovaUI_ScreenGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	local ok = pcall(function() screenGui.Parent = CoreGui end)
	if not ok then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

	local main = Create("Frame", {
		Name = "Main",
		Size = UDim2.new(0, 560, 0, 380),
		Position = UDim2.new(0.5, -280, 0.5, -190),
		BackgroundColor3 = theme.Background,
		Parent = screenGui,
	}, {
		Corner(10),
		Stroke(theme.Stroke),
	})

	local topbar = Create("Frame", {
		Name = "Topbar",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = theme.Topbar,
		Parent = main,
	}, {
		Corner(10),
		Create("TextLabel", {
			BackgroundTransparency = 1,
			Position = UDim2.new(0, 14, 0, 0),
			Size = UDim2.new(1, -80, 1, 0),
			Font = Enum.Font.GothamBold,
			Text = opts.Name or "NovaUI",
			TextColor3 = theme.TextColor,
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	-- close button
	local closeBtn = Create("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -36, 0, 6),
		BackgroundColor3 = theme.ElementBg,
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = theme.TextColor,
		Parent = topbar,
	}, {Corner(6)})
	closeBtn.MouseButton1Click:Connect(function()
		main.Visible = false
	end)

	-- minimize button
	local minimized = false
	local minBtn = Create("TextButton", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -70, 0, 6),
		BackgroundColor3 = theme.ElementBg,
		Text = "-",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = theme.TextColor,
		Parent = topbar,
	}, {Corner(6)})

	local body = Create("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		BackgroundTransparency = 1,
		Parent = main,
	})

	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		body.Visible = not minimized
		Tween(main, {Size = minimized and UDim2.new(0, 560, 0, 40) or UDim2.new(0, 560, 0, 380)}, 0.2)
	end)

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

	local Window = setmetatable({
		_theme = theme,
		_screenGui = screenGui,
		_main = main,
		_sidebar = sidebar,
		_pages = pages,
		_tabs = {},
	}, NovaUI)

	self._theme = theme
	self._screenGui = screenGui

	-- global UI toggle key (RightControl)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.RightControl then
			main.Visible = not main.Visible
		end
	end)

	return Window
end

--======================================================
-- TAB
--======================================================
function NovaUI:CreateTab(name)
	local theme = self._theme

	local tabBtn = Create("TextButton", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundColor3 = theme.ElementBg,
		Text = "  " .. name,
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = theme.SubTextColor,
		AutoButtonColor = false,
		Parent = self._sidebar,
	}, {Corner(6)})

	local page = Create("ScrollingFrame", {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = theme.Accent,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticCanvasSize.Y,
		Visible = false,
		Parent = self._pages,
	}, {
		Padding(14, 14, 14, 14),
		Create("UIListLayout", {Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	local Tab = setmetatable({
		_theme = theme,
		_page = page,
		_screenGui = self._screenGui,
	}, NovaUI)
	Tab._theme = theme

	local function selectTab()
		for _, child in ipairs(self._pages:GetChildren()) do
			if child:IsA("ScrollingFrame") then child.Visible = false end
		end
		for _, child in ipairs(self._sidebar:GetChildren()) do
			if child:IsA("TextButton") then
				child.BackgroundColor3 = theme.ElementBg
				child.TextColor3 = theme.SubTextColor
			end
		end
		page.Visible = true
		tabBtn.BackgroundColor3 = theme.Accent
		tabBtn.TextColor3 = Color3.fromRGB(255,255,255)
	end

	tabBtn.MouseButton1Click:Connect(selectTab)

	-- select the first tab automatically
	if #self._tabs == 0 then
		selectTab()
	end
	table.insert(self._tabs, Tab)

	return Tab
end

--======================================================
-- SECTION
--======================================================
function NovaUI:CreateSection(name)
	local theme = self._theme

	local section = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = theme.SectionBg,
		Parent = self._page,
	}, {
		Corner(8),
		Stroke(theme.Stroke),
		Padding(12, 12, 12, 12),
		Create("UIListLayout", {Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder}),
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		Font = Enum.Font.GothamBold,
		Text = name,
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
		Parent = section,
	})

	return setmetatable({_theme = theme, _container = section}, NovaUI)
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
		Text = opts.Name or "Button",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = theme.TextColor,
		AutoButtonColor = false,
		Parent = self._container,
	}, {Corner(6)})

	btn.MouseEnter:Connect(function() Tween(btn, {BackgroundColor3 = theme.ElementBgHover}, 0.15) end)
	btn.MouseLeave:Connect(function() Tween(btn, {BackgroundColor3 = theme.ElementBg}, 0.15) end)
	btn.MouseButton1Click:Connect(function()
		if opts.Callback then
			task.spawn(opts.Callback)
		end
	end)
	return btn
end

function NovaUI:CreateToggle(opts)
	opts = opts or {}
	local theme = self._theme
	local state = opts.Default or false

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Toggle",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local switchBg = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 38, 0, 20),
		BackgroundColor3 = state and theme.Accent or theme.Sidebar,
		Parent = holder,
	}, {Corner(10)})

	local knob = Create("Frame", {
		Size = UDim2.new(0, 16, 0, 16),
		Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8),
		BackgroundColor3 = Color3.fromRGB(255,255,255),
		Parent = switchBg,
	}, {Corner(8)})

	local function setState(new)
		state = new
		NovaUI.Flags[opts.Name or "Toggle"] = state
		Tween(switchBg, {BackgroundColor3 = state and theme.Accent or theme.Sidebar}, 0.15)
		Tween(knob, {Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.15)
		if opts.Callback then task.spawn(opts.Callback, state) end
	end

	holder.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setState(not state)
		end
	end)

	if opts.Default then setState(opts.Default) end

	return {Set = setState, Get = function() return state end}
end

function NovaUI:CreateSlider(opts)
	opts = opts or {}
	local theme = self._theme
	local min, max = opts.Min or 0, opts.Max or 100
	local value = math.clamp(opts.Default or min, min, max)

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6), Padding(10, 10, 6, 6)})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Slider",
		TextColor3 = theme.TextColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local valueLabel = Create("TextLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.new(0, 50, 0, 16),
		Font = Enum.Font.Gotham,
		Text = tostring(value),
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = holder,
	})

	local track = Create("Frame", {
		Position = UDim2.new(0, 0, 0, 26),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = theme.Sidebar,
		Parent = holder,
	}, {Corner(3)})

	local fill = Create("Frame", {
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = theme.Accent,
		Parent = track,
	}, {Corner(3)})

	local dragging = false
	local function updateFromX(x)
		local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		value = math.floor(min + (max - min) * rel + 0.5)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		valueLabel.Text = tostring(value)
		NovaUI.Flags[opts.Name or "Slider"] = value
		if opts.Callback then task.spawn(opts.Callback, value) end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			updateFromX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			updateFromX(input.Position.X)
		end
	end)

	return {Set = updateFromX, Get = function() return value end}
end

function NovaUI:CreateDropdown(opts)
	opts = opts or {}
	local theme = self._theme
	local options = opts.Options or {}
	local selected = opts.Default or options[1]
	local open = false

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
		Parent = holder,
	})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -30, 0, 34),
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
		Size = UDim2.new(0, 100, 0, 34),
		Font = Enum.Font.Gotham,
		Text = tostring(selected or ""),
		TextColor3 = theme.SubTextColor,
		TextSize = 13,
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

	for _, optName in ipairs(options) do
		local optBtn = Create("TextButton", {
			Size = UDim2.new(1, 0, 0, 28),
			BackgroundColor3 = theme.ElementBgHover,
			Text = tostring(optName),
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme.TextColor,
			Parent = list,
		})
		optBtn.MouseButton1Click:Connect(function()
			selected = optName
			valueLabel.Text = tostring(optName)
			NovaUI.Flags[opts.Name or "Dropdown"] = optName
			if opts.Callback then task.spawn(opts.Callback, optName) end
			open = false
			Tween(holder, {Size = UDim2.new(1, 0, 0, 34)}, 0.15)
		end)
	end

	header.MouseButton1Click:Connect(function()
		open = not open
		Tween(holder, {Size = open and UDim2.new(1, 0, 0, 34 + #options * 28) or UDim2.new(1, 0, 0, 34)}, 0.15)
	end)

	return {Get = function() return selected end}
end

function NovaUI:CreateColorPicker(opts)
	opts = opts or {}
	local theme = self._theme
	local color = opts.Default or Color3.fromRGB(255, 255, 255)

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -60, 1, 0),
		Font = Enum.Font.Gotham,
		Text = opts.Name or "Color",
		TextColor3 = theme.TextColor,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = holder,
	})

	local swatch = Create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 28, 0, 18),
		BackgroundColor3 = color,
		Text = "",
		Parent = holder,
	}, {Corner(4), Stroke(theme.Stroke)})

	-- simple RGB cycle-on-click color picker (lightweight, no external deps)
	swatch.MouseButton1Click:Connect(function()
		color = Color3.fromHSV(math.random(), 0.65, 0.95)
		swatch.BackgroundColor3 = color
		NovaUI.Flags[opts.Name or "Color"] = color
		if opts.Callback then task.spawn(opts.Callback, color) end
	end)

	return {Get = function() return color end}
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

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -100, 1, 0),
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
		Parent = holder,
	}, {Corner(4)})

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "..."
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			bind = input.KeyCode
			keyBtn.Text = bind.Name
			listening = false
			NovaUI.Flags[opts.Name or "Keybind"] = bind
		elseif not processed and input.KeyCode == bind then
			if opts.Callback then task.spawn(opts.Callback) end
		end
	end)

	return {Get = function() return bind end}
end

function NovaUI:CreateTextbox(opts)
	opts = opts or {}
	local theme = self._theme

	local holder = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = theme.ElementBg,
		Parent = self._container,
	}, {Corner(6)})

	Create("TextLabel", {
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 10, 0, 0),
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
		if opts.Callback then task.spawn(opts.Callback, box.Text, enterPressed) end
	end)

	return {Get = function() return box.Text end, Set = function(v) box.Text = v end}
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
