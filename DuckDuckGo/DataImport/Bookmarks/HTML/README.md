# Bookmarks HTML Reader flows

## Determining import source

```mermaid
graph TD
    A[cursor = document root node] -->|validateHTMLBookmarksDocument| B[cursor = h1 tag]
    B --> C[determineImportSource<br>findTopLevelFolderNameNode]
    C --> D[cursor => nextSibling]
    D -->|`dl` tag| E[proceedToTopLevel<br>FolderNameNode]
    E --> F[store cursor<br>cursor => firstChild]
    F -->|`dd` tag| G[cursor => firstChild]
    G -->|`h3` tag| H[cursor = top level folder name<br>source = other]
    F -->|`dt` tag| I[restore cursor<br>no top level folder]
    D -->|`h3` tag| J{isDDGBookmarks?}
    I --> K{isDDGBookmarks?}
    K -->|no| L[cursor = first item in folder<br>source = Safari]
    K -->|yes| M[cursor = first item in folder<br>source = DDG WebKit]
    J -->|no| N[cursor = top level folder name<br>source = Safari]
    J -->|yes| O[cursor = top level folder name<br>source = DDG WebKit]
    
```

## Reading a folder

```mermaid
graph TD
    A[cursor: XMLNode?<br>folderName: empty] --> B{get tag}
    B -->|h3| C[folderName = cursor.stringValue<br>cursor = nextSibling]
    B -->|dl| D
    C -->|dl| D[readFolderContents]
    D --> E[cursor = firstChild]
    E --> F{cursor != nil}
    F -->|yes| G{get cursor and<br>firstChild}
    G -->|dd,h3| H[readFolder]
    G -->|dt,a| I[readBookmark]
    H --> J
    I --> J[add to children]
    G -->|other| K[cursor = nextSibling]
    H --> A
    J --> K
    F -->|no| L[return folder]
    K --> F
```

## Constructing ImportedBookmarks object

```mermaid
graph TD
    A[bookmarkBar: empty<br>otherBookmarks: empty] --> B[read first folder]
    B --> C{import<br>source?}
    C -->|DDG WebKit| D{folder<br>has name?}
    D -->|yes| E[append folder<br>to otherBookmarks]
    D -->|no| F[append folder <b>contents</b><br>to otherBookmarks]
    C -->|other| G[set folder as bookmarkBar]
    E --> H[set fake empty folder<br>as bookmarkBar]
    F --> H
    G --> I[read the rest of the document<br>append everything to otherBookmarks]
    H --> I
```
