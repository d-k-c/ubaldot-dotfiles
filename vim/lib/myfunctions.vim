vim9script

# Remove trailing white spaces at the end of each line and at the end of the file
export def TrimWhitespace()
    var currwin = winsaveview()
    var save_cursor = getpos(".")
    silent! :keeppatterns :%s/\s\+$//e
    silent! :%s/\($\n\s*\)\+\%$//
    winrestview(currwin)
    setpos('.', save_cursor)
enddef


# Commit a dot.
# It is related to the opened buffer not to pwd!
export def CommitDot()
    # curr_dir = pwd
    cd %:p:h
    exe "!git add -u && git commit -m '.'"
    # cd curr_dir
enddef

export def PushDot()
    cd %:p:h
    exe "!git add -u && git commit -m '.' && git push"
enddef


export def Diff(spec: string)
    # For comparing:
    #   1. Your open buffer VS its last saved version (no args)
    #   2. Your open buffer with a given commit
    #
    # Usage: :Diff 12jhu23
    # To exit, just wipe the scratch buffer.
    vertical new
    setlocal bufhidden=wipe buftype=nofile nobuflisted noswapfile
    var cmd = bufname('#')
    if !empty(spec)
        cmd = "!git -C " .. shellescape(fnamemodify(finddir('.git', '.;'), ':p:h:h')) .. " show " .. spec .. ":#"
    endif
    execute "read " .. cmd
    silent :0d _
    &filetype = getbufvar('#', '&filetype')
    augroup Diff
      autocmd!
      autocmd BufWipeout <buffer> diffoff!
    augroup END
    diffthis
    wincmd p
    diffthis
enddef



export def Redir(cmd: string, rng: number, start: number, end: number)
    # Used to redirect the output from the terminal in a scratch buffer
    #
    # Example: :Redir !ls
    #
    # You can use it also to redirect the output of some Vim commands
	for win in range(1, winnr('$'))
		if !empty(getwinvar(win, 'scratch'))
			execute win .. 'windo :close'
		endif
	endfor
    var output = []
	if cmd =~ '^!'
		var cmd_filt = cmd =~ ' %'
			\ ? matchstr(substitute(cmd, ' %', ' ' .. shellescape(escape(expand('%:p'), '\')), ''), '^!\zs.*')
			\ : matchstr(cmd, '^!\zs.*')
		if rng == 0
			output = systemlist(cmd_filt)
		else
			var joined_lines = join(getline(start, end), '\n')
			var cleaned_lines = substitute(shellescape(joined_lines), "'\\\\''", "\\\\'", 'g')
			output = systemlist(cmd_filt .. " <<< $" .. cleaned_lines)
		endif
	else
        var tmp: string
		redir => tmp
		execute cmd
		redir END
		output = split(tmp, "\n")
	endif
	vnew
	w:scratch = 1
	setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
	setline(1, output)
enddef


var color_is_shown = false
# export def ColorsShow(clear: bool = false): void
export def ColorsToggle(): void
	if exists('b:prop_ids')
		map(b:prop_ids, (_, p) => prop_remove({id: p}))
	endif

	if color_is_shown
        color_is_shown = false
		return
	endif

    # This is only needed for removing.
	b:prop_ids = []

	for row in range(1, line('$'))
		var current = getline(row)
		var cnt = 1
		var [hex, starts, ends] = matchstrpos(current, '#\x\{6\}', 0, cnt)
		while starts != -1
			var col_tag = "inline_color_" .. hex[1 : ]
			var col_type = prop_type_get(col_tag)
			if col_type == {}
				hlset([{name: col_tag, guibg: hex, guifg: "black"}])
				prop_type_add(col_tag, {highlight: col_tag})
			endif
			add(b:prop_ids, prop_add(row, starts + 1, { length: ends - starts,  type: col_tag }))
			cnt += 1
			[hex, starts, ends] = matchstrpos(current, '#\x\{6\}', 0, cnt)
		endwhile
	endfor
    color_is_shown = true
enddef

# Highlight toggle
# TODO:
# 1) Three different highlights
# 2) Normal mode highlight current line
# 3) Set operation on selection.
export def Highlight()
    if !exists('b:prop_id')
        b:prop_id = 0
    endif
    if prop_type_get('my_hl') == {}
        prop_type_add('my_hl', {'highlight': 'DiffDelete'})
    endif

    var start_line = line("'<")
    var end_line = line("'>")
    var start_col = col("'<")
    var end_col = col("'>")
    # echom prop_list(line('.'), {'types':$ ['my_hl']})
    # echom prop_list(start_line, {'types': ['my_hl']})


    # If there are no prop under the cursor position, then add, otherwise if a
    # prop is detected remove it.
    var no_prop = empty(prop_list(start_line, {'types': ['my_hl']}))
    if no_prop
        prop_add(start_line, start_col, {'end_lnum': end_line, 'end_col': end_col, 'type': 'my_hl', 'id': b:prop_id})
        b:prop_id = b:prop_id + 1
    else
        var id = prop_list(start_line, {'types': ['my_hl']})[0]['id']
        prop_remove({'id': id})
    endif
enddef

# ------------ Terminal functions ------------------
# Change all the terminal directories when you change vim directory
export def ChangeTerminalDir()
    for ii in term_list()
        if bufname(ii) == "JULIA"
            term_sendkeys(ii, 'cd("' .. getcwd() .. '")' .. "\n")
        else
            term_sendkeys(ii, "cd " .. getcwd() .. "\n")
        endif
    endfor
enddef

# Close all terminals with :qa!
export def WipeoutTerminals()
    for buf_nr in term_list()
        exe "bw! " .. buf_nr
    endfor
enddef

export def OpenMyTerminal()
    var terms_name = []
    for ii in term_list()
        add(terms_name, bufname(ii))
    endfor

    if term_list() == [] || index(terms_name, 'MY_TERMINAL') == -1
        # enable the following and remove the popup_create part if you want
        # the terminal in a "classic" window.
        # vert term_start(&shell, {'term_name': 'MANIM' })
        term_start(&shell, {'term_name': 'MY_TERMINAL', 'hidden': 1, 'term_finish': 'close'})
        set nowrap
    endif
    popup_create(bufnr('MY_TERMINAL'), {
        title: " MY TERMINAL ",
        line: &lines,
        col: &columns,
        pos: "botright",
        posinvert: false,
        borderchars: ['─', '│', '─', '│', '╭', '╮', '╯', '╰'],
        border: [1, 1, 1, 1],
        maxheight: &lines - 1,
        minwidth: 80,
        minheight: 20,
        close: 'button',
        resize: true
        })
enddef

# Some mappings to learn
noremap <unique> <script> <Plug>Highlight <esc><ScriptCmd>Highlight()
# noremap <unique> <script> <Plug>Highlight2 <esc><ScriptCmd>Highlight('WildMenu')