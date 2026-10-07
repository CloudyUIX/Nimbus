# Nimbus Region System

Small region system with banners, local lighting, playlists and server events  

## be sure to replace assetids / get rid of them etc

## where stuff is

```text
Workspace > Regions -- region parts and models, visible while editing and hidden during play
ReplicatedStorage > RegionSystem > Config -- all region options and timing
ReplicatedStorage > RegionSystem > LightingPresets -- lighting folders
StarterGui > RegionGui > Banner -- editable template
ServerScriptService > RegionService -- server detection and player queries
StarterPlayer > StarterPlayerScripts > RegionClient -- local images, banners, lighting and music
```

## add a region

1. add a part, model or folder directly inside Workspace.Regions and name it Forest
2. make its parts cover the area, tall enough to overlap the players HumanoidRootPart
3. copy Wetlands in Config.Regions and rename the key to Forest
4. edit the name, subtitle, image, lighting and music

parts can be rotated, multiple parts can make one region  
mesh and union detection follows their collision geometry  
the top level name has to match a key in Config.Regions  

## banner options

```lua
ShowBanner = true -- false hides just the banner
FirstVisitOnly = false -- true shows it only once during this join
BannerCooldown = 8 -- optional override for this regions reentry cooldown
```

first visit means first time the banner actually shows  
respawning keeps that history, leaving and rejoining clears it  
nothing uses datastores  

Config.Banner.Cooldown is the default cooldown per region  
entering and leaving quickly wont replay the same banner  
a suppressed banner stays suppressed for that visit, enter again after the cooldown  
images from Config.Regions preload locally as the client starts  
if an image fails or takes too long, the banner still shows its text  
Config.ImagePreloadTimeout controls how long a banner can wait for its image  

## music

each region has its own Music table  

```lua
Music = {
    Enabled = true,
    Volume = 0.5,
    PlaybackSpeed = 1,
    ResumeOnReturn = true,
    Tracks = {
        "rbxassetid://123456789",
        "rbxassetid://987654321",
        { SoundId = "rbxassetid://555555555", Volume = 0.3, PlaybackSpeed = 1 },
    },
},
```

replace those example ids with ur audio ids  

tracks play one after another, after the last one it loops back to the first  
one track loops by itself  
empty Tracks or Enabled = false means no region music there  
outside all regions fades out the region music  
ResumeOnReturn = false starts the list from the beginning each visit  

Config.Music.FadeTime controls the fade between zones  
Config.Music.LoadTimeout skips a track that wont load  
if every track fails it stops trying until the next visit  
the controller only changes its own local sounds in SoundService.RegionMusic  
no music ids are selected by default  

## detection

server checks the HumanoidRootPart every Config.CheckInterval seconds  
doesnt depend on touch events so teleports and spawning inside work too  
hats, tools and arms outside the region dont trigger it  

```lua
Config.EnterDelay -- person has to stay the same this long before entering or switching
Config.ExitDelay -- stay outside this long before fully leaving
```

going back into the current region cancels the pending change  
death and character removal clear membership immediately  

highest Priority wins for the active region  
equal priority keeps the current region while it still overlaps  
otherwise equal priority uses alphabetical region keys  

## use from a server script

```lua
local RegionService = require(game.ServerScriptService.RegionService)
RegionService.Start() -- safe to call again

-- everyone physically overlapping Wetlands from the latest server check
-- includes players with another higher priority region active
for _, player in ipairs(RegionService.GetPlayersInRegion("Wetlands")) do
    print(player.Name)
end

-- only players whose confirmed active region is Wetlands
local activePlayers = RegionService.GetPlayersInRegion("Wetlands", true)

-- one active region or nil outside
print(RegionService.GetRegion(player))
print(RegionService.IsInRegion(player, "Wetlands"))

-- every overlapping region key, even lower priority ones
local allRegions = RegionService.GetRegions(player)

RegionService.Entered:Connect(function(player, regionKey)
    print(player.Name, "entered", regionKey)
end)

RegionService.Exited:Connect(function(player, regionKey)
    print(player.Name, "left", regionKey)
end)

RegionService.Changed:Connect(function(player, current, previous)
    print(player.Name, previous, "->", current)
end)
```

events describe the confirmed active region after the entry / exit delays  
GetPlayersInRegion without true and GetRegions describe the latest physical overlap  
those snapshots update every CheckInterval and dont wait for the active region delay  
returned lists are copies so changing them wont change the service  

```lua
RegionService.Refresh(player) -- optional immediate check after a teleport
RegionService.RefreshAll() -- optional immediate check after moving regions
```

explicit refresh skips the entry / exit delays, normal polling handles changes automatically  

on switch, state updates first then exited, entered and changed fire  
events report future changes, read the query methods for players already inside  
all detection happens on the server, clients dont submit region claims  

## use from a LocalScript

```lua
local player = game.Players.LocalPlayer

local function onRegionChanged()
    print(player:GetAttribute("CurrentRegion")) -- empty string means outside
end

player:GetAttributeChangedSignal("CurrentRegion"):Connect(onRegionChanged)
onRegionChanged()
```

## lighting

duplicate a folder in RegionSystem.LightingPresets and rename it Forest  
THE FOLDER HAS ATTRIBUTES FOR AMBIENT BRIGHTNESS ETC LOOK IN PROPERTIES  
edit or add lighting effects inside the folder  
set ChangeAtmosphere = true and LightingPreset = "Forest" in config  
ChangeAtmosphere = false restores the original lighting  
Config.LightingTweenTime controls the transition  

## banner layout

edit StarterGui.RegionGui.Banner  
keep ResetOnSpawn false so the same gui survives respawns  
timing, slide distance and uppercase titles are in Config.Banner  
