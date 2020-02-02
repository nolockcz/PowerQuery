# The Last Timestamp of Loading Data

You know that, too. A user calls you and asks when a dataset has been updated for the last time. What do you answer?

I also had this problem but that is over now. And it will become only a memory for you, as well, if you read this article and implement the last timestamp of loading data into your dataset.

Let’s go through all possible solutions and let’s start with DAX. Neither DAX measure nor DAX calculated column are suitable for getting the last timestamp of loading data because they know nothing about when the data were loaded. A calculated column value is changed every time you open the PBIX file or you click on Refresh. And a measure is changed even when a visual using this measure is refreshed.

An example of a measure / calculated column: DAX Now = NOW()
![IMG](https://github.com/nolockcz/PowerQuery/raw/master/The%20Last%20Timestamp%20of%20Loading%20Data/readme%20images/1.PNG)
 

When I publish a PBIX file with DAX Now to Power BI Service, the time is in UTC and not in my local time zone.
![IMG](https://github.com/nolockcz/PowerQuery/raw/master/The%20Last%20Timestamp%20of%20Loading%20Data/readme%20images/2.PNG)

## PowerQuery
Well, DAX is not a solution. The other option is PowerQuery. A PowerQuery query is called every time when our dataset is refreshed. That is a good start. A PowerQuery has a plenty of [date](https://docs.microsoft.com/en-us/powerquery-m/date-functions), [time](https://docs.microsoft.com/en-us/powerquery-m/time-functions), [datetime](https://docs.microsoft.com/en-us/powerquery-m/datetime-functions), and [datetimezone](https://docs.microsoft.com/en-us/powerquery-m/datetimezone-functions) functions. There must be something what can show us the local timestamp at the moment of refreshing dataset. There is the function [DateTime.LocalNow()](https://docs.microsoft.com/en-us/powerquery-m/datetime-localnow). It returns a timestamp in the local time zone and it works fine if your PBIX file is refreshed only on your desktop. But if you publish it to the Power BI Service, you will see that the time is in UTC. No, not again. There must be something else.

Well, there isn’t. We have to write our own code for this purpose.

## Power Query (online version)
The simplest solution is to use a webservice which responses with local time according to your time zone. There are plenty of them on the internet, I’ve used http://worldtimeapi.org/.

```m
let
    // get current datetimezone from web API
    DateTimeApiResult = Json.Document(Web.Contents("http://worldtimeapi.org/api/timezone/Europe/Berlin")),

    // parse datetimezone timestamps from text
    UtcTimestamp = DateTimeZone.FromText(DateTimeApiResult[utc_datetime]),
    LocalTimestamp = DateTimeZone.FromText(DateTimeApiResult[datetime]), 

    Result = #table(
        type table
        [
            #"UTC timestamp" = datetime, 
            #"UTC date" = date,
            #"Local timestamp with offset" = datetimezone,
            #"Local timestamp without offset" = datetime
        ], 
        {
            {
            UtcTimestamp,
            DateTime.Date(UtcTimestamp),
            LocalTimestamp,
            DateTimeZone.RemoveZone(LocalTimestamp)
            }
        }
    )
in
    Result
```

But sometimes you don’t have an internet connection, or there is a policy that denies an access to the public internet. Then, we have to search for another solution.

## Power Query (offline version)
The next solution will be an offline one. It is based on the UTC timestamp because it is the same wherever our dataset is refreshed.

The code is simple and if you think it is too long to read, don’t panic, half of it are comments ;)

```m
let
    StandardOffset = #duration(0, 1, 0, 0),
    DaylightSavingTimeOffset = #duration(0, 2, 0, 0),

    // get start and end of daylight saving time
    // this code implements the rules of EU counties
    // if it does not fill your expectations, visit https://en.wikipedia.org/wiki/Daylight_saving_time_by_country and implement your own function
    fnDaylightSavingTimePeriod = (
        now as datetime
    ) as record => 
        let
            // the daylight saving time starts on the last Sunday of March at 1am UTC
            LastDayOfMarch = #date(Date.Year(now), 3, 31),
            StartOfDaylightSavingTime = Date.AddDays(LastDayOfMarch, -Date.DayOfWeek(LastDayOfMarch, Day.Sunday)) & #time(1, 0, 0),
            // the daylight saving time ends on the last Sunday in October at 1am UTC
            LastDayOfOctober = #date(Date.Year(now), 10, 31),
            EndOfDaylightSavingTime = Date.AddDays(LastDayOfOctober, -Date.DayOfWeek(LastDayOfOctober, Day.Sunday)) & #time(1, 0, 0)
        in
            [From = StartOfDaylightSavingTime, To = EndOfDaylightSavingTime],

    // get a timestamp in UTC (with offset 00:00 all year long)
    UtcNow = DateTimeZone.UtcNow(),
    // convert UTC datetime with offset to datetime
    UtcNowWithoutZone = DateTimeZone.RemoveZone(UtcNow),

    // get daylight saving time period
    DaylightSavingTimePeriod = fnDaylightSavingTimePeriod(UtcNowWithoutZone),

    // convert UTC time to the local time with respect to current offset
    LocalTimeWithOffset = 
        if UtcNowWithoutZone >= DaylightSavingTimePeriod[From] and UtcNowWithoutZone < DaylightSavingTimePeriod[To] then
            DateTimeZone.SwitchZone(
                UtcNow, 
                Duration.Hours(DaylightSavingTimeOffset), 
                Duration.Minutes(DaylightSavingTimeOffset)
            )
        else
            DateTimeZone.SwitchZone(
                UtcNow, 
                Duration.Hours(StandardOffset), 
                Duration.Minutes(StandardOffset)
            ),
    
    // current date time without offset
    LocalTime = DateTimeZone.RemoveZone(LocalTimeWithOffset),

    // result table
    Result = #table(
        type table
        [
            #"UTC timestamp" = datetime, 
            #"UTC date" = date,
            #"Local timestamp with offset" = datetimezone,
            #"Local timestamp without offset" = datetime
        ], 
        {
            {
            UtcNowWithoutZone,
            DateTime.Date(UtcNowWithoutZone),
            LocalTimeWithOffset,
            LocalTime
            }
        }
    )
in
    Result
```

The only advanced thing is calculating the start and the end date of the DST (daylight saving time). The DST starts in EU on the last Sunday of March at 2 am and ends on the last Sunday of October at 3 am. If you have other rules in your country, you have to implement your own fnDaylightSavingTimePeriod function. This Wikipedia link https://en.wikipedia.org/wiki/Daylight_saving_time_by_country can help you do that.

 

The result is a table with one row which contains following columns:
```m
#"UTC timestamp" = datetime, 
#"UTC date" = date,
#"Local timestamp with offset" = datetimezone,
#"Local timestamp without offset" = datetime
```

And a screenshot of the result table:
![IMG](https://github.com/nolockcz/PowerQuery/raw/master/The%20Last%20Timestamp%20of%20Loading%20Data/readme%20images/3.PNG)

 

I always concentrate on the customer centricity and therefore my datasets do not only contain a well formatted timestamp of the last refresh, but also a text with a count of the days since the last refresh.
![IMG](https://github.com/nolockcz/PowerQuery/raw/master/The%20Last%20Timestamp%20of%20Loading%20Data/readme%20images/4.PNG)

 
By the way, the brand-new Power BI Service design contains also a timestamp of the last refresh which is very handy :)
![IMG](https://github.com/nolockcz/PowerQuery/raw/master/The%20Last%20Timestamp%20of%20Loading%20Data/readme%20images/5.PNG)

However, you could say that the article has become obsolete because of the new Power BI Service design feature, I say it hasn’t. If you still need a timestamp of last refresh visible in your report, you don’t have any other option.

## The original blog post
The code is a part of a blog post: https://community.powerbi.com/t5/Community-Blog/The-Last-Timestamp-of-Loading-Data/ba-p/760805
