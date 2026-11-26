{ base, lib, ... }:
{
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
