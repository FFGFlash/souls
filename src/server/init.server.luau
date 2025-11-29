local ServicesFolder = script:WaitForChild("Services")

local Services = {}

print("Loading Services...")
for _, module in ipairs(ServicesFolder:GetChildren()) do
	if module:IsA("ModuleScript") then
		local service = require(module)
		Services[module.Name] = service
	end
end

print("Initializing Services...")
for _, service in pairs(Services) do
	if service.Init then
		service:Init(Services)
	end
end

print("Starting Services...")
for _, service in pairs(Services) do
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
end

print("Server Started")
