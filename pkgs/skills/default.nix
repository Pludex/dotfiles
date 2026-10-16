{
  lib,
  runCommand,
  writeShellApplication,
  jq,
  uv,
  coreutils,
  findutils,
  gnugrep,
}:
let
  ciscoVersion = "CHANGEME";
  snykVersion = "0.4.18";

  approved = lib.importJSON ./skills-approved.json;

  skills = {

  };

  pathOf = s: if s ? subdir then "${s.src}/${s.subdir}" else "${s.src}";

  tree = runCommand "hermes-skills-unchecked" { } ''
    mkdir -p $out
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: s: ''
        cp -rL ${pathOf s} $out/${name}
        test -f $out/${name}/SKILL.md || { echo "${name}: no SKILL.md" >&2; exit 1; }
      '') skills
    )}
  '';

  unapproved = lib.attrNames (
    lib.filterAttrs (name: s: (approved.${name} or "") != s.src.narHash) skills
  );

  scan = writeShellApplication {
    name = "hermes-skills-scan";
    runtimeInputs = [
      jq
      uv
      coreutils
      findutils
      gnugrep
    ];
    text = ''
      approved_file=$(realpath "$1")
      reports=$(mktemp -d)
      snyk=''${HERMES_SKILLS_SNYK:-}
      failed=0
      echo "reports: $reports"

      scan_one() {
        local name=$1 dir=$2 hash=$3 ok=1 stage
        if [ "$(jq -r --arg n "$name" '.[$n] // ""' "$approved_file")" = "$hash" ]; then
          echo "[$name] already approved"
          return
        fi
        echo "== $name"

        if find "$dir" -type l | grep -q .; then
          echo "FAIL: symlinks present"
          ok=0
        fi
        find "$dir" -type f -perm /111 -printf 'NOTE executable: %P\n'

        stage=$(mktemp -d)
        cp -r --no-preserve=mode "$dir" "$stage/$name"

        uvx --from "cisco-ai-skill-scanner==${ciscoVersion}" skill-scanner scan-all "$stage" \
          --use-behavioral --fail-on-severity high \
          --format json --output "$reports/$name.cisco.json" \
          || { echo "FAIL: cisco"; ok=0; }

        if [ -n "$snyk" ]; then
          uvx "snyk-agent-scan@${snykVersion}" --skills "$stage/$name" --json \
            > "$reports/$name.snyk.json" \
            || { echo "FAIL: snyk"; ok=0; }
        fi

        if [ "$ok" = 1 ]; then
          jq --arg n "$name" --arg h "$hash" '.[$n] = $h' "$approved_file" > "$reports/approved.json"
          cp "$reports/approved.json" "$approved_file"
          echo "[$name] approved"
        else
          failed=1
        fi
      }

      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: s: ''
          scan_one ${name} ${tree}/${name} ${s.src.narHash}
        '') skills
      )}

      exit "$failed"
    '';
  };
in
runCommand "hermes-skills" { passthru = { inherit scan; }; } ''
  ${lib.optionalString (unapproved != [ ]) ''
    echo "not approved: ${lib.concatStringsSep ", " unapproved}" >&2
    echo "run hermes-skills-scan <path>/skills-approved.json" >&2
    exit 1
  ''}
  cp -r --no-preserve=mode ${tree} $out
''
