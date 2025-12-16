--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Filters API v1.0

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Filters.lua
Wiki: https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI
]]

--==============================================================================================================================
--#REGION ˚♡ Texture ♡˚
--==============================================================================================================================

---@class Texture
local Texture = {}

local __meta = figuraMetatables.Texture
local __index = __meta.__index
function __meta.__index(s, k)
	return Texture[k] or __index(s, k)
end

---Applies a texture filter to an area of pixels. The filter can be created by calling `<FOXFilterAPI>.newFilter()` after requiring FOXFilters.
---
---It is recommended to call `<Texture>:update()` after doing anything with textures.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#getting-started
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param filter FOXFilter
---@return self
function Texture:applyFilter(x, y, w, h, filter)
	for _, m in ipairs(filter[1]) do
		local val = m.val

		if type(val) == "Matrix4" then
			pcall(self.applyMatrix, self, x, y, w, h, val, true) -- Clip is true here for 1.21
		elseif type(val) == "function" then
			pcall(self.applyFunc, self, x, y, w, h, val)
		end
	end

	return self
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXFilter ♡˚
--==============================================================================================================================

---@class FOXFilter
---@field package [1] FOXFilter.Modifier[]
local Filter = {}
---@package
Filter.__index = Filter
---@package
Filter.__type = "FOXFilter"

---@class FOXFilter.Modifier
---@field val fun(col: Vector4?, x: integer?, y: integer?): Vector4?|Matrix4
---@field mul boolean

