---
layout: post
title: Git Cheat Sheet
---

Git is a fantastic tool for software development. 

## The Basics
At the most basic level, git keeps track of a project as it evolves through a series of changes. Each stage or checkpoint is called a commit.
- `git init` initializes git to track changes in the current directory and its subdirectories
- `git status` gives you an overview of the current state of the project
- `git add <filename>` adds `filename` to git's staging area. This allows you to add only specific files to the next commit.
- `git add -A` adds all files with any changes, including the deletion of entire files, to git's staging area.
- `git commit -m "Description of commit"` commits all changes to the files in the staging area, with a description of the work
- `git reset --hard` erases all changes, whether staged or not, and reverts back to the state of the most recent commit. **Be careful!**

## Remotes
- `git push [remote]` pushes your changes to the remote repository (or default if none specified)
- `git pull` pulls all changes from the default remote repository
- `git remote rename <current_name> <new_name>` renames the specified remote. GitHub defaults to the name 'origin', but I prefer renaming it to 'github'. Renaming remotes is especially useful for managing multiple environments (i.e. staging and production) on Heroku

## Branching
By default, all commits in git are made on the "master" branch. For individual projects it's often fine to just do all work on the master branch. However, I've found creating new branches especially helpful on collaborative projects (especially in conjunction with pull requests on GitHub, but that's another matter). How exactly to manage branching depends on the team--I've made branches specific to the current day's work (ex. "mk_01_10") and branches specific to features (ex. "mk_forgot_password"). As you can see, I also typically prefix my branch name with my initials, but this is of course optional.
- `git checkout <branch_name>` checks out the specified branch. Note: this command only works for pre-existing branches.
- `git checkout -b <branch_name>` creates a new branch named "branch_name" on the fly and checks it out
- `git push -u <remote> <branch_name>` pushes committed work on the current local branch to a new branch named "branch_name" on the remote repository, and sets everything up for tracking (to allow for standard push/pull).
- `git branch -D <branch_name>` deletes the specified branch locally. It will still exist at any remote to which it has been previously pushed. You cannot delete the branch you currently have checked out.
- `git push <remote> --delete <branch_name>` deletes the specified branch from the remote.

## Merging