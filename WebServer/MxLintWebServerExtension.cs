using System.ComponentModel.Composition;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using com.cinaq.MxLintExtension.Core;
using Mendix.StudioPro.ExtensionsAPI.Services;
using Mendix.StudioPro.ExtensionsAPI.UI.WebServer;

namespace com.cinaq.MxLintExtension.WebServer;

[Export(typeof(WebServerExtension))]
public class MxLintWebServerExtension : WebServerExtension
{
    private readonly IExtensionFileService _extensionFileService;
    private readonly ILogService _logService;
    private readonly IConfigurationService _configurationService;

    [ImportingConstructor]
    public MxLintWebServerExtension(
        IExtensionFileService extensionFileService,
        ILogService logService,
        IConfigurationService configurationService)
    {
        _extensionFileService = extensionFileService;
        _logService = logService;
        _configurationService = configurationService;
    }

    public override void InitializeWebServer(IWebServer webServer)
    {
        var wwwrootPath = _extensionFileService.ResolvePath("wwwroot");
        var files = Directory.GetFiles(wwwrootPath);

        foreach (var file in files)
        {
            var route = Path.GetFileName(file);
            webServer.AddRoute(route, (request, response, ct) => ServeFile(file, response, ct));
        }

        webServer.AddRoute("api", ServeApi);
        webServer.AddRoute("api/theme", ServeTheme);
        webServer.AddRoute("api/noqa", ServeNoqa);
    }

    private static async Task ServeFile(string filePath, HttpListenerResponse response, CancellationToken ct)
    {
        var mimeType = GetMimeType(filePath);
        await response.SendFileAndClose(mimeType, filePath, ct);
    }

    private static string GetMimeType(string filePath)
    {
        var extension = Path.GetExtension(filePath);
        return extension switch
        {
            ".html" => "text/html",
            ".js" => "text/javascript",
            ".css" => "text/css",
            _ => "application/octet-stream"
        };
    }

    private async Task ServeApi(HttpListenerRequest request, HttpListenerResponse response, CancellationToken ct)
    {
        if (CurrentApp == null)
        {
            response.SendNoBodyAndClose(404);
            return;
        }

        var jsonPath = Path.Combine(CurrentApp.Root.DirectoryPath, ".mendix-cache", "lint-results.json");
        var data = await File.ReadAllTextAsync(jsonPath, ct);
        var jsonStream = new MemoryStream();
        jsonStream.Write(Encoding.UTF8.GetBytes(data));
        response.SendJsonAndClose(jsonStream);
    }

    private Task ServeTheme(HttpListenerRequest request, HttpListenerResponse response, CancellationToken ct)
    {
        if (CurrentApp == null)
        {
            response.SendNoBodyAndClose(404);
            return Task.CompletedTask;
        }

        var themeObject = new JsonObject
        {
            ["theme"] = _configurationService.Configuration.Theme
                .ToString()
                .ToLowerInvariant()
        };

        var json = themeObject.ToJsonString(new()
        {
            WriteIndented = true
        });

        var jsonStream = new MemoryStream();
        jsonStream.Write(Encoding.UTF8.GetBytes(json));
        response.SendJsonAndClose(jsonStream);
        return Task.CompletedTask;
    }

    private async Task ServeNoqa(HttpListenerRequest request, HttpListenerResponse response, CancellationToken ct)
    {
        if (CurrentApp == null)
        {
            response.SendNoBodyAndClose(404);
            return;
        }

        if (!string.Equals(request.HttpMethod, "POST", StringComparison.OrdinalIgnoreCase))
        {
            response.SendNoBodyAndClose(405);
            return;
        }

        try
        {
            using var reader = new StreamReader(request.InputStream, request.ContentEncoding ?? Encoding.UTF8);
            var body = await reader.ReadToEndAsync(ct);
            var payload = JsonSerializer.Deserialize<NoqaRequest>(body);

            if (payload?.Entries == null || payload.Entries.Count == 0)
            {
                response.SendNoBodyAndClose(400);
                return;
            }

            var mxlint = new MxLint(CurrentApp, _logService);
            await mxlint.AddNoqaRules(payload.Entries);
            SendJson(response, new { success = true });
        }
        catch (Exception ex)
        {
            _logService.Error($"Failed to update NOQA config: {ex.Message}");
            SendJson(response, new { success = false, error = ex.Message }, 500);
        }
    }

    private static void SendJson(HttpListenerResponse response, object payload, int statusCode = 200)
    {
        var json = JsonSerializer.Serialize(payload);
        var jsonStream = new MemoryStream(Encoding.UTF8.GetBytes(json));
        response.SendJsonAndClose(jsonStream, statusCode);
    }
}

public sealed class NoqaRequest
{
    public List<NoqaDocumentRules> Entries { get; set; } = new();
}
