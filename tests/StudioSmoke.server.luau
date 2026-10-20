-- Included only by build_place.py --smoke-test. Requires Studio Play (F5).
-- Engine checks have NOT been executed by the Linux/cloud test runner.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio(), "Smoke tests are only allowed in Roblox Studio")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local count = 0
local function check(condition, message)
	assert(condition, "[ZUMBI SMOKE] FAIL: " .. message)
	count += 1
	print("[ZUMBI SMOKE] PASS: " .. message)
end

local deadline = os.clock() + 60
local player
repeat
	player = Players:GetPlayers()[1]
	if player and player:GetAttribute("InRound") then break end
	task.wait(0.2)
until os.clock() > deadline
check(player and player:GetAttribute("InRound"), "Player profile and character ready")

local server = game.ServerScriptService:WaitForChild("ZumbiServer")
local World = require(server.World)
local Combat = require(server.CombatService)
local Zombies = require(server.ZombieService)
local Util = require(server.Util)
local Balance = require(ReplicatedStorage.ZumbiShared.Balance)

check(World.Map ~= nil and #World.Map:GetDescendants() > 500, "Runtime map built")
for _, name in { "Igreja da Aurora", "Delegacia", "Hospital", "Oficina", "Mercado", "Cemitério", "Cripta", "Central de energia" } do
	check(World.Map:FindFirstChild(name) ~= nil, "Location: " .. name)
end
check(#World.Loot == 10, "Ten loot crates")
check(#World.Doors == 3, "Three shared unlockable doors")
check(not Util.near(player, Vector3.new(900, 0, 900), 13), "Remote interaction distance rejects distant points")

local alive, hum, root = Util.alive(player)
check(alive, "Player alive")
player.Character:PivotTo(CFrame.new(0, 4, 80))
local target = Zombies.spawn({ Health = 1000, Damage = 0, Speed = 0 }, false)
check(target ~= nil, "Zombie rig spawned")
target:PivotTo(CFrame.new(0, 3.5, 59))
target.HumanoidRootPart.Anchored = true
local targetHum = target:FindFirstChildOfClass("Humanoid")
local tool = player.Character:FindFirstChildOfClass("Tool")
check(tool and tool:GetAttribute("WeaponId") == "Pistol", "Pistol equipped on spawn")
local beforeAmmo, beforeHealth = tool:GetAttribute("Ammo"), targetHum.Health
Combat.fire(player, target.Head.Position)
check(tool:GetAttribute("Ammo") == beforeAmmo - 1, "Accepted shot consumes one round")
check(targetHum.Health < beforeHealth, "Server raycast damages actual zombie")
Combat.fire(player, target.Head.Position)
check(tool:GetAttribute("Ammo") == beforeAmmo - 1, "Impossible fire rate rejected")
Combat.fire(player, Vector3.new(0 / 0, 0, 0))
check(tool:GetAttribute("Ammo") == beforeAmmo - 1, "NaN aim rejected")

local wall = Instance.new("Part")
wall.Name, wall.Size, wall.CFrame = "SmokeCover", Vector3.new(12, 12, 2), CFrame.new(0, 5, 70)
wall.Anchored, wall.Parent = true, workspace
task.wait(Balance.Weapons.Pistol.Interval + 0.1)
local coveredHealth = targetHum.Health
Combat.fire(player, target.Head.Position)
check(tool:GetAttribute("Ammo") == beforeAmmo - 2, "Second legitimate shot accepted")
check(targetHum.Health == coveredHealth, "Solid cover blocks damage")
wall:Destroy()
Combat.reload(player)
check(tool:GetAttribute("Reloading") == true, "Server reload begins")
task.wait(Balance.Weapons.Pistol.Reload + 0.3)
check(tool:GetAttribute("Ammo") == Balance.Weapons.Pistol.Magazine, "Reload restores magazine")
check(tool:GetAttribute("Reserve") == Balance.Weapons.Pistol.Reserve - 2, "Reload consumes reserve")
local beforeKills = player:GetAttribute("RoundKills") or 0
Zombies.damage(target, 100000, player)
task.wait(0.1)
check(not Zombies.Active[target], "Zombie removed from wave accounting on death")
check(player:GetAttribute("RoundKills") == beforeKills + 1, "Server attributes kill and reward")
print("[ZUMBI SMOKE] COMPLETED: " .. count .. " engine checks passed. Manual multi-player/mobile/extraction checks still required.")
