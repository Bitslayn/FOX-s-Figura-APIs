--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's partToPartMatrix v1.0

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/partToPartMatrix.lua
]]

---Returns this part's line of parents
---@param mdp ModelPart
---@return ModelPart[]
---@nodiscard
local function get_parents(mdp)
	local tbl = {}

	while mdp:getParent() do
		table.insert(tbl, 1, mdp)
		mdp = mdp:getParent()
	end

	return tbl
end

---Finds the common root between two parts
---@param a ModelPart
---@param b ModelPart
---@return ModelPart? root Root ModelPart
---@return ModelPart[]? a Parents of `a` excluding root
---@return ModelPart[]? b Parents of `b` excluding root
---@nodiscard
local function find_root(a, b)
	a, b = get_parents(a), get_parents(b)

	for i = 1, math.max(#a, #b) do
		if a[i] ~= b[i] then
			return a[i - 1],
				{ table.unpack(a, i) },
				{ table.unpack(b, i) }
		end
	end
end

---Converts PascalCase to snake_case
---@param str string
---@return string
---@nodiscard
local function snake_case(str)
	local tbl = {}
	for w in str:gmatch("%u%l*") do
		table.insert(tbl, w:lower())
	end
	return table.concat(tbl, "_")
end

---Generates and returns a matrix, transforming the first part around the second
---@param a ModelPart
---@param b ModelPart
---@return Matrix4
---@nodiscard
return function(a, b)
	local mat = matrices.mat4()

	local root, tbl_a, tbl_b = find_root(a, b)
	if not root then return mat end

	-- Walk matrices through A -> ROOT

	for i = #tbl_a, 1, -1 do
		mat = mat * tbl_a[i]:getPositionMatrixRaw():invert()
	end

	-- Walk matrices through ROOT -> B

	for i = 1, #tbl_b do
		mat = mat * tbl_b[i]:getPositionMatrixRaw()
	end

	-- Initialize VanillaModelPart pivot

	local ctx_a = snake_case(a:getParentType())
	if vanilla_model[ctx_a] then
		mat = mat * matrices.translate4(-vanilla_model[ctx_a]:getOriginPos())
	end
	local ctx_b = snake_case(b:getParentType())
	if vanilla_model[ctx_b] then
		mat = mat * matrices.translate4(-vanilla_model[ctx_b]:getOriginPos())
	end

	-- Initialize ModelPart pivot

	mat = mat * matrices.translate4(b:getTruePivot() - a:getTruePivot())

	return mat
end
