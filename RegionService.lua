local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.RegionSystem.Config)
local Regions = workspace:WaitForChild("Regions")

local RegionService = {}
local playerStates = {}
local started = false

local entered = Instance.new("BindableEvent")
local exited = Instance.new("BindableEvent")
local changed = Instance.new("BindableEvent")

RegionService.Entered = entered.Event -- player, region name
RegionService.Exited = exited.Event -- player, region name
RegionService.Changed = changed.Event -- player, new region, previous region

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
overlap.FilterDescendantsInstances = { Regions }
overlap.RespectCanCollide = false
overlap.MaxParts = 0 -- dont cut off overlapping regions

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

-- everything inside a model or folder uses its top level region name
local function getRegionKey(part)
	local region = part
	while region and region.Parent ~= Regions do
		region = region.Parent
	end
	return region and Config.Regions[region.Name] and region.Name or nil
end

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

local function chooseRegion(state)
	local bestRegion = nil
	local bestPriority = -math.huge
	for key in pairs(state.Regions) do
		local priority = Config.Regions[key].Priority or 0
		local winsTie = priority == bestPriority and (not bestRegion or key < bestRegion)
		if priority > bestPriority or winsTie then
			bestRegion = key
			bestPriority = priority
		end
	end

	-- keep the current one if both have the same priority
	local current = state.CurrentRegion
	if current and state.Regions[current] and (Config.Regions[current].Priority or 0) == bestPriority then
		return current
	end
	return bestRegion
end

-- overlap per player catches teleports too, hats and limbs dont count
local function samplePlayer(player, immediate)
	local state = playerStates[player]
	if not state then
		return
	end

	local character = state.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	state.Regions = {}
	if not character or not character:IsDescendantOf(workspace) or not humanoid or humanoid.Health <= 0
		or not root or not root:IsA("BasePart") then
		state.PendingSince = nil
		state.PendingRegion = nil
		setRegion(player, nil)
		return
	end

	for _, volume in ipairs(workspace:GetPartsInPart(root, overlap)) do
		local key = getRegionKey(volume)
		if key then
			state.Regions[key] = true
		end
	end

	local person = chooseRegion(state)
	if immediate or person == state.CurrentRegion then
		state.PendingSince = nil
		state.PendingRegion = nil
		setRegion(player, person)
		return
	end

	local now = os.clock()
	if state.PendingSince == nil or state.PendingRegion ~= person then
		state.PendingRegion = person
		state.PendingSince = now
	end

	-- going back over the edge cancels the pending change
	local delayTime = person and (Config.EnterDelay or 0.25) or (Config.ExitDelay or 0.5)
	if now - state.PendingSince >= math.max(0, delayTime) then
		state.PendingSince = nil
		state.PendingRegion = nil
		setRegion(player, person)
	end
end

-- refresh is immediate, normal movement uses the delays
function RegionService.Refresh(player)
	samplePlayer(player, true)
end

function RegionService.RefreshAll()
	for player in pairs(playerStates) do
		RegionService.Refresh(player)
	end
end

local function clearCharacter(player)
	local state = playerStates[player]
	if not state then
		return
	end
	disconnectAll(state.CharacterConnections)
	state.Character = nil
	state.Regions = {}
	state.PendingSince = nil
	state.PendingRegion = nil
	setRegion(player, nil)
end

local function watchCharacter(player, character)
	clearCharacter(player)
	local state = playerStates[player]
	state.Character = character

	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if playerStates[player] ~= state or state.Character ~= character or not humanoid then
			return
		end
		table.insert(state.CharacterConnections, humanoid.Died:Connect(function()
			if state.Character == character then
				clearCharacter(player)
			end
		end))
	end)
end

local function watchPlayer(player)
	if playerStates[player] then
		return
	end
	local state = {
		Regions = {},
		CharacterConnections = {},
	}
	playerStates[player] = state
	player:SetAttribute("CurrentRegion", "")
	state.Connections = {
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end),
		player.CharacterRemoving:Connect(function(character)
			if state.Character == character then
				clearCharacter(player)
			end
		end),
	}
	if player.Character then
		watchCharacter(player, player.Character)
	end
end

function RegionService.GetRegion(player)
	local state = playerStates[player]
	return state and state.CurrentRegion or nil
end

-- same active region check as before
function RegionService.IsInRegion(player, regionKey)
	return RegionService.GetRegion(player) == regionKey
end

-- all overlapping regions from the latest check, even lower priority ones
function RegionService.GetRegions(player)
	local result = {}
	local state = playerStates[player]
	if state then
		for key in pairs(state.Regions) do
			table.insert(result, key)
		end
	end
	table.sort(result)
	return result
end

-- true for activeOnly matches GetRegion and the entered / exited events
function RegionService.GetPlayersInRegion(regionKey, activeOnly)
	local result = {}
	if not Config.Regions[regionKey] then
		return result
	end
	for player, state in pairs(playerStates) do
		local inside = state.Regions[regionKey]
		if activeOnly then
			inside = state.CurrentRegion == regionKey
		end
		if inside then
			table.insert(result, player)
		end
	end
	table.sort(result, function(a, b)
		return a.UserId < b.UserId
	end)
	return result -- fresh copy so ur script cant mess with our state
end

local function prepareVolume(volume)
	if not volume:IsA("BasePart") then
		return
	end
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanTouch = false -- no touch listeners needed anymore
	volume.CanQuery = true
	volume.Transparency = 0.9
end

function RegionService.Start()
	assert(RunService:IsServer(), "RegionService must run on server")
	if started then
		return
	end
	started = true

	Regions.DescendantAdded:Connect(prepareVolume)
	for _, instance in ipairs(Regions:GetDescendants()) do
		prepareVolume(instance)
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

	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < math.max(0.03, Config.CheckInterval or 0.1) then
			return
		end
		elapsed = 0
		for player in pairs(playerStates) do
			samplePlayer(player, false)
		end
	end)
end

return RegionService
