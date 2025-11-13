; ============================================================================
; Advanced ToDo List Manager - x86 Assembly with GUI
; Features: Multiple views, priorities, due dates, save/load, filtering, 
;           time tracking, task editing, and more
; ============================================================================

.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\user32.inc
include \masm32\include\kernel32.inc
include \masm32\include\comdlg32.inc
include \masm32\include\shlwapi.inc
include \masm32\macros\macros.asm

includelib \masm32\lib\user32.lib
includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\comdlg32.lib
includelib \masm32\lib\shlwapi.lib

WinMain proto :DWORD, :DWORD, :DWORD, :DWORD
CreateControls proto :DWORD
AddTask proto :DWORD
DeleteTask proto :DWORD
MarkTaskComplete proto :DWORD
EditTask proto :DWORD
EditTaskDialog proto :DWORD, :DWORD
SaveTasks proto :DWORD
LoadTasks proto :DWORD
RefreshTaskList proto
FormatTaskForDisplay proto :DWORD, :DWORD
SortTasks proto
UpdateStatusBar proto
ShowTaskDescription proto
ResizeControls proto :DWORD
GetActualTaskIndex proto :DWORD
EditWndProc proto :DWORD, :DWORD, :DWORD, :DWORD
ValidateDate proto :DWORD
MatchesSearchFilter proto :DWORD

; ============================================================================
; CONSTANTS
; ============================================================================
WindowWidth     equ 950
WindowHeight    equ 800

; Control IDs
IDC_TASKEDIT    equ 1001
IDC_ADDBTN      equ 1002
IDC_TASKLIST    equ 1003
IDC_DELETEBTN   equ 1004
IDC_COMPLETEBTN equ 1005
IDC_EDITBTN     equ 1006
IDC_SAVEBTN     equ 1007
IDC_LOADBTN     equ 1008
IDC_PRIORITY    equ 1009
IDC_VIEWALL     equ 1010
IDC_VIEWTODAY   equ 1011
IDC_VIEWDONE    equ 1012
IDC_SORTPRIORITY equ 1013
IDC_SORTDATE    equ 1014
IDC_SORTID      equ 1020
IDC_DESCEDIT    equ 1015
IDC_DUEDATEEDIT equ 1016
IDC_STATUS      equ 1018
IDC_DESCVIEW    equ 1019
IDC_SEARCHBAR   equ 1021
IDC_CLEARBTN    equ 1022
IDC_GROUP_LEFT  equ 1100
IDC_GROUP_RIGHT equ 1101

; Priority levels
PRIORITY_LOW    equ 0
PRIORITY_MED    equ 1
PRIORITY_HIGH   equ 2

; View modes
VIEW_ALL        equ 0
VIEW_TODAY      equ 1
VIEW_COMPLETED  equ 2

; Notification codes
LBN_SELCHANGE   equ 1

; Task structure offsets (256 bytes per task)
TASK_ID         equ 0       ; DWORD - 4 bytes
TASK_TITLE      equ 4       ; 64 bytes
TASK_DESC       equ 68      ; 128 bytes
TASK_PRIORITY   equ 196     ; DWORD - 4 bytes
TASK_COMPLETED  equ 200     ; DWORD - 4 bytes (0=no, 1=yes)
TASK_DUEDATE    equ 204     ; 16 bytes (MM/DD/YYYY)
TASK_TIMESPENT  equ 220     ; DWORD - seconds
TASK_CREATED    equ 224     ; DWORD - timestamp
TASK_SIZE       equ 256     ; Total size

MAX_TASKS       equ 100

; Responsive layout tuning
MIN_LEFT_WIDTH  equ 300
MAX_LEFT_WIDTH  equ 420
LEFT_WIDTH_PCT  equ 38      ; approximate percentage of window width
MIN_RIGHT_WIDTH equ 340
MIN_WINDOW_WIDTH equ 760
TOP_MARGIN      equ 10
SIDE_MARGIN     equ 10
V_GAP           equ 8
SECTION_GAP     equ 18
STATUS_HEIGHT   equ 20
DESC_HEIGHT     equ 100
SEARCH_BAR_HEIGHT equ 22
TASK_LIST_MIN_HEIGHT equ 200

; Edit control messages
EM_SETSEL       equ 0B1h

; ============================================================================
; DATA SECTION
; ============================================================================
.DATA
ClassName       db "AdvancedToDoClass",0
DialogClassName db "ToDoEditDialogClass",0
AppName         db "Advanced ToDo Manager - Assembly Edition",0

; Button labels
AddBtnText      db "Add Task",0
DeleteBtnText   db "Delete",0
CompleteBtnText db "Toggle Status",0
EditBtnText     db "Edit Task",0
SaveBtnText     db "Save List",0
LoadBtnText     db "Load List",0
SortPriorityText db "Sort: Priority",0
SortDateText    db "Sort: Date",0
SortIDText      db "Sort: ID",0
ClearBtnText    db "Clear",0
SearchLabelText db "Search (ID or Title):",0

; View labels
ViewAllText     db "All Tasks",0
ViewTodayText   db "Today/Upcoming",0
ViewDoneText    db "Completed",0

; Control class names
EditClass       db "EDIT",0
ButtonClass     db "BUTTON",0
ListBoxClass    db "LISTBOX",0
ComboBoxClass   db "COMBOBOX",0
StaticClass     db "STATIC",0

; Priority labels
PriorityLow     db "Low",0
PriorityMed     db "Medium",0
PriorityHigh    db "High",0

; UI labels
LabelTask       db "Task:",0
LabelDesc       db "Description:",0
LabelPriority   db "Priority:",0
LabelDueDate    db "Due Date (MM/DD/YYYY):",0
LabelDescView   db "Task Description:",0
GroupLeftText   db "New Task",0
GroupRightText  db "Tasks",0

; File dialog
FileFilter      db "ToDo Files (*.todo)",0,"*.todo",0
                db "All Files (*.*)",0,"*.*",0,0
DefExt          db "todo",0
SaveTitle       db "Save ToDo List",0
LoadTitle       db "Load ToDo List",0

; Messages
MsgTaskAdded    db "Task added successfully!",0
MsgTaskDeleted  db "Task deleted!",0
MsgTaskCompleted db "Task marked as complete!",0
MsgSaved        db "Tasks saved successfully!",0
MsgLoaded       db "Tasks loaded successfully!",0
MsgError        db "Error",0
MsgInfo         db "Info",0
MsgNoSelection  db "Please select a task first.",0
MsgEnterTask    db "Please enter a task title.",0
MsgEditMode     db "Task loaded into fields. Edit and click Add to update.",0
MsgMaxTasks     db "Maximum task limit (100) reached. Delete some tasks first.",0
MsgFileError    db "Error opening file. Please check the file path.",0
MsgReadError    db "Error reading from file. File may be corrupted.",0
MsgWriteError   db "Error writing to file. Check disk space and permissions.",0
MsgInvalidDate  db "Invalid date. Use MM/DD/YYYY.",0

EmptyString     db 0
NoDescText      db "No description",0
NewLine         db 13,10,0
SpaceStr        db " ",0
PrefixHigh      db "[HIGH] ",0
PrefixMed       db "[MED] ",0
PrefixLow       db "[LOW] ",0
PrefixDone      db "[DONE] ",0
DueDatePrefix   db " (Due: ",0
CloseBracket    db ")",0
StatusFmt       db "Advanced ToDo Manager - Ready",0
IdFmt           db "[%u] ",0

; ============================================================================
; UNINITIALIZED DATA
; ============================================================================
.DATA?
hInstance       HINSTANCE ?
CommandLine     LPSTR ?
hwndMain        HWND ?

; Control handles
hTaskEdit       HWND ?
hDescEdit       HWND ?
hDueDateEdit    HWND ?
hAddBtn         HWND ?
hTaskList       HWND ?
hDeleteBtn      HWND ?
hCompleteBtn    HWND ?
hEditBtn        HWND ?
hSaveBtn        HWND ?
hLoadBtn        HWND ?
hPriorityCombo  HWND ?
hViewAllBtn     HWND ?
hViewTodayBtn   HWND ?
hViewDoneBtn    HWND ?
hSortPriorityBtn HWND ?
hSortDateBtn    HWND ?
hSortIDBtn      HWND ?
hStatusText     HWND ?
hDescView       HWND ?
hDescLabel      HWND ?
hSearchBar      HWND ?
hSearchLabel    HWND ?
hClearBtn       HWND ?
hGroupLeft      HWND ?
hGroupRight     HWND ?

; Task storage (100 tasks max)
TaskArray       db (MAX_TASKS * TASK_SIZE) dup(?)
TaskCount       DWORD ?
NextTaskID      DWORD ?
CurrentView     DWORD ?
SortMode        DWORD ?         ; 0=Priority, 1=Date, 2=ID
SortAscending   DWORD ?         ; 1=Ascending, 0=Descending
ListBoxMap      DWORD MAX_TASKS dup(?)  ; Maps listbox index to task array index
SearchFilter    db 256 dup(?)   ; Current search text

