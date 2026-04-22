using System.Runtime.InteropServices;
using com.cinaq.MxLintExtension.Core;
using Xunit;

namespace MxLintExtension.Tests;

public class CliAssetResolutionTests
{
    [Fact]
    public void ResolveCliVersion_ReturnsConfiguredValue_WhenProvided()
    {
        var version = MxLint.ResolveCliVersion("v9.9.9");
        Assert.Equal("v9.9.9", version);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData(null)]
    public void ResolveCliVersion_ReturnsDefault_WhenValueMissing(string? configuredVersion)
    {
        var version = MxLint.ResolveCliVersion(configuredVersion);
        Assert.Equal(MxLint.DefaultCliVersion, version);
    }

    [Fact]
    public void ResolveCliAssetName_ReturnsWindowsArm64Asset_ForWindowsArm64()
    {
        var assetName = MxLint.ResolveCliAssetName(OSPlatform.Windows, Architecture.Arm64);
        Assert.Equal("mxlint-windows-arm64.exe", assetName);
    }

    [Theory]
    [InlineData(Architecture.X64)]
    [InlineData(Architecture.X86)]
    [InlineData(Architecture.Arm)]
    [InlineData(Architecture.Wasm)]
    [InlineData(Architecture.S390x)]
    [InlineData(Architecture.LoongArch64)]
    [InlineData(Architecture.Ppc64le)]
    public void ResolveCliAssetName_ReturnsWindowsAmd64Asset_ForNonArm64Windows(Architecture architecture)
    {
        var assetName = MxLint.ResolveCliAssetName(OSPlatform.Windows, architecture);
        Assert.Equal("mxlint-windows-amd64.exe", assetName);
    }

    [Fact]
    public void ResolveCliAssetName_ReturnsDarwinArm64Asset_ForMacArm64()
    {
        var assetName = MxLint.ResolveCliAssetName(OSPlatform.OSX, Architecture.Arm64);
        Assert.Equal("mxlint-darwin-arm64", assetName);
    }

    [Fact]
    public void ResolveCliAssetName_ReturnsDarwinAmd64Asset_ForMacX64()
    {
        var assetName = MxLint.ResolveCliAssetName(OSPlatform.OSX, Architecture.X64);
        Assert.Equal("mxlint-darwin-amd64", assetName);
    }

    [Fact]
    public void ResolveLocalExecutableName_IncludesVersionAndExe_ForWindowsAsset()
    {
        var executableName = MxLint.ResolveLocalExecutableName("mxlint-windows-arm64.exe", "v3.14.1");
        Assert.Equal("mxlint-windows-arm64-v3.14.1.exe", executableName);
    }

    [Fact]
    public void ResolveLocalExecutableName_IncludesVersionWithoutExtension_ForMacAsset()
    {
        var executableName = MxLint.ResolveLocalExecutableName("mxlint-darwin-arm64", "v3.14.1");
        Assert.Equal("mxlint-darwin-arm64-v3.14.1", executableName);
    }
}