---Applies a matrix transformation to this filter.
---
---If `mul` is true, multiplies this matrix with the last mergable matrix applied. Defaults to `true`.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#matrix
---@param mat Matrix4
---@param mul boolean?
---@return self
function Filter:applyMatrix(mat, mul)
	mul = mul == nil and true or mul

	local last = self[1][#self[1]]
	if mul and last and last.mul then
		last.val = mat * last.val
	else
		table.insert(self[1], { val = mat, mul = mul or false })
	end

	return self
end

---Applies a function to this filter.
---
---This function is given the color and pixel position for each pixel.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#function
---@param func fun(col: Vector4?, x: integer?, y: integer?): Vector4?
---@return self
function Filter:applyFunction(func)
	table.insert(self[1], { val = func, mul = false })
	return self
end

---Applies a tint modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#tint
---@param col Vector3
---@return self
function Filter:tint(col)
	return self:applyMatrix(matrices.scale4(col), true)
end

---Applies a hue rotation modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#hue-rotation
---@param deg number
---@return self
function Filter:hue(deg)
	deg = deg or 0

	local t = math.rad(deg)
	local sin_t = math.sin(t)
	local cos_t = math.cos(t)
	local sin_tf = sin_t / 3
	local cos_tf = (1 - cos_t) / 3

	return self:applyMatrix((
		matrices.scale3((1 + 2 * cos_t) / 3) + matrices.mat3(
			vec(0, 1, 0),
			vec(0, 0, 1),
			vec(1, 0, 0)
		) * (cos_tf + sin_tf) + matrices.mat3(
			vec(0, 0, 1),
			vec(1, 0, 0),
			vec(0, 1, 0)
		) * (cos_tf - sin_tf)
	):augmented(), true)
end

---Applies a color gradient to a grayscale texture, blending two to four colors. The first color is applied first to dark pixels.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#gradient
---@param col1 Vector3
---@param col2 Vector3
---@param col3 Vector3?
---@param col4 Vector3?
---@return self
---@overload fun(self: FOXFilter, col1: Vector3, col2: Vector3): FOXFilter
---@overload fun(self: FOXFilter, col1: Vector3, col2: Vector3, col3: Vector3?): FOXFilter
function Filter:gradient(col1, col2, col3, col4)
	if col4 then
		self:applyMatrix(matrices.mat4(
			vec(3, 3, -3, 0),
			vec(0, 0, 0, 0),
			vec(0, 0, 0, 0),
			vec(-1, -2, 1, 1)
		), false)

		self:applyMatrix(matrices.mat4(
			col3:augmented(1.01),
			col2:augmented(1.01),
			col1:augmented(1.01),
			col4:augmented(1.01)
		) * matrices.mat4(
			vec(1, -1, 0, 0),
			vec(-1, 0, 0, 1),
			vec(0, -1, 1, 0),
			vec(0, 1, 0, 0)
		), false)
	elseif col3 then
		self:applyMatrix(matrices.mat4(
			vec(2, 0, -2, 0),
			vec(0, 0, 0, 0),
			vec(0, 0, 0, 0),
			vec(-1, 1, 1, 1)
		), false)

		self:applyMatrix((matrices.mat3(
			col3,
			col2,
			col1
		) * matrices.mat3(
			vec(1, -1, 0),
			vec(0, 1, 0),
			vec(0, -1, 1)
		)):augmented(), false)
	else
		self:applyMatrix(matrices.mat3(
			col2,
			col1,
			vec(0, 0, 1)
		):augmented() * matrices.mat4(
			vec(1, 0, 0, 0),
			vec(0, -1, 0, 0),
			vec(0, 0, 0, 0),
			vec(0, 1, 0, 1)
		) * matrices.mat3(
			vec(1 / 3, 1 / 3, 1 / 3),
			vec(1 / 3, 1 / 3, 1 / 3),
			vec(1 / 3, 1 / 3, 1 / 3)
		):augmented(), false)
	end

	return self
end

---Applies a brightness modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#brightness
---@param val number
---@return self
function Filter:brightness(val)
	val = math.max(val or 1, 0)

	return self:applyMatrix(matrices.scale4(val, val, val), true)
end

---Applies a gamma modifier to this filter. **THIS MODIFIER IS INSTRUCTION HEAVY**
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#gamma
---@param val number
---@return self
function Filter:gamma(val)
	val = val or 1
	val = 1 / val

	return self:applyFunction(function(col)
		local r, g, b, a = col:unpack()
		return vec(r ^ val, g ^ val, b ^ val, a)
	end)
end

---Applies a saturation modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#saturation
---@param val number
---@return self
function Filter:saturation(val)
	val = math.max(val or 1, 0)

	return self:applyMatrix(math.lerp(matrices.mat3(
		vec(0.2126, 0.2126, 0.2126),
		vec(0.7152, 0.7152, 0.7152),
		vec(0.0722, 0.0722, 0.0722)
	):augmented(), matrices.mat4(), val) --[[@as Matrix4]], true)
end

---Applies a contrast modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#contrast
---@param val number
---@return self
function Filter:contrast(val)
	val = math.max(val or 1, 0)
	val = 0.5 + 0.5 * val

	return self:applyMatrix(math.lerp(matrices.mat4(
		vec(-1, 0, 0, 0),
		vec(0, -1, 0, 0),
		vec(0, 0, -1, 0),
		vec(1, 1, 1, 1)
	), matrices.mat4(), val) --[[@as Matrix4]], true)
end

---Applies a temperature modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#temperature
---@param val number
---@return self
function Filter:temperature(val)
	val = val or 0

	return self:applyMatrix(matrices.mat4(
		vec(1, 0, 0, 0),
		vec(0, 1, 0, 0),
		vec(0, 0, 1, 0),
		vec(0.1 * val, 0.05 * val, -0.1 * val, 1)
	), true)
end

---Applies an opacity modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#opacity
---@param val number
---@return self
function Filter:opacity(val)
	val = math.clamp(val or 1, 0, 1)

	return self:applyMatrix(math.lerp(matrices.mat4(
		vec(1, 0, 0, 0),
		vec(0, 1, 0, 0),
		vec(0, 0, 1, 0),
		vec(0, 0, 0, val)
	), matrices.mat4(), val) --[[@as Matrix4]], true)
end

---Inverts this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#invert
---@return self
function Filter:invert()
	return self:applyMatrix(matrices.mat4(
		vec(-1, 0, 0, 0),
		vec(0, -1, 0, 0),
		vec(0, 0, -1, 0),
		vec(1, 1, 1, 1)
	), true)
end

---Desaturates this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#grayscale
---@return self
function Filter:grayscale()
	return self:applyMatrix(matrices.mat3(
		vec(0.2126, 0.2126, 0.2126),
		vec(0.7152, 0.7152, 0.7152),
		vec(0.0722, 0.0722, 0.0722)
	):augmented(), true)
end

---Makes this filter black and white.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#mono
function Filter:mono()
	return self:applyMatrix(matrices.mat4(
		vec(0.2126, 0.2126, 0.2126, 0),
		vec(0.7152, 0.7152, 0.7152, 0),
		vec(0.0722, 0.0722, 0.0722, 0),
		vec(-0.25, -0.25, -0.25, 1)
	) * 2 ^ 32, false)
end

---Limits the number of colors used in this filter. **THIS MODIFIER IS INSTRUCTION HEAVY**
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#limit
---@param count number
---@return self
function Filter:limit(count)
	count = math.clamp(count or 2, 2, 256)
	count = math.floor(count - 1)

	return self:applyFunction(function(col)
		local r, g, b, a = col:unpack()

		r = math.round(r * count) / count
		g = math.round(g * count) / count
		b = math.round(b * count) / count

		return vec(r, g, b, a)
	end)
end

---Applies a sepia modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#sepia
---@param scl number
---@return self
function Filter:sepia(scl)
	scl = math.max(scl or 0, 0)

	return self:applyMatrix(math.lerp(matrices.mat4(), matrices.mat3(
		vec(0.39, 0.349, 0.272),
		vec(0.769, 0.686, 0.534),
		vec(0.189, 0.168, 0.131)
	):augmented(), scl) --[[@as Matrix4]], true)
end

---Applies a red-green colorblindness modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#protanopia
---@param scl number
---@return self
function Filter:protanopia(scl)
	scl = math.max(scl or 0, 0)

	return self:applyMatrix(math.lerp(matrices.mat4(), matrices.mat3(
		vec(0.567, 0.558, 0),
		vec(0.433, 0.442, 0.242),
		vec(0, 0, 0.758)
	):augmented(), scl) --[[@as Matrix4]], true)
end

---Applies a red-green colorblindness modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#deuteranopia
---@param scl number
---@return self
function Filter:deuteranopia(scl)
	scl = math.max(scl or 0, 0)

	return self:applyMatrix(math.lerp(matrices.mat4(), matrices.mat3(
		vec(0.625, 0.7, 0),
		vec(0.375, 0.3, 0.3),
		vec(0, 0, 0.7)
	):augmented(), scl) --[[@as Matrix4]], true)
end

---Applies a blue-yellow colorblindness modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#tritanopia
---@param scl number
---@return self
function Filter:tritanopia(scl)
	scl = math.max(scl or 0, 0)

	return self:applyMatrix(math.lerp(matrices.mat4(), matrices.mat3(
		vec(0.95, 0, 0),
		vec(0.05, 0.433, 0.475),
		vec(0, 0.567, 0.525)
	):augmented(), scl) --[[@as Matrix4]], true)
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ FOXFilterAPI ♡˚
--==============================================================================================================================

---@class FOXFiltersAPI
local api = setmetatable({}, { __type = "FOXFiltersAPI" })

---Creates a new texture filter which can be applied by calling `<Texture>:applyFilter()`.
---
---Filter modifiers can be chained together to create complex filters, and are applied in order.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#getting-started
---@return FOXFilter
function api.newFilter()
	return setmetatable({ {} }, Filter)
end

return api

--#ENDREGION
