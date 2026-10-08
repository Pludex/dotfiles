let
  mapk = key: action: {
    mode = "n";
    inherit key action;
  };

  mapr = key: action: {
    mode = "n";
    inherit key;
    action.__raw = action;
  };

  resize = dir: cmd: ''
    function()
      local grow = vim.fn.winnr("${dir}") ~= vim.fn.winnr()
      vim.cmd("${cmd} " .. (grow and "+2" or "-2"))
    end
  '';
in
{
  keymaps = [
    (mapk "<leader>w\\" "<cmd>vsplit<CR><cmd>lua Snacks.picker({ source = \"files\" })<CR>")
    (mapk "<leader>w_" "<cmd>split<CR><cmd>lua Snacks.picker({ source = \"files\" })<CR>")

    (mapk "<leader>w1" "<cmd>1wincmd w<CR>")
    (mapk "<leader>w2" "<cmd>2wincmd w<CR>")
    (mapk "<leader>w3" "<cmd>3wincmd w<CR>")
    (mapk "<leader>w4" "<cmd>4wincmd w<CR>")

    (mapk "<A-s>" "<cmd>close<CR>")

    # focus
    (mapk "<A-h>" "<cmd>wincmd h<CR>")
    (mapk "<A-j>" "<cmd>wincmd j<CR>")
    (mapk "<A-k>" "<cmd>wincmd k<CR>")
    (mapk "<A-l>" "<cmd>wincmd l<CR>")

    # move
    (mapk "<A-S-h>" "<cmd>wincmd H<CR>")
    (mapk "<A-S-j>" "<cmd>wincmd J<CR>")
    (mapk "<A-S-k>" "<cmd>wincmd K<CR>")
    (mapk "<A-S-l>" "<cmd>wincmd L<CR>")

    # resize
    (mapr "<C-A-h>" (resize "h" "vertical resize"))
    (mapr "<C-A-l>" (resize "l" "vertical resize"))
    (mapr "<C-A-j>" (resize "j" "resize"))
    (mapr "<C-A-k>" (resize "k" "resize"))
  ];
}
