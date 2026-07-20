--!strict
--@author: Shadow
--@date: 2026/07/01
--[[@description:
	Hitbox builder and runtime execution service.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local HitboxTypes = require("./HitboxTypes")
local HitboxNetwork = require("./HitboxNetwork")

-----------------------------
-- TYPES --
-----------------------------
type HitboxConfig = HitboxTypes.HitboxConfig
type ShapeType = HitboxTypes.ShapeType
type FilterFunction = HitboxTypes.FilterFunction
type HitCallback = HitboxTypes.HitCallback

type HitboxObjectType = HitboxConfig

-----------------------------
-- VARIABLES --
-----------------------------
local HitboxService = {}
local HitboxObject = {}
HitboxObject.__index = HitboxObject

local DEBUG_MODE = true
local DEBUG_DURATION = 0.1

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local function GetValidTarget(part: BasePart): Model?
	local model = part.Parent
	if not model then
		return nil
	end

	if model:IsA("Accessory") then
		model = model.Parent
	end

	if not model or not model:IsA("Model") then
		return nil
	end

	if model:FindFirstChildOfClass("Humanoid") then
		return model
	end

	return nil
end

local function ExtractRootPart(instance: Instance?): BasePart?
	if not instance then
		return nil
	end

	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		local humanoidRootPart = instance:FindFirstChild("HumanoidRootPart")
		if humanoidRootPart and humanoidRootPart:IsA("BasePart") then
			return humanoidRootPart
		end
		return instance.PrimaryPart
	end

	return nil
end

local function BuildHitboxObject(shape: ShapeType, size: Vector3, radius: number, angle: number): HitboxObjectType
	local object: HitboxObjectType = {
		_shape = shape,
		_size = size,
		_radius = radius,
		_angle = angle,
		_source = nil,
		_offset = CFrame.new(),
		_ignoreList = {},
		_filterPredicate = nil,
		_growthRate = 0,
	}

	setmetatable(object :: any, HitboxObject)
	return object
end

local function RenderDebug(shape: ShapeType, cf: CFrame, size: Vector3, radius: number)
	if not DEBUG_MODE then
		return
	end

	local part = Instance.new("Part")
	part.Name = "SERVER_DEBUG_HITBOX"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(255, 0, 0)
	part.Transparency = 0.8
	part.CFrame = cf

	if shape == "Block" then
		part.Size = size
	elseif shape == "Sphere" then
		part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		part.Shape = Enum.PartType.Ball
	elseif shape == "Cylinder" then
		part.Size = size
		part.Shape = Enum.PartType.Cylinder
	elseif shape == "Cone" then
		part.Size = Vector3.new(radius * 2, 2, radius)
		part.Shape = Enum.PartType.CornerWedge
		part.CFrame = cf * CFrame.new(0, 0, -(radius / 2))
	else
		part.Size = Vector3.new(1, 1, math.max(size.Magnitude, 1))
	end

	part.Parent = Workspace
	Debris:AddItem(part, DEBUG_DURATION)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
function HitboxService.NewBlock(size: Vector3): HitboxObjectType
	return BuildHitboxObject("Block", size, 0, 0)
end

function HitboxService.NewSphere(radius: number): HitboxObjectType
	return BuildHitboxObject("Sphere", Vector3.zero, radius, 0)
end

function HitboxService.NewCylinder(length: number, radius: number): HitboxObjectType
	return BuildHitboxObject("Cylinder", Vector3.new(length, radius * 2, radius * 2), radius, 0)
end

function HitboxService.NewRaycast(direction: Vector3): HitboxObjectType
	return BuildHitboxObject("Raycast", direction, 0, 0)
end

function HitboxService.NewCone(radius: number, angleDegrees: number): HitboxObjectType
	return BuildHitboxObject("Cone", Vector3.zero, radius, angleDegrees)
end

function HitboxObject.RelativeTo(self: HitboxObjectType, sourceInstance: Instance): HitboxObjectType
	self._source = sourceInstance
	table.insert(self._ignoreList, sourceInstance)
	return self
end

function HitboxObject.Ignore(self: HitboxObjectType, instances: { Instance }): HitboxObjectType
	for _, instance in ipairs(instances) do
		table.insert(self._ignoreList, instance)
	end
	return self
end

function HitboxObject.Filter(self: HitboxObjectType, predicate: FilterFunction): HitboxObjectType
	self._filterPredicate = predicate
	return self
end

function HitboxObject.WithGrowth(self: HitboxObjectType, studsPerSecond: number): HitboxObjectType
	self._growthRate = studsPerSecond
	return self
end

function HitboxObject.FromPoint(self: HitboxObjectType, targetPoint: Vector3 | CFrame): HitboxObjectType
	self._source = nil
	if typeof(targetPoint) == "Vector3" then
		self._offset = CFrame.new(targetPoint)
	else
		self._offset = targetPoint
	end
	return self
end

function HitboxObject.AroundSelf(self: HitboxObjectType): HitboxObjectType
	self._offset = CFrame.new()
	return self
end

function HitboxObject.ForwardBox(self: HitboxObjectType, forwardDistance: number): HitboxObjectType
	self._offset = CFrame.new(0, 0, -forwardDistance)
	return self
end

function HitboxObject.ForwardCylinder(self: HitboxObjectType, forwardDistance: number): HitboxObjectType
	self._offset = CFrame.new(0, 0, -(forwardDistance / 2)) * CFrame.Angles(0, math.rad(90), 0)
	return self
end

function HitboxObject.ForwardRay(self: HitboxObjectType, range: number): HitboxObjectType
	local root = ExtractRootPart(self._source)
	if root then
		self._size = root.CFrame.LookVector * range
	end
	return self
end

function HitboxObject.CalculateTargets(self: HitboxObjectType): ({ Model }, CFrame)
	local root = ExtractRootPart(self._source)
	local sourceCFrame = root and root.CFrame or CFrame.new()
	local targetCFrame = self._source and (sourceCFrame * self._offset) or self._offset

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Exclude
	overlapParams.FilterDescendantsInstances = self._ignoreList
	overlapParams.MaxParts = 0

	local partsFound: { BasePart } = {}

	if self._shape == "Block" then
		partsFound = Workspace:GetPartBoundsInBox(targetCFrame, self._size, overlapParams)
	elseif self._shape == "Sphere" then
		partsFound = Workspace:GetPartBoundsInRadius(targetCFrame.Position, self._radius, overlapParams)
	elseif self._shape == "Cylinder" then
		local boundingBoxSize = Vector3.new(self._size.X, self._radius * 2, self._radius * 2)
		local potentialParts = Workspace:GetPartBoundsInBox(targetCFrame, boundingBoxSize, overlapParams)
		for _, part in ipairs(potentialParts) do
			local localPos = targetCFrame:PointToObjectSpace(part.Position)
			if
				math.abs(localPos.X) <= (self._size.X / 2)
				and math.sqrt(localPos.Y ^ 2 + localPos.Z ^ 2) <= self._radius
			then
				table.insert(partsFound, part)
			end
		end
	elseif self._shape == "Cone" then
		local potentialParts = Workspace:GetPartBoundsInRadius(targetCFrame.Position, self._radius, overlapParams)
		for _, part in ipairs(potentialParts) do
			local localPos = targetCFrame:PointToObjectSpace(part.Position)
			if localPos.Z < 0 then
				local angleToTarget = math.deg(math.atan2(localPos.X, -localPos.Z))
				if math.abs(angleToTarget) <= (self._angle / 2) then
					table.insert(partsFound, part)
				end
			end
		end
	elseif self._shape == "Raycast" and root then
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = self._ignoreList

		local result = Workspace:Raycast(targetCFrame.Position, self._size, raycastParams)
		if result and result.Instance and result.Instance:IsA("BasePart") then
			partsFound = { result.Instance }
		end
	end

	local uniqueTargets: { Model } = {}
	local seen: { [Model]: boolean } = {}

	for _, part in ipairs(partsFound) do
		local target = GetValidTarget(part)
		if target and not seen[target] then
			seen[target] = true
			local isAllowed = not self._filterPredicate or self._filterPredicate(target)
			if isAllowed then
				table.insert(uniqueTargets, target)
			end
		end
	end

	return uniqueTargets, targetCFrame
end

function HitboxObject.DrawDebugVisual(self: HitboxObjectType, debugColor: Color3, displayDuration: number?): { Model }
	local duration = displayDuration or 0.4
	local targets, targetCFrame = HitboxObject.CalculateTargets(self)

	local debugPart = Instance.new("Part")
	debugPart.Name = "MANUAL_DEBUG_HITBOX"
	debugPart.Anchored = true
	debugPart.CanCollide = false
	debugPart.CanQuery = false
	debugPart.CanTouch = false
	debugPart.Material = Enum.Material.Neon
	debugPart.Transparency = 0.75
	debugPart.Color = debugColor
	debugPart.CFrame = targetCFrame

	if self._shape == "Block" then
		debugPart.Shape = Enum.PartType.Block
		debugPart.Size = self._size
	elseif self._shape == "Sphere" then
		debugPart.Shape = Enum.PartType.Ball
		debugPart.Size = Vector3.new(self._radius * 2, self._radius * 2, self._radius * 2)
	elseif self._shape == "Cylinder" then
		debugPart.Shape = Enum.PartType.Cylinder
		debugPart.Size = Vector3.new(self._size.X, self._radius * 2, self._radius * 2)
	else
		debugPart.Shape = Enum.PartType.Block
		debugPart.Size = Vector3.new(1, 1, if self._size.Magnitude > 0 then self._size.Magnitude else 1)
	end

	debugPart.Parent = Workspace

	task.delay(duration, function()
		local tween = TweenService:Create(debugPart, TweenInfo.new(0.15), { Transparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			debugPart:Destroy()
		end)
	end)

	return targets
end

function HitboxService.ExecuteInstant(hitbox: HitboxObjectType): { Model }
	local targets, targetCFrame = HitboxObject.CalculateTargets(hitbox)
	RenderDebug(hitbox._shape, targetCFrame, hitbox._size, hitbox._radius)

	if HitboxNetwork.VisualRemote then
		HitboxNetwork.VisualRemote:FireAllClients(hitbox._shape, targetCFrame, hitbox._size, hitbox._radius)
	end

	return targets
end

function HitboxService.StartTracking(hitbox: HitboxObjectType, duration: number, onHitCallback: HitCallback)
	local hitHistory: { [Model]: boolean } = {}
	local elapsedTime = 0

	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(deltaTime)
		elapsedTime += deltaTime
		if elapsedTime >= duration then
			connection:Disconnect()
			return
		end

		if hitbox._growthRate > 0 then
			local growth = hitbox._growthRate * deltaTime
			hitbox._radius += growth
			hitbox._size += Vector3.new(growth, growth, growth)
		end

		local targets, targetCFrame = HitboxObject.CalculateTargets(hitbox)
		RenderDebug(hitbox._shape, targetCFrame, hitbox._size, hitbox._radius)

		for _, target in ipairs(targets) do
			if not hitHistory[target] then
				hitHistory[target] = true
				onHitCallback(target)
				if HitboxNetwork.VisualRemote then
					HitboxNetwork.VisualRemote:FireAllClients("HitImpactVisual", target)
				end
			end
		end
	end)
end

-----------------------------
-- MAIN --
-----------------------------
return table.freeze(HitboxService)
