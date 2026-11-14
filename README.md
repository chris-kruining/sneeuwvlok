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

### Configure the router

The udm's settings that are managed from here are in `packages/udm/config.nix`. Show what differs, then change it:

```sh
nix run .#udm
nix run .#udm -- apply
```

It reads the api key (`unifi/api_key` in orome's secrets) with the admin age key, so it runs from any machine that has it.

## Inpirations

- [dafitt/dotfiles](https://github.com/dafitt/dotfiles/)
- [khaneliman/khanelinix](https://github.com/khaneliman/khanelinix)
- [hmajid2301/nixicle](https://gitlab.com/hmajid2301/nixicle) (the GOAT, he did what I am aiming for!)