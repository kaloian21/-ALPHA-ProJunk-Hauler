---- yo
local INVITE = "https://discord.gg/FYgZm9nH4C"
local SELL_POS = Vector3.new(550,3,250)

local function reconstruct_key()
	local encoded = {118,127,112,130,141,147,144,144,162,148,105}
	local parts = {}
	for i,v in ipairs(encoded) do
		parts[i] = string.char(v - i*5)
	end
	return table.concat(parts)
end
local KEY = reconstruct_key()

local JUNK_MIN_X, JUNK_MAX_X = 694,775
local JUNK_MIN_Z, JUNK_MAX_Z = 69,158
local JUNK_EXCL_MIN_X, JUNK_EXCL_MAX_X = 708,762
local JUNK_EXCL_MIN_Z, JUNK_EXCL_MAX_Z = 85,140
local JUNK_Y = 3

local HOLD_DURATION = 0.5
local HOLD_RADIUS = 18
local HOLD_DELAY_AFTER_TELEPORT = 0.2
local HOLD_ATTEMPTS = 3
local HOLD_ATTEMPT_INTERVAL = 0.12

local TELEPORT_INTERVAL = 1
local TELEPORT_COOLDOWN = 0.25

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local itemNames = {
	"Boots","Plant","Papers","Fridge","Toilet","Matress","Piano",
	"Big Trash","Sofa","Motorcycle","Gaming PC","Boat","Safe","AWP",
	"Grandfather Clock","Dead Body","Sarcophagus","Tank"
}

local function new(class,props,parent)
	local o = Instance.new(class)
	if props then for k,v in pairs(props) do o[k]=v end end
	if parent then o.Parent=parent end
	return o
end

local function corner(ui,r)
	new("UICorner",{CornerRadius=UDim.new(0,r or 12)},ui)
end

local gui = new("ScreenGui",{ResetOnSpawn=false},playerGui)

-- Start with small key GUI
local frame = new("Frame",{
	Size=UDim2.new(0,400,0,180), -- small
	Position=UDim2.new(0.5,-200,0.5,-90),
	BackgroundColor3=Color3.fromRGB(20,20,20),
	Active=true
},gui)
corner(frame,20)
new("UIStroke",{Thickness=2,Color=Color3.fromRGB(120,0,0),Parent=frame})

local title = new("TextLabel",{
	Size=UDim2.new(1,0,0,40),
	Text="Quantum Hub",
	BackgroundTransparency=1,
	TextScaled=true,
	TextColor3=Color3.new(1,1,1),
	Font=Enum.Font.GothamBold,
	Parent=frame
})

do
	local dragging,dragStart,frameStart
	title.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			dragging=true
			dragStart=i.Position
			frameStart=Vector2.new(frame.Position.X.Offset,frame.Position.Y.Offset)
			i.Changed:Connect(function()
				if i.UserInputState==Enum.UserInputState.End then dragging=false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			local d=i.Position-dragStart
			frame.Position=UDim2.new(0,frameStart.X+d.X,0,frameStart.Y+d.Y)
		end
	end)
end

local mainContent={}
local minimized=false
local minSize=UDim2.new(0,200,0,40)
local origSize=frame.Size

local minBtn=new("TextButton",{
	Size=UDim2.new(0,40,0,25),
	Position=UDim2.new(1,-50,0,7),
	Text="-",
	TextScaled=true,
	BackgroundColor3=Color3.fromRGB(40,40,40),
	TextColor3=Color3.new(1,1,1),
	Parent=frame
})
corner(minBtn,10)

minBtn.MouseButton1Click:Connect(function()
	minimized=not minimized
	for _,v in ipairs(mainContent) do v.Visible=not minimized end
	TweenService:Create(frame,TweenInfo.new(0.25),{Size=minimized and minSize or frame.Size}):Play()
end)

local inviteLabel=new("TextLabel",{
	Size=UDim2.new(0.7,0,0,30),
	Position=UDim2.new(0.05,0,0.18,0),
	Text=INVITE,
	TextScaled=true,
	TextXAlignment=Enum.TextXAlignment.Left,
	TextColor3=Color3.fromRGB(0,120,255),
	BackgroundTransparency=1,
	Font=Enum.Font.GothamBold,
	Parent=frame
})

local copyBtn=new("TextButton",{
	Size=UDim2.new(0,80,0,30),
	Position=UDim2.new(0.75,0,0.18,0),
	Text="Copy",
	TextScaled=true,
	BackgroundColor3=Color3.fromRGB(30,30,30),
	TextColor3=Color3.new(1,1,1),
	Parent=frame
})
corner(copyBtn,8)

copyBtn.MouseButton1Click:Connect(function()
	if setclipboard then setclipboard(INVITE) end
end)

