//
//  MarshlandApp.swift
//  Marshland
//
//  Created by Graham Bing on 2025-05-27.
//

import SwiftUI

@main
struct MarshlandApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarshlandDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
