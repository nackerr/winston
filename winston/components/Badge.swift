//
//  Badge.swift
//  winston
//
//  Created by Igor Marcossi on 01/07/23.
//

import Foundation
import SwiftUI
import Defaults


struct Badge: View {
  var usernameColor: Color = .blue
  var showAvatar = true
  var author: String
  var fullname: String? = nil
  var created: Double
  var avatarURL: String?
  var avatarSize: CGFloat = 30
  var nameSize: CGFloat = 13
  var labelSize: CGFloat = 12
  var extraInfo: [String:String] = [:]
  @State var opened = false
  @EnvironmentObject var redditAPI: RedditAPI
  var body: some View {
    //    Button {
    //      opened = true
    //    } label: {
    HStack(spacing: 5) {
      if showAvatar {
        Avatar(url: avatarURL, userID: author, fullname: fullname, avatarSize: avatarSize)
          .onTapGesture {
            opened = true
          }
        //            .shrinkOnTap()
      }
      
      VStack(alignment: .leading) {
        
        //          VStack {
        (Text("by ").font(.system(size: nameSize, weight: .medium)).foregroundColor(.primary.opacity(0.5)) + Text(author).font(.system(size: nameSize, weight: .semibold)).foregroundColor(author == "[deleted]" ? .red : usernameColor))
          .onTapGesture {
            opened = true
          }
          .background(
            NavigationLink(destination: UserView(user: User(id: author, api: redditAPI)), isActive: $opened, label: { EmptyView().opacity(0).allowsHitTesting(false).disabled(true) }).buttonStyle(PlainButtonStyle()).opacity(0).frame(width: 0, height: 0).allowsHitTesting(false).disabled(true)
          )
        //              .allowsHitTesting(false)
        //          }
        //          .contentShape(Rectangle())
        //          .onTapGesture {
        //            opened = true
        //          }
        
        HStack(alignment: .center, spacing: 6) {
          ForEach(Array(extraInfo.keys), id: \.self) { icon in
            if let info = extraInfo[icon] {
              HStack(alignment: .center, spacing: 2) {
                Image(systemName: icon)
                Text(info)
              }
            }
          }
          
          HStack(alignment: .center, spacing: 2) {
            Image(systemName: "hourglass.bottomhalf.filled")
            Text(timeSince(Int(created)))
          }
        }
        .font(.system(size: labelSize, weight: .medium))
        .compositingGroup()
        .opacity(0.5)
      }
    }
    
    //    }
    //    .buttonStyle(ShrinkableBtnStyle())
  }
}
//
