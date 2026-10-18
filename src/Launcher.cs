using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Principal;
using System.Windows.Forms;

// Thin launcher only. The readable PowerShell scripts contain all behavior.
internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        string action = "Menu";
        string index = null;
        bool pause = true, noRestart = false, selfTest = false;
        for (int i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--apply": action = "Apply"; break;
                case "--undo": action = "Undo"; break;
                case "--check": action = "Check"; break;
                case "--no-pause": pause = false; break;
                case "--no-restart": noRestart = true; break;
                case "--self-test": selfTest = true; break;
                case "--instance":
                    int n;
                    if (++i >= args.Length || !int.TryParse(args[i], out n) || n < 0 || n > 9999) return 2;
                    index = n.ToString(); break;
                default: Console.Error.WriteLine("Unknown option: " + args[i]); return 2;
            }
        }
        try
        {
            bool admin = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
            if (!admin && !selfTest && action != "Check")
            {
                ProcessStartInfo elevated = new ProcessStartInfo(Assembly.GetExecutingAssembly().Location);
                elevated.UseShellExecute = true;
                elevated.Verb = "runas";
                // Only validated, fixed switches and a numeric index are forwarded.
                elevated.Arguments = String.Join(" ", args);
                using (Process child = Process.Start(elevated)) { child.WaitForExit(); return child.ExitCode; }
            }
            string work = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MuMu-AdBlock", "runtime", Guid.NewGuid().ToString("N"));
            Directory.CreateDirectory(work);
            try
            {
                foreach (string name in new[] { "MuMu-AdBlock.ps1", "MuMu.Core.psm1", "block_mumu_ads.ps1" })
                {
                    using (Stream input = Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
                    using (FileStream output = File.Create(Path.Combine(work, name)))
                    {
                        if (input == null) throw new IOException("Missing embedded script: " + name);
                        input.CopyTo(output);
                    }
                }
                string powershell = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "WindowsPowerShell", "v1.0", "powershell.exe");
                ProcessStartInfo run = new ProcessStartInfo(powershell);
                run.UseShellExecute = false;
                if (selfTest)
                {
                    run.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"$ErrorActionPreference='Stop'; Get-ChildItem -LiteralPath '" + work + "' | ForEach-Object { $e=$null; $t=$null; [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$t,[ref]$e); if ($e.Count) { throw ($e | Out-String) } }; Write-Host 'PASS: all three embedded scripts parsed'\"";
                }
                else
                {
                    run.Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + Path.Combine(work, "MuMu-AdBlock.ps1") + "\" -Action " + action;
                    if (index != null) run.Arguments += " -VmIndex " + index;
                    if (!pause) run.Arguments += " -NoPause";
                    if (noRestart) run.Arguments += " -NoRestart";
                }
                using (Process child = Process.Start(run)) { child.WaitForExit(); return child.ExitCode; }
            }
            finally { try { Directory.Delete(work, true); } catch { } }
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine("MuMu AdBlock: " + ex.Message);
            if (pause) MessageBox.Show(ex.Message, "MuMu AdBlock - not completed", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return 1;
        }
    }
}
