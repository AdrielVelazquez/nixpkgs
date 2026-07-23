{ lib, ... }:

let
  mkOrbitNode =
    insecure:
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      testOrbit = pkgs.writeShellApplication {
        name = "orbit";
        text = ''
          set -eu

          test "$ORBIT_FLEET_URL" = "https://fleet.example.test"
          test -r "$ORBIT_ENROLL_SECRET_PATH"
          test "$(cat "$ORBIT_ENROLL_SECRET_PATH")" = "test-secret"
          test "$ORBIT_OSQUERYD_PATH" = "${lib.getExe' pkgs.osquery "osqueryd"}"
          test "$ORBIT_OSQUERY_LOG_PATH" = "/var/log/orbit/osquery"
          test "$ORBIT_DESKTOP_PATH" = "${lib.getExe pkgs.fleet-desktop}"
          test "$ORBIT_BROWSER_PATH" = "${lib.getExe' pkgs.xdg-utils "xdg-open"}"
          test "$(command -v sudo)" = "${config.security.wrapperDir}/sudo"
          test "$(readlink -f "$(command -v bash)")" = "$(readlink -f "${lib.getExe pkgs.bash}")"
          test "$(readlink -f "$(command -v zsh)")" = "$(readlink -f "${lib.getExe pkgs.zsh}")"
          test "$(readlink -f "$(command -v python)")" = "$(readlink -f "${lib.getExe pkgs.python3}")"
          test "$(readlink -f "$(command -v python3)")" = "$(readlink -f "${lib.getExe pkgs.python3}")"
          test -d /var/lib/orbit
          test -d /var/log/orbit

          ${
            if insecure then
              ''
                test -z "''${ORBIT_FLEET_CERTIFICATE+x}"
              ''
            else
              ''
                test "$ORBIT_FLEET_CERTIFICATE" = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ''
          }

          ${lib.getExe pkgs.fleet-orbit} version | grep -Fx "orbit 1.58.0"
          ${lib.getExe pkgs.fleet-desktop} --version | grep -Fx "fleet-desktop 1.58.0"
          touch /run/orbit-test-ready
          exec sleep infinity
        '';
      };
    in
    {
      environment.etc."fleet/enroll-secret".text = "test-secret";
      security.sudo.enable = true;

      services.orbit = {
        enable = true;
        package = testOrbit;
        fleetUrl = "https://fleet.example.test";
        enrollSecretPath = "/etc/fleet/enroll-secret";
        inherit insecure;
        debug = true;
        enableScripts = true;
        hostIdentifier = "uuid";
        desktop = {
          enable = true;
          package = pkgs.fleet-desktop;
          alternativeBrowserHost = "fleet-browser.example.test";
        };
        setupExperience = {
          enable = true;
          browserPackage = pkgs.xdg-utils;
        };
      };
    };
in
{
  name = "orbit";
  meta.maintainers = with lib.maintainers; [ adrielvelazquez ];

  nodes.secure = mkOrbitNode false;
  nodes.insecure = mkOrbitNode true;

  testScript = ''
    start_all()
    for machine in (secure, insecure):
        machine.wait_for_unit("orbit.service")
        machine.wait_for_file("/run/orbit-test-ready")
        machine.succeed("systemctl is-active orbit.service")
  '';
}
