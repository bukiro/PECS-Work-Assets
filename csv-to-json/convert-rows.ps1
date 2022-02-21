#Requires -Version 7
#Json encoding doesn't match expectations in Powershell 5
Param (
    [PSObject[]]$ObjectBlock,
    [string[]]$isStringList,
    [string]$Split,
    [switch]$SuppressProgress
)

$script:isStringList = $isStringList

function Convert-DataType([string]$Value, [string]$Path) {
    if ($Script:isStringList -Contains $Path) {
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

$Progress = 0

$Objects = [System.Collections.ArrayList]::New()

Foreach ($Row in $ObjectBlock) {
    $Object = New-Object -TypeName PSObject
    foreach ($Path in $Row.PSObject.Properties.Name | Where-Object { (("" -ne $Split) -and ($_ -eq $Split)) -or ("" -ne $Row.$($_)) }) {
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
    if (-not $SuppressProgress) {
        Write-Progress -Activity "Step 2 of 3: Converting rows..." -Status "$Progress of $($ObjectBlock.Count) rows" -PercentComplete ($Progress / $($ObjectBlock.Count * 100))
    }
}
    
$Objects