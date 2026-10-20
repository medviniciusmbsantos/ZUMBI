local Players = game:GetService("Players")
local Balance = require(game.ReplicatedStorage.ZumbiShared.Balance)
local Util = require(script.Parent.Util)
local Zombies = require(script.Parent.ZombieService)

local Combat = { Inventory = {}, Effects = nil }
local rng = Random.new()

local function sync(record)
	if not record.tool.Parent then return end
	record.tool:SetAttribute("Ammo", record.ammo)
	record.tool:SetAttribute("Reserve", record.reserve)
	record.tool:SetAttribute("Tier", record.tier)
	record.tool:SetAttribute("Reloading", record.reloading)
end

local function equipped(player)
	local list = Combat.Inventory[player]
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and list and list[tool:GetAttribute("WeaponId")]
end

function Combat.recolor(player)
	local skin = Balance.Skins[player:GetAttribute("Skin") or "Default"] or Balance.Skins.Default
	for _, record in Combat.Inventory[player] or {} do
		local panel = record.tool:FindFirstChild("Acabamento")
		if panel then panel.Color = Color3.fromRGB(table.unpack(skin.Color)) end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local trail = root:FindFirstChild("ZumbiTrail")
	if player:GetAttribute("Skin") == "Default" then
		if trail then trail.Enabled = false end
		return
	end
	if not trail then
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, b.Name, a.Position, b.Position = "TrailTop", "TrailBottom", Vector3.new(0, 0.4, 0.6), Vector3.new(0, -0.7, 0.6)
		a.Parent, b.Parent = root, root
		trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "ZumbiTrail", a, b
		trail.Lifetime, trail.MinLength, trail.LightEmission = 0.22, 0.2, 0.45
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
		trail.Parent = root
	end
	trail.Color, trail.Enabled = ColorSequence.new(Color3.fromRGB(table.unpack(skin.Color))), true
end

function Combat.give(player, id)
	local def = Balance.Weapons[id]
	if not def or not player.Character or not player:FindFirstChild("Backpack") then return false end
	local list = Combat.Inventory[player] or {}; Combat.Inventory[player] = list
	if list[id] and list[id].tool.Parent then Combat.refill(player, id, true); return true end
	local tool = Instance.new("Tool")
	tool.Name, tool.CanBeDropped, tool.RequiresHandle = def.Name, false, true
	tool:SetAttribute("WeaponId", id)
	tool.Grip = CFrame.new(0, -0.15, 0.2) * CFrame.Angles(0, 0, 0)
	local function gunpart(name, size, offset, color)
		local p = Instance.new("Part"); p.Name, p.Size, p.Color = name, size, color
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.Material = false, false, false, true, Enum.Material.Metal
		p.CFrame, p.Parent = offset, tool
		return p
	end
	local handle = gunpart("Handle", Vector3.new(0.35, 0.85, 0.4), CFrame.identity, Color3.fromRGB(40, 43, 47))
	local length = if id == "Pistol" then 1.4 elseif id == "Shotgun" then 3.2 else 2.6
	for _, spec in {
		{ "Corpo", Vector3.new(0.55, 0.55, length), CFrame.new(0, 0.45, -length / 2 + 0.3), Color3.fromRGB(47, 52, 57) },
		{ "Acabamento", Vector3.new(0.57, 0.2, length * 0.6), CFrame.new(0, 0.65, -length / 2 + 0.3), Color3.fromRGB(table.unpack(def.Color)) },
		{ "Cano", Vector3.new(0.22, 0.22, 0.6), CFrame.new(0, 0.45, -length + 0.1), Color3.fromRGB(22, 24, 28) },
	} do
		local p = gunpart(table.unpack(spec))
		local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1, weld.Parent = handle, p, p
	end
	local muzzle = Instance.new("Attachment"); muzzle.Name, muzzle.Position, muzzle.Parent = "Muzzle", Vector3.new(0, 0.45, -length - 0.2), handle
	local record = { tool = tool, id = id, ammo = def.Magazine, reserve = def.Reserve, tier = 0, reloading = false, nextShot = 0 }
	list[id] = record
	sync(record)
	tool.Parent = player.Backpack
	Combat.recolor(player)
	local _, hum = Util.alive(player)
	if hum then hum:EquipTool(tool) end
	return true
end

function Combat.clear(player)
	for _, record in Combat.Inventory[player] or {} do record.tool:Destroy() end
	Combat.Inventory[player] = {}
end

