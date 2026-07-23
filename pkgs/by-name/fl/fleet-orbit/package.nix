{
  bash,
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  nixosTests,
  python3,
  versionCheckHook,
  zsh,
}:

buildGoModule (finalAttrs: {
  pname = "fleet-orbit";
  version = "1.58.0";
  __structuredAttrs = true;

  src = fetchFromGitHub {
    owner = "fleetdm";
    repo = "fleet";
    tag = "orbit-v${finalAttrs.version}";
    hash = "sha256-3rZpL22fLQUT6lihauaxExtIkBCOwyp2/fWLslTfafY=";
  };

  vendorHash = "sha256-+cVeqdFEXQxjFUj9GpzK8IENzvvgat0P+PfP77mUq2I=";

  env.CGO_ENABLED = "1";

  subPackages = [ "orbit/cmd/orbit" ];

  goFlags = [ "-buildvcs=false" ];

  ldflags = [
    "-s"
    "-w"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Version=${finalAttrs.version}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Commit=0000000000000000000000000000000000000000"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/build.Date=1970-01-01T00:00:00Z"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/scripts.scriptShPath=${lib.getExe' bash "sh"}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/scripts.scriptBashPath=${lib.getExe bash}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/scripts.scriptZshPath=${lib.getExe zsh}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/scripts.scriptPythonPath=${lib.getExe python3}"
    "-X=github.com/fleetdm/fleet/v4/orbit/pkg/scripts.scriptPython3Path=${lib.getExe python3}"
  ];

  patches = [
    ./0001-runtime-path-overrides.patch
    ./0002-script-interpreter-paths.patch
  ];

  preCheck = ''
    go test ./orbit/cmd/orbit \
      -run '^(TestExternalComponentPaths|TestConfiguredPath|TestLinuxBrowserPath)$'
    go test ./orbit/pkg/scripts -run '^TestRewriteShebang$'
  '';

  doInstallCheck = true;
  versionCheckProgramArg = "version";
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    tests = {
      inherit (nixosTests) orbit;
    };
    updateScript = nix-update-script {
      extraArgs = [ "--version-regex=^orbit-v(\\d+\\.\\d+\\.\\d+)$" ];
    };
  };

  meta = {
    description = "Fleet's lightweight osquery manager";
    homepage = "https://github.com/fleetdm/fleet";
    changelog = "https://github.com/fleetdm/fleet/releases/tag/orbit-v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      {
        shortName = "fleet-ee";
        fullName = "Fleet Enterprise Edition License";
        url = "https://github.com/fleetdm/fleet/blob/orbit-v${finalAttrs.version}/ee/LICENSE";
        free = false;
      }
    ];
    mainProgram = "orbit";
    maintainers = with lib.maintainers; [ adrielvelazquez ];
    platforms = lib.platforms.linux;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
  };
})
