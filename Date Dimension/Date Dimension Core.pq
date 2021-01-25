let
    /*****
        Date Dimension Core.pq
        Author: Michal Dvorak (@nolockcz)
        Created: June 2019
        Updated:
            August 2020
                - Added MonthNameAbbreviatedYear (i.e. Jan 2020)
                - Added FiscalMonth and FiscalYearMonth
                - Added Is13MonthsBackwards
                - Bugfix for the date 1.5.2008 (two holidays are celebrated on this date which produces 2 rows for one day)
            January 2021
                - Bugfix: WeeksBackwards calculated wrong every 5 to 6 years
    *****/

    /***** Params *****/
    // Start year of date dim table
    StartYear = 2000,
    // End year of date dim table
    EndYear = 2039,
    /***** End of Params *****/

    /***** Table with one date column *****/
    StartDate = #date(StartYear, 1, 1),
    EndDate = #date(EndYear, 12, 31),
    NumberOfDays = Duration.Days( EndDate - StartDate ),
    ListOfDates = List.Dates(StartDate, NumberOfDays+1, #duration(1,0,0,0)),
    DatesAsTable = Table.FromList(ListOfDates, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),
    DateColumnAsDate = Table.TransformColumnTypes(DatesAsTable,{{"Date", type date}}),

    /***** Date properties *****/
    Year = Table.AddColumn(DateColumnAsDate, "Year", each Date.Year([Date]), type number),
    HalfYear = Table.AddColumn(Year, "HalfYear", each (if Date.QuarterOfYear([Date]) <= 2 then "H1" else "H2"), type text),
    YearHalfYear = Table.AddColumn(HalfYear, "YearHalfYear", each Number.ToText([Year]) & [HalfYear], type text),
    Quarter = Table.AddColumn(YearHalfYear, "Quarter", each "Q" & Number.ToText(Date.QuarterOfYear([Date])), type text),
    YearQuarter = Table.AddColumn(Quarter, "YearQuarter", each Number.ToText([Year]) & [Quarter], type text),
    Month = Table.AddColumn(YearQuarter, "Month", each Date.Month([Date]), type number),
    MonthTwoDigits = Table.AddColumn(Month, "MonthTwoDigits", each Date.ToText([Date], "MM"), type text),
    YearMonth = Table.AddColumn(MonthTwoDigits, "YearMonth", each Date.ToText([Date], "yyyyMM"), type text),
    MonthName = Table.AddColumn(YearMonth, "MonthName", each Date.ToText([Date], "MMMM"), type text),
    MonthNameAbbreviated = Table.AddColumn(MonthName, "MonthNameAbbreviated", each Date.ToText([Date], "MMM"), type text),
    MonthNameYear = Table.AddColumn(MonthNameAbbreviated, "MonthNameYear", each Date.ToText([Date], "MMMM yyyy"), type text),
    MonthNameAbbreviatedYear = Table.AddColumn(MonthNameYear, "MonthNameAbbreviatedYear", each Date.ToText([Date], "MMM yyyy"), type text),
    DayOfMonth = Table.AddColumn(MonthNameAbbreviatedYear, "DayOfMonth", each Date.Day([Date]), Int32.Type),
    DayOfYear = Table.AddColumn(DayOfMonth, "DayOfYear", each Date.DayOfYear([Date]), Int32.Type),
    WeekOfYear = Table.AddColumn(DayOfYear, "WeekOfYear", each Date.WeekOfYear([Date]), Int32.Type),
    DayOfWeek = Table.AddColumn(WeekOfYear, "DayOfWeek", each Date.DayOfWeek([Date], Day.Monday) + 1, Int32.Type),
    DayOfWeekName = Table.AddColumn(DayOfWeek, "DayOfWeekName", each Date.DayOfWeekName([Date]), type text),
    DayOfWeekNameAbbreviated = Table.AddColumn(DayOfWeekName, "DayOfWeekNameAbbreviated", each Date.ToText([Date], "ddd"), type text),

    /***** ISO week *****/
    IsoYearWeekFunc = (currentDate as date) as number => 
        let            
            // Inspired by: http://datacornering.com/how-to-calculate-iso-week-number-in-power-query/            
            DayOfYearOfStartOfWeekFunc = (dt as date) => Date.DayOfYear(dt) - (Date.DayOfWeek(dt, Day.Monday) + 1),            
            WeekNumOfYearFunc = (dateDiff as number) => Number.RoundDown((dateDiff + 10) / 7),
            WeekNumOfYear = WeekNumOfYearFunc(DayOfYearOfStartOfWeekFunc(currentDate)),
            DayOfWeekOfEndOfYear = Date.DayOfWeek(Date.EndOfYear(currentDate), Day.Monday) + 1,            
            EndOfLastYear = Date.EndOfYear(Date.AddYears(currentDate, -1)),
            LocalThursday = 4,
            IsoWeek =             
                if WeekNumOfYear = 0
                    then WeekNumOfYearFunc(DayOfYearOfStartOfWeekFunc(EndOfLastYear))
                else if WeekNumOfYear = 53 and DayOfWeekOfEndOfYear < LocalThursday
                    then 1
                else 
                    WeekNumOfYear,
            // if IsoWeek is 52 or 53, but it's January, then IsoWeek belongs to the previous year
            IsoYear = 
                if (IsoWeek >= 52 and Date.Month(currentDate) = 1) 
                then Date.Year(currentDate) - 1 
                else Date.Year(currentDate)
        in 
            IsoYear * 100 + IsoWeek,
    IsoYearWeek = Table.AddColumn(DayOfWeekNameAbbreviated, "IsoYearWeek", each IsoYearWeekFunc([Date]), Int32.Type),
    IsoYearWeekIndex = Table.AddColumn(IsoYearWeek, "IsoYearWeekIndex", each Number.RoundDown([IsoYearWeek] / 100) * 53 + Number.Mod([IsoYearWeek], 100), Int32.Type),

    FiscalMonth = Table.AddColumn(IsoYearWeekIndex, "FiscalMonth", each if [Month] >= 7 then [Month] - 6 else [Month] + 6, type number),
    FiscalYearMonth = Table.AddColumn(FiscalMonth, "FiscalYearMonth", each Text.From([Year] * 100 + [FiscalMonth]), type text),

    /***** Years, Months, Weeks, and Days backwards *****/
    Today = DateTime.Date(DateTime.LocalNow()),
    YearBackwards = Table.AddColumn(FiscalYearMonth, "YearBackwards", each Date.Year(Today) - [Year], Int32.Type),
    QuartersBackwards = Table.AddColumn(YearBackwards, "QuartersBackwards", each (Date.Year(Today) * 4 + Date.QuarterOfYear(Today)) - ([Year] * 4 + Date.QuarterOfYear([Date])), Int32.Type),    
    MonthsBackwards = Table.AddColumn(QuartersBackwards, "MonthsBackwards", each (Date.Year(Today) * 12 + Date.Month(Today)) - ([Year] * 12 + [Month]), Int32.Type),    
    Is13MonthsBackwards = Table.AddColumn(MonthsBackwards, "Is13MonthsBackwards", each [MonthsBackwards] >= 1 and [MonthsBackwards] <= 13, type logical),
    DaysBackwards = Table.AddColumn(Is13MonthsBackwards, "DaysBackwards", each Duration.Days(Duration.From(Today - [Date])), Int32.Type),
    WeeksBackwards = Table.AddColumn(
        DaysBackwards, 
        "WeeksBackwards", 
        each 
            if [DaysBackwards] > 0 then 
                Number.RoundDown(
                    ([DaysBackwards] - (Date.DayOfWeek(Today, Day.Monday) + 1)) / 7 + 1,
                    0
                ) 
            else if [DaysBackwards] = 0 then
                0
            else
                Number.RoundDown(
                    (-[DaysBackwards] - 7 + (Date.DayOfWeek(Today, Day.Monday))) / 7 + 1,
                    0
                ), 
        Int32.Type
    ),

    /***** Transform column data types *****/
    // use data type text for Year, Month, and IsoYearWeek because it prevents the automatical summarization in PowerBI Desktop
    TransformNumberToText = Table.TransformColumnTypes(WeeksBackwards,{{"Year", type text}, {"Month", type text}, {"IsoYearWeek", type text}}),    

    // sort the table by date
    SortByDate = Table.Sort(TransformNumberToText, {"Date"}),    

    /***** Translation of columns to German *****/
    ColumnTranslation = Table.RenameColumns(
        SortByDate,
        {
            {"Date", "Datum"}, 
            {"Year", "Jahr"}, 
            {"HalfYear", "Halbjahr"}, 
            {"YearHalfYear", "Jahr u. Halbjahr"}, 
            {"Quarter", "Quartal"}, 
            {"YearQuarter", "Jahr u. Quartal"}, 
            {"Month", "Monat"}, 
            {"MonthTwoDigits", "Monat (2 Ziffern)"}, 
            {"YearMonth", "Jahr u. Monat"}, 
            {"MonthName", "Monatsname"},
            {"MonthNameAbbreviated", "Monatsname gekürzt"}, 
            {"MonthNameYear", "Monatsname u. Jahr"}, 
            {"MonthNameAbbreviatedYear", "Monatsname gekürzt u. Jahr"}, 
            {"DayOfMonth", "Monatstag"}, 
            {"DayOfYear", "Jahrestag"}, 
            {"WeekOfYear", "Jahreswoche"}, 
            {"DayOfWeek", "Wochentag"}, 
            {"DayOfWeekName", "Wochentagsname"}, 
            {"DayOfWeekNameAbbreviated", "Wochentagsname gekürzt"}, 
            {"IsoYearWeek", "ISO Woche"},
            {"IsoYearWeekIndex", "ISO Woche Index"}, 
            {"FiscalMonth", "Fiskalmonat"}, 
            {"FiscalYearMonth", "Fiskal Jahr u. Monat"}, 
            {"YearBackwards", "Jahre rückliegend"}, 
            {"QuartersBackwards", "Quartale rückliegend"}, 
            {"MonthsBackwards", "Monate rückliegend"}, 
            {"Is13MonthsBackwards", "Ist 13 Monate rückliegend"}, 
            {"WeeksBackwards", "Wochen rückliegend"}, 
            {"DaysBackwards", "Tage rückliegend"}
        }
    )
in
    ColumnTranslation