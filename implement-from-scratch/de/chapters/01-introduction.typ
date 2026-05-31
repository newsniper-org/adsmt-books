= Einleitung

== Was ein SMT-Solver leistet

Ein SMT-Solver beantwortet die Frage: *Gibt es bei einer
Menge logischer Bedingungen über einem eingeschränkten
Vokabular eine Wertzuweisung an die freien Variablen, die
alle Bedingungen gleichzeitig erfüllt?* Das „Satisfiability
Modulo Theories" — Erfüllbarkeit modulo Theorien — im Namen
bezeichnet dasselbe Erfüllbarkeitsproblem, das einem aus der
Aussagenlogik vertraut ist, doch die atomaren Einheiten der
Formel sind nicht mehr nur Boolesche Variablen — es sind
Aussagen über bestimmte mathematische Strukturen: lineare
Ungleichungen über den ganzen Zahlen, Gleichungen über
uninterpretierten Funktionssymbolen, Lese-Schreib-Muster auf
Arrays, Operationen auf der Bit-Ebene von Vektoren fester
Breite und so weiter.

Ein triviales Beispiel. Die aussagenlogische Formel
$ phi = (p or q) and not (p and q) $
ist erfüllbar: man wähle $p = top, q = bot$. Eine SMT-Formel
ergänzt diesen Stil des Schließens um Theorieatome:
$ psi = (x + y > 5) and (x < 3) and (y < 3) $
ist *unerfüllbar* — $x < 3$ und $y < 3$ liefern zusammen
$x + y < 6$, doch die strenge Ungleichung $x + y > 5$
erzwingt $x + y >= 6$ über den ganzen Zahlen, und die
Konjunktion bricht zusammen. Ein Solver, der für $psi$
Unerfüllbarkeit meldet, muss nicht nur über die Boolesche
Struktur der Konjunktion schließen, sondern auch über den
*arithmetischen Gehalt* jeder einzelnen Ungleichung.

Diese Arbeitsteilung — die Boolesche Struktur wird von einem
SAT-artigen Kern erledigt, der Theoriegehalt von
spezialisierten Theorie-Solvern — ist die architektonische
Idee, die die SMT-Familie von Werkzeugen definiert.

== Warum noch einen bauen

Es gibt bereits hervorragende SMT-Solver: Z3 von Microsoft
Research, CVC5 aus einem Konsortium um Stanford und Iowa,
Bitwuzla für Bitvektoren, MathSAT für
Verifikationslasten, Yices für Echtzeitumgebungen. Das
adsmt-Projekt erhebt keinen Anspruch darauf, eines davon
auf den klassischen SMT-Benchmarks zu entthronen. Es
existiert aus drei Gründen.

*Erstens*, adsmt ist um eine *abduktive*
Schließ-Schicht herumgebaut, die den anderen fehlt. Erreicht
ein klassischer SMT-Solver einen Zustand, in dem er die
Erfüllbarkeit innerhalb seines Budgets nicht entscheiden
kann, gibt er `unknown` zurück. adsmt versucht in einem
solchen Zustand, eine *minimale Menge zusätzlicher
Hypothesen* zu finden, die — der Eingabe hinzugefügt — das
Problem entscheidbar machen würde. Diese abduktive Ausgabe
wird dann zusammen mit dem Verdikt zurückgegeben, sodass
Aufrufer (insbesondere Nutzer interaktiver
Theorembeweiser) entscheiden können, was damit anzufangen
ist. Der klassische Anwendungsfall ist das interaktive
Beweisen: ein menschlicher Beweisautor bittet adsmt, einen
Schritt abzuarbeiten, adsmt scheitert, sagt aber zugleich:
*hier ist, was es zum Funktionieren gebracht hätte*. Der
Mensch kann den Hinweis annehmen, verschärfen oder
verwerfen.

*Zweitens*, adsmt ist um einen Kern *höherstufiger Logik
mit höher-gekindeten Typen* (HOL+HKT) herum gebaut, statt
um die mehrsortige Prädikatenlogik erster Stufe, in der
klassische SMT-Solver arbeiten. Das bringt adsmt näher an
die logische Oberfläche, auf der interaktive
Theorembeweiser (Lean 4, Rocq, Isabelle) bereits operieren,
was die Reflektion — das Versenden von Beweiszertifikaten
von adsmt an einen ITP zur erneuten Verifikation —
deutlich glatter macht. Ob die höherstufige Oberfläche den
Implementierungs­aufwand wert ist, ist eine
Entwurfs­abwägung, die adsmt getroffen hat; die Trade-offs
werden in Kapitel 3 diskutiert.

*Drittens*, adsmt ist als *Lean-4-first*-Solver gebaut. Sein
Zertifikatsformat enthält ein Lean-Reflektions-Emit-Modul,
das es einem Lean-Anwender erlaubt, adsmt als Taktik
aufzurufen und den entstehenden Beweis in seinem Kern neu
ausarbeiten zu lassen. Andere ITPs (Rocq, Isabelle) werden
über außerhalb des Baums liegende Backends unterstützt; das
im Baum liegende Projekt verpflichtet sich auf Lean 4 als
Referenzziel.

Die Kombination dieser drei Festlegungen ist es, die adsmt
unverwechselbar macht. Keine davon ist für sich allein
*neu* — abduktives Schließen hat eine lange Literatur,
HOL+HKT-Systeme existieren in HOL Light und in Lean selbst,
ITP-freundliches SMT wurde von veriT und der
Alethe-Ausgabe von CVC5 verfolgt. Die Kombination jedoch
ist ungewöhnlich genug, dass „adsmt bauen" eine andere
Übung ist als „Z3 bauen".

== Der Schlachtplan

Der Solver wird von unten nach oben gebaut. Der Kern
(Kapitel 2) ist die kleinstmögliche vertrauenswürdige
Basis. Das Typsystem (Kapitel 3) setzt darauf auf. Die
SAT-Schicht (Kapitel 4) ist von allem darüber Liegenden
unabhängig; sie könnte herausgerissen und durch einen
externen SAT-Solver ersetzt werden (adsmt selbst tut dies
mit OxiZ als Standard-Backend). Die Theorieschicht (Kapitel
5 und 6) kooperiert mit der SAT-Schicht über ein wohl
definiertes Protokoll. Die Quantorenschicht (Kapitel 7)
liegt über der Theorieschicht und nutzt sie als Dienst. Die
abduktive Schicht (Kapitel 8) operiert über allem und
eskaliert, wenn den unteren Schichten die Luft ausgeht. Das
Zertifikatsformat (Kapitel 9) zieht sich durch jede
Schicht — jede Inferenz, jeder Theorie-Aufruf, jede
abduktive Eskalation erzeugt ein strukturiertes
Beweisfragment. Kapitel 10 behandelt die Reflektion.
Kapitel 11 ist das Engineering-Kapitel: Teststrategien,
Stabilisierung der Oberfläche, Semver-Disziplin und die
praktischen Realitäten des Auslieferns des Solvers.

Ein Leser, der dieses Buch beendet, sollte in der Lage
sein, ein vergleichbares System aus einem leeren Workspace
heraus zu implementieren, in welcher Sprache auch immer
ihm beliebt. Der Leser sollte ferner in der Lage sein, den
Quelltext von adsmt ohne Überraschungen zu lesen: wir sind
nahe an den tatsächlich getroffenen Entwurfsentscheidungen
geblieben, einschließlich der Ecken, in denen der erste
Versuch von adsmt fehlerhaft war und eine spätere Revision
ihn gerichtet hat.
