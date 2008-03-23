
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" File:         (G)Vim script file named srcexpl.vim
" Description:  A (G)VIM Plugin for exploring the C/C++ 
"               source code based on 'tags' and 'quickfix'.
" Author:       Che Wenlong
" Mail:         chewenlong AT buaa.edu.cn
" Copyright:    Copyright (C) 2008
" Last Change:  2008 Mar 23

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The_setting_example_in_my_vimrc_file:-)

" // Set one second time for refreshing
" let g:SrcExpl_RefreshTime   = 1
" // Set the window height of the Souce Explorer
" let g:SrcExpl_WinHeight     = 9
" // Set "Space" key do the refreshing operation
" let g:SrcExpl_RefreshMapKey = "<Space>"
" // Set "Ctrl-b" key go back from the definition context
" let g:SrcExpl_GoBackMapKey  = "<C-b>"
" // The switch of Source Explorer plugin
" nmap <F8> :SrcExplToggle<CR>

" Just_change_above_of_them_by_yourself:-)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if exists("loaded_srcexpl")
    finish
endif

let loaded_srcexpl = 1
let s:save_cpo = &cpoptions

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Source Explorer Plugin version control

if v:version < 700
    " Tell users the reason
    echohl WarningMsg | 
        \ echo "You need VIM v7.0 or later for SrcExpl Plugin" 
            \ | echohl None
    finish
endif

set cpoptions&vim

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" User interface for switching the Source Explorer Plugin
command! -nargs=0 -bar SrcExplToggle 
    \ call <SID>SrcExpl_Toggle()

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" User interface for changing the 
" height of the Source Explorer Window
if !exists('g:SrcExpl_WinHeight')
    let g:SrcExpl_WinHeight = 10
endif

" User interface for setting the 
" update time interval of each refreshing
if !exists('g:SrcExpl_RefreshTime')
    let g:SrcExpl_RefreshTime = 1
endif

" User interface for back from 
" the definition context
if !exists('g:SrcExpl_GoBackMapKey')
    let g:SrcExpl_GoBackMapKey = ""
endif

" User interface for refreshing one
" definition searching manually
if !exists('g:SrcExpl_RefreshMapKey')
    let g:SrcExpl_RefreshMapKey = ""
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Version information for display
let s:SrcExpl_VerInfo       =   "Source Explorer V2.1"
" Buffer Title for buffer listing
let s:SrcExpl_BufTitle      =   "__Source_Explorer__"
" The whole path of 'tags' file
let s:SrcExpl_TagsFilePath  =   ""
" The key word symbol for exploring
let s:SrcExpl_Symbol        =   ""
" Whole file path being explored now
let s:SrcExpl_FilePath      =   ""
" ID number of srcexpl.vim
let s:SrcExpl_ScriptID      =   0
" Current line number of the key word symbol
let s:SrcExpl_CurrLine      =   0
" Current col number of the key word symbol
let s:SrcExpl_CurrCol       =   0
" Source Explorer switch flag
let s:SrcExpl_Switch        =   0
" Source Explorer status:
" 1: exploring, 2: no definition
" 3: multi-definitions
let s:SrcExpl_Status        =   0

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" NOTE: You gugs can change this function by yourselves 
"       in order to adapt the editor window position for
"       the Source Explorer position.

function! g:SrcExpl_OtherPluginAdapter()
    " If the Taglist Plugin existed
    if bufname("%") == "__Tag_List__"
        " Move the cursor to its right window.
        " Because I used to put the taglist
        " Window on my left.
        silent! wincmd l
    endif
    " If the MiniBufExplorer Plugin existed
    if bufname("%") == "-MiniBufExplorer-"
        " Move the cursor to the window behind.
        " Because I used to put the minibufexpl
        " Window on the top position.
        silent! wincmd j
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Refresh the Source Explorer window and update the status

