param(
    [string]$InputPath = (Join-Path $PSScriptRoot '..\..\wage (1).xlsx'),
    [string]$OutputDir = (Join-Path $PSScriptRoot '..\data\processed'),
    [string]$ReportDir = (Join-Path $PSScriptRoot '..\reports')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Culture = [System.Globalization.CultureInfo]::InvariantCulture

function Test-Missing {
    param([object]$Value)
    return ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value))
}

function Convert-ToNullableDouble {
    param([object]$Value)
    if (Test-Missing $Value) {
        return $null
    }

    $parsed = 0.0
    $ok = [double]::TryParse(
        [string]$Value,
        [System.Globalization.NumberStyles]::Any,
        $Culture,
        [ref]$parsed
    )

    if (-not $ok) {
        throw "Cannot parse numeric value '$Value'."
    }

    return $parsed
}

function Format-NullableNumber {
    param([object]$Value)
    if ($null -eq $Value) {
        return ''
    }
    return ([double]$Value).ToString('G17', $Culture)
}

function Get-CellValue {
    param(
        [pscustomobject]$Row,
        [string]$Column
    )

    $property = $Row.PSObject.Properties[$Column]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Get-ColIndex {
    param([string]$CellReference)

    $letters = ([regex]::Match($CellReference, '^[A-Z]+')).Value
    $index = 0
    foreach ($ch in $letters.ToCharArray()) {
        $index = ($index * 26) + ([int][char]$ch - [int][char]'A' + 1)
    }
    return $index
}

function Read-XlsxFirstSheet {
    param([string]$Path)

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $sharedStrings = @()
        $sharedEntry = $zip.GetEntry('xl/sharedStrings.xml')
        if ($null -ne $sharedEntry) {
            $reader = New-Object System.IO.StreamReader($sharedEntry.Open())
            [xml]$sharedXml = $reader.ReadToEnd()
            $reader.Close()

            $sharedNs = New-Object System.Xml.XmlNamespaceManager($sharedXml.NameTable)
            $sharedNs.AddNamespace('a', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')

            foreach ($item in $sharedXml.SelectNodes('//a:si', $sharedNs)) {
                $textParts = $item.SelectNodes('.//a:t', $sharedNs) | ForEach-Object { $_.'#text' }
                $sharedStrings += ($textParts -join '')
            }
        }

        $sheetEntry = $zip.GetEntry('xl/worksheets/sheet1.xml')
        if ($null -eq $sheetEntry) {
            throw 'Cannot find xl/worksheets/sheet1.xml in workbook.'
        }

        $reader = New-Object System.IO.StreamReader($sheetEntry.Open())
        [xml]$sheetXml = $reader.ReadToEnd()
        $reader.Close()

        $sheetNs = New-Object System.Xml.XmlNamespaceManager($sheetXml.NameTable)
        $sheetNs.AddNamespace('a', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main')

        $rows = New-Object System.Collections.Generic.List[object]
        foreach ($row in $sheetXml.SelectNodes('//a:sheetData/a:row', $sheetNs)) {
            $cellMap = @{}
            $maxIndex = 0

            foreach ($cell in $row.SelectNodes('a:c', $sheetNs)) {
                $cellReference = $cell.GetAttribute('r')
                $cellType = $cell.GetAttribute('t')
                $cellIndex = Get-ColIndex $cellReference
                if ($cellIndex -gt $maxIndex) {
                    $maxIndex = $cellIndex
                }

                $valueNode = $cell.SelectSingleNode('a:v', $sheetNs)
                $value = if ($null -ne $valueNode) { $valueNode.InnerText } else { '' }

                if ($cellType -eq 's' -and -not (Test-Missing $value)) {
                    $value = $sharedStrings[[int]$value]
                }
                elseif ($cellType -eq 'inlineStr') {
                    $textNode = $cell.SelectSingleNode('.//a:t', $sheetNs)
                    $value = if ($null -ne $textNode) { $textNode.InnerText } else { '' }
                }

                $cellMap[$cellIndex] = $value
            }

            $rowValues = New-Object string[] $maxIndex
            for ($i = 1; $i -le $maxIndex; $i++) {
                $rowValues[$i - 1] = if ($cellMap.ContainsKey($i)) { [string]$cellMap[$i] } else { '' }
            }

            $rows.Add($rowValues) | Out-Null
        }

        if ($rows.Count -lt 2) {
            throw 'Workbook has no data rows.'
        }

        $headers = $rows[0]
        $records = New-Object System.Collections.Generic.List[object]
        for ($r = 1; $r -lt $rows.Count; $r++) {
            $record = [ordered]@{}
            for ($c = 0; $c -lt $headers.Length; $c++) {
                $value = if ($c -lt $rows[$r].Length) { $rows[$r][$c] } else { '' }
                $record[$headers[$c]] = $value
            }
            $records.Add([pscustomobject]$record) | Out-Null
        }

        return [pscustomobject][ordered]@{
            Headers = $headers
            Records = $records.ToArray()
        }
    }
    finally {
        $zip.Dispose()
    }
}

function Get-NonMissingNumbers {
    param(
        [object[]]$Rows,
        [string]$Column
    )

    $values = New-Object System.Collections.Generic.List[double]
    foreach ($row in $Rows) {
        $value = Convert-ToNullableDouble (Get-CellValue $row $Column)
        if ($null -ne $value) {
            $values.Add($value) | Out-Null
        }
    }
    return $values.ToArray()
}

function Get-Median {
    param([double[]]$Values)

    if ($Values.Count -eq 0) {
        return $null
    }

    $sorted = $Values.Clone()
    [Array]::Sort($sorted)
    $middle = [int][Math]::Floor($sorted.Count / 2)

    if (($sorted.Count % 2) -eq 1) {
        return $sorted[$middle]
    }

    return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Get-Mode {
    param([double[]]$Values)

    if ($Values.Count -eq 0) {
        return $null
    }

    $groups = $Values |
        ForEach-Object { [int]$_ } |
        Group-Object |
        Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = { [int]$_.Name }; Ascending = $true }

    return [int]$groups[0].Name
}

function Get-Quantile {
    param(
        [double[]]$Values,
        [double]$P
    )

    if ($Values.Count -eq 0) {
        return $null
    }

    $sorted = $Values.Clone()
    [Array]::Sort($sorted)
    $index = [int][Math]::Floor(($sorted.Count - 1) * $P)
    return $sorted[$index]
}

function Export-CsvUtf8 {
    param(
        [object[]]$Rows,
        [string]$Path
    )

    $Rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

$resolvedInput = (Resolve-Path $InputPath).Path
New-Item -ItemType Directory -Force $OutputDir, $ReportDir | Out-Null
$OutputDir = (Resolve-Path $OutputDir).Path
$ReportDir = (Resolve-Path $ReportDir).Path

$workbook = Read-XlsxFirstSheet $resolvedInput
$headers = $workbook.Headers
$rows = @($workbook.Records)
$rowCount = $rows.Count

$edaColumns = @(
    'lwage', 'wage',
    'educ', 'exper', 'expersq', 'IQ', 'KWW',
    'black', 'married', 'south', 'smsa',
    'fatheduc', 'motheduc',
    'nearc2', 'nearc4',
    'momdad14', 'sinmom14', 'step14',
    'south66', 'smsa66', 'libcrd14',
    'reg661', 'reg662', 'reg663', 'reg664', 'reg665', 'reg666', 'reg667', 'reg668', 'reg669'
)

$missingSummary = New-Object System.Collections.Generic.List[object]
foreach ($column in $edaColumns) {
    $missingCount = 0
    foreach ($row in $rows) {
        if (Test-Missing (Get-CellValue $row $column)) {
            $missingCount++
        }
    }

    $method = 'none'
    if ($column -in @('IQ', 'KWW', 'fatheduc', 'motheduc')) {
        $method = 'median for model dataset'
    }
    elseif ($column -in @('married', 'libcrd14')) {
        $method = 'mode for model dataset'
    }

    $missingSummary.Add([pscustomobject][ordered]@{
        variable = $column
        missing_count = $missingCount
        missing_pct = ([Math]::Round(100.0 * $missingCount / $rowCount, 2)).ToString('0.##', $Culture)
        treatment = $method
        impute_value = ''
    }) | Out-Null
}

$medianImputeColumns = @('IQ', 'KWW', 'fatheduc', 'motheduc')
$modeImputeColumns = @('married', 'libcrd14')
$imputeValues = @{}

foreach ($column in $medianImputeColumns) {
    $imputeValues[$column] = Get-Median (Get-NonMissingNumbers $rows $column)
}

foreach ($column in $modeImputeColumns) {
    $imputeValues[$column] = Get-Mode (Get-NonMissingNumbers $rows $column)
}

foreach ($item in $missingSummary) {
    if ($imputeValues.ContainsKey($item.variable)) {
        $item.impute_value = Format-NullableNumber $imputeValues[$item.variable]
    }
}

$edaRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $rows) {
    $out = [ordered]@{}
    foreach ($column in $edaColumns) {
        $out[$column] = Format-NullableNumber (Convert-ToNullableDouble (Get-CellValue $row $column))
    }
    $edaRows.Add([pscustomobject]$out) | Out-Null
}

$binaryColumns = @(
    'black', 'south', 'smsa',
    'nearc2', 'nearc4',
    'momdad14', 'sinmom14', 'step14',
    'south66', 'smsa66', 'libcrd14',
    'reg662', 'reg663', 'reg664', 'reg665', 'reg666', 'reg667', 'reg668', 'reg669'
)

$continuousColumns = @('educ', 'exper', 'expersq', 'IQ', 'KWW', 'fatheduc', 'motheduc')
$missingFlagColumns = @('IQ', 'KWW', 'fatheduc', 'motheduc', 'married', 'libcrd14')

$marriedValues = Get-NonMissingNumbers $rows 'married' |
    ForEach-Object { [int]$_ } |
    Sort-Object -Unique
$marriedBaseline = $marriedValues[0]
$marriedDummyValues = @($marriedValues | Where-Object { $_ -ne $marriedBaseline })

$modelRows = New-Object System.Collections.Generic.List[object]
foreach ($row in $rows) {
    $target = Convert-ToNullableDouble (Get-CellValue $row 'lwage')
    if ($null -eq $target) {
        continue
    }

    $out = [ordered]@{
        lwage = Format-NullableNumber $target
    }

    foreach ($column in $continuousColumns) {
        $rawValue = Get-CellValue $row $column
        $value = Convert-ToNullableDouble $rawValue
        if ($null -eq $value -and $imputeValues.ContainsKey($column)) {
            $value = $imputeValues[$column]
        }
        $out[$column] = Format-NullableNumber $value
    }

    foreach ($column in $binaryColumns) {
        $rawValue = Get-CellValue $row $column
        $value = Convert-ToNullableDouble $rawValue
        if ($null -eq $value -and $imputeValues.ContainsKey($column)) {
            $value = $imputeValues[$column]
        }
        $out[$column] = Format-NullableNumber $value
    }

    $marriedRaw = Get-CellValue $row 'married'
    $marriedValue = Convert-ToNullableDouble $marriedRaw
    if ($null -eq $marriedValue) {
        $marriedValue = $imputeValues['married']
    }
    $marriedCode = [int]$marriedValue

    foreach ($code in $marriedDummyValues) {
        $out["married_$code"] = if ($marriedCode -eq $code) { '1' } else { '0' }
    }

    foreach ($column in $missingFlagColumns) {
        $out["${column}_missing"] = if (Test-Missing (Get-CellValue $row $column)) { '1' } else { '0' }
    }

    $modelRows.Add([pscustomobject]$out) | Out-Null
}

$outlierColumns = @('wage', 'lwage', 'educ', 'exper', 'IQ', 'KWW')
$outlierSummary = New-Object System.Collections.Generic.List[object]
foreach ($column in $outlierColumns) {
    $values = Get-NonMissingNumbers $rows $column
    $q1 = Get-Quantile $values 0.25
    $q3 = Get-Quantile $values 0.75
    $iqr = $q3 - $q1
    $lower = $q1 - (1.5 * $iqr)
    $upper = $q3 + (1.5 * $iqr)
    $outlierCount = 0

    foreach ($value in $values) {
        if ($value -lt $lower -or $value -gt $upper) {
            $outlierCount++
        }
    }

    $outlierSummary.Add([pscustomobject][ordered]@{
        variable = $column
        n = $values.Count
        q1 = Format-NullableNumber $q1
        q3 = Format-NullableNumber $q3
        iqr = Format-NullableNumber $iqr
        lower_bound = Format-NullableNumber $lower
        upper_bound = Format-NullableNumber $upper
        outlier_count = $outlierCount
        outlier_pct = ([Math]::Round(100.0 * $outlierCount / $values.Count, 2)).ToString('0.##', $Culture)
    }) | Out-Null
}

$lwageDiffs = New-Object System.Collections.Generic.List[double]
$expersqMismatchCount = 0
foreach ($row in $rows) {
    $wage = Convert-ToNullableDouble (Get-CellValue $row 'wage')
    $lwage = Convert-ToNullableDouble (Get-CellValue $row 'lwage')
    if ($null -ne $wage -and $null -ne $lwage -and $wage -gt 0) {
        $lwageDiffs.Add([Math]::Abs($lwage - [Math]::Log($wage))) | Out-Null
    }

    $exper = Convert-ToNullableDouble (Get-CellValue $row 'exper')
    $expersq = Convert-ToNullableDouble (Get-CellValue $row 'expersq')
    if ($null -ne $exper -and $null -ne $expersq) {
        if ([Math]::Abs($expersq - ($exper * $exper)) -gt 0.0000001) {
            $expersqMismatchCount++
        }
    }
}

$maxLwageDiff = if ($lwageDiffs.Count -gt 0) { ($lwageDiffs | Measure-Object -Maximum).Maximum } else { $null }
$meanLwageDiff = if ($lwageDiffs.Count -gt 0) { ($lwageDiffs | Measure-Object -Average).Average } else { $null }

$variableRoles = @(
    [pscustomobject]@{ variable = 'lwage'; role = 'target'; action = 'keep'; note = 'Main regression target.' },
    [pscustomobject]@{ variable = 'wage'; role = 'raw target source'; action = 'EDA only'; note = 'Do not use as predictor for lwage.' },
    [pscustomobject]@{ variable = 'id'; role = 'identifier'; action = 'drop'; note = 'No statistical meaning.' },
    [pscustomobject]@{ variable = 'educ, exper, expersq, IQ, KWW, fatheduc, motheduc'; role = 'numeric predictors'; action = 'keep'; note = 'Median imputation for missing IQ, KWW, fatheduc, motheduc in model data.' },
    [pscustomobject]@{ variable = 'black, south, smsa, nearc2, nearc4, family and region dummies'; role = 'binary predictors'; action = 'keep'; note = 'reg661 omitted from model data as region baseline.' },
    [pscustomobject]@{ variable = 'married'; role = 'categorical predictor'; action = 'one-hot encode'; note = "Baseline category is married_$marriedBaseline omitted." },
    [pscustomobject]@{ variable = 'enroll, age, weight'; role = 'not used in Project 1 model file'; action = 'drop from prepared files'; note = 'Can be revisited if the research question changes.' }
)

$edaPath = Join-Path $OutputDir 'wage_eda.csv'
$modelPath = Join-Path $OutputDir 'wage_model.csv'
$missingPath = Join-Path $ReportDir 'missing_values.csv'
$outlierPath = Join-Path $ReportDir 'outliers_iqr.csv'
$rolesPath = Join-Path $ReportDir 'variable_roles.csv'
$summaryPath = Join-Path $ReportDir 'data_cleaning_summary.md'

Export-CsvUtf8 $edaRows.ToArray() $edaPath
Export-CsvUtf8 $modelRows.ToArray() $modelPath
Export-CsvUtf8 $missingSummary.ToArray() $missingPath
Export-CsvUtf8 $outlierSummary.ToArray() $outlierPath
Export-CsvUtf8 $variableRoles $rolesPath

$missingHighlights = $missingSummary |
    Where-Object { $_.missing_count -gt 0 } |
    Sort-Object @{ Expression = 'missing_count'; Descending = $true }

$outlierHighlights = $outlierSummary |
    Sort-Object @{ Expression = 'outlier_count'; Descending = $true }

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add('# Data cleaning summary - Project 1') | Out-Null
$summaryLines.Add('') | Out-Null
$summaryLines.Add("Input file: $resolvedInput") | Out-Null
$summaryLines.Add("Raw shape: $rowCount rows x $($headers.Count) columns") | Out-Null
$summaryLines.Add("EDA output: $edaPath") | Out-Null
$summaryLines.Add("Model output: $modelPath") | Out-Null
$summaryLines.Add('') | Out-Null
$summaryLines.Add('## Cleaning decisions') | Out-Null
$summaryLines.Add('- Dropped id from prepared datasets because it is only an identifier.') | Out-Null
$summaryLines.Add('- Kept wage only in the EDA dataset; it must not be used as a predictor for lwage.') | Out-Null
$summaryLines.Add('- Kept missing values in the EDA dataset so descriptive statistics can report valid n by variable.') | Out-Null
$summaryLines.Add('- Filled IQ, KWW, fatheduc, and motheduc with medians in the model dataset.') | Out-Null
$summaryLines.Add('- Filled married and libcrd14 with modes in the model dataset.') | Out-Null
$summaryLines.Add('- Added missing-value indicators for imputed variables.') | Out-Null
$summaryLines.Add('- One-hot encoded married and omitted the first observed category as baseline.') | Out-Null
$summaryLines.Add('- Dropped reg661 from the model dataset as the region baseline to reduce dummy-variable collinearity.') | Out-Null
$summaryLines.Add('- Did not delete IQR outliers; they are reported for review before statistical analysis.') | Out-Null
$summaryLines.Add('') | Out-Null
$summaryLines.Add('## Missing values') | Out-Null
foreach ($item in $missingHighlights) {
    $line = "- $($item.variable): $($item.missing_count) missing ($($item.missing_pct)%); treatment: $($item.treatment)"
    if (-not [string]::IsNullOrWhiteSpace($item.impute_value)) {
        $line += "; impute value: $($item.impute_value)"
    }
    $summaryLines.Add($line) | Out-Null
}
$summaryLines.Add('') | Out-Null
$summaryLines.Add('## Consistency checks') | Out-Null
$summaryLines.Add("- max abs(lwage - log(wage)): $(Format-NullableNumber $maxLwageDiff)") | Out-Null
$summaryLines.Add("- mean abs(lwage - log(wage)): $(Format-NullableNumber $meanLwageDiff)") | Out-Null
$summaryLines.Add("- expersq != exper^2 rows: $expersqMismatchCount") | Out-Null
$summaryLines.Add('') | Out-Null
$summaryLines.Add('## IQR outlier review') | Out-Null
foreach ($item in $outlierHighlights) {
    $summaryLines.Add("- $($item.variable): $($item.outlier_count) outliers ($($item.outlier_pct)%)") | Out-Null
}
$summaryLines.Add('') | Out-Null
$summaryLines.Add('## Output files') | Out-Null
$summaryLines.Add("- data/processed/wage_eda.csv: selected variables for descriptive statistics and visualization.") | Out-Null
$summaryLines.Add("- data/processed/wage_model.csv: numeric modeling table with imputation, missing flags, one-hot married dummies, and no wage leakage.") | Out-Null
$summaryLines.Add("- reports/missing_values.csv: missing-value counts and treatment.") | Out-Null
$summaryLines.Add("- reports/outliers_iqr.csv: IQR outlier bounds and counts.") | Out-Null
$summaryLines.Add("- reports/variable_roles.csv: variable roles and cleaning actions.") | Out-Null

[System.IO.File]::WriteAllLines($summaryPath, $summaryLines.ToArray(), [System.Text.Encoding]::UTF8)

Write-Output "Wrote $edaPath"
Write-Output "Wrote $modelPath"
Write-Output "Wrote $missingPath"
Write-Output "Wrote $outlierPath"
Write-Output "Wrote $rolesPath"
Write-Output "Wrote $summaryPath"
