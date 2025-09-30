//
//  UndoGroupingStateMachineTests.swift
//  MarshlandTests
//
//  Created by Graham Bing on 2025-09-30.
//

import Testing
import Foundation
@testable import Marshland

@Suite("UndoGroupingStateMachine Tests")
struct UndoGroupingStateMachineTests {

    // MARK: - Initial State Tests

    @Test("Initial state should be idle")
    func initialState() {
        let stateMachine = UndoGroupingStateMachine()
        #expect(stateMachine.currentState == .idle)
    }

    @Test("Reset returns to idle state")
    func reset() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "a"))
        stateMachine.reset()
        #expect(stateMachine.currentState == .idle)
    }

    // MARK: - Character Insertion Tests

    @Test("First character insertion starts new group")
    func firstCharacterInsertion() {
        let stateMachine = UndoGroupingStateMachine()
        let decision = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        #expect(decision == .startNewGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 1))
    }

    @Test("Sequential character insertion continues group")
    func sequentialCharacterInsertion() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.characterInsertion(at: 1, char: "e"))
        #expect(decision == .continueCurrentGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 2))
    }

    @Test("Sequential character insertion with emoji continues group")
    func sequentialCharacterInsertionWithEmoji() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "👋"))
        let decision = stateMachine.processEvent(.characterInsertion(at: 2, char: "h")) // emoji takes 2 UTF-16 code units
        #expect(decision == .continueCurrentGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 3))
    }

    @Test("Non-sequential character insertion starts new group")
    func nonSequentialCharacterInsertion() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.characterInsertion(at: 5, char: "e")) // gap in location
        #expect(decision == .startNewGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 6))
    }

    // MARK: - Space Insertion Tests

    @Test("Space insertion ends current group and starts new")
    func spaceInsertionDuringTyping() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.spaceInsertion(at: 1))
        #expect(decision == .endCurrentGroupAndStartNew)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 2))
    }

    @Test("Space insertion when idle starts new group")
    func spaceInsertionWhenIdle() {
        let stateMachine = UndoGroupingStateMachine()
        let decision = stateMachine.processEvent(.spaceInsertion(at: 0))
        #expect(decision == .startNewGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 1))
    }
    
    @Test("Non-sequential space insertion starts new group (not end+start)")
    func nonSequentialSpaceInsertion() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        // Space at non-sequential location should behave like non-sequential char insertion
        let decision = stateMachine.processEvent(.spaceInsertion(at: 5)) // gap in location
        #expect(decision == .startNewGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 6))
    }
    
    // MARK: - Newline/Tab Insertion Tests

    @Test("Newline insertion ends current group")
    func newlineInsertionDuringTyping() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.newlineInsertion(at: 1))
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }

    @Test("Tab insertion ends current group")
    func tabInsertionDuringTyping() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.tabInsertion(at: 1))
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }

    @Test("Newline insertion when idle gets own group")
    func newlineInsertionWhenIdle() {
        let stateMachine = UndoGroupingStateMachine()
        let decision = stateMachine.processEvent(.newlineInsertion(at: 0))
        #expect(decision == .endCurrentGroup) // No group to end, but operation gets its own group
        #expect(stateMachine.currentState == .idle)
    }

    // MARK: - Deletion Tests

    @Test("Deletion ends current group")
    func deletionDuringTyping() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.deletion(range: NSRange(location: 0, length: 1)))
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }

    @Test("Deletion when idle gets own group")
    func deletionWhenIdle() {
        let stateMachine = UndoGroupingStateMachine()
        let decision = stateMachine.processEvent(.deletion(range: NSRange(location: 0, length: 1)))
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }

    // MARK: - Selection Movement Tests

    @Test("Selection movement ends current group")
    func selectionMovement() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.selectionMoved(from: NSRange(location: 1, length: 0),
                                                               to: NSRange(location: 5, length: 0)))
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }

    // MARK: - Other Operation Tests

    @Test("Other operations end current group")
    func otherOperation() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        let decision = stateMachine.processEvent(.otherOperation)
        #expect(decision == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)
    }
    
    @Test("Other operation when idle gets own group")
    func otherOperationWhenIdle() {
        let stateMachine = UndoGroupingStateMachine()
        let decision = stateMachine.processEvent(.otherOperation)
        #expect(decision == .endCurrentGroup) // Gets its own group even when idle
        #expect(stateMachine.currentState == .idle)
    }
    
    @Test("Sequential space insertions continue group")
    func sequentialSpaceInsertions() {
        let stateMachine = UndoGroupingStateMachine()
        _ = stateMachine.processEvent(.spaceInsertion(at: 0))
        let decision = stateMachine.processEvent(.spaceInsertion(at: 1))
        #expect(decision == .continueCurrentGroup)
        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 2))
    }

    // MARK: - Complex Scenarios

    @Test("Typing word-space-word produces correct grouping")
    func typingWordSpaceWord() {
        let stateMachine = UndoGroupingStateMachine()

        // Type "hello"
        #expect(stateMachine.processEvent(.characterInsertion(at: 0, char: "h")) == .startNewGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 1, char: "e")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 2, char: "l")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 3, char: "l")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 4, char: "o")) == .continueCurrentGroup)

        // Type space (ends "hello" group, starts new group)
        #expect(stateMachine.processEvent(.spaceInsertion(at: 5)) == .endCurrentGroupAndStartNew)

        // Type "world"
        #expect(stateMachine.processEvent(.characterInsertion(at: 6, char: "w")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 7, char: "o")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 8, char: "r")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 9, char: "l")) == .continueCurrentGroup)
        #expect(stateMachine.processEvent(.characterInsertion(at: 10, char: "d")) == .continueCurrentGroup)

        #expect(stateMachine.currentState == .typingSequence(expectedLocation: 11))
    }

    @Test("Typing with newline breaks grouping")
    func typingWithNewline() {
        let stateMachine = UndoGroupingStateMachine()

        // Type "hello"
        _ = stateMachine.processEvent(.characterInsertion(at: 0, char: "h"))
        _ = stateMachine.processEvent(.characterInsertion(at: 1, char: "e"))

        // Insert newline (breaks group)
        #expect(stateMachine.processEvent(.newlineInsertion(at: 2)) == .endCurrentGroup)
        #expect(stateMachine.currentState == .idle)

        // Type more characters (starts new group)
        #expect(stateMachine.processEvent(.characterInsertion(at: 3, char: "w")) == .startNewGroup)
    }
}
