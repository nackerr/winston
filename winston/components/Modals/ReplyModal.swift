//
//  CommentModal.swift
//  winston
//
//  Created by Igor Marcossi on 02/07/23.
//

import SwiftUI
import HighlightedTextEditor
import Defaults

//class ReplyModalContent: Equatable, ObservableObject, Identifiable {
//  static func ==(lhs: ReplyModalContent, rhs: ReplyModalContent) -> Bool {
//    return lhs.id == rhs.id
//  }
//  @Published var comment: Comment?
//  var id: String {
//    return comment?.id ?? UUID().uuidString
//  }
//}

class TextFieldObserver : ObservableObject {
  @Published var debouncedTeplyText = ""
  @Published var replyText = ""
  
  init(delay: DispatchQueue.SchedulerTimeType.Stride) {
    $replyText
      .debounce(for: delay, scheduler: DispatchQueue.main)
      .assign(to: &$debouncedTeplyText)
  }
}

struct ReplyModalComment: View {
  @ObservedObject var comment: Comment
  
  func action(_ endLoading: (@escaping (Bool) -> ()), text: String) {
    if let _ = comment.typePrefix {
      Task {
        let result = await comment.reply(text)
        await MainActor.run {
          withAnimation(spring) {
            endLoading(result)
          }
        }
      }
    }
  }
  
  var body: some View {
    ReplyModal(thingFullname: comment.data?.name ?? "", action: action) {
      VStack {
        CommentLink(indentLines: 0, showReplies: false, comment: comment)
      }
    }
  }
}

struct ReplyModalPost: View {
  @ObservedObject var post: Post
  
  func action(_ endLoading: (@escaping (Bool) -> ()), text: String) {
    Task {
      let result = await post.reply(text)
      await MainActor.run {
        withAnimation(spring) {
          endLoading(result)
        }
      }
    }
  }
  
  var body: some View {
    ReplyModal(thingFullname: post.data?.name ?? "", action: action) {
      EmptyView()
    }
  }
}

struct ReplyModal<Content: View>: View {
  var thingFullname: String
  var action: ((@escaping (Bool) -> ()), String) -> ()
  @EnvironmentObject var tempGlobalState: TempGlobalState
  @EnvironmentObject var redditAPI: RedditAPI
  @State var alertExit = false
  @StateObject var textWrapper = TextFieldObserver(delay: 0.5)
  @Environment(\.dismiss) var dismiss
  @Environment(\.managedObjectContext) private var viewContext
  @State var currentDraft: ReplyDraft?
  @State var editorHeight: CGFloat = 200
  @State var loading = false
  @State private var selection: PresentationDetent = .medium
  @Default(.replyModalBlurBackground) var replyModalBlurBackground
  
  @FetchRequest(sortDescriptors: []) var drafts: FetchedResults<ReplyDraft>
  var content: (() -> Content)?
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 12) {
          
          VStack(alignment: .leading) {
            if let me = redditAPI.me?.data {
              Badge(author: me.name, fullname: me.name, created: Date().timeIntervalSince1970, avatarURL: me.icon_img ?? me.snoovatar_img)
            }
            MDEditor(text: $textWrapper.replyText)
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, minHeight: 200)
          .background(RR(16, .secondary.opacity(0.1)))
          .allowsHitTesting(!loading)
          .blur(radius: loading ? 24 : 0)
          .overlay(
            !loading
            ? nil
            : ProgressView()
              .progressViewStyle(.circular)
          )
          
          if let content = content {
            content()
          }
          
            
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 68)
      }
      .overlay(
        MasterButton(icon: "paperplane.fill", label: "Send", height: 48, fullWidth: true, cornerRadius: 16) {
          withAnimation(spring) {
            dismiss()
            tempGlobalState.loadingText = "Commenting..."
          }
          action({ result in
            tempGlobalState.loadingText = nil
            if result {
              if let currentDraft = currentDraft {
                viewContext.delete(currentDraft)
                try? viewContext.save()
              }
            }
          }, textWrapper.replyText)
        }
          .shrinkOnTap()
          .offset(y: loading || selection == collapsedPresentation ? 90 : 0)
          .animation(spring, value: selection)
          .padding(.horizontal, 16)
          .padding(.bottom, 8)
        , alignment: .bottom
      )
      .onChange(of: textWrapper.debouncedTeplyText, perform: { val in
        currentDraft?.replyText = val
        try? viewContext.save()
      })
      .onDisappear {
        if textWrapper.replyText == "", let currentDraft = currentDraft {
          viewContext.delete(currentDraft)
          try? viewContext.save()
        }
      }
      .onAppear {
        Task {
          await redditAPI.fetchMe()
        }
        if let draftEntity = drafts.first(where: { draft in draft.thingID == thingFullname }) {
          if let draftText = draftEntity.replyText {
            textWrapper.replyText = draftText
          }
          currentDraft = draftEntity
        } else {
          let newDraft = ReplyDraft(context: viewContext)
          newDraft.timestamp = Date()
          newDraft.thingID = thingFullname
          currentDraft = newDraft
        }
      }
      .navigationTitle("Replying")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem {
          HStack(spacing: 0) {
            MasterButton(icon: "trash.fill", mode: .subtle, color: .primary, textColor: .red, shrinkHoverEffect: true, height: 52, proportional: .circle, disabled: textWrapper.replyText == "") {
              withAnimation(spring) {
                alertExit = true
              }
            }
            .actionSheet(isPresented: $alertExit) {
              ActionSheet(title: Text("Are you sure you wanna discard?"), buttons: [
                .default(Text("Yes")) {
                  withAnimation(spring) {
                    dismiss()
                  }
                  if let currentDraft = currentDraft {
                    viewContext.delete(currentDraft)
                    try? viewContext.save()
                  }
                },
                .cancel()
              ])
            }
            
            MasterButton(icon: "chevron.down", mode: .subtle, color: .primary, textColor: .primary, shrinkHoverEffect: true, height: 52, proportional: .circle) {
              withAnimation(spring) {
                dismiss()
              }
            }
            
          }
        }
      }
    }
    .presentationDetents([.large, .fraction(0.75), .medium, collapsedPresentation], selection: $selection)
    .presentationCornerRadius(32)
    .presentationBackgroundInteraction(.enabled)
    .presentationBackground(replyModalBlurBackground ? AnyShapeStyle(.bar) : AnyShapeStyle(Color.listBG))
    .presentationDragIndicator(.hidden)
  }
}
