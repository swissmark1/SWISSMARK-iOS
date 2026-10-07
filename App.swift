import SwiftUI
import FirebaseCore

@main
struct SwissMarkApp: App {
    init() {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
        }
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if FirebaseApp.app() == nil {
                    ZStack {
                        T.bg.ignoresSafeArea()
                        Text("ملف GoogleService-Info.plist غير موجود داخل التطبيق")
                            .foregroundColor(.white).multilineTextAlignment(.center).padding()
                    }
                } else {
                    RootView()
                }
            }
            .environment(\.layoutDirection, .rightToLeft)
            .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @StateObject private var store = Store()
    var body: some View {
        Group {
            if store.loggedIn { MainView() } else { LoginView() }
        }
        .environmentObject(store)
    }
}

struct LoginView: View {
    @EnvironmentObject var store: Store
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            RadialGradient(colors: [T.blue.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 300).ignoresSafeArea()
            RadialGradient(colors: [T.red.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 260).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 50)
                    Text("S").font(.system(size: 52, weight: .black)).foregroundColor(T.red)
                        .frame(width: 92, height: 92)
                        .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: 0x0B1A2A)))
                    HStack(spacing: 0) {
                        Text("SWISS").foregroundColor(.white)
                        Text("MARK").foregroundColor(T.red)
                    }.font(.system(size: 34, weight: .black)).environment(\.layoutDirection, .leftToRight).padding(.top, 14)
                    Text("MAINTENANCE").font(.system(size: 9)).tracking(3).foregroundColor(Color(hex: 0x7890A8))
                    Spacer().frame(height: 32)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("تسجيل الدخول").font(.system(size: 25, weight: .heavy)).foregroundColor(.white)
                        Text("ادخل إلى نظام إدارة الصيانة").font(.system(size: 12)).foregroundColor(T.muted)
                        Spacer().frame(height: 8)
                        field("البريد الإلكتروني", text: $email, secure: false)
                        field("كلمة المرور", text: $password, secure: true)
                        if !store.loginError.isEmpty {
                            Text(store.loginError).font(.system(size: 12)).foregroundColor(T.red).frame(maxWidth: .infinity)
                        }
                        Button { store.login(email: email, password: password) } label: {
                            Text(store.loading ? "جاري الدخول..." : "دخول إلى النظام").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(maxWi
