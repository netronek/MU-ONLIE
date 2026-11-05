<%@ Page Language="C#" ResponseEncoding="utf-8" ValidateRequest="false" EnableSessionState="false" %>
<%@ Import Namespace="AternixWeb" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<script runat="server">
protected string FormToken = "";
protected string Message = "";
protected void Page_Load(object sender, EventArgs e)
{
    WebAuth.PrepareResponse(Context);
    if (!Request.IsSecureConnection)
    {
        if (Request.HttpMethod == "POST") { Response.StatusCode = 400; Message = "Přihlášení odešli pouze přes HTTPS."; return; }
        Response.Redirect("https://aternixmu.eu/login.aspx", true); return;
    }
    FormToken = WebAuth.GetCsrf(Context);
    if (Request.HttpMethod == "GET")
    {
        if (WebAuth.GetSession(Context) != null) Response.Redirect("account.aspx", true);
        return;
    }
    if (Request.HttpMethod != "POST") { Response.StatusCode = 405; return; }
    if (Request.ContentLength > 8192) { Response.StatusCode = 413; Message = "Požadavek je příliš velký."; return; }
    if (!WebAuth.CheckCsrf(Context, Request.Form["csrf"]))
    { Response.StatusCode = 400; Message = "Platnost formuláře vypršela. Obnov stránku a zkus to znovu."; return; }
    if (!WebAuth.AllowLoginAttempt(Request.UserHostAddress ?? "unknown"))
    { Response.StatusCode = 429; Response.Headers["Retry-After"] = "900"; Message = "Příliš mnoho pokusů. Zkus to znovu za 15 minut."; return; }
    string login = Request.Form["login"] ?? "";
    string password = Request.Form["password"] ?? "";
    if (!Regex.IsMatch(login, @"\A[!-~]{1,10}\z", RegexOptions.CultureInvariant) ||
        !Regex.IsMatch(password, @"\A[!-~]{1,10}\z", RegexOptions.CultureInvariant))
    { Message = "Přihlášení se nezdařilo. Zkontroluj login a heslo."; return; }
    PlayerSession authenticated = null;
    try
    {
        authenticated = WebAuth.Authenticate(login, password);
        if (authenticated == null) { Message = "Přihlášení se nezdařilo. Zkontroluj login a heslo."; return; }
        WebAuth.SignIn(Context, authenticated);
    }
    catch (Exception error)
    {
        Response.StatusCode = 503; Message = "Přihlášení je dočasně nedostupné. Zkus to později.";
        System.Diagnostics.Trace.TraceError("Aternix login error type: " + error.GetType().Name); return;
    }
    Response.Redirect("account.aspx", true);
}
</script>
<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><meta name="theme-color" content="#0b1015"><title>Přihlášení · AternixMU</title><link rel="icon" href="assets/favicon.ico"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="register.css"><link rel="stylesheet" href="account.css"></head><body>
<a class="skip" href="#obsah">Přejít na obsah</a><header class="header"><a class="brand" href="index.html" aria-label="AternixMU — úvod"><span class="brand-symbol" aria-hidden="true">A</span><span>ATERNIX<span class="gold">MU</span><small>MU ONLINE · SEASON 6</small></span></a><nav aria-label="Hlavní navigace"><a href="index.html">Úvod</a><a href="ranking.aspx">Žebříček</a><a href="register.aspx">Registrace</a><a href="login.aspx" aria-current="page">Přihlášení</a></nav><a class="nav-button" href="index.html#stazeni">Získat launcher →</a></header>
<main id="obsah" class="register-main login-main"><section class="register-intro"><p class="eyebrow">ATERNIXMU / HRÁČSKÝ ÚČET</p><h1>Vítej zpátky,<br><em>hrdino.</em></h1><p>Přihlas se herním loginem a heslem a prohlédni si své postavy na jednom místě.</p><div class="register-info"><span class="pill">SEASON 6</span><p>EXP 300× · DROP 30 %</p></div><p class="register-help">Přihlášení na web nespouští hru a nemění vlastnosti postav.</p><a class="register-back" href="index.html">← Zpět na hlavní stránku</a></section>
<section class="register-panel" aria-labelledby="login-title"><h2 id="login-title">Přihlášení hráče</h2><p class="form-subtitle">Použij stejný účet jako ve hře.</p>
<% if (!String.IsNullOrEmpty(Message)) { %><div class="register-error" role="alert"><%= WebAuth.Safe(Message) %></div><% } %>
<form method="post" action="login.aspx"><input type="hidden" name="csrf" value="<%= WebAuth.Safe(FormToken) %>"><label for="login">Login</label><input id="login" name="login" type="text" required maxlength="10" autocomplete="username" autocapitalize="none" spellcheck="false"><label for="password">Heslo</label><input id="password" name="password" type="password" required maxlength="10" autocomplete="current-password"><button class="button primary full" type="submit">Přihlásit se →</button></form><p class="account-form-note">Ještě nemáš účet? <a href="register.aspx">Vytvořit účet →</a></p></section></main>
<footer class="footer"><a class="footer-brand" href="index.html">ATERNIXMU<span>SEASON 6</span></a><p>Komunitní projekt MU Online · Testovací provoz</p><a href="https://discord.gg/tMENCSJJZE" target="_blank" rel="noopener noreferrer">Discord →</a></footer></body></html>
