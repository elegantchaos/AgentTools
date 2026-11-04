// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
//  Created by Sam Deane on 04/11/2026.
//  Copyright © 2026 Elegant Chaos Limited. All rights reserved.
// -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

import ApplicationServices
import Foundation

/// An element of a running application's accessibility hierarchy, read live through the macOS Accessibility API.
///
/// Attributes and children are fetched from the application each time they are read, so a walk sees the interface as
/// it is at that moment. Every call needs the Accessibility permission; without it the API returns nothing.
struct SystemAccessibilityElement: AccessibilityElement {
  /// How long to wait for an application to answer one request, so a hung application cannot stall a walk for long.
  static let messagingTimeout: Float = 2

  /// The underlying element.
  let element: AXUIElement

  /// The attributes `agt ui` reports.
  var attributes: AccessibilityAttributes {
    AccessibilityAttributes(
      role: string(kAXRoleAttribute),
      subrole: string(kAXSubroleAttribute),
      title: string(kAXTitleAttribute),
      value: valueText,
      identifier: string(kAXIdentifierAttribute),
      description: string(kAXDescriptionAttribute),
      enabled: value(kAXEnabledAttribute) as? Bool,
      frame: frame
    )
  }

  /// The child elements.
  var children: [SystemAccessibilityElement] {
    (value(kAXChildrenAttribute) as? [AXUIElement] ?? []).map(SystemAccessibilityElement.init(element:))
  }

  /// Returns the root element of the application with process identifier `pid`, or throws when it cannot be read.
  static func application(processIdentifier pid: pid_t) throws -> SystemAccessibilityElement {
    AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), messagingTimeout)
    let element = SystemAccessibilityElement(element: AXUIElementCreateApplication(pid))
    var role: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element.element, kAXRoleAttribute as CFString, &role)
    guard result == .success else {
      throw ToolError("Could not read the accessibility hierarchy of process \(pid) (AXError \(result.rawValue)).")
    }
    return element
  }

  /// The names of the actions the element supports, such as `AXPress`.
  var actions: [String] {
    var names: CFArray?
    guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
    return names as? [String] ?? []
  }

  /// Whether the element can be given keyboard focus.
  var canFocus: Bool {
    var settable: DarwinBoolean = false
    return AXUIElementIsAttributeSettable(element, kAXFocusedAttribute as CFString, &settable) == .success && settable.boolValue
  }

  /// Whether the element has keyboard focus.
  var isFocused: Bool {
    value(kAXFocusedAttribute) as? Bool ?? false
  }

  /// The frames that clip what is visible of the element: its window's and those of the scroll areas around it.
  var clips: [CGRect] {
    var frames: [CGRect] = []
    var ancestor = parent
    while let current = ancestor {
      if ["AXScrollArea", "AXWindow"].contains(current.string(kAXRoleAttribute)), let frame = current.frame {
        frames.append(frame)
      }
      ancestor = current.parent
    }
    return frames
  }

  /// Makes this application element's application the active one, so that typing goes to it.
  func activateApplication() throws {
    let result = AXUIElementSetAttributeValue(element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
    guard result == .success else {
      throw ToolError("The application could not be brought to the front (AXError \(result.rawValue)).")
    }
  }

  /// Gives the element keyboard focus, returning whether it then reports having it.
  func focus() -> Bool {
    AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue) == .success && isFocused
  }

  /// Performs the element's press action, as a click on it would.
  func press() throws {
    let result = AXUIElementPerformAction(element, kAXPressAction as CFString)
    guard result == .success else {
      throw ToolError("The element did not accept a press (AXError \(result.rawValue)).")
    }
  }
}

extension SystemAccessibilityElement {
  /// The value as text: strings as they are, numbers and booleans in decimal, and `nil` for anything else.
  private var valueText: String? {
    switch value(kAXValueAttribute) {
      case let string as String: string
      case let number as NSNumber: number.stringValue
      default: nil
    }
  }

  /// The frame in screen points, from the position and size attributes.
  var frame: CGRect? {
    var origin = CGPoint.zero
    var size = CGSize.zero
    guard let position = axValue(kAXPositionAttribute), AXValueGetValue(position, .cgPoint, &origin), let extent = axValue(kAXSizeAttribute), AXValueGetValue(extent, .cgSize, &size) else {
      return nil
    }
    return CGRect(origin: origin, size: size)
  }

  /// The element's parent, or `nil` at the top of the hierarchy.
  private var parent: SystemAccessibilityElement? {
    guard let raw = value(kAXParentAttribute), CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
    // The type ID check above makes this cast safe; conditional casts to CF types always succeed.
    return SystemAccessibilityElement(element: unsafeDowncast(raw, to: AXUIElement.self))
  }

  /// Returns the attribute's value, or `nil` when the element does not have it.
  private func value(_ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
    return value
  }

  /// Returns the attribute's value when it is a non-empty string.
  private func string(_ attribute: String) -> String? {
    guard let string = value(attribute) as? String, !string.isEmpty else { return nil }
    return string
  }

  /// Returns the attribute's value when it is an `AXValue`, which wraps a Core Graphics structure.
  private func axValue(_ attribute: String) -> AXValue? {
    guard let raw = value(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    // The type ID check above makes this cast safe; conditional casts to CF types always succeed.
    return unsafeDowncast(raw, to: AXValue.self)
  }
}
