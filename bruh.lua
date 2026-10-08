-- Roblox GUI Library
-- 75% base scale, fully mobile/touch compatible (100%)
-- Usage:
--   local Library = loadstring(game:HttpGet("...gui_library.lua"))()
--   local win = Library:CreateWindow({ Name = "My Hub", Size = UDim2.new(0, 520, 0, 380) })
--   local tab = win:CreateTab("Main")
--   tab:CreateButton({ Name = "Click me", Callback = function() print("hi") end })

local Library = {}
Library.__index = Library

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local BASE_SCALE = 0.75 -- 75% scale
local IS_TOUCH = UserInputService.TouchEnabled
local IS_MOBILE = IS_TOUCH and not UserInputService.KeyboardEnabled
local MIN_TOUCH = 34 -- minimum touch target (px) for mobile users

-- Theme
local Theme = {
	Background = Color3.fromRGB(22, 22, 28),
	Window = Color3.fromRGB(28, 28, 36),
	Header = Color3.fromRGB(34, 34, 44),
	Tab = Color3.fromRGB(40, 40, 52),
	TabActive = Color3.fromRGB(90, 120, 255),
	Element = Color3.fromRGB(46, 46, 58),
	Accent = Color3.fromRGB(90, 120, 255),
	AccentDark = Color3.fromRGB(60, 85, 200),
	Text = Color3.fromRGB(240, 240, 245),
	SubText = Color3.fromRGB(160, 160, 175),
	Stroke = Color3.fromRGB(60, 60, 75),
	Success = Color3.fromRGB(80, 200, 120),
	Danger = Color3.fromRGB(235, 90, 90),
}

local TWEEN_IN = TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

-- Services / helpers ---------------------------------------------------------

local function create(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function round(inst, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 8), Parent = inst })
end

local function stroke(inst, color, thickness, transparency)
	return create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function padding(inst, top, right, bottom, left)
	return create("UIPadding", {
		PaddingTop = UDim.new(0, top or 6),
		PaddingRight = UDim.new(0, right or 6),
		PaddingBottom = UDim.new(0, bottom or 6),
		PaddingLeft = UDim.new(0, left or 6),
		Parent = inst,
	})
end

local function label(text, size, color, parent)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, size or 16),
		Font = Enum.Font.GothamMedium,
		Text = text,
		TextColor3 = color or Theme.Text,
		TextSize = size or 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	})
end

local function buttonFont()
	return Enum.Font.GothamMedium
end

-- Make a frame draggable with mouse OR touch (mobile 100% support)
local function makeDraggable(handle, target, boundsCheck)
	local dragging, dragInput, dragStart, startPos

	local function begin(input)
		dragging = true
		dragStart = input.Position
		startPos = target.Position
		target.ZIndex = 100
	end

	local function move(input)
		if not dragging then
			return
		end
		local delta = input.Position - dragStart
		local newPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		if boundsCheck then
			local abs = target.AbsolutePosition
			local size = target.AbsoluteSize
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local nx = math.clamp(
				abs.X + (newPos.X.Offset - startPos.X.Offset),
				0, math.max(0, vp.X - size.X)
			)
			local ny = math.clamp(
				abs.Y + (newPos.Y.Offset - startPos.Y.Offset),
				0, math.max(0, vp.Y - size.Y)
			)
			newPos = UDim2.new(0, nx, 0, ny)
		end
		target.Position = newPos
	end

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			begin(input)
		end
	end)
	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			move(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			target.ZIndex = 1
		end
	end)
end

-- Core GUI (ScreenGui + 75% UIScale) ---------------------------------------

