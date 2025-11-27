--// Quantum Hub (All-in-One) with Minimize/Restore Animation
local KEY = "quantumhub1"
local SELL_POS = Vector3.new(550, 3, 250)

local player = game.Players.LocalPlayer
local gui = Instance.new("ScreenGui", player.PlayerGui)
gui.ResetOnSpawn = false

----------------------------------------------------------
-- FRAME UI
----------------------------------------------------------
local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 450, 0, 230)
frame.Position = UDim2.new(0.5, -225, 0.5, -115)
frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
frame.Active = true

local corner = Instance.new("UICorner", frame)
corner.CornerRadius = UDim.new(0, 25)

local stroke = Instance.new("UIStroke", frame)
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(120, 0, 0)

-- Title bar
local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,40)
title.Position = UDim2.new(0,0,0,0)
title.BackgroundTransparency = 1
title.Text = "Quantum Hub Key"
title.TextColor3 = Color3.fromRGB(0,0,0)
title.TextScaled = true
title.Font = Enum.Font.GothamBold

-- Minimize button
local minButton = Instance.new("TextButton", frame)
minButton.Size = UDim2.new(0,40,0,25)
minButton.Position = UDim2.new(1,-50,0,7)
minButton.Text = "-"
minButton.TextScaled = true
minButton.BackgroundColor3 = Color3.fromRGB(40,40,40)
minButton.TextColor3 = Color3.fromRGB(255,255,255)
Instance.new("UICorner", minButton).CornerRadius = UDim.new(0,10)

-- Key input
local keyBox = Instance.new("TextBox", frame)
keyBox.Size = UDim2.new(0.8,0,0,40)
keyBox.Position = UDim2.new(0.1,0,0.45,0)
keyBox.BackgroundColor3 = Color3.fromRGB(240,240,240)
keyBox.PlaceholderText = "Enter Key"
keyBox.Text = ""
keyBox.TextScaled = true
keyBox.Font = Enum.Font.Gotham

local keyCorner = Instance.new("UICorner", keyBox)
keyCorner.CornerRadius = UDim.new(0,15)

-- Unlock button
local submit = Instance.new("TextButton", frame)
submit.Size = UDim2.new(0.6,0,0,40)
submit.Position = UDim2.new(0.2,0,0.75,0)
submit.Text = "Unlock"
submit.TextScaled = true
submit.Font = Enum.Font.GothamBold
submit.BackgroundColor3 = Color3.fromRGB(200,0,0)
submit.TextColor3 = Color3.fromRGB(255,255,255)

local submitCorner = Instance.new("UICorner", submit)
submitCorner.CornerRadius = UDim.new(0,15)

----------------------------------------------------------
-- Fade Functions
----------------------------------------------------------
local function fadeOut()
	for i = 0,1,0.1 do
		frame.BackgroundTransparency = i
		title.TextTransparency = i
		keyBox.TextTransparency = i
		submit.TextTransparency = i
		task.wait(0.03)
	end
end

