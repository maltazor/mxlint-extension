using Xunit;
using com.cinaq.MxLintExtension.Core;
using MxLintExtension.Tests.Helpers;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace MxLintExtension.Tests;

public class NoqaTests : IDisposable
{
    private readonly TestFixture _fixture = new();

    [Fact]
    public async Task AddNoqaRules_AddsSkipEntry()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules
            {
                Document = "MyModule/MyPage",
                Rules = new List<string> { "001_0001" }
            }
        });

        var config = await ReadConfig();
        Assert.True(config.Lint.Skip.ContainsKey("MyModule/MyPage"));
        var rules = config.Lint.Skip["MyModule/MyPage"];
        Assert.Single(rules);
        Assert.Equal("001_0001", rules[0].Rule);
        Assert.NotEmpty(rules[0].Reason);
        Assert.NotEmpty(rules[0].Date);
    }

    [Fact]
    public async Task AddNoqaRules_MultipleRulesForSameDocument()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules
            {
                Document = "Admin/DomainModels$DomainModel",
                Rules = new List<string> { "002_0001", "002_0002", "003_0001" }
            }
        });

        var config = await ReadConfig();
        var rules = config.Lint.Skip["Admin/DomainModels$DomainModel"];
        Assert.Equal(3, rules.Count);
        Assert.Equal("002_0001", rules[0].Rule);
        Assert.Equal("002_0002", rules[1].Rule);
        Assert.Equal("003_0001", rules[2].Rule);
    }

    [Fact]
    public async Task AddNoqaRules_MultipleDocuments()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "ModA/Doc1", Rules = new List<string> { "001_0001" } },
            new NoqaDocumentRules { Document = "ModB/Doc2", Rules = new List<string> { "002_0001" } }
        });

        var config = await ReadConfig();
        Assert.Equal(2, config.Lint.Skip.Count);
        Assert.True(config.Lint.Skip.ContainsKey("ModA/Doc1"));
        Assert.True(config.Lint.Skip.ContainsKey("ModB/Doc2"));
    }

    [Fact]
    public async Task AddNoqaRules_DoesNotDuplicate()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        var entry = new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "001_0001" } };
        await mxlint.AddNoqaRules(new[] { entry });
        await mxlint.AddNoqaRules(new[] { entry });

        var config = await ReadConfig();
        Assert.Single(config.Lint.Skip["Mod/Doc"]);
    }

    [Fact]
    public async Task AddNoqaRules_AppendsToDifferentRulesForSameDoc()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "001_0001" } }
        });
        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "002_0001" } }
        });

        var config = await ReadConfig();
        Assert.Equal(2, config.Lint.Skip["Mod/Doc"].Count);
    }

    [Fact]
    public async Task AddNoqaRules_NormalizesBackslashes()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "MyModule\\SubFolder\\MyPage", Rules = new List<string> { "001_0001" } }
        });

        var config = await ReadConfig();
        Assert.True(config.Lint.Skip.ContainsKey("MyModule/SubFolder/MyPage"));
    }

    [Fact]
    public async Task AddNoqaRules_SkipsEmptyDocument()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "", Rules = new List<string> { "001_0001" } }
        });

        var config = await ReadConfig();
        Assert.Empty(config.Lint.Skip);
    }

    [Fact]
    public async Task AddNoqaRules_SkipsBlankRuleNumbers()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "", "  " } }
        });

        var config = await ReadConfig();
        Assert.True(config.Lint.Skip.ContainsKey("Mod/Doc"));
        Assert.Empty(config.Lint.Skip["Mod/Doc"]);
    }

    [Fact]
    public async Task AddNoqaRules_PreservesExistingConfig()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "001_0001" } }
        });

        var config = await ReadConfig();
        Assert.Equal("modelsource", config.Modelsource);
        Assert.Equal(".mendix-cache/rules", config.Rules.Path);
        Assert.Empty(config.Rules.Rulesets);
    }

    [Fact]
    public async Task AddNoqaRules_SetsDateToday()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);
        await mxlint.EnsureConfigFile();

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "001_0001" } }
        });

        var config = await ReadConfig();
        var rule = config.Lint.Skip["Mod/Doc"][0];
        Assert.Equal(DateTime.UtcNow.ToString("yyyy-MM-dd"), rule.Date);
    }

    [Fact]
    public async Task AddNoqaRules_CreatesConfigIfMissing()
    {
        var mxlint = new MxLint(_fixture.Model, _fixture.LogService);

        await mxlint.AddNoqaRules(new[]
        {
            new NoqaDocumentRules { Document = "Mod/Doc", Rules = new List<string> { "001_0001" } }
        });

        Assert.True(File.Exists(_fixture.ConfigPath));
        var config = await ReadConfig();
        Assert.Single(config.Lint.Skip);
    }

    private async Task<MxLintConfig> ReadConfig()
    {
        var yaml = await File.ReadAllTextAsync(_fixture.ConfigPath);
        var deserializer = new DeserializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .IgnoreUnmatchedProperties()
            .Build();
        return deserializer.Deserialize<MxLintConfig>(yaml);
    }

    public void Dispose() => _fixture.Dispose();
}
