# AternixMU Eclipse launcher

Nové logo, rytíř a hrad, stříbrné rozhraní s modrými detaily. Déšť běží přibližně při 30 FPS; po prvním záblesku přichází další zhruba jednou za 9–18 sekund. Přepínač EFEKTY nebo F8 vypne déšť i blesky. Minimalizace zastaví animační časovač. Pozadí se ukládá do paměti, znovu se nepřipravuje každý snímek.

## Instalace testovacího balíčku

1. Zavřete launcher a hru.
2. Zálohujte původní `MuLauncher.exe` a složku `assets` mimo instalaci hry.
3. Rozbalte obsah `AternixMU_Launcher_Eclipse_01.zip` do složky obsahující `main.exe` a `main.premium`. Potvrďte nahrazení souborů launcheru.
4. Spusťte `MuLauncher.exe`. ZIP není celý herní klient.
5. Ověřte ONLINE, AKTUALIZOVAT a SPUSTIT HRU. Otestujte zvolené rozlišení, zvuk a hru v okně.

Balíček nepřidává ani nenahrazuje `server.json`, `display.json`, `audio.json` ani `language.txt`. Zachová stávající nastavení. `update-source.txt` nastavuje stávající server `https://patch.aternixmu.eu`. Herní soubory v `Data` se vzhledem launcheru nemění.

## Implementace

`MuLauncher.exe` je nová prezentační vrstva Windows Forms pro .NET Framework 4.8, x86. Obsahuje vlastní vykreslování, ovládání a animaci. Původní již otestovaný launcher je nezměněný soubor `Aternix.Engine.dll` (přejmenovaný předchozí Aternix `MuLauncher.exe`). Zachovává protokol kontroly serveru, stahování manifestu a ověření SHA-256, obnovu při chybě, nastavení hry a spouštěcí argumenty. Původní animace modulu se vypíná.

Nové rozhraní čte skutečný stav modulu. ONLINE ani dokončená aktualizace se nepředstírají. Ovládání volá původní obsluhy tlačítek; nastavení rozlišení a zvuku se propisuje do původních ovládacích prvků. Modul je pevně svázaný s touto verzí; při jeho výměně musí být znovu ověřeny reflexní vazby, včetně názvů obsluh generovaných kompilátorem. Nová sestava má odlišnou interní identitu `AternixMU.Launcher`, i když distribuovaný soubor se jmenuje `MuLauncher.exe`.

`--preview` zobrazí vzhled bez modulu, připojování k serveru a spouštění hry. Náhled je výslovně označený.

## Ověření

- Sestavení proti referenčním knihovnám .NET Framework 4.8 bez varování.
- Původní modul shodný po bajtech s předchozím otestovaným Aternix launcherem.
- Na Mono + virtuální obrazovce: načtení skutečného modulu, devět rozlišení, čtení zvuku a jazyka, změna jazyka, inicializace a ukončení.
- Testy grafiky ověřily rozdíl mezi snímky deště, zastavení efektů, vytvoření blesku, CZ/EN a umístění ovládání při velikostech 1120×720 a 1008×648. Snímky byly vizuálně zkontrolovány.
- Souborová integrace původního updateru je v `EclipseTests.cs` připravená pro Windows; na Linuxu se vynechává, protože modul používá cesty Windows. Spuštění skutečné hry a živé připojení vyžaduje závěrečný test ve Windows s klientem.

Skript `build.ps1` sestaví prezentační EXE ve Windows; použijte s modulem a assets z distribučního ZIPu. `EclipseTests.cs` je samostatný testovací vstupní bod, není součást distribuovaného launcheru. Testovací fixture používejte v pracovní kopii, nikoli v živém klientu.
