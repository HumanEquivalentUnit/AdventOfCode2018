# README - how to use
#
# 1. Edit $registers line below, for how many registers you want, and what their starting state should be.
# 2. Edit the $ElfCodeInput below, with your code, or uncomment the Get-Content line and read it from a file.
# 3. Set $DEBUGPrintRegistersEveryNLoops = N if you want progress printed out every N instructions (slower)

# Optionally set this, to see the verbose log messages during 
# $VerbosePreference = 'Continue'

using namespace System.Reflection.Emit
Remove-Variable result -ea SilentlyContinue # so it won't accidentally show results from a previous run.

# configure initial values for each CPU register, 
[int[]]$registers = @(0,0,0,0,0,0)


$DEBUGPrintRegistersEveryNLoops = 0  # dump every N instructions; 0 = don't include debug code


#$ElfCodeInput = Get-Content .\data.txt
$ElfCodeInput = @"
#ip 5
addi 5 16 5
seti 1 1 4
seti 1 8 2
mulr 4 2 3
eqrr 3 1 3
addr 3 5 5
addi 5 1 5
addr 4 0 0
addi 2 1 2
gtrr 2 1 3
addr 5 3 5
seti 2 6 5
addi 4 1 4
gtrr 4 1 3
addr 3 5 5
seti 1 4 5
mulr 5 5 5
addi 1 2 1
mulr 1 1 1
mulr 5 1 1
muli 1 11 1
addi 3 7 3
mulr 3 5 3
addi 3 8 3
addr 1 3 1
addr 5 0 5
seti 0 9 5
setr 5 8 3
mulr 3 5 3
addr 5 3 3
mulr 5 3 3
muli 3 14 3
mulr 3 5 3
addr 1 3 1
seti 0 4 0
seti 0 3 5
"@ -split "`r?`n"


# The code in this PowerShell file does the following:

# 1. filter the ElfCode source code,
#    dropping blank or unreadable lines.
# 2. Generate a DynamicMethod to hold the CIL instructions.
# 3. Loop over the source instructions generating the CIL code.
# 4. Run it (optionally with debug prints from inside the VM every N instructions (slower)).
# 5. Get the final state of the registers, and print that.


# Design of the ElfCode machine is:

# local variable - register 0
# local variable - register N
# Instruction pointer
# 
# begin
# jump table
#  default -> goto halt
#  instruction
#  instruction
#  instruction
#
#  goto begin
#
# halt

# There is a load/tidy pair around each instruction to handle instruction pointer binding to register
# if you include debug code, it's copied once after every instruction

##
# Read and parse ElfCode, ready for CIL code generation
##

$ipRegisterNum = $null
$parsedLines = [System.Collections.Generic.List[psobject]]::new()

# Read and parse the source code instructions.
# Skip blank lines and unreadable lines,
# parse the numbers for each instruction.
$inputLineCounter = 1
foreach ($line in $ElfCodeInput)
{
    if ([string]::IsNullOrWhiteSpace($line))
    {
        continue
    }
    elseif ($line -match '^#ip (\d+)' -and $ipRegisterNum -eq $null)
    {
        $ipRegisterNum = [int]$matches[1]
    }
    elseif ($line -match '^#ip (\d+)' -and $ipRegisterNum -ne $null)
    {
        Write-Error -Message "Line $inputLineCounter, '$line' is trying to redefine #ip, that's not supported"
    }
    elseif ($line -match '^(\w+) (\d+) (\d+) (\d+)$')
    {
        $opcode = $matches[1]
        $ABC = [int[]]$matches[2,3,4]
        $parsedLines.Add(($opcode, $ABC))
    }
    else
    {
        Write-Verbose -Message "Can't read line $inputLineCounter, '$line', ignoring it."
    }
    
    $inputLineCounter++
}
Remove-Variable line, opcode, ABC -ErrorAction SilentlyContinue


##
# CodeGen Helper Functions
##

