**Required CLI Tools (for Nix Packaging)**

- `nushell` (`nu`): The core shell interpreter executing the script.
- `git`: For repository synchronization (`git pull`, `git add`, `git commit`, `git push`).
- `age`: For client-side encryption and decryption of configuration files.

---

**Prompt for Claude**

Write a robust, Linux-optimized Nushell (`.nu`) script to manage, encrypt, and synchronize Vivaldi browser preferences with a Nix configuration repository. All code, comments, and terminal messages must be written strictly in **English**.

### Environment Variables & Structure

- `$env.NIX_CONFIG_DIR`: The absolute path to the root of the Nix configuration repository (where git commands run).
- `$env.DATA_DIR`: The relative path inside `$env.NIX_CONFIG_DIR` where configuration files are stored. The full path is computed as `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)`.
- `$env.AGE_PUBLIC_KEY`: The public key string used for encrypting files during export.
- `$env.AGE_PRIVATE_KEY_PATH`: The file path to the private key used for decrypting files during import.

### Subcommands & Flags

- **Subcommands:**
  - `export`: Extracts preferences from the local browser, hashes them, encrypts them via `age`, and syncs to the Nix config repo.
  - `import`: Decrypts the encrypted config file via `age` and pushes preferences back to the local browser.
- **Flags:**
  - `--profile` (string, optional, default: `"Default"`): Determines the Vivaldi profile path at `~/.config/vivaldi/<profile>/Preferences`.

### Detailed Workflow

**1. The `export` Subcommand:**

- Read the local file `~/.config/vivaldi/<profile>/Preferences` and extract the root-level object named `"vivaldi"`.
- Write this object temporarily into `/tmp`, formatting it with an indentation of **2 spaces** (`to json -i 2`) to optimize for clean structure.
- **Compute the `sha256` hash** of this cleartext temporary JSON file _before_ encryption, and compare it against the existing hash file located at `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR $"vivaldi.config.($profile).json.sha256")`.
- **If unchanged:** Print a message and exit without modifying files or triggering git.
- **If changed:**
  - Encrypt the temporary cleartext JSON file using `age` (using `$env.AGE_PUBLIC_KEY`) and save the output as `vivaldi.config.<profile>.json.age` inside `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)`.
  - Update the corresponding sha256 hash file `vivaldi.config.<profile>.json.sha256` in the same directory.
  - Change working directory to `$env.NIX_CONFIG_DIR` and safely execute:
    - `git pull` (to fetch latest changes and avoid conflicts)
    - `git add .`
    - `git commit -m "chore(vivaldi): update encrypted preferences for <profile>"`
    - `git push`

**2. The `import` Subcommand:**

- Locate and decrypt `vivaldi.config.<profile>.json.age` from `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)` using `age` and the private key file at `$env.AGE_PRIVATE_KEY_PATH`, saving the decrypted cleartext temporarily in `/tmp`.
- Automatically create a safety backup copy named `Preferences.bak` of the active Vivaldi preferences file inside `~/.config/vivaldi/<profile>/` before modifying anything.
- Read the original `~/.config/vivaldi/<profile>/Preferences` file, update/merge the root-level `"vivaldi"` object with the decrypted JSON contents, and safely save it back to the Vivaldi profile directory.

### Implementation Guidelines

- Use Nushell native idioms exclusively for file paths (`path join`), data reading (`open`), JSON formatting (`to json -i 2`), and hashing (`hash sha256`).
- Invoke external `age` and `git` commands seamlessly within Nushell syntax with robust error handling for missing keys or decryption failures.