function! g:SrcExpl_Refresh()
    " Only Source Explorer window is valid 
    if &previewwindow
        return
    endif
    " Get the symbol under the cursor
    let l:result = <SID>SrcExpl_GetSymbol()
    " The symbol is invalid
    if l:result != 0
        return
    endif
    " Explore the source code using tag tool
    " First Just try to get the definition of the symbol
    try
        " First move to the Source Explorer window
        silent! wincmd P
        if &previewwindow
            " Get the whole file path of the buffer before tag
            let s:SrcExpl_FilePath = expand("%:p")
            " Get the current line before tag
            let s:SrcExpl_CurrLine = line(".")
            " Get the current colum before tag
            let s:SrcExpl_CurrCol = col(".")
            " Go back to the privious window
            silent! wincmd p
            " Indeed back to the editor window
            call g:SrcExpl_OtherPluginAdapter()
        endif
        " Begin to tag the symbol
        exe "silent " . "ptag " . s:SrcExpl_Symbol
    catch
        " Tag unsuccessfully
        let s:SrcExpl_Status = 3
        " Tell the Source Explorer window wyh
        call <SID>SrcExpl_DefNotFind()
        " Go back to the privious window again
        silent! wincmd p
        " Indeed back to the editor window
        call g:SrcExpl_OtherPluginAdapter()
        return
    endtry
    " Tag successfully and move to the preview window
    silent! wincmd P
    if &previewwindow
        " Judge that if or not point to the definition
        if (s:SrcExpl_FilePath == expand("%:p")) &&
            \ (s:SrcExpl_CurrLine == line(".")) &&
                \ (s:SrcExpl_CurrCol == col("."))
            " Mulitple definitions
            let s:SrcExpl_Status = 2
            " List the multi-definitions in the Source Explorer
            call <SID>SrcExpl_FindMultiDefs()
        else " Source Explorer Has pointed to the definition already
            let s:SrcExpl_Status = 1
            " Make the definition hightlight
            call <SID>SrcExpl_MatchSymbol()
        endif
        " Go back to the privious window again
        silent! wincmd p
        " Indeed back to the editor window
        call g:SrcExpl_OtherPluginAdapter()
    endif

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Go Back from the definition context.
" Users can call this function using their mapping key.

function! g:SrcExpl_GoBack()
    " Can not do this operation in Source Explorer
    if (!&previewwindow)
        " Jump back to the privous place
        exe "normal \<C-O>"
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Opreation when WinEnter Event happens

function! <SID>SrcExpl_WinEnter()
    " In the Source Explorer
    if &previewwindow
        if has("gui_running")
            " Delet the SrcExplGoBack item in Popup menu
            silent! nunmenu 1.01 PopUp.&SrcExplGoBack
            " Do the mapping for 'double-click' and 'enter'
            if maparg('<2-LeftMouse>', 'n') == ''
                nnoremap <silent> <2-LeftMouse> 
                    \ :call <SID>SrcExpl_Jump()<CR>
            endif
        endif
        if maparg('<CR>', 'n') == ''
            nnoremap <silent> <CR> :call <SID>SrcExpl_Jump()<CR>
        endif
    " Other windows
    else
        if has("gui_running")
            " You can use SrcExplGoBack item in Popup menu
            " to go back from the definition
            silent! nnoremenu 1.01 PopUp.&SrcExplGoBack 
                \ :call g:SrcExpl_GoBack()<CR>
            " Unmapping the exact mapping of 'double-click' and 'enter'
            if maparg("<2-LeftMouse>", "n") == 
                    \ ":call <SNR>" . s:SrcExpl_ScriptID . 
                \ "SrcExpl_Jump()<CR>"
                nunmap <silent> <2-LeftMouse>
            endif
        endif
        if maparg("<CR>", "n") == ":call <SNR>" . 
            \ s:SrcExpl_ScriptID . "SrcExpl_Jump()<CR>"
            nunmap <silent> <CR>
        endif
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Highlight the Symbol of definition

