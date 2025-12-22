-- =====================================
-- ESP + AIMLOCK + OBJECT + RESPAWN ESP
-- =====================================
local CONNECTIONS = {}
_G.HUB_MANAGER = _G.HUB_MANAGER or {}

-- se já tem um script vivo, mata ele
if _G.HUB_MANAGER.kill then
	pcall(_G.HUB_MANAGER.kill)
end

local ALIVE = true

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
repeat task.wait() until player.Character

local Camera = Workspace.CurrentCamera
local Mouse = player:GetMouse()

-- =====================================
-- CONFIG
-- =====================================
local showSurvivors = false
local showKillers = false
local showGenerators = false
local showFakeGenerators = false
local showMinions = false
local showKillerAttacks = false
local showVeronicaSpray = false
local showTwoTimeRespawns = true
local showNames = true
local showHealth = true
local showDistance = true
local showItems = false
local shedletskyEnabled = false
local guestEnabled = false
local aimlockEnabled = false
local shedKeybind = Enum.KeyCode.Q
local guestKeybind = Enum.KeyCode.C
local aimlockKeybind = Enum.KeyCode.Z
local waitingForBind = nil
local fakeBlockEnabled = false
local fakeBlocking = false
local fakeBlockThread = nil
local animationIds = {
    ["126830014841198"] = true, ["126355327951215"] = true, ["121086746534252"] = true,
    ["18885909645"] = true, ["98456918873918"] = true, ["105458270463374"] = true,
    ["83829782357897"] = true, ["125403313786645"] = true, ["118298475669935"] = true,
    ["82113744478546"] = true, ["70371667919898"] = true, ["99135633258223"] = true,
    ["97167027849946"] = true, ["109230267448394"] = true, ["139835501033932"] = true,
    ["126896426760253"] = true,
}
    local fakeBlockOn = false
    local currentMode = "Normal"

    local animations = {
        Normal = "rbxassetid://72722244508749",
        ["M3&4"] = "rbxassetid://96959123077498"
    }
local fakeBlockKeybind = Enum.KeyCode.F



local OBJECT_COLORS = {
	Generator = Color3.fromRGB(255,255,255),
	FakeGenerator = Color3.fromRGB(170,0,255),
	BuildermanDispenser = Color3.fromRGB(0,255,150),
	BuildermanSentry = Color3.fromRGB(255,170,0),
}
local COMPLETED_GEN_COLOR = Color3.fromRGB(120, 255, 120)
local INCOMPLETE_GEN_COLOR = Color3.fromRGB(255, 255, 255)
local DARK_BLUE = Color3.fromRGB(0,40,130)
local ITEM_COLOR = Color3.fromRGB(0,255,0)
local MINION_COLOR = Color3.fromRGB(255,100,0)
local ATTACK_COLOR = Color3.fromRGB(255,0,255)
local SPRAY_COLOR = Color3.fromRGB(255,20,147)

-- =====================================
-- TABLES
-- =====================================
local espHighlights = {}
local objectHighlights = {}
local aimlockHighlight = nil
local completedGenerators = {}

-- =====================================
-- UTILS
-- =====================================
local function KILL_SCRIPT()
	if not ALIVE then return end
	ALIVE = false

	-- limpa conexão
	if CONNECTIONS then
		for _, c in ipairs(CONNECTIONS) do
			pcall(function() c:Disconnect() end)
		end
		table.clear(CONNECTIONS)
	end

	-- limpa highlights
	for _, t in pairs({espHighlights, objectHighlights}) do
		if t then
			for _, h in pairs(t) do
				pcall(function() h:Destroy() end)
			end
		end
	end

	-- mata GUI
	local gui = player:FindFirstChild("PlayerGui")
	if gui then
		local m = gui:FindFirstChild("HackMenu")
		if m then m:Destroy() end
	end

	-- limpa estado
	zTarget = nil
	aimlockEnabled = false
	fakeBlockEnabled = false

	-- remove o kill global
	if _G.HUB_MANAGER and _G.HUB_MANAGER.kill == KILL_SCRIPT then
		_G.HUB_MANAGER.kill = nil
	end

	warn("☠️ hub morto, pode abrir outro agora")

	script:Destroy()
end
_G.HUB_MANAGER.kill = KILL_SCRIPT

local function healthToColor(p)
	p = math.clamp(p, 0, 1)
	if p > 0.5 then
		local t = (p - 0.5) / 0.5
		return Color3.fromRGB(255 * (1 - t), 255, 0)
	else
		local t = p / 0.5
		return Color3.fromRGB(255, 255 * t, 0)
	end
end
-- FAKE BLOCK (só a função, sem frescura)
local function fakeBlock(localPlayer, mode)
	local animations = {
		Normal = "rbxassetid://72722244508749",
		["M3&4"] = "rbxassetid://96959123077498"
	}

	local char = localPlayer.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animId = animations[mode or "Normal"]
	if not animId then return end

	local anim = Instance.new("Animation")
	anim.AnimationId = animId

	local track = humanoid:LoadAnimation(anim)
	track:Play()
end


local function isKiller(plr)
	return plr.Character
		and plr.Character.Parent
		and plr.Character.Parent.Name == "Killers"
end

local function getCharacterName(plr)
	if not plr.Character then return "Unknown" end
	return plr.Character:GetAttribute("Character")
		or plr:GetAttribute("Character")
		or plr.Character.Name
end

