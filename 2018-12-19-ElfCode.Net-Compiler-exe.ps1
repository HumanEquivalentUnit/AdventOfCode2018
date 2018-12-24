<#
.Synopsis
   Compiles the Advent Of Code 2018 instruction set ("ElfCode") 
   to DOTNet CIL, then runs it (PS or PS Core), or saves an .exe (only on Windows PS 5.1)

   NB parameter for loading ElfCode from file would be great, but doesn't exist.

   NB. Only runs on Windows PowerShell, $appDomain.DefineDynamicAssembly() fails on DOTNet Core. 
.DESCRIPTION
    README - how to use
    
    1. Edit $registers line below -> how many registers, and their start values.
    2. Edit $ElfCodeInput below -> paste your code, or uncomment the Get-Content line and read it from a file.
    3. Set $DEBUGPrintEveryNInstructions = N if you want progress printed out every N instructions (slower).

    Optionally set this, to see the verbose log messages during 
    $VerbosePreference = 'Continue'
.EXAMPLE
    PS C:\test> .\ElfCode-to-exe.ps1
    VERBOSE: Running the generated code
    Before: 0, 0, 0, 0, 0, 0
    Counter: 0      Instruction Pointer: 11
    Registers: 3000000000; 3000000001; 0; 1; 0; 10
.EXAMPLE
    PS C:\test> .\ElfCode-to-exe.ps1 -CompileToExe
    Saved elf.exe

#>

using namespace System.Reflection.Emit

[CmdletBinding()]
Param
(
    # Initial state of the registers
    [int64[]]$Registers = @(0,0,0,0,0,0),

    # Print register state every N elfCode instructions (roughly).
    [int64]$DEBUGPrintEveryNInstructions = 0, #500000000 # dump every N instructions; 0 = don't include debug code

    # If this switch is provided, save to an .exe instead of simply running the code.
    [switch]$CompileToExe = $false
)

Remove-Variable -Name result -ErrorAction SilentlyContinue
Remove-Variable -Name cilLocalVarResultArray, int64ToStringHelperVar, strJoinHelperVar -Scope Script -ErrorAction SilentlyContinue

[System.Environment]::CurrentDirectory = $PWD.Path

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

$ElfCodeInput = @"
#ip 5
seti 3000000000 0 0
addi 1 1 1
gtrr 1 0 3
muli 3 10 5
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
    $line = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($line))
    {
        continue
    }
    elseif ($line -match '^#ip (\d+)' -and $ipRegisterNum -eq $null)
    {
        $ipRegisterNum = [int64]$matches[1]
    }
    elseif ($line -match '^#ip (\d+)' -and $ipRegisterNum -ne $null)
    {
        Write-Error -Message "Line $inputLineCounter, '$line' is trying to redefine #ip, that's not supported"
    }
    elseif ($line -match '^(\w+) (-?\d+) (-?\d+) (-?\d+)$')
    {
        $opcode = $matches[1]
        [int64[]]$ABC = $matches[2,3,4]
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

function Add-IL-RegistersToArrayOnStack
{
    Write-Verbose -Message 'ILGen: Registers -> Array'
    # array sized to hold all the registers.
    if (-not $script:cilLocalVarResultArray) { $script:cilLocalVarResultArray = $IL.DeclareLocal([int64[]]) }
    $IL.Emit([OpCodes]::Ldc_I4, $registers.Count)
    $IL.Emit([OpCodes]::Newarr, [int64])
    $IL.Emit([OpCodes]::Stloc, $script:cilLocalVarResultArray)

    # register values (1 local var each) -> array contents.
    for ($i = 0; $i -lt $cilRegisterLocals.Count; $i++)
    {
        $IL.Emit([OpCodes]::Ldloc, $script:cilLocalVarResultArray)
        $IL.Emit([OpCodes]::Ldc_I4, $i)
        $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$i])
        $IL.Emit([OpCodes]::Stelem, [int64])
    }

    # array -> stack
    $IL.Emit([OpCodes]::Ldloc, $script:cilLocalVarResultArray)
}