function Add-ILRegistersToArrayOnStack
{
    Write-Verbose -Message 'ILGen: Registers -> Array'
    # new array sized to hold all the registers.
    if (-not $cilLocalVarResultArray) { $cilLocalVarResultArray = $IL.DeclareLocal([int32[]]) }
    $IL.Emit([OpCodes]::Ldc_I4, $registers.Count)
    $IL.Emit([OpCodes]::Newarr, [int32])
    $IL.Emit([OpCodes]::Stloc, $cilLocalVarResultArray)

    # register values (1 local var each) -> array contents.
    for ($i = 0; $i -lt $cilRegisterLocals.Count; $i++)
    {
        $IL.Emit([OpCodes]::Ldloc, $cilLocalVarResultArray)
        $IL.Emit([OpCodes]::Ldc_I4, $i)
        $IL.Emit([OpCodes]::Ldloc, $i)
        $IL.Emit([OpCodes]::Stelem, [int32])
    }

    # array -> stack, and return
    $IL.Emit([OpCodes]::Ldloc, $cilLocalVarResultArray)
}

# Increment the debug counter
# do a remainder check
# if it passes, print the registers
function Add-ILDebugPrint {
    Write-Verbose -Message 'ILGen: if (loopCounter++ % debugCount) { print registers }'
    # loopCounter++
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.Emit([OpCodes]::Ldc_I8, 1L)
    $IL.Emit([OpCodes]::Add)
    $IL.Emit([OpCodes]::Stloc, $loopCounterLocal)
    
    # $loopCounter % cycles
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.Emit([OpCodes]::Ldc_I8, [int64]$DEBUGPrintRegistersEveryNLoops)
    $IL.Emit([OpCodes]::Rem)
        
    # if ($that -gt 0) { skip the printing }
    #if (-not $script:skipPrintLabel) { $script:skipPrintLabel = $IL.DefineLabel() }
    $skipPrintLabel = $IL.DefineLabel()
    
    $IL.Emit([OpCodes]::Ldc_I8, 0L)
    $IL.Emit([OpCodes]::Bgt, $skipPrintLabel)
    
    # register values (1 local var each) -> array contents.
    $consoleWriteInt32  = [console].GetDeclaredMethods('Write').where{$_.GetParameters()[0].ParameterType -eq [int32]}[0]
    $consoleWriteInt64  = [console].GetDeclaredMethods('Write').where{$_.GetParameters()[0].ParameterType -eq [int64]}[0]
    $consoleWriteString = [console].GetDeclaredMethods('Write').where{$p = $_.GetParameters(); $p.Count -eq 1 -and $p.ParameterType -eq [string]}[0]
    $consoleWriteLineString = [console].GetDeclaredMethods('WriteLine').where{$p = $_.GetParameters(); $p.Count -eq 1 -and $p.ParameterType -eq [string]}[0]

    $IL.Emit([OpCodes]::Ldstr, 'Instruction Pointer: ')
    $IL.EmitCall([OpCodes]::Call, $consoleWriteString, $null)
    
    $IL.Emit([OpCodes]::Ldloc, $ipLocal)
    $IL.EmitCall([OpCodes]::Call, $consoleWriteInt32, $null)

    $IL.Emit([OpCodes]::Ldstr, '     Counter: ')
    $IL.EmitCall([OpCodes]::Call, $consoleWriteString, $null)
    
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.EmitCall([OpCodes]::Call, $consoleWriteInt64, $null)

    $IL.Emit([OpCodes]::Ldstr, "")
    $IL.EmitCall([OpCodes]::Call, $consoleWriteLineString, $null)

    $IL.Emit([OpCodes]::Ldstr, 'Registers: ')
    $IL.EmitCall([OpCodes]::Call, $consoleWriteString, $null)
    
    for ($i = 0; $i -lt $cilRegisterLocals.Count; $i++)
    {
        $IL.Emit([OpCodes]::Ldloc, $i)
        $IL.EmitCall([OpCodes]::Call, $consoleWriteInt32, $null)
        $IL.Emit([OpCodes]::Ldstr, ' ')
        $IL.EmitCall([OpCodes]::Call, $consoleWriteString, $null)
    }

    $IL.Emit([OpCodes]::Ldstr, "")
    $IL.EmitCall([OpCodes]::Call, $consoleWriteLineString, $null)

    # join array to string with [system.string]::Join(sep, generic int[]) overload
    # I haven't got this to work yet
    #$IL.Emit([OpCodes]::Ldstr, '; ')
    #Add-ILRegistersToArrayOnStack
    #$IL.EmitCall([opcodes]::Call, [string].GetDeclaredMethods('Join').where{$_.IsGenericMethod}[0].MakeGenericMethod([int32[]]), $null)
    ##if (-not $script:debugStringLocal) { $script:debugStringLocal = $IL.DeclareLocal([string]) }
    ##$IL.Emit([OpCodes]::Stloc, $debugStringLocal)
    ##$IL.Emit([OpCodes]::Ldloc, $debugStringLocal)
    #$IL.EmitCall([OpCodes]::Call, $consoleWriteLineString, $null)
    $IL.MarkLabel($skipPrintLabel)
}


