local Types = require(script.Types)

local Items: { [string]: Types.Item } = {}

for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") or module.Name == "Types" then
		continue
	end

	local item = require(module)
	if not item.Id then
		continue
	end

	Items[item.Id] = item
end

return Items