local function getDistance(plr)
	if not plr.Character or not player.Character then return "" end
	local a = player.Character:FindFirstChild("HumanoidRootPart")
	local b = plr.Character:FindFirstChild("HumanoidRootPart")
	if not a or not b then return "" end
	return math.floor((a.Position - b.Position).Magnitude) .. " studs"
end

local function getKiller()
	for _, plr in ipairs(Players:GetPlayers()) do
		if isKiller(plr)
			and plr.Character
			and plr.Character:FindFirstChild("HumanoidRootPart") then
			return plr
		end
	end
	return nil
end

local function lookAtKiller(duration)
	local killer = getKiller()
	if not killer then return end

	local hrp = killer.Character.HumanoidRootPart
	local start = tick()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if tick() - start >= duration then
			conn:Disconnect()
			return
		end

		if not hrp or not hrp.Parent then
			conn:Disconnect()
			return
		end

		local camPos = Camera.CFrame.Position
		Camera.CFrame = CFrame.lookAt(camPos, hrp.Position)
	end)
end
local function dragify(handle, frame)
	local UserInputService = game:GetService("UserInputService")

	local dragging = false
	local dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end
local function attackTPToKiller(duration)
	local killer = getKiller()
	if not killer or not killer.Character then return end

	local killerHRP = killer.Character:FindFirstChild("HumanoidRootPart")
	local char = player.Character
	if not char or not killerHRP then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local originalCFrame = hrp.CFrame
	local originalCam = Camera.CFrame

	-- TP: mesma altura (Y IGUAL)
	hrp.CFrame = CFrame.new(
		killerHRP.Position.X,
		killerHRP.Position.Y,
		killerHRP.Position.Z
	)

	-- força câmera no killer
	local start = tick()
	local camConn
	camConn = RunService.RenderStepped:Connect(function()
		if tick() - start >= duration then
			camConn:Disconnect()
			return
		end
		if killerHRP and killerHRP.Parent then
			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, killerHRP.Position)
		end
	end)

	-- volta depois
	task.delay(duration, function()
		if hrp then
			hrp.CFrame = originalCFrame
		end
		Camera.CFrame = originalCam
	end)
end

