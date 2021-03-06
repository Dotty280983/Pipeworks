function Use-InterestedSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true,ParameterSetName='ProcessSchematic')]
    [string]$InputDirectory,
    
    [Parameter(Mandatory=$true,ParameterSetName='GetSchematicParameters')]
    [string]$GetSchematicParameter,
    
    [Parameter(Mandatory=$true,ParameterSetName='GetSectionRequirement')]
    [string]$GetSectionRequirement
    )
    
    
    begin {
        $requiredSchematicParameters = @{
            Topic = "A list of http://shouldbeonschema.org/Topic objects"                                
            Mail = "The email address used to send follow-up notifications"
            User = "The user account used to send a follow-up notification"
            PasswordSetting = "The Setting that contains the password"
        }
        
        $optionalSchematicParameters = @{
            "BackgroundColor" = "The background color of the page"
        }
                
    }
    
    process {                             
        # 
        if ($psCmdlet.ParameterSetName -eq 'GetSchematicParameters') {                                    
            if ($IncludeOptional) {
                $requiredSchematicParameters  + $optionalSchematicParameters
            } else {
                $requiredSchematicParameters  
            }            
        }
        
        if ($psCmdlet.ParameterSetName -eq 'GetAllSchematicParameters') {
            return $requiredSchematicParameters                        

        } 
        
        
        
        
        $requiredItems = 
            & $myInvocation.MyCommand -GetSchematicParameter
        
        if ($requiredItems) { 
            foreach ($req in $requiredItems.GetEnumerator()) {
                
                if (-not $parameter.($Req.Key)) {
                    Write-Error "Must include $($req.Key).  $($req.Value)"
                    return
                }
            }    
        }
        
        
        
                     
        if (-not $Parameter.Topic) {
            Write-Error "Must define one or more topics"
            return 
        }
        
        if (-not $manifest.Table) {
            Write-Error "Must have a table to track customer interest"
            return
        }
                               
        
        
    }
} 

 
 
