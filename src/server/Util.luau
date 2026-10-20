local Players = game:GetService("Players")
local Util = {}

function Util.folder(parent, name)
	local found = parent:FindFirstChild(name)
	if found then return found end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = name, parent
	return folder
end

function Util.alive(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return hum and hum.Health > 0 and root ~= nil, hum, root
end

function Util.finiteVector(v)
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 10000 and math.abs(v.Y) < 10000 and math.abs(v.Z) < 10000
end

function Util.near(player, position, distance)
	local alive, _, root = Util.alive(player)
	return alive and (root.Position - position).Magnitude <= distance
end

function Util.livingPlayers()
	local result = {}
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("InRound") and Util.alive(player) then table.insert(result, player) end
	end
	return result
end

-- Token buckets are per player AND action. No yielding occurs during acceptance.
function Util.limiter(rate, burst)
	local buckets = setmetatable({}, { __mode = "k" })
	return function(player)
		local now = os.clock()
		local b = buckets[player] or { tokens = burst, at = now }
		b.tokens = math.min(burst, b.tokens + (now - b.at) * rate)
		b.at = now
		buckets[player] = b
		if b.tokens < 1 then return false end
		b.tokens -= 1
		return true
	end
end

return Util
