{ lib, base, ... }:
{
  plugins.blink-cmp = {
    enable = true;
    autoLoad = true;

    setupLspCapabilities = true;

    settings = {
      keymap = {
        preset = "none";

        "<A-j>" = [
          "select_next"
          "fallback"
        ];
        "<A-k>" = [
          "select_prev"
          "fallback"
        ];

        "<Down>" = [
          "select_next"
          "fallback"
        ];
        "<Up>" = [
          "select_prev"
          "fallback"
        ];

        "<C-space>" = [
          "show"
          "show_documentation"
          "hide_documentation"
        ];
        "<Tab>" = [
          "accept"
          "fallback"
        ];
      };

      appearance = {
        nerd_font_variant = "mono";
        use_nvim_cmp_as_default = true;
      };

      completion = {
        accept.auto_brackets.enabled = true;
        trigger = {
          show_on_keyword = true;
          show_on_trigger_character = true;
        };

        documentation = {
          auto_show = true;
          auto_show_delay_ms = 200;
          window.border = "rounded";
          windown.winhighlight = "Normal:BlinkCmpMenu,FloatBorder:BlinkCmpMenuBorder,CursorLine:BlinkCmpMenuSelection,Search:None,CurSearch:None";
        };

        ghost_text = {
          enabled = true;
          show_with_menu = true;
        };

        menu = {
          auto_show = true;

          border = "rounded";
          draw = {
            columns.__raw = ''
              { { "label", "label_description", gap = 1 }, { "kind_icon", gap = 1, "kind" } }
            '';
            components = {
              kind_icon = {
                ellipsis = false;

                text.__raw = ''
                  function(ctx)
                    local icon = ctx.kind_icon
                    if ctx.item.source_name == "Path" then
                      local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label)
                      if dev_icon then
                        icon = dev_icon
                      end
                    else
                      icon = require("lspkind").symbolic(ctx.kind, { mode = "symbol" })
                    end
                    return icon .. ctx.icon_gap
                  end
                '';

                highlight.__raw = ''
                  function(ctx)
                    local hl = ctx.kind_hl
                    if ctx.item.source_name == "Path" then
                      local dev_icon, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
                      if dev_icon then
                        hl = dev_hl
                      end
                    end
                    return hl
                  end
                '';
              };
            };
          };
        };
      };

      fuzzy = {
        frecency.enabled = true;
        implementation = "prefer_rust_with_warning"; # "rust" | "lua" | "prefer_rust..."
        sorts = [
          "score"
          "sort_text"
        ];
        use_proximity = true;
      };

      snippets = {
        preset = "luasnip";
      };

      sources = {
        default = [
          "lsp"
          "path"
          "snippets"
          "buffer"
        ];

        providers = {
          lsp = {
            enabled = true;
            name = "LSP";
            module = "blink.cmp.sources.lsp";
            score_offset = 90;
          };
          path = {
            enabled = true;
            name = "Path";
            module = "blink.cmp.sources.path";
            score_offset = 3;
            opts.trailing_slash = false;
          };
          snippets = {
            enabled = true;
            name = "Snippets";
            module = "blink.cmp.sources.snippets";
            score_offset = 85;
          };
          buffer = {
            enabled = true;
            name = "Buffer";
            module = "blink.cmp.sources.buffer";
            score_offset = 0;
            min_keyword_length = 3;
          };
        };
      };

      signature = {
        enabled = true;
      };
    };
  };

  plugins.cmp = {
    enable = false;
    autoEnableSources = true;

    settings = {
      experimental = {
        ghost_text = true;
      };

      snippet.expand.__raw = ''
        function(args)
          require('luasnip').lsp_expand(args.body)
        end
      '';

      performance = {
        max_view_entries = 30;
      };

      window = {
        completion = {
          side_padding = 1;
          scrollbar = true;
          border = base.glyphs.border;
          winhighlight = "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
        };

        documentation = {
          border = base.glyphs.border;
          winhighlight = "FloatBorder:CmpBorder,Normal:CmpPmenu,CursorLine:CmpSel,Search:PmenuSel";
        };
      };

      mapping = {
        "<A-u>".__raw = ''
          cmp.mapping(function()
            if cmp.visible() then
              cmp.abort()
            else
              cmp.complete()
            end
          end, { "i", "c" })
        '';

        "<C-d>".__raw = "cmp.mapping.scroll_docs(-4)";
        "<C-k>".__raw = "cmp.mapping.scroll_docs(4)";

        "<CR>".__raw = "cmp.mapping.confirm({ select = false })";

        "<Tab>".__raw = ''
          cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif require("luasnip").expand_or_jumpable() then
              require("luasnip").expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" })
        '';

        "<S-Tab>".__raw = ''
          cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif require("luasnip").jumpable(-1) then
              require("luasnip").jump(-1)
            else
              fallback()
            end
          end, { "i", "s" })
        '';

        "<Down>".__raw = ''
          function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif require("luasnip").expand_or_jumpable() then
              vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
            else
              fallback()
            end
          end
        '';

        "<Up>".__raw = ''
          function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif require("luasnip").jumpable(-1) then
              vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
            else
              fallback()
            end
          end
        '';
      };

      sources = [
        {
          name = "nvim_lsp";
          priority = 1000;
        }
        {
          name = "luasnip";
          priority = 750;
        }
        {
          name = "buffer";
          priority = 500;
        }
        {
          name = "path";
          priority = 250;
        }
      ];

      formatting = {
        fields = [
          "icon"
          "abbr"
          "kind"
          "menu"
        ];
        format = lib.mkForce ''
          require('lspkind').cmp_format({
            maxwidth = {
              menu = 50,
              abbr = 50,
            },
            ellipsis_char = '...',
            show_labelDetails = true,
            before = function (entry, vim_item)
              if vim_item.kind then
                vim_item.kind = "   (" .. vim_item.kind .. ")"
              end
              return vim_item
            end
          })
        '';
      };
    };
  };
}
