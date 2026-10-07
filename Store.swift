import SwiftUI
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class Store: ObservableObject {
    @Published var orders: [Order] = []
    @Published var loggedIn = false
    @Published var loading = false
    @Published var loginError = ""
    @Published var dataError = ""
    private var listener: ListenerRegistration?

    init() {
        if Auth.auth().currentUser != nil { loggedIn = true; listen() }
    }

    func login(email: String, password: String) {
        guard !email.isEmpty, !password.isEmpty else { loginError = "أدخل البريد وكلمة المرور"; return }
        loading = true; loginError = ""
        Task {
            do {
                let res = try await Auth.auth().signIn(withEmail: email.trimmingCharacters(in: .whitespaces), password: password)
                let snap = try await Firestore.firestore().collection("users").document(res.user.uid).getDocument()
                let d = snap.data() ?? [:]
                let active = d["active"] as? Bool ?? true
                let deleted = d["deleted"] as? Bool ?? false
                if !active || deleted {
                    try? Auth.auth().signOut()
                    loginError = "هذا الحساب موقوف أو محذوف. راجع المدير."
                } else {
                    loggedIn = true; listen()
                }
            } catch {
                try? Auth.auth().signOut()
                loginError = error.localizedDescription
            }
            loading = false
        }
    }

    func logout() {
        listener?.remove(); listener = nil
        try? Auth.auth().signOut()
        orders = []; loggedIn = false
    }

    private func listen() {
        listener?.remove()
        listener = Firestore.firestore().collection("orders").addSnapshotListener { [weak self] snap, err in
            let parsed = (snap?.documents ?? []).map { Store.parse($0) }.sorted { $0.dateAdded > $1.dateAdded }
            let msg = err?.localizedDescription ?? ""
            Task { @MainActor in
                self?.dataError = msg
                if err == nil { self?.orders = parsed }
            }
        }
    }

    nonisolated static func parse(_ doc: QueryDocumentSnapshot) -> Order {
        let d = doc.data()
        func num(_ v: Any?) -> Double {
            if let n = v as? NSNumber { return n.doubleValue }
            if let s = v as? String { return Double(s) ?? 0 }
            return 0
        }
        func str(_ k: String) -> String { d[k] as? String ?? "" }
        return Order(id: doc.documentID, number: Int(num(d["orderNumber"])), customer: str("customerName"),
                     phone: str("phone"), region: str("region"), device: str("device"), fault: str("faultType"),
                     status: (d["status"] as? String) ?? "قيد الانتظار", fee: num(d["maintenanceFee"]),
                     urgent: d["urgent"] as? Bool ?? false, dateAdded: Int64(num(d["dateAdded"])), notes: str("notes"))
    }

    func setStatus(_ id: String, _ status: String) {
        var data: [String: Any] = ["status": status]
        if completedStatuses.contains(status) { data["completionDate"] = Int64(Date().timeIntervalSince1970 * 1000) }
        Firestore.firestore().collection("orders").document(id).updateData(data)
    }

    func addOrder(customer: String, phone: String, region: String, device: String, fault: String, urgent: Bool) {
        let db = Firestore.firestore()
        let highest = Int64(orders.map { $0.number }.max() ?? 0)
        let ref = db.collection("counters").document("orders")
        db.runTransaction({ tx, errPtr -> Any? in
            let snap: DocumentSnapshot
            do { snap = try tx.getDocument(ref) } catch let e as NSError { errPtr?.pointee = e; return nil }
            let last = (snap.data()?["lastOrderNumber"] as? NSNumber)?.int64Value ?? 0
            let next = max(last, highest) + 1
            tx.setData(["lastOrderNumber": next], forDocument: ref, merge: true)
            return next
        }) { result, _ in
            guard let n = result as? Int64 else { return }
            db.collection("orders").addDocument(data: [
                "orderNumber": n, "customerName": customer, "agent": "", "phone": phone, "secondPhone": "",
                "region": region, "device": device, "faultType": fault, "status": "قيد الانتظار",
                "dateAdded": Int64(Date().timeIntervalSince1970 * 1000), "completionDate": 0,
                "maintenanceFee": 0, "urgent": urgent, "customerLocation": "", "notes": ""
            ])
        }
    }
}
