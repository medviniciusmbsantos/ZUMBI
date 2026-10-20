local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local Balance = require(game.ReplicatedStorage.ZumbiShared.Balance)
local Data = require(script.Parent.DataService)
local World = require(script.Parent.World)
local Util = require(script.Parent.Util)
local Combat = require(script.Parent.CombatService)
local Zombies = require(script.Parent.ZombieService)
local Commerce = require(script.Parent.CommerceService)

local Game = { Phase = "Waiting", Wave = 0, Round = 0, Spawning = {}, Remaining = 0, EndsAt = 0, WipeAt = nil,
	Repairs = {}, Mystery = {}, TrapUntil = 0, TrapCooldown = 0 }
local rng = Random.new()
local remotes, state

local function toast(player, text, good)
	remotes.Effects:FireClient(player, "Toast", { Text = text, Good = good == true })
end

local function announce(text)
	remotes.Effects:FireAllClients("Announcement", { Text = text })
end

local function publish()
	state:SetAttribute("Phase", Game.Phase)
	state:SetAttribute("Wave", Game.Wave)
	state:SetAttribute("Remaining", Game.Remaining)
	state:SetAttribute("Enemies", Zombies.count())
	state:SetAttribute("EndsAt", Game.EndsAt)
	state:SetAttribute("Power", World.Powered)
	state:SetAttribute("WipeAt", Game.WipeAt or 0)
	state:SetAttribute("Living", #Util.livingPlayers())
	state:SetAttribute("Round", Game.Round)
end

function Game.stats(player)
	local alive, hum = Util.alive(player)
	if not alive then return end
	local maxHealth = 100 + (if player:GetAttribute("Vanguard") then 25 else 0) + (if player:GetAttribute("Juggernaut") then 75 else 0)
	local delta = maxHealth - hum.MaxHealth
	hum.MaxHealth = maxHealth
	hum.Health = math.clamp(hum.Health + math.max(0, delta), 0, maxHealth)
	hum.WalkSpeed = (if player:GetAttribute("Sprinting") then Balance.SprintSpeed else Balance.BaseSpeed)
		+ (if player:GetAttribute("Runner") then 3 else 0) + (if player:GetAttribute("Vanguard") then 2 else 0)
end

local function resetPerks(player)
	for key in Balance.Perks do player:SetAttribute(key, false) end
	player:SetAttribute("RoundRevives", 0)
	player:SetAttribute("BoughtRescue", false)
	player:SetAttribute("Stamina", 100)
	player:SetAttribute("Sprinting", false)
	player:SetAttribute("RoundKills", 0)
end

function Game.spawn(player, fresh)
	if Game.Spawning[player] or not player.Parent or not player:GetAttribute("DataReady") then return end
	Game.Spawning[player] = true
	local round = Game.Round
	if fresh then resetPerks(player) end
	player:SetAttribute("InRound", false)
	Combat.clear(player)
	local ok, err = pcall(function() player:LoadCharacterAsync() end)
	if ok and player.Parent and player.Character and round == Game.Round then
		local root = player.Character:WaitForChild("HumanoidRootPart", 8)
		if root and Game.Phase ~= "GameOver" and Game.Phase ~= "Victory" then
			player.Character:PivotTo(CFrame.new(World.Spawn + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-5, 5))))
			player:SetAttribute("InRound", true)
			player:SetAttribute("Eliminated", false)
			player:SetAttribute("InvulnerableUntil", workspace:GetServerTimeNow() + 8)
			Game.stats(player)
			local shield = Instance.new("ForceField"); shield.Visible, shield.Parent = true, player.Character
			task.delay(8, function() shield:Destroy() end)
			Combat.give(player, "Pistol")
		end
	else warn("[ZUMBI] Character spawn failed: " .. tostring(err)) end
	Game.Spawning[player] = nil
end

function Game.addPlayer(player)
	player:SetAttribute("InRound", false)
	player:SetAttribute("Eliminated", false)
	resetPerks(player)
	player.CharacterAdded:Connect(function(character)
		local hum = character:WaitForChild("Humanoid", 10)
		if not hum then return end
		local function collide(part)
			if part:IsA("BasePart") then part.CollisionGroup = "Survivors" end
		end
		for _, p in character:GetDescendants() do collide(p) end
		character.DescendantAdded:Connect(collide)
		hum.Died:Connect(function()
			if player.Character ~= character then return end
			player:SetAttribute("InRound", false)
			player:SetAttribute("Eliminated", true)
			player:SetAttribute("Sprinting", false)
			toast(player, "Eliminado. Você retorna na pausa seguinte; um resgate permite voltar agora.", false)
		end)
	end)
	Data.load(player)
	if not player.Parent or not player:GetAttribute("DataReady") then return end
	task.spawn(Commerce.refreshPass, player)
	if Game.Phase ~= "Waiting" and Game.Phase ~= "Victory" and Game.Phase ~= "GameOver" then Game.spawn(player, true) end
