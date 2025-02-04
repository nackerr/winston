//
//  Posts.swift
//  winston
//
//  Created by Igor Marcossi on 24/06/23.
//

import SwiftUI
import Defaults
import Combine

let alphabetLetters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map { String($0) }

struct SubItem: View {
  @Environment(\.editMode) var editMode
  var openSub: (Subreddit) -> ()
  @ObservedObject var sub: Subreddit
  var selected: Bool
  var body: some View {
    if let data = sub.data {
      let favorite = data.user_has_favorited ?? false
      Button {
        openSub(sub)
      } label: {
        HStack {
          SubredditIcon(data: data)
          Text(data.display_name ?? "")
          
          Spacer()
          
          Image(systemName: "star.fill")
            .foregroundColor(favorite ? selected ? .white : .blue : selected ? .white.opacity(0.3) : .gray.opacity(0.3))
            .highPriorityGesture(
              TapGesture()
                .onEnded {
                  Task {
                    await sub.favoriteToggle()
                  }
                }
            )
        }
        .contentShape(Rectangle())
        .foregroundColor(selected ? .white : .primary)
      }
      .buttonStyle(.automatic)
      .background(RR(IPAD ? 13 : 0, selected ? .blue : .clear).padding(.horizontal, -16).padding(.vertical, -6))
      
    } else {
      Text("Error")
    }
  }
}

class SubsDictContainer: ObservableObject {
  @Published var data: [String: [Subreddit]] = [:] {
    didSet { observeChildrenChanges() }
  }
  var cancellables = [AnyCancellable]()
  
  init() {
    self.observeChildrenChanges()
  }
  
  func observeChildrenChanges() {
    cancellables.forEach { cancelable in
      cancelable.cancel()
    }
    Array(data.values).flatMap { $0 }.forEach({
      let c = $0.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() })
      self.cancellables.append(c)
    })
  }
}

struct PostsInBoxView: View {
  var openQuickPost: (PostInBox) -> ()
  var someOpened: Bool
  @EnvironmentObject var redditAPI: RedditAPI
  @Default(.postsInBox) var postsInBox
  
  var body: some View {
    if postsInBox.count > 0 {
      Section("Posts Box") {
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(postsInBox, id: \.self.id) { post in
              PostInBoxLink(post: post, openPost: openQuickPost)
                .animation(spring, value: postsInBox)
            }
          }
        }
        .id("quickPosts")
        .onChange(of: someOpened) { newValue in if !newValue { Task { await updatePostsInBox(redditAPI) } } }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
      }
    }
  }
}

class SelectedSubredditContainer: ObservableObject {
  @Published var sub = Subreddit(id: "home", api: RedditAPI())
}

struct Subreddits: View {
  var reset: Bool
  @Environment(\.openURL) var openURL
  @EnvironmentObject var redditAPI: RedditAPI
  @Default(.subreddits) var subreddits
  @State var searchText: String = ""
  @StateObject var subsDict = SubsDictContainer()
  @StateObject var selectedSubreddit = SelectedSubredditContainer()
  @State var selectedPost = PostInBox(id: "a", fullname: "a", title: "a", body: "a", subredditIconURL: "a", img: "a", subredditName: "a", authorName: "a")
  @State var selectedSubActive = IPAD
  @State var selectedPostActive = false
  @State var loaded = false
  @State var editMode: EditMode = .inactive
//  @StateObject var sharedVideo = SharedVideo(url: URL(string: "a")!)
  
  func sort(_ subs: [ListingChild<SubredditData>]) -> [String: [Subreddit]] {
    return Dictionary(grouping: subs.compactMap { $0.data }, by: { String($0.display_name?.prefix(1) ?? "").uppercased() })
      .mapValues { items in items.sorted { ($0.display_name ?? "") < ($1.display_name ?? "") }.map { Subreddit(data: $0, api: redditAPI) } }
  }
  
  func openSub(_ sub: Subreddit) {
    selectedSubreddit.sub = sub
    doThisAfter(0.05) {
      withAnimation {
        selectedSubActive = true
      }
    }
  }
  
  func openQuickPost(_ post: PostInBox) {
    selectedPost = post
    doThisAfter(0.05) {
      withAnimation {
        selectedPostActive = true
      }
    }
  }
  
  var subsArr: [Subreddit] {
    return Array(subsDict.data.values).flatMap { $0 }
  }
  
  var favoritesArr: [Subreddit] {
    return Array(subsArr.filter { $0.data?.user_has_favorited ?? false }).sorted { ($0.data?.display_name?.lowercased() ?? "") < ($1.data?.display_name?.lowercased() ?? "") }
  }
  
  var listArr: [String] {
    return Array(subsDict.data.keys).sorted { $0 < $1 }
  }
  
