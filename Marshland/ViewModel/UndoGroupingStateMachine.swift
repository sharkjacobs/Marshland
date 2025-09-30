//
//  UndoGroupingStateMachine.swift
//  Marshland
//
//  Created by Graham Bing on 2025-09-30.
//

import Foundation

/// States for undo grouping behavior
enum UndoGroupingState: Equatable {
    case idle
    case typingSequence(expectedLocation: Int, sequence: String)
    case otherOperation
}

/// Events that affect undo grouping decisions
enum UndoGroupingEvent {
    case characterInsertion(at: Int, char: Character)
    case spaceInsertion(at: Int)
    case newlineInsertion(at: Int)
    case tabInsertion(at: Int)
    case deletion(range: NSRange)
    case selectionMoved(from: NSRange, to: NSRange)
    case otherOperation
}

/// Decisions for how to handle undo grouping
enum UndoGroupingDecision {
    case continueCurrentGroup
    case startNewGroup
    case endCurrentGroup
    case endCurrentGroupAndStartNew
}

/// State machine that manages undo grouping decisions for text operations
class UndoGroupingStateMachine {
    private(set) var currentState: UndoGroupingState = .idle

    /// Process an event and return the appropriate undo grouping decision
    /// - Parameter event: The event that occurred
    /// - Returns: The decision for how to handle undo grouping
    func processEvent(_ event: UndoGroupingEvent) -> UndoGroupingDecision {
        let decision = decisionForEvent(event)
        updateState(for: event, decision: decision)
        return decision
    }

    /// Reset the state machine to idle
    func reset() {
        currentState = .idle
    }

    // MARK: - Private Implementation

    private func decisionForEvent(_ event: UndoGroupingEvent) -> UndoGroupingDecision {
        switch (currentState, event) {

        // Character insertions
        case (.idle, .characterInsertion(_, _)):
            return .startNewGroup

        case (.typingSequence(let expectedLocation, _), .characterInsertion(let location, _)):
            if location == expectedLocation {
                return .continueCurrentGroup
            } else {
                // Non-sequential insertion starts new group
                return .startNewGroup
            }

        case (.otherOperation, .characterInsertion):
            return .startNewGroup

        // Space insertions
        case (.idle, .spaceInsertion):
            return .startNewGroup

        case (.typingSequence(let expectedLocation, let sequence), .spaceInsertion(let location)):
            if location == expectedLocation {
                if sequence.last == " " {
                    // Continue space sequence
                    return .continueCurrentGroup
                } else {
                    // Sequential space ends current word group and starts new group for next word
                    return .endCurrentGroupAndStartNew
                }
            } else {
                // Non-sequential space starts new group (like non-sequential char)
                return .startNewGroup
            }

        case (.otherOperation, .spaceInsertion):
            return .startNewGroup

        // Newline and tab insertions (always end groups, don't start new ones)
        case (_, .newlineInsertion), (_, .tabInsertion):
            return .endCurrentGroup

        // Deletions (always end groups)
        case (_, .deletion):
            return .endCurrentGroup

        // Selection movements (always end groups)
        case (_, .selectionMoved):
            return .endCurrentGroup

        // Other operations (always end groups)
        case (_, .otherOperation):
            return .endCurrentGroup
        }
    }

    private func updateState(for event: UndoGroupingEvent, decision: UndoGroupingDecision) {
        switch decision {
        case .continueCurrentGroup:
            // Update expected location and extend sequence for typing sequence
            if case .typingSequence(_, let sequence) = currentState {
                let newSequence = sequence + sequenceString(for: event)
                currentState = .typingSequence(expectedLocation: nextExpectedLocation(for: event), sequence: newSequence)
            }

        case .startNewGroup:
            // Start new typing sequence
            let sequence = sequenceString(for: event)
            currentState = .typingSequence(expectedLocation: nextExpectedLocation(for: event), sequence: sequence)

        case .endCurrentGroup:
            // Return to idle (newlines, tabs, deletions, selections, other operations)
            currentState = .idle

        case .endCurrentGroupAndStartNew:
            // End current group and start new one (spaces)
            let sequence = sequenceString(for: event)
            currentState = .typingSequence(expectedLocation: nextExpectedLocation(for: event), sequence: sequence)
        }
    }

    private func nextExpectedLocation(for event: UndoGroupingEvent) -> Int {
        switch event {
        case .characterInsertion(let location, let char):
            return location + char.utf16.count

        case .spaceInsertion(let location):
            return location + 1 // Space is always 1 UTF-16 code unit

        case .newlineInsertion(let location):
            return location + 1 // Newline is always 1 UTF-16 code unit

        case .tabInsertion(let location):
            return location + 1 // Tab is always 1 UTF-16 code unit

        case .deletion, .selectionMoved, .otherOperation:
            return 0 // These events don't establish expected locations
        }
    }

    private func sequenceString(for event: UndoGroupingEvent) -> String {
        switch event {
        case .characterInsertion(_, let char):
            return String(char)

        case .spaceInsertion:
            return " "

        case .newlineInsertion:
            return "\n"

        case .tabInsertion:
            return "\t"

        case .deletion, .selectionMoved, .otherOperation:
            return "" // These events don't contribute to sequences
        }
    }
}
