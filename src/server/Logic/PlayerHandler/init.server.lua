--[[

    Player Handler

    Griffin Dalby
    2025.07.19

    This script will handle player connections & disconnections, and
    manage their data.

--]]

--]] Services
local replicatedStorage = game:GetService('ReplicatedStorage')
local players = game:GetService('Players')

--]] Modules
local profileStore = require(replicatedStorage.ProfileStore)
local sawdust = require(replicatedStorage.Sawdust)

local caching = sawdust.core.cache

--]] Settings
--]] Constants
local playerTemplate = require(script.DataTemplate)
local playerStore = profileStore.New('PlayerStore', playerTemplate)

--]] Variables
--]] Functions
--]] Constants
local playerCache = caching.findCache('players')

--]] Connections
local charConns = {}
local function loadPlayerData(player: Player)
	--> Collision Groups
	if not charConns[player] then
		charConns[player] = player.CharacterAdded:Connect(function(character)
			for _, part in pairs(character:GetChildren()) do
				if not part:IsA('BasePart') then continue end
				part.CollisionGroup = 'Player'
			end
		end)
	end

	local playerData = playerCache:createTable(player)

	--> Session data
	playerData:setValue('inventory', {})

	--> Persistent data
	local playerProfile = playerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent~=players end 
	})

	if playerProfile~=nil then
		playerProfile:AddUserId(player.UserId)
		playerProfile:Reconcile()

		playerProfile.OnSessionEnd:Connect(function()
			--> Clean data

			player:Kick('Your session has ended!')
		end)

		if player.Parent==players then
			--> Load data
			
		else
			playerProfile:EndSession()
		end

	else
		player:Kick('Failed to load profile! Please rejoin.')
	end
end

for _, player in players:GetPlayers() do
	task.spawn(loadPlayerData, player) end

players.PlayerAdded:Connect(loadPlayerData)
players.PlayerRemoving:Connect(function(player)
	if playerCache:hasEntry(player) then
		playerCache:setValue(player, nil) end

	if charConns[player] then
		charConns[player]:Disconnect()
		charConns[player]=nil end
end)