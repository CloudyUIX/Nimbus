local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")

local player = Players.LocalPlayer
local system = ReplicatedStorage:WaitForChild("RegionSystem")
local Config = require(system:WaitForChild("Config"))
local Banner = require(system:WaitForChild("Banner"))
local LightingController = require(system:WaitForChild("LightingController"))
local MusicController = require(system:WaitForChild("MusicController"))

local images = {}
local shown = {} -- stays through respawns, gone when u leave the game
local lastShown = {}
local revision = 0

-- start all the banner images locally before anyone enters a region
local function preloadImage(id)
	if type(id) ~= "string" or id == "" then
		return nil
	end
	if images[id] then
		return images[id]
	end
	local status = { Done = false, Loaded = false }
	images[id] = status
	task.spawn(function()
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ id }, function(_, result)
				status.Loaded = result == Enum.AssetFetchStatus.Success
			end)
		end)
		status.Done = true
		if not ok or not status.Loaded then
			warn("[RegionSystem] didnt preload banner " .. id)
		end
	end)
	return status
end

for _, region in pairs(Config.Regions) do
	preloadImage(region.Image)
end

-- use the players copy, keep this gui through respawns
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RegionGui")
gui.ResetOnSpawn = false
local banner = Banner.new(gui, Config.Banner)
local lighting = LightingController.new(system:WaitForChild("LightingPresets"), Config.LightingTweenTime)
local music = MusicController.new(Config.Music)

local function updateRegion()
	revision += 1
	local currentRevision = revision
	local regionKey = player:GetAttribute("CurrentRegion") or ""
	local region = Config.Regions[regionKey]

	lighting:Apply(region)
	music:Apply(regionKey, region)
	banner:Hide()

	if not region or region.ShowBanner == false or (region.FirstVisitOnly and shown[regionKey]) then
		return
	end
	local cooldown = math.max(0, region.BannerCooldown or Config.Banner.Cooldown or 8)
	if lastShown[regionKey] and os.clock() - lastShown[regionKey] < cooldown then
		return
	end

	task.spawn(function()
		local status = preloadImage(region.Image)
		local deadline = os.clock() + math.max(0, Config.ImagePreloadTimeout or 5)
		while status and not status.Done and revision == currentRevision and os.clock() < deadline do
			task.wait(0.05)
		end
		if revision ~= currentRevision then
			return -- ur already somewhere else
		end

		local displayRegion = region
		if status and not status.Loaded then
			displayRegion = table.clone(region)
			displayRegion.Image = "" -- still show the text if the image cant load in time
		end
		banner:Show(displayRegion)
		shown[regionKey] = true
		lastShown[regionKey] = os.clock()
	end)
end

player:GetAttributeChangedSignal("CurrentRegion"):Connect(updateRegion)
updateRegion() -- catches a region the server set before this script finished loading
