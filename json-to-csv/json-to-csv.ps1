#Requires -Version 7
Param (
    [string]$InFile = "",
    [string]$OutFile = "json-to-csv.csv",
    [int]$First = 0
)

$BaseProperties = [System.Collections.ArrayList]::New(@(
        "name",
        "displayName",
        "id",
        "type",
        "desc",
        "_extensionFileName",
        "sourceBook",
        "level",
        "sortLevel",
        "levelreq",
        "levelReq",
        "bulk",
        "price",
        "access",
        "PFSnote",
        "subType",
        "subTypeDesc",
        "hide",
        "critSuccess",
        "success",
        "failure",
        "critFailure",
        "traits/0",
        "traits/1",
        "traits/2",
        "traits/3",
        "traits/4",
        "traits/5",
        "traits/6",
        "traits/7",
        "traits/8",
        "traits/9",
        "traits/10",
        "traits/11",
        "traits/12",
        "traits/13",
        "traits/14",
        "traits/15",
        "traits/16",
        "traits/17",
        "traits/18",
        "traits/19",
        "traits/20"
    ))

if ($InFile) {
    $OutFile = $InFile -Replace "\.json$", ".csv"
}

$ScriptPath = $PSScriptRoot

$InPath = "$PSScriptRoot\Input\$InFile"
$OutPath = "$PSScriptRoot\Output\$OutFile"

$objects = @()

foreach ($File in (Get-ChildItem $InPath | Where-Object { $_.Name -like "*.json" })) {
    try {
        $Objects += (Get-Content $File) | ConvertFrom-Json -Depth 100
    }
    catch {
        Write-Host "$($File.Name) could not be imported."
        Write-Host -ForegroundColor Red $_
    }
}

if ($Objects.count -eq 0) {
    Write-Host "No files were imported."
    Exit 1
}

$PropertyList = [System.Collections.ArrayList]::new()

$ConvertedObjects = @()

function Set-Property([PSObject]$ConvertedObject, [PSObject]$Property, [string]$path) {
    #Reverse comparison to avoid (0 -eq "") being true.
    if (("" -ne $Property) -or ($property -isnot [string])) {
        if ($Property -is [array]) {
            foreach ($Index in (0..($Property.count - 1))) {
                Set-Property $ConvertedObject $Property[$Index] "$path/$Index"
            }
        }
        elseif ($Property.GetType().Name -eq "PSCustomObject") {
            foreach ($SubProperty in $Property.PSObject.Properties.Name) {
                Set-Property $ConvertedObject $Property.$SubProperty "$path/$SubProperty"
            }
        }
        else {
            Add-Member -InputObject $ConvertedObject -MemberType NoteProperty -name $Path -Value $Property
            if (-not ($PropertyList -contains $Path)) {
                $propertyList.Add($Path) | Out-Null
            }
        }
    }
}

if ($First -eq 0) {
    $First = $Objects.Count
}

$Progress = 0

foreach ($Object in ($Objects | Select-Object -First $First)) {
    $ConvertedObject = New-Object PSObject
    foreach ($Property in $Object.PSObject.Properties.Name) {
        Set-Property $ConvertedObject $Object.$Property $Property
    }
    $ConvertedObjects += $convertedObject
    $Progress++
    Write-Progress -Activity "Flattening properties..." -Status "$Progress of $($Objects.Count) Objects" -PercentComplete ($Progress / $Objects.Count * 100)
}

Write-Progress -Activity "Flattening properties..." -PercentComplete 100 -Completed
Write-Host "Wrote $($PropertyList.Count) properties on $Progress objects."

$SortedProperties = @()
$BaseProperties | ForEach-Object {
    if ($PropertyList -ccontains $_) {
        $SortedProperties += $_
    }
}
$SortedProperties += $PropertyList | Sort-Object | WHere-Object { -not ($_ -like "*/*") } 
$SortedProperties += ($PropertyList | Sort-Object)
$SortedProperties = $SortedProperties | Select-Object -Unique

$ConvertedObjects | Select-Object $SortedProperties | Export-CSV -NoTypeInformation $OutPath