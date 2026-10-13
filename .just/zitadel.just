set unstable := true
set quiet := true

_default:
    just --list zitadel

[doc('Regenerate the client id and secret of zitadel app {app} on {machine}, the units using them restart by themselves')]
[no-exit-message]
[script]
rotate machine app:
    # Find the app in any org or project, its tofu resource and the units that read its credentials
    found=$(nix eval --json ..#nixosConfigurations.{{ machine }}.config.sneeuwvlok.services.authentication.zitadel.organization --apply '
        orgs: builtins.concatLists (builtins.attrValues (builtins.mapAttrs (org: o:
            builtins.concatLists (builtins.attrValues (builtins.mapAttrs (project: p:
                if p.application ? "{{ app }}"
                then [ { resource = "zitadel_application_oidc.${org}_${project}_{{ app }}"; units = p.application."{{ app }}".restartUnits; } ]
                else []
            ) o.project))
        ) orgs))
    ')

    case $(jq length <<< "$found") in
        0) echo "App {{ app }} does not exist on {{ machine }}"; exit 1 ;;
        1) ;;
        *) echo "App {{ app }} exists in more than one org or project on {{ machine }}"; exit 1 ;;
    esac

    resource=$(jq -r '.[0].resource' <<< "$found")
    units=$(jq -r '.[0].units | join(" ")' <<< "$found")

    # The tofu unit recreates whatever is listed in this file, and removes it once applied
    echo "Replacing $resource"
    ssh {{ machine }} "
        echo '$resource' | sudo tee -a /var/lib/tofu/zitadel/replace > /dev/null
        sudo systemctl start tofu-zitadel.service || { sudo journalctl -u tofu-zitadel.service -n 30 --no-pager; exit 1; }

        if sudo test -e /var/lib/tofu/zitadel/replace; then
            sudo rm /var/lib/tofu/zitadel/replace
            echo 'Nothing was replaced, the zitadel workspace only plans'
            exit 1
        fi
    "

    echo "Done${units:+, $units restart once the new credentials are written}"
