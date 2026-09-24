import SwiftUI
import PhotosUI
import CoreLocation
import UIKit

// SWISS MARK iOS port based on the actual Android SWISSMARK source.
// Firebase is accessed through its HTTPS APIs so the project does not depend on an
// iOS Firebase SDK being preinstalled. The same Firebase project is used.

@main
struct SWISSMARKiOSApp: App {
    @StateObject private var session = AppSession()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(session) }
    }
}

// MARK: - Theme

enum SMTheme {
    static let bg = Color(red: 6/255, green: 20/255, blue: 38/255)
    static let card = Color(red: 23/255, green: 47/255, blue: 77/255)
    static let blue = Color(red: 37/255, green: 99/255, blue: 235/255)
    static let green = Color(red: 8/255, green: 185/255, blue: 104/255)
    static let orange = Color(red: 1, green: 168/255, blue: 0)
    static let red = Color(red: 245/255, green: 34/255, blue: 62/255)
    static let purple = Color(red: 113/255, green: 56/255, blue: 232/255)
    static let cyan = Color(red: 18/255, green: 169/255, blue: 200/255)
    static let text = Color(red: 234/255, green: 240/255, blue: 1)
}

struct SMBackground: View {
    var body: some View {
        LinearGradient(colors: [SMTheme.bg, Color.black.opacity(0.96)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

struct SMCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content.padding(16).background(SMTheme.card.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(SMTheme.blue.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - Models

enum UserRole: String, Codable, CaseIterable {
    case superAdmin = "SUPER_ADMIN", manager = "MANAGER", assistantManager = "ASSISTANT_MANAGER", technician = "TECHNICIAN", followUp = "FOLLOW_UP", unknown = "UNKNOWN"
    var title: String { switch self { case .superAdmin: "الإدارة"; case .manager: "المدير"; case .assistantManager: "مساعد المدير"; case .technician: "الفني"; case .followUp: "المتابعة"; case .unknown: "غير معروف" } }
    var canEditOrder: Bool { self != .unknown }
    var canDeleteOrder: Bool { self == .manager || self == .superAdmin }
    var canMarkUrgent: Bool { [.superAdmin,.manager,.assistantManager,.followUp].contains(self) }
    var canEnterFee: Bool { self != .unknown }
    var canManageUsers: Bool { self == .manager || self == .superAdmin }
}

struct Order: Identifiable, Codable, Hashable {
    var id = ""
    var orderNumber = 0
    var customerName = ""
    var agent = ""
    var phone = ""
    var secondPhone = ""
    var region = ""
    var device = ""
    var faultType = ""
    var status = "قيد الانتظار"
    var dateAdded: TimeInterval = 0
    var completionDate: TimeInterval = 0
    var maintenanceFee: Double = 0
    var urgent = false
    var photos: [String] = []
    var videos: [String] = []
    var customerLocation = ""
    var notes = ""
}

struct SMUser: Identifiable, Codable, Hashable {
    var id: String
    var name: String = ""
    var email: String = ""
    var role: UserRole = .unknown
    var active = true
}

enum SMStatus {
    static let all = ["قيد الانتظار","لا يرد","مؤجل","لم يكتمل","تمت الزيارة","تحت التجربة","خلل فني","مكتمل","تم في الورشة","تم الاستبدال","تم هاتفياً","تم السحب","رفض دفع الأجور"]
    static let completed = ["مكتمل","تم في الورشة","تم الاستبدال","تم هاتفياً","رفض دفع الأجور"]
    static func color(_ s: String) -> Color {
        if completed.contains(s) { return SMTheme.green }
        switch s { case "مؤجل","قيد الانتظار","تحت التجربة": return SMTheme.orange; case "تم السحب": return SMTheme.purple; case "مستعجلة": return SMTheme.red; case "تمت الزيارة": return SMTheme.cyan; default: return SMTheme.blue }
    }
}

// MARK: - Firebase REST

final class FirebaseREST {
    static let shared = FirebaseREST()
    let apiKey = "AIzaSyCQWRS4n2PtFv_pbr2YkLsrjesFJ7oIcuo"
    let project = "swissmark-93070"
    var idToken: String?
    var uid: String?
    private let session = URLSession.shared

    func signIn(email: String, password: String) async throws {
        var req = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(apiKey)")!)
        req.httpMethod = "POST"; req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["email":email,"password":password,"returnSecureToken":true])
        let (data,response) = try await session.data(for:req); guard let http = response as? HTTPURLResponse, http.statusCode < 300 else { throw FirebaseError.message(Self.errorText(data)) }
        let obj = try JSONSerialization.jsonObject(with:data) as! [String:Any]
        idToken = obj["idToken"] as? String; uid = obj["localId"] as? String
    }
    func signOut() { idToken=nil; uid=nil }
    private static func errorText(_ data: Data) -> String { (((try? JSONSerialization.jsonObject(with:data) as? [String:Any])?["error"] as? [String:Any])?["message"] as? String) ?? "تعذر الاتصال بـ Firebase" }

    func query(collection: String) async throws -> [[String:Any]] {
        let url = URL(string:"https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/\(collection)")!
        var req=URLRequest(url:url); req.setValue("Bearer \(idToken ?? "")",forHTTPHeaderField:"Authorization")
        let (data,response)=try await session.data(for:req); guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw FirebaseError.message(Self.errorText(data)) }
        let root=try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
        return (root["documents"] as? [[String:Any]] ?? []).map(Self.decodeDocument)
    }
    func set(collection:String, document:String, fields:[String:Any]) async throws {
        let url=URL(string:"https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/\(collection)/\(document)")!
        var req=URLRequest(url:url); req.httpMethod="PATCH"; req.setValue("Bearer \(idToken ?? "")",forHTTPHeaderField:"Authorization"); req.setValue("application/json",forHTTPHeaderField:"Content-Type")
        req.httpBody=try JSONSerialization.data(withJSONObject:["fields":Self.encodeFields(fields)])
        let (data,response)=try await session.data(for:req); guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw FirebaseError.message(Self.errorText(data)) }
    }
    func delete(collection:String, document:String) async throws {
        let url=URL(string:"https://firestore.googleapis.com/v1/projects/\(project)/databases/(default)/documents/\(collection)/\(document)")!
        var req=URLRequest(url:url); req.httpMethod="DELETE"; req.setValue("Bearer \(idToken ?? "")",forHTTPHeaderField:"Authorization")
        let (data,response)=try await session.data(for:req); guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else { throw FirebaseError.message(Self.errorText(data)) }
    }
    private static func decodeDocument(_ d:[String:Any])->[String:Any]{ var x=d["fields"] as? [String:Any] ?? [:]; var o:[String:Any]=["id":(d["name"] as? String)?.split(separator:"/").last.map(String.init) ?? ""]; for (k,v) in x { o[k]=decodeValue(v) }; return o }
    private static func decodeValue(_ v:Any)->Any { guard let d=v as? [String:Any] else{return v}; if let x=d["stringValue"]{return x}; if let x=d["integerValue"]{return Int(x as! String) ?? 0}; if let x=d["doubleValue"]{return x}; if let x=d["booleanValue"]{return x}; if let x=d["timestampValue"]{return x}; if let x=d["arrayValue"] as? [String:Any]{return (x["values"] as? [Any] ?? []).map(decodeValue)}; return "" }
    private static func encodeFields(_ f:[String:Any])->[String:Any]{ Dictionary(uniqueKeysWithValues:f.map{($0.key,encodeValue($0.value))}) }
    private static func encodeValue(_ v:Any)->[String:Any]{ if let s=v as? String{return ["stringValue":s]}; if let i=v as? Int{return ["integerValue":String(i)]}; if let d=v as? Double{return ["doubleValue":d]}; if let b=v as? Bool{return ["booleanValue":b]}; if let a=v as? [String]{return ["arrayValue":["values":a.map{["stringValue":$0]}]]}; return ["stringValue":String(describing:v)] }
}

enum FirebaseError: Error { case message(String) }

// MARK: - Session

@MainActor final class AppSession: ObservableObject {
    @Published var loggedIn=false
    @Published var role:UserRole = .unknown
    @Published var userName=""
    @Published var orders:[Order]=[]
    @Published var users:[SMUser]=[]
    @Published var loading=false
    @Published var error=""
    let api=FirebaseREST.shared

    func login(email:String,password:String) async {
        loading=true; error=""
        do { try await api.signIn(email:email,password:password); let docs=try await api.query(collection:"users"); let mine=docs.first{($0["email"] as? String)?.lowercased()==email.lowercased() || ($0["id"] as? String)==api.uid}; role=UserRole(rawValue:(mine?["role"] as? String ?? "UNKNOWN").uppercased()) ?? .unknown; userName=mine?["name"] as? String ?? email; loggedIn=true; await refresh() } catch let err {
            if case let FirebaseError.message(message) = err { error = message } else { error = "تعذر تسجيل الدخول" }
        }; loading=false
    }
    func logout(){api.signOut(); loggedIn=false; orders=[]; role = .unknown}
    func refresh() async { guard loggedIn else{return}; loading=true; do { let docs=try await api.query(collection:"orders"); orders=docs.compactMap(Self.order) } catch { self.error="تعذر تحميل الأوردرات" }; loading=false }
    static func order(_ d:[String:Any])->Order? { var o=Order(); o.id=d["id"] as? String ?? ""; o.orderNumber=d["orderNumber"] as? Int ?? Int(d["orderNumber"] as? String ?? "") ?? 0; o.customerName=d["customerName"] as? String ?? ""; o.agent=d["agent"] as? String ?? ""; o.phone=d["phone"] as? String ?? ""; o.secondPhone=d["secondPhone"] as? String ?? ""; o.region=d["region"] as? String ?? ""; o.device=d["device"] as? String ?? ""; o.faultType=d["faultType"] as? String ?? ""; o.status=d["status"] as? String ?? "قيد الانتظار"; o.dateAdded=(d["dateAdded"] as? Int).map(Double.init) ?? (d["dateAdded"] as? Double ?? 0); o.completionDate=(d["completionDate"] as? Int).map(Double.init) ?? (d["completionDate"] as? Double ?? 0); o.maintenanceFee=d["maintenanceFee"] as? Double ?? Double(d["maintenanceFee"] as? Int ?? 0); o.urgent=d["urgent"] as? Bool ?? false; o.photos=d["photos"] as? [String] ?? []; o.videos=d["videos"] as? [String] ?? []; o.customerLocation=d["customerLocation"] as? String ?? ""; o.notes=d["notes"] as? String ?? ""; return o }
    func save(_ o:Order) async { do { var f:[String:Any]=["orderNumber":o.orderNumber,"customerName":o.customerName,"agent":o.agent,"phone":o.phone,"secondPhone":o.secondPhone,"region":o.region,"device":o.device,"faultType":o.faultType,"status":o.status,"dateAdded":Int(o.dateAdded),"completionDate":Int(o.completionDate),"maintenanceFee":o.maintenanceFee,"urgent":o.urgent,"photos":o.photos,"videos":o.videos,"customerLocation":o.customerLocation,"notes":o.notes]; try await api.set(collection:"orders",document:o.id.isEmpty ? UUID().uuidString : o.id,fields:f); await refresh() } catch { self.error="تعذر حفظ الأوردر" } }
}

// MARK: - Root/Login

struct RootView: View {
    @EnvironmentObject var session:AppSession
    var body: some View { ZStack { SMBackground(); if session.loggedIn { MainSystem() } else { LoginScreen() } } .preferredColorScheme(.dark) }
}

struct LoginScreen: View {
    @EnvironmentObject var session:AppSession
    @State private var email=""; @State private var password=""
    var body: some View { VStack(spacing:22) { Spacer(); Text("SWISS MARK").font(.system(size:38,weight:.black)).foregroundStyle(SMTheme.text); Text("نظام إدارة الصيانة").foregroundStyle(.secondary); SMCard { VStack(spacing:14){ TextField("البريد الإلكتروني",text:$email).textInputAutocapitalization(.never).textFieldStyle(.roundedBorder); SecureField("كلمة المرور",text:$password).textFieldStyle(.roundedBorder); if !session.error.isEmpty{Text(session.error).foregroundStyle(SMTheme.red).font(.footnote)}; Button { Task{await session.login(email:email,password:password)} } label:{ HStack{if session.loading{ProgressView()}; Text("تسجيل الدخول").fontWeight(.bold)} }.frame(maxWidth:.infinity).padding().background(SMTheme.blue,in:RoundedRectangle(cornerRadius:14)) } }; Spacer() }.padding(20) }
}

// MARK: - Main navigation

enum MainPage: String, CaseIterable, Identifiable { case home="الرئيسية", orders="الأوردرات", urgent="المستعجلة", search="البحث", stats="الإحصائيات", add="إضافة أوردر", users="المستخدمون", blacklist="البلاك ليست", reports="التقارير", fees="أجور الصيانة", expenses="المصاريف", media="إدارة الوسائط", trash="سلة المحذوفات", settings="إعدادات النظام", chat="المحادثات"; var id:String{rawValue} }

struct MainSystem: View {
    @EnvironmentObject var session:AppSession
    @State private var page:MainPage = .home
    @State private var drawer=false
    var body: some View { ZStack(alignment:.leading) { Group { switch page { case .home: HomePage(); case .orders: OrdersPage(); case .urgent: OrdersPage(urgentOnly:true); case .search: SearchPage(); case .stats: StatisticsPage(); case .add: AddOrderPage(onSaved:{page = .orders}); case .users: UserManagementPage(); case .blacklist: SimplePage(title:"البلاك ليست"); case .reports: ReportsPage(); case .fees: SimplePage(title:"أجور الصيانة"); case .expenses: SimplePage(title:"المصاريف"); case .media: SimplePage(title:"إدارة الوسائط"); case .trash: SimplePage(title:"سلة المحذوفات"); case .settings: SettingsPage(); case .chat: SimplePage(title:"المحادثات") } }.frame(maxWidth:.infinity,maxHeight:.infinity); if drawer{Color.black.opacity(0.5).ignoresSafeArea().onTapGesture{withAnimation{drawer=false}}; DrawerView(page:$page,isOpen:$drawer)} }.onAppear{Task{await session.refresh()}} }
}

struct Header: View { let title:String; let menu:()->Void; var body:some View{HStack{Button(action:menu){Image(systemName:"line.3.horizontal").font(.title3)}; Spacer(); Text(title).font(.title3.bold()); Spacer(); Image(systemName:"wrench.and.screwdriver.fill").foregroundStyle(SMTheme.blue)}.foregroundStyle(SMTheme.text).padding(.horizontal,18).padding(.top,10).padding(.bottom,8)} }

// MARK: - Home

struct HomePage: View {
    @EnvironmentObject var session:AppSession
    var body:some View{NavigationStack{ScrollView{VStack(spacing:14){Header(title:"SWISS MARK",menu:{}); HStack{Text("مرحباً، \(session.userName)").font(.title2.bold());Spacer()}; LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:12){Metric(title:"كل الأوردرات",value:session.orders.count,icon:"list.bullet",color:SMTheme.blue);Metric(title:"قيد الانتظار",value:session.orders.filter{$0.status=="قيد الانتظار"}.count,icon:"clock",color:SMTheme.orange);Metric(title:"مكتمل",value:session.orders.filter{SMStatus.completed.contains($0.status)}.count,icon:"checkmark.circle",color:SMTheme.green);Metric(title:"مستعجل",value:session.orders.filter{$0.urgent}.count,icon:"exclamationmark.triangle",color:SMTheme.red)}; SMCard{VStack(alignment:.leading,spacing:12){Text("حالات الأوردرات").font(.headline);ForEach(SMStatus.all.prefix(8),id:\.self){s in let n=session.orders.filter{$0.status==s}.count; HStack{Circle().fill(SMStatus.color(s)).frame(width:8,height:8);Text(s);Spacer();Text("\(n)").bold()}}};}; Spacer(minLength:30)}.padding(.horizontal,14)}.background(SMTheme.bg)} }
}
struct Metric:View{let title:String;let value:Int;let icon:String;let color:Color;var body:some View{SMCard{VStack(alignment:.leading,spacing:8){Image(systemName:icon).foregroundStyle(color).font(.title2);Text("\(value)").font(.system(size:30,weight:.black));Text(title).foregroundStyle(.secondary).font(.caption)}}}}

// MARK: - Orders

struct OrdersPage: View {
    @EnvironmentObject var session: AppSession
    var urgentOnly = false
    @State private var status = "الكل"
    @State private var selected: Order?
    var filtered: [Order] { session.orders.filter { (status == "الكل" || $0.status == status) && (!urgentOnly || $0.urgent) } }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Header(title: urgentOnly ? "الأوردرات المستعجلة" : "الأوردرات", menu: {})
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button("الكل") { status = "الكل" }.buttonStyle(.bordered)
                        ForEach(SMStatus.all, id: \.self) { s in Button(s) { status = s }.buttonStyle(.bordered) }
                    }.padding(.horizontal, 14).padding(.bottom, 8)
                }
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filtered) { order in OrderCard(order: order).onTapGesture { selected = order } }
                    }.padding(14)
                }
            }
            .background(SMTheme.bg)
            .sheet(item: $selected) { OrderDetailPage(order: $0) }
        }
    }
}

