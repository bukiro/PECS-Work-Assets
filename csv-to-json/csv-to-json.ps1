#Requires -Version 7
#Json encoding doesn't match expectations in Powershell 5
Param (
    [string]$InFile = "*",
    [string]$OutFile = "",
    [string]$Split = "",
    [int]$First = 0
)

if (-not ($OutFile)) {
    if ($Infile -ne "*") {
        $OutFile = $InFile -Replace "\.csv", ".json"
    }
    else {
        $OutFile = "csv-to-json.json"
    }
    
}

$InPath = "$($MyInvocation.MyCommand.Path.Replace('\csv-to-json.ps1', ''))\Input\$InFile"
$OutPath = "$($MyInvocation.MyCommand.Path.Replace('\csv-to-json.ps1', ''))\Output"

$script:stringOverrides = @(
    "effects\/[\d]+\/value$",
    "effects\/[\d]+\/setValue$",
    "^bulk$",
    "gainSpells\/[\d]+\/dynamicLevel$",
    "\/[\d]+\/0/dynamicEffectiveSpellLevel$"
)

$script:ImportedCSV = $()
try {
    $ImportedCSV = Import-CSV -Path $InPath
}
catch {
    Write-Host "CSV $InPath could not be imported."
    Exit 1
}

if ($Split) {
    if (($importedCSV.$Split | Where-Object { $_ }).Count -eq 0) {
        Write-Host "No row has the field '$Split' - content will not be split."
        $Split = ""
    }
}

Class JSONProperty {
    [string]$Name
    [string]$Path
    [JSONProperty[]]$Properties = @()
    [boolean]$isString = $false
    [boolean]$isNumber = $false
    [boolean]$isBoolean = $false
    [boolean]$isArray = $false
    
    #JSONProperty([string]$Name, [string]$Path, [boolean]$Array = $false) {
    JSONProperty([string]$Name, [string]$Path) {
        $this.Name = $Name
        $this.Path = $Path
    }

    setType() {
        if ($this.Name -Match "\d") {
            $this.isArray = $true
            return
        }
        #Variables in the string overrides list are always strings.
        if (($script:stringOverrides | Where-Object { $Property.Path -match $_ }).Count -gt 0) {
            $this.isString = $true
            return
        }
    
        foreach ($Value in ($script:ImportedCSV."$($this.Path)" | Where-Object { $_ })) {
            if ($this.isString) {
                break;
            }
            if ($value -match "^-?\d+(\.\d+)?$") {
                $this.isNumber = $true
            }
            elseif (($value -eq "TRUE") -or ($value -eq "FALSE")) {
                $this.isBoolean = $true
            }
            else {
                $this.isString = $true
                $this.isNumber = $false
                $this.isBoolean = $false
                $this.isArray = $false
            }
        }
        return
    }
}

function Convert-DataType([string]$value, [JSONProperty]$Property) {
    if (-not $value) {
        return $value
    }
    if ($Property.isString) {
        return $value
    }
    elseif ($Property.isNumber) {
        if ($value -match "^-?\d+(\.\d+)$") {
            return [convert]::ToDecimal($value)
        }
        else {
            return [convert]::ToInt32($value)
        }
    }
    elseif ($Property.isBoolean) {
        if ($value -eq "TRUE") {
            return $true
        }
        else {
            return $false   
        }
    }
    else {
        return $value
    }
}

function New-Property([PSObject]$Row, [JSONProperty]$Property) {
    if ($Property.Properties.Count -gt 0) {
        if ($Property.Properties[0].Name -Match "\d") {
            $ArrayObject = [System.Collections.ArrayList]::new()
            foreach ($SubProperty in $Property.Properties) {
                $ArrayObject.Add((New-Property $Row $SubProperty)) | Out-Null
            }
            return $ArrayObject
        }
        else {
            $SubObject = New-Object -TypeName PSObject
            foreach ($SubProperty in $Property.Properties) {
                Add-Member -InputObject $SubObject -MemberType NoteProperty -Name $SubProperty.Name -Value (New-Property $Row $SubProperty)
                if (($SubProperty.Properties.Count -gt 0) -and ($SubProperty.Properties[0].Name -Match "\d")) {
                    if (-not ($SubObject."$($SubProperty.Name)" -is [array])) {
                        $SubObject."$($SubProperty.Name)" = [array]@($SubObject."$($SubProperty.Name)")
                    }
                }
            }
            return $SubObject
        }
    }
    else {
        return Convert-DataType $Row."$($Property.Path)" $Property
    }
}

