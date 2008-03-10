
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" File:         (G)Vim script file named srcexpl.vim
" Description:  A (G)VIM Plugin for exploring the C/C++ 
"               source code based on 'tags' and 'quickfix'.
" Author:       Che Wenlong
" Mail:         chewenlong@buaa.edu.cn
" Copyright:    Copyright (C) 2008
" Last Change:  2008 Mar 9

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" A_setting_example_in_my_vimrc_file:

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

" You_can_change_above_of_them_by_yourself:

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

if exists("loaded_srcexpl")
    finish
endif

let loaded_srcexpl = 1
let s:save_cpo = &cpoptions

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

" The key word symbol for exploring
let s:SrcExpl_Symbol    =   ""
" Whole file path being explored now
let s:SrcExpl_FilePath  =   ""
" Title of Source Explorer for display
let s:SrcExpl_Title     =   "__Source_Explorer__"
" ID number of srcexpl.vim
let s:SrcExpl_ScriptID  =   0
" Current line number of the key word symbol
let s:SrcExpl_CurrLine  =   0
" Current col number of the key word symbol
let s:SrcExpl_CurrCol   =   0
" Source Explorer switch flag
let s:SrcExpl_Switch    =   0
" Source Explorer status:
" 1: exploring, 2: no definition
" 3: multi-definitions
let s:SrcExpl_Status    =   0

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" NOTE: You gugs can change this function by yourselves 
"       in order to adapt the editor window position for
"       the Source Explorer position.

function! g:SrcExpl_WinPosAdapter()
    " If the Taglist(I can't work without it!) Plugin existed
    if bufname("%") == "__Tag_List__"
        " Move the cursor to its right window
        " Because I used to put the taglist
        " Window on my left.
        silent! wincmd l
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
            call g:SrcExpl_WinPosAdapter()
        endif
        " Begin to tag the symbol
        exe "silent " . "ptag " . s:SrcExpl_Symbol
    catch
        " Tag unsuccessfully
        let s:SrcExpl_Status = 3
        " Tell the Source Explorer window wyh
        call <SID>SrcExpl_Report()
        " Go back to the privious window again
        silent! wincmd p
        " Indeed back to the editor window
        call g:SrcExpl_WinPosAdapter()
        return
    endtry
    " Tag successfully and move to the preview window
    silent! wincmd P
    if &previewwindow
        " Judge that if or not point to the definition
        if (s:SrcExpl_FilePath == expand("%:p")) &&
            \ (s:SrcExpl_CurrLine == line(".")) &&
                \ (s:SrcExpl_CurrCol == col("."))
            " Mulitple definition
            let s:SrcExpl_Status = 2
            call <SID>SrcExpl_Report()
        else " Source Explorer Has pointed to the definition already
            let s:SrcExpl_Status = 1
            " Make the definition hightlight
            call <SID>SrcExpl_MatchSymbol()
        endif
        " Go back to the privious window again
        silent! wincmd p
        " Indeed back to the editor window
        call g:SrcExpl_WinPosAdapter()
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

" Jump to the editor window and point to the definition

function! <SID>SrcExpl_Jump()
    " Only do the operation on the Source Explorer 
    " window is valid
    if !&previewwindow
        return
    endif
    " Do we get the definition already?
    if (bufname("%") == s:SrcExpl_Title)
        if s:SrcExpl_Status == 3 " No definition
            return
        endif
    endif
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_WinPosAdapter()
    " We got Multiple definitions
    if s:SrcExpl_Status == 2
        " Use tag tool again to point to the definition 
        " according to user's choice manually
        exe "tag " . s:SrcExpl_Symbol
	    call search("$", "b")
	    let s:SrcExpl_Symbol = substitute(s:SrcExpl_Symbol, 
            \ '\\', '\\\\', "")
	    call search('\<\V' . s:SrcExpl_Symbol . '\>')
        return
    endif
    " Open the buffer using editor
    exe "edit " . s:SrcExpl_FilePath
    " Jump to the context line of that symbol
    call cursor(s:SrcExpl_CurrLine, s:SrcExpl_CurrCol)
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

" Report to the Source Explorer what happens

function! <SID>SrcExpl_Report()
    " Do the Source Explorer exsited already?
    let l:bufnum = bufnr(s:SrcExpl_Title)
    if l:bufnum == -1
        " Create a new buffer
        let l:wcmd = s:SrcExpl_Title
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
        silent! %delete _
        setlocal buflisted
        setlocal buftype=nofile
        " Report the reason why Source Explorer
        " can not point to the definition
        if s:SrcExpl_Status == 3
            normal aDefinition Not Found
        elseif s:SrcExpl_Status == 2
            normal aMultiple Definitions
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

" Clean up the rubbish of plugin and free the mapping resouces

function! <SID>SrcExpl_Cleanup()
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
    " First set the height of preview window
    exe "set previewheight=". string(g:SrcExpl_WinHeight)
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
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Close the Source Explorer window and delete its buffer

function! <SID>SrcExpl_CloseWin()
    " Just close the preview window
    pclose
    " Judge if or not the Source Explorer
    " buffer had been deleted
    let l:bufnum = bufnr(s:SrcExpl_Title)
    " Existed indeed
    if l:bufnum != -1
        exe "bdelete! " . s:SrcExpl_Title
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Open the Source Explorer window under the bottom of (G)Vim,
" and set the buffer's proprity of the Source Explorer

function! <SID>SrcExpl_OpenWin()
    " Open the Source Explorer window as the idle one
    exe "silent! " . "pedit " . s:SrcExpl_Title
    " Jump to the Source Explorer
    silent! wincmd P
    " Open successfully and jump to it indeed
    if &previewwindow
        " Show its name on the buffer list
        setlocal buflisted
        " No exact file
        setlocal buftype=nofile
        " Show the version of the Source Explorer
        normal aSource Explorer V1.1
        " Make it no modifiable
        setlocal nomodifiable
        " Put it on the bottom of (G)Vim
        silent! wincmd J
    endif
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_WinPosAdapter()
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The User Interface function for open / close
" the Source Explorer

function! <SID>SrcExpl_Toggle()
    " Closed
    if s:SrcExpl_Switch == 0
        let s:SrcExpl_Switch = 1
        " Initialize the proprities
        call <SID>SrcExpl_Initialize()
        " Open the window
        call <SID>SrcExpl_OpenWin()
    " Opened
    else
        " Close the window
        call <SID>SrcExpl_CloseWin()
        " Do the cleaning work
        call <SID>SrcExpl_Cleanup()
        let  s:SrcExpl_Switch = 0
    endif
endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

set cpoptions&
let &cpoptions = s:save_cpo
unlet s:save_cpo

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

