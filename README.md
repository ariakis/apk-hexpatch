# apk-hexpatch

Simple bash script to make hex patch files from a decompiled and modified apk.

Depends on the [APKLab](https://marketplace.visualstudio.com/items?itemName=Surendrajat.apklab) vscode plugin for the tools and stuff, for now.

## Usage:

```bash
# decompile an apk using APKLab
# cd into the output directory
# make some modifications
# don't commit them so we can easily switch back to the clean apk
# then run:

bash /path/to/apk-hexpatch.sh
```

## Todo

- Don't rely on APKLab for paths to tools
- Figure out which commit we're on, compile everything, switch to the first commit in the repo, then swap back to the original commmit that we were on (while also handling stashing)
- Use a temp directory for the comparion parts instead of the cwd