; Temporary buffers
TempBuffer      db 512 dup(?)
FileNameBuffer  db 260 dup(?)
DisplayBuffer   db 1024 dup(?)

; Edit dialog data
EditDialogTitle db 64 dup(?)
EditDialogDesc  db 128 dup(?)
EditDialogDate  db 16 dup(?)
EditDialogPriority DWORD ?
EditTaskIndex   DWORD ?

; ============================================================================
; CODE SECTION
; ============================================================================
.CODE

; ----------------------------------------------------------------------------
; Program Entry Point
; ----------------------------------------------------------------------------
start:
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    invoke GetCommandLineA
    mov CommandLine, eax
    invoke WinMain, hInstance, NULL, CommandLine, SW_SHOWDEFAULT
    invoke ExitProcess, eax

; ----------------------------------------------------------------------------
; WinMain - Main window creation and message loop
; ----------------------------------------------------------------------------
WinMain proc hInst:HINSTANCE, hPrevInst:HINSTANCE, CmdLine:LPSTR, CmdShow:DWORD
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    LOCAL hwnd:HWND

    ; Initialize data
    mov TaskCount, 0
    mov NextTaskID, 1
    mov CurrentView, VIEW_ALL
    mov SortMode, 0             ; Default to Priority sort
    mov SortAscending, 1        ; Default to Ascending
    
    ; Register window class
    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET WndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInstance
    mov wc.hInstance, eax
    mov wc.hbrBackground, COLOR_BTNFACE+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET ClassName

    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax

    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax

    invoke RegisterClassEx, ADDR wc
    cmp eax, 0
    je @@RegError

    ; Register dialog window class (no controls created automatically)
    mov wc.cbSize, SIZEOF WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, OFFSET EditWndProc
    mov wc.cbClsExtra, 0
    mov wc.cbWndExtra, 0
    mov eax, hInstance
    mov wc.hInstance, eax
    mov wc.hbrBackground, COLOR_BTNFACE+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, OFFSET DialogClassName
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    invoke RegisterClassEx, ADDR wc

    ; Create main window
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR ClassName, ADDR AppName, \
           WS_OVERLAPPEDWINDOW or WS_VISIBLE, \
           CW_USEDEFAULT, CW_USEDEFAULT, WindowWidth, WindowHeight, \
           NULL, NULL, hInstance, NULL
    mov hwndMain, eax
    cmp eax, 0
    je @@WndError

    invoke ShowWindow, hwndMain, SW_SHOW
    invoke UpdateWindow, hwndMain

    ; Message loop
MessageLoop:
    invoke GetMessage, ADDR msg, NULL, 0, 0
    cmp eax, 0
    je ExitLoop
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp MessageLoop

ExitLoop:
    mov eax, msg.wParam
    ret
    
@@RegError:
@@WndError:
    xor eax, eax
    ret
WinMain endp

; ----------------------------------------------------------------------------
; WndProc - Main window procedure
; ----------------------------------------------------------------------------
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    LOCAL priority:DWORD
    LOCAL selectedIdx:DWORD
    
    .IF uMsg == WM_CREATE
        ; Only create controls for the main window, not for edit dialogs
        mov eax, hWnd
        .IF eax == hwndMain || hwndMain == 0
            ; This is the main window (hwndMain not set yet or matches)
            invoke CreateControls, hWnd
        .ENDIF
        xor eax, eax
        ret

    .ELSEIF uMsg == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh
        
        .IF eax == IDC_ADDBTN
            invoke AddTask, hWnd
            
        .ELSEIF eax == IDC_DELETEBTN
            invoke DeleteTask, hWnd
            
        .ELSEIF eax == IDC_COMPLETEBTN
            invoke MarkTaskComplete, hWnd
            
        .ELSEIF eax == IDC_EDITBTN
            invoke EditTask, hWnd
            
        .ELSEIF eax == IDC_SAVEBTN
            invoke SaveTasks, hWnd
            
        .ELSEIF eax == IDC_LOADBTN
            invoke LoadTasks, hWnd
            
        .ELSEIF eax == IDC_VIEWALL
            mov CurrentView, VIEW_ALL
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_VIEWTODAY
            mov CurrentView, VIEW_TODAY
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_VIEWDONE
            mov CurrentView, VIEW_COMPLETED
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_SORTPRIORITY
            ; Toggle if same mode, else set ascending
            mov eax, SortMode
            .IF eax == 0
                ; Same mode - toggle direction
                mov eax, SortAscending
                xor eax, 1
                mov SortAscending, eax
            .ELSE
                ; New mode - set to ascending
                mov SortMode, 0
                mov SortAscending, 1
            .ENDIF
            invoke SortTasks
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_SORTDATE
            ; Toggle if same mode, else set ascending
            mov eax, SortMode
            .IF eax == 1
                ; Same mode - toggle direction
                mov eax, SortAscending
                xor eax, 1
                mov SortAscending, eax
            .ELSE
                ; New mode - set to ascending
                mov SortMode, 1
                mov SortAscending, 1
            .ENDIF
            invoke SortTasks
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_SORTID
            ; Toggle if same mode, else set ascending
            mov eax, SortMode
            .IF eax == 2
                ; Same mode - toggle direction
                mov eax, SortAscending
                xor eax, 1
                mov SortAscending, eax
            .ELSE
                ; New mode - set to ascending
                mov SortMode, 2
                mov SortAscending, 1
            .ENDIF
            invoke SortTasks
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_TASKLIST
            ; Check if this is a selection change notification
            mov eax, wParam
            shr eax, 16
            .IF eax == LBN_SELCHANGE
                invoke ShowTaskDescription
            .ENDIF
            
        .ELSEIF eax == IDC_CLEARBTN
            ; Clear search filter
            invoke SetWindowText, hSearchBar, ADDR EmptyString
            lea edi, SearchFilter
            mov byte ptr [edi], 0
            invoke RefreshTaskList
            
        .ELSEIF eax == IDC_SEARCHBAR
            ; Check if this is an EN_CHANGE notification
            mov eax, wParam
            shr eax, 16
            .IF eax == EN_CHANGE
                ; Get search text
                invoke GetWindowText, hSearchBar, ADDR SearchFilter, 255
                invoke RefreshTaskList
            .ENDIF
            
        .ENDIF
        
        xor eax, eax
        ret

    .ELSEIF uMsg == WM_CLOSE
        ; Check if this is the main window
        mov eax, hWnd
        .IF eax == hwndMain
            ; Main window closing - destroy it
            invoke DestroyWindow, hWnd
        .ELSE
            ; Edit dialog closing - let default handler deal with it
            invoke DefWindowProc, hWnd, uMsg, wParam, lParam
        .ENDIF
        xor eax, eax
        ret

    .ELSEIF uMsg == WM_SIZE
        invoke ResizeControls, lParam
        xor eax, eax
        ret

    .ELSEIF uMsg == WM_DESTROY
        ; Check if this is the main window or edit dialog
        mov eax, hWnd
        .IF eax == hwndMain
            ; This is the main window, quit application
            invoke PostQuitMessage, 0
        .ELSE
            ; This is a popup/child window (edit dialog), re-enable parent
            invoke GetParent, hWnd
            .IF eax != 0
                invoke EnableWindow, eax, TRUE
                invoke SetForegroundWindow, eax
            .ENDIF
        .ENDIF
        xor eax, eax
        ret

    .ENDIF

    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret
WndProc endp

