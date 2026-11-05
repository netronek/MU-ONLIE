<%@ Page Language="C#" ResponseEncoding="utf-8" ValidateRequest="false" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Data.SqlClient" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<%@ Import Namespace="System.Security.Cryptography" %>
<script runat="server">
protected string FormToken = "";
protected string Message = "";
protected bool Succeeded;
private const string CookieName = "__Host-AternixRegistration";
private static readonly object RateLock = new object();
private sealed class AttemptCounter { public int Count; }

private static bool Matches(string text, string pattern)
{
    return Regex.IsMatch(text ?? "", pattern, RegexOptions.CultureInvariant);
}
private static string NewToken()
{
    byte[] bytes = new byte[32];
    using (RandomNumberGenerator random = RandomNumberGenerator.Create()) random.GetBytes(bytes);
    return Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
}
private static string GenerateSecurityCode()
{
    char[] digits = new char[7];
    byte[] buffer = new byte[32];
    int filled = 0;
    using (RandomNumberGenerator random = RandomNumberGenerator.Create())
    {
        while (filled < digits.Length)
        {
            random.GetBytes(buffer);
            for (int i = 0; i < buffer.Length && filled < digits.Length; i++)
            {
                // Rejection sampling keeps all ten digits equally likely.
                if (buffer[i] < 250) digits[filled++] = (char)('0' + buffer[i] % 10);
            }
        }
    }
    return new string(digits);
}
private void SetToken(string token)
{
    HttpCookie cookie = new HttpCookie(CookieName, token);
    cookie.HttpOnly = true;
    cookie.Secure = true;
    cookie.Path = "/";
    cookie.SameSite = System.Web.SameSiteMode.Strict;
    Response.Cookies.Set(cookie);
}
private static bool EqualToken(string left, string right)
{
    if (!Matches(left, @"\A[A-Za-z0-9_-]{43}\z") || !Matches(right, @"\A[A-Za-z0-9_-]{43}\z")) return false;
    int difference = 0;
    for (int i = 0; i < 43; i++) difference |= left[i] ^ right[i];
    return difference == 0;
}
private static bool AllowAttempt(string address)
{
    // Basic per-application limit: 100 requests total / 15 min, 10 per client IP.
    // X-Forwarded-For is intentionally not trusted on this direct IIS installation.
    lock (RateLock)
    {
        string[] keys = { "Aternix.Register.Global.v1", "Aternix.Register.IP.v1." + address };
        int[] maximum = { 100, 10 };
        for (int i = 0; i < keys.Length; i++)
        {
            AttemptCounter counter = System.Web.HttpRuntime.Cache[keys[i]] as AttemptCounter;
            if (counter == null)
            {
                counter = new AttemptCounter();
                System.Web.HttpRuntime.Cache.Insert(keys[i], counter, null,
                    DateTime.UtcNow.AddMinutes(15), System.Web.Caching.Cache.NoSlidingExpiration,
                    System.Web.Caching.CacheItemPriority.NotRemovable, null);
            }
            if (counter.Count >= maximum[i]) return false;
            counter.Count++;
        }
        return true;
    }
}
protected string Safe(string value) { return Server.HtmlEncode(value ?? ""); }
protected void Page_Load(object sender, EventArgs e)
{
    Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
    Response.Cache.SetNoStore();
    Response.TrySkipIisCustomErrors = true;
    Response.Headers["X-Frame-Options"] = "DENY";
    Response.Headers["X-Content-Type-Options"] = "nosniff";
    Response.Headers["Referrer-Policy"] = "same-origin";
    if (!Request.IsSecureConnection)
    {
        if (Request.HttpMethod == "POST") { Response.StatusCode = 400; Message = "Registraci odešli pouze přes HTTPS."; return; }
        Response.Redirect("https://aternixmu.eu/register.aspx", true);
        return;
    }
    string cookieToken = Request.Cookies[CookieName] == null ? "" : Request.Cookies[CookieName].Value;
    FormToken = Matches(cookieToken, @"\A[A-Za-z0-9_-]{43}\z") ? cookieToken : NewToken();
    if (FormToken != cookieToken) SetToken(FormToken);
    if (Request.HttpMethod == "GET") return;
    if (Request.HttpMethod != "POST") { Response.StatusCode = 405; return; }
    if (Request.ContentLength > 8192) { Response.StatusCode = 413; Message = "Požadavek je příliš velký."; return; }
    if (!EqualToken(cookieToken, Request.Form["csrf"]))
    { Response.StatusCode = 400; Message = "Platnost formuláře vypršela. Obnov stránku a zkus to znovu."; return; }
    if (!String.IsNullOrEmpty(Request.Form["website"]))
    { Response.StatusCode = 400; Message = "Registraci se nepodařilo dokončit."; return; }
    if (!AllowAttempt(Request.UserHostAddress ?? "unknown"))
    { Response.StatusCode = 429; Message = "Příliš mnoho pokusů. Zkus to znovu za 15 minut."; return; }

    string login = Request.Form["login"] ?? "";
    string password = Request.Form["password"] ?? "";
    string repeated = Request.Form["passwordRepeat"] ?? "";
    string email = (Request.Form["email"] ?? "").Trim();
    if (!Matches(login, @"\A[A-Za-z0-9]{4,10}\z"))
    { Message = "Login musí mít 4–10 anglických písmen nebo číslic."; return; }
    if (!Matches(password, @"\A[!-~]{8,10}\z"))
    { Message = "Heslo musí mít 8–10 znaků bez mezer a diakritiky."; return; }
    if (!String.Equals(password, repeated, StringComparison.Ordinal))
    { Message = "Zadaná hesla se neshodují."; return; }
    if (email.Length > 50 || !Matches(email, @"\A[!-~]+@[!-~]+\.[!-~]+\z"))
    { Message = "Zadej platný e-mail, nejvýše 50 znaků bez mezer a diakritiky."; return; }
    try
    {
        System.Net.Mail.MailAddress parsed = new System.Net.Mail.MailAddress(email);
        if (!String.Equals(parsed.Address, email, StringComparison.OrdinalIgnoreCase))
        { Message = "Zadej pouze e-mailovou adresu, bez jména."; return; }
    }
    catch (FormatException) { Message = "Zadej platný e-mail."; return; }
    try
    {
        string code = GenerateSecurityCode();
        using (SqlConnection connection = new SqlConnection(
            "Data Source=lpc:localhost;Initial Catalog=MuOnlineS6;Integrated Security=True;Connect Timeout=5;Application Name=AternixWebRegistration;"))
        using (SqlCommand command = new SqlCommand("dbo.WebRegisterAccount", connection))
        {
            command.CommandType = CommandType.StoredProcedure;
            command.CommandTimeout = 5;
            command.Parameters.Add("@Login", SqlDbType.NVarChar, 64).Value = login;
            command.Parameters.Add("@Password", SqlDbType.NVarChar, 128).Value = password;
            command.Parameters.Add("@Email", SqlDbType.NVarChar, 254).Value = email;
            command.Parameters.Add("@SecurityCode", SqlDbType.NVarChar, 64).Value = code;
            SqlParameter result = command.Parameters.Add("@Result", SqlDbType.Int);
            result.Direction = ParameterDirection.ReturnValue;
            connection.Open();
            command.ExecuteNonQuery();
            int status = Convert.ToInt32(result.Value);
            if (status == 0)
            {
                Succeeded = true;
                FormToken = NewToken(); SetToken(FormToken);
            }
            else if (status == 1) Message = "Tento login není dostupný. Vyber jiný.";
            else if (status == 2) Message = "Zkontroluj vyplněné údaje.";
            else { Response.StatusCode = 503; Message = "Registrace je dočasně nedostupná. Zkus to později."; }
        }
    }
    catch (SqlException error)
    {
        Response.StatusCode = 503;
        Message = "Registraci se nepodařilo potvrdit. Pokud už účet vznikl, půjde se s ním přihlásit. Jinak to zkus později.";
        System.Diagnostics.Trace.TraceError("Aternix registration SQL error number: " + error.Number);
    }
    catch (Exception error)
    {
        Response.StatusCode = 503;
        Message = "Registrace je dočasně nedostupná. Zkus to později.";
        System.Diagnostics.Trace.TraceError("Aternix registration error type: " + error.GetType().Name);
    }
}
</script>
<!doctype html>
<html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><meta name="theme-color" content="#0b1015"><title>Registrace · AternixMU</title><link rel="icon" href="assets/favicon.ico"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="register.css"></head>
<body><a class="skip" href="#obsah">Přejít na obsah</a>
<header class="header"><a class="brand" href="index.html" aria-label="AternixMU — úvod"><span class="brand-symbol" aria-hidden="true">A</span><span>ATERNIX<span class="gold">MU</span><small>MU ONLINE · SEASON 6</small></span></a><nav aria-label="Hlavní navigace"><a href="index.html">Úvod</a><a href="ranking.aspx">Žebříček</a><a href="register.aspx" aria-current="page">Registrace</a><a href="login.aspx">Přihlášení</a><a href="index.html#komunita">Komunita</a></nav><a class="nav-button" href="index.html#stazeni">Získat launcher →</a></header>
<main id="obsah" class="register-main"><section class="register-intro"><p class="eyebrow">ATERNIXMU / TVŮJ NOVÝ ZAČÁTEK</p><h1>Vytvoř si účet.<br><em>Napiš svůj příběh.</em></h1><p>Jeden herní účet, svět plný možností. Připrav se na cestu světem AternixMU Season 6.</p><div class="register-info"><span class="pill">TESTOVACÍ PROVOZ</span><p>EXP 300× · DROP 30 %</p></div><p class="register-help">Ulož si login a heslo. Heslo použij jiné než u e-mailu nebo jiných služeb.</p><a class="register-back" href="index.html">← Zpět na hlavní stránku</a></section>
<section class="register-panel" aria-labelledby="form-title">
<% if (Succeeded) { %>
<div class="register-success" role="status"><span aria-hidden="true">✓</span><h2>Účet je vytvořený.</h2><p>Teď se můžeš zkusit přihlásit do hry zadaným loginem a heslem.</p><a class="button primary full" href="login.aspx">Přihlásit se na web →</a></div>
<% } else { %>
<h2 id="form-title">Registrace hráče</h2><p class="form-subtitle">Vytvoření nového herního účtu</p>
<% if (!String.IsNullOrEmpty(Message)) { %><div class="register-error" role="alert"><%= Safe(Message) %></div><% } %>
<form method="post" action="register.aspx" autocomplete="on">
<input type="hidden" name="csrf" value="<%= Safe(FormToken) %>">
<div class="honey" aria-hidden="true"><label for="website">Web</label><input id="website" name="website" type="text" tabindex="-1" autocomplete="off"></div>
<label for="login">Login</label><input id="login" name="login" type="text" required minlength="4" maxlength="10" pattern="[A-Za-z0-9]{4,10}" autocomplete="username" autocapitalize="none" spellcheck="false" aria-describedby="login-help"><small id="login-help">4–10 anglických písmen nebo číslic. Ve hře se přihlašuješ loginem.</small>
<label for="email">E-mail</label><input id="email" name="email" type="email" required maxlength="50" autocomplete="email" aria-describedby="email-help"><small id="email-help">Kontaktní adresa, nejvýše 50 znaků. Potvrzovací e-mail se zatím neodesílá.</small>
<div class="form-columns"><div><label for="password">Heslo</label><input id="password" name="password" type="password" required minlength="8" maxlength="10" autocomplete="new-password" aria-describedby="password-help"></div><div><label for="password-repeat">Heslo znovu</label><input id="password-repeat" name="passwordRepeat" type="password" required minlength="8" maxlength="10" autocomplete="new-password"></div></div><small id="password-help">8–10 znaků bez mezer a diakritiky. Délku omezuje herní klient.</small>
<button class="button primary full" type="submit">Vytvořit herní účet <span aria-hidden="true">→</span></button>
</form>
<% } %>
</section></main><footer class="footer"><a class="footer-brand" href="index.html">ATERNIXMU<span>SEASON 6</span></a><p>Komunitní projekt MU Online · Testovací provoz</p><a href="https://discord.gg/tMENCSJJZE" target="_blank" rel="noopener noreferrer">Discord →</a></footer></body></html>
