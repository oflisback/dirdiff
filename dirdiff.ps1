[CmdletBinding()]
param (
  [parameter(HelpMessage="Stores the execution working directory.")]
  [string]$ExecutionDirectory=$PWD,

  [parameter(Position=0,HelpMessage="Compare two directories recursively for differences.")]
  [string[]]$Compare
)

# Validates string, might be a path
function ValidatePath($PathName, $TestPath) {
  If([string]::IsNullOrWhiteSpace($TestPath)) {
    Write-Host ("{0} is not a path" -f $PathName)
  }
}

# Normalizes relative or absolute path to absolute path
function NormalizePath($PathName, $TestPath) {
  ValidatePath "$PathName" "$TestPath"
  $TestPath = [System.IO.Path]::Combine((pwd).Path, $TestPath)
  $NormalizedPath = [System.IO.Path]::GetFullPath($TestPath)
  return $NormalizedPath
}

# Validates string, resolves to a path and returns absolute path
function RequirePath($PathName, $TestPath, $PathType) {
  ValidatePath $PathName $TestPath
  If(!(Test-Path $TestPath -PathType $PathType)) {
    Write-Host ("{0} ({1}) does not exist as a {2}." -f $PathName, $TestPath, $PathType)
    exit 1
  }
  $ResolvedPath = Resolve-Path $TestPath
  return $ResolvedPath
}

# Sets working directory for .NET
function SetWorkDir($PathName, $TestPath) {
  $AbsPath = NormalizePath $PathName $TestPath
  Set-Location $AbsPath
  [System.IO.Directory]::SetCurrentDirectory($AbsPath)
}

# Gets all files in a path recursively
function GetFiles {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$TRUE,Position=0,HelpMessage="Path to get files for.")]
    [string]$Path
  )
  PROCESS {
    Get-ChildItem $Path -r | where { !$_.PSIsContainer }
  }
}

# Returns list of @{RelativePath, Hash, FullName}
function GetFilesWithHash {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$TRUE,Position=0,HelpMessage="Path to get files for.")]
    [string]$Path
  )
  PROCESS {
    $OriginalPath = $PWD
    SetWorkDir path/to/diff $Path
    GetFiles $Path | select @{N="RelativePath";E={$_.FullName | Resolve-Path -Relative}},
                            @{N="Hash";E={(Get-FileHash $_.FullName -Algorithm "MD5" | select Hash).Hash}},
                            FullName
    SetWorkDir path/to/original $OriginalPath
  }
}

# Wrap single element in array, no need to deal with array input,
# powershell automatically flattens nested arrays
function ToArray
{
  BEGIN {
    $output = @();
  }
  PROCESS {
    $output += $_;
  }
  END {
    return ,$output;
  }
}

# Returns List of @{RelativePath, Hash, FullName}
function DiffDirectories {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$TRUE,Position=0,HelpMessage="Directory to compare left.")]
    [alias("l")]
    [string]$LeftPath,

    [parameter(Mandatory=$TRUE,Position=1,HelpMessage="Directory to compare right.")]
    [alias("r")]
    [string]$RightPath
  )
  PROCESS {
    $LeftHash = GetFilesWithHash $LeftPath | ToArray
    $RightHash = GetFilesWithHash $RightPath | ToArray

    # -Property specifies a _combination_ of properties that are tested for equality
    # OLA: Added -PassThru to include FullName
    diff -PassThru -IncludeEqual -ReferenceObject $LeftHash -DifferenceObject $RightHash -Property RelativePath,Hash
  }
}

function PrintResult {
  [CmdletBinding()]
  param (
    [parameter(Mandatory=$TRUE,Position=0)]
    $Elements,

    [parameter(Mandatory=$TRUE,Position=1)]
    [string]$SingularString,

    [parameter(Mandatory=$TRUE,Position=2)]
    [string]$PluralString
  )
  PROCESS {
    If ($Elements.Count -eq 0) {
      Write-Host ("No {0}." -f $PluralString)
    } ElseIf ($Elements.Count -eq 1) {
      Write-Host ("One {0}:" -f $SingularString)
    } Else {
      Write-Host ("{0} {1}:" -f $Elements.Count, $PluralString)
    }
    Write-Host ($Elements | % { ("`t{0} `n" -f $_.RelativePath)}) -NoNewline -f "green"
  }
}

if($Compare.Count -ne 2) {
  Write-Host "USAGE: dirdiff <first directory>,<second directory>"
  Write-Host ("Dirdiff requires passing exactly 2 directory parameters separated by comma, {0} were received." -f $Compare.length)
  exit 1
}

$leftPath = RequirePath path/to/left $Compare[0] container
$rightPath = RequirePath path/to/right $Compare[1] container
$diff = DiffDirectories $leftPath $rightPath
$identical = $diff | where {$_.SideIndicator -eq "=="} | ToArray
$leftDiff = $diff | where {$_.SideIndicator -eq "<="} | select RelativePath,Hash,FullName
$rightDiff = $diff | where {$_.SideIndicator -eq "=>"} | select RelativePath,Hash,FullName

If ($leftDiff -eq $null) {$leftDiff =@()}
If ($rightDiff -eq $null) {$rightDiff = @()}

# Get the RelativePaths that are in both leftDiff and rightDiff
$different = diff -IncludeEqual -ExcludeDifferent -ReferenceObject $leftDiff -DifferenceObject $rightDiff -Property RelativePath | ToArray

# Get the RelativePaths that are only in leftDiff
$onlyInLeft = diff -PassThru -ReferenceObject $leftDiff -DifferenceObject $rightDiff -Property RelativePath | where {$_.SideIndicator -eq "<="} | ToArray

# Get the RelativePaths that are only in rightDiff
$onlyInRight = diff -PassThru -ReferenceObject $leftDiff -DifferenceObject $rightDiff -Property RelativePath | where {$_.SideIndicator -eq "=>"} | ToArray

PrintResult $identical "identical file" "identical files"
PrintResult $onlyInLeft ("file only present in {0}" -f $leftPath) ("files only present in {0}" -f $leftPath)
PrintResult $onlyInRight ("file only present in {0}" -f $rightPath) ("files only present in {0}" -f $rightPath)
PrintResult $different "file present in both directories and has different content" "files present in both directories and have different content"