; ----------------------------------------------------------------------------
; CreateControls - Create all UI controls
; ----------------------------------------------------------------------------
CreateControls proc hWnd:HWND
    LOCAL x:DWORD, y:DWORD, shiftedX:DWORD
    
    mov x, 10
    mov y, 10
    
    ; Calculate shifted x position for inputs (30% of window width starting point)
    mov shiftedX, 90  ; Approximately 30% for 300px width controls
    
    ; ===== Left Panel: Task Input =====
    
    ; Task Label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelTask, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           x, y, 100, 20, \
           hWnd, NULL, hInstance, NULL
    
    add y, 20
    
    ; Task Title Edit - moved up slightly
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL, \
           x, y, 300, 25, \
           hWnd, IDC_TASKEDIT, hInstance, NULL
    mov hTaskEdit, eax
    
    add y, 35
    
    ; Description Label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelDesc, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           x, y, 100, 20, \
           hWnd, NULL, hInstance, NULL
    
    add y, 22
    
    ; Description Edit (multiline) - shifted right, 20% smaller height (80px)
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_MULTILINE or ES_AUTOVSCROLL or WS_VSCROLL, \
           shiftedX, y, 300, 80, \
           hWnd, IDC_DESCEDIT, hInstance, NULL
    mov hDescEdit, eax
    
    add y, 90
    
    ; Priority Label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelPriority, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           x, y, 100, 20, \
           hWnd, NULL, hInstance, NULL
    
    add y, 22
    
    ; Priority ComboBox - shifted right
    invoke CreateWindowEx, 0, ADDR ComboBoxClass, NULL, \
           WS_CHILD or WS_VISIBLE or CBS_DROPDOWNLIST or WS_VSCROLL, \
           shiftedX, y, 150, 100, \
           hWnd, IDC_PRIORITY, hInstance, NULL
    mov hPriorityCombo, eax
    invoke SendMessage, hPriorityCombo, CB_ADDSTRING, 0, ADDR PriorityLow
    invoke SendMessage, hPriorityCombo, CB_ADDSTRING, 0, ADDR PriorityMed
    invoke SendMessage, hPriorityCombo, CB_ADDSTRING, 0, ADDR PriorityHigh
    invoke SendMessage, hPriorityCombo, CB_SETCURSEL, 1, 0  ; Default to Medium
    
    add y, 35
    
    ; Due Date Label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelDueDate, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           x, y, 200, 20, \
           hWnd, NULL, hInstance, NULL
    
    add y, 32
    
    ; Due Date Edit - shifted right
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL, \
           shiftedX, y, 150, 25, \
           hWnd, IDC_DUEDATEEDIT, hInstance, NULL
    mov hDueDateEdit, eax
    
    add y, 35
    
    ; Add Task Button - shifted right
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR AddBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           shiftedX, y, 140, 30, \
           hWnd, IDC_ADDBTN, hInstance, NULL
    mov hAddBtn, eax
    
    ; ===== Right Panel Group Box =====
    
    mov x, 360
    mov y, 10
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR GroupRightText, \
        WS_CHILD or WS_VISIBLE or BS_GROUPBOX, \
        x, y, 520, 580, \
        hWnd, IDC_GROUP_RIGHT, hInstance, NULL
    mov hGroupRight, eax
    
    ; Inner controls start inside group box (10px padding from group edge)
    add x, 10
    add y, 25
    
    ; Search Label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR SearchLabelText, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           x, y, 150, 20, \
           hWnd, NULL, hInstance, NULL
    mov hSearchLabel, eax
    
    add x, 155
    
    ; Search Edit Box
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL, \
           x, y, 260, 22, \
           hWnd, IDC_SEARCHBAR, hInstance, NULL
    mov hSearchBar, eax
    
    add x, 265
    
    ; Clear Button
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR ClearBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 60, 22, \
           hWnd, IDC_CLEARBTN, hInstance, NULL
    mov hClearBtn, eax
    
    mov x, 370
    add y, 30
    
    ; View Mode Buttons
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR ViewAllText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 100, 25, \
           hWnd, IDC_VIEWALL, hInstance, NULL
    mov hViewAllBtn, eax
    
    add x, 105
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR ViewTodayText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 120, 25, \
           hWnd, IDC_VIEWTODAY, hInstance, NULL
    mov hViewTodayBtn, eax
    
    add x, 125
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR ViewDoneText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 100, 25, \
           hWnd, IDC_VIEWDONE, hInstance, NULL
    mov hViewDoneBtn, eax
    
    mov x, 370
    add y, 35
    
    ; Task ListBox
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR ListBoxClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or LBS_NOTIFY or WS_VSCROLL or LBS_HASSTRINGS, \
           x, y, 500, 350, \
           hWnd, IDC_TASKLIST, hInstance, NULL
    mov hTaskList, eax
    
    add y, 360
    
    ; Action Buttons Row
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR CompleteBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 110, 28, \
           hWnd, IDC_COMPLETEBTN, hInstance, NULL
    mov hCompleteBtn, eax
    
    add x, 115
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR EditBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 100, 28, \
           hWnd, IDC_EDITBTN, hInstance, NULL
    mov hEditBtn, eax
    
    add x, 105
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR DeleteBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 80, 28, \
           hWnd, IDC_DELETEBTN, hInstance, NULL
    mov hDeleteBtn, eax
    
    mov x, 370
    add y, 35
    
    ; Bottom Buttons Row
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR SaveBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 90, 28, \
           hWnd, IDC_SAVEBTN, hInstance, NULL
    mov hSaveBtn, eax
    
    add x, 95
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR LoadBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 90, 28, \
           hWnd, IDC_LOADBTN, hInstance, NULL
    mov hLoadBtn, eax
    
    add x, 95
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR SortPriorityText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 100, 28, \
           hWnd, IDC_SORTPRIORITY, hInstance, NULL
    mov hSortPriorityBtn, eax
    
    add x, 105
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR SortDateText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 90, 28, \
           hWnd, IDC_SORTDATE, hInstance, NULL
    mov hSortDateBtn, eax
    
    add x, 95
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR SortIDText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           x, y, 70, 28, \
           hWnd, IDC_SORTID, hInstance, NULL
    mov hSortIDBtn, eax
    
    ; Description Viewer - below the group boxes
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelDescView, \
        WS_CHILD or WS_VISIBLE or SS_LEFT, \
        10, 600, 200, 20, \
        hWnd, -1, hInstance, NULL
    mov hDescLabel, eax
    
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, ADDR NoDescText, \
           WS_CHILD or WS_VISIBLE or ES_MULTILINE or ES_READONLY or WS_VSCROLL or ES_AUTOVSCROLL, \
           10, 625, 870, 80, \
           hWnd, IDC_DESCVIEW, hInstance, NULL
    mov hDescView, eax
    
    ; Status bar - way at bottom
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR EmptyString, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           10, 715, 870, 20, \
           hWnd, IDC_STATUS, hInstance, NULL
    mov hStatusText, eax
    
    ret
CreateControls endp

; ----------------------------------------------------------------------------
; AddTask - Add a new task to the list
; ----------------------------------------------------------------------------
AddTask proc hWnd:HWND
    LOCAL txtLen:DWORD
    LOCAL taskPtr:DWORD
    LOCAL priority:DWORD
    LOCAL tempBuf[64]:BYTE
    
    ; Check if we can add more tasks
    mov eax, TaskCount
    cmp eax, MAX_TASKS
    jge @@CannotAdd
    
    ; Calculate pointer to new task (MUST do this first!)
    lea eax, TaskArray
    mov edx, TaskCount
    imul edx, edx, TASK_SIZE
    add eax, edx
    mov taskPtr, eax
    
    ; Verify control handle exists
    mov eax, hTaskEdit
    cmp eax, 0
    je @@NoTitle
    
    ; Get task title - read it into temp buffer first
    lea eax, tempBuf
    invoke GetWindowText, hTaskEdit, eax, 63
    mov txtLen, eax
    
    ; Check if we got any text
    cmp txtLen, 0
    je @@NoTitle
    
    ; Get and validate due date ONCE (before storing anything)
    lea eax, TempBuffer
    invoke GetWindowText, hDueDateEdit, eax, 15
    ; Allow blank due date (no validation) else validate
    mov al, TempBuffer
    cmp al, 0
    je @@DateOK
    ; Date has content - validate it
    lea eax, TempBuffer
    invoke ValidateDate, eax
    cmp eax, 0
    jne @@DateOK
    ; Invalid date - show error and abort
    invoke MessageBox, hWnd, ADDR MsgInvalidDate, ADDR MsgError, MB_OK or MB_ICONWARNING
    invoke SetFocus, hDueDateEdit
    invoke SendMessage, hDueDateEdit, EM_SETSEL, 0, -1
    xor eax, eax
    ret
    
@@DateOK:
    ; Copy date (blank or valid) to task
    mov edx, taskPtr
    lea edi, [edx + TASK_DUEDATE]
    lea esi, TempBuffer
    mov ecx, 16
    rep movsb
    
    ; Set task ID
    mov edx, taskPtr
    mov eax, NextTaskID
    mov [edx + TASK_ID], eax
    inc NextTaskID
    
    ; Get and store title
    mov edx, taskPtr
    lea ecx, [edx + TASK_TITLE]
    invoke GetWindowText, hTaskEdit, ecx, 60
    
    ; Get and store description
    mov edx, taskPtr
    lea ecx, [edx + TASK_DESC]
    invoke GetWindowText, hDescEdit, ecx, 124
    
    ; Get priority
    invoke SendMessage, hPriorityCombo, CB_GETCURSEL, 0, 0
    mov edx, taskPtr
    mov [edx + TASK_PRIORITY], eax
    
    ; Initialize other fields
    mov edx, taskPtr
    mov dword ptr [edx + TASK_COMPLETED], 0
    mov dword ptr [edx + TASK_TIMESPENT], 0
    invoke GetTickCount
    mov edx, taskPtr
    mov [edx + TASK_CREATED], eax
    
    ; Increment task count
    inc TaskCount
    
    ; Clear input fields
    invoke SetWindowText, hTaskEdit, ADDR EmptyString
    invoke SetWindowText, hDescEdit, ADDR EmptyString
    invoke SetWindowText, hDueDateEdit, ADDR EmptyString
    invoke SendMessage, hPriorityCombo, CB_SETCURSEL, 1, 0
    
    ; Refresh display
    invoke RefreshTaskList
    invoke UpdateStatusBar
    ret
    
