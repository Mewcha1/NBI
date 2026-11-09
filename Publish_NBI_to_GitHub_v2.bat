@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM NBI Jupyter Book: build the site and publish to GitHub Pages.
REM Adapted from publish_HART_direct_env.bat.
REM Double-click this file after saving your notebook edits.
REM ============================================================

set "BOOK_DIR=C:\Users\mgebremedhin\OneDrive - Florida Gulf Coast University\NBI"
set "ENV_DIR=C:\Users\mgebremedhin\AppData\Local\ESRI\conda\envs\nbi-book"
set "REPO_URL=https://github.com/Mewcha1/NBI.git"
set "SITE_URL=https://mewcha1.github.io/NBI/"

set "PY=%ENV_DIR%\python.exe"
set "JB=%ENV_DIR%\Scripts\jupyter-book.exe"
set "GHP=%ENV_DIR%\Scripts\ghp-import.exe"

echo ============================================================
echo   NBI - Build and Publish Jupyter Book to GitHub Pages
echo ============================================================
echo.

echo [1/9] Opening the NBI Jupyter Book directory...
cd /d "%BOOK_DIR%"
if errorlevel 1 goto :bookdir_error

echo [2/9] Checking Jupyter Book source files...
if not exist "_config.yml" goto :config_error
if not exist "_toc.yml" goto :toc_error

echo [3/9] Checking the existing nbi-book environment...
if not exist "%PY%" goto :env_error
if not exist "%JB%" goto :jb_error
echo Environment: %ENV_DIR%
echo.

echo [4/9] Cleaning the previous build when possible...
if exist "_build" (
    attrib -R -H -S "_build" /S /D >nul 2>&1
    rmdir /S /Q "_build" >nul 2>&1
)
if exist "_build" (
    echo WARNING: _build could not be completely removed.
    echo Continuing; if the build fails, close apps using this folder.
) else (
    echo Old build removed, or there was no old build.
)
echo.

echo [5/9] Building the NBI Jupyter Book...
"%JB%" build .
if errorlevel 1 goto :build_error
if not exist "_build\html\index.html" goto :html_error
echo Build complete.
echo.

echo [6/9] Checking Git and the destination repository...
where git >nul 2>&1
if errorlevel 1 goto :git_missing

if not exist ".git" (
    echo No local Git repository found. Initializing one...
    git init
    if errorlevel 1 goto :git_error
    git branch -M main
    if errorlevel 1 goto :git_error
) else (
    REM Preserve any existing gh-pages branch and work on main.
    set "CURRENT_BRANCH="
    for /f "delims=" %%B in ('git branch --show-current') do set "CURRENT_BRANCH=%%B"
    if /I not "!CURRENT_BRANCH!"=="main" (
        git show-ref --verify --quiet refs/heads/main
        if errorlevel 1 (
            echo Creating a separate main branch for notebook source...
            git switch -c main
        ) else (
            echo Switching to the existing main branch...
            git switch main
        )
        if errorlevel 1 goto :branch_error
    )
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    git remote add origin "%REPO_URL%"
    if errorlevel 1 goto :git_error
) else (
    REM This file is only intended for Mewcha1/NBI.
    REM Do not silently redirect a different repository.
    for /f "delims=" %%R in ('git remote get-url origin') do set "EXISTING_REMOTE=%%R"
    if /I not "!EXISTING_REMOTE!"=="%REPO_URL%" (
        if /I not "!EXISTING_REMOTE!"=="https://github.com/Mewcha1/NBI" (
            echo ERROR: The current Git remote is not the expected NBI repository:
            echo   !EXISTING_REMOTE!
            echo Expected: %REPO_URL%
            goto :remote_error
        )
    )
)
echo Git target: %REPO_URL%
echo.

echo [7/9] Reviewing and pushing NBI source updates to main...
REM Exclude generated HTML, notebook checkpoints, local caches and secrets.
REM The _build\html folder is published separately via ghp-import.
git add -A -- . ":(exclude)_build" ":(exclude).ipynb_checkpoints" ":(exclude)**/.ipynb_checkpoints/**" ":(exclude).buildinfo" ":(exclude)**/__pycache__/**" ":(exclude)**/.env" ":(exclude)**/.env.*" ":(exclude)**/.venv/**"
if errorlevel 1 goto :git_error

