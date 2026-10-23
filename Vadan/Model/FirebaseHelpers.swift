import Foundation
import FirebaseFirestore
import FirebaseFunctions

/** Shared Firebase handles (AppModule.kt on Android). Functions run in us-central1. */
enum Backend {
    static var db: Firestore { Firestore.firestore() }
    static var functions: Functions { Functions.functions(region: "us-central1") }
}

/** Reading loosely-typed Firestore / callable data the way Android's getString/getLong do. */
extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func int(_ key: String) -> Int? { (self[key] as? NSNumber)?.intValue }
    func int64(_ key: String) -> Int64? { (self[key] as? NSNumber)?.int64Value }
    func bool(_ key: String) -> Bool? { (self[key] as? NSNumber)?.boolValue }
    func timestamp(_ key: String) -> Timestamp? { self[key] as? Timestamp }
    func stringList(_ key: String) -> [String] { (self[key] as? [Any])?.compactMap { $0 as? String } ?? [] }
    func map(_ key: String) -> [String: Any] { self[key] as? [String: Any] ?? [:] }
}

extension Error {
    /** The Cloud Functions error code, when this came from a callable. */
    var functionsCode: FunctionsErrorCode? {
        let ns = self as NSError
        guard ns.domain == FunctionsErrorDomain else { return nil }
        return FunctionsErrorCode(rawValue: ns.code)
    }

    /** The Firestore error code, when this came from Firestore. */
    var firestoreCode: FirestoreErrorCode.Code? {
        let ns = self as NSError
        guard ns.domain == FirestoreErrorDomain else { return nil }
        return FirestoreErrorCode.Code(rawValue: ns.code)
    }

    /** Like Kotlin's exception.message. */
    var message: String { localizedDescription }
}

extension Timestamp {
    var millis: Int64 { Int64(dateValue().timeIntervalSince1970 * 1000) }
}

/** The callable's `data` as a dictionary. */
extension HTTPSCallableResult {
    var dict: [String: Any] { data as? [String: Any] ?? [:] }
}
