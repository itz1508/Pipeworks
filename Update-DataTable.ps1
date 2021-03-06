function Update-DataTable {
    <#
    .Synopsis
        Updates a datatable
    .Description
        Updates data within a datatable, or adds new rows
    .Link
        New-DataTable
    .Example
        $dt = New-DataTable -ColumnName Name, Age -ColumnType [string], [int] -KeyColumn Name
        New-Object PSObject -Property @{
            Name = "James"
            Age = 32
        } |
            Update-Datatable $dt
    #>
    [OutputType([Data.DataRow], [Nullable])]
    param(
    # The data to add to the data table
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [PSObject[]]
    $InputObject,

    # The datatable that will be updated
    [Parameter(Mandatory=$true,Position=0)]
    [Data.DataTable]
    $DataTable,

    # If set, will return the row added to the datatable
    [Switch]
    $PassThru,

    # If set, will add columns to the table if they are not found
    [Switch]
    $Force,

    # If set, will merge the found in a new record into the row.  If not set, the row will be deleted and re-added.
    [Switch]
    $Merge
    )
    
    begin {
        #region Define Simple Type Lookup Table
        $simpleTypes = ('System.Boolean', 'System.Byte[]', 'System.Byte', 'System.Char', 'System.Datetime', 'System.Decimal', 'System.Double', 'System.Guid', 'System.Int16', 'System.Int32', 'System.Int64', 'System.Single', 'System.UInt16', 'System.UInt32', 'System.UInt64')

        $SimpletypeLookup = @{}
        foreach ($s in $simpleTypes) {
            $SimpletypeLookup[$s] = $s
        }        
        #endregion Define Simple Type Lookup Table
    }

    process {
        foreach ($In in $InputObject) { 
            $DataRow = $DataTable.NewRow()   
            $isDataRow = $in.psobject.TypeNames -like "*.DataRow*" -as [bool]

            
            
            
            foreach($property in $In.PsObject.properties) {   
                if ($isDataRow -and 
                    'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors' -contains $property.Name) {
                    continue     
                }
                $propName = $property.Name
                $propValue = $property.Value
                $IsSimpleType = $SimpletypeLookup.ContainsKey($property.TypeNameOfValue)

                
                if (-not $DataTable.Columns.Contains($propName)) {   
                    if ($Force) {
                        $DataTable.Columns.Add((
                            New-Object Data.DataColumn -Property @{
                                ColumnName = $propName
                                DataType = if ($issimpleType) {
                                    $property.TypeNameOfValue
                                } else {
                                    'System.Object'
                                }
                            }
                        ))
                    } else {
                        continue
                    }
                }                   
                
                $DataRow.Item($propName) = if ($isSimpleType -and $propValue) {
                    $propValue
                } elseif ($propValue) {
                    [PSObject]$propValue
                } else {
                    [DBNull]::Value
                }
                
            }   
            if ($DataTable.PrimaryKey) {
                
                $keyColumns = $DataTable.PrimaryKey | Select-Object -ExpandProperty ColumnName

                $otherRow = $DataTable.Rows.Find($DataRow.$keyColumns)
                if ($otherRow -and $Merge) {
                    foreach ($property in $in.psobject.properties) {
                        if ($isDataRow -and 
                            'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors' -contains $property.Name) {
                            continue     
                        }
                        $propName = $property.Name
                        $propValue = $property.Value
                        $IsSimpleType = $SimpletypeLookup.ContainsKey($property.TypeNameOfValue)

                    

                        $otherRow.Item($propName) = if ($isSimpleType -and $propValue) {
                            $propValue
                        } elseif ($propValue) {
                            [PSObject]$propValue
                        } else {
                            [DBNull]::Value
                        }
                    }
                
                } elseif ($otherRow) {
                    $DataTable.Rows.Remove($otherRow)
                    $DataTable.Rows.Add($DataRow) 

                } else {                    
                    $DataTable.Rows.Add($DataRow) 

                }
            } else {
                # No key, just add it to the table
                $DataTable.Rows.Add($DataRow) 
            }
            
            
            if ($PassThru) {
                $DataRow
            }  
        } 
    }
} 
