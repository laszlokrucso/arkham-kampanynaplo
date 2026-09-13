# Arkham · Kampánynapló

Magyar, reszponzív, kattintható prototípus. Belépési pont: `dist/index.html`, statikus HTTP szerverrel kiszolgálva.

## Kipróbálás

A felső játékosváltóval Anna, Bence és Lili szerepe próbálható ki. Mindenki a saját nyomozóját szerkeszti. Az alkalom játékmestere rögzíti a közös eredményt, a kampánygazda vagy a játékmester átadhatja a szerepet. Minden személyes eredmény mentése és a közös eredmény után véglegesíthető az alkalom, majd új indítható.

## Korlátok

Mintaadatok és öt alapnyomozó. A localStorage csak az adott böngészőben tárol; nincs valódi hitelesítés, meghívás, szerveroldali jogosultság vagy többfelhasználós szinkronizálás. A szerepellenőrzés UX demonstráció, nem biztonsági határ. A nyomozócsere nullázott adatokkal indul, a korábbi adatlap archiválódik. A szabályokat a játékosok alkalmazzák kézzel.

Az opcionális Google Fonts betöltése nélkül rendszerbetűkkel is működik. Az angol felület még nincs megvalósítva; a következő fejlesztési szakaszban a felületi szövegek nyelvi szótárba kerülnek.
