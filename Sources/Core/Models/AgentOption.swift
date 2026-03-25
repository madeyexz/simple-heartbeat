import Foundation

public struct AgentOption: Identifiable {
    public var id: String { key }
    public let key: String
    public let label: String
    public let description: String
    public let type: OptionType
    public let defaultValue: String
    public let choices: [String]

    public enum OptionType {
        case text, dropdown, toggle
    }

    public init(
        key: String,
        label: String,
        description: String,
        type: OptionType,
        defaultValue: String,
        choices: [String]
    ) {
        self.key = key
        self.label = label
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
        self.choices = choices
    }
}
