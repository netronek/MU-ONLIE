# AternixMU: světlé načítací pozadí

Schválený první světlý motiv: rytíř s původními zlatými znaky na plášti a vlajkách, hrad za úsvitu, hlavní logo AternixMU nahoře. Obrázek neobsahuje nakreslenou načítací lištu ani procenta; ty vykresluje stávající klient.

## Co balíček mění

Pouze `Data/Custom/Interface/Loading/Back01.ozj` až `Back06.ozj`. Dodaný klient obsahuje tři dvojice různých pozadí: lodě, plovoucí hrad a červeného bojovníka. Všechny tři dvojice jsou sjednoceny na nový motiv, aby případné střídání nevracelo staré obrázky.

Samostatné soubory `SelectBack01.ozj` až `SelectBack06.ozj` nejsou v balíčku. Stejně tak nejsou zahrnuty `Bar.ozj`, `BarFrame.ozt`, `Loading.ozt`, `Porcento.ozt`, Lua, EXE ani DLL. Instalace je nesmí odstranit.

## Instalace a návrat

1. Zavřít hru i launcher.
2. Zálohovat celou původní složku `Data/Custom/Interface/Loading` mimo složku klienta.
3. Rozbalit ZIP a sloučit jeho složku `Data` s existující složkou `Data` vedle `main.exe`. Nahradit pouze šest dodaných souborů; ostatní ponechat.
4. Spustit hru a ověřit pozadí i fungování původní načítací lišty. Nejdříve otestovat místní klient, teprve potom zvažovat veřejnou aktualizaci.
5. Pro návrat zavřít klient a obnovit původních šest `Back*.ozj` ze zálohy.

## Formát a ověření

Původní soubory používají JPEG s 24bajtovým prefixem, který duplikuje prvních 24 bajtů skutečného JPEG. Všechny textury jsou RGB 1024×1024. První soubor dvojice je levá polovina, druhý pravá, dohromady logické plátno 2048×1024. Návrh se převádí na toto plátno a klient jej při vykreslení přizpůsobuje oknu stejným způsobem jako původní pozadí.

Nové JPEG byly vytvořeny přes FFmpeg (Lanczos, JPEG q=2, yuvj444p). Ověřeno dekódování všech šesti OZJ po odstranění prefixu, rozměry, orientace, shoda obsahu všech tří dvojic a neporušenost ZIPu. Spojené poloviny byly vizuálně zkontrolovány v náhledu 1680×945. Skutečný render a případné podmínky výběru pozadí vyžadují závěrečné ověření v herním klientu Windows.

`build-manifest.json` obsahuje kontrolní součty původních a nových šesti textur. `preview.png` je náhled opětovně složený z vytvořených JPEG polovin; není součástí instalace do Data.
