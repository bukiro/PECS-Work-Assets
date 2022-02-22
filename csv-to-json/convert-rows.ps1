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

function New-ConvertedObject([psObject]$Row, [string[]]$List, [string]$Path) {
    if ($Row.$Path) {
        return Convert-DataType -Value $Row.$Path -Path $Path
    }
    $BaseHeaders = $List | ForEach-Object { ($_ -Split "/")[0] } | Select-Object -Unique
    if ($BaseHeaders -Match "^\d+$") {
        $ArrayObject = [System.Collections.ArrayList]::new()
        $isArray = $true
    }
    else {
        $Object = New-Object psobject
        $isArray = $false
    }
    Foreach ($BaseHeader in $BaseHeaders) {
        if ($Path) {
            $NewPath = "$Path/$BaseHeader"
        }
        else {
            $NewPath = $BaseHeader
        }
        if ($BaseHeader -eq "hints") {
            $Stop|Out-Null
        }
        $SubHeaders = @($List | Where-Object { $_ -Like "$BaseHeader/*" }) -Replace "^$BaseHeader/", ""
        $Value = New-ConvertedObject -Row $Row -List $SubHeaders -Path $NewPath
        if ($isArray) {
            $ArrayObject.Add($Value) | Out-Null
            if (($SubHeaders | ForEach-Object { ($_ -Split "/")[0] }) -Match "^\d+$") {
                $ArrayObject[-1] = [System.Collections.ArrayList]@($ArrayObject[-1])
            }
        }
        else {
            Add-Member -InputObject $Object -MemberType NoteProperty -Name $BaseHeader -Value $Value
            if (($SubHeaders | ForEach-Object { ($_ -Split "/")[0] }) -Match "^\d+$") {
                $Object.$BaseHeader = [System.Collections.ArrayList]@($Object.$BaseHeader)
            }
        }
    }
    if ($isArray) {
        return $ArrayObject
    }
    else {
        return $Object
    }
}

$Progress = 0

$Objects = [System.Collections.ArrayList]::New()

Foreach ($Row in $ObjectBlock) {
    $Headers = $Row.psObject.Properties.Name | Where-Object { "" -ne $Row.$_ }
    $Object = New-ConvertedObject -Row $Row -List $Headers -Path ""
    $Objects.add($Object) | Out-Null
    $Progress++
    if (-not $SuppressProgress) {
        Write-Progress -Activity "Step 2 of 3: Converting rows..." -Status "$Progress of $($ObjectBlock.Count) rows" -PercentComplete ($Progress / $($ObjectBlock.Count * 100))
    }
}
    
$Objects