-- Constants / Config
local INVITE = "https://discord.gg/FYgZm9nH4C"
local SELL_POS = Vector3.new(550, 3, 250)

local function reconstruct_key()
	local encoded = {118,127,112,130,141,147,144,144,162,148,105}
	local parts = {}
	for i, v in ipairs(encoded) do
		parts[i] = string.char(v - i * 5)
	end
	return table.concat(parts)
end
local KEY = reconstruct_key()

-- Junk area for quantum teleport
local JUNK_MIN_X, JUNK_MAX_X = 694, 775
local JUNK_MIN_Z, JUNK_MAX_Z = 69, 158
local JUNK_EXCL_MIN_X, JUNK_EXCL_MAX_X = 708, 762
local JUNK_EXCL_MIN_Z, JUNK_EXCL_MAX_Z = 85, 140
local JUNK_Y = 3

local HOLD_DURATION = 0.5         
local HOLD_RADIUS = 18              
local HOLD_DELAY_AFTER_TELEPORT = 0.2
local HOLD_ATTEMPTS = 3             
local HOLD_ATTEMPT_INTERVAL = 0.12  

local TELEPORT_INTERVAL = 1.0      
local TELEPORT_COOLDOWN = 0.25      

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Helpers
local function newInstance(class, props, parent)
	local obj = Instance.new(class)
	if props then for k,v in pairs(props) do obj[k] = v end end
	if parent then obj.Parent = parent end
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

local connections = {}
local created = {}
local function trackConnection(c) table.insert(connections, c); return c end
local function trackCreated(i) table.insert(created, i); return i end
local function cleanup()
	for _, c in ipairs(connections) do if c and type(c.Disconnect) == "function" then pcall(function() c:Disconnect() end) end end
	for _, i in ipairs(created) do if i and i.Parent then pcall(function() i:Destroy() end) end end
	connections = {}
	created = {}
end

-- UI
local gui = trackCreated(newInstance("ScreenGui", {Name="QuantumHubGui", ResetOnSpawn=false, IgnoreGuiInset=true}, playerGui))
local frame = trackCreated(newInstance("Frame", {Size=UDim2.new(0,450,0,230), Position=UDim2.new(0.5,-225,0.5,-115), BackgroundColor3=Color3.fromRGB(20,20,20), Active=true, Parent=gui}))
makeCorner(frame,25)
trackCreated(newInstance("UIStroke",{Thickness=2,Color=Color3.fromRGB(120,0,0),Parent=frame}))

local title = trackCreated(newInstance("TextLabel",{Size=UDim2.new(1,0,0,40),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Text="Quantum Hub",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Font=Enum.Font.GothamBold,Parent=frame}))
local minButton = trackCreated(newInstance("TextButton",{Size=UDim2.new(0,40,0,25),Position=UDim2.new(1,-50,0,7),Text="-",TextScaled=true,BackgroundColor3=Color3.fromRGB(40,40,40),TextColor3=Color3.fromRGB(255,255,255),Parent=frame}))
makeCorner(minButton,10)

-- Invite and copy
local inviteFrame = trackCreated(newInstance("Frame",{Size=UDim2.new(0.8,0,0,44),Position=UDim2.new(0.1,0,0.28,0),BackgroundTransparency=1,Parent=frame}))
local inviteLabel = trackCreated(newInstance("TextLabel",{Size=UDim2.new(1,-70,1,0),Position=UDim2.new(0,0,0,0),BackgroundTransparency=1,Text=INVITE,TextColor3=Color3.fromRGB(0,102,204),TextScaled=true,TextXAlignment=Enum.TextXAlignment.Left,Font=Enum.Font.GothamBold,Parent=inviteFrame}))
local copyButton = trackCreated(newInstance("TextButton",{Size=UDim2.new(0,64,0,30),Position=UDim2.new(1,-68,0,7),Text="Copy",TextScaled=true,Font=Enum.Font.GothamBold,BackgroundColor3=Color3.fromRGB(30,30,30),TextColor3=Color3.fromRGB(255,255,255),Parent=inviteFrame}))
makeCorner(copyButton,8)

local feedback = trackCreated(newInstance("TextLabel",{Size=UDim2.new(0,120,0,24),Position=UDim2.new(0.5,-60,0.06,40),BackgroundTransparency=0.8,BackgroundColor3=Color3.fromRGB(20,20,20),Text="",TextColor3=Color3.fromRGB(255,255,255),TextScaled=true,Visible=false,Parent=frame}))
makeCorner(feedback,8)

local function showFeedback(text,time)
	feedback.Text=text feedback.Visible=true feedback.TextTransparency=1 feedback.BackgroundTransparency=1
	tween(feedback,{TextTransparency=0,BackgroundTransparency=0.5},TweenInfo.new(0.18))
	task.delay(time or 1.2,function()
		if feedback and feedback.Parent then tween(feedback,{TextTransparency=1,BackgroundTransparency=1},TweenInfo.new(0.18)) task.delay(0.2,function() if feedback and feedback.Parent then feedback.Visible=false end end) end
	end)
end

