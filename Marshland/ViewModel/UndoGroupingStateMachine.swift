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
    case typingSequence(expectedLocation: Int)
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
//        fatalError("Not implemented")
        return .startNewGroup
    }

    /// Reset the state machine to idle
    func reset() {
//        fatalError("Not implemented")
    }
}
