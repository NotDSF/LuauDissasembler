local byte, bit, ldexp = string.byte, bit or require("bit"), math.ldexp;
local bor, blshift, brshift, band = bit.bor, bit.lshift, bit.rshift, bit.band;

local function gBit(Bit, Start, End)
    -- credits to https://github.com/Rerumu/Rerubi/blob/master/Source.lua for this function
	if End then -- Thanks to cntkillme for giving input on this shorter, better approach.
		local Res	= (Bit / 2 ^ (Start - 1)) % 2 ^ ((End - 1) - (Start - 1) + 1);

		return Res - Res % 1;
	else
		local Plc = 2 ^ (Start - 1);

		if (Bit % (Plc + Plc) >= Plc) then
			return 1;
		else
			return 0;
		end;
	end;
end;

local function Deserialize(bytecode, env) 
    local offset = 1;
    local strings = {};
    local protos = {};
    
    local function gBits8() 
        local b = byte(bytecode, offset, offset);
        offset = offset + 1; 
        return b;
    end;

    local function gBits32()
        local A,B,C,D = byte(bytecode, offset, offset + 3);
        offset = offset + 4;
        return (D * 16777216) + (C * 65536) + (B * 256) + A;
    end;

    local function readVarInt()
        local result, shift, byte = 0, 0;

        repeat
            byte = gBits8();
            result = bor(result, blshift(band(byte, 127), shift));
            shift = shift + 7;
        until band(byte, 128) == 0;

        return result;
    end;

    local function gString()
        local Len = readVarInt();
        local Ret = string.sub(bytecode, offset, offset + Len - 1);
        offset = offset + Len;
        return Ret;
    end;

    local function getImport(id, k) 
        local count = brshift(id, 30);
        local id0 = count > 0 and band(brshift(id, 20), 1023) or -1;
        local id1 = count > 1 and band(brshift(id, 10), 1023) or -1;
        local id2 = count > 2 and band(id, 1023) or -1;
        local f = env[k[id0 + 1]];

        if id1 >= 0 and f then
            f = f[k[id1 + 1]];
        end;

        if id2 >= 0 and f then
            f = f[k[id2 + 1]];
        end;

        return f;
    end;

    local function gFloat() 
        -- credits to https://github.com/Rerumu/Rerubi/blob/master/Source.lua for this function
        local Left, Right, Normal = gBits32(), gBits32(), 1;
        local Mantissa = (gBit(Right, 1, 20) * (2 ^ 32)) + Left;
        local Exponent = gBit(Right, 21, 31);
        local Sign = ((-1) ^ gBit(Right, 32));

        if Exponent == 0 then
            if Mantissa == 0 then
                return Sign * 0; -- +-0
            end;
            Exponent = 1;
            Normal = 0;
        elseif Exponent == 2047 then
            return Sign * ((Mantissa == 0 and 1 or 0) / 0); -- +-Inf +-Q/Nan
        end;
        
        return ldexp(Sign, Exponent - 1023) * (Normal + (Mantissa / (2 ^ 52)));
    end;

    local function readString() 
        local id = readVarInt();
        return id == 0 and nil or strings[id];
    end;

    local version = gBits8();
    assert(version == 0 or version == 1, "bytecode version mismatch");

    local stringCount = readVarInt();
    for i=1, stringCount do
        strings[i] = gString();
    end;

    local protoCount = readVarInt();
    for i=1, protoCount do
        local Instr = {}
        local Constants = {};
        local Proto = {
            maxstacksize = gBits8(),
            numparams = gBits8(),
            nups = gBits8(),
            is_vararg = gBits8(),
            sizecode = readVarInt(),
            code = Instr,
            const = Constants
        }

        for c=1, Proto.sizecode do
            local Code = gBits32();
            local Opcode = band(Code, 255);
            Instr[c] = {
                Code = Code,
                Opcode = Opcode,
                Reg = {
                    band(brshift(Code, 8), 255), -- a
                    band(brshift(Code, 16), 255), -- b
                    band(brshift(Code, 24), 255) -- c
                }
            }
        end;

        local sizeK = readVarInt();
        Proto.sizek = sizeK;
        for b=1, sizeK do
            local Type, Cnst = gBits8();

            if Type == 1 then -- LBC_CONSTANT_BOOLEAN
                Cnst = gBits8() ~= 0;
            elseif Type == 2 then -- LBC_CONSTANT_NUMBER
                Cnst = gFloat();
            elseif Type == 3 then -- LBC_CONSTANT_STRING
                Cnst = readString();
            elseif Type == 4 then -- LBC_CONSTANT_IMPORT
                Cnst = getImport(gBits32(), Constants) or 0;
            elseif Type == 5 then -- LBC_CONSTANT_TABLE
                local keys = readVarInt();
                local tbl = {};
                for i=1, keys do
                    local key = readVarInt();
                    tbl[i] = Cnst[key];
                end;
                Cnst = tbl;
            elseif Type == 6 then -- LBC_CONSTANT_CLOSURE
                local id = readVarInt();
                Cnst = protos[id];
            end;
            Constants[b] = Cnst; -- We skip LBC_CONSTANT_NIL due to it being assigned nil anyway.
        end;

        local sizep, p = readVarInt(), {};
        for b=1, sizep do
            local id = readVarInt();
            p[b] = protos[id + 1]; 
        end;
        Proto.p = p;

        local debugname = readString();
        Proto.name = debugname;
        
        local lineInfo = gBits8() == 1;
        if lineInfo then
            local lineinfo, abslineinfo, Linegaplog2 = {}, {}, gBits8();
            local Intervals = brshift(Proto.sizecode - 1, Linegaplog2) + 1;
            local absoffset = band(Proto.sizecode + 3, -4);
            local lastoffset, lastline = 0, 0;

            for b=1, Proto.sizecode do
                lastoffset = lastoffset + gBits8();
                lineinfo[b] = lastoffset;
            end;

            for b=1, Intervals do
                lastline = lastline + gBits32();
                abslineinfo[b] = lastline;
            end;

            Proto.lineinfo = lineinfo;
            Proto.abslineinfo = abslineinfo;
        end;

        local debugInfo = gBits8() == 1;
        if debugInfo then
            local sizelocvars = readVarInt();
            for b=1, sizelocvars do
                readString();
                readVarInt();
                readVarInt();
                gBits8();
            end;

            local sizeupvalues = readVarInt();
            for b=1, sizeupvalues do
                readString();
            end;
        end;
        protos[i] = Proto;
    end;

    local main = readVarInt();
    local proto = protos[main + 1];

    return proto;
end;

return Deserialize;