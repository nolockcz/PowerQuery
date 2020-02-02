# Time Dimension in Power Query

I have developed 2 different time dimensions in Power Query. One is in the 24-hour and the other in the 12-hour format.

A time dimension is very simple in comparison to a [date dimension](https://github.com/nolockcz/PowerQuery/tree/master/Date%20Dimension). A day has 24 hours, an hour 60 minutes, and a minute - 60 seconds. I don’t care about the [leap second](https://en.wikipedia.org/wiki/Leap_second).

## What are seconds good for?

Hmm, seconds. Do we really need them in a time dimension? I don’t think so. A time dimension having the smallest unit one minute contains 24 x 60 = 1440 rows. However, a time dimension which contains also seconds has 86 400 rows. Not only that. We also need this precision in a time column of a fact table. It means that a time column will also contain up to 86 400 unique values and won’t be able to be compressed so well. In my opinion, a granularity of one minute is good enough.

Let’s start with the code. At the beginning we create a table containing every minute of a day. For every minute we extract its hour and minute. Till now nothing spectacular.

```m
/***** Table with one minute column *****/
NumberOfMinutes = 24 * 60,
ListOfMinutes = List.Times(#time(0, 0, 0), NumberOfMinutes, #duration(0, 0, 1, 0)),
MinutesAsTable = Table.FromList(ListOfMinutes, Splitter.SplitByNothing(), {"Time"}, null, ExtraValues.Error),
MinuteColumnAsTime = Table.TransformColumnTypes(MinutesAsTable,{{"Time", type time}}),

/***** Index column *****/
Index = Table.AddColumn(MinuteColumnAsTime, "Index", each Time.Hour([Time]) * 100 + Time.Minute([Time]), Int32.Type),

/***** Hour and minute *****/
Hour = Table.AddColumn(Index, "Hour", each Time.Hour([Time]), Int32.Type),
Minute = Table.AddColumn(Hour, "Minute", each Time.Minute([Time]), Int32.Type),
```

The code generates a table with four columns:
![img](https://github.com/nolockcz/PowerQuery/raw/master/Time%20Dimension/readme%20images/0.PNG)

Next step will be columns which are grouped by intervals like 5, 10, 15, 30, and 60 minutes. To achieve that we use a basic custom function, which rounds down minutes to the last fold of an interval.
 
```m
/***** Round down minutes by interval value *****/
fnTimeRoundDown = (currentTime as time, interval as number) as time => 
    let
        currentHour = Time.Hour(currentTime),
        currentMinute = Time.Minute(currentTime),
        result = #time(currentHour, currentMinute - Number.Mod(currentMinute, interval), 0)
    in
        result,
FiveMinutes = Table.AddColumn(Minute, "FiveMinutes", each fnTimeRoundDown([Time], 5), type time),
TenMinutes = Table.AddColumn(FiveMinutes, "TenMinutes", each fnTimeRoundDown([Time], 10), type time),
FifteenMinutes = Table.AddColumn(TenMinutes, "FifteenMinutes", each fnTimeRoundDown([Time], 15), type time),
ThirtyMinutes = Table.AddColumn(FifteenMinutes, "ThirtyMinutes", each fnTimeRoundDown([Time], 30), type time),
OneHour = Table.AddColumn(ThirtyMinutes, "OneHour", each fnTimeRoundDown([Time], 60), type time),
```

A subset looks like:
![img](https://github.com/nolockcz/PowerQuery/raw/master/Time%20Dimension/readme%20images/0x.PNG)

They are useful, but what our customers expect in their colorful visuals are intervals like from 10:00 to 10:15, from 10:15 to 10:30 and so on. For that we need another custom function.

 
```m
/***** Generates a text from a time interval *****/
fnTimeToText = (currentTime as time, countOfMinutes as number) as text =>
    let 
        from = currentTime,
        to = currentTime + #duration(0, 0, countOfMinutes, 0),
        result = Time.ToText(from) & " - " & Time.ToText(to)
    in
        result,
FiveMinutesText = Table.AddColumn(OneHour, "FiveMinutesInterval", each fnTimeToText([FiveMinutes], 5), type text),
TenMinutesText = Table.AddColumn(FiveMinutesText, "TenMinutesInterval", each fnTimeToText([TenMinutes], 10), type text),
FifteenMinutesText = Table.AddColumn(TenMinutesText, "FifteenMinutesInterval", each fnTimeToText([FifteenMinutes], 15), type text),
ThirtyMinutesText = Table.AddColumn(FifteenMinutesText, "ThirtyMinutesInterval", each fnTimeToText([ThirtyMinutes], 30), type text),
OneHourText = Table.AddColumn(ThirtyMinutesText, "OneHourInterval", each fnTimeToText([OneHour], 60), type text),
```

Again a subset of generated data:
![img](https://github.com/nolockcz/PowerQuery/raw/master/Time%20Dimension/readme%20images/1.PNG)

And in the end of the code, as usual, there is a translation section. You can change the column names to your language with ease. 

## 24-hour vs. 12-hour time format

There is a big part of the world which doesn’t use 24-hour time format but instead 12-hours with meridiem (the a.m. and p.m. thing has a name). I have prepared a special edition of a time dimension.

![img](https://github.com/nolockcz/PowerQuery/raw/master/Time%20Dimension/readme%20images/2.jpg)
(Source: https://travel.stackexchange.com/questions/34950/which-large-countries-use-12-hour-time-format-am-pm)

First of all, you can choose what format the meridiem should have. According to the internet you can write it in many ways. Do you prefer “a.m.” over “am”? No problem, just change it at the beginning of the Power Query query in the variables *AmFormat* and *PmFormat*.

The rest of the code is almost the same as the 24-hour format. I am not sure how am/pm is used in intervals if the start is before midday, but the end is after midday. And the same is around midnight. I have tried to find out the correct form on the internet but without success. I’ve decided to write both meridians if they are different like 11:45 am – 12:00 pm in comparison to 12:00 – 12:15 pm. If you expect another format, modify the code ;)

```m
/***** Generates a text from a time interval *****/
fnTimeToText = (currentTime as time, countOfMinutes as number) as text =>
    let 
        from = currentTime,
        to = currentTime + #duration(0, 0, countOfMinutes, 0),
        fromMeridiem = if Time.Hour(from) < 12 then amFormat else PmFormat,
        toMeridiem = if Time.Hour(to) < 12 then AmFormat else PmFormat,
        result = 
    Time.ToText(from, "h:mm") & 
            (if fromMeridiem = toMeridiem then "" else " " & fromMeridiem) & 
            " - " & 
            Time.ToText(to, "h:mm") & " " & toMeridiem
    in
        result,
``` 

Some examples when am switches to pm:
![img](https://github.com/nolockcz/PowerQuery/raw/master/Time%20Dimension/readme%20images/3.PNG)

## The original blog post
The code is a part of a blog post: https://community.powerbi.com/t5/Community-Blog/Time-Dimension-in-Power-Query/ba-p/809094