-- =====================================
local function isGeneratorCompleted(gen)
	if typeof(gen) ~= "Instance" or not gen.Parent then
		return false
	end

	-- cache (não deixa voltar atrás)
	if completedGenerators[gen] then
		return true
	end

	-- Prompt REAL
	local prompt = gen:FindFirstChild("Prompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		-- se o prompt sumiu ou ficou permanentemente off
		if not prompt.Enabled then
			completedGenerators[gen] = true
			return true
		end
	end

	return false
end
-- Monitora mudanças no Progress de cada gerador
local generatorConnections = {}

local function setupGeneratorMonitor(gen)
	if generatorConnections[gen] then return end
	
	local progress = gen:FindFirstChild("Progress", true)
	if not progress or not progress:IsA("NumberValue") then return end
	
	generatorConnections[gen] = progress:GetPropertyChangedSignal("Value"):Connect(function()
		if progress.Value >= 100 then
			completedGenerators[gen] = true
		end
	end)
end

-- =====================================
-- RESPAWN ESP
-- =====================================
local function isPlayerRespawnLocation(name)
	if not string.match(name, "RespawnLocation$") then return false end
	for _, plr in ipairs(Players:GetPlayers()) do
		if name == plr.Name .. "RespawnLocation" then
			return true
		end
	end
	return false
end

local function lentidaoTemporaria(speed, tempo)
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local original = humanoid.WalkSpeed
	humanoid.WalkSpeed = speed

	task.delay(tempo, function()
		if humanoid then
			humanoid.WalkSpeed = original
		end
	end)
end
local function highlightRespawn(obj)
	if objectHighlights[obj] then return end
	if not showTwoTimeRespawns then return end

	local adornee = nil

	if obj:IsA("BasePart") then
		adornee = obj
	else
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				adornee = d
				break
			end
		end
	end

	if not adornee then
		local proxy = Instance.new("Part")
		proxy.Name = "_RespawnProxy"
		proxy.Size = Vector3.new(3,3,3)
		proxy.CFrame = obj:GetPivot()
		proxy.Anchored = true
		proxy.CanCollide = false
		proxy.Transparency = 1
		proxy.Parent = obj

		adornee = proxy
	end

	local h = Instance.new("Highlight")
	h.Adornee = adornee
	h.FillColor = DARK_BLUE
	h.OutlineColor = DARK_BLUE
	h.FillTransparency = 0.25
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = adornee

	objectHighlights[obj] = h
end

local function scanRespawnLocations()
	local map = Workspace:FindFirstChild("Map")
	local ingame = map and map:FindFirstChild("Ingame")
	if not ingame then return end

	for _, obj in ipairs(ingame:GetDescendants()) do
		if (obj:IsA("BasePart") or obj:IsA("Model"))
			and isPlayerRespawnLocation(obj.Name) then
			highlightRespawn(obj)
		end
	end

	ingame.DescendantAdded:Connect(function(obj)
		if (obj:IsA("BasePart") or obj:IsA("Model"))
			and isPlayerRespawnLocation(obj.Name) then
			task.wait()
			highlightRespawn(obj)
		end
	end)
end

-- =====================================
-- PLAYER ESP
-- =====================================
local function createCharacterTag(plr)
	if not plr.Character then return end
	if plr.Character:FindFirstChild("CharacterTag") then return end

	local head = plr.Character:FindFirstChild("Head")
	if not head then return end

	local gui = Instance.new("BillboardGui")
	gui.Name = "CharacterTag"
	gui.Adornee = head
	gui.Size = UDim2.new(0,200,0,65)
	gui.StudsOffset = Vector3.new(0,2.8,0)
	gui.AlwaysOnTop = true
	gui.Parent = plr.Character

	local function makeLabel(y, size)
		local t = Instance.new("TextLabel", gui)
		t.Position = UDim2.new(0,0,y,0)
		t.Size = size
		t.BackgroundTransparency = 1
		t.TextScaled = true
		t.Font = Enum.Font.GothamBold
		t.TextStrokeTransparency = 0
		t.Text = ""
		t.TextColor3 = Color3.new(1, 1, 1)
		return t
	end

	local nameLabel = makeLabel(0, UDim2.new(1,0,0.4,0))
	local distLabel = makeLabel(0.4, UDim2.new(1,0,0.3,0))
	local hpLabel   = makeLabel(0.7, UDim2.new(1,0,0.3,0))

	local charName = getCharacterName(plr)
	if isKiller(plr) then
		nameLabel.TextColor3 = Color3.fromRGB(255,60,60)
		nameLabel.Text = showNames and ("🔪 "..charName) or ""
	else
		nameLabel.TextColor3 = Color3.fromRGB(80,170,255)
		nameLabel.Text = showNames and ("🧍 "..charName) or ""
	end

	task.spawn(function()
		while gui and gui.Parent and plr and plr.Parent do
			if showDistance then
				distLabel.Text = getDistance(plr)
			else
				distLabel.Text = ""
			end
			
			if showHealth and plr.Character then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					if hum.MaxHealth > 0 then
						local p = hum.Health / hum.MaxHealth
						hpLabel.Text = "❤️ "..math.floor(p*100).."%"
						hpLabel.TextColor3 = healthToColor(p)
					else
						hpLabel.Text = "❤️ 0%"
						hpLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
					end
				else
					hpLabel.Text = ""
				end
			else
				hpLabel.Text = ""
			end
			
			if showNames then
				local charName = getCharacterName(plr)
				if isKiller(plr) then
					nameLabel.TextColor3 = Color3.fromRGB(255,60,60)
					nameLabel.Text = "🔪 "..charName
				else
					nameLabel.TextColor3 = Color3.fromRGB(80,170,255)
					nameLabel.Text = "🧍 "..charName
				end
			else
				nameLabel.Text = ""
			end
			
			task.wait(0.2)
		end
	end)
end

local function updatePlayerESP()
	for plr, h in pairs(espHighlights) do
		h:Destroy()
		espHighlights[plr] = nil
	end
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			local tag = plr.Character:FindFirstChild("CharacterTag")
			if tag then tag:Destroy() end
		end
	end
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character then
			local shouldShow = (isKiller(plr) and showKillers) or (not isKiller(plr) and showSurvivors)
			
			if shouldShow then
				local h = Instance.new("Highlight")
				h.Adornee = plr.Character
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.FillTransparency = 0.5
				h.OutlineTransparency = 0
				h.FillColor = isKiller(plr)
					and Color3.fromRGB(255,0,0)
					or Color3.fromRGB(0,100,255)
				h.Parent = Workspace
				espHighlights[plr] = h
				createCharacterTag(plr)
			end
		end
	end
end

-- =====================================
-- OBJECT ESP
-- =====================================
local function updateObjectESP()
	for obj, h in pairs(objectHighlights) do
		if obj.Name ~= "_RespawnProxy" and not obj.Name:match("RespawnLocation$") and not h:GetAttribute("MinionESP") and not h:GetAttribute("AttackESP") and not h:GetAttribute("SprayESP") then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end
	
	local map = Workspace:FindFirstChild("Map")
	local ingame = map and map:FindFirstChild("Ingame")
	local mapModel = ingame and ingame:FindFirstChild("Map")
	if not mapModel then return end

	for _, obj in ipairs(mapModel:GetDescendants()) do
		if obj:IsA("Model") then
			local shouldShow = false
			
			if obj.Name == "Generator" and showGenerators then
				shouldShow = true
			elseif obj.Name == "FakeGenerator" and showFakeGenerators then
				shouldShow = true
			end
			
			if shouldShow and not objectHighlights[obj] then
				local color = OBJECT_COLORS[obj.Name]
				if color then
					local h = Instance.new("Highlight")
					h.Adornee = obj
					
					-- Se for gerador, verifica se está completo
					if obj.Name == "Generator" then
						setupGeneratorMonitor(obj)
						local completed = isGeneratorCompleted(obj)
						h.FillColor = completed and COMPLETED_GEN_COLOR or INCOMPLETE_GEN_COLOR
						h.OutlineColor = completed and COMPLETED_GEN_COLOR or INCOMPLETE_GEN_COLOR
					else
						h.FillColor = color
						h.OutlineColor = color
					end
					
					h.FillTransparency = 0.35
					h.OutlineTransparency = 0
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = obj
					objectHighlights[obj] = h
				end
			end
		end
	end
end
local function playBlockAnimOnly()
	local char = player.Character
	if not char then return end

	local anims = char:FindFirstChild("Animations")
	if not anims then return end

	local blockAnim = anims:FindFirstChild("Block")
	if not blockAnim then
		warn("Sem animação Block, porra")
		return
	end

	blockAnim:Play(0.175)
end

local function updateRespawnESP()
	for obj, h in pairs(objectHighlights) do
		if obj.Name:match("RespawnLocation$") or obj.Name == "_RespawnProxy" then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end

	if not showTwoTimeRespawns then return end

	local map = Workspace:FindFirstChild("Map")
	local ingame = map and map:FindFirstChild("Ingame")
	if not ingame then return end

	for _, obj in ipairs(ingame:GetDescendants()) do
		if (obj:IsA("BasePart") or obj:IsA("Model"))
			and isPlayerRespawnLocation(obj.Name) then
			highlightRespawn(obj)
		end
	end
end

local function updateItemESP()
	for obj, h in pairs(objectHighlights) do
		if obj:IsA("Tool") then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end

	if not showItems then return end

	local map = Workspace:FindFirstChild("Map")
	local ingame = map and map:FindFirstChild("Ingame")
	local mapModel = ingame and ingame:FindFirstChild("Map")
	if not mapModel then return end

	for _, obj in ipairs(mapModel:GetDescendants()) do
		if obj:IsA("Tool") and (obj.Name == "BloxyCola" or obj.Name == "Medkit") then
			if not objectHighlights[obj] then
				local h = Instance.new("Highlight")
				h.Adornee = obj
				h.FillColor = ITEM_COLOR
				h.OutlineColor = ITEM_COLOR
				h.FillTransparency = 0.3
				h.OutlineTransparency = 0
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h.Parent = obj
				objectHighlights[obj] = h
			end
		end
	end
end

local function updateMinionESP()
	for obj, h in pairs(objectHighlights) do
		if h:GetAttribute("MinionESP") then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end

	if not showMinions then return end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name == "1x1x1x1Zombie" or obj.Name == "Mafia1") then
			if not objectHighlights[obj] then
				local h = Instance.new("Highlight")
				h.Adornee = obj
				h.FillColor = MINION_COLOR
				h.OutlineColor = MINION_COLOR
				h.FillTransparency = 0.3
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h:SetAttribute("MinionESP", true)
				h.Parent = obj

				objectHighlights[obj] = h
			end
		end
	end
