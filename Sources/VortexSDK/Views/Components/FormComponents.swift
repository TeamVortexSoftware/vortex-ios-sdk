import SwiftUI

struct HeadingView: View {
    let block: ElementNode
    
    // Map heading levels to font sizes and weights (matching RN SDK)
    private var headingStyle: (fontSize: CGFloat, fontWeight: Font.Weight, marginBottom: CGFloat) {
        let overrideTagName = block.settings?.overrideTagName ?? "h1"
        switch overrideTagName {
        case "h1": return (24, .bold, 16)
        case "h2": return (20, .bold, 14)
        case "h3": return (18, .semibold, 12)
        case "h4": return (16, .semibold, 10)
        case "h5": return (14, .semibold, 8)
        case "h6": return (12, .semibold, 8)
        default: return (24, .bold, 16)
        }
    }
    
    // Get text alignment from block style
    private var textAlignment: TextAlignment {
        if let textAlign = block.style?["textAlign"] {
            switch textAlign {
            case "center": return .center
            case "right": return .trailing
            default: return .leading
            }
        }
        return .leading
    }
    
    // Get frame alignment from block style
    private var frameAlignment: Alignment {
        if let textAlign = block.style?["textAlign"] {
            switch textAlign {
            case "center": return .center
            case "right": return .trailing
            default: return .leading
            }
        }
        return .leading
    }
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.system(size: headingStyle.fontSize, weight: headingStyle.fontWeight))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
                .padding(.horizontal)
                .padding(.bottom, headingStyle.marginBottom)
        }
    }
}

// MARK: - Text View

struct TextView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(6) // Approximates lineHeight: 20 with fontSize 14
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal)
        }
    }
}

// MARK: - Form Label View

struct FormLabelView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal)
        }
    }
}

// MARK: - Image View

struct ImageView: View {
    let block: ElementNode
    
    var body: some View {
        if let src = block.attributes?["src"]?.stringValue, let url = URL(string: src) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure:
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                @unknown default:
                    EmptyView()
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Link View

struct LinkView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Button(action: {
                if let action = block.settings?.action,
                   action.type == "openWebsite",
                   let urlString = action.value,
                   let url = URL(string: urlString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .underline()
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Button View

struct ButtonView: View {
    let block: ElementNode
    
    var body: some View {
        let variant = block.attributes?["variant"]?.stringValue ?? "secondary"
        let isPrimary = variant == "primary"
        
        Button(action: {
            if let action = block.settings?.action {
                handleAction(action)
            }
        }) {
            Text(block.textContent ?? "Button")
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isPrimary ? Color.blue : Color(UIColor.secondarySystemBackground))
                .foregroundColor(isPrimary ? .white : .primary)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    private func handleAction(_ action: NodeAction) {
        switch action.type {
        case "openWebsite":
            if let urlString = action.value, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        default:
            print("[VortexSDK] Warning: Button action type '\(action.type)' is not yet supported in iOS SDK")
        }
    }
}

// MARK: - Divider View

struct DividerView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent, !text.isEmpty {
            // Divider with text
            HStack {
                Rectangle()
                    .fill(Color(UIColor.separator))
                    .frame(height: 1)
                Text(text)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color(UIColor.separator))
                    .frame(height: 1)
            }
            .padding(.horizontal)
        } else {
            // Simple divider
            Divider()
                .padding(.horizontal)
        }
    }
}

// MARK: - Menu View

struct MenuView: View {
    let block: ElementNode
    
    var body: some View {
        let direction = block.attributes?["direction"]?.stringValue ?? "horizontal"
        let divider = block.attributes?["divider"]?.stringValue ?? " | "
        let options = block.settings?.options ?? []
        
        if direction == "vertical" {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(options, id: \.id) { option in
                    menuItem(option)
                }
            }
            .padding(.horizontal)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    menuItem(option)
                    if index < options.count - 1 {
                        Text(divider)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func menuItem(_ option: ElementOption) -> some View {
        Button(action: {
            if let action = option.action {
                handleAction(action)
            }
        }) {
            Text(option.textContent ?? option.label ?? "")
                .font(.system(size: 14))
                .foregroundColor(.blue)
        }
    }
    
    private func handleAction(_ action: NodeAction) {
        switch action.type {
        case "openWebsite":
            if let urlString = action.value, let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        default:
            print("[VortexSDK] Warning: Menu action type '\(action.type)' is not yet supported in iOS SDK")
        }
    }
}

// MARK: - Layout Views

struct RootView<Content: View>: View {
    let block: ElementNode
    let renderBlock: (ElementNode) -> Content
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(block.children ?? [], id: \.id) { child in
                renderBlock(child)
            }
        }
    }
}

struct RowLayoutView<Content: View>: View {
    let block: ElementNode
    let renderBlock: (ElementNode) -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(block.children ?? [], id: \.id) { child in
                renderBlock(child)
            }
        }
    }
}

struct ColumnView<Content: View>: View {
    let block: ElementNode
    let renderBlock: (ElementNode) -> Content
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(block.children ?? [], id: \.id) { child in
                renderBlock(child)
            }
        }
    }
}