struct OrderCard: View {
    let order: Order
    var body: some View {
        SMCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("#\(order.orderNumber)").font(.title3.bold())
                    Spacer()
                    Text(order.status).font(.caption.bold()).padding(.horizontal, 9).padding(.vertical, 5)
                        .background(SMStatus.color(order.status), in: Capsule())
                    if order.urgent { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(SMTheme.red) }
                }
                Text(order.customerName.isEmpty ? "بدون اسم" : order.customerName).font(.headline)
                InfoLine(k: "الهاتف", v: order.phone)
                InfoLine(k: "الجهاز", v: order.device)
                InfoLine(k: "العطل", v: order.faultType)
                InfoLine(k: "المنطقة", v: order.region)
                InfoLine(k: "تاريخ النزول", v: formatDate(order.dateAdded))
            }
        }
    }
}

struct InfoLine: View {
    let k: String; let v: String
    var body: some View { HStack { Text(k).foregroundStyle(.secondary); Spacer(); Text(v.isEmpty ? "-" : v).multilineTextAlignment(.trailing) } }
}

struct OrderDetailPage: View {
    @EnvironmentObject var session: AppSession
    @State var order: Order
    @Environment(\.dismiss) var dismiss
    let fields: [(String,String)]
    init(order: Order) {
        _order = State(initialValue: order)
        fields = [("اسم الزبون",order.customerName),("الوكيل",order.agent),("الهاتف",order.phone),("الهاتف الثاني",order.secondPhone),("المنطقة",order.region),("الجهاز",order.device),("نوع العطل",order.faultType),("الموقع",order.customerLocation),("أجور الصيانة",String(order.maintenanceFee)),("الملاحظات",order.notes)]
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    SMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { Text("الأوردر #\(order.orderNumber)").font(.title2.bold()); Spacer(); Text(order.status).padding(.horizontal,10).padding(.vertical,6).background(SMStatus.color(order.status), in: Capsule()) }
                            ForEach(Array(fields.enumerated()), id: \.offset) { _, item in InfoLine(k: item.0, v: item.1) }
                        }
                    }
                    SMCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("تغيير الحالة").font(.headline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack { ForEach(SMStatus.all, id: \.self) { s in Button(s) { order.status = s; if SMStatus.completed.contains(s) { order.completionDate = Date().timeIntervalSince1970 * 1000 }; Task { await session.save(order) } }.buttonStyle(.borderedProminent).tint(SMStatus.color(s)) } }
                            }
                        }
                    }
                    if order.maintenanceFee > 0 { SMCard { Text("أجرة الصيانة: \(order.maintenanceFee)").font(.headline) } }
                    if !order.customerLocation.isEmpty { SMCard { HStack { Text("الموقع"); Spacer(); Button("فتح Waze") { openWaze(order.customerLocation) } } } }
                }.padding(14)
            }
            .background(SMTheme.bg)
            .navigationTitle("تفاصيل الأوردر")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("إغلاق") { dismiss() } } }
        }
    }
}

