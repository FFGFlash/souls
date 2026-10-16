--!strict
-- Thin wrapper around the Gizmo package so debug drawing is typed, Studio-only and free when disabled.
-- Gizmo is immediate mode: call these every frame you want something visible.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DebugConfig = require(script.Parent.Parent.Config.Debug)

local DebugDraw = {}

DebugDraw.Enabled = DebugConfig.Enabled and RunService:IsStudio()

local gizmo: any = nil

local function getGizmo(): any
	if not gizmo then
		gizmo = require(ReplicatedStorage.Packages.Gizmo) :: any
		gizmo.Init()
	end
	return gizmo
end

function DebugDraw.Ray(from: Vector3, to: Vector3, color: Color3)
	if not DebugDraw.Enabled then
		return
	end
	local g = getGizmo()
	g.PushProperty("Color3", color)
	g.Ray:Draw(from, to)
end

function DebugDraw.Sphere(position: Vector3, radius: number, color: Color3)
	if not DebugDraw.Enabled then
		return
	end
	local g = getGizmo()
	g.PushProperty("Color3", color)
	g.Sphere:Draw(CFrame.new(position), radius, 12, 360)
end

function DebugDraw.Text(position: Vector3, text: string, color: Color3?)
	if not DebugDraw.Enabled then
		return
	end
	local g = getGizmo()
	g.PushProperty("Color3", color or Color3.new(1, 1, 1))
	g.Text:Draw(position, text, 16)
end

return DebugDraw
