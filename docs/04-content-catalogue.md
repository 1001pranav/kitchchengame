# 04 — Content Catalogue

Source tables for the content JSON files (schemas in `03-data-schemas.md`). Convert each
table row to one JSON object; do not add, rename or drop rows without updating this file.
Display names are English reference text — in JSON store a string key and put the text
in `strings_en.json`.

---

## 1. Ingredients (`ingredients.json`) — 43 rows

One **unit** is roughly one portion's worth of that ingredient.

| id | name | category | storage | shelf (days) | baseCost |
|---|---|---|---|---|---|
| ing_flour | Flour | dry | dry | 60 | 0.30 |
| ing_rice | Rice | dry | dry | 90 | 0.30 |
| ing_pasta | Dry pasta | dry | dry | 90 | 0.50 |
| ing_noodles | Noodles | dry | dry | 60 | 0.50 |
| ing_oil | Cooking oil | dry | dry | 90 | 0.30 |
| ing_sugar | Sugar | dry | dry | 120 | 0.20 |
| ing_beans | Dried beans & lentils | dry | dry | 120 | 0.40 |
| ing_spice | Spice mix | dry | dry | 120 | 0.60 |
| ing_soy | Soy sauce | dry | dry | 120 | 0.40 |
| ing_canned_tomato | Canned tomato | dry | dry | 120 | 0.60 |
| ing_tortilla | Corn tortillas | dry | dry | 7 | 0.40 |
| ing_chocolate | Chocolate | dry | dry | 90 | 1.20 |
| ing_tea_coffee | Tea & coffee | dry | dry | 120 | 0.40 |
| ing_onion | Onion | produce | dry | 14 | 0.30 |
| ing_garlic_ginger | Garlic & ginger | produce | dry | 14 | 0.40 |
| ing_potato | Potato | produce | dry | 14 | 0.30 |
| ing_tomato | Tomato | produce | chilled | 5 | 0.60 |
| ing_greens | Leafy greens | produce | chilled | 3 | 0.70 |
| ing_pepper | Bell pepper | produce | chilled | 6 | 0.70 |
| ing_chilli | Chilli | produce | chilled | 7 | 0.40 |
| ing_mushroom | Mushroom | produce | chilled | 4 | 0.90 |
| ing_herbs | Fresh herbs | produce | chilled | 3 | 0.80 |
| ing_citrus | Lemon & lime | produce | chilled | 10 | 0.40 |
| ing_avocado | Avocado | produce | chilled | 4 | 1.40 |
| ing_mixed_veg | Mixed vegetables | produce | chilled | 5 | 0.60 |
| ing_cream | Milk & cream | dairy | chilled | 5 | 0.70 |
| ing_butter | Butter & ghee | dairy | chilled | 21 | 0.90 |
| ing_cheese | Hard cheese | dairy | chilled | 14 | 1.30 |
| ing_mozzarella | Mozzarella | dairy | chilled | 7 | 1.50 |
| ing_paneer | Paneer | dairy | chilled | 6 | 1.40 |
| ing_yogurt | Yogurt | dairy | chilled | 7 | 0.60 |
| ing_eggs | Eggs | dairy | chilled | 14 | 0.40 |
| ing_tofu | Tofu | dairy | chilled | 6 | 0.90 |
| ing_chicken | Chicken | meat_fish | chilled | 3 | 2.00 |
| ing_beef | Beef | meat_fish | chilled | 3 | 3.20 |
| ing_pork | Pork | meat_fish | chilled | 3 | 2.40 |
| ing_lamb | Lamb | meat_fish | chilled | 3 | 3.40 |
| ing_fish | Fish | meat_fish | chilled | 2 | 3.00 |
| ing_cured_meat | Cured meat | meat_fish | chilled | 21 | 2.20 |
| ing_prawns | Prawns | frozen | frozen | 30 | 3.60 |
| ing_wrappers | Dumpling wrappers | frozen | frozen | 60 | 0.50 |
| ing_ice_cream | Ice cream | frozen | frozen | 60 | 1.00 |
| ing_fries | Frozen fries | frozen | frozen | 60 | 0.50 |

