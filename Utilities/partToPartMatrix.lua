--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's partToPartMatrix v1.1

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/partToPartMatrix.lua
]]

---Returns the matrix chain of this ModelPart
---@param mdp ModelPart?
---@return Matrix4
---@nodiscard
local function get_part_matrix(mdp)
	local mat = matrices.mat4()
	while mdp ~= nil do
		mat = mdp:getPositionMatrixRaw() * mat
		mdp = mdp:getParent()
	end
	return mat
end

---Returns a matrix representing the transformation from one ModelPart to another in the same world space
---@param mdp_a ModelPart
---@param mdp_b ModelPart
---@return Matrix4
---@nodiscard
local function part_to_part_matrix(mdp_a, mdp_b)
	return get_part_matrix(mdp_a):invert()
		* get_part_matrix(mdp_b)
		* matrices.translate4(mdp_b:getTruePivot() - mdp_a:getTruePivot())
end

return part_to_part_matrix
