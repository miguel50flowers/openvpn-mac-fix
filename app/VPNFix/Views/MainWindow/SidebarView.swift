import SwiftUI

struct SidebarView: View {
    @Binding var selection: SidebarItem?
    @State private var helperActive: Bool = false
    @State private var helperLabel: String = "Checking..."

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarSection.allCases, id: \.self) { section in
                Section(section.rawValue) {
                    ForEach(SidebarItem.items(for: section)) { item in
                        Label(item.label, systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(helperActive ? .green : .orange)
                Text(helperLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            let status = HelperInstaller.shared.checkStatus()
            helperActive = status.isActive
            helperLabel = status.label
        }
    }
}
