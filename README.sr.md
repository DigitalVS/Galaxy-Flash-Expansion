# Fleš proširenje za Galaksiju

Fleš proširenje za Galaksiju je dodatak za retro računar [Galaksija](https://en.wikipedia.org/wiki/Galaksija_(computer)) koji omogućava upotrebu USB fleš ključa (fleš drajva) kao jedince spoljne memorije. Proširenje postoji u verziji za klasičnu Galaksiju, kod koje se priključuje na port za proširenje, i noviju verziju Galaksije iz 2024. godine, gde se priključuje u procesorsko podnožje. Proširenje za klasičnu Galaksiju sadrži i dodatnu RAM memoriju od 32 kilobajta.

Ovaj repozitorijum sadrži sve hardverske i softverske fajlove neophodne za izradu ovakvog proširenja. Sav sadržaj je objavljen kao _open-source_ i svako je slobodan da ga sam napravi, ali ovo proširenje je moguće naručiti i kao već sastavljen i testiran dodatak, putem elektronske pošte preko adrese autora koja je povezana sa ovim Github nalogom (eventualni kasniji načini naručivanja će biti objavljeni ovde kad budu dostupni).

Izvorni kod je napisan u Z80 asemblerskom jeziku i skoro potpuno je identičan za obe verzije Galaksije. Međutim, hardverski deo se dosta razlikuje i, da ne bi dolazilo do zabune, proširenja za dve verzije Galaksije su imenovana različito:

- __Galaxy Space Expansion (skraćeno: GSE)__ - naziv proširenja za klasičnu Galksiju
- __Galaxy Flash Expansion (skraćeno: GFE)__ - naziv proširenja za noviju Galaksiju iz 2024. godine

> Približna ocena brzine pokazuje impresivne rezultate za računar sa tako skromnim procesorskim mogućnostima. Sa isključenim osvežavanjem ekrana, brzina čitanja podataka sa USB ključa je u opsegu od 80 do 100 kilobajta u sekundi.

Sledeća slika pokazuje ispis sadržaja jednog direktorijuma. Dugačka imena fajlova su skraćena na osam znakova i završavaju se sa `>1`. U slučaju da je prvih šest znakova naziva istovetno za veći broj fajlova, oni će biti prikazani sa različitim završetkom: `>2`, `>3`, itd. Na kraju svake linije je oznaka `<DIR>` za direktorijume ili veličina fajla za fajlove. Veličina fajlova većih od 9999 bajtova je prikazana u kilobajtima sa slovom `K` na kraju, ili u megabajtima i tada se završava slovom `M`. Prikaz direktorijuma sa fajlovima većim od jednog gigabajta nije podržan.

![Primer ispisa direktorijuma.](/images/usb_flash_screen.png)

> USB-A konektor koji se nalazi na ovom proširenju nije unverzalni USB port i drugi uređaji priključeni na njega, osim USB fleš ključa (i eventualno spoljnog USB hard diska), neće raditi!

## Hardverske mogućnosti

Glavna odlika koja je zajednička za obe verzije proširenja - podrška za USB fleš drajv, je implementirana sa CH376S čipom koji podržava drajvove sa FAT12, FAT16 i FAT32 fajl sistemom veličine do 32GB. USB hard diskovi sa FAT32 fajl sistemom bi takođe trebalo da rade.

Ostale funkcionalnosti su različite za GSE i GFE verzije proširenja i biće opisane u odvojenim poglavljima.

> Ovo proširenje se sme instalirati samo ukoliko je napajanje računara isključeno. Priključivanje proširenja dok je računar uključen može prouzrokovati oštećenje računara, kao i elektronskih komponenti samog proširenja.

### Prostorno proširenje za Galaksiju (GSE)

Prostorno proširenje za Galaksiju (eng: Galaxy Space Expansion) sadrži čip sa  dodatnih 32 kilobajta RAM memorije, kao i jedan dodatni EPROM čip. Proširenje memorije, zajedno sa već postojećih 6 kilobajta na matičnoj ploči Galaksije, čini jedan kontinualan memorijski prostor od 38 kilobajta. Dodatni EPROM čip sadrži mašinski program u kojem su implementirane komande za komunikaciju sa USB fleš ključem (i nešto više od toga, a to će biti predstavljeno dalje u tekstu). Ova dva čipa zauzimaju sledeći prostor u memorijskoj mapi računara:

- RAM: &4000 - &BFFF
- EPROM: &C000 - &FFFF

Programski kod pre upotrebe mora biti inicijalizovan, svaki put po uključivanju računara, unosom sledeće komande u BASIC komandnoj liniji: `A=USR(&C000)`.

Naredna slika prikazuje dve verzije GSE proširenja. Glavna razlika između njih je da je jedna sa SRAM čipom u PDIP kućištu (štampana ploča na levoj strani), a druga je sa SRAM čipom u TSOP kućištu (manja štampana ploča na desnoj strani). Šeme, Gerber fajlovi, i svi drugi fajlovi neophodni za izradu obe verzije su objavljeni na ovom repozitorijumu.

![Izgled dve različite GSE verzije.](/images/two-gse-versions.png)

#### Uputstvo za povezivanje

Štampana ploča prostornog proširenja za Galaksiju (GSE) na sebi ima 44-pinski  konektor koji se priključuje na ivični konektor na matičnoj ploči Galaksije. Svi koji na svojoj klasičnoj Galaksiji nemaju zalemljenu malu štampanu ploču na kojoj se nalazi ivični konektor, mogu je izraditi pomoću fajlova objavljenih na  [Galaksija Resources](https://github.com/DigitalVS/Galaksija-Resources) repozitorijumu, ili je naručiti zajedno sa GSE štampanom pločom. Ova verzija te male štampane ploče je unazad kompatibilna sa  štampanom pločom ivičnog konektora za originalni projekat Galaksije iz 1984. godine, ali omogućava i povezivanje dodatnih signala koji su nedostajali na originalnoj ploči, a od kojih su neki neophodni za pravilno funkcionisanje GSE proširenja. To su: napon napajanja (VCC), kao i RD i RESET signali Z80 procesora.

Dovesti ove nedostajuće signale do konektora za proširenje nije naročito teško i ne zahteva nikakve specijalne sposobnosti ili alat. Biće vam potreban komad izolovane žice (ni previše tanke, ni previše debele), tinol žica i lemilica.

Štampana ploča ivičnog konektora objavljena na repozitorijumu _Galaksija Resources_ već ima predviđena mesta, tj. kontakte, označene natpisima VCC, RD- i RESET-. Ovo su mesta na koje treba zalemiti jednu stranu žice za navedene signale. Drugu stranu žice koja povezuje napon napajanja (VCC) sa ivičnim konektorom je najbolje zalemiti negde blizu ulaza za napajanje računara, na neku od tačaka na kojim je dostupan napon napajanja. RD signal je najbolje zalemiti direktno na pin broj 21 procesora, to jest, na sam RD pin, i to sa donje strane matične ploče. Drugu stranu RESET žice možete povezati na pin broj 26 procesora, ili na neku tačku koja je bliže ivičnom konektoru. Na primer, sledeća slika prikazuje ivični konektor kod kog je RESET signal povezan na obližnji reset taster.

![Izgled porta za proširenje.](/images/port-example.png)

Oni koji već imaju port za proširenje, tj. ivični konektor, na svojoj Galaksiji, prvo moraju da provere da li su navedeni dodatni signali povezani sa
ovim portom, i ako jesu, da provere da li je svaki od njih povezan na pravilan pin. Pinovi za tri dodatna signala (strogo gledano, VCC nije signal) VCC, RD i RESET su ovde izabrani tako da se poklapaju sa pinovima na kojima su postavljeni za neke stare projekte, tako da postoji verovatnoća da je neki od njih već pravilno povezan. Dakle, treba uporediti pinove na postojećem portu za proširenje sa pinovima za VCC, RD i RESET na ivičnom konektoru objavljenom na _Galaksija Resources_ repozitorijumu i ukoliko neki od signala nije povezan ili je povezan na pogrešan pin, treba ih prevezati onako kako je objašnjeno u prethodnom pasusu.

Sve ovo može izgledati previše komplikovano za nekoga ko je neiskusan u lemljenju i u radu sa elektronikom uopšte, ali uspešno povezivanje će biti bogato nagrađeno dobijanjem značajno unapređene i mnogo funkcionalnije Galaksije.

### Fleš proširenje za Galaksiju (GFE)

Nova Galaksija iz 2024. godine ima više RAM i ROM memorije od stare Galaksije, tako da u memorijskoj mapi računara nije preostalo slobodnog mesta za eventualne dodatne memorijske čipove. Na sreću, dobar deo prostora u ugrađenom EPROM čipu se ne koristi i to je prostor u koji se upisuje softver za ovaj projekat. Mana je jedino što se taj EPROM čip mora ili reprogramirati ili zameniti novim, ali, po drugoj strani, prednost je da se softver zato inicializuje automatski i nije potrebno izrvšavati dodatne komande za njegovu inicijalizaciju.

#### Uputstvo za povezivanje

Instalacija fleš proširenja za Galaksiju (eng: Galaxy Flash Expansion) je jednostavnije nego instalacija Prostornog proširenje za Galaksiju. Ovde se podrazumeva da svi imaju procesor instaliran preko podnožja, a ne direktno zalemljen na matičnoj ploči. Ovo je najčešće već ispunjeno, ali ukoliko je procesor na vašoj Galaksiji zalemljen za štampanu ploču, moraćete prvo da ga odlemite i da na njegovo mesto na matičnoj ploči zalemite odgovarajuće 40-pinsko podnožje.

Pažljivo izvucite Z80 procesor iz podnožja. Ukoliko nemate poseban alat za vađenje integrisanih kola, možete to uraditi i manjim pljosnatim šrafcigerom. Tokom vađenja probajte da podjednako podižete obe strane procesora, da bi izbegli savijanje pinova na čipu. Ukoliko se neki od pinova ipak savije, nije ništa strašno, samo ga pažljivo i bez primene prevelike sile, vratite u pravilan položaj. To možete uraditi špicastim kleštima ili uz pomoć pljosnatog šrafcigera.

Sada je potrebno utaknuti GFE pločicu u procesorsko podnožje, kao i procesor u podnožje na GFE pločici. GFE pločica može biti instalirana samo u jednom položaju (nema dovoljno mesta da bi mogla da se utakne u podnožje u inverznoj orjentaciji), tako da je nije moguće instalirati pogrešno, dok je za procesor neophodno pratiti oznaku orjentacije na GFE pločici.

Dimenzije GFE pločice su vrlo male, tako da kad se jednom instalira, praktično je više nije neophodno vaditi iz podnožja.

Sledeća slika prikazuje GFE pločicu postavljenu u Galaksijin procesorski slot. Još dva logička kola se nalaze sa zadnje strane pločice, iza procesora, i nisu vidljiva na slici.

![Izgled instalirane GFE pločice.](/images/installed-gfe.png)

> Ne zaboravite da takođe zamenite ili reprogramirate Bejzik EPROM čip, koji je na levoj strani štampane ploče (oznaka U3), jer GFE neće raditi bez novog softvera.

## Softverske mogućnosti

Podržani su samo USB fleš ključevi sa FAT fajl sistemom. Pristup fajl sistemu je sličan kao kod MS-DOS-a, ali ima i nekoliko razlika.

Imenovanje fajlova je po MS-DOS standardu u formatu 8+3 karaktera za ime i ekstenziju, na primer: "filename.txt". Dugačka imena fajlova nisu podržana. Nazivi direktorijuma po dubini su odvojeni znakom `/` (eng: slash). Dozvoljene ekstenzije su `.BAS`, `.GTP`, `.BIN` i `.TXT`. Fajlovi sa drugim ekstenzijama nisu dozvoljeni. Ekstenzija je obavezan deo imena fajla.

Ekstenzija `.BAS` se koristi za Bejzik program fajl, dok fajl sa `.GTP` ekstenzijom predstavlja mašinski program ili program sa kombinacijom mašinskog i Bejzik koda. Ekstenzija `.BIN` se koristi za binarne fajlove. Ekstenzija `.TXT` se tretira isto kao `.BIN`, a dodata je da bi se lakše razlikovao sadržaj fajlova.

Dužina putanje direktorijuma (eng: path) je ograničena na 36 karaktera, što predstavlja najmanje četiri nivoa direktorijuma. Fajlovima se može pristupati jedino iz tekućeg direktorijuma (na primer: "path/filename.txt" nije pravilan naziv fajla). Promena tekućeg direktorijuma se izvodi komandom `CD`, koja prihvata celu putanju kao argument (na primer: "subdir1/subdir2/subdir3"). Ukoliko putanja počinje sa znakom `/`, onda ona počinje od korenskog direktorijuma, inače je putanja relativna u odnosu na tekući direktorijum. Parametar komande ".." znači promenu tekućeg direktorijuma jedan nivo naviše, dok `.` predstavlja trenutni direktorijum.

_MS Windows_ koristi znak `~` (tilda) za kreiranje kratkih imena fajlova. Međutim, ovaj znak ne postoji na Galaksiji i umesto njega se upotrebljava karakter `>`.

Korišćenje svih neophodnih potprograma za USB komunikaciju je omogućeno preko _jump_ tabele, tako da ih drugi programi mogu pozivati i lakše implementirati funkcije čitanja i pisanja na USB fleš drajv.

### Komande

Za upravljanje fajlovima na USB fleš drajvu je implementirano nekoliko osnovnih komandi. Ove komande su sledeće:

| Komanda | Opis
|------|---------------
| CAT | Lista sadržaj trenutnog direktorijuma
| FLOAD | Učitava fajl sa fleš drajva u memoriju
| FSAVE | Snima sadržaj memorije na fleš drajv
| CD  | Postavlja trenutni direktorijum
| REMOVE | Briše fajl sa fleš drajva
| MKDIR | Kreira novi direktorijum
| RMDIR | Briše direktorijum
| GAD  | Startuje aplikaciju za debagovanje

Parametri navedeni u zagradama su opcioni parametri (mada ne uvek za sve varijante komandi).

> Kada se unosi parametar pod navodnicama i nema dodatnih parametara iza ovog parametra, završni znak navoda može biti izostavljen.

#### CAT ("\<wildcard\>")

Prikazuje detaljni sadržaj trenutnog direktorijuma. Parametar "\<wildcard\>" je opcioni. _Wildcard_ karakteri `?` i `*` se koriste za filtriranje prikazanih fajlova, na primer, `CAT "*.BAS"` prikazuje samo imena sa BAS ekstenzijom.

> Da bi mogli da pregledamo duže listinge direktorijuma, __linije listinga se na ekranu ispisuju samo dok je taster ENTER pritisnut__. Ovo znači da je moguće izlistati deo sadržaja direktorijuma držeći taster ENTER pritisnut, pa onda otpustiti ENTER da bi pregledali prikazan listing, onda opet pritisnuti ENTER da bi se nastavilo listanje ili pritisnuti taster BREAK (označen i kao ESC na nekim tastaturama) da bi prekinuli dalje listanje.

Ova komanda ne prikazuje skrivene fajlove i direktorijume.

> Jedna od novih komandi na Galaksiji 2024 nosi naziv `DIR`. Zbog toga ova reč nije mogla da bude iskorišćena za naziv ove komande i naziv `CAT` (od eng: catalog) je izabran umesto nje.

#### FLOAD "filename(",\<address\>)

Učitava fajl "filename" na određenu lokaciju u memoriji. Parametar \<address\> je decimalna ili heksadecimalna addresa od koje se fajl upisuje u memoriju.

Podržane ekstenzije su `.BAS`, `.GTP`, `.BIN` i `.TXT`. Parametar \<address\> je adresa u memoriji od koje se učitava sadržaj fajla i obavezan je za `.BIN` i `.TXT` ekstenzije, dok je za `.BAS` i `.GTP` opcioni i ukoliko je naveden onda se ignoriše.

#### FSAVE "filename(",\<address\>,\<length\>)

Snima sadržaj memorije u fajl na USB fleš drajvu. Parametri \<address\> and \<length\> su decimalne ili heksadecimalne vrednosti.

Podržane ekstenzije su `.BAS`, `.GTP`, `.BIN` i `.TXT`. Parametar \<address\> je obavezan parametar za `.GTP`, `.BIN` i `.TXT` ekstenzije, dok je za `.BAS` opcioni i ukoliko je naveden onda se ignoriše. Parametar \<length\> predstavlja broj bajtova u memoriji koji se snima na fleš drajv, početo od adrese \<address\>, i on je obavezan ukoliko parametar \<address\> postoji.

#### CD ("path")

Menja vrednost trenutnog direktorijuma. Parametar "path" je opcioni i ukoliko nije naveden, na ekranu se prikazuje trenutni direktorijum.

PRIMERI:

`CD "/"`  postavlja korenski (eng: root) direktorijum kao vrednost trenutnog direktorijuma\
`CD ".."` menja vrednost trenutnog direktorijuma na jedan nivo naviše\
`CD "."` pristupa trenutnom direktorijumu (koristi se proveru da li je trenutni direktorijum validan)\
`CD` ispisuje put (eng: path) i naziv trenutnog direktorijuma.

#### REMOVE "filename"

Briše fajl sa USB fleš drajva.

> Znajte da ova komanda ne zahteva potvrdu pre brisanja i da jednom izbrisani fajl ne može biti povraćen nazad.

#### MKDIR "dirname"

Kreira novi direktorijum u okviru trenutnog direktorijuma. Ako je kreiranje uspešno izvedeno, novi direktorijum se otvara i postavlja kao vrednost trenutnog direktorijuma.

#### RMDIR "dirname"

Briše direktorijum. Direktorijum mora biti prazan pre brisanja.

#### GAD

Startuje [GAD](https://github.com/DigitalVS/GAD) aplikaciju za debagovanje. Ova aplikacija je korisna za debagovanje Z80 asemblerskog koda i nije u direktnoj vezi sa ostalim ovde navedenim komandama. Ona ne zavisi od GSE ili GFE hardvera i može takođe biti korišćena na svakoj Galaksiji ili u emulatoru Galaksije. Za više informacija pogledajte dokumentaciju GAD aplikacije.

## Otklanjanje problema

Možda postoje neki fleš drajvovi koji ne rade sa CH376 čipom, ali autor ovog projekta nije naišao na takav drajv.

Starije revizije CH376 čipa, a koje se i dalje mogu naći u prodaji, dokazano ne prepoznaju fleš drajvove formatirane na _Windows_ operativnom sistemu (posebno _Windows 10_). Ukoliko imate ovakav slučaj, probajte da formatirate fleš drajv kao FAT32 fajl sistem na _Linux_ ili _Mac_ računaru (na primer, sa programom GParted) ili sa nekim od sličnih dodatnih alata za _Windows_ drugih proizvođača.

Ukoliko tokom izvršavanja komande dobijate poruku `NO CH376`, to znači da računar ne prepoznaje proširenje. U tom slučaju proverite da li je štampana ploča proširenja pravilno utaknuta u računar. Probajte da resetujete računar ili da ga restartujete (isključite i ponovo uključite napajanje).

Greška `NO USB` se ispisuje u slučaju da USB fleš drajv nije utaknut u USB slot proširenja.

The MIT License (MIT)

Copyright (c) 2025 Vitomir Spasojević (<https://github.com/DigitalVS/Galaxy-Flash-Expansion>). Sva prava zadržana.
