//
//  Post.swift
//  winston
//
//  Created by Igor Marcossi on 28/06/23.
//

import SwiftUI
import CoreMedia
import Defaults
import AVKit
import AVFoundation

struct FlairTag: View {
  var text: String
  var color: Color = .secondary
  var body: some View {
    Text(text)
      .fontSize(13)
      .padding(.horizontal, 9)
      .padding(.vertical, 2)
      .background(Capsule(style: .continuous).fill(color.opacity(0.2)))
      .foregroundColor(.primary.opacity(0.5))
      .frame(maxWidth: 250, alignment: .leading)
      .fixedSize(horizontal: true, vertical: false)
      .lineLimit(1)
  }
}

let POSTLINK_INNER_H_PAD: CGFloat = 16

private class Appeared: ObservableObject {
  @Published var isIt: Bool = false
}

struct PostLink: View, Equatable {
  static func == (lhs: PostLink, rhs: PostLink) -> Bool {
    lhs.post == rhs.post && lhs.sub == rhs.sub
  }
  
  @Default(.preferenceShowPostsCards) var preferenceShowPostsCards
  @Default(.preferenceShowPostsAvatars) var preferenceShowPostsAvatars
  @ObservedObject var post: Post
  @ObservedObject var sub: Subreddit
  var showSub = false
  @State private var openedPost = false
  @State private var openedSub = false
  @StateObject private var appeared = Appeared()
  
  var contentWidth: CGFloat { UIScreen.screenWidth - (POSTLINK_OUTER_H_PAD * 2) - (preferenceShowPostsCards ? POSTLINK_INNER_H_PAD * 2 : 0) }
  
