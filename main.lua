local Disassemble = require("src/disassemble");
local Deserialize = require("src/deserializer");
local FileName    = ({...})[1];

assert(FileName, string.format("Usage: lua %s [file]", debug.getinfo(1).short_src));

local f, e = io.open(FileName);
assert(f, e);

local e, r = pcall(Disassemble, Deserialize(f:read("*a"), getfenv(1)));
assert(e, r);
print(r);