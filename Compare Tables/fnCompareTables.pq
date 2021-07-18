let
    fnCompareTablesType = 
        type function (
            firstTableName as (type text meta [
                Documentation.FieldCaption = "First table name",
                Documentation.FieldDescription = "The name of the first table.",
                Documentation.SampleValues = { "The name of the first table." }
            ]),
            firstTablePK as (type text meta [
                Documentation.FieldCaption = "First Table PK",
                Documentation.FieldDescription = "The name of the primary key column of the first table.",
                Documentation.SampleValues = { "The name of the primary key column of the first table." }
            ]),
            secondTableName as (type text meta [
                Documentation.FieldCaption = "Second table name",
                Documentation.FieldDescription = "The name of the second table.",
                Documentation.SampleValues = { "The name of the second table." }
            ]),
            secondTablePK as (type text meta [
                Documentation.FieldCaption = "Second Table PK",
                Documentation.FieldDescription = "The name of the primary key column of the second table.",
                Documentation.SampleValues = { "The name of the primary key column of the second table." }
            ]),
            ignoreWhitespaces as (type text meta [
                Documentation.FieldCaption = "Ignore whitespaces",
                Documentation.FieldDescription = "Trim a string and set it to null if empty before comparison.",
                Documentation.AllowedValues = { true, false }           
            ])
        ) as table meta 
                [
                    Documentation.Name = "fnCompareTables.pq",
                    Documentation.LongDescription = "Compares two tables by Michal Dvorak // @nolockcz",                    
                    Documentation.Author = "Michal Dvorak // @nolockcz",
                    Documentation.Created = "July 2021",
                    Documentation.Updates = {}
                ],
        fnCompareTablesFunction = 
            (             
                firstTableName as text, 
                firstTablePK as text, 
                secondTableName as text, 
                secondTablePK as text,                
                ignoreWhitespaces as logical
            ) as table =>
                let
                    // add a suffix to every column name
                    fnAddSuffixToColumnNames = 
                        (tbl as table, suffix as text) as table =>
                            Table.RenameColumns(
                                tbl,
                                List.Zip(
                                    {
                                        Table.ColumnNames(tbl),
                                        List.Transform(Table.ColumnNames(tbl), each _ & suffix)
                                    }
                                )
                            ),

                    // get table by their names (WARNING: #shared works only in Power BI Desktop!)
                    tbl1 = Expression.Evaluate("#shared[" & firstTableName & "]", #shared),
                    tbl2 = Expression.Evaluate("#shared[" & secondTableName & "]", #shared),

                    // initialize suffixes
                    tbl1Suffix = " [" & Text.Upper(firstTableName) & "]",
                    tbl2Suffix = " [" & Text.Upper(secondTableName) & "]",
                    equalSuffix = " IS_EQUAL?",

                    // add a suffix to column names
                    RenameColumnsTbl1 = fnAddSuffixToColumnNames(tbl1, tbl1Suffix),
                    // add a suffix to column names
                    RenameColumnsTbl2 = fnAddSuffixToColumnNames(tbl2, tbl2Suffix),

                    // join tables
                    FullOuterJoin = Table.Join(
                        RenameColumnsTbl1, {firstTablePK & tbl1Suffix}, 
                        RenameColumnsTbl2, {secondTablePK & tbl2Suffix}, 
                        JoinKind.FullOuter
                    ),        

                    // convert any value to string and set it to null if it contains an empty string or whitespaces
                    fnNormalize = (val as any) as nullable text =>
                        let
                            valAsText = Text.From(val),
                            trimmedText = Text.Trim(valAsText)
                        in
                            if ignoreWhitespaces = false then valAsText
                            else if trimmedText = null or trimmedText = "" then null 
                            else trimmedText,

                    // for every original column name compare all values in POWERBI and ACCESS columns
                    Compare = List.Accumulate(
                        Table.ColumnNames(tbl1),
                        FullOuterJoin,
                        (state, current) =>
                            Table.AddColumn(
                                state,
                                // the name of the new column containing the result of comparison
                                current & equalSuffix,
                                // compare normalized strings
                                each fnNormalize(Record.Field(_, current & tbl1Suffix)) = fnNormalize(Record.Field(_, current & tbl2Suffix)),
                                type logical
                            )
                    ),

                    // get original column names which have all values TRUE in the column [col name].IS_EQUAL
                    GetIsEqualColumnNamePrefixWithTruesOnly = List.Transform(
                        List.Select(
                            List.Select(Table.ColumnNames(Compare), each Text.EndsWith(_, equalSuffix)),
                            (colName) => try List.AllTrue(Table.Column(Compare, colName)) otherwise false
                        ),
                        each Text.Replace(_, equalSuffix, "")
                    ),

                    // get all column names which have a prefix coming from GetIsEqualColumnNamePrefixWithTruesOnly
                    ColumnsWithTruesOnlyToRemove = List.Select(
                        Table.ColumnNames(Compare),
                        (colName) =>
                            List.MatchesAny(
                                GetIsEqualColumnNamePrefixWithTruesOnly,
                                each Text.StartsWith(colName, _)
                            )
                    ),

                    // remove all columns which are the same in both sources
                    RemoveAllTrueColumns = Table.RemoveColumns(Compare, ColumnsWithTruesOnlyToRemove),  

                    // reorder columns to an alphabetical order
                    ReorderColumns = Table.ReorderColumns(
                        RemoveAllTrueColumns,
                        List.Sort(Table.ColumnNames(RemoveAllTrueColumns))
                    )
                in
                    ReorderColumns
    in
        Value.ReplaceType(fnCompareTablesFunction, fnCompareTablesType)