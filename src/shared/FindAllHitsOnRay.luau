return function(origin: Vector3, direction: Vector3, params: RaycastParams)
	local p = RaycastParams.new()
	p.BruteForceAllSlow = params.BruteForceAllSlow
	p.CollisionGroup = params.CollisionGroup
	p.FilterDescendantsInstances = params.FilterDescendantsInstances
	p.FilterType = params.FilterType
	p.IgnoreWater = params.IgnoreWater
	p.RespectCanCollide = params.RespectCanCollide

	local targets = {}
	repeat
		local target = workspace:Raycast(origin, direction, p)
		if target then
			table.insert(targets, target)
			p:AddToFilter(target.Instance)
		end
	until not target
	return targets
end
