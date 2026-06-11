= Abduktion

== Deduktion, Induktion, Abduktion

Die Wissenschaftsphilosophie klassifiziert das Schließen in drei
Modi, die häufig Charles Sanders Peirce zugeschrieben werden:

- *Deduktion.* Aus einer Regel und einer Prämisse wird die
  Konklusion abgeleitet. "Alle Raben sind schwarz. Dies ist ein
  Rabe. Folglich ist er schwarz." Korrekt und sicher.
- *Induktion.* Aus vielen Fällen eines Musters wird verallgemeinert.
  "Jeder Rabe, den ich gesehen habe, ist schwarz. Also sind alle
  Raben schwarz." Anfechtbar; der nächste Fall könnte sie widerlegen.
- *Abduktion.* Zu einer Beobachtung wird eine Hypothese aufgestellt,
  die sie erklären würde. "Dieser Rabe ist weiß. Vielleicht ist er
  ein Albino." Spekulativ; mehrere Hypothesen könnten passen.

Das Standard-SMT ist rein *deduktiv*: zu einer Formel wird sat
oder unsat abgeleitet. *Abduktives SMT* — das unterscheidende
Merkmal von adsmt — fügt den dritten Modus hinzu.

== Die abduktive Frage

Standard-SMT fragt: *"ist $phi$ wahr?"*

Abduktives SMT fragt: *"welche Hypothese $H$ würde $phi$ wahr
(oder äquivalent $not phi$ falsch) machen?"*

Praktisch ist $H$ die minimale Menge zusätzlicher Annahmen, die
der Benutzer akzeptieren müsste, damit der Solver das ursprüngliche
Ziel erledigen kann. Der Benutzer prüft $H$ und entscheidet, ob
die Annahmen für seinen Bereich vernünftig sind.

== Warum dies für Beweisassistenten wichtig ist

In einem ITP-Kontext ist die typische Interaktion:

1. Der Benutzer schreibt einen Beweis. Trifft auf ein Teilziel.
2. Der Benutzer ruft die SMT-Taktik auf. SMT erledigt entweder
   das Teilziel oder gibt "unknown" zurück.
3. Bei "unknown" steckt der Benutzer fest — er muss raten, welche
   zusätzliche Hypothese helfen würde.

Abduktives SMT verändert Schritt 3:

3'. Bei *abductive* liefert SMT eine *gerangte Liste von
    Kandidatenhypothesen*. Der Benutzer wählt eine aus und fügt
    sie als Annahme hinzu (oder beweist sie separat).

Der Unterschied ist qualitativ: anstelle von "der Solver hat
aufgegeben" sieht der Benutzer "hier sind fünf konkrete Dinge,
die der Solver für hilfreich hält, sortiert nach Ihrer
Kosten-Proxy".

== Ein durchgearbeitetes Beispiel

Ein Lean-4-Benutzer hat das Ziel:

```lean
example (n : Nat) : f n ≤ g n := by
  smt_abduce
```

`smt_abduce` ruft adsmt im abduktiven Modus auf. Das
Grundschließen (es liegen keine Fakten über $f$ oder $g$ vor)
erschöpft sich sofort, daher eskaliert adsmt:

```text
abductive-candidates:
  (candidate :rank 1 :hypothesis ((∀ n, f n ≤ n) (∀ n, n ≤ g n))
             :justification (sld_chain via Trans.trans))
  (candidate :rank 2 :hypothesis ((∀ n, f n ≤ g n))
             :justification (quantifier_exhausted))
  (candidate :rank 3 :hypothesis ((∀ n, f n = n) (∀ n, n = g n))
             :justification (sld_chain via Eq.subst))
```

Die Lean-4-Taktik bringt diese als benannte Platzhalter zum
Vorschein:

```lean
example (n : Nat) : f n ≤ g n := by
  have h1 : ∀ n, f n ≤ n := by sorry  -- candidate 1
  have h2 : ∀ n, n ≤ g n := by sorry  -- candidate 1
  exact Nat.le_trans (h1 n) (h2 n)
```

Der Benutzer erledigt die `sorry`s, falls die Hypothesen in
seinem Kontext wahr sind, oder verfeinert das Ziel, falls die
Kandidaten nicht akzeptabel sind.

== Wie adsmt Kandidaten findet

Drei Quellen, jeweils an der Engine-Grenze sichtbar gemacht
(Begleitband Kap. 8):

1. *SLD-Ketten über Horn-Regeln.* Die Wissensbasis des Benutzers
   (asserted Fakten + Regeln in `.kb`-Form) wird rückwärts vom
   Ziel ausgehend durchlaufen. Jede Regel, deren Kopf mit dem
   Ziel unifiziert, erzeugt eine Teilkette; Teilketten, deren
   Residuen nicht grundständig sind, werden zu
   Kandidatenhypothesen.

