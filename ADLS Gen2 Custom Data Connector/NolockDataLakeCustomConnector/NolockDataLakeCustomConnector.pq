section NolockDataLakeCustomConnector;

// Constants
APP_CONSTANTS = [
    APP_LABEL = "Azure Data Lake Storage Gen2 with HNS",
    APP_DESCRIPTION = "ADLS Gen2 connector with HNS support (provided by nolock)"
];

//
// Constructor
//
NolockDataLakeCustomConnector = [
    TestConnection =
        (dataSourcePath) =>
            let
                json = Json.Document(dataSourcePath),
                storageAccountNameOrUrl = json[storageAccountNameOrUrl]
            in
                {
                    "NolockDataLakeCustomConnector.Contents",
                    storageAccountNameOrUrl
                },
    Authentication = [
        Aad = [
            AuthorizationUri = "https://login.microsoftonline.com/common/oauth2/authorize",
            // in this connector you can use just a name of a storage account instead of a URL, 
            // but then you have to define all parts of the authentication request
            Resource = "https://storage.azure.com",
            response_type = "code",
            prompt = "select_account",
            scope = "user_impersonation",
            display = "popup"
        ]
    ],
    Label = APP_CONSTANTS[APP_LABEL]
];
//
// Data Source UI
//
NolockDataLakeCustomConnector.Publish = [
    Beta = false,
    Category = "Azure",
    ButtonText = {
        APP_CONSTANTS[APP_LABEL],
        APP_CONSTANTS[APP_DESCRIPTION]
    },
    LearnMoreUrl = "https://github.com/nolockcz/PowerQuery/ADLS%20Gen2%20Custom%20Data%20Connector",
    SourceImage = NolockDataLakeCustomConnector.Icons,
    SourceTypeImage = NolockDataLakeCustomConnector.Icons
];
//
// Shared main function
// 
[
    DataSource.Kind = "NolockDataLakeCustomConnector",
    Publish = "NolockDataLakeCustomConnector.Publish"
]
shared NolockDataLakeCustomConnector.Contents =
    Value.ReplaceType(
        NavigationTable,
        NavigationTableType
    );

//
// Navigation table (root)
//
NavigationTable =
    (storageAccountNameOrUrl as text) as table =>
        let
            uriParts = Uri.Parts(storageAccountNameOrUrl),
            // first part of the Host is the storage account name
            storageAccountName = List.First(Text.Split(uriParts[Host], ".")),
            // container is the first part of Path
            container = Text.EmptyIfNull(List.First(Path.Split(uriParts[Path]))),
            // directory path
            directoryPath = Text.EmptyIfNull(Path.Combine(List.Skip(Path.Split(uriParts[Path]), 1))),
            // if the path contains a container, load direct subfolders
            navigationTable =
                if (container = "") then
                    ADLS.GetContainers(storageAccountName)
                else if (directoryPath = "") then
                    ADLS.GetSubfolders(
                        storageAccountName,
                        container,
                        directoryPath
                    )
                else
                    let
                        subfolders =
                            ADLS.GetSubfolders(
                                storageAccountName,
                                container,
                                directoryPath
                            ),
                        // 2 rows means, there is an "all files" row and one another file
                        isSingleFileItem = Table.RowCount(subfolders) = 2,
                        // if the name of the file (second row) is same as the suffix of the URL
                        isSameName =
                            Text.EndsWith(
                                directoryPath,
                                subfolders{1}[Name]
                            ),
                        // if the URL navigates to one file, show the file only
                        nonEmptyDirectoryPathNavigationTable =
                            if isSingleFileItem and isSameName then
                                ADLS.ListFilesRecursively(
                                    storageAccountName,
                                    container,
                                    directoryPath
                                )
                            else
                                ADLS.GetSubfolders(
                                    storageAccountName,
                                    container,
                                    directoryPath
                                )
                    in
                        nonEmptyDirectoryPathNavigationTable
        in
            navigationTable;

