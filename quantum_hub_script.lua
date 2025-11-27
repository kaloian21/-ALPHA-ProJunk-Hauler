-- Improved Quantum Hub LocalScript — fixed ProximityPrompt "hold E" to run reliably after every teleport.
-- Place as a LocalScript (StarterPlayerScripts or StarterGui).

-- Config
local KEY = "quantumhub1"
local SELL_POS = Vector3.new(550, 3, 250)

-- Hold simulation config
local HOLD_DURATION = 0.5            -- seconds to "hold E" after teleport
local HOLD_RADIUS = 8                -- studs to search for a ProximityPrompt to hold
local HOLD_DELAY_AFTER_TELEPORT = 0.2-- wait after teleport before searching for prompts
local HOLD_ATTEMPTS = 3              -- number of attempts to try finding/holding prompts
local HOLD_ATTEMPT_INTERVAL = 0.12   -- wait between attempts

-- Teleport delay config
local TELEPORT_COOLDOWN = 0.5        -- seconds to wait after any teleport before allowing another teleport

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
	error("This script must run as a LocalScript (LocalPlayer not found).")
end

local playerGui = player:WaitForChild("PlayerGui")

-- Helpers
local function newInstance(class, props, parent)
	local obj = Instance.new(class)
	if props then
		for k,v in pairs(props) do
			obj[k] = v
		end
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = parent
	return c
end

local function tween(instance, properties, info)
	info = info or TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tw = TweenService:Create(instance, info, properties)
	tw:Play()
	return tw
end

-- Track connections and created objects for cleanup
local connections = {}
local created = {}

local function trackConnection(conn)
	table.insert(connections, conn)
	return conn
end

local function trackCreated(inst)
	table.insert(created, inst)
	return inst
end

local function cleanup()
	for _, c in ipairs(connections) do
		if c and type(c.Disconnect) == "function" then
			pcall(function() c:Disconnect() end)
		end
	end
	connections = {}

	for _, inst in ipairs(created) do
		if inst and inst.Parent then
			pcall(function() inst:Destroy() end)
		end
	end
	created = {}
end

-- Build UI (same style as before)
local gui = trackCreated(newInstance("ScreenGui", {
	Name = "QuantumHubGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
}, playerGui))

local frame = trackCreated(newInstance("Frame", {
	Size = UDim2.new(0, 450, 0, 230),
	Position = UDim2.new(0.5, -225, 0.5, -115),
	BackgroundColor3 = Color3.fromRGB(255,255,255),
	Active = true,
	Parent = gui,
}))

makeCorner(frame, 25)
local stroke = trackCreated(newInstance("UIStroke", {
	Thickness = 2,
	Color = Color3.fromRGB(120,0,0),
	Parent = frame
}))

local title = trackCreated(newInstance("TextLabel", {
	Size = UDim2.new(1,0,0,40),
	Position = UDim2.new(0,0,0,0),
	BackgroundTransparency = 1,
	Text = "Quantum Hub Key",
	TextColor3 = Color3.fromRGB(0,0,0),
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	Parent = frame,
}))

local minButton = trackCreated(newInstance("TextButton", {
	Size = UDim2.new(0,40,0,25),
	Position = UDim2.new(1,-50,0,7),
	Text = "-",
	TextScaled = true,
	BackgroundColor3 = Color3.fromRGB(40,40,40),
	TextColor3 = Color3.fromRGB(255,255,255),
	Parent = frame,
}))
makeCorner(minButton, 10)

local keyBox = trackCreated(newInstance("TextBox", {
	Size = UDim2.new(0.8,0,0,40),
	Position = UDim2.new(0.1,0,0.45,0),
	BackgroundColor3 = Color3.fromRGB(240,240,240),
	PlaceholderText = "Enter Key",
	Text = "",
	TextScaled = true,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
	Parent = frame,
}))
makeCorner(keyBox, 15)

local submit = trackCreated(newInstance("TextButton", {
	Size = UDim2.new(0.6,0,0,40),
	Position = UDim2.new(0.2,0,0.75,0),
	Text = "Unlock",
	TextScaled = true,
	Font = Enum.Font.GothamBold,
	BackgroundColor3 = Color3.fromRGB(200,0,0),
	TextColor3 = Color3.fromRGB(255,255,255),
	Parent = frame,
}))
makeCorner(submit, 15)

