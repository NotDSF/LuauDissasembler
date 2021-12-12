# Luau Dissasembler
This is an effient luau dissasembler made in Lua 5.1.

*(obviously not as fast as ones made in cpp but pretty damn fast for lua)*
## Usage
```bash
lua main.lua [file]
```

## Roblox Bytecode
Due to obvious reasons disassembling Roblox bytecode will not have opcode information or register deduction, however this can be easily fixed by remapping the opcodes in op.lua, but this is not needed to disassemble Roblox bytecode.

An example of this is:
```
Proto[0]
> #Stack: 2
> #Params: 0
> #Name: "undefined"

Constants[2]
> [0] (string) "print"
> [1] (function) "function: 00966F60"
> [2] (string) "Hello World!"

Instructions[5]
> [0->163] 163 { 0, 0, 0 }
> [1->65700] 164 { 0, 1, 0 }
> [2->1073741824] LOP_NOP { 0, 0, 64 }
> [3->131439] 111 { 1, 2, 0 }
> [4->16908447] 159 { 0, 2, 1 }
> [5->65666] 130 { 0, 1, 0 }
```
as you can see, all opcode names are missing except NOP.

## How to compile luau files
> You need https://github.com/Roblox/luau installed

```bash
luau --compile=binary [file] > compiled.out
```