function Combat.refill(player, id, full)
	local record = if id then (Combat.Inventory[player] or {})[id] else equipped(player)
	if not record or not record.tool.Parent then return false end
	local def = Balance.Weapons[record.id]
	record.reserve = math.min(def.Reserve, record.reserve + (if full then def.Reserve else math.ceil(def.Reserve * 0.35)))
	if full then record.ammo = def.Magazine end
	sync(record)
	return true
end

function Combat.owned(player, id)
	local record = (Combat.Inventory[player] or {})[id]
	return record and record.tool.Parent ~= nil
end

function Combat.upgrade(player)
	local record = equipped(player)
	if not record or record.tier >= 3 then return false end
	record.tier += 1
	record.ammo, record.reserve = Balance.Weapons[record.id].Magazine, Balance.Weapons[record.id].Reserve
	record.tool.Name = Balance.Weapons[record.id].Name .. " +" .. record.tier
	sync(record)
	return true
end

function Combat.canUpgrade(player)
	local record = equipped(player)
	return record and record.tier < 3
end

function Combat.hasEquipped(player) return equipped(player) ~= nil end

function Combat.reload(player)
	local record = equipped(player)
	if not record or not Util.alive(player) or not player:GetAttribute("InRound") then return end
	local def = Balance.Weapons[record.id]
	if record.reloading or record.ammo >= def.Magazine or record.reserve <= 0 then return end
	record.reloading = true
	sync(record)
	local duration = def.Reload * (if player:GetAttribute("QuickHands") then 0.65 else 1)
	task.delay(duration, function()
		if not record.tool.Parent then return end
		local load = math.min(def.Magazine - record.ammo, record.reserve)
		record.ammo += load; record.reserve -= load; record.reloading = false
		sync(record)
	end)
end

function Combat.fire(player, aim)
	if not Util.finiteVector(aim) or not player:GetAttribute("InRound") then return end
	local alive, _, root = Util.alive(player)
	local record = equipped(player)
	if not alive or not record or record.tool.Parent ~= player.Character or record.reloading then return end
	local def = Balance.Weapons[record.id]
	local now = os.clock()
	if now < record.nextShot or record.ammo < 1 then return end
	local head = player.Character:FindFirstChild("Head")
	local origin = if head then head.Position else root.Position + Vector3.new(0, 1.5, 0)
	local delta = aim - origin
	if delta.Magnitude < 1 then return end
	record.nextShot = now + def.Interval * 0.95
	record.ammo -= 1
	sync(record)
	local base = delta.Unit
	local basis = CFrame.lookAt(Vector3.zero, base)
	local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	local drops = workspace:FindFirstChild("ZumbiDrops"); if drops then table.insert(ignore, drops) end
	params.FilterDescendantsInstances = ignore
	local hits, anyHit, headshot = {}, false, false
	local segments = {}
	for _ = 1, def.Pellets do
		local direction = (base + basis.RightVector * rng:NextNumber(-def.Spread, def.Spread) + basis.UpVector * rng:NextNumber(-def.Spread, def.Spread)).Unit
		local result = workspace:Raycast(origin, direction * def.Range, params)
		local finish = if result then result.Position else origin + direction * def.Range
		table.insert(segments, finish)
		local model = result and result.Instance:FindFirstAncestorOfClass("Model")
		if model and Zombies.Active[model] then
			local isHead = result.Instance.Name == "Head" or result.Instance.Name == "Olho"
			headshot = headshot or isHead
			local damage = Balance.upgradeDamage(def.Damage, record.tier) * (if isHead then 1.7 else 1)
			hits[model] = (hits[model] or 0) + damage
			anyHit = true
		end
	end
	for model, damage in hits do Zombies.damage(model, damage, player) end
	-- Send visual data only; clients cannot nominate victims or damage.
	Combat.Effects:FireAllClients("Shot", { UserId = player.UserId, Origin = origin, Ends = segments })
	if anyHit then Combat.Effects:FireClient(player, "Hit", { Head = headshot }) end
end

function Combat.start(remotes)
	Combat.Effects = remotes.Effects
	local allowFire, allowReload = Util.limiter(18, 8), Util.limiter(2, 2)
	remotes.Fire.OnServerEvent:Connect(function(player, aim) if allowFire(player) then Combat.fire(player, aim) end end)
	remotes.Reload.OnServerEvent:Connect(function(player) if allowReload(player) then Combat.reload(player) end end)
	Players.PlayerRemoving:Connect(function(player) Combat.clear(player); Combat.Inventory[player] = nil end)
end

return Combat