@@NoTitle:
    invoke MessageBox, hWnd, ADDR MsgEnterTask, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
    
@@CannotAdd:
    invoke MessageBox, hWnd, ADDR MsgMaxTasks, ADDR MsgError, MB_OK or MB_ICONERROR
    ret
AddTask endp

; ----------------------------------------------------------------------------
; RefreshTaskList - Rebuild task list based on current view
; ----------------------------------------------------------------------------
; ----------------------------------------------------------------------------
; MatchesSearchFilter - Check if task matches current search filter
; Input: taskPtr - pointer to task structure
; Returns: EAX = 1 if matches (or no filter), 0 if doesn't match
; ----------------------------------------------------------------------------
MatchesSearchFilter proc uses esi edi ebx taskPtr:DWORD
    LOCAL searchLen:DWORD
    LOCAL idStr[16]:BYTE
    
    ; Check if search filter is empty
    lea esi, SearchFilter
    movzx eax, byte ptr [esi]
    test al, al
    jz @@Match  ; Empty filter = show all
    
    ; Get search string length
    invoke lstrlen, esi
    mov searchLen, eax
    test eax, eax
    jz @@Match
    
    ; Convert task ID to string for comparison
    mov esi, taskPtr
    mov eax, [esi + TASK_ID]
    lea edi, idStr
    invoke wsprintf, edi, ADDR IdFmt, eax
    
    ; Check if ID contains search text (case-insensitive)
    lea edi, idStr
    lea esi, SearchFilter
    invoke StrStrI, edi, esi  ; Case-insensitive substring search
    test eax, eax
    jnz @@Match  ; Found in ID
    
    ; Check if title contains search text
    mov esi, taskPtr
    lea edi, [esi + TASK_TITLE]
    lea esi, SearchFilter
    invoke StrStrI, edi, esi
    test eax, eax
    jnz @@Match  ; Found in title
    
    ; No match
    xor eax, eax
    ret
    
@@Match:
    mov eax, 1
    ret
MatchesSearchFilter endp

; ----------------------------------------------------------------------------
; RefreshTaskList - Update the task listbox based on current view filter
; ----------------------------------------------------------------------------
RefreshTaskList proc
    LOCAL i:DWORD
    LOCAL taskPtr:DWORD
    LOCAL showTask:DWORD
    LOCAL listIdx:DWORD
    
    ; Clear listbox
    invoke SendMessage, hTaskList, LB_RESETCONTENT, 0, 0
    
    ; Iterate through tasks
    mov i, 0
    mov listIdx, 0
    lea edx, TaskArray
    
@@LoopStart:
    mov eax, i
    cmp eax, TaskCount
    jge @@Done
    
    mov taskPtr, edx
    mov showTask, 1  ; Default: show task
    
    ; Apply view filter
    mov eax, CurrentView
    .IF eax == VIEW_COMPLETED
        ; Show only completed tasks
        mov edx, taskPtr
        mov eax, [edx + TASK_COMPLETED]
        cmp eax, 0
        jne @@ShowIt
        mov showTask, 0
        jmp @@CheckShow
    .ELSEIF eax == VIEW_TODAY
        ; Show only incomplete tasks (simplified - would check date in real impl)
        mov edx, taskPtr
        mov eax, [edx + TASK_COMPLETED]
        cmp eax, 0
        je @@ShowIt
        mov showTask, 0
        jmp @@CheckShow
    .ENDIF
    
@@ShowIt:
@@CheckShow:
    cmp showTask, 0
    je @@NextTask
    
    ; Apply search filter
    invoke MatchesSearchFilter, taskPtr
    test eax, eax
    jz @@NextTask  ; Doesn't match search - skip
    
    ; Store mapping: listbox index -> actual task index
    mov eax, listIdx
    shl eax, 2  ; multiply by 4 for DWORD
    lea edx, ListBoxMap
    add edx, eax
    mov eax, i
    mov [edx], eax
    
    ; Format and add task to listbox
    invoke FormatTaskForDisplay, taskPtr, ADDR DisplayBuffer
    invoke SendMessage, hTaskList, LB_ADDSTRING, 0, ADDR DisplayBuffer
    
    inc listIdx
    
@@NextTask:
    inc i
    add taskPtr, TASK_SIZE
    mov edx, taskPtr
    jmp @@LoopStart
    
@@Done:
    ret
RefreshTaskList endp

; ----------------------------------------------------------------------------
; FormatTaskForDisplay - Format a task for display in listbox
; Returns: formatted string in provided buffer
; ----------------------------------------------------------------------------
FormatTaskForDisplay proc uses esi edi taskPtr:DWORD, bufferPtr:DWORD
    LOCAL priority:DWORD
    LOCAL completed:DWORD
    
    mov edi, bufferPtr
    mov esi, taskPtr
    
    ; Prepend task ID: "[<id>] "
    mov eax, [esi + TASK_ID]
    invoke wsprintf, edi, ADDR IdFmt, eax
    add edi, eax
    
    ; Get completion status
    mov eax, [esi + TASK_COMPLETED]
    mov completed, eax
    
    ; Get priority
    mov eax, [esi + TASK_PRIORITY]
    mov priority, eax
    
    ; Add completion prefix if completed
    .IF completed != 0
        push esi
        mov esi, OFFSET PrefixDone
        @@CopyDone:
            lodsb
            test al, al
            jz @@DoneDone
            stosb
            jmp @@CopyDone
        @@DoneDone:
        pop esi
    .ENDIF
    
    ; Add priority prefix
    .IF priority == PRIORITY_HIGH
        push esi
        mov esi, OFFSET PrefixHigh
        @@CopyHigh:
            lodsb
            test al, al
            jz @@HighDone
            stosb
            jmp @@CopyHigh
        @@HighDone:
        pop esi
    .ELSEIF priority == PRIORITY_LOW
        push esi
        mov esi, OFFSET PrefixLow
        @@CopyLow:
            lodsb
            test al, al
            jz @@LowDone
            stosb
            jmp @@CopyLow
        @@LowDone:
        pop esi
    .ELSE
        push esi
        mov esi, OFFSET PrefixMed
        @@CopyMed:
            lodsb
            test al, al
            jz @@MedDone
            stosb
            jmp @@CopyMed
        @@MedDone:
        pop esi
    .ENDIF
    
    ; Copy task title
    mov esi, taskPtr
    lea esi, [esi + TASK_TITLE]
    @@CopyTitle:
        lodsb
        test al, al
        jz @@TitleDone
        stosb
        jmp @@CopyTitle
    @@TitleDone:
    
    ; Check if there's a due date
    mov esi, taskPtr
    lea esi, [esi + TASK_DUEDATE]
    mov al, [esi]
    test al, al
    jz @@NoDueDate
    
    ; Add " (Due: "
    push esi
    mov esi, OFFSET DueDatePrefix
    @@CopyDuePrefix:
        lodsb
        test al, al
        jz @@DuePrefixDone
        stosb
        jmp @@CopyDuePrefix
    @@DuePrefixDone:
    pop esi
    
    ; Copy due date
    @@CopyDate:
        lodsb
        test al, al
        jz @@DateDone
        stosb
        jmp @@CopyDate
    @@DateDone:
    
    ; Add closing ")"
    mov al, ')'
    stosb
    
@@NoDueDate:
    ; Null terminate
    xor al, al
    stosb
    
    ret
FormatTaskForDisplay endp

; ----------------------------------------------------------------------------
; DeleteTask - Delete selected task
; ----------------------------------------------------------------------------
DeleteTask proc hWnd:HWND
    LOCAL selectedIdx:DWORD
    LOCAL actualIdx:DWORD
    LOCAL i:DWORD
    LOCAL srcPtr:DWORD
    LOCAL dstPtr:DWORD
    
    ; Get selected item
    invoke SendMessage, hTaskList, LB_GETCURSEL, 0, 0
    cmp eax, LB_ERR
    je @@NoSelection
    
    mov selectedIdx, eax
    
    ; Get actual task index
    invoke GetActualTaskIndex, selectedIdx
    cmp eax, -1
    je @@NoSelection
    mov actualIdx, eax
    
    ; Shift tasks down
    mov i, eax
    
@@ShiftLoop:
    mov eax, i
    inc eax
    cmp eax, TaskCount
    jge @@ShiftDone
    
    ; Calculate source and destination pointers
    mov eax, i
    inc eax
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov srcPtr, eax
    
    mov eax, i
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov dstPtr, eax
    
    ; Copy task
    mov esi, srcPtr
    mov edi, dstPtr
    mov ecx, TASK_SIZE
    rep movsb
    
    inc i
    jmp @@ShiftLoop
    
