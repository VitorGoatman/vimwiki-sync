augroup vimwiki
  if !exists('g:zettel_synced')
    let g:zettel_synced = 0
  else
    finish
  endif

  " g:zettel_dir is defined by vim_zettel
  if !exists('g:zettel_dir')
    let g:zettel_dir = vimwiki#vars#get_wikilocal('path') "VimwikiGet('path',g:vimwiki_current_idx)
  endif

  " make the Git branch used for synchronization configurable
  if !exists('g:vimwiki_sync_branch')
    let g:vimwiki_sync_branch = "HEAD"
  endif

  " enable disabling of Taskwarrior synchronization
  if !exists("g:sync_taskwarrior")
    let g:sync_taskwarrior = 1
  endif

  " don't try to start synchronization if the opend file is not in vimwiki
  " path
  let current_dir = expand("%:p:h")
  if !current_dir ==# fnamemodify(g:zettel_dir, ":h")
    finish
  endif

  if !exists('g:vimwiki_sync_commit_message')
    let g:vimwiki_sync_commit_message = 'Auto commit + push. %c'
  endif

  " don't sync temporary wiki
  if vimwiki#vars#get_wikilocal('is_temporary_wiki') == 1
    finish
  endif
  
  if !exists('g:vimwiki_sync_prefix')
    let g:vimwiki_sync_prefix = ':silent !git -C '
  endif

  " execute vim function. because vimwiki can be started from any directory,
  " we must use pushd and popd commands to execute git commands in wiki root
  " dir. silent is used to disable necessity to press <enter> after each
  " command. the downside is that the command output is not displayed at all.
  " One idea: what about running git asynchronously?
  function! s:git_action(action)
    execute ':silent !' . a:action 
    " prevent screen artifacts
    redraw!
  endfunction

  function! My_exit_cb(channel,msg )
    echom "[vimiwiki sync] Sync done"
    execute 'checktime' 
  endfunction

  function! My_close_cb(channel)
    " it seems this callback is necessary to really pull the repo
  endfunction


  " pull changes from git origin and sync task warrior for taskwiki
  " using asynchronous jobs
  " we should add some error handling
  function! s:pull_changes()
    if g:zettel_synced==0
      echom "[vimwiki sync] pulling changes"

      let g:zettel_synced = 1
      let gitCommand = g:vimwiki_sync_prefix . g:zettel_dir . " pull --rebase origin " . g:vimwiki_sync_branch
      let gitCallbacks = {"exit_cb": "My_exit_cb", "close_cb": "My_close_cb"}

      if has("nvim")
        let gitjob = jobstart(gitCommand, gitCallbacks)
      else
        let gitjob = job_start(gitCommand, gitCallbacks)
      endif

      if g:sync_taskwarrior==1
        let taskjob = jobstart("task sync")
      endif
    endif
  endfunction

  function! s:stage_changes()
    execute g:vimwiki_sync_prefix . g:zettel_dir . " add . "
  endfunction

  function! s:push_changes()
    echom "[vimwiki sync] pushing changes"
    execute g:vimwiki_sync_prefix . g:zettel_dir . " commit -m \"" . strftime(g:vimwiki_sync_commit_message) . "\""
    execute g:vimwiki_sync_prefix . g:zettel_dir . " push origin " . g:vimwiki_sync_branch
    if g:sync_taskwarrior==1
      let taskjob = jobstart("task sync")
    endif
    echom "[vimwiki sync] changes pushed"
  endfunction

  " sync changes at the start
  au! VimEnter * call <sid>pull_changes()
  au! BufRead * call <sid>pull_changes()
  au! BufEnter * call <sid>pull_changes()
  " auto commit changes on each file change
  au! BufWritePost * call <sid>stage_changes()
  " push changes only on at the end
  au! VimLeave * call <sid>push_changes()
augroup END
