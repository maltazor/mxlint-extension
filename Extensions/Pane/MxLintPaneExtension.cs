using System.ComponentModel.Composition;
using Mendix.StudioPro.ExtensionsAPI.Services;
using Mendix.StudioPro.ExtensionsAPI.UI.DockablePane;
using Mendix.StudioPro.ExtensionsAPI.UI.Services;

namespace com.cinaq.MxLintExtension.Extensions.Pane;

[Export(typeof(DockablePaneExtension))]
public class MxLintPaneExtension : DockablePaneExtension
{
    public const string IdValue = "com-cinaq-mxlint-extension";
    public override string Id => IdValue;
    public override DockablePanePosition InitialPosition => DockablePanePosition.Bottom;

    private readonly ILogService _logService;
    private readonly IDockingWindowService _dockingWindowService;

    [ImportingConstructor]
    public MxLintPaneExtension(IDockingWindowService dockingWindowService, ILogService logService)
    {
        _logService = logService;
        _dockingWindowService = dockingWindowService;
    }

    public override DockablePaneViewModelBase Open()
    {
        var baseUri = new Uri(Path.Combine(WebServerBaseUrl.AbsoluteUri, "wwwroot"));
        return new MxLintPaneExtensionWebViewModel(baseUri, () => CurrentApp, _logService, _dockingWindowService)
        {
            Title = "MxLint"
        };
    }
}