@@ShiftDone:
    dec TaskCount
    invoke RefreshTaskList
    invoke UpdateStatusBar
    ret
    
@@NoSelection:
    invoke MessageBox, hWnd, ADDR MsgNoSelection, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
DeleteTask endp

; ----------------------------------------------------------------------------
; MarkTaskComplete - Mark selected task as complete
; ----------------------------------------------------------------------------
MarkTaskComplete proc hWnd:HWND
    LOCAL selectedIdx:DWORD
    LOCAL actualIdx:DWORD
    LOCAL taskPtr:DWORD
    
    ; Get selected item
    invoke SendMessage, hTaskList, LB_GETCURSEL, 0, 0
    cmp eax, LB_ERR
    je @@NoSelection
    
    mov selectedIdx, eax
    
    ; Get actual task index
    invoke GetActualTaskIndex, selectedIdx
    cmp eax, -1
    je @@NoSelection
    mov actualIdx, eax
    
    ; Calculate task pointer
    mov eax, actualIdx
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov taskPtr, eax
    
    ; Toggle completion status
    mov edx, taskPtr
    mov eax, [edx + TASK_COMPLETED]
    xor eax, 1
    mov [edx + TASK_COMPLETED], eax
    
    invoke RefreshTaskList
    invoke MessageBox, hWnd, ADDR MsgTaskCompleted, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
    
@@NoSelection:
    invoke MessageBox, hWnd, ADDR MsgNoSelection, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
MarkTaskComplete endp

; ----------------------------------------------------------------------------
; EditTask - Edit selected task in a popup window
; ----------------------------------------------------------------------------
EditTask proc hWnd:HWND
    LOCAL selectedIdx:DWORD
    LOCAL actualIdx:DWORD
    
    ; Get selected item
    invoke SendMessage, hTaskList, LB_GETCURSEL, 0, 0
    cmp eax, LB_ERR
    je @@NoSelection
    
    mov selectedIdx, eax
    
    ; Get actual task index
    invoke GetActualTaskIndex, selectedIdx
    cmp eax, -1
    je @@NoSelection
    mov actualIdx, eax
    
    ; Show edit dialog
    mov eax, actualIdx
    mov EditTaskIndex, eax
    invoke EditTaskDialog, hWnd, actualIdx
    ret
    
@@NoSelection:
    invoke MessageBox, hWnd, ADDR MsgNoSelection, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
EditTask endp

; ----------------------------------------------------------------------------
; EditTaskDialog - Show modal dialog for editing a task
; ----------------------------------------------------------------------------
EditTaskDialog proc hParent:HWND, taskIdx:DWORD
    LOCAL hEditWnd:HWND
    LOCAL hEditTitle:HWND
    LOCAL hEditDesc:HWND
    LOCAL hEditPriority:HWND
    LOCAL hEditDate:HWND
    LOCAL hOkBtn:HWND
    LOCAL hCancelBtn:HWND
    LOCAL hLabel:HWND
    LOCAL msg:MSG
    LOCAL taskPtr:DWORD
    LOCAL result:DWORD
    LOCAL txtLen:DWORD
    
    ; Calculate task pointer
    mov eax, taskIdx
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov taskPtr, eax
    
    ; Create modal dialog window - INCREASED SIZE FOR VISIBILITY
    invoke CreateWindowEx, WS_EX_DLGMODALFRAME or WS_EX_TOPMOST, \
        ADDR DialogClassName, ADDR EditBtnText, \
        WS_CAPTION or WS_SYSMENU or WS_VISIBLE, \
        250, 100, 500, 380, \
        hParent, NULL, hInstance, NULL
    mov hEditWnd, eax
    cmp eax, 0
    je @@Error
    
    ; Disable parent window to make this truly modal
    invoke EnableWindow, hParent, FALSE
    
    ; Create labels and controls
    ; Title label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelTask, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           10, 10, 100, 20, \
           hEditWnd, NULL, hInstance, NULL
    
    ; Title edit
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL, \
           10, 35, 460, 25, \
           hEditWnd, 5001, hInstance, NULL
    mov hEditTitle, eax
    
    ; Load current title
    mov eax, taskPtr
    lea ecx, [eax + TASK_TITLE]
    invoke SetWindowText, hEditTitle, ecx
    
    ; Description label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelDesc, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           10, 70, 100, 20, \
           hEditWnd, NULL, hInstance, NULL
    
    ; Description edit
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_MULTILINE or ES_AUTOVSCROLL or WS_VSCROLL, \
           10, 95, 460, 100, \
           hEditWnd, 5002, hInstance, NULL
    mov hEditDesc, eax
    
    ; Load current description
    mov eax, taskPtr
    lea ecx, [eax + TASK_DESC]
    invoke SetWindowText, hEditDesc, ecx
    
    ; Priority label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelPriority, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           10, 205, 100, 20, \
           hEditWnd, NULL, hInstance, NULL
    
    ; Priority combo
    invoke CreateWindowEx, 0, ADDR ComboBoxClass, NULL, \
           WS_CHILD or WS_VISIBLE or CBS_DROPDOWNLIST or WS_VSCROLL, \
           10, 230, 200, 100, \
           hEditWnd, 5003, hInstance, NULL
    mov hEditPriority, eax
    invoke SendMessage, hEditPriority, CB_ADDSTRING, 0, ADDR PriorityLow
    invoke SendMessage, hEditPriority, CB_ADDSTRING, 0, ADDR PriorityMed
    invoke SendMessage, hEditPriority, CB_ADDSTRING, 0, ADDR PriorityHigh
    
    ; Load current priority
    mov eax, taskPtr
    mov edx, [eax + TASK_PRIORITY]
    invoke SendMessage, hEditPriority, CB_SETCURSEL, edx, 0
    
    ; Due date label
    invoke CreateWindowEx, 0, ADDR StaticClass, ADDR LabelDueDate, \
           WS_CHILD or WS_VISIBLE or SS_LEFT, \
           220, 205, 200, 20, \
           hEditWnd, NULL, hInstance, NULL
    
    ; Due date edit
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, ADDR EditClass, NULL, \
           WS_CHILD or WS_VISIBLE or WS_BORDER or ES_AUTOHSCROLL, \
           220, 230, 250, 25, \
           hEditWnd, 5004, hInstance, NULL
    mov hEditDate, eax
    
    ; Load current due date
    mov eax, taskPtr
    lea ecx, [eax + TASK_DUEDATE]
    invoke SetWindowText, hEditDate, ecx
    
    ; OK button (Save Changes)
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR EditBtnText, \
           WS_CHILD or WS_VISIBLE or BS_DEFPUSHBUTTON, \
           280, 280, 90, 30, \
           hEditWnd, 1, hInstance, NULL
    mov hOkBtn, eax
    
    ; Cancel button
    invoke CreateWindowEx, 0, ADDR ButtonClass, ADDR DeleteBtnText, \
           WS_CHILD or WS_VISIBLE or BS_PUSHBUTTON, \
           380, 280, 90, 30, \
           hEditWnd, 2, hInstance, NULL
    mov hCancelBtn, eax
    
    ; Modal behavior handled by disabling parent; message handling is in EditWndProc
    ret

@@Error:
    invoke EnableWindow, hParent, TRUE
    xor eax, eax
    ret
EditTaskDialog endp

; ----------------------------------------------------------------------------
; ShowTaskDescription - Display description of currently selected task
; ----------------------------------------------------------------------------
ShowTaskDescription proc
    LOCAL selectedIdx:DWORD
    LOCAL actualIdx:DWORD
    LOCAL taskPtr:DWORD
    
    ; Get selected item
    invoke SendMessage, hTaskList, LB_GETCURSEL, 0, 0
    cmp eax, LB_ERR
    je @@NoSelection
    
    mov selectedIdx, eax
    
    ; Map to actual task index (accounts for filtering)
    invoke GetActualTaskIndex, selectedIdx
    cmp eax, -1
    je @@NoSelection
    mov actualIdx, eax
    ; Calculate task pointer
    mov eax, actualIdx
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov taskPtr, eax
    
    ; Get pointer to description
    lea ecx, [eax + TASK_DESC]
    
    ; Check if description is empty
    mov al, byte ptr [ecx]
    cmp al, 0
    je @@ShowNoDesc
    
    ; Display description in the viewer
    invoke SetWindowText, hDescView, ecx
    ret

@@ShowNoDesc:
    ; Show "No description" if empty
    invoke SetWindowText, hDescView, ADDR NoDescText
    ret
    
@@NoSelection:
    ; Clear description if nothing selected
    invoke SetWindowText, hDescView, ADDR EmptyString
    ret
ShowTaskDescription endp