//
// Type of the navigation table (metadata)
//
NavigationTableType =
    type function (storageAccountNameOrUrl as
        (
            Uri.Type
            meta
            [
                Documentation.FieldCaption = "Storage Account Name or URL",
                Documentation.FieldDescription = "The name or the URL of an ADLS Gen2 storage account.",
                Documentation.SampleValues = {
                    "https://younameit.dfs.core.windows.net[/yourcontainer[/yourdirectory[/yourfile]]]"
                }
            ]
        )) as table
    meta
    [
        Documentation.Name = APP_CONSTANTS[APP_LABEL],
        Documentation.LongDescription = APP_CONSTANTS[APP_DESCRIPTION],
        Documentation.Examples = {
            [
                Description = "Returns a hierarchical structure of a storage account with HNS.",
                Code = "NolockDataLakeCustomConnector.Contents(""https://younameit.dfs.core.windows.net"")"
            ]
        }
    ];

//
// Get containers as navigation table
//
ADLS.GetContainers =
    (storageAccountName as text) as table =>
        let
            Url =
                "https://"
                & storageAccountName
                & ".dfs.core.windows.net/?resource=account",
            Source =
                Web.Contents(
                    Url,
                    [Headers = [
                        #"Accept" = "application/json"
                    ]]
                ),
            ResponseJsonContainers = Json.Document(Source),
            ToTable = Record.ToTable(ResponseJsonContainers),
            FirstValue = ToTable{0}[Value],
            ToTableFromList =
                Table.FromList(
                    FirstValue,
                    Splitter.SplitByNothing(),
                    null,
                    null,
                    ExtraValues.Error
                ),
            AddName =
                Table.ExpandRecordColumn(
                    ToTableFromList,
                    "Column1",
                    {"name"},
                    {"Name"}
                ),
            AddData =
                Table.AddColumn(
                    AddName,
                    "Data",
                    each
                        ADLS.GetSubfolders(
                            storageAccountName,
                            [Name],
                            ""
                        )
                ),
            AddItemKind =
                Table.AddColumn(
                    AddData,
                    "ItemKind",
                    each "Database"
                ),
            AddItemName =
                Table.AddColumn(
                    AddItemKind,
                    "ItemName",
                    each "Container"
                ),
            AddIsLeaf =
                Table.AddColumn(
                    AddItemName,
                    "IsLeaf",
                    each false
                ),
            navigationTable =
                Table.ToNavigationTable(
                    AddIsLeaf,
                    {"Name"},
                    "Name",
                    "Data",
                    "ItemKind",
                    "ItemName",
                    "IsLeaf"
                )
        in
            navigationTable;
