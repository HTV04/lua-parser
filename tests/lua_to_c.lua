#!/usr/bin/env lua
local parser = require 'parser'
local ast = require 'parser.ast'
local file = require 'ext.file'
local table = require 'ext.table'

local requires = table()
local cobjtype = 'Object'

local cppReservedWord = {
	'class',
}

local tabs = -1	-- because everything is in one block
function tab()
	return ('\t'):rep(tabs)
end
function tabblock(t)
	tabs = tabs + 1
	local s = table(t):mapi(function(expr)
		return tab() .. tostring(expr)
	end):concat';\n'
	tabs = tabs - 1
	return s..';\n'
end

-- make lua output the default for nodes' c outputw
local names = table()
for name,nc in pairs(ast) do
	if ast.node:isa(nc) then
		names:insert(name)
		nc.tostringmethods.c = nc.tostringmethods.lua
	end
end
for _,info in ipairs{
	{'concat','+'},
	{'and','&&'},
	{'or','||'},
	{'ne','!='},
} do
	local name, op = table.unpack(info)
	ast['_'..name].tostringmethods.c = function(self) 
		return table(self.args):mapi(tostring):concat(' '..op..' ')
	end
end
function ast._not.tostringmethods:c()
	return '!'..tostring(self[1])
end
function ast._len.tostringmethods:c()
	return tostring(self[1])..'.size()';
end
function ast._assign.tostringmethods:c()
	local s = table()
	for i=1,#self.vars do
		if self.exprs[i] then
			s:insert(tostring(self.vars[i])..' = '..tostring(self.exprs[i]))
		else
			s:insert(tostring(self.vars[i]))
		end
	end
	return s:concat', '
end
function ast._block.tostringmethods:c()
	return tabblock(self)
end
function ast._call.tostringmethods:c()
	local s = tostring(self.func)..'('..table.mapi(self.args, tostring):concat', '..')'
	if self.func.name == 'require' then
		if self.args[1].type == 'string' then
			-- ok here we add the require file based on our lua path
			-- does this mean we need to declare the lua path up front to lua_to_c?
			requires:insert(self.args[1].value)
		else
			s = s .. '\n#error require arg not a string'
		end
		--s = s .. ' ## HERE ##'
	end
	return s
end
function ast._foreq.tostringmethods:c()
	local s = 'for ('..cobjtype..' '..self.var..' = '..self.min..'; '..self.var..' < '..self.max..'; '
	if self.step then
		s = s .. self.var..' += '..self.step
	else
		s = s .. '++'..self.var
	end
	s = s ..') {\n' .. tabblock(self) .. tab() .. '}'
	return s
end
function ast._forin.tostringmethods:c()
	return 'for ('..table(self.vars):mapi(tostring):concat', '..' in '..table(self.iterexprs):mapi(tostring):concat', '..') {\n' .. tabblock(self) .. tab() .. '}'
end
function ast._function.tostringmethods:c()
	if self.name then
		-- global-scope def?
		--return cobjtype..' '..self.name..'('..table(self.args):mapi(function(arg) return cobjtype..' '..tostring(arg) end):concat', '..') {\n' .. tabblock(self) .. tab() .. '}'
		-- local-scope named function def ...
		return cobjtype..' '..self.name..' = []('..table(self.args):mapi(function(arg) return cobjtype..' '..tostring(arg) end):concat', '..') {\n' .. tabblock(self) .. tab() .. '}'
	else
		-- lambdas?
		return '[]('..table(self.args):mapi(function(arg) return cobjtype..' '..tostring(arg) end):concat', '..') {\n' .. tabblock(self) .. tab() .. '}'
	end
end
function ast._if.tostringmethods:c()
	local s = 'if ('..self.cond..') {\n' .. tabblock(self) .. tab() .. '}'
	for _,ei in ipairs(self.elseifs) do
		s = s .. ei
	end
	if self.elsestmt then s = s .. self.elsestmt end
	return s
end
function ast._elseif.tostringmethods:c()
	return ' else if ('..self.cond..') {\n' .. tabblock(self) .. tab() .. '}'
end
function ast._else.tostringmethods:c()
	return ' else {\n' .. tabblock(self) .. tab() .. '}'
