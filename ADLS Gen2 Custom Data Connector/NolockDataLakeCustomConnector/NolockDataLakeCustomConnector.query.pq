// Use this file to write queries to test your data connector
let
    result = NolockDataLakeCustomConnector.Contents("https://younameit.dfs.core.windows.net/")
in
    result