end

local function buy(player, cost)
	if not Data.spend(player, cost) then toast(player, "Suprimentos insuficientes • precisa de " .. cost .. " moedas."); return false end
	return true
end

function Game.interact(player, action, arg)
	if not player:GetAttribute("InRound") or not Util.alive(player) or Game.Phase == "GameOver" or Game.Phase == "Victory" then return false end
	if action == "Door" then
		if buy(player, arg.Price) then announce(player.DisplayName .. " abriu " .. arg.Name); return true end
	elseif action == "Weapon" then
		local def = Balance.Weapons[arg]
		local owned = Combat.owned(player, arg)
		local cost = if owned then Balance.refillCost(def.Price) else def.Price
		if buy(player, cost) then
			Combat.give(player, arg)
			toast(player, if owned then "Arma reabastecida." else def.Name .. " equipada!", true)
			return true
		end
	elseif action == "Ammo" then
		if not Combat.hasEquipped(player) then toast(player, "Equipe uma arma primeiro."); return false end
		if buy(player, 45) then Combat.refill(player, nil, true); toast(player, "Munição completa.", true); return true end
	elseif action == "Upgrade" then
		if not World.Powered then toast(player, "Ligue a energia na central ao norte."); return false end
		if not Combat.canUpgrade(player) then toast(player, "Equipe uma arma abaixo do nível 3."); return false end
		if buy(player, Balance.UpgradeCost) then Combat.upgrade(player); toast(player, "Arma aprimorada! +45% do dano base por nível.", true); return true end
	elseif action == "Perk" then
		if not World.Powered then toast(player, "Os buffs precisam da energia da central."); return false end
		if player:GetAttribute(arg) then toast(player, "Esse buff já está ativo nesta partida."); return false end
		if buy(player, Balance.Perks[arg].Price) then
			player:SetAttribute(arg, true); Game.stats(player)
			toast(player, Balance.Perks[arg].Name .. " ativo até o fim da partida!", true)
			return true
		end
	elseif action == "Power" then
		if World.Powered then toast(player, "A energia já está ligada."); return false end
		if buy(player, 180) then
			World.Powered = true
			World.PowerPanel.Color = Color3.fromRGB(80, 255, 170)
			announce("ENERGIA RESTAURADA • buffs, aprimoramento e armadilha disponíveis")
			publish(); return true
		end
	elseif action == "Heal" then
		local _, hum = Util.alive(player)
		if hum.Health >= hum.MaxHealth then toast(player, "Sua vida está completa."); return false end
		if buy(player, 60) then hum.Health = hum.MaxHealth; toast(player, "Vida recuperada.", true); return true end
	elseif action == "RoundRevive" then
		if player:GetAttribute("BoughtRescue") then toast(player, "Você já comprou o resgate desta partida."); return false end
		if buy(player, 90) then
			player:SetAttribute("BoughtRescue", true)
			player:SetAttribute("RoundRevives", (player:GetAttribute("RoundRevives") or 0) + 1)
			toast(player, "Resgate pronto. Use o botão RESGATAR quando for eliminado.", true)
			return true
		end
	elseif action == "Loot" then
		local _, hum = Util.alive(player)
		local roll = rng:NextInteger(1, 3)
		if roll == 1 then Combat.refill(player, nil, false); toast(player, "Suprimentos: munição +25 moedas", true); Data.award(player, 25)
		elseif roll == 2 then hum.Health = math.min(hum.MaxHealth, hum.Health + 45); Data.award(player, 25); toast(player, "Suprimentos: cura +25 moedas", true)
		else Data.award(player, 65); toast(player, "Suprimentos: +65 moedas", true) end
		return true
	elseif action == "Mystery" then
		if Game.Mystery[player] == Game.Wave then toast(player, "Resgate gratuito já usado nesta horda."); return false end
		Game.Mystery[player] = Game.Wave
		local pool = { "Pistol", "SMG", "Shotgun", "Rifle" }
		local id = pool[rng:NextInteger(1, #pool)]
		Combat.give(player, id)
		toast(player, "Resgate gratuito: " .. Balance.Weapons[id].Name .. " • 25% cada arma", true)
		return true
	elseif action == "Repair" then
		Game.Repairs[player] = Game.Repairs[player] or {}
		if Game.Repairs[player][arg] == Game.Wave then toast(player, "Barricada reparada nesta horda."); return false end
		Game.Repairs[player][arg] = Game.Wave
		Data.award(player, 20); toast(player, "Barricada reforçada • +20 moedas", true)
		return true
	elseif action == "Trap" then
		local now = workspace:GetServerTimeNow()
		if not World.Powered then toast(player, "Ligue a energia primeiro."); return false end
		if Game.TrapCooldown > now then toast(player, "Armadilha recarregando • " .. math.ceil(Game.TrapCooldown - now) .. "s"); return false end
		if buy(player, 80) then
			Game.TrapUntil, Game.TrapCooldown = now + 12, now + 50
			remotes.Effects:FireAllClients("Trap", { Position = Vector3.new(0, 1, -18), Duration = 12 })
			return true
		end
	end
	return false
end

local function onKill(z)
	local killer = z.killer
	if killer and killer.Parent then
		local boosted = (killer:GetAttribute("BoostUntil") or 0) > os.time()
		local reward = Balance.killReward(Game.Wave, boosted) * (if z.boss then 6 else 1)
		Data.award(killer, reward, 1)
		killer:SetAttribute("RoundKills", (killer:GetAttribute("RoundKills") or 0) + 1)
		remotes.Effects:FireClient(killer, "Kill", { Coins = reward, Boss = z.boss })
	end
	for player in z.hits do if player ~= killer and player.Parent then Data.award(player, Balance.AssistCoins) end end
	if rng:NextNumber() < 0.17 then World.drop(z.root.Position, function(player) Combat.refill(player, nil, false) end) end
end

local function loadedPlayers()
	local result = {}
	for _, player in Players:GetPlayers() do if player:GetAttribute("DataReady") then table.insert(result, player) end end
	return result
end

local function hasSurvivors()
	if #loadedPlayers() == 0 then return false end
	if #Util.livingPlayers() > 0 or next(Game.Spawning) then Game.WipeAt = nil; return true end
	if not Game.WipeAt then Game.WipeAt = workspace:GetServerTimeNow() + 8; announce("EQUIPE ELIMINADA • 8 segundos para usar um resgate") end
	return workspace:GetServerTimeNow() < Game.WipeAt
end

local function phase(name, duration)
	Game.Phase, Game.EndsAt, Game.WipeAt = name, workspace:GetServerTimeNow() + (duration or 0), nil
	publish()
end

local function prep(initial)
	phase("Preparation", if initial then Balance.InitialPrep else Balance.BetweenWaves)
	Game.Repairs, Game.Mystery = {}, {}
	World.resetLoot()
	for _, player in loadedPlayers() do
		if not player:GetAttribute("InRound") or initial then task.spawn(Game.spawn, player, initial) end
		local alive, hum = Util.alive(player)
		if alive then hum.Health = hum.MaxHealth end
	end
	announce(if initial then "VOO 813 CAIU • explore, encontre armas e prepare a defesa" else "HORDA CONCLUÍDA • cure-se, reabasteça e prepare-se")
	if initial then World.crash() end
	while workspace:GetServerTimeNow() < Game.EndsAt do
		if #loadedPlayers() == 0 then return false end
		publish(); task.wait(0.4)
	end
	return true
end

local function runWave(wave)
	Game.Wave = wave
	local settings = Balance.wave(wave, #loadedPlayers())
	Game.Remaining = settings.Count + (if settings.Boss then 1 else 0)
	Game.Repairs, Game.Mystery = {}, {}
	World.resetLoot()
	phase("Wave", 0)
	announce("HORDA " .. wave .. (if settings.Boss then " • O COMANDANTE CHEGOU" else " • DEFENDAM A CIDADE"))
	if settings.Boss then Zombies.spawn(settings, true); Game.Remaining -= 1 end
	local nextSpawn = 0
	while Game.Remaining > 0 or Zombies.count() > 0 do
		if not hasSurvivors() then return false end
		if os.clock() >= nextSpawn and Game.Remaining > 0 and Zombies.count() < Balance.MaxLivingZombies then
			local spawned = Zombies.spawn(settings, false)
			if spawned then Game.Remaining -= 1 end
			nextSpawn = os.clock() + settings.SpawnInterval
		end
		publish(); task.wait(0.2)
	end
	for _, player in loadedPlayers() do Data.award(player, Balance.WaveCoins + wave * 3); Data.record(player, wave, false) end
	return true
end

local function extract()
	phase("Extraction", Balance.ExtractionTime)
	World.extraction()
	announce("RESGATE A CAMINHO • alcance o heliponto junto ao avião antes do cronômetro zerar")
	remotes.Effects:FireAllClients("Waypoint", { Position = World.Extraction })
	local nextSpawn = 0
	while workspace:GetServerTimeNow() < Game.EndsAt do
		if not hasSurvivors() then return false end
		if os.clock() > nextSpawn and Zombies.count() < 18 then
			Zombies.spawn(Balance.wave(Balance.FinalWave, #loadedPlayers()), false)
			nextSpawn = os.clock() + 1.4
		end
		publish(); task.wait(0.25)
	end
	local winners = 0
	for _, player in Util.livingPlayers() do
		local _, _, root = Util.alive(player)
		local delta = root.Position - World.Extraction
		if math.abs(delta.X) <= 16 and math.abs(delta.Z) <= 16 and root.Position.Y < 25 then
			winners += 1
			Data.award(player, Balance.ExtractionCoins)
			Data.record(player, Balance.FinalWave, true)
			toast(player, "EXTRAÍDO! +300 moedas • vitória salva", true)
		else toast(player, "O helicóptero partiu sem você. Alcance a zona verde na próxima tentativa.") end
	end
	return winners > 0
end

function Game.start(remoteFolder, stateFolder)
	remotes, state = remoteFolder, stateFolder
	World.build(Game.interact)
	Zombies.init(onKill)
	Combat.start(remotes)
	Data.start()
	Commerce.start(remotes.Effects, Game.stats)
	local allowAction = Util.limiter(5, 8)
	remotes.Action.OnServerEvent:Connect(function(player, action, arg)
		if not allowAction(player) or type(action) ~= "string" then return end
		if action == "Ready" then Commerce.sendCatalog(player, remotes.Effects); return end
		if not player:GetAttribute("DataReady") then return end
		if action == "Skin" and type(arg) == "string" and #arg < 30 then
			if Data.cosmetic(player, arg) then Combat.recolor(player); toast(player, "Acabamento equipado!", true)
			else toast(player, "Moedas insuficientes ou acabamento inválido.") end
		elseif action == "Sprint" and type(arg) == "boolean" then
			player:SetAttribute("Sprinting", arg and player:GetAttribute("InRound") and (player:GetAttribute("Stamina") or 0) > 5)
			Game.stats(player)
		elseif action == "Revive" then
			if Game.Phase ~= "Wave" and Game.Phase ~= "Extraction" then toast(player, "Você retorna automaticamente na próxima preparação."); return end
			if player:GetAttribute("InRound") or Game.Spawning[player] then return end
			local tokens = player:GetAttribute("RoundRevives") or 0
			if tokens > 0 then player:SetAttribute("RoundRevives", tokens - 1)
			elseif not Data.useRevive(player) then toast(player, "Sem resgates. Há um reanimador por moedas na igreja."); return end
			-- Invalidate the wipe timer immediately; spawning may yield for avatar loading.
			Game.WipeAt = nil
			task.spawn(Game.spawn, player, false)
		end
	end)
	Players.PlayerAdded:Connect(function(player) task.spawn(Game.addPlayer, player) end)
	Players.PlayerRemoving:Connect(function(player)
		Game.Spawning[player], Game.Repairs[player], Game.Mystery[player] = nil, nil, nil
	end)
	for _, player in Players:GetPlayers() do task.spawn(Game.addPlayer, player) end
	-- Server stamina and electric trap updates do not depend on client frame rate.
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local alive, hum, root = Util.alive(player)
				if alive then
					local stamina = player:GetAttribute("Stamina") or 100
					local velocity = root.AssemblyLinearVelocity
					local running = player:GetAttribute("Sprinting") and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 3
					stamina = math.clamp(stamina + (if running then -4 else 2.8), 0, 100)
					player:SetAttribute("Stamina", stamina)
					if stamina <= 0 and player:GetAttribute("Sprinting") then player:SetAttribute("Sprinting", false); Game.stats(player) end
				end
			end
			if workspace:GetServerTimeNow() < Game.TrapUntil then
				for model, z in Zombies.Active do
					if (z.root.Position - Vector3.new(0, 2, -18)).Magnitude < 25 then Zombies.damage(model, 18, nil) end
				end
			end
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			phase("Waiting", 0)
			while #loadedPlayers() == 0 do task.wait(1) end
			Game.Round += 1
			Game.Wave, Game.Remaining, Game.TrapUntil, Game.TrapCooldown = 0, 0, 0, 0
			Zombies.clear(); World.reset()
			local completed = prep(true)
			if completed then
				for wave = 1, Balance.FinalWave do
					if not runWave(wave) then completed = false; break end
					if wave < Balance.FinalWave and not prep(false) then completed = false; break end
				end
			end
			local won = completed and extract()
			Zombies.clear()
			phase(if won then "Victory" else "GameOver", 15)
			announce(if won then "ÚLTIMO VOO • SOBREVIVENTES EXTRAÍDOS" else "A CIDADE CAIU • REAGRUPANDO EM 15 SEGUNDOS")
			for _, player in loadedPlayers() do
				player:SetAttribute("InRound", false)
				task.spawn(Data.save, player, false)
			end
			task.wait(15)
		end
	end)
end

return Game
