
""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" File Name:	srcexpl.vim
" Abstract:		A (G)VIM plugin for exploring the C/C++ 
"				source code based on 'tags' and 'quickfix'.
" Author:		Wenlong Che
" EMail:		chewenlong @ buaa.edu.cn
" Version:		2.4
" Last Change:	July 8, 2008

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The_setting_example_in_my_vimrc_file:-)

" // Set 300 ms for refreshing the the Source Explorer
" let g:SrcExpl_RefreshTime   = 300
" // Set the window height of the Source Explorer
" let g:SrcExpl_WinHeight     = 9
" // Let the Source Explorer update the tags file when initializing
" let g:SrcExpl_UpdateTags    = 1
" // Set "Space" key for refresh the Source Explorer manually
" let g:SrcExpl_RefreshMapKey = "<Space>"
" // Set "Ctrl-b" key for back from the definition context
" let g:SrcExpl_GoBackMapKey  = "<C-b>"
" // The switch of the Source Explorer
" nmap <F8> :SrcExplToggle<CR>

" Just_change_above_of_them_by_yourself:-)

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Avoid reloading the plugin again

if exists('loaded_srcexpl')
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
    let g:SrcExpl_RefreshTime = 500
endif

" User interface for update tags
" file when loading SrcExpl Plugin
if !exists('g:SrcExpl_UpdateTags')
    let g:SrcExpl_UpdateTags = 0
endif

" User interface for back from 
" the definition context
if !exists('g:SrcExpl_GoBackMapKey')
    let g:SrcExpl_GoBackMapKey = ''
endif

" User interface for refreshing one
" definition searching manually
if !exists('g:SrcExpl_RefreshMapKey')
    let g:SrcExpl_RefreshMapKey = ''
endif

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Buffer Title for buffer listing
let s:SrcExpl_BufTitle      =   '__Source_Explorer__'
" The whole path of 'tags' file
let s:SrcExpl_TagsFilePath  =   ''
" The key word symbol for exploring
let s:SrcExpl_Symbol        =   ''
" Whole file path being explored now
let s:SrcExpl_EditFilePath  =   ''
" Original work path when initilizing
let s:SrcExpl_RawWorkPath   =   ''
" ID number of srcexpl.vim
let s:SrcExpl_ScriptID      =   0
" Current line number of the key word symbol
let s:SrcExpl_CurrLine      =   0
" Current col number of the key word symbol
let s:SrcExpl_CurrCol       =   0
" Source Explorer switch flag
let s:SrcExpl_Switch        =   0
" Source Explorer status:
" 1: Sigle-definition
" 2: Multi-definitions 
" 3: No such definition
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

	let l:exp = ''
	let l:rtn = 0

	" Only Source Explorer window is valid 
    if &previewwindow
        return
    endif
	" Avoid errors of multi-buffers
	if &modified
		" Tell the user what has happened
        echohl ErrorMsg | 
            \ echo "SrcExpl: The current file was not saved."
        \ | echohl None
		return
	endif
    " Get the symbol under the cursor
    let l:rtn = <SID>SrcExpl_GetSymbol()
    " The symbol is invalid
    if l:rtn != 0
        return
    endif
	let l:exp = '\C\<' . s:SrcExpl_Symbol . '\>'

    " Explore the source code using tag tool
    " First Just try to get the definition of the symbol
    try
        " First move to the Source Explorer window
        silent! wincmd P
        if &previewwindow
            " Get the whole file path of the buffer before tag
            let s:SrcExpl_EditFilePath = expand("%:p")
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
        exe 'silent ' . 'ptag /' . l:exp
    catch
		" Tag failed
		let s:SrcExpl_Status = 3
		" Tell the Source Explorer window
		call <SID>SrcExpl_NoDef()
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
        if (s:SrcExpl_EditFilePath == expand("%:p")) &&
            \ (s:SrcExpl_CurrLine == line(".")) &&
                \ (s:SrcExpl_CurrCol == col("."))
            " Mulitple definitions
            let s:SrcExpl_Status = 2 
            " List the multi-definitions in the Source Explorer
            call <SID>SrcExpl_ListTags(l:exp)
        else " Source Explorer Has pointed to the definition already
            let s:SrcExpl_Status = 1
            " Make the definition hightlight
            call <SID>SrcExpl_MatchExpr()
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