copyButton.MouseButton1Click:Connect(function()
	local ok=false
	pcall(function() if setclipboard then setclipboard(INVITE) ok=true end end)
	if ok then showFeedback("Invite copied!",1.2) else showFeedback("Could not copy. Manual: "..INVITE,2.5) end
end)

-- Key input
local keyBox = trackCreated(newInstance("TextBox",{Size=UDim2.new(0.8,0,0,40),Position=UDim2.new(0.1,0,0.5,0),BackgroundColor3=Color3.fromRGB(240,240,240),PlaceholderText="Enter Key",Text="",TextScaled=true,Font=Enum.Font.Gotham,ClearTextOnFocus=false,Parent=frame}))
makeCorner(keyBox,15)
local submit = trackCreated(newInstance("TextButton",{Size=UDim2.new(0.6,0,0,40),Position=UDim2.new(0.2,0,0.75,0),Text="Unlock",TextScaled=true,Font=Enum.Font.GothamBold,BackgroundColor3=Color3.fromRGB(200,0,0),TextColor3=Color3.fromRGB(255,255,255),Parent=frame}))
makeCorner(submit,15)

-- Track elements for minimize AFTER unlock (buttons only)
local mainContent = {}

-- Drag
do
	local dragging=false local dragStart=Vector2.new() local frameStart=Vector2.new()
	title.InputBegan:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true dragStart=input.Position frameStart=Vector2.new(frame.Position.X.Offset,frame.Position.Y.Offset)
			input.Changed:Connect(function() if input.UserInputState==Enum.UserInputState.End then dragging=false end end)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
			local delta=input.Position-dragStart
			frame.Position=UDim2.new(frame.Position.X.Scale,frameStart.X+delta.X,frame.Position.Y.Scale,frameStart.Y+delta.Y)
		end
	end)
end

-- Minimize / maximize
local originalSize = frame.Size
local minimized=false
local minimizedSize=UDim2.new(0,200,0,40)
minButton.MouseButton1Click:Connect(function()
	minimized=not minimized
	if minimized then
		for _,child in ipairs(mainContent) do
			if child and child.Parent then child.Visible=false end
		end
		tween(frame,{Size=minimizedSize},TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
	else
		tween(frame,{Size=originalSize},TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.Out))
		task.delay(0.25,function()
			for _,child in ipairs(mainContent) do
				if child and child.Parent then child.Visible=true end
			end
		end)
	end
end)

-- === UNLOCK & BUTTON LOGIC ===
local qtEnabled = false
local hrp = nil
local timer = 0
local lastTeleport = 0
local teleportCooldown = false
local nextTeleportIsSell = false
local fastPickupEnabled=false
local fastOriginal={}
local fastDescendantConn=nil

-- Helper functions
local function updateHumanoidRootPart()
	local char=player.Character
	hrp=nil
	if char then
		local ok,part=pcall(function() return char:WaitForChild("HumanoidRootPart",5) end)
		if ok and part then hrp=part end
	end
end
trackConnection(player.CharacterAdded:Connect(function() task.defer(updateHumanoidRootPart) end))
updateHumanoidRootPart()

local function getRandomJunkPosition()
	local tries=0
	while true do
		tries=tries+1
		local x=math.random(JUNK_MIN_X,JUNK_MAX_X)
		local z=math.random(JUNK_MIN_Z,JUNK_MAX_Z)
		if not (x>=JUNK_EXCL_MIN_X and x<=JUNK_EXCL_MAX_X and z>=JUNK_EXCL_MIN_Z and z<=JUNK_EXCL_MAX_Z) then
			return Vector3.new(x,JUNK_Y,z)
		end
		if tries>100 then return Vector3.new((JUNK_MIN_X+JUNK_MAX_X)/2,JUNK_Y,(JUNK_MIN_Z+JUNK_MAX_Z)/2) end
	end
end

local function getPromptWorldPosition(prompt)
	if not prompt or not prompt.Parent then return nil end
	local p=prompt.Parent
	while p and not p:IsA("BasePart") and not p:IsA("Attachment") do p=p.Parent end
	if not p then return nil end
	if p:IsA("Attachment") then
		if p.WorldPosition then return p.WorldPosition end
		if p.Parent and p.Parent:IsA("BasePart") then return p.Parent.Position+p.Position end
	end
	if p:IsA("BasePart") then return p.Position end
	return nil
end

local function findNearestPrompt(position,radius)
	local nearest,best=nil,math.huge
	for _,obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Enabled then
			local ok,pos=pcall(getPromptWorldPosition,obj)
			if ok and pos then
				local d=(pos-position).Magnitude
				if d<=radius and d<best then best=d nearest=obj end
			end
		end
	end
	return nearest
end

local function holdPrompt(prompt,duration)
	if not prompt or not prompt.Parent or not prompt.Enabled then return false end
	local okBeg=false
	pcall(function()
		if typeof(prompt.InputHoldBegin)=="function" then
			prompt:InputHoldBegin()
			okBeg=true
		end
	end)
	if okBeg then
		task.wait(duration)
		pcall(function() if typeof(prompt.InputHoldEnd)=="function" then prompt:InputHoldEnd() end end)
	end
	return okBeg
