#Requires -Version 7
#Json encoding doesn't match expectations in Powershell 5
Param (
    [string]$InFile = "*",
    [string]$OutFile = "",
    [string]$Split = "",
    [int]$First = 0,
    [switch]$NoSort
)

if (-not ($OutFile)) {
    if ($Infile -ne "*") {
        $OutFile = $InFile -Replace "\.csv", ".json"
    }
    else {
        $OutFile = "csv-to-json.json"
    }
}

if ($InFile -eq "*") {
    Write-Host "No file given, using first file in input folder: "
    $InFile = (Get-ChildItem "$($MyInvocation.MyCommand.Path.Replace('\csv-to-json.ps1', ''))\Input\" | Select-Object -First 1).Name
}

$InPath = "$($MyInvocation.MyCommand.Path.Replace('\csv-to-json.ps1', ''))\Input\$InFile"
$OutPath = "$($MyInvocation.MyCommand.Path.Replace('\csv-to-json.ps1', ''))\Output"

$script:stringOverrides = @(
    "effects\/[\d]+\/value$",
    "effects\/[\d]+\/setValue$",
    "Effects\/[\d]+\/value$",
    "^bulk$",
    "gainSpells\/[\d]+\/dynamicLevel$",
    "\/[\d]+\/0/dynamicEffectiveSpellLevel$",
    "descs\/[\d]+\/value$"
)

$script:ImportedCSV = $()
try {
    $ImportedCSV = Import-CSV -Path $InPath
}
catch {
    Write-Host "CSV $InPath could not be imported."
    Write-Host -ForegroundColor Red $_
    Exit 1
}

if ($Split) {
    if (($importedCSV.$Split | Where-Object { $_ }).Count -eq 0) {
        Write-Host "No row has the field '$Split' - content will not be split."
        $Split = ""
    }
}

function Convert-DataType([string]$Value, [string]$Path) {
    if ($isStringList -Contains $Path) {
        return $value
    }
    elseif ($value -match "^-?\d+(\.\d+)$") {
        return [convert]::ToDecimal($value)
    }
    elseif ($value -match "^-?\d+$") {
        return [convert]::ToInt32($value)
    }
    elseif ($value -eq "TRUE") {
        return $true
    }
    elseif ($Value -eq "FALSE") {
        return $false   
    }
    else {
        return $value
    }
}

function New-Property($Parts, $Row, $Basis, $Current, $Path) {
    $Next = $Current + 1
    if ($Next -eq $Parts.Count) {
        if ($Row.$Path -eq "Undead Creature Damage Resistance") {
            $Test | Out-Null
        }
        return (Convert-DataType $Row.$Path $Path)
    }
    else {
        if ($Parts[$Next] -match "^\d+$") {
            if ($Basis.$($Parts[$Current])) {
                $ArrayObject = [System.Collections.ArrayList]@($Basis.$($Parts[$Current]))
            }
            else {
                $ArrayObject = ([System.Collections.ArrayList]::new())
            }
            if ($ArrayObject[$Parts[$Next]]) {
                $ArrayObject[$Parts[$Next]] = (New-Property $Parts $Row $ArrayObject $Next $Path)
            }
            else {
                While ($ArrayObject.Count -lt $Parts[$Next]) {
                    $ArrayObject.Add("") | Out-Null
                }
                $ArrayObject.Add((New-Property $Parts $Row $ArrayObject $Next $Path)) | Out-Null
            }
            return $ArrayObject
        }
        else {
            if ($Basis -is [System.Collections.ArrayList]) {
                if ($Basis[$($Parts[$Current])]) {
                    $SubObject = ($Basis[$($Parts[$Current])])
                }
                else {
                    $SubObject = (New-Object PSObject)
                }
            }
            elseif ($Basis.$($Parts[$Current])) {
                $SubObject = ($Basis.$($Parts[$Current]))
            }
            else {
                $SubObject = (New-Object PSObject)
            }
            if ($SubObject.$($Parts[$Next])) {
                $SubObject.$($Parts[$Next]) = (New-Property $Parts $Row $SubObject $Next $Path)
            }
            else {
                Add-Member -InputObject $SubObject -MemberType NoteProperty -Name $Parts[$Next] -Value (New-Property $Parts $Row $SubObject $Next $Path)
            }
            if ($Parts[$Next + 1] -and $Parts[$Next + 1] -match "^\d+$") {
                if ($Parts[$Next] -isnot [System.Collections.ArrayList]) {
                    $SubObject.$($Parts[$Next]) = [System.Collections.ArrayList]@($SubObject.$($Parts[$Next]))
                }
            }
            return $SubObject
        }
    }
}

function Update-Property($Object) {
    forEach ($Property in $Object.PSObject.Properties.Name) {
        if (($Object.$Property -is [System.Collections.ArrayList]) -or ($Object.$Property -is [array])) {
            foreach ($Index in 0..($Object.$Property.Count - 1)) {
                if ($Object.$Property[$Index] -is [psobject]) {
                    Update-Property $Object.$Property[$Index]
                    if (-not @($Object.$Property[$Index].PSObject.Properties.Count)) {
                        $Object.$Property[$Index] = ""
                    }
                } 
            }
            $Object.$Property = $Object.$Property | Where-Object { $_ -ne "" }
            if ($Object.$Property.Count -eq 0) {
                $Object.PSObject.Properties.Remove($Property)
            }
            else {
                $Object.$Property = [System.Collections.ArrayList]@($Object.$Property)
            }
        }
        elseif ($Object.$Property -is [psobject]) {
            Update-Property $Object.$Property
            if (@($Object.$Property.PSObject.Properties.Count) -eq 0) {
                $Object.PSObject.Properties.Remove($Property)
            }
        }
        #Reverse comparison to avoid (0 -eq "") being true.
        elseif (("" -eq $Object.$Property) -and ($Property -ne $Split)) {
            $Object.PSObject.Properties.Remove($Property)
        }
    }
}

$Progress = 0

$isStringList = [System.Collections.ArrayList]::new()

$Headers = $ImportedCSV[0].PSObject.Properties.Name

foreach ($Header in $Headers) {
    $isString = $false

    if (($script:stringOverrides | Where-Object { $Property.Path -match $_ }).Count -gt 0) {
        $isString = $true
    }
    else {
        $LegalValues = $ImportedCSV.$Header | Where-Object { "" -ne $_ }
        if ($LegalValues -match "^(?!.*(TRUE|FALSE))[^\d\W]") {
            $isString = $true;
        }
    }

    if ($isString) {
        $isStringList.Add($Header) | Out-Null
    }
    $Progress++
    Write-Progress -Activity "Step 1 of 3: Determining datatypes..." -Status "$Progress of $($Headers.Count) properties" -PercentComplete ($Progress / $Headers.Count * 100)
}

Write-Progress -Activity "Step 1 of 3: Determining datatypes..." -PercentComplete 100 -Completed
Write-Host "Processed $Progress properties."

$Progress = 0

if ($First -eq 0) {
    $First = $ImportedCSV.Count
}

$Objects = [System.Collections.ArrayList]::new()

Foreach ($Row in $ImportedCSV | Select-Object -First $First) {
    $Object = New-Object -TypeName PSObject
    foreach ($Path in $Row.PSObject.Properties.Name | Where-Object { ($_ -eq $Split) -or ("" -ne $Row.$($_)) }) {
        $Parts = $Path -Split "\/"
        if ($Object.$($Parts[0])) {
            $Object.$($Parts[0]) = (New-Property $Parts $Row $Object 0 $Path)
        }
        else {
            Add-Member -InputObject $Object -MemberType NoteProperty -Name $Parts[0] -Value (New-Property $Parts $Row $Object 0 $Path) -Force
        }
        if ($Parts[1] -Match "^\d$") {
            if (-not ($Object.$($Parts[0]) -is [System.Collections.ArrayList])) {
                $Object.$($Parts[0]) = [System.Collections.ArrayList]@($Object.$($Parts[0]))
            }
        }
    }
    $Objects.add($Object) | Out-Null
    $Progress++
    Write-Progress -Activity "Step 2 of 3: Converting rows..." -Status "$Progress of $($ImportedCSV.Count) rows" -PercentComplete ($Progress / $ImportedCSV.Count * 100)
}

Write-Progress -Activity "Step 2 of 3: Converting rows..." -PercentComplete 100 -Completed
Write-Host "Converted $Progress rows."

$Progress = 0

Foreach ($Object in $Objects) {
    Update-Property $Object
    $Progress++
    Write-Progress -Activity "Step 3 of 3: Cleaning up..." -Status "$Progress of $($Objects.Count) Objects" -PercentComplete ($Progress / $Objects.Count * 100)
}

Write-Progress -Activity "Step 3 of 3: Cleaning up..." -PercentComplete 100 -Completed
Write-Host "Cleaned $Progress objects."

if (-not $NoSort) {
    $Sorting = @()
    if ($Objects.sortLevel) {
        $Sorting += "sortLevel"
    }
    if ($Objects.level) {
        $Sorting += "level"
    }
    if ($Objects.name) {
        $Sorting += "name"
    }
    if ($Sorting.Count) {
        $Objects = $Objects | Sort-Object -Property $Sorting
    }
}

if ($Split) {
    $invalidChars = [IO.Path]::GetInvalidFileNameChars() -join ''
    $re = "[{0}]" -f [RegEx]::Escape($invalidChars)
    foreach ($Variation in ($Objects.$Split | Select-Object -Unique)) {
        if ($Variation -eq "") {
            $Path = "Other"
        }
        else {
            $Path = ($Variation -replace $re)
        }
        $ExportedObjects = $Objects | Where-Object { $_.$Split -eq $Variation }
        if ($ExportedObjects.name) {
            $ExportedObjects = $ExportedObjects | Sort-Object -Property "name"
        }
        if ($ExportedObjects.level) {
            $ExportedObjects = $ExportedObjects | Sort-Object -Property "level"
        }
        ($ExportedObjects | ConvertTo-JSON -Depth 100 -AsArray).Replace("\r\n", "\n") | Set-Content "$OutPath\$Path.json"
        Write-Host "Exported $(@($ExportedObjects).Count) entries to $Path.json"
    }
}
else {
    ($Objects | ConvertTo-JSON -Depth 100 -AsArray).Replace("\r\n", "\n") | Set-Content "$OutPath\$OutFile"
    Write-Host "Exported $(@($Objects).Count) entries to $OutFile"
}