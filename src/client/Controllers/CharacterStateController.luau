local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateMachine = require(ReplicatedStorage.Shared.Classes.StateMachine)
local CameraController = require(script.Parent.CameraController)
local CharacterController = require(script.Parent.CharacterController)

export type CharacterStateController = {
	Character: CharacterController.CharacterController,
	Camera: CameraController.CameraController,
	FSM: StateMachine.StateMachine<CharacterStateController>,
	Init: (
		self: CharacterStateController,
		controllers: {
			CameraController: CameraController.CameraController,
			CharacterController: CharacterController.CharacterController,
		}
	) -> (),
	Start: (self: CharacterStateController) -> (),
}
local CharacterStateController = {} :: CharacterStateController

local function calculateAnimationWeight(moveAngle: number, referenceAngle: number)
	local pi2 = math.pi * 2
	local pi = math.pi
	local diff = moveAngle - referenceAngle
	local wrap = (diff % pi2 + pi2) % pi2
	local short = math.min(wrap, pi2 - wrap)
	local weight = 1 - (short / (pi / 2))
	return math.clamp(weight, 0, 1)
end

CharacterStateController.FSM = StateMachine.new(CharacterStateController, {
	Idle = {
		OnEnter = function(host)
			host.Character:SetCapability("Movement", true)
			host.Character:SetCapability("Rotation", false)
			host.Camera:EnableAutoRotate(true)

			host.Character:PlayAnimation("Idle")
		end,
		OnUpdate = function(host)
			if not host.Character:IsGrounded() then
				host.FSM:Transition("Fall")
				return
			end

			if host.Character:IsMoving() then
				host.FSM:Transition("Walk")
				return
			end

			if host.Character:IsBindingDown("Roll") then
				host.FSM:Transition("Roll")
				return
			end
		end,
		OnExit = function(host)
			host.Character:SetCapability("Rotation", true)
			host.Character:StopAnimation("Idle")
			host.Camera:EnableAutoRotate(false)
		end,
	},
	Walk = {
		OnEnter = function(host)
			host.Character:SetCapability("Movement", true)
			host.Character:SetCapability("Rotation", true)

			host.Character:PlayAnimation("WalkForward", nil, 0)
			host.Character:PlayAnimation("WalkBackward", nil, 0)
			host.Character:PlayAnimation("WalkLeft", nil, 0)
			host.Character:PlayAnimation("WalkRight", nil, 0)
		end,
		OnUpdate = function(host)
			if not host.Character:IsGrounded() then
				host.FSM:Transition("Fall")
				return
			end

			if not host.Character:IsMoving() then
				host.FSM:Transition("Idle")
				return
			end

			if host.Character:IsBindingDown("Roll") then
				host.FSM:Transition("Roll")
				return
			end

			local movementDirection = host.Character.Movement.LastMoveDirection
			local lookVector = host.Character.Root.CFrame.LookVector
			local dotProduct = movementDirection:Dot(lookVector)
			local angle = math.atan2(movementDirection:Cross(lookVector).Y, dotProduct)

			local forwardWeight = calculateAnimationWeight(angle, 0)
			local backwardWeight = calculateAnimationWeight(angle, math.pi)
			local leftWeight = calculateAnimationWeight(angle, -math.pi / 2)
			local rightWeight = calculateAnimationWeight(angle, math.pi / 2)

			host.Character:AdjustAnimationWeight("WalkForward", forwardWeight, 0.1)
			host.Character:AdjustAnimationWeight("WalkBackward", backwardWeight, 0.1)
			host.Character:AdjustAnimationWeight("WalkLeft", leftWeight, 0.1)
			host.Character:AdjustAnimationWeight("WalkRight", rightWeight, 0.1)
		end,
		OnExit = function(host)
			host.Character:StopAnimations()
		end,
	},
	Roll = {
		Context = { Duration = 0.5 },
		OnEnter = function(host, context)
			host.Character:SetCapability("Movement", false)
			host.Character:SetCapability("Rotation", false)

			local moveDirection = host.Character.Movement.MoveDirection
			local lookDirection = host.Character.Root.CFrame.LookVector
			local dashDirection = moveDirection.Magnitude > 0 and moveDirection or -lookDirection

			host.Character:SetForcedVelocity(dashDirection * 100)

			context.StartTime = tick()

			local rollTrack = host.Character:GetAnimationTrack("RollForward")
			if rollTrack then
				context.Duration = rollTrack.Length
			end

			local dotProduct = dashDirection:Dot(lookDirection)
			local angle = math.atan2(dashDirection:Cross(lookDirection).Y, dotProduct)

			local forwardWeight = calculateAnimationWeight(angle, 0)
			local backwardWeight = calculateAnimationWeight(angle, math.pi)
			local leftWeight = calculateAnimationWeight(angle, -math.pi / 2)
			local rightWeight = calculateAnimationWeight(angle, math.pi / 2)

			if backwardWeight > 0.4 then
				host.Character:PlayAnimation("RollBackward")
			else
				host.Character:PlayAnimation("RollForward", nil, forwardWeight)
				host.Character:PlayAnimation("RollLeft", nil, leftWeight)
				host.Character:PlayAnimation("RollRight", nil, rightWeight)
			end
		end,
		OnUpdate = function(host, context)
			if tick() - context.StartTime >= context.Duration then
				host.FSM:Transition("Idle")
			end
		end,
		OnExit = function(host)
			host.Character:StopAnimations()
			host.Character:SetCapability("Movement", true)
			host.Character:SetCapability("Rotation", true)
			host.Character:SetForcedVelocity(nil)
		end,
	},
	Fall = {
		OnEnter = function(host, context)
			context.StartTime = tick()

			host.Character:PlayAnimation("Fall")
		end,
		OnUpdate = function(host, context)
			if host.Character:IsGrounded() then
				if tick() - context.StartTime >= 0.5 then
					host.FSM:Transition("Land")
					return
				end

				host.FSM:Transition("Idle")
			end
		end,
		OnExit = function(host)
			host.Character:StopAnimation("Fall")
		end,
	},
	Land = {
		Context = { Duration = 1 },
		OnEnter = function(host, context)
			host.Character:SetCapability("Movement", false)
			host.Character:SetCapability("Rotation", false)
			host.Character:PlayAnimation("Land")

			context.StartTime = tick()
		end,
		OnUpdate = function(host, context)
			if tick() - context.StartTime >= context.Duration then
				host.FSM:Transition("Idle")
				return
			end
		end,
		OnExit = function(host)
			host.Character:SetCapability("Movement", true)
			host.Character:SetCapability("Rotation", true)
			host.Character:StopAnimation("Land")
		end,
	},
})

function CharacterStateController.Init(self: CharacterStateController, controllers)
	self.Character = controllers.CharacterController
	self.Camera = controllers.CameraController

	self.Camera.LockOnTargetChanged:Connect(function(lockedOn)
		self.Character:SetLockToCamera(lockedOn)
	end)
end

function CharacterStateController.Start(self: CharacterStateController)
	self.FSM:Start("Idle")
end

return CharacterStateController
