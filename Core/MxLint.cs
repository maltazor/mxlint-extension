using System.Diagnostics;
using System.IO.Compression;
using System.Net.Http;
using Mendix.StudioPro.ExtensionsAPI.Model;
using Mendix.StudioPro.ExtensionsAPI.Services;

namespace com.cinaq.MxLintExtension.Core;

public class MxLint
{
    private readonly IModel _model;
    private readonly ILogService _logService;
    private readonly string _executablePath;
    private readonly string _lintResultsPath;
    private readonly string _cachePath;
    private readonly string _rulesPath;
    private readonly string _cliBaseUrl;
    private readonly string _rulesBaseUrl;

    private const string CliVersion = "v3.12.0";
    private const string RulesVersion = "v3.3.0";

    public MxLint(IModel model, ILogService logService)
    {
        _model = model;
        _logService = logService;

        _cachePath = Path.Combine(_model.Root.DirectoryPath, ".mendix-cache");
        _executablePath = Path.Combine(_cachePath, "mxlint-local.exe");
        _lintResultsPath = Path.Combine(_cachePath, "lint-results.json");
        _rulesPath = Path.Combine(_cachePath, "rules");
        _cliBaseUrl = $"https://github.com/mxlint/mxlint-cli/releases/download/{CliVersion}/";
        _rulesBaseUrl = $"https://github.com/mxlint/mxlint-rules/releases/download/{RulesVersion}/";
    }

    public async Task Lint()
    {
        try
        {
            await EnsureCli();
            await EnsurePolicies();
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
        await RunProcess("export-model", "Exporting model");
    }

    public async Task LintModel()
    {
        await RunProcess($"lint -j \"{_lintResultsPath}\" -r \"{_rulesPath}\"", "Linting model");
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
        var downloadUrl = $"{_cliBaseUrl}mxlint-{CliVersion}-windows-amd64.exe";
        _logService.Info($"Downloading CLI from {downloadUrl}");
        var response = await client.GetAsync(downloadUrl);
        await using var fs = new FileStream(_executablePath, FileMode.CreateNew);
        await response.Content.CopyToAsync(fs);
    }

    private async Task EnsurePolicies()
    {
        if (Directory.Exists(_rulesPath))
        {
            _logService.Info("Rules already exists");
            return;
        }

        using var client = new HttpClient();
        var downloadUrl = $"{_rulesBaseUrl}rules-{RulesVersion}.zip";
        var tempZip = Path.Combine(_cachePath, "rules.zip");
        _logService.Info($"Downloading rules from {downloadUrl}");
        var response = await client.GetAsync(downloadUrl);
        await using var fs = new FileStream(tempZip, FileMode.CreateNew);
        await response.Content.CopyToAsync(fs);
        ZipFile.ExtractToDirectory(tempZip, _cachePath);
        File.Delete(tempZip);
    }
}
