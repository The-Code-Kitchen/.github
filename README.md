# The Code Kitchen — Org Defaults

Shared configuration for [The Code Kitchen](https://github.com/The-Code-Kitchen) repositories.

## Renovate Preset

Automatically detect and update PowerShell module dependencies (`RequiredModules` in `.psd1` files) sourced from PSGallery.

### For consumers of our modules

Add this to your `renovate.json`:

```json
{
  "extends": ["github>The-Code-Kitchen/.github:renovate-preset"]
}
```

This will:

- Detect version-pinned `RequiredModules` in any `.psd1` file
- Check PSGallery for newer versions
- Auto-merge patch and minor updates (after CI passes)
- Flag major/breaking updates with a `breaking-change` label for manual review

### Supported modules

- `PowerCraft.AI`
- `PowerCraft.Secrets`
- `PowerCraft.Release`
- `CodeCompass.GitHub`
- `CodeCompass.Repo`
- `LeadForge`
