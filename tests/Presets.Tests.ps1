# Holds the presets to what the README says they do, against the Renovate that is current today.
#
#   Invoke-Pester ./tests
#
# It needs Node.js and the network: it installs Renovate into a temporary folder, unless
# RENOVATE_HOME names a folder that already has it, and it asks the PowerShell Gallery which
# versions exist. It needs no token, and it writes nothing outside the temporary folder.
#
# Renovate runs here as it does for a repository, only without opening anything
# (--platform=local): it reads tests/fixture as if that were a repository extending both presets,
# and the tests read what it would have proposed.

BeforeAll {
    $root = Split-Path $PSScriptRoot -Parent
    $work = Join-Path ([IO.Path]::GetTempPath()) "renovate-presets-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory $work | Out-Null

    $renovateHome = $env:RENOVATE_HOME
    if (-not $renovateHome) {
        $renovateHome = Join-Path $work 'renovate'
        New-Item -ItemType Directory $renovateHome | Out-Null
        Set-Content (Join-Path $renovateHome 'package.json') '{ "name": "renovate-presets-check", "private": true }'
        Push-Location $renovateHome
        try {
            npm install renovate --no-audit --no-fund --loglevel=error | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "npm install renovate ended with $LASTEXITCODE." }
        }
        finally { Pop-Location }
    }
    $suffix = if ($IsWindows) { '.cmd' } else { '' }
    $validator = Join-Path $renovateHome "node_modules/.bin/renovate-config-validator$suffix"
    $renovate = Join-Path $renovateHome "node_modules/.bin/renovate$suffix"

    # A repository that extends both presets. 'extends' reads a preset from its host, which would
    # test what is published and not what is here, so the two are put together by hand: the
    # custom manager of the first, and the package rules of both, in the order 'extends' gives.
    $repository = Join-Path $work 'repository'
    Copy-Item (Join-Path $PSScriptRoot 'fixture') $repository -Recurse
    $config = Get-Content (Join-Path $root 'renovate-preset.json') -Raw | ConvertFrom-Json -AsHashtable
    $managed = Get-Content (Join-Path $root 'renovate-managed-workflows.json') -Raw | ConvertFrom-Json -AsHashtable
    $config.packageRules = @($config.packageRules) + @($managed.packageRules)
    $config | ConvertTo-Json -Depth 20 | Set-Content (Join-Path $repository 'renovate.json')

    # Renovate lists a repository's files with git, so the fixture has to be one.
    git -C $repository -c init.defaultBranch=main init --quiet
    git -C $repository add --all 2>$null
    git -C $repository -c user.name=fixture -c user.email=fixture@example.invalid commit --quiet --message fixture

    # Without a token Renovate skips every action before it applies a rule to it, and the rule is
    # what is tested here. With the warning off it applies the rules first.
    $before = @{}
    $settings = @{ LOG_LEVEL = 'debug'; LOG_FORMAT = 'json'; RENOVATE_GITHUB_TOKEN_WARN = 'false' }
    foreach ($name in $settings.Keys) {
        $before[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $settings[$name])
    }
    Push-Location $repository
    try {
        $log = & $renovate --platform=local 2>&1
        $renovateExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
        foreach ($name in $before.Keys) { [Environment]::SetEnvironmentVariable($name, $before[$name]) }
    }

    $found = foreach ($line in $log) {
        if ("$line" -notmatch '^\{') { continue }
        $entry = "$line" | ConvertFrom-Json -Depth 40
        if ($entry.msg -ne 'packageFiles with updates') { continue }
        foreach ($manager in $entry.config.PSObject.Properties) {
            foreach ($file in $manager.Value) {
                foreach ($dependency in $file.deps) {
                    [pscustomobject]@{
                        Manager    = $manager.Name
                        File       = $file.packageFile
                        Name       = $dependency.depName
                        Current    = $dependency.currentValue
                        SkipReason = $dependency.skipReason
                        Updates    = @($dependency.updates)
                    }
                }
            }
        }
    }
    $found = @($found)
    $modules = @($found | Where-Object Manager -EQ 'regex')
    $actions = @($found | Where-Object { $_.Manager -eq 'github-actions' -and $_.Name -eq 'actions/checkout' })
    $ownPullRequest = 'renovate/the-code-kitchen-modules'
}

AfterAll {
    if ($work -and (Test-Path $work)) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'The presets' {
    It 'is written with the option names Renovate uses today: <_>' -ForEach 'renovate-preset.json', 'renovate-managed-workflows.json' {
        # --strict fails on a name Renovate has renamed, which it would otherwise migrate quietly.
        $output = & $validator --strict (Join-Path $root $_) 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output -join "`n")
    }

    It 'can be read by Renovate as a repository would read it' {
        $renovateExit | Should -Be 0
        $found | Should -Not -BeNullOrEmpty -Because 'Renovate reported no dependencies at all, so nothing below was tested'
    }

    Context 'RequiredModules in a manifest' {
        It 'proposes the newer release of <name>, written <written>' -ForEach @(
            @{ name = 'PowerCraft.AI'; current = '1.2.0'; written = 'on one line with a minimum version' }
            @{ name = 'PowerCraft.Secrets'; current = '1.0.1'; written = 'in double quotes, with a GUID and an exact version' }
            @{ name = 'CodeCompass.Release'; current = '0.10.0'; written = 'over several lines, version first' }
        ) {
            $module = $modules | Where-Object Name -EQ $name
            $module | Should -Not -BeNullOrEmpty -Because "the manifest requires $name"
            $module.Current | Should -Be $current
            # NuGet reads 1.2.0 as "1.2.0 or later". Read that way, every newer release already
            # satisfies the manifest and nothing is ever proposed: the preset did that until
            # 2026-11-18.
            $module.Updates | Should -Not -BeNullOrEmpty -Because "the gallery has a release of $name after $current"
        }

        It 'puts the releases of our own modules in one pull request' {
            $ours = $modules | Where-Object Name -Match '^(PowerCraft|CodeCompass)\.'
            $branches = $ours.Updates | Where-Object updateType -NE 'major' | ForEach-Object branchName
            $branches | Sort-Object -Unique | Should -Be $ownPullRequest
        }

        It 'reads a module that is not ours, and keeps it out of that pull request' {
            $module = $modules | Where-Object Name -EQ 'Pester'
            $module.Updates | Should -Not -BeNullOrEmpty
            $module.Updates.branchName | Should -Not -Contain $ownPullRequest
        }

        It "does not take the manifest's own version for a requirement" {
            $modules.Current | Should -Not -Contain '9.9.9'
        }

        It 'finds the four entries that name a version, and not the one that does not' {
            $modules.Name | Sort-Object | Should -Be 'CodeCompass.Release', 'Pester', 'PowerCraft.AI', 'PowerCraft.Secrets'
        }
    }

    Context 'Workflow files written by CodeCompass' {
        It 'leaves the actions alone in <_>' -ForEach 'ci.yml', 'release.yml', 'dependency-check.yml', 'workflow-freshness.yml' {
            $action = $actions | Where-Object File -EQ ".github/workflows/$_"
            $action | Should -Not -BeNullOrEmpty -Because 'the fixture uses an action in that file'
            $action.SkipReason | Should -Be 'disabled'
        }

        It 'still reads a workflow the repository wrote itself' {
            $action = $actions | Where-Object File -EQ '.github/workflows/own.yml'
            $action | Should -Not -BeNullOrEmpty
            $action.SkipReason | Should -Not -Be 'disabled'
        }
    }
}
