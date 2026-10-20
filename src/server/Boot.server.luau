local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
Players.CharacterAutoLoads = false

local Util = require(script.Parent.Util)
local network = Util.folder(ReplicatedStorage, "ZumbiNetwork")
local remotes = {}
for _, name in { "Fire", "Reload", "Action", "Effects" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name, remote.Parent = name, network
	remotes[name] = remote
end
local state = Util.folder(ReplicatedStorage, "ZumbiState")
require(script.Parent.GameService).start(remotes, state)
