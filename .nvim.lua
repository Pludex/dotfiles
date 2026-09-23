vim.keymap.set('n', '<leader>ff', function()
  require('telescope.builtin').find_files({
    file_ignore_patterns = { "^data/", }
  })
end, { buffer = true, desc = "Find files (ignore data)" })

vim.keymap.set('n', '<leader>fg', function()
  require('telescope.builtin').live_grep({
    file_ignore_patterns = { "^data/", }
  })
end, { buffer = true, desc = "Live grep (ignore data)" })
