local PathfindingService = game:GetService("PathfindingService")
local PhysicsService = game:GetService("PhysicsService")
local Debris = game:GetService("Debris")
local Util = require(script.Parent.Util)
local World = require(script.Parent.World)

local Zombies = { Active = {}, OnKill = nil, Serial = 0, Generation = 0 }
local rng = Random.new()

local function body(model, name, size, cf, color)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color, p.Material = name, size, cf, color, Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch = false, false, false
	p.CollisionGroup = "Infected"
	p.Parent = model
	return p
end

local function joint(parent, name, a, b, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name, motor.Part0, motor.Part1, motor.C0, motor.C1, motor.Parent = name, a, b, c0, c1, parent
	return motor
end

function Zombies.init(onKill)
	Zombies.OnKill = onKill
	pcall(function() PhysicsService:RegisterCollisionGroup("Infected") end)
	pcall(function() PhysicsService:RegisterCollisionGroup("Survivors") end)
	PhysicsService:CollisionGroupSetCollidable("Infected", "Infected", false)
	PhysicsService:CollisionGroupSetCollidable("Survivors", "Survivors", false)
	-- Contact still collides with the map; zombie damage is evaluated on the server.
	PhysicsService:CollisionGroupSetCollidable("Infected", "Survivors", false)
	task.spawn(function()
		while true do
			for model, z in Zombies.Active do
				if model.Parent and z.hum.Health > 0 then
					Zombies.step(z)
				end
			end
			task.wait(0.25)
		end
	end)
end

function Zombies.count()
	local count = 0
	for _ in Zombies.Active do count += 1 end
	return count
end

function Zombies.clear()
	Zombies.Generation += 1
	for model in Zombies.Active do model:Destroy() end
	table.clear(Zombies.Active)
	World.Enemies:ClearAllChildren()
end

function Zombies.spawn(settings, boss)
	local living = Util.livingPlayers()
	if #living == 0 then return end
	local candidates = {}
	for _, pos in World.SpawnPoints do
		local distance = math.huge
		for _, player in living do
			local _, _, root = Util.alive(player)
			distance = math.min(distance, (root.Position - pos).Magnitude)
		end
		if distance > 55 then table.insert(candidates, pos) end
	end
	local position = if #candidates > 0 then candidates[rng:NextInteger(1, #candidates)] else World.SpawnPoints[rng:NextInteger(1, #World.SpawnPoints)]
	position += Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
	local fast = not boss and rng:NextNumber() < 0.20
	local color = if boss then Color3.fromRGB(145, 60, 68) elseif fast then Color3.fromRGB(154, 146, 60) else Color3.fromRGB(88, 129, 89)
	local model = Instance.new("Model"); model.Name = if boss then "O Comandante" elseif fast then "Corredor infectado" else "Infectado"
	model:SetAttribute("Zombie", true)
	local cf = CFrame.new(position)
	local root = body(model, "HumanoidRootPart", Vector3.new(2, 2, 1), cf, color)
	root.Transparency, root.CanCollide = 1, true
	local torso = body(model, "Torso", Vector3.new(2, 2, 1), cf, Color3.fromRGB(47, 65, 60))
	local head = body(model, "Head", Vector3.new(2, 1, 1), cf * CFrame.new(0, 1.5, 0), color)
	local leftArm = body(model, "Left Arm", Vector3.new(1, 2, 1), cf * CFrame.new(-1.5, 0, 0), color)
	local rightArm = body(model, "Right Arm", Vector3.new(1, 2, 1), cf * CFrame.new(1.5, 0, 0), color)
	local leftLeg = body(model, "Left Leg", Vector3.new(1, 2, 1), cf * CFrame.new(-0.5, -2, 0), Color3.fromRGB(40, 44, 49))
	local rightLeg = body(model, "Right Leg", Vector3.new(1, 2, 1), cf * CFrame.new(0.5, -2, 0), Color3.fromRGB(40, 44, 49))
	joint(root, "RootJoint", root, torso, CFrame.identity, CFrame.identity)
	joint(torso, "Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	joint(torso, "Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	joint(torso, "Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	joint(torso, "Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))
	joint(torso, "Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	for _, x in { -0.5, 0.5 } do
		local eye = body(model, "Olho", Vector3.new(0.25, 0.18, 0.08), cf * CFrame.new(x, 1.65, -0.55), Color3.fromRGB(255, 91, 54))
		eye.Material = Enum.Material.Neon
		local weld = Instance.new("WeldConstraint"); weld.Part0, weld.Part1, weld.Parent = head, eye, eye
	end
	local hum = Instance.new("Humanoid")
	hum.MaxHealth = math.floor(settings.Health * (if boss then 7 + #living else 1))
	hum.Health, hum.WalkSpeed, hum.BreakJointsOnDeath = hum.MaxHealth, settings.Speed * (if fast then 1.35 elseif boss then 0.8 else 1), false
	hum.DisplayDistanceType, hum.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.Parent = root, World.Enemies
	if boss then model:ScaleTo(1.6) end
	root:SetNetworkOwner(nil)
	local gui = Instance.new("BillboardGui"); gui.Size, gui.StudsOffset, gui.MaxDistance, gui.Parent = UDim2.fromOffset(if boss then 160 else 70, 26), Vector3.new(0, if boss then 5 else 3.5, 0), 80, head
	local text = Instance.new("TextLabel"); text.Size, text.BackgroundTransparency, text.TextColor3, text.TextSize, text.Font, text.Parent = UDim2.fromScale(1, 1), 0.45, Color3.fromRGB(255, 190, 148), 12, Enum.Font.GothamBold, gui
	local function healthText() text.Text = (if boss then "COMANDANTE " else "") .. math.ceil(hum.Health) end
	healthText(); hum.HealthChanged:Connect(healthText)
	local z = { model = model, hum = hum, root = root, damage = settings.Damage * (if boss then 1.6 else 1),
		boss = boss, hits = {}, lastAttack = 0, lastPath = -rng:NextNumber(0, 3), pathing = false,
		born = os.clock(), lastPosition = position, lastProgress = os.clock(), waypoints = {}, waypoint = 1 }
	Zombies.Active[model] = z
	hum.Died:Connect(function()
		if not Zombies.Active[model] then return end
		Zombies.Active[model] = nil
		root.CanCollide = false
		for _, p in model:GetChildren() do if p:IsA("BasePart") then p.CanCollide = false; p.Transparency = 0.6 end end
		if Zombies.OnKill then Zombies.OnKill(z) end
		Debris:AddItem(model, 1)
	end)
	return model
end

function Zombies.damage(model, amount, player)
	local z = Zombies.Active[model]
	if not z or z.hum.Health <= 0 then return false end
	if player then
		z.hits[player] = (z.hits[player] or 0) + math.min(amount, z.hum.Health)
		z.killer = player
	end
	z.hum:TakeDamage(amount)
	return true
end

function Zombies.step(z)
	local now = os.clock()
	local torso = z.model:FindFirstChild("Torso")
	if torso then
		local scale = if z.boss then 1.6 else 1
		local stride = math.sin(now * (if z.boss then 5 else 8)) * 0.4
		torso["Left Shoulder"].C0 = CFrame.new(-scale, 0.5 * scale, 0) * CFrame.Angles(1.1 + stride * 0.2, 0, -0.12)
		torso["Right Shoulder"].C0 = CFrame.new(scale, 0.5 * scale, 0) * CFrame.Angles(1.1 - stride * 0.2, 0, 0.12)
		torso["Left Hip"].C0 = CFrame.new(-0.5 * scale, -scale, 0) * CFrame.Angles(stride, 0, 0)
		torso["Right Hip"].C0 = CFrame.new(0.5 * scale, -scale, 0) * CFrame.Angles(-stride, 0, 0)
	end
	local target, distance = nil, math.huge
	for _, player in Util.livingPlayers() do
		local _, _, root = Util.alive(player)
		local d = (root.Position - z.root.Position).Magnitude
		if d < distance then target, distance = player, d end
	end
	if not target then return end
	local _, hum, root = Util.alive(target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { World.Enemies, World.Drops }
	local obstacle = workspace:Raycast(z.root.Position, root.Position - z.root.Position, params)
	local visible = not obstacle or obstacle.Instance:IsDescendantOf(target.Character)
	if distance < (if z.boss then 7 else 4.8) and visible and now - z.lastAttack > 1.1 then
		z.lastAttack = now
		if (target:GetAttribute("InvulnerableUntil") or 0) < workspace:GetServerTimeNow() then hum:TakeDamage(z.damage) end
	end
	if visible then
		z.hum:MoveTo(root.Position)
		table.clear(z.waypoints)
	elseif not z.pathing and now - z.lastPath > 2.8 then
		z.lastPath, z.pathing = now, true
		local destination = root.Position
		local generation = Zombies.Generation
		task.spawn(function()
			local path = PathfindingService:CreatePath({ AgentRadius = if z.boss then 2.8 else 2, AgentHeight = if z.boss then 8 else 5, AgentCanJump = true, WaypointSpacing = 5 })
			local ok = pcall(function() path:ComputeAsync(z.root.Position, destination) end)
			if generation == Zombies.Generation and z.model.Parent and ok and path.Status == Enum.PathStatus.Success then
				z.waypoints, z.waypoint = path:GetWaypoints(), 2
			end
			path:Destroy(); z.pathing = false
		end)
	end
	if not visible then
		local point = z.waypoints[z.waypoint]
		if point then
			if (point.Position - z.root.Position).Magnitude < 4 then z.waypoint += 1; point = z.waypoints[z.waypoint] end
			if point then
				if point.Action == Enum.PathWaypointAction.Jump then z.hum.Jump = true end
				z.hum:MoveTo(point.Position)
			end
		else z.hum:MoveTo(root.Position) end
	end
	if (z.root.Position - z.lastPosition).Magnitude > 3 then z.lastPosition, z.lastProgress = z.root.Position, now end
	if now - z.lastProgress > 7 then z.hum.Jump = true end
	-- Avoid unwinnable waves when navigation fails. Despawn without kill rewards.
	if now - z.lastProgress > 28 or z.root.Position.Y < -25 then
		Zombies.Active[z.model] = nil
		z.model:Destroy()
	end
end

return Zombies