## 2. Dishes (`dishes.json`) — 12 per theme

Recipe notation: `ingredient×qty` (drop the `ing_` prefix here only; JSON uses full ids).
`basePrice` is derived at load (doc 03 §1.3). Popularity is 1.0 unless stated.

### 2.1 Italian — stations: stove, oven, cold

| id | name | course | station | prep | skill | recipe |
|---|---|---|---|---|---|---|
| dish_it_bruschetta | Bruschetta | starter | cold | 2 | 20 | flour×1, tomato×1, herbs×1, garlic_ginger×1 |
| dish_it_caprese | Caprese salad | starter | cold | 2 | 15 | mozzarella×1, tomato×1, herbs×1 |
| dish_it_minestrone | Minestrone | starter | stove | 4 | 30 | mixed_veg×2, canned_tomato×1, pasta×1, onion×1 |
| dish_it_margherita | Margherita pizza | main | oven | 6 | 40 | flour×2, canned_tomato×1, mozzarella×2, herbs×1 (popularity 1.3) |
| dish_it_salami_pizza | Salami pizza | main | oven | 6 | 40 | flour×2, canned_tomato×1, mozzarella×2, cured_meat×1 (popularity 1.2) |
| dish_it_bolognese | Spaghetti bolognese | main | stove | 6 | 45 | pasta×2, beef×1, canned_tomato×1, onion×1 |
| dish_it_risotto | Mushroom risotto | main | stove | 8 | 65 | rice×2, mushroom×2, butter×1, cheese×1, onion×1 |
| dish_it_baked_fish | Baked fish with lemon | main | oven | 7 | 60 | fish×1, citrus×1, herbs×1, potato×1 (popularity 0.8) |
| dish_it_garlic_bread | Garlic bread | side | oven | 3 | 15 | flour×1, butter×1, garlic_ginger×1 |
| dish_it_salad | Green salad | side | cold | 2 | 10 | greens×2, citrus×1 |
| dish_it_tiramisu | Tiramisu | dessert | cold | 2 | 50 | cream×2, eggs×1, tea_coffee×1, sugar×1 |
| dish_it_espresso | Espresso | drink | cold | 1 | 10 | tea_coffee×1 |

### 2.2 Chinese — stations: wok, fryer, stove

| id | name | course | station | prep | skill | recipe |
|---|---|---|---|---|---|---|
| dish_cn_spring_rolls | Spring rolls | starter | fryer | 3 | 25 | wrappers×2, mixed_veg×1, oil×1 |
| dish_cn_dumplings | Steamed dumplings | starter | stove | 4 | 40 | wrappers×2, pork×1, garlic_ginger×1 |
| dish_cn_hot_sour_soup | Hot and sour soup | starter | stove | 4 | 35 | tofu×1, mushroom×1, eggs×1, soy×1 |
| dish_cn_fried_rice | Chicken fried rice | main | wok | 4 | 35 | rice×2, chicken×1, eggs×1, soy×1 (popularity 1.3) |
| dish_cn_chow_mein | Vegetable chow mein | main | wok | 4 | 35 | noodles×2, mixed_veg×2, soy×1 |
| dish_cn_kung_pao | Kung pao chicken | main | wok | 5 | 50 | chicken×2, chilli×1, pepper×1, soy×1 (popularity 1.2) |
| dish_cn_sweet_sour_pork | Sweet and sour pork | main | fryer | 6 | 50 | pork×2, pepper×1, sugar×1, oil×1 |
| dish_cn_mapo_tofu | Mapo tofu | main | wok | 5 | 55 | tofu×2, pork×1, chilli×1, spice×1 (popularity 0.8) |
| dish_cn_steamed_rice | Steamed rice | side | stove | 2 | 10 | rice×2 |
| dish_cn_greens | Stir-fried greens | side | wok | 3 | 25 | greens×2, garlic_ginger×1 |
| dish_cn_fried_ice_cream | Fried ice cream | dessert | fryer | 3 | 40 | ice_cream×1, flour×1, oil×1 |
| dish_cn_jasmine_tea | Jasmine tea | drink | stove | 1 | 10 | tea_coffee×1 |

