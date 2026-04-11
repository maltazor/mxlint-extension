using System.Diagnostics;
using System.Net.Http;
using System.Text;
using Mendix.StudioPro.ExtensionsAPI.Model;
using Mendix.StudioPro.ExtensionsAPI.Services;

namespace com.cinaq.MxLintExtension.Core;

public class MxLint
{
    private readonly IModel _model;
    private readonly ILogService _logService;
    private readonly string _executablePath;
    private readonly string _lintResultsPath;
    private readonly string _configPath;
    private readonly string _cachePath;
    private readonly string _cliBaseUrl;

    private const string CliVersion = "v3.14.0";
    private const string RulesVersion = "v3.3.0";

    public MxLint(IModel model, ILogService logService)
    {
        _model = model;
        _logService = logService;

        _cachePath = Path.Combine(_model.Root.DirectoryPath, ".mendix-cache");
        _executablePath = Path.Combine(_cachePath, "mxlint-local.exe");
        _lintResultsPath = Path.Combine(_cachePath, "lint-results.json");
        _configPath = Path.Combine(_cachePath, "mxlint-extension.yaml");
        _cliBaseUrl = $"https://github.com/mxlint/mxlint-cli/releases/download/{CliVersion}/";
    }

    public async Task Lint()
    {
        try
        {
            EnsureCacheDirectory();
            await EnsureCli();
            await EnsureConfig();
            await ExportModel();
            await LintModel();
        }
        catch (Exception ex)
        {
            _logService.Error($"Error during linting process: {ex.Message}");
        }
    }

    public async Task ExportModel()
    {
        await RunProcess($"--config \"{_configPath}\" export", "Exporting model");
    }

    public async Task LintModel()
    {
        await RunProcess($"--config \"{_configPath}\" lint", "Linting model");
    }

    private async Task RunProcess(string arguments, string operationName)
    {
        var startInfo = new ProcessStartInfo
        {
            FileName = _executablePath,
            Arguments = arguments,
            WorkingDirectory = _model.Root.DirectoryPath,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };

        using var process = new Process { StartInfo = startInfo };
        process.OutputDataReceived += (_, e) =>
        {
            if (e.Data != null)
            {
                _logService.Info(e.Data);
            }
        };
        process.ErrorDataReceived += (_, e) =>
        {
            if (e.Data != null)
            {
                _logService.Error(e.Data);
            }
        };

        try
        {
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            await process.WaitForExitAsync();
            if (process.ExitCode != 0)
            {
                throw new InvalidOperationException($"{operationName} failed with exit code {process.ExitCode}");
            }

            _logService.Info($"Finished {operationName}");
        }
        catch (Exception ex)
        {
            _logService.Error($"Error during {operationName}: {ex.Message}");
        }
    }

    private async Task EnsureCli()
    {
        if (File.Exists(_executablePath))
        {
            _logService.Info("CLI already exists");
            return;
        }

        using var client = new HttpClient();
        var downloadUrl = $"{_cliBaseUrl}mxlint-windows-amd64.exe";
        _logService.Info($"Downloading CLI from {downloadUrl}");
        var response = await client.GetAsync(downloadUrl);
        response.EnsureSuccessStatusCode();
        await using var fs = new FileStream(_executablePath, FileMode.CreateNew);
        await response.Content.CopyToAsync(fs);
    }

    private void EnsureCacheDirectory()
    {
        if (!Directory.Exists(_cachePath))
        {
            Directory.CreateDirectory(_cachePath);
        }
    }

    private async Task EnsureConfig()
    {
        if (File.Exists(_configPath))
        {
            _logService.Info("MxLint extension config already exists");
            return;
        }

        var config = $$"""
rules:
  path: .mendix-cache/rules
  rulesets:
    - https://github.com/mxlint/mxlint-rules/releases/download/{{RulesVersion}}/rules-{{RulesVersion}}.zip
lint:
  xunitReport: ""
  jsonFile: .mendix-cache/lint-results.json
  ignoreNoqa: false
  noCache: false
  concurrency: 4
  regoTrace: false
  skip: {}
cache:
  directory: .mendix-cache/mxlint
  enable: true
modelsource: modelsource
projectDirectory: .
export:
  filter: ".*"
  raw: false
  appstore: false
""";

        await File.WriteAllTextAsync(_configPath, config, Encoding.UTF8);
    }
}