struct AddOrderPage: View {
    @EnvironmentObject var session: AppSession
    var onSaved: () -> Void
    @State private var customer = ""
    @State private var agent = ""
    @State private var phone = ""
    @State private var second = ""
    @State private var region = ""
    @State private var device = ""
    @State private var fault = ""
    @State private var notes = ""
    @State private var location = ""
    @State private var urgent = false
    @State private var saving = false

    init(onSaved: @escaping () -> Void) {
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("بيانات الزبون") { Field("اسم الزبون", $customer); Field("الوكيل", $agent); Field("الهاتف", $phone); Field("الهاتف الثاني", $second); Field("المنطقة", $region) }
                Section("العطل") { Field("الجهاز", $device); Field("نوع العطل", $fault); Field("الملاحظات", $notes); Field("موقع الزبون", $location) }
                Section { Toggle("مستعجل", isOn: $urgent) }
                Section { Button { Task { await save() } } label: { HStack { Spacer(); if saving { ProgressView() }; Text("حفظ الأوردر").bold(); Spacer() } } }
            }.scrollContentBackground(.hidden).background(SMTheme.bg).navigationTitle("إضافة أوردر جديد")
        }
    }
    func save() async {
        guard !customer.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        saving=true
        let n=(session.orders.map{$0.orderNumber}.max() ?? 0)+1
        let o=Order(id:UUID().uuidString,orderNumber:n,customerName:customer,agent:agent,phone:phone,secondPhone:second,region:region,device:device,faultType:fault,status:"قيد الانتظار",dateAdded:Date().timeIntervalSince1970*1000,urgent:urgent,customerLocation:location,notes:notes)
        await session.save(o); saving=false; onSaved()
    }
}

