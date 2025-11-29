local Types = require(script.Types)

local CombatData: { [string]: Types.CombatData } = {}

for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") or module.Name == "Types" then
		continue
	end

	local item = require(module)
	if not item.Id then
		continue
	end

	CombatData[item.Id] = item
end

return CombatData