### 2.3 Mexican — stations: grill, fryer, stove, cold

| id | name | course | station | prep | skill | recipe |
|---|---|---|---|---|---|---|
| dish_mx_guacamole | Guacamole and chips | starter | cold | 2 | 20 | avocado×2, tomato×1, citrus×1, tortilla×1 |
| dish_mx_nachos | Nachos | starter | fryer | 3 | 20 | tortilla×2, cheese×1, chilli×1, beans×1 (popularity 1.2) |
| dish_mx_tortilla_soup | Tortilla soup | starter | stove | 4 | 30 | canned_tomato×1, tortilla×1, chicken×1, chilli×1 |
| dish_mx_chicken_tacos | Chicken tacos | main | grill | 4 | 35 | tortilla×2, chicken×1, onion×1, herbs×1 (popularity 1.3) |
| dish_mx_burrito | Beef burrito | main | grill | 5 | 40 | flour×2, beef×1, rice×1, beans×1, cheese×1 (popularity 1.2) |
| dish_mx_quesadilla | Cheese quesadilla | main | grill | 4 | 30 | flour×2, cheese×2, pepper×1 |
| dish_mx_fish_tacos | Fish tacos | main | fryer | 5 | 45 | tortilla×2, fish×1, greens×1, citrus×1 (popularity 0.8) |
| dish_mx_chilli | Chilli con carne | main | stove | 7 | 50 | beef×2, beans×1, canned_tomato×1, spice×1 |
| dish_mx_rice | Mexican rice | side | stove | 3 | 20 | rice×2, canned_tomato×1 |
| dish_mx_beans | Refried beans | side | stove | 3 | 20 | beans×2, onion×1 |
| dish_mx_churros | Churros | dessert | fryer | 3 | 35 | flour×1, sugar×1, chocolate×1, oil×1 |
| dish_mx_agua_fresca | Lime agua fresca | drink | cold | 1 | 10 | citrus×2, sugar×1 |

### 2.4 Indian — stations: tandoor, stove, fryer

| id | name | course | station | prep | skill | recipe |
|---|---|---|---|---|---|---|
| dish_in_samosa | Samosa | starter | fryer | 3 | 30 | flour×1, potato×1, spice×1, oil×1 (popularity 1.2) |
| dish_in_paneer_tikka | Paneer tikka | starter | tandoor | 5 | 45 | paneer×2, yogurt×1, pepper×1, spice×1 |
| dish_in_dal_soup | Lentil soup | starter | stove | 4 | 25 | beans×2, onion×1, spice×1 |
| dish_in_butter_chicken | Butter chicken | main | stove | 6 | 55 | chicken×2, canned_tomato×1, butter×1, cream×1, spice×1 (popularity 1.3) |
| dish_in_tandoori_chicken | Tandoori chicken | main | tandoor | 7 | 50 | chicken×2, yogurt×1, spice×1, citrus×1 |
| dish_in_palak_paneer | Palak paneer | main | stove | 5 | 45 | paneer×2, greens×2, garlic_ginger×1, spice×1 |
| dish_in_biryani | Lamb biryani | main | stove | 9 | 70 | rice×2, lamb×2, onion×1, yogurt×1, spice×1 (popularity 1.2) |
| dish_in_chana_masala | Chana masala | main | stove | 5 | 35 | beans×2, tomato×1, onion×1, spice×1 (popularity 0.8) |
| dish_in_naan | Naan | side | tandoor | 2 | 30 | flour×2, butter×1 (popularity 1.3) |
| dish_in_jeera_rice | Jeera rice | side | stove | 2 | 15 | rice×2, spice×1 |
| dish_in_gulab_jamun | Gulab jamun | dessert | fryer | 3 | 40 | cream×1, flour×1, sugar×2 |
| dish_in_chai | Masala chai | drink | stove | 1 | 10 | tea_coffee×1, cream×1 |