##
# End CodeGen Helper Functions
##


##
# Boilerplate start - prepare ElfCode machine
#  1. Make a DynamicMethod and type it to take no params, return an int array.
#  2. Inline opcodes to setup registers, avoids having to load them from a parameter.
##

    $methodInfo = new-object Reflection.Emit.DynamicMethod -ArgumentList @('ElfCode', [int32[]], @())
    $IL = $methodInfo.GetILGenerator()

    # Make a local variable for each register and intialize them,
    # with values from the $registers array here.
    $cilRegisterLocals = for ($i = 0; $i -lt $registers.Count; $i++)
    {
        $IL.DeclareLocal([int32])
        $IL.Emit([OpCodes]::Ldc_I4, $registers[$i])
        $IL.Emit([OpCodes]::Stloc, $i)
    }

    # Store the count of registers,
    # so we can make an appropriate array to return them all
    $regCountLocal = $IL.DeclareLocal([int32])
    $IL.Emit([OpCodes]::Ldc_I4, $registers.Count)
    $IL.Emit([OpCodes]::Stloc, $regCountLocal)


    # Instruction Pointer local var sits after the register vars
    $ipLocal = $IL.DeclareLocal([int32])
    $IL.Emit([OpCodes]::Ldc_I4_0)
    $IL.Emit([OpCodes]::Stloc, $ipLocal)


    # If we want a debug print, setup a counter to track when
    if ($DEBUGPrintRegistersEveryNLoops -gt 0)
    {
        $loopCounterLocal = $IL.DeclareLocal([int64])
        $IL.Emit([OpCodes]::Ldc_I8, 0L)
        $IL.Emit([OpCodes]::Stloc, $loopCounterLocal)
    }

##
# Boilerplate end - ElfCode machine initialised.
##

##
# Generate CIL instructions for ElfCode
##

# Offsets for the parameters
$A = 0
$B = 1
$C = 2

# Setup the end, so we can jump to it later
$haltLabel = $IL.DefineLabel()

[Label[]]$lineJumpLabels = for ($i = 0; $i -lt $parsedLines.Count; $i++)
{
    $IL.DefineLabel()
}


# Label before the instruction jumptable
$beginLabel = $IL.DefineLabel()
$IL.MarkLabel($beginLabel)

# JumpTable - jump to the line for the instruction pointer
$IL.Emit([OpCodes]::Ldloc, $ipLocal)
$IL.Emit([OpCodes]::Switch, $lineJumpLabels)
$defaultCaseLabel = $IL.DefineLabel()
$IL.MarkLabel($defaultCaseLabel)
$IL.Emit([OpCodes]::Br, $haltLabel)

