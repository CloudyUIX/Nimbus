local Config = {}

Config.ExitDelay = 0.2

Config.Banner = { 
	EnterTime = 0.45, -- how long banner takes to fully be there
	HoldTime = 3, -- how long banner is there for
	ExitTime = 0.3, -- how fast banner disappears
	SlideDistance = 10, 
	UppercaseTitle = true, -- incase ur too lazy to type WETLANDS
}

Config.LightingTweenTime = 0.8 -- pretty smooth at 0.8 tbh less = faster

-- each one has to match a model or part or something in Workspace.Regions

Config.Regions = {
	Wetlands = {
		Name = "Wetlands", -- uhhh.. the name
		Subtitle = "💀 Still water 💀", -- description of place
		Image = "rbxassetid://0000000000", -- optional image behind the text "rbxassetid://0000000000" must have rbxassetid
		ImageTransparency = 0.7, -- 0 solid, 1 invisible
		AccentColor = Color3.fromRGB(255, 255, 255), -- divider color
		Priority = 0, -- if im in both, higher priority goes over the other one

		ChangeAtmosphere = true, -- do u just want the banner or atmosphere
		LightingPreset = "Wetlands", -- folder inside RegionSystem.LightingPresets
	},

	Highlands = {
		Name = "Highlands",
		Subtitle = "ur in a land thats high up",
		Image = "",
		ImageTransparency = 0.7,
		AccentColor = Color3.fromRGB(255, 255, 255),
		Priority = 0,

		ChangeAtmosphere = true,
		LightingPreset = "Highlands",
	},
}

return Config
