# Nimbus Region System

Small region system. easy to edit, a banner, local lighting, and server events

## install

drag `Nimbus.rbxm` into Studio, then ungroup all the folders in their respected place

## how to edit

| explorer | what it do |
| --- | --- |
| Workspace > Regions | visible in edit mode and hidden during play |
| ReplicatedStorage > RegionSystem > Config | region names, image, colors, priorities, atmosphere toggle, and timing |
| ReplicatedStorage > RegionSystem > LightingPresets | lighting folders |
| StarterGui > RegionGui > Banner | editable temp (short for template) |
| ServerScriptService > RegionService | server detection and events incase you got scripts to know stuff about regions |
| StarterPlayer > StarterPlayerScripts > RegionClient | banner and local lighting entry |

## example adding region

1. put a part / union operation / mesh / model or folder directly inside `Workspace.Regions` lets say "Forest"
2. make the parts inside like good, dont do super thin etc
3. Duplicate a already made region in `Config.Regions`, and change it to `Forest`

```lua
Forest = {
    Name = "The Forest",
    Subtitle = "Ouuuh trees",
    Image = "rbxassetid://0000000000",
    ImageTransparency = 0.7,
    AccentColor = Color3.fromRGB(255, 255, 255),
    Priority = 0,

    ChangeAtmosphere = false, -- (obviously true if you want it to change lighting)
    LightingPreset = "Forest",
},
```

## change atmosphere

1. duplicate folder in `RegionSystem.LightingPresets` and rename it `Forest`.
2. THE FOLDER HAS ATTRIBUTES FOR AMBIENT BRIGHTNESS ETC LOOK IN PROPERTIES OF THE FOLDER
3. edit or add different lighting stuff inside the folders
4. set `ChangeAtmosphere = true` and `LightingPreset = "Forest"` in config

original values and effects from ur game when you enter ur first zone if you o somewhere where ChangeAtmosphere = false then it goes back to the one you had

## how you use from another script

```lua
local Players = game:GetService("Players")
local RegionService = require(game.ServerScriptService.RegionService)

RegionService.Start() -- safe to call again.

RegionService.Entered:Connect(function(player, regionKey)
    if regionKey == "Wetlands" then
        print(player.Name .. " entered wetlands")
    end
end)

RegionService.Exited:Connect(function(player, regionKey)
    print(player.Name .. " went out of " .. regionKey)
end)

RegionService.Changed:Connect(function(player, current, previous)
    -- current / previous are region, or nil when outside
    print(player.Name, previous, ">", current)
end)

for _, player in ipairs(Players:GetPlayers()) do
    print(RegionService.GetRegion(player)) -- region or nil
    print(RegionService.IsInRegion(player, "Wetlands"))
end
```

on switch, state updates first, then exited, entered, and changed fire. events report future changes, read GetRegion for players already inside. server gets owner, clients do not submit region claims. check server for rewards or gameplay perms

## use from LocalScript

```lua
local player = game.Players.LocalPlayer

local function onRegionChanged()
    local regionKey = player:GetAttribute("CurrentRegion") or ""
    print(regionKey) -- Empty string means outside.
end

player:GetAttributeChangedSignal("CurrentRegion"):Connect(onRegionChanged)
onRegionChanged()
```
