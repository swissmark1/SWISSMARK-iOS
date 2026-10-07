import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum T {
    static let bg = Color(hex: 0x040B14)
    static let card = Color(hex: 0x0B1D31)
    static let stroke = Color(hex: 0x193A5A)
    static let blue = Color(hex: 0x2F7BFF)
    static let green = Color(hex: 0x19C77A)
    static let orange = Color(hex: 0xFFB020)
    static let red = Color(hex: 0xFF3B5C)
    static let cyan = Color(hex: 0x22C7E8)
    static let muted = Color(hex: 0x7F96AE)
}

let allStatuses = ["قيد الانتظار", "مكتمل", "تم السحب", "لا يرد", "مؤجل", "تم في الورشة",
                   "تم الاستبدال", "تمت الزيارة", "تحت التجربة", "تم هاتفياً", "رفض الصيانة", "رفض دفع الأجور"]
let completedStatuses: Set<String> = ["مكتمل", "تم في الورشة", "تم الاستبدال", "تحت التجربة", "تم هاتفياً", "رفض دفع الأجور"]

func statusColor(_ s: String) -> Color {
    switch s {
    case "مكتمل", "تم في الورشة", "تم الاستبدال", "تحت التجربة", "تم هاتفياً", "رفض دفع الأجور": return T.green
    case "قيد الانتظار": return T.orange
    case "لا يرد": return Color(hex: 0xE86A78)
    case "مؤجل": return Color(hex: 0xC95B68)
    case "تم السحب": return Color(hex: 0xFFC107)
    case "تمت الزيارة": return T.cyan
    default: return T.blue
    }
}

struct Order: Identifiable {
    var id: String
    var number: Int
    var customer: String
    var phone: String
    var region: String
    var device: String
    var fault: String
    var status: String
    var fee: Double
    var urgent: Bool
    var dateAdded: Int64
    var notes: String = ""
    var isToday: Bool { Calendar.current.isDateInToday(Date(timeIntervalSince1970: Double(dateAdded) / 1000)) }
}