  var body: some View {
    let subsDictData = subsDict.data
    GoodNavigator {
      List {
        
        if searchText == "" {
          VStack(spacing: 12) {
            HStack(spacing: 12) {
              ListBigBtn(openSub: openSub, icon: "house.circle.fill", iconColor: .blue, label: "Home", destination: Subreddit(id: "home", api: redditAPI), selected: IPAD && selectedSubreddit.sub.id == "home")
              
              ListBigBtn(openSub: openSub, icon: "chart.line.uptrend.xyaxis.circle.fill", iconColor: .red, label: "Popular", destination: Subreddit(id: "popular", api: redditAPI), selected: IPAD && selectedSubreddit.sub.id == "popular")
            }
            HStack(spacing: 12) {
              ListBigBtn(openSub: openSub, icon: "globe.americas.fill", iconColor: .orange, label: "All", destination: Subreddit(id: "all", api: redditAPI), selected: IPAD && selectedSubreddit.sub.id == "all")
              
              ListBigBtn(openSub: openSub, icon: "bookmark.circle.fill", iconColor: .green, label: "Saved", destination: Subreddit(id: "saved", api: redditAPI), selected: IPAD && selectedSubreddit.sub.id == "saved").allowsHitTesting(false).opacity(0.5)
            }
          }
          .frame(maxWidth: .infinity)
          .id("bigButtons")
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
          .onChange(of: subreddits) { val in
            withAnimation(nil) {
              subsDict.data = sort(val)
            }
          }
        }
        

        PostsInBoxView(openQuickPost: openQuickPost, someOpened: selectedSubActive || selectedPostActive)
            .scrollIndicators(.hidden)
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowBackground(Color.clear)

        
        if searchText != "" {
          Section("Found subs") {
            ForEach(Array(subsArr.filter { ($0.data?.display_name ?? "").lowercased().contains(searchText.lowercased()) }).sorted { ($0.data?.display_name?.lowercased() ?? "") < ($1.data?.display_name?.lowercased() ?? "") }, id: \.self.id) { sub in
              SubItem(openSub: openSub, sub: sub, selected: IPAD && selectedSubreddit.sub == sub)
            }
          }
        } else {
          Section("Favorites") {
            ForEach(favoritesArr, id: \.self.id) { sub in
              SubItem(openSub: openSub, sub: sub, selected: IPAD && selectedSubreddit.sub == sub)
            }
            .onDelete(perform: deleteFromFavorites)
          }
          ForEach(listArr, id: \.self) { letter in
            if let subs = subsDictData[letter] {
              Section(header: Text(letter)) {
                ForEach(subs) { sub in
                  SubItem(openSub: openSub, sub: sub, selected: IPAD && selectedSubreddit.sub == sub)
                }
                .onDelete(perform: { i in deleteFromList(at: i, letter: letter)})
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .scrollDismissesKeyboard(.immediately)
      .background(
        NavigationLink(destination: SubredditPosts(subreddit: selectedSubreddit.sub), isActive: $selectedSubActive, label: { EmptyView() }).buttonStyle(EmptyButtonStyle()).opacity(0).allowsHitTesting(false)
      )
      .background(
        NavigationLink(destination: PostViewContainer(post: Post(id: selectedPost.id, api: redditAPI), sub: Subreddit(id: selectedPost.subredditName, api: redditAPI)), isActive: $selectedPostActive, label: { EmptyView() }).buttonStyle(EmptyButtonStyle()).opacity(0).allowsHitTesting(false).id(selectedPost.id)
      )
      .background(OFWOpener(reset: reset))
      .searchable(text: $searchText, prompt: "Search my subreddits")
      .refreshable {
        Task {
          await updatePostsInBox(redditAPI, force: true)
        }
        await redditAPI.fetchSubs()
      }
      .navigationTitle("Subs")
      .onChange(of: reset) { _ in
        selectedSubActive = false
        selectedPostActive = false
      }
      .onAppear {
        if !loaded {
          if subreddits.count > 0 {
            subsDict.data = sort(subreddits)
            loaded = true
          }
          
          Task {
            await redditAPI.fetchSubs()
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          EditButton()
        }
      }
      .environment(\.editMode, $editMode)
      //        .onDelete(perform: deleteItems)
    }
  }
  
  func deleteFromFavorites(at offsets: IndexSet) {
    for i in offsets {
      Task {
        await favoritesArr[i].subscribeToggle(optimistic: true)
      }
    }
  }
  
  func deleteFromList(at offsets: IndexSet, letter: String) {
    for i in offsets {
      if let sub = subsDict.data[letter]?[i] {
        Task {
          await sub.subscribeToggle(optimistic: true)
        }
      }
    }
  }
}

//struct Posts_Previews: PreviewProvider {
//  static var previews: some View {
//    Posts()
//  }
//}