## 3. Equipment (`equipment.json`)

| type | name | kind | station / storage | slots / capacity | price | wearPerDay |
|---|---|---|---|---|---|---|
| eq_range | Range | station | stove | 4 | 6,000 | 0.5 |
| eq_oven | Oven | station | oven | 3 | 5,000 | 0.4 |
| eq_fryer | Deep fryer | station | fryer | 2 | 3,000 | 0.6 |
| eq_grill | Grill | station | grill | 3 | 4,000 | 0.5 |
| eq_wok | Wok burner | station | wok | 3 | 3,500 | 0.5 |
| eq_tandoor | Tandoor | station | tandoor | 2 | 4,500 | 0.4 |
| eq_fridge | Refrigerator | storage | chilled | 1,000 | 4,000 | 0.3 |
| eq_freezer | Freezer | storage | frozen | 400 | 3,500 | 0.3 |
| eq_shelving | Dry store shelving | storage | dry | 1,500 | 800 | 0.05 |
| eq_dish_machine | Dish machine | support | — | — | 3,000 | 0.5 |
| eq_hood | Exhaust hood | support | — | — | 2,500 | 0.3 |
| eq_pos | Till / POS | support | — | — | 1,500 | 0.2 |
| eq_ac | Air conditioning | support | — | — | 3,000 | 0.3 |
| eq_generator | Generator | support | — | — | 4,000 | 0.1 |

**Starting equipment** = theme base set × tier scale. Every restaurant has 1 each of
fridge, freezer, shelving, dish machine, hood, POS, AC (Bad and Worst have no AC;
only Excellent and Best have a generator). Excellent and Best get a second fridge.

| Theme | Base station set | Excellent adds |
|---|---|---|
| Italian | range ×1, oven ×1 | range ×1, oven ×1 |
| Chinese | wok ×1, fryer ×1, range ×1 | wok ×1, fryer ×1 |
| Mexican | grill ×1, fryer ×1, range ×1 | grill ×1, range ×1 |
| Indian | tandoor ×1, range ×1, fryer ×1 | tandoor ×1, range ×1 |

Best gets the first item of the "Excellent adds" column only. In Worst, one random
station unit starts `broken`.

## 4. Suppliers (`suppliers.json`)

| id | name | categories | priceMult | quality | reliability | minOrder | leadDays | creditDays |
|---|---|---|---|---|---|---|---|---|
| sup_budget | Budget Wholesale | all | 0.85 | 50 | 0.80 | 300 | 1 | 0 |
| sup_standard | City Foodservice | all | 1.00 | 65 | 0.93 | 200 | 1 | 7 |
| sup_premium | Premium Provisions | all | 1.25 | 85 | 0.97 | 150 | 1 | 14 |
| sup_farm | Farm Direct | produce, dairy | 0.95 | 85 | 0.85 | 100 | 1 | 0 |
| sup_butcher | Butcher & Fishmonger | meat_fish | 1.10 | 90 | 0.95 | 100 | 1 | 7 |
| sup_cash_carry | Cash & Carry | all | 1.15 | 60 | 1.00 | 0 | 0 | 0 |

`leadDays = 0` means the goods arrive immediately when ordered during prep (an emergency
top-up); it cannot be used during service or close.

## 5. Staff traits (`traits.json`)

Modifier keys are a fixed list; the sim reads each key where the listed rule applies.

| id | name | modifiers | effect |
|---|---|---|---|
| trait_mentor | Mentor | `sameRoleSkillBonus: 3` | Others in the same role work at +3 skill while this person is working |
| trait_hot_headed | Hot-headed | `conflictWeight: 2` | Doubles weight of conflict incidents involving them |
| trait_often_late | Often late | `lateMult: 2` | pLate ×2 |
| trait_perfectionist | Perfectionist | `qualityBonus: 5, durationMult: 1.1` | Better food, slower |
| trait_ambitious | Ambitious | `raiseExpectWeeks: 8` | Morale −1/day after 8 weeks without raise or promotion |
| trait_toxic | Toxic | `othersMoraleDaily: -1` | Everyone else working that day −1 morale |
| trait_loyal | Loyal | `quitMult: 0.5` | Half as likely to quit |
| trait_light_fingered | Light-fingered | `honestyCap: 30` | Honesty never above 30 |
| trait_fast_learner | Fast learner | `trainingMult: 1.5` | Training gains ×1.5 |
| trait_hard_worker | Hard worker | `fatigueMult: 0.7` | Gains fatigue more slowly |
| trait_clumsy | Clumsy | `mishapChance: 0.01` | 1% per task to add 3 ticks |
| trait_charming | Charming (server/cashier) | `tipMult: 1.25` | Groups they billed tip 25% more |

