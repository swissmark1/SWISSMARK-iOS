import SwiftUI

struct HomeView: View {
    let orders: [Order]
    var goOrders: () -> Void

    var completed: Int { orders.filter { completedStatuses.contains($0.status) }.count }
    func count(_ s: String) -> Int { orders.filter { $0.status == s }.count }

    var body: some View {
        ZStack {
            T.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SWISS MARK").font(.system(size: 18, weight: .black)).foregroundColor(.white)
                            Text("MAINTENANCE").font(.system(size: 8)).tracking(2).foregroundColor(Color(hex: 0x6F88A2))
                        }
                        Spacer()
                        Image(systemName: "bell.fill").foregroundColor(.white).padding(12)
                            .background(Circle().fill(Color(hex: 0x0B1A2A)))
                    }
                    hero
                    HStack(spacing: 12) {
                        metric("الكل", orders.count, T.blue, "tray.full.fill")
                        metric("مكتملة", completed, T.green, "checkmark.seal.fill")
                    }
                    HStack(spacing: 12) {
                        metric("قيد الانتظار", count("قيد الانتظار"), T.orange, "clock.fill")
                        metric("مستعجلة", orders.filter { $0.urgent }.count, T.red, "bolt.fill")
                    }
                    statusCard
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("آخر الأوردرات").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                            Spacer()
                            Button("عرض الكل", action: goOrders).font(.system(size: 12)).foregroundColor(T.blue)
                        }
                        ForEach(orders.prefix(4)) { OrderRow(order: $0) }
                    }
                }.padding(18)
            }
        }
    }

    var hero: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 26)
                .fill(LinearGradient(colors: [Color(hex: 0x0C2A47), Color(hex: 0x071A2C), Color(hex: 0x071221)], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 6) {
                Text("Always at Your Service").font(.system(size: 15)).foregroundColor(Color(hex: 0xB7C7D9))
                Text("\(orders.filter { $0.isToday }.count)").font(.system(size: 44, weight: .black)).foregroundColor(.white)
                Text("أوردر اليوم").font(.system(size: 11)).foregroundColor(Color(hex: 0x93A9BE))
            }.padding(22)
        }
        .frame(maxWidth: .infinity).frame(height: 150)
        .overlay(RoundedRectangle(cornerRadius: 26).stroke(T.stroke, lineWidth: 1))
    }

    func metric(_ title: String, _ n: Int, _ color: Color, _ icon: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 11)).foregroundColor(T.muted)
                Text("\(n)").font(.system(size: 28, weight: .black)).foregroundColor(.white)
            }
            Spacer()
            Image(systemName: icon).foregroundColor(color).padding(10).background(Circle().fill(color.opacity(0.15)))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22).fill(T.card))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(color.opacity(0.35), lineWidth: 1))
    }

    var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الحالات").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
            ForEach(["لا يرد", "مؤجل", "تم السحب", "تمت الزيارة"], id: \.self) { s in
                let n = count(s)
                VStack(spacing: 5) {
                    HStack { Text(s).font(.system(size: 12)).foregroundColor(.white); Spacer(); Text("\(n)").font(.system(size: 12, weight: .bold)).foregroundColor(statusColor(s)) }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule().fill(statusColor(s)).frame(width: g.size.width * CGFloat(n) / CGFloat(max(orders.count, 1)))
                        }
                    }.frame(height: 6)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: 0x081A2C)))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color(hex: 0x173653), lineWidth: 1))
    }
}

struct OrderRow: View {
    let order: Order
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("#\(order.number)").font(.system(size: 12, weight: .bold)).foregroundColor(T.blue)
                    if order.urgent { Text("مستعجل").font(.system(size: 9, weight: .bold)).foregroundColor(.white).padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(T.red)) }
                }
                Text(order.customer).font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                Text("\(order.device) • \(order.region)").font(.system(size: 11)).foregroundColor(T.muted).lineLimit(1)
            }
            Spacer()
            Text(order.status).font(.system(size: 10, weight: .bold)).foregroundColor(statusColor(order.status))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(statusColor(order.status).opacity(0.15)))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 20).fill(Color(hex: 0x0B1E31)))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: 0x163650), lineWidth: 1))
    }
}
