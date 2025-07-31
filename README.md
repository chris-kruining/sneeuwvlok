# My nix flake for my systems

## Commands

### Show the output of the flake

```sh
nix flake show
```

### Create install iso

```sh
nix build .#install-isoConfigurations.minimal
```

## Inpirations

- [dafitt/dotfiles](https://github.com/dafitt/dotfiles/)
- [khaneliman/khanelinix](https://github.com/khaneliman/khanelinix)
- [hmajid2301/nixicle](https://gitlab.com/hmajid2301/nixicle) (the GOAT, he did what I am aiming for!)