; ----------------------------------------------------------------------------
; GetActualTaskIndex - Convert listbox index to actual task array index
; Returns: actual task index in eax, or -1 if error
; ----------------------------------------------------------------------------
GetActualTaskIndex proc listboxIdx:DWORD
    mov eax, listboxIdx
    cmp eax, 0
    jl @@Error
    cmp eax, MAX_TASKS
    jge @@Error
    
    shl eax, 2  ; multiply by 4 for DWORD
    lea edx, ListBoxMap
    add edx, eax
    mov eax, [edx]
    ret
    
@@Error:
    mov eax, -1
    ret
GetActualTaskIndex endp

; ----------------------------------------------------------------------------
; ResizeControls - Resize controls when window is resized
; ----------------------------------------------------------------------------
ResizeControls proc lParam:DWORD
    LOCAL winW:DWORD, winH:DWORD, leftW:DWORD, rightX:DWORD, rightW:DWORD
    LOCAL curY:DWORD, listTopY:DWORD, listH:DWORD, btnY:DWORD, descY:DWORD
    LOCAL statusY:DWORD, temp:DWORD, coordX:DWORD, coordY:DWORD, coordW:DWORD

    ; Extract window client size
    mov eax, lParam
    and eax, 0FFFFh
    mov winW, eax
    mov eax, lParam
    shr eax, 16
    mov winH, eax

    ; Enforce minimums
    mov eax, winW
    cmp eax, MIN_WINDOW_WIDTH
    jge @@MinWOK
    mov winW, MIN_WINDOW_WIDTH
@@MinWOK:
    mov eax, winH
    cmp eax, 600
    jge @@MinHOK
    mov winH, 600
@@MinHOK:

    ; leftW = clamp( winW * LEFT_WIDTH_PCT / 100 )
    mov eax, winW
    mov ecx, LEFT_WIDTH_PCT
    mul ecx
    mov ecx, 100
    xor edx, edx
    div ecx
    mov leftW, eax
    mov eax, leftW
    cmp eax, MIN_LEFT_WIDTH
    jge @@LeftMinOK
    mov leftW, MIN_LEFT_WIDTH
@@LeftMinOK:
    mov eax, leftW
    cmp eax, MAX_LEFT_WIDTH
    jle @@LeftMaxOK
    mov leftW, MAX_LEFT_WIDTH
@@LeftMaxOK:

    ; Right panel origin & width
    mov eax, leftW
    add eax, SIDE_MARGIN
    add eax, 20
    mov rightX, eax
    mov eax, winW
    sub eax, rightX
    sub eax, SIDE_MARGIN
    mov rightW, eax
    mov eax, rightW
    cmp eax, MIN_RIGHT_WIDTH
    jge @@RightMinOK
    mov rightW, MIN_RIGHT_WIDTH
@@RightMinOK:

    ; Group box heights
    mov eax, winH
    sub eax, DESC_HEIGHT
    sub eax, STATUS_HEIGHT
    sub eax, 90
    mov temp, eax
    ; Left group
    invoke MoveWindow, hGroupLeft, SIDE_MARGIN, TOP_MARGIN, leftW, temp, TRUE
    ; Right group
    invoke MoveWindow, hGroupRight, rightX, TOP_MARGIN, rightW, temp, TRUE

    ; Inner left width (padding 40)
    mov eax, leftW
    sub eax, 40
    mov temp, eax

    ; Title edit - moved up slightly
    mov eax, SIDE_MARGIN
    add eax, 10
    mov ebx, TOP_MARGIN
    add ebx, 30
    mov ecx, temp
    invoke MoveWindow, hTaskEdit, eax, ebx, ecx, 25, TRUE
    mov coordX, eax  ; Save for reuse (x=20 for title)
    mov coordY, ebx

    ; Description edit - shifted 90px right (30%), 20% smaller height (96px)
    mov eax, coordY
    add eax, 35
    mov curY, eax
    mov eax, coordX
    add eax, 90  ; Shift right to 30%
    mov ebx, curY
    mov ecx, temp
    sub ecx, 90  ; Adjust width
    invoke MoveWindow, hDescEdit, eax, ebx, ecx, 96, TRUE

    ; Priority combo - shifted 90px right (30%)
    mov eax, curY
    add eax, 106
    mov curY, eax
    mov eax, curY
    add eax, 25
    mov ebx, coordX
    add ebx, 90  ; Shift right to 30%
    invoke MoveWindow, hPriorityCombo, ebx, eax, 150, 100, TRUE

    ; Due date edit - shifted 90px right (30%) with extra spacing
    mov eax, curY
    add eax, 80
    mov curY, eax
    mov ebx, coordX
    add ebx, 90  ; Shift right to 30%
    mov eax, curY
    invoke MoveWindow, hDueDateEdit, ebx, eax, 150, 25, TRUE

    ; Add button - shifted 90px right (30%)
    mov eax, curY
    add eax, 35
    mov curY, eax
    mov ebx, coordX
    add ebx, 90  ; Shift right to 30%
    mov eax, curY
    invoke MoveWindow, hAddBtn, ebx, eax, 140, 30, TRUE

    ; Right panel top offsets
    mov eax, TOP_MARGIN
    add eax, 25
    mov curY, eax

    ; Search row
    mov eax, rightX
    add eax, 10
    mov ebx, TOP_MARGIN
    add ebx, 25
    invoke MoveWindow, hSearchLabel, eax, ebx, 150, SEARCH_BAR_HEIGHT, TRUE
    mov coordY, ebx  ; Save for reuse
    
    mov eax, rightX
    add eax, 165
    mov ecx, rightW
    sub ecx, 240
    mov ebx, coordY
    invoke MoveWindow, hSearchBar, eax, ebx, ecx, SEARCH_BAR_HEIGHT, TRUE
    
    mov eax, rightX
    add eax, rightW
    sub eax, 65
    mov ebx, coordY
    invoke MoveWindow, hClearBtn, eax, ebx, 55, SEARCH_BAR_HEIGHT, TRUE

    ; View buttons row
    mov eax, TOP_MARGIN
    add eax, 55
    mov curY, eax
    mov eax, rightX
    add eax, 10
    mov ebx, curY
    invoke MoveWindow, hViewAllBtn, eax, ebx, 100, 25, TRUE
    mov eax, rightX
    add eax, 120
    mov ebx, curY
    invoke MoveWindow, hViewTodayBtn, eax, ebx, 120, 25, TRUE
    mov eax, rightX
    add eax, 250
    mov ebx, curY
    invoke MoveWindow, hViewDoneBtn, eax, ebx, 100, 25, TRUE

    ; Task list
    mov eax, curY
    add eax, 30
    mov listTopY, eax
    mov eax, winH
    sub eax, listTopY
    sub eax, DESC_HEIGHT
    sub eax, STATUS_HEIGHT
    sub eax, 170
    mov listH, eax
    mov eax, listH
    cmp eax, TASK_LIST_MIN_HEIGHT
    jge @@ListHeightOK
    mov listH, TASK_LIST_MIN_HEIGHT
@@ListHeightOK:
    mov eax, rightX
    add eax, 10
    mov ebx, rightW
    sub ebx, 20
    mov ecx, listTopY
    mov edx, listH
    invoke MoveWindow, hTaskList, eax, ecx, ebx, edx, TRUE

    ; Action buttons row
    mov eax, listTopY
    add eax, listH
    add eax, 8
    mov btnY, eax
    mov ebx, btnY
    mov eax, rightX
    add eax, 10
    invoke MoveWindow, hCompleteBtn, eax, ebx, 110, 28, TRUE
    mov eax, rightX
    add eax, 130
    mov ebx, btnY
    invoke MoveWindow, hEditBtn, eax, ebx, 100, 28, TRUE
    mov eax, rightX
    add eax, 240
    mov ebx, btnY
    invoke MoveWindow, hDeleteBtn, eax, ebx, 80, 28, TRUE

    ; Second buttons row
    mov eax, btnY
    add eax, 35
    mov btnY, eax
    mov ebx, btnY
    mov eax, rightX
    add eax, 10
    invoke MoveWindow, hSaveBtn, eax, ebx, 100, 28, TRUE
    mov eax, rightX
    add eax, 120
    mov ebx, btnY
    invoke MoveWindow, hLoadBtn, eax, ebx, 100, 28, TRUE
    mov eax, rightX
    add eax, 230
    mov ebx, btnY
    invoke MoveWindow, hSortPriorityBtn, eax, ebx, 105, 28, TRUE
    mov eax, rightX
    add eax, 340
    mov ebx, btnY
    invoke MoveWindow, hSortDateBtn, eax, ebx, 95, 28, TRUE
    mov eax, rightX
    add eax, 445
    mov ebx, btnY
    invoke MoveWindow, hSortIDBtn, eax, ebx, 75, 28, TRUE

    ; Description area
    mov eax, winH
    sub eax, DESC_HEIGHT
    sub eax, STATUS_HEIGHT
    sub eax, 10
    mov descY, eax
    mov ebx, descY
    sub ebx, 20
    invoke MoveWindow, hDescLabel, SIDE_MARGIN, ebx, 200, 18, TRUE
    mov eax, winW
    sub eax, SIDE_MARGIN
    sub eax, SIDE_MARGIN
    mov ebx, descY
    mov ecx, DESC_HEIGHT
    sub ecx, 40
    invoke MoveWindow, hDescView, SIDE_MARGIN, ebx, eax, ecx, TRUE

    ; Status bar
    mov eax, winH
    sub eax, STATUS_HEIGHT
    sub eax, 5
    mov statusY, eax
    mov eax, winW
    sub eax, SIDE_MARGIN
    sub eax, SIDE_MARGIN
    mov ebx, statusY
    invoke MoveWindow, hStatusText, SIDE_MARGIN, ebx, eax, STATUS_HEIGHT, TRUE
    ret
