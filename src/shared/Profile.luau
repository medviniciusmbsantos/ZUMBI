--!strict
-- Pure profile rules. This module performs no I/O and never runs imported code.
local Balance = require(script and script.Parent.Balance or "./Balance")
local Profile = {}
local MAX_INTEGER = 9007199254740991

function Profile.isInteger(value: any): boolean
	return type(value) == "number" and value == value and value >= 0
		and value <= MAX_INTEGER and value % 1 == 0
end

local function integer(value: any, fallback: number): number
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, MAX_INTEGER)
end

function Profile.copy(value: any): any
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in value do result[key] = Profile.copy(item) end
	return result
end

function Profile.normalize(raw: any): any
	local source = if type(raw) == "table" then raw else {}
	local result = {
		Version = 1,
		Coins = integer(source.Coins, Balance.StartingCoins),
		BestWave = integer(source.BestWave, 0),
		Wins = integer(source.Wins, 0),
		Kills = integer(source.Kills, 0),
		Skin = "Default",
		Skins = { Default = true },
		Revives = integer(source.Revives, 0),
		BoostUntil = integer(source.BoostUntil, 0),
		Receipts = {},
	}
	if type(source.Skins) == "table" then
		for key, owned in source.Skins do
			if type(key) == "string" and Balance.Skins[key] and owned == true then result.Skins[key] = true end
		end
	end
	if type(source.Skin) == "string" and result.Skins[source.Skin] then result.Skin = source.Skin end
	if type(source.Receipts) == "table" then
		for key, delivered in source.Receipts do
			if type(key) == "string" and #key > 0 and #key <= 200 and delivered == true then result.Receipts[key] = true end
		end
	end
	return result
end

function Profile.lockedByOther(raw: any, session: string, now: number): boolean
	if type(raw) ~= "table" or type(raw.Session) ~= "table" then return false end
	local lease = raw.Session
	return type(lease.Id) == "string" and lease.Id ~= session
		and Profile.isInteger(lease.Until) and lease.Until > now
end

function Profile.credit(data: any, coins: any, kills: any): boolean
	if not Profile.isInteger(coins) or not Profile.isInteger(kills) then return false end
	local nextCoins, nextKills = data.Coins + coins, data.Kills + kills
	if not Profile.isInteger(nextCoins) or not Profile.isInteger(nextKills) then return false end
	data.Coins, data.Kills = nextCoins, nextKills
	return true
end

function Profile.debit(data: any, amount: any): boolean
	if not Profile.isInteger(amount) or data.Coins < amount then return false end
	data.Coins -= amount
	return true
end

function Profile.grant(data: any, product: any, now: number): boolean
	if type(product) ~= "table" or not Profile.isInteger(product.Amount) or product.Amount == 0 then return false end
	local field, value
	if product.Grant == "Coins" then field, value = "Coins", data.Coins + product.Amount
	elseif product.Grant == "Revives" then field, value = "Revives", data.Revives + product.Amount
	elseif product.Grant == "Boost" then field, value = "BoostUntil", math.max(now, data.BoostUntil) + product.Amount
	else return false end
	if not Profile.isInteger(value) then return false end
	data[field] = value
	return true
end

return Profile
