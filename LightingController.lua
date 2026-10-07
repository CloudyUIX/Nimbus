local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local LightingController = {}
LightingController.__index = LightingController

-- add another tweenable lighting property here if your presets need it
local LightingProperties = {
	"Ambient", -- light tint in shaded areas
	"OutdoorAmbient", -- light tint outdoors
	"Brightness", -- strength of the sun/moon light
	"ClockTime", -- time of day: 0 = midnight, 12 = noon
	"ExposureCompensation", -- brighten or darken the whole scene
	"FogColor", -- regular fog tint atmosphere has its own color
	"FogStart", -- where regular fog begins in studs
	"FogEnd", -- where regular fog becomes fully opaque
	"ColorShift_Top", -- tint on surfaces facing the light
	"ColorShift_Bottom", -- tint on surfaces facing away from the light
	"EnvironmentDiffuseScale", -- how much the environment contributes to diffuse light
	"EnvironmentSpecularScale", -- how much the environment contributes to reflections
	"ShadowSoftness", -- softness of supported shadows
	"GeographicLatitude", -- changes the sun / moons path through the sky
}

-- these are the effect types a preset replaces. Terrain clouds are not included.
local function isLightingEffect(instance)
	return instance:IsA("Atmosphere") or instance:IsA("Sky") or instance:IsA("PostEffect")
end

-- each controller keeps its own originals and the effects it created.
function LightingController.new(presets, tweenTime)
	return setmetatable({
		Presets = presets,
		TweenTime = tweenTime,
		OriginalProperties = nil, -- lighting values from before entering a zone
		OriginalEffects = {}, -- actual original objects so they can come back
		PresetEffects = {}, -- copies made for the active zone
		Tween = nil, -- cancel if another region takes over
		Revision = 0, -- keeps an old restore callback from clearing a newer one
	}, LightingController)
end

-- save once per visit. switching regions should not save the last region as default
function LightingController:CaptureOriginal()
	if self.OriginalProperties then
		return
	end

	self.OriginalProperties = {}
	for _, property in ipairs(LightingProperties) do
		self.OriginalProperties[property] = Lighting[property]
	end

	for _, effect in ipairs(Lighting:GetChildren()) do
		if isLightingEffect(effect) then
			table.insert(self.OriginalEffects, effect)
		end
	end
end

-- only remove our own copies never somebody elses unrelated objects
function LightingController:ClearPresetEffects()
	for _, effect in ipairs(self.PresetEffects) do
		effect:Destroy()
	end
	self.PresetEffects = {}
end

-- timing comes from Config.LightingTweenTime lower = faster
function LightingController:TweenProperties(properties)
	if self.Tween then
		self.Tween:Cancel()
	end

	self.Tween = TweenService:Create(
		Lighting,
		TweenInfo.new(self.TweenTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		properties
	)
	self.Tween:Play()
	return self.Tween
end

-- put the originals back when leaving, dying, or entering atmosphere disabled zone
function LightingController:Restore()
	self.Revision += 1
	local revision = self.Revision
	if not self.OriginalProperties then
		return
	end

	self:ClearPresetEffects()
	for _, effect in ipairs(self.OriginalEffects) do
		effect.Parent = Lighting
	end

	local tween = self:TweenProperties(self.OriginalProperties)
	task.spawn(function()
		tween.Completed:Wait()
		if self.Revision == revision then
			-- next visit captures any outside lighting edits made since this visit
			self.OriginalProperties = nil
			self.OriginalEffects = {}
		end
	end)
end

-- folder attributes change lighting properties folder children supply the effects
function LightingController:Apply(region)
	if not region or not region.ChangeAtmosphere then
		self:Restore()
		return
	end

	local preset = self.Presets:FindFirstChild(region.LightingPreset or "")
	if not preset then
		warn("[RegionSystem] missing preset: " .. tostring(region.LightingPreset))
		self:Restore()
		return
	end

	self.Revision += 1
	self:CaptureOriginal()
	self:ClearPresetEffects()

	-- keep the actual originals so names, attributes, and instance references survive
	for _, effect in ipairs(self.OriginalEffects) do
		effect.Parent = nil
	end

	-- unspecified values stay at the original setting, not the previous zones setting
	local properties = table.clone(self.OriginalProperties)
	for _, property in ipairs(LightingProperties) do
		local value = preset:GetAttribute(property)
		if value ~= nil and typeof(value) == typeof(properties[property]) then
			properties[property] = value
		end
	end

	-- effects swap immediately color lighting properties tween below
	for _, effect in ipairs(preset:GetChildren()) do
		if isLightingEffect(effect) then
			local copy = effect:Clone()
			copy.Parent = Lighting
			table.insert(self.PresetEffects, copy)
		end
	end

	self:TweenProperties(properties)
end

return LightingController