struct RowView<Content: View>: View {
    let block: ElementNode
    let renderBlock: (ElementNode) -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(block.children ?? [], id: \.id) { child in
                renderBlock(child)
            }
        }
    }
}

// MARK: - Form Element Views

struct TextboxView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    @State private var text: String = ""
    
    private var fieldName: String {
        block.attributes?["name"]?.stringValue ?? block.id
    }
    
    private var label: String? {
        block.attributes?["label"]?.stringValue
    }
    
    private var placeholder: String {
        block.attributes?["placeholder"]?.stringValue ?? ""
    }
    
    private var hint: String? {
        block.attributes?["hint"]?.stringValue
    }
    
    private var isRequired: Bool {
        block.attributes?["required"]?.stringValue == "true"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text) { newValue in
                    viewModel.setFormFieldValue(fieldName, value: newValue)
                }
            
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            text = viewModel.getFormFieldValue(fieldName) ?? ""
        }
    }
}

struct TextareaView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    @State private var text: String = ""
    
    private var fieldName: String {
        block.attributes?["name"]?.stringValue ?? block.id
    }
    
    private var label: String? {
        block.attributes?["label"]?.stringValue
    }
    
    private var placeholder: String {
        block.attributes?["placeholder"]?.stringValue ?? ""
    }
    
    private var hint: String? {
        block.attributes?["hint"]?.stringValue
    }
    
    private var isRequired: Bool {
        block.attributes?["required"]?.stringValue == "true"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            TextEditor(text: $text)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(UIColor.separator), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if text.isEmpty {
                            Text(placeholder)
                                .foregroundColor(Color(UIColor.placeholderText))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                    },
                    alignment: .topLeading
                )
                .onChange(of: text) { newValue in
                    viewModel.setFormFieldValue(fieldName, value: newValue)
                }
            
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            text = viewModel.getFormFieldValue(fieldName) ?? ""
        }
    }
}

