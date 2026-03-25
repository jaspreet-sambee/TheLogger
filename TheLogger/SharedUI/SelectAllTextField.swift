//
//  SelectAllTextField.swift
//  TheLogger
//
//  UITextField-backed field that selects all text on focus
//

import SwiftUI
import UIKit

// MARK: - Select All Text Field
/// UITextField-backed field that selects all on focus. Dismiss via tap-overlay or scroll.
struct SelectAllTextField: UIViewRepresentable {
    @Binding var text: String
    var focusWhenAppear: Bool
    var placeholder: String
    var keyboardType: UIKeyboardType
    var onFocusTriggered: () -> Void
    var onCommit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.keyboardType = keyboardType
        field.borderStyle = .none
        field.backgroundColor = .clear
        field.font = .systemFont(ofSize: 17, weight: .semibold)
        field.textAlignment = .natural
        field.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if focusWhenAppear && !context.coordinator.didTriggerFocus {
            context.coordinator.didTriggerFocus = true
            onFocusTriggered()
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SelectAllTextField
        var didTriggerFocus = false

        init(_ parent: SelectAllTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.text = textField.text ?? ""
            parent.onCommit()
        }
    }
}
