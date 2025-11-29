local Types = require(script.Types)

local AssetData: { [string]: Types.AssetData } = {}

for _, module in script:GetChildren() do
	if not module:IsA("ModuleScript") or module.Name == "Types" then
		continue
	end

	local data = require(module)
	if not data.Id then
		continue
	end

	AssetData[data.Id] = data
end

return AssetData
