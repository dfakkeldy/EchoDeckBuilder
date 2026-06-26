import Foundation

public struct GenerationBatcher: Sendable {
    public init() {}

    public func batches(from sections: [BookSection], maxSectionsPerBatch: Int) -> [[BookSection]] {
        guard !sections.isEmpty else {
            return []
        }

        let safeBatchSize = max(1, maxSectionsPerBatch)
        var batches: [[BookSection]] = []
        var currentBatch: [BookSection] = []
        var currentSpineIndex: Int?

        for section in sections {
            let startsNewSpine = currentSpineIndex != nil && section.spineIndex != currentSpineIndex
            let exceedsBatchSize = currentBatch.count >= safeBatchSize
            if !currentBatch.isEmpty && (startsNewSpine || exceedsBatchSize) {
                batches.append(currentBatch)
                currentBatch = []
            }

            currentSpineIndex = section.spineIndex
            currentBatch.append(section)
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        return batches
    }
}