function Library.new(opts)
	opts = opts or {}
	local self = setmetatable({}, Library)

	self.Scale = opts.Scale or BASE_SCALE
	self.Name = opts.Name or "Library"
	self.Windows = {}
	self.Minimized = false

	-- remove old gui if re-executed
	local old = PlayerGui:FindFirstChild("GL_" .. self.Name)
	if old then
		old:Destroy()
	end

	self.Gui = create("ScreenGui", {
		Name = "GL_" .. self.Name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999999999,
		Parent = PlayerGui,
	})

	-- 75% scale applied to everything inside
	self.ScaleObject = create("UIScale", { Scale = self.Scale, Parent = self.Gui })

	self.Container = create("Frame", {
		Name = "Container",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 1, 0),
		Parent = self.Gui,
	})

	-- Mobile: floating show/hide button (no keyboard hotkey on phones)
	if IS_MOBILE then
		self.ToggleButton = create("TextButton", {
			Name = "MobileToggle",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 6),
			Size = UDim2.new(0, 64, 0, 32),
			BackgroundColor3 = Theme.Accent,
			Font = buttonFont(),
			Text = "UI",
			TextColor3 = Theme.Text,
			TextSize = 14,
			AutoButtonColor = true,
			Parent = self.Gui,
		})
		round(self.ToggleButton, 8)
		stroke(self.ToggleButton, Theme.Stroke, 1, 0.4)
		self.ToggleButton.Activated:Connect(function()
			self:SetVisible(not self.Visible)
		end)
	end

	self.Visible = true

	-- keep the 75% scale and window layout sane on every screen size
	local function onViewport()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		-- very narrow screens: shrink a little more so 100% of mobile fits
		if vp.X < 600 then
			self.ScaleObject.Scale = self.Scale * 0.9
		else
			self.ScaleObject.Scale = self.Scale
		end
		for _, win in ipairs(self.Windows) do
			win:ClampToScreen()
		end
	end
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(onViewport)
	end
	onViewport()

	-- mobile safe area (notch / rounded corners)
	local ok = pcall(function()
		create("UISafeAreaCompatibility", { Parent = self.Gui })
	end)
	if not ok then
		-- older engines: fall back to manual inset via padding on container
		local inset = GuiService:GetGuiInset()
		padding(self.Container, inset.Y, 0, 0, 0)
	end

	return self
end

function Library:SetVisible(visible)
	self.Visible = visible
	for _, win in ipairs(self.Windows) do
		win.Frame.Visible = visible
	end
end

function Library:Toggle()
	self:SetVisible(not self.Visible)
end

