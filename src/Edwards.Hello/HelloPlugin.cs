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
///
/// Once the character is in the world it posts one local system chat line naming its version, so a
/// tester can see which release loaded. Nothing is sent to the server.
/// </summary>
public sealed class HelloPlugin : IAcDreamPlugin
{
    private const string StorageKey = "last-enabled-at";

    private IPluginHost? _host;
    private bool _announced;

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

        _announced = false;
        host.Events.Tick += OnTick;
    }

    public void Disable()
    {
        if (_host is not null)
            _host.Events.Tick -= OnTick;
        _host = null;
    }

    private void OnTick(double deltaSeconds)
    {
        IPluginHost? host = _host;
        if (host is null || _announced || !host.Automation.IsAvailable)
            return;

        _announced = true;
        host.Events.Tick -= OnTick;
        host.Automation.Chat.PostSystemMessage("Hello " + Version + " loaded (edwards.hello).");
    }

    private static string Version =>
        typeof(HelloPlugin).Assembly
            .GetCustomAttributes(typeof(System.Reflection.AssemblyInformationalVersionAttribute), false)
            .OfType<System.Reflection.AssemblyInformationalVersionAttribute>()
            .Select(attribute => attribute.InformationalVersion.Split('+')[0])
            .FirstOrDefault() ?? "unknown";
}
