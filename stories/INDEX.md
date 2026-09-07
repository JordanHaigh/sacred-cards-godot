# Story Index

Codex must execute exactly one story per iteration.

| Ticket | Priority | Status | Dependencies | Story |
|---|---|---|---|---|
| [SC-001](SC-001.md) | P0 | DONE | — | Initialize Godot Project Architecture |
| [SC-101](SC-101.md) | P0 | DONE | SC-001 | Discover Existing Card JSON Schema |
| [SC-102](SC-102.md) | P0 | DONE | SC-101 | Implement CardDefinition |
| [SC-103](SC-103.md) | P0 | DONE | SC-102 | Implement CardDatabase |
| [SC-104](SC-104.md) | P0 | DONE | SC-102 | Implement CardInstance |
| [SC-201](SC-201.md) | P0 | DONE | SC-001 | Create DuelRuleSet |
| [SC-202](SC-202.md) | P0 | DONE | SC-201, SC-103 | Implement Sacred Cards Matchup System |
| [SC-301](SC-301.md) | P0 | DONE | SC-103, SC-104 | Implement DuelPlayerState |
| [SC-302](SC-302.md) | P0 | DONE | SC-301, SC-201 | Implement DuelState |
| [SC-303](SC-303.md) | P0 | DONE | SC-302 | Implement Duel Action API |
| [SC-304](SC-304.md) | P0 | DONE | SC-202, SC-302 | Implement BattleResolver |
| [SC-401](SC-401.md) | P0 | TODO | SC-304 | Add Battle Resolver Unit Tests |
| [SC-402](SC-402.md) | P0 | TODO | SC-202 | Add Matchup Matrix Tests |
| [SC-1601](SC-1601.md) | P0 | TODO | SC-304, SC-305, SC-306, SC-401, SC-801, SC-901, SC-903 | Complete Playable Duel Vertical Slice |
| [SC-203](SC-203.md) | P1 | TODO | SC-201 | Document Exact Sacred Cards Rules |
| [SC-305](SC-305.md) | P1 | TODO | SC-303 | Implement Duel State Machine |
| [SC-306](SC-306.md) | P1 | TODO | SC-304 | Implement Victory and Defeat Resolution |
| [SC-403](SC-403.md) | P1 | TODO | SC-305 | Add Duel State and Action Tests |
| [SC-501](SC-501.md) | P1 | TODO | SC-103 | Implement Deck Model |
| [SC-502](SC-502.md) | P1 | TODO | SC-501 | Implement Sacred Cards Deck Capacity |
| [SC-503](SC-503.md) | P1 | TODO | SC-501 | Implement Duelist Level Restrictions |
| [SC-504](SC-504.md) | P1 | TODO | SC-103 | Implement Player Card Collection |
| [SC-601](SC-601.md) | P1 | TODO | SC-501, SC-502, SC-503, SC-504 | Implement Deck Builder Core Logic |
| [SC-603](SC-603.md) | P1 | TODO | SC-601 | Build Deck Builder UI |
| [SC-701](SC-701.md) | P1 | TODO | SC-103 | Implement Card Effect Registry |
| [SC-702](SC-702.md) | P1 | TODO | SC-302 | Implement Duel Event Bus |
| [SC-703](SC-703.md) | P1 | TODO | SC-701, SC-702 | Implement Basic Spell Effect Primitives |
| [SC-704](SC-704.md) | P1 | TODO | SC-702 | Implement Trap Trigger System |
| [SC-801](SC-801.md) | P1 | TODO | SC-303 | Implement Basic Legal-Move AI |
| [SC-802](SC-802.md) | P1 | TODO | SC-304, SC-801 | Implement AI Combat Evaluation |
| [SC-901](SC-901.md) | P1 | TODO | SC-302 | Build Basic Duel Screen |
| [SC-902](SC-902.md) | P1 | TODO | SC-901 | Build Card Inspection UI |
| [SC-903](SC-903.md) | P1 | TODO | SC-303, SC-901 | Implement Player Duel Controls |
| [SC-1001](SC-1001.md) | P1 | TODO | SC-001 | Implement Overworld Player Movement |
| [SC-1002](SC-1002.md) | P1 | TODO | SC-1001 | Implement Overworld Map Framework |
| [SC-1003](SC-1003.md) | P1 | TODO | SC-1002 | Implement NPC Framework |
| [SC-1004](SC-1004.md) | P1 | TODO | SC-1003 | Implement Overworld Interaction System |
| [SC-1005](SC-1005.md) | P1 | TODO | SC-1002 | Implement Scene and Map Transitions |
| [SC-1101](SC-1101.md) | P1 | TODO | SC-001 | Implement Dialogue Database |
| [SC-1102](SC-1102.md) | P1 | TODO | SC-1101 | Implement Dialogue Runner |
| [SC-1103](SC-1103.md) | P1 | TODO | SC-001 | Implement Game Flag System |
| [SC-1105](SC-1105.md) | P1 | TODO | SC-1102, SC-901 | Implement Dialogue Duel Trigger |
| [SC-1201](SC-1201.md) | P1 | TODO | SC-103 | Implement Duelist Database |
| [SC-1202](SC-1202.md) | P1 | TODO | SC-1201, SC-504 | Implement Duel Rewards |
| [SC-1203](SC-1203.md) | P1 | TODO | SC-502 | Implement Deck Capacity Progression |
| [SC-1204](SC-1204.md) | P1 | TODO | SC-503 | Implement Duelist Level Progression |
| [SC-1301](SC-1301.md) | P1 | TODO | SC-504, SC-1103 | Implement Save Data Model |
| [SC-1302](SC-1302.md) | P1 | TODO | SC-1301 | Implement Save and Load |
| [SC-1501](SC-1501.md) | P1 | TODO | SC-101, SC-103 | Build Robust Card JSON Importer |
| [SC-1602](SC-1602.md) | P1 | TODO | SC-603, SC-1601 | Connect Deck Builder to Duel |
| [SC-1603](SC-1603.md) | P1 | TODO | SC-1004, SC-1105, SC-1601 | Connect Overworld to Duel |
| [SC-1604](SC-1604.md) | P1 | TODO | SC-1602, SC-1603, SC-1202, SC-1302 | Complete Core Gameplay Loop |
| [SC-602](SC-602.md) | P2 | TODO | SC-601 | Implement Card Sorting and Filtering |
| [SC-705](SC-705.md) | P2 | TODO | SC-701, SC-101 | Map Extracted Card Effects |
| [SC-803](SC-803.md) | P2 | TODO | SC-802 | Implement AI Profiles |
| [SC-904](SC-904.md) | P2 | TODO | SC-903 | Add Duel Feedback and Animations |
| [SC-1104](SC-1104.md) | P2 | TODO | SC-1102, SC-1103 | Implement Conditional NPC Dialogue |
| [SC-1303](SC-1303.md) | P2 | TODO | SC-1302 | Implement Save Migration System |
| [SC-1401](SC-1401.md) | P2 | TODO | SC-504, SC-1103 | Build Developer Debug Menu |
| [SC-1402](SC-1402.md) | P2 | TODO | SC-302 | Build Duel State Inspector |
| [SC-1502](SC-1502.md) | P2 | TODO | SC-1501 | Generate Card Dataset Validation Report |
| [SC-1503](SC-1503.md) | P2 | TODO | SC-1501 | Implement Optional Card Asset Path Mapping |

## Selection Rule

Choose the highest-priority eligible story. Within the same priority, choose the lowest numerical ticket ID. A story is eligible only when all dependencies are `DONE` and it is not `BLOCKED`.

Only one story may be `IN PROGRESS` at any time.
