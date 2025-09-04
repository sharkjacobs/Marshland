//
//  AboutView.swift
//  Marshland
//
//  Created by Graham Bing on 2025-08-19.
//

import SwiftUI

struct AboutView: View {
    private var appVersionAndBuild: String {
        let version = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        let build = Bundle.main
            .infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        return "Version \(version) (\(build))"
    }
    
    private var copyright: String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        return "© \(year) GDB. All Rights Reserved."
    }
    
    private var developerWebsite: URL {
        URL(string: "https://gdb")!
    }
    
    var body: some View {
        VStack(spacing: 14) {
            Image("AppIcon")
                .resizable().scaledToFit()
                .frame(width: 80)
            Text("Marshland")
                .font(.title)
            VStack(spacing: 6) {
                Text(appVersionAndBuild)
                Text(copyright)
            }
            .font(.callout)
            Link(
                "Developer Website",
                destination: developerWebsite
            )
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 260)
    }
}

#Preview {
    AboutView()
}
