# Toolchain_CI
Build Toolchain With Git Action

## How to use
1. Fork this repository

2. change some things in build.sh like git config, git username, repo target

3. Add a repository secret in "Settings" - "Secrets and Variables" - "Actions" - "Repository Secret" with the name "LLVM_NAME" and type any llvm name

4. Add a repository secret with the name "GH_TOKEN" and add your access token

5. Run and check workflow.