function Update-Property($Object) {
    forEach ($Property in $Object.PSObject.Properties.Name) {
        if ($Object.$Property -is [array]) {
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
                $Object.$Property = [array]@($Object.$Property)
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

[JSONProperty[]]$Template = @()

$Headers = $ImportedCSV[0].PSObject.Properties.Name

$Progress = 0

foreach ($Header in $Headers) {
    $Parts = $Header -Split "\/"
    if (-not ($Template.Name -Contains $Parts[0])) {
        $Template += [JSONProperty]::New($Parts[0], $Parts[0])
        $Template[$Template.length - 1].setType()
    }
    $Test = $null
    if ($Parts.Count -gt 1) {
        foreach ($Index in (1..($Parts.Count - 1))) {
            if ($Parts[$Index]) {
                if ($Index -eq 1) {
                    $Test = $Template | Where-Object { $_.Name -eq $Parts[$Index - 1] }
                }
                else {
                    $Test = $Test.Properties | Where-Object { $_.Name -eq $Parts[$Index - 1] }
                }
                if (-not ($Test.Properties.Name -Contains $Parts[$Index])) {
                    $Test.Properties += [JSONProperty]::New($Parts[$Index], ($Parts[0..$Index] -Join "/"))
                    $Test.Properties[$Test.Properties.length - 1].setType()
                }
            }
        }
    }
    $Progress++
    Write-Progress -Activity "Step 1 of 3: Building structure..." -Status "$Progress of $($Headers.Count) Properties" -PercentComplete ($Progress / $Headers.Count * 100)
}

Write-Progress -Activity "Step 1 of 3: Building structure..." -PercentComplete 100 -Completed
Write-Host "Processed $Progress properties."

$Objects = @()

$Progress = 0

if ($First -eq 0) {
    $First = $ImportedCSV.Count
}

Foreach ($Row in $ImportedCSV | Select-Object -First $First) {
    $Object = New-Object -TypeName PSObject
    foreach ($Property in $Template) {
        Add-Member -InputObject $Object -MemberType NoteProperty -Name $Property.Name -Value (New-Property $Row $Property)
        if (($Property.Properties.Count -gt 0) -and ($Property.Properties[0].Name -Match "\d")) {
            if (-not ($Object."$($Property.Name)" -is [array])) {
                $Object."$($Property.Name)" = [array]@($Object."$($Property.Name)")
            }
        }
    }
    $Objects += $Object
    $Progress++
    Write-Progress -Activity "Step 2 of 3: Converting entries..." -Status "$Progress of $($ImportedCSV.Count) Entries                                         " -PercentComplete ($Progress / $ImportedCSV.Count * 100)
}

Write-Progress -Activity "Step 2 of 3: Converting entries..." -PercentComplete 100 -Completed
Write-Host "Converted $Progress entries."

$Progress = 0

Foreach ($Object in $Objects) {
    Update-Property $Object
    $Progress++
    Write-Progress -Activity "Step 3 of 3: Cleaning up..." -Status "$Progress of $($Objects.Count) Objects" -PercentComplete ($Progress / $Objects.Count * 100)
}

Write-Progress -Activity "Step 3 of 3: Cleaning up..." -PercentComplete 100 -Completed
Write-Host "Cleaned $Progress objects."

if ($Objects.name -and $objects.level) {
    $Objects = $Objects | Sort-Object -Property level, name
}
elseif ($Objects.name) {
    $Objects = $Objects | Sort-Object -Property name
}
elseif ($Objects.level) {
    $Objects = $Objects | Sort-Object -Property level
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