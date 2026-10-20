local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Balance = require(game.ReplicatedStorage.ZumbiShared.Balance)
local Config = require(game.ReplicatedStorage.ZumbiShared.Config)

local Data = { Profiles = {}, Loading = {} }
local store
local storeAvailable, storeResult = pcall(function() return DataStoreService:GetDataStore(Config.DataStoreName) end)
if storeAvailable then store = storeResult end
local session = game.JobId .. ":" .. HttpService:GenerateGUID(false)
local shuttingDown = false

local function defaults()
	return { Version = 1, Coins = Balance.StartingCoins, BestWave = 0, Wins = 0, Kills = 0,
		Skin = "Default", Skins = { Default = true }, Revives = 0, BoostUntil = 0, Receipts = {} }
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = copy(item) end
	return result
end

local function hydrate(raw)
	local result = defaults()
	if type(raw) ~= "table" then return result end
	for key, value in result do
		if type(raw[key]) == type(value) then result[key] = copy(raw[key]) end
	end
	result.Skins.Default = true
	if not Balance.Skins[result.Skin] or not result.Skins[result.Skin] then result.Skin = "Default" end
	return result
end

function Data.sync(player)
	local p = Data.Profiles[player]
	if not p then return end
	local d = p.data
	player:SetAttribute("Coins", d.Coins)
	player:SetAttribute("Revives", d.Revives)
	player:SetAttribute("Skin", d.Skin)
	player:SetAttribute("BestWave", d.BestWave)
	player:SetAttribute("Wins", d.Wins)
	player:SetAttribute("BoostUntil", d.BoostUntil)
	player:SetAttribute("DataPersistent", p.persistent)
	for key in Balance.Skins do player:SetAttribute("Skin_" .. key, d.Skins[key] == true) end
	local stats = player:FindFirstChild("leaderstats")
	if stats then stats.Abates.Value = d.Kills; stats.Recorde.Value = d.BestWave end
end

function Data.load(player)
	if Data.Loading[player] or Data.Profiles[player] then return end
	Data.Loading[player] = true
	local loaded
	local ok, err
	for attempt = 1, 3 do
		ok, err = pcall(function()
			assert(store, "DataStore unavailable in this place")
			loaded = store:UpdateAsync("u_" .. player.UserId, function(old)
				if type(old) == "table" and old.Session and old.Session.Id ~= session and old.Session.Until > os.time() then return nil end
				local d = hydrate(old)
				d.Session = { Id = session, Until = os.time() + 150 }
				return d
			end)
		end)
		if ok then break end
		if attempt < 3 then task.wait(attempt) end
	end
	Data.Loading[player] = nil
	if not player.Parent then
		if ok and loaded then
			pcall(function() store:UpdateAsync("u_" .. player.UserId, function(old)
				if old and old.Session and old.Session.Id == session then old.Session = nil; return old end
				return nil
			end) end)
		end
		return
	end
	if ok and not loaded then player:Kick("Seus dados estão abertos em outro servidor. Aguarde 2 minutos e tente novamente."); return end
	if not ok and not RunService:IsStudio() then
		warn("[ZUMBI] Profile load failed; purchases disabled: " .. tostring(err))
		player:Kick("Não foi possível carregar seus dados com segurança. Tente novamente em instantes.")
		return
	end
	if not ok then warn("[ZUMBI] Studio sem DataStore: progresso temporário; compras desativadas.") end
	Data.Profiles[player] = { data = hydrate(loaded), persistent = ok, busy = false, closing = false, lastSaved = os.clock() }
	local stats = Instance.new("Folder"); stats.Name = "leaderstats"; stats.Parent = player
	for _, key in { "Abates", "Recorde" } do local v = Instance.new("IntValue"); v.Name = key; v.Parent = stats end
	Data.sync(player)
	player:SetAttribute("DataReady", true)
end

function Data.award(player, coins, kills)
	local p = Data.Profiles[player]
	if not p or p.closing then return end
	p.data.Coins += math.max(0, math.floor(coins or 0))
	p.data.Kills += math.max(0, math.floor(kills or 0))
	Data.sync(player)
end