function Add-ILPrint-Registers {
    
    # register values (1 local var each) -> array contents.
    $consoleWriteLineString = [console].GetDeclaredMethods('WriteLine').where{
                                        $p = $_.GetParameters()
                                        $p.Count -eq 1 -and $p.ParameterType -eq [string]
                                        }[0]
  
    $stringConcatStrStrStr    = [string].GetDeclaredMethods('Concat').where{ 
                                        $p = $_.GetParameters()
                                        $p.Count -eq 3 -and $p[0].ParameterType -eq [string] -and $p[1].ParameterType -eq [string] -and
                                                            $p[2].ParameterType -eq [string]
                                        }[0]

    $stringConcatStrStrStrStr = [string].GetDeclaredMethods('Concat').where{ 
                                        $p = $_.GetParameters()
                                        $p.Count -eq 4 -and $p[0].ParameterType -eq [string] -and $p[1].ParameterType -eq [string] -and
                                                            $p[2].ParameterType -eq [string] -and $p[3].ParameterType -eq [string]
                                        }[0]

    $stringJoinInt64        = [string].GetDeclaredMethods('Join').where{$_.IsGenericMethod}[0].MakeGenericMethod([int64])
    $int64ToString          = [int64].GetDeclaredMethods('ToString').Where{$_.getparameters().Count -eq 0}[0]
    
    if (-not $script:int64ToStringHelperVar) { $script:int64ToStringHelperVar = $IL.DeclareLocal([int64]) }
    
    $IL.Emit([OpCodes]::Ldstr, 'Counter: ')
    
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.Emit([OpCodes]::Stloc, $int64ToStringHelperVar)
    $IL.Emit([OpCodes]::Ldloca, $int64ToStringHelperVar)
    $IL.EmitCall([opcodes]::Call, $int64ToString, $null)
    
    $IL.Emit([OpCodes]::Ldstr, '      Instruction Pointer: ')
    
    $IL.Emit([OpCodes]::Ldloc, $ipLocal)
    $IL.Emit([OpCodes]::Stloc, $int64ToStringHelperVar)
    $IL.Emit([OpCodes]::Ldloca, $int64ToStringHelperVar)
    $IL.EmitCall([OpCodes]::Call, $int64ToString, $null)
    
    $IL.EmitCall([OpCodes]::Call, $stringConcatStrStrStrStr, $null)
    
    $IL.Emit([OpCodes]::Ldstr, "`nRegisters: ")
    
    $IL.Emit([OpCodes]::Ldstr, '; ')
    Add-IL-RegistersToArrayOnStack
    $IL.EmitCall([opcodes]::Call, $stringJoinInt64, $null)

    $IL.EmitCall([OpCodes]::Call, $stringConcatStrStrStr, $null)
    $IL.EmitCall([OpCodes]::Call, $consoleWriteLineString, $null)

}

# Increment the debug counter
# do a remainder check
# if it passes, print the registers
function Add-IL-DebugPrint {
    Write-Verbose -Message 'ILGen: if (loopCounter++ % debugCount) { print registers }'
    # loopCounter++
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.Emit([OpCodes]::Ldc_I8, 1L)
    $IL.Emit([OpCodes]::Add)
    $IL.Emit([OpCodes]::Stloc, $loopCounterLocal)
    
    # $loopCounter % cycles
    $IL.Emit([OpCodes]::Ldloc, $loopCounterLocal)
    $IL.Emit([OpCodes]::Ldc_I8, $DEBUGPrintEveryNInstructions)
    $IL.Emit([OpCodes]::Rem)
        
    # if ($that -gt 0) { skip the printing }
    $skipPrintLabel = $IL.DefineLabel()
    
    $IL.Emit([OpCodes]::Ldc_I8, 0L)
    $IL.Emit([OpCodes]::Bgt, $skipPrintLabel)

    Add-ILPrint-Registers
    
    $IL.MarkLabel($skipPrintLabel)
}


##
# End CodeGen Helper Functions
##


# Setup the CIL generation, based on running it now or making an .exe
#
# You might think it could be the same, but .Net Core doesn't support DefineDynamicAssembly with the option to 'Save', afaict
if ($CompileToExe)
{
    $appDomain = [System.AppDomain]::CurrentDomain
    $assemblyName = [System.Reflection.AssemblyName]::new("AoC2018ElfCodeProcessor")
    $assemblyBuilder = $appDomain.DefineDynamicAssembly($assemblyName, [AssemblyBuilderAccess]::Save)
    $moduleBuilder = $assemblyBuilder.DefineDynamicModule("ElfModule", "elf.exe")
    $typeBuilder = $moduleBuilder.DefineType("ProcessorClass", [System.Reflection.TypeAttributes]::Public)
    $methodBuilder = $typeBuilder.DefineMethod("Main", [System.Reflection.MethodAttributes]::Public -bor [System.Reflection.MethodAttributes]::Static, $null, $null)
    $assemblyBuilder.SetEntryPoint($methodBuilder)

    $IL = $methodBuilder.GetILGenerator()
}
else
{
    $methodInfo = new-object Reflection.Emit.DynamicMethod -ArgumentList @('ElfCode', $null, @())
    $IL = $methodInfo.GetILGenerator()
}

