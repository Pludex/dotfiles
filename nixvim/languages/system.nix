{
  modules.nixvim.languages = {
    bazel = {
      plugins.lsp.servers.bazelrc_lsp = {
        enable = true;
        package = null;
      };

      plugins.treesitter.settings.ensure_installed = [
        "bazel"
        "starlark"
      ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        bazel = [ "buildifier" ];
        bzl = [ "buildifier" ];
      };
    };

    c-cpp = {
      lsp.servers.clangd = {
        enable = true;
        config = {
          cmd = [
            "clangd"
            "--background-index"
            "--clang-tidy"
            "--header-insertion=iwyu"
            "--completion-style=detailed"
          ];
          filetypes = [
            "h"
            "hpp"
            "c"
            "cpp"
            "cxx"
            "cc"
          ];
        };
      };

      plugins.treesitter.settings.ensure_installed = [
        "cpp"
        "c"
      ];
      plugins.conform-nvim.settings.formatters_by_ft = {
        h = [ "clang-format" ];
        hpp = [ "clang-format" ];
        c = [ "clang-format" ];
        cpp = [ "clang-format" ];
        cxx = [ "clang-format" ];
        cc = [ "clang-format" ];
      };
    };

    cmake = {
      plugins.lsp.servers.neocmake = {
        enable = true;
      };

      plugins.treesitter.settings.ensure_installed = [
        "cmake"
      ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        cmake = [ "gersemi" ];
      };
    };

    java = {
      plugins.lsp.servers.jdtls = {
        enable = true;
      };

      plugins.treesitter.settings.ensure_installed = [ "java" ];

      plugins.conform-nvim.settings.formatters_by_ft = {
        java = [ "google-java-format" ];
      };
    };

    rust = {
      plugins.lsp.servers.rust_analyzer = {
        enable = true;
        installCargo = true;
        installRustc = true;
        extraOptions = {
          settings = {
            "rust-analyzer" = {
              "checkOnSave.command" = "clippy";
            };
          };
        };
      };

      plugins.treesitter.settings.ensure_installed = [ "rust" ];
      plugins.conform-nvim.settings.formatters_by_ft = {
        rs = [ "rustfmt" ];
      };
    };
  };
}
