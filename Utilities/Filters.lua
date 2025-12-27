--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Filters API v1.2

Github: https://github.com/Bitslayn/FOX-s-Figura-APIs/blob/main/Utilities/Filters.lua
Wiki: https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI
]]

--==============================================================================================================================
--#REGION ˚♡ Metatables ♡˚
--==============================================================================================================================

------------------------------------------------------------------------------------------------
--#REGION ˚♡ Metatables > UserData ♡˚
------------------------------------------------------------------------------------------------

---@class Texture
local texture = {}

local __meta = figuraMetatables.Texture
local __index = __meta.__index
function __meta.__index(s, k)
	return texture[k] or __index(s, k)
end

figuraMetatables.Vector4.__metatable = false
figuraMetatables.Matrix4.__metatable = false

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Metatables > FOXFilter ♡˚
------------------------------------------------------------------------------------------------

---@class FOXFilter.Private
---@field mod FOXFilter.Modifier[] All applied modifiers
---@field val string[] Applied modifier strings
---@field hsh string Concatenated strings

---@class FOXFilter
---@field package [1] FOXFilter.Private
local filter = {}
local filter_meta = {
	__index = filter,
	__type = "FOXFilter",
	---@param a FOXFilter
	---@param b FOXFilter
	__eq = function(a, b)
		return a[1].hsh == b[1].hsh
	end,
	__metatable = false,
}

---@alias FOXFilter.Function fun(col: Vector4?, x: integer?, y: integer?): Vector4?

---@class FOXFilter.Modifier
---@field typ "mat"|"fun" This modifier's type
---@field val FOXFilter.Function|Matrix4 This modifier's value
---@field mul boolean? If this modifier is mergable

--#ENDREGION -----------------------------------------------------------------------------------
--#REGION ˚♡ Metatables > FOXFiltersAPI ♡˚
------------------------------------------------------------------------------------------------

---@class FOXFiltersAPI
local api = setmetatable({}, { __type = "FOXFiltersAPI" })

--#ENDREGION

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Copy ♡˚
--==============================================================================================================================

---Sanitizes this filter.
---@param flt FOXFilter
---@return FOXFilter
local function sanitize(flt)
	---@type FOXFilter.Private
	local old = rawget(flt, 1)
	---@type FOXFilter.Private
	local new = { mod = {}, val = {}, hsh = "" }
	---@type FOXFilter
	local out = setmetatable({ new }, filter_meta)

	---@type FOXFilter.Modifier[]
	local mod = rawget(old, "mod")
	---@type string[]
	local val = rawget(old, "val")

	local unsafe = false
	for i = 1, rawlen(mod) do
		---@type FOXFilter.Modifier
		local a = rawget(mod, i)
		---@type FOXFilter.Modifier
		local b = {
			typ = rawget(a, "typ"),
			val = rawget(a, "val"),
			mul = rawget(a, "mul"),
		}

		if b.typ == "mat" then
			b.val = matrices.mat4():set(b.val --[[@as Matrix4]])
			new.val[i] = tostring(b.val)
		elseif b.typ == "fun" then
			local nam, par = val[i]:match("(%a*)(.*)")

			if filter[nam] then
				filter[nam](out, par)
			else
				unsafe = true
				new.val[i] = string.dump(b.val --[[@as function]])
			end
		elseif b.typ == "ker" then
			local ker = {}
			for j = 1, rawlen(b.val) do
				ker[j] = { table.unpack(b.val) }
			end
			new.val[i] = toJson(ker)
		end

		new.mod[i] = b
	end

	new.hsh = table.concat(new.val)

	assert(not unsafe or flt == out)
	return out
end

---Copies this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#copy
---@param flt FOXFilter
---@return FOXFilter?
local function copy(flt)
	local suc, prv = pcall(sanitize, flt)
	return suc and prv or setmetatable({ { mod = {}, val = {}, hsh = "" } }, filter_meta)
end

filter.copy = copy
api.copy = copy

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Texture ♡˚
--==============================================================================================================================

---Caches copies of known safe filters
---@type table<string, FOXFilter>
local cache = {}

---Applies a texture filter to an area of pixels. The filter can be created by calling `<FOXFilterAPI>.newFilter()` after requiring FOXFilters.
---
---It is recommended to call `<Texture>:update()` after doing anything with textures.
---
---Another filter can be used as a mask. **APPLYING MASKS ARE INSTRUCTION HEAVY**
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#getting-started
---@param x integer
---@param y integer
---@param w integer
---@param h integer
---@param flt FOXFilter
---@param msk FOXFilter?
---@return self
function texture:applyFilter(x, y, w, h, flt, msk)
	if flt and flt[1] then
		flt = cache[flt[1].hsh] or copy(flt)
		cache[flt[1].hsh] = flt
	end
	if msk and msk[1] then
		msk = cache[msk[1].hsh] or copy(msk)
		cache[msk[1].hsh] = msk
	end

	if msk and msk[1].mod[1] and flt and flt[1].mod[1] then
		local byt = self:save()
		local _flt = textures:read("_flt", byt)
			:applyFilter(x, y, w, h, flt)
		local _msk = textures:read("_msk", byt)
			:applyFilter(x, y, w, h, msk)

		self:applyFunc(x, y, w, h, function(_, _x, _y)
			return math.lerp(
				self:getPixel(_x, _y),
				_flt:getPixel(_x, _y),
				_msk:getPixel(_x, _y)
			) --[[@as Vector4]]
		end)
	else
		for _, mod in ipairs(flt[1].mod) do
			local val = mod.val

			if mod.typ == "mat" then
				self:applyMatrix(x, y, w, h, val --[[@as Matrix4]], true) -- Clip is true here for 1.21
			elseif mod.typ == "fun" then
				self:applyFunc(x, y, w, h, val --[[@as FOXFilter.Function]])
			elseif mod.typ == "ker" then
				local _tmp = textures:read("_tmp", self:save())

				self:applyFunc(x, y, w, h, function(col, u, v)
					-- TODO Write convolution function
				end)
			end
		end
	end

	return self
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ Modifiers ♡˚
--==============================================================================================================================

