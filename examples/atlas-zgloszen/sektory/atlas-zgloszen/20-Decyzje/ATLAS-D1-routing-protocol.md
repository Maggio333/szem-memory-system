---
type: decyzja
id: ATLAS-D1
title: "ADR: przykład protokołu routingu"
status: szkic
parents: [ATLAS-S1]
author: public-example
date: 2026-08-20
created_at: 2026-08-20
---
# ADR: przykład protokołu routingu

## Status
- [ ] Reject / [x] Implements as example / [x] Reversibility considerations

## Kontekst
[ATLAS-S1](../25-Syntezy/ATLAS-S1-contextual-routing.md) proponuje routing zależny od niejednoznaczności i ryzyka. Ten ADR nie zmienia realnego procesu; pokazuje, jak decyzja odwołuje się do syntezy.

## Decyzja
W przykładzie każda syntetyczna karta dostaje właściciela, powód i następny krok. Karty o jawnie określonym niskim ryzyku mogą mieć jednego właściciela; pozostałe kierowane są do odpowiedniej roli oraz, gdy potrzeba, niezależnego recenzenta.

## Odwracalność
Przed wykonaniem zaplanowanego przeglądu decyzja jest w pełni odwracalna: zmienia się tylko dokument przykładowy. Jeżeli kryterium z ATLAS-S1 nie przejdzie, ADR wraca do statusu `zdemotowany` z proweniencją.

## Action items
- [ ] Zdefiniować 16 syntetycznych kart bez danych rzeczywistych.
- [ ] Zapisać regułę ryzyka przed odczytem kart.
- [ ] Dać pakiet trzem niezależnym recenzentom.

## Powiązania
- parents: ATLAS-S1
