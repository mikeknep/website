---
layout: post
title: Bash Aliasing
---
It is often said one of the best characteristics a developer can have is laziness. The fewer keystrokes and lines of code, the better. If you agree and haven't heard of aliases, get excited.

There are many Terminal (or, preferably, [iTerm2](http://www.iterm2.com/)) commands that you'll repeat again and again. Aliasing lets you define shortcuts for any command you choose. Aliases are saved in your bash profile, which can be accessed on Mac OS by typing `open ~/.bash_profile`. Aliases follow this syntax: `export <alias>='<full command>'`. Aliases cannot have spaces, but the commands can; in fact, you can create aliases for multi-line commands by separating the commands with semicolons.

## Navigation
alias project='cd ~/path/to/project'

## Rails
alias rc='rails console'
alias rs='rails server'
alias migrate='rake db:migrate; rake db:test:prepare'

## Git
alias gs='git status'
alias gp='git push'
alias gpl='git pull'
alias gaa='git add -A'
alias gcm='git commit -m'
alias grh='git reset --hard'
alias gco='git checkout'