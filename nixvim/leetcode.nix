{
  plugins.nui.enable = true;

  plugins.leetcode = {
    enable = true;
    settings = {
      lang = "cpp";

      storage = {
        home = "/workspaces/learn/leetcode";
        kaggle = false;
      };

      console = {
        open_on_runcode = true;
        size = {
          width = "75%";
          height = "75%";
        };
      };
      image_support = false;

      hooks.question_enter = [
        {
          __raw = ''
            function(question)
              local q = question.q
              local dir = vim.fs.joinpath("/workspaces/learn/leetcode", "desc")
              vim.fn.mkdir(dir, "p")

              local md = q.content or ""
              local entities = {
                ["&nbsp;"] = " ", ["&lt;"] = "<", ["&gt;"] = ">",
                ["&quot;"] = '"', ["&#39;"] = "'", ["&amp;"] = "&",
              }
              md = md
                :gsub("<pre>(.-)</pre>", "\n```\n%1\n```\n")
                :gsub("<strong>(.-)</strong>", "**%1**")
                :gsub("<b>(.-)</b>", "**%1**")
                :gsub("<em>(.-)</em>", "*%1*")
                :gsub("<code>(.-)</code>", "`%1`")
                :gsub("<sup>(.-)</sup>", "^%1")
                :gsub("<li>%s*", "- ")
                :gsub("</li>", "\n")
                :gsub("</p>", "\n\n")
                :gsub("<br%s*/?>", "\n")
                :gsub("<[^>]+>", "")
                :gsub("&%w+;", entities)
                :gsub("&#39;", "'")
                :gsub("\n\n\n+", "\n\n")

              local header = ("# %s. %s\n\n**Difficulty:** %s\n\n"):format(
                q.frontend_id, q.title, q.difficulty or "?"
              )
              local path = vim.fs.joinpath(dir, ("%04d.%s.md"):format(tonumber(q.frontend_id) or 0, q.title_slug))
              vim.fn.writefile(vim.split(header .. md, "\n"), path)

              pcall(function() question.description:hide() end)
            end
          '';
        }
      ];
    };
  };

  autoCmd = [
    {
      event = "VimEnter";
      command = "Leet";
      once = true;
    }
  ];
}
