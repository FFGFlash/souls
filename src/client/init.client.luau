local ControllersFolder = script:WaitForChild("Controllers")

local Controllers = {}

print("Loading Controllers...")
for _, module in ipairs(ControllersFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local controller = require(module)
		Controllers[module.Name] = controller
	end
end

print("Initializing Controllers...")
for _, controller in pairs(Controllers) do
	if controller.Init then
		controller:Init(Controllers)
	end
end

print("Starting Controllers...")
for _, controller in pairs(Controllers) do
	if controller.Start then
		task.spawn(function()
			controller:Start()
		end)
	end
end

print("Client Started")