end

local function attemptHoldSequence(position)
	task.wait(HOLD_DELAY_AFTER_TELEPORT)
	for i=1,HOLD_ATTEMPTS do
		local prompt=findNearestPrompt(position,HOLD_RADIUS)
		if prompt then
			local ok=holdPrompt(prompt,HOLD_DURATION)
			if ok then return true end
		end
		task.wait(HOLD_ATTEMPT_INTERVAL)
	end
	return false
end

local function doTeleport(targetPos)
	if not hrp or not hrp.Parent then return false end
	local now=tick()
	if teleportCooldown and now-lastTeleport<TELEPORT_COOLDOWN then return false end
	lastTeleport=now
	teleportCooldown=true
	task.delay(TELEPORT_COOLDOWN,function() teleportCooldown=false end)
	pcall(function() hrp.CFrame=CFrame.new(targetPos) end)
	task.spawn(function() attemptHoldSequence(hrp and hrp.Position or targetPos) end)
	return true
end

local function onHeartbeat(dt)
	if not qtEnabled or not hrp then return end
	timer+=dt
	if timer>=TELEPORT_INTERVAL then
		timer=timer-TELEPORT_INTERVAL
		local target=nextTeleportIsSell and SELL_POS or getRandomJunkPosition()
		local ok=doTeleport(target)
		if ok then nextTeleportIsSell=not nextTeleportIsSell end
	end
end
trackConnection(RunService.Heartbeat:Connect(onHeartbeat))

local function setPromptFast(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") then return end
	local ok,_=pcall(function()
		if fastOriginal[prompt]==nil then fastOriginal[prompt]=prompt.HoldDuration end
		prompt.HoldDuration=0.05
	end)
	if not ok then fastOriginal[prompt]=nil end
end

local function restoreFastPrompts()
	for prompt,original in pairs(fastOriginal) do
		if prompt and prompt.Parent and typeof(original)=="number" then pcall(function() prompt.HoldDuration=original end) end
	end
	fastOriginal={}
end

-- Unlock
submit.MouseButton1Click:Connect(function()
	if keyBox.Text=="quantumhub1" then
		showFeedback("Join Discord for new key",2) return
	end
	if keyBox.Text~=KEY then
		title.Text="WRONG KEY!" title.TextColor3=Color3.fromRGB(255,0,0)
		task.delay(1,function() if title and title.Parent then title.Text="Quantum Hub" title.TextColor3=Color3.fromRGB(255,255,255) end end)
		return
	end

	-- Unlock UI
	submit.Active=false keyBox.Active=false
	keyBox.Visible=false submit.Visible=false inviteFrame.Visible=false inviteLabel.Visible=false copyButton.Visible=false
	frame.BackgroundColor3=Color3.fromRGB(0,0,0)

	-- Buttons container
	local buttonContainer=trackCreated(newInstance("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Parent=frame}))
	table.insert(mainContent,buttonContainer)

	local function createButton(text,order)
		local b=trackCreated(newInstance("TextButton",{Size=UDim2.new(0.8,0,0,35),Position=UDim2.new(0.1,0,0.35+((order-1)*0.22),0),Text=text,TextScaled=true,Font=Enum.Font.GothamBold,BackgroundColor3=Color3.fromRGB(30,30,30),TextColor3=Color3.fromRGB(255,255,255),Parent=buttonContainer}))
		makeCorner(b,15)
		return b
	end

	local tpButton=createButton("Teleport to Sell",1)
	local fastButton=createButton("Fast Pickup (OFF)",2)
	local qtButton=createButton("Quantum Teleport (OFF)",3)

	-- Teleport to Sell
	tpButton.MouseButton1Click:Connect(function() if hrp then pcall(function() hrp.CFrame=CFrame.new(SELL_POS) end) end end)

	-- Fast Pickup toggle
	fastButton.MouseButton1Click:Connect(function()
		fastPickupEnabled=not fastPickupEnabled
		fastButton.Text=fastPickupEnabled and "Fast Pickup (ON)" or "Fast Pickup (OFF)"
		if fastPickupEnabled then
			for _,obj in ipairs(Workspace:GetDescendants()) do if obj:IsA("ProximityPrompt") then setPromptFast(obj) end end
			fastDescendantConn=trackConnection(Workspace.DescendantAdded:Connect(function(desc) if desc:IsA("ProximityPrompt") then setPromptFast(desc) end end))
		else
			restoreFastPrompts()
			if fastDescendantConn then pcall(function() fastDescendantConn:Disconnect() end) fastDescendantConn=nil end
		end
	end)

	-- Quantum Teleport toggle
	qtButton.MouseButton1Click:Connect(function()
		qtEnabled=not qtEnabled
		qtButton.Text=qtEnabled and "Quantum Teleport (ON)" or "Quantum Teleport (OFF)"
		if qtEnabled then timer=0 nextTeleportIsSell=false else timer=0 end
	end)
end)

trackConnection(gui.AncestryChanged:Connect(function(_,parent) if not parent then cleanup() end end))
trackConnection(player.AncestryChanged:Connect(function(_,parent) if not parent then cleanup() end end))
