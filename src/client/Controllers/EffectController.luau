local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packet = require(ReplicatedStorage.Shared.Classes.Packet)
export type EffectController = {
	Init: (self: EffectController, controllers: {}) -> (),
	Start: (self: EffectController) -> (),
	PlayEffect: (self: EffectController, effect: string | Instance, transform: CFrame) -> (),
	EffectPacket: Packet.Packet<Instance | string>,
}

local EffectController = {} :: EffectController

EffectController.EffectPacket = Packet("Effect", Packet.Any, Packet.CFrameF32U16)

function EffectController:Init() end
function EffectController:Start() end

function EffectController:PlayEffect(effect, transform)
	self.EffectPacket:Fire(effect, transform)
end

return EffectController
