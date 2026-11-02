public final class PageFrames {
    private var names: [String] = []

    public init() {}

    public var depth: Int { names.count }

    public func push(_ name: String) {
        names.append(name)
    }

    public func pop() -> String? {
        if depth <= 1 {
            return nil
        }
        return names.removeLast()
    }

    public func drop() -> String? {
        if names.isEmpty {
            return nil
        }
        return names.removeLast()
    }

    public func popTo(_ name: String) -> [String]? {
        guard let index = names.lastIndex(of: name) else {
            return nil
        }
        var removed: [String] = []
        while names.count - 1 > index {
            removed.append(names.removeLast())
        }
        return removed
    }

    public func top() -> String? {
        names.last
    }

    public func clear() -> [String] {
        let remaining = names
        names.removeAll()
        return remaining
    }
}