end

local function updateKillerAttackESP()
	for obj, h in pairs(objectHighlights) do
		if h:GetAttribute("AttackESP") then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end

	if not showKillerAttacks then return end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if (obj:IsA("Part") or obj:IsA("MeshPart")) then
			local name = obj.Name:lower()
			if name:find("hit") or name:find("attack") or name:find("slash") or name:find("puddle") or name:find("spike") then
				if not objectHighlights[obj] then
					local h = Instance.new("Highlight")
					h.Adornee = obj
					h.FillColor = ATTACK_COLOR
					h.OutlineColor = ATTACK_COLOR
					h.FillTransparency = 0.4
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h:SetAttribute("AttackESP", true)
					h.Parent = obj

					objectHighlights[obj] = h
				end
			end
		end
	end
end

local function updateVeronicaSprayESP()
	for obj, h in pairs(objectHighlights) do
		if h:GetAttribute("SprayESP") then
			h:Destroy()
			objectHighlights[obj] = nil
		end
	end

	if not showVeronicaSpray then return end

	for _, obj in ipairs(Workspace:GetDescendants()) do
		if (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart")) and obj.Name:lower():find("spray") then
			if not objectHighlights[obj] then
				local h = Instance.new("Highlight")
				h.Adornee = obj
				h.FillColor = SPRAY_COLOR
				h.OutlineColor = SPRAY_COLOR
				h.FillTransparency = 0.3
				h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				h:SetAttribute("SprayESP", true)
				h.Parent = obj

				objectHighlights[obj] = h
			end
		end
	end
end
-- 🔁 atualização em tempo real do Veronica Spray
Workspace.DescendantAdded:Connect(function(obj)
	if not showVeronicaSpray then return end

	if (obj:IsA("Model") or obj:IsA("Part") or obj:IsA("MeshPart"))
		and obj.Name:lower():find("spray") then

		task.wait() -- espera spawnar tudo certinho
		updateVeronicaSprayESP()
	end
end)

Workspace.DescendantRemoving:Connect(function(obj)
	if objectHighlights[obj] and objectHighlights[obj]:GetAttribute("SprayESP") then
		objectHighlights[obj]:Destroy()
		objectHighlights[obj] = nil
	end
end)

RunService.Heartbeat:Connect(function()
	if not showGenerators then return end

	for obj, h in pairs(objectHighlights) do
		-- blindagem anti-crash
		if typeof(obj) ~= "Instance" then
			objectHighlights[obj] = nil
			continue
		end
		print("[GEN CHECK]", obj, obj.Parent ~= nil)
		if not obj.Parent then
			if h then h:Destroy() end
			objectHighlights[obj] = nil
			continue
		end

		if not h or not h:IsA("Highlight") then
			objectHighlights[obj] = nil
			continue
		end

		if obj.Name == "Generator" then
			local completed = isGeneratorCompleted(obj)
			h.FillColor = completed and COMPLETED_GEN_COLOR or INCOMPLETE_GEN_COLOR
			h.OutlineColor = completed and COMPLETED_GEN_COLOR or INCOMPLETE_GEN_COLOR
		end
	end
end)


-- =====================================
-- AIMLOCK
-- =====================================
local zTarget = nil
local lerpSpeed = 0.06

local function updateAimlockHighlight()
	if aimlockHighlight then
		aimlockHighlight:Destroy()
		aimlockHighlight = nil
	end
	
	if zTarget and zTarget.Character then
		local h = Instance.new("Highlight")
		h.Adornee = zTarget.Character
		h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		h.FillTransparency = 0.3
		h.OutlineTransparency = 0
		h.FillColor = Color3.fromRGB(0, 50, 150)
		h.OutlineColor = Color3.fromRGB(0, 100, 255)
		h.Parent = Workspace
		aimlockHighlight = h
	end
end

local function handleAimlockInput(input, gp)
	if gp then return end
	if not aimlockEnabled then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if input.KeyCode ~= aimlockKeybind then return end

	if zTarget then
		zTarget = nil
		updateAimlockHighlight()
		return
	end

	local target = Mouse.Target
	if not target then return end

	local model = target:FindFirstAncestorOfClass("Model")
	local plr = Players:GetPlayerFromCharacter(model)
	if not plr or plr == player then return end

	zTarget = plr
	updateAimlockHighlight()
end

table.insert(CONNECTIONS,
    RunService.RenderStepped:Connect(function()
        if not aimlockEnabled or not zTarget or not zTarget.Character then return end
        local hrp = zTarget.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local camPos = Camera.CFrame.Position
        local pos = hrp.Position
        local newPos = camPos:Lerp(pos + Vector3.new(0,5,15), lerpSpeed)
        Camera.CFrame = CFrame.lookAt(newPos, pos)
    end)
)


-- MENU COM PÁGINAS

-- 🔥 mata qualquer menu antigo antes
local old = player.PlayerGui:FindFirstChild("HackMenu")
if old then
	old:Destroy()
end

local menuGui = Instance.new("ScreenGui")
menuGui.Name = "HackMenu"
menuGui.ResetOnSpawn = false
menuGui.Parent = player.PlayerGui

local menuOpen = false

local GUI_WIDTH = 800
local GUI_HEIGHT = 500

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, GUI_WIDTH, 0, GUI_HEIGHT)
frame.Position = UDim2.new(0.5, -GUI_WIDTH/2, 0.5, -GUI_HEIGHT/2)
frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
frame.Visible = false
frame.Parent = menuGui
local TweenService = game:GetService("TweenService")

