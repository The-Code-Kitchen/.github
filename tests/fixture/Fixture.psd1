# A fixture for tests/Presets.Tests.ps1: the ways a manifest can name a required module.
# It is not a module, and its versions are old on purpose.
@{
    RootModule        = 'Fixture.psm1'
    ModuleVersion     = '9.9.9'
    GUID              = '11111111-1111-1111-1111-111111111111'
    RequiredModules   = @(
        @{ ModuleName = 'PowerCraft.AI'; ModuleVersion = '1.2.0' }
        @{ ModuleName = "PowerCraft.Secrets"; GUID = '22222222-2222-2222-2222-222222222222'; RequiredVersion = "1.0.1" }
        @{
            ModuleVersion = '0.10.0'
            ModuleName    = 'CodeCompass.Release'
        }
        @{ ModuleName = 'Pester'; ModuleVersion = '5.0.0' }
        'Microsoft.PowerShell.Management'
    )
    PrivateData       = @{ PSData = @{ Tags = @('fixture') } }
}