---Applies a matrix transformation to this filter.
---
---If `mul` is true, multiplies this matrix with the last mergable matrix applied. Defaults to `true`.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#matrix
---@param mat Matrix4
---@param mul boolean?
---@return self
function filter:applyMatrix(mat, mul)
	mul = mul == nil and true or mul

	local prv = self[1]
	local len = #prv.mod

	local top = prv.mod[len]
	if mul and top and top.mul and top.typ == "mat" then
		top.val = mat * top.val
		prv.val[len] = tostring(top.val)
	else
		table.insert(prv.mod, { typ = "mat", val = mat, mul = mul or false })
		table.insert(prv.val, tostring(mat))
	end

	prv.hsh = table.concat(prv.val)
	return self
end

---Applies a kernel convolution matrix to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#kernel
function filter:applyKernel(ker, mode)
	-- TODO Check and error if kernel contains even indexes or holes.	

	local prv = self[1]

	table.insert(prv.mod, { typ = "ker", val = ker })
	table.insert(prv.val, toJson(ker))

	prv.hsh = table.concat(prv.val)
	return self
end

---Applies a function to this filter.
---
---This function is given the color and pixel position for each pixel.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#function
---@param fun FOXFilter.Function
---@param hsh string?
---@return self
function filter:applyFunction(fun, hsh)
	local prv = self[1]

	table.insert(prv.mod, { typ = "fun", val = fun })
	table.insert(prv.val, hsh or string.dump(fun))

	prv.hsh = table.concat(prv.val)
	return self
end

---Applies a tint modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#tint
---@param col Vector3
---@return self
function filter:tint(col)
	return self:applyMatrix(matrices.scale4(col), true)
end

---Applies a hue rotation modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#hue-rotation
---@param deg number
---@return self
function filter:hue(deg)
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
function filter:gradient(col1, col2, col3, col4)
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
function filter:brightness(val)
	val = math.max(val or 1, 0)

	return self:applyMatrix(matrices.scale4(val, val, val), true)
end

---Applies a gamma modifier to this filter. **THIS MODIFIER IS INSTRUCTION HEAVY**
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#gamma
---@param val number
---@return self
function filter:gamma(val)
	if not val then return self end

	val = 1 / val

	return self:applyFunction(function(col)
		local r, g, b, a = col:unpack()
		return vec(r ^ val, g ^ val, b ^ val, a)
	end, "gamma" .. val)
end

---Applies a saturation modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#saturation
---@param val number
---@return self
function filter:saturation(val)
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
function filter:contrast(val)
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
function filter:temperature(val)
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
function filter:opacity(val)
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
function filter:invert()
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
function filter:grayscale()
	return self:applyMatrix(matrices.mat3(
		vec(0.2126, 0.2126, 0.2126),
		vec(0.7152, 0.7152, 0.7152),
		vec(0.0722, 0.0722, 0.0722)
	):augmented(), true)
end

---Makes this filter black and white.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#mono
function filter:mono()
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
---@param val number
---@return self
function filter:limit(val)
	if not val then return self end

	val = math.floor(math.clamp(val - 1, 2, 256))

	return self:applyFunction(function(col)
		local r, g, b, a = col:unpack()

		r = math.round(r * val) / val
		g = math.round(g * val) / val
		b = math.round(b * val) / val

		return vec(r, g, b, a)
	end, "limit" .. val)
end

---Applies a sepia modifier to this filter.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#sepia
---@param scl number
---@return self
function filter:sepia(scl)
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
function filter:protanopia(scl)
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
function filter:deuteranopia(scl)
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
function filter:tritanopia(scl)
	scl = math.max(scl or 0, 0)

	return self:applyMatrix(math.lerp(matrices.mat4(), matrices.mat3(
		vec(0.95, 0, 0),
		vec(0.05, 0.433, 0.475),
		vec(0, 0.567, 0.525)
	):augmented(), scl) --[[@as Matrix4]], true)
end

--#ENDREGION --=================================================================================================================
--#REGION ˚♡ API ♡˚
--==============================================================================================================================

---Creates a new texture filter which can be applied by calling `<Texture>:applyFilter()`.
---
---Filter modifiers can be chained together to create complex filters, and are applied in order.
---
---https://github.com/Bitslayn/FOX-s-Figura-APIs/wiki/FOXFiltersAPI#getting-started
---@return FOXFilter
function api.newFilter()
	---@type FOXFilter.Private
	local prv = { mod = {}, val = {}, hsh = "" }
	return setmetatable({ prv }, filter_meta)
end

return api

--#ENDREGION