----------------------------------------------------------
-- Unlock + Main Hub
----------------------------------------------------------
submit.MouseButton1Click:Connect(function()
	if keyBox.Text ~= KEY then
		title.Text = "WRONG KEY!"
		title.TextColor3 = Color3.fromRGB(255,0,0)
		task.wait(1)
		title.Text = "Quantum Hub Key"
		title.TextColor3 = Color3.fromRGB(0,0,0)
		return
	end

	-- Correct key, fade out
	fadeOut()
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = Color3.fromRGB(0,0,0)

	local bg = Instance.new("ImageLabel", frame)
	bg.Size = UDim2.new(1,0,1,0)
	bg.BackgroundTransparency = 1
	bg.Image = "rbxassetid://76793698293120"
	bg.ImageTransparency = 1
	Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 25)
	local bgStroke = Instance.new("UIStroke", bg)
	bgStroke.Thickness = 2
	bgStroke.Color = Color3.fromRGB(120,0,0)

	for i = 1,0,-0.1 do
		bg.ImageTransparency = i
		task.wait(0.03)
	end

	title.Text = "Quantum Hub"
	title.TextColor3 = Color3.fromRGB(255,255,255)
	title.TextTransparency = 0

	keyBox:Destroy()
	submit:Destroy()

	-- Button container
	local buttonContainer = Instance.new("Frame", frame)
	buttonContainer.Size = UDim2.new(1,0,1,0)
	buttonContainer.BackgroundTransparency = 1

	local buttons = {}
	local function createButton(text, order)
		local b = Instance.new("TextButton", buttonContainer)
		b.Size = UDim2.new(0.8,0,0,35)
		b.Position = UDim2.new(0.1,0,0.35 + ((order-1)*0.2),0)
		b.Text = text
		b.TextScaled = true
		b.Font = Enum.Font.GothamBold
		b.BackgroundColor3 = Color3.fromRGB(30,30,30)
		b.TextColor3 = Color3.fromRGB(255,255,255)
		Instance.new("UICorner", b).CornerRadius = UDim.new(0,15)
		table.insert(buttons, b)
		return b
	end

	local tpButton = createButton("Teleport to Sell",1)
	local fastButton = createButton("Fast Pickup (OFF)",2)
	local qtButton = createButton("Quantum Teleport (OFF)",3)

	-- Store original size and position for minimize/restore
	local originalSize = frame.Size
	local minimized = false

	-- Function to animate size change
	local function tweenSize(newSize)
		local steps = 10
		local currentSize = frame.Size
		for i = 1, steps do
			local alpha = i/steps
			local width = currentSize.X.Offset + (newSize.X.Offset - currentSize.X.Offset)*alpha
			local height = currentSize.Y.Offset + (newSize.Y.Offset - currentSize.Y.Offset)*alpha
			frame.Size = UDim2.new(currentSize.X.Scale, width, currentSize.Y.Scale, height)
			task.wait(0.02)
		end
		frame.Size = newSize
	end

	-- Minimize button: smooth animation
	minButton.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			buttonContainer.Visible = false
			tweenSize(UDim2.new(0,200,0,40))
		else
			tweenSize(originalSize)
			buttonContainer.Visible = true
		end
	end)

	------------------------------------------------------
	-- BUTTON LOGIC
	------------------------------------------------------
	tpButton.MouseButton1Click:Connect(function()
		local char = player.Character
		if char and char:FindFirstChild("HumanoidRootPart") then
			char.HumanoidRootPart.CFrame = CFrame.new(SELL_POS)
		end
	end)

	local fastPickupEnabled = false
	local FAST_HOLD = 0.05
	local function setPromptFast(prompt)
		if prompt and prompt:IsA("ProximityPrompt") then
			pcall(function()
				prompt.HoldDuration = FAST_HOLD
			end)
		end
	end
	fastButton.MouseButton1Click:Connect(function()
		fastPickupEnabled = not fastPickupEnabled
		fastButton.Text = fastPickupEnabled and "Fast Pickup (ON)" or "Fast Pickup (OFF)"
		if fastPickupEnabled then
			for _, obj in ipairs(workspace:GetDescendants()) do
				setPromptFast(obj)
			end
			workspace.DescendantAdded:Connect(setPromptFast)
		end
	end)

	-- Quantum teleport
	local qtEnabled = false
	local RunService = game:GetService("RunService")
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local minX, maxX = 694, 775
	local minZ, maxZ = 69, 158
	local exclMinX, exclMaxX = 708, 762
	local exclMinZ, exclMaxZ = 85, 140
	local fixedPos = Vector3.new(581, 3, 267)
	local qtTimer1, qtTimer2 = 0, 0

	local function getRandomPosition()
		while true do
			local x = math.random(minX, maxX)
			local z = math.random(minZ, maxZ)
			if not (x >= exclMinX and x <= exclMaxX and z >= exclMinZ and z <= exclMaxZ) then
				return Vector3.new(x, 3, z)
			end
		end
	end

	RunService.RenderStepped:Connect(function(dt)
		if not qtEnabled then return end
		qtTimer1 += dt
		qtTimer2 += dt
		if qtTimer1 >= 1 then
			hrp.CFrame = CFrame.new(getRandomPosition())
			qtTimer1 = 0
		end
		if qtTimer2 >= 2 then
			hrp.CFrame = CFrame.new(fixedPos)
			qtTimer2 = 0
		end
	end)

	qtButton.MouseButton1Click:Connect(function()
		qtEnabled = not qtEnabled
		qtButton.Text = qtEnabled and "Quantum Teleport (ON)" or "Quantum Teleport (OFF)"
	end)

	------------------------------------------------------
	-- DRAG LOGIC
	------------------------------------------------------
	local dragging = false
	local dragInput, mousePos, framePos
	local UserInputService = game:GetService("UserInputService")

	title.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			mousePos = input.Position
			framePos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - mousePos
			frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
		end
	end)
end)
