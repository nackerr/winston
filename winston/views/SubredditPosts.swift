//
//  SubredditPosts.swift
//  winston
//
//  Created by Igor Marcossi on 26/06/23.
//

import SwiftUI
import Defaults
import SwiftUIIntrospect
import WaterfallGrid

let POSTLINK_OUTER_H_PAD: CGFloat = IPAD ? 0 : 8

struct SubredditPosts: View {
  @Default(.preferenceShowPostsCards) var preferenceShowPostsCards
  @ObservedObject var subreddit: Subreddit
  @Environment(\.openURL) var openURL
  @State var loading = true
  //  @State var loadingMore = false
  @StateObject var posts = ObservableArray<Post>()
  @State var lastPostAfter: String?
  @State var searchText: String = ""
  @State var sort: SubListingSortOption = Defaults[.preferredSort]
  @State var newPost = false
  //  @State var disableScroll = false
  @EnvironmentObject var redditAPI: RedditAPI
  
  func asyncFetch(force: Bool = false, loadMore: Bool = false) async {
    if (subreddit.data == nil || force) && !feedsAndSuch.contains(subreddit.id) {
      await subreddit.refreshSubreddit()
    }
    if posts.data.count > 0 && lastPostAfter == nil && !force {
      return
    }
    if let result = await subreddit.fetchPosts(sort: sort, after: loadMore ? lastPostAfter : nil), let newPosts = result.0 {
      withAnimation {
        if loadMore {
//          print("load more")
          posts.data.append(contentsOf: newPosts)
        } else {
          posts.data = newPosts
        }
        loading = false
        lastPostAfter = result.1
        //        loadingMore = false
      }
      Task {
        await redditAPI.updateAvatarURLCacheFromPosts(posts: newPosts)
      }
    }
  }
  
  func fetch(loadMore: Bool = false) {
    //    if loadMore {
    //      withAnimation {
    //        <#code#>
    //        loadingMore = true
    //      }
    //    }
    Task {
      await asyncFetch(loadMore: loadMore)
    }
  }
  
  var body: some View {
    Group {
      //      if IPAD {
      //        ScrollView(.vertical) {
      //          WaterfallGrid(posts.data, id: \.self.id) { el in
      //            PostLink(post: el, sub: subreddit)
      //          }
      //          .gridStyle(columns: 2, spacing: 16, animation: .easeInOut(duration: 0.5))
      //          .scrollOptions(direction: .vertical)
      //          .padding(.horizontal, 16)
      //        }
      //        .introspect(.scrollView, on: .iOS(.v13, .v14, .v15, .v16, .v17)) { scrollView in
      //          scrollView.backgroundColor = UIColor.systemGroupedBackground
      //        }
      //      } else {
      List {
        Group {
            ForEach(Array(posts.data.enumerated()), id: \.self.element.id) { i, post in
              
              PostLink(post: post, sub: subreddit)
                .equatable()
                .onAppear { if(Int(Double(posts.data.count) * 0.75) == i) { fetch(loadMore: true) } }
                .id(post.id)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .animation(.default, value: posts.data)
              
              if !preferenceShowPostsCards && i != (posts.data.count - 1) {
                VStack(spacing: 0) {
                  Divider()
                  Color.listBG
                    .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6)
                  Divider()
                }
                .id("\(post.id)-divider")
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
              }
              
            }
          if !lastPostAfter.isNil {
            ProgressView()
              .progressViewStyle(.circular)
              .frame(maxWidth: .infinity, minHeight: UIScreen.screenHeight - 200 )
              .id("post-loading")
          }
        }
        //          .listRowSeparator(preferenceShowPostsCards ? .hidden : .automatic)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
      }
      .introspect(.list, on: .iOS(.v15)) { list in
        list.backgroundColor = UIColor.systemGroupedBackground
      }
      .introspect(.list, on: .iOS(.v16, .v17)) { list in
        list.backgroundColor = UIColor.systemGroupedBackground
      }
      //    .listStyle(IPAD ? .grouped : .plain)
      //    .scrollContentBackground(.hidden)
      .listStyle(.plain)
      //        .if(IPAD) { $0.listStyle(.insetGrouped) }
      .environment(\.defaultMinListRowHeight, 1)
      //      }
    }
    .overlay(
      loading && posts.data.count == 0
      ? ProgressView()
        .frame(maxWidth: .infinity, minHeight: UIScreen.screenHeight)
      : nil)
    .overlay(
      feedsAndSuch.contains(subreddit.id)
      ? nil
      : Button {
        newPost = true
      } label: {
        Image(systemName: "newspaper.fill")
          .fontSize(22, .bold)
          .frame(width: 64, height: 64)
          .foregroundColor(.blue)
          .floating()
          .contentShape(Circle())
      }
        .buttonStyle(NoBtnStyle())
        .shrinkOnTap()
        .padding(.all, 12)
      , alignment: .bottomTrailing
    )
    .sheet(isPresented: $newPost, content: {
      NewPostModal(subreddit: subreddit)
    })
    .navigationBarItems(
      trailing:
        HStack {
          Menu {
            ForEach(SubListingSortOption.allCases) { opt in
              Button {
                sort = opt
              } label: {
                HStack {
                  Text(opt.rawVal.value.capitalized)
                  Spacer()
                  Image(systemName: opt.rawVal.icon)
                    .foregroundColor(.blue)
                    .fontSize(17, .bold)
                }
              }
            }
          } label: {
            Button { } label: {
              Image(systemName: sort.rawVal.icon)
                .foregroundColor(.blue)
                .fontSize(17, .bold)
            }
          }
          
          if let data = subreddit.data {
            NavigationLink {
              SubredditInfo(subreddit: subreddit)
            } label: {
              SubredditIcon(data: data)
            }
          }
        }
        .animation(nil, value: sort)
    )
    .navigationTitle("\(feedsAndSuch.contains(subreddit.id) ? subreddit.id.capitalized : "r/\(subreddit.data?.display_name ?? subreddit.id)")")
    .refreshable {
      await asyncFetch(force: true)
    }
    .searchable(text: $searchText, prompt: "Search r/\(subreddit.data?.display_name ?? subreddit.id)")
    .onAppear {
      //      sort = Defaults[.preferredSort]
      doThisAfter(0) {
        if posts.data.count == 0 {
          fetch()
        }
      }
    }
    .onChange(of: sort) { val in
      withAnimation {
        loading = true
        posts.data.removeAll()
      }
      fetch()
    }
  }
}

