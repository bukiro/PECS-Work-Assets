#Requires -Version 7
#Json encoding doesn't match expectations in Powershell 5

Param (
    [string]$InFile = "*",
    [string]$OutFile = "",
    [string]$Split = "",
    [int]$First = 0,
    [switch]$NoSort,
    [switch]$ForceSingleThread,
    [switch]$SkipQuoting
)

if (-not ($OutFile)) {
    if ($Infile -ne "*") {
        $OutFile = $InFile -Replace "\.csv", ".json"
    }
    else {
        $OutFile = "csv-to-json.json"
    }
}

$ScriptPath = $PSScriptRoot

if ($InFile -eq "*") {
    Write-Host "No file given, using first file in input folder: "
    $InFile = (Get-ChildItem "$ScriptPath\Input\" | Select-Object -First 1).Name
}

$InPath = "$ScriptPath\Input\$InFile"
$TempPath = "$ScriptPath\Temp\$InFile"
$OutPath = "$ScriptPath\Output"

$script:stringOverrides = @(
    "effects\/[\d]+\/value$",
    "effects\/[\d]+\/setValue$",
    "Effects\/[\d]+\/value$",
    "^bulk$",
    "gainSpells\/[\d]+\/dynamicLevel$",
    "\/[\d]+\/0/dynamicEffectiveSpellLevel$",
    "descs\/[\d]+\/value$"
)

$ImportedObjects = $()
if (Test-Path $InPath) {
    try {
        if ($SkipQuoting) {
            $ImportedObjects = Import-CSV $InPath
        }
        else {
            #The following line is a regex hack that quotes every value in the csv that starts with a space, so that these values aren't trimmed in the import.
            # As a side effect, already quoted values are double-quoted and need to be cleaned up again. Previously existing double quotes are preserved by replacing them for the process and reverting them after.
            (Get-Content $InPath | Out-String ) -Replace '""', "[escapeddoublequotes]" -Replace '(\"[^\"]+\")|(?<=^|,)( [^,]+)', '$1"$2"' -Replace '\"+', '"' -Replace "\[escapeddoublequotes\]", '""' | Set-Content $TempPath
            $ImportedObjects = Import-CSV $TempPath
            Remove-Item $TempPath -Confirm:$false
        }
    }
    catch {
        Write-Host "CSV $InPath could not be imported."
        Write-Host -ForegroundColor Red $_
        Exit 1
    } 
}
else {
    Write-Host "CSV $InPath could not be imported."
    Write-Host -ForegroundColor Red "File not found."
    Exit 1
}

if ($Split) {
    if (($ImportedObjects.$Split | Where-Object { $_ }).Count -eq 0) {
        Write-Host "No row has the field '$Split' - content will not be split."
        $Split = ""
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

if ($First -eq 0) {
    $First = $ImportedObjects.Count
}

$Multithreaded = (($First -gt 100) -and (-not $ForceSingleThread))

$Headers = $ImportedObjects[0].PSObject.Properties.Name

foreach ($Header in $Headers) {
    $isString = $false

    if (($script:stringOverrides | Where-Object { $Header -match $_ }).Count -gt 0) {
        $isString = $true
    }

    $LegalValues = (($ImportedObjects | Select-Object -First $First).$Header | Where-Object { "" -ne $_ })
    if ($LegalValues.Count -gt 0) {
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

if ($Multithreaded) {
    $Step = 10
    $Jobs = for ($Processed = 0; $Processed -lt $First; $Processed += $Step) {
        $ObjectBlock = @($ImportedObjects | Select-Object -First $Step -Skip $Processed)
        Start-ThreadJob -ScriptBlock { & "$($using:ScriptPath)\convert-rows.ps1" -ObjectBlock $using:ObjectBlock -isStringList $using:isStringList -Split $using:Split -SuppressProgress } -ThrottleLimit 10
    }
    Write-Host "Started $($Jobs.Count) conversion threads."
    $JobsTotal = $Jobs.Count
    While ($Jobs | Where-Object State -ne "Completed") {
        $Progress = ($Jobs | Where-Object State -eq "Completed").Count
        $Running = ($Jobs | Where-Object State -eq "Running").Count
        Write-Progress -Activity "Step 2 of 3: Converting rows..." -CurrentOperation "Running Jobs" -Status "$Progress of $JobsTotal jobs completed ($Running running)" -PercentComplete ($Progress / $JobsTotal)
        Start-Sleep -Milliseconds 100
    }
    $Jobs | Wait-Job | Out-Null
    $Objects = @()
    $Jobs | Foreach-Object {
        $Objects += Receive-Job $_
    }
    $Jobs | Remove-Job
}
else {
    $Objects = & "$ScriptPath\convert-rows.ps1" -ObjectBlock ($ImportedObjects | Select-Object -First $First) -isStringList $isStringList -Split $Split
}

Write-Progress -Activity "Step 2 of 3: Converting rows..." -PercentComplete 100 -Completed
Write-Host "Converted $($Objects.Count) rows."

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
    if ($Objects.type) {
        $Sorting += "type"
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

if ($Objects.Count) {
    if ($Split) {
        Foreach ($Object in $Objects) {
            $ObjectSplit = $Object.$Split
            if (-not $ObjectSplit) {
                $ObjectSplit = "other"
            }
            if ($Object.PSObject.Properties.Name -Contains "_extensionFileName") {
                $Object."_extensionFileName" = $ObjectSplit
            }
            else {
                Add-Member -InputObject $Object -MemberType NoteProperty -Name "_extensionFileName" -Value $ObjectSplit
            }
        }
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
}
else {
    Write-Host "No content was generated."
}