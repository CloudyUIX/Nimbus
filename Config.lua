local Config = {}

Config.CheckInterval = 0.25 -- seconds between server checks
Config.EnterDelay = 0.125 -- stay inside this long before switching regions
Config.ExitDelay = 0.5 -- step back in before this and it cancels the exit
Config.ImagePreloadTimeout = 5 -- dont hold the banner forever if an image breaks

Config.Music = {
	FadeTime = 0.5,
	LoadTimeout = 10, -- skip an audio if it still hasnt loaded
}

Config.Banner = { 
	Cooldown = 8, -- seconds before the same regions banner can show again
	EnterTime = 0.45, -- how long banner takes to fully be there
	HoldTime = 3, -- how long banner is there for
	ExitTime = 0.3, -- how fast banner disappears
	SlideDistance = 10, 
	UppercaseTitle = true, -- incase ur too lazy to type WETLANDS
}

Config.LightingTweenTime = 0.6 -- pretty smooth at 0.6 less = faster

-- each one has to match a model or part or something in Workspace.Regions

Config.Regions = {
	Wetlands = {
		Name = "Wetlands", -- uhhh.. the name
		ShowBanner = true, -- false hides the banner but music and lighting still work
		FirstVisitOnly = true, -- true shows it once per join, respawning doesnt reset it
		Subtitle = "💀 Still water 💀", -- description of place
		Image = "rbxassetid://0000000000", -- optional image behind the text "rbxassetid://0000000000" must have rbxassetid
		ImageTransparency = 0.7, -- 0 solid, 1 invisible
		AccentColor = Color3.fromRGB(255, 255, 255), -- divider color
		Priority = 0, -- if player in both, higher priority goes over the other region

		ChangeAtmosphere = true, -- do u just want the banner or atmosphere
		LightingPreset = "Wetlands", -- folder inside RegionSystem.LightingPresets

		Music = {
			Enabled = true,
			Volume = 0.5,
			ResumeOnReturn = true, -- come back where the song left off
			Tracks = {
				{ SoundId = "rbxassetid://0000000000", Volume = 0.35, PlaybackSpeed = 1 },
			},
		},
	},

	Highlands = {
		Name = "Highlands",
		ShowBanner = true,
		FirstVisitOnly = false,
		Subtitle = "ur in a land thats high up",
		Image = "rbxassetid://0000000000",
		ImageTransparency = 0.7,
		AccentColor = Color3.fromRGB(255, 255, 255),
		Priority = 0,

		ChangeAtmosphere = true,
		LightingPreset = "Highlands",

		Music = {
			Enabled = true,
			Volume = 0.5,
			ResumeOnReturn = true,
			Tracks = {
				{ SoundId = "rbxassetid://0000000000", Volume = 0.35, PlaybackSpeed = 1 },
			},
		},
	},
}

return Config
