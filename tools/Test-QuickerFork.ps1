$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$artifacts=Join-Path $root 'artifacts/quicker-validation'
foreach($name in @('QRCoder','QRCoder.Xaml')){
    $tfm=if($name -eq 'QRCoder'){'net10.0'}else{'net6.0-windows'}
    $paths=@{}
    foreach($platform in @('x64','ARM64')){
        $json=& dotnet msbuild "$root/$name/$name.csproj" -nologo "-p:TargetFramework=$tfm" "-p:Platform=$platform" -p:UseArtifactsOutput=true "-p:ArtifactsPath=$artifacts" '-getProperty:PlatformTarget,OutputPath,IntermediateOutputPath'
        if($LASTEXITCODE -ne 0){throw 'Property evaluation failed'}
        $value=($json | ConvertFrom-Json).Properties
        if($value.PlatformTarget -ne 'AnyCPU'){throw 'Library must remain AnyCPU'}
        $paths[$platform]=$value
    }
    foreach($property in @('OutputPath','IntermediateOutputPath')){
        if($paths.x64.$property -eq $paths.ARM64.$property){throw 'Architectures share build paths'}
    }
}
# The fork's Xaml/test-project TFMs predate its core library TFMs; do not claim that legacy matrix.
foreach($platform in @('x64','ARM64')){
    & dotnet build "$root/QRCoder/QRCoder.csproj" -c Release -f net10.0 "-p:Platform=$platform" --artifacts-path $artifacts -p:ManagePackageVersionsCentrally=false
    if($LASTEXITCODE -ne 0){throw "$platform core library build failed"}
}
& dotnet run --project "$root/tools/QuickerSmoke/QuickerSmoke.csproj" -c Release --artifacts-path $artifacts -p:ManagePackageVersionsCentrally=false
if($LASTEXITCODE -ne 0){throw 'QR PNG smoke failed'}
