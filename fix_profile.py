import re

# Read original to extract SpeciesDetailView
with open('WWFChallenge7/original_profile.swift', 'r') as f:
    orig = f.read()

start_idx = orig.find('private struct SpeciesDetailView: View {')
end_idx = orig.find('private struct UnlockCelebrationView: View {')
if start_idx != -1 and end_idx != -1:
    species_view_code = orig[start_idx:end_idx]
    species_view_code = species_view_code.replace('private struct SpeciesDetailView', 'struct SpeciesDetailView')
else:
    species_view_code = ""

# Read current ProfileView
with open('WWFChallenge7/Features/Profile/ProfileView.swift', 'r') as f:
    content = f.read()

# Fixes
content = content.replace('currentLevel?.localizedTitle ?? localizer.localizedString(for: "explorer")', 'currentLevel?.title ?? localizer.localizedString(for: "explorer")')
content = content.replace('stats?.poisVisited ?? 0', 'stats?.poisVisitedCount ?? 0')
content = content.replace('badge.iconUrl', 'badge.iconName')
content = content.replace('badge.localizedName', 'badge.name')
content = content.replace('species.localizedName', 'species.name')
content = content.replace('WWFDesign.Colors.backgroundMain', 'Color(.systemBackground)')

# Append SpeciesDetailView if it's not already there
if 'struct SpeciesDetailView: View' not in content:
    content += '\n' + species_view_code

with open('WWFChallenge7/Features/Profile/ProfileView.swift', 'w') as f:
    f.write(content)

print("Fixes applied successfully!")
