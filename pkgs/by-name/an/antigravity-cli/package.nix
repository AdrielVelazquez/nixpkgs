{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  versionCheckHook,
}:

let
  # Version and platform-specific data retrieved from Google's manifests
  version = "1.0.6";

  sourceData = {
    "x86_64-linux" = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.6-6458082025406464/linux-x64/cli_linux_x64.tar.gz";
      hash = "sha256-TpwTZuGoZSCw7SNIE7M/WPczPcmR/XdDw/I5n88ouWQ=";
    };
    "aarch64-linux" = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.6-6458082025406464/linux-arm/cli_linux_arm64.tar.gz";
      hash = "sha256-UuLN1xygJSMvIjw+nYW0+NrCdXkh1xCkAT6BjdB9hEA=";
    };
    "aarch64-darwin" = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.6-6458082025406464/darwin-arm/cli_mac_arm64.tar.gz";
      hash = "sha256-fbP4FF1n3gNhbem45p8O/8GYdl85NcGvOJ2WF1UUoDo=";
    };
    "x86_64-darwin" = {
      url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.0.6-6458082025406464/darwin-x64/cli_mac_x64.tar.gz";
      hash = "sha256-3daHp4baEA+PU4bqeLlse8I/CoqRVJ2hYbETevPGnBw=";
    };
  };

  sources = lib.mapAttrs (
    _system: source:
    fetchzip {
      inherit (source) url hash;
    }
  ) sourceData;

in
stdenv.mkDerivation (finalAttrs: {
  pname = "antigravity-cli";
  inherit version;

  src =
    sources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 antigravity $out/bin/agy

    runHook postInstall
  '';

  nativeInstallCheckInputs = [ versionCheckHook ];
  doInstallCheck = true;

  passthru = {
    inherit sources;
    updateScript = ./update.sh;
  };

  meta = {
    description = "Google's Go-based terminal user interface (TUI) agent client";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      adrielvelazquez
      u3kkasha
    ];
    platforms = lib.attrNames sourceData;
    mainProgram = "agy";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
