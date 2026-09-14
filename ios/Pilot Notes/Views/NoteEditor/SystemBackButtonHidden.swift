//
//  SystemBackButtonHidden.swift
//  Pilot Notes
//
//  Created by Artem Zasypalov on 14.09.26.
//

import SwiftUI

/// `DocumentGroup` hosts its content in a controller whose navigation item carries a `backAction`,
/// so UIKit synthesizes the document back button instead of deriving it from a navigation stack.
/// That makes SwiftUI's `navigationBarBackButtonHidden` a no-op here, and `hidesBackButton` a no-op
/// too - both only govern a real stack back button. Clearing `backAction` removes the button UIKit
/// synthesizes from it; restoring the stashed action brings the button back unchanged.
struct SystemBackButtonHidden: UIViewRepresentable {
    let isHidden: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let item = view.nearestNavigationItem else { return }

        if isHidden {
            context.coordinator.backAction = context.coordinator.backAction ?? item.backAction
            item.backAction = nil
        } else if let backAction = context.coordinator.backAction {
            item.backAction = backAction
            context.coordinator.backAction = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var backAction: UIAction?
    }
}

private extension UIView {
    var nearestNavigationItem: UINavigationItem? {
        var responder: UIResponder? = next
        while let current = responder {
            if let controller = current as? UIViewController {
                return controller.navigationItem
            }
            responder = current.next
        }
        return nil
    }
}