local function fadeElements(elements, targetTransparency, time)
	for _, el in ipairs(elements) do
		if el then
			local props = {}
			if el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox") then
				props.TextTransparency = targetTransparency
			end
			props.BackgroundTransparency = targetTransparency
			if el:IsA("ImageLabel") or el:IsA("ImageButton") then
				props.ImageTransparency = targetTransparency
			end
			if next(props) then
				tween(el, props, TweenInfo.new(time or 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			end
		end
	end
end

local function showWrongKey()
	local oldText = title.Text
	local oldColor = title.TextColor3
	title.Text = "WRONG KEY!"
	title.TextColor3 = Color3.fromRGB(255,0,0)
	task.delay(1, function()
		if title and title.Parent then
			title.Text = oldText
			title.TextColor3 = oldColor
		end
	end)
end

-- Fast pickup support (unchanged)
local fastPickupEnabled = false
local fastDescendantConn
local fastOriginal = {} -- [prompt] = originalHoldDuration

local function setPromptFast(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	local ok, _ = pcall(function()
		if fastOriginal[prompt] == nil then
			fastOriginal[prompt] = prompt.HoldDuration
		end
		prompt.HoldDuration = 0.05
	end)
	if not ok then
		fastOriginal[prompt] = nil
	end
end

local function restoreFastPrompts()
	for prompt, original in pairs(fastOriginal) do
		if prompt and prompt.Parent and typeof(original) == "number" then
			pcall(function()
				prompt.HoldDuration = original
			end)
		end
	end
	fastOriginal = {}
end

-- Quantum teleport state
local qtEnabled = false
local qtTimer1, qtTimer2 = 0, 0
local hrp -- current HumanoidRootPart (updated on respawn)
local teleportCooldown = false -- prevents rapid consecutive teleports

local function updateHumanoidRootPart()
	local character = player.Character
	hrp = nil
	if character then
		local ok, res = pcall(function() return character:WaitForChild("HumanoidRootPart", 5) end)
		if ok and res then
			hrp = res
		end
	end
end

trackConnection(player.CharacterAdded:Connect(function()
	task.defer(updateHumanoidRootPart)
end))
updateHumanoidRootPart()

local minX, maxX = 694, 775
local minZ, maxZ = 69, 158
local exclMinX, exclMaxX = 708, 762
local exclMinZ, exclMaxZ = 85, 140
local fixedPos = Vector3.new(581, 3, 267)

local function getRandomPosition()
	while true do
		local x = math.random(minX, maxX)
		local z = math.random(minZ, maxZ)
		if not (x >= exclMinX and x <= exclMaxX and z >= exclMinZ and z <= exclMaxZ) then
			return Vector3.new(x, 3, z)
		end
	end
end

-- Helper: find the world position for a prompt (Attachment or BasePart parent)
local function getPromptWorldPosition(prompt)
	if not prompt or not prompt.Parent then return nil end
	local p = prompt.Parent
	while p and not p:IsA("BasePart") and not p:IsA("Attachment") do
		p = p.Parent
	end
	if not p then return nil end
	if p:IsA("Attachment") then
		if p.WorldPosition then
			return p.WorldPosition
		else
			if p.Parent and p.Parent:IsA("BasePart") then
				return p.Parent.Position + p.Position
			end
		end
	end
	if p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

-- Find nearest ProximityPrompt to a position within a radius (handles Attachment and BasePart parents)
local function findNearestPrompt(position, radius)
	local nearest = nil
	local bestDist = math.huge
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Enabled then
			local ok, pos = pcall(getPromptWorldPosition, obj)
			if ok and pos then
				local d = (pos - position).Magnitude
				if d <= radius and d < bestDist then
					bestDist = d
					nearest = obj
				end
			end
		end
	end
	return nearest
end

-- Simulate holding "E" by calling ProximityPrompt InputHold methods for duration on a prompt
local function holdPrompt(prompt, duration)
	if not prompt or not prompt.Parent or not prompt.Enabled then return false end
	local succeeded = false
	pcall(function()
		if typeof(prompt.InputHoldBegin) == "function" then
			prompt:InputHoldBegin()
			succeeded = true
		end
	end)
	if succeeded then
		task.wait(duration)
		pcall(function()
			if typeof(prompt.InputHoldEnd) == "function" then
				prompt:InputHoldEnd()
			end
		end)
	end
	return succeeded
end

-- Try multiple attempts to hold the nearest prompt at position
local function attemptHoldSequence(position)
	-- wait a short moment to let things settle (e.g., after teleport)
	task.wait(HOLD_DELAY_AFTER_TELEPORT)
	for attempt = 1, HOLD_ATTEMPTS do
		local prompt = findNearestPrompt(position, HOLD_RADIUS)
		if prompt then
			local ok = holdPrompt(prompt, HOLD_DURATION)
			if ok then
				return true
			end
		end
		-- if not successful, wait and retry (some objects may appear slightly after teleport)
		task.wait(HOLD_ATTEMPT_INTERVAL)
	end
	return false
end

-- Heartbeat handler for quantum teleport (client-only)
local function onHeartbeat(dt)
	if not qtEnabled or not hrp then return end
	qtTimer1 += dt
	qtTimer2 += dt

	-- handle random teleport (1s) and fixed teleport (2s)
	if qtTimer1 >= 1 then
		if not teleportCooldown then
			teleportCooldown = true
			qtTimer1 = 0
			pcall(function()
				hrp.CFrame = CFrame.new(getRandomPosition())
			end)
			-- always attempt hold sequence after teleport (separate from teleport cooldown)
			task.spawn(function()
				attemptHoldSequence(hrp.Position)
			end)
			task.delay(TELEPORT_COOLDOWN, function()
				teleportCooldown = false
			end)
		else
			qtTimer1 = 0
		end
	end

	if qtTimer2 >= 2 then
		if not teleportCooldown then
			teleportCooldown = true
			qtTimer2 = 0
			pcall(function()
				hrp.CFrame = CFrame.new(fixedPos)
			end)
			task.spawn(function()
				attemptHoldSequence(hrp.Position)
			end)
			task.delay(TELEPORT_COOLDOWN, function()
				teleportCooldown = false
			end)
		else
			qtTimer2 = 0
		end
	end
end

-- Connect Heartbeat
trackConnection(RunService.Heartbeat:Connect(onHeartbeat))

-- Build unlock behavior (similar UI + controls as before)
submit.MouseButton1Click:Connect(function()
	if keyBox.Text ~= KEY then
		showWrongKey()
		return
	end

	submit.Active = false
	keyBox.Active = false

	fadeElements({frame, title, keyBox, submit}, 1, 0.18)
	task.wait(0.22)

	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = Color3.fromRGB(0,0,0)

	local bg = trackCreated(newInstance("ImageLabel", {
		Size = UDim2.new(1,0,1,0),
		BackgroundTransparency = 1,
		Image = "rbxassetid://76793698293120",
		ImageTransparency = 1,
		Parent = frame,
	}))
	makeCorner(bg, 25)
	local bgStroke = trackCreated(newInstance("UIStroke", {
		Thickness = 2,
		Color = Color3.fromRGB(120,0,0),
		Parent = bg,
	}))

	tween(bg, {ImageTransparency = 0}, TweenInfo.new(0.25))
	task.wait(0.25)

	title.Text = "Quantum Hub"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.TextTransparency = 0

	pcall(function() keyBox:Destroy() end)
	pcall(function() submit:Destroy() end)

	local buttonContainer = trackCreated(newInstance("Frame", {
		Size = UDim2.new(1,0,1,0),
		BackgroundTransparency = 1,
		Parent = frame,
	}))

	local function createButton(text, order)
		local b = trackCreated(newInstance("TextButton", {
			Size = UDim2.new(0.8,0,0,35),
			Position = UDim2.new(0.1,0,0.35 + ((order-1)*0.22),0),
			Text = text,
			TextScaled = true,
			Font = Enum.Font.GothamBold,
			BackgroundColor3 = Color3.fromRGB(30,30,30),
			TextColor3 = Color3.fromRGB(255,255,255),
			Parent = buttonContainer,
		}))
		makeCorner(b, 15)
		return b
	end

	local tpButton = createButton("Teleport to Sell", 1)
	local fastButton = createButton("Fast Pickup (OFF)", 2)
	local qtButton = createButton("Quantum Teleport (OFF)", 3)

	-- Minimize toggle
	local originalSize = frame.Size
	local minimized = false
	local minimizedSize = UDim2.new(0,200,0,40)
	trackConnection(minButton.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			if buttonContainer then buttonContainer.Visible = false end
			tween(frame, {Size = minimizedSize}, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
		else
			tween(frame, {Size = originalSize}, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
			if buttonContainer then
				task.delay(0.25, function()
					if buttonContainer then buttonContainer.Visible = true end
				end)
			end
		end
	end))

	-- Teleport to sell (client-side)
	tpButton.MouseButton1Click:Connect(function()
		local character = player.Character
		if not character then return end
		local root = character:FindFirstChild("HumanoidRootPart")
		if not root then return end
		pcall(function()
			root.CFrame = CFrame.new(SELL_POS)
		end)
	end)

	-- Fast pickup toggle
	trackConnection(fastButton.MouseButton1Click:Connect(function()
		fastPickupEnabled = not fastPickupEnabled
		fastButton.Text = fastPickupEnabled and "Fast Pickup (ON)" or "Fast Pickup (OFF)"

		if fastPickupEnabled then
			for _, obj in ipairs(Workspace:GetDescendants()) do
				if obj:IsA("ProximityPrompt") then
					setPromptFast(obj)
				end
			end
			fastDescendantConn = trackConnection(Workspace.DescendantAdded:Connect(function(desc)
				if desc:IsA("ProximityPrompt") then
					setPromptFast(desc)
				end
			end))
		else
			restoreFastPrompts()
			if fastDescendantConn then
				pcall(function() fastDescendantConn:Disconnect() end)
				fastDescendantConn = nil
			end
		end
	end))

	-- Quantum teleport toggle
	trackConnection(qtButton.MouseButton1Click:Connect(function()
		qtEnabled = not qtEnabled
		qtButton.Text = qtEnabled and "Quantum Teleport (ON)" or "Quantum Teleport (OFF)"
		if not qtEnabled then
			qtTimer1 = 0
			qtTimer2 = 0
			teleportCooldown = false
		end
	end))

	-- Dragging support
	local dragging = false
	local dragStart, startPos
	trackConnection(title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			trackConnection(input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end))
		end
	end))

	trackConnection(UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement and dragStart and startPos then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
end)

-- Cleanup listeners if GUI removed
trackConnection(gui.AncestryChanged:Connect(function(_, parent)
	if not parent then
		cleanup()
	end
end))

trackConnection(player.AncestryChanged:Connect(function(_, parent)
	if not parent then
		cleanup()
	end
end))
