# edwards.hello

A trivial gameplay-only [OpenAC](https://github.com/eriknihlen/OpenAC) plugin. It exists to
prove the launcher's plugin-install path end to end (listed in `shaneedwards/openac-plugins`). On
`Enable()` it writes one key, `last-enabled-at`, through the plugin host's storage API and logs
one line. It does nothing else.

**Host:** both, declared as `"hosts": ["graphical", "headless"]` (the launcher requires `hosts`). Headless has no plugin storage, so there it logs a warning and writes nothing.
Loading on both hosts lets a launcher test check that a headless character with a blank plugin
list loads nothing.

## Building

This plugin references OpenAC's `AcDream.Plugin.Abstractions` as a plain assembly `Reference`
to a local copy of the built DLL at `src/Edwards.Hello/lib/AcDream.Plugin.Abstractions.dll`
(`Private=false`, so it is not copied into this plugin's own output — the host supplies its own
copy at load time). That DLL is a scratch copy taken from a local OpenAC checkout's built client
payload (`bin/payload/client-osx-arm64/AcDream.Plugin.Abstractions.dll`); this repo's build never
references or builds inside an OpenAC checkout directly. To refresh it against a newer OpenAC
release, copy the new `AcDream.Plugin.Abstractions.dll` over the one in `lib/`.

```sh
dotnet build src/Edwards.Hello/Edwards.Hello.csproj -c Release
```

## Cutting a release

`plugin.json` at the project root is checked in as a template: every field is final except
`version`, which is never typed a second time anywhere else in this repo. `package.sh` is the
single place a release version is supplied:

```sh
./package.sh 0.1.0
```

This builds Release and writes exactly three files to `dist/v0.1.0/`:

- `plugin.json` — the template with `version` set to `0.1.0`; byte-identical to the copy at the
  zip root
- `edwards.hello-0.1.0.zip` — `plugin.json` at the zip root plus `Edwards.Hello.dll` (and its
  `.pdb`, if present); nothing else, no `runtimes/` folder, every file extension on the release
  contract's allowlist, no executable bits
- `edwards.hello-0.1.0.zip.sha256` — `shasum -a 256` output for the zip

The script verifies its own output before exiting: the allowlist, the zip-root layout, that the
dist and zip-root `plugin.json` are byte-identical, that the hash file matches, and that nothing
extracted from the zip is executable.

To publish a release:

1. Run `./package.sh <version>` for the version being released.
2. Tag `v<version>` (for example `v0.1.0`) and push the tag.
3. Create a GitHub release on that tag, **not** a draft or a prerelease, and attach the three
   files from `dist/v<version>/` as release assets, unchanged.
4. Make sure GitHub marks this release *latest* — it must be the highest version, since the
   launcher refuses downgrades.

See `plan-launcher-plugins.md` § The shared contract for the full release contract this follows.
