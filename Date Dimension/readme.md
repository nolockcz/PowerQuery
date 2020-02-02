# Date Dimension with Holidays in PowerQuery

We all know how important it is to transform our data into a star schema and to have a fact table and dimension tables. Date dimension is one of those dimensions.

There are 4 ways how we can create a date dimension:
- Date dimension is already in our DWH and we just need to load it into our model.
- We create our own date dimension in PowerQuery.
- We use DAX (https://www.sqlbi.com/tools/dax-date-template/).
- We don’t care and just use the Time Intelligence of Power BI Desktop.

There are pros and cons of all these solutions. In my scenario, I need to have a date dimension already in PowerQuery because it is used in my ETL process. I’ve been searching on the internet for solutions and have found some:
- [Generating A Date Dimension Table In Power Query](https://blog.crossjoin.co.uk/2013/11/19/generating-a-date-dimension-table-in-power-query/) by Chris Webb
- [Script to Generate Date Dimension with Power Query M - With Financial Columns](http://www.rad.pasfu.com/index.php?/archives/166-Script-to-Generate-Date-Dimension-with-Power-Query-M-With-Financial-Columns.html) by Reza Rad
- [Creating a Date Dimension with a Power Query Script](https://www.mattmasson.com/2014/02/creating-a-date-dimension-with-a-power-query-script/) by Matt Masson

Unfortunately, all these contain only the basics and therefore didn’t fulfill my expectations. At this moment, I decided to write my own date dimension in PowerQuery from scratch.

## The core
A good date dimension used later in Power BI **must start on the 1st of January and end on the 31st of December**. Therefore, I personally prefer to use only the start and the end year as parameters.

There is a long list of features I have implemented: **years, half-years, quarters, months, ISO weeks, days, and their differently formatted variations**.

There is also a group of columns calculating a count of years backwards, vice versa for quarters, months, weeks, and days. What is it good for? You can filter your fact table by a range like *MonthsBackwards <= 13 AND MonthsBackwards >= 1* to get data from the last 12 full months.

And finally, the holy grail - holidays! In many business use cases, it is crucial that we know if a definite date is a working day or not. And what is a working day? It is a day which is neither weekend nor an official holiday. Countries (or even states within a country) have their own holidays. How have I solved this diversity? I have not yet. I have prepared the dimension for holidays in the state of Baden-Württemberg in Germany. And it is your task to check out the list and remove or add new holidays – it is very simple, trust me.

How to modify the list of holidays? There is a function called *fnGetAllHolidaysOfAYear* which generates all holidays in a year. In Germany, most of them are based on the Easter Sunday and that is also my starting point. Then I generate a list *CurrentYearHolidaysList* which contains the definition of all holidays in one year.

Example New Year and Easter Monday:
```m
// NewYear = always January 1st
[Date = #date(year, 1, 1), HolidayName = "Neujahr"],
```
```m
// EasterMonday = 1 day after Easter Sunday
[Date = Date.AddDays(EasterSunday, 1), HolidayName = "Ostermontag"],
```

The last thing I do is translating all column names. Now you are back in the game again. It is up to you to change these translation pairs.

## From community to community
There will never be a date dimension which fulfills everybody’s expectations. But we will do our best! Right?

I have committed 2 versions:
- The core: A date dimension without holidays 
- The extended version: the core plus holidays

## The original blog post
The code is a part of a blog post: https://community.powerbi.com/t5/Community-Blog/Date-Dimension-with-Holidays-in-PowerQuery/bc-p/750627