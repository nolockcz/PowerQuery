let
    /*****
        Date Dimension Extended.pq
        Author: Michal Dvorak (Nolock)
        Created: June 2019
    *****/

    /***** Params *****/
    // Start year of date dim table
    StartYear = 2000,
    // End year of date dim table
    EndYear = 2039,   

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
    DayOfMonth = Table.AddColumn(MonthNameYear, "DayOfMonth", each Date.Day([Date]), Int32.Type),
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

    /***** Years, Months, Weeks, and Days backwards *****/
    YearBackwards = Table.AddColumn(IsoYearWeekIndex, "YearBackwards", each Date.Year(DateTime.LocalNow()) - [Year], Int32.Type),
    QuartersBackwards = Table.AddColumn(YearBackwards, "QuartersBackwards", each (Date.Year(DateTime.LocalNow()) * 4 + Date.QuarterOfYear(DateTime.LocalNow())) - ([Year] * 4 + Date.QuarterOfYear([Date])), Int32.Type),    
    MonthsBackwards = Table.AddColumn(QuartersBackwards, "MonthsBackwards", each (Date.Year(DateTime.LocalNow()) * 12 + Date.Month(DateTime.LocalNow())) - ([Year] * 12 + [Month]), Int32.Type),    
    TempYearWeek = Table.AddColumn(MonthsBackwards, "TempYearWeek", each [Year]*100+[WeekOfYear]),    
    WeekCountHelpTable = 
        // create a date table with a week counter
        let                        
            WeekCountHelpTable_YearWeek = Table.AddColumn(DateColumnAsDate, "WeekCountHelpTable_YearWeek", each Date.Year([Date]) * 100 + Date.WeekOfYear([Date])),
            WeekCountHelpTable_YearWeekDistinct = Table.Distinct(WeekCountHelpTable_YearWeek, {"WeekCountHelpTable_YearWeek"}),
            WeekCountHelpTable_WeekCounter = Table.AddIndexColumn(WeekCountHelpTable_YearWeekDistinct, "WeekCountHelpTable_WeekCounter", 0, 1),            
            WeekCountHelpTable_IsCurrentWeek = Table.AddColumn(WeekCountHelpTable_WeekCounter, "WeekCountHelpTable_IsCurrentWeek", each Date.IsInCurrentWeek([Date]), type logical),
            WeekCountHelpTable_ChangeType = Table.TransformColumnTypes(WeekCountHelpTable_IsCurrentWeek,{{"WeekCountHelpTable_WeekCounter", Int64.Type}})
        in
            WeekCountHelpTable_ChangeType,
    // join dim date table with WeekCountHelpTable
    JoinWithWeekCountHelpTable = Table.NestedJoin(TempYearWeek,{"TempYearWeek"},WeekCountHelpTable,{"WeekCountHelpTable_YearWeek"},"WeekCountHelpTable", JoinKind.LeftOuter),    
    ExpandWeekCountHelpTable = Table.ExpandTableColumn(JoinWithWeekCountHelpTable, "WeekCountHelpTable", {"WeekCountHelpTable_WeekCounter", "WeekCountHelpTable_IsCurrentWeek"}, {"TempWeekCountHelpTable_WeekCounter", "TempWeekCountHelpTable_IsCurrentWeek"}),
    TempCurrentWeekFirstRow = Table.AddColumn(ExpandWeekCountHelpTable, "TempCurrentWeekFirstRow", each Table.SelectRows(WeekCountHelpTable, each ([WeekCountHelpTable_IsCurrentWeek] = true)){0}),
    TempWeekCounterOfToday = Table.ExpandRecordColumn(TempCurrentWeekFirstRow, "TempCurrentWeekFirstRow", {"WeekCountHelpTable_WeekCounter"}, {"TempWeekCounterOfToday"}),
    WeeksBackwards = Table.AddColumn(TempWeekCounterOfToday, "WeeksBackwards", each [TempWeekCounterOfToday] - [TempWeekCountHelpTable_WeekCounter], Int32.Type),
    RemoveTempColumns = Table.RemoveColumns(WeeksBackwards,{"TempYearWeek", "TempWeekCountHelpTable_WeekCounter", "TempWeekCountHelpTable_IsCurrentWeek", "TempWeekCounterOfToday"}),
    DaysBackwards = Table.AddColumn(RemoveTempColumns, "DaysBackwards", each Duration.Days(Duration.From(DateTime.Date(DateTime.LocalNow()) - [Date])), Int32.Type),

    /***** Holidays *****/
    // get a list of years and all holidays in that years
    fnGetAllHolidaysOfAYear = (year as number) as list => 
        let 
            // get a date of Easter Sunday (Source: https://en.wikipedia.org/wiki/Computus)
            EasterSundayFunc = (year as number) as date =>
                let 
                    a = Number.Mod(year, 19),
                    b = Number.RoundDown(year / 100),
                    c = Number.Mod(year, 100),
                    d = Number.RoundDown(b / 4),
                    e = Number.Mod(b, 4),
                    f = Number.RoundDown((b + 8) / 25),
                    g = Number.RoundDown((b - f + 1) / 3),
                    h = Number.Mod((19 * a + b - d - g + 15), 30),
                    i = Number.RoundDown(c / 4),
                    k = Number.Mod(c, 4),
                    l = Number.Mod((32 + 2 * e + 2 * i - h - k), 7),
                    m = Number.RoundDown((a + 11 * h + 22 * l) / 451),
                    n = Number.RoundDown((h + l - 7 * m + 114) / 31),
                    p = Number.Mod((h + l - 7 * m + 114), 31) + 1,
                    dt = #date(year, n, p)
                in
                    dt,

            EasterSunday = EasterSundayFunc(year),

            CurrentYearHolidaysList = {
                // NewYear = always January 1st
                [Date = #date(year, 1, 1), HolidayName = "Neujahr"],
                
                // Epiphany = always January 6th
                [Date = #date(year, 1, 6), HolidayName = "Heilige Drei Könige"],

                // GoodFriday = 2 days before Easter Sunday 
                [Date = Date.AddDays(EasterSunday, -2), HolidayName = "Karfreitag"],

                // EasterMonday = 1 day after Easter Sunday
                [Date = Date.AddDays(EasterSunday, 1), HolidayName = "Ostermontag"],

                // LabourDay = always Mai 1st
                [Date = #date(year, 5, 1), HolidayName = "Tag der Arbeit"],

                // AscensionDay = 39 days after Easter Sunday
                [Date = Date.AddDays(EasterSunday, 39), HolidayName = "Christi Himmelfahrt"],
            
                // WhitMonday = 50 days after Easter Sunday
                [Date = Date.AddDays(EasterSunday, 50), HolidayName = "Pfingstmontag"],
            
                // CorpusChristi = 60 days after Easter Sunday
                [Date = Date.AddDays(EasterSunday, 60), HolidayName = "Fronleichnam"],

                // GermanUnityDay = always October 3rd
                [Date = #date(year, 10, 3), HolidayName = "Tag der Deutschen Einheit"],

                // AllSaintsDay = always November 1st
                [Date = #date(year, 11, 1), HolidayName = "Allerheiligen"],

                // ChristmasEve = always December 24th
                [Date = #date(year, 12, 24), HolidayName = "Heiligabend"],

                // ChristmasDay = always December 25th
                [Date = #date(year, 12, 25), HolidayName = "1. Weihnachtstag"],

                // StStephensDay = always December 26th
                [Date = #date(year, 12, 26), HolidayName = "2. Weihnachtstag"],

                // Silvester = always December 31st
                [Date = #date(year, 12, 31), HolidayName = "Silvester"]
            }
        in
            CurrentYearHolidaysList,

    // get a table of all holidays
    fnGetAllHolidaysTable = (startYear as number, endYear as number) as table =>
        let
            // a list of years starting one year before actual start
            yearList = {startYear-1..endYear},
            holidayYearList = List.Transform(yearList, fnGetAllHolidaysOfAYear),
            holidaysYearListAsTable = Table.FromList(holidayYearList, Splitter.SplitByNothing(), null, null, ExtraValues.Error),
            expandList = Table.ExpandListColumn(holidaysYearListAsTable, "Column1"),
            holidaysTable = Table.ExpandRecordColumn(expandList, "Column1", {"Date", "HolidayName"}, {"HolidayDate", "HolidayName"})
        in
            holidaysTable,
    AllHolidaysTable = fnGetAllHolidaysTable(StartYear, EndYear),

    // join the date table with AllHolidaysTable
    JoinHolidaysTable = Table.Join(DaysBackwards, "Date", AllHolidaysTable, "HolidayDate", JoinKind.LeftOuter),
    // remove the column HolidayDate coming from join
    RemoveHolidayDate = Table.RemoveColumns(JoinHolidaysTable, "HolidayDate"),

    /***** Holiday, weekend, working day flags *****/
    // is a holiday
    IsHoliday = Table.AddColumn(RemoveHolidayDate, "IsHoliday", each [HolidayName] <> null, type logical),
    // is a weekend day
    IsWeekend = Table.AddColumn(IsHoliday, "IsWeekend", each Date.DayOfWeek([Date]) >= 5, type logical),
    // is a working day
    IsWorkingDay = Table.AddColumn(IsWeekend, "IsWorkingDay", each not [IsHoliday] and not [IsWeekend], type logical),
    
    // sort the table by date
    SortByDate = Table.Sort(IsWorkingDay, {"Date"}),  

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
            {"DayOfMonth", "Monatstag"}, 
            {"DayOfYear", "Jahrestag"}, 
            {"WeekOfYear", "Jahreswoche"}, 
            {"DayOfWeek", "Wochentag"}, 
            {"DayOfWeekName", "Wochentagsname"}, 
            {"DayOfWeekNameAbbreviated", "Wochentagsname gekürzt"}, 
            {"IsoYearWeek", "ISO Woche"}, 
            {"IsoYearWeekIndex", "ISO Woche Index"}, 
            {"YearBackwards", "Jahre rückliegend"}, 
            {"QuartersBackwards", "Quartale rückliegend"}, 
            {"MonthsBackwards", "Monate rückliegend"}, 
            {"WeeksBackwards", "Wochen rückliegend"}, 
            {"DaysBackwards", "Tage rückliegend"}, 
            {"IsWeekend", "Ist Wochenende"}, 
            {"HolidayName", "Feiertagsname"}, 
            {"IsHoliday", "Ist Feiertag"}, 
            {"IsWorkingDay", "Ist Arbeitstag"}
        }
    )
in
    ColumnTranslation