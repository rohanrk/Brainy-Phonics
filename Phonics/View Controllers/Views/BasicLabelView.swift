//
//  LabelView.swift
//  Phonics
//
//  Created by Cal Stephens on 6/24/17.
//  Copyright © 2017 Cal Stephens. All rights reserved.
//

import UIKit

class BasicLabelView: UIView {
    
    private let label: UILabel
    
    var text: String? {
        set {
            self.label.text = newValue
        }
        get {
            return self.label.text
        }
    }
    
    init(with text: String, font: UIFont, frame: CGRect = .zero) {
        label = UILabel()
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setUpLabel(with: text, font: font)
    }
    
    required init?(coder aDecoder: NSCoder) {
        label = UILabel()
        super.init(coder: aDecoder)
        translatesAutoresizingMaskIntoConstraints = false
        setUpLabel(with: "", font: UIFont.comicSans)
    }
    
    private func setUpLabel(with text: String, font: UIFont) {
        addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.constraintInCenterOfSuperview()
        label.text = text
        label.font = font
        label.clipsToBounds = false
        label.layer.masksToBounds = false
        
        label.numberOfLines = 0
    }
    
    // Method that allows editing the private label
    func editLabelFont(font: UIFont) {
        self.label.font = font
    }
    
}

extension UIView {
    
    typealias Constraints = (
        centerX: NSLayoutConstraint,
        centerY: NSLayoutConstraint,
        leading: NSLayoutConstraint,
        trailing: NSLayoutConstraint,
        top: NSLayoutConstraint,
        bottom: NSLayoutConstraint
    )
    
    @discardableResult
    func constraintInCenterOfSuperview(requireHugging: Bool = true) -> Constraints? {
        guard let superview = superview else {
            return nil
        }
        
        let centerX = self.centerXAnchor.constraint(equalTo: superview.centerXAnchor)
        let centerY = self.centerYAnchor.constraint(equalTo: superview.centerYAnchor)
        let leading = self.leadingAnchor.constraint(greaterThanOrEqualTo: superview.leadingAnchor)
        let trailing = self.trailingAnchor.constraint(lessThanOrEqualTo: superview.trailingAnchor)
        let top = self.topAnchor.constraint(greaterThanOrEqualTo: superview.topAnchor)
        let bottom = self.bottomAnchor.constraint(lessThanOrEqualTo: superview.bottomAnchor)
        
        for constraint in [centerX, centerY, leading, trailing, top, bottom] {
            constraint.isActive = true
        }
        
        if requireHugging {
            self.setContentHuggingPriority(.required, for: .vertical)
            self.setContentHuggingPriority(.required, for: .horizontal)
        }
        
        return (
            centerX: centerX,
            centerY: centerY,
            leading: leading,
            trailing: trailing,
            top: top,
            bottom: bottom
        )
    }
    
}
