--!strict
-- Frame-rate independent smoothing and small vector/angle helpers.
--
-- Yaw convention matches Roblox: CFrame.Angles(0, yaw, 0).LookVector == DirectionFromYaw(yaw).

local MathUtil = {}

local TAU = 2 * math.pi

-- Fraction of the remaining distance to cover this frame for exponential damping at `rate` (1/s).
function MathUtil.ExpAlpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

function MathUtil.Damp(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * MathUtil.ExpAlpha(rate, dt)
end

function MathUtil.DampVector(current: Vector3, target: Vector3, rate: number, dt: number): Vector3
	return current:Lerp(target, MathUtil.ExpAlpha(rate, dt))
end

-- Wraps an angle into [-pi, pi).
function MathUtil.WrapAngle(angle: number): number
	return (angle + math.pi) % TAU - math.pi
end

function MathUtil.DampAngle(current: number, target: number, rate: number, dt: number): number
	return current + MathUtil.WrapAngle(target - current) * MathUtil.ExpAlpha(rate, dt)
end

function MathUtil.MoveTowards(current: number, target: number, maxDelta: number): number
	if math.abs(target - current) <= maxDelta then
		return target
	end
	return current + math.sign(target - current) * maxDelta
end

function MathUtil.Flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

-- Flattened unit vector, or zero if the flattened vector is (nearly) zero.
function MathUtil.FlatUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	local magnitude = flat.Magnitude
	if magnitude < 1e-4 then
		return Vector3.zero
	end
	return flat / magnitude
end

function MathUtil.YawFromDirection(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

function MathUtil.DirectionFromYaw(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- Signed angle (radians) of `direction` relative to `forward`, around +Y. Positive = to the right of forward.
function MathUtil.SignedAngleY(forward: Vector3, direction: Vector3): number
	return MathUtil.WrapAngle(MathUtil.YawFromDirection(forward) - MathUtil.YawFromDirection(direction))
end

-- Weight in [0, 1] for a directional animation authored at `referenceAngle`: 1 when aligned, 0 at 90 degrees off.
function MathUtil.DirectionalWeight(angle: number, referenceAngle: number): number
	local difference = math.abs(MathUtil.WrapAngle(angle - referenceAngle))
	return math.clamp(1 - difference / (math.pi / 2), 0, 1)
end

-- Samples a piecewise linear curve given as sorted { {t, value} } keys.
function MathUtil.SampleCurve(keys: { { number } }, t: number): number
	local first = keys[1]
	if t <= first[1] then
		return first[2]
	end
	for index = 2, #keys do
		local key = keys[index]
		if t <= key[1] then
			local previous = keys[index - 1]
			local alpha = (t - previous[1]) / (key[1] - previous[1])
			return previous[2] + (key[2] - previous[2]) * alpha
		end
	end
	return keys[#keys][2]
end

-- Applies a radial deadzone to a stick vector, rescaling the remaining range to [0, 1] and keeping direction.
function MathUtil.RadialDeadzone(stick: Vector2, inner: number, outer: number): Vector2
	local magnitude = stick.Magnitude
	if magnitude <= inner then
		return Vector2.zero
	end
	local scaled = math.clamp((magnitude - inner) / (outer - inner), 0, 1)
	return stick / magnitude * scaled
end

return MathUtil