end
function ast._index.tostringmethods:c()
	return tostring(self.expr)..'['..tostring(self.key)..']'
end
function ast._indexself.tostringmethods:c()
	return tostring(self.expr)..'.'..tostring(self.key)
end
function ast._local.tostringmethods:c()
	if self.exprs[1].type == 'function' or self.exprs[1].type == 'assign' then
		-- if exprs[1] is a multi-assign then an 'cobjtype' needs to prefix each new declaration
		return cobjtype..' '..tostring(self.exprs[1])
	else
		local s = table()
		for i=1,#self.exprs do
			s:insert(cobjtype..' '..self.exprs[i])
		end
		return s:concat'\n'
	end
end
function ast._vararg.tostringmethods:c()
	return 'reserved_vararg'	-- reserved name?
end
function ast._var.tostringmethods:c()
	if cppReservedWord[self.name] then
		return 'cppreserved_' .. self.name
	end
	return self.name
end
--print(names:sort():concat' ')



ast.tostringmethod = 'c'
--print('c:')

local function addtab(s)
	return '\t'..(s:gsub('\n', '\n\t'))	-- tab
end

-- also populates requires()
local function luaFileToCpp(fn)
	assert(fn, "expected filename")
	local luacode = assert(file(fn):exists(), "failed to find "..tostring(fn))
	local luacode = assert(file(fn):read(), "failed to find "..tostring(fn))
	local tree = parser.parse(luacode)
	local cppcode = tostring(tree)
	cppcode = '//file: '..fn..'\n'..cppcode
	cppcode = addtab(cppcode)
	return cppcode 
end



print[[

#include "CxxAsLua/Object.h"
using namespace CxxAsLua;

// how to handle _G ...
// esp wrt locals ...
// if we use _G then that incurs overhead ...
Object _G;

// for global calls ...
Object error;
Object type;
Object require;
Object table;

int main(int argc, char** argv) {
	_G = Object::Map();
	_G["package"] = Object::Map();
	_G["package"]["loaded"] = Object::Map();

	error = _G["error"] = [](Object x) -> Object {
		throw std::runtime_error((std::string)x);
	};

	//hmm, 'type' might be used as a global later, so i might have to remove the 'using namespace' and instead replace all Object's with Object::Object's
	::type = _G["type"] = [](Object x) -> Object {
		if (x.is_nil()) {
			return "nil";
		} else if (x.is_string()) {
			return "string";
		} else if (x.is_table()) {
			return "table";
		} else if (x.is_boolean()) {
			return "boolean";
		} else if (x.is_function()) {
			return "function";
		} else if (x.is_nil()) {
			return "nil";
		}
		//or use getTypeIndex()
		// or better yet, rewrite our x.details to be a std::variant, 
		// and map the variant index to a type,
		// then just store type info in that extra arra
	};
	
	table = _G["table"] = Object::Map();

	table["concat"] = [](VarArg arg) -> Object {
		if (!arg[1].is_table()) error("expected a table");
	//TODO FINISHME	
		// list, sep, i
		std::ostringstream s;
		std::string sep = "";
		for (const Object& o : arg.objects) {
			std::cout << sep;
			std::cout << o;
			sep = "\t";
		}
		std::cout << std::endl;
	};

	require = _G["require"] = [&](std::string const & s) -> Object {
		Object x = _G["package"]["loaded"][s];
		if (x != nil) return x;
	
		x = _G["cppmodules"][s];
		if (x != nil) {
			x = x();
			_G["package"]["loaded"][s] = x;
			return x;
		}

		return error(Object("idk how to load ") + s);
	};
	
	_G["cppmodules"] = Object::Map();
]]

local cppcode = luaFileToCpp(... or 'lua_to_c_test.lua')

for _,req in ipairs(requires) do
	-- ok here's where lua_to_c has to assume the same LUA_PATH as the c++ runtime
	print('//require: '..req)
	local fn = package.searchpath(req, package.path)
	if not fn then
		print("// package.searchpath couldn't find file")
	else
		print([[
	_G["cppmodules"]["]]..req..[["] = []() -> Object {
]])
		print(addtab(luaFileToCpp(fn)))
	
		print[[
	};
]]
	end
end

print(cppcode)

print[[
}
]]
