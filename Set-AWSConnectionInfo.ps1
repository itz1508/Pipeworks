function Set-AWSConnectionInfo
{
    <#
    .Synopsis
        Sets AWS connection info
    .Description
        Sets the Access Key and Secret Access key for Amazon Web Services
    .Example
        Set-AWSConnectionInfo
    .Link
        Add-SecureSetting
    #>
    [OutputType([Nullable])]
    param(
    # The Amazon Web Services Access Key
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$AwsAccessKeyId,
    # The Amazon Web Services Secret Access Key
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonSecretAccessKey
    )
    
    process {
        #Region Add Settings
        Add-SecureSetting -Name AwsAccessKeyId -String $AwsAccessKeyId
        Add-SecureSetting -Name AmazonSecretAccessKey -String $AmazonSecretAccessKey
        #endRegion Add Settings
        
        #region re-import module
        if ($MyInvocation.MyCommand.ScriptBlock.Module.Name ) {
            Import-Module $MyInvocation.MyCommand.ScriptBlock.Module.Name -Force -Global
        }
        #endregion re-import module
    }
} 
