<%@ Page Language="C#" ResponseEncoding="utf-8" EnableSessionState="false" %>
<%@ Import Namespace="AternixWeb" %>
<%@ Import Namespace="System.Data" %>
<script runat="server">
protected PlayerSession Player;
protected DataTable Characters;
protected string FormToken = "";
protected bool Unavailable;
protected void Page_Load(object sender, EventArgs e)
{
    WebAuth.PrepareResponse(Context);
    if (!Request.IsSecureConnection) { Response.Redirect("https://aternixmu.eu/account.aspx", true); return; }
    if (Request.HttpMethod != "GET") { Response.StatusCode = 405; Unavailable = true; return; }
    Player = WebAuth.GetSession(Context);
    if (Player == null) { Response.Redirect("login.aspx", true); return; }
    FormToken = WebAuth.GetCsrf(Context);
    try { Characters = WebAuth.LoadCharacters(Player); }
    catch (Exception error)
    {
        Unavailable = true; Response.StatusCode = 503;
        System.Diagnostics.Trace.TraceError("Aternix account error type: " + error.GetType().Name); return;
    }
    if (Characters == null)
    {
        WebAuth.SignOut(Context); Response.Redirect("login.aspx", true); return;
    }
}
</script>
<!doctype html><html lang="cs"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex, nofollow"><meta name="theme-color" content="#0b1015"><title>Můj účet · AternixMU</title><link rel="icon" href="assets/favicon.ico"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="ranking.css"><link rel="stylesheet" href="account.css"></head><body>
<a class="skip" href="#obsah">Přejít na obsah</a><header class="header"><a class="brand" href="index.html" aria-label="AternixMU — úvod"><span class="brand-symbol" aria-hidden="true">A</span><span>ATERNIX<span class="gold">MU</span><small>MU ONLINE · SEASON 6</small></span></a><nav aria-label="Hlavní navigace"><a href="index.html">Úvod</a><a href="ranking.aspx">Žebříček</a><a href="account.aspx" aria-current="page">Můj účet</a><a href="index.html#komunita">Komunita</a></nav><a class="nav-button" href="index.html#stazeni">Získat launcher →</a></header>
<main id="obsah" class="ranking-main"><div class="account-heading"><div><p class="eyebrow">ATERNIXMU / HRÁČSKÝ ÚČET</p><h1>Tvoje postavy.<br><em>Tvůj příběh.</em></h1><% if (Player != null) { %><p>Přihlášený účet: <strong><%= WebAuth.Safe(Player.Login) %></strong></p><% } %></div>
<% if (Player != null) { %><form method="post" action="logout.aspx"><input type="hidden" name="csrf" value="<%= WebAuth.Safe(FormToken) %>"><button class="button secondary logout-button" type="submit">Odhlásit se →</button></form><% } %></div>
<% if (Unavailable) { %><section class="ranking-message" role="status"><h2>Účet je dočasně nedostupný.</h2><p>Zkus stránku načíst znovu za chvíli.</p><a class="button secondary" href="account.aspx">Načíst znovu →</a></section>
<% } else if (Characters != null && Characters.Rows.Count == 0) { %><section class="ranking-message"><h2>Tvůj příběh teprve začíná.</h2><p>Na tomto účtu zatím nemáš žádnou postavu. Vytvoř si ji přímo ve hře.</p><a class="button secondary" href="index.html#stazeni">Ke stažení →</a></section>
<% } else if (Characters != null) { %><div class="account-summary"><span class="pill">VLASTNÍ POSTAVY</span><span>Počet postav: <strong><%= Characters.Rows.Count %></strong></span></div><div class="ranking-scroll" role="region" aria-label="Vlastní postavy, tabulku lze posouvat vodorovně" tabindex="0"><table class="ranking-table"><caption>Postavy přihlášeného hráče</caption><thead><tr><th scope="col">Postava</th><th scope="col">Třída</th><th scope="col" class="numeric">Level</th><th scope="col" class="numeric">Resety</th><th scope="col" class="numeric">Master resety</th></tr></thead><tbody>
<% foreach (DataRow row in Characters.Rows) { %><tr><th scope="row"><%= WebAuth.Safe(row["CharacterName"]) %></th><td class="class-name"><%= WebAuth.Safe(WebAuth.CharacterClass(row["ClassCode"])) %></td><td class="numeric"><%= WebAuth.Number(row["CharacterLevel"]) %></td><td class="numeric"><%= WebAuth.Number(row["Resets"]) %></td><td class="numeric masters"><%= WebAuth.Number(row["MasterResets"]) %></td></tr><% } %>
</tbody></table></div><% } %><div class="account-security"><div><h2>Zabezpečení účtu</h2><p>Spravuj přístup ke svému hernímu účtu.</p></div><a class="button secondary" href="change-password.aspx">Změnit heslo →</a></div><p class="ranking-note">Údaje zobrazuješ pouze pro svůj účet. Nejnovější stav po hraní načti obnovením stránky.</p><a class="ranking-back" href="index.html">← Zpět na hlavní stránku</a></main>
<footer class="footer"><a class="footer-brand" href="index.html">ATERNIXMU<span>SEASON 6</span></a><p>Komunitní projekt MU Online · Testovací provoz</p><a href="https://discord.gg/tMENCSJJZE" target="_blank" rel="noopener noreferrer">Discord →</a></footer></body></html>