struct Field: View { let title:String; @Binding var value:String; init(_ t:String,_ v:Binding<String>){title=t;_value=v}; var body:some View{TextField(title,text:$value)} }

struct SearchPage: View {
    @EnvironmentObject var session: AppSession; @State private var q=""
    var body: some View { NavigationStack { VStack { Header(title:"البحث",menu:{}); TextField("اسم الزبون أو الهاتف أو رقم الأوردر",text:$q).textFieldStyle(.roundedBorder).padding(.horizontal,14); ScrollView { LazyVStack { ForEach(session.orders.filter { q.isEmpty || $0.customerName.localizedCaseInsensitiveContains(q) || $0.phone.contains(q) || String($0.orderNumber).contains(q) }) { OrderCard(order:$0) } }.padding(14) } }.background(SMTheme.bg) } }
}

struct StatisticsPage: View {
    @EnvironmentObject var session: AppSession
    var body: some View { NavigationStack { ScrollView { VStack(spacing:10) { Header(title:"الإحصائيات",menu:{}); Metric(title:"إجمالي",value:session.orders.count,icon:"chart.bar.fill",color:SMTheme.blue); ForEach(SMStatus.all,id:\.self) { s in HStack { Text(s); Spacer(); Text("\(session.orders.filter{$0.status==s}.count)").bold() }.padding().background(SMTheme.card,in:RoundedRectangle(cornerRadius:12)) } }.padding(14) }.background(SMTheme.bg) } }
}

