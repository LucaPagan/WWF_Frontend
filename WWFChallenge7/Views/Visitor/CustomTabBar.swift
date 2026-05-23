import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @ObservedObject private var localizer = LocalizationManager.shared
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Green organic hills that embrace the tab buttons
            BottomWavyShape()
                .fill(WWFDesign.Colors.forestMid)
                .frame(height: 140)
                .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: -4)
            
            // Tab buttons — positioned to sit inside the hills
            HStack(spacing: 0) {
                TabBarItem(
                    icon: "map",
                    title: localizer.localizedString(for: "explore"),
                    isSelected: selectedTab == 0
                ) {
                    selectedTab = 0
                }
                
                TabBarItem(
                    icon: "calendar.badge.clock",
                    title: localizer.localizedString(for: "events"),
                    isSelected: selectedTab == 1
                ) {
                    selectedTab = 1
                }
                
                TabBarItem(
                    icon: "person",
                    title: localizer.localizedString(for: "profile"),
                    isSelected: selectedTab == 2
                ) {
                    selectedTab = 2
                }
            }
            .padding(.bottom, 28)
            .padding(.horizontal, 24)
        }
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(WWFDesign.Colors.leafLight)
                            .frame(width: 56, height: 56)
                    }
                    
                    Image(systemName: isSelected ? icon + ".fill" : icon)
                        .font(.system(size: 24, weight: isSelected ? .bold : .regular))
                        .foregroundColor(isSelected ? WWFDesign.Colors.forestDark : .white)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .foregroundColor(isSelected ? .white : .white.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
