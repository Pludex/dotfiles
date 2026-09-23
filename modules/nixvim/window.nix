{
  keymaps = [
    {
      mode = "n";
      key = "<leader>w\\";
      action = "<cmd>vsplit<CR><cmd>lua Snacks.picker({ source = \"files\" })<CR>";
    }

    {
      mode = "n";
      key = "<leader>w_";
      action = "<cmd>split<CR><cmd>lua Snacks.picker({ source = \"files\" })<CR>";
    }

    {
      mode = "n";
      key = " <leader> w=";
      action = "<cmd>wincmd + <CR>";
    }

    {
      mode = "n";
      key = "<leader>w-";
      action = "<cmd>wincmd - <CR>";
    }

    {
      mode = "n";
      key = "<leader>wh";
      action = "<cmd>wincmd h <CR>";
    }

    {
      mode = "n";
      key = "<leader>wj";
      action = "<cmd>wincmd j <CR>";
    }

    {
      mode = "n";
      key = "<leader>wk";
      action = "<cmd>wincmd k <CR>";
    }

    {
      mode = "n";
      key = "<leader>wl";
      action = "<cmd>wincmd l <CR>";
    }

    {
      mode = "n";
      key = "<leader>w1";
      action = "<cmd>1wincmd w <CR>";
    }

    {
      mode = "n";
      key = "<leader>w2";
      action = "<cmd>2wincmd w <CR>";
    }

    {
      mode = "n";
      key = "<leader>w3";
      action = "<cmd>3wincmd w <CR>";
    }

    {
      mode = "n";
      key = "<leader>w4";
      action = "<cmd>4wincmd w <CR>";
    }

    {
      mode = "n";
      key = "<leader>ws";
      action = "<cmd>close<CR>";
    }
  ];
}
