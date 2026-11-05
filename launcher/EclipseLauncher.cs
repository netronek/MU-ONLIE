using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Windows.Forms;

[assembly: AssemblyTitle("AternixMU Eclipse Launcher")]
[assembly: AssemblyProduct("AternixMU")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace Aternix.Eclipse
{
    // The tested game/updater assembly stays intact. This shell only changes presentation.
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            try
            {
                string root = AppDomain.CurrentDomain.BaseDirectory;
                Directory.SetCurrentDirectory(root);
                bool preview = Array.IndexOf(args, "--preview") >= 0;
                Engine engine = preview ? null : new Engine(root);
                using (EclipseForm form = new EclipseForm(root, engine)) Application.Run(form);
            }
            catch (Exception error)
            {
                Exception cause = error.GetBaseException();
                MessageBox.Show("Launcher nelze spustit. Rozbalte celý ZIP do složky hry.\n\n" + cause.Message,
                    "AternixMU", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }
    }

    internal sealed class Engine : IDisposable
    {
        private readonly Form form;
        private readonly Type type;
        public Engine(string root)
        {
            Assembly assembly = Assembly.LoadFrom(Path.Combine(root, "Aternix.Engine.dll"));
            type = assembly.GetType("MuLocal.Launcher", true);
            form = (Form)Activator.CreateInstance(type, true);
            // Off-screen owner form keeps the original BackgroundWorker/UI synchronization alive.
            form.ShowInTaskbar = false;
            form.StartPosition = FormStartPosition.Manual;
            form.Location = new Point(-20000, -20000);
            form.Opacity = 0;
        }
        private object Field(string name) { return type.GetField(name, BindingFlags.Instance | BindingFlags.NonPublic).GetValue(form); }
        private void Call(string name, params object[] values) { type.GetMethod(name, BindingFlags.Instance | BindingFlags.NonPublic).Invoke(form, values); }
        public void Align(Form owner)
        {
            if (form.Owner != owner) form.Owner = owner;
            // Original error dialogs center on this hidden form: keep them on the user's screen.
            form.Location = owner.Location;
        }
        public void Start(Form owner)
        {
            Align(owner);
            form.Show();
            // The original artwork has its own animation; do not render it behind this skin.
            object art = Field("artwork");
            if (art != null) art.GetType().GetProperty("AnimationEnabled").SetValue(art, false, null);
            form.Hide();
            owner.Activate();
        }
        public ComboBox Resolution { get { return (ComboBox)Field("resolution"); } }
        public CheckBox Music { get { return (CheckBox)Field("music"); } }
        public CheckBox Effects { get { return (CheckBox)Field("effects"); } }
        public CheckBox Windowed { get { return (CheckBox)Field("windowed"); } }
        public bool Czech { get { return (bool)Field("cz"); } }
        public bool Busy { get { return ((BackgroundWorker)Field("worker")).IsBusy; } }
        public bool? Online { get { return (bool?)Field("serverOnline"); } }
        public string Status { get { return ((Control)Field("state")).Text; } }
        public int Progress { get { object p = Field("progress"); return (int)p.GetType().GetProperty("Value").GetValue(p, null); } }
        public void SetLanguage(bool czech)
        {
            type.GetField("cz", BindingFlags.Instance | BindingFlags.NonPublic).SetValue(form, czech);
            ((Action)Field("translateUi"))();
            File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "language.txt"), czech ? "CZ" : "EN");
        }
        public void Update() { if (!Busy) Call("<.ctor>b__d", form, EventArgs.Empty); }
        public void Play() { if (!Busy) Call("<.ctor>b__f", form, EventArgs.Empty); }
        public void Dispose() { form.Close(); form.Dispose(); }
    }

    internal sealed class Storm
    {
        private struct Drop { public float X, Y, Speed, Length; public int Alpha; }
        private readonly Drop[] drops = new Drop[140];
        private readonly Random random = new Random();
        private readonly List<PointF[]> bolts = new List<PointF[]>();
        private double nextLightning = 7;
        private double lightningAt = -10;
        public double Time { get; private set; }
        public bool Enabled = true;
        public Storm()
        {
            for (int i = 0; i < drops.Length; i++) drops[i] = new Drop {
                X = (float)random.NextDouble(), Y = (float)random.NextDouble(),
                Speed = .38f + (float)random.NextDouble() * .55f,
                Length = .013f + (float)random.NextDouble() * .028f, Alpha = random.Next(35, 100) };
        }
        public void Advance(double dt)
        {
            if (!Enabled) return;
            dt = Math.Max(0, Math.Min(.06, dt));
            Time += dt;
            for (int i = 0; i < drops.Length; i++)
            {
                drops[i].Y += (float)dt * drops[i].Speed;
                drops[i].X -= (float)dt * drops[i].Speed * .22f;
                if (drops[i].Y > 1.05f) { drops[i].Y = -.05f; drops[i].X = (float)random.NextDouble() * 1.12f; }
                if (drops[i].X < -.06f) drops[i].X += 1.12f;
            }
            if (Time >= nextLightning)
            {
                lightningAt = Time;
                nextLightning = Time + 9 + random.NextDouble() * 9;
                bolts.Clear();
                float x = .73f + (float)random.NextDouble() * .18f;
                var points = new List<PointF>();
                for (int j = 0; j < 8; j++) points.Add(new PointF(x + (float)(random.NextDouble() - .5) * .055f, .03f + j * .052f));
                bolts.Add(points.ToArray());
                PointF fork = points[3];
                bolts.Add(new PointF[] { fork, new PointF(fork.X + .06f, fork.Y + .045f), new PointF(fork.X + .035f, fork.Y + .10f) });
            }
        }
        public void Draw(Graphics g, Rectangle area)
        {
            if (!Enabled) return;
            GraphicsState saved = g.Save();
            g.SetClip(area, CombineMode.Intersect);
            foreach (Drop drop in drops)
                using (Pen pen = new Pen(Color.FromArgb(drop.Alpha, 169, 216, 229), .75f))
                    g.DrawLine(pen, area.X + drop.X * area.Width, area.Y + drop.Y * area.Height,
                        area.X + (drop.X - drop.Length * .22f) * area.Width, area.Y + (drop.Y + drop.Length) * area.Height);
            double age = Time - lightningAt;
            // One restrained flash with a soft fade, never rapid flickering.
            if (age >= 0 && age < .65)
            {
                float strength = (float)Math.Exp(-age * 7);
                using (Brush flash = new SolidBrush(Color.FromArgb((int)(30 * strength), 176, 219, 235))) g.FillRectangle(flash, area);
                foreach (PointF[] bolt in bolts)
                {
                    PointF[] p = new PointF[bolt.Length];
                    for (int i = 0; i < p.Length; i++) p[i] = new PointF(area.X + bolt[i].X * area.Width, area.Y + bolt[i].Y * area.Height);
                    using (Pen glow = new Pen(Color.FromArgb((int)(58 * strength), 100, 226, 255), 6)) g.DrawLines(glow, p);
                    using (Pen core = new Pen(Color.FromArgb((int)(215 * strength), 218, 247, 255), 1.1f)) g.DrawLines(core, p);
                }
            }
            g.Restore(saved);
        }
    }

    internal sealed class SteelButton : Button
    {
        private bool hover;
        public bool Primary;
        public bool Selected;
        public SteelButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
            FlatStyle = FlatStyle.Flat; FlatAppearance.BorderSize = 0;
            BackColor = Color.FromArgb(10, 17, 22); ForeColor = EclipseForm.Ink;
            Font = new Font("Segoe UI", 10, FontStyle.Bold);
            Cursor = Cursors.Hand; UseVisualStyleBackColor = false;
        }
        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle r = new Rectangle(1, 1, Width - 3, Height - 3);
            Color top = Primary ? Color.FromArgb(179, 192, 200) : Color.FromArgb(21, 32, 40);
            Color bottom = Primary ? Color.FromArgb(73, 91, 105) : Color.FromArgb(7, 13, 18);
            if (hover && Enabled) { top = Primary ? Color.FromArgb(208, 225, 231) : Color.FromArgb(35, 62, 71); }
            using (var fill = new LinearGradientBrush(r, top, bottom, 90)) g.FillRectangle(fill, r);
            using (var pen = new Pen(Selected || hover ? EclipseForm.Cyan : Color.FromArgb(108, 127, 138))) g.DrawRectangle(pen, r);
            if (Primary)
            {
                using (var p = new Pen(Color.FromArgb(69, 222, 242), 2)) g.DrawLine(p, Width * .17f, Height - 2, Width * .83f, Height - 2);
                using (var p = new Pen(Color.FromArgb(210, 226, 231))) g.DrawLine(p, 6, 5, Width - 7, 5);
            }
            TextRenderer.DrawText(g, Text, Font, ClientRectangle,
                Enabled ? (Primary ? Color.FromArgb(9, 18, 25) : ForeColor) : Color.FromArgb(107, 120, 127),
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis);
            if (Focused && ShowFocusCues) ControlPaint.DrawFocusRectangle(g, Rectangle.Inflate(r, -5, -5));
        }
    }

    internal sealed class StormCheck : CheckBox
    {
        public StormCheck()
        {
            AutoSize = false; BackColor = Color.FromArgb(9, 16, 21); ForeColor = EclipseForm.Ink;
            Font = new Font("Segoe UI", 11); Cursor = Cursors.Hand;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer, true);
        }
        protected override void OnCheckedChanged(EventArgs e) { Invalidate(); base.OnCheckedChanged(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.Clear(BackColor); g.SmoothingMode = SmoothingMode.AntiAlias;
            Rectangle box = new Rectangle(2, (Height - 19) / 2, 19, 19);
            using (Pen pen = new Pen(Checked ? EclipseForm.Cyan : Color.FromArgb(132, 151, 162))) g.DrawRectangle(pen, box);
            if (Checked) using (Pen pen = new Pen(EclipseForm.Cyan, 2))
                g.DrawLines(pen, new Point[] { new Point(6, box.Y + 10), new Point(11, box.Y + 15), new Point(19, box.Y + 5) });
            TextRenderer.DrawText(g, Text, Font, new Rectangle(36, 0, Width - 36, Height), ForeColor,
                TextFormatFlags.Left | TextFormatFlags.VerticalCenter);
            if (Focused && ShowFocusCues) ControlPaint.DrawFocusRectangle(g, new Rectangle(32, 2, Width - 35, Height - 4));
        }
    }

    internal sealed class EclipseForm : Form
    {
        public static readonly Color Cyan = Color.FromArgb(116, 237, 247);
        public static readonly Color Ink = Color.FromArgb(224, 232, 236);
        private readonly Engine engine;
        private readonly string root;
        private readonly Image scene, logo;
        private readonly Storm storm = new Storm();
        private readonly Timer timer = new Timer();
        private readonly Stopwatch watch = Stopwatch.StartNew();
        private readonly ComboBox resolution = new ComboBox();
        private readonly StormCheck windowed = new StormCheck(), music = new StormCheck(), effects = new StormCheck();
        private readonly SteelButton play = new SteelButton(), update = new SteelButton(), cz = new SteelButton(), en = new SteelButton(), animation = new SteelButton();
        private readonly ToolTip tip = new ToolTip();
        private readonly List<Control> scaledControls = new List<Control>();
        private readonly Dictionary<Control, Rectangle> bounds = new Dictionary<Control, Rectangle>();
        private bool czech = true, starting = true, closed;
        private double lastTime;
        private string status = "";
        private bool? online;
        private int progress;
        private Bitmap frame;
        private bool frameDirty = true;
        private const int W = 1120, H = 720;
        private readonly Rectangle artArea = new Rectangle(2, 108, 731, 516);
        private bool dragging;
        private Point dragAt;

        public EclipseForm(string root, Engine engine)
        {
            this.root = root; this.engine = engine;
            AutoScaleMode = AutoScaleMode.None;
            FormBorderStyle = FormBorderStyle.None; StartPosition = FormStartPosition.CenterScreen;
            Text = "AternixMU · Season 6 · Eclipse"; BackColor = Color.FromArgb(7, 13, 18);
            DoubleBuffered = true; KeyPreview = true;
            // Cache the illustration at its display size; rain never resamples a large PNG every frame.
            using (Image source = Image.FromFile(Path.Combine(root, "assets", "eclipse-scene.png")))
            {
                Bitmap cached = new Bitmap(artArea.Width, artArea.Height, PixelFormat.Format32bppPArgb);
                using (Graphics canvas = Graphics.FromImage(cached)) { canvas.InterpolationMode = InterpolationMode.HighQualityBicubic; canvas.DrawImage(source, new Rectangle(0, 0, cached.Width, cached.Height)); }
                scene = cached;
            }
            logo = Image.FromFile(Path.Combine(root, "assets", "eclipse-logo.png"));
            string iconPath = Path.Combine(root, "assets", "eclipse.ico");
            if (File.Exists(iconPath)) Icon = new Icon(iconPath);
            ClientSize = new Size(W, H);
            Rectangle screen = Screen.FromControl(this).WorkingArea;
            float scale = Math.Min(1f, Math.Min((screen.Width - 24f) / W, (screen.Height - 24f) / H));
            ClientSize = new Size((int)(W * scale), (int)(H * scale));

            SteelButton web = Button("WEB", new Rectangle(620, 34, 100, 36), delegate { Open("https://www.aternixmu.eu/"); });
            SteelButton discord = Button("DISCORD", new Rectangle(735, 34, 120, 36), delegate { Open("https://discord.gg/tMENCSJJZE"); });
            tip.SetToolTip(web, "aternixmu.eu"); tip.SetToolTip(discord, "AternixMU Discord");
            Add(cz, new Rectangle(875, 34, 48, 36)); cz.Text = "CZ"; cz.Click += delegate { Language(true); };
            Add(en, new Rectangle(923, 34, 48, 36)); en.Text = "EN"; en.Click += delegate { Language(false); };
            Button("—", new Rectangle(1012, 16, 35, 30), delegate { WindowState = FormWindowState.Minimized; });
            Button("×", new Rectangle(1060, 16, 35, 30), delegate { Close(); });

            resolution.DropDownStyle = ComboBoxStyle.DropDownList;
            resolution.FlatStyle = FlatStyle.Flat; resolution.BackColor = Color.FromArgb(18, 29, 37);
            resolution.ForeColor = Ink; resolution.Font = new Font("Segoe UI", 12);
            Add(resolution, new Rectangle(768, 228, 315, 34));
            if (engine != null)
            {
                foreach (object item in engine.Resolution.Items) resolution.Items.Add(item);
                resolution.SelectedIndex = engine.Resolution.SelectedIndex;
                windowed.Checked = engine.Windowed.Checked; music.Checked = engine.Music.Checked; effects.Checked = engine.Effects.Checked;
                czech = engine.Czech;
            }
            else { resolution.Items.AddRange(new object[] { "1280 × 720", "1920 × 1080" }); resolution.SelectedIndex = 1; music.Checked = effects.Checked = true; }
            Add(windowed, new Rectangle(768, 286, 315, 36)); Add(music, new Rectangle(768, 330, 315, 36)); Add(effects, new Rectangle(768, 374, 315, 36));
            resolution.SelectedIndexChanged += delegate { if (engine != null && !starting) engine.Resolution.SelectedIndex = resolution.SelectedIndex; };
            windowed.CheckedChanged += delegate { if (engine != null && !starting) engine.Windowed.Checked = windowed.Checked; };
            music.CheckedChanged += delegate { if (engine != null && !starting) engine.Music.Checked = music.Checked; };
            effects.CheckedChanged += delegate { if (engine != null && !starting) engine.Effects.Checked = effects.Checked; };

            play.Primary = true; play.Font = new Font("Georgia", 20, FontStyle.Bold);
            Add(play, new Rectangle(764, 527, 323, 72)); play.Click += delegate { Act(false); };
            Add(update, new Rectangle(823, 652, 264, 40)); update.Click += delegate { Act(true); };
            Add(animation, new Rectangle(478, 34, 114, 36)); animation.Font = new Font("Segoe UI", 9);
            try { storm.Enabled = !File.Exists(Path.Combine(root, "eclipse-effects-off.txt")); } catch { }
            animation.Click += delegate {
                storm.Enabled = !storm.Enabled;
                try { string path = Path.Combine(root, "eclipse-effects-off.txt"); if (storm.Enabled) File.Delete(path); else File.WriteAllText(path, "off"); } catch { }
                Translate(); Invalidate();
            };
            tip.SetToolTip(animation, "Zapnout/vypnout déšť a blesky · Rain and lightning on/off");
            Translate(); ScaleControls(); starting = false;
            timer.Interval = 33;
            timer.Tick += Tick;
            Shown += delegate { if (engine != null) engine.Start(this); lastTime = watch.Elapsed.TotalSeconds; timer.Start(); };
            LocationChanged += delegate { if (engine != null && !closed) engine.Align(this); };
            Resize += delegate { ScaleControls(); if (WindowState == FormWindowState.Minimized) timer.Stop(); else if (!starting && !closed) { lastTime = watch.Elapsed.TotalSeconds; timer.Start(); } };
            FormClosing += delegate(object sender, FormClosingEventArgs e) {
                if (engine != null && engine.Busy) { e.Cancel = true; MessageBox.Show(this, T("Počkejte na dokončení aktualizace.", "Please wait until the update is complete."), "AternixMU"); }
            };
            FormClosed += delegate { closed = true; timer.Stop(); };
            KeyDown += delegate(object sender, KeyEventArgs e) { if (e.KeyCode == Keys.F8) { animation.PerformClick(); e.Handled = true; } };
            MouseDown += delegate(object sender, MouseEventArgs e) { if (e.Button == MouseButtons.Left && e.Y < 108f * ClientSize.Height / H) { dragging = true; dragAt = e.Location; Capture = true; } };
            MouseMove += delegate(object sender, MouseEventArgs e) { if (dragging) Location = new Point(Left + e.X - dragAt.X, Top + e.Y - dragAt.Y); };
            MouseUp += delegate { dragging = false; Capture = false; };
        }
        private void Add(Control control, Rectangle rectangle) { bounds.Add(control, rectangle); scaledControls.Add(control); Controls.Add(control); control.Bounds = rectangle; }
        private SteelButton Button(string text, Rectangle rectangle, EventHandler handler) { var button = new SteelButton(); button.Text = text; Add(button, rectangle); button.Click += handler; return button; }
        private void ScaleControls()
        {
            float sx = ClientSize.Width / (float)W, sy = ClientSize.Height / (float)H;
            foreach (Control control in scaledControls) { Rectangle r = bounds[control]; control.Bounds = new Rectangle((int)(r.X * sx), (int)(r.Y * sy), (int)(r.Width * sx), (int)(r.Height * sy)); }
            Invalidate();
        }
        private string T(string cs, string en) { return czech ? cs : en; }
        private void Language(bool cs)
        {
            try { if (engine != null) engine.SetLanguage(cs); czech = cs; Translate(); }
            catch (Exception e) { MessageBox.Show(this, e.GetBaseException().Message, "AternixMU"); }
        }
        private void Translate()
        {
            frameDirty = true;
            cz.Selected = czech; en.Selected = !czech; cz.Invalidate(); en.Invalidate();
            windowed.Text = T("Hra v okně", "Windowed mode"); music.Text = T("Hudba", "Music"); effects.Text = T("Zvuky", "Sound effects");
            play.Text = T("SPUSTIT HRU", "PLAY GAME"); update.Text = T("AKTUALIZOVAT", "CHECK UPDATES");
            animation.Text = T("EFEKTY: ", "EFFECTS: ") + (storm.Enabled ? "ON" : "OFF");
            animation.Selected = storm.Enabled; animation.Invalidate();
            timer.Interval = storm.Enabled ? 33 : 150;
            Invalidate();
        }
        private void Act(bool updating)
        {
            if (engine == null) { MessageBox.Show(this, T("Toto je pouze náhled vzhledu.", "This is a visual preview only."), "AternixMU"); return; }
            try { if (updating) engine.Update(); else engine.Play(); }
            catch (Exception error) { MessageBox.Show(this, error.GetBaseException().Message, "AternixMU"); }
        }
        private void Tick(object sender, EventArgs e)
        {
            double now = watch.Elapsed.TotalSeconds; storm.Advance(now - lastTime); lastTime = now;
            if (engine != null)
            {
                bool changed = status != engine.Status || online != engine.Online || progress != engine.Progress;
                status = engine.Status; online = engine.Online; progress = engine.Progress;
                play.Enabled = update.Enabled = !engine.Busy;
                if (changed) frameDirty = true;
                if (changed) Invalidate(); else if (storm.Enabled) InvalidateScenery();
            }
            else { online = null; if (storm.Enabled) InvalidateScenery(); }
        }
        private void InvalidateScenery()
        {
            float sx = ClientSize.Width / (float)W, sy = ClientSize.Height / (float)H;
            Invalidate(new Rectangle((int)(artArea.X * sx), (int)(artArea.Y * sy), (int)Math.Ceiling(artArea.Width * sx), (int)Math.Ceiling(358 * sy)));
        }
        private void Open(string address)
        {
            try { Process.Start(new ProcessStartInfo(address) { UseShellExecute = true }); }
            catch (Exception e) { MessageBox.Show(this, e.Message, "AternixMU"); }
        }
        private static void TextAt(Graphics g, string text, float size, FontStyle style, Color color, Rectangle rectangle, string font = "Segoe UI")
        {
            using (Font f = new Font(font, size, style, GraphicsUnit.Pixel))
            using (Brush b = new SolidBrush(color))
            using (StringFormat format = new StringFormat { Trimming = StringTrimming.EllipsisCharacter, FormatFlags = StringFormatFlags.NoWrap, LineAlignment = StringAlignment.Center })
                g.DrawString(text, f, b, rectangle, format);
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            base.OnPaint(e);
            if (frame == null || frameDirty)
            {
                if (frame == null) frame = new Bitmap(W, H, PixelFormat.Format32bppPArgb);
                using (Graphics canvas = Graphics.FromImage(frame)) PaintFrame(canvas);
                frameDirty = false;
            }
            Graphics g = e.Graphics;
            GraphicsState original = g.Save();
            g.ScaleTransform(ClientSize.Width / (float)W, ClientSize.Height / (float)H);
            g.DrawImage(frame, new Rectangle(0, 0, W, H));
            // Rain stays in the scenery, away from the title and interactive controls.
            GraphicsState state = g.Save();
            g.SetClip(new Rectangle(artArea.X, artArea.Y, artArea.Width, 358));
            storm.Draw(g, artArea);
            g.Restore(state);
            g.Restore(original);
        }
        private void PaintFrame(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            g.Clear(BackColor);
            using (var brush = new LinearGradientBrush(new Rectangle(0, 0, W, 108), Color.FromArgb(14, 23, 29), Color.FromArgb(5, 10, 15), 90)) g.FillRectangle(brush, 0, 0, W, 108);
            g.DrawImage(logo, new Rectangle(18, 5, 309, 103));
            TextAt(g, "SEASON 6", 17, FontStyle.Regular, Ink, new Rectangle(339, 35, 130, 36));
            g.DrawImage(scene, artArea);
            using (var shade = new LinearGradientBrush(new Rectangle(2, 434, 731, 190), Color.FromArgb(0, 3, 8, 12), Color.FromArgb(232, 3, 8, 12), 90)) g.FillRectangle(shade, 2, 434, 731, 190);
            TextAt(g, T("NOVÁ ÉRA ZAČÍNÁ", "A NEW ERA BEGINS"), 36, FontStyle.Regular, Ink, new Rectangle(32, 468, 680, 54), "Georgia");
            using (Pen p = new Pen(Cyan)) g.DrawLine(p, 34, 533, 274, 533);
            TextAt(g, "EXP 300×   /   DROP 30 %", 18, FontStyle.Regular, Ink, new Rectangle(34, 541, 550, 30));
            using (Pen p = new Pen(Color.FromArgb(100, 191, 215))) g.DrawRectangle(p, 34, 582, 218, 28);
            TextAt(g, T("TESTOVACÍ PROVOZ", "TEST SERVER"), 13, FontStyle.Bold, Cyan, new Rectangle(48, 580, 200, 32));
            using (var panel = new LinearGradientBrush(new Rectangle(734, 108, 384, 516), Color.FromArgb(13, 23, 30), Color.FromArgb(6, 12, 17), 35)) g.FillRectangle(panel, 734, 108, 384, 516);
            TextAt(g, T("NASTAVENÍ HRY", "GAME SETTINGS"), 25, FontStyle.Regular, Ink, new Rectangle(766, 139, 330, 42), "Georgia");
            using (Pen p = new Pen(Cyan)) g.DrawLine(p, 768, 189, 915, 189);
            TextAt(g, T("Rozlišení:", "Resolution:"), 16, FontStyle.Regular, Ink, new Rectangle(766, 200, 310, 27));
            using (Pen p = new Pen(Color.FromArgb(67, 86, 99))) g.DrawLine(p, 768, 433, 1083, 433);
            Color stateColor = online == true ? Cyan : online == false ? Color.FromArgb(230, 136, 129) : Color.FromArgb(152, 170, 184);
            string serverText = online == true ? "SERVER ONLINE" : online == false ? "SERVER OFFLINE" : T("KONTROLUJI SERVER…", "CHECKING SERVER…");
            if (engine == null) serverText = T("NÁHLED VZHLEDU", "DESIGN PREVIEW");
            using (Brush b = new SolidBrush(stateColor)) g.FillEllipse(b, 770, 468, 12, 12);
            TextAt(g, serverText, 18, FontStyle.Bold, stateColor, new Rectangle(796, 455, 296, 36));
            using (var footer = new LinearGradientBrush(new Rectangle(0, 625, W, 94), Color.FromArgb(13, 22, 29), Color.FromArgb(5, 11, 16), 90)) g.FillRectangle(footer, 1, 625, W - 2, 93);
            string message = string.IsNullOrWhiteSpace(status) ? T("Před hraním zkontroluj aktualizace.", "Check for updates before playing.") : status;
            TextAt(g, message, 14, FontStyle.Regular, Ink, new Rectangle(32, 640, 752, 24));
            using (Brush b = new SolidBrush(Color.FromArgb(31, 47, 57))) g.FillRectangle(b, 34, 677, 746, 5);
            int done = Math.Max(0, Math.Min(100, progress));
            if (done > 0) using (Brush b = new SolidBrush(Cyan)) g.FillRectangle(b, 34, 677, 746f * done / 100f, 5);
            TextAt(g, "ATERNIXMU / ECLIPSE", 10, FontStyle.Regular, Color.FromArgb(113, 136, 151), new Rectangle(34, 688, 700, 20));
            using (Pen p = new Pen(Color.FromArgb(115, 140, 154))) { g.DrawRectangle(p, 1, 1, W - 3, H - 3); g.DrawLine(p, 2, 107, W - 3, 107); g.DrawLine(p, 733, 108, 733, 624); g.DrawLine(p, 2, 624, W - 3, 624); }
        }
        protected override void Dispose(bool disposing)
        {
            if (disposing) { closed = true; timer.Stop(); timer.Dispose(); tip.Dispose(); if (engine != null) engine.Dispose(); scene.Dispose(); logo.Dispose(); if (frame != null) frame.Dispose(); }
            base.Dispose(disposing);
        }
    }
}
