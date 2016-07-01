## What's this?

dirdiff.ps1 is a simple powershell script used to compare two directory structures. It outputs a summary of identical files, different files and files only present in one of the directories. Similarity is determined based on path, filename and file content.

Example usage:
```
PS C:\> dirdiff.ps1 C:\dir1 C:\dir2
One identical file:
        .\identical.txt
One file only present in C:\dir1:
        .\newdir1.txt
2 files only present in C:\dir2:
        .\newdir2.txt
        .\newdir\newfilesdir2.txt
One file present in both directories and has different content:
        .\modified.bin
```

The file handling, directory juggling and comparison parts were taken from this very useful [gist](https://gist.github.com/cchamberlain/883959151aa1162e73f1) published by Cole Chamberlain.
