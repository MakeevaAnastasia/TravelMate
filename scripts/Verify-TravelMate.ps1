$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
[xml]$page = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'MauiApp1/MainPage.xaml')
$ns = 'http://schemas.microsoft.com/winfx/2009/xaml'
$visualTypes = @('ContentPage','ScrollView','VerticalStackLayout','HorizontalStackLayout','Grid','Border','Label','Entry','Editor','Picker','RadioButton','CheckBox','Switch','DatePicker','Slider','Image','Button','BoxView')
$visuals = @($page.SelectNodes('//*') | Where-Object { $_.LocalName -in $visualTypes })
$names = @{}
foreach ($node in $visuals) {
    $name = $node.GetAttribute('Name', $ns)
    if ($name -notmatch '^_[A-Za-z][A-Za-z0-9]*_$' -or $names.ContainsKey($name)) { throw "Missing or duplicate UI name: $($node.LocalName) '$name'" }
    $names[$name] = $true
}
$requirements = @{
    Entry = @('Placeholder','Keyboard','MaxLength','TextChanged')
    Editor = @('Placeholder','AutoSize','MaxLength','TextChanged')
    Picker = @('Title','SelectedIndexChanged')
    RadioButton = @('Content','GroupName','Value','CheckedChanged')
    CheckBox = @('IsChecked','Color','CheckedChanged')
    Switch = @('IsToggled','OnColor','Toggled')
    DatePicker = @('Format','Date','MinimumDate','MaximumDate','DateSelected')
    Slider = @('Minimum','Maximum','Value','ValueChanged')
    Image = @('Source','Aspect','HeightRequest')
    Button = @('Text','Clicked')
    Grid = @('RowDefinitions','ColumnDefinitions')
}
foreach ($type in $requirements.Keys) {
    $nodes = @($visuals | Where-Object LocalName -eq $type)
    if (!$nodes.Count) { throw "Missing control: $type" }
    foreach ($node in $nodes) {
        foreach ($property in $requirements[$type]) {
            if (!$node.HasAttribute($property)) { throw "Missing $type.$property" }
        }
    }
}
foreach ($pair in @(@('RadioButton',3),@('CheckBox',2),@('Entry',2),@('Button',2),@('Slider',1),@('DatePicker',1),@('Picker',1),@('Editor',1),@('Image',1),@('Switch',1))) {
    if (@($visuals | Where-Object LocalName -eq $pair[0]).Count -ne $pair[1]) { throw "Wrong control count: $($pair[0])" }
}
foreach ($grid in @($visuals | Where-Object LocalName -eq 'Grid')) {
    foreach ($child in @($grid.ChildNodes | Where-Object { $_.NodeType -eq 'Element' -and $_.LocalName -in $visualTypes })) {
        if (!$child.HasAttribute('Grid.Row') -or !$child.HasAttribute('Grid.Column')) { throw 'Grid placement must be explicit' }
    }
}
$radios = @($visuals | Where-Object LocalName -eq 'RadioButton')
if (@($radios | ForEach-Object { $_.GroupName } | Select-Object -Unique).Count -ne 1) { throw 'Radio group must be shared' }
if (@($radios | ForEach-Object { $_.Value } | Select-Object -Unique).Count -ne 3) { throw 'Radio values must be distinct' }
$entries = @($visuals | Where-Object LocalName -eq 'Entry')
if (($entries | ForEach-Object { $_.Keyboard } | Sort-Object) -join ',' -ne 'Numeric,Text') { throw 'Entry keyboards must differ' }
$slider = $visuals | Where-Object LocalName -eq 'Slider'
if ($slider.Minimum -ne '1' -or $slider.Maximum -ne '30' -or $slider.Value -ne '7') { throw 'Incorrect duration defaults' }
if (@($visuals | Where-Object LocalName -eq 'ScrollView').Count -ne 1) { throw 'Expected one scroll view' }
foreach ($stack in @($visuals | Where-Object { $_.LocalName -in @('VerticalStackLayout','HorizontalStackLayout') })) {
    if (!$stack.HasAttribute('Spacing')) { throw 'Stack spacing must be explicit' }
}
$raw = $page.OuterXml
if ($raw -notmatch 'x:Reference' -or $raw -notmatch 'Path=Value' -or $raw -notmatch 'Mode=OneWay') { throw 'Missing explicit slider binding' }
$countries = @($page.SelectNodes('//*[local-name()="Picker.Items"]/*') | ForEach-Object InnerText)
if (($countries -join ',') -ne 'Турция,Египет,Таиланд,ОАЭ') { throw 'Incorrect country choices' }
if (@($visuals | Where-Object { $_.LocalName -eq 'Label' -and $_.HasAttribute('Text') -and $_.HasAttribute('FontSize') -and $_.HasAttribute('FontAttributes') }).Count -lt 2) { throw 'Missing explicit Label properties' }
Write-Output "PASS: XAML contract; $($visuals.Count) named UI elements."
