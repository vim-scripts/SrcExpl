
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" File Name:      srcexpl.vim
" Abstract:       A (G)VIM plugin for exploring the source code 
"                 based on 'tags' and 'quickfix', and it works 
"                 like the context window in the Souce Insight.
" Author:         Wenlong Che
" EMail:          chewenlong @ buaa.edu.cn
" Version:        2.6
" Last Change:    July 26, 2008

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The_setting_example_in_my_vimrc_file:-)

" // Set 300 ms for refreshing the Source Explorer
" let g:SrcExpl_refreshTime  = 300

" // Set the window height of Source Explorer
" let g:SrcExpl_winHeight    = 9

" // Let the Source Explorer update the tags file when opening
" let g:SrcExpl_updateTags   = 1

" // Set "Space" key for refresh the Source Explorer manually
" let g:SrcExpl_refreshKey   = "<Space>"

" // Set "Ctrl-b" key for back from the definition context
" let g:SrcExpl_gobackKey    = "<C-b>"

" // In order to Aviod conflicts, the Source Explorer should know
" // what plugins are using buffers. And you need add their bufnames
" // into the list below according to the command ":buffers!" 
" let g:SrcExpl_pluginList = [
"         \ "__Tag_List__", 
"         \ "_NERD_tree_", 
"         \ "Source_Explorer"
"     \ ]

" // The switch of the Source Explorer
" nmap <F8> :SrcExplToggle<CR>

" Just_change_above_of_them_by_yourself:-)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" NOTE: The graph below shows my work platform with some VIM  
"       plugins, including 'Taglist', 'Source Explorer', and 
"       'MiniBufExplorer'.

