# Pathfinder Excessive Character Sheet (P.E.C.S.)
Internal To Do list

## To Do

:x: Initialize basic Node.js app

:x: We are using AngularJS now
- [x] We are using TypeScript now
- [x] Learn a language
- [x] Recreate everything in Angular
- [x] We are using Angular now
- [x] Get SSH key working in VSC >:|
- [x] Fill character sheet
- [x] - Abilities
- [x] - Armor
- [x] - Attacks
- [x] - Skills
- [x] - Traits
- [x] - Feats -> Abilities, Attacks, Skills
- [x] - Classes, Ancestries, Heritages, Backgrounds
- [x] - So many results of Classes, Ancestries, Heritages, Backgrounds
- [x] -- Adding skills and lore through Feats and Backgrounds
- [x] - Actions granted through class and feats
- [x] - Implement Ohm
- [x] - Implement Finn
- [x] - Animal companion
- [x] - Implement a spellcasting class
- [x] - Implement all General and Skill Feats
- [ ] - Implement all Weapons
- [ ] - Implement all Armors
- [ ] - Implement all Shields
- [ ] - Implement all Worn Items
- [ ] - Implement all Held Items
- [ ] - Implement all Consumables
- [x] -- Implement all Alchemical Bombs and Consumable Bombs
- [x] -- Implement all Potions
- [x] -- Implement all Alchemical Elixirs
- [x] -- Implement all Alchemical Tools
- [x] -- Implement all Oils
- [x] -- Implement Scrolls
- [x] -- Implement all Talismans
- [ ] -- Implement all Ammunition
- [x] - Implement all Adventuring Gear
- [x] - Implement all Materials
- [x] - Allow custom content
- [x] - Implement one full Class with Feats and Features
- [x] - Feat requirements
- [x] - Equipment (weapons, armor, shields) -> Abilities, Armor, Attacks, Skills
- [x] - Actions granted through equipment
- [x] - More equipment (worn magic items etc.) and effects
- [x] - Runes
- [x] -- Implement all Weapon Runes
- [x] -- Implement all Armor Runes
- [x] - Exclusive bonuses: Proficiency, Circumstance, Item, Status, untyped
- [x] - Classes and Levels
- [x] - Conditions
- [x] - Passing time
- [x] - Resting
- [x] - Using consumables
- [x] - Adding custom items
- [x] Populate character sheet from JSON
- [x] Use Database
- [x] Cleanup Savegame
- [x] Load/Save from/to Database
- [x] Action Icons
- [x] Implement all Core and Character Guide Ancestries
- [ ] Implement all Core and Character Guide Ancestry Feats
- [x] - Dwarf
- [x] - Elf
- [ ] - Gnome
- [x] - Goblin
- [x] - Halfling
- [x] - Human
- [x] - Half-Orc (including Orc, but excluding ACG)
- [ ] - Hobgoblin
- [ ] - Leshy
- [x] - Lizardfolk
- [ ] - Shoony
- [x] Implement all Core and Character Guide Heritages
- [x] Implement all Core and Character Guide Backgrounds
- [ ] Implement all Core and Character Guide Classes and Multiclass Archetypes
- [ ] - Alchemist
- [x] - Barbarian
- [x] - Bard
- [ ] - Champion
- [x] - Cleric
- [x] - Druid
- [x] - Fighter
- [x] - Monk
- [x] - Ranger
- [x] - Rogue
- [x] - Sorcerer
- [x] - Wizard
- [ ] Implement all Spells
- [ ] - Focus Spells
- [x] -- Monk
- [ ] -- Champion
- [x] -- Cleric
- [x] -- Wizard
- [x] -- Bard
- [x] -- Druid
- [x] -- Sorcerer
- [x] - Cantrips
- [x] - Level 1 Spells
- [x] - Level 2 Spells
- [x] - Level 3 Spells
- [x] - Level 4 Spells
- [x] - Level 5 Spells
- [x] - Level 6 Spells
- [ ] - Level 7 Spells
- [ ] - Level 8 Spells
- [ ] - Level 9 Spells
- [ ] - Level 10 Spells
- [x] Add custom conditions with effects
- [x] Add License notices to comply with Pathfinder Community Use Policy and Open Game License
- [x] Add casting spells on party members
- [x] Add exchanging items with party members
- [x] Add manual mode without automated conditions and effects
- [ ] Stretch Goal: Bitmap Icons for items, spells, feats, activities etc.
- [ ] Stretch Goal: Initiative tracker, battles, being a battle member, GM-Player-Communication.......
- [ ] Stretch Goal: Include optional systems like Stamina & Resolve
- [x] Stretch Goal: Icon-driven UI with dynamic tooltips
- [ ] Stretch Goal: Exporting statblock and files for other tools (e.g. Foundry VTT)

Active to-do:
- Type item in itemContent.component
- Show deity's restrictionDesc on cleric spells in spells and spellbook components
- Hero Points are limited to 3

Implement:
- Cache system to prevent re-calculating complicated values if nothing has changed
- Dust of Disappearance

Test:

Bugs:
- Gaining a light item (e.g. moderate healing potion) from another character that tips over the encumbrance limit doesn't update effects.

To do:
- Move customfeats that are always generated out of the character and into the FeatsService
- Error handling in all steps of the saving process.
- "When a character creates consumable items, they can make them in batches of four."
- Feat.meetsHeritageReq should check the level that additional heritages were gained on
- ItemActivity.data should be removed if not used.
- Subscribes
- - Fix deprecated subscribes
- - http calls don't need to unsubscribe
- - Change one-time subscriptions from unsubscribe to pipe(take(1))
- ngOnInit content can often be moved to constructor
- Replacements within foreach() should be changed to map()
- Create Modal directive that allows modals that don't close when clicking outside
- Improve inventory html with InventoryParameters & ItemParameters
- Apply errata if needed
- Set IconValueOverride for items with multiple subtypes and for items with subtype "Type *"
- Add options to resting: Duration, whether to tick once per day things...
- Implement Bulk Conversions for creature size (p. 295 Core Rulebook) (https://2e.aonprd.com/Rules.aspx?ID=257)
- Change Skilled Heritage from hardcoded skill increase to feat with subfeats?
- Fill out PFS notes for all feats
- Maybe: Move custom content to database, then allow custom content creation in app (very simplified version of the custom item creation).
- Many Activities need conditions (caster conditions at least)
- - Battle Medicine
- Gnome feats
- Hobgoblin feats
- Leshy feats
- Shoony feats
- Implement Conditions for Poisons
- Champion
- Alchemist
- Create better (graphical) item creation tool