# ~/.bashrc

# Function to parse Git branch and status
parse_git_branch_and_status() {
  # 檢查是否在 git work tree 中。如果不是，立即返回空字符串。
  # 這裡使用 ! 來判斷命令是否執行失敗
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "" # 返回空字符串，不在提示符中顯示 Git 狀態
    return 0 # 結束函數
  fi

  # 如果執行到這裡，表示在 git work tree 中，可以安全執行 Git 命令

  # (可選) 每次都 fetch 最新狀態，但可能會拖慢提示符顯示速度
  # 若要啟用，請取消下面一行的註解，但請注意其潛在的效能影響
  # git fetch --quiet >/dev/null 2>&1 & # 在背景執行 fetch，並忽略所有輸出

  local branch
  # 獲取當前分支名或 commit hash，並忽略錯誤輸出
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || branch=$(git rev-parse --short HEAD 2>/dev/null)

  # 如果成功獲取到分支名或 hash
  if [ -n "$branch" ]; then
    local behind ahead remote
    # 獲取遠端名稱，預設 origin，並忽略錯誤輸出
    remote=$(git config branch.$branch.remote 2>/dev/null || echo "origin")
    local remote_branch_ref
    # 檢查是否有追蹤的遠端分支，並忽略錯誤輸出
    remote_branch_ref=$(git rev-parse --abbrev-ref $branch@{u} 2>/dev/null)

    local status_output=" ("
    status_output+="\033[0;35m${branch}\033[0m" # 洋紅色分支名 (方案一配色)

    # 檢查是否有追蹤的遠端分支
    if [ -n "$remote_branch_ref" ]; then
      # 計算 ahead 和 behind 的數量，並忽略錯誤輸出
      ahead=$(git rev-list --count $remote_branch_ref..HEAD 2>/dev/null)
      behind=$(git rev-list --count HEAD..$remote_branch_ref 2>/dev/null)

      if [ "$behind" -gt 0 ]; then
        status_output+=" \033[0;91m⇣${behind}\033[0m" # 亮紅色表示落後 (方案一配色)
      fi
      if [ "$ahead" -gt 0 ]; then
        status_output+=" \033[0;92m⇡${ahead}\033[0m" # 亮綠色表示領先 (方案一配色)
      fi
    fi # 結束 if [ -n "$remote_branch_ref" ]

    # 檢查是否有未提交的變更 (dirty state)，並忽略錯誤輸出
    if ! git diff --quiet --ignore-submodules HEAD 2>/dev/null; then
      status_output+=" \033[0;93m*\033[0m" # 亮黃色星號表示有變更 (方案一配色)
    fi

    status_output+=")"
    echo -e "$status_output"
  fi # 結束 if [ -n "$branch" ]
  # 如果 branch 是空的 (例如：空倉庫)，函數會在此結束，返回空字符串
}

# PS1 設定 (使用 PROMPT_COMMAND 來更新變數，然後在 PS1 中使用)
# PROMPT_COMMAND 在每次顯示提示符前執行

update_prompt() {
  # 獲取台灣時區時間
  CURRENT_TIME_TW=$(TZ="Asia/Taipei" date +"%H:%M")

  # 獲取 Git 狀態 (調用上面修改過的函數)
  GIT_STATUS=$(parse_git_branch_and_status)
}

# 將 update_prompt 添加到 PROMPT_COMMAND。現有的 PROMPT_COMMAND 也會被保留。
PROMPT_COMMAND="update_prompt; $PROMPT_COMMAND"
PS1='\[\033[0;90m\]${CURRENT_TIME_TW}\[\033[0m\] \[\033[0;36m\]\u@\h\[\033[0m\]:\[\033[0;94m\]\w\[\033[0m\]${GIT_STATUS}\$ '

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

if [ -z "$SSH_AUTH_SOCK" ]; then
  # Launch ssh-agent if it isn't already running
  eval "$(ssh-agent -s)" > /dev/null
fi