//
// Get subfolders
//
ADLS.GetSubfolders =
    (storageAccountName as text, filesystem as text, directoryPath as text) as any =>
        let
            Url =
                "https://"
                & storageAccountName
                & ".dfs.core.windows.net/"
                & filesystem
                & "?resource=filesystem"
                & "&directory="
                & directoryPath
                & "&recursive=false",
            Source =
                Web.Contents(
                    Url,
                    [Headers = [
                        #"Accept" = "application/json"
                    ]]
                ),
            ResponseJsonContainers = Json.Document(Source),
            ToTable = Record.ToTable(ResponseJsonContainers),
            FirstValue = ToTable{0}[Value],
            ToTableFromList =
                Table.FromList(
                    FirstValue,
                    Splitter.SplitByNothing(),
                    null,
                    null,
                    ExtraValues.Error
                ),
            ExpandTable =
                if Table.IsEmpty(ToTableFromList) then
                    #table(
                        {
                            "tmpFolderPath",
                            "tmpIsDirectory"
                        },
                        {}
                    )
                else
                    Table.ExpandRecordColumn(
                        ToTableFromList,
                        "Column1",
                        {
                            "name",
                            "isDirectory"
                        },
                        {
                            "tmpFolderPath",
                            "tmpIsDirectory"
                        }
                    ),
            AddFolderName =
                Table.AddColumn(
                    ExpandTable,
                    "Name",
                    each Path.LastNonEmptyPart({[tmpFolderPath]}),
                    type text
                ),
            AddData =
                Table.AddColumn(
                    AddFolderName,
                    "Data",
                    each
                        if [tmpIsDirectory] = null then
                            ADLS.GetFile(
                                storageAccountName,
                                filesystem,
                                Path.Combine(directoryPath, [Name])
                            )
                        else
                            @ADLS.GetSubfolders(
                                storageAccountName,
                                filesystem,
                                Path.Combine(directoryPath, [Name])
                            ),
                    type table
                ),
            AddItemKind =
                Table.AddColumn(
                    AddData,
                    "ItemKind",
                    each
                        if [tmpIsDirectory] = null then
                            "Table"
                        else
                            "Folder",
                    type text
                ),
            AddItemName =
                Table.AddColumn(
                    AddItemKind,
                    "ItemName",
                    each
                        if [tmpIsDirectory] = null then
                            "File"
                        else
                            "Folder",
                    type text
                ),
            AddIsLeaf =
                Table.AddColumn(
                    AddItemName,
                    "IsLeaf",
                    each [tmpIsDirectory] = null,
                    type logical
                ),
            RemoveTmpColumns =
                Table.RemoveColumns(
                    AddIsLeaf,
                    {
                        "tmpFolderPath",
                        "tmpIsDirectory"
                    }
                ),
            PrependAllFilesRecord =
                Table.Combine(
                    {
                        NavigationTableRecordOfAllFiles(
                            storageAccountName,
                            filesystem,
                            directoryPath
                        ),
                        RemoveTmpColumns
                    }
                ),
            NavigationTable =
                Table.ToNavigationTable(
                    PrependAllFilesRecord,
                    {"Name"},
                    "Name",
                    "Data",
                    "ItemKind",
                    "ItemName",
                    "IsLeaf"
                )
        in
            NavigationTable;
//
// Get file from an ADLS Gen 2
//
ADLS.GetFile =
    (storageAccountName as text, filesystem as text, filePath as text) as binary =>
        let
            Url =
                "https://"
                & storageAccountName
                & ".dfs.core.windows.net/"
                & Path.Combine(filesystem, filePath),
            Source = Web.Contents(Url)
        in
            Source;
//
// List files from a directory recursively
//
ADLS.ListFilesRecursively =
    (storageAccountName as text, filesystem as text, filePath as text) as table =>
        let
            Url =
                "https://"
                & storageAccountName
                & ".dfs.core.windows.net/"
                & filesystem
                & "?resource=filesystem"
                & "&directory="
                & filePath
                & "&recursive=true",
            Source =
                Web.Contents(
                    Url,
                    [Headers = [
                        #"Accept" = "application/json"
                    ]]
                ),
            ListOfRecords = Json.Document(Source)[paths],
            SelectFilesAndNoDirectories =
                List.Select(
                    ListOfRecords,
                    each not Record.HasFields(_, "isDirectory")
                ),
            GetFileByPath =
                List.Transform(
                    SelectFilesAndNoDirectories,
                    each
                        [
                            #"Content" =
                                ADLS.GetFile(
                                    storageAccountName,
                                    filesystem,
                                    [name]
                                ),
                            #"Name" = Path.LastNonEmptyPart({[name]}),
                            #"Extension" = List.Last(Text.Split([name], ".")),
                            #"Date accessed" = null,
                            #"Date modified" = DateTime.FromText([lastModified]),
                            #"Date created" = null,
                            #"Attributes" = [
                                #"Content Type" = null,
                                #"Kind" = null,
                                #"Size" = [contentLength],
                                #"Group" = null,
                                #"Owner" = null,
                                #"Permissions" = [permissions]
                            ],
                            #"Folder Path" =
                                "https://"
                                & storageAccountName
                                & ".dfs.core.windows.net/"
                                & Path.Combine(filesystem, [name])
                        ]
                ),
            ListToTable =
                Table.FromRecords(
                    GetFileByPath,
                    type table [
                        #"Content" = Binary.Type,
                        #"Name" = Text.Type,
                        #"Extension" = Text.Type,
                        #"Date accessed" = DateTime.Type,
                        #"Date modified" = DateTime.Type,
                        #"Date created" = DateTime.Type,
                        #"Attributes" = Record.Type,
                        #"Folder Path" = Text.Type
                    ]
                )
        in
            ListToTable;

