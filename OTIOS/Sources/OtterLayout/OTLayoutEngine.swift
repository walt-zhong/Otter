import CoreGraphics
import Foundation
import OtterCore
#if canImport(StretchKit)
import StretchKit
#endif

public struct OTLayoutError: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String {
        message
    }
}

public struct OTLayoutInput {
    public var viewport: CGSize
    public var windowWidth: CGFloat
    public var root: ParsedNode
    public var data: [String: Any]
    public var expression: (Any, Any?) -> Any?

    public init(
        viewport: CGSize,
        windowWidth: CGFloat,
        root: ParsedNode,
        data: [String: Any],
        expression: @escaping (Any, Any?) -> Any?
    ) {
        self.viewport = viewport
        self.windowWidth = windowWidth
        self.root = root
        self.data = data
        self.expression = expression
    }
}

public struct OTLaidOutNode {
    public var viewName: String
    public var id: String
    public var frame: CGRect
    public var fields: [String: String]
    public var children: [OTLaidOutNode]
    public var item: ParsedNode?
    public var listItems: [[String: Any]]
    public var scroll: Bool
    public var glass: Bool

    public init(
        viewName: String,
        id: String,
        frame: CGRect,
        fields: [String: String],
        children: [OTLaidOutNode],
        item: ParsedNode? = nil,
        listItems: [[String: Any]] = [],
        scroll: Bool = false,
        glass: Bool = false
    ) {
        self.viewName = viewName
        self.id = id
        self.frame = frame
        self.fields = fields
        self.children = children
        self.item = item
        self.listItems = listItems
        self.scroll = scroll
        self.glass = glass
    }
}

public enum OTLayoutEngine {
    /// `OTEngine.createNodeTree`: `NodeTreePrepare.create` then `WrapTextHeight.settle`.
    /// Viewport and `windowWidth` are points. Stretch receives points, not pixels.
    public static func layout(_ input: OTLayoutInput) throws -> OTLaidOutNode {
        let windowWidth = Float(input.windowWidth)
        let root = try build(
            input.root,
            parent: nil,
            data: input.data,
            expression: input.expression,
            windowWidthPoints: windowWidth
        )
        try WrapTextHeight.settle(
            root,
            viewport: input.viewport,
            windowWidthPoints: windowWidth,
            expression: input.expression,
            compute: { try compute(root, viewport: input.viewport) }
        )
        return laidOut(root)
    }
}

final class LayoutNode {
    let viewName: String
    let id: String
    let fields: [String: String]
    let stretch: Node
    var children: [LayoutNode] = []
    weak var parent: LayoutNode?
    var item: ParsedNode?
    var listItems: [[String: Any]]
    var scroll: Bool
    var glass: Bool
    var layout: Layout?

    init(
        viewName: String,
        id: String,
        fields: [String: String],
        stretch: Node,
        listItems: [[String: Any]],
        scroll: Bool,
        glass: Bool
    ) {
        self.viewName = viewName
        self.id = id
        self.fields = fields
        self.stretch = stretch
        self.listItems = listItems
        self.scroll = scroll
        self.glass = glass
    }
}

private func build(
    _ node: ParsedNode,
    parent: LayoutNode?,
    data: [String: Any],
    expression: (Any, Any?) -> Any?,
    windowWidthPoints: Float
) throws -> LayoutNode {
    let bound = bindAttributes(
        viewName: node.viewName,
        attrs: node.attrs,
        data: data,
        expression: expression
    )
    let flex = try OTFlexBox.create(
        viewName: node.viewName,
        fields: bound.fields,
        windowWidthPoints: windowWidthPoints
    )
    let layoutNode = LayoutNode(
        viewName: node.viewName,
        id: node.id,
        fields: bound.fields,
        stretch: Node(style: flex.makeStyle(), children: []),
        listItems: bound.listItems,
        scroll: bound.scroll,
        glass: bound.glass
    )
    layoutNode.parent = parent
    // `NodeTreePrepare` keeps the list item template and does not stretch it
    // with the page. Expressions inside the item stay on that template.
    layoutNode.item = node.item
    for child in node.children {
        let childNode = try build(
            child,
            parent: layoutNode,
            data: data,
            expression: expression,
            windowWidthPoints: windowWidthPoints
        )
        layoutNode.children.append(childNode)
        layoutNode.stretch.addChild(childNode.stretch)
    }
    return layoutNode
}

private func compute(_ root: LayoutNode, viewport: CGSize) throws {
    // `Node.safeComputeLayout` subtracts 0.01 so an integer viewport does not
    // collapse nested nodes. StretchKit's `computeLayout` does not.
    let fit = Size<Float?>(
        width: Float(viewport.width) - 0.01,
        height: Float(viewport.height) - 0.01
    )
    try apply(root, root.stretch.computeLayout(thatFits: fit))
}

private func apply(_ node: LayoutNode, _ layout: Layout) throws {
    node.layout = layout
    if layout.children.count != node.children.count {
        throw OTLayoutError(
            "stretch layout child count \(layout.children.count) does not match node \(node.id) children \(node.children.count)"
        )
    }
    for index in node.children.indices {
        try apply(node.children[index], layout.children[index])
    }
}

private func laidOut(_ node: LayoutNode) -> OTLaidOutNode {
    OTLaidOutNode(
        viewName: node.viewName,
        id: node.id,
        frame: frame(from: node.layout),
        fields: node.fields,
        children: node.children.map(laidOut),
        item: node.item,
        listItems: node.listItems,
        scroll: node.scroll,
        glass: node.glass
    )
}

/// `OTEngine.applyLayout` rounds stretch x/y/width/height with `roundToInt`
/// before they become the view frame. Origin stays relative to the parent.
private func frame(from layout: Layout?) -> CGRect {
    guard let layout else {
        return .zero
    }
    return CGRect(
        x: CGFloat(javaRoundToInt(layout.x)),
        y: CGFloat(javaRoundToInt(layout.y)),
        width: CGFloat(javaRoundToInt(layout.width)),
        height: CGFloat(javaRoundToInt(layout.height))
    )
}
