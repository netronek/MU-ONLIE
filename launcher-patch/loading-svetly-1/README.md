# Patch launcheru: loading-svetly-1

Balíček pro aktualizační server, nikoli pro web ani přímou instalaci klienta. Obsahuje šest již ve hře ověřených OZJ pozadí, návrh sloučeného manifestu a aktualizovaný MIME typ IIS.

## Obsah a rozsah

- `files/Data/Custom/Interface/Loading/Back01.ozj` až `Back06.ozj` — stejné soubory jako v lokálně otestovaném balíčku světlého pozadí.
- `manifest.NEW.json` — verze `loading-svetly-1`, celkem osm položek. Zachovává beze změny testovací soubor a `Data/Local/Eng/movereq_eng.bmd`; přidává pouze šest obrázků.
- `web.config` — zachovává MIME `.bmd`, přidává `.ozj` jako `application/octet-stream`. Předchozí definici `.ozj` případně odstraní v rámci tohoto webu, aby nevznikla duplicita.
- Žádný nový launcher, EXE, DLL, Lua, přihlašování ani změna načítací lišty.

`base-manifest.json` je ve zdrojích pro porovnání; není určen k instalaci. Původní dva payloady nejsou v ZIPu a musí zůstat v `C:\AternixUpdates\files`.

## Příprava na serveru

1. ZIP rozbalit do `C:\Tools\AternixLoadingPatch01`. Zatím nenahrazovat aktivní manifest.
2. Zálohovat současné `C:\AternixUpdates\manifest.json` a `web.config` mimo veřejnou složku, např. do `C:\Tools\AternixPatchBackups\loading-before`.
3. Složku `files` z balíčku sloučit s `C:\AternixUpdates\files`; původní soubory testu a menu map nesmazat.
4. Zkopírovat `web.config` a `manifest.NEW.json` do `C:\AternixUpdates`. Aktivní `manifest.json` zatím ponechat.
5. Ověřit dostupnost nových `.ozj` souborů přes `https://patch.aternixmu.eu/files/Data/Custom/Interface/Loading/Back01.ozj` až `Back06.ozj`.
6. Před zveřejněním ověřit velikost a SHA-256 všech osmi payloadů podle nového manifestu; ověřit, že všechny položky aktuálního manifestu jsou v novém zachovány beze změny. Pokud se od přípravy objevil další patch, tento manifest nezveřejňovat bez nového sloučení.
7. Nový manifest zveřejnit až jako poslední krok atomickým `System.IO.File.Replace`. Jako třetí argument použít skutečnou záložní cestu, nikoli `$null`.

## Test po zveřejnění

- Veřejný manifest musí vracet `version: loading-svetly-1`, `ready: true`, osm položek.
- Na klientu bez nového pozadí zavřít hru a v launcheru spustit AKTUALIZOVAT. Klient s předchozí aktualizací map má získat šest nových souborů.
- Opakované AKTUALIZOVAT má změnit nula souborů.
- Spustit hru a ověřit nové pozadí a původní funkční načítací lištu.
- Již lokálně upravený klient může stáhnout nula souborů hned při prvním pokusu; rozhodující jsou shodné kontrolní součty.

## Návrat

Obnovení předchozího manifestu zastaví nabídku nových textur dalším klientům, nevrací však obrázky již aktualizovaným klientům. Pro skutečný návrat klientů je nutný další manifest obsahující původní textury. Při problému s IIS obnovit zálohovaný `web.config`.

## Ověřeno před předáním

JSON schéma a osm unikátních bezpečných relativních cest; původní dva záznamy shodné s dodaným živým manifestem; SHA-256 a velikost všech šesti nových payloadů; shoda s herně otestovaným balíčkem; parsování XML a zachování MIME `.bmd`; konzistence finálního ZIPu. Živý IIS a distribuce přes launcher vyžadují závěrečný test na serveru a klientu.