-- Window ---------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Library:CreateWindow(opts)
	opts = opts or {}
	local win = setmetatable({}, Window)
	win.Library = self
	win.Tabs = {}
	win.ActiveTab = nil

	local size = opts.Size or UDim2.new(0, 520, 0, 380)
	-- mobile: default to near-fullscreen so 100% of phone users get usable UI
	if IS_MOBILE then
		size = opts.MobileSize or UDim2.new(0.94, 0, 0.8, 0)
	end

	local frame = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = size,
		BackgroundColor3 = Theme.Window,
		ClipsDescendants = true,
		Parent = self.Container,
	})
	round(frame, 12)
	local frameStroke = stroke(frame, Theme.Stroke, 1, 0.25)
	win.Frame = frame

	-- header (drag handle for mouse + touch)
	local header = create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		Parent = frame,
	})
	create("Frame", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = Theme.Stroke,
		BorderSizePixel = 0,
		Parent = header,
	})

	local title = label(opts.Name or "Window", 16, Theme.Text, header)
	title.Position = UDim2.new(0, 12, 0, 0)
	title.Size = UDim2.new(1, -110, 1, 0)

	local closeBtn = create("TextButton", {
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.new(0, IS_TOUCH and MIN_TOUCH or 26, 0, IS_TOUCH and MIN_TOUCH or 26),
		BackgroundColor3 = Theme.Danger,
		Font = buttonFont(),
		Text = "X",
		TextColor3 = Theme.Text,
		TextSize = 14,
		AutoButtonColor = true,
		Parent = header,
	})
	round(closeBtn, 8)

	-- minimize button (mobile friendly)
	local minBtn = create("TextButton", {
		Name = "Minimize",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(IS_TOUCH and (MIN_TOUCH + 16) or 40), 0.5, 0),
		Size = UDim2.new(0, IS_TOUCH and MIN_TOUCH or 26, 0, IS_TOUCH and MIN_TOUCH or 26),
		BackgroundColor3 = Theme.Element,
		Font = buttonFont(),
		Text = "-",
		TextColor3 = Theme.Text,
		TextSize = 16,
		AutoButtonColor = true,
		Parent = header,
	})
	round(minBtn, 8)

	makeDraggable(header, frame, true)

	-- body: sidebar + page
	local body = create("Frame", {
		Name = "Body",
		Position = UDim2.new(0, 0, 0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
		Parent = frame,
	})

	local sidebar = create("ScrollingFrame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 130, 1, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = body,
	})
	padding(sidebar, 6, 4, 6, 6)
	create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = sidebar,
	})

	local pages = create("Frame", {
		Name = "Pages",
		Position = UDim2.new(0, 130, 0, 0),
		Size = UDim2.new(1, -130, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})

	-- mobile: stack sidebar on top instead of side-by-side when narrow
	if IS_MOBILE then
		sidebar.Size = UDim2.new(1, -8, 0, 44)
		sidebar.Position = UDim2.new(0, 4, 0, 4)
		sidebar.CanvasSize = UDim2.new(0, 0, 0, 0)
		sidebar.AutomaticCanvasSize = Enum.AutomaticSize.X
		sidebar.ScrollingDirection = Enum.ScrollingDirection.X
		create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = sidebar,
		})
		pages.Position = UDim2.new(0, 4, 0, 52)
		pages.Size = UDim2.new(1, -8, 1, -56)
	end

	-- elements column, shared by every page
	function win:CreateTab(tabName)
		local tab = {
			Name = tabName,
			Elements = {},
		}

		local tabBtn = create("TextButton", {
			Name = tabName,
			Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 30),
			BackgroundColor3 = Theme.Tab,
			Font = buttonFont(),
			Text = "  " .. tabName,
			TextColor3 = Theme.SubText,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			AutoButtonColor = true,
			LayoutOrder = #self.Tabs + 1,
			Parent = sidebar,
		})
		round(tabBtn, 8)
		if IS_MOBILE then
			tabBtn.AutomaticSize = Enum.AutomaticSize.X
			tabBtn.Size = UDim2.new(0, 0, 1, 0)
			padding(tabBtn, 0, 12, 0, 12)
		end

		local page = create("ScrollingFrame", {
			Name = tabName .. "Page",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 1, 0),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			Visible = false,
			Parent = pages,
		})
		padding(page, 8, 8, 8, 8)
		local layout = create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = page,
		})
		local pagePad = padding(page, 8, 8, 8, 8)

		-- keep a little room at the bottom for the mobile keyboard
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			page.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
		end)

		local function activate()
			if self.ActiveTab then
				self.ActiveTab.Page.Visible = false
				self.ActiveTab.Button.BackgroundColor3 = Theme.Tab
				self.ActiveTab.Button.TextColor3 = Theme.SubText
			end
			page.Visible = true
			tabBtn.BackgroundColor3 = Theme.TabActive
			tabBtn.TextColor3 = Theme.Text
			self.ActiveTab = tab
		end

		tabBtn.Activated:Connect(activate)
		tab.Button = tabBtn
		tab.Page = page

		table.insert(self.Tabs, tab)
		if not self.ActiveTab then
			activate()
		end

		-- ---- element factories -------------------------------------------

		local function section(name)
			local f = create("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 24),
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			local t = label(name, 15, Theme.Accent, f)
			t.Size = UDim2.new(1, 0, 1, 0)
			table.insert(tab.Elements, f)
			return f
		end
		tab.CreateSection = section

		local function baseButton(name, color)
			local btn = create("TextButton", {
				Name = name,
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 32),
				BackgroundColor3 = color or Theme.Element,
				Font = buttonFont(),
				Text = name,
				TextColor3 = Theme.Text,
				TextSize = 14,
				AutoButtonColor = true,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(btn, 8)
			stroke(btn, Theme.Stroke, 1, 0.5)
			table.insert(tab.Elements, btn)
			return btn
		end

		function tab:CreateButton(o)
			o = o or {}
			local btn = baseButton(o.Name or "Button")
			btn.Activated:Connect(function()
				if o.Callback then
					task.spawn(o.Callback)
				end
			end)
			return btn
		end

		function tab:CreateToggle(o)
			o = o or {}
			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 34),
				BackgroundColor3 = Theme.Element,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(row, 8)
			stroke(row, Theme.Stroke, 1, 0.5)
			table.insert(tab.Elements, row)

			local text = label(o.Name or "Toggle", 14, Theme.Text, row)
			text.Position = UDim2.new(0, 10, 0, 0)
			text.Size = UDim2.new(1, -70, 1, 0)

			local pill = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0, 44, 0, 22),
				BackgroundColor3 = Theme.Stroke,
				Parent = row,
			})
			round(pill, 11)
			local knob = create("Frame", {
				Position = UDim2.new(0, 3, 0, 3),
				Size = UDim2.new(0, 16, 0, 16),
				BackgroundColor3 = Theme.Text,
				Parent = pill,
			})
			round(knob, 8)

			local state = o.Default == true
			local function render()
				local targetPos = state and UDim2.new(1, -19, 0, 3) or UDim2.new(0, 3, 0, 3)
				local targetColor = state and Theme.Accent or Theme.Stroke
				TweenService:Create(knob, TWEEN_IN, { Position = targetPos }):Play()
				TweenService:Create(pill, TWEEN_IN, { BackgroundColor3 = targetColor }):Play()
			end

			row.Activated:Connect(function()
				state = not state
				render()
				if o.Callback then
					task.spawn(o.Callback, state)
				end
			end)
			render()
			return {
				Set = function(_, v)
					state = v
					render()
				end,
				Get = function()
					return state
				end,
			}
		end

		function tab:CreateSlider(o)
			o = o or {}
			local minV = o.Min or 0
			local maxV = o.Max or 100
			local step = o.Step or 1
			local value = o.Default or minV

			local row = create("Frame", {
				Size = UDim2.new(1, 0, 0, IS_TOUCH and 48 or 44),
				BackgroundColor3 = Theme.Element,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(row, 8)
			stroke(row, Theme.Stroke, 1, 0.5)
			table.insert(tab.Elements, row)

			local text = label((o.Name or "Slider"), 14, Theme.Text, row)
			text.Position = UDim2.new(0, 10, 0, 4)
			text.Size = UDim2.new(1, -80, 0, 18)

			local valueLabel = label(tostring(value), 13, Theme.Accent, row)
			valueLabel.AnchorPoint = Vector2.new(1, 0)
			valueLabel.Position = UDim2.new(1, -10, 0, 4)
			valueLabel.Size = UDim2.new(0, 70, 0, 18)
			valueLabel.TextXAlignment = Enum.TextXAlignment.Right

			-- big touch-friendly track
			local track = create("Frame", {
				Name = "Track",
				Position = UDim2.new(0, 10, 0, IS_TOUCH and 28 or 26),
				Size = UDim2.new(1, -20, 0, 8),
				BackgroundColor3 = Theme.Stroke,
				Parent = row,
			})
			round(track, 4)

			local fill = create("Frame", {
				Name = "Fill",
				Size = UDim2.new(0.5, 0, 1, 0),
				BackgroundColor3 = Theme.Accent,
				Parent = track,
			})
			round(fill, 4)

			local knob = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, IS_TOUCH and 18 or 14, 0, IS_TOUCH and 18 or 14),
				BackgroundColor3 = Theme.Text,
				Parent = track,
			})
			round(knob, 9)

			-- invisible wide grab area so thumbs can hit it easily
			local grab = create("TextButton", {
				Name = "Grab",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 20, 1, IS_TOUCH and 24 or 16),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Text = "",
				Parent = track,
			})

			local dragging = false
			local function render()
				local pct = (value - minV) / math.max(1, (maxV - minV))
				fill.Size = UDim2.new(pct, 0, 1, 0)
				knob.Position = UDim2.new(pct, 0, 0.5, 0)
				valueLabel.Text = tostring(value)
			end
			local function apply(input)
				local rel = (input.Position.X - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X)
				rel = math.clamp(rel, 0, 1)
				local raw = minV + (maxV - minV) * rel
				local snapped = math.floor(raw / step + 0.5) * step
				snapped = math.clamp(snapped, minV, maxV)
				if snapped ~= value then
					value = snapped
					if o.Callback then
						task.spawn(o.Callback, value)
					end
				end
				render()
			end

			grab.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = true
					apply(input)
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch) then
					apply(input)
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch then
					dragging = false
				end
			end)

			render()

			return {
				Set = function(_, v)
					value = math.clamp(v, minV, maxV)
					render()
				end,
				Get = function()
					return value
				end,
			}
		end

		function tab:CreateDropdown(o)
			o = o or {}
			local options = o.Options or {}
			local selected = o.Default or (options[1] and tostring(options[1]))

			local holder = create("Frame", {
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 34),
				BackgroundTransparency = 1,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			table.insert(tab.Elements, holder)

			local main = create("TextButton", {
				Name = "Main",
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 34),
				BackgroundColor3 = Theme.Element,
				Font = buttonFont(),
				Text = "  " .. tostring(selected) .. "   v",
				TextColor3 = Theme.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = true,
				Parent = holder,
			})
			round(main, 8)
			stroke(main, Theme.Stroke, 1, 0.5)

			local list = create("ScrollingFrame", {
				Name = "List",
				Position = UDim2.new(0, 0, 0, (IS_TOUCH and MIN_TOUCH or 34) + 4),
				Size = UDim2.new(1, 0, 0, 0),
				BackgroundColor3 = Theme.Background,
				BorderSizePixel = 0,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Accent,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Visible = false,
				ZIndex = 20,
				Parent = holder,
			})
			round(list, 8)
			stroke(list, Theme.Stroke, 1, 0.3)
			local listLayout = create("UIListLayout", {
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
				Parent = list,
			})
			padding(list, 4, 4, 4, 4)

			local open = false
			local function setOpen(v)
				open = v
				list.Visible = v
				list.Size = v and UDim2.new(1, 0, 0, math.min(160, #options * ((IS_TOUCH and MIN_TOUCH or 30) + 4) + 10))
					or UDim2.new(1, 0, 0, 0)
				main.Text = "  " .. tostring(selected) .. (v and "   ^" or "   v")
				holder.Size = UDim2.new(1, 0, 0, (v and math.min(160, #options * ((IS_TOUCH and MIN_TOUCH or 30) + 4) + 10) + (IS_TOUCH and MIN_TOUCH or 34) + 4)
					or (IS_TOUCH and MIN_TOUCH or 34))
			end

			local function rebuild()
				for _, child in ipairs(list:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end
				for i, opt in ipairs(options) do
					local item = create("TextButton", {
						Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 30),
						BackgroundColor3 = Theme.Element,
						Font = buttonFont(),
						Text = "  " .. tostring(opt),
						TextColor3 = Theme.Text,
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutoButtonColor = true,
						LayoutOrder = i,
						ZIndex = 21,
						Parent = list,
					})
					round(item, 6)
					item.Activated:Connect(function()
						selected = tostring(opt)
						setOpen(false)
						if o.Callback then
							task.spawn(o.Callback, selected)
						end
					end)
				end
			end

			main.Activated:Connect(function()
				setOpen(not open)
			end)
			rebuild()
			setOpen(false)

			return {
				Refresh = function(_, newOptions)
					options = newOptions
					rebuild()
					setOpen(open)
				end,
				Get = function()
					return selected
				end,
				Set = function(_, v)
					selected = v
					setOpen(false)
				end,
			}
		end

		function tab:CreateTextbox(o)
			o = o or {}
			local box = create("TextBox", {
				Name = o.Name or "Input",
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 34),
				BackgroundColor3 = Theme.Element,
				Font = buttonFont(),
				PlaceholderText = o.Placeholder or (o.Name or "Type here"),
				Text = o.Default or "",
				TextColor3 = Theme.Text,
				PlaceholderColor3 = Theme.SubText,
				TextSize = 14,
				ClearTextOnFocus = false,
				ClipsDescendants = true,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(box, 8)
			stroke(box, Theme.Stroke, 1, 0.5)
			padding(box, 0, 10, 0, 10)
			table.insert(tab.Elements, box)

			box.FocusLost:Connect(function(enter)
				if o.Callback then
					task.spawn(o.Callback, box.Text, enter)
				end
			end)
			return box
		end

		function tab:CreateLabel(o)
			o = typeof(o) == "string" and { Name = o } or o or {}
			local f = create("Frame", {
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 30),
				BackgroundColor3 = Theme.Element,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(f, 8)
			local t = label(o.Name or "", 14, o.Color or Theme.Text, f)
			t.Size = UDim2.new(1, -16, 1, 0)
			t.Position = UDim2.new(0, 8, 0, 0)
			t.TextWrapped = true
			t.TextTruncate = Enum.TextTruncate.AtEnd
			table.insert(tab.Elements, f)
			return t
		end

		function tab:CreateColorPicker(o)
			o = o or {}
			local current = o.Default or Color3.fromRGB(255, 255, 255)

			local row = create("TextButton", {
				Size = UDim2.new(1, 0, 0, IS_TOUCH and MIN_TOUCH or 34),
				BackgroundColor3 = Theme.Element,
				Text = "  " .. (o.Name or "Color"),
				TextColor3 = Theme.Text,
				Font = buttonFont(),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = true,
				LayoutOrder = #tab.Elements + 1,
				Parent = page,
			})
			round(row, 8)
			stroke(row, Theme.Stroke, 1, 0.5)
			table.insert(tab.Elements, row)

			local swatch = create("Frame", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0, IS_TOUCH and 24 or 20, 0, IS_TOUCH and 24 or 20),
				BackgroundColor3 = current,
				Parent = row,
			})
			round(swatch, 6)
			stroke(swatch, Theme.Stroke, 1, 0.4)

			-- simple HSV popup with touch support
			local popup = create("Frame", {
				Name = "Popup",
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 40),
				Size = UDim2.new(1, -16, 0, 170),
				BackgroundColor3 = Theme.Background,
				Visible = false,
				ZIndex = 30,
				Parent = row,
			})
			round(popup, 10)
			stroke(popup, Theme.Stroke, 1, 0.3)

			local hueBar = create("Frame", {
				Position = UDim2.new(0, 10, 0, 10),
				Size = UDim2.new(1, -20, 0, 18),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				Parent = popup,
				ZIndex = 31,
			})
			round(hueBar, 6)
			create("UIGradient", {
			 Rotation = 0,
			 Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
					ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
					ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
					ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
					ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
					ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
					ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
				}),
				Parent = hueBar,
			})

			local satBar = create("Frame", {
				Position = UDim2.new(0, 10, 0, 36),
				Size = UDim2.new(1, -20, 0, 18),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				Parent = popup,
				ZIndex = 31,
			})
			round(satBar, 6)

			local valBar = create("Frame", {
				Position = UDim2.new(0, 10, 0, 62),
				Size = UDim2.new(1, -20, 0, 18),
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				Parent = popup,
				ZIndex = 31,
			})
			round(valBar, 6)
			create("UIGradient", {
				Color = ColorSequence.new(Color3.fromRGB(0, 0, 0), Color3.fromRGB(255, 255, 255)),
				Parent = valBar,
			})

			local preview = create("Frame", {
				Position = UDim2.new(0, 10, 0, 92),
				Size = UDim2.new(0, 60, 0, 40),
				BackgroundColor3 = current,
				Parent = popup,
				ZIndex = 31,
			})
			round(preview, 8)
			stroke(preview, Theme.Stroke, 1, 0.3)

			local done = create("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 92),
				Size = UDim2.new(0, 90, 0, IS_TOUCH and MIN_TOUCH or 36),
				BackgroundColor3 = Theme.Accent,
				Font = buttonFont(),
				Text = "OK",
				TextColor3 = Theme.Text,
				TextSize = 14,
				AutoButtonColor = true,
				ZIndex = 31,
				Parent = popup,
			})
			round(done, 8)

			local h, s, v = Color3.toHSV(current)
			local function update()
				current = Color3.fromHSV(h, s, v)
				swatch.BackgroundColor3 = current
				preview.BackgroundColor3 = current
				satBar.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
				valBar.BackgroundColor3 = Color3.fromHSV(h, s, 1)
				if o.Callback then
					task.spawn(o.Callback, current)
				end
			end

			local function bindBar(bar, callback)
				local dragging = false
				local function apply(input)
					local rel = (input.Position.X - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X)
					callback(math.clamp(rel, 0, 1))
				end
				bar.Active = true
				bar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch then
						dragging = true
						apply(input)
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
						or input.UserInputType == Enum.UserInputType.Touch) then
						apply(input)
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1
						or input.UserInputType == Enum.UserInputType.Touch then
						dragging = false
					end
				end)
			end

			bindBar(hueBar, function(x)
				h = x
				update()
			end)
			bindBar(satBar, function(x)
				s = 1 - x
				update()
			end)
			bindBar(valBar, function(x)
				v = 1 - x
				update()
			end)

			row.Activated:Connect(function()
				popup.Visible = not popup.Visible
			end)
			done.Activated:Connect(function()
				popup.Visible = false
			end)
			update()

			return {
				Get = function()
					return current
				end,
				Set = function(_, c)
					h, s, v = Color3.toHSV(c)
					update()
				end,
			}
		end

		return tab
	end

	-- minimize behavior
	local minimized = false
	local savedSize = frame.Size
	minBtn.Activated:Connect(function()
		minimized = not minimized
		if minimized then
			savedSize = frame.Size
			TweenService:Create(frame, TWEEN_IN, {
				Size = UDim2.new(savedSize.X.Scale, savedSize.X.Offset, 0, 36),
			}):Play()
			minBtn.Text = "+"
		else
			TweenService:Create(frame, TWEEN_IN, { Size = savedSize }):Play()
			minBtn.Text = "-"
		end
		task.delay(0.3, function()
			win:ClampToScreen()
		end)
	end)

	closeBtn.Activated:Connect(function()
		frame.Visible = false
	end)

	function win:ClampToScreen()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local scaledW = frame.AbsoluteSize.X
		local scaledH = frame.AbsoluteSize.Y
		local abs = frame.AbsolutePosition
		local nx = math.clamp(abs.X, 0, math.max(0, vp.X - scaledW))
		local ny = math.clamp(abs.Y, 0, math.max(0, vp.Y - scaledH))
		frame.Position = UDim2.new(0, nx, 0, ny)
	end

	function win:SetTitle(t)
		title.Text = t
	end

	table.insert(self.Windows, win)
	return win
end

-- Convenience: create library + window in one call
-- local lib, win = Library.Window({ Name = "My Hub" })
function Library.Window(opts)
	local lib = Library.new(opts)
	return lib, lib:CreateWindow(opts)
end

return Library