struct UserManagementPage: View {
    @EnvironmentObject var session: AppSession
    var body: some View { NavigationStack { List { ForEach(session.users) { u in HStack { VStack(alignment:.leading){Text(u.name.isEmpty ? u.email:u.name).bold();Text(u.role.title).font(.caption).foregroundStyle(.secondary)};Spacer();Circle().fill(u.active ? SMTheme.green:SMTheme.red).frame(width:10,height:10) } } }.scrollContentBackground(.hidden).background(SMTheme.bg).navigationTitle("المستخدمون والصلاحيات") } }
}

struct ReportsPage: View { @EnvironmentObject var session:AppSession; var body:some View{NavigationStack{ScrollView{VStack{Header(title:"التقارير",menu:{});SMCard{VStack(alignment:.leading){Text("تقرير نصف شهري").font(.headline);Text("الفترة 1–15 أو 16–نهاية الشهر").foregroundStyle(.secondary);Button("تجهيز تقرير") { }}}}.padding(14)}.background(SMTheme.bg)}}}
struct SimplePage: View { let title:String; var body:some View{NavigationStack{VStack{Header(title:title,menu:{});ContentUnavailableView(title,systemImage:"square.stack.3d.up");Spacer()}.background(SMTheme.bg)}}}
struct SettingsPage: View { @EnvironmentObject var session:AppSession; var body:some View{NavigationStack{Form{Section("الحساب"){Text(session.userName);Text(session.role.title);Button("تسجيل الخروج",role:.destructive){session.logout()}};Section("النظام"){Text("SWISS MARK")}}.scrollContentBackground(.hidden).background(SMTheme.bg).navigationTitle("إعدادات النظام")}}}

