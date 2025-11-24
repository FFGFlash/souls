local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RemoteEvent = {}
RemoteEvent.__index = RemoteEvent

function RemoteEvent.new(name: string)
	local event
	if RunService:IsServer() then
		event = Instance.new("RemoteEvent")
		event.name = "Event_" .. name
		event.Parent = ReplicatedStorage
	else
		event = ReplicatedStorage:WaitForChild("Event_" .. name)
	end
	return event
end

return RemoteEvent
