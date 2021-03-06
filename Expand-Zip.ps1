function Expand-Zip
{
    <#
    .Synopsis
        Expands the contents of a Zip file
    .Description
        Expands the contents of a Zip file that was compressed with Out-Zip.
    .Example
        dir $home\Documents\WindowsPowerShell\Modules\Pipeworks -Recurse | 
            Out-Zip -ZipFile $home\Pipeworks.zip        
        Expand-Zip $home\Pipeworks.zip -OutputPath $psHome\Modules\Pipeworks
    .Link
        Out-Zip
    #>
    [OutputType([Nullable])]
    param(
    # The path of the zip file
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname', 'Filename', 'ZipFile')]
    [string]
    $ZipPath,

    # The output directory.  By default, this will be the name of the zip file.
    [string]
    $OutputPath
    )

    begin {
                Add-Type -AssemblyName WindowsBase        

    }
    
    process {
        
        $fullPAth = "$($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ZipPath))"
        $file = Get-Item $fullPAth
        if (-not $fullpath) { return } 
        $package = [IO.Packaging.Package]::Open($fullpath, "Open", "Read")
        if (-not $package) { return } 
        $relationships = $package.GetRelationships()
        $parts = $package.GetParts()
        
        if (-not $outputPath) {
            $OutputPath = Join-Path $pwd $file.Name.Replace(".zip", "")

        }
        
        if (-not (Test-Path $OutputPath)) {
            $null = New-Item -ItemType Directory -path $OutputPath  -Force
        }
        $partCount = @($parts).Count
        $pc = 0
        

        if ($parts.Count -gt 0) {

            $extractedParts = foreach ($p in $parts) {        
            
                $pStream = $p.GetStream("Open", "Read")
                $byteArray = New-Object Byte[] $pStream.Length
                $readCount = $pStream.Read($byteArray, 0, $pStream.Length)
                $file = New-Object PSObject -Property @{
                    Uri = $p.Uri
                    ContentType = $p.ContentType
                    Content = $byteArray
                }

                $outputFileName = Join-Path (Resolve-path $OutputPath) $file.Uri

                $parentDir = $outputFileName | Split-Path 
                if (-not (Test-Path $parentDir)) {
                    $null = New-Item -ItemType Directory -Path $parentDir -Force
                }

            
        
                #$partDict[$p.Uri] = "$strWrite"
                $pStream.Close()            
                $perc = $pc * 100 / $partCount
                $pc++
                Write-Progress "Extracting Files" "$($file.Uri.ToString().Replace("/", "\"))" -PercentComplete $perc
                [IO.File]::WriteAllBytes($outputFileName, $byteArray)
            }
            $package.Close()
            #$openXmlDocument.Parts = $extractedParts
            #$openXmlDocument.Relationships = $relationships
            #New-Object PSObject -Property $openXmlDocument
        
            
        } else {
            $package.Close()
            $tempPath = [IO.path]::GetTempPath()
            $resolvedFile = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($zipPath)
            $tempPath = Join-Path $tempPath "$(Get-Random)_Expand_Zip"
            $newItem = New-ITem -itemType Directory -path $tempPath  -Force
            $psCmd = [Powershell]::Create().AddScript({
            param($path, $zipPath)
                $shell = new-object -com Shell.Application
                $destFolder = $shell.NameSpace("$Path")
                $destFolder.CopyHere(($shell.NameSpace($zipPath).Items()))
            }).AddArgument("$newItem").AddArgument("$resolvedFile")
        
            $psCmd.Invoke()
            $psCmd.Dispose()
        
            Get-ChildItem $tempPath -Recurse -Force |
                Where-Object { -NOT $_.PSISCONTAINER } | 
                ForEach-Object {
                    $source = $_
                    $relativePAth = $_.Fullname.Replace($tempPath, "")
                    $nfPath = Join-Path $OutputPath $RelativePath

                    $nf = New-Item -ItemType File -Path $nfPath  -Force

                    $BYTES = [IO.File]::ReadAllBytes($source.FullName)

                    [IO.FILE]::WriteAllBytes($nf.FullName, $BYTES)

                    Remove-Item -LiteralPath $SOURCE.FullName
                }
              
            Remove-Item $tempPath -Recurse -Force        
          
            #Get-ChildItem $path -Recurse -Force
        }

        

        
        return
                        
    }
    
}
 
