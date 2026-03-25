//
//  SetInputTextField.swift
//  TheLogger
//
//  UITextField with toolbar above keyboard: [Done] dismisses keyboard, [Log Set] saves set
//

import SwiftUI
import UIKit

// MARK: - Set Input Text Field with Log Set Keyboard Accessory
/// UITextField with toolbar above keyboard: [Done] dismisses keyboard, [Log Set] saves set.
/// Eliminates the need to tap outside and then tap checkmark when using numberPad/decimalPad.
struct SetInputTextFieldWithAccessory: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    var focusWhenAppear: Bool
    var onDismissKeyboard: () -> Void
    var onLogSet: () -> Void

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

        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.sizeToFit()
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        let logSetButton = UIBarButtonItem(title: "Log Set", style: .done, target: context.coordinator, action: #selector(Coordinator.logSetTapped))
        let spacer = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        toolbar.items = [doneButton, spacer, logSetButton]
        field.inputAccessoryView = toolbar

        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        if !focusWhenAppear {
            context.coordinator.didTriggerFocus = false
        }
        if focusWhenAppear && !context.coordinator.didTriggerFocus {
            context.coordinator.didTriggerFocus = true
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
                uiView.selectAll(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SetInputTextFieldWithAccessory
        var didTriggerFocus = false

        init(_ parent: SetInputTextFieldWithAccessory) {
            self.parent = parent
        }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            parent.onDismissKeyboard()
        }

        @objc func logSetTapped() {
            parent.onLogSet()  // Save first; parent may refocus for next set (no dismiss)
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            DispatchQueue.main.async {
                textField.selectAll(nil)
            }
        }
    }
}