function! <SID>SrcExpl_MatchSymbol()
    " First open the folding if exists
    if has("folding")
        silent! .foldopen
    endif
    " Match the symbol and make it highlight
	call search("$", "b")
	let s:SrcExpl_Symbol = substitute(s:SrcExpl_Symbol, 
        \ '\\', '\\\\', "")
	call search('\<\V' . s:SrcExpl_Symbol . '\>')
    hi SrcExpl_HighLight term=bold guifg=Black guibg=Magenta
	exe 'match SrcExpl_HighLight "\%' . line(".") . 'l\%' . 
        \ col(".") . 'c\k*"'
    " Save the file path, the current line and the current 
    " col of the definition
    let s:SrcExpl_FilePath = expand("%:p")
    let s:SrcExpl_CurrLine = line(".")
    let s:SrcExpl_CurrCol = col(".")
endfunction!

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Select one of multi-definitions, and jump to there.

function! <SID>SrcExpl_SelectToJump()

    let l:i = 0
    let l:f = ""
    let l:s = ""

    " Get the item data that user selected
    let l:list = getline(".")

    " Traverse the prompt string until get the 
    " file path
    while !((l:list[l:i] == ']') && 
        \ (l:list[l:i + 1] == ':'))
        let l:i += 1
    endwhile
    " Done
    let l:i += 3
    " Get the whole file path of the exact definition
    while !((l:list[l:i] == ' ') && 
        \ (l:list[l:i + 1] == '[')) 
        let l:f = l:f . l:list[l:i]
        let l:i += 1
    endwhile
    " Done
    let l:i += 2
    " Traverse the prompt string until get the symbol
    while !((l:list[l:i] == ']') && 
        \ (l:list[l:i + 1] == ':'))
        let l:i += 1
    endwhile
    " Done
    let l:i += 3
    " Get the EX symbol in order to jump
    while l:list[l:i] != ''
        " If the '*' in the function definition,
        " then we add the '\' in front of it.
        if (l:list[l:i] == '*') && (l:list[l:i - 1] != '\')
            let l:s = l:s . '\' . '*'
        else
            let l:s = l:s . l:list[l:i]
        endif
        let l:i += 1
    endwhile
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_OtherPluginAdapter()
    " Open the file of definition context
    if expand("%:p") != l:f
        exe "edit " . l:f
    endif
    " Use EX Pattern to Jump to the exact line of the definition
    silent! exe l:s
    " Match the symbol word under the cursor
	call search("$", "b")
	let s:SrcExpl_Symbol = substitute(s:SrcExpl_Symbol, 
        \ '\\', '\\\\', "")
	call search('\<\V' . s:SrcExpl_Symbol . '\>')
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Jump to the editor window and point to the definition

function! <SID>SrcExpl_Jump()
    " Only do the operation on the Source Explorer 
    " window is valid
    if !&previewwindow
        return
    endif
    " Do we get the definition already?
    if (bufname("%") == s:SrcExpl_BufTitle)
        if s:SrcExpl_Status == 3 " No definition
            return
        endif
    endif
   " We got Multiple definitions
    if s:SrcExpl_Status == 2
        call <SID>SrcExpl_SelectToJump()
        return
    endif
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_OtherPluginAdapter()

    if s:SrcExpl_Status == 1
        " Open the buffer using editor
        exe "edit " . s:SrcExpl_FilePath
        " Jump to the context line of that symbol
        call cursor(s:SrcExpl_CurrLine, s:SrcExpl_CurrCol)
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" List the multi-definitions of symbol under the cursor onto
" the Source Explorer window.

function! <SID>SrcExpl_ListMultiDefs(path, list)

    let l:bufnum = bufnr("__Source_Explorer__")

    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = "__Source_Explorer__"
    else
        " Edit the existing buffer
        let l:wcmd = '+buffer' . l:bufnum
    endif
    " Reopen the Source Explorer idle window
    exe "silent! " . "pedit " . l:wcmd

    silent! wincmd P

    if &previewwindow
        " Reset the proprity of the Source Explorer
        setlocal modifiable
        setlocal buflisted
        setlocal buftype=nofile
        " Set the loop flag
        let l:i  = 0
        let l:f = ""
        let l:s = ""
        " Parse each pattern line data in the tags file
        while a:list[l:i] != ''
            " Firstly, get the file path start point
            while a:list[l:i] != nr2char(9)
                let l:i += 1
            endwhile
            " Got it
            let l:i += 1
            " Use the whole file path
            let l:f = a:path
            " UNIXs OS
            if has("unix")
                let l:f = l:f . '/'
            " Windows
            else
                let l:f = l:f . '\'
            endif
            " Secondly, store the whole file path
            while a:list[l:i] != nr2char(9)
                let l:f = l:f . a:list[l:i]
                let l:i += 1
            endwhile
            " Done
            let l:i += 1
            " Thirdly, Store the Ex symbol
            while !((a:list[l:i] == ';') && 
                \ (a:list[l:i + 1] == '"'))
                let l:s = l:s . a:list[l:i]
                let l:i += 1
            endwhile
            " Done
            let l:i += 2
            " Prepare to parse the next match line data
            while !((a:list[l:i] == '!') && 
                \ (a:list[l:i + 1] == '@') &&
            \ (a:list[l:i + 2] == '#') && 
                \ (a:list[l:i + 3] == '$'))
                let l:i += 1
            endwhile
            " List the previous line data on the Source 
            " Explorer Window.
            exe "normal a" . "[File Path]: " . l:f . " " . 
                \ "[EX Pattern]: " . l:s
            " Clean the buffers
            let l:f = ""
            let l:s = ""
            " Next line
            let l:i += 4
            exe "normal o"
        endwhile
    endif
    " Remove the last line
    exe "normal dd"
    " Back to the first line
    exe "normal gg"
    setlocal nomodifiable
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Find the multi-definitions in Tags file and show them on the
" Source Explorer Window.

function! <SID>SrcExpl_FindMultiDefs()

    let l:tags = ""
    let l:line = 0
    
    " The tags file must be available, or quit.
    if (s:SrcExpl_TagsFilePath == "") ||
        \ (!filereadable(s:SrcExpl_TagsFilePath))
        let s:SrcExpl_Status = 3
        call <SID>SrcExpl_DefNotFind()
        return
    endif
    " Set the searche pattern in Tags file.
    let l:symbol = '^\<' . s:SrcExpl_Symbol . '\>'
    " Get the buffer of the Tags file
    let l:bufnum = bufnr(s:SrcExpl_TagsFilePath)

    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = s:SrcExpl_TagsFilePath
    else
    " Edit the existing buffer
        let l:wcmd = '+buffer' . l:bufnum
    endif
    " Open the tags file window
    exe "silent! " . "pedit " . l:wcmd

    silent! wincmd P
        
    if &previewwindow
        " Loop to get all symbol lines in Tags file.
        while 1
            " Search the whole Tags file up to down
            let l:line = search(l:symbol, 'W')
            " Search one symbol line
            if l:line != 0
                " Set my private flag '!@#$' to separate
                " one symbol line from another
                let l:tags = l:tags . getline(".") . "!@#$"
            else
                " Search work is done, then list them.
                call <SID>SrcExpl_ListMultiDefs(getcwd(), l:tags)
                return
            endif
        endwhile
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Report to the Source Explorer what happens

function! <SID>SrcExpl_DefNotFind()
    " Do the Source Explorer exsited already?
    let l:bufnum = bufnr(s:SrcExpl_BufTitle)

    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = s:SrcExpl_BufTitle
    else
        " Edit the existing buffer
        let l:wcmd = '+buffer' . l:bufnum
    endif
    " Reopen the Source Explorer idle window
    exe "silent! " . "pedit " . l:wcmd
    " Move to it
    silent! wincmd P
    if &previewwindow
        " First make it modifiable
        setlocal modifiable
        " Just delete all content
        "silent! %delete _
        setlocal buflisted
        setlocal buftype=nofile
        " Report the reason why Source Explorer
        " can not point to the definition
        if s:SrcExpl_Status == 3
            normal aDefinition Not Found
        endif
        " Make it unmodifiable again
        setlocal nomodifiable
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Get key word symbol under the current cursor

function! <SID>SrcExpl_GetSymbol()
    " Get the current charactor under the cursor
    let l:cchar = getline('.')[col('.') - 1]
    " Change it to ASCII code
    let l:ascii = eval(char2nr(l:cchar))

    " Judge that if or not the charactor is invalid,
    " beause only 0-9, a-z, A-Z, and '_' are valid
    if (l:ascii >= 48 && l:ascii <= 57) || 
            \ (l:ascii >= 65 && l:ascii <= 90) ||
        \ (l:ascii >= 97 && l:ascii <= 122) ||
                \ (l:ascii == 95) 
        " The key word symbol has been explored
        " just now, so should not explore that again
        if s:SrcExpl_Symbol == expand("<cword>")
            return -1
        " Get a new key word symbol
        else
            let s:SrcExpl_Symbol = expand("<cword>")
        endif
    " Invalid charactor
    else
        if s:SrcExpl_Symbol == ""
            return -1 " Second, third ...
        else " First
            let s:SrcExpl_Symbol = ""
        endif
    endif
    return 0
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Probe if or not there is a 'tags' file under the project PATH

function! <SID>SrcExpl_AccessTags()    
    " Just save the CWD info
    let l:temp = ""
    
    " Loop to probe the tags in CWD
    while !filereadable("tags")
        " First save
        let l:temp = getcwd()
        " Up to my parent directory
        cd ..
        " Have been up to the system root dir
        if l:temp == getcwd()
            " So break out
            break
        endif
    endwhile    
    " Indeed in the system root dir
    if l:temp == getcwd()
        " Clean the buffer
        let s:SrcExpl_TagsFilePath = ""
    " Have found a 'tags' file already
    else
        " UNIXs OS
        if has("unix")
            if getcwd()[strlen(getcwd()) - 1] == '/'
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . "tags"
            else
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . "/tags"
            endif
        " WINDOWS
        else
            if getcwd()[strlen(getcwd()) - 1] == '\'
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . "tags"
            else
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . "\\tags"
            endif
        endif
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Clean up the rubbish of plugin and free the mapping resouces

function! <SID>SrcExpl_Cleanup()
    " GUI Version
    if has("gui_running")
        " Delet the SrcExplGoBack item in Popup menu
        silent! nunmenu 1.01 PopUp.&SrcExplGoBack
        " Make the 'double-click' and 'enter' for nothing
        if maparg('<2-LeftMouse>', 'n') != ''
            unmap <silent> <2-LeftMouse>
        endif
    endif
    if maparg('<CR>', 'n') != ''
        unmap <silent> <CR>
    endif
    " Unmap the user's key
    if maparg(g:SrcExpl_RefreshMapKey, 'n') == 
        \ ":call g:SrcExpl_Refresh()<CR>"
        exe "unmap " . g:SrcExpl_RefreshMapKey
    endif
    " Unmap the user's key
    if maparg(g:SrcExpl_GoBackMapKey, 'n') == 
        \ ":call g:SrcExpl_GoBack()<CR>"
        exe "unmap " . g:SrcExpl_GoBackMapKey
    endif
    " Unload the autocmd group
    silent! autocmd! SrcExpl_AutoCmd
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Initialize the Souce Explorer proprities

function! <SID>SrcExpl_Initialize()
    " Access the Tags file 
    call <SID>SrcExpl_AccessTags()
    " Found one Tags file
    if s:SrcExpl_TagsFilePath != ""
        " First set the height of preview window
        exe "set previewheight=". string(g:SrcExpl_WinHeight)
        " Load the Tags file into buffer
        exe "silent! " . "pedit " . s:SrcExpl_TagsFilePath
    else
        " Can not find any tags file in the project path or its
        " parent directory.
        echohl ErrorMsg | 
            \ echo "SrcExpl Plugin: There is no tags file in $PATH." 
        \ | echohl None
        " Quit
        return -1
    endif
    " Set the actual update time according to user's requestion
    " one second/times by default
    exe "set updatetime=" . string(g:SrcExpl_RefreshTime * 1000)
    " Map the user's key to go back from the 
    " definition context.
    if g:SrcExpl_GoBackMapKey != ""
        exe "nnoremap " . g:SrcExpl_GoBackMapKey . 
            \ " :call g:SrcExpl_GoBack()<CR>"
    endif
    " Map the user's key to refresh the definition
    " updating manually.
    if g:SrcExpl_RefreshMapKey != ""
        exe "nnoremap " . g:SrcExpl_RefreshMapKey . 
            \ " :call g:SrcExpl_Refresh()<CR>"
    endif
    " First get the srcexpl.vim's ID
    map <SID>xx <SID>xx
    let s:SrcExpl_ScriptID = substitute(maparg('<SID>xx'), 
        \ '<SNR>\(\d\+_\)xx$', '\1', '')
    unmap <SID>xx
    " Then form an autocmd group
    augroup SrcExpl_AutoCmd
        " Delete the autocmd group first
        autocmd!
        au! CursorHold * nested call g:SrcExpl_Refresh()
        au! WinEnter * nested call <SID>SrcExpl_WinEnter()
    augroup end
    " Initialize successfully
    return 0
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Close the Source Explorer window and delete its buffer

function! <SID>SrcExpl_CloseWin()
    " Just close the preview window
    pclose
    " Judge if or not the Source Explorer
    " buffer had been deleted
    let l:bufnum = bufnr(s:SrcExpl_BufTitle)
    " Existed indeed
    if l:bufnum != -1
        exe "bdelete! " . s:SrcExpl_BufTitle
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Open the Source Explorer window under the bottom of (G)Vim,
" and set the buffer's proprity of the Source Explorer

function! <SID>SrcExpl_OpenWin()
    " Open the Source Explorer window as the idle one
    exe "silent! " . "pedit " . s:SrcExpl_BufTitle
    " Jump to the Source Explorer
    silent! wincmd P
    " Open successfully and jump to it indeed
    if &previewwindow
        " Show its name on the buffer list
        setlocal buflisted
        " No exact file
        setlocal buftype=nofile
        " Display the version of the Source Explorer
        exe "normal a" . s:SrcExpl_VerInfo
        " Make it no modifiable
        setlocal nomodifiable
        " Put it on the bottom of (G)Vim
        silent! wincmd J
    endif
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_OtherPluginAdapter()
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The User Interface function for open / close
" the Source Explorer

function! <SID>SrcExpl_Toggle()
    " Closed
    if s:SrcExpl_Switch == 0        
        " Initialize the proprities
        let l:result = <SID>SrcExpl_Initialize()
        " Initialize unsuccessfully
        if l:result != 0
            return
        endif
        " Create the window
        call <SID>SrcExpl_OpenWin()
        " Set the switch flag on
        let s:SrcExpl_Switch = 1
    " Opened
    else
        " Set the switch flag off
        let  s:SrcExpl_Switch = 0
        " Close the window
        call <SID>SrcExpl_CloseWin()
        " Do the cleaning work
        call <SID>SrcExpl_Cleanup()
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set cpoptions&
let &cpoptions = s:save_cpo
unlet s:save_cpo

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

