<%@ Page Language="C#" ResponseEncoding="utf-8" ValidateRequest="false" EnableSessionState="false" %>
<%@ Import Namespace="AternixWeb" %>
<%@ Import Namespace="System.Text.RegularExpressions" %>
<script runat="server">
protected PlayerSession Player;
protected string FormToken = "";
protected string Message = "";
protected bool Succeeded;
protected bool MustLogin;
protected void Page_Load(object sender, EventArgs e)
{
    WebAuth.PrepareResponse(Context);
    if (!Request.IsSecureConnection)
    {
        if (Request.HttpMethod == "POST") { Response.StatusCode = 400; MustLogin = true; Message = "Změnu hesla odešli pouze přes HTTPS."; return; }
        Response.Redirect("https://aternixmu.eu/change-password.aspx", true); return;
    }
    Player = WebAuth.GetSession(Context);
    if (Player == null) { Response.Redirect("login.aspx", true); return; }
    FormToken = WebAuth.GetCsrf(Context);
    if (Request.HttpMethod == "GET") return;
    if (Request.HttpMethod != "POST") { Response.StatusCode = 405; MustLogin = true; return; }
    if (Request.ContentLength > 8192) { Response.StatusCode = 413; Message = "Požadavek je příliš velký."; return; }
    if (!WebAuth.CheckCsrf(Context, Request.Form["csrf"]))
    { Response.StatusCode = 400; Message = "Platnost formuláře vypršela. Obnov stránku a zkus to znovu."; return; }
    if (!WebAuth.AllowPasswordAttempt(Request.UserHostAddress ?? "unknown", Player))
    { Response.StatusCode = 429; Response.Headers["Retry-After"] = "900"; Message = "Příliš mnoho pokusů. Zkus to znovu za 15 minut."; return; }
    string oldPassword = Request.Form["oldPassword"] ?? "";
    string newPassword = Request.Form["newPassword"] ?? "";
    string repeated = Request.Form["newPasswordRepeat"] ?? "";
    if (!Regex.IsMatch(oldPassword, @"\A[!-~]{1,10}\z", RegexOptions.CultureInvariant))
    { Message = "Zkontroluj současné heslo."; return; }
    if (!Regex.IsMatch(newPassword, @"\A[!-~]{8,10}\z", RegexOptions.CultureInvariant))
    { Message = "Nové heslo musí mít 8–10 znaků bez mezer a diakritiky."; return; }
    if (!String.Equals(newPassword, repeated, StringComparison.Ordinal))
    { Message = "Nová hesla se neshodují."; return; }
    if (String.Equals(oldPassword, newPassword, StringComparison.Ordinal))
    { Message = "Nové heslo musí být jiné než současné."; return; }
    int result;
    try { result = WebAuth.ChangePassword(Context, Player, oldPassword, newPassword); }
    catch (Exception error)
    {
        Response.StatusCode = 503; MustLogin = true;
        Message = "Výsledek změny nelze potvrdit. Přihlas se znovu; pokud nové heslo nefunguje, zkus původní.";
        System.Diagnostics.Trace.TraceError("Aternix password change error type: " + error.GetType().Name); return;
    }
    if (result == 0) { Succeeded = true; return; }
    if (result == 3) { Response.Redirect("login.aspx", true); return; }
    if (result == 1) Message = "Heslo se nezměnilo. Zkontroluj současné heslo nebo stav účtu.";
    else if (result == 2) Message = "Zkontroluj zadaná hesla. Nové musí mít 8–10 znaků a být jiné než současné.";
    else { Response.StatusCode = 503; Message = "Změna hesla je dočasně nedostupná."; }
}
</script>
<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><meta name="theme-color" content="#0b1015"><title>Změna hesla · AternixMU</title><link rel="icon" href="assets/favicon.ico"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="register.css"><link rel="stylesheet" href="account.css"></head><body>
<a class="skip" href="#obsah">Přejít na obsah</a><header class="header"><a class="brand" href="index.html" aria-label="AternixMU — úvod"><span class="brand-symbol" aria-hidden="true">A</span><span>ATERNIX<span class="gold">MU</span><small>MU ONLINE · SEASON 6</small></span></a><nav aria-label="Hlavní navigace"><a href="index.html">Úvod</a><a href="ranking.aspx">Žebříček</a><a href="account.aspx" aria-current="page">Můj účet</a><a href="index.html#komunita">Komunita</a></nav><a class="nav-button" href="index.html#stazeni">Získat launcher →</a></header>
<main id="obsah" class="register-main login-main"><section class="register-intro"><p class="eyebrow">ATERNIXMU / ZABEZPEČENÍ ÚČTU</p><h1>Nové heslo.<br><em>Stejný příběh.</em></h1><p>Pro změnu potřebuješ znát současné heslo. Nové heslo se použije pro přihlášení na web i do hry.</p><div class="register-info"><span class="pill">HRÁČSKÝ ÚČET</span><p>Změnu můžeš provést i během hraní.</p></div><p class="register-help">Po změně se odhlásí webová přihlášení účtu. Běžící hra zůstane připojená; nové heslo použij při příštím přihlášení.</p><a class="register-back" href="account.aspx">← Zpět do účtu</a></section>
<section class="register-panel" aria-labelledby="password-title">
<% if (Succeeded) { %><div class="register-success" role="status"><span aria-hidden="true">✓</span><h2>Heslo bylo změněno.</h2><p>Webová přihlášení účtu byla ukončena. Přihlas se znovu novým heslem.</p><a class="button primary full" href="login.aspx">Přihlásit se →</a></div>
<% } else if (MustLogin) { %><h2 id="password-title">Přihlas se znovu.</h2><div class="register-error" role="alert"><%= WebAuth.Safe(Message) %></div><a class="button primary full" href="login.aspx">Přejít k přihlášení →</a>
<% } else { %><h2 id="password-title">Změna hesla</h2><% if (Player != null) { %><p class="form-subtitle">Účet: <strong><%= WebAuth.Safe(Player.Login) %></strong></p><% } %>
<% if (!String.IsNullOrEmpty(Message)) { %><div class="register-error" role="alert"><%= WebAuth.Safe(Message) %></div><% } %>
<form method="post" action="change-password.aspx"><input type="hidden" name="csrf" value="<%= WebAuth.Safe(FormToken) %>"><label for="old-password">Současné heslo</label><input id="old-password" name="oldPassword" type="password" required maxlength="10" autocomplete="current-password"><label for="new-password">Nové heslo</label><input id="new-password" name="newPassword" type="password" required minlength="8" maxlength="10" autocomplete="new-password" aria-describedby="password-help"><small id="password-help">8–10 znaků bez mezer a diakritiky. Nepoužívej heslo z jiné služby.</small><label for="new-password-repeat">Nové heslo znovu</label><input id="new-password-repeat" name="newPasswordRepeat" type="password" required minlength="8" maxlength="10" autocomplete="new-password"><button class="button primary full" type="submit">Změnit heslo →</button></form><% } %>
</section></main><footer class="footer"><a class="footer-brand" href="index.html">ATERNIXMU<span>SEASON 6</span></a><p>Komunitní projekt MU Online · Testovací provoz</p><a href="https://discord.gg/tMENCSJJZE" target="_blank" rel="noopener noreferrer">Discord →</a></footer></body></html>