function! <SID>SrcExpl_EnterWin()

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

function! <SID>SrcExpl_MatchExpr()

    " First open the folding if exists
    if has("folding")
        silent! .foldopen
    endif
    " Match the symbol and make it highlight
	call search("$", "b")
	let s:SrcExpl_Symbol = substitute(s:SrcExpl_Symbol, 
        \ '\\', '\\\\', "")
	call search('\C\<\V' . s:SrcExpl_Symbol . '\>')
	" Set the highlight color
    hi SrcExpl_HighLight term=bold guifg=Black guibg=Magenta ctermfg=Black ctermbg=Magenta
	" Highlight
	exe 'match SrcExpl_HighLight "\%' . line(".") . 'l\%' . 
        \ col(".") . 'c\k*"'
    " Save the file path, the current line and the current 
    " col of the definition
    let s:SrcExpl_EditFilePath = expand("%:p")
    let s:SrcExpl_CurrLine = line(".")
    let s:SrcExpl_CurrCol = col(".")

endfunction!

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Select one of multi-definitions, and jump to there.

function! <SID>SrcExpl_SelToJump()

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
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_OtherPluginAdapter()
    " Open the file of definition context
    exe "edit " . s:SrcExpl_TagsFilePath . l:f
    " Use EX Pattern to Jump to the exact line of the definition
    silent! exe l:s
	if has("folding")
		silent! .foldopen
	endif
    " Match the symbol word under the cursor
	call search("$", "b")
	let s:SrcExpl_Symbol = substitute(s:SrcExpl_Symbol, 
        \ '\\', '\\\\', "")
	call search('\V\<' . s:SrcExpl_Symbol . '\>')

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
   " We got multiple definitions
    if s:SrcExpl_Status == 2
        call <SID>SrcExpl_SelToJump()
        return
    endif
    " Go back to the privious window
    silent! wincmd p
    " Indeed back to the editor window
    call g:SrcExpl_OtherPluginAdapter()
	" We got only one definition
    if s:SrcExpl_Status == 1
        " Open the buffer using editor
        exe "edit " . s:SrcExpl_EditFilePath
        " Jump to the context line of that symbol
        call cursor(s:SrcExpl_CurrLine, s:SrcExpl_CurrCol)
		if has("folding")
			silent! .foldopen
		endif
    endif

endfunction

" Report to the Source Explorer what happens

function! <SID>SrcExpl_NoDef()

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
        if s:SrcExpl_Status == 3
			" Delete all lines in buffer.
			1,$d _
			" Goto the end of the buffer put the buffer list
			$
			" Display the version of the Source Explorer
			put! ='Definition Not Found'
			" Delete the extra trailing blank line
			$ d _
        endif
        " Make it unmodifiable again
        setlocal nomodifiable
    endif

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Traversal the tags infomation from the tags file and list them

function! <SID>SrcExpl_ListTags(exp)

	" The tags file must be available, or quit.
    if s:SrcExpl_TagsFilePath == ""
        let s:SrcExpl_Status = 3
        call <SID>SrcExpl_NoDef()
        return
    endif

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
		let l:indx = 0
		" Loop for listing each tag from tags file
		while 1
			" First get each tag list
			let l:dict = get(l:list, l:indx, {})
			" There is one tag
			if l:dict != {}
				" Goto the end of the buffer put the buffer list
				$
				put! ='[File Path]: '. l:dict['filename']
					\ . ' ' . '[EX Pattern]: ' . l:dict['cmd']
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
        " if the key word symbol has been explored
        " just now, we will not explore that again
        if s:SrcExpl_Symbol ==# expand("<cword>")
            return -1
        " Get a new key word symbol
        else
            let s:SrcExpl_Symbol = expand("<cword>")
        endif
    " Invalid charactor
    else
        if s:SrcExpl_Symbol == ''
            return -1 " Second, third ...
        else " First
            let s:SrcExpl_Symbol = ''
        endif
    endif
    return 0

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

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

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" Probe if or not there is a 'tags' file under the project PATH

