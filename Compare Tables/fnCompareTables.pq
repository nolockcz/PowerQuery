(
    // the first table name
    #"First table name" as text, 
    // the name of PK column of the first table
    #"First Table PK" as text, 
    // the second table name
    #"Second table name" as text, 
    // the name of PK column of the second table
    #"Second Table PK" as text,
    // ignore white spaces
    #"Ignore whitespaces" as logical
) as table =>
    /*****
        fnCompareTables.pq
        Author: Michal Dvorak (@nolockcz)
        Created: July 2021
        Updated:
            ---
    *****/

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
        tbl1 = Expression.Evaluate("#shared[" & #"First table name" & "]", #shared),
        tbl2 = Expression.Evaluate("#shared[" & #"Second table name" & "]", #shared),

        // initialize suffixes
        tbl1Suffix = " [" & Text.Upper(#"First table name") & "]",
        tbl2Suffix = " [" & Text.Upper(#"Second table name") & "]",
        equalSuffix = " IS_EQUAL?",

        // add a suffix to column names
        RenameColumnsTbl1 = fnAddSuffixToColumnNames(tbl1, tbl1Suffix),
        // add a suffix to column names
        RenameColumnsTbl2 = fnAddSuffixToColumnNames(tbl2, tbl2Suffix),

        // join tables
        FullOuterJoin = Table.Join(
            RenameColumnsTbl1, {#"First Table PK" & tbl1Suffix}, 
            RenameColumnsTbl2, {#"Second Table PK" & tbl2Suffix}, 
            JoinKind.FullOuter
        ),        

        // convert any value to string and set it to null if it contains an empty string or whitespaces
        fnNormalize = (val as any) as nullable text =>
            let
                valAsText = Text.From(val),
                trimmedText = Text.Trim(valAsText)
            in
                if #"Ignore whitespaces" then valAsText
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