//
// Generate a record of the navigation table containing all files of a directory
//
NavigationTableRecordOfAllFiles =
    (storageAccountName as text, filesystem as text, directoryPath as text) as table =>
        Table.FromRecords(
            {
                [
                    Name =
                        "# All files of '"
                        & Path.LastNonEmptyPart(
                            {
                                filesystem,
                                directoryPath
                            }
                        )
                        & "'",
                    Data =
                        ADLS.ListFilesRecursively(
                            storageAccountName,
                            filesystem,
                            directoryPath
                        ),
                    ItemKind = "Folder",
                    ItemName = "Folder",
                    // IsLeaf must be true - it contains only files
                    IsLeaf = true
                ]
            },
            type table [
                Name = Text.Type,
                Data = Table.Type,
                ItemKind = Text.Type,
                ItemName = Text.Type,
                IsLeaf = Logical.Type
            ]
        );

//
// Get the last non empty part of a path
//
Path.LastNonEmptyPart = (parts as list) as text => List.Last(Path.Split(Path.Combine(parts)));
//
// Combine parts of a path
//
Path.Combine =
    (parts as any, optional additionalPart as text) as text =>
        let
            partsAsList =
                if Type.Is(List.Type, Value.Type(parts)) then
                    parts
                else if Type.Is(Text.Type, Value.Type(parts)) then
                    {
                        parts,
                        additionalPart
                    }
                else
                    error
                        "Invalid type of the first parameter: '"
                        & Value.Type(parts)
                        & "'. Expected: List or Text."
        in
            Text.Combine(
                List.Select(
                    List.Transform(
                        partsAsList,
                        each Text.Trim(_, "/")
                    ),
                    each _ <> ""
                ),
                "/"
            );
//
// Split a path into parts
//
Path.Split =
    (str as nullable text) as list =>
        List.Select(
            Text.Split(Text.EmptyIfNull(str), "/"),
            each _ <> ""
        );

//
// If the string is null, set it to empty string
//
Text.EmptyIfNull =
    (str as nullable text) as text =>
        if str = null then
            ""
        else
            str;

//
// Icons
//
NolockDataLakeCustomConnector.Icons = [
    Icon16 = {
        Extension.Contents("NolockDataLakeCustomConnector16.png"),
        Extension.Contents("NolockDataLakeCustomConnector20.png"),
        Extension.Contents("NolockDataLakeCustomConnector24.png"),
        Extension.Contents("NolockDataLakeCustomConnector32.png")
    },
    Icon32 = {
        Extension.Contents("NolockDataLakeCustomConnector32.png"),
        Extension.Contents("NolockDataLakeCustomConnector40.png"),
        Extension.Contents("NolockDataLakeCustomConnector48.png"),
        Extension.Contents("NolockDataLakeCustomConnector64.png")
    }
];

// 
// Load common library functions
// 
Table.ToNavigationTable =
    (table as table, keyColumns as list, nameColumn as text, dataColumn as text, itemKindColumn as text, itemNameColumn as text, isLeafColumn as text) as table =>
        let
            tableType = Value.Type(table),
            newTableType =
                Type.AddTableKey(
                    tableType,
                    keyColumns,
                    true
                )
                meta
                [
                    NavigationTable.NameColumn = nameColumn,
                    NavigationTable.DataColumn = dataColumn,
                    NavigationTable.ItemKindColumn = itemKindColumn,
                    Preview.DelayColumn = itemNameColumn,
                    NavigationTable.IsLeafColumn = isLeafColumn
                ],
            navigationTable = Value.ReplaceType(table, newTableType)
        in
            navigationTable;