##
# Boilerplate start - prepare ElfCode machine
#  1. Make a DynamicMethod and type it to take no params, return an int array.
#  2. Inline opcodes to setup registers, avoids having to load them from a parameter.
##


      
    # Make a local variable for each register and intialize them,
    # with values from the $registers array here.
   $cilRegisterLocals = for ($i = 0; $i -lt $registers.Count; $i++)
   {
       $cilReg = $IL.DeclareLocal([int64])
       $IL.Emit([OpCodes]::Ldc_I8, [int64]$registers[$i])
       $IL.Emit([OpCodes]::Stloc, $cilReg)
       $cilReg
   }


   # Instruction Pointer local var sits after the register vars
   $ipLocal = $IL.DeclareLocal([int64])
   $IL.Emit([OpCodes]::Ldc_I8, 0L)
   $IL.Emit([OpCodes]::Stloc, $ipLocal)


   # only used in debug code
   $loopCounterLocal = $IL.DeclareLocal([int64])
   $IL.Emit([OpCodes]::Ldc_I8, 0L)
   $IL.Emit([OpCodes]::Stloc, $loopCounterLocal)
  
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
$IL.Emit([OpCodes]::Conv_I4) #switch needs int32 here (?)
$IL.Emit([OpCodes]::Switch, $lineJumpLabels)
$defaultCaseLabel = $IL.DefineLabel()
$IL.MarkLabel($defaultCaseLabel)
$IL.Emit([OpCodes]::Br, $haltLabel)

# CIL generation for each line of input, inside a CIL switch jump table
[int64]$i = 0
[int64]$inputLineCounter = 1
foreach ($line in $parsedLines)
{
    Write-Verbose -Message "Generating IL for line $inputLineCounter : $($line[0]) $($line[1] -join ' ')"
    [string]$opcode, [int64[]]$ABC = $line
    
    # output label so IP can jump to this instruction
    $IL.MarkLabel($lineJumpLabels[$i])

    # Instruction Pointer -> Register
    # NB. small optimization - if none of the op codes read or write to it, don't bother loading it.
    if ($ABC -eq $ipRegisterNum)
    {
        $IL.Emit([OpCodes]::Ldloc, $ipLocal)
        $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ipRegisterNum])
    }

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
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
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
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
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
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
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
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
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
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$A])
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'gtir' { # gtir (greater-than immediate/register) sets register C to 1 if value A is greater than register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtir"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$A])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($gtLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'gtri' { # gtri (greater-than register/immediate) sets register C to 1 if register A is greater than value B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtri"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($gtLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'gtrr' { # gtrr (greater-than register/register) sets register C to 1 if register A is greater than register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "gtrr"
            $gtLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Bgt, $gtLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($gtLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'eqir' { # eqir (equal immediate/register) sets register C to 1 if value A is equal to register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqir"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$A])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($eqLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'eqri' { # eqri (equal register/immediate) sets register C to 1 if register A is equal to value B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqri"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldc_I8, [int64]$ABC[$B])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($eqLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
        'eqrr' { # eqrr (equal register/register) sets register C to 1 if register A is equal to register B. Otherwise, register C is set to 0.
            Write-Verbose -Message "eqri"
            $eqLabel = $IL.DefineLabel()
            $IL.Emit([OpCodes]::Ldc_I8, 1L)
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$A]])
            $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ABC[$B]])
            $IL.Emit([OpCodes]::Beq, $eqLabel)
            $IL.Emit([OpCodes]::Pop)
            $IL.Emit([OpCodes]::Ldc_I8, 0L)
            $IL.MarkLabel($eqLabel)
            $IL.Emit([OpCodes]::Stloc, $cilRegisterLocals[$ABC[$C]])
        }
    }

    # IP bound register -> stack -> + 1 -> Instruction Pointer local var
    if ($ABC -eq $ipRegisterNum)
    {
        $IL.Emit([OpCodes]::Ldloc, $cilRegisterLocals[$ipRegisterNum])
    }
    else
    {
        $IL.Emit([OpCodes]::Ldloc, $iplocal)
    }
    $IL.Emit([OpCodes]::Ldc_I8, 1L)
    $IL.Emit([OpCodes]::Add)
    $IL.Emit([OpCodes]::Stloc, $ipLocal)

    
    if ($DEBUGPrintEveryNInstructions -gt 0)
    {
        Add-IL-DebugPrint
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
    Add-ILPrint-Registers
    $IL.Emit([OpCodes]::Ret)

##
# Boilerplate end - end of CIL code generation.
##

if ($CompileToExe)
{
    Write-Verbose -Verbose -Message "Saving to elf.exe"
    $ProcessorClass = $typeBuilder.CreateType()
    $assemblyBuilder.Save("elf.exe")
}
else
{
    Write-Verbose -Verbose -Message "Running the generated code"
    # Convert DyanmicMethod -> Delegate, and call it.
    $ElfCode = $methodInfo.CreateDelegate([System.Action])

    write-host "Before: $($registers -join ', ')"
    $ElfCode.Invoke()
}
