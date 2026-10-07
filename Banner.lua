local TweenService = game:GetService("TweenService")

local Banner = {}
Banner.__index = Banner

function Banner.new(gui, settings)
	local self = setmetatable({}, Banner)

	self.Frame = gui.Banner
	self.Settings = settings
	self.RestPosition = self.Frame.Position
	self.Sequence = 0
	self.Tween = nil
	self.Frame.Visible = false
	self.Frame.GroupTransparency = 1

	return self
end

function Banner:PlayTween(duration, properties)
	if self.Tween then
		self.Tween:Cancel()
	end

	self.Tween = TweenService:Create(
		self.Frame,
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		properties
	)
	self.Tween:Play()

	return self.Tween
end

function Banner:Hide()
	self.Sequence += 1
	local sequence = self.Sequence
	local tween = self:PlayTween(self.Settings.ExitTime, {
		GroupTransparency = 1,
		Position = self.RestPosition - UDim2.fromOffset(0, self.Settings.SlideDistance),
	})

	task.spawn(function()
		tween.Completed:Wait()
		if self.Sequence == sequence then
			self.Frame.Visible = false
		end
	end)
end

function Banner:Show(region)
	self.Sequence += 1
	local sequence = self.Sequence
	local frame = self.Frame

	if self.Tween then
		self.Tween:Cancel()
	end

	frame.Title.Text = self.Settings.UppercaseTitle and string.upper(region.Name) or region.Name
	frame.Subtitle.Text = region.Subtitle or ""
	frame.BackgroundImage.Image = region.Image or ""
	frame.BackgroundImage.Visible = region.Image ~= nil and region.Image ~= ""
	frame.BackgroundImage.ImageTransparency = region.ImageTransparency or 0.7
	frame.Divider.BackgroundColor3 = region.AccentColor or Color3.new(1, 1, 1)
	frame.Position = self.RestPosition - UDim2.fromOffset(0, self.Settings.SlideDistance)
	frame.GroupTransparency = 1
	frame.Visible = true

	self:PlayTween(self.Settings.EnterTime, {
		GroupTransparency = 0,
		Position = self.RestPosition,
	})

	task.delay(self.Settings.EnterTime + self.Settings.HoldTime, function()
		if self.Sequence == sequence then
			self:Hide()
		end
	end)
end

return Banner