task.wait() -- garante que o Size do frame já existe

local CLOSED_POS = UDim2.new(
	0.5, -frame.Size.X.Offset/2,
	1.2, 0
)

local OPEN_POS = UDim2.new(
	0.5, -frame.Size.X.Offset/2,
	0.5, -frame.Size.Y.Offset/2
)

frame.Position = CLOSED_POS
frame.Visible = false

local openTween = TweenService:Create(
	frame,
	TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	{ Position = OPEN_POS }
)

local closeTween = TweenService:Create(
	frame,
	TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	{ Position = CLOSED_POS }
)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(225,15,0)
stroke.Thickness = 2
stroke.Parent = frame

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1,0,0,40)
title.BackgroundTransparency = 1
title.Text = "Forsaken Scripthub"
title.TextColor3 = Color3.fromRGB(255,255,255)
title.Font = Enum.Font.GothamBold
title.TextSize = 24
title.Active = true
dragify(title, frame)

local pageLabel = Instance.new("TextLabel", frame)
pageLabel.Size = UDim2.new(1,0,0,25)
pageLabel.Position = UDim2.new(0,0,0,40)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "ESP"
pageLabel.TextColor3 = Color3.fromRGB(200,200,200)
pageLabel.Font = Enum.Font.Arial
pageLabel.TextSize = 16

local content = Instance.new("Frame", frame)
content.Size = UDim2.new(1, -40, 1, -150)
content.Position = UDim2.new(0, 20, 0, 75)
content.BackgroundTransparency = 1

local pages = {}
local pageNames = {}
local currentPage = 1

local function createPage(name)
	local p = Instance.new("Frame", content)
	p.Size = UDim2.new(1,0,1,0)
	p.BackgroundTransparency = 1
	p.Visible = false

	local l = Instance.new("UIGridLayout", p)
	l.CellSize = UDim2.new(0, 200, 0, 35)
	l.CellPadding = UDim2.new(0, 10, 0, 10)
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Top

	table.insert(pages, p)
	table.insert(pageNames, name)
	return p
end

local function showPage(index)
	for i, p in ipairs(pages) do
		p.Visible = (i == index)
	end
	currentPage = index
	pageLabel.Text = pageNames[index]
end

local function createButton(parent, text)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(0, 200, 0, 35)
	b.Text = text
	b.Font = Enum.Font.Arial
	b.TextSize = 14
	b.BackgroundColor3 = Color3.fromRGB(0,0,0)
	b.TextColor3 = Color3.new(1,1,1)

	local s = Instance.new("UIStroke", b)
	s.Color = Color3.fromRGB(0,0,0)
	s.Thickness = 2

	return b
end

-- =====================================
-- PÁGINA 1: ESP
-- =====================================
local page1 = createPage("ESP")

local allBtn, survivorBtn, killerBtn, genBtn, fakeGenBtn, itemsBtn, minionBtn, attackBtn, sprayBtn, respawnBtn, namesBtn, healthBtn, distBtn

