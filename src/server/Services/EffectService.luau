local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Shared.Classes.Packet)
local Task = require(ReplicatedStorage.Shared.Classes.Task)
export type EffectService = {
	Init: (self: EffectService, services: {}) -> (),
	Start: (self: EffectService) -> (),
	OnEffect: (self: EffectService, player: Player, effect: string | Instance, transform: CFrame) -> (),
	SetCooldown: (self: EffectService, player: Player, cooldown: number) -> (),
	CheckCooldown: (self: EffectService, player: Player) -> (),
	EffectPacket: Packet.Packet<Instance | string, CFrame>,
	Effects: {
		Cooldown: number,
		ActiveCooldowns: { [string]: boolean },
	},
}

local EffectService = {} :: EffectService

EffectService.EffectPacket = Packet("Effect", Packet.Any, Packet.CFrameF32U16)

function EffectService:Init() end

function EffectService:Start()
	self.EffectPacket.OnServerEvent:Connect(function(...)
		self:OnEffect(...)
	end)
end

function EffectService:OnEffect(player, effect, transform)
	if self:CheckCooldown(player) then
		return
	end

	self.EffectPacket:Fire(effect, transform)

	self:SetCooldown(player, self.Effects.Cooldown)
end

function EffectService:SetCooldown(player, cooldown)
	local userId = player.UserId

	self.Effects.ActiveCooldowns[userId] = true
	Task:Delay(cooldown, function(userId)
		self.Effects.ActiveCooldowns[userId] = nil
	end, userId)
end

function EffectService:CheckCooldown(player)
	return self.Effects.ActiveCooldowns[player.UserId] == true
end