function Data.spend(player, amount)
	local p = Data.Profiles[player]
	if not p or p.closing or amount < 0 or p.data.Coins < amount then return false end
	p.data.Coins -= amount
	Data.sync(player)
	return true
end

function Data.record(player, wave, won)
	local p = Data.Profiles[player]
	if not p then return end
	p.data.BestWave = math.max(p.data.BestWave, wave)
	if won then p.data.Wins += 1 end
	Data.sync(player)
end

function Data.cosmetic(player, key)
	local skin = Balance.Skins[key]
	local p = Data.Profiles[player]
	if not p or not skin then return end
	if not p.data.Skins[key] then
		if not Data.spend(player, skin.Price) then return false end
		p.data.Skins[key] = true
	end
	p.data.Skin = key
	Data.sync(player)
	return true
end

function Data.useRevive(player)
	local p = Data.Profiles[player]
	if not p or p.closing or p.data.Revives < 1 then return false end
	p.data.Revives -= 1
	Data.sync(player)
	return true
end

local function lock(p)
	while p.busy do task.wait(0.05) end
	p.busy = true
end

function Data.save(player, release)
	local p = Data.Profiles[player]
	if not p then return true end
	if not p.persistent then
		if release then Data.Profiles[player] = nil end
		return true
	end
	lock(p)
	if release then p.closing = true end
	local snapshot = copy(p.data)
	snapshot.Session = if release then nil else { Id = session, Until = os.time() + 150 }
	local saved
	local ok, err = pcall(function()
		saved = store:UpdateAsync("u_" .. player.UserId, function(old)
			if not old or not old.Session or old.Session.Id ~= session then return nil end
			return snapshot
		end)
	end)
	p.busy = false
	if ok and saved then
		p.lastSaved = os.clock()
		if release then Data.Profiles[player] = nil end
		return true
	end
	warn("[ZUMBI] Save failed: " .. tostring(err or "session ownership lost"))
	if not release and os.clock() - p.lastSaved > 95 then
		p.closing = true
		player:SetAttribute("DataPersistent", false)
		player:Kick("Conexão com seus dados interrompida. Reconecte para proteger seu progresso.")
	end
	return false
end

local function applyProduct(d, product)
	if product.Grant == "Coins" then d.Coins += product.Amount
	elseif product.Grant == "Revives" then d.Revives += product.Amount
	elseif product.Grant == "Boost" then d.BoostUntil = math.max(os.time(), d.BoostUntil) + product.Amount end
end

-- Acknowledge ONLY after the entitlement and receipt ID are saved atomically.
function Data.receipt(player, receiptId, product)
	local p = Data.Profiles[player]
	if not p or not p.persistent or p.closing then return false end
	lock(p)
	if p.closing then p.busy = false; return false end
	if p.data.Receipts[receiptId] then p.busy = false; return true end
	local snapshot = copy(p.data)
	local saved
	local ok = pcall(function()
		saved = store:UpdateAsync("u_" .. player.UserId, function(old)
			if not old or not old.Session or old.Session.Id ~= session then return nil end
			if old.Receipts and old.Receipts[receiptId] then return old end
			local result = copy(snapshot)
			applyProduct(result, product)
			result.Receipts[receiptId] = true
			result.Session = { Id = session, Until = os.time() + 150 }
			return result
		end)
	end)
	if ok and saved and saved.Receipts[receiptId] then
		-- Apply a delta so gameplay earnings made while UpdateAsync yielded survive.
		applyProduct(p.data, product)
		p.data.Receipts[receiptId] = true
		p.lastSaved = os.clock()
		Data.sync(player)
		p.busy = false
		return true
	end
	p.busy = false
	return false
end

function Data.start()
	Players.PlayerRemoving:Connect(function(player)
		for attempt = 1, 3 do if Data.save(player, true) then break end; task.wait(attempt) end
	end)
	task.spawn(function()
		while not shuttingDown do
			task.wait(40)
			for player in Data.Profiles do task.spawn(Data.save, player, false) end
		end
	end)
	game:BindToClose(function()
		shuttingDown = true
		local pending = 0
		for player in Data.Profiles do
			pending += 1
			task.spawn(function()
				for attempt = 1, 3 do if Data.save(player, true) then break end; task.wait(attempt) end
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
	end)
end

return Data
