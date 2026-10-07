local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.RegionSystem.Config)
local Regions = workspace:WaitForChild("Regions")

local RegionService = {}
local playerStates = {} -- character, contacts, and connections for each player
local volumeConnections = {} -- touch connections belonging to each region part
local started = false
local refreshAllQueued = false

local entered = Instance.new("BindableEvent")
local exited = Instance.new("BindableEvent")
local changed = Instance.new("BindableEvent")

RegionService.Entered = entered.Event -- player, region name
RegionService.Exited = exited.Event -- player, region name
RegionService.Changed = changed.Event -- player, new region, previous region

-- only used for spawn, exit confirmation, or an explicit refresh
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { Regions }
overlap.RespectCanCollide = false -- trigger parts dont need to block the player

-- stop listening when a character or region part is removed
local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

-- a models child parts all use the models name in Config
local function getRegionKey(part)
	local region = part
	while region and region.Parent ~= Regions do
		region = region.Parent
	end
	return region and Config.Regions[region.Name] and region.Name or nil
end

-- touching another limb or part in the same region wont replay the banner and or lighting
local function setRegion(player, regionKey)
	local state = playerStates[player]
	local previous = state.CurrentRegion
	if previous == regionKey then
		return
	end

	state.CurrentRegion = regionKey
	player:SetAttribute("CurrentRegion", regionKey or "")
	if previous then
		exited:Fire(player, previous)
	end
	if regionKey then
		entered:Fire(player, regionKey)
	end
	changed:Fire(player, regionKey, previous)
end

-- keep all body part contacts, so one part leaving isnt a full exit
local function chooseRegion(state)
	local bestRegion = nil
	local bestPriority = -math.huge
	for volume, bodyParts in pairs(state.Contacts) do
		for bodyPart in pairs(bodyParts) do
			if bodyPart.Parent ~= state.Character or not bodyPart.CanTouch then
				bodyParts[bodyPart] = nil
			end
		end

		local key = volumeConnections[volume] and getRegionKey(volume)
		if not key or not next(bodyParts) then
			state.Contacts[volume] = nil
			continue
		end

		local priority = Config.Regions[key].Priority or 0
		local winsTie = priority == bestPriority and (not bestRegion or key < bestRegion)
		if priority > bestPriority or winsTie then
			bestRegion = key
			bestPriority = priority
		end
	end
	return bestRegion
end

-- call after PivotTo/CFrame teleports, those moves can skip touch events
function RegionService.Refresh(player)
	local state = playerStates[player]
	if not state then
		return
	end

	state.Contacts = {}
	local character = state.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		setRegion(player, nil)
		return
	end

	-- direct body parts only. hats / tools should not trigger region
	for _, bodyPart in ipairs(character:GetChildren()) do
		if not bodyPart:IsA("BasePart") or not bodyPart.CanTouch then
			continue
		end
		for _, volume in ipairs(workspace:GetPartsInPart(bodyPart, overlap)) do
			if volumeConnections[volume] then
				state.Contacts[volume] = state.Contacts[volume] or {}
				state.Contacts[volume][bodyPart] = true
			end
		end
	end
	setRegion(player, chooseRegion(state))
end

-- several limbs may leave together queue one check for that player
local function queueRefresh(player, delayTime)
	local state = playerStates[player]
	if not state or state.RefreshQueued then
		return
	end
	state.RefreshQueued = true
	local characterVersion = state.CharacterVersion
	task.delay(delayTime, function()
		if playerStates[player] ~= state or state.CharacterVersion ~= characterVersion then
			return -- this callback belonged to old character
		end
		state.RefreshQueued = false
		RegionService.Refresh(player)
	end)
end

-- use after moving a zone or changing its name / priority during play
function RegionService.RefreshAll()
	for player in pairs(playerStates) do
		RegionService.Refresh(player)
	end
end

-- adding a model may add many parts at once refresh once for the whole batch
local function queueRefreshAll()
	if refreshAllQueued then
		return
	end
	refreshAllQueued = true
	task.defer(function()
		refreshAllQueued = false
		RegionService.RefreshAll()
	end)
end

-- ignore scenery, dead characters, accessories, and tools
local function getTouchingPlayer(bodyPart)
	local character = bodyPart.Parent
	if not character or not character:IsA("Model") then
		return nil
	end
	local player = Players:GetPlayerFromCharacter(character)
	local state = player and playerStates[player]
	local humanoid = state and state.Character and state.Character:FindFirstChildOfClass("Humanoid")
	if state and state.Character == character and humanoid and humanoid.Health > 0 then
		return player, state
	end
	return nil
