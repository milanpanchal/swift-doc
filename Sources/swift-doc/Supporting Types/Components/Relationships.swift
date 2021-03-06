import CommonMarkBuilder
import SwiftDoc
import SwiftMarkup
import SwiftSemantics
import Foundation
import HypertextLiteral
import GraphViz
import DOT

extension StringBuilder {
    // MARK: buildIf

    public static func buildIf(_ string: String?) -> String {
        return string ?? ""
    }

    // MARK: buildEither

    public static func buildEither(first: String) -> String {
        return first
    }

    public static func buildEither(second: String) -> String {
        return second
    }
}

struct Relationships: Component {
    var module: Module
    var symbol: Symbol
    var inheritedTypes: [Symbol]

    init(of symbol: Symbol, in module: Module) {
        self.module = module
        self.symbol = symbol
        self.inheritedTypes = module.interface.typesInherited(by: symbol) + module.interface.typesConformed(by: symbol)
    }


    var sections: [(title: String, symbols: [Symbol])] {
        return [
            ("Member Of", [module.interface.relationshipsBySubject[symbol.id]?.filter { $0.predicate == .memberOf }.first?.object].compactMap { $0 }),
            ("Nested Types", module.interface.members(of: symbol).filter { $0.api is Type }),
            ("Superclass", module.interface.typesInherited(by: symbol)),
            ("Subclasses", module.interface.typesInheriting(from: symbol)),
            ("Conforms To", module.interface.typesConformed(by: symbol)),
            ("Types Conforming to <code>\(softbreak(symbol.id.description))</code>", module.interface.typesConforming(to: symbol)),
        ].filter { !$0.symbols.isEmpty }
    }

    // MARK: - Component

    var fragment: Fragment {
        guard !inheritedTypes.isEmpty else { return Fragment { "" } }

        return Fragment {
            Section {
                Heading { "Inheritance" }

                Fragment {
                    #"""
                    \#(inheritedTypes.map { type in
                        if type.api is Unknown {
                            return "`\(type.id)`"
                        } else {
                            return "[`\(type.id)`](\(path(for: type)))"
                        }
                    }.joined(separator: ", "))
                    """#
                }
            }
        }
    }

    var html: HypertextLiteral.HTML {
        var graph = symbol.graph(in: module)
        guard !graph.edges.isEmpty else { return "" }

        graph.aspectRatio = 0.125
        graph.center = true
        graph.overlap = "compress"

        let algorithm: LayoutAlgorithm = graph.nodes.count > 3 ? .neato : .dot
        var svg: HypertextLiteral.HTML?

        do {
            svg = try HypertextLiteral.HTML(String(data: graph.render(using: algorithm, to: .svg), encoding: .utf8) ?? "")
        } catch {
            print(error)
        }

        return #"""
        <section id="relationships">
            <h2 hidden>Relationships</h2>
            <figure>
                \#(svg ?? "")

                <figcaption hidden>Inheritance graph for \#(symbol.id).</figcaption>
            </figure>
                \#(sections.compactMap { (heading, symbols) -> HypertextLiteral.HTML? in
                    guard !symbols.isEmpty else { return nil }

                    let partitioned = symbols.filter { !($0.api is Unknown) } + symbols.filter { ($0.api is Unknown) }

                    return #"""
                    <h3>\#(unsafeUnescaped: heading)</h3>
                    <dl>
                        \#(partitioned.map { symbol -> HypertextLiteral.HTML in
                            let descriptor = String(describing: type(of: symbol.api)).lowercased()
                            if symbol.api is Unknown {
                                return #"""
                                <dt class="\#(descriptor)"><code>\#(symbol.id)</code></dt>
                                """#
                            } else {
                                return #"""
                                <dt class="\#(descriptor)"><code><a href="/\#(path(for: symbol))">\#(symbol.id)</a></code></dt>
                                <dd>\#(commonmark: symbol.documentation?.summary ?? "")</dd>
                                """#
                            }
                        })
                    </dl>
                    """#
                })
        </section>
        """#
    }
}
