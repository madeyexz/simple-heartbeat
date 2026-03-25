import Foundation

struct AgentOption: Identifiable {
    var id: String { key }
    let key: String
    let label: String
    let description: String
    let type: OptionType
    let defaultValue: String
    let choices: [String]

    enum OptionType {
        case text, dropdown, toggle
    }
}