ResizeControls endp

; ----------------------------------------------------------------------------
; EditWndProc - Dedicated window proc for edit dialog (only handles close)
; ----------------------------------------------------------------------------
EditWndProc proc hWnd:HWND, uMsg:DWORD, wParam:DWORD, lParam:DWORD
    LOCAL taskPtr:DWORD
    LOCAL id:DWORD

    .IF uMsg == WM_COMMAND
        mov eax, wParam
        and eax, 0FFFFh
        mov id, eax
        
    .IF id == 1 ; OK button
            ; Compute task pointer from EditTaskIndex
            mov eax, EditTaskIndex
            mov ecx, TASK_SIZE
            mul ecx
            lea edx, TaskArray
            add eax, edx
            mov taskPtr, eax

            ; Read Title
            invoke GetDlgItem, hWnd, 5001
            push eax
            invoke GetWindowText, eax, ADDR EditDialogTitle, 63
            pop eax
            ; Copy 64 bytes into task
            mov edi, taskPtr
            add edi, TASK_TITLE
            lea esi, EditDialogTitle
            mov ecx, 64
            rep movsb

            ; Read Description
            invoke GetDlgItem, hWnd, 5002
            push eax
            invoke GetWindowText, eax, ADDR EditDialogDesc, 127
            pop eax
            mov edi, taskPtr
            add edi, TASK_DESC
            lea esi, EditDialogDesc
            mov ecx, 128
            rep movsb

            ; Read Due Date
            invoke GetDlgItem, hWnd, 5004
            push eax
            invoke GetWindowText, eax, ADDR EditDialogDate, 15
            pop eax
            ; If not empty, validate date format MM/DD/YYYY
            mov al, EditDialogDate
            cmp al, 0
            je @F
            invoke ValidateDate, ADDR EditDialogDate
            cmp eax, 0
            jne @F
            ; Invalid date: warn and keep dialog open
            invoke MessageBox, hWnd, ADDR MsgInvalidDate, ADDR MsgError, MB_OK or MB_ICONWARNING
            invoke GetDlgItem, hWnd, 5004
            push eax
            invoke SetFocus, eax
            pop eax
            invoke SendMessage, eax, EM_SETSEL, 0, -1
            xor eax, eax
            ret
@@:
            mov edi, taskPtr
            add edi, TASK_DUEDATE
            lea esi, EditDialogDate
            mov ecx, 16
            rep movsb

            ; Read Priority
            invoke GetDlgItem, hWnd, 5003
            invoke SendMessage, eax, CB_GETCURSEL, 0, 0
            mov EditDialogPriority, eax
            mov eax, taskPtr
            mov edx, EditDialogPriority
            mov [eax + TASK_PRIORITY], edx

            ; Refresh UI
            invoke GetWindow, hWnd, GW_OWNER
            mov ebx, eax
            invoke RefreshTaskList
            invoke UpdateStatusBar
            ; Re-enable parent and close
            .IF ebx != 0
                invoke EnableWindow, ebx, TRUE
                invoke SetForegroundWindow, ebx
            .ENDIF
            invoke DestroyWindow, hWnd
            xor eax, eax
            ret

        .ELSEIF id == 2 ; Cancel button
            invoke GetWindow, hWnd, GW_OWNER
            .IF eax != 0
                invoke EnableWindow, eax, TRUE
                invoke SetForegroundWindow, eax
            .ENDIF
            invoke DestroyWindow, hWnd
            xor eax, eax
            ret
        .ENDIF

        xor eax, eax
        ret

    .ELSEIF uMsg == WM_CLOSE
        invoke GetWindow, hWnd, GW_OWNER
        .IF eax != 0
            invoke EnableWindow, eax, TRUE
            invoke SetForegroundWindow, eax
        .ENDIF
        invoke DestroyWindow, hWnd
        xor eax, eax
        ret

    .ELSEIF uMsg == WM_DESTROY
        xor eax, eax
        ret
    .ENDIF
    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret
EditWndProc endp

; ----------------------------------------------------------------------------
; ValidateDate - Basic MM/DD/YYYY validation
; In: lpDate (pointer to 0-terminated string)
; Out: EAX = 1 valid, 0 invalid
; Rules: length 10, digits in positions 0,1,3,4,6,7,8,9 and '/' in 2,5
;        month 01-12, day 01-31, year >= 2024 (simple check)
; ----------------------------------------------------------------------------
ValidateDate proc lpDate:DWORD
    LOCAL month:DWORD
    LOCAL day:DWORD
    LOCAL year:DWORD
    ; Preserve callee-saved regs we use
    push ebx
    push esi
    push edi
    mov edx, lpDate
    ; Check length == 10
    mov ecx, 0
@@lenLoop:
    mov al, [edx+ecx]
    cmp al, 0
    je @@lenDone
    inc ecx
    cmp ecx, 11
    jge @@invalid
    jmp @@lenLoop
@@lenDone:
    cmp ecx, 10
    jne @@invalid
    ; Check separators
    mov al, [edx+2]
    cmp al, '/'
    jne @@invalid
    mov al, [edx+5]
    cmp al, '/'
    jne @@invalid
    ; Macro to check digit
    ; positions: 0 1 3 4 6 7 8 9
    mov esi, 0
@@digitLoop:
    mov eax, esi
    cmp eax, 10
    je @@digitsDone
    cmp eax, 2
    je @@skip
    cmp eax, 5
    je @@skip
    mov al, [edx+eax]
    cmp al, '0'
    jb @@invalid
    cmp al, '9'
    ja @@invalid
@@skip:
    inc esi
    jmp @@digitLoop
@@digitsDone:
    ; Parse month
    mov al, [edx]
    sub al, '0'
    mov ah, [edx+1]
    sub ah, '0'
    mov bl, 10
    mul bl ; AL*10 -> AX low
    add al, ah
    movzx eax, al
    mov month, eax
    cmp month, 1
    jb @@invalid
    cmp month, 12
    ja @@invalid
    ; Parse day
    mov al, [edx+3]
    sub al, '0'
    mov ah, [edx+4]
    sub ah, '0'
    mov bl, 10
    mul bl
    add al, ah
    movzx eax, al
    mov day, eax
    cmp day, 1
    jb @@invalid
    cmp day, 31
    ja @@invalid
    ; Parse year
    mov year, 0
    xor ecx, ecx
@@yearLoop:
    mov al, [edx+ecx+6]
    sub al, '0'
    cmp al, 0
    jl @@invalid
    cmp al, 9
    jg @@invalid
    movzx ebx, al
    mov eax, year
    mov edi, eax        ; Use EDI instead of EDX to avoid clobbering string pointer
    shl eax, 3
    lea eax, [eax + edi*2]
    add eax, ebx
    mov year, eax
    inc ecx
    cmp ecx, 4
    jl @@yearLoop
    cmp year, 2024
    jb @@invalid
    mov eax, 1
    jmp @@exit
@@invalid:
    xor eax, eax
@@exit:
    pop edi
    pop esi
    pop ebx
    ret
ValidateDate endp

; ----------------------------------------------------------------------------
; SaveTasks - Save tasks to file
; ----------------------------------------------------------------------------
SaveTasks proc hWnd:HWND
    LOCAL ofn:OPENFILENAME
    LOCAL hFile:DWORD
    LOCAL bytesWritten:DWORD
    
    ; Initialize OPENFILENAME structure
    invoke RtlZeroMemory, ADDR ofn, SIZEOF OPENFILENAME
    mov ofn.lStructSize, SIZEOF OPENFILENAME
    mov eax, hWnd
    mov ofn.hwndOwner, eax
    mov ofn.lpstrFilter, OFFSET FileFilter
    mov ofn.lpstrFile, OFFSET FileNameBuffer
    mov ofn.nMaxFile, 260
    mov ofn.lpstrDefExt, OFFSET DefExt
    mov ofn.lpstrTitle, OFFSET SaveTitle
    mov ofn.Flags, OFN_OVERWRITEPROMPT or OFN_PATHMUSTEXIST
    
    ; Clear filename buffer
    invoke RtlZeroMemory, OFFSET FileNameBuffer, 260
    
    ; Show save dialog
    invoke GetSaveFileName, ADDR ofn
    cmp eax, 0
    je @@Cancelled
    
    ; Create file
    invoke CreateFile, OFFSET FileNameBuffer, GENERIC_WRITE, 0, NULL, \
           CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je @@Error
    mov hFile, eax
    
    ; Write task count
    invoke WriteFile, hFile, ADDR TaskCount, 4, ADDR bytesWritten, NULL
    cmp eax, 0
    je @@WriteError
    
    ; Write NextTaskID
    invoke WriteFile, hFile, ADDR NextTaskID, 4, ADDR bytesWritten, NULL
    cmp eax, 0
    je @@WriteError
    
    ; Write all tasks
    mov eax, TaskCount
    mov ecx, TASK_SIZE
    mul ecx
    mov ecx, eax  ; Save size in ecx
    invoke WriteFile, hFile, ADDR TaskArray, ecx, ADDR bytesWritten, NULL
    cmp eax, 0
    je @@WriteError
    
    ; Close file
    invoke CloseHandle, hFile
    
    invoke MessageBox, hWnd, ADDR MsgSaved, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
    
