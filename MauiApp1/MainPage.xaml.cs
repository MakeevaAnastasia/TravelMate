using System.Globalization;
using System.Text.RegularExpressions;

namespace MauiApp1;

public partial class MainPage : ContentPage
{
    private static readonly CultureInfo RussianCulture = CultureInfo.GetCultureInfo("ru-RU");
    private bool _isUpdating = true;

    // Initialized before XAML reads the date bindings.
    public DateTime EarliestTravelDate { get; } = DateTime.Today;
    public DateTime LatestTravelDate { get; } = DateTime.Today.AddYears(2);
    public DateTime InitialTravelDate { get; } = DateTime.Today.AddDays(14);

    public MainPage()
    {
        InitializeComponent();
        _isUpdating = false;
        UpdateReadiness();
    }

    private void OnFormChanged(object? sender, EventArgs e)
    {
        // XAML initialization and reset can raise events before controls are ready.
        if (_isUpdating)
            return;

        _ResultCard_.IsVisible = false;
        _ResultLabel_.Text = string.Empty;
        _ValidationLabel_.IsVisible = false;
        _ValidationLabel_.Text = string.Empty;
        UpdateReadiness();
    }

    private void UpdateReadiness()
    {
        _ReadyLabel_.IsVisible = !string.IsNullOrWhiteSpace(_NameEntry_.Text)
            && TryParseBudget(_BudgetEntry_.Text, out _);
    }

    private static bool TryParseBudget(string? input, out decimal budget)
    {
        budget = 0;
        if (string.IsNullOrWhiteSpace(input))
            return false;

        // Accept decimal comma/point and properly grouped thousands, including NBSP.
        // Reject signs, exponent notation, currency symbols and ambiguous grouping.
        string normalized = input.Trim().Replace('\u00A0', ' ').Replace('\u202F', ' ');
        if (!Regex.IsMatch(normalized, @"^(?:[0-9]+|[0-9]{1,3}(?: [0-9]{3})+)(?:[.,][0-9]{1,2})?$"))
            return false;

        normalized = normalized.Replace(" ", string.Empty).Replace(',', '.');
        return decimal.TryParse(normalized, NumberStyles.AllowDecimalPoint,
            CultureInfo.InvariantCulture, out budget) && budget > 0;
    }

    private static int RoundDuration(double value) =>
        Math.Clamp((int)Math.Round(value, MidpointRounding.AwayFromZero), 1, 30);

    private static string FormatDays(int days)
    {
        string ending = days % 100 is >= 11 and <= 14 ? "дней"
            : days % 10 == 1 ? "день"
            : days % 10 is >= 2 and <= 4 ? "дня" : "дней";
        return $"{days} {ending}";
    }

    private void OnDurationChanged(object? sender, ValueChangedEventArgs e)
    {
        if (_isUpdating || sender is not Slider slider)
            return;

        int days = RoundDuration(e.NewValue);
        // Whole-day snapping keeps the x:Reference label and summary consistent.
        if (slider.Value != days)
            slider.Value = days;

        OnFormChanged(sender, e);
    }

    private async void OnSubmitClicked(object? sender, EventArgs e)
    {
        string? error = ValidateForm(out decimal budget);
        if (error is not null)
        {
            _ResultCard_.IsVisible = false;
            _ValidationLabel_.Text = error;
            _ValidationLabel_.IsVisible = true;
            SemanticScreenReader.Announce(error);
            await _MainScroll_.ScrollToAsync(_ValidationLabel_, ScrollToPosition.MakeVisible, true);
            return;
        }

        _ValidationLabel_.IsVisible = false;
        _ResultLabel_.Text = BuildSummary(budget);
        _ResultCard_.IsVisible = true;
        // Dispatch after layout can place the newly visible card.
        Dispatcher.Dispatch(() => _MainScroll_.ScrollToAsync(_ResultCard_, ScrollToPosition.Start, true));
        SemanticScreenReader.Announce("Ваше путешествие: сводка готова");
    }

    private string? ValidateForm(out decimal budget)
    {
        budget = 0;
        if (string.IsNullOrWhiteSpace(_NameEntry_.Text))
            return "Введите имя путешественника.";
        if (string.IsNullOrWhiteSpace(_BudgetEntry_.Text))
            return "Укажите бюджет на путешествие в рублях.";
        if (!TryParseBudget(_BudgetEntry_.Text, out budget))
            return "Бюджет должен быть числом больше нуля, например 120 000 или 120000,50 (до двух знаков после запятой).";
        if (_StartDatePicker_.Date is null)
            return "Выберите дату начала поездки.";
        return null;
    }

    private string BuildSummary(decimal budget)
    {
        string holidayType = new[] { _BeachRadio_, _SightseeingRadio_, _ActiveRadio_ }
            .FirstOrDefault(radio => radio.IsChecked)?.Value?.ToString() ?? "Не выбрано";
        string country = _CountryPicker_.SelectedItem?.ToString() ?? "Не выбрано";
        string wishes = string.IsNullOrWhiteSpace(_WishesEditor_.Text)
            ? "Не указаны" : _WishesEditor_.Text.Trim();
        string budgetFormat = budget == decimal.Truncate(budget) ? "N0" : "N2";
        static string YesNo(bool value) => value ? "Да" : "Нет";

        return $"Имя: {_NameEntry_.Text?.Trim()}\n"
            + $"Бюджет: {budget.ToString(budgetFormat, RussianCulture)} ₽\n"
            + $"Страна: {country}\n"
            + $"Тип отдыха: {holidayType}\n"
            + $"Экскурсии: {YesNo(_ExcursionsCheck_.IsChecked)}\n"
            + $"Питание в отеле: {YesNo(_MealsCheck_.IsChecked)}\n"
            + $"Всё включено: {YesNo(_AllInclusiveSwitch_.IsToggled)}\n"
            + $"Дата начала: {_StartDatePicker_.Date?.ToString("dd.MM.yyyy", RussianCulture)}\n"
            + $"Длительность: {FormatDays(RoundDuration(_DurationSlider_.Value))}\n"
            + $"Пожелания: {wishes}";
    }

    private async void OnClearClicked(object? sender, EventArgs e)
    {
        _isUpdating = true;
        try
        {
            _NameEntry_.Text = string.Empty;
            _BudgetEntry_.Text = string.Empty;
            _WishesEditor_.Text = string.Empty;
            _CountryPicker_.SelectedIndex = -1;
            _BeachRadio_.IsChecked = false;
            _SightseeingRadio_.IsChecked = false;
            _ActiveRadio_.IsChecked = false;
            _ExcursionsCheck_.IsChecked = false;
            _MealsCheck_.IsChecked = false;
            _AllInclusiveSwitch_.IsToggled = false;
            _StartDatePicker_.Date = InitialTravelDate;
            _DurationSlider_.Value = 7;
            _ResultCard_.IsVisible = false;
            _ResultLabel_.Text = string.Empty;
            _ValidationLabel_.IsVisible = false;
            _ValidationLabel_.Text = string.Empty;
        }
        finally
        {
            _isUpdating = false;
        }

        UpdateReadiness();
        _NameEntry_.Unfocus();
        _BudgetEntry_.Unfocus();
        _WishesEditor_.Unfocus();
        await _MainScroll_.ScrollToAsync(0, 0, true);
    }
}
