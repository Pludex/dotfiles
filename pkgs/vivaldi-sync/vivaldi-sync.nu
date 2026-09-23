#!/usr/bin/env nu

# =============================================================================
# Vivaldi Preferences Nix Synchronization Script
# Manages, encrypts, and synchronizes Vivaldi browser preferences with a Nix
# configuration repository using age encryption.
# =============================================================================

# Validates that all required environment variables are present
def ensure-env [] {
    let required_vars = [
        "NIX_CONFIG_DIR"
        "DATA_DIR"
        "AGE_PUBLIC_KEY"
        "AGE_PRIVATE_KEY_PATH"
    ]
    for var in $required_vars {
        # Using -o (--optional) to avoid deprecation warnings in Nushell >= 0.106.0
        if ($env | get -o $var | is-empty) {
            print $"Error: Required environment variable ($var) is missing."
            exit 1
        }
    }
}

# Subcommand: Extract, encrypt, and sync Vivaldi preferences to the Nix config repo
def "main export" [
    --profile: string = "Default" # The Vivaldi profile to export
] {
    ensure-env

    # Resolve local and destination paths
    let prefs_path = ("~/.config/vivaldi" | path expand | path join $profile "Preferences")
    let dest_dir = ($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)

    # We use string concatenation to safely build paths without unintended string interpolation
    let age_filename = "vivaldi.config." + $profile + ".json.age"
    let hash_filename = "vivaldi.config." + $profile + ".json.sha256"
    let enc_path = ($dest_dir | path join $age_filename)
    let hash_path = ($dest_dir | path join $hash_filename)

    let tmp_file_name = "vivaldi_export_" + $profile + "_" + ($nu.pid | into string) + ".json"
    let tmp_path = ("/tmp" | path join $tmp_file_name)

    if not ($prefs_path | path exists) {
        print $"Error: Vivaldi Preferences file not found at ($prefs_path)"
        exit 1
    }

    print $"Reading Vivaldi preferences from ($prefs_path)..."

    # Open as raw string and parse to handle the missing .json file extension properly
    let prefs = try {
        open --raw $prefs_path | from json
    } catch {
        print "Error: Failed to parse local Preferences JSON file."
        exit 1
    }

    # Extract the root-level "vivaldi" object using the modern optional flag (-o)
    let vivaldi_obj = ($prefs | get -o vivaldi)
    if ($vivaldi_obj | is-empty) {
        print "Error: No 'vivaldi' object found in local Preferences."
        exit 1
    }

    # Write cleartext to temporary file, formatting with an indentation of 2 spaces
    $vivaldi_obj | to json -i 2 | save -f $tmp_path

    # Compute sha256 hash of the cleartext file before encryption
    let current_hash = (open --raw $tmp_path | hash sha256)

    # Read the previously saved hash if it exists
    let existing_hash = if ($hash_path | path exists) {
        open --raw $hash_path | str trim
    } else {
        ""
    }

    # Compare hashes to skip useless encryption and git commits
    if ($current_hash == $existing_hash) {
        print "Preferences are unchanged. Skipping export."
        rm -f $tmp_path
        exit 0
    }

    print "Changes detected. Encrypting preferences..."
    if not ($dest_dir | path exists) {
        mkdir $dest_dir
    }

    # Encrypt the temporary JSON using age
    ^age -r $env.AGE_PUBLIC_KEY -o $enc_path $tmp_path
    if $env.LAST_EXIT_CODE != 0 {
        print "Error: Failed to encrypt the file using age."
        rm -f $tmp_path
        exit 1
    }

    # Persist the newly computed hash
    $current_hash | save -f $hash_path
    rm -f $tmp_path

    print "Synchronizing with Nix config repository..."
    cd $env.NIX_CONFIG_DIR

    print " -> git pull"
    ^git pull
    if $env.LAST_EXIT_CODE != 0 { print "Error: git pull failed."; exit 1 }

    print " -> git add ."
    ^git add .
    if $env.LAST_EXIT_CODE != 0 { print "Error: git add failed."; exit 1 }

    let commit_msg = "chore(vivaldi): update encrypted preferences for " + $profile
    print (" -> git commit -m \"" + $commit_msg + "\"")
    ^git commit -m $commit_msg
    if $env.LAST_EXIT_CODE != 0 { print "Error: git commit failed."; exit 1 }

    print " -> git push"
    ^git push
    if $env.LAST_EXIT_CODE != 0 { print "Error: git push failed."; exit 1 }

    print "Export synchronization completed successfully."
}

# Subcommand: Decrypt and import Vivaldi preferences from the Nix config repo
def "main import" [
    --profile: string = "Default" # The Vivaldi profile to import
] {
    ensure-env

    # Resolve local and target paths
    let prefs_dir = ("~/.config/vivaldi" | path expand | path join $profile)
    let prefs_path = ($prefs_dir | path join "Preferences")
    let backup_path = ($prefs_dir | path join "Preferences.bak")

    let dest_dir = ($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)
    let age_filename = "vivaldi.config." + $profile + ".json.age"
    let enc_path = ($dest_dir | path join $age_filename)

    let tmp_file_name = "vivaldi_import_" + $profile + "_" + ($nu.pid | into string) + ".json"
    let tmp_path = ("/tmp" | path join $tmp_file_name)

    if not ($enc_path | path exists) {
        print $"Error: Encrypted configuration not found at ($enc_path)"
        exit 1
    }

    if not ($prefs_path | path exists) {
        print $"Error: Target Vivaldi Preferences file not found at ($prefs_path)"
        exit 1
    }

    print $"Decrypting ($enc_path) via age..."
    ^age -d -i $env.AGE_PRIVATE_KEY_PATH -o $tmp_path $enc_path
    if $env.LAST_EXIT_CODE != 0 {
        print "Error: Decryption failed. Please verify your private key."
        exit 1
    }

    let imported_data = try {
        open --raw $tmp_path | from json
    } catch {
        print "Error: Failed to parse the decrypted JSON payload."
        rm -f $tmp_path
        exit 1
    }

    print $"Creating safety backup at ($backup_path)..."
    cp -f $prefs_path $backup_path

    print "Merging imported preferences..."
    let current_prefs = try {
        open --raw $prefs_path | from json
    } catch {
        print "Error: Failed to parse current local Vivaldi Preferences JSON."
        rm -f $tmp_path
        exit 1
    }

    # Upsert securely replaces the 'vivaldi' object or creates it if it happens to be missing
    let updated_prefs = ($current_prefs | upsert vivaldi $imported_data)

    print "Writing updated preferences back to disk safely..."
    $updated_prefs | to json -i 2 | save -f $prefs_path

    # Clean up decrypted cleartext data
    rm -f $tmp_path
    print "Import completed successfully."
}

# Fallback wrapper to display help automatically if arguments are invalid or empty
def main [] {
    print "Vivaldi Nix Configuration Sync"
    print "Usage:"
    print "  nu vivaldi-sync.nu export [--profile <profile_name>]"
    print "  nu vivaldi-sync.nu import [--profile <profile_name>]"
    print ""
    print "Options:"
    print "  --profile: Target Vivaldi profile name (default: \"Default\")"
}