@@WriteError:
    invoke CloseHandle, hFile
    invoke MessageBox, hWnd, ADDR MsgWriteError, ADDR MsgError, MB_OK or MB_ICONERROR
    ret
    
@@Error:
    invoke MessageBox, hWnd, ADDR MsgFileError, ADDR MsgError, MB_OK or MB_ICONERROR
    ret
    
@@Cancelled:
    ret
SaveTasks endp

; ----------------------------------------------------------------------------
; LoadTasks - Load tasks from file
; ----------------------------------------------------------------------------
LoadTasks proc hWnd:HWND
    LOCAL ofn:OPENFILENAME
    LOCAL hFile:DWORD
    LOCAL bytesRead:DWORD
    
    ; Initialize OPENFILENAME structure
    invoke RtlZeroMemory, ADDR ofn, SIZEOF OPENFILENAME
    mov ofn.lStructSize, SIZEOF OPENFILENAME
    mov eax, hWnd
    mov ofn.hwndOwner, eax
    mov ofn.lpstrFilter, OFFSET FileFilter
    mov ofn.lpstrFile, OFFSET FileNameBuffer
    mov ofn.nMaxFile, 260
    mov ofn.lpstrDefExt, OFFSET DefExt
    mov ofn.lpstrTitle, OFFSET LoadTitle
    mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST
    
    ; Clear filename buffer
    invoke RtlZeroMemory, OFFSET FileNameBuffer, 260
    
    ; Show open dialog
    invoke GetOpenFileName, ADDR ofn
    cmp eax, 0
    je @@Cancelled
    
    ; Open file
    invoke CreateFile, OFFSET FileNameBuffer, GENERIC_READ, 0, NULL, \
           OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, NULL
    cmp eax, INVALID_HANDLE_VALUE
    je @@Error
    mov hFile, eax
    
    ; Read task count
    invoke ReadFile, hFile, ADDR TaskCount, 4, ADDR bytesRead, NULL
    cmp eax, 0
    je @@ReadError
    cmp bytesRead, 4
    jne @@ReadError
    
    ; Read NextTaskID
    invoke ReadFile, hFile, ADDR NextTaskID, 4, ADDR bytesRead, NULL
    cmp eax, 0
    je @@ReadError
    cmp bytesRead, 4
    jne @@ReadError
    
    ; Validate task count
    mov eax, TaskCount
    cmp eax, MAX_TASKS
    jg @@ReadError
    
    ; Read all tasks
    mov eax, TaskCount
    mov ecx, TASK_SIZE
    mul ecx
    mov ecx, eax  ; Save size in ecx
    invoke ReadFile, hFile, ADDR TaskArray, ecx, ADDR bytesRead, NULL
    cmp eax, 0
    je @@ReadError
    
    ; Close file
    invoke CloseHandle, hFile
    
    invoke RefreshTaskList
    invoke UpdateStatusBar
    invoke MessageBox, hWnd, ADDR MsgLoaded, ADDR MsgInfo, MB_OK or MB_ICONINFORMATION
    ret
    
@@ReadError:
    invoke CloseHandle, hFile
    ; Reset to safe state
    mov TaskCount, 0
    mov NextTaskID, 1
    invoke MessageBox, hWnd, ADDR MsgReadError, ADDR MsgError, MB_OK or MB_ICONERROR
    ret
    
@@Error:
    invoke MessageBox, hWnd, ADDR MsgFileError, ADDR MsgError, MB_OK or MB_ICONERROR
    ret
    
@@Cancelled:
    ret
LoadTasks endp

; ----------------------------------------------------------------------------
; SortTasks - Sort tasks by priority (high to low)
; ----------------------------------------------------------------------------
SortTasks proc
    LOCAL i:DWORD
    LOCAL j:DWORD
    LOCAL taskPtr1:DWORD
    LOCAL taskPtr2:DWORD
    LOCAL tempTask[256]:BYTE
    LOCAL swapped:DWORD
    LOCAL cmpResult:DWORD
    LOCAL val1:DWORD
    LOCAL val2:DWORD
    LOCAL id1:DWORD
    LOCAL id2:DWORD
    
    ; Simple bubble sort
    mov i, 0
    
@@OuterLoop:
    mov eax, TaskCount
    dec eax
    cmp i, eax
    jge @@SortDone
    
    mov swapped, 0
    mov j, 0
    
@@InnerLoop:
    mov eax, TaskCount
    sub eax, i
    dec eax
    cmp j, eax
    jge @@InnerDone
    
    ; Get pointers to adjacent tasks
    mov eax, j
    mov ecx, TASK_SIZE
    mul ecx
    lea edx, TaskArray
    add eax, edx
    mov taskPtr1, eax
    
    add eax, TASK_SIZE
    mov taskPtr2, eax
    
    ; Get task IDs for tiebreaker
    mov esi, taskPtr1
    mov eax, [esi + TASK_ID]
    mov id1, eax
    mov esi, taskPtr2
    mov eax, [esi + TASK_ID]
    mov id2, eax
    
    ; Compare based on SortMode
    mov eax, SortMode
    .IF eax == 0
        ; Priority sort
        mov esi, taskPtr1
        mov eax, [esi + TASK_PRIORITY]
        mov val1, eax
        mov esi, taskPtr2
        mov eax, [esi + TASK_PRIORITY]
        mov val2, eax
    .ELSEIF eax == 1
        ; Date sort - compare as strings
        mov esi, taskPtr1
        lea esi, [esi + TASK_DUEDATE]
        mov edi, taskPtr2
        lea edi, [edi + TASK_DUEDATE]
        invoke lstrcmp, esi, edi
        mov cmpResult, eax
        jmp @@CheckDirection
    .ELSE
        ; ID sort
        mov eax, id1
        mov val1, eax
        mov eax, id2
        mov val2, eax
    .ENDIF
    
    ; Compare values (for priority and ID)
    mov eax, val1
    mov edx, val2
    cmp eax, edx
    je @@UseTiebreaker
    ; Not equal - determine swap based on direction
    mov cmpResult, 0
    .IF eax > edx
        mov cmpResult, 1
    .ELSE
        mov cmpResult, -1
    .ENDIF
    jmp @@CheckDirection
    
@@UseTiebreaker:
    ; Values equal - use ID as tiebreaker (always ascending)
    mov eax, id1
    mov edx, id2
    cmp eax, edx
    jle @@NoSwap
    mov cmpResult, 1
    jmp @@DoSwap
    
@@CheckDirection:
    ; Apply ascending/descending
    mov eax, SortAscending
    .IF eax == 1
        ; Ascending: swap if cmpResult > 0
        mov eax, cmpResult
        cmp eax, 0
        jle @@NoSwap
    .ELSE
        ; Descending: swap if cmpResult < 0
        mov eax, cmpResult
        cmp eax, 0
        jge @@NoSwap
    .ENDIF
    
@@DoSwap:
    ; Swap tasks
    mov esi, taskPtr1
    lea edi, tempTask
    mov ecx, TASK_SIZE
    rep movsb
    
    mov esi, taskPtr2
    mov edi, taskPtr1
    mov ecx, TASK_SIZE
    rep movsb
    
    lea esi, tempTask
    mov edi, taskPtr2
    mov ecx, TASK_SIZE
    rep movsb
    
    mov swapped, 1
    
@@NoSwap:
    inc j
    jmp @@InnerLoop
    
@@InnerDone:
    cmp swapped, 0
    je @@SortDone
    inc i
    jmp @@OuterLoop
    
@@SortDone:
    ret
SortTasks endp

; ----------------------------------------------------------------------------
; UpdateStatusBar - Update status bar with task count
; ----------------------------------------------------------------------------
UpdateStatusBar proc
    ; Simplified - just set a static message for now
    invoke SetWindowText, hStatusText, ADDR StatusFmt
    ret
UpdateStatusBar endp

END start
