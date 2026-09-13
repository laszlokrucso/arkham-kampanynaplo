# Arkham · Kampánynapló

Magyar, mobilbarát webapp Supabase Auth és PostgreSQL háttérrel. Supabase-projekt: Arkham Journal (`ddxzgkqjorqlfotfhiok`). Mindkét migráció alkalmazva.

## Funkciók

E-mail/jelszó belépés, regisztráció és jelszó-visszaállítás; kampányok; hét napos, visszavonható meghívólinkek; legfeljebb négy csapattag; nyomozóválasztás; saját adatlap, XP, traumák, állapotok, jegyzetek és paklilink; alkalmanként átadható játékmesteri szerep; közös napló és eredmény; változástörténet; kampánygazda átadása; kampány lezárása.

A személyes eredmények az alkalom lezárásáig javíthatók. Csak a különbözet módosítja az XP-t és a traumát, egyetlen adatbázis-tranzakcióban. Régi verzióval nem írható felül új mentés. Lezáráskor minden résztvevőnek mentenie kell. Nyomozócsere két alkalom között lehetséges, a korábbi adatlap megmarad. A játékmester saját nyomozó nélkül is vezethet alkalmat. Az alkalom résztvevőlistája indításkor rögzül.

## Indítás

Node.js 22 vagy újabb. Parancsok a projekt könyvtárában:

    npm ci
    npm run build
    python -m http.server 4173 --bind 127.0.0.1 --directory dist

Helyi cím: http://127.0.0.1:4173/
A Supabase SDK helyben csomagolva kerül a frontendbe. A publikus Supabase-kulcs szándékosan nyilvános. Service-role kulcs nem szükséges, és nem kerülhet a frontendbe.

## A csoportos induláshoz még szükséges

1. Supabase / Authentication / URL Configuration: a Redirect URLs listába kerüljön a http://127.0.0.1:4173/ cím. Publikálás után az éles URL legyen a Site URL és engedélyezett visszatérési cím. A jelszó-visszaállítás az app PASSWORD_RECOVERY nézetét nyitja meg.
2. Supabase / Authentication / Email vagy SMTP Settings: saját SMTP és ellenőrzött feladó szükséges a csoport regisztrációs leveleihez. Az alap levélküldő korlátozott. Az e-mail megerősítés aktív maradt. A levelek kézbesítését még nem ellenőriztük.
3. A webfelület még nincs publikálva. A korábbi külső feltöltést az automatikus jóváhagyási ellenőrzés blokkolta; a külön felhasználói engedély még szükséges. A Sites jelenlegi hozzáférése csak a tulajdonosé. A csoportos eléréshez a webfelület hozzáférését is rendezni kell, a kampányadatokat ettől függetlenül Supabase-tagsági szabályok védik.

## Adattárolás és jogosultságok

Az adatbázis az egyetlen hiteles adattároló. A böngésző a Supabase-belépést, a kiválasztott kampány azonosítóját és az átmeneti meghívókódot tárolja. A prototípus mintaadatait nem importáltuk. Más játékosok mentései a Frissítés gombbal tölthetők be. Offline írás nincs; sikertelen mentésnél a kitöltött mezők megmaradnak.

Minden tábla RLS-védett. Közvetlen kliensoldali adatbázisírás tiltott. Az arkham_action függvény ellenőrzi a belépést, kampánytagságot, az aktuális szerepet és a rekordverziót. Kampánysor-zárolás sorba rendezi a párhuzamos módosításokat. A naplót csak a szerver írhatja.

A Supabase ellenőrzője két szándékosan hitelesített felhasználók számára elérhető SECURITY DEFINER függvényt jelez. Ezek ellenőrzött belépési pontok, rögzített üres search_path értékkel; anon/PUBLIC végrehajtás tiltott. Leírás: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable

## Ellenőrzés

    npm test

A tests/database.sql integrációs teszt a tényleges Supabase-sémán futott három ideiglenes tesztfelhasználóval, visszagörgetett tranzakcióban. Sikeresen ellenőrizte az idegen kampány elrejtését, a meghívós tagságot, saját nyomozó szerkesztését, a közvetlen írások tiltását, duplikált karakter és eredmény tiltását, XP-javítást, játékmester- és kampánygazdaváltást, lezárási feltételeket és archiválást. Tesztadat nem maradt. Kliensellenőrzések: számmezők, HTML-escape, biztonságos paklilinkek. A telepített futásidejű függőségek npm audit ellenőrzése nem talált ismert hibát.

## Jelenlegi keret

Öt alapnyomozó az adatbázisból betöltve; teljes katalógus és kártyaképek később bővíthetők. Magyar felület; az opcionális angol változat még nincs elkészítve. Csak alkalmak közötti állapotot tárol, félbehagyott játékot nem.