# CIL generation for each line of input, inside a CIL switch jump table
$i = 0
$inputLineCounter = 1
foreach ($line in $parsedLines)
{
    Write-Verbose -Message "Generating IL for line $inputLineCounter : $($line[0]) $($line[1] -join ' ')"
    $opcode, $ABC = $line
    
    # output label so IP can jump to this instruction
    $IL.MarkLabel($lineJumpLabels[$i])

    # Instruction Pointer -> Register
    $IL.Emit([OpCodes]::Ldloc, $ipLocal)
    $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ipRegisterNum])

    switch ($opcode)
    {
        'addr' { #addr (add register) stores into register C the result of adding register A and register B.
            Write-Verbose -Message "addr"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Add)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'addi' { #addi (add immediate) stores into register C the result of adding register A and value B.
            Write-Verbose -Message "addi"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::Add)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'mulr' { # mulr (multiply register) stores into register C the result of multiplying register A and register B.
            Write-Verbose -Message "mulr"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Mul)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'muli' { # muli (multiply immediate) stores into register C the result of multiplying register A and value B.
            Write-Verbose -Message "muli"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::Mul)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'banr' { # banr (bitwise AND register) stores into register C the result of the bitwise AND of register A and register B.
            Write-Verbose -Message "banr"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::And)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'bani' { # bani (bitwise AND immediate) stores into register C the result of the bitwise AND of register A and value B.
            Write-Verbose -Message "bani"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::And)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'borr' { # borr (bitwise OR register) stores into register C the result of the bitwise OR of register A and register B.
            Write-Verbose -Message "borr"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Or)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'bori' { # bori (bitwise OR immediate) stores into register C the result of the bitwise OR of register A and value B.
            Write-Verbose -Message "bori"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::Or)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'setr' { # setr (set register) copies the contents of register A into register C. (Input B is ignored.)
            Write-Verbose -Message "setr"
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'seti' { # seti (set immediate) stores value A into register C. (Input B is ignored.)
            Write-Verbose -Message "seti"
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$A])
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'gtir' { # gtir (greater-than immediate/register) sets register C to 1 if value A is greater than register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtir"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$A])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($gtLabel)
        }
        'gtri' { # gtri (greater-than register/immediate) sets register C to 1 if register A is greater than value B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtri"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($gtLabel)
        }
        'gtrr' { # gtrr (greater-than register/register) sets register C to 1 if register A is greater than register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtrr"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($gtLabel)
        }
        'eqir' { # eqir (equal immediate/register) sets register C to 1 if value A is equal to register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqir"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$A])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($eqLabel)
        }
        'eqri' { # eqri (equal register/immediate) sets register C to 1 if register A is equal to value B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqri"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I4, $ABC[$B])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($eqLabel)
        }
        'eqrr' { # eqrr (equal register/register) sets register C to 1 if register A is equal to register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqri"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Ldc_I4_1)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Ldc_I4_0)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
            $IL.MarkLabel($eqLabel)
        }
    }

    # IP bound register -> stack -> + 1 -> Instruction Pointer local var
    $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ipRegisterNum])
    $IL.Emit([OpCodes]::Ldc_I4_1)
    $IL.Emit([OpCodes]::Add)
    $IL.Emit([OpCodes]::Stloc, $ipLocal)

    
    if ($DEBUGPrintRegistersEveryNLoops -gt 0)
    {
        Add-ILDebugPrint
    }

    $i++

    $IL.Emit([OpCodes]::br, $beginLabel)
}


##
# End CIL instructions for ElfCode
##
##
# End CodeGen - return register values to the caller.
##
    $IL.MarkLabel($haltLabel)
    Add-ILRegistersToArrayOnStack
    $IL.Emit([OpCodes]::Ret)

##
# Boilerplate end - end of CIL code generation.
##


# Convert DyanmicMethod -> Delegate, and call it.
$ElfCode = $methodInfo.CreateDelegate([System.Func[[int32[]]]])

Write-Verbose -Message 'Attempting to run code:'
write-host "Before: $($registers -join ', ')"
$result = $ElfCode.Invoke()
write-host "Result: $($result -join ', ')"
