" FILE: toggl.vim
" AUTHOR: Toshiki Teramura <toshiki.teramura@gmail.com>
" LICENCE: MIT

let s:save_cpo = &cpo
set cpo&vim

function! s:parse_args(args) abort
  let result = {
        \ "words": split(a:args),
        \ "tags": [],
        \ "args": [],
        \ }
  for s in result.words 
    if s[0] == "+"
      let result.project = s[1:]
    elseif s[0] == "@"
      call add(result.tags, s[1:])
    else
      call add(result.args, s)
    endif
  endfor
  return result
endfunction

function! toggl#start(args) abort
  let args = s:parse_args(a:args)
  if has_key(args, "project")
    let pid = s:get_pid(args.project)
  else
    let pid = 0
  endif
  let res = toggl#time_entries#start(join(args.args, " "), pid, args.tags)
  call s:save_settings(res.description, res.duration)
  echo 'Start task: ' . res.description
	let g:toggl_task = res.description
endfunction

function! toggl#select_start() abort
  let tmp = @@
  silent normal gvy
  let selected = @@
  let @@ = tmp
  call toggl#start(selected)
endfunction

function! toggl#stop() abort
  let now = toggl#time_entries#get_running()
  if now is 0
    echo 'No task is running'
    return
  endif
  call s:save_settings('free', 0)
  let stop = toggl#time_entries#stop(now.id)
  let duration = stop.data.duration
  let time = toggl#get_time(duration)
  echo 'Stop task: ' . now.description . ' "' . time . '"'
	let g:toggl_task = 'no task'
endfunction

function! s:getftime_of_days_ago(days) abort
  let t = localtime() - a:days * 24 * 60 * 60
  let pre = strftime("%FT%T%z", t)
  return pre[:-3] . ':' . pre[-2:]
endfunction

function! toggl#list() abort
  let now = s:getftime_of_days_ago(0)
  let week_ago = s:getftime_of_days_ago(7)
  return toggl#time_entries#range(week_ago, now)
endfunction

function! s:get_wid() abort
  if !exists("g:toggl_workspace_id")
    return toggl#workspaces#get()[0].id
  else
    return g:toggl_workspace_id
  endif
endfunction

function! s:get_pid(project_name) abort
  let pl = toggl#projects()
  for p in pl
    if p.name == a:project_name
      return p.id
    endif
  endfor
  echo 'Project "' . a:project_name . '" does not found.'
  return 0
endfunction

function! toggl#projects() abort
  let wid = s:get_wid()
  return toggl#workspaces#projects(wid)
endfunction

function! toggl#tags() abort
  let wid = s:get_wid()
  return toggl#workspaces#tags(wid)
endfunction

function! toggl#task_cache_update() abort
  let now = toggl#time_entries#get_running()
  if now is 0
    call s:save_settings('free', 0)
    echo "No task is running"
    return
  endif
  call s:save_settings(now.description, now.duration)
  let time = toggl#get_time(localtime() + s:load_settings()["time"])
  echo now.description . ' ' . time
endfunction

function! toggl#task() abort
  return s:load_settings()["task"]
endfunction

function! toggl#time() abort
  let time = toggl#get_time(localtime() + s:load_settings()["time"])
  if s:load_settings()["time"] == 0
    let time = ''
  endif
  return time
endfunction

function! toggl#update_current(data) abort
  let now = toggl#time_entries#get_running()
  if now is 0
    throw "No task is running"
    return
  endif
  return toggl#time_entries#update(now.id, a:data)
endfunction

function! toggl#get_time(duration) abort
  let hour = a:duration / 3600
  let minute = (a:duration / 60) % 60
  if hour < 10
    let hour = '0' . hour
  endif
  if minute < 10
    let minute = '0' . minute
  endif
  let time = hour . ':' . minute
  return time
endfunction

let s:configfile = expand('~/.toggl-vim')

function! s:save_settings(task, time)
  let config = {'task': a:task, 'time': a:time}
  call writefile([string(config)], s:configfile)
endfunction

function! s:load_settings()
  if filereadable(s:configfile)
    silent! sandbox let config = eval(join(readfile(s:configfile), ''))
    return config
  else
    let v:errmsg = "[Please call :TogglCacheUpdate] "
    return 0
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
