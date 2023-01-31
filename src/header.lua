--[[----------
p8tron header
By HTV04
--]]----------

-- String metatable --

do
	local meta = getmetatable("") -- Get the metatable for strings

	local sub = sub

	function meta.__index(t, k)
		k = k >> 48

		return sub(t, k, k)
	end
	function meta.__metatable()
		return nil -- Prevent metatable from being accessed
	end
end

-- p8tron functions --

local __p8tron_number_op
local __p8tron_string_op

local __p8tron_shl
local __p8tron_shr
local __p8tron_lshr
local __p8tron_rotl
local __p8tron_rotr
local __p8tron_band
local __p8tron_bor
local __p8tron_bxor

local __p8tron_len
local __p8tron_bnot
local __p8tron_peek
local __p8tron_peek2
local __p8tron_peek4

do
	local tonumber = tonumber
	local tostring = tostring
	local type = type

	local function from_number(n)
		return n / (1 << 48)
	end
	local function to_number(n)
		return (((n * (1 << 48)) + 0.5) // 1) & (((1 << 32) - 1) << 32)
	end

	function __p8tron_number_op(n)
		if type(n) == "number" then
			return tostring(n / (1 << 48))
		end

		return n
	end
	function __p8tron_string_op(s)
		if type(a) == "string" then
			return (((((((tonumber(s) + 0x8000) % 0x10000) - 0x8000) * (1 << 48)) + 0.5) // 1) & (((1 << 32) - 1) << 32))
		end

		return s
	end

	function __p8tron_shl(a, b)
		a = tonum(a)
		b = tonum(b)

		return a << (b >> 48)
	end
	function __p8tron_shr(a, b)
		a = tonum(a)
		b = tonum(b)

		return (a // (1 << (b >> 48))) & (((1 << 32) - 1) << 32)
	end
	function __p8tron_lshr(a, b)
		a = tonum(a)
		b = tonum(b)

		return (a << (b >> 48)) & (((1 << 32) - 1) << 32)
	end
	function __p8tron_rotl(a, b)
		a = tonum(a)
		b = tonum(b)

		return (a << (b >> 48)) | (a >> (32 - (b >> 48)))
	end
	function __p8tron_rotr(a, b)
		a = tonum(a)
		b = tonum(b)

		return (a >> (b >> 48)) | (a << (32 - (b >> 48)))
	end
	function __p8tron_band(a, b)
		a = tonum(a)
		b = tonum(b)

		return a & b
	end
	function __p8tron_bor(a, b)
		a = tonum(a)
		b = tonum(b)

		return a | b
	end
	function __p8tron_bxor(a, b)
		a = tonum(a)
		b = tonum(b)

		return a ~ b
	end

	function __p8tron_len(a)
		local meta = type(a) == "table" and getmetatable(a)

		if meta and meta.__len then
			return meta.__len(a)
		else
			return rawlen(a)
		end
	end
	__p8tron_peek = peek
	__p8tron_peek2 = peek2
	__p8tron_peek4 = peek4
end

-- Hide internal functions --

tonumber = nil

-- Compiled code --