end

-- each part gets its own two listeners, even when several parts form one region
local function connectVolume(volume)
	if not volume:IsA("BasePart") or volumeConnections[volume] then
		return
	end

	volume.Anchored = true
	volume.CanCollide = false -- walk through it
	volume.CanTouch = true -- needed for Touched and TouchEnded
	volume.CanQuery = true -- lets the one-off exit check see it
	volume.Transparency = 1 -- visible in edit mode, hidden during play

	volumeConnections[volume] = {
		volume.Touched:Connect(function(bodyPart)
			local player, state = getTouchingPlayer(bodyPart)
			if not player then
				return
			end
			state.Contacts[volume] = state.Contacts[volume] or {}
			state.Contacts[volume][bodyPart] = true -- a set avoids counting duplicate touches
			setRegion(player, chooseRegion(state))
		end),

		volume.TouchEnded:Connect(function(bodyPart)
			local player, state = getTouchingPlayer(bodyPart)
			local contacts = state and state.Contacts[volume]
			if not contacts or not contacts[bodyPart] then
				return
			end
			contacts[bodyPart] = nil
			if chooseRegion(state) ~= state.CurrentRegion then
				queueRefresh(player, Config.ExitDelay)
			end
		end),
	}
end

-- disconnect the old character and cancel its pending exit check
local function clearCharacter(player)
	local state = playerStates[player]
	state.CharacterVersion += 1
	state.RefreshQueued = false
	state.Contacts = {}
	state.Character = nil
	disconnectAll(state.CharacterConnections)
	setRegion(player, nil)
end

-- new spawn gets fresh contacts and its own death/removal listeners
local function watchCharacter(player, character)
	clearCharacter(player)
	local state = playerStates[player]
	state.Character = character

	-- character can arrive in pieces, so refresh as its body is made
	local function bodyChanged(child)
		if child:IsA("BasePart") then
			queueRefresh(player, 0)
		end
	end
	table.insert(state.CharacterConnections, character.ChildAdded:Connect(bodyChanged))
	table.insert(state.CharacterConnections, character.ChildRemoved:Connect(bodyChanged))

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if playerStates[player] ~= state or state.Character ~= character or not humanoid then
			return
		end
		table.insert(state.CharacterConnections, humanoid.Died:Connect(function()
			clearCharacter(player) -- dont wait for body to leave the zone
		end))
		RegionService.Refresh(player) -- spawning inside may not produce a touch
	end)
end

-- keep the same player state across respawns replace only the character state
local function watchPlayer(player)
	if playerStates[player] then
		return
	end
	local state = {
		Contacts = {},
		CharacterConnections = {},
		CharacterVersion = 0,
		RefreshQueued = false,
	}
	playerStates[player] = state
	player:SetAttribute("CurrentRegion", "")
	state.Connections = {
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			clearCharacter(player)
		end),
	}
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

function RegionService.GetRegion(player)
	local state = playerStates[player]
	return state and state.CurrentRegion or nil -- nil means outside
end

-- handy when another server script just needs a yes / no answer
function RegionService.IsInRegion(player, regionKey)
	return RegionService.GetRegion(player) == regionKey
end

-- safe to call again it wont connect duplicate events
function RegionService.Start()
	assert(RunService:IsServer(), "RegionService must run on the server.")
	if started then
		return
	end
	started = true

	Regions.DescendantAdded:Connect(function(instance)
		connectVolume(instance)
		if instance:IsA("BasePart") then
			queueRefreshAll()
		end
	end)
	Regions.DescendantRemoving:Connect(function(instance)
		local connections = volumeConnections[instance]
		if not connections then
			return
		end
		disconnectAll(connections)
		volumeConnections[instance] = nil
		for player, state in pairs(playerStates) do
			if state.Contacts[instance] then
				state.Contacts[instance] = nil
				queueRefresh(player, Config.ExitDelay)
			end
		end
	end)
	for _, instance in ipairs(Regions:GetDescendants()) do
		connectVolume(instance)
	end

	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player)
		local state = playerStates[player]
		if state then
			clearCharacter(player)
			disconnectAll(state.Connections)
			playerStates[player] = nil
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watchPlayer(player)
	end
end

return RegionService