local keyBox=new("TextBox",{
	Size=UDim2.new(0.8,0,0,40),
	Position=UDim2.new(0.1,0,0.5,0),
	PlaceholderText="Enter Key",
	TextScaled=true,
	Font=Enum.Font.Gotham,
	Parent=frame
})
corner(keyBox,15)

local unlock=new("TextButton",{
	Size=UDim2.new(0.6,0,0,40),
	Position=UDim2.new(0.2,0,0.75,0),
	Text="Unlock",
	TextScaled=true,
	BackgroundColor3=Color3.fromRGB(200,0,0),
	TextColor3=Color3.new(1,1,1),
	Parent=frame
})
corner(unlock,15)

local hrp
player.CharacterAdded:Connect(function(c)
	hrp=c:WaitForChild("HumanoidRootPart")
end)
if player.Character then hrp=player.Character:WaitForChild("HumanoidRootPart") end


local fastPickup=false

local qtEnabled=false
local timer=0
local lastTeleport=0
local teleportCooldown=false
local nextTeleportIsSell=false

local function getRandomJunkPosition()
	while true do
		local x=math.random(JUNK_MIN_X,JUNK_MAX_X)
		local z=math.random(JUNK_MIN_Z,JUNK_MAX_Z)
		if not (x>=JUNK_EXCL_MIN_X and x<=JUNK_EXCL_MAX_X and z>=JUNK_EXCL_MIN_Z and z<=JUNK_EXCL_MAX_Z) then
			return Vector3.new(x,JUNK_Y,z)
		end
	end
end

local function getPromptWorldPosition(prompt)
	local p=prompt.Parent
	while p and not p:IsA("BasePart") and not p:IsA("Attachment") do
		p=p.Parent
	end
	if p:IsA("Attachment") then
		return p.WorldPosition or (p.Parent.Position+p.Position)
	end
	if p:IsA("BasePart") then return p.Position end
end

local function findNearestPrompt(pos,rad)
	local nearest,best=nil,math.huge
	for _,o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("ProximityPrompt") and o.Enabled then
			local p=getPromptWorldPosition(o)
			if p then
				local d=(p-pos).Magnitude
				if d<=rad and d<best then best=d nearest=o end
			end
		end
	end
	return nearest
end

local function holdPrompt(p,d)
	p:InputHoldBegin()
	task.wait(d)
	p:InputHoldEnd()
end

local function attemptHoldSequence(pos)
	task.wait(HOLD_DELAY_AFTER_TELEPORT)
	for i=1,HOLD_ATTEMPTS do
		local p=findNearestPrompt(pos,HOLD_RADIUS)
		if p then holdPrompt(p,HOLD_DURATION) return end
		task.wait(HOLD_ATTEMPT_INTERVAL)
	end
end

local function doTeleport(pos)
	local now=tick()
	if teleportCooldown and now-lastTeleport<TELEPORT_COOLDOWN then return end
	lastTeleport=now
	teleportCooldown=true
	task.delay(TELEPORT_COOLDOWN,function() teleportCooldown=false end)
	hrp.CFrame=CFrame.new(pos)
	task.spawn(function() attemptHoldSequence(hrp.Position) end)
end

RunService.Heartbeat:Connect(function(dt)
	if not qtEnabled or not hrp then return end
	timer+=dt
	if timer>=TELEPORT_INTERVAL then
		timer-=TELEPORT_INTERVAL
		doTeleport(nextTeleportIsSell and SELL_POS or getRandomJunkPosition())
		nextTeleportIsSell=not nextTeleportIsSell
	end
end)

