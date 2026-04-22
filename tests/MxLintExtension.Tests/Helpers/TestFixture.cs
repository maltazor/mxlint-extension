using Mendix.StudioPro.ExtensionsAPI.Model;
using Mendix.StudioPro.ExtensionsAPI.Model.Projects;
using Mendix.StudioPro.ExtensionsAPI.Services;
using NSubstitute;

namespace MxLintExtension.Tests.Helpers;

public sealed class TestFixture : IDisposable
{
    public string ProjectDir { get; }
    public string CachePath { get; }
    public string ConfigPath { get; }
    public IModel Model { get; }
    public ILogService LogService { get; }

    public TestFixture()
    {
        ProjectDir = Path.Combine(Path.GetTempPath(), "mxlint-test-" + Guid.NewGuid().ToString("N")[..8]);
        Directory.CreateDirectory(ProjectDir);

        CachePath = Path.Combine(ProjectDir, ".mendix-cache");
        ConfigPath = Path.Combine(ProjectDir, "mxlint.yaml");

        var root = Substitute.For<IProject>();
        root.DirectoryPath.Returns(ProjectDir);

        Model = Substitute.For<IModel>();
        Model.Root.Returns(root);

        LogService = Substitute.For<ILogService>();
    }

    public void Dispose()
    {
        try
        {
            if (Directory.Exists(ProjectDir))
            {
                Directory.Delete(ProjectDir, true);
            }
        }
        catch
        {
            // best-effort cleanup
        }
    }
}