  var body: some View {
    if let data = post.data {
      let over18 = data.over_18 ?? false
      VStack(alignment: .leading, spacing: 8) {
        VStack(alignment: .leading, spacing: 12) {
          Text(data.title.escape)
            .fontSize(17, .medium)
            .allowsHitTesting(false)
          
          let imgPost = data.is_gallery == true || data.url.hasSuffix("jpg") || data.url.hasSuffix("png") || data.url.hasSuffix("webp")
          
          Group {
            if let media = data.secure_media {
              switch media {
              case .first(let datas):
                if let url = datas.reddit_video.hls_url, let rootURL = rootURL(url) {
                  VideoPlayerPost(post: post, sharedVideo: SharedVideo(url: rootURL))
                }
              case .second(_):
                EmptyView()
              }
            }
            
            if imgPost {
              ImageMediaPost(post: post, contentWidth: contentWidth)
            } else if data.selftext != "" {
              Text(data.selftext.md()).lineLimit(3)
                .fontSize(15)
                .opacity(0.75)
                .allowsHitTesting(false)
            }
            
            if !data.url.isEmpty && !data.is_self && !(data.is_video ?? false) && !(data.is_gallery ?? false) && data.post_hint != "image" {
              PreviewLink(data.url, contentWidth: contentWidth, media: data.secure_media)
            }
          }
          .nsfw(over18)
        }
        .zIndex(1)
        
        HStack(spacing: 0) {
          
          if showSub || feedsAndSuch.contains(sub.id) {
            FlairTag(text: "r/\(sub.data?.display_name ?? post.data?.subreddit ?? "Error")", color: .blue)
              .highPriorityGesture(TapGesture() .onEnded { openedSub = true })
            
            WDivider()
          }
          
          if over18 {
            FlairTag(text: "NSFW", color: .red)
            WDivider()
          }
          
          if let link_flair_text = data.link_flair_text {
            FlairTag(text: link_flair_text.emojied())
              .allowsHitTesting(false)
          }
          
          if !showSub && !feedsAndSuch.contains(sub.id) {
            WDivider()
          }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 2)
        
        HStack {
          if let fullname = data.author_fullname {
            Badge(showAvatar: preferenceShowPostsAvatars, author: data.author, fullname: fullname, created: data.created, extraInfo: ["message.fill":"\(data.num_comments)"])
          }
          
          Spacer()
          
          HStack(alignment: .center, spacing: 0) {
            MasterButton(icon: "arrow.up", mode: .subtle, color: .white, colorHoverEffect: .none, textColor: data.likes != nil && data.likes! ? .orange : .gray, textSize: 22, proportional: .circle) {
              Task {
                _ = await post.vote(action: .up)
              }
            }
            //            .shrinkOnTap()
            .padding(.all, -8)
            
            let downup = Int(data.ups - data.downs)
            Text(formatBigNumber(downup))
              .foregroundColor(downup == 0 ? .gray : downup > 0 ? .orange : .blue)
              .fontSize(16, .semibold)
              .padding(.horizontal, 12)
              .viewVotes(data.ups, data.downs)
              .zIndex(10)
            
            MasterButton(icon: "arrow.down", mode: .subtle, color: .white, colorHoverEffect: .none, textColor: data.likes != nil && !data.likes! ? .blue : .gray, textSize: 22, proportional: .circle) {
              Task {
                _ = await post.vote(action: .down)
              }
            }
            //            .shrinkOnTap()
            .padding(.all, -8)
          }
          .fontSize(22, .medium)
        }
      }
      .padding(.horizontal, preferenceShowPostsCards ? POSTLINK_INNER_H_PAD : 0)
      .padding(.vertical, preferenceShowPostsCards ? 14 : 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        !feedsAndSuch.contains(sub.id)
        ? nil
        : VStack {
          NavigationLink(destination: PostViewContainer(post: post.duplicate(), sub: Subreddit(id: post.data?.subreddit ?? "", api: post.redditAPI)), isActive: $openedPost, label: { EmptyView() }).buttonStyle(EmptyButtonStyle()).opacity(0).allowsHitTesting(false)
          NavigationLink(destination: SubredditPostsContainer(sub: Subreddit(id: post.data?.subreddit ?? "", api: post.redditAPI)), isActive: $openedSub, label: { EmptyView() }).buttonStyle(EmptyButtonStyle()).opacity(0).allowsHitTesting(false)
        }.opacity(0).allowsHitTesting(false)
      )
      .background(
        feedsAndSuch.contains(sub.id)
        ? nil
        : NavigationLink(destination: PostView(post: post, subreddit: sub), isActive: $openedPost, label: { EmptyView() }).buttonStyle(EmptyButtonStyle()).opacity(0).allowsHitTesting(false))
      .background(
        !preferenceShowPostsCards
        ? nil
        : RR(20, .listBG).allowsHitTesting(false)
      )
      .padding(.vertical, !preferenceShowPostsCards ? 8 : 0)
      .padding(.horizontal, !preferenceShowPostsCards ? POSTLINK_OUTER_H_PAD : 0 )
      .overlay(Rectangle().fill(.primary.opacity(openedPost ? 0.1 : 0)).allowsHitTesting(false))
      .mask(RR(preferenceShowPostsCards ? 20 : 0, .black))
      .padding(.horizontal, preferenceShowPostsCards ? POSTLINK_OUTER_H_PAD : 0 )
      .padding(.vertical, preferenceShowPostsCards ? 8 : 0)
      .compositingGroup()
      .opacity((data.winstonSeen ?? false) ? 0.75 : 1)
      .contentShape(Rectangle())
      .swipyUI(onTap: {
        openedPost = true
      }, secondActionIcon: (data.winstonSeen ?? false) ? "eye.slash.fill" : "eye.fill",
               leftActionHandler: {
        Task {
          _ = await post.vote(action: .down)
        }
      }, rightActionHandler: {
        Task {
          _ = await post.vote(action: .up)
        }
      }, secondActionHandler: {
        withAnimation {
          post.toggleSeen(optimistic: true)
        }
      })
      .foregroundColor(.primary)
      .multilineTextAlignment(.leading)
      .zIndex(1)
//      .opacity(appeared.isIt ? 1 : 0)
//      .offset(y: appeared.isIt ? 0 : 32)
//      .onAppear {
//        if !appeared.isIt {
//          withAnimation(spring) {
//            appeared.isIt = true
//          }
//        }
//      }
    } else {
      Text("Oops something went wrong")
    }
  }
}

struct EmptyButtonStyle: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
  }
}
