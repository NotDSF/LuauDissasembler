local format, typev, string, concat = string.format, type, tostring, table.concat;
local op = {};

for i,v in pairs(require("src/op")) do
    op[v] = i;
end;

local function Disassemble(chunk, id) 
    local id = id or 0;
    local Instructions = chunk.code;
    local Constants = chunk.const;
    local out = format("Proto[%d]\n> #Stack: %d\n> #Params: %d\n> #Name: \"%s\"\n\nConstants[%d]\n", id, chunk.maxstacksize, chunk.numparams, chunk.name or "undefined", chunk.sizek - 1);

    for i,v in pairs(Constants) do
        out = out .. format("> [%d] (%s) \"%s\"\n", i - 1, typev(v), string(v));
    end;

    out = out .. format("\nInstructions[%d]\n", chunk.sizecode - 1);

    for i,v in pairs(Instructions) do
        local Opcode = op[v.Opcode + 1] or string(v.Opcode);
        local Registers = v.Reg;
        local Code = v.Code;
        local B = Registers[2] + 1;
        local Deduct = "";

        if Opcode == "LOP_GETIMPORT" then
            if Constants[B] then
                Deduct = format(" / R[2] = %s (%s)", string(Constants[B]), Constants[B - 1]);
            else
                Deduct = format(" / R[2] = Env[\"%s\"]", Constants[B - 1]);
            end;
        elseif Opcode == "LOP_LOADK" then
            Deduct = format(" / R[2] = \"%s\"", string(Constants[B]));
        end;

        out = out .. format("> [%d->%d] %s { %s }%s\n", i - 1, Code, Opcode, concat(Registers, ", "), Deduct);
    end;

    for i,v in pairs(chunk.p) do
        out = out .. "\n" .. Disassemble(v, i);
    end;

    return out;
end;

return Disassemble;