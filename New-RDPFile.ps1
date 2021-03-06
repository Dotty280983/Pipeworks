function New-RDPFile
{
    <#
    .Synopsis
        Creates a new Remote Desktop file
    .Description
        Creates a new Remote Desktop file that can connect with a credential
    .Example
        New-RDPFile -ComputerName MyComputer
    .Link
        ConvertFrom-SecureString
    #>
    [OutputType([string])]
    param(
    # The computername
    [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0)]    
    [Alias('CN')]
    [string]
    $ComputerName,
    
    # The credential.  RDP files created with this credential will only work on this machine
    [Management.Automation.PSCredential]
    $Credential
    )
    
    
    process {
        #region Connection and Screen Settings
        $RdpFileContent = "
full address:s:" + $ComputerName 

        $RdpFileContent += "
screen mode id:i:2
promptcredentialonce:i:1"
    
        #endregion Connection and Screen Settings
        
        
        #region Embed Credential 
        if ($psboundParameters.Credential) {
            $RdpFileContent += "
username:s:" + $credential.Username
            $RdpFileContent += "
password 51:b:" + ($credential.password | ConvertFrom-SecureString)
        }
        #endregion Embed Credential
        if ($RunCommand) {
            $RdpFileContent += "
shell working directory:s:
alternate shell:s:" + $RunCommand

        }
        
    
        $RdpFileContent 
    
    }
} 
