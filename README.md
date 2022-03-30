# install-wsl

```
/ >_ /
(powershell icon. I do not have the icon or image.)
```

## Overview

Install WSL2 distribution from docker images.

## Requirement

- powershell
- windows
- wsl2
- docker

(I don't think about it much, but that's about it.)

## Usage

1. download this.
2. create or edit config json.
    1. install-wsl-centos8.json is sample of centos8.
    1. install-wsl-rocky.json is sample of RockyLinux.
3. execute following command.
    ```
    .\install-wsl.ps1 -ConfigFile install-wsl-rocky.json
    ```

## Features

- install wsl2 distribution from docker
- initialize wsl2 distribution.
    - for example: 
        - dnf update -y
        - python3 -m pip install psutil
        - ...

## Reference

- [WSL2で 自分好みのRedHat系 が使いたい！](https://zenn.dev/tachang/articles/ac2349509c2675)

## Author

- [my hatena blog](https://uumee-diary.hatenablog.com/)
- [my twitter](https://twitter.com/uumee_san)

## Licensce
MIT License
