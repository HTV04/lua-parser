#!/usr/bin/env lua5.1
--taken from the tests at https://github.com/stravant/LuaMinify
local parser = require 'parser'
for line in io.lines'minify_tests.txt' do
	local expected = not line:match'-- FAIL$'
	local luaResults = not not loadstring(line)
	assert(expected == luaResults, "looks like your Lua version doesn't match the baseline")
	local parserResults, errorString = pcall(parser.parse, line)
	print(expected,parserResults,line)
	if expected ~= parserResults then error("failed or error "..errorString) end
end