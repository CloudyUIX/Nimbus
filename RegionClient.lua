local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local system = ReplicatedStorage:WaitForChild("RegionSystem")
local Config = require(system.Config)
local Banner = require(system.Banner)
local LightingController = require(system.LightingController)

-- use the players copy, not the template
local gui = player:WaitForChild("PlayerGui"):WaitForChild("RegionGui")
local banner = Banner.new(gui, Config.Banner)
local lighting = LightingController.new(system.LightingPresets, Config.LightingTweenTime)

-- an empty region means outside restore lighting and hide the banner
local function updateRegion()
	local regionKey = player:GetAttribute("CurrentRegion")
	local region = Config.Regions[regionKey]

	lighting:Apply(region)

	if region then
		banner:Show(region)
	else
		banner:Hide()
	end
end

player:GetAttributeChangedSignal("CurrentRegion"):Connect(updateRegion)
updateRegion() -- catches a region the server set before this script finished loading