struct DrawerView: View {
    @EnvironmentObject var session: AppSession; @Binding var page: MainPage; @Binding var isOpen: Bool
    var body: some View {
        VStack(alignment:.leading,spacing:6) {
            HStack { Text("SWISS MARK").font(.title2.bold()); Spacer(); Button { isOpen=false } label: { Image(systemName:"xmark") } }.padding(.bottom,20)
            ScrollView { ForEach(MainPage.allCases) { p in if allowed(p) { Button { page=p; isOpen=false } label: { HStack { Image(systemName:icon(p)).frame(width:24); Text(p.rawValue); Spacer() }.padding(.vertical,11) }.foregroundStyle(SMTheme.text) } } }
            Spacer(); Text(session.role.title).font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width:300).background(SMTheme.card).ignoresSafeArea()
    }
    func allowed(_ p:MainPage)->Bool { if [.users,.trash].contains(p) { return session.role.canManageUsers }; return true }
    func icon(_ p:MainPage)->String { switch p { case .home:return "house.fill";case .orders:return "list.bullet.rectangle";case .urgent:return "exclamationmark.triangle";case .search:return "magnifyingglass";case .stats:return "chart.bar.fill";case .add:return "plus.circle";case .users:return "person.2";case .blacklist:return "nosign";case .reports:return "doc.text";case .fees:return "banknote";case .expenses:return "creditcard";case .media:return "photo.on.rectangle";case .trash:return "trash";case .settings:return "gearshape";case .chat:return "message" } }
}

func openWaze(_ location:String) { let parts=location.split(separator:",").map{String($0).trimmingCharacters(in:.whitespaces)}; guard parts.count>=2 else{return}; let url=URL(string:"waze://?ll=\(parts[0]),\(parts[1])&navigate=yes") ?? URL(string:"https://waze.com/ul?ll=\(parts[0]),\(parts[1])&navigate=yes")!; UIApplication.shared.open(url) }
func formatDate(_ ms:TimeInterval)->String { guard ms>0 else{return "-"}; let d=Date(timeIntervalSince1970:ms/1000); let f=DateFormatter(); f.dateFormat="yyyy-MM-dd HH:mm"; f.locale=Locale(identifier:"en_US_POSIX"); return f.string(from:d) }