function! <SID>SrcExpl_ProbeTags()    

    let l:tmp = getcwd()
    " Get the raw work path
    if l:tmp != s:SrcExpl_RawWorkPath
        " First load Source Explorer
        if s:SrcExpl_RawWorkPath == ""
            " Save that
            let s:SrcExpl_RawWorkPath = l:tmp
        endif
        " Go to the raw work path
        exe "cd " . s:SrcExpl_RawWorkPath
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
        let s:SrcExpl_TagsFilePath = ""
    " Have found a 'tags' file already
    else
        " UNIXs OS or MAC OS-X
        if has("unix") || has("macunix")
            if getcwd()[strlen(getcwd()) - 1] != '/'
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . '/'
            endif
        " WINDOWS 95/98/ME/NT/2000/XP
        elseif has("win32")
            if getcwd()[strlen(getcwd()) - 1] != '\'
                let s:SrcExpl_TagsFilePath = 
                    \ getcwd() . '\'
            endif
        else
            " Other operating system
            echohl ErrorMsg | 
                \ echo "SrcExpl Plugin: Not support on this OS." 
            \ | echohl None
        endif
    endif

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
		" Delete all lines in buffer
		1,$d _
		" Goto the end of the buffer
		$
		" Display the version of the Source Explorer
		put! ='Source Explorer V2.4'
		" Delete the extra trailing blank line
		$ d _
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

" Clean up the rubbish and free the mapping resouces

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

" Initialize the Source Explorer proprities

function! <SID>SrcExpl_Init()

    " Access the Tags file 
    call <SID>SrcExpl_ProbeTags()
    " Found one Tags file
    if s:SrcExpl_TagsFilePath != ""
        " Compiled with 'Quickfix' feature
        if !has("quickfix")
            " Can not create preview window without quickfix feature
            echohl ErrorMsg | 
                \ echo "SrcExpl: Not support without 'Quickfix'." 
            \ | echohl None
            return -1
        endif
        " Have found 'tags' file and update that
        if g:SrcExpl_UpdateTags == 1
            " Call the external 'ctags' program
            silent !ctags -R *
        endif
    else
        " Ask user if or not create a tags file
        echohl Question |
            \ let l:answer = <SID>SrcExpl_GetInput("SrcExpl: "
                \ . "'tags' file isn't found in your PATHs.\n"
            \ . "Create one in the current directory? (y or n)")
        \ | echohl None
        " They do
        if l:answer == "y" || l:answer == "yes"
            " Back from the root directory
            exe "cd " . s:SrcExpl_RawWorkPath
            " Call the external 'ctags' program
            silent !ctags -R *
            " Rejudge the tags file if existed
            call <SID>SrcExpl_ProbeTags()
            " Maybe there is no 'ctags' program in user's system
            if s:SrcExpl_TagsFilePath == ""
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
    exe "set previewheight=". string(g:SrcExpl_WinHeight)
    " Load the Tags file into buffer
    exe "silent! " . "pedit " . s:SrcExpl_TagsFilePath . "tags"
    " Set the actual update time according to user's requestion
    " 1000 milliseconds by default
    exe "set updatetime=" . string(g:SrcExpl_RefreshTime)
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
        au! WinEnter * nested call <SID>SrcExpl_EnterWin()
    augroup end
    " Initialize successfully
    return 0

endfunction

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" The User Interface function for open / close
" the Source Explorer

function! <SID>SrcExpl_Toggle()

    " Already closed
    if s:SrcExpl_Switch == 0
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
        let s:SrcExpl_Switch = 1
    " Already Opened
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

