//
//  ContentView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var document: MarshlandDocument

    var body: some View {
        NSTextEditor(attributedText: $document.attributedText)
    }
}