2. *Theorie-Lücken.* Wenn ein Theorie-Solver "unknown" mit
   einer konkreten Form zurückgibt ("ich müsste $i eq.not j$ wissen,
   um dieses select/store zu entscheiden"), wird die Lücke zu
   einem Kandidaten.

3. *Quantorenerschöpfung.* Wenn die Tier-1-2-3-Instanzierungs-
   Pipeline erschöpft ist, wird der Quantor selbst zu einem
   Kandidaten — er wird als Hypothese hochgestuft, die der
   Benutzer möglicherweise akzeptiert.

Die drei Quellen werden zu einer gerangten Liste zusammengeführt,
bevor sie an den Aufrufer zurückgegeben werden.

== Ranking

Mehrere Kandidaten erledigen häufig dasselbe Ziel. adsmt
sortiert sie nach einer Benutzerkosten-Proxy:

- Weniger Atome werden bevorzugt.
- Kleinere (geringere Tiefe) Atome werden bevorzugt.
- Bereits im Geltungsbereich befindliche Atome werden gegenüber
  neuen bevorzugt.

Der Benutzer sieht den Spitzenkandidaten am Anfang der Liste
und kann weiter scrollen, falls der Spitzenkandidat nicht
passt.

== Minimalität

Ein erster Anlauf zur Bestimmung der "Hypothesen, die das Ziel
erledigen würden" sammelt gewöhnlich Redundanz an. Wenn $H_1 =
\{P, Q\}$ das Ziel erledigt und $H_2 = \{P\}$ es ebenfalls
erledigt (mit $P$ alleine), ist letzteres vorzuziehen. Der
`minimize`-Durchgang von adsmt geht jeden Kandidaten durch und
streicht Atome, die vom Rest des Kandidaten impliziert werden
(modulo Theoriekontext).

Das Ergebnis ist eine *theorie-minimale* Kandidatenmenge: keine
echte Teilmenge eines zurückgegebenen Kandidaten erledigt das
Ziel.

== Vertrauen

Abduktive Kandidaten sind *Hypothesen*, keine Beweise. Der
Benutzer übernimmt die Verantwortung dafür, ob die Hypothese
wahr ist. Das Zertifikat hält den abduktiven Schritt explizit
fest (Kapitel 9), sodass der nachgelagerte ITP folgendes sieht:

```text
(step :rule abductive_assume
      :id 17
      :hypothesis ((P a) (Q b))
      :justification (sld_chain ...))
```

Der ITP stellt dies als `sorry`-förmige Platzhalter dar. Es
besteht kein Risiko, dass die abduktive Schicht stillschweigend
Unkorrektheit einführt — jede akzeptierte Hypothese ist als
Verpflichtung *sichtbar*.

== Wenn sich Abduktion schlecht verhält

Abduktion hat ihre eigenen Versagensmodi:

- *Keine Kandidaten.* Die Wissensbasis des Benutzers ist zu
  dünn — die SLD-Kette findet keine Regel, deren Kopf mit dem
  Ziel unifiziert. Verdikt `unknown(AbductiveExhausted)`. Der
  Benutzer reichert die Wissensbasis an oder vereinfacht das
  Ziel.
- *Zu viele Kandidaten.* Hunderte von Kandidaten nach dem
  Ranking. Der Bereich des Benutzers hat wahrscheinlich eine
  Struktur, von der der Solver nichts weiß. Es wird empfohlen,
  die Behauptungen manuell zu verschärfen.
- *Schlechtes Ranking.* Der "korrekte" Kandidat steht an
  dritter Stelle in der Liste, nicht an erster. Die
  Rangheuristik von adsmt ist nutzerkostengetrieben; wenn Ihr
  Bereich dem widerspricht, hinterlegen Sie über die LSP-/CLI-
  Optionen eigene Ranggewichte.

== Wo Abduktion glänzt

Die wichtigsten Anwendungsfälle:

- *Interaktiver Beweis.* Der Benutzer iteriert zwischen adsmt
  und seinem Beweisskript, akzeptiert Kandidaten als
  Verpflichtungen und erledigt sie dann durch Taktiken.
- *Spezifikationsverfeinerung.* "Warum ist meine Spezifikation
  inkonsistent?" Abduktive Kandidaten zeigen, welche Hypothese
  Sie hinzufügen müssten, um die Erfüllbarkeit
  *wiederherzustellen* — ein Hinweis darauf, welche Annahme
  Ihnen fehlt.
- *Theorieexploration.* Welche Konsequenzen kann man bei
  einigen wenigen Axiomen formulieren und vom Solver fehlende
  Fakten abduzieren lassen? Eine Art automatisierter
  Vermutungsgenerierung.

== Der größere Anspruch

Der Anspruch von adsmt ist nicht, dass abduktives SMT
deduktives SMT ersetzt — das tut es nicht. Der Anspruch ist,
dass *das "unknown"-Verdikt des deduktiven SMT verarmt ist*
und dass ein Solver, der einen Beweisassistenten bedienen soll,
dem Benutzer etwas Umsetzbareres geben sollte. Die abduktive
Schicht ist dieses Etwas.

Kapitel 9 behandelt die Zertifikatsmaschinerie, die abduktive
Schritte auf der ITP-Seite wiederherstellbar macht. Kapitel 10
führt die Integration durchgehend vor.
