import SwiftUI

struct OrdersView: View {
    let orders: [Order]
    @State private var query = ""
    @State private var filter = "الكل"

    var shown: [Order] {
        orders.filter { (filter == "الكل" || $0.status == filter) &&
            (query.isEmpty || $0.customer.contains(query) || $0.phone.contains(query) || "\($0.number)".contains(query)) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                T.bg.ignoresSafeArea()
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(T.muted)
                        TextField("بحث بالاسم أو الرقم", text: $query)
                    }
                    .padding(14).background(RoundedRectangle(cornerRadius: 16).fill(T.card))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(["الكل"] + allStatuses, id: \.self) { s in
                                Button { filter = s } label: {
                                    Text(s).font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(filter == s ? .white : T.muted)
                                        .padding(.horizontal, 14).padding(.vertical, 8)
                                        .background(Capsule().fill(filter == s ? T.blue : T.card))
                                }
                            }
                        }
                    }
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(shown) { o in
                                NavigationLink { OrderDetailView(orderId: o.id) } label: { OrderRow(order: o) }.buttonStyle(.plain)
                            }
                        }
                    }
                }.padding(18)
            }
            .navigationTitle("الأوردرات").navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct OrderDetailView: View {
    @EnvironmentObject var store: Store
    let orderId: String
    var order: Order { store.orders.first { $0.id == orderId } ?? Order(id: orderId, number: 0, customer: "", phone: "", region: "", device: "", fault: "", status: "", fee: 0, urgent: false, dateAdded: 0) }
    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 8) {
                        Text("#\(order.number)").font(.system(size: 14, weight: .bold)).foregroundColor(T.blue)
                        Text(order.customer).font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                        Text(order.status).font(.system(size: 12, weight: .bold)).foregroundColor(statusColor(order.status))
                            .padding(.horizontal, 14).padding(.vertical, 6).background(Capsule().fill(statusColor(order.status).opacity(0.15)))
                    }.frame(maxWidth: .infinity).padding(20)
                        .background(RoundedRectangle(cornerRadius: 24).fill(T.card))
                    VStack(spacing: 0) {
                        row("phone.fill", "الهاتف", order.phone)
                        row("mappin.circle.fill", "المنطقة", order.region)
                        row("wrench.and.screwdriver.fill", "الجهاز", order.device)
                        row("exclamationmark.triangle.fill", "العطل", order.fault)
                        row("banknote.fill", "أجور الصيانة", order.fee == 0 ? "—" : "\(Int(order.fee)) د.ع")
                    }
                    .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
                    Menu {
                        ForEach(allStatuses, id: \.self) { s in Button(s) { store.setStatus(orderId, s) } }
                    } label: {
                        Text("تغيير الحالة").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(RoundedRectangle(cornerRadius: 16).fill(T.blue))
                    }
                    HStack(spacing: 12) {
                        action("اتصال", "phone.fill", T.green)
                        action("واتساب", "message.fill", Color(hex: 0x25D366))
                        action("الموقع", "location.fill", T.blue)
                    }
                }.padding(18)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    func row(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(T.blue).frame(width: 26)
            Text(label).font(.system(size: 13)).foregroundColor(T.muted)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
        }.padding(16)
    }

    func action(_ title: String, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
            Text(title).font(.system(size: 12, weight: .bold)).foregroundColor(.white)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 18).fill(color.opacity(0.14)))
    }
}

struct AddOrderView: View {
    @EnvironmentObject var store: Store
    var done: () -> Void
    @State private var customer = ""
    @State private var phone = ""
    @State private var region = ""
    @State private var device = ""
    @State private var fault = ""
    @State private var urgent = false

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("إضافة أوردر جديد").font(.system(size: 22, weight: .heavy)).foregroundColor(.white)
                    f("اسم الزبون", $customer); f("رقم الهاتف", $phone); f("المنطقة", $region)
                    f("الجهاز", $device); f("نوع العطل", $fault)
                    Toggle("مستعجل", isOn: $urgent).tint(T.red).padding(14)
                        .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
                    Button {
                        store.addOrder(customer: customer, phone: phone, region: region, device: device, fault: fault, urgent: urgent)
                        customer = ""; phone = ""; region = ""; device = ""; fault = ""; urgent = false
                        done()
                    } label: {
                        Text("حفظ الأوردر").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            .frame(maxWidth: .infinity).frame(height: 54)
                            .background(RoundedRectangle(cornerRadius: 17).fill(T.blue))
                    }.disabled(customer.isEmpty)
                }.padding(18)
            }
        }
    }

    func f(_ title: String, _ text: Binding<String>) -> some View {
        TextField(title, text: text).padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(T.card))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0x18324D), lineWidth: 1))
    }
}

struct MoreView: View {
    @EnvironmentObject var store: Store
    let items: [(String, String)] = [
        ("exclamationmark.circle.fill", "المستعجلة"), ("chart.bar.fill", "التقارير"), ("creditcard.fill", "المصاريف"),
        ("bubble.left.and.bubble.right.fill", "المحادثة"), ("person.3.fill", "المستخدمين"), ("nosign", "القائمة السوداء"),
        ("video.fill", "الفيديوهات"), ("internaldrive.fill", "التخزين"), ("trash.fill", "المحذوفات"),
    ]
    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(items, id: \.1) { icon, title in
                        VStack(spacing: 10) {
                            Image(systemName: icon).font(.system(size: 24)).foregroundColor(T.blue)
                            Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .background(RoundedRectangle(cornerRadius: 20).fill(T.card))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(T.stroke, lineWidth: 1))
                    }
                }.padding(18)
                Button { store.logout() } label: {
                    Text("تسجيل الخروج").font(.system(size: 14, weight: .bold)).foregroundColor(T.red)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 16).fill(T.red.opacity(0.12)))
                }.padding(.horizontal, 18)
            }
        }
    }
}
