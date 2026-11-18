# The Code Kitchen: shared configuration

Configuration that repositories share, here and in any organisation that uses our modules.
Today that is two [Renovate](https://docs.renovatebot.com/) presets.

This repository is public so that a repository outside the organisation can read the presets.
The modules' source is not here.

## Keep the modules you depend on up to date

A PowerShell module names the modules it needs in `RequiredModules` of its `.psd1` manifest.
Renovate does not read that on its own. With this preset it does, and it opens a pull request
when the PowerShell Gallery has a newer release than the manifest names.

Add this to `renovate.json` in your repository:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["github>The-Code-Kitchen/.github:renovate-preset"]
}
```

What it does:

- **It reads every entry that names a version**, for any module on the PowerShell Gallery:
  `@{ ModuleName = 'PowerCraft.AI'; ModuleVersion = '1.2.0' }`. `RequiredVersion` is read the
  same way. An entry that is only a name has no version to update and is left alone.
- **It proposes the newer release.** The pull request changes the version in the manifest, so a
  minimum version moves up to the release your tests then run against.
- **Our own modules come in one pull request.** Patch and minor releases of `PowerCraft.*` and
  `CodeCompass.*` are grouped, and merged by Renovate when the checks on the pull request pass.
- **A major release of ours is left for a person.** It gets the label `breaking-change` and is
  not merged for you.
- **Other modules follow your own Renovate configuration.** The preset says nothing about them
  beyond finding them.

The preset adds to your configuration and switches nothing off. To change a rule, add your own
`packageRules` after the `extends` line.

## When CodeCompass writes your workflows

`CodeCompass.Release` writes four workflow files and updates them from its templates. Renovate
would also offer to update the actions in those files, and a file edited that way no longer
matches its template. This preset tells Renovate to leave those four alone:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "github>The-Code-Kitchen/.github:renovate-preset",
    "github>The-Code-Kitchen/.github:renovate-managed-workflows"
  ]
}
```

The four are `ci.yml`, `release.yml`, `dependency-check.yml` and `workflow-freshness.yml` in
`.github/workflows`. A workflow you wrote yourself is not affected.

## If Renovate opens nothing

Renovate has to be installed for the repository and allowed to act.

- **The app installed on "All repositories" starts silent.** The hosted Renovate app then reads
  the repositories and opens no pull request and no issue. Set the repository, or the
  organisation, to Interactive in the [Mend Developer Portal](https://developer.mend.io/). The
  same portal shows the log of every run.
- **A manifest that is already current has nothing to propose.** The log of the run lists each
  module it found and the release it compared with.

## Changing a preset

The tests run Renovate against a small fixture and read what it would propose. They need
Node.js and PowerShell, and no token:

```powershell
Invoke-Pester ./tests
```

They run on every push and pull request here, and every Monday, with the Renovate that is
current that day. Two things are held that way, because both went wrong unnoticed for five
months:

- **Option names.** Renovate renames options between versions and goes on reading the old
  names. The tests fail on a name that needs migrating.
- **That something is proposed.** The first version of the preset looked the versions up as
  NuGet ranges. NuGet reads `1.2.0` as "1.2.0 or later", every newer release satisfies that, and
  so Renovate found each module and never proposed a thing.
