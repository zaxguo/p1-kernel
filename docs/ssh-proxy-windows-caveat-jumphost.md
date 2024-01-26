### Windows caveat 2: an outdated ssh client (only needed if you run into this bug)

Previously, some students reported VSCode has a bug that broke ssh with jumphost. You can refer to [this](https://github.com/microsoft/vscode-remote-release/issues/18#issuecomment-507258777). In a nutshell, manual download a newer win32 ssh to overwrite the one shipping with Win 10 (it's a good idea to save a back up). Window's security mechanism is in your way. Work around it. 

Make sure to download the OpenSSH-Win64 version (not Win32). 2. Double check the SSH version. See the screenshot below.

| ![](images/vscode-ssh-override.png)                  | ![](images/win-ssh-version.png)           |
| ---------------------------------------------------- | ----------------------------------------- |
| *Turning off protection on ssh.exe (see link above)* | *The newer ssh client manually installed* |

Now, you should be good to go with VSCode. 

**Password-less login used to work fine, but suddenly breaks?** A common cause is that VSCode updates automatically, overwriting the ssh client you manually installed. Solution: check your ssh version and use the one we suggested. 