{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Wrapper that delegates to the active UCC profile launcher.
  # UCC_NVIM_PROFILE env var selects which profile; defaults to "auto" (round-robin).
  # Set by :ClaudeCodeProfile picker or externally.
  # Falls back to bare "claude" if UCC is not installed.
  ucc-nvim-claude = pkgs.writeShellScriptBin "ucc-nvim-claude" ''
    launcher="$HOME/.local/share/ucc/bin/ucc-''${UCC_NVIM_PROFILE:-auto}"
    if [ -x "$launcher" ]; then
      exec "$launcher" "$@"
    else
      exec claude "$@"
    fi
  '';
in
{
  plugins = {
    claudecode = {
      enable = builtins.elem "claudecode" config.khanelivim.ai.plugins;

      settings = {
        terminal_cmd = "${ucc-nvim-claude}/bin/ucc-nvim-claude";
        terminal = {
          split_side = "right";
          split_width_percentage = 0.30;
        };
        focus_after_send = false;
        track_selection = true;
        diff_opts = {
          auto_close_on_accept = true;
          vertical_split = true;
          open_in_current_tab = true;
        };
      };

      lazyLoad = lib.mkIf config.plugins.lz-n.enable {
        settings = {
          cmd = [
            "ClaudeCode"
            "ClaudeCodeFocus"
            "ClaudeCodeSelectModel"
            "ClaudeCodeProfile"
            "ClaudeCodeAdd"
            "ClaudeCodeSend"
            "ClaudeCodeDiffAccept"
            "ClaudeCodeDiffDeny"
          ];
        };
      };
    };

    which-key.settings.spec = lib.optionals config.plugins.claudecode.enable [
      {
        __unkeyed-1 = "<leader>ac";
        group = "Claude Code";
        icon = "";
        mode = [
          "n"
          "v"
        ];
      }
    ];
  };

  extraConfigLua = lib.mkIf config.plugins.claudecode.enable ''
    vim.api.nvim_create_user_command("ClaudeCodeProfile", function()
      local profiles_dir = vim.fn.expand("~/.local/share/ucc/profiles")
      local uv = vim.uv or vim.loop
      local profiles = {}
      local handle = uv.fs_scandir(profiles_dir)
      if not handle then
        vim.notify("No UCC profiles at " .. profiles_dir, vim.log.levels.WARN)
        return
      end
      while true do
        local name, ftype = uv.fs_scandir_next(handle)
        if not name then break end
        if ftype == "directory" then
          local launcher = vim.fn.expand("~/.local/share/ucc/bin/ucc-" .. name)
          if vim.fn.executable(launcher) == 1 then
            table.insert(profiles, name)
          end
        end
      end
      table.sort(profiles)
      table.insert(profiles, 1, "auto")

      vim.ui.select(profiles, {
        prompt = "Select UCC Profile:",
        format_item = function(item)
          local current = vim.env.UCC_NVIM_PROFILE or "auto"
          if item == current then return item .. " (current)" end
          return item
        end,
      }, function(choice)
        if not choice then return end
        vim.env.UCC_NVIM_PROFILE = choice == "auto" and nil or choice
        pcall(vim.cmd, "ClaudeCodeShutdown")
        vim.notify("Claude profile: " .. choice .. ". Press <leader>act to open.", vim.log.levels.INFO)
      end)
    end, { desc = "Select UCC profile for Claude" })
  '';

  keymaps = lib.mkIf config.plugins.claudecode.enable [
    {
      mode = "n";
      key = "<leader>act";
      action = "<cmd>ClaudeCode<cr>";
      options = {
        desc = "Toggle Claude";
      };
    }
    {
      mode = "n";
      key = "<leader>acc";
      action = "<cmd>ClaudeCode --continue<cr>";
      options = {
        desc = "Continue Claude";
      };
    }
    {
      mode = "n";
      key = "<leader>acr";
      action = "<cmd>ClaudeCode --resume<cr>";
      options = {
        desc = "Resume Claude";
      };
    }
    {
      mode = "n";
      key = "<leader>acf";
      action = "<cmd>ClaudeCodeFocus<cr>";
      options = {
        desc = "Focus Claude";
      };
    }
    {
      mode = "n";
      key = "<leader>acm";
      action = "<cmd>ClaudeCodeSelectModel<cr>";
      options = {
        desc = "Select Claude model";
      };
    }
    {
      mode = "n";
      key = "<leader>acp";
      action = "<cmd>ClaudeCodeProfile<cr>";
      options = {
        desc = "Select UCC profile";
      };
    }
    {
      mode = "n";
      key = "<leader>acb";
      action = "<cmd>ClaudeCodeAdd %<cr>";
      options = {
        desc = "Add current buffer";
      };
    }
    {
      mode = "v";
      key = "<leader>acs";
      action = "<cmd>ClaudeCodeSend<cr>";
      options = {
        desc = "Send to Claude";
      };
    }
    {
      mode = "n";
      key = "<leader>aca";
      action = "<cmd>ClaudeCodeDiffAccept<cr>";
      options = {
        desc = "Accept diff";
      };
    }
    {
      mode = "n";
      key = "<leader>acd";
      action = "<cmd>ClaudeCodeDiffDeny<cr>";
      options = {
        desc = "Deny diff";
      };
    }
  ];
}
