using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Threading;
using System.Windows.Forms;

namespace Aternix.Eclipse
{
    internal static class EclipseTests
    {
        static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
        static object Field(object target, string name) { return target.GetType().GetField(name, BindingFlags.Instance | BindingFlags.NonPublic).GetValue(target); }
        static string Hash(string path) { using (var sha = SHA256.Create()) using (var file = File.OpenRead(path)) return BitConverter.ToString(sha.ComputeHash(file)).Replace("-", "").ToLowerInvariant(); }
        static void Pump(int milliseconds)
        {
            Stopwatch clock = Stopwatch.StartNew();
            while (clock.ElapsedMilliseconds < milliseconds) { Application.DoEvents(); Thread.Sleep(5); }
        }
        static void Wait(Engine engine)
        {
            Stopwatch clock = Stopwatch.StartNew();
            while (engine.Busy && clock.ElapsedMilliseconds < 15000) { Application.DoEvents(); Thread.Sleep(5); }
            Pump(100);
            Check(!engine.Busy, "Updater timed out");
        }
        [STAThread]
        static int Main()
        {
            Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
            string root = AppDomain.CurrentDomain.BaseDirectory;
            string sourcePath = Path.Combine(root, "update-source.txt");
            byte[] previousSource = File.Exists(sourcePath) ? File.ReadAllBytes(sourcePath) : null;
            string languagePath = Path.Combine(root, "language.txt");
            byte[] previousLanguage = File.Exists(languagePath) ? File.ReadAllBytes(languagePath) : null;
            string effectsPath = Path.Combine(root, "eclipse-effects-off.txt");
            bool previousEffects = File.Exists(effectsPath);
            string fixture = Path.Combine(root, "test-fixture");
            string target = Path.Combine(root, "eclipse-integration-test.txt");
            try
            {
                Check(!File.Exists(target), "Test must not overwrite an existing file");
                Directory.CreateDirectory(Path.Combine(fixture, "files"));
                string payload = Path.Combine(fixture, "files", "eclipse-integration-test.txt");
                File.WriteAllText(payload, "Aternix Eclipse updater integration fixture\n");
                File.WriteAllText(Path.Combine(fixture, "manifest.json"), "{\"version\":\"eclipse-test\",\"ready\":true,\"files\":[{\"path\":\"eclipse-integration-test.txt\",\"size\":" + new FileInfo(payload).Length + ",\"sha256\":\"" + Hash(payload) + "\"}]}");
                File.WriteAllText(sourcePath, fixture);
                using (Engine engine = new Engine(root))
                {
                    Check(engine.Resolution.Items.Count == 9, "Expected the original nine resolution choices");
                    engine.SetLanguage(false); Check(!engine.Czech, "English did not reach engine");
                    engine.SetLanguage(true); Check(engine.Czech, "Czech did not reach engine");
                    engine.Music.Checked = !engine.Music.Checked;
                    engine.Resolution.SelectedIndex = 8;
                    Check(engine.Resolution.SelectedIndex == 8, "Resolution binding failed");
                    if (Environment.OSVersion.Platform == PlatformID.Win32NT)
                    {
                        engine.Update(); Check(engine.Busy, "Original updater did not start"); Wait(engine);
                        Check(File.Exists(target) && Hash(target) == Hash(payload), "Updater did not deploy the checksum-verified payload");
                        Check(engine.Progress == 100, "Progress did not reach 100");
                        Console.WriteLine("PASS original updater deployed fixture: " + engine.Status);
                        engine.Update(); Wait(engine);
                        Check(engine.Status.Contains("0"), "Repeated update should change zero files");
                        Console.WriteLine("PASS repeated update: " + engine.Status);
                    }
                    else Console.WriteLine("SKIP updater file integration: unchanged engine uses Windows path separators; test on Windows.");
                    using (Form owner = new Form())
                    {
                        owner.Location = new Point(120, 140); engine.Align(owner);
                        Form original = (Form)Field(engine, "form");
                        Check(original.Owner == owner && original.Location == owner.Location, "Original dialogs would be positioned off-screen");
                    }
                    Console.WriteLine("PASS engine settings, language and visible dialog ownership");
                }
                using (EclipseForm form = new EclipseForm(root, null))
                {
                    form.Show(); Pump(150);
                    Storm storm = (Storm)Field(form, "storm"); storm.Enabled = true;
                    System.Windows.Forms.Timer timer = (System.Windows.Forms.Timer)Field(form, "timer"); timer.Stop();
                    using (Bitmap a = new Bitmap(form.Width, form.Height))
                    using (Bitmap b = new Bitmap(form.Width, form.Height))
                    {
                        form.DrawToBitmap(a, form.ClientRectangle); storm.Advance(.05); form.DrawToBitmap(b, form.ClientRectangle);
                        int changed = 0;
                        for (int y = 120; y < 420; y += 3) for (int x = 30; x < 700; x += 3) if (a.GetPixel(x, y) != b.GetPixel(x, y)) changed++;
                        Check(changed > 50, "Rain did not animate");
                        b.Save(Path.Combine(root, "Eclipse-runtime.png"), ImageFormat.Png);
                    }
                    double before = storm.Time; storm.Enabled = false; storm.Advance(.05); Check(storm.Time == before, "Disabled effects kept advancing");
                    storm.Enabled = true;
                    for (int i = 0; i < 150; i++) storm.Advance(.05);
                    var bolts = (System.Collections.ICollection)Field(storm, "bolts"); Check(bolts.Count == 2, "Lightning did not generate a bolt and branch");
                    Console.WriteLine("PASS rain moves, effects pause, lightning generated");
                    SteelButton en = (SteelButton)Field(form, "en"), cz = (SteelButton)Field(form, "cz");
                    en.PerformClick(); Check(((SteelButton)Field(form, "play")).Text == "PLAY GAME", "EN UI did not change");
                    cz.PerformClick(); Check(((SteelButton)Field(form, "play")).Text == "SPUSTIT HRU", "CZ UI did not change");
                    foreach (Control child in form.Controls) Check(form.ClientRectangle.Contains(child.Bounds), "Control outside window: " + child.Text);
                    form.ClientSize = new Size(1008, 648); Application.DoEvents();
                    foreach (Control child in form.Controls) Check(form.ClientRectangle.Contains(child.Bounds), "Control outside smaller window: " + child.Text);
                    using (Bitmap small = new Bitmap(form.Width, form.Height)) { form.DrawToBitmap(small, form.ClientRectangle); small.Save(Path.Combine(root, "Eclipse-runtime-small.png"), ImageFormat.Png); }
                    Console.WriteLine("PASS CZ/EN buttons and controls fit at full and reduced sizes");
                    form.Close(); Check(!timer.Enabled, "Animation timer survived closing");
                }
                Console.WriteLine("PASS Eclipse integration and UI tests. Windows game launch still requires client-side verification.");
                return 0;
            }
            catch (Exception e) { Console.WriteLine(e); return 1; }
            finally
            {
                if (previousSource == null) File.Delete(sourcePath); else File.WriteAllBytes(sourcePath, previousSource);
                if (previousLanguage == null) File.Delete(languagePath); else File.WriteAllBytes(languagePath, previousLanguage);
                if (!previousEffects) File.Delete(effectsPath);
                if (Directory.Exists(fixture)) Directory.Delete(fixture, true);
                File.Delete(target);
            }
        }
    }
}