allBtn = createButton(page1, "SHOW ALL")
survivorBtn = createButton(page1, "SHOW SURVIVORS")
killerBtn = createButton(page1, "SHOW KILLERS")
genBtn = createButton(page1, "SHOW GENERATORS")
fakeGenBtn = createButton(page1, "SHOW FAKE GEN")
itemsBtn = createButton(page1, "SHOW ITEMS")
minionBtn = createButton(page1, "SHOW MINIONS")
attackBtn = createButton(page1, "SHOW KILLER ATTACKS")
sprayBtn = createButton(page1, "VERONICA SPRAY")
respawnBtn = createButton(page1, "HIDE TWO TIME RESPAWNS")
namesBtn = createButton(page1, "HIDE NAMES")
healthBtn = createButton(page1, "HIDE HEALTH")
distBtn = createButton(page1, "HIDE DISTANCE")

allBtn.MouseButton1Click:Connect(function()
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray

	if anyActive then
		showSurvivors = false
		showKillers = false
		showGenerators = false
		showFakeGenerators = false
		showItems = false
		showMinions = false
		showKillerAttacks = false
		showVeronicaSpray = false

		allBtn.Text = "SHOW ALL"
		survivorBtn.Text = "SHOW SURVIVORS"
		killerBtn.Text = "SHOW KILLERS"
		genBtn.Text = "SHOW GENERATORS"
		fakeGenBtn.Text = "SHOW FAKE GEN"
		itemsBtn.Text = "SHOW ITEMS"
		minionBtn.Text = "SHOW MINIONS"
		attackBtn.Text = "SHOW KILLER ATTACKS"
		sprayBtn.Text = "VERONICA SPRAY"
	else
		showSurvivors = true
		showKillers = true
		showGenerators = true
		showFakeGenerators = true
		showItems = true
		showMinions = true
		showKillerAttacks = true
		showVeronicaSpray = true

		allBtn.Text = "DISABLE ALL"
		survivorBtn.Text = "HIDE SURVIVORS"
		killerBtn.Text = "HIDE KILLERS"
		genBtn.Text = "HIDE GENERATORS"
		fakeGenBtn.Text = "HIDE FAKE GEN"
		itemsBtn.Text = "HIDE ITEMS"
		minionBtn.Text = "HIDE MINIONS"
		attackBtn.Text = "HIDE KILLER ATTACKS"
		sprayBtn.Text = "HIDE VERONICA SPRAY"
	end

	updatePlayerESP()
	updateObjectESP()
	updateItemESP()
	updateMinionESP()
	updateKillerAttackESP()
	updateVeronicaSprayESP()
end)

survivorBtn.MouseButton1Click:Connect(function()
	showSurvivors = not showSurvivors
	survivorBtn.Text = showSurvivors and "HIDE SURVIVORS" or "SHOW SURVIVORS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updatePlayerESP()
end)

killerBtn.MouseButton1Click:Connect(function()
	showKillers = not showKillers
	killerBtn.Text = showKillers and "HIDE KILLERS" or "SHOW KILLERS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updatePlayerESP()
end)

genBtn.MouseButton1Click:Connect(function()
	showGenerators = not showGenerators
	genBtn.Text = showGenerators and "HIDE GENERATORS" or "SHOW GENERATORS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateObjectESP()
end)

fakeGenBtn.MouseButton1Click:Connect(function()
	showFakeGenerators = not showFakeGenerators
	fakeGenBtn.Text = showFakeGenerators and "HIDE FAKE GEN" or "SHOW FAKE GEN"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateObjectESP()
end)

itemsBtn.MouseButton1Click:Connect(function()
	showItems = not showItems
	itemsBtn.Text = showItems and "HIDE ITEMS" or "SHOW ITEMS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateItemESP()
end)

minionBtn.MouseButton1Click:Connect(function()
	showMinions = not showMinions
	minionBtn.Text = showMinions and "HIDE MINIONS" or "SHOW MINIONS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateMinionESP()
end)

attackBtn.MouseButton1Click:Connect(function()
	showKillerAttacks = not showKillerAttacks
	attackBtn.Text = showKillerAttacks and "HIDE KILLER ATTACKS" or "SHOW KILLER ATTACKS"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateKillerAttackESP()
end)

sprayBtn.MouseButton1Click:Connect(function()
	showVeronicaSpray = not showVeronicaSpray
	sprayBtn.Text = showVeronicaSpray and "HIDE VERONICA SPRAY" or "VERONICA SPRAY"
	
	local anyActive = showSurvivors or showKillers or showGenerators or showFakeGenerators or showItems or showMinions or showKillerAttacks or showVeronicaSpray
	allBtn.Text = anyActive and "DISABLE ALL" or "SHOW ALL"
	
	updateVeronicaSprayESP()
end)

respawnBtn.MouseButton1Click:Connect(function()
	showTwoTimeRespawns = not showTwoTimeRespawns
	respawnBtn.Text = showTwoTimeRespawns and "HIDE TWO TIME RESPAWNS" or "SHOW TWO TIME RESPAWNS"
	
	updateRespawnESP()
end)

namesBtn.MouseButton1Click:Connect(function()
	showNames = not showNames
	namesBtn.Text = showNames and "HIDE NAMES" or "SHOW NAMES"
end)

healthBtn.MouseButton1Click:Connect(function()
	showHealth = not showHealth
	healthBtn.Text = showHealth and "HIDE HEALTH" or "SHOW HEALTH"
end)

distBtn.MouseButton1Click:Connect(function()
	showDistance = not showDistance
	distBtn.Text = showDistance and "HIDE DISTANCE" or "SHOW DISTANCE"
end)

