using System.Runtime.InteropServices;
using com.cinaq.MxLintExtension.Core;
using Xunit;

namespace MxLintExtension.Tests;

public class CliAssetResolutionTests
{
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
    public void ResolveLocalExecutableName_ReturnsExe_ForWindows()
    {
        var executableName = MxLint.ResolveLocalExecutableName(OSPlatform.Windows);
        Assert.Equal("mxlint-local.exe", executableName);
    }

    [Fact]
    public void ResolveLocalExecutableName_ReturnsNoExtension_ForMac()
    {
        var executableName = MxLint.ResolveLocalExecutableName(OSPlatform.OSX);
        Assert.Equal("mxlint-local", executableName);
    }
}
