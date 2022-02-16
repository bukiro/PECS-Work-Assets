#Requires -Version 7
Param (
    [Parameter(Mandatory = $true)][string]$Path,
    #[string]$Path = "wornitems.csv",
    [string]$OutFile = ""
)

if (-not ($OutFile)) {
    $OutFile = $Path -Replace "\.csv", ".json"
}

$stringOverrides = @(
    "effects\/[\d]+\/value$",
    "effects\/[\d]+\/setValue$",
    "^bulk$",
    "gainSpells\/[\d]+\/dynamicLevel$",
    "\/[\d]+\/0/dynamicEffectiveSpellLevel$"
)

$ImportedCSV = $()
try {
    $ImportedCSV = Import-CSV -Path $Path
}
catch {
    Write-Host "CSV $Path could not be imported."
    Exit 1
}

Class JSONProperty {
    [string]$Name
    [string]$Path
    #[boolean]$Array
    [JSONProperty[]]$Properties = @()
    
    #JSONProperty([string]$Name, [string]$Path, [boolean]$Array = $false) {
    JSONProperty([string]$Name, [string]$Path) {
        $this.Name = $Name
        $this.Path = $Path
    }
}

function New-Property($Row, $Property) {
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
        #Literals start off as a string
        $value = $Row."$($Property.Path)"
        #If they are in the string overrides list, they remain a string, with typical bad characters replaced.
        if (($stringOverrides | Where-Object { $Property.Path -match $_ }).Count -gt 0) {
            $value = $value.Replace('–', '-').Replace("’", "'").Replace('“', '"').Replace('”', '"').Replace('—', ' - ')
        }
        #Otherwise they get converted to decimals, ints or booleans as appropriate.
        elseif ($value -match "^-?\d+(\.\d+)$") {
            $value = [convert]::ToDecimal($value)
        }
        elseif ($value -match "^-?\d+$") {
            $value = [convert]::ToInt32($value, 10)
        }
        elseif ($value -eq "TRUE") {
            $value = $true
        }
        elseif ($value -eq "FALSE") {
            $value = $false   
        } else {
            $value = $value.Replace('–', '-').Replace("’", "'").Replace('“', '"').Replace('”', '"').Replace('—', ' - ')
        }
        return $value
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
        elseif ("" -eq $Object.$Property) {
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

Foreach ($Row in $ImportedCSV) {
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

Write-Progress -Activity "Finished and exporting..." -PercentComplete 100 -Completed
Write-Host "Cleaned $Progress objects."

$Objects | ConvertTo-JSON -Depth 100 | Set-Content $OutFile