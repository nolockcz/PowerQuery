let
    /*****
        Date Dimension Core.pq
        Author: Michal Dvorak (Nolock)
        Created: June 2019
        Updated:
            August 2020
                - Added MonthNameAbbreviatedYear (i.e. Jan 2020)
                - Added FiscalMonth and FiscalYearMonth
                - Added Is13MonthsBackwards
                - Added LastWorkingDate
                - Added IsLastWorkingDate
                - Added IsCurrentBillingMonth
                - Bugfix for the date 1.5.2008 (two holidays are celebrated on this date which produces 2 rows for one day)
    *****/

    /***** Params *****/
    // Start year of date dim table
    StartYear = 2000,
    // End year of date dim table
    EndYear = 2039,
    // Is a holiday on the Christmas Eve
    IsChristmasEveHoliday = true,
    // Is a holiday on the New Year's Eve
    IsNewYearsEveHoliday = true,
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
    YearBackwards = Table.AddColumn(FiscalYearMonth, "YearBackwards", each Date.Year(DateTime.LocalNow()) - [Year], Int32.Type),
    QuartersBackwards = Table.AddColumn(YearBackwards, "QuartersBackwards", each (Date.Year(DateTime.LocalNow()) * 4 + Date.QuarterOfYear(DateTime.LocalNow())) - ([Year] * 4 + Date.QuarterOfYear([Date])), Int32.Type),    
    MonthsBackwards = Table.AddColumn(QuartersBackwards, "MonthsBackwards", each (Date.Year(DateTime.LocalNow()) * 12 + Date.Month(DateTime.LocalNow())) - ([Year] * 12 + [Month]), Int32.Type),    
    Is13MonthsBackwards = Table.AddColumn(MonthsBackwards, "Is13MonthsBackwards", each [MonthsBackwards] >= 1 and [MonthsBackwards] <= 13, type logical),

    TempYearWeek = Table.AddColumn(Is13MonthsBackwards, "TempYearWeek", each [Year]*100+[WeekOfYear]),    
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

    // get a record containing holiday name, isWeekend, and isWorkingDay for a date
    HolidayFunc = (dt as date) as record => 
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

            EasterSunday = EasterSundayFunc(Date.Year(dt)),            

            // NewYear = always January 1st
            NewYear = 
                if Date.Month(dt) = 1 and Date.Day(dt) = 1 
                then [HolidayName = "Neujahr", IsHoliday = true]
                else null,
            // Epiphany = always January 6th
            Epiphany = 
                if Date.Month(dt) = 1 and Date.Day(dt) = 6 
                then [HolidayName = "Heilige Drei Könige", IsHoliday = true]
                else null,

            // GoodFriday = 2 days before Easter Sunday
            GoodFriday = 
                if dt = Date.AddDays(EasterSunday, -2)
                then [HolidayName = "Karfreitag", IsHoliday = true]
                else null,

            // EasterMonday = 1 day after Easter Sunday
            EasterMonday  = 
                if dt = Date.AddDays(EasterSunday, 1)
                then [HolidayName = "Ostermontag", IsHoliday = true]
                else null,

            // LabourDay = always Mai 1st
            LabourDay =
                if Date.Month(dt) = 5 and Date.Day(dt) = 1 
                then [HolidayName = "Tag der Arbeit", IsHoliday = true]
                else null,

            // AscensionDay = 39 days after Easter Sunday
            AscensionDay  = 
                if dt = Date.AddDays(EasterSunday, 39)
                then [HolidayName = "Christi Himmelfahrt", IsHoliday = true]
                else null,
            
            // WhitMonday = 50 days after Easter Sunday
            WhitMonday  = 
                if dt = Date.AddDays(EasterSunday, 50)
                then [HolidayName = "Pfingstmontag", IsHoliday = true]
                else null,
            
            // CorpusChristi = 60 days after Easter Sunday
            CorpusChristi   = 
                if dt = Date.AddDays(EasterSunday, 60)
                then [HolidayName = "Fronleichnam", IsHoliday = true]
                else null,

            // GermanUnityDay = always October 3rd
            GermanUnityDay =
                if Date.Month(dt) = 10 and Date.Day(dt) = 3 
                then [HolidayName = "Tag der Deutschen Einheit", IsHoliday = true]
                else null,

            // AllSaintsDay = always November 1st
            AllSaintsDay =
                if Date.Month(dt) = 11 and Date.Day(dt) = 1 
                then [HolidayName = "Allerheiligen", IsHoliday = true]
                else null,

            // ChristmasEve = always December 24th
            ChristmasEve =
                if Date.Month(dt) = 12 and Date.Day(dt) = 24 and IsChristmasEveHoliday
                then [HolidayName = "Heiligabend", IsHoliday = true]
                else null,

            // ChristmasDay = always December 25th
            ChristmasDay =
                if Date.Month(dt) = 12 and Date.Day(dt) = 25 
                then [HolidayName = "1. Weihnachtstag", IsHoliday = true]
                else null,

            // StStephensDay = always December 26th
            StStephensDay =
                if Date.Month(dt) = 12 and Date.Day(dt) = 26 
                then [HolidayName = "2. Weihnachtstag", IsHoliday = true]
                else null,

            // Silvester = always December 31st
            NewYearsEve =
                if Date.Month(dt) = 12 and Date.Day(dt) = 31 and IsNewYearsEveHoliday
                then [HolidayName = "Silvester", IsHoliday = true]
                else null,

            HolidayRecord = 
                if      NewYear         <> null then NewYear
                else if Epiphany        <> null then Epiphany
                else if GoodFriday      <> null then GoodFriday
                else if EasterMonday    <> null then EasterMonday
                else if LabourDay       <> null then LabourDay
                else if AscensionDay    <> null then AscensionDay
                else if WhitMonday      <> null then WhitMonday
                else if CorpusChristi   <> null then CorpusChristi
                else if GermanUnityDay  <> null then GermanUnityDay
                else if AllSaintsDay    <> null then AllSaintsDay
                else if ChristmasEve    <> null then ChristmasEve
                else if ChristmasDay    <> null then ChristmasDay
                else if StStephensDay   <> null then StStephensDay
                else if NewYearsEve     <> null then NewYearsEve
                else [HolidayName = null, IsHoliday = false],

            IsWeekend = Date.DayOfWeek(dt, Day.Monday) >= 5
        in 
            [
                HolidayName = HolidayRecord[HolidayName], 
                IsHoliday = HolidayRecord[IsHoliday], 
                IsWeekend = IsWeekend, 
                IsWorkingDay = HolidayRecord[IsHoliday] = false and IsWeekend = false
            ],

    HolidayRecord = Table.AddColumn(DaysBackwards, "HolidayRecord", each HolidayFunc([Date])),
    ExpandHolidayRecord = Table.ExpandRecordColumn(HolidayRecord, "HolidayRecord", {"HolidayName", "IsHoliday", "IsWeekend", "IsWorkingDay"}),  
    ChangeHolidayRecordTypes = Table.TransformColumnTypes(ExpandHolidayRecord,{{"HolidayName", type text}, {"IsHoliday", type logical}, {"IsWeekend", type logical}, {"IsWorkingDay", type logical}}), 
    
    // calculate the last working date before a date
    LastWorkingDateFunc = (holidays as record, dt as date) as date =>
        let
            MaxCountOfHolidaysInRow = 6, // Sa, Sun, Mo(24.12.), Tue(25.12.), Wed(26.12.)
            // get a list of descending dates starting on yesterday
            ListOfLastDatesDescending = List.Dates(Date.AddDays(dt, -1), MaxCountOfHolidaysInRow, #duration(-1,0,0,0)),
            // select only those which aren't in the record with holidays
            ListOfLastDatesWithoutHoliday = List.Select(ListOfLastDatesDescending, each not Record.HasFields(holidays, Date.ToText(_, "dd.MM.yyyy"))),
            // take only the first element of descending list - last working date
            LastWorkingDate = List.First(ListOfLastDatesWithoutHoliday)
        in
            LastWorkingDate,
    
    // a record containing all not-working days in a form of a look-up table
    NotWorkingDaysTempRecord = 
        let
            StartDate = #date(StartYear - 1, 1, 1),
            EndDate = #date(EndYear, 12, 31),
            NumberOfDays = Duration.Days( EndDate - StartDate ),
            ListOfDates = List.Dates(StartDate, NumberOfDays+1, #duration(1,0,0,0)),
            DatesAsTable = Table.FromList(ListOfDates, Splitter.SplitByNothing(), {"Date"}, null, ExtraValues.Error),
            DateColumnAsDate = Table.TransformColumnTypes(DatesAsTable,{{"Date", type date}}),
            HolidayRecord = Table.AddColumn(DateColumnAsDate, "HolidayRecord", each HolidayFunc([Date])),
            ExpandHolidayRecord = Table.ExpandRecordColumn(HolidayRecord, "HolidayRecord", {"IsWorkingDay"}),
            OnlyHolidaysDays = Table.SelectRows(ExpandHolidayRecord, each not [IsWorkingDay]),
            DateAsListBuffered = List.Buffer(OnlyHolidaysDays[Date]),
            DateAsRecord = List.Accumulate(
                DateAsListBuffered,
                [],
                (state, current) => 
                    state & 
                    Expression.Evaluate(
                        "[" & Date.ToText(current, "dd.MM.yyyy") & "= true]", 
                        [current = current]
                    )
            )
        in
            DateAsRecord,

    // get the last working day before today (like on Sa, Su, and Mo it is Friday if Friday was a working day)
    LastWorkingDate = Table.AddColumn(ChangeHolidayRecordTypes, "LastWorkingDate", each LastWorkingDateFunc(NotWorkingDaysTempRecord, [Date]), type date),

    // is last working date?
    LastWorkingDayOfToday = LastWorkingDateFunc(NotWorkingDaysTempRecord, DateTime.Date(DateTime.LocalNow())),
    IsLastWorkingDate = Table.AddColumn(LastWorkingDate, "IsLastWorkingDate", each [Date] = LastWorkingDayOfToday, type logical),

    // is current billing month?   
    IsCurrentBillingMonthFunc = (dt as date, lastWorkingDt as date) as logical =>
        let            
            result = 
                Date.Year(dt) = Date.Year(lastWorkingDt) and 
                Date.Month(dt) = Date.Month(lastWorkingDt) and 
                dt <= lastWorkingDt
        in
            result,
    IsCurrentBillingMonth = Table.AddColumn(IsLastWorkingDate, "IsCurrentBillingMonth", each IsCurrentBillingMonthFunc([Date], LastWorkingDayOfToday), type logical),
    
    /***** Transform column data types *****/
    // use data type text for Year, Month, and IsoYearWeek because it prevents the automatical summarization in PowerBI Desktop
    TransformNumberToText = Table.TransformColumnTypes(IsCurrentBillingMonth,{{"Year", type text}, {"Month", type text}, {"IsoYearWeek", type text}}),    

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
            {"DaysBackwards", "Tage rückliegend"}, 
            {"IsWeekend", "Ist Wochenende"},
            {"HolidayName", "Feiertagsname"}, 
            {"IsHoliday", "Ist Feiertag"}, 
            {"IsWorkingDay", "Ist Arbeitstag"}, 
            {"LastWorkingDate", "Letzter Arbeitstag"}, 
            {"IsLastWorkingDate", "Ist letzter Arbeitstag"}, 
            {"IsCurrentBillingMonth", "Ist aktueller Abrechnungsmonat"}
        }
    )
in
    ColumnTranslation