REM Remove unwanted files that may have been staged by a previous run.
REM This only changes Git staging, not the local files.
git rev-parse --verify HEAD >nul 2>&1
if errorlevel 1 (
    REM First local commit: remove previously staged generated files.
    git rm -r -q --cached --ignore-unmatch -- .ipynb_checkpoints _build .buildinfo >nul 2>&1
) else (
    git reset -q HEAD -- .ipynb_checkpoints >nul 2>&1
    git reset -q HEAD -- _build >nul 2>&1
    git reset -q HEAD -- .buildinfo >nul 2>&1
)

git diff --cached --quiet
if errorlevel 1 (
    echo The following local files will be included in the GitHub commit:
    REM Avoid Git pager (the colon prompt that stopped the previous run).
    git --no-pager diff --cached --name-only
    echo.
    echo The NBI repository is PUBLIC. Check this list for private files.
    choice /C YN /M "Commit and upload these files to GitHub"
    if errorlevel 2 goto :cancelled
    git commit -m "Update NBI Jupyter Book"
    if errorlevel 1 goto :commit_error
) else (
    echo No new source changes to commit.
)

git push -u origin main
if errorlevel 1 goto :push_error
echo Source branch pushed successfully.
echo.

echo [8/9] Publishing the rendered website to gh-pages...
if not exist "%GHP%" (
    echo Installing ghp-import into the same nbi-book environment...
    "%PY%" -m pip install ghp-import
    if errorlevel 1 goto :ghp_install_error
)
if not exist "%GHP%" goto :ghp_missing

"%GHP%" -n -p -f "_build\html"
if errorlevel 1 goto :publish_error
echo Site files pushed successfully.
echo.

echo [9/9] NBI publication completed.
echo.
echo GitHub source code:
echo   https://github.com/Mewcha1/NBI
echo.
echo Published website:
echo   %SITE_URL%
echo.
echo GitHub Pages settings should be:
echo   Settings ^> Pages ^> Deploy from a branch
echo   Branch: gh-pages
echo   Folder: / (root)
echo.
echo The public website may need a short time to update.
echo.
pause
exit /b 0

:bookdir_error
echo ERROR: Cannot open the NBI project directory:
echo   %BOOK_DIR%
goto :fail
:config_error
echo ERROR: Cannot find _config.yml in the NBI directory.
goto :fail
:toc_error
echo ERROR: Cannot find _toc.yml in the NBI directory.
goto :fail
:env_error
echo ERROR: Cannot find Python in:
echo   %ENV_DIR%
goto :fail
:jb_error
echo ERROR: Cannot find jupyter-book.exe in:
echo   %ENV_DIR%\Scripts
goto :fail
:build_error
echo ERROR: Jupyter Book build failed; no changes were published.
echo If _build is locked, close VS Code, Jupyter and any preview windows.
echo OneDrive syncing may also lock build files.
goto :fail
:html_error
echo ERROR: Build did not produce _build\html\index.html.
goto :fail
:git_missing
echo ERROR: Git was not found. Install Git for Windows first.
goto :fail
:git_error
echo ERROR: A Git command failed. Check the messages above.
goto :fail
:branch_error
echo ERROR: Could not switch to the main source branch.
echo Save your work and resolve local Git changes, then rerun.
goto :fail
:remote_error
echo ERROR: Git remote mismatch. The publisher did not push changes.
goto :fail
:commit_error
echo ERROR: Git commit failed.
echo If needed, configure Git with your name and GitHub email.
goto :fail
:push_error
echo ERROR: Could not push the source branch to origin/main.
echo Check your GitHub sign-in, network and existing remote commits.
echo No website publishing was attempted.
goto :fail
:ghp_install_error
echo ERROR: Could not install ghp-import in the nbi-book environment.
goto :fail
:ghp_missing
echo ERROR: ghp-import.exe was not found after installation.
goto :fail
:publish_error
echo ERROR: The website could not be pushed to gh-pages.
echo The source push may have succeeded; review the messages above.
goto :fail
:cancelled
echo.
echo Cancelled: nothing was pushed to GitHub.
goto :fail
:fail
echo.
echo NBI publication stopped.
echo.
pause
exit /b 1