Generation: 50% of staff have 0 traits, 40% have 1, 10% have 2. `trait_toxic` and
`trait_mentor` never appear together. Worst-tier staff always include one `trait_toxic`
or `trait_hot_headed` member.

## 6. Tier staff rosters (`tiers.json`)

| Tier | Roles |
|---|---|
| Excellent (12) | headChef, lineCook ×3, prepCook, dishwasher, server ×4, cashier, cleaner |
| Best (10) | headChef, lineCook ×2, prepCook, dishwasher, server ×3, cashier, cleaner |
| Good (8) | headChef, lineCook ×2, dishwasher, server ×2, cashier, cleaner |
| Bad (7) | headChef, lineCook, dishwasher, server ×2, cashier, cleaner |
| Worst (6) | headChef, lineCook, dishwasher, server ×2, cashier |

Staff stats: skill uniform in the tier's range; reliability and loyalty = tier morale
±20; honesty uniform 30–95 (hidden problems may override one person); wage =
`expectedWage` × (1.1 for Excellent, 1.0 Best/Good, 0.9 Bad, 0.85 Worst); fatigue 20.
Default rota: everyone works 6 days, day off assigned round-robin Mon–Thu so no role is
empty on Fri–Sun where avoidable.

Starting stock: enough of every menu ingredient for 1.5 forecast days, with `daysLeft`
uniform between 1 and shelf life. Worst tier: 0.5 days and 30% of chilled batches at 1 day left.

## 7. Festivals (per theme, in `themes.json`)

Each theme has 3 festivals of 2–3 days with `demandMult` 1.3–1.6 and a matching leave-request
incident (`inc_festival_leave`). Names are fictional/generic ("Harvest Week", "Lantern
Nights", "Spring Fair") so nothing depends on real calendars. A fourth, shared event
"New Year" (month 12, days 27–28, ×1.5) exists in all themes.

## 8. Stage objectives (`objectives.json`)

| id | stage | objective | reward |
|---|---|---|---|
| obj_1_first_profit | 1 | Finish a day with positive profit | 500 coins |
| obj_1_full_rota | 1 | Run a service with no role uncovered and owner idle ≥ 50% | Unlock auto-run tutorial tip |
| obj_1_clear_problems | 1 | Resolve all hidden problems | Reputation +0.1 |
| obj_1_no_waste | 1 | A week with waste cost < 3% of revenue | 1,000 coins |
| obj_2_inspection_a | 2 | Pass an inspection with hygiene ≥ 90 | Reputation +0.2 |
| obj_2_four_star | 2 | Reach reputation 4.0 | 2,000 coins |
| obj_2_train_chef | 2 | Promote a line cook you trained to head chef | Staff loyalty +10 (all) |
| obj_2_week_off | 2 | Owner rests 2 days in a week and the week is still profitable | Unlock manager applicants early |
| obj_3_second_profit | 3 | Second location profitable 4 weeks in a row | 5,000 coins |
| obj_3_hands_off | 3 | A full week with zero owner floor tasks at any location | Credit score +10 |
| obj_4_bulk | 4 | Sign a bulk contract covering 3 locations | Ingredient costs −3% permanently |
| obj_4_brand_45 | 4 | Brand reputation ≥ 4.5 | Valuation multiplier 40 → 45 |
| obj_5_second_brand | 5 | Second brand reaches 3 locations | Ending unlocked |
