local Path = require("fyler.lib.path")
local M = {}

function M.dump(opts, _next)
  local abspath = Path.new(opts.path):os_path()
  local ps_script = string.format(
    [[
      $timeoutSeconds = 30;
      $job = Start-Job -ScriptBlock {
        Add-Type -AssemblyName Microsoft.VisualBasic;
        $ErrorActionPreference = 'Stop';
        $item = Get-Item -LiteralPath '%s';
        if ($item.PSIsContainer) {
          [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory('%s', 'OnlyErrorDialogs', 'SendToRecycleBin');
        } else {
          [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('%s', 'OnlyErrorDialogs', 'SendToRecycleBin');
        }
      };
      $completed = Wait-Job -Job $job -Timeout $timeoutSeconds;
      if ($completed) {
        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue -ErrorVariable jobError;
        Remove-Job -Job $job -Force;
        if ($jobError) {
          Write-Error $jobError;
          exit 1;
        }
      } else {
        Remove-Job -Job $job -Force;
        Write-Error 'Operation timed out after 30 seconds';
        exit 1;
      }
    ]],
    abspath,
    abspath,
    abspath
  )

  local Process = require("fyler.lib.process")
  local proc = Process.new({
    path = "powershell",
    args = { "-NoProfile", "-NonInteractive", "-Command", ps_script },
  })

  proc:spawn_async(function(code)
    vim.schedule(function()
      if code == 0 then
        pcall(_next)
      else
        pcall(_next, "failed to move to recycle bin: " .. (proc:err() or ""))
      end
    end)
  end)
end

return M
