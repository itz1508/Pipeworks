function Get-Ami
{
    <#
    .Synopsis
        Gets Amazon Machine Images
    .Description
        Gets the available Amazon Machine Images
    .Example
        Get-Ami
    .Link
        Add-EC2
    
    #>
    [CmdletBinding(DefaultParameterSetName='Keyword')]
    [OutputType([PSObject])]
    param(
    # The exact name of the AMI image
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='Name')]
    [string]$Name,
    # A keyword to look for in AMI images
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='Keyword')]
    [string]$Keyword,
    
    # If set, gets all available AMIs
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='All')]
    [Switch]$All
    )
    
    process {
            if (-not $script:CachedImageData) {
                $script:CachedImageData = $AwsConnections.EC2.DescribeImages((New-Object Amazon.EC2.Model.DescribeImagesRequest)).DescribeImagesResult.Image
            }
            $script:CachedImageData | 
                Where-Object {
                    if ($Name) {
                        $_.Name -eq $name
                    } elseif ($Keyword) {
                        $_.Name -like "*$keyword*" -or $_.Description -like "*$Keyword*"
                    } else {
                        $true
                    }
                } | 
                Sort-Object Platform -Descending
        
    }
} 
 
