import SwiftUI

struct DemoBottomNavigationView: View {
    @Binding var selection: DemoSection

    var body: some View {
        HStack {
            ForEach(DemoSection.allCases) { section in
                Button {
                    selection = section
                } label: {
                    Label(section.title, systemImage: section.systemImage)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == section ? .primary : .secondary)
                .background(
                    selection == section
                        ? Color.accentColor.opacity(0.16)
                        : Color.clear,
                    in: .rect(cornerRadius: 10)
                )
                .accessibilityAddTraits(
                    selection == section ? .isSelected : []
                )
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }
}
