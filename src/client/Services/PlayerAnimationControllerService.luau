local Players = game:GetService("Players")
local PlayerAnimationControllerService = {}
export type PlayerAnimationControllerService = typeof(PlayerAnimationControllerService)

PlayerAnimationControllerService.AnimationIDs = {} :: { [string]: string }
PlayerAnimationControllerService.Tracks = {} :: { [string]: AnimationTrack }
PlayerAnimationControllerService.Animator = nil :: Animator?

local function loadAnimation(animtor: Animator, name: string, animationId: string)
	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = animationId
	local track = animtor:LoadAnimation(animation)
	if not track then
		warn("Failed to load animation " .. name .. " (" .. animationId .. ")")
	end
	track.Name = name
	return track
end

function PlayerAnimationControllerService.Init(self: PlayerAnimationControllerService)
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(function(char)
		self.Animator = char:WaitForChild("Humanoid"):WaitForChild("Animator")

		for name, id in pairs(self.AnimationIDs) do
			self.Tracks[name] = loadAnimation(self.Animator, name, id)
		end
	end)
end

function PlayerAnimationControllerService.LoadAnimation(
	self: PlayerAnimationControllerService,
	name: string,
	animationId: string
): AnimationTrack?
	if self.AnimationIDs[name] then
		warn("Animation name taken: " .. name .. " (" .. self.AnimationIDs[name] .. ") -> (" .. animationId .. ")")
		return
	end
	self.AnimationIDs[name] = animationId

	if self.Animator then
		self.Tracks[name] = loadAnimation(self.Animator, name, animationId)

		return self.Tracks[name]
	end

	return nil
end

function PlayerAnimationControllerService.GetTrack(self: PlayerAnimationControllerService, name: string)
	if not self.AnimationIDs[name] then
		error("Animation not found: " .. name)
	end

	repeat
		wait()
	until self.Tracks[name] ~= nil

	return self.Tracks[name]
end

function PlayerAnimationControllerService.StopAll(self: PlayerAnimationControllerService)
	if not self.Animator then
		return
	end
	for _, track in pairs(self.Animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end
end

return PlayerAnimationControllerService
