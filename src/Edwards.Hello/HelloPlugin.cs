using AcDream.Plugin.Abstractions;

namespace Edwards.Hello;

/// <summary>
/// The launcher-install test plugin (L-301 sequencing step 2). Gameplay-only: it does not
/// implement any render-pack interface, unlike the OpenAC test fixture with the same class name
/// (<c>AcDream.Core.Tests.Fixtures.HelloPlugin</c>), which this plugin does not copy from.
///
/// Runs on both hosts. Headless has no plugin storage (<c>Storage.IsAvailable</c> is false
/// there), so on headless it logs instead of writing. Loading on both hosts lets the launcher's
/// runtime gate check that a headless character with a blank plugin list loads nothing.
/// </summary>
public sealed class HelloPlugin : IAcDreamPlugin
{
    private const string StorageKey = "last-enabled-at";

    private IPluginHost? _host;

    public void Initialize(IPluginHost host) => _host = host;

    public void Enable()
    {
        IPluginHost? host = _host;
        if (host is null)
            return;

        if (host.Storage.IsAvailable)
        {
            host.Storage.WriteText(StorageKey, DateTimeOffset.UtcNow.ToString("O"));
            host.Log.Info("edwards.hello: wrote '" + StorageKey + "' to plugin storage.");
        }
        else
        {
            host.Log.Warn("edwards.hello: plugin storage unavailable on this host; nothing written.");
        }
    }

    public void Disable()
    {
        _host = null;
    }
}