" +----------------------------------------------------------+
" |" Press <F1> to|[1:demo.c]*                               |
" |               |                                          |
" |-demo.c--------|-MiniBufExplorer--------------------------|
" |               |                                          |
" |function       |/* This is the edit window. */            |
" |  foo          |                                          |
" |  bar          |void foo(void)                            |
" |               |{                                         |
" |~              |}                                         |
" |~              |                                          |
" |~              |void bar(void)                            |
" |~              |{                                         |
" |~              |}                                         |
" |~              |                                          |
" |~              |~                                         |
" |-__Tag_List__--|-demo.c-----------------------------------|
" |Source Explorer V2.6                                      |
" |                                                          |
" |~                                                         |
" |~                                                         |
" |~                                                         |
" |-Source_Explorer------------------------------------------|
" |:                                                         |
" +----------------------------------------------------------+

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Avoid reloading {{{

if exists('loaded_srcexpl')
    finish
endif

let loaded_srcexpl = 1
let s:save_cpo = &cpoptions

" }}}

" VIM version control {{{

" The VIM version control for running the Source Explorer

if v:version < 700
    " Tell users the reason
    echohl ErrorMsg | 
        \ echo "Require VIM 7.0 or above for running the Source Explorer." 
            \ | echohl None
    finish
endif

set cpoptions&vim

" }}}

" User interfaces {{{

" User interface for switching the Source Explorer

command! -nargs=0 -bar SrcExplToggle 
    \ call <SID>SrcExpl_Toggle()

" User interface for opening the Source Explorer

command! -nargs=0 -bar SrcExpl 
    \ call <SID>SrcExpl()
    
" User interface for closing the Source Explorer

command! -nargs=0 -bar SrcExplClose 
    \ call <SID>SrcExpl_Close()

" User interface for changing the 
" height of the Source Explorer Window
if !exists('g:SrcExpl_winHeight')
    let g:SrcExpl_winHeight = 10
endif

" User interface for setting the 
" update time interval of each refreshing
if !exists('g:SrcExpl_refreshTime')
    let g:SrcExpl_refreshTime = 500
endif

" User interface to update the 'tags'
" file when loading the Source Explorer
if !exists('g:SrcExpl_updateTags')
    let g:SrcExpl_updateTags = 0
endif

" User interface to go back from 
" the definition context
if !exists('g:SrcExpl_gobackKey')
    let g:SrcExpl_gobackKey = ''
endif

" User interface for refreshing one
" definition searching manually
if !exists('g:SrcExpl_refreshKey')
    let g:SrcExpl_refreshKey = ''
endif

" User interface for handling the 
" conflicts between the Source Explorer
" and other plugins
if !exists('g:SrcExpl_pluginList')
    let g:SrcExpl_pluginList = [
        \ "__Tag_List__", 
        \ "_NERD_tree_", 
        \ "Source_Explorer"
    \ ]
endif

" }}}

" Global varialbes {{{

" Buffer title for buffer listing
let s:SrcExpl_title         =    'Source_Explorer'

" The log file path for debug
let s:SrcExpl_logPath       =   './srcexpl.log'

" The whole path of 'tags' file
let s:SrcExpl_tagsPath      =   ''

" The key word symbol for exploring
let s:SrcExpl_symbol        =   ''

" Original work path when initilizing
let s:SrcExpl_rawWorkPath   =   ''

" Whole file path being explored now
let s:SrcExpl_currPath      =   ''

" Current line number of the key word symbol
let s:SrcExpl_currLine      =   0

" Current col number of the key word symbol
let s:SrcExpl_currCol       =   0

" Debug Switch for logging the debug information
let s:SrcExpl_isDebug       =   0

" ID number of SrcExpl.vim
let s:SrcExpl_scriptID      =   0

" The edit window position
let s:SrcExpl_editWin       =   0

" Source Explorer switch flag
let s:SrcExpl_isOpen        =   0

" Source Explorer status:
" 1: Single definition
" 2: Multi-definitions
" 3: No such tag definition
let s:SrcExpl_status        =   0

" }}}

" SrcExpl_Refresh() {{{

" Refresh the Source Explorer window and update the status

function! g:SrcExpl_Refresh()

    let l:exp = ""
    " If or not the cursor is on the edit window
    let l:rtn = <SID>SrcExpl_AdaptPlugins()

    if l:rtn != 0
        return
    endif

    " Only Source Explorer window is valid 
    if &previewwindow
        return
    endif
    " Avoid errors of multi-buffers
    if &modified
        " Tell the user what has happened
        echohl ErrorMsg | 
            \ echo "SrcExpl: The modified file is not saved."
        \ | echohl None
        return
    endif
    " Get the edit window position
    let s:SrcExpl_editWin = winnr()

    " Get the symbol under the cursor
    let l:rtn = <SID>SrcExpl_GetSymbol()
    " The symbol is invalid
    if l:rtn != 0
        return
    endif
    " call <SID>SrcExpl_Debug('s:SrcExpl_symbol is (' . s:SrcExpl_symbol . ')')
    let l:exp = '\C\<' . s:SrcExpl_symbol . '\>'
    " First move to the Source Explorer window
    silent! wincmd P
    if &previewwindow
        call <SID>SrcExpl_SetCurr()
        " Indeed go back to the edit window
        silent! exe s:SrcExpl_editWin . "wincmd w"
    endif
    " Explore the tag using tag tool
    " First Just try to get the definition of the symbol
    try
        " Begin to tag the symbol
        exe 'silent ' . 'ptag /' . l:exp
    catch
        " Call the 'gd' command to get the local definition
        " let l:rtn = <SID>SrcExpl_SearchDecl(l:exp)
        " if l:rtn < 0
            " Tag failed
            let s:SrcExpl_status = 3
            " Tell the Source Explorer window
            call <SID>SrcExpl_NoDef()
        " else
            " Tag to the local definition
            " let s:SrcExpl_status = 1
        " endif
        " Indeed go back to the edit window
        silent! exe s:SrcExpl_editWin . "wincmd w"
        return
    endtry
    " Tag successfully and move to the preview window
    silent! wincmd P
    if &previewwindow
        " Judge that if or not point to the definition
        if (s:SrcExpl_currPath ==# expand("%:p"))
            \  && (s:SrcExpl_currLine == line("."))
                \  && (s:SrcExpl_currCol == col("."))
            " Mulitple definitions
            let s:SrcExpl_status = 2
            " List the multi-definitions in the Source Explorer
            call <SID>SrcExpl_ListTags(l:exp)
        else " Source Explorer Has pointed to the definition already
            let s:SrcExpl_status = 1
            " Match the symbol
            call <SID>SrcExpl_MatchExpr()
            " Highlight the symbol
            call <SID>SrcExpl_HiExpr()
            " Set the current edit property
            call <SID>SrcExpl_SetCurr()
        endif
        " Indeed go back to the edit window
        silent! exe s:SrcExpl_editWin . "wincmd w"
    endif

endfunction " }}}

" SrcExpl_GoBack() {{{

" Go Back from the definition context.
" Users can call this function using their mapping key.

function! g:SrcExpl_GoBack()

    " Can not do this operation in Source Explorer
    if (!&previewwindow)
        " Jump back to the privous place
        exe "normal \<C-O>"
        " Open the folding if exists
        if has("folding")
            silent! . foldopen!
        endif
    endif

endfunction " }}}

" SrcExpl_EnterWin() {{{

" Opreation when WinEnter Event happens

function! <SID>SrcExpl_EnterWin()

    " If or not the cursor is on the edit window
    let l:rtn = <SID>SrcExpl_AdaptPlugins()

    " In the Source Explorer
    if (&previewwindow) || (l:rtn != 0)
        if has("gui_running")
            " Delete the SrcExplGoBack item in Popup menu
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
                    \ ":call <SNR>" . s:SrcExpl_scriptID . 
                \ "SrcExpl_Jump()<CR>"
                nunmap <silent> <2-LeftMouse>
            endif
        endif
        if maparg("<CR>", "n") == ":call <SNR>" . 
            \ s:SrcExpl_scriptID . "SrcExpl_Jump()<CR>"
            nunmap <silent> <CR>
        endif
    endif

endfunction " }}}

" SrcExpl_Debug() {{{

" Log the supplied debug information along with the time

function! <SID>SrcExpl_Debug(log)

    " Debug switch is on
    if s:SrcExpl_isDebug == 1
        " Log file path is valid
        if s:SrcExpl_logPath != ''
            " Output to the log file
            exe "redir >> " . s:SrcExpl_logPath
            " Add the current time
            silent echon strftime("%H:%M:%S") . ": " . a:log . "\r\n"
            redir END
        endif
    endif

endfunction " }}}

" SrcExpl_AdaptPlugins() {{{

" The Source Explorer window will not work when the cursor on the 

" window of other plugins, such as "Taglist", "MiniBufExplorer" etc.

function! <SID>SrcExpl_AdaptPlugins()

    " Traversal the list of other plugins
    for item in g:SrcExpl_pluginList
        " If they acted as a split window
        if bufname("%") ==# item
            " Just avoid this operation
            return 1
        endif
    endfor
    " Safe
    return 0

endfunction " }}}

" SrcExpl_SetCurr() {{{

" Save the current file path, line number and colum number

function! <SID>SrcExpl_SetCurr()

    " Get the whole file path of the buffer before tag
    let s:SrcExpl_currPath = expand("%:p")
    " Get the current line before tag
    let s:SrcExpl_currLine = line(".")
    " Get the current colum before tag
    let s:SrcExpl_currCol = col(".")

endfunction " }}}

" SrcExpl_MatchExpr() {{{

" Match the Symbol of definition

function! <SID>SrcExpl_MatchExpr()

    " First open the folding if exists
    if has("folding")
        silent! . foldopen!
    endif
    " Match the symbol and make it highlight
    call search("$", "b")
    let s:SrcExpl_symbol = substitute(s:SrcExpl_symbol, 
        \ '\\', '\\\\', "")
    call search('\V\C\<' . s:SrcExpl_symbol . '\>')

endfunction " }}}

" SrcExpl_HiExpr() {{{

" Highlight the Symbol of definition

function! <SID>SrcExpl_HiExpr()

    " Set the highlight color
    hi SrcExpl_HighLight term=bold guifg=Black guibg=Magenta ctermfg=Black ctermbg=Magenta
    " Highlight
    exe 'match SrcExpl_HighLight "\%' . line(".") . 'l\%' . 
        \ col(".") . 'c\k*"'

endfunction " }}}

" SrcExpl_SelToJump() {{{

" Select one of multi-definitions, and jump to there.

function! <SID>SrcExpl_SelToJump()

    " If point to the Jump list head, just avoid that
    if line(".") == 1
        return
    endif

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
        " If the '*', '[' and ']' in the function definition,
        " then we add the '\' in front of it.
        if (l:list[l:i] == '*')
            let l:s = l:s . '\' . '*'
        elseif (l:list[l:i] == '[')
            let l:s = l:s . '\' . '['
        elseif (l:list[l:i] == ']')
            let l:s = l:s . '\' . ']'
        else
            let l:s = l:s . l:list[l:i]
        endif
        let l:i += 1
    endwhile
    " Indeed go back to the edit window
    silent! exe s:SrcExpl_editWin . "wincmd w"
    " Open the file of definition context
    exe "edit " . s:SrcExpl_tagsPath . l:f
    " Use Ex Command to Jump to the exact line of the definition
    silent! exe l:s
    call <SID>SrcExpl_MatchExpr()

endfunction " }}}

" SrcExpl_Jump() {{{

" Jump to the edit window and point to the definition

function! <SID>SrcExpl_Jump()

    " Only do the operation on the Source Explorer 
    " window is valid
    if !&previewwindow
        return
    endif
    " Do we get the definition already?
    if (bufname("%") == s:SrcExpl_title)
        if s:SrcExpl_status == 3 " No definition
            return
        endif
    endif
   " We got multiple definitions
    if s:SrcExpl_status == 2
        call <SID>SrcExpl_SelToJump()
        return
    endif
    " Indeed go back to the edit window
    silent! exe s:SrcExpl_editWin . "wincmd w"
    " We got only one definition
    if s:SrcExpl_status == 1
        " Open the buffer using edit window
        exe "edit " . s:SrcExpl_currPath
        " Jump to the context line of that symbol
        call cursor(s:SrcExpl_currLine, s:SrcExpl_currCol)
        call <SID>SrcExpl_MatchExpr()
    endif

endfunction " }}}

" SrcExpl_NoDef() {{{

" Report to the Source Explorer what happens

function! <SID>SrcExpl_NoDef()

    " Do the Source Explorer exsited already?
    let l:bufnum = bufnr(s:SrcExpl_title)
    " Not existed
    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = s:SrcExpl_title
    else
        " Edit the existing buffer
        let l:wcmd = '+buffer' . l:bufnum
    endif
    " Reopen the Source Explorer idle window
    exe 'silent! ' . 'pedit ' . l:wcmd
    " Move to it
    silent! wincmd P
    if &previewwindow
        " First make it modifiable
        setlocal modifiable
        setlocal buflisted
        setlocal buftype=nofile
        " Report the reason why Source Explorer
        " can not point to the definition
        if s:SrcExpl_status == 3
            " Delete all lines in buffer.
            1,$d _
            " Goto the end of the buffer put the buffer list
            $
            " Display the version of the Source Explorer
            put! ='Definition Not Found'
            " Cancel all the hightlighted words
            match none
            " Delete the extra trailing blank line
            $ d _
        endif
        " Make it unmodifiable again
        setlocal nomodifiable
    endif

endfunction " }}}

" SrcExpl_ListTags() {{{

" Traversal the tags infomation from the tags file and list them

function! <SID>SrcExpl_ListTags(exp)

    " The tags file must be available, or quit.
    if s:SrcExpl_tagsPath == ""
        let s:SrcExpl_status = 3
        call <SID>SrcExpl_NoDef()
        return
    endif

    " Do the Source Explorer exsited already?
    let l:bufnum = bufnr(s:SrcExpl_title)
    " Create a new buffer
    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = s:SrcExpl_title
    else
        " Edit the existing buffer
        let l:wcmd = '+buffer' . l:bufnum
    endif
    " Reopen the Source Explorer idle window
    exe "silent! " . "pedit " . l:wcmd
    " Return to the preview window
    silent! wincmd P
    " Done
    if &previewwindow
        " Reset the proprity of the Source Explorer
        setlocal modifiable
        setlocal buflisted
        setlocal buftype=nofile
        " Delete all lines in buffer
        1,$d _
        " Get the tags dictionary array
        let l:list = taglist(a:exp)        
        " Begin build the Jump List for exploring the tags
        put! = '[Jump List]: '. s:SrcExpl_symbol . ' \|' . len(l:list) . '\| '
        " Match the symbol
        call <SID>SrcExpl_MatchExpr()
        " Highlight the symbol
        call <SID>SrcExpl_HiExpr()
        " Loop key & index
        let l:indx = 0
        " Loop for listing each tag from tags file
        while 1
            " First get each tag list
            let l:dict = get(l:list, l:indx, {})
            " There is one tag
            if l:dict != {}
                " Goto the end of the buffer put the buffer list
                $
                put! ='[File Name]: '. l:dict['filename']
                    \ . ' ' . '[Ex Command]: ' . l:dict['cmd']
            else " Traversal finished
                break
            endif
            let l:indx += 1
        endwhile
    endif
    " Delete the extra trailing blank line
    $ d _
    " Move the cursor to the top of the Source Explorer window
    exe "normal! gg"
    " Back to the first line
    setlocal nomodifiable

endfunction " }}}

" SrcExpl_SearchDecl() {{{

" Search the local decleration

function! <SID>SrcExpl_SearchDecl(exp)

    " Get the original cursor position
    let l:oldline = line(".")
    let l:oldcol = col(".")
    " Try to search the local decleration
    if searchdecl(a:exp, 0, 1) != 0
        " Search failed
        return -1    
    endif
    " Get the new cursor position
    let l:newline = line(".")
    let l:newcol = col(".")
    " Go back to the original cursor position
    call cursor(l:oldline, l:oldcol)
    " Preview the context
    exe "silent " . "pedit " . expand("%:p")
    " Go to the Preview window
    silent! wincmd P
    " Indeed in the Preview window
    if &previewwindow
        " Go to the new cursor position
        call cursor(l:newline, l:newcol)
        " Match the symbol
        call <SID>SrcExpl_MatchExpr()
        " Highlight the symbol
        call <SID>SrcExpl_HiExpr()
    endif
    " Search successfully
    return 0

endfunction " }}}

" SrcExpl_GetSymbol() {{{

" Get the valid symbol under the current cursor

function! <SID>SrcExpl_GetSymbol()

    " Get the current charactor under the cursor
    let l:cchar = getline('.')[col('.') - 1]
    " Get the current word under the cursor
    let l:cword = expand("<cword>")

    " Judge that if or not the charactor is invalid,
    " beause only 0-9, a-z, A-Z, and '_' are valid
    if (l:cchar =~ '\w') && (l:cword =~ '\w')
        " If the key word symbol has been explored
        " just now, we will not explore that again
        if s:SrcExpl_symbol ==# l:cword
            return -1
        " Get a new key word symbol
        else
            let s:SrcExpl_symbol = l:cword
        endif
    " Invalid charactor
    else
        if s:SrcExpl_symbol == ''
            return -2 " Second, third ...
        else " First
            let s:SrcExpl_symbol = ''
        endif
    endif
    return 0

endfunction " }}}

" SrcExpl_GetInput() {{{

" Get the word inputed by user on the command line window

function! <SID>SrcExpl_GetInput(note)

    " Be sure synchronize
    call inputsave()
    " Get the input content
    let l:input = input(a:note)
    " Save the content
    call inputrestore()
    " Tell SrcExpl
    return l:input

endfunction " }}}

" SrcExpl_ProbeTags() {{{

" Probe if or not there is a 'tags' file under the project PATH

function! <SID>SrcExpl_ProbeTags()    

    " First get current work directory
    let l:tmp = getcwd()

    " Get the raw work path
    if l:tmp != s:SrcExpl_rawWorkPath
        " First load Source Explorer
        if s:SrcExpl_rawWorkPath == ""
            " Save that
            let s:SrcExpl_rawWorkPath = l:tmp
        endif
        " Go to the raw work path
        exe "cd " . s:SrcExpl_rawWorkPath
    endif

    let l:tmp = ""

    " Loop to probe the tags in CWD
    while !filereadable("tags")
        " First save
        let l:tmp = getcwd()
        " Up to my parent directory
        cd ..
        " Have been up to the system root dir
        if l:tmp == getcwd()
            " So break out
            break
        endif
    endwhile
    " Indeed in the system root dir
    if l:tmp == getcwd()
        " Clean the buffer
        let s:SrcExpl_tagsPath = ""
    " Have found a 'tags' file already
    else
        " UNIXs OS or MAC OS-X
        if has("unix") || has("macunix")
            if getcwd()[strlen(getcwd()) - 1] != '/'
                let s:SrcExpl_tagsPath = 
                    \ getcwd() . '/'
            endif
        " WINDOWS 95/98/ME/NT/2000/XP
        elseif has("win32")
            if getcwd()[strlen(getcwd()) - 1] != '\'
                let s:SrcExpl_tagsPath = 
                    \ getcwd() . '\'
            endif
        else
            " Other operating system
            echohl ErrorMsg | 
                \ echo "SrcExpl: Not support on this OS platform for now." 
            \ | echohl None
        endif
    endif

    call <SID>SrcExpl_Debug("s:SrcExpl_tagsPath is (" . s:SrcExpl_tagsPath . ")")

endfunction " }}}

" SrcExpl_CloseWin() {{{

" Close the Source Explorer window and delete its buffer

function! <SID>SrcExpl_CloseWin()

    " Just close the preview window
    pclose
    " Judge if or not the Source Explorer
    " buffer had been deleted
    let l:bufnum = bufnr(s:SrcExpl_title)
    " Existed indeed
    if l:bufnum != -1
        exe "bdelete! " . s:SrcExpl_title
    endif

endfunction " }}}

" SrcExpl_OpenWin() {{{

" Open the Source Explorer window under the bottom of (G)Vim,
" and set the buffer's proprity of the Source Explorer

function! <SID>SrcExpl_OpenWin()

    " Get the edit window position
    let s:SrcExpl_editWin = winnr()

    " Open the Source Explorer window as the idle one
    exe "silent! " . "pedit " . s:SrcExpl_title
    " Jump to the Source Explorer
    silent! wincmd P
    " Open successfully and jump to it indeed
    if &previewwindow
        " Show its name on the buffer list
        setlocal buflisted
        " No exact file
        setlocal buftype=nofile
        " Delete all lines in buffer
        1,$d _
        " Goto the end of the buffer
        $
        " Display the version of the Source Explorer
        put! ='Source Explorer V2.6'
        " Delete the extra trailing blank line
        $ d _
        " Make it no modifiable
        setlocal nomodifiable
        " Put it on the bottom of (G)Vim
        silent! wincmd J
    endif
    " Indeed go back to the edit window
    silent! exe s:SrcExpl_editWin . "wincmd w"

endfunction " }}}

" SrcExpl_Cleanup() {{{

" Clean up the rubbish and free the mapping resouces

function! <SID>SrcExpl_Cleanup()

    " GUI Version
    if has("gui_running")
        " Delete the SrcExplGoBack item in Popup menu
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
    if maparg(g:SrcExpl_refreshKey, 'n') == 
        \ ":call g:SrcExpl_Refresh()<CR>"
        exe "unmap " . g:SrcExpl_refreshKey
    endif
    " Unmap the user's key
    if maparg(g:SrcExpl_gobackKey, 'n') == 
        \ ":call g:SrcExpl_GoBack()<CR>"
        exe "unmap " . g:SrcExpl_gobackKey
    endif
    " Unload the autocmd group
    silent! autocmd! SrcExpl_AutoCmd

endfunction " }}}

" SrcExpl_Init() {{{

" Initialize the Source Explorer proprities

function! <SID>SrcExpl_Init()

    " Access the Tags file 
    call <SID>SrcExpl_ProbeTags()
    " Found one Tags file
    if s:SrcExpl_tagsPath != ""
        " Compiled with 'Quickfix' feature
        if !has("quickfix")
            " Can not create preview window without quickfix feature
            echohl ErrorMsg | 
                \ echo "SrcExpl: Not support without 'Quickfix'." 
            \ | echohl None
            return -1
        endif
        " Have found 'tags' file and update that
        if g:SrcExpl_updateTags != 0
            " Call the external 'ctags' program
            silent !ctags -R *
        endif
    else
        " Ask user if or not create a tags file
        echohl Question |
            \ let l:answer = <SID>SrcExpl_GetInput("SrcExpl: "
                \ . "The 'tags' file isn't found in your PATH.\n"
            \ . "Create one in the current directory now? (y or n)")
        \ | echohl None
        " They do
        if l:answer == "y" || l:answer == "yes"
            " Back from the root directory
            exe "cd " . s:SrcExpl_rawWorkPath
            " Call the external 'ctags' program
            silent !ctags -R *
            " Rejudge the tags file if existed
            call <SID>SrcExpl_ProbeTags()
            " Maybe there is no 'ctags' program in user's system
            if s:SrcExpl_tagsPath == ""
                " Tell them what happened
                echohl ErrorMsg | 
                    \ echo "SrcExpl: Execute 'ctags' program failed."
                \ | echohl None
                return -2
            endif
        else
            " They don't
            echo ""
            return -3
        endif
    endif
    " First set the height of preview window
    exe "set previewheight=". string(g:SrcExpl_winHeight)
    " Load the Tags file into buffer
     exe "silent! " . "pedit " . s:SrcExpl_tagsPath . "tags"
    " Set the actual update time according to user's requestion
    " 1000 milliseconds by default
    exe "set updatetime=" . string(g:SrcExpl_refreshTime)
    " Map the user's key to go back from the 
    " definition context.
    if g:SrcExpl_gobackKey != ""
        exe "nnoremap " . g:SrcExpl_gobackKey . 
            \ " :call g:SrcExpl_GoBack()<CR>"
    endif
    " Map the user's key to refresh the definition
    " updating manually.
    if g:SrcExpl_refreshKey != ""
        exe "nnoremap " . g:SrcExpl_refreshKey . 
            \ " :call g:SrcExpl_Refresh()<CR>"
    endif
    " First get the SrcExpl.vim's ID
    map <SID>xx <SID>xx
    let s:SrcExpl_scriptID = substitute(maparg('<SID>xx'), 
        \ '<SNR>\(\d\+_\)xx$', '\1', '')
    unmap <SID>xx
    " Then form an autocmd group
    augroup SrcExpl_AutoCmd
        " Delete the autocmd group first
        autocmd!
        au! CursorHold * nested call g:SrcExpl_Refresh()
        au! WinEnter * nested call <SID>SrcExpl_EnterWin()
    augroup end
    " Initialize successfully
    return 0

endfunction " }}}

" SrcExpl_Toggle() {{{

" The User Interface function to open / close the Source Explorer

function! <SID>SrcExpl_Toggle()

    call <SID>SrcExpl_Debug("s:SrcExpl_isOpen is (" . s:SrcExpl_isOpen . ")")

    " Already closed
    if s:SrcExpl_isOpen == 0
        " Initialize the proprities
        let l:rtn = <SID>SrcExpl_Init()
        " Initialize failed
        if l:rtn != 0
            " Quit
            return
        endif
        " Create the window
        call <SID>SrcExpl_OpenWin()
        " Set the switch flag on
        let s:SrcExpl_isOpen = 1
    " Already Opened
    else
        " Set the switch flag off
        let  s:SrcExpl_isOpen = 0
        " Close the window
        call <SID>SrcExpl_CloseWin()
        " Do the cleaning work
        call <SID>SrcExpl_Cleanup()
    endif

endfunction " }}}

" SrcExpl_Close() {{{

" The User Interface function to close the Source Explorer

function! <SID>SrcExpl_Close()

    if s:SrcExpl_isOpen == 1
        " Set the switch flag off
        let s:SrcExpl_isOpen = 0
        " Close the window
        call <SID>SrcExpl_CloseWin()
        " Do the cleaning work
        call <SID>SrcExpl_Cleanup()
    else
        " Tell users the reason
        echohl ErrorMsg | 
            \ echo "The Source Explorer is closed." 
                \ | echohl None
        return
    endif

endfunction " }}}

" SrcExpl() {{{

" The User Interface function to open the Source Explorer

function! <SID>SrcExpl()

    if s:SrcExpl_isOpen == 0
        " Initialize the proprities
        let l:rtn = <SID>SrcExpl_Init()
        " Initialize failed
        if l:rtn != 0
            " Quit
            return
        endif
        " Create the window
        call <SID>SrcExpl_OpenWin()
        " Set the switch flag on
        let s:SrcExpl_isOpen = 1
    else
        " Tell users the reason
        echohl ErrorMsg | 
            \ echo "The Source Explorer is running." 
                \ | echohl None
        return
    endif

endfunction " }}}

" Avoid side effects {{{

set cpoptions&
let &cpoptions = s:save_cpo
unlet s:save_cpo

" }}}

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" vim:foldmethod=marker:tabstop=4

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

