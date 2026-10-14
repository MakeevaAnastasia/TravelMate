$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$source = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'MauiApp1/MainPage.xaml.cs')
$start = $source.IndexOf('    private static bool TryParseBudget')
$end = $source.IndexOf('    private void OnDurationChanged')
if ($start -lt 0 -or $end -le $start) { throw 'Budget and duration helpers not found' }
$methods = $source.Substring($start, $end - $start)
$checks = @'
    static int checks;
    static void Assert(bool condition, string message)
    {
        checks++;
        if (!condition) throw new Exception(message);
    }
    public static void Main()
    {
        foreach (string invalid in new[] { "", " ", "0", "0,00", "-10", "+10", "NaN", "Infinity", "1e3", "abc", "12 34", "1,2.3", "1.000", "100 ₽", "999999999999999999999999999999999999999" })
            Assert(!TryParseBudget(invalid, out _), "Accepted invalid budget: " + invalid);
        Assert(!TryParseBudget(null, out _), "Accepted null budget");
        foreach (string input in new[] { "120000", "120 000", " 120000 ", "120\u00A0000", "120\u202F000" })
            Assert(TryParseBudget(input, out decimal amount) && amount == 120000m, "Wrong whole budget: " + input);
        foreach (string input in new[] { "120000,50", "120000.50", "120 000,50" })
            Assert(TryParseBudget(input, out decimal amount) && amount == 120000.50m, "Wrong fractional budget: " + input);
        Assert(TryParseBudget("0,01", out decimal small) && small == .01m, "Small positive budget rejected");
        Assert(RoundDuration(1) == 1, "Minimum duration");
        Assert(RoundDuration(30) == 30, "Maximum duration");
        Assert(RoundDuration(7.49) == 7, "Rounding below midpoint");
        Assert(RoundDuration(7.5) == 8, "Rounding midpoint");
        Assert(RoundDuration(8.5) == 9, "Rounding even midpoint");
        Assert(FormatDays(1) == "1 день", "Singular days");
        Assert(FormatDays(2) == "2 дня", "Few days");
        Assert(FormatDays(11) == "11 дней", "Eleven days");
        Assert(FormatDays(14) == "14 дней", "Fourteen days");
        Assert(FormatDays(21) == "21 день", "Twenty-one days");
        Assert(FormatDays(22) == "22 дня", "Twenty-two days");
        Assert(FormatDays(30) == "30 дней", "Thirty days");
        Console.WriteLine($"PASS: {checks} budget and duration assertions against actual code-behind helpers.");
    }
'@
$folder = Join-Path $root '.verification'
[void][System.IO.Directory]::CreateDirectory($folder)
$generated = "#nullable enable`nusing System;`nusing System.Globalization;`nusing System.Text.RegularExpressions;`nclass TravelMateLogicChecks {`n$methods`n$checks`n}"
[System.IO.File]::WriteAllText((Join-Path $folder 'LogicChecks.cs'), $generated, [System.Text.UTF8Encoding]::new($true))
$dotnetRoot = Split-Path (Get-Command dotnet).Source -Parent
$sdkVersion = (& dotnet --version).Trim()
$compiler = Join-Path $dotnetRoot "sdk/$sdkVersion/Roslyn/bincore/csc.dll"
$refPack = Get-ChildItem (Join-Path $dotnetRoot 'packs/Microsoft.NETCore.App.Ref') -Directory | Where-Object Name -Like '10.*' | Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$references = Get-ChildItem (Join-Path $refPack.FullName 'ref/net10.0') -Filter '*.dll' | ForEach-Object { '-r:"' + $_.FullName + '"' }
$argsFile = Join-Path $folder 'compile.rsp'
$arguments = @('-nologo', '-target:exe', ('-out:"' + (Join-Path $folder 'LogicChecks.dll') + '"'), ('"' + (Join-Path $folder 'LogicChecks.cs') + '"')) + $references
[System.IO.File]::WriteAllLines($argsFile, $arguments, [System.Text.UTF8Encoding]::new($true))
& dotnet $compiler "@$argsFile"
if ($LASTEXITCODE -ne 0) { throw 'Logic check compilation failed' }
[System.IO.File]::WriteAllText((Join-Path $folder 'LogicChecks.runtimeconfig.json'), '{"runtimeOptions":{"tfm":"net10.0","framework":{"name":"Microsoft.NETCore.App","version":"10.0.0"}}}')
& dotnet (Join-Path $folder 'LogicChecks.dll')
if ($LASTEXITCODE -ne 0) { throw 'Logic checks failed' }
