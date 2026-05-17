import csv

mapping = {
    "Fire": ["sunforge_basilica", "emberfault_chasm"],
    "Plant": ["thornfang_warrens", "skytide_reservoir"],
    "Water": ["skytide_reservoir"],
    "Electric": ["stargrave_observatory", "ironhowl_bastion"],
    "Sound": ["echo_vault"],
    "Cosmic": ["stargrave_observatory"],
    "Undead": ["gloomrot_catacombs", "echo_vault"],
    "Holy": ["sunforge_basilica"],
    "Poison": ["thornfang_warrens", "gloomrot_catacombs"],
    "Metal": ["ironhowl_bastion"],
    "Dragon": ["stargrave_observatory", "emberfault_chasm"],
    "Air": ["stargrave_observatory", "skytide_reservoir"],
    "Beast": ["ironhowl_bastion", "thornfang_warrens"],
    "Earth": ["skytide_reservoir", "emberfault_chasm"],
    "Ice": ["skytide_reservoir", "stargrave_observatory"]
}

input_file = "docs/monster_brainstorm_125.csv"
output_file = "docs/monster_brainstorm_125_updated.csv"

with open(input_file, mode="r", encoding="utf-8") as f:
    reader = csv.DictReader(f)
    fieldnames = reader.fieldnames + ["Biome"]
    rows = list(reader)

for row in rows:
    biomes = set()
    e1 = row.get("Element 1", "").strip()
    e2 = row.get("Element 2", "").strip()
    
    if e1 in mapping:
        biomes.update(mapping[e1])
    if e2 in mapping:
        biomes.update(mapping[e2])
    
    row["Biome"] = ", ".join(sorted(list(biomes)))

with open(input_file, mode="w", encoding="utf-8", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(rows)