-- =====================================
-- PÁGINA 2: SURVIVOR
-- =====================================
local page2 = createPage("SURVIVOR")

local shedBtn, shedBindBtn, guestBtn, guestBindBtn, noAbilityLabel
local function forceBlockAnimation()
	local char = player.Character
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	local animFolder = char:FindFirstChild("Animations")
	if not animFolder then
		warn("sem pasta Animations")
		return
	end

	local anim = animFolder:FindFirstChild("Block")
	if not anim or not anim:IsA("Animation") then
		warn("Block não é Animation, caralho")
		return
	end

	local track = animator:LoadAnimation(anim)
	track:Play(0.175)
	
end

local function updateSurvivorPage()
	-- Limpa tudo da página
	for _, child in ipairs(page2:GetChildren()) do
		if child:IsA("GuiObject") and child ~= page2:FindFirstChildOfClass("UIGridLayout") then
			child:Destroy()
		end
	end
	
	shedBtn = nil
	shedBindBtn = nil
	guestBtn = nil
	guestBindBtn = nil
	noAbilityLabel = nil
	
	local charName = getCharacterName(player)
	local isShedletsky = (charName == "Shedletsky")
	local isGuest = (charName == "Guest1337")

	if isShedletsky then
		shedBtn = createButton(page2, "ENABLE SHEDLETSKY AUTO-AIM")
		shedBtn.TextSize = 12

		shedBindBtn = createButton(page2, "KEY: Q")
		shedBindBtn.Size = UDim2.new(0, 200, 0, 30)
		shedBindBtn.TextSize = 12

		shedBtn.MouseButton1Click:Connect(function()
			shedletskyEnabled = not shedletskyEnabled
			shedBtn.Text = shedletskyEnabled and "DISABLE SHEDLETSKY AUTO-AIM" or "ENABLE SHEDLETSKY AUTO-AIM"
		end)

		shedBindBtn.MouseButton1Click:Connect(function()
			shedBindBtn.Text = "PRESS ANY KEY..."
			waitingForBind = "shed"
		end)
		-- TEXTO BETA
local betaLabel = Instance.new("TextLabel", page2)
betaLabel.Size = UDim2.new(1, 0, 0, 40)
betaLabel.BackgroundTransparency = 1
betaLabel.TextWrapped = true
betaLabel.TextYAlignment = Enum.TextYAlignment.Top
betaLabel.Text = "BETA\nstuff that might get you clipped"
betaLabel.Font = Enum.Font.GothamBold
betaLabel.TextSize = 13
betaLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
local attackTPEnabled = false

local attackTPBtn = createButton(page2, "ENABLE ATTACK TP TO KILLER")
attackTPBtn.TextSize = 12

attackTPBtn.MouseButton1Click:Connect(function()
	attackTPEnabled = not attackTPEnabled
	attackTPBtn.Text = attackTPEnabled
		and "DISABLE ATTACK TP TO KILLER"
		or "ENABLE ATTACK TP TO KILLER"
end)

	end

	if isGuest then
		guestBtn = createButton(page2, "ENABLE GUEST1337 AUTO-AIM")
		guestBtn.TextSize = 12

		guestBindBtn = createButton(page2, "KEY: C")
		guestBindBtn.Size = UDim2.new(0, 200, 0, 30)
		guestBindBtn.TextSize = 12

		guestBtn.MouseButton1Click:Connect(function()
			guestEnabled = not guestEnabled
			guestBtn.Text = guestEnabled and "DISABLE GUEST1337 AUTO-AIM" or "ENABLE GUEST1337 AUTO-AIM"
		end)
guestBindBtn.MouseButton1Click:Connect(function()
			guestBindBtn.Text = "PRESS ANY KEY..."
			waitingForBind = "guest"
		end)
			-- botão FAKE BLOCK (AGORA DENTRO DA FUNÇÃO)
	local fakeBlockBtn = createButton(page2, "ENABLE FAKE BLOCK")
	fakeBlockBtn.TextSize = 12

	fakeBlockBtn.MouseButton1Click:Connect(function()
		fakeBlockEnabled = not fakeBlockEnabled
		fakeBlockBtn.Text = fakeBlockEnabled
			and "DISABLE FAKE BLOCK"
			or "ENABLE FAKE BLOCK"
	end)

	fakeBlockBindBtn = createButton(page2, "KEY: F")
	fakeBlockBindBtn.Size = UDim2.new(0, 200, 0, 30)
	fakeBlockBindBtn.TextSize = 12
	fakeBlockBindBtn.MouseButton1Click:Connect(function()
		fakeBlockBindBtn.Text = "PRESS ANY KEY..."
		waitingForBind = "fakeblock"
	end)
	end

	if not isShedletsky and not isGuest then
		noAbilityLabel = Instance.new("TextLabel", page2)
		noAbilityLabel.Size = UDim2.new(0.8, 0, 0, 50)
		noAbilityLabel.BackgroundTransparency = 1
		noAbilityLabel.Text = "No survivor abilities available\nfor this character"
		noAbilityLabel.TextColor3 = Color3.fromRGB(150,150,150)
		noAbilityLabel.Font = Enum.Font.Arial
		noAbilityLabel.TextSize = 14
		noAbilityLabel.TextWrapped = true
	end
end

updateSurvivorPage()

-- Detecta quando o personagem muda
player.CharacterAdded:Connect(function(char)
	task.wait(0.5) -- Espera o atributo carregar
	updateSurvivorPage()
end)

