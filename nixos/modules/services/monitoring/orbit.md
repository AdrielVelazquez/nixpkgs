# Fleet Orbit {#module-services-orbit}

[Fleet Orbit](https://fleetdm.com/guides/orbit) is Fleet's lightweight osquery
manager. The NixOS service disables Orbit's self-updater and supplies osquery,
Fleet Desktop, the setup browser launcher, and script interpreters from
nixpkgs.

Fleet Orbit includes Fleet Enterprise Edition code and therefore requires an
unfree-package allowance. For a narrow allowance:

```nix
{ lib, ... }:

{
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "fleet-orbit" ];
}
```

## Enrollment secret {#module-services-orbit-enrollment-secret}

`services.orbit.enrollSecretPath` must point to a runtime file outside the Nix
store. Do not use `builtins.toFile`, `pkgs.writeText`, or an inline secret.
Orbit receives the file through a systemd credential.

For a file provisioned outside Nix:

```nix
{
  services.orbit = {
    enable = true;
    fleetUrl = "https://fleet.example.com";
    enrollSecretPath = "/etc/fleet/enroll-secret";
    desktop.enable = true;
    enableScripts = true;
  };
}
```

For a SOPS-managed secret:

```nix
{ config, ... }:

{
  sops.secrets.fleet-orbit-enroll-secret = { };

  services.orbit = {
    enable = true;
    fleetUrl = "https://fleet.example.com";
    enrollSecretPath = config.sops.secrets.fleet-orbit-enroll-secret.path;
    desktop.enable = true;
  };
}
```

## TLS and setup experience {#module-services-orbit-tls-setup}

By default Orbit verifies Fleet with the nixpkgs CA bundle and enables Fleet's
web setup experience through `xdg-open`. Set
`services.orbit.setupExperience.enable = false` to disable browser launching.
Setting `services.orbit.insecure = true` disables TLS verification and omits
the certificate argument; use it only for controlled testing.
