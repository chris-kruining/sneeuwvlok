{
  lib,
  ardaLib,
  self,
  pkgs,
  settings,
  ...
}: let
  createTerranixModule = {
    users,
    email_password,
    key_file,
    ...
  }: terra: let
    inherit (lib) toUpper toSentenceCase nameValuePair mapAttrs mapAttrs' concatMapAttrs concatMapStringsSep filterAttrsRecursive listToAttrs imap0 head drop length literalExpression attrNames;
    inherit (ardaLib) toSnakeCase;
    inherit (terra.lib) tfRef;

    _refTypeMap = {
      org = {type = "org";};
      project = {type = "project";};
      user = {
        type = "user";
        tfType = "human_user";
      };
    };

    mapRef' = {
      type,
      tfType ? type,
    }: name: {"${type}Id" = "\${ resource.zitadel_${tfType}.${toSnakeCase name}.id }";};
    mapRef = type: name: mapRef' (_refTypeMap.${type}) name;
    mapEnum = prefix: value: "${prefix}_${value |> toSnakeCase |> toUpper}";

    mapValue = type: value: ({
      appType = mapEnum "OIDC_APP_TYPE" value;
      grantTypes = map (t: mapEnum "OIDC_GRANT_TYPE" t) value;
      responseTypes = map (t: mapEnum "OIDC_RESPONSE_TYPE" t) value;
      authMethodType = mapEnum "OIDC_AUTH_METHOD_TYPE" value;

      flowType = mapEnum "FLOW_TYPE" value;
      triggerType = mapEnum "TRIGGER_TYPE" value;
      accessTokenType = mapEnum "OIDC_TOKEN_TYPE" value;
    }."${type}" or value);

    toResource = name: value:
      nameValuePair
      (toSnakeCase name)
      (lib.mapAttrs' (k: v: nameValuePair (toSnakeCase k) (mapValue k v)) value);

    withRef = type: name: attrs: attrs // (mapRef type name);

    select = keys: callback: set:
      if (length keys) == 0
      then mapAttrs' callback set
      else let
        key = head keys;
      in
        concatMapAttrs (k: v: select (drop 1 keys) (callback k) (v.${key} or {})) set;

    append = attrList: set: set // (listToAttrs attrList);

    forEach = src: key: set: let
      _key = concatMapStringsSep "_" (k: "\${item.${k}}") key;
    in
      {
        forEach = tfRef ''          {
                  for item in ${src} :
                  "''${item.org}_''${item.name}" => item
                }'';
      }
      // set;
  in {
    terraform.required_providers.zitadel = {
      source = "zitadel/zitadel";
      version = "2.2.0";
    };

    provider.zitadel = {
      domain = settings.externalDomain;
      insecure = false;

      system_api = {
        user = "infra";
        inherit key_file;
      };
    };

    locals = {
      extra_users = tfRef "
        flatten([ for org, users in jsondecode(file(\"${users}\")): [
          for name, details in users: {
            org = org
            name = name
            email = details.email
            firstName = details.firstName
            lastName = details.lastName
          }
        ] ])
      ";
      orgs = settings.organization |> mapAttrs (org: _: tfRef "resource.zitadel_org.${org}.id");
    };

    resource = {
      # Organizations
      zitadel_org =
        settings.organization
        |> select [] (
          name: {isDefault, ...}:
            {inherit name isDefault;}
            |> toResource name
        );

      # Projects per organization
      zitadel_project =
        settings.organization
        |> select ["project"] (
          org: name: {
            hasProjectCheck,
            privateLabelingSetting,
            projectRoleAssertion,
            projectRoleCheck,
            ...
          }:
            {
              inherit name hasProjectCheck privateLabelingSetting projectRoleAssertion projectRoleCheck;
            }
            |> withRef "org" org
            |> toResource "${org}_${name}"
        );

      # Each OIDC app per project
      zitadel_application_oidc =
        settings.organization
        |> select ["project" "application"] (
          org: project: name: {
            displayName ? name,
            redirectUris,
            grantTypes,
            responseTypes,
            ...
          }:
            {
              name = displayName;
              inherit redirectUris grantTypes responseTypes;

              accessTokenRoleAssertion = true;
              idTokenRoleAssertion = true;
              accessTokenType = "JWT";
            }
            |> withRef "org" org
            |> withRef "project" "${org}_${project}"
            |> toResource "${org}_${project}_${name}"
        );

      # Each project role
      zitadel_project_role =
        settings.organization
        |> select ["project" "role"] (
          org: project: name: value:
            {
              inherit (value) displayName group;
              roleKey = name;
            }
            |> withRef "org" org
            |> withRef "project" "${org}_${project}"
            |> toResource "${org}_${project}_${name}"
        );

      # Each project role assignment
      zitadel_user_grant =
        settings.organization
        |> select ["project" "assign"] (
          org: project: user: roles:
            {roleKeys = roles;}
            |> withRef "org" org
            |> withRef "project" "${org}_${project}"
            |> withRef "user" "${org}_${user}"
            |> toResource "${org}_${project}_${user}"
        );

      # Users
      zitadel_human_user =
        settings.organization
        |> select ["user"] (
          org: name: {
            email,
            userName,
            firstName,
            lastName,
            ...
          }:
            {
              inherit email userName firstName lastName;

              isEmailVerified = true;
              lifecycle = {
                ignore_changes = ["first_name" "last_name" "user_name"];
              };
            }
            |> withRef "org" org
            |> toResource "${org}_${name}"
        )
        |> append [
          (forEach "local.extra_users" ["org" "name"] {
              orgId = tfRef "local.orgs[each.value.org]";
              userName = tfRef "each.value.name";
              email = tfRef "each.value.email";
              firstName = tfRef "each.value.firstName";
              lastName = tfRef "each.value.lastName";

              isEmailVerified = true;
            }
            |> toResource "extraUsers")
        ];

      # Global user roles
      zitadel_instance_member =
        settings.organization
        |> filterAttrsRecursive (n: v: !(v ? "instanceRoles" && (length v.instanceRoles) == 0))
        |> select ["user"] (
          org: name: {instanceRoles, ...}:
            {roles = instanceRoles;}
            |> withRef "user" "${org}_${name}"
            |> toResource "${org}_${name}"
        );

      # Organazation specific roles
      zitadel_org_member =
        settings.organization
        |> filterAttrsRecursive (n: v: !(v ? "roles" && (length v.roles) == 0))
        |> select ["user"] (
          org: name: {roles, ...}:
            {inherit roles;}
            |> withRef "org" org
            |> withRef "user" "${org}_${name}"
            |> toResource "${org}_${name}"
        );

      # Organazation's actions
      zitadel_action =
        settings.organization
        |> select ["action"] (
          org: name: {
            timeout,
            allowedToFail,
            script,
            ...
          }:
            {
              inherit allowedToFail name;
              timeout = "${toString timeout}s";
              script = "const ${name} = ${script}";
            }
            |> withRef "org" org
            |> toResource "${org}_${name}"
        );

      # Organazation's action assignments
      zitadel_trigger_actions =
        settings.organization
        |> concatMapAttrs (
          org: {triggers, ...}:
            triggers
            |> imap0 (i: {
              flowType,
              triggerType,
              actions,
              ...
            }: (
              let
                name = "trigger_${toString i}";
              in
                {
                  inherit flowType triggerType;

                  actionIds =
                    actions
                    |> map (action: (tfRef "zitadel_action.${org}_${toSnakeCase action}.id"));
                }
                |> withRef "org" org
                |> toResource "${org}_${name}"
            ))
            |> listToAttrs
        );

      # SMTP config
      zitadel_smtp_config.default = {
        sender_address = settings.smtp.senderAddress;
        sender_name = settings.smtp.senderName;
        tls = true;
        host = settings.smtp.host;
        user = settings.smtp.user;
        password = tfRef "file(\"${email_password}\")";
        set_active = true;
      };

      # Client credentials per app
      local_sensitive_file =
        settings.organization
        |> select ["project" "application"] (
          org: project: name: {exportMap, ...}:
            nameValuePair "${org}_${project}_${name}" {
              content = ''
                ${
                  if exportMap.client_id != null
                  then exportMap.client_id
                  else "CLIENT_ID"
                }=${tfRef "resource.zitadel_application_oidc.${org}_${project}_${name}.client_id"}
                ${
                  if exportMap.client_secret != null
                  then exportMap.client_secret
                  else "CLIENT_SECRET"
                }=${tfRef "resource.zitadel_application_oidc.${org}_${project}_${name}.client_secret"}
              '';
              filename = "/var/lib/zitadel/clients/${org}_${project}_${name}";
            }
        );
    };
  };
in {
  createInfra = args @ {...}: let
    tofu = "${lib.getExe pkgs.opentofu} -input=false";
    terraformConfiguration = self.inputs.terranix.lib.terranixConfiguration {
      system = pkgs.stdenv.hostPlatform.system;
      modules = [
        (createTerranixModule args)
      ];
    };
  in {
    systemd.services."infra-zitadel" = {
      description = "Infra for Zitadel";

      wantedBy = ["multi-user.target"];
      wants = ["zitadel.service"];
      after = ["zitadel.service"];

      preStart = ''
        install -d -m 0770 -o zitadel -g media /var/lib/infra-zitadel
      '';

      script = ''
        # Sleep for a bit to give the service a chance to start up
        sleep 5s

        if [ "$(systemctl is-active zitadel)" != "active" ]; then
          echo "zitadel is not running"
          exit 1
        fi

        # Print the path to the source for easier debugging
        echo "config location: ${terraformConfiguration}"

        # Copy infra code into workspace
        cp -f ${terraformConfiguration} config.tf.json

        # Initialize OpenTofu
        ${tofu} init

        # Run the infrastructure code
        ${tofu} plan -out=tfplan
        ${tofu} apply -json -auto-approve tfplan
      '';

      serviceConfig = {
        Type = "oneshot";
        User = "zitadel";
        Group = "zitadel";

        StateDirectory = "/var/lib/infra-zitadel";
      };
    };
  };
}
