I write content in Excel in column per object format, then transpose to row per object and export to CSV.

Before exports, replace all these characters in Excel:
– => -
’ => '
“ => "
” => "
— =>  - 
(with spaces)

# New Method using Powershell

`csv-to-json.ps1` converts `the named or first` csv file in its input folder into a json file in the output folder and optionally can split the file by an attribute (like _extensionFileName). Empty attributes are deleted automatically. The script always treats certain column as strings to satisfy PECS data structures.
Typical usage: 
```
csv-to-json.ps1 -InFile conditions.csv -Split "type"
```

`json-to-csv.ps1` converts `a named file or ALL` json files in the input folder into `one csv file`.

# Old method:

Convert to JSON on http://convertcsv.com/csv-to-json.htm (site may freeze with big lists),
then open result search & replace the following regex with nothing (VSC may freeze with big lists for the first replaces):

,\n[ ]*(""|null)
\n[ ]*(""|null),
\n[ ]*(""|null)
,\n[ ]*"[_,A-Z,a-z,0-9]*": (""|null|\{\})
\n[ ]*"[_,A-Z,a-z,0-9]*": (""|null|\{\}),
\n[ ]*"[_,A-Z,a-z,0-9]*": (""|null|\{\})
,\n[ ]*\{\n[ ]*\}
\n[ ]*\{\n[ ]*\},
\n[ ]*\{\n[ ]*\}
,\n[ ]*"[_,A-Z,a-z,0-9]*": \{\n[ ]*\}
\n[ ]*"[_,A-Z,a-z,0-9]*": \{\n[ ]*\},
\n[ ]*"[_,A-Z,a-z,0-9]*": \{\n[ ]*\}
,\n[ ]*"[_,A-Z,a-z,0-9]*": \[\n[ ]*\]
\n[ ]*"[_,A-Z,a-z,0-9]*": \[\n[ ]*\],
\n[ ]*"[_,A-Z,a-z,0-9]*": \[\n[ ]*\]

Repeat list until no more results are found.