struct SelectView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    @State private var selectedValue: String = ""
    
    private var fieldName: String {
        block.attributes?["name"]?.stringValue ?? block.id
    }
    
    private var label: String? {
        block.attributes?["label"]?.stringValue
    }
    
    private var hint: String? {
        block.attributes?["hint"]?.stringValue
    }
    
    private var isRequired: Bool {
        block.attributes?["required"]?.stringValue == "true"
    }
    
    private var options: [ElementOption] {
        block.settings?.options ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label = label {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            Menu {
                ForEach(options, id: \.id) { option in
                    Button(action: {
                        selectedValue = option.value ?? ""
                        viewModel.setFormFieldValue(fieldName, value: selectedValue)
                    }) {
                        Text(option.label ?? option.value ?? "")
                    }
                }
            } label: {
                HStack {
                    Text(selectedValue.isEmpty ? "Select..." : (options.first { $0.value == selectedValue }?.label ?? selectedValue))
                        .foregroundColor(selectedValue.isEmpty ? Color(UIColor.placeholderText) : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
            }
            
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            selectedValue = viewModel.getFormFieldValue(fieldName) ?? ""
        }
    }
}

struct RadioView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    @State private var selectedValue: String = ""
    
    private var fieldName: String {
        block.attributes?["name"]?.stringValue ?? block.id
    }
    
    private var label: String? {
        block.attributes?["label"]?.stringValue
    }
    
    private var hint: String? {
        block.attributes?["hint"]?.stringValue
    }
    
    private var isRequired: Bool {
        block.attributes?["required"]?.stringValue == "true"
    }
    
    private var options: [ElementOption] {
        block.settings?.options ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            ForEach(options, id: \.id) { option in
                Button(action: {
                    selectedValue = option.value ?? ""
                    viewModel.setFormFieldValue(fieldName, value: selectedValue)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedValue == option.value ? "circle.inset.filled" : "circle")
                            .foregroundColor(selectedValue == option.value ? .blue : .secondary)
                        Text(option.label ?? option.value ?? "")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            selectedValue = viewModel.getFormFieldValue(fieldName) ?? ""
        }
    }
}

struct CheckboxView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    @State private var selectedValues: Set<String> = []
    
    private var fieldName: String {
        block.attributes?["name"]?.stringValue ?? block.id
    }
    
    private var label: String? {
        block.attributes?["label"]?.stringValue
    }
    
    private var hint: String? {
        block.attributes?["hint"]?.stringValue
    }
    
    private var isRequired: Bool {
        block.attributes?["required"]?.stringValue == "true"
    }
    
    private var options: [ElementOption] {
        block.settings?.options ?? []
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label = label {
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 14, weight: .medium))
                    if isRequired {
                        Text("*")
                            .foregroundColor(.red)
                    }
                }
            }
            
            ForEach(options, id: \.id) { option in
                Button(action: {
                    let value = option.value ?? ""
                    if selectedValues.contains(value) {
                        selectedValues.remove(value)
                    } else {
                        selectedValues.insert(value)
                    }
                    viewModel.setFormFieldValue(fieldName, value: Array(selectedValues).joined(separator: ","))
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: selectedValues.contains(option.value ?? "") ? "checkmark.square.fill" : "square")
                            .foregroundColor(selectedValues.contains(option.value ?? "") ? .blue : .secondary)
                        Text(option.label ?? option.value ?? "")
                            .foregroundColor(.primary)
                        Spacer()
                    }
                }
            }
            
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .onAppear {
            if let stored = viewModel.getFormFieldValue(fieldName) {
                selectedValues = Set(stored.split(separator: ",").map(String.init))
            }
        }
    }
}

struct SubmitButtonView: View {
    let block: ElementNode
    @ObservedObject var viewModel: VortexInviteViewModel
    
    private var variant: String {
        block.attributes?["variant"]?.stringValue ?? "primary"
    }
    
    private var isPrimary: Bool {
        variant == "primary"
    }
    
    var body: some View {
        Button(action: {
            Task {
                await viewModel.sendInvitation()
            }
        }) {
            HStack {
                if viewModel.isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: isPrimary ? .white : .primary))
                } else {
                    Text(block.textContent ?? "Submit")
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isPrimary ? Color.blue : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isPrimary ? .white : .primary)
            .cornerRadius(10)
        }
        .disabled(viewModel.isSending)
        .padding(.horizontal)
    }
}

// MARK: - Autojoin View

struct AutojoinView: View {
    let block: ElementNode
    
    var body: some View {
        if let text = block.textContent {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Color(UIColor.label))
                .padding(.horizontal)
        }
    }
}

// MARK: - Unsupported Element View

struct UnsupportedElementView: View {
    let block: ElementNode
    let reason: String
    
    init(block: ElementNode, reason: String) {
        self.block = block
        self.reason = reason
        // Log warning to console
        print("[VortexSDK] Warning: Element '\(block.subtype ?? "unknown")' (id: \(block.id)) - \(reason)")
    }
    
    var body: some View {
        // Return empty view but warning was logged in init
        EmptyView()
    }
}

// MARK: - Share Button Component