unlock.MouseButton1Click:Connect(function()
	if keyBox.Text~=KEY then title.Text="WRONG KEY" return end

	TweenService:Create(frame,TweenInfo.new(0.25),{Size=UDim2.new(0,500,0,340)}):Play()

	keyBox.Visible=false
	unlock.Visible=false
	inviteLabel.Visible=false
	copyBtn.Visible=false

	local box=new("Frame",{Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,Parent=frame})
	table.insert(mainContent,box)

	local function btn(text,y)
		local b=new("TextButton",{
			Size=UDim2.new(0.8,0,0,35),
			Position=UDim2.new(0.1,0,y,0),
			Text=text,
			TextScaled=true,
			BackgroundColor3=Color3.fromRGB(30,30,30),
			TextColor3=Color3.new(1,1,1),
			Parent=box
		})
		corner(b,15)
		return b
	end

	local tp=btn("Teleport to Sell",0.15)
	local fast=btn("Fast Pickup (OFF)",0.32)
	local qtBtn=btn("Quantum Teleport (OFF)",0.49)

	local bringLabel=new("TextLabel",{
		Size=UDim2.new(0.4,0,0,35),
		Position=UDim2.new(0.1,0,0.66,0),
		Text="Bring Item:",
		TextScaled=true,
		BackgroundTransparency=1,
		TextColor3=Color3.new(1,1,1),
		Font=Enum.Font.GothamBold,
		Parent=box
	})

	local bringBox=new("TextBox",{
		Size=UDim2.new(0.4,0,0,35),
		Position=UDim2.new(0.5,0,0.66,0),
		PlaceholderText="Type name or 'all'",
		TextScaled=true,
		Font=Enum.Font.Gotham,
		Parent=box
	})
	corner(bringBox,10)

	local infoBtn=new("TextButton",{
		Size=UDim2.new(0,25,0,25),
		Position=UDim2.new(0.92,0,0.66,0),
		Text="i",
		TextScaled=true,
		BackgroundColor3=Color3.fromRGB(50,50,50),
		TextColor3=Color3.new(1,1,1),
		Parent=box
	})
	corner(infoBtn,8)

	local infoGui=new("Frame",{
		Size=UDim2.new(0,300,0,250),
		Position=UDim2.new(0.5,-150,0.5,-125),
		BackgroundColor3=Color3.fromRGB(20,20,20),
		Visible=false,
		Parent=gui
	})
	corner(infoGui,15)
	new("UIStroke",{Thickness=2,Color=Color3.fromRGB(120,0,0),Parent=infoGui})
	new("TextLabel",{Size=UDim2.new(1,0,1,0),Text="Items:\n"..table.concat(itemNames,"\n").."\n\nType 'all' to teleport everything",TextScaled=true,TextColor3=Color3.new(1,1,1),BackgroundTransparency=1,Font=Enum.Font.GothamBold,Parent=infoGui})

	local closeInfoBtn=new("TextButton",{
		Size=UDim2.new(0,25,0,25),
		Position=UDim2.new(1,-30,0,5),
		Text="X",
		TextScaled=true,
		BackgroundColor3=Color3.fromRGB(150,0,0),
		TextColor3=Color3.new(1,1,1),
		Parent=infoGui
	})
	corner(closeInfoBtn,5)

	closeInfoBtn.MouseButton1Click:Connect(function()
		infoGui.Visible=false
	end)

	do
		local dragging,dragStart,posStart
		infoGui.InputBegan:Connect(function(i)
			if i.UserInputType==Enum.UserInputType.MouseButton1 then
				dragging=true
				dragStart=i.Position
				posStart=Vector2.new(infoGui.Position.X.Offset,infoGui.Position.Y.Offset)
				i.Changed:Connect(function()
					if i.UserInputState==Enum.UserInputState.End then dragging=false end
				end)
			end
		end)
		infoGui.InputChanged:Connect(function(i)
			if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
				local d=i.Position-dragStart
				infoGui.Position=UDim2.new(0,posStart.X+d.X,0,posStart.Y+d.Y)
			end
		end)
	end

	infoBtn.MouseButton1Click:Connect(function()
		infoGui.Visible = not infoGui.Visible
	end)

	bringBox.FocusLost:Connect(function(enterPressed)
		if not enterPressed then return end
		local input = bringBox.Text:lower()
		if input=="all" then
			for _,name in ipairs(itemNames) do
				for _,obj in ipairs(Workspace:GetDescendants()) do
					if obj.Name==name and hrp then
						if obj:IsA("Model") and obj.PrimaryPart then
							obj:SetPrimaryPartCFrame(hrp.CFrame + Vector3.new(math.random(-6,6),0,math.random(-6,6)))
						elseif obj:IsA("BasePart") then
							obj.CFrame = hrp.CFrame + Vector3.new(math.random(-6,6),0,math.random(-6,6))
						end
					end
				end
			end
		else
			for _,name in ipairs(itemNames) do
				if name:lower()==input then
					for _,obj in ipairs(Workspace:GetDescendants()) do
						if obj.Name==name and hrp then
							if obj:IsA("Model") and obj.PrimaryPart then
								obj:SetPrimaryPartCFrame(hrp.CFrame + Vector3.new(math.random(-6,6),0,math.random(-6,6)))
							elseif obj:IsA("BasePart") then
								obj.CFrame = hrp.CFrame + Vector3.new(math.random(-6,6),0,math.random(-6,6))
							end
						end
					end
					break
				end
			end
		end
		bringBox.Text=""
	end)

	tp.MouseButton1Click:Connect(function()
		if hrp then hrp.CFrame=CFrame.new(SELL_POS) end
	end)

	fast.MouseButton1Click:Connect(function()
		fastPickup=not fastPickup
		fast.Text=fastPickup and "Fast Pickup (ON)" or "Fast Pickup (OFF)"
		for _,p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("ProximityPrompt") then
				p.HoldDuration=fastPickup and 0.05 or 0.5
			end
		end
	end)

	qtBtn.MouseButton1Click:Connect(function()
		qtEnabled=not qtEnabled
		qtBtn.Text=qtEnabled and "Quantum Teleport (ON)" or "Quantum Teleport (OFF)"
		timer=0
		nextTeleportIsSell=false
	end)
end)
