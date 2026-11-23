{
  plugins.nvim-autopairs = {
    enable = true;
    settings = {
      check_ts = false;
      map_cr = true;
    };
  };

  extraConfigLua = ''
    local ok, cmp = pcall(require, "cmp")
    if ok then
      cmp.event:on(
        "confirm_done",
        require("nvim-autopairs.completion.cmp").on_confirm_done()
      )
    end

    vim.api.nvim_create_user_command("AutopairsReload", function()
      local ap = require("nvim-autopairs")
      ap.disable()
      ap.enable()
    end, {})
  '';
}
