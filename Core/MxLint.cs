using System.Diagnostics;
using System.Net.Http;
using System.Text;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;
using Mendix.StudioPro.ExtensionsAPI.Model;
using Mendix.StudioPro.ExtensionsAPI.Services;

namespace com.cinaq.MxLintExtension.Core;

public class MxLint
{
    private const string NoqaReason = "Skipped from MxLint extension";
    private readonly IModel _model;
    private readonly ILogService _logService;
    private readonly string _executablePath;
    private readonly string _lintResultsPath;
    private readonly string _configPath;
    private readonly string _cachePath;
    private readonly string _cliBaseUrl;

    private const string CliVersion = "v3.14.1";
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
            await EnsureConfigFile();
            await EnsureCli();
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

    public async Task AddNoqaRules(IEnumerable<NoqaDocumentRules> entries)
    {
        EnsureCacheDirectory();
        await EnsureConfigFile();
        var config = await ReadConfig();

        config.Lint ??= new MxLintConfigLint();
        config.Lint.Skip ??= new Dictionary<string, List<MxLintConfigSkipRule>>(StringComparer.OrdinalIgnoreCase);

        foreach (var entry in entries)
        {
            var documentPath = NormalizeDocumentPath(entry.Document);
            if (string.IsNullOrWhiteSpace(documentPath))
            {
                continue;
            }

            if (!config.Lint.Skip.TryGetValue(documentPath, out var skipRules))
            {
                skipRules = new List<MxLintConfigSkipRule>();
                config.Lint.Skip[documentPath] = skipRules;
            }

            var existingRules = skipRules
                .Where(item => !string.IsNullOrWhiteSpace(item.Rule))
                .Select(item => item.Rule)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            foreach (var ruleNumber in entry.Rules.Select(NormalizeRuleNumber).Where(rule => !string.IsNullOrWhiteSpace(rule)))
            {
                if (existingRules.Contains(ruleNumber))
                {
                    continue;
                }

                skipRules.Add(new MxLintConfigSkipRule
                {
                    Rule = ruleNumber,
                    Reason = NoqaReason,
                    Date = DateTime.UtcNow.ToString("yyyy-MM-dd")
                });

                existingRules.Add(ruleNumber);
            }
        }

        await WriteConfig(config);
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

    public async Task EnsureConfigFile()
    {
        if (File.Exists(_configPath))
        {
            _logService.Info("MxLint extension config already exists");
            return;
        }

        EnsureCacheDirectory();
        var config = CreateDefaultConfig();
        await WriteConfig(config);
    }

    private async Task<MxLintConfig> ReadConfig()
    {
        if (!File.Exists(_configPath))
        {
            return CreateDefaultConfig();
        }

        var yaml = await File.ReadAllTextAsync(_configPath);
        var deserializer = new DeserializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build();

        var config = deserializer.Deserialize<MxLintConfig>(yaml);
        return config ?? CreateDefaultConfig();
    }

    private async Task WriteConfig(MxLintConfig config)
    {
        var serializer = new SerializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .Build();

        var yaml = serializer.Serialize(config);
        await File.WriteAllTextAsync(_configPath, yaml, Encoding.UTF8);
    }

    private MxLintConfig CreateDefaultConfig()
    {
        return new MxLintConfig
        {
            Rules = new MxLintConfigRules
            {
                Path = ".mendix-cache/rules",
                Rulesets = new List<string>
                {
                    $"https://github.com/mxlint/mxlint-rules/releases/download/{RulesVersion}/rules-{RulesVersion}.zip"
                }
            },
            Lint = new MxLintConfigLint
            {
                XunitReport = "",
                JsonFile = ".mendix-cache/lint-results.json",
                IgnoreNoqa = false,
                NoCache = false,
                Concurrency = 4,
                RegoTrace = false,
                Skip = new Dictionary<string, List<MxLintConfigSkipRule>>()
            },
            Cache = new MxLintConfigCache
            {
                Directory = ".mendix-cache/mxlint",
                Enable = true
            },
            Modelsource = "modelsource",
            ProjectDirectory = ".",
            Export = new MxLintConfigExport
            {
                Filter = ".*",
                Raw = false,
                Appstore = false
            }
        };
    }

    private static string NormalizeDocumentPath(string value)
    {
        var normalized = value.Trim().Replace("\\", "/");
        normalized = normalized.TrimStart('/');
        normalized = normalized.StartsWith("./", StringComparison.Ordinal) ? normalized[2..] : normalized;
        return normalized;
    }

    private static string NormalizeRuleNumber(string value)
    {
        return value.Trim();
    }
}

public sealed class NoqaDocumentRules
{
    public string Document { get; set; } = string.Empty;
    public List<string> Rules { get; set; } = new();
}

public sealed class MxLintConfig
{
    public MxLintConfigRules Rules { get; set; } = new();
    public MxLintConfigLint Lint { get; set; } = new();
    public MxLintConfigCache Cache { get; set; } = new();
    public MxLintConfigExport Export { get; set; } = new();
    public MxLintConfigServe Serve { get; set; } = new();
    public string Modelsource { get; set; } = "modelsource";
    public string ProjectDirectory { get; set; } = ".";
}

public sealed class MxLintConfigRules
{
    public string Path { get; set; } = ".mendix-cache/rules";
    public List<string> Rulesets { get; set; } = new();
}

public sealed class MxLintConfigLint
{
    public string XunitReport { get; set; } = "";
    public string JsonFile { get; set; } = "";
    public bool IgnoreNoqa { get; set; }
    public bool NoCache { get; set; }
    public int Concurrency { get; set; } = 4;
    public bool RegoTrace { get; set; }
    public Dictionary<string, List<MxLintConfigSkipRule>> Skip { get; set; } = new();
}

public sealed class MxLintConfigCache
{
    public string Directory { get; set; } = ".mendix-cache/mxlint";
    public bool Enable { get; set; } = true;
}

public sealed class MxLintConfigExport
{
    public string Filter { get; set; } = ".*";
    public bool Raw { get; set; }
    public bool Appstore { get; set; }
}

public sealed class MxLintConfigServe
{
    public int Port { get; set; } = 8082;
    public int Debounce { get; set; } = 500;
}

public sealed class MxLintConfigSkipRule
{
    public string Rule { get; set; } = string.Empty;
    public string Reason { get; set; } = string.Empty;
    public string Date { get; set; } = string.Empty;
}