-- Detecta quando o atributo Character muda
if player.Character then
	player.Character:GetAttributeChangedSignal("Character"):Connect(function()
		updateSurvivorPage()
	end)
end

player:GetAttributeChangedSignal("Character"):Connect(function()
	updateSurvivorPage()
end)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

	-- =============================
	-- 🔑 CAPTURA DE KEYBINDS (PRIMEIRO)
	-- =============================
	if waitingForBind then
		if waitingForBind == "shed" and shedBindBtn then
			shedKeybind = input.KeyCode
			shedBindBtn.Text = "KEY: "..input.KeyCode.Name

		elseif waitingForBind == "guest" and guestBindBtn then
			guestKeybind = input.KeyCode
			guestBindBtn.Text = "KEY: "..input.KeyCode.Name

		elseif waitingForBind == "aimlock" and aimBindBtn then
			aimlockKeybind = input.KeyCode
			aimBindBtn.Text = "KEY: "..input.KeyCode.Name

		elseif waitingForBind == "fakeblock" and fakeBlockBindBtn then
			fakeBlockKeybind = input.KeyCode
			fakeBlockBindBtn.Text = "KEY: "..input.KeyCode.Name
		end

		waitingForBind = nil
		return -- ISSO É O QUE TU NÃO TINHA
	end

	-- =============================
	-- 🛡️ FAKE BLOCK
	-- =============================
	if input.KeyCode == fakeBlockKeybind and fakeBlockEnabled then
		if getCharacterName(player) == "Guest1337" then
			fakeBlock(player, "Normal")
			lentidaoTemporaria(4, 1.1)
			return
		end
	end

	-- =============================
	-- 🎯 OUTROS BINDS
	-- =============================
if input.KeyCode == shedKeybind and shedletskyEnabled then
		if getCharacterName(player) == "Shedletsky" then
			lookAtKiller(0.75)

			if attackTPEnabled then
				attackTPToKiller(1)
			end
		end

	elseif input.KeyCode == guestKeybind and guestEnabled then
		if getCharacterName(player) == "Guest1337" then
			lookAtKiller(0.75)
		end

	elseif input.KeyCode == aimlockKeybind and aimlockEnabled then
		handleAimlockInput(input, gp)

	elseif input.KeyCode == Enum.KeyCode.Delete then
		menuOpen = not menuOpen
		if menuOpen then
			frame.Visible = true
			openTween:Play()
		else
			closeTween:Play()
			task.delay(0.15, function()
				if not menuOpen then
					frame.Visible = false
				end
			end)
		end
	end
end)




-- =====================================
-- PÁGINA 3: KILLER
-- =====================================
local page3 = createPage("KILLER")

local aimBtn = createButton(page3, "ENABLE AIMLOCK")
local aimBindBtn = createButton(page3, "KEY: Z")
aimBindBtn.Size = UDim2.new(0, 200, 0, 30)
aimBindBtn.TextSize = 12

aimBtn.MouseButton1Click:Connect(function()
	aimlockEnabled = not aimlockEnabled
	if not aimlockEnabled then
		zTarget = nil
		updateAimlockHighlight()
	end
	aimBtn.Text = aimlockEnabled and "DISABLE AIMLOCK" or "ENABLE AIMLOCK"
end)

aimBindBtn.MouseButton1Click:Connect(function()
	aimBindBtn.Text = "PRESS ANY KEY..."
	waitingForBind = "aimlock"
end)
local pageConfigs = createPage("CONFIGS")
local killBtn = createButton(pageConfigs, "☠️ KILL SWITCH")
killBtn.TextColor3 = Color3.fromRGB(255, 60, 60)
killBtn.TextSize = 16

killBtn.MouseButton1Click:Connect(function()
	KILL_SCRIPT()
end)

-- NAVEGAÇÃO
local nav = Instance.new("Frame", frame)
nav.Size = UDim2.new(1,0,0,50)
nav.Position = UDim2.new(0,0,1,-60)
nav.BackgroundTransparency = 1

local left = Instance.new("TextButton", nav)
left.Size = UDim2.new(0,50,0,35)
left.Position = UDim2.new(0,20,0,7.5)
left.Text = "←"
left.Font = Enum.Font.GothamBold
left.TextSize = 24
left.BackgroundColor3 = Color3.fromRGB(0,0,0)
left.TextColor3 = Color3.new(1,1,1)

local sl = Instance.new("UIStroke", left)
sl.Color = Color3.fromRGB(255,0,0)
sl.Thickness = 2

local right = Instance.new("TextButton", nav)
right.Size = UDim2.new(0,50,0,35)
right.Position = UDim2.new(1,-70,0,7.5)
right.Text = "→"
right.Font = Enum.Font.GothamBold
right.TextSize = 24
right.BackgroundColor3 = Color3.fromRGB(0,0,0)
right.TextColor3 = Color3.new(1,1,1)

local sr = Instance.new("UIStroke", right)
sr.Color = Color3.fromRGB(255,0,0)
sr.Thickness = 2

left.MouseButton1Click:Connect(function()
	if currentPage > 1 then
		showPage(currentPage - 1)
	end
end)

right.MouseButton1Click:Connect(function()
	if currentPage < #pages then
		showPage(currentPage + 1)
	end
end)

showPage(1)

-- SCAN INICIAL DE RESPAWNS
scanRespawnLocations()

print("🔥 Script carregado - 3 PÁGINAS: ESP | SURVIVOR | KILLER")
